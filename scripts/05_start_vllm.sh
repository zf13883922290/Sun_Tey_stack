#!/usr/bin/env bash
# vLLM 推理服务 — 替代 NIM，支持 P100 float16
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/.env"

MODEL="${VLLM_MODEL:-meta-llama/Llama-3.1-8B-Instruct}"
PORT="${VLLM_PORT:-8000}"

echo "启动 vLLM: $MODEL (float16, port $PORT)"
[ -n "$HF_TOKEN" ] && export HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"

python -m vllm.entrypoints.openai.api_server \
    --model "$MODEL" \
    --dtype float16 \
    --port "$PORT" \
    --host 0.0.0.0 \
    --max-model-len 4096 \
    --gpu-memory-utilization 0.85 \
    --served-model-name "sun-tey" \
    --trust-remote-code
