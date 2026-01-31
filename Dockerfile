FROM ghcr.io/ggml-org/llama.cpp:server-cuda

# Set up model cache directories
ENV HF_HOME=/workspace/.cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/.cache/huggingface

RUN mkdir -p /workspace/.cache/huggingface

# Install Python and RunPod worker dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY start.sh /start.sh
COPY handler.py /app/handler.py
RUN chmod +x /start.sh

WORKDIR /app
CMD ["/start.sh"]
