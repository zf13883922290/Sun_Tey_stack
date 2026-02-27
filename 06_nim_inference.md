# ⚡ NIM 推理部署指南

## 什么是 NIM

NVIDIA NIM 是一个容器化推理微服务。你不需要写任何推理代码——
下载容器、启动、API 直接可用。

**NIM 自动做的事**:
- TensorRT-LLM 推理优化（比普通 PyTorch 快 3-10x）
- 自动 GPU 内存管理
- OpenAI 兼容 API（Cline 直接对接）
- 安全更新和企业支持

---

## 支持的模型列表

访问 NGC Catalog 查看所有可用 NIM：
https://catalog.ngc.nvidia.com/orgs/nim/collections/microservices

常用模型：

```bash
# 查看所有可用 NIM
ngc registry image list --format_type json nvcr.io/nim/*

# 推荐起步模型（8B，单 GPU 可运行）
nvcr.io/nim/meta/llama-3.1-8b-instruct:latest

# 代码模型
nvcr.io/nim/meta/codellama-13b-instruct:latest

# 大模型（需要多 GPU 或高显存）
nvcr.io/nim/meta/llama-3.1-70b-instruct:latest
```

---

## NIM API 使用

NIM 完全兼容 OpenAI API 格式：

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed",   # 本地不需要
)

response = client.chat.completions.create(
    model="meta/llama-3.1-8b-instruct",
    messages=[
        {"role": "user", "content": "你好"}
    ],
    max_tokens=512,
)
print(response.choices[0].message.content)
```

```bash
# curl 测试
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta/llama-3.1-8b-instruct",
    "messages": [{"role": "user", "content": "你好"}],
    "max_tokens": 100
  }'
```

---

## 性能调优

```yaml
# NIM 环境变量调优
NIM_MAX_MODEL_LEN: 8192        # 最大上下文长度
NIM_TENSOR_PARALLEL_SIZE: 1    # GPU 数量（单卡=1）
NIM_GPU_MEMORY_UTILIZATION: 0.85  # GPU 显存使用率
```

---

## 部署你自己微调的模型

```bash
# 1. 从 NeMo Customizer 导出 LoRA 权重
# 通过 UI 操作或 API：
curl -X POST http://localhost:8080/v1/models/export \
  -d '{"model_id": "sun_tey_v1", "format": "nim"}'

# 2. 将权重挂载到 NIM 容器
docker run --gpus '"device=GPU-<UUID>"' \
  -v /path/to/sun_tey_v1:/opt/nim/.cache/nim/sun_tey_v1 \
  -p 8000:8000 \
  -e NGC_API_KEY=$NGC_API_KEY \
  nvcr.io/nim/meta/llama-3.1-8b-instruct:latest
```
