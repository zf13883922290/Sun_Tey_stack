# 📐 完整架构说明

## 核心设计原则

```
微调 ≠ 控制权
模型 ≠ 执行系统
控制权必须在架构层
```

## 完整数据流

```
用户 / VSCode / Cline
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│              NeMo Agent Toolkit (MCP Server)            │
│                  GPU 0 容器 · port 9000                 │
│                                                         │
│  每次请求强制执行：                                       │
│    1. 查询 ChromaDB 记忆（NeMo Retriever）               │
│    2. MCP 工具预执行                                     │
│    3. 注入上下文 → 发送给 NIM                            │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│              NVIDIA NIM 推理微服务                       │
│                  GPU 0 容器 · port 8000                 │
│                                                         │
│  模型只在这里，只输出 JSON 意图                           │
│  不控制任何其他系统                                       │
└──────────────────────┬──────────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
┌──────────────────┐    ┌──────────────────────────────┐
│  ChromaDB 记忆   │    │   NeMo Customizer (GPU 1)    │
│  (NeMo Retriever)│    │   训练 / 微调 / 数据管理     │
│  port 8001       │    │   port 8080                  │
└──────────────────┘    └──────────────────────────────┘
```

## 双 GPU 容器分工

### GPU 0 容器 — 推理容器（永远在线）

| 服务 | NVIDIA 软件 | 端口 | 作用 |
|------|------------|------|------|
| NIM 推理服务 | NVIDIA NIM | 8000 | 模型推理 API |
| MCP Server | NeMo Agent Toolkit | 9000 | 工具集成 |
| 记忆检索 | NeMo Retriever | - | RAG 管道 |
| 向量数据库 | ChromaDB | 8001 | 长期记忆 |
| 安全护栏 | NeMo Guardrails | - | 策略控制 |

### GPU 1 容器 — 训练容器（按需启动）

| 服务 | NVIDIA 软件 | 端口 | 作用 |
|------|------------|------|------|
| 语言模型微调 | NeMo Customizer | 8080 | 语言/代码模型微调 UI |
| 数据集构建 | NeMo Data Designer | 8081 | 合成数据、数据集管理 |
| 模型评估 | NeMo Evaluator | 8082 | 基准测试、质量监控 |
| 数据清洗 | NeMo Curator | - | GPU 加速数据处理 |
| 语音专项 | NeMo Speech | 8083 | ASR/TTS 专用微调 |

## NVIDIA Container Toolkit 管理层

```bash
# GPU UUID 绑定示意
GPU 0 UUID → GPU 0 容器（推理）
GPU 1 UUID → GPU 1 容器（训练）

# 容器启动示例
docker run --gpus device=GPU-<UUID-0> ...  # 推理容器
docker run --gpus device=GPU-<UUID-1> ...  # 训练容器
```

## NeMo Agent Toolkit as MCP Server

NeMo Agent Toolkit 原生支持 MCP 协议，提供：

- **工具发布**：把任何 Python 函数发布为 MCP 工具
- **上下文注入**：自动把 RAG 结果注入模型上下文
- **工具调用追踪**：完整的 observability 和 profiling
- **多框架兼容**：支持 LangChain、AutoGen 等框架

```yaml
# NeMo Agent Toolkit MCP 配置示意
mcp_server:
  host: 0.0.0.0
  port: 9000
  tools:
    - name: query_memory
      description: 查询长期记忆
    - name: search_knowledge
      description: 检索知识库
    - name: run_gpu_task
      description: 执行 GPU 计算任务
```
