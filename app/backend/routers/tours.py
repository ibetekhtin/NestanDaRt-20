"""
Tours Router
"""
import re
from fastapi import APIRouter, HTTPException
from typing import Optional
from db import sb

router = APIRouter()

_UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.IGNORECASE,
)

_LIST_COLS = (
    "id,slug,title,city,market_id,category,"
    "price_adult,price_child,duration,image_url,"
    "tags,sort_order,active,season_note,min_people,max_people"
)


@router.get("/tours")
async def get_tours(
    market_id: Optional[str] = None,
    category: Optional[str] = None,
    active: bool = True,
):
    try:
        q = sb.table("tours").select(_LIST_COLS).eq("active", active)
        if market_id:
            q = q.eq("market_id", market_id)
        if category:
            q = q.eq("category", category)
        result = q.order("sort_order").execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return result.data or []


@router.get("/tours/{tour_id}")
async def get_tour(tour_id: str):
    column = "id" if _UUID_RE.match(tour_id) else "slug"
    try:
        result = sb.table("tours").select("*").eq(column, tour_id).maybe_single().execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    if not result or not result.data:
        raise HTTPException(status_code=404, detail="Tour not found")
    return result.data
