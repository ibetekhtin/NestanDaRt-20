"""OpenRouter — единый API для множества моделей, поддерживает online-поиск"""
import os
from .openai_compat import call_openai_compat


async def call_openrouter(
    prompt: str, system: str = "", max_tokens: int = 600, temperature: float = 0.85, online: bool = False
) -> str:
    model = os.getenv("OPENROUTER_MODEL", "google/gemini-2.5-flash-lite")
    if online:
        model = os.getenv("OPENROUTER_ONLINE_MODEL", model + ":online")
    return await call_openai_compat(
        endpoint="https://openrouter.ai/api/v1/chat/completions",
        api_key=os.environ["OPENROUTER_API_KEY"],
        model=model,
        prompt=prompt, system=system, max_tokens=max_tokens, temperature=temperature,
        extra_headers={"HTTP-Referer": "https://nestandart.online", "X-Title": "Nestandart Bot"},
    )
