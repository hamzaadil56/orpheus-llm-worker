"""
RunPod load balancing proxy for llama.cpp server.

Exposes GET /ping for RunPod health checks (200 when ready, 204 when initializing)
and forwards all other requests to the backend llama-server (OpenAI-compatible /v1/completions).
"""

import os
import logging
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware

LLAMA_SERVER = os.getenv("LLAMA_SERVER_URL", "http://0.0.0.0:8080")
PORT = int(os.getenv("PORT", "80"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield


app = FastAPI(title="Orpheus llama.cpp Load Balancing Proxy",
              version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=[
                   "*"], allow_methods=["*"], allow_headers=["*"])


async def _llama_healthy() -> bool:
    """Return True if llama-server /health returns 200."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{LLAMA_SERVER}/health")
            return r.status_code == 200
    except Exception:
        return False


@app.get("/ping")
async def ping():
    """RunPod load balancer health check: 200 when ready, 204 when initializing."""
    if await _llama_healthy():
        return JSONResponse(content={"status": "healthy"}, status_code=200)
    return JSONResponse(content={"status": "initializing"}, status_code=204)


@app.get("/")
async def root():
    """Root endpoint with basic info."""
    ready = await _llama_healthy()
    return {
        "message": "Orpheus llama.cpp Load Balancing Server",
        "status": "ready" if ready else "initializing",
        "endpoints": {
            "health": "/ping",
            "completions": "/v1/completions",
        },
    }


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
async def proxy(path: str, request: Request):
    """Forward all other requests to llama-server, including streaming."""
    url = f"{LLAMA_SERVER}/{path}"
    if request.scope.get("query_string"):
        url = f"{url}?{request.scope['query_string'].decode()}"

    body = await request.body()
    headers = dict(request.headers)
    # Drop hop-by-hop and host
    for h in ("host", "connection", "transfer-encoding"):
        headers.pop(h, None)

    client = httpx.AsyncClient(timeout=300.0)
    try:
        return await _stream_proxy(client, request.method, url, headers, body)
    except Exception:
        await client.aclose()
        raise


async def _stream_proxy(client: httpx.AsyncClient, method: str, url: str, headers: dict, body: bytes):
    """Stream response from llama-server back to client. Keeps connection open until stream is consumed."""
    req = client.build_request(method, url, content=body, headers=headers)
    r = await client.send(req, stream=True)

    async def stream():
        try:
            async for chunk in r.aiter_bytes():
                yield chunk
        except httpx.StreamClosed as e:
            # Upstream or client closed the stream; stop cleanly
            logger.debug("Stream closed: %s", e)
        finally:
            await r.aclose()
            await client.aclose()

    return StreamingResponse(
        stream(),
        status_code=r.status_code,
        headers={
            k: v
            for k, v in r.headers.items()
            if k.lower() not in ("transfer-encoding", "connection")
        },
        media_type=r.headers.get("content-type", "text/event-stream"),
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="info")
