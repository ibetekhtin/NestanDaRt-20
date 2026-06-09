"""
Memory Router — client memory (client_memory table)
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from config import settings
from supabase import create_client

router = APIRouter()
sb = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)


class MemoryUpdate(BaseModel):
    market_id: str
    key: str
    value: str
    importance: int = 5
    expires_at: Optional[datetime] = None


@router.get("/clients/{client_id}/memory")
async def get_memory(client_id: str, market_id: Optional[str] = None):
    """Получить память клиента."""
    query = sb.table("client_memory").select("key, value, importance").eq("client_id", client_id)
    if market_id:
        query = query.eq("market_id", market_id)
    query = query.order("importance", desc=True).limit(20)
    result = query.execute()
    if result.error:
        raise HTTPException(status_code=500, detail=str(result.error))
    return result.data or []


@router.post("/clients/{client_id}/memory")
async def update_memory(client_id: str, mem: MemoryUpdate):
    """Обновить память клиента (upsert)."""
    result = sb.rpc("app_update_memory", {
        "p_client_id": client_id,
        "p_market_id": mem.market_id,
        "p_key": mem.key,
        "p_value": mem.value,
        "p_importance": mem.importance,
        "p_expires_at": mem.expires_at.isoformat() if mem.expires_at else None,
    }).execute()
    if result.data is None:
        raise HTTPException(status_code=500, detail="Failed to update memory")
    return {"id": result.data, "status": "ok"}