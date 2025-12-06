# Qwen3-VL API 客户端调用示例

本文档提供多种编程语言的客户端调用示例。

## 基础信息

- **API 端点**: `http://localhost:8000`
- **兼容性**: OpenAI API 格式
- **模型名称**: `Qwen/Qwen3-VL-8B-Instruct`

---

## 1. cURL 命令行

### 基础聊天请求

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [
      {"role": "user", "content": "你好，请介绍一下自己"}
    ],
    "max_tokens": 100
  }'
```

### 带参数的请求

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [
      {"role": "system", "content": "你是一个专业的AI助手"},
      {"role": "user", "content": "解释一下机器学习"}
    ],
    "temperature": 0.7,
    "top_p": 0.8,
    "max_tokens": 500,
    "stream": false
  }'
```

### 流式响应

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-VL-8B-Instruct",
    "messages": [
      {"role": "user", "content": "写一首关于春天的诗"}
    ],
    "stream": true
  }'
```

---

## 2. Python 客户端

### 使用 requests 库

```python
import requests
import json

# API 配置
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

    response = requests.post(API_URL, json=payload)
    response.raise_for_status()

    result = response.json()
    return result['choices'][0]['message']['content']

# 使用示例
if __name__ == "__main__":
    # 基础对话
    answer = chat("什么是人工智能？")
    print(f"AI: {answer}")

    # 带系统提示
    answer = chat(
        message="用简单的话解释量子计算",
        system_prompt="你是一个科普作家，善于用简单的语言解释复杂概念"
    )
    print(f"AI: {answer}")
```

### 使用 OpenAI Python SDK

```python
from openai import OpenAI

# 配置客户端指向本地 vLLM 服务
client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="EMPTY"  # vLLM 不需要 API key
)

# 基础对话
response = client.chat.completions.create(
    model="Qwen/Qwen3-VL-8B-Instruct",
    messages=[
        {"role": "user", "content": "你好，介绍一下你自己"}
    ],
    max_tokens=200
)

print(response.choices[0].message.content)

# 流式响应
stream = client.chat.completions.create(
    model="Qwen/Qwen3-VL-8B-Instruct",
    messages=[
        {"role": "user", "content": "写一个快速排序的 Python 实现"}
    ],
    stream=True,
    max_tokens=500
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
print()
```

### 多轮对话示例

```python
import requests

API_URL = "http://localhost:8000/v1/chat/completions"
MODEL = "Qwen/Qwen3-VL-8B-Instruct"

class ChatSession:
    """多轮对话会话管理"""

    def __init__(self, system_prompt=None):
        self.messages = []
        if system_prompt:
            self.messages.append({"role": "system", "content": system_prompt})

    def send(self, user_message, temperature=0.7, max_tokens=500):
        """发送消息并获取回复"""
        # 添加用户消息
        self.messages.append({"role": "user", "content": user_message})

        # 发送请求
        payload = {
            "model": MODEL,
            "messages": self.messages,
            "temperature": temperature,
            "max_tokens": max_tokens
        }

        response = requests.post(API_URL, json=payload)
        response.raise_for_status()

        # 获取 AI 回复
        ai_message = response.json()['choices'][0]['message']['content']

        # 保存 AI 回复到历史
        self.messages.append({"role": "assistant", "content": ai_message})

        return ai_message

    def clear(self):
        """清空对话历史"""
        self.messages = []

# 使用示例
if __name__ == "__main__":
    session = ChatSession(system_prompt="你是一个编程助手")

    print("用户: 什么是Python装饰器？")
    reply = session.send("什么是Python装饰器？")
    print(f"AI: {reply}\n")

    print("用户: 给我一个例子")
    reply = session.send("给我一个例子")
    print(f"AI: {reply}\n")
```

---

## 3. JavaScript / Node.js 客户端

### 使用 fetch API

```javascript
// chat.js
async function chat(message, options = {}) {
    const {
        systemPrompt = null,
        temperature = 0.7,
        maxTokens = 500,
        stream = false
    } = options;

    const messages = [];

    if (systemPrompt) {
        messages.push({ role: "system", content: systemPrompt });
    }

    messages.push({ role: "user", content: message });

    const response = await fetch("http://localhost:8000/v1/chat/completions", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            model: "Qwen/Qwen3-VL-8B-Instruct",
            messages: messages,
            temperature: temperature,
            max_tokens: maxTokens,
            stream: stream
        })
    });

    if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data.choices[0].message.content;
}

// 使用示例
(async () => {
    try {
        const answer = await chat("什么是机器学习？");
        console.log("AI:", answer);

        const answer2 = await chat(
            "用简单的话解释神经网络",
            { systemPrompt: "你是一个科普作家" }
        );
        console.log("AI:", answer2);
    } catch (error) {
        console.error("Error:", error);
    }
})();
```

### 使用 OpenAI SDK (Node.js)

```javascript
// npm install openai
import OpenAI from 'openai';

const client = new OpenAI({
    baseURL: 'http://localhost:8000/v1',
    apiKey: 'EMPTY'  // vLLM 不需要 API key
});

async function main() {
    // 基础对话
    const response = await client.chat.completions.create({
        model: 'Qwen/Qwen3-VL-8B-Instruct',
        messages: [
            { role: 'user', content: '你好，介绍一下你自己' }
        ],
        max_tokens: 200
    });

    console.log(response.choices[0].message.content);

    // 流式响应
    const stream = await client.chat.completions.create({
        model: 'Qwen/Qwen3-VL-8B-Instruct',
        messages: [
            { role: 'user', content: '写一首关于人工智能的诗' }
        ],
        stream: true
    });

    for await (const chunk of stream) {
        const content = chunk.choices[0]?.delta?.content;
        if (content) {
            process.stdout.write(content);
        }
    }
}

main();
```

---

## 4. 其他编程语言示例

### Go

```go
package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
)

type Message struct {
    Role    string `json:"role"`
    Content string `json:"content"`
}

type ChatRequest struct {
    Model      string    `json:"model"`
    Messages   []Message `json:"messages"`
    MaxTokens  int       `json:"max_tokens"`
    Temperature float64  `json:"temperature"`
}

type ChatResponse struct {
    Choices []struct {
        Message Message `json:"message"`
    } `json:"choices"`
}

func chat(message string) (string, error) {
    url := "http://localhost:8000/v1/chat/completions"

    reqBody := ChatRequest{
        Model: "Qwen/Qwen3-VL-8B-Instruct",
        Messages: []Message{
            {Role: "user", Content: message},
        },
        MaxTokens: 500,
        Temperature: 0.7,
    }

    jsonData, err := json.Marshal(reqBody)
    if err != nil {
        return "", err
    }

    resp, err := http.Post(url, "application/json", bytes.NewBuffer(jsonData))
    if err != nil {
        return "", err
    }
    defer resp.Body.Close()

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return "", err
    }

    var chatResp ChatResponse
    if err := json.Unmarshal(body, &chatResp); err != nil {
        return "", err
    }

    return chatResp.Choices[0].Message.Content, nil
}

func main() {
    answer, err := chat("什么是Go语言？")
    if err != nil {
        fmt.Println("Error:", err)
        return
    }
    fmt.Println("AI:", answer)
}
```

---

## 5. 常用参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `model` | string | 必填 | 模型名称 |
| `messages` | array | 必填 | 消息列表 |
| `temperature` | float | 0.7 | 采样温度 (0-1)，越高越随机 |
| `top_p` | float | 0.8 | 核采样参数 (0-1) |
| `top_k` | int | 20 | Top-K 采样 |
| `max_tokens` | int | - | 最大生成 token 数 |
| `stream` | boolean | false | 是否流式返回 |
| `stop` | array | - | 停止词列表 |
| `presence_penalty` | float | 0 | 存在惩罚 (-2.0 到 2.0) |
| `frequency_penalty` | float | 0 | 频率惩罚 (-2.0 到 2.0) |

---

## 6. 错误处理

### Python 示例

```python
import requests
from requests.exceptions import RequestException

def safe_chat(message):
    try:
        response = requests.post(
            "http://localhost:8000/v1/chat/completions",
            json={
                "model": "Qwen/Qwen3-VL-8B-Instruct",
                "messages": [{"role": "user", "content": message}],
                "max_tokens": 500
            },
            timeout=30  # 30秒超时
        )
        response.raise_for_status()
        return response.json()['choices'][0]['message']['content']

    except requests.exceptions.Timeout:
        return "Error: 请求超时"
    except requests.exceptions.ConnectionError:
        return "Error: 无法连接到服务器"
    except requests.exceptions.HTTPError as e:
        return f"Error: HTTP错误 {e.response.status_code}"
    except Exception as e:
        return f"Error: {str(e)}"

# 使用
result = safe_chat("你好")
print(result)
```

---

## 7. 健康检查

```bash
# 检查服务是否运行
curl http://localhost:8000/health

# 查看可用模型
curl http://localhost:8000/v1/models
```

---

## 8. 性能优化建议

1. **批量请求**: 对于多个独立请求，考虑并发处理
2. **连接复用**: 使用 HTTP 连接池
3. **超时设置**: 设置合理的超时时间
4. **错误重试**: 实现指数退避重试策略
5. **流式响应**: 对于长文本生成，使用 `stream=true`

---

## 9. 远程访问配置

如果需要从其他机器访问 API：

```bash
# 修改 start_server.sh，将服务绑定到所有网络接口
vllm serve $MODEL \
    --host 0.0.0.0 \  # 添加此行
    --port 8000 \
    --max-model-len 1024 \
    --gpu-memory-utilization 0.95
```

然后从其他机器访问：
```bash
curl http://<服务器IP>:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen3-VL-8B-Instruct", "messages": [{"role": "user", "content": "你好"}]}'
```

**注意**: 生产环境建议配置防火墙和认证机制。
