#!/bin/bash
set -e

echo "Starting llama-server (Orpheus TTS) with Hugging Face model..."

export HF_HOME=/workspace/.cache/huggingface
mkdir -p "$HF_HOME"

# llama-server from ggml-org image: /app/llama-server
LLAMA_BIN="${LLAMA_BIN:-/app/llama-server}"
MODEL_HF="${MODEL_HF:-lex-au/Orpheus-3b-FT-Q4_K_M.gguf}"
PORT_LLAMA="${PORT_LLAMA:-8080}"
# Model download can take 20-40+ min; increase for slow networks
WAIT_TIMEOUT_SEC="${WAIT_TIMEOUT_SEC:-2400}"
WAIT_INTERVAL_SEC="${WAIT_INTERVAL_SEC:-5}"

# Start llama-server in background with line-buffered output so download progress is visible
echo "Downloading model and starting llama-server (output below)..."
if command -v stdbuf >/dev/null 2>&1; then
  stdbuf -oL -eL "$LLAMA_BIN" \
    -hf "$MODEL_HF" \
    --host 0.0.0.0 \
    --port "$PORT_LLAMA" \
    --n-gpu-layers -1 2>&1 &
else
  "$LLAMA_BIN" \
    -hf "$MODEL_HF" \
    --host 0.0.0.0 \
    --port "$PORT_LLAMA" \
    --n-gpu-layers -1 2>&1 &
fi

# Wait for llama-server to be ready (model must download and load first)
echo "Waiting for llama-server on port $PORT_LLAMA (model download/load may take 20-40 min on first run)..."
ITERATIONS=$((WAIT_TIMEOUT_SEC / WAIT_INTERVAL_SEC))
for i in $(seq 1 "$ITERATIONS"); do
  if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT_LLAMA}/health" 2>/dev/null | grep -q "200"; then
    echo "llama-server is ready."
    break
  fi
  if [ "$i" -eq "$ITERATIONS" ]; then
    echo "Timeout (${WAIT_TIMEOUT_SEC}s) waiting for llama-server - model may still be downloading"
    exit 1
  fi
  # Print status every ~60 seconds so user knows we're still waiting
  if [ $((i % 12)) -eq 0 ] && [ "$i" -gt 0 ]; then
    echo "[$((i * WAIT_INTERVAL_SEC))s] Still waiting for model load... (check llama-server output above for download progress)"
  fi
  sleep "$WAIT_INTERVAL_SEC"
done

# Run proxy on main port (RunPod expects single port: /ping + /v1/completions)
export LLAMA_SERVER_URL="http://0.0.0.0:${PORT_LLAMA}"
exec python3 -u /app/proxy.py
