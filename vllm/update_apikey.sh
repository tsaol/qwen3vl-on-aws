#!/bin/bash

# vLLM API Key 配置脚本
# 用于为 qwen3vl systemd 服务添加 API Key 认证
# 使用方法: bash update-vllm-apikey.sh [YOUR_API_KEY]

set -e

# 检查是否提供了 API Key
if [ -z "$1" ]; then
    echo "❌ 错误: 未提供 API Key"
    echo ""
    echo "使用方法:"
    echo "  bash update-vllm-apikey.sh YOUR_API_KEY"
    echo ""
    echo "示例:"
    echo "  bash update-vllm-apikey.sh sk-qwen-abc123def456"
    echo ""
    echo "生成 API Key:"
    echo "  python3 -c \"import secrets; print(f'sk-qwen-{secrets.token_urlsafe(32)}')\""
    exit 1
fi

API_KEY="$1"
SERVICE_FILE="/etc/systemd/system/qwen3vl.service"
BACKUP_FILE="${SERVICE_FILE}.bak.$(date +%Y%m%d-%H%M%S)"

echo "=== 配置 vLLM API Key 认证 ==="
echo ""
echo "API Key: ${API_KEY:0:15}..." # 只显示前 15 个字符
echo ""

# 检查服务文件是否存在
if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ 错误: 服务文件不存在: $SERVICE_FILE"
    echo "   请先运行 install_service.sh 安装 systemd 服务"
    exit 1
fi

# 备份原配置
echo "📦 备份原配置..."
sudo cp "$SERVICE_FILE" "$BACKUP_FILE"
echo "   备份保存到: $BACKUP_FILE"
echo ""

# 更新服务配置添加 --api-key
echo "🔧 更新服务配置..."
sudo tee "$SERVICE_FILE" > /dev/null << SERVICEEOF
[Unit]
Description=Qwen3-VL vLLM API Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/codes/qwen3vl-on-aws
Environment="PATH=/home/ubuntu/codes/qwen3vl-on-aws/.venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/home/ubuntu/codes/qwen3vl-on-aws/.venv/bin/vllm serve Qwen/Qwen3-VL-8B-Instruct --port 8000 --max-model-len 1024 --gpu-memory-utilization 0.95 --api-key $API_KEY

Restart=always
RestartSec=10
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
SERVICEEOF

echo "✅ 服务配置已更新"
echo ""

# 重新加载 systemd
echo "♻️  重新加载 systemd..."
sudo systemctl daemon-reload
echo "✅ Systemd 已重载"
echo ""

# 重启服务
echo "🔄 重启 qwen3vl 服务..."
sudo systemctl restart qwen3vl
echo "✅ 服务已重启"
echo ""

# 等待服务启动
echo "⏳ 等待服务启动（5秒）..."
sleep 5
echo ""

# 检查服务状态
echo "📊 服务状态:"
sudo systemctl status qwen3vl --no-pager --lines=10 || true
echo ""

echo "=== 配置完成 ==="
echo ""
echo "🔒 API Key 认证已启用"
echo ""
echo "测试方法:"
echo "  # 不带 API Key（应该返回 401）"
echo "  curl -w '\\nHTTP: %{http_code}\\n' http://localhost:8000/v1/models"
echo ""
echo "  # 带 API Key（应该成功）"
echo "  curl -H 'Authorization: Bearer $API_KEY' http://localhost:8000/v1/models"
echo ""
echo "客户端使用:"
echo "  export QWEN_API_KEY='$API_KEY'"
echo "  python3 examples/vision_test.py"
