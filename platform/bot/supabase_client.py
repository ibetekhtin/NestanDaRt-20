"""Supabase REST client for KotE bot — all DB operations via httpx."""

import os
import httpx

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY", "")
KOTE_SECRET = os.getenv("KOTE_SECRET", "dc3247bae80970e35f7a65906e1bfddb2bd4eb91ce80a514")

_HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
}


async def _rpc(func: str, params: dict) -> dict | list | None:
    url = f"{SUPABASE_URL}/rest/v1/rpc/{func}"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(url, headers=_HEADERS, json=params)
            if resp.status_code in (200, 201):
                return resp.json()
            print(f"[Supabase] {func} {resp.status_code}: {resp.text[:200]}")
            return None
    except Exception as e:
        print(f"[Supabase] {func} error: {e}")
        return None


async def bot_upsert_client(tg_chat_id: str, name: str = "Гость") -> dict | None:
    return await _rpc("bot_upsert_client", {
        "p_tg_chat_id": tg_chat_id,
        "p_name": name,
        "p_source": "telegram",
    })


async def get_kote_context(tg_chat_id: str, query: str) -> dict | None:
    result = await _rpc("get_kote_context", {
        "p_tg_chat_id": tg_chat_id,
        "p_query": query,
        "p_secret": KOTE_SECRET,
    })
    if isinstance(result, list):
        return result[0] if result else None
    return result


async def save_conversation(client_id: str | None, message: str, response: str) -> bool:
    if not client_id:
        return False
    url = f"{SUPABASE_URL}/rest/v1/conversations"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(
                url,
                headers={**_HEADERS, "Prefer": "return=minimal"},
                json={"client_id": client_id, "message": message, "response": response, "source": "telegram"},
            )
            return resp.status_code in (200, 201)
    except Exception as e:
        print(f"[Supabase] save_conversation error: {e}")
        return False


async def upsert_client_memory(client_id: str | None, **kwargs) -> bool:
    if not client_id:
        return False
    field_map = {
        "interests": "p_interests",
        "budget_level": "p_budget_level",
        "last_intent": "p_last_intent",
        "last_tour_viewed": "p_last_tour_viewed",
        "arrival_date": "p_arrival_date",
        "group_size": "p_group_size",
        "has_children": "p_has_children",
    }
    params: dict = {"p_client_id": client_id}
    for k, v in kwargs.items():
        if k in field_map and v is not None:
            params[field_map[k]] = v
    result = await _rpc("upsert_client_memory", params)
    return result is not None


async def update_client_stage(tg_chat_id: str, stage: str) -> bool:
    result = await _rpc("update_client_stage", {
        "p_tg_chat_id": tg_chat_id,
        "p_stage": stage,
    })
    return result is not None
