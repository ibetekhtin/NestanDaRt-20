"""
AI Router — proxy to AI providers via KOTE

TRADE-OFF (2026-06-19): эндпоинт намеренно STATELESS. История диалога,
память клиента (app_get_client_context) и логирование (таблицы messages /
ai_interactions) вырезаны, т.к. этих таблиц/RPC нет в текущей схеме БД и
вызовы падали. Если они появятся — вернуть: подгрузку history по session_id,
memory_context в system_prompt и запись в ai_interactions. См. git-историю
этого файла до 2026-06-19 за исходной реализацией.
"""
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
from providers import ask as ai_ask

router = APIRouter()


class AIRequest(BaseModel):
    market_id: str
    session_id: str
    message: str
    client_id: Optional[str] = None


class AIResponse(BaseModel):
    reply: str
    intent: str = "other"


@router.post("/ai/ask", response_model=AIResponse)
async def ask_ai(req: AIRequest):
    system_prompt = f"Ты — КотЭ, AI-помощник туристической компании. Рынок: {req.market_id}. Отвечай кратко и по делу."

    try:
        reply = await ai_ask(
            prompt=req.message,
            system=system_prompt,
            max_tokens=600,
            temperature=0.85,
        )
        if not reply:
            reply = "🐾 Извини, не смог ответить. Попробуй ещё раз."
    except Exception:
        reply = "🐾 Техническая пауза. Попробуй позже!"

    lower_msg = req.message.lower()
    if any(w in lower_msg for w in ["sos", "помощь", "тревога", "экстрен"]):
        intent = "sos"
    elif any(w in lower_msg for w in ["заброниров", "бронь", "booking"]):
        intent = "booking"
    elif any(w in lower_msg for w in ["рекомен", "совет", "посоветуй"]):
        intent = "recommendation"
    elif "?" in req.message:
        intent = "question"
    else:
        intent = "other"

    return AIResponse(reply=reply, intent=intent)
