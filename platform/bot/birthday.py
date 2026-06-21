"""
birthday.py — Поздравления с днём рождения.

Раз в сутки находит клиентов, у кого сегодня ДР, и шлёт тёплое поздравление
с напоминанием про скидку именинника 3.5% (действует только сегодня, стекается с выгодой наборов).

Cron (раз в день, ~09:00 по Бангкоку = 02:00 UTC):
  0 2 * * * docker exec kote-bot python /app/birthday.py >> /var/log/kote-birthday.log 2>&1
"""

import asyncio
import os
from datetime import datetime, timezone, timedelta

import httpx

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY", "")
BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
_H = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}


async def _send(chat_id: str, text: str) -> bool:
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            r = await c.post(f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
                             json={"chat_id": chat_id, "text": text, "parse_mode": "HTML"})
            return r.status_code == 200
    except Exception as e:
        print(f"[birthday] send error: {e}")
        return False


async def main():
    if not (SUPABASE_URL and SUPABASE_KEY and BOT_TOKEN):
        print("[birthday] no config"); return
    today = datetime.now(timezone(timedelta(hours=7))).strftime("%m-%d")
    # тянем клиентов с заполненным ДР и telegram-чатом
    async with httpx.AsyncClient(timeout=15) as c:
        r = await c.get(f"{SUPABASE_URL}/rest/v1/clients", headers=_H,
                        params={"birthday": "not.is.null", "tg_chat_id": "not.is.null",
                                "select": "name,tg_chat_id,birthday", "limit": "1000"})
    if r.status_code != 200:
        print(f"[birthday] query {r.status_code}"); return
    sent = 0
    for cl in r.json():
        bd = cl.get("birthday") or ""
        if len(bd) < 10 or bd[5:10] != today:
            continue
        chat_id = cl.get("tg_chat_id")
        if not chat_id:
            continue
        first = (cl.get("name") or "друг").split()[0]
        text = (
            f"🎂🥳 <b>{first}, с Днём Рождения!</b> 🎉\n\n"
            "Мур-р-р! Я, КотЭ, поздравляю тебя от всей пушистой души 🐾🧡\n\n"
            "И у меня для тебя подарок: сегодня, и только сегодня, твоя личная "
            "<b>скидка именинника 3.5%</b> на ВСЁ — экскурсии, наборы, подарки. "
            "А на наборы она ещё и приплюсуется к их выгоде! 🎁\n\n"
            "Хочешь устроить себе праздник у моря? Только скажи — подберу лучшее 🌴"
        )
        if await _send(chat_id, text):
            sent += 1
    print(f"[birthday] {today} done, congratulated={sent}")


if __name__ == "__main__":
    asyncio.run(main())
