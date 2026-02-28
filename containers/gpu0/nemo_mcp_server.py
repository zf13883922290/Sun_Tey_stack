import os, json, time, hashlib, logging
from http.server import BaseHTTPRequestHandler, HTTPServer
import chromadb

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("SunTey.MCP")

CHROMA_HOST = os.getenv("CHROMA_HOST", "localhost")
CHROMA_PORT = int(os.getenv("CHROMA_PORT", "8001"))

def get_collection():
    client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
    return client.get_or_create_collection("sun_tey_memory")

def save_memory(content, tags=""):
    try:
        coll = get_collection()
        uid  = hashlib.sha256(f"{content}{time.time()}".encode()).hexdigest()[:16]
        coll.add(documents=[content], ids=[uid],
                 metadatas=[{"tags": tags, "timestamp": str(int(time.time()))}])
        return f"已保存 id={uid}"
    except Exception as e:
        return f"保存失败: {e}"

def query_memory(query):
    try:
        coll  = get_collection()
        count = coll.count()
        if count == 0:
            return "记忆库为空"
        res  = coll.query(query_texts=[query], n_results=min(5, count))
        docs = res.get("documents", [[]])[0]
        return "\n---\n".join(docs) if docs else "无相关记忆"
    except Exception as e:
        return f"查询失败: {e}"

def get_gpu_status():
    try:
        import torch
        if not torch.cuda.is_available():
            return "GPU 不可用"
        name  = torch.cuda.get_device_name(0)
        alloc = torch.cuda.memory_allocated(0) / (1024**2)
        total = torch.cuda.get_device_properties(0).total_memory / (1024**2)
        return f"GPU: {name} | 已用: {alloc:.0f}MB / {total:.0f}MB"
    except Exception as e:
        return f"GPU查询失败: {e}"

class MCPHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        log.info(fmt % args)

    def do_GET(self):
        if self.path == "/health":
            self._ok({"status": "ok", "chroma_port": CHROMA_PORT})
        elif self.path == "/tools":
            self._ok({"tools": ["save_memory", "query_memory", "get_gpu_status"]})
        else:
            self._ok({"error": "not found"})

    def do_POST(self):
        n    = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(n) or b"{}")
        tool = body.get("tool", "")
        args = body.get("args", {})
        if tool == "save_memory":
            result = save_memory(args.get("content", ""), args.get("tags", ""))
        elif tool == "query_memory":
            result = query_memory(args.get("query", ""))
        elif tool == "get_gpu_status":
            result = get_gpu_status()
        else:
            result = f"未知工具: {tool}"
        self._ok({"result": result})

    def _ok(self, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

log.info(f"MCP Server 启动 :9000 → ChromaDB {CHROMA_HOST}:{CHROMA_PORT}")
HTTPServer(("0.0.0.0", 9000), MCPHandler).serve_forever()
