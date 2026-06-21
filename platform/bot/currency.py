"""
currency.py — Конвертация цен из БАТОВ (THB, базовая валюта каталога)
в валюту счёта клиента: RUB (рубли) или KZT (тенге).

Курс берётся живой (open.er-api.com, без ключа), кэш на 1 час,
с фолбэком на константы из .env. Можно задать фиксированный курс и наценку.

ENV:
  THB_RUB_RATE   — фикс. курс THB→RUB (если задан — используется как есть)
  THB_KZT_RATE   — фикс. курс THB→KZT
  FX_MARKUP      — множитель-наценка на ЖИВОЙ курс (например 1.05 = +5%); по умолч. 1.0
"""

import logging
import os
import time

import httpx

log = logging.getLogger("kote.currency")

SUPPORTED = ("RUB", "KZT", "USD")  # валюты счёта (USD — для крипто-оплаты)
SYMBOL = {"RUB": "₽", "KZT": "₸", "THB": "฿", "USD": "$"}
NAME_RU = {"RUB": "руб.", "KZT": "тенге", "THB": "бат", "USD": "USD"}

# Фолбэк-курсы (если интернет недоступен). RUB=3.0 — как на сайте (2500฿→7500₽).
_FALLBACK = {
    "RUB": float(os.getenv("THB_RUB_RATE") or 3.0),
    "KZT": float(os.getenv("THB_KZT_RATE") or 15.0),
    "USD": float(os.getenv("THB_USD_RATE") or 0.03),
}
_MARKUP = float(os.getenv("FX_MARKUP") or 1.0)
_FIXED = {
    "RUB": os.getenv("THB_RUB_RATE"),
    "KZT": os.getenv("THB_KZT_RATE"),
    "USD": os.getenv("THB_USD_RATE"),
}

_API = "https://open.er-api.com/v6/latest/THB"
_CACHE: dict = {"rates": None, "ts": 0.0}
_TTL = 3600  # 1 час


async def _live_rates() -> dict | None:
    now = time.time()
    if _CACHE["rates"] and now - _CACHE["ts"] < _TTL:
        return _CACHE["rates"]
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            r = await client.get(_API)
        if r.status_code == 200:
            data = r.json()
            rates = data.get("rates") or {}
            if rates:
                _CACHE["rates"] = rates
                _CACHE["ts"] = now
                return rates
    except Exception as e:
        log.warning(f"FX live error: {e}")
    return None


async def get_rate(target: str) -> float:
    """Курс THB→target. Фикс. из .env > живой×наценка > фолбэк."""
    target = target.upper()
    if target == "THB":
        return 1.0
    if target not in SUPPORTED:
        target = "RUB"
    # 1) фиксированный курс из .env
    if _FIXED.get(target):
        try:
            return float(_FIXED[target])
        except ValueError:
            pass
    # 2) живой курс × наценка
    rates = await _live_rates()
    if rates and target in rates:
        return float(rates[target]) * _MARKUP
    # 3) фолбэк
    return _FALLBACK.get(target, 3.0)


async def convert(amount_thb: float, target: str) -> int:
    """Переводит баты в target. Рубли/тенге — до 10, USD — до целого доллара."""
    rate = await get_rate(target)
    val = amount_thb * rate
    if target.upper() == "USD":
        return int(round(val))
    return int(round(val / 10.0) * 10)


def fmt(amount: int, currency: str) -> str:
    """'7 500 ₽' — с разделителем тысяч."""
    sym = SYMBOL.get(currency.upper(), currency)
    return f"{amount:,}".replace(",", " ") + f" {sym}"


def fmt_thb(amount_thb: int) -> str:
    return f"{amount_thb:,}".replace(",", " ") + " ฿"
