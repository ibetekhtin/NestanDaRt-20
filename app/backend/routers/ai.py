"""
AI Router — proxy to AI providers via KOTE
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import time
from config import settings
from providers import ask as ai_ask
from supabase import create_client

router = APIRouter()
sb = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)


class AIRequest(BaseModel):
    market_id: str
    session_id: str
    message: str
    client_id: Optional[str] = None


class AIResponse(BaseModel):
    reply: str
    intent: str = "other"
    interaction_id: Optional[str] = None


@router.post("/ai/ask", response_model=AIResponse)
async def ask_ai(req: AIRequest):
    """Задать вопрос КотЭ (AI с fallback chain)."""

    start_time = time.time()

    # История из Supabase
    history = []
    try:
        result = sb.table("messages").select("role, content").eq(
            "session_id", req.session_id
        ).order("created_at", desc=True).limit(10).execute()
        if result.data:
            history = list(reversed(result.data))
    except Exception:
        pass

    # Контекст из памяти клиента
    memory_context = ""
    if req.client_id:
        try:
            mem = sb.rpc("app_get_client_context", {
                "p_client_id": req.client_id,
                "p_market_id": req.market_id,
            }).execute()
            if mem.data:
                memory_context = "\nПамять клиента: " + "; ".join(
                    [f"{m['key']}={m['value']}" for m in mem.data]
                )
        except Exception:
            pass

    # Промпт
    system_prompt = f"Ты — КотЭ, AI-помощник. Рынок: {req.market_id}{memory_context}"
    messages_text = "\n".join(
        [f"{'Пользователь' if h['role'] == 'user' else 'КотЭ'}: {h['content']}" for h in history]
    )
    full_prompt = f"{system_prompt}\n\n{messages_text}\nПользователь: {req.message}\nКотЭ:"

    try:
        reply = await ai_ask(
            prompt=full_prompt,
            system=system_prompt,
            max_tokens=600,
            temperature=0.85,
        )
        if not reply:
            reply = "🐾 Извини, я не могу ответить."
    except Exception as e:
        reply = f"🐾 Техническая пауза. Попробуй позже!"

    latency_ms = int((time.time() - start_time) * 1000)

    # Определяем intent
    lower_msg = req.message.lower()
    intent = "other"
    if any(w in lower_msg for w in ["sos", "помощь", "тревога", "экстрен"]):
        intent = "sos"
    elif any(w in lower_msg for w in ["заброниров", "бронь", "booking"]):
        intent = "booking"
    elif any(w in lower_msg for w in ["рекомен", "совет", "посоветуй"]):
        intent = "recommendation"
    elif "?" in req.message:
        intent = "question"

    # Сохраняем лог
    try:
        sb.table("ai_interactions").insert({
            "market_id": req.market_id,
            "client_id": req.client_id,
            "session_id": req.session_id,
            "user_message": req.message,
            "ai_response": reply,
            "model": settings.GEMINI_MODEL,
            "latency_ms": latency_ms,
            "intent": intent,
        }).execute()
    except Exception:
        pass

    # Сохраняем сообщения
    try:
        sb.table("messages").insert([
            {"market_id": req.market_id, "client_id": req.client_id,
             "session_id": req.session_id, "role": "user", "content": req.message},
            {"market_id": req.market_id, "client_id": req.client_id,
             "session_id": req.session_id, "role": "assistant", "content": reply},
        ]).execute()
    except Exception:
        pass

    return AIResponse(reply=reply, intent=intent)
