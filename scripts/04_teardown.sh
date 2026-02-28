#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "停止 GPU 0 容器..."
cd "$ROOT/containers/gpu0" && docker compose down
echo "停止 GPU 1 容器..."
cd "$ROOT/containers/gpu1" && docker compose down
echo "✅ 所有服务已停止"
