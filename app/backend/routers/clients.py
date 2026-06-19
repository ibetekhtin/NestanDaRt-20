"""
Clients Router
"""
from fastapi import APIRouter, HTTPException
from db import sb

router = APIRouter()


@router.get("/clients/{tg_chat_id}")
async def get_client(tg_chat_id: str):
    try:
        result = sb.table("clients").select("*").eq("tg_chat_id", tg_chat_id).maybe_single().execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    if not result or not result.data:
        raise HTTPException(status_code=404, detail="Client not found")
    return result.data
