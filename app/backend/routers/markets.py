"""
Markets Router
"""
from fastapi import APIRouter, HTTPException
from config import settings
from supabase import create_client

router = APIRouter()

if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_KEY:
    sb = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)
else:
    sb = None


@router.get("/markets")
async def get_markets():
    """Список активных рынков."""
    result = sb.table("markets").select("*").eq("active", True).execute()
    if result.error:
        raise HTTPException(status_code=500, detail=str(result.error))
    return result.data


@router.get("/markets/{market_id}")
async def get_market(market_id: str):
    """Информация о рынке + статистика."""
    result = sb.table("markets").select("*").eq("id", market_id).single().execute()
    if result.error or not result.data:
        raise HTTPException(status_code=404, detail="Market not found")

    # Статистика
    stats = sb.rpc("app_get_market_stats", {"p_market_id": market_id}).execute()
    return {**result.data, "stats": stats.data if stats.data else {}}
