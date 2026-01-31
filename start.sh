#!/bin/bash
set -e

echo "Starting llama-server with HF model download..."

export HF_HOME=/workspace/.cache/huggingface
mkdir -p "$HF_HOME"

exec /workspace/build/bin/llama-server \
  -hf lex-au/Orpheus-3b-FT-Q4_K_M.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --n-gpu-layers -1