"""
Clients Router
"""
from fastapi import APIRouter, HTTPException
from config import settings
from supabase import create_client

router = APIRouter()
sb = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)


@router.get("/clients/{telegram_id}")
async def get_client(telegram_id: str):
    result = sb.table("clients").select("*").eq("telegram_id", telegram_id).single().execute()
    if result.error or not result.data:
        raise HTTPException(status_code=404, detail="Client not found")
    return result.data