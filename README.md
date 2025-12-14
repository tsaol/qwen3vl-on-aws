# Qwen3-VL 在 AWS 上的部署指南

这个仓库包含在 AWS 上部署 Qwen3-VL-8B-Instruct 模型的脚本和文档。

## 环境要求

- AWS EC2 实例（推荐 G6e 系列 GPU 实例）
- Python 3.10+
- NVIDIA GPU（支持 CUDA）
- 选择Deep Learning Base AMI with Single CUDA (Ubuntu) 

## 推荐的 AWS 实例类型

| 实例类型 | GPU | 显存 |
|---------|-----|------|
| g6e.xlarge | 1x L40S | 48GB | 
| g6e.2xlarge | 1x L40S | 48GB | 

## 快速开始

### 方式 1：一键部署（推荐）⭐

使用自动化脚本快速部署：

```bash
# 1. 克隆仓库
git clone https://github.com/tsaol/qwen3vl-on-aws.git
cd qwen3vl-on-aws

# 2. 运行部署脚本（安装依赖和环境）
bash deploy.sh

# 3. 启动服务
bash start_server.sh
```

**就这么简单！** 🎉 服务将在 `http://localhost:8000` 启动。

---

### 方式 2：手动安装（高级用户）

如果你想了解详细步骤或自定义配置：

#### 1. 安装依赖

使用 `uv` 工具（超快的 Python 包管理器）：

```bash
# 安装 uv (如果还没安装)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 更新 PATH（让 shell 能找到 uv）
source $HOME/.local/bin/env

# 创建虚拟环境 (Python 3.10+)
uv venv --python 3.10 --seed

# 激活虚拟环境
source .venv/bin/activate

# 安装 vLLM（自动检测 GPU 后端）
uv pip install vllm --torch-backend=auto
```

#### 2. 启动 vLLM 服务

```bash
# 基础启动命令
vllm serve Qwen/Qwen3-VL-8B-Instruct \
  --port 8000 \
  --max-model-len 1024 \
  --gpu-memory-utilization 0.95
```

**参数说明：**
- `--port 8000` - API 服务端口
- `--max-model-len 1024` - 最大序列长度（输入+输出 token 总数）
- `--gpu-memory-utilization 0.95` - 使用 95% 的 GPU 显存

---

### 测试 API

服务启动后，使用统一测试脚本：

```bash
# 交互式选择测试类型
bash test.sh
```

或直接用 curl 测试：

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [
      {"role": "user", "content": "你好，请介绍一下你自己"}
    ]
  }'
```

---

## 🔒 API Key 认证配置

vLLM 支持原生 API Key 认证，启用后所有 API 请求都需要提供有效的 Bearer Token。

### 为什么需要 API Key？

- ✅ **访问控制** - 防止未授权访问
- ✅ **成本管理** - 追踪和控制 API 使用量
- ✅ **安全合规** - 满足生产环境安全要求
- ✅ **多租户隔离** - 支持不同客户端使用不同密钥

### 启用步骤

#### 1. 生成安全的 API Key

```bash
# 使用 Python 生成随机密钥
python3 -c "import secrets; print(f'sk-qwen-{secrets.token_urlsafe(32)}')"
```

输出示例：`sk-qwen-abc123def456...`

#### 2. 配置 systemd 服务

使用提供的自动化脚本：

```bash
# 编辑脚本，替换 API_KEY 为你生成的密钥
nano update-vllm-apikey.sh

# 在两台实例上执行（如果使用多实例部署）
bash update-vllm-apikey.sh
```

或手动修改 `/etc/systemd/system/qwen3vl.service`：

```ini
ExecStart=/path/to/.venv/bin/vllm serve Qwen/Qwen3-VL-8B-Instruct \
  --port 8000 \
  --max-model-len 1024 \
  --gpu-memory-utilization 0.95 \
  --api-key YOUR_API_KEY_HERE
```

然后重启服务：

```bash
sudo systemctl daemon-reload
sudo systemctl restart qwen3vl
```

#### 3. 验证认证生效

```bash
# 测试 1: 不带 API Key（应该失败）
curl -w "\nHTTP: %{http_code}\n" \
  https://your-domain.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen3-VL-8B-Instruct", "messages": [{"role": "user", "content": "你好"}]}'

# 预期输出：{"error":"Unauthorized"} HTTP: 401

# 测试 2: 带正确的 API Key（应该成功）
curl https://your-domain.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"model": "Qwen/Qwen3-VL-8B-Instruct", "messages": [{"role": "user", "content": "你好"}]}'

# 预期输出：正常的 JSON 响应
```

### 客户端使用

#### Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://your-domain.com/v1",
    api_key="YOUR_API_KEY"  # 替换为你的 API Key
)

response = client.chat.completions.create(
    model="Qwen/Qwen3-VL-8B-Instruct",
    messages=[{"role": "user", "content": "你好"}]
)

print(response.choices[0].message.content)
```

#### Python (requests)

```python
import requests

headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer YOUR_API_KEY"
}

data = {
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [{"role": "user", "content": "你好"}]
}

response = requests.post(
    "https://your-domain.com/v1/chat/completions",
    headers=headers,
    json=data
)

print(response.json())
```

#### cURL

```bash
curl https://your-domain.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"model": "Qwen/Qwen3-VL-8B-Instruct", "messages": [...]}'
```

#### JavaScript/Node.js

```javascript
const response = await fetch('https://your-domain.com/v1/chat/completions', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer YOUR_API_KEY'
  },
  body: JSON.stringify({
    model: 'Qwen/Qwen3-VL-8B-Instruct',
    messages: [{role: 'user', content: '你好'}]
  })
});

const data = await response.json();
console.log(data.choices[0].message.content);
```

### 安全最佳实践

1. **不要硬编码 API Key** - 使用环境变量
   ```bash
   export QWEN_API_KEY="sk-qwen-xxx"
   ```

2. **不要提交到 Git** - 添加到 `.gitignore`
   ```
   .env
   config.yaml
   *_config.env
   ```

3. **定期轮换密钥** - 建议每 90 天更新一次

4. **使用不同密钥** - 开发/测试/生产环境分离

5. **启用访问日志** - 监控异常访问模式
   ```bash
   sudo journalctl -u qwen3vl -f | grep "Unauthorized"
   ```

### 常见问题

**Q: 如何禁用 API Key 认证？**
```bash
# 移除 --api-key 参数，重启服务
sudo nano /etc/systemd/system/qwen3vl.service
sudo systemctl daemon-reload
sudo systemctl restart qwen3vl
```

**Q: 支持多个 API Key 吗？**
vLLM 原生仅支持单个 API Key。如需多密钥管理，建议使用 [LiteLLM Proxy](https://docs.litellm.ai/) 或 Nginx 反向代理。

**Q: 忘记 API Key 怎么办？**
```bash
# 查看当前配置的 API Key
sudo grep "api-key" /etc/systemd/system/qwen3vl.service
```

---

## 客户端调用示例

我们提供了多种编程语言的客户端示例，详见 [client_examples.md](client_examples.md)

### 快速开始 - Python 客户端

```python
# 使用提供的示例脚本
python3 examples/python_client.py

# 或者使用 OpenAI SDK
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="EMPTY"
)

response = client.chat.completions.create(
    model="Qwen/Qwen3-VL-8B-Instruct",
    messages=[{"role": "user", "content": "你好"}]
)

print(response.choices[0].message.content)
```

### 支持的客户端

- ✅ **cURL** - 命令行测试
- ✅ **Python** (requests / OpenAI SDK) - [查看示例](examples/)
- ✅ **JavaScript/Node.js** (fetch / OpenAI SDK)
- ✅ **Go** - HTTP 客户端
- ✅ 任何支持 OpenAI API 的客户端库

## ⚠️ 高可用部署

**重要提示**：当前的基础部署**不是高可用**，存在以下风险：
- ❌ 单点故障 - 进程崩溃导致服务中断
- ❌ 无自动重启 - 需要人工干预
- ❌ SSH 断开风险 - 可能导致进程终止

### 推荐：安装 systemd 服务

实现自动重启、开机自启、故障恢复：

```bash
# 安装高可用服务
sudo bash install_service.sh

# 查看服务状态
sudo systemctl status qwen3vl

# 查看实时日志
sudo journalctl -u qwen3vl -f
```

**完整高可用部署方案**请参考：[GPU_HIGH_AVAILABILITY.md](GPU_HIGH_AVAILABILITY.md)

## 加载私有模型

### 方法 1：使用本地模型路径（推荐）

如果模型已下载到本地：

```bash
# 直接指定本地路径
MODEL=/path/to/your/private/model bash start_server.sh
```

或修改 start_server.sh 中的 MODEL 变量：
```bash
MODEL="/data/models/my-private-qwen3vl"
```

### 方法 2：使用 HuggingFace Token（私有仓库）

如果模型在 HuggingFace 私有仓库：

```bash
# 设置 HuggingFace Token
export HF_TOKEN="hf_xxxxxxxxxxxxxxxxxxxxx"

# 启动服务
MODEL=your-org/private-model bash start_server.sh
```

或使用 huggingface-cli 一次性登录：
```bash
pip install huggingface-hub
huggingface-cli login
```

### 方法 3：从 S3/云存储加载

```bash
# 1. 下载模型到本地
aws s3 sync s3://your-bucket/models/qwen3vl /data/models/qwen3vl

# 2. 使用本地路径启动
MODEL=/data/models/qwen3vl bash start_server.sh
```

### 方法 4：使用配置文件

创建 `model_config.env` 文件：

```bash
# model_config.env
MODEL_PATH="/data/models/my-private-model"
HF_TOKEN="hf_xxxxx"  # 如果需要
PORT=8000
MAX_MODEL_LEN=1024
GPU_MEMORY_UTIL=0.95
```

修改 start_server.sh 加载配置文件：
```bash
# 在脚本开头添加
if [ -f "model_config.env" ]; then
    source model_config.env
fi
```

**安全提醒**：
- 不要把 Token 提交到 Git 仓库
- 将 `model_config.env` 添加到 `.gitignore`
- 生产环境建议使用 AWS Secrets Manager


## 故障排查

### 1. CUDA 找不到
```bash
# 检查 CUDA 是否安装
nvidia-smi

# 检查 PyTorch CUDA 支持
python -c "import torch; print(torch.cuda.is_available())"
```

### 2. 显存不足
- 减少 `--gpu-memory-utilization`
- 减少 `--max-model-len`
- 使用更大的 GPU 实例

### 3. 模型下载慢
```bash
# 设置 HuggingFace 镜像
export HF_ENDPOINT=https://hf-mirror.com
```

## 生产环境部署

对于生产环境，建议：
1. 使用 Docker 容器化
2. 配置负载均衡器（ALB/NLB）
3. 设置 Auto Scaling
4. 启用 CloudWatch 监控
5. 配置日志收集

## 相关资源

- [vLLM 官方文档](https://docs.vllm.ai/)
- [Qwen3-VL 模型卡](https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct)
- [AWS GPU 实例定价](https://aws.amazon.com/ec2/instance-types/)

## 许可证

MIT License
