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
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from config import settings
from db import sb
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
async def upsert_lead_legacy(lead: LeadIn):
    """Backward-compatible endpoint. Use POST /api/v1/leads instead."""
    res = sb.rpc("app_upsert_lead", {
        "p_name":        lead.name,
        "p_phone":       lead.phone,
        "p_telegram":    lead.telegram,
        "p_tg_chat_id":  lead.tg_chat_id,
        "p_source":      lead.source,
        "p_external_id": None,
        "p_email":       None,
        "p_whatsapp":    None,
        "p_instagram":   None,
        "p_vk":          None,
        "p_tour_name":   None,
        "p_tour_slug":   None,
        "p_date_start":  None,
        "p_people":      None,
        "p_budget":      None,
        "p_total":       None,
        "p_comment":     None,
        "p_status":      "Новый",
        "p_secret":      settings.KOTE_RPC_SECRET,
    }).execute()
    return {"ok": True, "data": res.data}


# ── Заявка из приложения «Нестандарт» (PWA checkout) ──────────
# Публичный (форма приложения), rate-limit на nginx. Раньше шёл на мёртвый порт 3055.
class AppOrder(BaseModel):
    external_id: str | None = None
    source: str = "Приложение"
    name: str | None = None
    phone: str | None = None
    tg_chat_id: str | None = None
    tour_name: str | None = None
    total: int | None = None
    status: str = "Новый"
    comment: str | None = None


@app.post("/api/leads", tags=["leads"], include_in_schema=False)
async def app_order(order: AppOrder):
    try:
        sb.rpc("app_upsert_lead", {
            "p_external_id": order.external_id,
            "p_source":      order.source or "Приложение",
            "p_name":        order.name,
            "p_phone":       order.phone,
            "p_tg_chat_id":  order.tg_chat_id,
            "p_tour_name":   order.tour_name,
            "p_total":       order.total,
            "p_comment":     order.comment,
            "p_status":      order.status or "Новый",
            "p_secret":      settings.KOTE_RPC_SECRET,
        }).execute()
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


