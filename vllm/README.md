# vLLM 部署方式

基于 vLLM 推理框架部署 Qwen3-VL-8B-Instruct 视觉语言模型。

## 🎯 特点

- **PagedAttention**: 细粒度内存管理，高效的 KV Cache
- **高吞吐量**: 适合批量推理和高并发场景
- **成熟稳定**: 生产环境广泛使用
- **OpenAI 兼容**: 完全兼容 OpenAI API 格式

## 📋 配置参数

- **端口**: 8000
- **最大上下文长度**: 1,024 tokens（默认）
- **GPU 显存利用率**: 0.95
- **API Key 认证**: 支持

## 🚀 快速部署

### 1. 部署 vLLM

```bash
cd vllm
bash deploy.sh
```

脚本会自动：
- ✅ 检查 GPU 环境
- ✅ 安装 Python 3.10
- ✅ 创建虚拟环境 `.venv`
- ✅ 安装 vLLM 和依赖
- ✅ 下载模型到缓存

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
sudo systemctl start qwen3vl      # 启动
sudo systemctl stop qwen3vl       # 停止
sudo systemctl restart qwen3vl    # 重启
sudo systemctl status qwen3vl     # 查看状态
sudo journalctl -u qwen3vl -f     # 查看日志
```

## 🔒 API Key 配置

生成并配置 API Key：

```bash
# 生成密钥
python3 -c "import secrets; print(f'sk-qwen-{secrets.token_urlsafe(32)}')"

# 更新配置
bash update_apikey.sh <your-api-key>
```

## 🔧 自定义配置

编辑 `start_server.sh` 修改启动参数：

```bash
# 最大上下文长度（默认 1024）
MAX_MODEL_LEN=${MAX_MODEL_LEN:-1024}

# 修改为更大的值以支持长文本
MAX_MODEL_LEN=${MAX_MODEL_LEN:-32768}   # 32K
MAX_MODEL_LEN=${MAX_MODEL_LEN:-262144}  # 256K (模型最大能力)

# GPU 显存利用率（默认 0.95）
GPU_MEMORY_UTIL=${GPU_MEMORY_UTIL:-0.95}

# 端口（默认 8000）
PORT=${PORT:-8000}
```

## 📊 性能特点

| 场景 | 表现 |
|------|------|
| 短对话 | ⭐⭐⭐⭐⭐ 优秀 |
| 批量推理 | ⭐⭐⭐⭐⭐ 优秀 |
| 高并发 | ⭐⭐⭐⭐⭐ 优秀 |
| 长文档 | ⭐⭐⭐ 需配置 max-model-len |
| 视频理解 | ⭐⭐⭐ 需配置 max-model-len |

## 🧪 测试 API

```bash
# 健康检查
curl http://localhost:8000/health

# 查看模型
curl http://localhost:8000/v1/models

# 聊天完成（需要 API Key）
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [{"role": "user", "content": "你好"}]
  }'
```

## 📁 文件说明

- `deploy.sh` - 部署脚本，安装 vLLM 环境
- `start_server.sh` - 启动 vLLM 服务器
- `qwen3vl.service` - systemd 服务配置文件
- `install_service.sh` - 安装 systemd 服务
- `update_apikey.sh` - 更新 API Key 配置

## 🆚 与 SGLang 对比

选择 vLLM 如果你需要：
- ✅ 更高的批量推理吞吐量
- ✅ 更成熟稳定的生产环境
- ✅ 更好的高并发支持
- ✅ 更少的显存占用（相同配置下）

选择 SGLang 如果你需要：
- ✅ 更快的首 token 延迟
- ✅ 更好的多轮对话性能
- ✅ 更高效的 KV Cache 复用
- ✅ 原生支持模型最大上下文（256K）

## 📚 更多文档

- [客户端使用示例](../docs/client_examples.md)
- [高可用部署方案](../docs/GPU_HIGH_AVAILABILITY.md)
- [LiteLLM 网关方案](../docs/LITELLM_HA_SOLUTIONS.md)
- [Python 示例代码](../examples/)

## ⚠️ 常见问题

### Q: 为什么默认 max-model-len 只有 1024？

A: 这是一个保守的默认值，确保在各种 GPU 上都能运行。Qwen3-VL 实际支持 256K tokens，你可以根据 GPU 显存调整这个值。

### Q: 如何支持更长的上下文？

A: 修改 `start_server.sh` 中的 `MAX_MODEL_LEN` 参数，然后重启服务：
```bash
MAX_MODEL_LEN=262144  # 256K
```

### Q: API Key 存储在哪里？

A: API Key 配置在 systemd 服务文件 `qwen3vl.service` 的 `ExecStart` 参数中。

### Q: 如何切换到 SGLang？

A: 使用迁移工具：
```bash
cd ..
bash tools/migrate_to_sglang.sh
```

## 📞 技术支持

- GitHub Issues: https://github.com/tsaol/qwen3vl-on-aws/issues
- vLLM 文档: https://docs.vllm.ai/
