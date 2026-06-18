"""
kote-backend — FastAPI REST API
Нестандартный Отдых® / ПХУКЕТИК

Маршруты:
  GET  /health            — healthcheck (docker + nginx)
  GET  /api/v1/tours      — каталог туров
  GET  /api/v1/markets    — активные рынки
  POST /api/v1/lead       — создать/обновить лид (→ app_upsert_lead RPC)
  GET  /api/v1/bookings   — брони клиента по телефону
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from supabase import create_client, Client
from pydantic import BaseModel

# ── Конфиг ────────────────────────────────────────────────────
from config import settings

app = FastAPI(
    title="Нестандартный Отдых — API",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://nestandart.online",
        "https://www.nestandart.online",
        "http://localhost:3000",     # dev
    ],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

def get_sb() -> Client:
    if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_KEY:
        raise HTTPException(503, "Supabase не настроен")
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)


# ── Схемы ──────────────────────────────────────────────────────
class LeadIn(BaseModel):
    name: str | None = None
    phone: str | None = None
    telegram: str | None = None
    tg_chat_id: str | None = None
    source: str = "app"
    market_id: str | None = None


# ── Маршруты ──────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/api/v1/tours")
async def get_tours(market_id: str | None = None, active: bool = True):
    sb = get_sb()
    q = sb.table("tours").select(
        "id,slug,title,market_id,category,price_adult,price_child,"
        "duration,description,image_url,tags,sort_order"
    ).eq("active", active)
    if market_id:
        q = q.eq("market_id", market_id)
    res = q.order("sort_order").execute()
    return res.data


@app.get("/api/v1/markets")
async def get_markets():
    sb = get_sb()
    res = sb.table("markets").select(
        "id,slug,name,name_en,accent_color,active,sort_order,tagline"
    ).eq("active", True).order("sort_order").execute()
    return res.data


@app.post("/api/v1/lead")
async def upsert_lead(lead: LeadIn):
    sb = get_sb()
    # ВАЖНО: боевая app_upsert_lead НЕ имеет параметра p_market_id (рынок
    # выводится из тура). Передавать его нельзя — PostgREST не найдёт overload
    # и вернёт 404. Передаём только реально существующие параметры.
    res = sb.rpc("app_upsert_lead", {
        "p_name":       lead.name,
        "p_phone":      lead.phone,
        "p_telegram":   lead.telegram,
        "p_tg_chat_id": lead.tg_chat_id,
        "p_source":     lead.source,
    }).execute()
    return {"ok": True, "data": res.data}


@app.get("/api/v1/bookings")
async def get_bookings(phone: str):
    sb = get_sb()
    res = sb.rpc("get_bookings_by_phone", {"p_phone": phone}).execute()
    return res.data