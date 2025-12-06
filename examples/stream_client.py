#!/usr/bin/env python3
"""
Qwen3-VL 流式响应客户端示例
"""
import requests
import json
import sys

API_URL = "http://localhost:8000/v1/chat/completions"
MODEL = "Qwen/Qwen3-VL-8B-Instruct"


def chat_stream(message, system_prompt=None):
    """
    发送流式聊天请求

    Args:
        message: 用户消息
        system_prompt: 系统提示（可选）

    Yields:
        生成的文本片段
    """
    messages = []

    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})

    messages.append({"role": "user", "content": message})

    payload = {
        "model": MODEL,
        "messages": messages,
        "stream": True,
        "max_tokens": 1000
    }

    try:
        response = requests.post(API_URL, json=payload, stream=True, timeout=30)
        response.raise_for_status()

        for line in response.iter_lines():
            if line:
                line = line.decode('utf-8')
                if line.startswith('data: '):
                    data = line[6:]  # 移除 'data: ' 前缀
                    if data == '[DONE]':
                        break
                    try:
                        json_data = json.loads(data)
                        content = json_data['choices'][0]['delta'].get('content', '')
                        if content:
                            yield content
                    except json.JSONDecodeError:
                        continue

    except requests.exceptions.RequestException as e:
        print(f"\n错误: {e}", file=sys.stderr)


def main():
    print("=== Qwen3-VL 流式响应客户端 ===\n")

    # 示例 1: 流式生成故事
    print("请求: 写一个关于人工智能的短故事\n")
    print("AI: ", end="", flush=True)

    for chunk in chat_stream("写一个关于人工智能的短故事"):
        print(chunk, end="", flush=True)
    print("\n")

    # 示例 2: 流式代码生成
    print("\n请求: 用Python实现一个二分查找算法\n")
    print("AI: ", end="", flush=True)

    for chunk in chat_stream("用Python实现一个二分查找算法，包含注释"):
        print(chunk, end="", flush=True)
    print("\n")


if __name__ == "__main__":
    main()
