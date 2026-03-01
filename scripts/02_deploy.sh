#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/.env"

step() { echo ""; echo "━━━ Step $1: $2 ━━━"; }
ok()   { echo "✅ $1"; }
warn() { echo "⚠️  $1"; }
fail() { echo "❌ $1"; exit 1; }
ask()  { read -p "▶ $1 继续? [y/N] " r; [[ "$r" == "y" ]] || exit 0; }

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║     Sun_Tey Stack — 分步部署 v2.0              ║"
echo "║  Ubuntu 双P100 训练 + Windows 5060Ti 推理       ║"
echo "╚══════════════════════════════════════════════════╝"

step 1 "环境检查"
nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader | \
    while IFS=',' read -r idx name mem; do echo "  GPU${idx}: ${name} ${mem}"; done
docker info > /dev/null 2>&1 && ok "Docker 正常" || fail "Docker 异常"
[[ -n "$GPU_UUID_0" ]] && ok "GPU UUID 已配置" || fail "请先运行 01_get_gpu_uuids.sh"
ask "Step 1 完成"

step 2 "ChromaDB 向量记忆数据库"
cd "$ROOT/containers/gpu0"
docker compose up -d chromadb
sleep 5
curl -sf http://localhost:8001/api/v2/heartbeat > /dev/null && \
    ok "ChromaDB 正常 (port 8001)" || fail "ChromaDB 启动失败"
ask "Step 2 完成"

step 3 "MCP Server"
sudo systemctl enable sun_tey_mcp 2>/dev/null
sudo systemctl restart sun_tey_mcp
sleep 5
curl -sf http://localhost:9000/health > /dev/null && \
    ok "MCP Server 正常 (port 9000)" || fail "MCP Server 启动失败"
ask "Step 3 完成"

step 4 "vLLM 推理服务 (P100 float16，替代 NIM)"
pip show vllm > /dev/null 2>&1 || pip install vllm --quiet
sudo systemctl enable sun_tey_vllm 2>/dev/null
sudo systemctl restart sun_tey_vllm 2>/dev/null && \
    ok "vLLM 服务已启动" || warn "手动运行: bash scripts/05_start_vllm.sh"
ask "Step 4 完成"

step 5 "NeMo Framework (训练/微调)"
docker images | grep -q "nvcr.io/nvidia/nemo" && \
    ok "NeMo 镜像已存在" || {
    warn "NeMo 未下载，后台下载中..."
    nohup docker pull nvcr.io/nvidia/nemo:24.07 > ~/nemo_download.log 2>&1 &
    echo "  下载日志: tail -f ~/nemo_download.log"
}
ask "Step 5 完成"

step 6 "LLaMA-Factory 微调界面"
[ -d "$HOME/LLaMA-Factory" ] && ok "LLaMA-Factory 已安装" || \
    warn "未安装，运行: bash scripts/06_install_llamafactory.sh"
ask "Step 6 完成"

step 7 "测试 Windows Ollama 连接 (192.168.1.2)"
curl -sf "http://${WINDOWS_IP}:11434/api/tags" > /dev/null && \
    ok "Windows Ollama 连接正常" || \
    warn "Windows Ollama 未响应，请先在 Windows 启动 Ollama"
ask "Step 7 完成"

step 8 "完成"
bash "$ROOT/scripts/03_check_health.sh"
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║              服务访问地址                       ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  ChromaDB:      http://localhost:8001           ║"
echo "║  MCP Server:    http://localhost:9000           ║"
echo "║  vLLM API:      http://localhost:8000/v1        ║"
echo "║  LLaMA-Factory: http://localhost:7860           ║"
echo "║  Windows Ollama:http://192.168.1.2:11434        ║"
echo "╚══════════════════════════════════════════════════╝"
