"""
nudge.py — Догрев брошенной брони.

Находит брони со статусом «Новый» (не оплаченные), которым 2-48 часов,
которые ещё не получали напоминание, и шлёт тёплый кото-нудж с ссылкой на оплату.

Запуск по cron (раз в 30 мин):
  */30 * * * * docker exec kote-bot python /app/nudge.py >> /var/log/kote-nudge.log 2>&1
"""

import asyncio
import os
from datetime import datetime, timedelta, timezone

import httpx

import currency as cur_mod

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY", "")
BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
_H = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}", "Content-Type": "application/json"}

MIN_AGE_H = 2    # не дёргаем раньше 2 часов
MAX_AGE_H = 48   # и не дёргаем совсем старые


async def _send(chat_id: str, text: str) -> bool:
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            r = await c.post(f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
                             json={"chat_id": chat_id, "text": text, "parse_mode": "HTML",
                                   "disable_web_page_preview": True})
            return r.status_code == 200
    except Exception as e:
        print(f"[nudge] send error: {e}")
        return False


async def _mark(booking_id: str):
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            await c.patch(f"{SUPABASE_URL}/rest/v1/bookings",
                          headers={**_H, "Prefer": "return=minimal"},
                          params={"id": f"eq.{booking_id}"},
                          json={"reminded_at": "now()"})
    except Exception as e:
        print(f"[nudge] mark error: {e}")


async def main():
    if not (SUPABASE_URL and SUPABASE_KEY and BOT_TOKEN):
        print("[nudge] no config"); return
    now = datetime.now(timezone.utc)
    lo = (now - timedelta(hours=MAX_AGE_H)).isoformat()
    hi = (now - timedelta(hours=MIN_AGE_H)).isoformat()

    params = {
        "status": "eq.Новый",
        "reminded_at": "is.null",
        "created_at": f"gte.{lo}",
        "select": "id,tour_name,total,created_at,clients(tg_chat_id,name,currency),payments(confirmation_url,status,provider)",
        "order": "created_at.desc",
        "limit": "50",
    }
    async with httpx.AsyncClient(timeout=15) as c:
        r = await c.get(f"{SUPABASE_URL}/rest/v1/bookings", headers=_H, params=params)
    if r.status_code != 200:
        print(f"[nudge] query {r.status_code}: {r.text[:200]}"); return

    rows = r.json()
    sent = 0
    for b in rows:
        if b.get("created_at", "") > hi:
            continue  # моложе 2 часов — рано
        cl = b.get("clients") or {}
        chat_id = cl.get("tg_chat_id")
        if not chat_id:
            continue
        name = cl.get("name") or "друг"
        first = name.split()[0] if name else "друг"
        cur = cl.get("currency") or "RUB"
        tour = b.get("tour_name") or "экскурсия"
        total_thb = float(b.get("total") or 0)

        # ссылка на оплату (берём pending с confirmation_url)
        pay_url = None
        for p in (b.get("payments") or []):
            if p.get("confirmation_url") and p.get("status") == "pending":
                pay_url = p["confirmation_url"]; break

        # Максимально ненавязчиво: тёплый заход + дословная фраза. Без давления и без CTA на оплату.
        import random
        opener = random.choice([
            f"🐾 {first}, привет! Это КотЭ — просто заглянул мурлыкнуть тёплое.",
            f"🐾 {first}, доброго дня! Грелся тут на солнышке и вспомнил о тебе.",
            f"🐾 {first}, привет-привет! Без повода, просто по-доброму.",
            f"🐾 {first}, мур! Заглянул пожелать хорошего настроения.",
        ])
        text = (
            f"{opener}\n\n"
            "Как будете готовы - возвращайтесь. Мы Вас будем ОЧЕНЬ ЖДАТЬ. "
            "Мы - ДороЖиМ КаЖдЫм КлиЕнТом и будем рады, если вы вернётесь.\n\n"
            "Я тут 24/7 — самый вежливый кот-консьерж на планете. "
            "Ничего не нужно прямо сейчас, просто знай: я рядом и всегда помогу 🐾🧡"
        )

        if await _send(chat_id, text):
            await _mark(b["id"])
            sent += 1
    print(f"[nudge] {now.isoformat()} done, sent={sent}, candidates={len(rows)}")


if __name__ == "__main__":
    asyncio.run(main())
