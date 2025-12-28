# SGLang 部署方式

基于 SGLang 推理框架部署 Qwen3-VL-8B-Instruct 视觉语言模型。

##  特点

- **RadixAttention**: 自动 KV Cache 共享，更高效的内存管理
- **快速响应**: 更快的首 token 延迟
- **长上下文**: 原生支持 256K tokens（262,144）
- **多轮对话优化**: 适合交互式应用场景
- **OpenAI 兼容**: 完全兼容 OpenAI API 格式

##  配置参数

- **端口**: 8000
- **最大上下文长度**: 262,144 tokens（自动从模型配置读取）
- **GPU 显存利用率**: 0.85
- **API Key 认证**: 支持（通过 --api-key 参数）

##  快速部署

### 1. 部署 SGLang

```bash
cd sglang
bash deploy.sh
```

脚本会自动：
-  检查 GPU 环境
-  安装 Python 3.10
-  创建虚拟环境 `.venv-sglang`
-  安装 SGLang 和依赖（flashinfer, sgl-kernel 等）
-  配置 NVMe 缓存目录
-  下载模型到缓存

**注意**: 部署需要约 10 分钟，会下载 ~3GB 依赖包。

### 2. 启动服务

```bash
bash start_server.sh
```

### 3. 安装 systemd 服务（推荐）

```bash
bash install_service.sh
```

服务管理命令：
```bash
sudo systemctl start qwen3vl-sglang      # 启动
sudo systemctl stop qwen3vl-sglang       # 停止
sudo systemctl restart qwen3vl-sglang    # 重启
sudo systemctl status qwen3vl-sglang     # 查看状态
sudo journalctl -u qwen3vl-sglang -f     # 查看日志
```

##  自定义配置

编辑 `start_server.sh` 修改启动参数：

```bash
# 模型路径
MODEL="${MODEL:-Qwen/Qwen3-VL-8B-Instruct}"

# 端口（默认 8000）
PORT=${PORT:-8000}

# 主机地址（默认 0.0.0.0）
HOST="${HOST:-0.0.0.0}"

# GPU 显存利用率（默认 0.85）
MEM_FRACTION_STATIC="${MEM_FRACTION_STATIC:-0.85}"
```

**注意**: SGLang 会自动读取模型配置文件中的 `max_position_embeddings` (262144)，无需手动指定。

##  高级优化配置（针对 L40S 48GB）

针对 AWS g6e.xlarge (L40S 48GB) 运行 Qwen2.5-VL 多模态模型的优化配置。

### 优化启动命令

```bash
python -m sglang.launch_server \
    --model-path Qwen/Qwen2.5-VL-7B-Instruct \
    --host 0.0.0.0 \
    --port 8000 \
    --quantization fp8 \
    --mm-proj-url Qwen/Qwen2.5-VL-7B-Instruct-mmproj \
    --attention-backend fa3 \
    --mem-fraction-static 0.82 \
    --schedule-policy lpm \
    --max-total-tokens 8192 \
    --max-running-requests 48 \
    --enable-torch-compile \
    --api-key YOUR_API_KEY
```

### 参数说明

| 参数 | 值 | 说明 |
|------|-----|------|
| `--quantization` | fp8 | FP8 量化，加速视觉塔推理 |
| `--mm-proj-url` | 模型-mmproj | 视觉投影模块路径（Qwen-VL 专用） |
| `--attention-backend` | fa3 | FlashAttention 3，更快的注意力计算 |
| `--mem-fraction-static` | 0.82 | L40S 优化值，预留 18% 给图像特征缓存 |
| `--schedule-policy` | lpm | 最长前缀匹配调度策略 |
| `--max-total-tokens` | 8192 | 最大 token 数（支持长上下文） |
| `--max-running-requests` | 48 | 最大并发请求数 |
| `--enable-torch-compile` | - | 启用 PyTorch 编译优化 |

### L40S + Qwen-VL 性能预期

| 负载类型 | 预期性能 | 备注 |
|---------|---------|------|
| 纯文本 | 180-250 tokens/s | 与文本模型相当 |
| 单图推理 | 120-160 tokens/s | 视觉编码占 30% 时间 |
| 多图+长文本 | 80-110 tokens/s | 8K 上下文 |

**L40S 48GB 优势**：
- 视觉塔 + KV Cache 轻松容纳
- 支持多图输入和高并发
- 充足显存支持长上下文推理

### 多模态推理示例

**图像理解**：
```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "model": "Qwen/Qwen2.5-VL-7B-Instruct",
    "messages": [{
      "role": "user",
      "content": [
        {
          "type": "image_url",
          "image_url": {"url": "https://example.com/image.jpg"}
        },
        {
          "type": "text",
          "text": "描述这张图片"
        }
      ]
    }]
  }'
```

### 性能基准测试

```bash
# 使用 SGLang 内置基准工具
python3 -m sglang.bench_serving \
  --backend sglang \
  --dataset sharegpt4_vision \
  --num-prompts 500 \
  --request-rate 10 \
  --base-url http://localhost:8000
```

**预期结果**：
- 单图推理 TTFT < 1s
- 吞吐量 > 100 tokens/s
- GPU 利用率 > 85%
- 视觉任务延迟远低于 vLLM

### 图像分辨率配置

SGLang 默认支持：
- 默认分辨率：512x512
- 支持动态分辨率调整
- 自动适配输入图像尺寸

##  API Key 认证配置

SGLang 支持原生 API Key 认证，通过 `--api-key` 参数配置。

### 生成 API Key

```bash
# 生成安全的随机密钥
python3 -c "import secrets; print(f'sk-sglang-{secrets.token_urlsafe(32)}')"
```

### 配置方法

#### 方法 1: 修改启动脚本

编辑 `start_server.sh`，添加 API Key 参数：

```bash
python -m sglang.launch_server \
    --model-path $MODEL \
    --host $HOST \
    --port $PORT \
    --mem-fraction-static $MEM_FRACTION_STATIC \
    --api-key YOUR_API_KEY_HERE
```

#### 方法 2: 修改 systemd 服务

编辑 `/etc/systemd/system/qwen3vl-sglang.service`：

```ini
ExecStart=/path/to/.venv-sglang/bin/python -m sglang.launch_server \
    --model-path Qwen/Qwen3-VL-8B-Instruct \
    --host 0.0.0.0 \
    --port 8000 \
    --mem-fraction-static 0.85 \
    --api-key YOUR_API_KEY_HERE
```

然后重启服务：

```bash
sudo systemctl daemon-reload
sudo systemctl restart qwen3vl-sglang
```

### 客户端使用

配置 API Key 后，所有请求都需要提供 Bearer Token：

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [{"role": "user", "content": "你好"}]
  }'
```

Python 示例：

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="YOUR_API_KEY"
)

response = client.chat.completions.create(
    model="Qwen/Qwen3-VL-8B-Instruct",
    messages=[{"role": "user", "content": "你好"}]
)
```

##  性能特点

| 场景 | 表现 |
|------|------|
| 短对话 |  优秀 |
| 批量推理 |  良好 |
| 高并发 |  良好 |
| 长文档 |  原生支持 256K |
| 视频理解 |  支持小时级视频 |
| 多轮对话 |  RadixAttention 优化 |
| 首 token 延迟 |  更快 |

##  测试 API

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

##  视频理解示例

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "video", "video_url": "https://example.com/video.mp4"},
        {"type": "text", "text": "请描述这个视频的内容"}
      ]
    }]
  }'
```

##  文件说明

- `deploy.sh` - 部署脚本，安装 SGLang 环境
- `start_server.sh` - 启动 SGLang 服务器
- `qwen3vl.service` - systemd 服务配置文件
- `install_service.sh` - 安装 systemd 服务

##  核心优势

### 1. RadixAttention 技术

SGLang 使用 RadixAttention，自动检测和复用 KV Cache：

```
场景：多轮对话

用户 1: "介绍一下北京"
用户 2: "介绍一下北京的美食"
用户 3: "介绍一下北京的历史"

RadixAttention 会自动识别"介绍一下北京"这个共同前缀，
只计算一次，后续请求直接复用，大幅提升性能。
```

### 2. 原生长上下文

- Qwen3-VL 支持 256K tokens
- SGLang 自动读取模型配置
- **无需手动设置** `max-model-len`
- 可以处理整本书、小时级视频

### 3. 更快的首 token 延迟

对于交互式应用（聊天机器人、实时问答）：
- SGLang: ~50-100ms 首 token
- vLLM: ~100-200ms 首 token

##  与 vLLM 对比

选择 SGLang 如果你需要：
-  更快的首 token 延迟（交互式应用）
-  原生 256K 长上下文支持
-  更好的多轮对话性能
-  自动 KV Cache 复用

选择 vLLM 如果你需要：
-  更高的批量推理吞吐量
-  更成熟稳定的生产环境
-  更好的高并发支持

##  更多文档

- [客户端使用示例](../docs/client_examples.md)
- [高可用部署方案](../docs/GPU_HIGH_AVAILABILITY.md)
- [LiteLLM 网关方案](../docs/LITELLM_HA_SOLUTIONS.md)
- [Python 示例代码](../examples/)

##  常见问题

### Q: 为什么 SGLang 显示 262,144 tokens？

A: SGLang 会自动读取模型配置文件中的 `max_position_embeddings`，Qwen3-VL 原生支持 256K (262,144) tokens。

### Q: 为什么部署时间比 vLLM 长？

A: SGLang 需要安装额外的优化库：
- flashinfer: Flash Attention 内核
- sgl-kernel: SGLang 自定义内核
- triton: GPU 编译器

这些库提供了更好的性能，值得等待。

### Q: 如何添加 API Key 认证？

A: SGLang 支持原生 API Key 认证，通过 `--api-key` 参数配置。详见上方的 [API Key 认证配置](#api-key-认证配置) 章节。

如需更高级的认证管理（多密钥、速率限制等），可以使用：
1. LiteLLM Proxy（推荐）
2. AWS API Gateway
3. Nginx 反向代理 + Basic Auth

参考 [LiteLLM 方案文档](../docs/LITELLM_HA_SOLUTIONS.md)。

### Q: 显存占用比 vLLM 高吗？

A: 相同上下文长度下，显存占用基本相当。但 SGLang 支持更长的上下文，所以实际显存占用可能更高：
- vLLM (1K): ~40GB
- SGLang (256K): ~42GB

### Q: 可以同时运行 vLLM 和 SGLang 吗？

A: 可以，但需要：
1. 使用不同的端口
2. 每个 GPU 只运行一个实例
3. 确保有足够显存（每个实例需要 40-45GB）

##  技术细节

### RadixAttention vs PagedAttention

| 特性 | RadixAttention (SGLang) | PagedAttention (vLLM) |
|------|------------------------|----------------------|
| 核心结构 | 前缀树 (Radix Tree) | 分页内存 (Paging) |
| KV Cache 复用 | 自动检测前缀 | 需要手动指定 |
| 多轮对话 |  优化 |  标准 |
| 批量推理 |  良好 |  优秀 |
| 内存效率 | 更高（相同前缀共享） | 高（细粒度分页） |

### 依赖包大小

```
torch:          858 MB
sgl-kernel:     510 MB
triton:         162 MB
flashinfer:      99 MB
transformers:    11 MB
其他:           ~200 MB
----------------------------
总计:          ~1.8 GB
```

---

##  EAGLE3 投机解码加速

EAGLE3 (Extrapolative A* Generative Language Engine) 是一种投机解码技术，可以显著提升推理速度。

### 性能提升

| 指标 | 标准模式 | EAGLE3 模式 | 提升 |
|-----|---------|------------|------|
| **输出吞吐量** | 389 tok/s | **507 tok/s** | **+30%** |
| **请求吞吐量** | 9.7 req/s | **12.7 req/s** | **+30%** |
| **平均延迟** | 1.03s | **0.79s** | **-23%** |
| **每Token时间** | 24.5ms | **18.2ms** | **-26%** |

### 工作原理

```
┌─────────────────────────────────────────────────────────┐
│                    EAGLE3 工作流程                       │
├─────────────────────────────────────────────────────────┤
│  1. Draft Model (0.4B) 快速生成多个候选 token           │
│                    ↓                                    │
│  2. Main Model (8B) 一次性验证所有候选                  │
│                    ↓                                    │
│  3. 接受正确的 token，拒绝错误的                        │
│                    ↓                                    │
│  4. 平均每步接受 2-3 个 token，实现加速                 │
└─────────────────────────────────────────────────────────┘
```

### 前置条件

1. **Draft 模型**: 需要下载专门的 EAGLE3 Draft 模型
2. **SGLang 版本**: 需要支持 Qwen3-VL EAGLE3 的版本（PR #13918）

### 部署步骤

#### 1. 下载 Draft 模型

```bash
# 下载 EAGLE3 Draft 模型 (约 1GB)
huggingface-cli download taobao-mnn/Qwen3-VL-8B-Instruct-Eagle3 \
    --local-dir /opt/dlami/nvme/models/Qwen3-VL-8B-Instruct-Eagle3

# 或者使用 Python
python -c "from huggingface_hub import snapshot_download; snapshot_download('taobao-mnn/Qwen3-VL-8B-Instruct-Eagle3', local_dir='/opt/dlami/nvme/models/Qwen3-VL-8B-Instruct-Eagle3')"
```

#### 2. 安装支持 EAGLE3 的 SGLang

由于 Qwen3-VL EAGLE3 支持正在合并中（PR #13918），需要从 PR 分支安装：

```bash
# 克隆 PR 分支
cd /home/ubuntu/codes
git clone -b qwen3_vl_eagle https://github.com/Lzhang-hub/sglang.git sglang-eagle3

# 安装
cd sglang-eagle3
source /path/to/your/venv/bin/activate
pip install -e python/
```

> **注意**: 当 PR #13918 合并到主分支后，可以直接使用官方 SGLang 版本。

#### 3. 启动 EAGLE3 模式

```bash
python -m sglang.launch_server \
    --model-path /opt/dlami/nvme/models/Qwen3-VL-8B-Instruct \
    --host 0.0.0.0 \
    --port 8000 \
    --mem-fraction-static 0.8 \
    --trust-remote-code \
    --speculative-algorithm EAGLE3 \
    --speculative-draft-model-path /opt/dlami/nvme/models/Qwen3-VL-8B-Instruct-Eagle3 \
    --speculative-num-steps 3 \
    --speculative-eagle-topk 6 \
    --speculative-num-draft-tokens 16
```

#### 4. 使用启动脚本

```bash
# 使用 EAGLE3 启动脚本
bash start_server_eagle3.sh
```

### EAGLE3 参数说明

| 参数 | 推荐值 | 说明 |
|------|-------|------|
| `--speculative-algorithm` | `EAGLE3` | 投机解码算法 |
| `--speculative-draft-model-path` | 模型路径 | Draft 模型路径 |
| `--speculative-num-steps` | `3` | 投机步数 |
| `--speculative-eagle-topk` | `6` | Top-K 候选数 |
| `--speculative-num-draft-tokens` | `16` | 每步草稿 token 数 |

### EAGLE3 vs 标准模式

| 特性 | 标准模式 | EAGLE3 模式 |
|-----|---------|------------|
| 吞吐量 | 基准 | **+30%** |
| 延迟 | 基准 | **-23%** |
| 显存占用 | ~18GB | ~19GB (+1GB Draft模型) |
| TTFT | 更快 | 略慢 (+10ms) |
| 输出质量 | 基准 | 完全一致 |

### 注意事项

1. **TTFT 略有增加**: EAGLE3 需要同时加载主模型和 Draft 模型，首 Token 时间会略增
2. **显存占用增加**: Draft 模型额外占用约 1GB 显存
3. **输出完全一致**: EAGLE3 只是加速，不影响输出质量
4. **PR 状态**: Qwen3-VL EAGLE3 支持目前在 PR #13918，已获批准待合并

### 相关资源

- **Draft 模型**: [taobao-mnn/Qwen3-VL-8B-Instruct-Eagle3](https://huggingface.co/taobao-mnn/Qwen3-VL-8B-Instruct-Eagle3)
- **SGLang PR**: [#13918 - support qwen3-vl eagle infer](https://github.com/sgl-project/sglang/pull/13918)
- **EAGLE3 论文**: [Speculative Decoding with EAGLE](https://arxiv.org/abs/2401.15077)

---

##  技术支持

- GitHub Issues: https://github.com/tsaol/qwen3vl-on-aws/issues
- SGLang 文档: https://docs.sglang.ai/
- SGLang GitHub: https://github.com/sgl-project/sglang
