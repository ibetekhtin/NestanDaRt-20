"""
Leads Router — создание и просмотр лидов через clients + bookings
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import Optional

from auth import require_secret
from db import sb, upsert_lead

router = APIRouter()


class LeadCreate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    telegram: Optional[str] = None
    tg_chat_id: Optional[str] = None
    email: Optional[str] = None
    source: str = "telegram"
    tour_name: Optional[str] = None
    tour_slug: Optional[str] = None
    comment: Optional[str] = None
    budget: Optional[int] = None


@router.post("/leads")
async def create_lead(lead: LeadCreate):
    if not any([lead.phone, lead.tg_chat_id, lead.telegram, lead.email]):
        raise HTTPException(status_code=400, detail="Нужен хотя бы один идентификатор: phone / tg_chat_id / telegram / email")
    try:
        result = upsert_lead(
            name=lead.name, phone=lead.phone, telegram=lead.telegram,
            tg_chat_id=lead.tg_chat_id, email=lead.email, source=lead.source,
            tour_name=lead.tour_name, tour_slug=lead.tour_slug,
            comment=lead.comment, budget=lead.budget,
        )
    except Exception:
        raise HTTPException(status_code=500, detail="Не удалось сохранить лид")
    return {"ok": True, "data": result.data}


@router.get("/leads")
async def get_leads(
    status: Optional[str] = None,
    stage: Optional[str] = None,
    limit: int = Query(50, le=200),
    _=Depends(require_secret),
):
    try:
        query = sb.table("clients").select(
            "id, name, phone, tg_chat_id, source, status, stage, created_at, last_contact"
        )
        if status:
            query = query.eq("status", status)
        if stage:
            query = query.eq("stage", stage)
        result = query.order("created_at", desc=True).limit(limit).execute()
    except Exception:
        raise HTTPException(status_code=500, detail="Ошибка чтения лидов")
    return result.data or []
