"""
admin_notify.py — Уведомления менеджеру в Telegram.

Используется для:
- Новый лид
- Новое бронирование
- Эскалация (клиент просит помочь)
- Успешная оплата (ЮKassa)
"""

import os
import httpx


# ── Конфиг ────────────────────────────────────────────────────────────────────
BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
ADMIN_CHAT_ID = os.getenv("TELEGRAM_ADMIN_CHAT_ID") or os.getenv("MANAGER_CHAT_ID", "")
_API = f"https://api.telegram.org/bot{BOT_TOKEN}" if BOT_TOKEN else ""


# ── Внутренняя функция отправки ──────────────────────────────────────────────
async def _send(text: str) -> bool:
    """Отправляет сообщение админу/менеджеру в Telegram."""
    if not _API or not ADMIN_CHAT_ID:
        print(f"[AdminNotify] Пропущено (нет токена/chata): {text[:80]}...")
        return False

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(
                f"{_API}/sendMessage",
                json={"chat_id": ADMIN_CHAT_ID, "text": text, "parse_mode": "HTML"},
            )
            return resp.status_code == 200
    except Exception as e:
        print(f"[AdminNotify] Ошибка отправки: {e}")
        return False


# ── Публичные методы ─────────────────────────────────────────────────────────
class notify:
    """Статический класс уведомлений менеджеру."""

    @staticmethod
    async def new_lead(name: str, source: str = "telegram", telegram: str = "") -> bool:
        """Уведомление о новом лиде."""
        text = (
            "🆕 <b>Новый лид!</b>\n\n"
            f"👤 {name}\n"
            f"📱 Источник: {source}\n"
            f"💬 Telegram: @{telegram}" if telegram else
            f"👤 {name}\n"
            f"📱 Источник: {source}"
        )
        return await _send(text)

    @staticmethod
    async def new_booking(
        tour: str, date: str, people: str, total: str, client: str
    ) -> bool:
        """Уведомление о новом бронировании."""
        text = (
            "📦 <b>Новое бронирование!</b>\n\n"
            f"🏖 Тур: {tour}\n"
            f"📅 Дата: {date}\n"
            f"👥 Людей: {people}\n"
            f"💰 Сумма: {total}\n"
            f"👤 Клиент: {client}"
        )
        return await _send(text)

    @staticmethod
    async def escalation(client: str, chat_id: str, reason: str) -> bool:
        """Уведомление об эскалации — клиент просит менеджера."""
        text = (
            "🚨 <b>Эскалация!</b>\n\n"
            f"👤 Клиент: {client}\n"
            f"💬 Chat ID: {chat_id}\n"
            f"📝 Причина: {reason}\n\n"
            "⚠️ Требуется вмешательство менеджера!"
        )
        return await _send(text)

    @staticmethod
    async def payment_ok(
        tour: str, amount: str, client: str, payment_id: str
    ) -> bool:
        """Уведомление об успешной оплате через ЮKassa."""
        text = (
            "✅ <b>Оплата получена!</b>\n\n"
            f"🏖 Тур: {tour}\n"
            f"💰 Сумма: {amount}\n"
            f"👤 Клиент: {client}\n"
            f"🆔 Платёж: {payment_id}"
        )
        return await _send(text)