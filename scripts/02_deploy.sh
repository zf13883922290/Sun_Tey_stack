#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# Sun_Tey Stack — 分步部署脚本
# 用法: bash scripts/02_deploy.sh
# ══════════════════════════════════════════════════════════════════

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/.env"

step() { echo ""; echo "━━━ Step $1: $2 ━━━"; }
ok()   { echo "✅ $1"; }
fail() { echo "❌ $1"; exit 1; }
ask()  { read -p "▶ $1 继续? [y/N] " r; [[ "$r" == "y" ]] || exit 0; }

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║         Sun_Tey Stack — 分步部署               ║"
echo "╚══════════════════════════════════════════════════╝"

# ── Step 1: 环境检查 ───────────────────────────────────────────
step 1 "环境检查"
nvidia-smi --query-gpu=name --format=csv,noheader && ok "GPU 正常" || fail "GPU 异常"
docker info > /dev/null 2>&1 && ok "Docker 正常" || fail "Docker 异常"
[[ -n "$GPU_UUID_0" ]] && ok "GPU UUID 已配置" || fail "请先运行 01_get_gpu_uuids.sh"
[[ -n "$NGC_API_KEY" ]] && ok "NGC API Key 已配置" || fail "请在 .env 填入 NGC_API_KEY"
ask "Step 1 完成"

# ── Step 2: ChromaDB ───────────────────────────────────────────
step 2 "ChromaDB 向量记忆数据库"
cd "$ROOT/containers/gpu0"
docker compose up -d chromadb
sleep 5
curl -sf http://localhost:8001/api/v2/heartbeat > /dev/null && ok "ChromaDB 正常" || fail "ChromaDB 启动失败"
ask "Step 2 完成"

# ── Step 3: MCP Server ─────────────────────────────────────────
step 3 "MCP Server"
sudo systemctl enable sun_tey_mcp 2>/dev/null
sudo systemctl restart sun_tey_mcp
sleep 5
curl -sf http://localhost:9000/health > /dev/null && ok "MCP Server 正常" || fail "MCP Server 启动失败"
ask "Step 3 完成"

# ── Step 4: NIM 推理镜像下载 ───────────────────────────────────
step 4 "NIM 推理镜像下载 (约 20GB，需要时间)"
echo "镜像: nvcr.io/nim/meta/llama-3.1-8b-instruct:latest"
echo "下载完成前请勿关闭终端"
ask "开始下载 NIM"
docker pull nvcr.io/nim/meta/llama-3.1-8b-instruct:latest && ok "NIM 镜像下载完成" || fail "NIM 下载失败"
ask "Step 4 完成"

# ── Step 5: 启动 NIM ───────────────────────────────────────────
step 5 "启动 NIM 推理服务"
cd "$ROOT/containers/gpu0"
docker compose up -d nim
echo "等待 NIM 初始化 (首次约5-10分钟)..."
for i in $(seq 1 20); do
    sleep 30
    curl -sf http://localhost:8000/v1/health/ready > /dev/null && ok "NIM 就绪!" && break
    echo "  等待中... ($((i*30))秒)"
done
ask "Step 5 完成"

# ── Step 6: NeMo Framework 下载 ────────────────────────────────
step 6 "NeMo Framework 下载 (约 20GB)"
echo "镜像: nvcr.io/nvidia/nemo:24.07"
ask "开始下载 NeMo"
docker pull nvcr.io/nvidia/nemo:24.07 && ok "NeMo 下载完成" || fail "NeMo 下载失败"
ask "Step 6 完成"

# ── Step 7: 完成 ───────────────────────────────────────────────
step 7 "全部完成"
bash "$ROOT/scripts/03_check_health.sh"
echo ""
echo "🎉 Sun_Tey Stack 部署完成！"
