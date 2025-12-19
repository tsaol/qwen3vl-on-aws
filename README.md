# Qwen3-VL 在 AWS 上的部署指南

在 AWS 上部署 Qwen3-VL-8B-Instruct 多模态视觉语言模型，支持 **vLLM** 和 **SGLang** 两种推理框架。

##  两种部署方式

本项目提供两种高性能推理框架，根据你的使用场景选择：

| 特性 | [vLLM](vllm/) | [SGLang](sglang/) |
|------|---------------|-------------------|
| 推理技术 | PagedAttention | RadixAttention |
| 最大上下文 | 1K-256K (可配置) | 256K (原生支持) |
| 首 token 延迟 | ~100-200ms | ~50-100ms  |
| 批量吞吐量 |  最高 |  高 |
| 多轮对话 |  标准 |  优化 |
| 长文档/视频 | 需配置 |  原生支持 |
| API Key 认证 |  原生支持 |  原生支持 |
| 生产成熟度 |  广泛使用 |  新兴 |

###  选择 vLLM 如果你需要：
-  高并发批量推理
-  成熟稳定的生产环境
-  更低的显存占用

###  选择 SGLang 如果你需要：
-  交互式聊天应用（更快响应）
-  长文档分析（整本书）
-  视频理解（小时级视频）
-  多轮对话优化

---

##  环境要求

- **AWS EC2 实例**：推荐 G6e 系列 GPU 实例
- **Python**: 3.10+
- **NVIDIA GPU**: 支持 CUDA
- **AMI**: Deep Learning Base AMI with Single CUDA (Ubuntu)

### 推荐的 AWS 实例类型

| 实例类型 | GPU | 显存 | 适用场景 |
|---------|-----|------|---------|
| g6e.xlarge | 1x L40S | 48GB | 单实例部署 |
| g6e.2xlarge | 1x L40S | 48GB | 高性能单实例 |
| g6e.4xlarge | 2x L40S | 96GB | 多实例/模型并行 |

---

##  快速开始

### 方案 A: vLLM 部署（推荐生产环境）

```bash
# 1. 克隆仓库
git clone https://github.com/tsaol/qwen3vl-on-aws.git
cd qwen3vl-on-aws

# 2. 进入 vLLM 目录
cd vllm

# 3. 部署 vLLM
bash deploy.sh

# 4. 安装 systemd 服务（可选但推荐）
bash install_service.sh

# 5. 启动服务
sudo systemctl start qwen3vl
# 或者直接运行：bash start_server.sh
```

**完整文档**: [vllm/README.md](vllm/README.md)

---

### 方案 B: SGLang 部署（推荐交互式应用）

```bash
# 1. 克隆仓库
git clone https://github.com/tsaol/qwen3vl-on-aws.git
cd qwen3vl-on-aws

# 2. 进入 SGLang 目录
cd sglang

# 3. 部署 SGLang（需要 10 分钟）
bash deploy.sh

# 4. 安装 systemd 服务（可选但推荐）
bash install_service.sh

# 5. 启动服务
sudo systemctl start qwen3vl-sglang
# 或者直接运行：bash start_server.sh
```

**完整文档**: [sglang/README.md](sglang/README.md)

---

##  测试 API

两种部署方式都兼容 OpenAI API 格式：

```bash
# 健康检查
curl http://localhost:8000/health

# 查看模型
curl http://localhost:8000/v1/models

# 聊天完成
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [{"role": "user", "content": "你好"}]
  }'
```

---

##  项目结构

```
qwen3vl-on-aws/
├── README.md                    # 主文档（本文件）
├── vllm/                        #  vLLM 部署方式
│   ├── README.md               # vLLM 详细文档
│   ├── deploy.sh               # 部署脚本
│   ├── start_server.sh         # 启动脚本
│   ├── qwen3vl.service         # systemd 服务
│   ├── install_service.sh      # 服务安装脚本
│   └── update_apikey.sh        # API Key 更新脚本
├── sglang/                      #  SGLang 部署方式
│   ├── README.md               # SGLang 详细文档
│   ├── deploy.sh               # 部署脚本
│   ├── start_server.sh         # 启动脚本
│   ├── qwen3vl.service         # systemd 服务
│   └── install_service.sh      # 服务安装脚本
├── examples/                    #  客户端示例代码
│   ├── python_client.py        # Python 基础调用
│   ├── stream_client.py        # 流式响应
│   └── vision_test.py          # 视觉理解示例
├── docs/                        #  完整文档
│   ├── client_examples.md      # 多语言客户端示例
│   ├── GPU_HIGH_AVAILABILITY.md # 高可用部署方案
│   └── LITELLM_HA_SOLUTIONS.md # LiteLLM 网关方案
└── tools/                       #  工具脚本
    └── test.sh                 # API 测试脚本
```

---

##  客户端调用示例

### Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="EMPTY"  # vLLM 需要配置 API Key
)

response = client.chat.completions.create(
    model="Qwen/Qwen3-VL-8B-Instruct",
    messages=[{"role": "user", "content": "你好"}]
)

print(response.choices[0].message.content)
```

### 视觉理解示例

```python
# 使用提供的示例脚本
cd examples
python3 vision_test.py

# 或者自定义
response = client.chat.completions.create(
    model="Qwen/Qwen3-VL-8B-Instruct",
    messages=[{
        "role": "user",
        "content": [
            {"type": "image_url", "image_url": {"url": "https://example.com/image.jpg"}},
            {"type": "text", "text": "描述这张图片"}
        ]
    }]
)
```

**完整客户端示例**: [docs/client_examples.md](docs/client_examples.md)

---

##  API Key 认证

vLLM 和 SGLang 都支持原生 API Key 认证。

### vLLM 配置

```bash
# 1. 生成密钥
python3 -c "import secrets; print(f'sk-qwen-{secrets.token_urlsafe(32)}')"

# 2. 配置 API Key
cd vllm
bash update_apikey.sh <your-api-key>

# 3. 重启服务
sudo systemctl restart qwen3vl
```

**详细配置**: [vllm/README.md#api-key-配置](vllm/README.md)

### SGLang 配置

SGLang 通过启动参数配置：

```bash
# 编辑 sglang/start_server.sh，添加 --api-key 参数
python -m sglang.launch_server \
    --model-path Qwen/Qwen3-VL-8B-Instruct \
    --host 0.0.0.0 \
    --port 8000 \
    --api-key YOUR_API_KEY

# 重启服务
sudo systemctl restart qwen3vl-sglang
```

**详细配置**: [sglang/README.md#api-key-配置](sglang/README.md)

---

##  高可用部署

### 单实例高可用（systemd 自动重启）

```bash
# vLLM
cd vllm && bash install_service.sh

# 或 SGLang
cd sglang && bash install_service.sh
```

特性：
-  进程崩溃自动重启
-  开机自动启动
-  统一日志管理
-  服务状态监控

### 多实例高可用（负载均衡）

使用 ALB + 多个 EC2 实例：

```
       ┌─────────────┐
       │  ALB / NLB  │
       └──────┬──────┘
              │
      ┌───────┴────────┐
      │                │
┌─────▼─────┐  ┌───────▼──────┐
│ Instance 1 │  │  Instance 2  │
│   vLLM     │  │   vLLM       │
│ L40S 48GB  │  │  L40S 48GB   │
└────────────┘  └──────────────┘
```

**完整方案**: [docs/GPU_HIGH_AVAILABILITY.md](docs/GPU_HIGH_AVAILABILITY.md)

### LiteLLM 统一网关

使用 LiteLLM 实现：
-  负载均衡和故障转移
-  API 密钥管理
-  速率限制和配额控制
-  请求缓存

**完整方案**: [docs/LITELLM_HA_SOLUTIONS.md](docs/LITELLM_HA_SOLUTIONS.md)

---

##  性能对比

### 测试环境
- 实例: g6e.xlarge (NVIDIA L40S 48GB)
- 模型: Qwen3-VL-8B-Instruct

### 基准测试结果

| 测试场景 | vLLM | SGLang |
|---------|------|--------|
| 短对话首 token (ms) | 120 | 65  |
| 批量推理吞吐 (tokens/s) | 850  | 720 |
| 多轮对话 (10轮) | 1.2s | 0.8s  |
| 长文档 (10K tokens) | 配置后可用 | 原生支持  |
| GPU 显存占用 (1K上下文) | 40GB | 42GB |
| GPU 显存占用 (256K上下文) | - | 42GB |

---

##  故障排查

### CUDA 找不到
```bash
nvidia-smi  # 检查 GPU
python -c "import torch; print(torch.cuda.is_available())"
```

### 显存不足
- 减少 `--gpu-memory-utilization`
- 减少 `--max-model-len`（vLLM）
- 减少 `--mem-fraction-static`（SGLang）

### 模型下载慢
```bash
export HF_ENDPOINT=https://hf-mirror.com
```

### 端口被占用
```bash
# 查看端口占用
sudo lsof -i :8000

# 修改端口
PORT=8001 bash start_server.sh
```

---

##  完整文档

- **部署方式**
  - [vLLM 部署文档](vllm/README.md)
  - [SGLang 部署文档](sglang/README.md)

- **使用指南**
  - [客户端使用示例](docs/client_examples.md)
  - [Python 示例代码](examples/)

- **高级配置**
  - [高可用部署方案](docs/GPU_HIGH_AVAILABILITY.md)
  - [LiteLLM 网关方案](docs/LITELLM_HA_SOLUTIONS.md)

---

##  常见问题

### Q: 应该选择 vLLM 还是 SGLang？

**选择 vLLM** 如果：
- 你需要稳定的生产环境
- 高并发批量推理是主要场景

**选择 SGLang** 如果：
- 你在做交互式聊天应用
- 需要处理长文档或视频
- 需要更快的响应速度

### Q: 可以同时运行两种方式吗？

可以，但需要：
1. 使用不同的端口（如 8000 和 8001）
2. 每个 GPU 只运行一个实例
3. 确保有足够显存（每个实例 40-45GB）

### Q: vLLM 的 1024 上下文太短怎么办？

编辑 `vllm/start_server.sh`：
```bash
MAX_MODEL_LEN=${MAX_MODEL_LEN:-262144}  # 改为 256K
```

### Q: 如何从 vLLM 切换到 SGLang？

```bash
# 停止 vLLM
sudo systemctl stop qwen3vl

# 部署 SGLang
cd sglang && bash deploy.sh && bash install_service.sh

# 启动 SGLang
sudo systemctl start qwen3vl-sglang
```

---

##  相关资源

- [vLLM 官方文档](https://docs.vllm.ai/)
- [SGLang 官方文档](https://docs.sglang.ai/)
- [SGLang GitHub](https://github.com/sgl-project/sglang)
- [Qwen3-VL 模型卡](https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct)
- [AWS GPU 实例定价](https://aws.amazon.com/ec2/instance-types/)

---

##  技术支持

- GitHub Issues: https://github.com/tsaol/qwen3vl-on-aws/issues
- 部署问题: 查看对应部署方式的 README
- 性能优化: 参考高可用部署文档

---

##  许可证

MIT License

---

##  致谢

- [vLLM](https://github.com/vllm-project/vllm) - 高性能 LLM 推理引擎
- [SGLang](https://github.com/sgl-project/sglang) - 新一代推理框架
- [Qwen Team](https://github.com/QwenLM) - 优秀的多模态模型
