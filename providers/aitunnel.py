"""AiTunnel — российский OpenAI-совместимый агрегатор (216+ моделей)"""
import os
from .openai_compat import call_openai_compat


async def call_aitunnel(prompt: str, system: str = "", max_tokens: int = 600, temperature: float = 0.85) -> str:
    return await call_openai_compat(
        endpoint="https://api.aitunnel.ru/v1/chat/completions",
        api_key=os.environ["AITUNNEL_API_KEY"],
        model=os.getenv("AITUNNEL_MODEL", "gemini-2.5-flash"),
        prompt=prompt, system=system, max_tokens=max_tokens, temperature=temperature,
        extra_headers={"HTTP-Referer": "https://nestandart.online", "X-Title": "Nestandart Bot"},
    )
