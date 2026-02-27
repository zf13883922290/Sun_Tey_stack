# 🐳 GPU 容器配置详解

## 双 GPU UUID 隔离方案

NVIDIA Container Toolkit 提供三种指定 GPU 的方式：

```bash
# 方式 1：按 UUID（最稳定，推荐）
docker run --gpus '"device=GPU-ad2367dd-a40e-6b86-6fc3-c44a2cc92c7e"' ...

# 方式 2：按索引
docker run --gpus '"device=0"' ...

# 方式 3：环境变量
docker run -e NVIDIA_VISIBLE_DEVICES=GPU-<UUID> ...
```

**推荐使用 UUID**，因为 GPU 索引可能因重启而改变，UUID 永远固定。

## 查询你的 GPU UUID

```bash
# 方法 1：查询所有 GPU
nvidia-smi --query-gpu=index,name,uuid --format=csv

# 方法 2：查询特定索引的 GPU
nvidia-smi -i 0 --query-gpu=uuid --format=csv,noheader
nvidia-smi -i 1 --query-gpu=uuid --format=csv,noheader

# 方法 3：在 Docker 容器内验证
docker run --gpus '"device=0,1"' --rm nvidia/cuda:12.1.0-base-ubuntu22.04 \
    nvidia-smi --query-gpu=uuid --format=csv
```

## GPU 0 容器（推理）详细配置

```yaml
# containers/gpu0/docker-compose.yml

services:
  nim:
    image: nvcr.io/nim/meta/llama-3.1-8b-instruct:latest
    environment:
      - NVIDIA_VISIBLE_DEVICES=${GPU_UUID_0}
      - NGC_API_KEY=${NGC_API_KEY}
    # NIM 自动使用 TensorRT-LLM 优化推理
    # 不需要手写任何推理代码

  nemo_agent_mcp:
    image: nvcr.io/nvidia/nemo:24.07
    environment:
      - NVIDIA_VISIBLE_DEVICES=${GPU_UUID_0}
    # NeMo Agent Toolkit as MCP Server
    # 工具在模型之前强制执行
    
  chromadb:
    image: chromadb/chroma:latest
    # 向量记忆数据库，无需 GPU
```

## GPU 1 容器（训练）详细配置

```yaml
# containers/gpu1/docker-compose.yml

services:
  nemo_customizer:
    image: nvcr.io/nvidia/nemo-microservices/customizer:latest
    environment:
      - NVIDIA_VISIBLE_DEVICES=${GPU_UUID_1}
    # 微调 UI，带训练进度监控
    
  nemo_data_designer:
    image: nvcr.io/nvidia/nemo-microservices/data-designer:latest
    # 数据集构建，合成数据生成
    
  nemo_evaluator:
    image: nvcr.io/nvidia/nemo-microservices/evaluator:latest
    environment:
      - NVIDIA_VISIBLE_DEVICES=${GPU_UUID_1}
    # 评估模型质量
```

## 容器隔离验证

```bash
# 验证 GPU 0 容器只看到 GPU 0
docker exec <gpu0_container> nvidia-smi

# 验证 GPU 1 容器只看到 GPU 1
docker exec <gpu1_container> nvidia-smi

# 两个容器应该分别只显示各自绑定的 GPU
```
