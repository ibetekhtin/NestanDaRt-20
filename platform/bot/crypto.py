"""
crypto.py — Криптовалютная оплата через NOWPayments.

Один API-ключ. Клиент на странице оплаты сам выбирает монету:
TON, USDT, USDC, BTC, ETH и 300+ других. Цена считается от USD.

Активируется, когда в .env заданы:
  NOWPAYMENTS_API_KEY      — ключ API (account.nowpayments.io → Settings → API keys)
  NOWPAYMENTS_IPN_SECRET   — секрет для проверки вебхуков (IPN)

Пока ключей нет — create_invoice() возвращает None, крипто-вариант не показывается.
"""

import hashlib
import hmac
import json
import logging
import os

import httpx

log = logging.getLogger("kote.crypto")

API_KEY = os.getenv("NOWPAYMENTS_API_KEY", "")
IPN_SECRET = os.getenv("NOWPAYMENTS_IPN_SECRET", "")
IPN_URL = os.getenv("NOWPAYMENTS_IPN_URL", "https://nestandart.online/bot/crypto")
SUCCESS_URL = os.getenv("NOWPAYMENTS_SUCCESS_URL", "https://nestandart.online/phuket/")
API = "https://api.nowpayments.io/v1"
TIMEOUT = 15.0

# Монеты, которые показываем/принимаем (клиент выберет любую на странице).
# Чем больше — тем лучше: стейблы, мейнстрим, TON.
COINS = ["ton", "usdttrc20", "usdtbsc", "usdc", "btc", "eth", "usdtsol", "trx", "bnb", "ltc", "sol"]


def enabled() -> bool:
    return bool(API_KEY)


async def create_invoice(
    amount_usd: float,
    order_id: str,
    description: str,
) -> dict | None:
    """
    Создаёт крипто-инвойс. Возвращает {"invoice_id", "invoice_url"} или None.
    Клиент сам выбирает монету (TON/USDT/USDC/BTC/ETH…) на странице NOWPayments.
    """
    if not enabled():
        log.info("NOWPayments не настроен — пропускаю крипто-инвойс")
        return None

    body = {
        "price_amount": round(amount_usd, 2),
        "price_currency": "usd",
        "order_id": order_id,
        "order_description": description[:200],
        "ipn_callback_url": IPN_URL,
        "success_url": SUCCESS_URL,
        "cancel_url": SUCCESS_URL,
    }
    headers = {"x-api-key": API_KEY, "Content-Type": "application/json"}

    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            r = await client.post(f"{API}/invoice", headers=headers, json=body)
        if r.status_code in (200, 201):
            d = r.json()
            return {"invoice_id": str(d.get("id")), "invoice_url": d.get("invoice_url")}
        log.warning(f"NOWPayments HTTP {r.status_code}: {r.text[:200]}")
        return None
    except Exception as e:
        log.warning(f"NOWPayments error: {e}")
        return None


def verify_ipn(raw_body: bytes, signature: str) -> bool:
    """Проверка подписи IPN (HMAC-SHA512 по отсортированному JSON с IPN-секретом)."""
    if not IPN_SECRET or not signature:
        return False
    try:
        data = json.loads(raw_body)
        sorted_json = json.dumps(data, sort_keys=True, separators=(",", ":"))
        digest = hmac.new(
            IPN_SECRET.encode(), sorted_json.encode(), hashlib.sha512
        ).hexdigest()
        return hmac.compare_digest(digest, signature)
    except Exception as e:
        log.warning(f"IPN verify error: {e}")
        return False


# Статусы NOWPayments, означающие успешную оплату
PAID_STATUSES = {"finished", "confirmed", "sending", "partially_paid"}
