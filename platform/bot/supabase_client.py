"""Supabase REST client for KotE bot — all DB operations via httpx."""

import os
import httpx

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY", "")
KOTE_SECRET = os.getenv("KOTE_RPC_SECRET") or os.getenv("KOTE_SECRET", "")

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
            if resp.status_code == 204:
                return {}  # успех без тела (напр. void-функции)
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
        "p_secret": KOTE_SECRET,
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


async def get_client_market(tg_chat_id: str) -> str | None:
    """Возвращает выбранный рынок клиента (markets.id) или None, если не выбран."""
    url = f"{SUPABASE_URL}/rest/v1/clients"
    params = {"tg_chat_id": f"eq.{tg_chat_id}", "select": "market", "limit": "1"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, headers=_HEADERS, params=params)
            if resp.status_code == 200:
                data = resp.json()
                if data and data[0].get("market"):
                    return data[0]["market"]
            return None
    except Exception as e:
        print(f"[Supabase] get_client_market error: {e}")
        return None


async def set_client_market(tg_chat_id: str, market: str) -> bool:
    """Сохраняет выбранный рынок клиента (единая точка входа со всех туннелей)."""
    url = f"{SUPABASE_URL}/rest/v1/clients"
    params = {"tg_chat_id": f"eq.{tg_chat_id}"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.patch(
                url,
                headers={**_HEADERS, "Prefer": "return=minimal"},
                params=params,
                json={"market": market},
            )
            return resp.status_code in (200, 204)
    except Exception as e:
        print(f"[Supabase] set_client_market error: {e}")
        return False


# Согласия на рассылки бот НЕ собирает — только сайт/приложение
_PROFILE_FIELDS = {"name", "phone", "email", "birthday", "whatsapp", "instagram",
                   "vk", "country"}


async def update_client_profile(tg_chat_id: str, **fields) -> bool:
    """Обновляет профиль клиента — только переданные непустые разрешённые поля."""
    data = {}
    for k, v in fields.items():
        if k in _PROFILE_FIELDS and v not in (None, ""):
            data[k] = v
    if not data:
        return False
    data["last_contact"] = "now()"
    url = f"{SUPABASE_URL}/rest/v1/clients"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.patch(
                url, headers={**_HEADERS, "Prefer": "return=minimal"},
                params={"tg_chat_id": f"eq.{tg_chat_id}"}, json=data,
            )
            return resp.status_code in (200, 204)
    except Exception as e:
        print(f"[Supabase] update_client_profile error: {e}")
        return False


async def get_client_consent(tg_chat_id: str) -> bool:
    """Согласился ли клиент на сбор данных."""
    url = f"{SUPABASE_URL}/rest/v1/clients"
    params = {"tg_chat_id": f"eq.{tg_chat_id}", "select": "consent_given", "limit": "1"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, headers=_HEADERS, params=params)
            if resp.status_code == 200 and resp.json():
                return bool(resp.json()[0].get("consent_given"))
    except Exception as e:
        print(f"[Supabase] get_client_consent error: {e}")
    return False


async def set_client_consent(tg_chat_id: str) -> bool:
    """Фиксирует согласие на сбор данных + разрешения на рассылки."""
    url = f"{SUPABASE_URL}/rest/v1/clients"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.patch(
                url, headers={**_HEADERS, "Prefer": "return=minimal"},
                params={"tg_chat_id": f"eq.{tg_chat_id}"},
                json={"consent_given": True, "consent_at": "now()",
                      "allow_email": True, "allow_sms": True, "allow_messenger": True},
            )
            return resp.status_code in (200, 204)
    except Exception as e:
        print(f"[Supabase] set_client_consent error: {e}")
        return False


async def get_client_birthday(tg_chat_id: str) -> str | None:
    """Дата рождения клиента (YYYY-MM-DD) или None."""
    url = f"{SUPABASE_URL}/rest/v1/clients"
    params = {"tg_chat_id": f"eq.{tg_chat_id}", "select": "birthday", "limit": "1"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, headers=_HEADERS, params=params)
            if resp.status_code == 200 and resp.json():
                return resp.json()[0].get("birthday")
    except Exception as e:
        print(f"[Supabase] get_client_birthday error: {e}")
    return None


async def get_client_currency(tg_chat_id: str) -> str:
    """Валюта счёта клиента (RUB по умолчанию)."""
    url = f"{SUPABASE_URL}/rest/v1/clients"
    params = {"tg_chat_id": f"eq.{tg_chat_id}", "select": "currency", "limit": "1"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, headers=_HEADERS, params=params)
            if resp.status_code == 200:
                data = resp.json()
                if data and data[0].get("currency"):
                    return data[0]["currency"]
    except Exception as e:
        print(f"[Supabase] get_client_currency error: {e}")
    return "RUB"


async def set_client_currency(tg_chat_id: str, currency: str) -> bool:
    url = f"{SUPABASE_URL}/rest/v1/clients"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.patch(
                url,
                headers={**_HEADERS, "Prefer": "return=minimal"},
                params={"tg_chat_id": f"eq.{tg_chat_id}"},
                json={"currency": currency},
            )
            return resp.status_code in (200, 204)
    except Exception as e:
        print(f"[Supabase] set_client_currency error: {e}")
        return False


DISCOUNT_MAX = 3.5  # потолок скидки, %


async def get_client_discount(tg_chat_id: str) -> float:
    """Текущая скидка клиента в % (0 если нет)."""
    url = f"{SUPABASE_URL}/rest/v1/clients"
    params = {"tg_chat_id": f"eq.{tg_chat_id}", "select": "discount_pct", "limit": "1"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, headers=_HEADERS, params=params)
            if resp.status_code == 200:
                data = resp.json()
                if data and data[0].get("discount_pct") is not None:
                    return float(data[0]["discount_pct"])
    except Exception as e:
        print(f"[Supabase] get_client_discount error: {e}")
    return 0.0


async def set_client_discount(tg_chat_id: str, pct: float) -> float:
    """Ставит скидку = max(текущая, pct), но не выше DISCOUNT_MAX. Возвращает итог."""
    pct = min(float(pct), DISCOUNT_MAX)
    current = await get_client_discount(tg_chat_id)
    final = min(max(current, pct), DISCOUNT_MAX)
    if final == current:
        return current
    url = f"{SUPABASE_URL}/rest/v1/clients"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            await client.patch(
                url,
                headers={**_HEADERS, "Prefer": "return=minimal"},
                params={"tg_chat_id": f"eq.{tg_chat_id}"},
                json={"discount_pct": final},
            )
    except Exception as e:
        print(f"[Supabase] set_client_discount error: {e}")
    return final


# ── Подарочные сертификаты (одноразовые, атомарное погашение) ───────────────────
import secrets as _secrets


def gen_gift_code() -> str:
    """Непредсказуемый код подарка: NO-XXXXXXXX (8 hex)."""
    return "NO-" + _secrets.token_hex(4).upper()


async def create_gift_certificate(amount_thb: float, buyer_client_id: str | None,
                                  recipient_name: str, gift_message: str,
                                  booking_id: str, package_slug: str | None = None) -> str | None:
    """Создаёт сертификат в статусе 'issued' (станет 'paid' после оплаты). Возвращает код."""
    for _ in range(5):  # на случай коллизии кода
        code = gen_gift_code()
        row = await _insert("gift_certificates", {
            "code": code, "amount_thb": amount_thb, "buyer_client_id": buyer_client_id,
            "recipient_name": recipient_name or None, "gift_message": gift_message or None,
            "booking_id": booking_id, "package_slug": package_slug, "status": "issued",
        })
        if row:
            return code
    return None


async def mark_gift_paid_by_booking(booking_id: str) -> dict | None:
    """После оплаты: сертификат issued→paid (атомарно по фильтру). Возвращает {code, amount, buyer_chat}."""
    url = f"{SUPABASE_URL}/rest/v1/gift_certificates"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.patch(url, headers={**_HEADERS, "Prefer": "return=representation"},
                                   params={"booking_id": f"eq.{booking_id}", "status": "eq.issued"},
                                   json={"status": "paid"})
            if r.status_code not in (200, 204):
                return None
            rows = r.json() if r.text else []
            if not rows:
                return None
            cert = rows[0]
            buyer_chat = None
            if cert.get("buyer_client_id"):
                rc = await client.get(f"{SUPABASE_URL}/rest/v1/clients", headers=_HEADERS,
                                      params={"id": f"eq.{cert['buyer_client_id']}", "select": "tg_chat_id", "limit": "1"})
                if rc.status_code == 200 and rc.json():
                    buyer_chat = rc.json()[0].get("tg_chat_id")
            return {"code": cert.get("code"), "amount": float(cert.get("amount_thb") or 0),
                    "buyer_chat": buyer_chat, "recipient": cert.get("recipient_name"),
                    "message": cert.get("gift_message")}
    except Exception as e:
        print(f"[Supabase] mark_gift_paid_by_booking error: {e}")
        return None


async def redeem_gift_rpc(code: str, tg_chat_id: str) -> dict:
    """Атомарно гасит подарок (одноразово). Возвращает результат RPC."""
    res = await _rpc("redeem_gift", {"p_code": code, "p_tg_chat_id": tg_chat_id, "p_secret": KOTE_SECRET})
    if isinstance(res, list):
        res = res[0] if res else {}
    return res or {"ok": False, "error": "rpc_failed"}


async def spend_bonus_rpc(tg_chat_id: str, amount_thb: float) -> float:
    """Атомарно списывает доступные бонусы (баты) на оплату тура. Возвращает применённую сумму."""
    res = await _rpc("spend_bonus", {"p_tg_chat_id": tg_chat_id,
                                     "p_amount_thb": amount_thb, "p_secret": KOTE_SECRET})
    if isinstance(res, list):
        res = res[0] if res else {}
    try:
        return float((res or {}).get("applied") or 0)
    except Exception:
        return 0.0


# ── Самообучение: КотЭ пополняет базу знаний ────────────────────────────────────
_KN_CITIES = {"Пхукет", "Паттайя", "Вьетнам", "Бали", "Дубай", "Общее"}
_KN_CATS = {"place", "beach", "food", "shopping", "lifehack", "transport",
            "price", "safety", "event", "faq"}


async def learn_knowledge(title: str, content: str, city: str = "Общее",
                          category: str = "faq", tip: str = "") -> bool:
    """
    Сохраняет новый факт от КотЭ в базу знаний на МОДЕРАЦИЮ (active=false).
    Дедуп по близкому заголовку. Возвращает True, если добавлено.
    """
    title = (title or "").strip()[:200]
    content = (content or "").strip()[:1500]
    if len(title) < 4 or len(content) < 10:
        return False
    city = city if city in _KN_CITIES else "Общее"
    category = category if category in _KN_CATS else "faq"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            # дедуп: уже есть запись с таким заголовком?
            chk = await client.get(f"{SUPABASE_URL}/rest/v1/knowledge", headers=_HEADERS,
                                   params={"title": f"ilike.{title}", "select": "id", "limit": "1"})
            if chk.status_code == 200 and chk.json():
                return False
            r = await client.post(f"{SUPABASE_URL}/rest/v1/knowledge",
                                  headers={**_HEADERS, "Prefer": "return=minimal"},
                                  json={"title": title, "content": content, "city": city,
                                        "category": category, "insider_tip": tip or None,
                                        "source": "kote_learned", "active": False, "priority": 50})
            return r.status_code in (200, 201)
    except Exception as e:
        print(f"[Supabase] learn_knowledge error: {e}")
        return False


# ── СБП: реферальная система ───────────────────────────────────────────────────
REFERRAL_PCT = 1.5  # % с покупок приглашённого — пригласившему


def _gen_ref_code(tg_chat_id: str) -> str:
    import hashlib
    return "k" + hashlib.sha1(tg_chat_id.encode()).hexdigest()[:7]


async def get_or_create_ref_code(tg_chat_id: str) -> str | None:
    """Возвращает (создаёт при необходимости) персональный реф-код клиента."""
    url = f"{SUPABASE_URL}/rest/v1/clients"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(url, headers=_HEADERS,
                                 params={"tg_chat_id": f"eq.{tg_chat_id}", "select": "ref_code", "limit": "1"})
            if r.status_code == 200 and r.json() and r.json()[0].get("ref_code"):
                return r.json()[0]["ref_code"]
            code = _gen_ref_code(tg_chat_id)
            await client.patch(url, headers={**_HEADERS, "Prefer": "return=minimal"},
                               params={"tg_chat_id": f"eq.{tg_chat_id}"}, json={"ref_code": code})
            return code
    except Exception as e:
        print(f"[Supabase] get_or_create_ref_code error: {e}")
        return None


async def set_referred_by(tg_chat_id: str, ref_code: str) -> bool:
    """Привязывает клиента к пригласившему (только если ещё не привязан и не сам себя)."""
    url = f"{SUPABASE_URL}/rest/v1/clients"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(url, headers=_HEADERS, params={
                "tg_chat_id": f"eq.{tg_chat_id}", "select": "referred_by,ref_code", "limit": "1"})
            row = (r.json() or [{}])[0] if r.status_code == 200 else {}
            if row.get("referred_by") or row.get("ref_code") == ref_code:
                return False  # уже привязан или сам себя
            await client.patch(url, headers={**_HEADERS, "Prefer": "return=minimal"},
                               params={"tg_chat_id": f"eq.{tg_chat_id}"}, json={"referred_by": ref_code})
            return True
    except Exception as e:
        print(f"[Supabase] set_referred_by error: {e}")
        return False


async def get_ref_stats(tg_chat_id: str) -> dict:
    """Статистика СБП клиента: код, сколько пригласил, бонусный баланс (баты)."""
    url = f"{SUPABASE_URL}/rest/v1/clients"
    out = {"ref_code": None, "invited": 0, "bonus": 0.0}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(url, headers=_HEADERS, params={
                "tg_chat_id": f"eq.{tg_chat_id}", "select": "ref_code,bonus_balance", "limit": "1"})
            if r.status_code == 200 and r.json():
                out["ref_code"] = r.json()[0].get("ref_code")
                out["bonus"] = float(r.json()[0].get("bonus_balance") or 0)
            if out["ref_code"]:
                r2 = await client.get(url, headers={**_HEADERS, "Prefer": "count=exact"}, params={
                    "referred_by": f"eq.{out['ref_code']}", "select": "id", "limit": "1"})
                cr = r2.headers.get("content-range", "")
                if "/" in cr:
                    out["invited"] = int(cr.split("/")[-1])
    except Exception as e:
        print(f"[Supabase] get_ref_stats error: {e}")
    return out


async def credit_referrer_bonus(buyer_tg_chat_id: str, amount_thb: float) -> bool:
    """Начисляет пригласившему REFERRAL_PCT% с покупки приглашённого (в батах)."""
    url = f"{SUPABASE_URL}/rest/v1/clients"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(url, headers=_HEADERS, params={
                "tg_chat_id": f"eq.{buyer_tg_chat_id}", "select": "referred_by", "limit": "1"})
            ref = (r.json() or [{}])[0].get("referred_by") if r.status_code == 200 else None
            if not ref:
                return False
            r2 = await client.get(url, headers=_HEADERS, params={
                "ref_code": f"eq.{ref}", "select": "id,bonus_balance,tg_chat_id", "limit": "1"})
            inviter = (r2.json() or [None])[0] if r2.status_code == 200 else None
            if not inviter:
                return False
            bonus = round(amount_thb * REFERRAL_PCT / 100.0, 2)
            new_bal = float(inviter.get("bonus_balance") or 0) + bonus
            await client.patch(url, headers={**_HEADERS, "Prefer": "return=minimal"},
                               params={"id": f"eq.{inviter['id']}"}, json={"bonus_balance": new_bal})
            return True
    except Exception as e:
        print(f"[Supabase] credit_referrer_bonus error: {e}")
        return False


# ── Заказы и платежи ─────────────────────────────────────────────────────────
async def _insert(table: str, row: dict) -> dict | None:
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(
                url,
                headers={**_HEADERS, "Prefer": "return=representation"},
                json=row,
            )
            if resp.status_code in (200, 201):
                data = resp.json()
                return data[0] if isinstance(data, list) and data else data
            print(f"[Supabase] insert {table} {resp.status_code}: {resp.text[:200]}")
            return None
    except Exception as e:
        print(f"[Supabase] insert {table} error: {e}")
        return None


async def get_tour_by_slug(slug: str) -> dict | None:
    """Тур по slug — для расчёта суммы и названия (из источника правды)."""
    url = f"{SUPABASE_URL}/rest/v1/tours"
    params = {"slug": f"eq.{slug}", "select": "id,slug,title,price_adult,price_child,city", "limit": "1"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, headers=_HEADERS, params=params)
            if resp.status_code == 200:
                data = resp.json()
                return data[0] if data else None
            return None
    except Exception as e:
        print(f"[Supabase] get_tour_by_slug error: {e}")
        return None


async def get_package_by_slug(slug: str) -> dict | None:
    """Набор по slug — цена и состав (источник правды)."""
    url = f"{SUPABASE_URL}/rest/v1/packages"
    params = {"slug": f"eq.{slug}", "select": "slug,title,kind,price_adult,price_child,tour_slugs", "limit": "1"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, headers=_HEADERS, params=params)
            if resp.status_code == 200 and resp.json():
                return resp.json()[0]
            return None
    except Exception as e:
        print(f"[Supabase] get_package_by_slug error: {e}")
        return None


async def create_booking(
    client_id: str | None,
    tour_id: str | None,
    tour_name: str,
    date_start: str | None,
    adults: int | None,
    children: int | None,
    total: int | None,
    comment: str = "",
    source: str = "telegram",
) -> dict | None:
    people = (adults or 0) + (children or 0) or None
    return await _insert("bookings", {
        "client_id": client_id,
        "tour_id": tour_id,
        "tour_name": tour_name,
        "date_start": date_start,
        "people_count": people,
        "adults": adults,
        "children": children,
        "total": total,
        "comment": comment,
        "source": source,
        "status": "Новый",
    })


async def create_payment_row(
    booking_id: str, amount: int, payment_id: str | None,
    confirmation_url: str | None, status: str = "pending",
    currency: str = "RUB", provider: str = "yookassa",
) -> dict | None:
    return await _insert("payments", {
        "booking_id": booking_id,
        "provider": provider,
        "payment_id": payment_id,
        "amount": amount,
        "currency": currency,
        "status": status,
        "confirmation_url": confirmation_url,
    })


async def mark_crypto_paid(booking_id: str) -> dict | None:
    """Отмечает крипто-платёж succeeded ИДЕМПОТЕНТНО (только pending→succeeded).
    Дубль вебхука вернёт None — повторного начисления не будет."""
    pay_url = f"{SUPABASE_URL}/rest/v1/payments"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.patch(
                pay_url,
                headers={**_HEADERS, "Prefer": "return=representation"},
                params={"booking_id": f"eq.{booking_id}", "provider": "eq.nowpayments",
                        "status": "eq.pending"},
                json={"status": "succeeded", "paid_at": "now()"},
            )
            if resp.status_code not in (200, 204):
                print(f"[Supabase] mark_crypto_paid {resp.status_code}: {resp.text[:200]}")
                return None
            rows = resp.json() if resp.text else []
            if not rows:
                return None  # уже обработано ранее — идемпотентность
        await client_patch_booking(booking_id, "Оплачено")
        return await get_booking_full(booking_id)
    except Exception as e:
        print(f"[Supabase] mark_crypto_paid error: {e}")
        return None


async def mark_payment_succeeded(payment_id: str) -> dict | None:
    """Отмечает платёж succeeded ИДЕМПОТЕНТНО (только pending→succeeded).
    Дубль вебхука вернёт None — без повторного чека и начисления рефералки."""
    pay_url = f"{SUPABASE_URL}/rest/v1/payments"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.patch(
                pay_url,
                headers={**_HEADERS, "Prefer": "return=representation"},
                params={"payment_id": f"eq.{payment_id}", "status": "eq.pending"},
                json={"status": "succeeded", "paid_at": "now()"},
            )
            if resp.status_code not in (200, 204):
                print(f"[Supabase] mark_payment {resp.status_code}: {resp.text[:200]}")
                return None
            rows = resp.json() if resp.text else []
            if not rows:
                return None  # уже обработано ранее — идемпотентность
            booking_id = rows[0].get("booking_id")
        if booking_id:
            await client_patch_booking(booking_id, "Оплачено")
            return await get_booking_full(booking_id)
        return None
    except Exception as e:
        print(f"[Supabase] mark_payment_succeeded error: {e}")
        return None


async def client_patch_booking(booking_id: str, status: str) -> bool:
    url = f"{SUPABASE_URL}/rest/v1/bookings"
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.patch(
                url,
                headers={**_HEADERS, "Prefer": "return=minimal"},
                params={"id": f"eq.{booking_id}"},
                json={"status": status},
            )
            return resp.status_code in (200, 204)
    except Exception as e:
        print(f"[Supabase] client_patch_booking error: {e}")
        return False


async def get_booking_full(booking_id: str) -> dict | None:
    """Бронь + данные клиента (для чека и уведомления)."""
    url = f"{SUPABASE_URL}/rest/v1/bookings"
    params = {
        "id": f"eq.{booking_id}",
        "select": "*,clients(name,tg_chat_id,phone)",
        "limit": "1",
    }
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, headers=_HEADERS, params=params)
            if resp.status_code == 200:
                data = resp.json()
                return data[0] if data else None
            return None
    except Exception as e:
        print(f"[Supabase] get_booking_full error: {e}")
        return None
