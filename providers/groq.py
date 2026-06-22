"""Groq — ultra-fast LLM inference (llama-3.3-70b по умолчанию)"""
import os
from .openai_compat import call_openai_compat


async def call_groq(prompt: str, system: str = "", max_tokens: int = 600, temperature: float = 0.85) -> str:
    return await call_openai_compat(
        endpoint="https://api.groq.com/openai/v1/chat/completions",
        api_key=os.environ["GROQ_API_KEY"],
        model=os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile"),
        prompt=prompt, system=system, max_tokens=max_tokens, temperature=temperature,
    )
