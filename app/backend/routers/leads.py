"""
Leads Router
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from config import settings
from supabase import create_client

router = APIRouter()
sb = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)


class LeadCreate(BaseModel):
    market_id: str
    telegram_id: Optional[str] = None
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    source: str = "telegram"
    notes: Optional[str] = None


class LeadUpdate(BaseModel):
    status: Optional[str] = None
    notes: Optional[str] = None


@router.post("/leads")
async def create_lead(lead: LeadCreate):
    result = sb.rpc("app_upsert_lead", {
        "p_market_id": lead.market_id,
        "p_telegram_id": lead.telegram_id,
        "p_name": lead.name,
        "p_phone": lead.phone,
        "p_email": lead.email,
        "p_source": lead.source,
        "p_notes": lead.notes,
    }).execute()

    if result.data is None:
        raise HTTPException(status_code=500, detail="Failed to create lead")
    return {"id": result.data, "status": "new"}


@router.get("/leads")
async def get_leads(
    market_id: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 50,
):
    query = sb.table("leads").select("*")
    if market_id:
        query = query.eq("market_id", market_id)
    if status:
        query = query.eq("status", status)
    query = query.order("created_at", desc=True).limit(limit)
    result = query.execute()
    if result.error:
        raise HTTPException(status_code=500, detail=str(result.error))
    return result.data or []
