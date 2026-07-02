"""
Shared Supabase client — единственный инстанс на всё приложение.
Создаётся один раз при импорте; все роутеры делают `from db import sb`.
"""
from supabase import create_client, Client
from config import settings

sb: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)

# Полный набор p_*-полей RPC app_upsert_lead. Единый источник правды —
# чтобы не дублировать словарь из ~18 ключей в каждом роутере.
LEAD_FIELDS = (
    "external_id", "name", "phone", "telegram", "tg_chat_id", "email",
    "whatsapp", "instagram", "vk", "source", "tour_name", "tour_slug",
    "date_start", "people", "budget", "total", "comment", "status",
)


def upsert_lead(**fields):
    """Единая точка вызова app_upsert_lead: заполняет пропущенные поля None,
    ставит статус «Новый» по умолчанию и всегда подставляет секрет-гейт."""
    params = {f"p_{k}": None for k in LEAD_FIELDS}
    for k, v in fields.items():
        key = f"p_{k}"
        if key not in params:
            raise ValueError(f"upsert_lead: неизвестное поле {k!r}")
        params[key] = v
    if params["p_status"] is None:
        params["p_status"] = "Новый"
    params["p_secret"] = settings.KOTE_RPC_SECRET
    return sb.rpc("app_upsert_lead", params).execute()
