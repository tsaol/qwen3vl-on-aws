#!/bin/bash
set -e

echo "========================================"
echo "Qwen3-VL on AWS - 自动部署脚本"
echo "========================================"

# 检查是否在 GPU 实例上
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ 错误: 未检测到 NVIDIA GPU"
    echo "请在 GPU 实例上运行此脚本（如 G5, P3, P4 系列）"
    exit 1
fi

echo "✅ 检测到 GPU:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

# 检查 Python 版本
if ! command -v python3.10 &> /dev/null; then
    echo "⚠️  未找到 Python 3.10，尝试安装..."
    sudo apt-get update
    sudo apt-get install -y python3.10 python3.10-venv
fi

echo "✅ Python 版本: $(python3.10 --version)"

# 安装 uv（如果未安装）
if ! command -v uv &> /dev/null; then
    echo "📦 安装 uv 包管理器..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "✅ uv 版本: $(uv --version)"

# 创建虚拟环境
echo "🔧 创建 Python 虚拟环境..."
uv venv --python 3.10 --seed

# 激活虚拟环境
echo "🔧 激活虚拟环境..."
source .venv/bin/activate

# 安装 vLLM
echo "📦 安装 vLLM（这可能需要几分钟）..."
uv pip install vllm --torch-backend=auto

# 验证安装
echo "🔍 验证安装..."
python -c "import vllm; import torch; print(f'vLLM 版本: {vllm.__version__}'); print(f'PyTorch 版本: {torch.__version__}'); print(f'CUDA 可用: {torch.cuda.is_available()}')"

echo ""
echo "========================================"
echo "✅ 部署完成！"
echo "========================================"
echo ""
echo "启动 vLLM 服务："
echo "  source .venv/bin/activate"
echo "  vllm serve Qwen/Qwen3-VL-8B-Instruct --port 8000 --max-model-len 1024 --gpu-memory-utilization 0.95"
echo ""
echo "或使用启动脚本："
echo "  bash start_server.sh"
echo ""
