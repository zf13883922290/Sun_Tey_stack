#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# scripts/02_deploy.sh
#
# 一键部署 Sun_Tey 全栈
# 用法: bash scripts/02_deploy.sh [--inference-only | --training-only]
# ══════════════════════════════════════════════════════════════════

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║         Sun_Tey Stack — 部署启动               ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── 检查 .env ─────────────────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env 文件不存在。请先运行 bash scripts/01_get_gpu_uuids.sh"
    exit 1
fi

source "$ENV_FILE"

if [ -z "$GPU_UUID_0" ]; then
    echo "❌ GPU_UUID_0 未设置。请先运行 bash scripts/01_get_gpu_uuids.sh"
    exit 1
fi

if [ -z "$NGC_API_KEY" ]; then
    echo "⚠️  NGC_API_KEY 未设置"
    echo "   请编辑 .env 填入你的 NGC API Key"
    echo "   获取方式: https://ngc.nvidia.com/ → Profile → Setup → API Key"
    read -p "   按 Enter 继续（NIM 需要 Key，MCP/ChromaDB 不需要）..."
fi

# ── 解析参数 ──────────────────────────────────────────────────────────────
MODE="all"
case "${1:-}" in
    --inference-only) MODE="inference" ;;
    --training-only)  MODE="training"  ;;
esac

# ── NGC 登录 ──────────────────────────────────────────────────────────────
if [ -n "$NGC_API_KEY" ]; then
    echo "📦 登录 NGC 容器仓库..."
    echo "$NGC_API_KEY" | docker login nvcr.io \
        --username '$oauthtoken' --password-stdin && \
        echo "✅ NGC 登录成功" || echo "⚠️  NGC 登录失败（继续）"
fi

# ── 启动 GPU 0 推理栈 ──────────────────────────────────────────────────────
if [ "$MODE" != "training" ]; then
    echo ""
    echo "🚀 启动 GPU 0 容器（推理栈）..."
    cd "$ROOT/containers/gpu0"
    docker compose --env-file "$ENV_FILE" up -d
    echo "✅ GPU 0 容器启动完成"
fi

# ── 启动 GPU 1 训练栈 ──────────────────────────────────────────────────────
if [ "$MODE" != "inference" ]; then
    echo ""
    echo "🚀 启动 GPU 1 容器（训练栈）..."
    cd "$ROOT/containers/gpu1"
    docker compose --env-file "$ENV_FILE" up -d
    echo "✅ GPU 1 容器启动完成"
fi

# ── 等待服务就绪 ───────────────────────────────────────────────────────────
echo ""
echo "⏳ 等待服务启动..."
echo "   NIM 首次启动需要 5-30 分钟（编译优化）"
echo "   其他服务通常 30-60 秒内就绪"
echo ""
sleep 10

# ── 运行健康检查 ───────────────────────────────────────────────────────────
bash "$ROOT/scripts/03_check_health.sh"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║            服务访问地址                         ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  NIM 推理 API:      http://localhost:8000/v1    ║"
echo "║  MCP Server:        http://localhost:9000       ║"
echo "║  ChromaDB:          http://localhost:8001       ║"
echo "║  NeMo Customizer:   http://localhost:8080       ║"
echo "║  NeMo Data Designer:http://localhost:8081       ║"
echo "║  NeMo Evaluator:    http://localhost:8082       ║"
echo "╚══════════════════════════════════════════════════╝"
