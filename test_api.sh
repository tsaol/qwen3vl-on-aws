#!/bin/bash

# 测试 vLLM API
PORT=${PORT:-8000}

echo "========================================"
echo "测试 Qwen3-VL API"
echo "========================================"
echo "API 地址: http://localhost:$PORT"
echo ""

# 测试健康检查
echo "1️⃣ 健康检查..."
curl -s http://localhost:$PORT/health | jq . || echo "服务未启动或 jq 未安装"
echo ""

# 测试聊天补全
echo "2️⃣ 聊天补全测试..."
curl -s http://localhost:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [
      {"role": "user", "content": "你好，请用一句话介绍你自己"}
    ],
    "max_tokens": 100
  }' | jq . || echo "请求失败"

echo ""
echo "✅ 测试完成"
