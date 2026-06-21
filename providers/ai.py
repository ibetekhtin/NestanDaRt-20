"""
AI Providers — конфигурируемая fallback-цепочка.

Порядок по умолчанию (переопределяется env AI_PROVIDER_ORDER):
    groq -> aitunnel -> openrouter -> gemini

  - groq       — бесплатный, ultra-fast (основной)
  - aitunnel   — платный (рубли, aitunnel.ru), OpenAI-совместимый
  - openrouter — платный ($), единый API к множеству моделей
  - gemini     — бесплатный (free-tier), финальный резерв

Каждый провайдер автоматически ПРОПУСКАЕТСЯ, если его API-ключ не задан в ENV,
поэтому цепочка сама подстраивается под то, что реально подключено.
"""
import os
import logging
import time

from .groq import call_groq
from .aitunnel import call_aitunnel
from .openrouter import call_openrouter
from .gemini import call_gemini

logger = logging.getLogger("ai")

FALLBACK_MESSAGE = (
    "🐾 Секунду, я немного перегружен. "
    "Попробуй ещё раз через минуту — я точно помогу!"
)

# name -> (callable, имя env-переменной с ключом)
REGISTRY = {
    "groq": (call_groq, "GROQ_API_KEY"),
    "aitunnel": (call_aitunnel, "AITUNNEL_API_KEY"),
    "openrouter": (call_openrouter, "OPENROUTER_API_KEY"),
    "gemini": (call_gemini, "GEMINI_API_KEY"),
}

DEFAULT_ORDER = "groq,aitunnel,openrouter,gemini"


def _provider_order():
    raw = os.getenv("AI_PROVIDER_ORDER", DEFAULT_ORDER)
    names = [n.strip().lower() for n in raw.split(",") if n.strip()]
    return [n for n in names if n in REGISTRY]


async def ask(prompt: str, system: str = "", max_tokens: int = 600, temperature: float = 0.85) -> str:
    errors = []
    tried = 0
    for name in _provider_order():
        provider, key_env = REGISTRY[name]
        if not os.getenv(key_env, "").strip():
            logger.debug(f"[AI] skip {name}: {key_env} not set")
            continue
        tried += 1
        try:
            logger.info(f"[AI] Trying provider: {name}")
            start = time.time()
            reply = await provider(prompt=prompt, system=system, max_tokens=max_tokens, temperature=temperature)
            latency = int((time.time() - start) * 1000)
            if reply and reply.strip():
                logger.info(f"[AI] {name} responded in {latency}ms")
                return reply.strip()
            logger.warning(f"[AI] {name} returned empty reply after {latency}ms")
        except Exception as e:
            logger.warning(f"[AI] Provider {name} failed: {type(e).__name__}: {e}")
            errors.append(f"{name}({type(e).__name__})")
            continue
    if tried == 0:
        logger.error("[AI] Ни один провайдер не настроен (нет API-ключей в ENV)")
    else:
        logger.error(f"[AI] All providers failed: {chr(44).join(errors)}")
    return FALLBACK_MESSAGE
