"""
RunPod serverless handler that forwards prompts to the local llama-server
and returns the completion response in the same format as the llama-server.
"""

import runpod
import requests

LLAMA_SERVER_URL = "http://0.0.0.0:8080/v1/completions"


def handler(event):
    """
    RunPod handler. Expects input:
        { "input": { "prompt": "Hello World" } }

    Forwards the prompt to the running llama-server and returns
    the exact response from the /completion endpoint.
    """
    input_data = event.get("input", {})
    prompt = input_data.get("prompt")

    if prompt is None:
        return {"error": "Missing 'prompt' in input"}

    # Build request body: prompt + optional params from input (n_predict, temperature, etc.)
    body = {
        "prompt": prompt,
        "stream": False,
    }
    # Pass through common completion params if provided
    for key in ("n_predict", "temperature", "top_p", "top_k", "stop", "seed"):
        if key in input_data:
            body[key] = input_data[key]

    try:
        resp = requests.post(
            f"{LLAMA_SERVER_URL}",
            json=body,
            timeout=300,
        )
        resp.raise_for_status()
        return resp.json()
    except requests.exceptions.ConnectionError:
        return {"error": "llama-server not reachable at 127.0.0.1:8080"}
    except requests.exceptions.Timeout:
        return {"error": "llama-server request timed out"}
    except requests.exceptions.RequestException as e:
        return {"error": str(e), "status_code": getattr(e.response, "status_code", None)}


runpod.serverless.start({"handler": handler})
