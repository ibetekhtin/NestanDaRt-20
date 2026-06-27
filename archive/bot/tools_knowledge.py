"""
tools_knowledge.py — Инструмент поиска по базе знаний для Claude API.

Определяет:
- KNOWLEDGE_TOOL_DEF — определение инструмента для Claude tools=
- search_knowledge() — async функция поиска по Supabase
"""

import os
from supabase import create_client

# ── Claude Tool Definition ────────────────────────────────────────────────────
KNOWLEDGE_TOOL_DEF = {
    "name": "search_knowledge",
    "description": (
        "Поиск по базе знаний проекта «Нестандартный Отдых». "
        "Используй для вопросов про: куда сходить, где поесть, что купить, "
        "лайфхаки, цены на месте, безопасность, визы, экскурсии, пляжи. "
        "Возвращает релевантные записи с возможным insider_tip и related_tour_slug."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "Поисковый запрос (например: 'где поесть на пхукете')",
            },
            "market": {
                "type": "string",
                "description": "Рынок для фильтрации: phuket, pattaya, bali, dubai. Если не указан — искать по всем.",
                "enum": ["phuket", "pattaya", "bali", "dubai"],
            },
        },
        "required": ["query"],
    },
}


# ── Supabase клиент ──────────────────────────────────────────────────────────
_url = os.getenv("SUPABASE_URL", "")
_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY", "")
_sb = create_client(_url, _key) if _url and _key else None


# ── Поиск ────────────────────────────────────────────────────────────────────
# Рынок (для Claude) → город (колонка city в таблице knowledge)
_MARKET_TO_CITY = {
    "phuket": "Пхукет",
    "pattaya": "Паттайя",
    "bali": "Бали",
    "dubai": "Дубай",
}
_SELECT = "id, title, content, city, category, insider_tip, related_tour_slug, priority"


async def search_knowledge(query: str, market: str = None) -> list[dict]:
    """
    Ищет по таблице knowledge в Supabase.
    Колонка фильтрации — city ('Пхукет'/'Паттайя'/'Общее'), market транслируется.
    Записи 'Общее' (виза, деньги, безопасность) попадают в выдачу всегда.
    """
    if not _sb:
        return [{"error": "Supabase не настроен"}]

    city = _MARKET_TO_CITY.get(market) if market else None

    try:
        query_lower = f"%{query.lower()}%"

        qb = (
            _sb.table("knowledge")
            .select(_SELECT)
            .eq("active", True)
            .or_(f"title.ilike.{query_lower},content.ilike.{query_lower}")
        )
        # Город + общетайские записи (city='Общее')
        if city:
            qb = qb.in_("city", [city, "Общее"])

        result = qb.order("priority", desc=True).limit(6).execute()

        if result.data:
            return result.data

        # Fallback: без текстового совпадения — топ полезного по городу
        qb2 = _sb.table("knowledge").select(_SELECT).eq("active", True)
        if city:
            qb2 = qb2.in_("city", [city, "Общее"])
        result2 = qb2.order("priority", desc=True).limit(3).execute()
        return result2.data or []

    except Exception as e:
        return [{"error": f"Ошибка поиска: {str(e)}"}]