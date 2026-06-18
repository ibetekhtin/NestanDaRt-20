"""
AI Providers — fallback chain: Gemini → OpenRouter → Groq
"""
import os
import logging
import time
from typing import Optional

from .gemini import call_gemini
from .openrouter import call_openrouter
from .groq import call_groq

logger = logging.getLogger("ai")

FALLBACK_MESSAGE = (
    "🐾 Секунду, я немного перегружен. "
    "Попробуй ещё раз через минуту — я точно помогу!"
)

PROVIDERS = [
    ("gemini", call_gemini),
    ("openrouter", call_openrouter),
    ("groq", call_groq),
]


async def ask(
    prompt: str,
    system: str = "",
    max_tokens: int = 600,
    temperature: float = 0.85,
) -> str:
    """
    Универсальный вызов AI с fallback chain.

    Args:
        prompt: Пользовательский запрос
        system: Системный промпт
        max_tokens: Максимальное количество токенов
        temperature: Креативность (0.0 — детерминированный, 1.0 — креативный)

    Returns:
        Текст ответа или FALLBACK_MESSAGE
    """
    errors = []

    for name, provider in PROVIDERS:
        try:
            logger.info(f"[AI] Trying provider: {name}")
            start = time.time()

            reply = await provider(
                prompt=prompt,
                system=system,
                max_tokens=max_tokens,
                temperature=temperature,
            )

            latency = int((time.time() - start) * 1000)
            logger.info(f"[AI] {name} responded in {latency}ms")

            if reply and reply.strip():
                return reply.strip()

        except Exception as e:
            logger.warning(f"[AI] Provider {name} failed: {e}")
            errors.append(f"{name}({type(e).__name__})")
            continue

    # Все провайдеры упали
    logger.error(f"[AI] All providers failed: {', '.join(errors)}")
    return FALLBACK_MESSAGE