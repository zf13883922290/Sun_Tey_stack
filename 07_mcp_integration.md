# 🔌 MCP 集成指南

## NeMo Agent Toolkit as MCP Server

NeMo Agent Toolkit 原生支持 MCP 协议。
你不需要自己写 MCP Server——用 NeMo 的封装即可。

**官方文档**: https://docs.nvidia.com/nemo/agent-toolkit/mcp/

---

## 为什么用 NeMo Agent Toolkit 做 MCP Server

- ✅ NVIDIA 官方维护，稳定
- ✅ 原生 MCP 协议支持
- ✅ 内置工具追踪和 observability
- ✅ 自动把工具调用结果注入模型上下文
- ✅ 支持与 Cline / Claude Desktop 直接对接

---

## 配置 NeMo Agent Toolkit MCP Server

```python
# nemo_mcp_server.py
# NeMo Agent Toolkit 官方 MCP Server 写法

from nemo_agent_toolkit import AgentToolkit
from nemo_agent_toolkit.mcp import MCPServer
import chromadb

toolkit = AgentToolkit()
mcp = MCPServer(toolkit)

# 注册工具 - 自动通过 MCP 协议暴露
@mcp.tool(name="query_memory", description="查询长期记忆")
def query_memory(query: str) -> str:
    client = chromadb.HttpClient(host="chromadb", port=8000)
    coll   = client.get_or_create_collection("sun_tey_memory")
    result = coll.query(query_texts=[query], n_results=5)
    return "\n".join(result["documents"][0])

@mcp.tool(name="search_knowledge", description="搜索知识库")
def search_knowledge(query: str) -> str:
    # NeMo Retriever 集成
    ...

@mcp.tool(name="get_gpu_status", description="获取GPU状态")  
def get_gpu_status() -> str:
    import torch
    return f"GPU: {torch.cuda.get_device_name(0)}, 可用: {torch.cuda.is_available()}"

# 启动 MCP Server
mcp.start(host="0.0.0.0", port=9000)
```

---

## Cline 连接 MCP Server

在 VSCode 的 Cline 扩展设置中添加 MCP Server：

```json
// .vscode/settings.json 或 Cline 配置
{
  "cline.mcpServers": {
    "sun_tey_tools": {
      "url": "http://localhost:9000",
      "transport": "sse"
    }
  }
}
```

---

## MCP 工具强制前置执行

NeMo Agent Toolkit 保证：工具在模型推理之前执行。
这意味着：

```
用户输入
   ↓
NeMo Agent Toolkit 自动执行：
   - query_memory("用户输入内容")     ← MCP 工具
   - search_knowledge("用户输入内容") ← MCP 工具
   ↓
把结果注入上下文
   ↓
NIM 模型推理（已有完整上下文）
   ↓
结果返回用户
```

模型没有选择是否调用工具的权利。架构保证了这一点。

---

## 与 NeMo Retriever 集成（RAG）

```python
# NeMo Retriever 作为 RAG 后端
from nemo_agent_toolkit.retrievers import NeMoRetriever

retriever = NeMoRetriever(
    embedding_model="nvidia/nv-embedqa-e5-v5",
    reranker_model="nvidia/nv-rerankqa-mistral-4b-v3",
    vector_db="chromadb",
    vector_db_url="http://chromadb:8000",
)

@mcp.tool(name="rag_search")
def rag_search(query: str) -> str:
    results = retriever.retrieve(query, top_k=5)
    return "\n".join([r.text for r in results])
```
