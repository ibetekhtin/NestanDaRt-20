"""
SOS Router — emergency calls
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import httpx
from config import settings
from db import sb

router = APIRouter()

EMERGENCY_NUMBERS = {
    "phuket":  {"police": "191", "ambulance": "1669", "fire": "199", "embassy": "+66-2-650-2531"},
    "pattaya": {"police": "191", "ambulance": "1669", "fire": "199", "embassy": "+66-2-650-2531"},
    "bali":    {"police": "110", "ambulance": "118",  "fire": "113", "embassy": "+62-21-5765765"},
    "dubai":   {"police": "999", "ambulance": "998",  "fire": "997", "embassy": "+971-4-363-8600"},
}


class SOSRequest(BaseModel):
    tg_chat_id: str
    market_id: str


async def _tg_send(token: str, chat_id: str, text: str) -> None:
    async with httpx.AsyncClient(timeout=10) as client:
        await client.post(
            f"https://api.telegram.org/bot{token}/sendMessage",
            json={"chat_id": chat_id, "text": text},
        )


@router.post("/sos")
async def trigger_sos(req: SOSRequest):
    try:
        result = sb.table("clients").select("name, stage").eq("tg_chat_id", req.tg_chat_id).maybe_single().execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    client_name = (result.data["name"] if result and result.data else None) or "Турист"
    numbers = EMERGENCY_NUMBERS.get(req.market_id, EMERGENCY_NUMBERS["phuket"])

    token = settings.TELEGRAM_BOT_TOKEN
    manager_chat = str(settings.MANAGER_CHAT_ID)

    await _tg_send(
        token, manager_chat,
        f"🚨 SOS!\nКлиент: {client_name}\nРынок: {req.market_id}\nTG: {req.tg_chat_id}\n\n⚡ Свяжитесь немедленно!"
    )

    await _tg_send(
        token, req.tg_chat_id,
        (
            f"🚨 SOS получен!\n\n"
            f"📞 Полиция: {numbers['police']}\n"
            f"🚑 Скорая: {numbers['ambulance']}\n"
            f"🔥 Пожарные: {numbers['fire']}\n"
            f"📞 Посольство: {numbers['embassy']}\n\n"
            f"Менеджер свяжется с тобой прямо сейчас!"
        )
    )

    return {"status": "alerted", "emergency_numbers": numbers}
