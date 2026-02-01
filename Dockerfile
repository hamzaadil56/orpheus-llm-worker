# Load balancing llama.cpp server for Orpheus TTS (lex-au/Orpheus-3b-FT-Q4_K_M.gguf)
# RunPod load balancer expects: GET /ping (200 when ready, 204 when initializing), POST /v1/completions
FROM ghcr.io/ggml-org/llama.cpp:server-cuda

ENV HF_HOME=/workspace/.cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/.cache/huggingface

RUN mkdir -p /workspace/.cache/huggingface

# Install Python and proxy dependencies (no RunPod serverless SDK for load balancing)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY proxy.py /app/proxy.py
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Single port for RunPod: proxy serves /ping and forwards to llama-server
ENV PORT=80
EXPOSE 80

# Base image sets ENTRYPOINT to llama-server; we override to run our startup script
ENTRYPOINT []
CMD ["/start.sh"]
