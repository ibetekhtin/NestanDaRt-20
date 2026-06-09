"""
Bookings Router
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import date
from config import settings
from supabase import create_client

router = APIRouter()
sb = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)


class BookingCreate(BaseModel):
    market_id: str
    telegram_id: str
    client_name: str
    service_id: str
    date: date
    total: Optional[float] = None


class BookingUpdate(BaseModel):
    status: str


@router.post("/bookings")
async def create_booking(booking: BookingCreate):
    result = sb.rpc("app_create_booking", {
        "p_market_id": booking.market_id,
        "p_telegram_id": booking.telegram_id,
        "p_client_name": booking.client_name,
        "p_service_id": booking.service_id,
        "p_date": str(booking.date),
        "p_total": booking.total,
    }).execute()

    if result.data is None:
        raise HTTPException(status_code=500, detail="Failed to create booking")
    return {"booking_id": result.data, "status": "draft"}


@router.patch("/bookings/{booking_id}")
async def update_booking(booking_id: str, update: BookingUpdate):
    result = sb.table("bookings").update({"status": update.status}).eq("id", booking_id).execute()
    if result.error:
        raise HTTPException(status_code=500, detail=str(result.error))
    return {"booking_id": booking_id, "status": update.status}


@router.get("/bookings/{booking_id}")
async def get_booking(booking_id: str):
    result = sb.table("v_booking_full").select("*").eq("booking_id", booking_id).single().execute()
    if result.error or not result.data:
        raise HTTPException(status_code=404, detail="Booking not found")
    return result.data