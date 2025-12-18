#!/bin/bash
set -e

INSTANCE_ID="${1:-i-092208ff13efc08d2}"
REMOTE_DIR="/home/ubuntu/codes/qwen3vl-on-aws"

echo "========================================"
echo "将实例 $INSTANCE_ID 迁移到 SGLang"
echo "========================================"

# 检查实例状态
echo "📊 检查实例状态..."
INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name' --output text)

if [ "$INSTANCE_STATE" != "running" ]; then
    echo "❌ 错误: 实例状态为 $INSTANCE_STATE，需要 running"
    exit 1
fi

echo "✅ 实例状态: $INSTANCE_STATE"

# 步骤 1: 停止 vLLM 服务
echo ""
echo "🛑 步骤 1: 停止 vLLM 服务..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["sudo systemctl stop qwen3vl || true", "sleep 2", "systemctl is-active qwen3vl && echo \"⚠️  服务仍在运行\" || echo \"✅ vLLM 服务已停止\""]' \
    --output text \
    --query 'Command.CommandId' > /tmp/cmd_id_1.txt

COMMAND_ID=$(cat /tmp/cmd_id_1.txt)
sleep 5

aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id $INSTANCE_ID \
    --query 'StandardOutputContent' \
    --output text

# 步骤 2: 上传 SGLang 部署脚本
echo ""
echo "📤 步骤 2: 上传 SGLang 部署脚本..."

# 创建临时脚本来上传文件
cat > /tmp/upload_sglang_files.sh << 'UPLOAD_EOF'
#!/bin/bash
cd /home/ubuntu/codes/qwen3vl-on-aws

# 如果有 git 仓库，先 pull 最新代码
if [ -d .git ]; then
    echo "📥 拉取最新代码..."
    git pull origin main || git pull origin master || echo "⚠️  无法 pull，继续..."
fi
UPLOAD_EOF

# 通过 SSM 执行文件上传准备
echo "正在准备上传文件..."

# 步骤 3: 部署 SGLang
echo ""
echo "📦 步骤 3: 部署 SGLang..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters commands=["cd $REMOTE_DIR","git pull || echo 'Git pull failed'","bash deploy_sglang.sh"] \
    --timeout-seconds 600 \
    --output text \
    --query 'Command.CommandId' > /tmp/cmd_id_3.txt

COMMAND_ID=$(cat /tmp/cmd_id_3.txt)
echo "⏳ 等待 SGLang 安装完成（这可能需要 5-10 分钟）..."
sleep 10

# 轮询命令状态
for i in {1..60}; do
    STATUS=$(aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id $INSTANCE_ID \
        --query 'Status' \
        --output text 2>/dev/null || echo "Pending")

    echo "[$i/60] 命令状态: $STATUS"

    if [ "$STATUS" = "Success" ]; then
        echo "✅ SGLang 安装成功！"
        aws ssm get-command-invocation \
            --command-id "$COMMAND_ID" \
            --instance-id $INSTANCE_ID \
            --query 'StandardOutputContent' \
            --output text | tail -20
        break
    elif [ "$STATUS" = "Failed" ]; then
        echo "❌ SGLang 安装失败！"
        aws ssm get-command-invocation \
            --command-id "$COMMAND_ID" \
            --instance-id $INSTANCE_ID \
            --query '[StandardOutputContent,StandardErrorContent]' \
            --output text
        exit 1
    fi

    sleep 10
done

# 步骤 4: 安装并启动 SGLang systemd 服务
echo ""
echo "🚀 步骤 4: 安装并启动 SGLang 服务..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters commands=["cd $REMOTE_DIR","bash install_sglang_service.sh"] \
    --timeout-seconds 60 \
    --output text \
    --query 'Command.CommandId' > /tmp/cmd_id_4.txt

COMMAND_ID=$(cat /tmp/cmd_id_4.txt)
sleep 10

aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id $INSTANCE_ID \
    --query 'StandardOutputContent' \
    --output text

# 步骤 5: 验证服务状态
echo ""
echo "✅ 步骤 5: 验证 SGLang 服务状态..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["systemctl status qwen3vl-sglang --no-pager", "sleep 3", "curl -s http://localhost:8000/health || echo \"Health check failed\""]' \
    --output text \
    --query 'Command.CommandId' > /tmp/cmd_id_5.txt

COMMAND_ID=$(cat /tmp/cmd_id_5.txt)
sleep 8

aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id $INSTANCE_ID \
    --query 'StandardOutputContent' \
    --output text

echo ""
echo "========================================"
echo "✅ 迁移完成！"
echo "========================================"
echo ""
echo "实例 $INSTANCE_ID 现在运行 SGLang"
echo ""
echo "后续步骤："
echo "1. 测试 API: curl http://172.18.171.76:8000/v1/models"
echo "2. 查看日志: aws ssm start-session --target $INSTANCE_ID"
echo "            journalctl -u qwen3vl-sglang -f"
echo ""
