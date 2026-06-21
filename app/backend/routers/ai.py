"""
AI Router — proxy to AI providers via KOTE.

/ai/ask  — stateless, backend строит простой system prompt (для PWA/мобилки).
/ai/chat — passthrough: принимает готовый OpenAI-формат (messages[]) и прогоняет
           через каскад провайдеров (groq -> aitunnel -> openrouter -> gemini).
           Использует n8n-бот: вся сборка промпта (персона/память/история/каталог)
           остаётся в n8n, backend только обеспечивает fallback между провайдерами.
"""
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional, List
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
        reply = await ai_ask(prompt=req.message, system=system_prompt, max_tokens=600, temperature=0.85)
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


# Passthrough для n8n-бота: OpenAI-формат на входе и выходе, внутри — каскад.
class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    model: Optional[str] = None
    messages: List[ChatMessage]
    max_tokens: Optional[int] = 600
    temperature: Optional[float] = 0.85


@router.post("/ai/chat")
async def ai_chat(req: ChatRequest):
    system = "\n".join(m.content for m in req.messages if m.role == "system")
    prompt = "\n".join(m.content for m in req.messages if m.role != "system")
    try:
        reply = await ai_ask(
            prompt=prompt,
            system=system,
            max_tokens=req.max_tokens or 600,
            temperature=req.temperature or 0.85,
        )
    except Exception:
        reply = "🐾 Техническая пауза. Попробуй позже!"
    if not reply or not reply.strip():
        reply = "🐾 Извини, не смог ответить. Попробуй ещё раз."
    return {"choices": [{"message": {"role": "assistant", "content": reply}}]}
