"""SOS Router — экстренные вызовы (приватный, с секрет-гейтом)."""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from auth import require_secret
from config import settings
from db import sb
from notify import tg_send

router = APIRouter()

EMERGENCY_NUMBERS = {
    "phuket":  {"police": "191", "ambulance": "1669", "fire": "199", "embassy": "+66-2-650-2531"},
    "pattaya": {"police": "191", "ambulance": "1669", "fire": "199", "embassy": "+66-2-650-2531"},
    "vietnam": {"police": "113", "ambulance": "115",  "fire": "114", "embassy": "+84-24-3833-6991"},
    "bali":    {"police": "110", "ambulance": "118",  "fire": "113", "embassy": "+62-21-5765765"},
    "dubai":   {"police": "999", "ambulance": "998",  "fire": "997", "embassy": "+971-4-363-8600"},
}
# Неизвестный рынок: универсальный номер 112, а НЕ подмена Таиландом (это было опасно).
EMERGENCY_DEFAULT = {"police": "112", "ambulance": "112", "fire": "112", "embassy": "уточните у менеджера"}


class SOSRequest(BaseModel):
    tg_chat_id: str
    market_id: str


@router.post("/sos")
async def trigger_sos(req: SOSRequest, _=Depends(require_secret)):
    try:
        result = sb.table("clients").select("name, stage").eq("tg_chat_id", req.tg_chat_id).maybe_single().execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail="Внутренняя ошибка сервера") from e

    client_name = (result.data["name"] if result and result.data else None) or "Турист"
    numbers = EMERGENCY_NUMBERS.get(req.market_id, EMERGENCY_DEFAULT)

    await tg_send(
        settings.MANAGER_CHAT_ID,
        f"🚨 SOS!\nКлиент: {client_name}\nРынок: {req.market_id}\nTG: {req.tg_chat_id}\n\n⚡ Свяжитесь немедленно!",
    )
    await tg_send(
        req.tg_chat_id,
        (
            f"🚨 SOS получен!\n\n"
            f"📞 Полиция: {numbers['police']}\n"
            f"🚑 Скорая: {numbers['ambulance']}\n"
            f"🔥 Пожарные: {numbers['fire']}\n"
            f"📞 Посольство: {numbers['embassy']}\n\n"
            f"Менеджер свяжется с тобой прямо сейчас!"
        ),
    )
    return {"status": "alerted", "emergency_numbers": numbers}
