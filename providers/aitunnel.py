"""
AITUNNEL AI Provider — российский API-агрегатор (OpenAI-совместимый)
216+ моделей: GPT, Claude, Gemini, DeepSeek, Groq и др.
Endpoint: https://api.aitunnel.ru/v1/chat/completions
"""
import httpx
import logging
import os

logger = logging.getLogger(__name__)


async def call_aitunnel(
    prompt: str,
    system: str = "",
    max_tokens: int = 600,
    temperature: float = 0.85,
) -> str:
    """
    Вызов через AITUNNEL API (OpenAI-совместимый).
    Доступные модели: gemini-2.5-flash, gpt-4o-mini, deepseek-chat,
    claude-haiku-4.5 и 200+ других.
    """
    api_key = os.getenv("AITUNNEL_API_KEY", "")
    model = os.getenv("AITUNNEL_MODEL", "gemini-2.5-flash")

    if not api_key:
        raise RuntimeError("AITUNNEL_API_KEY не найден в ENV")

    endpoint = "https://api.aitunnel.ru/v1/chat/completions"

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://nestandart.online",
        "X-Title": "KoteE Bot",
    }

    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
    }

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(endpoint, headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()

        if "error" in data:
            raise RuntimeError(f"AITUNNEL error: {data['error']}")

        choices = data.get("choices", [])
        if not choices:
            raise RuntimeError("AITUNNEL: пустой ответ")

        text = choices[0].get("message", {}).get("content", "")
        return text.strip()