"""
Payments Router — YooKassa (ЮKassa). Закалённая версия.

Поток:
  1. POST /api/v1/pay/create  — n8n запрашивает платёж по существующей брони.
     Сумма считается НА СЕРВЕРЕ из tours.price_adult/price_child × платящих × курс ฿→₽.
     Идемпотентно: повторный вызов по той же брони не плодит платежи (переиспользует pending).
  2. POST /api/v1/pay/webhook — ЮKassa шлёт уведомление. Статус ПЕРЕПРОВЕРЯЕТСЯ у API.
     Сверяется СУММА+валюта с ожидаемой. Обрабатываются succeeded / canceled / refund.
     При расхождении/осиротевшей оплате — алерт менеджеру, бронь НЕ помечается.
  3. POST /api/v1/pay/reconcile — (n8n по расписанию) ищет зависшие pending и оплаты без брони.

Без ключей YooKassa всё деградирует мягко (create → available=false). Секрет-гейт fail-closed.
"""
import base64
import hashlib
import logging
from decimal import Decimal, InvalidOperation
from datetime import datetime, timezone
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel

from auth import require_secret
from config import settings
from db import sb

log = logging.getLogger("nestandart.payments")
router = APIRouter()

YK_API = "https://api.yookassa.ru/v3/payments"
TIMEOUT = 15.0


def _enabled() -> bool:
    return bool(settings.YOOKASSA_SHOP_ID and settings.YOOKASSA_SECRET_KEY)


def _auth() -> str:
    raw = f"{settings.YOOKASSA_SHOP_ID}:{settings.YOOKASSA_SECRET_KEY}".encode()
    return "Basic " + base64.b64encode(raw).decode()


class PayCreate(BaseModel):
    external_id: str
    tour_slug: str
    adults: int = 1
    children: int = 0
    name: Optional[str] = None
    tg_chat_id: Optional[str] = None


def _amount_rub(tour: dict, adults: int, children: int) -> int:
    pa = int(tour.get("price_adult") or 0)
    pc = tour.get("price_child")
    pc = int(pc) if pc is not None else pa   # NULL ребёнок = цена взрослого
    baht = pa * max(adults, 0) + pc * max(children, 0)
    rate = settings.YOOKASSA_BAHT_TO_RUB
    if not rate or rate <= 0:               # B7: валидация курса
        log.error("YOOKASSA_BAHT_TO_RUB invalid: %s", rate)
        return 0
    from math import ceil
    return ceil(baht * rate)                 # округление ВВЕРХ — не занижаем


async def _notify(chat: Optional[str], text: str) -> None:
    token = settings.TELEGRAM_BOT_TOKEN
    if not (token and chat):
        return
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as cli:
            await cli.post(f"https://api.telegram.org/bot{token}/sendMessage",
                           json={"chat_id": chat, "text": text, "parse_mode": "HTML"})
    except Exception as e:
        log.warning("telegram notify failed: %s", e)


async def _notify_manager(text: str) -> None:
    await _notify(settings.MANAGER_CHAT_ID, text)


@router.post("/pay/create")
async def pay_create(body: PayCreate, _=Depends(require_secret)):
    # 1) цена тура из БД (источник истины)
    try:
        tr = await run_in_threadpool(lambda: sb.table("tours").select("price_adult,price_child,title").eq("slug", body.tour_slug).limit(1).execute())
    except Exception as e:
        log.warning("tours lookup failed: %s", e)
        return {"available": False, "reason": "tour_lookup_failed"}
    if not tr.data:
        return {"available": False, "reason": "tour_not_found"}
    tour = tr.data[0]
    amount = _amount_rub(tour, body.adults, body.children)
    if amount <= 0:
        return {"available": False, "reason": "zero_amount"}

    # 2) B4: бронь ДОЛЖНА существовать
    booking_id = None
    try:
        bk = await run_in_threadpool(lambda: sb.table("bookings").select("id").eq("external_id", body.external_id).limit(1).execute())
        if bk.data:
            booking_id = bk.data[0]["id"]
    except Exception as e:
        log.warning("booking lookup failed: %s", e)
    if not booking_id:
        log.warning("pay_create: booking not found ext=%s", body.external_id)
        return {"available": False, "reason": "booking_not_found"}

    if not _enabled():
        return {"available": False, "reason": "not_configured", "amount_rub": amount}

    # 3) B3: идемпотентность — не плодить платежи по одной брони
    try:
        ex = await run_in_threadpool(
            lambda: sb.table("payments").select("payment_id,status,confirmation_url,amount")
            .eq("booking_id", booking_id).order("created_at", desc=True).limit(1).execute()
        )
        if ex.data:
            p = ex.data[0]
            if p.get("status") == "succeeded":
                return {"available": False, "reason": "already_paid"}
            if p.get("status") in ("pending", "waiting_for_capture") and p.get("confirmation_url") and p.get("amount") == amount:
                return {"available": True, "confirmation_url": p["confirmation_url"],
                        "amount_rub": amount, "payment_id": p["payment_id"], "reused": True}
    except Exception as e:
        log.warning("idempotency check failed: %s", e)

    # 4) платёж в ЮKassa — стабильный Idempotence-Key по (бронь, сумма)
    idem = hashlib.sha256(f"{body.external_id}:{amount}".encode()).hexdigest()
    desc = f"{tour.get('title') or body.tour_slug} — {body.name or 'бронь'}"[:128]
    payload = {
        "amount": {"value": f"{amount:.2f}", "currency": "RUB"},
        "capture": True,
        "confirmation": {"type": "redirect", "return_url": settings.YOOKASSA_RETURN_URL or "https://nestandart.online/"},
        "description": desc,
        "metadata": {"external_id": body.external_id, "booking_id": booking_id, "tg_chat_id": body.tg_chat_id or ""},
    }
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as cli:
            r = await cli.post(YK_API, json=payload, headers={
                "Authorization": _auth(),
                "Idempotence-Key": idem,
                "Content-Type": "application/json",
            })
        r.raise_for_status()
        pay = r.json()
    except Exception as e:
        log.error("YooKassa create failed: %s", e)
        return {"available": False, "reason": "yookassa_error", "amount_rub": amount}

    url = (pay.get("confirmation") or {}).get("confirmation_url")
    # 5) записать платёж (idempotent: при повторе Idempotence-Key вернётся тот же id)
    try:
        await run_in_threadpool(lambda: sb.table("payments").upsert({
            "booking_id": booking_id, "provider": "yookassa", "payment_id": pay.get("id"),
            "amount": amount, "currency": "RUB",
            "status": pay.get("status", "pending"), "confirmation_url": url,
        }, on_conflict="payment_id").execute())
    except Exception as e:
        log.warning("payments insert failed: %s", e)

    return {"available": True, "confirmation_url": url, "amount_rub": amount, "payment_id": pay.get("id")}


async def _yk_get(pay_id: str) -> dict:
    async with httpx.AsyncClient(timeout=TIMEOUT) as cli:
        r = await cli.get(f"{YK_API}/{pay_id}", headers={"Authorization": _auth()})
    r.raise_for_status()
    return r.json()


@router.post("/pay/webhook")
async def pay_webhook(request: Request):
    try:
        body = await request.json()
    except Exception:
        return {"ok": True}
    event = (body or {}).get("event") or ""
    obj = (body or {}).get("object") or {}
    pay_id = obj.get("id")
    if not pay_id or not _enabled():
        return {"ok": True}

    # B6: обрабатываем только ИЗВЕСТНЫЕ нам платежи (есть в нашей таблице)
    try:
        known = await run_in_threadpool(lambda: sb.table("payments").select("amount,currency,status,booking_id").eq("payment_id", pay_id).limit(1).execute())
    except Exception as e:
        log.error("payments lookup failed: %s", e)
        raise HTTPException(status_code=503, detail="retry")   # B4: 5xx → YooKassa повторит
    if not known.data:
        log.warning("webhook: unknown payment_id %s — ignored", pay_id)
        return {"ok": True}
    prow = known.data[0]

    # перепроверка у API ЮKassa (не доверяем payload)
    try:
        pay = await _yk_get(pay_id)
    except Exception as e:
        log.error("YooKassa verify failed: %s", e)
        raise HTTPException(status_code=502, detail="retry")   # transient → retry

    status = pay.get("status")
    meta = pay.get("metadata") or {}
    ext = meta.get("external_id")
    chat = meta.get("tg_chat_id")
    secret = settings.KOTE_RPC_SECRET

    # B5: ВОЗВРАТ
    if event.startswith("refund") or status == "refunded" or (pay.get("refunded_amount") or {}).get("value"):
        try:
            await run_in_threadpool(lambda: sb.table("payments").update({"status": "refunded"}).eq("payment_id", pay_id).execute())
        except Exception:
            raise HTTPException(status_code=503, detail="retry")
        if ext:
            try:
                await run_in_threadpool(lambda: sb.rpc("app_set_booking_status", {"p_external_id": ext, "p_status": "Возврат", "p_secret": secret}).execute())
            except Exception as e:
                log.warning("refund status set failed: %s", e)
        await _notify_manager(f"↩️ <b>ВОЗВРАТ</b> по брони <code>{ext}</code> (платёж {pay_id}). Бронь → «Возврат».")
        return {"ok": True}

    # B5: ОТМЕНА
    if status == "canceled":
        try:
            await run_in_threadpool(lambda: sb.table("payments").update({"status": "canceled"}).eq("payment_id", pay_id).execute())
        except Exception:
            raise HTTPException(status_code=503, detail="retry")
        return {"ok": True}

    if status != "succeeded":
        return {"ok": True}

    # B2: СВЕРКА СУММЫ И ВАЛЮТЫ
    amt = pay.get("amount") or {}
    try:
        paid_val = Decimal(str(amt.get("value")))
    except (InvalidOperation, TypeError):
        paid_val = None
    cur = amt.get("currency")
    expected = Decimal(int(prow["amount"]))
    if cur != "RUB" or paid_val is None or paid_val != expected:
        log.error("AMOUNT MISMATCH pay=%s expected=%s got=%s %s", pay_id, expected, paid_val, cur)
        await _notify_manager(
            f"⚠️ <b>ОПЛАТА НЕ СОВПАЛА</b>\nПлатёж {pay_id}\nОжидали: {expected} RUB\nПришло: {paid_val} {cur}\n"
            f"Бронь <code>{ext}</code> НЕ помечена оплаченной — проверьте вручную.")
        return {"ok": True}   # реальный mismatch — повтор не поможет, не retry

    # payments → succeeded
    try:
        await run_in_threadpool(lambda: sb.table("payments").update({"status": "succeeded", "paid_at": datetime.now(timezone.utc).isoformat()}).eq("payment_id", pay_id).execute())
    except Exception:
        raise HTTPException(status_code=503, detail="retry")

    # бронь → 'Оплачено' (чистый RPC, без побочек)
    booking_marked = False
    if ext:
        try:
            res = await run_in_threadpool(lambda: sb.rpc("app_mark_paid", {"p_external_id": ext, "p_secret": secret}).execute())
            data = res.data if isinstance(res.data, dict) else (res.data[0] if isinstance(res.data, list) and res.data else None)
            booking_marked = bool(data and data.get("ok"))
        except Exception as e:
            log.warning("mark paid failed: %s", e)
    # B4: деньги есть, брони нет → алерт
    if not booking_marked:
        await _notify_manager(
            f"⚠️ <b>ОПЛАТА БЕЗ БРОНИ</b>\nПлатёж {pay_id} прошёл ({expected} RUB), но бронь "
            f"<code>{ext or '—'}</code> не отмечена. Деньги получены — проверьте вручную!")

    await _notify(chat, "Мур-р-р, оплата прошла! 🐾 Бронь подтверждена — ждём тебя на экскурсии. Хорошего отдыха! 😸")
    return {"ok": True}


@router.post("/pay/reconcile")
async def pay_reconcile(_=Depends(require_secret)):
    """Вызывается n8n по расписанию: ищет зависшие pending и succeeded без оплаченной брони."""
    try:
        res = await run_in_threadpool(lambda: sb.rpc("pay_stuck_report", {"p_secret": settings.KOTE_RPC_SECRET, "p_hours": 2}).execute())
        rep = res.data if isinstance(res.data, dict) else (res.data[0] if isinstance(res.data, list) and res.data else {})
    except Exception as e:
        log.warning("reconcile report failed: %s", e)
        return {"ok": False}
    stale = (rep or {}).get("stale_pending", 0)
    nb = (rep or {}).get("paid_without_booking", 0)
    if stale or nb:
        await _notify_manager(
            f"🧮 <b>Сверка платежей</b>\nЗависших pending (&gt;2ч): {stale}\nОплачено без брони: {nb}\n"
            f"Проверьте, если значения &gt; 0.")
    return {"ok": True, "stale_pending": stale, "paid_without_booking": nb}
