# 🏗️ NVIDIA 产品详解与选型

## 你的架构用到的全部 NVIDIA 官方软件

---

## 1. NVIDIA NIM — 推理微服务（核心）

**官方地址**: https://docs.nvidia.com/nim/

**作用**: 把任何 LLM 变成标准 REST API 服务，自动 GPU 优化。

```
你不需要写任何推理代码。
NIM 容器启动后直接暴露 OpenAI 兼容 API。
VSCode Cline 直接连这个 API。
```

**支持模型**:
- Meta LLaMA 3.1 / 3.2 / 3.3（8B、70B）
- Mistral / Mixtral
- NVIDIA Nemotron 系列
- 你自己用 NeMo 微调的模型（导出后放入 NIM）

**部署**:
```bash
# 拉取 NIM 容器（需要 NVIDIA NGC 账号）
docker pull nvcr.io/nim/meta/llama-3.1-8b-instruct:latest

# 启动（GPU 0）
docker run --gpus device=GPU-<UUID> \
  -p 8000:8000 \
  -e NGC_API_KEY=$NGC_API_KEY \
  nvcr.io/nim/meta/llama-3.1-8b-instruct:latest
```

---

## 2. NVIDIA NeMo Customizer — 模型微调（带 UI）

**官方地址**: https://docs.nvidia.com/nemo/microservices/latest/nemo-customizer/

**作用**: 用你自己的数据微调语言模型，提供 Web UI 和 REST API。

**特点**:
- ✅ 带 Web 界面，无需写代码
- ✅ 支持 LoRA / Full Fine-tuning
- ✅ 支持语言模型、代码模型
- ✅ 自动管理训练数据集
- ✅ 与 NeMo Data Designer 集成

**支持的专项微调**:
| 类型 | 软件 |
|------|------|
| 语言模型 | NeMo Customizer |
| 代码模型 | NeMo Customizer + 代码数据集 |
| 语音识别(ASR) | NeMo Speech（专用） |
| 语音合成(TTS) | NeMo Speech（专用） |
| 翻译 | NeMo 多语言模型微调 |

---

## 3. NeMo Data Designer — 数据集构建（带 UI）

**官方地址**: https://docs.nvidia.com/nemo/microservices/latest/nemo-data-designer/

**作用**: 构建高质量训练数据集，支持合成数据生成。

**功能**:
- 合成训练数据生成
- 快速数据预览和评估
- 数据集版本管理
- 与 Hugging Face Hub 集成

---

## 4. NeMo Evaluator — 模型评估

**官方地址**: https://docs.nvidia.com/nemo/microservices/latest/nemo-evaluator/

**作用**: 对训练好的模型做基准测试，支持标准评测集和自定义评测。

**功能**:
- MMLU、HumanEval 等标准 benchmark
- LLM-as-judge 自动评分
- 持续监控模型质量
- 与 NeMo Customizer 训练循环集成

---

## 5. NeMo Retriever — RAG 管道

**官方地址**: https://docs.nvidia.com/nemo/microservices/latest/nemo-retriever/

**作用**: 高精度检索增强生成（RAG），这是你的"长期记忆"的正确实现。

**功能**:
- 多模态文档嵌入
- 高性能向量检索
- 与 ChromaDB / Milvus / Weaviate 集成
- 隐私保护数据访问

---

## 6. NeMo Agent Toolkit — MCP Server/Host

**官方地址**: https://docs.nvidia.com/nemo/agent-toolkit/

**作用**: 把你的工具发布为 MCP Server，同时管理 Agent 工作流。

**MCP 支持**:
```python
# NeMo Agent Toolkit 作为 MCP Server
# 发布工具给 Cline / Claude / 任何 MCP Client

from nemo_agent_toolkit import MCPServer, tool

server = MCPServer()

@server.tool
def query_memory(query: str) -> str:
    """查询长期记忆数据库"""
    ...

@server.tool  
def run_gpu_compute(script: str) -> str:
    """在 GPU 上执行计算任务"""
    ...

server.start(host="0.0.0.0", port=9000)
```

---

## 7. NeMo Guardrails — 安全护栏

**官方地址**: https://docs.nvidia.com/nemo/guardrails/

**作用**: 给模型输出加安全策略、主题控制、有害内容过滤。

---

## 8. NeMo Curator — 数据清洗

**官方地址**: https://docs.nvidia.com/nemo/curator/

**作用**: GPU 加速的数据清洗、去重、质量过滤。处理大规模训练语料。

---

## 9. NeMo Speech — 语音专项（ASR / TTS）

**官方地址**: https://docs.nvidia.com/nemo/framework/latest/speech-ai/

**作用**: 语音识别和语音合成的专用训练框架。

---

## 10. NVIDIA Container Toolkit — GPU 容器管理

**官方地址**: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/

**作用**: 让 Docker 容器可以访问宿主机 GPU。双 GPU 隔离的核心。

```bash
# 安装
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

---

## NGC 账号说明

大部分 NVIDIA 软件需要免费的 NGC 账号：
1. 注册：https://ngc.nvidia.com/
2. 获取 API Key：Profile → Setup → Generate API Key
3. 登录：`docker login nvcr.io`（用户名填 `$oauthtoken`，密码填 API Key）
