"""Безопасная отправка в Telegram: guard токена/чата + обработка ошибок.

Единый хелпер вместо разрозненных _tg_send/_notify реализаций.
"""
import logging
from typing import Optional

import httpx

from config import settings

log = logging.getLogger("nestandart.notify")


async def tg_send(chat_id: Optional[str], text: str, parse_mode: Optional[str] = None) -> bool:
    """Шлёт сообщение в Telegram. Возвращает True при успехе, никогда не бросает."""
    token = settings.TELEGRAM_BOT_TOKEN
    if not (token and chat_id):
        return False
    payload = {"chat_id": chat_id, "text": text}
    if parse_mode:
        payload["parse_mode"] = parse_mode
    try:
        async with httpx.AsyncClient(timeout=10) as cli:
            await cli.post(f"https://api.telegram.org/bot{token}/sendMessage", json=payload)
        return True
    except Exception as e:  # noqa: BLE001 — отправка уведомления не должна ронять запрос
        log.warning("telegram send failed: %s", e)
        return False


async def notify_manager(text: str, parse_mode: Optional[str] = "HTML") -> bool:
    return await tg_send(settings.MANAGER_CHAT_ID, text, parse_mode)
