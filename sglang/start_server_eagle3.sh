#!/bin/bash
# SGLang + EAGLE3 投机解码启动脚本
# 提供约 30% 的性能提升

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# 配置参数
MODEL="${MODEL:-Qwen/Qwen3-VL-8B-Instruct}"
MODEL_PATH="${MODEL_PATH:-/opt/dlami/nvme/models/Qwen3-VL-8B-Instruct}"
DRAFT_MODEL_PATH="${DRAFT_MODEL_PATH:-/opt/dlami/nvme/models/Qwen3-VL-8B-Instruct-Eagle3}"
PORT=${PORT:-8000}
HOST="${HOST:-0.0.0.0}"
MEM_FRACTION_STATIC="${MEM_FRACTION_STATIC:-0.8}"

# EAGLE3 参数
SPECULATIVE_NUM_STEPS="${SPECULATIVE_NUM_STEPS:-3}"
SPECULATIVE_EAGLE_TOPK="${SPECULATIVE_EAGLE_TOPK:-6}"
SPECULATIVE_NUM_DRAFT_TOKENS="${SPECULATIVE_NUM_DRAFT_TOKENS:-16}"

# API Key (可选)
API_KEY="${API_KEY:-}"

# 虚拟环境路径
VENV_PATH="${VENV_PATH:-$PARENT_DIR/.venv-sglang}"

# 检查虚拟环境
if [ ! -d "$VENV_PATH" ]; then
    echo "Error: Virtual environment not found at $VENV_PATH"
    echo "Please run deploy.sh first or set VENV_PATH"
    exit 1
fi

# 检查主模型
if [ ! -d "$MODEL_PATH" ]; then
    echo "Warning: Model not found at $MODEL_PATH"
    echo "Will download from HuggingFace: $MODEL"
    MODEL_PATH="$MODEL"
fi

# 检查 Draft 模型
if [ ! -d "$DRAFT_MODEL_PATH" ]; then
    echo "Error: EAGLE3 Draft model not found at $DRAFT_MODEL_PATH"
    echo ""
    echo "Please download it first:"
    echo "  huggingface-cli download taobao-mnn/Qwen3-VL-8B-Instruct-Eagle3 \\"
    echo "      --local-dir $DRAFT_MODEL_PATH"
    echo ""
    echo "Or set DRAFT_MODEL_PATH environment variable"
    exit 1
fi

# 激活虚拟环境
source "$VENV_PATH/bin/activate"

echo "=============================================="
echo "  SGLang + EAGLE3 Server"
echo "=============================================="
echo "Model: $MODEL_PATH"
echo "Draft Model: $DRAFT_MODEL_PATH"
echo "Host: $HOST"
echo "Port: $PORT"
echo "Memory Fraction: $MEM_FRACTION_STATIC"
echo ""
echo "EAGLE3 Parameters:"
echo "  - Num Steps: $SPECULATIVE_NUM_STEPS"
echo "  - Top-K: $SPECULATIVE_EAGLE_TOPK"
echo "  - Draft Tokens: $SPECULATIVE_NUM_DRAFT_TOKENS"
echo "=============================================="

# 构建启动命令
CMD="python -m sglang.launch_server \
    --model-path $MODEL_PATH \
    --host $HOST \
    --port $PORT \
    --mem-fraction-static $MEM_FRACTION_STATIC \
    --trust-remote-code \
    --speculative-algorithm EAGLE3 \
    --speculative-draft-model-path $DRAFT_MODEL_PATH \
    --speculative-num-steps $SPECULATIVE_NUM_STEPS \
    --speculative-eagle-topk $SPECULATIVE_EAGLE_TOPK \
    --speculative-num-draft-tokens $SPECULATIVE_NUM_DRAFT_TOKENS"

# 添加 API Key (如果设置)
if [ -n "$API_KEY" ]; then
    CMD="$CMD --api-key $API_KEY"
    echo "API Key: Enabled"
fi

echo ""
echo "Starting server..."
echo ""

# 启动服务
exec $CMD
