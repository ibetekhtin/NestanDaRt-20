"""
OpenRouter AI Provider — единый API для разных моделей
"""
import httpx
import logging
import os

logger = logging.getLogger(__name__)


async def call_openrouter(
    prompt: str,
    system: str = "",
    max_tokens: int = 600,
    temperature: float = 0.85,
) -> str:
    """
    Вызов через OpenRouter API.
    Поддерживает любые модели (Gemini, Claude, Llama, etc.)
    """
    api_key = os.getenv("OPENROUTER_API_KEY", "")
    model = os.getenv(
        "OPENROUTER_MODEL", "google/gemini-2.0-flash-exp:free"
    )

    if not api_key:
        raise RuntimeError("OPENROUTER_API_KEY не найден в ENV")

    endpoint = "https://openrouter.ai/api/v1/chat/completions"

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://nestandart.online",
        "X-Title": "KOTЭ Bot",
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
            raise RuntimeError(f"OpenRouter error: {data['error']}")

        choices = data.get("choices", [])
        if not choices:
            raise RuntimeError("OpenRouter: пустой ответ")

        text = choices[0].get("message", {}).get("content", "")
        return text.strip()