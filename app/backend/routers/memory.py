"""
Memory Router — client_memory table
Схема: interests[], budget_level, travel_style, last_intent,
       last_tour_viewed, tours_viewed[], tours_booked[],
       arrival_date, group_size, has_children
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from db import sb

router = APIRouter()


class MemoryUpsert(BaseModel):
    interests: Optional[List[str]] = None
    budget_level: Optional[str] = None     # low | medium | high | vip
    travel_style: Optional[str] = None
    last_intent: Optional[str] = None
    last_tour_viewed: Optional[str] = None
    tours_viewed: Optional[List[str]] = None
    arrival_date: Optional[str] = None
    group_size: Optional[int] = None
    has_children: Optional[bool] = None


@router.get("/clients/{client_id}/memory")
async def get_memory(client_id: str):
    try:
        result = sb.table("client_memory").select("*").eq("client_id", client_id).maybe_single().execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return (result.data if result else None) or {}


@router.post("/clients/{client_id}/memory")
async def upsert_memory(client_id: str, mem: MemoryUpsert):
    # updated_at проставляется server-side (DB default) — не передаём вручную
    payload = {"client_id": client_id, **mem.model_dump(exclude_none=True)}
    try:
        result = sb.table("client_memory").upsert(
            payload, on_conflict="client_id"
        ).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return result.data[0] if result.data else {"status": "ok"}
