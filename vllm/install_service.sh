#!/bin/bash
set -e

echo "========================================"
echo "安装 Qwen3-VL systemd 服务"
echo "========================================"

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 sudo 运行此脚本"
    echo "用法: sudo bash install_service.sh"
    exit 1
fi

# 1. 停止当前运行的服务（如果有）
echo "1. 检查现有服务..."
if systemctl is-active --quiet qwen3vl; then
    echo "   停止现有服务..."
    systemctl stop qwen3vl
fi

# 2. 复制服务文件
echo "2. 安装 systemd 服务文件..."
cp qwen3vl.service /etc/systemd/system/qwen3vl.service
chmod 644 /etc/systemd/system/qwen3vl.service

# 3. 重新加载 systemd
echo "3. 重新加载 systemd..."
systemctl daemon-reload

# 4. 启用服务（开机自启）
echo "4. 启用开机自启动..."
systemctl enable qwen3vl

# 5. 启动服务
echo "5. 启动服务..."
systemctl start qwen3vl

# 6. 等待服务启动
echo "6. 等待服务启动..."
sleep 5

# 7. 检查服务状态
echo ""
echo "========================================"
echo "✅ 安装完成！"
echo "========================================"
echo ""
echo "服务状态:"
systemctl status qwen3vl --no-pager || true
echo ""
echo "常用命令:"
echo "  查看状态: sudo systemctl status qwen3vl"
echo "  查看日志: sudo journalctl -u qwen3vl -f"
echo "  重启服务: sudo systemctl restart qwen3vl"
echo "  停止服务: sudo systemctl stop qwen3vl"
echo ""
