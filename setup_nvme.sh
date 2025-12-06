#!/bin/bash
# NVMe 临时存储初始化脚本
# 用于 g6e/g5/p 系列实例启动时自动配置

set -e

NVME_PATH="/opt/dlami/nvme"
HF_CACHE="$NVME_PATH/huggingface"

echo "========================================"
echo "NVMe 临时存储配置"
echo "========================================"

# 检查 NVMe 是否存在
if [ ! -d "$NVME_PATH" ]; then
    echo "❌ 未检测到 NVMe 临时存储"
    echo "此脚本仅适用于带 NVMe 的实例（g6e, g5, p3, p4 等）"
    exit 1
fi

echo "✅ 检测到 NVMe: $NVME_PATH"

# 显示磁盘信息
df -h "$NVME_PATH" | tail -1 | awk '{print "容量: " $2 ", 已用: " $3 ", 可用: " $4}'

# 创建 HuggingFace 缓存目录
if [ ! -d "$HF_CACHE" ]; then
    echo "📁 创建 HuggingFace 缓存目录..."
    sudo mkdir -p "$HF_CACHE"
    sudo chown -R ubuntu:ubuntu "$HF_CACHE"
    echo "✅ 目录创建完成: $HF_CACHE"
else
    echo "✅ 缓存目录已存在: $HF_CACHE"
    du -sh "$HF_CACHE" 2>/dev/null || echo "目录为空"
fi

# 创建符号链接（可选，方便访问）
if [ ! -L "$HOME/.cache/huggingface" ]; then
    echo "🔗 创建符号链接..."
    mkdir -p "$HOME/.cache"
    rm -rf "$HOME/.cache/huggingface" 2>/dev/null || true
    ln -sf "$HF_CACHE" "$HOME/.cache/huggingface"
    echo "✅ 符号链接: ~/.cache/huggingface -> $HF_CACHE"
fi

# 添加环境变量到 ~/.bashrc（如果还没有）
if ! grep -q "HF_HOME=$HF_CACHE" "$HOME/.bashrc" 2>/dev/null; then
    echo ""
    echo "📝 添加环境变量到 ~/.bashrc..."
    cat >> "$HOME/.bashrc" << EOF

# HuggingFace 使用 NVMe 临时存储
export HF_HOME=$HF_CACHE
export HF_DATASETS_CACHE=$HF_CACHE/datasets
export TRANSFORMERS_CACHE=$HF_CACHE/transformers
EOF
    echo "✅ 环境变量已添加"
fi

echo ""
echo "========================================"
echo "✅ NVMe 配置完成！"
echo "========================================"
echo ""
echo "说明："
echo "  - 模型将下载到: $HF_CACHE"
echo "  - 符号链接: ~/.cache/huggingface"
echo "  - ⚠️  重要: NVMe 是临时存储，实例停止后数据会丢失"
echo ""
echo "首次启动服务时，模型会自动下载（约 17GB）"
echo "后续重启实例（不停止），模型保留在 NVMe 上"
echo ""
