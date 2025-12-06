#!/usr/bin/env python3
"""
Qwen3-VL API Python 客户端示例
"""
import requests
import sys

API_URL = "http://localhost:8000/v1/chat/completions"
MODEL = "Qwen/Qwen3-VL-8B-Instruct"


def chat(message, system_prompt=None, temperature=0.7, max_tokens=500):
    """
    发送聊天请求到 Qwen3-VL API

    Args:
        message: 用户消息
        system_prompt: 系统提示（可选）
        temperature: 温度参数 (0-1)
        max_tokens: 最大生成 token 数

    Returns:
        AI 回复内容
    """
    messages = []

    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})

    messages.append({"role": "user", "content": message})

    payload = {
        "model": MODEL,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens
    }

    try:
        response = requests.post(API_URL, json=payload, timeout=30)
        response.raise_for_status()
        result = response.json()
        return result['choices'][0]['message']['content']
    except requests.exceptions.RequestException as e:
        print(f"错误: {e}", file=sys.stderr)
        return None


def main():
    print("=== Qwen3-VL 客户端示例 ===\n")

    # 示例 1: 基础对话
    print("1. 基础对话:")
    answer = chat("什么是人工智能？")
    if answer:
        print(f"AI: {answer}\n")

    # 示例 2: 带系统提示
    print("2. 带系统提示的对话:")
    answer = chat(
        message="用简单的话解释量子计算",
        system_prompt="你是一个科普作家，善于用简单的语言解释复杂概念"
    )
    if answer:
        print(f"AI: {answer}\n")

    # 示例 3: 交互模式
    print("3. 交互模式（输入 'quit' 退出）:")
    while True:
        user_input = input("你: ").strip()
        if user_input.lower() in ['quit', 'exit', '退出']:
            break
        if user_input:
            answer = chat(user_input)
            if answer:
                print(f"AI: {answer}\n")


if __name__ == "__main__":
    main()
