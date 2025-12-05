#!/bin/bash
set -e

echo "========================================"
echo "启动 Qwen3-VL vLLM 服务"
echo "========================================"

# 激活虚拟环境
if [ ! -d ".venv" ]; then
    echo "❌ 错误: 未找到虚拟环境"
    echo "请先运行: bash deploy.sh"
    exit 1
fi

source .venv/bin/activate

# 配置参数
MODEL="Qwen/Qwen3-VL-8B-Instruct"
PORT=${PORT:-8000}
MAX_MODEL_LEN=${MAX_MODEL_LEN:-1024}
GPU_MEMORY_UTIL=${GPU_MEMORY_UTIL:-0.95}

echo "模型: $MODEL"
echo "端口: $PORT"
echo "最大序列长度: $MAX_MODEL_LEN"
echo "GPU 显存利用率: $GPU_MEMORY_UTIL"
echo ""

# 启动服务
echo "🚀 启动 vLLM 服务..."
vllm serve $MODEL \
    --port $PORT \
    --max-model-len $MAX_MODEL_LEN \
    --gpu-memory-utilization $GPU_MEMORY_UTIL
