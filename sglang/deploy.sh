#!/bin/bash
set -e

echo "========================================"
echo "Qwen3-VL on AWS - SGLang 部署脚本"
echo "========================================"

# 检查是否在 GPU 实例上
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ 错误: 未检测到 NVIDIA GPU"
    echo "请在 GPU 实例上运行此脚本（如 G5, G6e, P3, P4 系列）"
    exit 1
fi

echo "✅ 检测到 GPU:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

# 检查 Python 版本
if ! command -v python3.10 &> /dev/null; then
    echo "⚠️  未找到 Python 3.10，尝试安装..."
    sudo apt-get update
    sudo apt-get install -y python3.10 python3.10-venv python3.10-dev
fi

echo "✅ Python 版本: $(python3.10 --version)"

# 确保 uv 在 PATH 中（先设置路径）
export PATH="$HOME/.local/bin:/root/.local/bin:$PATH"

# 安装 uv（如果未安装）
if ! command -v uv &> /dev/null; then
    echo "📦 安装 uv 包管理器..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:/root/.local/bin:$PATH"
fi

echo "✅ uv 版本: $(uv --version)"

# 创建虚拟环境
VENV_DIR=".venv-sglang"
if [ ! -d "$VENV_DIR" ]; then
    echo "🔧 创建 Python 虚拟环境: $VENV_DIR"
    uv venv --python 3.10 --seed $VENV_DIR
else
    echo "✅ 虚拟环境已存在: $VENV_DIR"
fi

# 激活虚拟环境
echo "🔧 激活虚拟环境..."
source $VENV_DIR/bin/activate

# 设置缓存目录到 NVMe（如果可用）
NVME_PATH="/opt/dlami/nvme"
if [ -d "$NVME_PATH" ]; then
    echo "💾 使用 NVMe 作为缓存目录"
    export UV_CACHE_DIR="$NVME_PATH/uv_cache"
    export HF_HOME="$NVME_PATH/huggingface"
    mkdir -p "$UV_CACHE_DIR" "$HF_HOME"
fi

# 安装 SGLang
echo "📦 安装 SGLang（这可能需要几分钟）..."
echo "安装依赖: flashinfer, sglang[all]"
echo "缓存目录: $UV_CACHE_DIR"
uv pip install "sglang[all]" --find-links https://flashinfer.ai/whl/cu124/torch2.4/flashinfer/

# 验证安装
echo "🔍 验证安装..."
python -c "
import torch
try:
    import sglang
    print(f'✅ SGLang 安装成功')
except ImportError as e:
    print(f'❌ SGLang 导入失败: {e}')
    exit(1)

print(f'PyTorch 版本: {torch.__version__}')
print(f'CUDA 可用: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA 版本: {torch.version.cuda}')
    print(f'GPU 数量: {torch.cuda.device_count()}')
"

echo ""
echo "========================================"
echo "✅ SGLang 部署完成！"
echo "========================================"
echo ""
echo "启动 SGLang 服务："
echo "  source $VENV_DIR/bin/activate"
echo "  python -m sglang.launch_server --model-path Qwen/Qwen3-VL-8B-Instruct --port 8000"
echo ""
echo "或使用启动脚本："
echo "  bash start_sglang.sh"
echo ""
