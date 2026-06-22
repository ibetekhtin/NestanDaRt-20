"""
OpenAI-compatible provider — общая реализация для Groq, AiTunnel, OpenRouter.
Все три используют одинаковый API: POST /v1/chat/completions с Bearer-токеном.
"""
import os
import httpx


async def call_openai_compat(
    endpoint: str,
    api_key: str,
    model: str,
    prompt: str,
    system: str = "",
    max_tokens: int = 600,
    temperature: float = 0.85,
    extra_headers: dict | None = None,
) -> str:
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        **(extra_headers or {}),
    }

    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(endpoint, headers=headers, json={
            "model": model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
        })
        r.raise_for_status()
        data = r.json()

    if "error" in data:
        raise RuntimeError(f"API error: {data['error']}")
    choices = data.get("choices") or []
    if not choices:
        raise RuntimeError("Empty response from API")
    return (choices[0].get("message") or {}).get("content", "").strip()
