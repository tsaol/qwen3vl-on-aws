#!/bin/bash
# 统一测试脚本

echo "========================================"
echo "Qwen3-VL 测试工具"
echo "========================================"
echo ""
echo "选择测试类型："
echo "  1) 基础聊天测试"
echo "  2) 视觉分析测试"
echo ""

read -p "请选择 (1/2): " choice

case $choice in
    1)
        echo "运行基础聊天测试..."
        uv run python examples/python_client.py
        ;;
    2)
        echo "运行视觉分析测试..."
        uv run python examples/vision_test.py
        ;;
    *)
        echo "无效选择"
        exit 1
        ;;
esac
