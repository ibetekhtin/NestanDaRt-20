"""
Webhooks Router — relay for n8n callbacks
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from config import settings
from supabase import create_client

router = APIRouter()
sb = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)


class WebhookPayload(BaseModel):
    booking_id: Optional[str] = None
    client_id: Optional[str] = None
    market_id: Optional[str] = None
    action: Optional[str] = None
    data: Optional[dict] = None


@router.post("/webhook/lead-intake")
async def webhook_lead_intake(payload: WebhookPayload):
    """Relay: создание лида → n8n"""
    result = sb.rpc("app_upsert_lead", {
        "p_market_id": payload.market_id or "unknown",
        "p_name": payload.data.get("name", "Unknown") if payload.data else "Unknown",
        "p_telegram_id": payload.data.get("telegram_id") if payload.data else None,
        "p_phone": payload.data.get("phone") if payload.data else None,
        "p_source": payload.data.get("source", "manual") if payload.data else "manual",
    }).execute()
    return {"status": "ok", "lead_id": result.data}


@router.post("/webhook/booking-confirm")
async def webhook_booking_confirm(payload: WebhookPayload):
    """Relay: подтверждение брони → n8n"""
    if not payload.booking_id:
        raise HTTPException(status_code=400, detail="booking_id required")

    result = sb.table("bookings").update({"status": "confirmed"}).eq("id", payload.booking_id).execute()
    return {"status": "confirmed", "booking_id": payload.booking_id}


@router.post("/webhook/sos")
async def webhook_sos(payload: WebhookPayload):
    """Relay: SOS → n8n"""
    return {"status": "received", "message": "SOS will be processed by n8n"}