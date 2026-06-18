"""
КотЭ — Telegram бот (Python / aiogram / Gemini 2.0 Flash)

Pipeline (зеркало n8n workflow «КотЭ — AI Агент с памятью»):
  Telegram → Upsert client → Load context → Build prompt →
  Gemini → Send reply → Save conversation → Detect intent →
  Update memory + Update stage

⚠️  НЕ ЗАПУСКАТЬ пока n8n Cloud webhook активен — будет конфликт!
    Для переключения: остановить n8n workflow, потом:
      python main.py  (polling, dev)
      WEBHOOK_URL=https://nestandart.online python main.py  (webhook, prod)
"""

import asyncio
import json
import logging
import os
import sys

import httpx

# Structured JSON logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("kote-bot")

from aiogram import Bot, Dispatcher, types
from aiogram.enums import ParseMode
from aiogram.filters import Command, CommandStart
from aiogram.webhook.aiohttp_server import SimpleRequestHandler, setup_application
from aiohttp import web

from admin_notify import notify
from intent import detect_intent
from supabase_client import (
    bot_upsert_client,
    get_kote_context,
    save_conversation,
    update_client_stage,
    upsert_client_memory,
)

# ── Config ─────────────────────────────────────────────────────────────────────
BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
WEBHOOK_URL = os.getenv("WEBHOOK_URL", "")  # empty = polling mode
WEBHOOK_PATH = "/bot/webhook"
HOST = "0.0.0.0"
PORT = int(os.getenv("BOT_PORT", "8080"))

GEMINI_ENDPOINT = (
    f"https://generativelanguage.googleapis.com/v1beta/models/"
    f"gemini-2.0-flash:generateContent?key={GEMINI_API_KEY}"
)

if not BOT_TOKEN:
    raise SystemExit("TELEGRAM_BOT_TOKEN обязателен в .env")
if not GEMINI_API_KEY:
    raise SystemExit("GEMINI_API_KEY обязателен в .env")

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("kote")

bot = Bot(token=BOT_TOKEN, parse_mode=ParseMode.HTML)
dp = Dispatcher()

# ── System Prompt ──────────────────────────────────────────────────────────────
_SYSTEM = """Ты — КотЭ 🐾, цифровой кот и душа проекта «Нестандартный Отдых» на Пхукете и в Паттайе.
Живёшь в Таиланде с 2013 года, знаешь каждый пляж, рынок и закат как свои подушечки.
Твоя миссия: чтобы человек получил лучший отпуск в жизни — быстро, спокойно и без переплат.

━━━ КТО ТЫ ━━━
Ты не бот и не call-центр. Ты — тот самый местный друг, к которому пишут «слушай, а посоветуй...».
Тёплый, внимательный, с мягким кошачьим юмором. Тебе искренне не всё равно.

━━━ ГЛАВНЫЙ ПРИНЦИП ━━━
Сначала — забота о человеке. Потом — продажа. Всегда в этом порядке.
Если честный ответ — «вам это не нужно» или «сейчас не сезон» — так и говори. Доверие дороже одной продажи.
Безопасность и спокойствие туриста важнее любых денег.

━━━ КАК ТЫ ОБЩАЕШЬСЯ ━━━
- Тепло и по-человечески. Обращайся по имени, если знаешь его.
- Коротко: 2-4 предложения. Это живая переписка, а не брошюра.
- Сначала ответь на вопрос человека, потом — мягко предложи.
- Эмодзи к месту и умеренно: 🌊 🏝️ 🐾 🛥️ — для тепла, не для украшения.
- Зеркаль настроение: с весёлым — легко, с уставшим с дороги — заботливо, с тревожным — спокойно и по делу.
- Цены называй сразу и честно, без «уточните у менеджера».

━━━ КАК ТЫ ПРОДАЁШЬ (мягко и умно) ━━━
- Не вываливай каталог. Пойми, что человеку важно — предложи 1-3 точных варианта.
- Рисуй картинку: не «Пхи-Пхи 3200฿», а «бирюзовая лагуна, плывёшь над рыбами... это Пхи-Пхи, 3200฿».
- Объясняй ценность, а не оправдывай цену.
- Лови момент: человек готов — сразу дай ссылку: https://t.me/nestandart_phuket?start={slug из каталога}
- Семья с детьми, годовщина, первый раз в Азии — подмечай и подбирай под повод.

━━━ ОТКУДА БЕРЁШЬ ДАННЫЕ ━━━
ТУРЫ и ЗНАНИЯ загружены ниже. Рекомендуй ТОЛЬКО из каталога, с реальными ценами.
Поле season — закон: не сезон — честно скажи и предложи замену.
Нет данных — честно скажи и предложи @nestandart_phuket. Лучше «уточню», чем ошибка.

━━━ НИКОГДА ━━━
Не врёшь, не давишь, не торопишь, не споришь. Не обещаешь погоду и наличие мест."""


def _build_system(ctx: dict) -> str:
    """Build full system prompt with client context and catalog data."""
    from datetime import date as _date
    current_date = _date.today().strftime("%-d %B %Y")

    # Client memory block
    lines = []
    if ctx.get("client_name"):
        lines.append(f"Имя: {ctx['client_name']}")
    if ctx.get("client_stage") and ctx["client_stage"] != "new":
        lines.append(f"Стадия: {ctx['client_stage']}")
    if ctx.get("client_country"):
        lines.append(f"Откуда: {ctx['client_country']}")
    if ctx.get("interests"):
        lines.append(f"Интересы: {', '.join(ctx['interests'])}")
    if ctx.get("budget_level") and ctx["budget_level"] != "medium":
        lines.append(f"Бюджет: {ctx['budget_level']}")
    if ctx.get("arrival_date"):
        lines.append(f"Дата приезда: {ctx['arrival_date']}")
    if ctx.get("group_size"):
        lines.append(f"Группа: {ctx['group_size']} чел.")
    if ctx.get("has_children"):
        lines.append("Едут с детьми: да")
    if ctx.get("last_tour_viewed"):
        lines.append(f"Смотрел тур: {ctx['last_tour_viewed']}")
    if ctx.get("tours_booked"):
        lines.append(f"Забронировал: {', '.join(ctx['tours_booked'])}")
    client_memory = "\n".join(lines) or "Новый гость, ничего не знаем."

    # Dialog history
    convs = ctx.get("last_conversations") or []
    if isinstance(convs, str):
        try:
            convs = json.loads(convs)
        except Exception:
            convs = []
    if convs:
        last_convs = "\n---\n".join(
            f"Клиент: {c.get('msg', '')}\nКотЭ: {c.get('res', '')}"
            for c in list(reversed(convs[:8]))
        )
    else:
        last_convs = "Первое обращение."

    # Tours catalog
    tours_list = ctx.get("tours_catalog") or []
    tours = "\n".join(
        f"[{t.get('city', '')}] {t.get('t', '')} — {t.get('price', '')}฿"
        + (f" (дети {t['child']}฿)" if t.get("child") else "")
        + (f", {t['dur']}" if t.get("dur") else "")
        + (f" ⚠️ {t['season']}" if t.get("season") else "")
        + f" | start={t.get('slug', '')}"
        for t in tours_list
    ) or "Каталог временно пуст — отправь к менеджеру."

    # Knowledge pack
    knowledge_list = ctx.get("knowledge_pack") or []
    knowledge = "\n".join(
        f"• {k.get('t', '')} [{k.get('city', '')}]: {k.get('c', '')}"
        + (f"\n  💡 {k['tip']}" if k.get("tip") else "")
        for k in knowledge_list
    ) or "По этому вопросу знаний не нашлось — отвечай аккуратно, без выдумок."

    return (
        _SYSTEM
        + f"\n\n=== ТЕКУЩАЯ ДАТА ===\n{current_date}"
        + f"\n\n=== ПАМЯТЬ О КЛИЕНТЕ ===\n{client_memory}"
        + f"\n\n=== ИСТОРИЯ ДИАЛОГА ===\n{last_convs}"
        + f"\n\n=== ТУРЫ (живой каталог) ===\n{tours}"
        + f"\n\n=== ЗНАНИЯ (под вопрос клиента) ===\n{knowledge}"
    )


async def ask_gemini(system: str, user_message: str) -> str:
    """Call Gemini 2.0 Flash and return text reply."""
    payload = {
        "systemInstruction": {"parts": [{"text": system}]},
        "contents": [{"role": "user", "parts": [{"text": user_message}]}],
        "generationConfig": {"temperature": 0.85, "maxOutputTokens": 600, "topP": 0.95},
    }
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(GEMINI_ENDPOINT, json=payload)
            data = resp.json()
            if data.get("error"):
                code = data["error"].get("code") or data["error"].get("status", "")
                if code in (429, "RESOURCE_EXHAUSTED"):
                    return "Секунду, немного перегружен — напишите ещё раз через минуту 🙏"
                log.error(f"Gemini error: {data['error']}")
                return "Технические неполадки, уже разбираемся!"
            text = (
                data.get("candidates", [{}])[0]
                .get("content", {})
                .get("parts", [{}])[0]
                .get("text", "")
            )
            return text.strip() or "🐾 Не могу ответить. Попробуй ещё раз!"
    except Exception as e:
        log.error(f"Gemini request error: {e}")
        return "🐾 Техническая пауза. Попробуй позже!"


# ── Handlers ───────────────────────────────────────────────────────────────────
@dp.message(CommandStart())
async def cmd_start(message: types.Message):
    tg_chat_id = str(message.chat.id)
    from_user = message.from_user
    name = " ".join(filter(None, [from_user.first_name, from_user.last_name])) or "Гость"

    await bot_upsert_client(tg_chat_id, name)
    await notify.new_lead(name=name, source="telegram", telegram=from_user.username or "")
    await update_client_stage(tg_chat_id, "new")

    await message.answer(
        f"🐾 Привет, {from_user.first_name or 'путник'}!\n"
        "Я — КотЭ, твой помощник на отдыхе.\n\n"
        "Расскажи, что планируешь — море, острова, активный отдых? Помогу выбрать лучшее!"
    )


@dp.message(Command("help"))
async def cmd_help(message: types.Message):
    await message.answer(
        "🐾 <b>КотЭ — помощник в путешествии</b>\n\n"
        "/start — начать заново\n\n"
        "Или просто напиши что интересует — отвечу!"
    )


@dp.message()
async def handle_message(message: types.Message):
    if not message.text:
        return

    tg_chat_id = str(message.chat.id)
    from_user = message.from_user
    name = " ".join(filter(None, [from_user.first_name, from_user.last_name])) or "Гость"
    text = message.text.strip()

    await message.chat.do("typing")

    # 1. Upsert client
    await bot_upsert_client(tg_chat_id, name)

    # 2. Load full context: history, tours, knowledge, memory
    ctx = await get_kote_context(tg_chat_id, text) or {}

    # 3. Build prompt + call Gemini
    system = _build_system(ctx)
    reply = await ask_gemini(system, text)

    # 4. Send reply to Telegram
    await message.answer(reply)

    # 5. Save conversation to Supabase
    client_id = ctx.get("client_id")
    await save_conversation(client_id, text, reply)

    # 6. Detect intent from user message
    intent = detect_intent(text)

    # 7. Update client memory if new data found
    if intent.has_updates:
        await upsert_client_memory(
            client_id,
            interests=intent.interests or None,
            budget_level=intent.budget_level,
            last_intent=intent.new_stage,
            last_tour_viewed=intent.last_tour_viewed,
            arrival_date=intent.arrival_date,
            group_size=intent.group_size,
            has_children=intent.has_children,
        )

    # 8. Update funnel stage
    if intent.new_stage:
        await update_client_stage(tg_chat_id, intent.new_stage)


# ── Entry point ────────────────────────────────────────────────────────────────
async def main():
    if WEBHOOK_URL:
        log.info(f"Webhook mode: {WEBHOOK_URL}{WEBHOOK_PATH}")
        await bot.set_webhook(f"{WEBHOOK_URL}{WEBHOOK_PATH}")
        app = web.Application()
        SimpleRequestHandler(dispatcher=dp, bot=bot).register(app, path=WEBHOOK_PATH)
        setup_application(app, dp, bot=bot)
        runner = web.AppRunner(app)
        await runner.setup()
        await web.TCPSite(runner, HOST, PORT).start()
        log.info(f"Listening on {HOST}:{PORT}{WEBHOOK_PATH}")
        await asyncio.Event().wait()
    else:
        log.info("Polling mode (dev)")
        await bot.delete_webhook(drop_pending_updates=True)
        await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
