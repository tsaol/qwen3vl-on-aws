#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Qwen3-VL 视觉分析测试脚本
使用 vLLM 服务器进行图像分析
"""

import base64
import os
from pathlib import Path
import requests

# 配置
API_BASE_URL = "https://qwen.xcaoliu.com/v1"
MODEL_NAME = "Qwen/Qwen3-VL-8B-Instruct"

# API Key 配置（如果启用了认证）
# 方式 1: 从环境变量读取（推荐）
API_KEY = os.getenv("QWEN_API_KEY")

# 方式 2: 直接设置（不推荐，仅用于测试）
# API_KEY = "sk-qwen-xxx"

# 如果没有设置 API Key，提示用户
if not API_KEY:
    print("⚠️  警告: 未设置 API Key")
    print("   如果服务器启用了认证，请求将失败")
    print("   设置方法: export QWEN_API_KEY='your-api-key'")
    print()

# 用户配置
userLoc = 'Chinese'
userLabels = '{"1":"person", "2":"cat is sleeping", "3":"child"}'

# 定义图片目录
image_dir = "./images"

# 获取目录下所有图片文件
image_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp'}
image_files = [f for f in Path(image_dir).iterdir() 
               if f.suffix.lower() in image_extensions]

print(f"找到 {len(image_files)} 张图片\n")
print("=" * 80)

# 系统提示词
extra_instruction = f"Translation in locale {userLoc} language"
system_prompt = "You are a surveillance image analyst. Analyze images and output ONLY valid JSON."

# 遍历处理每张图片
for idx, image_path in enumerate(image_files, 1):
    print(f"\n处理第 {idx}/{len(image_files)} 张图片: {image_path.name}")
    print("-" * 80)
    
    # 读取并编码图片
    with open(image_path, "rb") as image_file:
        binary_data = image_file.read()
        base64_string = base64.b64encode(binary_data).decode("utf-8")
    
    # 获取图片格式
    image_format = image_path.suffix.lower().replace('.', '')
    if image_format == 'jpg':
        image_format = 'jpeg'
    
    # 构建用户消息（Qwen3-VL 格式）
    user_content = [
        {
            "type": "image_url",
            "image_url": {
                "url": f"data:image/{image_format};base64,{base64_string}"
            }
        },
        {
            "type": "text",
            "text": f"""Analyze this image and output ONLY valid JSON.

## OUTPUT FORMAT (Required)
{{
  "description": "[Concise English description ≤100 chars: natural scene description, avoid unnecessary articles like 'a/an' before person/people/objects]",
  "descriptionExtra": "[{extra_instruction}]",
  "keys": ["matched scene labels from SCENES INPUT only"],
  "risk": "[Safety risk description or empty string]",
  "noDetection": "[Set 'false' if ANY person/animal/vehicle detected, otherwise set 'true']",
  "summary": "[Natural English summary ≤30 chars, conversational tone, capitalize first letter, no punctuation]",
  "summaryExtra": "[{extra_instruction}]"
}}

Locale: {userLoc}
SCENES INPUT: {userLabels}

Examples:
- Image: Man with glasses + INPUT: {{"1":"person wear glasses"}} → keys: ["1"]
- Image: Sleeping cat + INPUT: {{"2":"cat is sleeping", "3":"dog"}} → keys: ["2"]
- Image: Dog playing + INPUT: {{"5":"child"}} → keys: []
"""
        }
    ]
    
    # 构建请求
    payload = {
        "model": MODEL_NAME,
        "messages": [
            {
                "role": "system",
                "content": system_prompt
            },
            {
                "role": "user",
                "content": user_content
            }
        ],
        "max_tokens": 500,
        "temperature": 0.1,
        "top_p": 0.8
    }
    
    try:
        # 构建请求头
        headers = {"Content-Type": "application/json"}

        # 如果配置了 API Key，添加 Authorization header
        if API_KEY:
            headers["Authorization"] = f"Bearer {API_KEY}"

        # 调用 API
        response = requests.post(
            f"{API_BASE_URL}/chat/completions",
            headers=headers,
            json=payload,
            timeout=60
        )
        
        response.raise_for_status()
        result = response.json()
        
        # 提取响应内容
        content = result["choices"][0]["message"]["content"]
        
        print(f"\n[分析结果]")
        print(content)
        
        # 显示 token 使用情况
        if "usage" in result:
            usage = result["usage"]
            print(f"\n[Token 使用]")
            print(f"  输入: {usage.get('prompt_tokens', 0)}")
            print(f"  输出: {usage.get('completion_tokens', 0)}")
            print(f"  总计: {usage.get('total_tokens', 0)}")
        
    except requests.exceptions.RequestException as e:
        print(f"❌ 请求失败: {str(e)}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"响应内容: {e.response.text}")
    except Exception as e:
        print(f"❌ 处理图片时出错: {str(e)}")

print("\n" + "=" * 80)
print(f"\n所有图片处理完成!")
