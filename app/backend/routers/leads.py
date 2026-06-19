"""
Leads Router — создание и просмотр лидов через clients + bookings
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from db import sb

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
        result = sb.rpc("app_upsert_lead", {
            "p_name":       lead.name,
            "p_phone":      lead.phone,
            "p_telegram":   lead.telegram,
            "p_tg_chat_id": lead.tg_chat_id,
            "p_email":      lead.email,
            "p_source":     lead.source,
            "p_tour_name":  lead.tour_name,
            "p_tour_slug":  lead.tour_slug,
            "p_comment":    lead.comment,
            "p_budget":     lead.budget,
            "p_external_id": None,
            "p_whatsapp":   None,
            "p_instagram":  None,
            "p_vk":         None,
            "p_date_start": None,
            "p_people":     None,
            "p_total":      None,
            "p_status":     "Новый",
        }).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return {"ok": True, "data": result.data}


@router.get("/leads")
async def get_leads(
    status: Optional[str] = None,
    stage: Optional[str] = None,
    limit: int = 50,
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
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return result.data or []
