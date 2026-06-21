"""
kote-backend — FastAPI REST API
Нестандартный Отдых® / ПХУКЕТИК

Эндпоинты:
  GET  /health                        — healthcheck
  GET  /api/v1/markets                — список рынков
  GET  /api/v1/markets/{id}           — рынок + детали
  GET  /api/v1/tours                  — каталог туров
  GET  /api/v1/tours/{id|slug}        — тур по id или slug
  POST /api/v1/lead                   — создать лид (legacy, без /s)
  POST /api/v1/leads                  — создать лид
  GET  /api/v1/leads                  — список лидов
  GET  /api/v1/bookings               — брони по телефону (?phone=)
  GET  /api/v1/bookings/{id}          — бронь по id
  POST /api/v1/bookings               — создать бронь
  GET  /api/v1/clients/{tg_chat_id}   — клиент по tg_chat_id
  GET/POST /api/v1/clients/{id}/memory
  POST /api/v1/ai/ask                 — запрос к AI (fallback chain)
  POST /api/v1/sos                    — SOS-тревога
  POST /api/v1/webhook/lead           — вебхук из n8n
  POST /api/v1/webhook/booking        — вебхук из n8n
  GET  /api/docs                      — Swagger UI
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from db import sb
from routers import ai, bookings, clients, leads, markets, memory, payments, sos, tours, webhooks

app = FastAPI(
    title="Нестандартный Отдых — API",
    version="2.0.0",
    docs_url="/api/docs",
    redoc_url=None,
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
    }).execute()
    return {"ok": True, "data": res.data}


@app.get("/api/v1/bookings", tags=["bookings"], include_in_schema=False)
async def get_bookings_by_phone(phone: str):
    """Legacy: get bookings by phone. Use GET /api/v1/bookings/{id} instead."""
    res = sb.rpc("get_bookings_by_phone", {"p_phone": phone}).execute()
    return res.data
