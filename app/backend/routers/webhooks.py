"""
Webhooks Router — входящие вызовы от n8n
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

from auth import require_secret
from db import sb, upsert_lead

router = APIRouter()


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
async def webhook_lead(payload: LeadWebhook, _=Depends(require_secret)):
    try:
        result = upsert_lead(
            name=payload.name, phone=payload.phone, telegram=payload.telegram,
            tg_chat_id=payload.tg_chat_id, source=payload.source,
            tour_slug=payload.tour_slug, comment=payload.comment,
        )
    except Exception:
        raise HTTPException(status_code=500, detail="Не удалось сохранить лид")
    return {"ok": True, "data": result.data}


@router.post("/webhook/booking")
async def webhook_booking(payload: BookingWebhook, _=Depends(require_secret)):
    try:
        sb.table("bookings").update({"status": payload.status}).eq("id", payload.booking_id).execute()
    except Exception:
        raise HTTPException(status_code=500, detail="Не удалось обновить бронь")
    return {"ok": True, "booking_id": payload.booking_id, "status": payload.status}
