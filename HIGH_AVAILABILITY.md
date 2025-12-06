# Qwen3-VL 高可用部署指南

当前的基础部署**不是高可用**，存在以下风险：
- ❌ 单点故障 - 进程崩溃导致服务中断
- ❌ 无自动重启 - 需要人工干预
- ❌ SSH 断开风险 - 可能导致进程终止
- ❌ 无监控告警 - 故障难以及时发现

---

## 方案 1：systemd 服务（推荐）⭐

### 优势
- ✅ 自动重启 - 进程崩溃后自动恢复
- ✅ 开机自启 - 系统重启后自动启动
- ✅ 日志管理 - 统一的日志系统
- ✅ 进程管理 - 方便的启停控制
- ✅ 资源限制 - 防止资源耗尽

### 安装步骤

```bash
# 1. 停止当前后台进程（如果有）
# 找到进程 ID
ps aux | grep vllm

# 终止进程
kill <PID>

# 2. 安装 systemd 服务
sudo bash install_service.sh

# 3. 查看服务状态
sudo systemctl status qwen3vl

# 4. 查看实时日志
sudo journalctl -u qwen3vl -f
```

### 常用命令

```bash
# 启动服务
sudo systemctl start qwen3vl

# 停止服务
sudo systemctl stop qwen3vl

# 重启服务
sudo systemctl restart qwen3vl

# 查看状态
sudo systemctl status qwen3vl

# 查看日志（最近 100 行）
sudo journalctl -u qwen3vl -n 100

# 实时查看日志
sudo journalctl -u qwen3vl -f

# 启用开机自启
sudo systemctl enable qwen3vl

# 禁用开机自启
sudo systemctl disable qwen3vl
```

### 服务配置说明

服务文件位置：`/etc/systemd/system/qwen3vl.service`

关键配置：
- `Restart=always` - 总是自动重启
- `RestartSec=10` - 重启前等待 10 秒
- `StartLimitInterval=0` - 不限制重启次数

---

## 方案 2：Supervisor 进程管理

### 安装 Supervisor

```bash
# 安装
sudo apt-get update
sudo apt-get install -y supervisor

# 创建配置文件
sudo tee /etc/supervisor/conf.d/qwen3vl.conf > /dev/null <<EOF
[program:qwen3vl]
command=/home/ubuntu/codes/qwen3vl-on-aws/.venv/bin/vllm serve Qwen/Qwen3-VL-8B-Instruct --port 8000 --max-model-len 1024 --gpu-memory-utilization 0.95
directory=/home/ubuntu/codes/qwen3vl-on-aws
user=ubuntu
autostart=true
autorestart=true
startretries=999
redirect_stderr=true
stdout_logfile=/var/log/qwen3vl.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
environment=PATH="/home/ubuntu/codes/qwen3vl-on-aws/.venv/bin:%(ENV_PATH)s"
EOF

# 重新加载配置
sudo supervisorctl reread
sudo supervisorctl update

# 启动服务
sudo supervisorctl start qwen3vl
```

### Supervisor 常用命令

```bash
# 查看状态
sudo supervisorctl status qwen3vl

# 启动
sudo supervisorctl start qwen3vl

# 停止
sudo supervisorctl stop qwen3vl

# 重启
sudo supervisorctl restart qwen3vl

# 查看日志
sudo tail -f /var/log/qwen3vl.log
```

---

## 方案 3：Docker 容器化部署

### 创建 Dockerfile

```dockerfile
FROM nvidia/cuda:12.1.0-devel-ubuntu22.04

# 安装 Python 和依赖
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 安装 uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# 设置工作目录
WORKDIR /app

# 安装 vLLM
RUN uv pip install --system vllm

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["vllm", "serve", "Qwen/Qwen3-VL-8B-Instruct", \
     "--port", "8000", \
     "--max-model-len", "1024", \
     "--gpu-memory-utilization", "0.95", \
     "--host", "0.0.0.0"]
```

### Docker Compose 配置

```yaml
version: '3.8'

services:
  qwen3vl:
    image: qwen3vl:latest
    container_name: qwen3vl
    runtime: nvidia
    ports:
      - "8000:8000"
    environment:
      - NVIDIA_VISIBLE_DEVICES=0
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 180s
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

### 使用 Docker

```bash
# 构建镜像
docker build -t qwen3vl:latest .

# 启动容器（自动重启）
docker-compose up -d

# 查看日志
docker logs -f qwen3vl

# 重启容器
docker restart qwen3vl

# 停止容器
docker-compose down
```

---

## 方案 4：使用 Screen 或 tmux（临时方案）

### 使用 screen

```bash
# 创建 screen 会话
screen -S qwen3vl

# 启动服务
bash start_server.sh

# 分离会话（按 Ctrl+A，然后按 D）

# 重新连接
screen -r qwen3vl

# 查看所有会话
screen -ls

# 终止会话
screen -X -S qwen3vl quit
```

### 使用 tmux

```bash
# 创建 tmux 会话
tmux new -s qwen3vl

# 启动服务
bash start_server.sh

# 分离会话（按 Ctrl+B，然后按 D）

# 重新连接
tmux attach -t qwen3vl

# 查看所有会话
tmux ls

# 终止会话
tmux kill-session -t qwen3vl
```

**注意**：screen/tmux 不是真正的高可用方案，只是防止 SSH 断开导致进程终止。

---

## 方案 5：健康检查和监控

### 创建健康检查脚本

```bash
#!/bin/bash
# health_check.sh

API_URL="http://localhost:8000/health"
MAX_RETRIES=3
RETRY_DELAY=5

for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf $API_URL > /dev/null; then
        echo "✅ Service is healthy"
        exit 0
    else
        echo "❌ Health check failed (attempt $i/$MAX_RETRIES)"
        if [ $i -lt $MAX_RETRIES ]; then
            sleep $RETRY_DELAY
        fi
    fi
done

echo "🚨 Service is unhealthy, restarting..."
sudo systemctl restart qwen3vl
exit 1
```

### 配置 cron 定时检查

```bash
# 每 5 分钟检查一次
*/5 * * * * /home/ubuntu/codes/qwen3vl-on-aws/health_check.sh >> /var/log/qwen3vl-health.log 2>&1
```

### 使用 CloudWatch 监控（AWS）

```bash
# 安装 CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# 配置自定义指标
# - GPU 使用率
# - 内存使用率
# - 请求成功率
# - 响应时间
```

---

## 方案 6：生产环境高可用架构

### 完整架构

```
┌─────────────────────────────────────────┐
│          Application Load Balancer       │
│         (ALB with Health Checks)         │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
┌───────────────┐   ┌───────────────┐
│  EC2 Instance │   │  EC2 Instance │
│  + vLLM       │   │  + vLLM       │
│  (Primary)    │   │  (Standby)    │
└───────┬───────┘   └───────┬───────┘
        │                   │
        └─────────┬─────────┘
                  │
        ┌─────────▼─────────┐
        │   Model Storage    │
        │  (S3 / EFS)        │
        └───────────────────┘
```

### 关键组件

1. **负载均衡器 (ALB)**
   - 健康检查
   - 自动故障转移
   - SSL 终止

2. **Auto Scaling Group**
   - 自动扩缩容
   - 替换不健康实例

3. **共享模型存储**
   - S3 或 EFS
   - 避免重复下载

4. **监控和告警**
   - CloudWatch Alarms
   - SNS 通知
   - 日志聚合

### 成本优化

- 使用 Spot Instances（节省 70%）
- 设置最小实例数为 1
- 按需扩展

---

## 推荐方案选择

| 场景 | 推荐方案 | 理由 |
|------|---------|------|
| **开发测试** | Screen/Tmux | 简单快速 |
| **单机部署** | systemd | 稳定可靠，自动重启 |
| **多实例管理** | Supervisor | 统一管理多个服务 |
| **容器化** | Docker + Docker Compose | 环境一致性，易于迁移 |
| **生产环境** | ALB + Auto Scaling | 真正的高可用，自动故障转移 |

---

## 当前部署升级建议

1. **立即行动**（防止 SSH 断开导致服务中断）
   ```bash
   # 方法 1：使用 screen（临时）
   screen -S qwen3vl
   bash start_server.sh
   # Ctrl+A, D 分离

   # 方法 2：使用 nohup（临时）
   nohup bash start_server.sh > qwen3vl.log 2>&1 &
   ```

2. **短期方案**（1 小时内完成）
   ```bash
   # 安装 systemd 服务
   sudo bash install_service.sh
   ```

3. **长期方案**（生产环境）
   - 配置 Auto Scaling
   - 设置负载均衡
   - 启用 CloudWatch 监控
   - 配置告警通知

---

## 故障恢复清单

当服务宕机时：

### 1. 检查服务状态
```bash
sudo systemctl status qwen3vl
```

### 2. 查看日志
```bash
sudo journalctl -u qwen3vl -n 100
```

### 3. 检查 GPU
```bash
nvidia-smi
```

### 4. 检查内存
```bash
free -h
df -h
```

### 5. 手动重启
```bash
sudo systemctl restart qwen3vl
```

### 6. 如果无法启动
```bash
# 停止服务
sudo systemctl stop qwen3vl

# 杀死残留进程
pkill -f vllm

# 清理 GPU 内存
nvidia-smi --gpu-reset

# 重新启动
sudo systemctl start qwen3vl
```

---

## 总结

**当前状态**：❌ 不是高可用，存在宕机风险

**建议行动**：
1. ⚡ 立即使用 screen 或 nohup 防止 SSH 断开
2. 🔧 1 小时内安装 systemd 服务实现自动重启
3. 📊 配置监控和健康检查
4. 🚀 生产环境考虑多实例 + 负载均衡

选择 `sudo bash install_service.sh` 即可快速升级到高可用部署！
