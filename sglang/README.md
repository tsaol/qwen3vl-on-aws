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
- **API Key 认证**: 暂不支持（可通过 API Gateway 实现）

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
-  API Key 认证支持

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

A: SGLang 目前不支持原生 API Key 认证。建议使用：
1. Nginx 反向代理 + Basic Auth
2. AWS API Gateway
3. LiteLLM Proxy（推荐）

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

##  技术支持

- GitHub Issues: https://github.com/tsaol/qwen3vl-on-aws/issues
- SGLang 文档: https://docs.sglang.ai/
- SGLang GitHub: https://github.com/sgl-project/sglang
