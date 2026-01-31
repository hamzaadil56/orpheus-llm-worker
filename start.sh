#!/bin/bash
set -e

echo "Starting llama-server with HF model download..."

export HF_HOME=/workspace/.cache/huggingface
mkdir -p "$HF_HOME"

# Start llama-server in background
/workspace/build/bin/llama-server \
  -hf lex-au/Orpheus-3b-FT-Q4_K_M.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --n-gpu-layers -1 &

# Wait for llama-server to be ready
echo "Waiting for llama-server on port 8080..."
for i in $(seq 1 120); do
  if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/health 2>/dev/null | grep -q "200"; then
    echo "llama-server is ready."
    break
  fi
  if [ "$i" -eq 120 ]; then
    echo "Timeout waiting for llama-server"
    exit 1
  fi
  sleep 2
done

# Start RunPod worker (blocking)
exec python3 -u handler.py
