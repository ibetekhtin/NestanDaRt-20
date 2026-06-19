"""
Markets Router
"""
from fastapi import APIRouter, HTTPException
from db import sb

router = APIRouter()


@router.get("/markets")
async def get_markets():
    try:
        result = sb.table("markets").select(
            "id, name, name_en, country, accent_color, timezone, currency, tagline, active"
        ).eq("active", True).order("sort_order").execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return result.data or []


@router.get("/markets/{market_id}")
async def get_market(market_id: str):
    try:
        result = sb.table("markets").select("*").eq("id", market_id).maybe_single().execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    if not result or not result.data:
        raise HTTPException(status_code=404, detail="Market not found")
    return result.data
