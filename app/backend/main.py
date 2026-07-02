"""
nestandart-backend — FastAPI REST API
Nestandart / Нестандартный Отдых®

Эндпоинты:
  GET   /health
  GET   /api/v1/markets, /api/v1/markets/{id}
  GET   /api/v1/tours[?market_id&active], /api/v1/tours/{id|slug}
  POST  /api/v1/leads              — создать/обновить лид
  GET   /api/v1/bookings/{id}      — бронь
  PATCH /api/v1/bookings/{id}      — сменить статус (X-Kote-Secret)
  GET   /api/v1/clients/{tg_chat_id}
  POST  /api/v1/ai/chat            — passthrough для n8n-бота (X-Kote-Secret)
  POST  /api/v1/ai/ask             — AI для PWA
  POST  /api/v1/pay/create         — создать платёж YooKassa (X-Kote-Secret)
  POST  /api/v1/pay/webhook        — YooKassa webhook
  POST  /api/v1/sos
  POST  /api/v1/webhook/lead, /api/v1/webhook/booking
  GET   /api/docs                  — Swagger UI
"""
from fastapi import FastAPI, HTTPException
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from db import upsert_lead
from notify import notify_manager
from routers import ai, bookings, clients, leads, markets, memory, payments, sos, tours, webhooks

app = FastAPI(
    title="Нестандартный Отдых — API",
    version="2.0.0",
    # Карта API скрыта в проде (не раскрываем эндпоинты/RPC/PII-поля).
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://nestandart.online",
        "https://www.nestandart.online",
        "https://app.nestandart.online",
        "http://localhost:3000",
    ],
    allow_methods=["GET", "POST", "PATCH"],
    allow_headers=["*"],
)

# ── Роутеры ──────────────────────────────────────────────────
PREFIX = "/api/v1"
app.include_router(markets.router,  prefix=PREFIX, tags=["markets"])
app.include_router(tours.router,    prefix=PREFIX, tags=["tours"])
app.include_router(leads.router,    prefix=PREFIX, tags=["leads"])
app.include_router(bookings.router, prefix=PREFIX, tags=["bookings"])
app.include_router(clients.router,  prefix=PREFIX, tags=["clients"])
app.include_router(memory.router,   prefix=PREFIX, tags=["memory"])
app.include_router(payments.router, prefix=PREFIX, tags=["payments"])
app.include_router(ai.router,       prefix=PREFIX, tags=["ai"])
app.include_router(sos.router,      prefix=PREFIX, tags=["sos"])
app.include_router(webhooks.router, prefix=PREFIX, tags=["webhooks"])


# ── Системные эндпоинты ───────────────────────────────────────
@app.get("/health", tags=["system"])
async def health():
    return {"status": "ok", "version": "2.0.0"}


# ── Legacy /api/v1/lead (без /s) — обратная совместимость ────
class LeadIn(BaseModel):
    name: str | None = None
    phone: str | None = None
    telegram: str | None = None
    tg_chat_id: str | None = None
    source: str = "app"
    market_id: str | None = None


@app.post("/api/v1/lead", tags=["leads"], include_in_schema=False)
def upsert_lead_legacy(lead: LeadIn):
    """Backward-compatible endpoint. Use POST /api/v1/leads instead."""
    if not any([lead.phone, lead.tg_chat_id, lead.telegram]):
        raise HTTPException(status_code=400, detail="Нужен хотя бы один идентификатор: phone / tg_chat_id / telegram")
    try:
        res = upsert_lead(
            name=lead.name, phone=lead.phone, telegram=lead.telegram,
            tg_chat_id=lead.tg_chat_id, source=lead.source,
        )
    except Exception:
        raise HTTPException(status_code=500, detail="Не удалось сохранить лид")
    return {"ok": True, "data": res.data}


# ── Заявка из приложения «Нестандарт» (PWA checkout) ──────────
# Публичный (форма приложения), rate-limit на nginx. Раньше шёл на мёртвый порт 3055.
class AppOrder(BaseModel):
    external_id: str | None = None
    source: str = "Приложение"
    name: str | None = None
    phone: str | None = None
    email: str | None = None
    telegram: str | None = None
    whatsapp: str | None = None
    tg_chat_id: str | None = None
    tour_name: str | None = None
    tour_slug: str | None = None
    date_start: str | None = None
    people: int | None = None
    total: int | None = None
    status: str = "Новый"
    comment: str | None = None
    ref_code: str | None = None   # промокод — дописываем в comment (в app_upsert_lead нет p_ref_code)


@app.post("/api/leads", tags=["leads"], include_in_schema=False)
async def app_order(order: AppOrder):
    # Не создаём пустой лид-мусор и не спамим менеджера при пустом теле.
    if not any([order.phone, order.tg_chat_id, order.name, order.email]):
        raise HTTPException(status_code=400, detail="Нужен хотя бы один идентификатор: phone / tg_chat_id / name / email")
    comment = order.comment
    if order.ref_code:
        comment = f"{comment or ''} | Промокод: {order.ref_code}".lstrip(" |")
    try:
        # sync-клиент Supabase — уводим в threadpool, чтобы не блокировать event loop
        await run_in_threadpool(
            lambda: upsert_lead(
                external_id=order.external_id,
                source=order.source or "Приложение",
                name=order.name, phone=order.phone, email=order.email,
                telegram=order.telegram, whatsapp=order.whatsapp,
                tg_chat_id=order.tg_chat_id,
                tour_name=order.tour_name, tour_slug=order.tour_slug,
                date_start=order.date_start, people=order.people,
                total=order.total, comment=comment,
                status=order.status or "Новый",
            )
        )
    except Exception:
        # Не валим клиента (он уйдёт в outbox), но сообщаем менеджеру об ошибке записи.
        await notify_manager(
            f"⚠️ Заявка из приложения НЕ записалась в CRM\n{order.name or ''} {order.phone or ''}\n"
            f"{order.tour_name or ''} — {order.total or '?'} ₽\n{order.comment or ''}"
        )
        return {"ok": False}
    await notify_manager(
        f"🆕 <b>Заявка из приложения</b>\n👤 {order.name or '—'}  📞 {order.phone or '—'}\n"
        f"🏝 {order.tour_name or '—'} — {order.total or '?'} ₽\n💬 {order.comment or ''}"
    )
    return {"ok": True}


