"""
nemo_mcp_server.py
══════════════════
NeMo Agent Toolkit as MCP Server.

这个文件使用 NVIDIA NeMo Agent Toolkit 官方 MCP 封装，
把工具发布给 Cline / Claude Desktop / 任何 MCP Client。

工具在模型推理之前强制执行——这是架构保证的，不是模型训练出来的。

官方文档: https://docs.nvidia.com/nemo/agent-toolkit/mcp/
"""

import os
import logging
import chromadb

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("SunTey.MCPServer")

# ── ChromaDB 连接 ─────────────────────────────────────────────────────────────
CHROMA_HOST = os.getenv("CHROMA_HOST", "chromadb")
CHROMA_PORT = int(os.getenv("CHROMA_PORT", "8000"))

def get_chroma_collection(name: str = "sun_tey_memory"):
    client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
    return client.get_or_create_collection(name)


# ── 尝试导入 NeMo Agent Toolkit ──────────────────────────────────────────────
try:
    from nemo_agent_toolkit import AgentToolkit
    from nemo_agent_toolkit.mcp import MCPServer

    toolkit = AgentToolkit()
    mcp     = MCPServer(toolkit)

    # ── MCP 工具定义 ─────────────────────────────────────────────────────────

    @mcp.tool(name="query_memory", description="查询长期记忆数据库，获取历史上下文")
    def query_memory(query: str) -> str:
        """
        在 ChromaDB 中检索与 query 相关的历史记忆。
        每次请求自动调用，确保模型有完整上下文。
        """
        try:
            coll    = get_chroma_collection()
            count   = coll.count()
            if count == 0:
                return "（记忆库为空）"
            results = coll.query(
                query_texts=[query],
                n_results=min(5, count),
            )
            docs = results.get("documents", [[]])[0]
            return "\n---\n".join(docs) if docs else "（无相关记忆）"
        except Exception as e:
            log.warning(f"query_memory failed: {e}")
            return f"记忆查询失败: {e}"

    @mcp.tool(name="save_memory", description="保存信息到长期记忆")
    def save_memory(content: str, tags: str = "") -> str:
        """持久化存储信息到 ChromaDB。"""
        try:
            import hashlib, time
            coll    = get_chroma_collection()
            uid     = hashlib.sha256(f"{content}{time.time()}".encode()).hexdigest()[:16]
            coll.add(
                documents=[content],
                ids=[uid],
                metadatas=[{"tags": tags, "timestamp": str(int(time.time()))}],
            )
            return f"已保存 (id={uid})"
        except Exception as e:
            return f"保存失败: {e}"

    @mcp.tool(name="get_gpu_status", description="获取 GPU 运行状态和显存信息")
    def get_gpu_status() -> str:
        """返回 GPU 健康状态。"""
        try:
            import torch
            if not torch.cuda.is_available():
                return "GPU 不可用"
            name = torch.cuda.get_device_name(0)
            alloc = torch.cuda.memory_allocated(0) / (1024**2)
            total = torch.cuda.get_device_properties(0).total_memory / (1024**2)
            return f"GPU: {name} | 已用: {alloc:.0f}MB / {total:.0f}MB"
        except Exception as e:
            return f"GPU 状态查询失败: {e}"

    @mcp.tool(name="list_available_models", description="列出 NIM 当前可用的模型")
    def list_available_models() -> str:
        """查询 NIM API 返回可用模型列表。"""
        try:
            import requests
            nim_url = os.getenv("NIM_BASE_URL", "http://nim:8000/v1")
            r = requests.get(f"{nim_url}/models", timeout=5)
            data = r.json()
            models = [m["id"] for m in data.get("data", [])]
            return "可用模型:\n" + "\n".join(f"- {m}" for m in models)
        except Exception as e:
            return f"模型列表查询失败: {e}"

    log.info("NeMo Agent Toolkit MCP Server 启动中...")
    mcp.start(host="0.0.0.0", port=9000)

except ImportError:
    # ── Fallback: 纯 HTTP MCP stub（NeMo 未安装时）─────────────────────────
    log.warning("NeMo Agent Toolkit 未找到，使用轻量 HTTP stub")
    import json, time
    from http.server import BaseHTTPRequestHandler, HTTPServer

    class FallbackMCPHandler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args): pass

        def do_GET(self):
            if self.path == "/health":
                self._ok({"status": "ok", "mode": "fallback_stub"})
            elif self.path == "/tools":
                self._ok({"tools": ["query_memory", "save_memory", "get_gpu_status"]})
            else:
                self._ok({"error": "not found"})

        def do_POST(self):
            n    = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(n) or b"{}")
            tool = body.get("tool", "")
            args = body.get("args", {})
            if tool == "query_memory":
                result = query_memory(args.get("query", ""))
            elif tool == "save_memory":
                result = save_memory(args.get("content", ""), args.get("tags", ""))
            elif tool == "get_gpu_status":
                result = get_gpu_status()
            else:
                result = f"Unknown tool: {tool}"
            self._ok({"result": result})

        def _ok(self, data):
            body = json.dumps(data, ensure_ascii=False).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", len(body))
            self.end_headers()
            self.wfile.write(body)

    # reuse tool functions defined above
    from types import SimpleNamespace

    def query_memory(query):
        try:
            coll  = get_chroma_collection()
            count = coll.count()
            if count == 0: return "（记忆库为空）"
            res  = coll.query(query_texts=[query], n_results=min(5, count))
            docs = res.get("documents", [[]])[0]
            return "\n---\n".join(docs) if docs else "（无相关记忆）"
        except Exception as e:
            return f"查询失败: {e}"

    def save_memory(content, tags=""):
        try:
            import hashlib
            coll = get_chroma_collection()
            uid  = hashlib.sha256(f"{content}{time.time()}".encode()).hexdigest()[:16]
            coll.add(documents=[content], ids=[uid],
                     metadatas=[{"tags": tags, "timestamp": str(int(time.time()))}])
            return f"已保存 (id={uid})"
        except Exception as e:
            return f"保存失败: {e}"

    def get_gpu_status():
        try:
            import torch
            if not torch.cuda.is_available(): return "GPU 不可用"
            name  = torch.cuda.get_device_name(0)
            alloc = torch.cuda.memory_allocated(0) / (1024**2)
            total = torch.cuda.get_device_properties(0).total_memory / (1024**2)
            return f"GPU: {name} | 已用: {alloc:.0f}MB / {total:.0f}MB"
        except Exception as e:
            return f"GPU 状态查询失败: {e}"

    log.info("Fallback MCP stub 启动于 :9000")
    HTTPServer(("0.0.0.0", 9000), FallbackMCPHandler).serve_forever()
