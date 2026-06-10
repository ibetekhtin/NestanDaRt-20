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
async def search_knowledge(query: str, market: str = None) -> list[dict]:
    """
    Ищет по таблице knowledge в Supabase.

    Возвращает список записей:
    [
        {
            "id": "...",
            "title": "...",
            "content": "...",
            "market": "phuket",
            "category": "food|attraction|tip|visa|safety|...",
            "insider_tip": "...",       # может быть None
            "related_tour_slug": "...",  # может быть None
        },
        ...
    ]
    """
    if not _sb:
        return [{"error": "Supabase не настроен"}]

    try:
        # Full-text search по title + content
        # Используем ilike для простого поиска (Supabase PostgREST)
        query_lower = f"%{query.lower()}%"

        qb = (
            _sb.table("knowledge")
            .select("id, title, content, market, category, insider_tip, related_tour_slug")
            .or_(f"title.ilike.{query_lower},content.ilike.{query_lower}")
        )

        if market:
            qb = qb.eq("market", market)

        qb = qb.limit(5)
        result = qb.execute()

        if result.data:
            return result.data

        # Fallback: если нет results — попробовать broader search
        qb2 = _sb.table("knowledge").select(
            "id, title, content, market, category, insider_tip, related_tour_slug"
        ).limit(3)
        if market:
            qb2 = qb2.eq("market", market)
        result2 = qb2.execute()
        return result2.data or []

    except Exception as e:
        return [{"error": f"Ошибка поиска: {str(e)}"}]