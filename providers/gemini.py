"""
Gemini AI Provider — прямой вызов через REST API
"""
import httpx
import logging
import time
import os

logger = logging.getLogger(__name__)


async def call_gemini(
    prompt: str,
    system: str = "",
    max_tokens: int = 600,
    temperature: float = 0.85,
) -> str:
    """
    Вызов Gemini через REST API.
    """
    api_key = os.getenv("GEMINI_API_KEY", "")
    model = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")

    if not api_key:
        raise RuntimeError("GEMINI_API_KEY не найден в ENV")

    endpoint = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent?key={api_key}"
    )

    payload = {
        "systemInstruction": {"parts": [{"text": system}]},
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": temperature,
            "maxOutputTokens": max_tokens,
            "topP": 0.95,
        },
    }

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(endpoint, json=payload)
        response.raise_for_status()
        data = response.json()

        if data.get("error"):
            code = data["error"].get("code") or data["error"].get("status", "")
            if code in (429, "RESOURCE_EXHAUSTED"):
                raise RuntimeError(f"Rate limited: {code}")
            raise RuntimeError(f"Gemini error: {data['error']}")

        text = (
            data.get("candidates", [{}])[0]
            .get("content", {})
            .get("parts", [{}])[0]
            .get("text", "")
        )

        return text.strip()