#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/.env" ] && source "$ROOT/.env"

check() {
    curl -sf --max-time 5 "$2" > /dev/null 2>&1 && \
        echo "  ✅ $1" || echo "  ❌ $1 → $2"
}

check_svc() {
    systemctl is-active --quiet "$2" 2>/dev/null && \
        echo "  ✅ $1 (运行中)" || echo "  ⚠️  $1 (未运行)"
}

echo ""
echo "── Ubuntu 本地服务 (192.168.1.5) ───────────────────"
check "ChromaDB"       "http://localhost:8001/api/v2/heartbeat"
check "MCP Server"     "http://localhost:9000/health"
check "vLLM API"       "http://localhost:8000/v1/models"
check "LLaMA-Factory"  "http://localhost:7860"

echo ""
echo "── systemd 服务 ─────────────────────────────────────"
check_svc "ChromaDB"      "sun_tey_chromadb"
check_svc "MCP Server"    "sun_tey_mcp"
check_svc "vLLM"          "sun_tey_vllm"

echo ""
echo "── Windows 远程推理 (192.168.1.2) ──────────────────"
check "Windows Ollama"  "http://192.168.1.2:11434/api/tags"

echo ""
echo "── GPU 状态 ─────────────────────────────────────────"
nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total \
    --format=csv,noheader | while IFS=',' read -r i n u mu mt; do
    echo "  GPU${i}: ${n} | 使用率:${u} | 显存:${mu}/${mt}"
done

echo ""
echo "── Docker 容器 ──────────────────────────────────────"
docker ps --format "  {{.Names}}\t{{.Status}}" | grep sun_tey || echo "  无运行中容器"
echo ""
