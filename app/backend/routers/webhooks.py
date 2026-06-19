"""
Webhooks Router — входящие вызовы от n8n
"""
from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional
from config import settings
from db import sb

router = APIRouter()


def _check_secret(x_kote_secret: Optional[str]) -> None:
    expected = settings.KOTE_RPC_SECRET
    # fail-closed: незаданный секрет — это мисконфигурация сервера, а не «всем можно»
    if not expected:
        raise HTTPException(status_code=503, detail="KOTE_RPC_SECRET not configured")
    if x_kote_secret != expected:
        raise HTTPException(status_code=403, detail="Invalid secret")


class LeadWebhook(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    telegram: Optional[str] = None
    tg_chat_id: Optional[str] = None
    source: str = "webhook"
    tour_slug: Optional[str] = None
    comment: Optional[str] = None


class BookingWebhook(BaseModel):
    booking_id: str
    status: str


@router.post("/webhook/lead")
async def webhook_lead(payload: LeadWebhook, x_kote_secret: Optional[str] = Header(None)):
    _check_secret(x_kote_secret)
    try:
        result = sb.rpc("app_upsert_lead", {
            "p_name":        payload.name,
            "p_phone":       payload.phone,
            "p_telegram":    payload.telegram,
            "p_tg_chat_id":  payload.tg_chat_id,
            "p_source":      payload.source,
            "p_tour_slug":   payload.tour_slug,
            "p_comment":     payload.comment,
            "p_external_id": None,
            "p_email":       None,
            "p_whatsapp":    None,
            "p_instagram":   None,
            "p_vk":          None,
            "p_tour_name":   None,
            "p_date_start":  None,
            "p_people":      None,
            "p_budget":      None,
            "p_total":       None,
            "p_status":      "Новый",
        }).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return {"ok": True, "data": result.data}


@router.post("/webhook/booking")
async def webhook_booking(payload: BookingWebhook, x_kote_secret: Optional[str] = Header(None)):
    _check_secret(x_kote_secret)
    try:
        sb.table("bookings").update({"status": payload.status}).eq("id", payload.booking_id).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return {"ok": True, "booking_id": payload.booking_id, "status": payload.status}
