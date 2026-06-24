"""
Bookings Router
"""
from typing import Literal, Optional
from datetime import date

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel

from config import settings
from db import sb

router = APIRouter()

BookingStatus = Literal["Новый", "Подтверждён", "Оплачено", "Завершён", "Отменён"]


def _check_secret(x_kote_secret: Optional[str]) -> None:
    secret = settings.KOTE_RPC_SECRET
    if secret and x_kote_secret != secret:
        raise HTTPException(status_code=403, detail="Forbidden")


class BookingCreate(BaseModel):
    client_id: str
    tour_id: Optional[str] = None
    tour_name: Optional[str] = None
    date_start: Optional[date] = None
    people_count: Optional[int] = None
    adults: Optional[int] = None
    children: Optional[int] = None
    budget: Optional[int] = None
    total: Optional[int] = None
    comment: Optional[str] = None
    source: str = "app"


class BookingUpdate(BaseModel):
    status: BookingStatus


@router.post("/bookings")
async def create_booking(booking: BookingCreate, x_kote_secret: Optional[str] = Header(None)):
    _check_secret(x_kote_secret)
    try:
        result = sb.table("bookings").insert({
            "client_id":    booking.client_id,
            "tour_id":      booking.tour_id,
            "tour_name":    booking.tour_name,
            "date_start":   str(booking.date_start) if booking.date_start else None,
            "people_count": booking.people_count,
            "adults":       booking.adults,
            "children":     booking.children,
            "budget":       booking.budget,
            "total":        booking.total,
            "comment":      booking.comment,
            "source":       booking.source,
            "status":       "Новый",
        }).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    if not result.data:
        raise HTTPException(status_code=500, detail="Booking insert returned no row")
    return {"booking_id": result.data[0]["id"], "status": "Новый"}


@router.patch("/bookings/{booking_id}")
async def update_booking(booking_id: str, update: BookingUpdate, x_kote_secret: Optional[str] = Header(None)):
    _check_secret(x_kote_secret)
    try:
        sb.table("bookings").update({"status": update.status}).eq("id", booking_id).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return {"booking_id": booking_id, "status": update.status}


@router.get("/bookings/{booking_id}")
async def get_booking(booking_id: str):
    try:
        result = sb.table("bookings").select(
            "*, clients(name, phone, tg_chat_id), tours(title, slug)"
        ).eq("id", booking_id).maybe_single().execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    if not result or not result.data:
        raise HTTPException(status_code=404, detail="Booking not found")
    return result.data
