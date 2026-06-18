"""
Groq AI Provider — ultra-fast LLM inference
"""
import httpx
import logging
import os

logger = logging.getLogger(__name__)


async def call_groq(
    prompt: str,
    system: str = "",
    max_tokens: int = 600,
    temperature: float = 0.85,
) -> str:
    """
    Вызов через Groq API.
    Модели: llama-3.3-70b, llama-3.1-8b, mixtral и др.
    """
    api_key = os.getenv("GROQ_API_KEY", "")
    model = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")

    if not api_key:
        raise RuntimeError("GROQ_API_KEY не найден в ENV")

    endpoint = "https://api.groq.com/openai/v1/chat/completions"

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
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
            raise RuntimeError(f"Groq error: {data['error']}")

        choices = data.get("choices", [])
        if not choices:
            raise RuntimeError("Groq: пустой ответ")

        text = choices[0].get("message", {}).get("content", "")
        return text.strip()