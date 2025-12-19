#!/bin/bash
set -e

echo "========================================"
echo "完整 SGLang 部署脚本"
echo "实例: $(hostname)"
echo "日期: $(date)"
echo "========================================"
echo ""

# 步骤 1: 扩展文件系统
echo "========== 步骤 1: 扩展文件系统 =========="
echo "当前磁盘状态:"
df -h /
echo ""

echo "扩展分区..."
sudo growpart /dev/nvme0n1 1 || echo "⚠️  分区已经是最大大小或growpart失败"
echo ""

echo "扩展文件系统..."
sudo resize2fs /dev/nvme0n1p1 || echo "⚠️  resize2fs失败"
echo ""

echo "✅ 扩展后的磁盘空间:"
df -h /
echo ""

# 步骤 2: 拉取最新代码
echo "========== 步骤 2: 拉取最新代码 =========="
cd /home/ubuntu/codes/qwen3vl-on-aws
git config --global --add safe.directory /home/ubuntu/codes/qwen3vl-on-aws || true
git pull origin main
echo ""

# 步骤 3: 部署 SGLang
echo "========== 步骤 3: 部署 SGLang =========="
bash deploy_sglang.sh
echo ""

# 步骤 4: 安装systemd服务
echo "========== 步骤 4: 安装 systemd 服务 =========="
bash install_sglang_service.sh
echo ""

# 步骤 5: 验证服务状态
echo "========== 步骤 5: 验证服务状态 =========="
sleep 5
sudo systemctl status qwen3vl-sglang --no-pager || true
echo ""

# 步骤 6: 测试健康检查
echo "========== 步骤 6: 测试健康检查 =========="
echo "等待服务启动..."
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ 健康检查通过!"
        curl -s http://localhost:8000/health
        break
    fi
    echo "[$i/30] 等待服务启动..."
    sleep 2
done
echo ""

echo "========================================"
echo "✅ 部署完成！"
echo "========================================"
echo ""
echo "服务信息:"
echo "  - systemd 服务: qwen3vl-sglang"
echo "  - 端口: 8000"
echo "  - 健康检查: http://localhost:8000/health"
echo ""
echo "常用命令:"
echo "  sudo systemctl status qwen3vl-sglang   # 查看状态"
echo "  sudo systemctl restart qwen3vl-sglang  # 重启服务"
echo "  sudo journalctl -u qwen3vl-sglang -f   # 查看日志"
echo ""
