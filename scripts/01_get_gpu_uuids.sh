#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# scripts/01_get_gpu_uuids.sh
#
# 查询所有 GPU 的 UUID，并自动写入 .env 文件
# 用法: bash scripts/01_get_gpu_uuids.sh
# ══════════════════════════════════════════════════════════════════

set -e

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║         Sun_Tey Stack — GPU UUID 配置           ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── 检查 NVIDIA 驱动 ───────────────────────────────────────────────────────
if ! command -v nvidia-smi &>/dev/null; then
    echo "❌ nvidia-smi 未找到，请先安装 NVIDIA 驱动"
    exit 1
fi

# ── 显示所有 GPU ───────────────────────────────────────────────────────────
echo "检测到以下 GPU："
echo ""
nvidia-smi --query-gpu=index,name,memory.total,uuid \
    --format=csv,noheader | while IFS=',' read -r idx name mem uuid; do
    echo "  GPU ${idx}: ${name} (${mem})"
    echo "  UUID: ${uuid}"
    echo ""
done

# ── 获取 GPU 数量 ──────────────────────────────────────────────────────────
GPU_COUNT=$(nvidia-smi --query-gpu=uuid --format=csv,noheader | wc -l)

if [ "$GPU_COUNT" -lt 2 ]; then
    echo "⚠️  警告：检测到 ${GPU_COUNT} 个 GPU，推荐 2 个 GPU"
    echo "   单 GPU 模式：推理和训练共用同一 GPU"
fi

# ── 读取 UUID ──────────────────────────────────────────────────────────────
GPU_UUID_0=$(nvidia-smi -i 0 --query-gpu=uuid --format=csv,noheader | tr -d ' ')
GPU_UUID_1=$(nvidia-smi -i $((GPU_COUNT > 1 ? 1 : 0)) --query-gpu=uuid --format=csv,noheader | tr -d ' ')

echo "GPU 0 UUID: ${GPU_UUID_0}"
echo "GPU 1 UUID: ${GPU_UUID_1}"
echo ""

# ── 写入 .env ──────────────────────────────────────────────────────────────
ENV_FILE="$(dirname "$0")/../.env"

if [ ! -f "$ENV_FILE" ]; then
    cp "$(dirname "$0")/../.env.example" "$ENV_FILE"
fi

# 替换 UUID 值
sed -i "s|GPU_UUID_0=.*|GPU_UUID_0=${GPU_UUID_0}|" "$ENV_FILE"
sed -i "s|GPU_UUID_1=.*|GPU_UUID_1=${GPU_UUID_1}|" "$ENV_FILE"

echo "✅ GPU UUID 已写入 .env"
echo ""
echo "下一步："
echo "  1. 编辑 .env 填入 NGC_API_KEY"
echo "  2. 运行: bash scripts/02_deploy.sh"
echo ""

# ── 验证绑定 ───────────────────────────────────────────────────────────────
echo "验证 GPU 0 绑定..."
docker run --rm --gpus "\"device=${GPU_UUID_0}\"" \
    nvidia/cuda:12.1.0-base-ubuntu22.04 \
    nvidia-smi --query-gpu=name --format=csv,noheader && \
    echo "✅ GPU 0 绑定正常" || echo "❌ GPU 0 绑定失败"

if [ "$GPU_COUNT" -ge 2 ]; then
    echo "验证 GPU 1 绑定..."
    docker run --rm --gpus "\"device=${GPU_UUID_1}\"" \
        nvidia/cuda:12.1.0-base-ubuntu22.04 \
        nvidia-smi --query-gpu=name --format=csv,noheader && \
        echo "✅ GPU 1 绑定正常" || echo "❌ GPU 1 绑定失败"
fi
