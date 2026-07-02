"""
Clients Router
"""
from fastapi import APIRouter, Depends, HTTPException

from auth import require_secret
from db import sb

router = APIRouter()


@router.get("/clients/{tg_chat_id}")
def get_client(tg_chat_id: str, _=Depends(require_secret)):
    try:
        result = sb.table("clients").select("*").eq("tg_chat_id", tg_chat_id).maybe_single().execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail="Внутренняя ошибка сервера") from e
    if not result or not result.data:
        raise HTTPException(status_code=404, detail="Client not found")
    return result.data
