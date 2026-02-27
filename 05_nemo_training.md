# 🎯 NeMo 训练与微调指南

## NeMo 微调系统组成

```
NeMo Data Designer    →    NeMo Customizer    →    NeMo Evaluator
（构建数据集）              （执行微调）              （评估质量）
    ↓                           ↓                       ↓
数据集仓库                  微调后模型                评测报告
（HuggingFace）            （导出→NIM）              （自动反馈）
```

---

## 1. NeMo Data Designer — 构建训练数据

**访问**: http://localhost:8081

### 功能

- **合成数据生成**: 用现有 LLM 自动生成高质量训练样本
- **数据集预览**: 实时查看数据质量，快速迭代
- **内置评估**: 生成前自动评估数据多样性和覆盖率
- **HuggingFace 集成**: 直接从 HF Hub 导入公开数据集

### 数据格式（JSONL）

```jsonl
{"messages": [{"role": "system", "content": "你是Sun_Tey"}, {"role": "user", "content": "你是谁？"}, {"role": "assistant", "content": "我是Sun_Tey，本地AI助手。"}]}
{"messages": [{"role": "user", "content": "帮我写代码"}, {"role": "assistant", "content": "好的，请告诉我需求。"}]}
```

### 数据类型建议

| 微调类型 | 数据格式 | 建议数量 |
|---------|---------|---------|
| 语言/对话 | JSONL 多轮对话 | 500-2000 条 |
| 代码生成 | instruction + code 对 | 300-1000 条 |
| 翻译 | source + target 对 | 1000+ 条 |
| ASR/TTS | 音频 + 文本 | 专用格式 |

---

## 2. NeMo Customizer — 执行微调

**访问**: http://localhost:8080

### 支持的微调方法

| 方法 | 显存需求 | 适用场景 |
|------|---------|---------|
| LoRA | 低（推荐） | 个性化、风格 |
| QLoRA | 极低 | 显存不足时 |
| P-Tuning | 低 | 提示微调 |
| Full Fine-tune | 高 | 深度领域适应 |

### 微调配置（通过 UI 设置）

```yaml
# configs/nemo_customizer.yaml
# 这个文件可以通过 NeMo Customizer API 提交

model: meta/llama-3.1-8b-instruct  # 基础模型（从 NIM 选）
method: lora                         # 微调方法
lora_rank: 64
lora_alpha: 128
learning_rate: 2e-4
num_epochs: 3
batch_size: 4
output_model_name: sun_tey_v1
```

### 专项微调路径

**语言/对话模型**:
```
基础模型（LLaMA/Mistral）
    ↓ NeMo Customizer
    ↓ 对话数据集
    → 微调后模型 → 导出 → NIM 部署
```

**代码模型**:
```
基础模型（CodeLLaMA/StarCoder）
    ↓ NeMo Customizer
    ↓ 代码数据集（HF Hub: bigcode/the-stack）
    → 代码专用模型 → 导出 → NIM 部署
```

**语音识别(ASR)**:
```
NeMo Speech（专用模块）
    ↓ 音频数据（WAV + 文本标注）
    → 微调 Parakeet/Canary 模型
    → 部署到 NVIDIA Riva
```

**翻译模型**:
```
NeMo Customizer
    ↓ 平行语料（中英对照）
    → 翻译专用模型 → NIM 部署
```

---

## 3. NeMo Evaluator — 评估模型

**访问**: http://localhost:8082

### 评估方式

```bash
# API 提交评估任务
curl -X POST http://localhost:8082/v1/evaluations \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sun_tey_v1",
    "benchmarks": ["mmlu", "humaneval", "custom"],
    "judge_model": "meta/llama-3.1-70b-instruct"
  }'
```

---

## 4. NeMo Curator — 数据清洗

```bash
# GPU 加速清洗你的训练数据
python -m nemo_curator.scripts.semdedup \
    --input-data-dir ./raw_data \
    --output-dir ./cleaned_data \
    --cache-dir ./cache \
    --num-gpus 1
```

功能：去重、质量过滤、语言识别、有害内容过滤。

---

## 5. 微调后模型部署到 NIM

```bash
# 1. 从 NeMo Customizer 导出模型
# （通过 UI 或 API 触发导出）

# 2. 将模型放入 NIM 容器可访问路径
cp -r ./exported_model /opt/nim/models/sun_tey_v1/

# 3. 重启 NIM 加载新模型
docker restart nim_container

# 4. 验证新模型
curl http://localhost:8000/v1/models
```

---

## 数据集资源（NVIDIA + 社区）

| 来源 | 地址 | 类型 |
|------|------|------|
| NVIDIA NGC | https://catalog.ngc.nvidia.com/datasets | 官方数据集 |
| HuggingFace Hub | https://huggingface.co/datasets | 社区数据集 |
| NeMo Data Designer | 内置合成生成 | 自定义合成 |
| OpenHermes | HF: teknium/OpenHermes-2.5 | 对话指令 |
| The Stack | HF: bigcode/the-stack | 代码数据 |
