#!/bin/bash
set -e

echo "========================================"
echo "安装 Qwen3-VL SGLang systemd 服务"
echo "========================================"

SERVICE_NAME="qwen3vl-sglang"
SERVICE_FILE="qwen3vl-sglang.service"

# 检查服务文件是否存在
if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ 错误: 未找到服务文件 $SERVICE_FILE"
    exit 1
fi

# 停止旧服务（如果正在运行）
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "🛑 停止现有服务..."
    sudo systemctl stop $SERVICE_NAME
fi

# 复制服务文件到 systemd 目录
echo "📋 复制服务文件到 /etc/systemd/system/"
sudo cp $SERVICE_FILE /etc/systemd/system/

# 重新加载 systemd
echo "🔄 重新加载 systemd daemon..."
sudo systemctl daemon-reload

# 启用服务（开机自启动）
echo "✅ 启用服务..."
sudo systemctl enable $SERVICE_NAME

# 启动服务
echo "🚀 启动服务..."
sudo systemctl start $SERVICE_NAME

# 等待几秒
sleep 3

# 检查状态
echo ""
echo "========================================"
echo "📊 服务状态"
echo "========================================"
sudo systemctl status $SERVICE_NAME --no-pager -l

echo ""
echo "========================================"
echo "✅ SGLang 服务安装完成！"
echo "========================================"
echo ""
echo "常用命令："
echo "  查看状态: sudo systemctl status $SERVICE_NAME"
echo "  查看日志: sudo journalctl -u $SERVICE_NAME -f"
echo "  停止服务: sudo systemctl stop $SERVICE_NAME"
echo "  启动服务: sudo systemctl start $SERVICE_NAME"
echo "  重启服务: sudo systemctl restart $SERVICE_NAME"
echo ""
