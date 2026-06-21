"""
Payments Router — YooKassa (ЮKassa).

Поток:
  1. POST /api/v1/pay/create  — n8n (после создания брони) запрашивает платёж.
     Сумма считается НА СЕРВЕРЕ из tours.price_adult/price_child × платящих × курс ฿→₽.
     Возвращает confirmation_url (или available=false, если ключи не заданы).
  2. POST /api/v1/pay/webhook — ЮKassa шлёт уведомление об оплате.
     Статус ПЕРЕПРОВЕРЯЕТСЯ запросом к API ЮKassa (не доверяем payload).
     При успехе: payments → succeeded, бронь → 'Оплачено' (через app_upsert_lead),
     клиенту в Telegram уходит подтверждение от КотЭ.

Без YOOKASSA_SHOP_ID/SECRET_KEY всё деградирует мягко: create вернёт available=false,
бот предложит оплату через менеджера. Никаких падений.
"""
import base64
import logging
import uuid
from typing import Optional

import httpx
from fastapi import APIRouter, Request
from pydantic import BaseModel

from config import settings
from db import sb

log = logging.getLogger("kote.payments")
router = APIRouter()

YK_API = "https://api.yookassa.ru/v3/payments"
TIMEOUT = 15.0


def _enabled() -> bool:
    return bool(settings.YOOKASSA_SHOP_ID and settings.YOOKASSA_SECRET_KEY)


def _auth() -> str:
    raw = f"{settings.YOOKASSA_SHOP_ID}:{settings.YOOKASSA_SECRET_KEY}".encode()
    return "Basic " + base64.b64encode(raw).decode()


class PayCreate(BaseModel):
    external_id: str            # external_id брони (ключ)
    tour_slug: str
    adults: int = 1
    children: int = 0
    name: Optional[str] = None
    tg_chat_id: Optional[str] = None


def _amount_rub(tour: dict, adults: int, children: int) -> int:
    pa = int(tour.get("price_adult") or 0)
    pc = tour.get("price_child")
    pc = int(pc) if pc is not None else pa
    baht = pa * max(adults, 0) + pc * max(children, 0)
    return round(baht * settings.YOOKASSA_BAHT_TO_RUB)


@router.post("/pay/create")
async def pay_create(body: PayCreate):
    # 1) цена тура из БД (источник истины)
    try:
        tr = sb.table("tours").select("price_adult,price_child,title").eq("slug", body.tour_slug).limit(1).execute()
    except Exception as e:
        log.warning("tours lookup failed: %s", e)
        return {"available": False, "reason": "tour_lookup_failed"}
    if not tr.data:
        return {"available": False, "reason": "tour_not_found"}
    tour = tr.data[0]
    amount = _amount_rub(tour, body.adults, body.children)
    if amount <= 0:
        return {"available": False, "reason": "zero_amount"}

    # 2) booking_id по external_id
    booking_id = None
    try:
        bk = sb.table("bookings").select("id").eq("external_id", body.external_id).limit(1).execute()
        if bk.data:
            booking_id = bk.data[0]["id"]
    except Exception as e:
        log.warning("booking lookup failed: %s", e)

    if not _enabled():
        log.info("YooKassa keys not set — graceful skip")
        return {"available": False, "reason": "not_configured", "amount_rub": amount}

    # 3) платёж в ЮKassa
    desc = f"{tour.get('title') or body.tour_slug} — {body.name or 'бронь'}"[:128]
    payload = {
        "amount": {"value": f"{amount:.2f}", "currency": "RUB"},
        "capture": True,
        "confirmation": {"type": "redirect", "return_url": settings.YOOKASSA_RETURN_URL or "https://nestandart.online/"},
        "description": desc,
        "metadata": {"external_id": body.external_id, "booking_id": booking_id or "", "tg_chat_id": body.tg_chat_id or ""},
    }
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as cli:
            r = await cli.post(YK_API, json=payload, headers={
                "Authorization": _auth(),
                "Idempotence-Key": str(uuid.uuid4()),
                "Content-Type": "application/json",
            })
        r.raise_for_status()
        pay = r.json()
    except Exception as e:
        log.error("YooKassa create failed: %s", e)
        return {"available": False, "reason": "yookassa_error", "amount_rub": amount}

    url = (pay.get("confirmation") or {}).get("confirmation_url")
    # 4) записать платёж
    try:
        sb.table("payments").insert({
            "booking_id": booking_id,
            "provider": "yookassa",
            "payment_id": pay.get("id"),
            "amount": amount,
            "currency": "RUB",
            "status": pay.get("status", "pending"),
            "confirmation_url": url,
        }).execute()
    except Exception as e:
        log.warning("payments insert failed: %s", e)

    return {"available": True, "confirmation_url": url, "amount_rub": amount, "payment_id": pay.get("id")}


async def _notify_client(tg_chat_id: str, text: str) -> None:
    token = settings.TELEGRAM_BOT_TOKEN
    if not (token and tg_chat_id):
        return
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as cli:
            await cli.post(f"https://api.telegram.org/bot{token}/sendMessage",
                           json={"chat_id": tg_chat_id, "text": text, "parse_mode": "HTML"})
    except Exception as e:
        log.warning("telegram notify failed: %s", e)


@router.post("/pay/webhook")
async def pay_webhook(request: Request):
    # ЮKassa шлёт {event, object:{id,status,metadata}}. Статус перепроверяем у API.
    try:
        body = await request.json()
    except Exception:
        return {"ok": True}
    obj = (body or {}).get("object") or {}
    pay_id = obj.get("id")
    if not pay_id or not _enabled():
        return {"ok": True}

    # перепроверка статуса напрямую у ЮKassa (не доверяем payload)
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as cli:
            r = await cli.get(f"{YK_API}/{pay_id}", headers={"Authorization": _auth()})
        r.raise_for_status()
        pay = r.json()
    except Exception as e:
        log.error("YooKassa verify failed: %s", e)
        return {"ok": True}

    if pay.get("status") != "succeeded":
        return {"ok": True}

    meta = pay.get("metadata") or {}
    ext = meta.get("external_id")
    chat = meta.get("tg_chat_id")

    # payments → succeeded
    try:
        sb.table("payments").update({"status": "succeeded", "paid_at": "now()"}).eq("payment_id", pay_id).execute()
    except Exception as e:
        log.warning("payments update failed: %s", e)

    # бронь → 'Оплачено' через санкционированный RPC (не прямой UPDATE)
    if ext:
        try:
            sb.rpc("app_upsert_lead", {"p_external_id": ext, "p_status": "Оплачено"}).execute()
        except Exception as e:
            log.warning("mark paid failed: %s", e)

    await _notify_client(chat, "Мур-р-р, оплата прошла! 🐾 Бронь подтверждена — ждём тебя на экскурсии. Хорошего отдыха! 😸")
    return {"ok": True}
