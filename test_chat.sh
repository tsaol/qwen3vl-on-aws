#!/bin/bash

# 测试 Qwen3-VL-8B-Instruct 视觉分析接口
echo "测试 Qwen3-VL-8B-Instruct 视觉分析接口..."
echo "=========================================="

# 配置
IMAGE_PATH="./images/1.jpg"
USER_LOC="Chinese"
USER_LABELS='{"1":"person wear glasses", "2":"cat is sleeping", "3":"child"}'

# 检查图片是否存在
if [ ! -f "$IMAGE_PATH" ]; then
    echo "错误: 图片文件不存在: $IMAGE_PATH"
    exit 1
fi

# 读取并编码图片为 base64
BASE64_IMAGE=$(base64 -i "$IMAGE_PATH")

# 获取图片格式
IMAGE_EXT="${IMAGE_PATH##*.}"
IMAGE_FORMAT="${IMAGE_EXT,,}"
if [ "$IMAGE_FORMAT" = "jpg" ]; then
    IMAGE_FORMAT="jpeg"
fi

# 构建 prompt
EXTRA_INSTRUCTION="Translation in locale ${USER_LOC} language"

curl -s https://qwen.xcaoliu.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [
      {
        "role": "system",
        "content": "You are a surveillance image analyst. Analyze images and output ONLY valid JSON."
      },
      {
        "role": "user",
        "content": [
          {
            "type": "image_url",
            "image_url": {
              "url": "data:image/'"$IMAGE_FORMAT"';base64,'"$BASE64_IMAGE"'"
            }
          },
          {
            "type": "text",
            "text": "Analyze this image and output ONLY valid JSON.\n\n## OUTPUT FORMAT (Required)\n{\n  \"description\": \"[Concise English description ≤100 chars: natural scene description, avoid unnecessary articles like a/an before person/people/objects]\",\n  \"descriptionExtra\": \"['"$EXTRA_INSTRUCTION"']\",\n  \"keys\": [\"matched scene labels from SCENES INPUT only\"],\n  \"risk\": \"[Safety risk description or empty string]\",\n  \"noDetection\": \"[Set false if ANY person/animal/vehicle detected, otherwise set true]\",\n  \"summary\": \"[Natural English summary ≤30 chars, conversational tone, capitalize first letter, no punctuation]\",\n  \"summaryExtra\": \"['"$EXTRA_INSTRUCTION"']\"\n}\n\n## CRITICAL RULES\n1. keys Matching: Match image against SCENES INPUT descriptions, return corresponding key IDs only\n   - If SCENES INPUT is empty or uncertain → return \"keys\": []\n   - NEVER create new keys not in SCENES INPUT\n\n2. Language: Keep description/summary in English\n\n3. Style: Use \"person\" not \"a person\", be concise and direct\n\nLocale: '"$USER_LOC"'\nSCENES INPUT: '"$USER_LABELS"'\n\nExamples:\n- Image: Man with glasses + INPUT: {\"1\":\"person wear glasses\"} → keys: [\"1\"]\n- Image: Sleeping cat + INPUT: {\"2\":\"cat is sleeping\", \"3\":\"dog\"} → keys: [\"2\"]\n- Image: Dog playing + INPUT: {\"5\":\"child\"} → keys: []"
          }
        ]
      }
    ],
    "max_tokens": 3000,
    "temperature": 0.1,
    "top_p": 0.8
  }' | jq . || echo "请求失败"
