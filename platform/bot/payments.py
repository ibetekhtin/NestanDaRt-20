"""
payments.py — Платежи через ЮKassa (YooKassa).

Активируется автоматически, как только в .env заданы:
  YOOKASSA_SHOP_ID
  YOOKASSA_SECRET_KEY

Пока ключей нет — create_payment() возвращает None, и бот предлагает
оплату через менеджера / сайт / приложение (как удобнее клиенту).
"""

import base64
import logging
import os
import uuid

import httpx

log = logging.getLogger("kote.payments")

SHOP_ID = os.getenv("YOOKASSA_SHOP_ID", "")
SECRET_KEY = os.getenv("YOOKASSA_SECRET_KEY", "")
RETURN_URL = os.getenv("YOOKASSA_RETURN_URL", "https://nestandart.online/phuket/")
API_URL = "https://api.yookassa.ru/v3/payments"
TIMEOUT = 15.0


def enabled() -> bool:
    """True, если ЮKassa настроена (есть ключи)."""
    return bool(SHOP_ID and SECRET_KEY)


def _auth_header() -> str:
    raw = f"{SHOP_ID}:{SECRET_KEY}".encode()
    return "Basic " + base64.b64encode(raw).decode()


async def create_payment(
    amount: int,
    description: str,
    metadata: dict | None = None,
    return_url: str | None = None,
    currency: str = "RUB",
) -> dict | None:
    """
    Создаёт платёж в ЮKassa и возвращает:
      {"payment_id": str, "confirmation_url": str, "status": str}
    или None, если ключей нет / ошибка.
    amount — в валюте `currency` (RUB/KZT), уже сконвертированной из батов.
    """
    if not enabled():
        log.info("ЮKassa не настроена — пропускаю создание платежа")
        return None

    body = {
        "amount": {"value": f"{amount:.2f}", "currency": currency},
        "capture": True,
        "confirmation": {
            "type": "redirect",
            "return_url": return_url or RETURN_URL,
        },
        "description": description[:128],
        "metadata": metadata or {},
    }
    headers = {
        "Authorization": _auth_header(),
        "Idempotence-Key": str(uuid.uuid4()),
        "Content-Type": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            r = await client.post(API_URL, headers=headers, json=body)
        if r.status_code in (200, 201):
            d = r.json()
            return {
                "payment_id": d.get("id"),
                "confirmation_url": d.get("confirmation", {}).get("confirmation_url"),
                "status": d.get("status"),
            }
        log.warning(f"ЮKassa HTTP {r.status_code}: {r.text[:200]}")
        return None
    except Exception as e:
        log.warning(f"ЮKassa error: {e}")
        return None


def verify_webhook_ip(remote_ip: str) -> bool:
    """
    Проверка, что вебхук пришёл из подсети ЮKassa.
    Список сетей: https://yookassa.ru/developers/using-api/webhooks
    """
    import ipaddress
    allowed = [
        "185.71.76.0/27", "185.71.77.0/27", "77.75.153.0/25",
        "77.75.156.11/32", "77.75.156.35/32", "77.75.154.128/25",
        "2a02:5180::/32",
    ]
    try:
        ip = ipaddress.ip_address(remote_ip)
        return any(ip in ipaddress.ip_network(net) for net in allowed)
    except Exception:
        return False
