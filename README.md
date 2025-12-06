# Qwen3-VL 在 AWS 上的部署指南

这个仓库包含在 AWS 上部署 Qwen3-VL-8B-Instruct 模型的脚本和文档。

## 环境要求

- AWS EC2 实例（推荐 G5 或 P 系列 GPU 实例）
- Python 3.10+
- NVIDIA GPU（支持 CUDA）
- Ubuntu 22.04 或更高版本

## 推荐的 AWS 实例类型

| 实例类型 | GPU | 显存 | 适用场景 |
|---------|-----|------|---------|
| g5.xlarge | 1x A10G | 24GB | 小规模测试 |
| g5.2xlarge | 1x A10G | 24GB | 开发环境 |
| p3.2xlarge | 1x V100 | 16GB | 训练/推理 |
| p4d.24xlarge | 8x A100 | 320GB | 大规模生产 |

## 快速开始

### 方式 1：一键部署（推荐）⭐

使用自动化脚本快速部署：

```bash
# 1. 克隆仓库
git clone https://github.com/tsaol/qwen3vl-on-aws.git
cd qwen3vl-on-aws

# 2. 运行部署脚本（安装依赖和环境）
bash deploy.sh

# 3. 启动服务
bash start_server.sh
```

**就这么简单！** 🎉 服务将在 `http://localhost:8000` 启动。

---

### 方式 2：手动安装（高级用户）

如果你想了解详细步骤或自定义配置：

#### 1. 安装依赖

使用 `uv` 工具（超快的 Python 包管理器）：

```bash
# 安装 uv (如果还没安装)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 更新 PATH（让 shell 能找到 uv）
source $HOME/.local/bin/env

# 创建虚拟环境 (Python 3.10+)
uv venv --python 3.10 --seed

# 激活虚拟环境
source .venv/bin/activate

# 安装 vLLM（自动检测 GPU 后端）
uv pip install vllm --torch-backend=auto
```

#### 2. 启动 vLLM 服务

```bash
# 基础启动命令
vllm serve Qwen/Qwen3-VL-8B-Instruct \
  --port 8000 \
  --max-model-len 1024 \
  --gpu-memory-utilization 0.95
```

**参数说明：**
- `--port 8000` - API 服务端口
- `--max-model-len 1024` - 最大序列长度（输入+输出 token 总数）
- `--gpu-memory-utilization 0.95` - 使用 95% 的 GPU 显存

---

### 测试 API

服务启动后，可以通过 OpenAI 兼容的 API 调用：

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [
      {"role": "user", "content": "你好，请介绍一下你自己"}
    ]
  }'
```

## 客户端调用示例

我们提供了多种编程语言的客户端示例，详见 [client_examples.md](client_examples.md)

### 快速开始 - Python 客户端

```python
# 使用提供的示例脚本
python3 examples/python_client.py

# 或者使用 OpenAI SDK
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="EMPTY"
)

response = client.chat.completions.create(
    model="Qwen/Qwen3-VL-8B-Instruct",
    messages=[{"role": "user", "content": "你好"}]
)

print(response.choices[0].message.content)
```

### 支持的客户端

- ✅ **cURL** - 命令行测试
- ✅ **Python** (requests / OpenAI SDK) - [查看示例](examples/)
- ✅ **JavaScript/Node.js** (fetch / OpenAI SDK)
- ✅ **Go** - HTTP 客户端
- ✅ 任何支持 OpenAI API 的客户端库

## ⚠️ 高可用部署

**重要提示**：当前的基础部署**不是高可用**，存在以下风险：
- ❌ 单点故障 - 进程崩溃导致服务中断
- ❌ 无自动重启 - 需要人工干预
- ❌ SSH 断开风险 - 可能导致进程终止

### 推荐：安装 systemd 服务

实现自动重启、开机自启、故障恢复：

```bash
# 安装高可用服务
sudo bash install_service.sh

# 查看服务状态
sudo systemctl status qwen3vl

# 查看实时日志
sudo journalctl -u qwen3vl -f
```

**完整高可用部署方案**请参考：[HIGH_AVAILABILITY.md](HIGH_AVAILABILITY.md)

## 加载私有模型

### 方法 1：使用本地模型路径（推荐）

如果模型已下载到本地：

```bash
# 直接指定本地路径
MODEL=/path/to/your/private/model bash start_server.sh
```

或修改 start_server.sh 中的 MODEL 变量：
```bash
MODEL="/data/models/my-private-qwen3vl"
```

### 方法 2：使用 HuggingFace Token（私有仓库）

如果模型在 HuggingFace 私有仓库：

```bash
# 设置 HuggingFace Token
export HF_TOKEN="hf_xxxxxxxxxxxxxxxxxxxxx"

# 启动服务
MODEL=your-org/private-model bash start_server.sh
```

或使用 huggingface-cli 一次性登录：
```bash
pip install huggingface-hub
huggingface-cli login
```

### 方法 3：从 S3/云存储加载

```bash
# 1. 下载模型到本地
aws s3 sync s3://your-bucket/models/qwen3vl /data/models/qwen3vl

# 2. 使用本地路径启动
MODEL=/data/models/qwen3vl bash start_server.sh
```

### 方法 4：使用配置文件

创建 `model_config.env` 文件：

```bash
# model_config.env
MODEL_PATH="/data/models/my-private-model"
HF_TOKEN="hf_xxxxx"  # 如果需要
PORT=8000
MAX_MODEL_LEN=1024
GPU_MEMORY_UTIL=0.95
```

修改 start_server.sh 加载配置文件：
```bash
# 在脚本开头添加
if [ -f "model_config.env" ]; then
    source model_config.env
fi
```

**安全提醒**：
- 不要把 Token 提交到 Git 仓库
- 将 `model_config.env` 添加到 `.gitignore`
- 生产环境建议使用 AWS Secrets Manager

## 性能优化建议

### 调整显存使用
```bash
# 如果遇到 OOM (Out of Memory)，降低显存利用率
--gpu-memory-utilization 0.8
```

### 增加最大序列长度
```bash
# 处理更长的文本
--max-model-len 4096
```

### 启用张量并行（多 GPU）
```bash
# 在多 GPU 实例上分布模型
--tensor-parallel-size 2  # 使用 2 个 GPU
```

## 故障排查

### 1. CUDA 找不到
```bash
# 检查 CUDA 是否安装
nvidia-smi

# 检查 PyTorch CUDA 支持
python -c "import torch; print(torch.cuda.is_available())"
```

### 2. 显存不足
- 减少 `--gpu-memory-utilization`
- 减少 `--max-model-len`
- 使用更大的 GPU 实例

### 3. 模型下载慢
```bash
# 设置 HuggingFace 镜像
export HF_ENDPOINT=https://hf-mirror.com
```

## 生产环境部署

对于生产环境，建议：
1. 使用 Docker 容器化
2. 配置负载均衡器（ALB/NLB）
3. 设置 Auto Scaling
4. 启用 CloudWatch 监控
5. 配置日志收集

## 相关资源

- [vLLM 官方文档](https://docs.vllm.ai/)
- [Qwen3-VL 模型卡](https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct)
- [AWS GPU 实例定价](https://aws.amazon.com/ec2/instance-types/)

## 许可证

MIT License
