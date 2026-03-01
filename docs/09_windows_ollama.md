# Windows 11 Ollama 安装配置

## 安装
下载: https://ollama.com/download/windows

## 拉取模型
```
ollama pull llama3.1:8b
```

## 允许局域网访问（必须）
系统环境变量新增:
- 变量名: OLLAMA_HOST
- 变量值: 0.0.0.0:11434

重启 Ollama 服务。

## 防火墙放行
```powershell
netsh advfirewall firewall add rule name="Ollama" dir=in action=allow protocol=TCP localport=11434
```

## Ubuntu 测试连接
```bash
curl http://192.168.1.2:11434/api/tags
```

## VSCode Cline 配置
```json
{
  "cline.apiProvider": "openai",
  "cline.openAiBaseUrl": "http://192.168.1.2:11434/v1",
  "cline.openAiApiKey": "ollama",
  "cline.openAiModelId": "llama3.1:8b"
}
```
