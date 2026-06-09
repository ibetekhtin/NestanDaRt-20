"""
SOS Router — emergency calls
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import requests
from config import settings
from supabase import create_client

router = APIRouter()
sb = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)

EMERGENCY_NUMBERS = {
    "phuket": {"police": "191", "ambulance": "1669", "fire": "199", "embassy": "+66-2-650-2531"},
    "pattaya": {"police": "191", "ambulance": "1669", "fire": "199", "embassy": "+66-2-650-2531"},
    "bali": {"police": "110", "ambulance": "118", "fire": "113", "embassy": "+62-21-5765765"},
    "dubai": {"police": "999", "ambulance": "998", "fire": "997", "embassy": "+971-4-363-8600"},
}


class SOSRequest(BaseModel):
    telegram_id: str
    market_id: str


@router.post("/sos")
async def trigger_sos(req: SOSRequest):
    # Получаем клиента
    result = sb.table("clients").select("name, market_id").eq("telegram_id", req.telegram_id).single().execute()
    if result.error or not result.data:
        raise HTTPException(status_code=404, detail="Client not found")

    client_name = result.data["name"]
    market = result.data["market_id"]

    # Уведомляем менеджера
    token = settings.TELEGRAM_BOT_TOKEN
    manager_chat = settings.MANAGER_CHAT_ID
    alert_text = f"🚨 SOS!\nПользователь: {client_name}\nРынок: {market}\nTelegram: {req.telegram_id}\n\n⚡ Немедленно свяжитесь!"
    requests.post(
        f"https://api.telegram.org/bot{token}/sendMessage",
        json={"chat_id": manager_chat, "text": alert_text},
    )

    # Ответ клиенту
    numbers = EMERGENCY_NUMBERS.get(market, EMERGENCY_NUMBERS["phuket"])
    client_text = (
        f"🚨 Получил SOS!\n\n"
        f"📞 Полиция: {numbers['police']}\n"
        f"🚑 Скорая: {numbers['ambulance']}\n"
        f"🔥 Пожарные: {numbers['fire']}\n"
        f"📞 Посольство: {numbers.get('embassy', 'N/A')}\n\n"
        f"Менеджер свяжется с тобой прямо сейчас!"
    )
    requests.post(
        f"https://api.telegram.org/bot{token}/sendMessage",
        json={"chat_id": req.telegram_id, "text": client_text},
    )

    # Лог
    try:
        sb.rpc("app_log_action", {
            "p_market_id": market,
            "p_actor_type": "user",
            "p_actor_id": req.telegram_id,
            "p_action": "sos",
            "p_entity_type": "client",
        }).execute()
    except Exception:
        pass

    return {"status": "alerted", "emergency_numbers": numbers}