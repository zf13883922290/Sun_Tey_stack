# 🔧 完整安装指南

## 前置条件检查

```bash
# 检查 NVIDIA 驱动
nvidia-smi

# 检查 Docker
docker --version

# 检查 GPU 数量
nvidia-smi --list-gpus
```

---

## Step 1：安装 NVIDIA Container Toolkit

```bash
# 配置 APT 源
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 安装
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# 配置 Docker 使用 NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# 验证
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

---

## Step 2：获取 GPU UUID

```bash
# 查询所有 GPU 的 UUID
nvidia-smi --query-gpu=index,name,uuid --format=csv,noheader

# 输出示例:
# 0, NVIDIA GeForce RTX 4090, GPU-ad2367dd-a40e-6b86-6fc3-c44a2cc92c7e
# 1, NVIDIA GeForce RTX 4090, GPU-16a23983-e73e-0945-2095-cdeb50696982

# 验证特定 GPU 绑定
docker run --gpus '"device=0"' --rm nvidia/cuda:12.1.0-base-ubuntu22.04 \
    nvidia-smi --query-gpu=uuid --format=csv
```

记录两个 UUID，填入 `.env` 文件：

```bash
cp .env.example .env
nano .env  # 填入 GPU_UUID_0 和 GPU_UUID_1
```

---

## Step 3：注册 NGC 账号并配置

```bash
# 1. 访问 https://ngc.nvidia.com/ 注册
# 2. 获取 API Key：Profile → Setup → API Key → Generate

# 3. 配置登录
docker login nvcr.io
# Username: $oauthtoken
# Password: <你的 NGC API Key>

# 4. 把 NGC API Key 填入 .env
```

---

## Step 4：启动 GPU 0 容器（推理容器）

```bash
cd containers/gpu0
docker compose up -d

# 检查状态
docker compose ps
docker compose logs -f nim
```

等待 NIM 初始化（首次启动需下载模型，约 10-30 分钟）：

```bash
# 测试 NIM API
curl http://localhost:8000/v1/models

# 测试推理
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta/llama-3.1-8b-instruct",
    "messages": [{"role": "user", "content": "你好"}]
  }'
```

---

## Step 5：启动 GPU 1 容器（训练容器）

```bash
cd containers/gpu1
docker compose up -d

# 检查状态
docker compose ps
```

访问界面：
- **NeMo Customizer UI**: http://localhost:8080
- **NeMo Data Designer**: http://localhost:8081  
- **NeMo Evaluator**: http://localhost:8082

---

## Step 6：验证完整系统

```bash
# 运行健康检查脚本
bash scripts/03_check_health.sh
```

期望输出：
```
✅ GPU 0 容器: 运行中
✅ GPU 1 容器: 运行中
✅ NIM API: 正常 (port 8000)
✅ MCP Server: 正常 (port 9000)
✅ ChromaDB: 正常 (port 8001)
✅ NeMo Customizer: 正常 (port 8080)
✅ NeMo Data Designer: 正常 (port 8081)
✅ NeMo Evaluator: 正常 (port 8082)
```

---

## Step 7：配置 VSCode / Cline

1. 安装 Cline 扩展
2. 打开 VSCode 设置（Ctrl+,）
3. 搜索 "Cline"
4. 设置：
   - API Provider: `OpenAI Compatible`
   - Base URL: `http://localhost:8000/v1`
   - API Key: `none`（本地不需要）
   - Model: `meta/llama-3.1-8b-instruct`

或直接复制 `.vscode/settings.json` 到你的项目。

---

## 常见问题

### GPU 被两个容器争用？

不会。每个容器通过 UUID 绑定到独立 GPU：

```yaml
# GPU 0 容器
environment:
  - NVIDIA_VISIBLE_DEVICES=GPU-<UUID-0>

# GPU 1 容器  
environment:
  - NVIDIA_VISIBLE_DEVICES=GPU-<UUID-1>
```

### NIM 启动很慢？

正常。首次启动需要：
1. 下载模型权重（数GB）
2. TensorRT-LLM 编译优化（5-15分钟）

之后启动会很快（使用缓存）。

### NeMo Customizer 在哪里上传数据？

访问 http://localhost:8080，界面里直接上传 JSONL 格式训练数据。格式：

```json
{"messages": [{"role": "user", "content": "问题"}, {"role": "assistant", "content": "回答"}]}
```
