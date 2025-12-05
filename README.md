# Qwen3-VL 在 AWS 上的部署指南

这个仓库包含在 AWS 上部署 Qwen3-VL-8B-Instruct 模型的脚本和文档。

## 环境要求

- AWS EC2 实例（推荐 G5 或 P 系列 GPU 实例）
- Python 3.12
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

### 1. 安装依赖

使用 `uv` 工具（超快的 Python 包管理器）：

```bash
# 安装 uv (如果还没安装)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 创建虚拟环境 (Python 3.12)
uv venv --python 3.12 --seed

# 激活虚拟环境
source .venv/bin/activate

# 安装 vLLM（自动检测 GPU 后端）
uv pip install vllm --torch-backend=auto
```

### 2. 启动 vLLM 服务

```bash
# 基础启动命令
vllm serve Qwen/Qwen3-VL-8B-Instruct \
  --port 8000 \
  --max-model-len 1024 \
  --gpu-memory-utilization 0.95
```

#### 参数说明

- `--port 8000` - API 服务端口
- `--max-model-len 1024` - 最大序列长度（输入+输出 token 总数）
- `--gpu-memory-utilization 0.95` - 使用 95% 的 GPU 显存

### 3. 测试 API

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

## 使用部署脚本

我们提供了自动化部署脚本：

```bash
# 一键部署（包含环境设置和服务启动）
bash deploy.sh
```

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
