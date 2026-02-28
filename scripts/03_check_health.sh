#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# scripts/03_check_health.sh
#
# 检查所有服务健康状态
# ══════════════════════════════════════════════════════════════════

check() {
    local name="$1"
    local url="$2"
    if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
        echo "  ✅ ${name}"
    else
        echo "  ❌ ${name} (${url})"
    fi
}

echo ""
echo "── 健康检查 ─────────────────────────────────────────"

# GPU 0 服务
check "NIM 推理 API"   "http://localhost:8000/v1/health/ready"
check "MCP Server"     "http://localhost:9000/health"
check "ChromaDB"       "http://localhost:8001/api/v1/heartbeat"

# GPU 1 服务
check "NeMo Customizer"    "http://localhost:8080/health"
check "NeMo Data Designer" "http://localhost:8081/health"
check "NeMo Evaluator"     "http://localhost:8082/health"

echo ""

# GPU 状态
echo "── GPU 状态 ─────────────────────────────────────────"
nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total \
    --format=csv,noheader | while IFS=',' read -r idx name util mem_used mem_total; do
    echo "  GPU ${idx}: ${name}"
    echo "    使用率: ${util} | 显存: ${mem_used} / ${mem_total}"
done

# 容器状态
echo ""
echo "── 容器状态 ─────────────────────────────────────────"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "sun_tey|NAME"

echo ""
