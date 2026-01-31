FROM ghcr.io/ggml-org/llama.cpp:server-cuda

# Set up model cache directories
ENV HF_HOME=/workspace/.cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/.cache/huggingface

RUN mkdir -p /workspace/.cache/huggingface

# Copy start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]