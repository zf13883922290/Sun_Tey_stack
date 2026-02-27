# 🖥️ VSCode / Cline 接入指南

## 连接方式

```
VSCode + Cline
      │
      ├── NIM API (port 8000)      ← 模型推理
      └── MCP Server (port 9000)   ← 工具调用
```

---

## 安装 Cline

1. 打开 VSCode 扩展市场
2. 搜索 "Cline"
3. 安装 "Cline - Autonomous Coding Agent"

---

## 配置 Cline 连接 NIM

打开 VSCode 设置 (Ctrl+,) → 搜索 Cline：

```json
{
  "cline.apiProvider": "openai",
  "cline.openAiBaseUrl": "http://localhost:8000/v1",
  "cline.openAiApiKey": "not-needed",
  "cline.openAiModelId": "meta/llama-3.1-8b-instruct"
}
```

或直接复制本项目的 `.vscode/settings.json`。

---

## 配置 MCP Server

Cline 支持 MCP Server，添加到配置：

```json
{
  "cline.mcpServers": {
    "sun_tey": {
      "url": "http://localhost:9000",
      "transport": "sse",
      "tools": [
        "query_memory",
        "search_knowledge", 
        "get_gpu_status"
      ]
    }
  }
}
```

---

## 完整 .vscode/settings.json

```json
{
  "cline.apiProvider": "openai",
  "cline.openAiBaseUrl": "http://localhost:8000/v1",
  "cline.openAiApiKey": "not-needed",
  "cline.openAiModelId": "meta/llama-3.1-8b-instruct",
  "cline.mcpServers": {
    "sun_tey_tools": {
      "url": "http://localhost:9000",
      "transport": "sse"
    }
  }
}
```

---

## 验证连接

在 Cline 聊天框输入：
```
你是谁？你有哪些工具可以使用？
```

正常输出应包含：
- 模型身份回复（来自 NIM）
- 可用工具列表（来自 MCP Server）
- 记忆库查询结果（来自 ChromaDB）
