"""
KOTЭ Bot — Python/aiogram + Claude API (tools)
Заменяет bot/index.js при миграции на Python.
"""

import os
import json
import anthropic
from aiogram import Bot, Dispatcher, types
from aiogram.filters import CommandStart, Command
from aiogram.enums import ParseMode

from tools_knowledge import KNOWLEDGE_TOOL_DEF, search_knowledge
from admin_notify import notify

# ── Config ────────────────────────────────────────────────────────────────────
BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
CLAUDE_MODEL = os.getenv("CLAUDE_MODEL", "claude-sonnet-4-6")
ADMIN_CHAT_ID = os.getenv("TELEGRAM_ADMIN_CHAT_ID") or os.getenv("MANAGER_CHAT_ID")

if not BOT_TOKEN:
    raise SystemExit("TELEGRAM_BOT_TOKEN обязателен в .env")
if not ANTHROPIC_API_KEY:
    raise SystemExit("ANTHROPIC_API_KEY обязателен в .env")

# ── Claude Client ─────────────────────────────────────────────────────────────
claude = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

# Системный промпт
SYSTEM_PROMPT = """Ты — КотЭ, AI-помощник проекта «Нестандартный Отдых».

## Личность
- Дружелюбный, эмпатичный, короткие ответы
- Общаешься на русском языке
- Emoji 🐾 в начале ответов

## Принципы
1. Сначала польза. Потом продажа.
2. Никогда не выдумывай данные — работай только через Supabase.
3. Превращай запрос в бронирование — помогай человеку забронировать.
4. Краткие ответы — не пиши больше 3 предложений.

## Инструменты
Для вопросов про то, куда сходить, где поесть, что купить, лайфхаки,
цены на месте, безопасность и визы — используй инструмент search_knowledge.
Если у найденной записи есть insider_tip — обязательно вплети его в ответ,
это твоя фирменная кошачья фишка. Если есть related_tour_slug — мягко,
без давления предложи соответствующий тур.

## Формат ответа
- Начинай с 🐾
- Отвечай на русском
- Максимум 3 предложения
- В конце — предложение действий: «Хочешь забронировать?»
"""

# ── Bot & Dispatcher ──────────────────────────────────────────────────────────
bot = Bot(token=BOT_TOKEN, parse_mode=ParseMode.HTML)
dp = Dispatcher()

# Сессия: {user_id: {"market": str, "history": list}}
sessions: dict[int, dict] = {}


def get_session(user_id: int) -> dict:
    if user_id not in sessions:
        sessions[user_id] = {"market": None, "history": []}
    return sessions[user_id]


# ── Claude с tools ────────────────────────────────────────────────────────────
async def ask_claude(user_message: str, market: str = None) -> str:
    """Отправляет сообщение в Claude с инструментом search_knowledge."""
    session = get_session(0)  # placeholder
    history = session.get("history", [])

    # Формируем контекст
    system = SYSTEM_PROMPT
    if market:
        system += f"\n\nТекущий рынок: {market}"

    messages = history[-10:] + [{"role": "user", "content": user_message}]

    try:
        # Первый запрос — с tools
        response = claude.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=600,
            system=system,
            tools=[KNOWLEDGE_TOOL_DEF],
            messages=messages,
        )

        # Обрабатываем tool_use блоки
        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    # Выполняем инструмент
                    if block.name == "search_knowledge":
                        result = await search_knowledge(**block.input)
                    else:
                        result = [{"error": f"Неизвестный инструмент: {block.name}"}]

                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result, ensure_ascii=False),
                    })

            # Добавляем assistant response + tool results в историю
            messages.append({"role": "assistant", "content": response.content})
            messages.append({"role": "user", "content": tool_results})

            # Следующий запрос
            response = claude.messages.create(
                model=CLAUDE_MODEL,
                max_tokens=600,
                system=system,
                tools=[KNOWLEDGE_TOOL_DEF],
                messages=messages,
            )

        # Извлекаем текстовый ответ
        text_parts = [b.text for b in response.content if b.type == "text"]
        return "\n".join(text_parts) or "🐾 Извини, я не могу ответить."

    except Exception as e:
        print(f"[Claude] Ошибка: {e}")
        return "🐾 Техническая пауза. Попробуй позже!"


# ── Хендлеры ──────────────────────────────────────────────────────────────────
@dp.message(CommandStart())
async def cmd_start(message: types.Message):
    session = get_session(message.from_user.id)
    session["market"] = None
    session["history"] = []

    # Уведомление менеджеру о новом пользователе
    await notify.new_lead(
        name=message.from_user.first_name or "Путник",
        source="telegram",
        telegram=message.from_user.username or "",
    )

    await message.answer(
        f"🐾 Привет, {message.from_user.first_name}!\n"
        "Я — КотЭ, твой помощник на отдыхе.\n\n"
        "Выбери направление:"
    )


@dp.message(Command("help"))
async def cmd_help(message: types.Message):
    await message.answer(
        "🐾 *КотЭ — твой помощник*\n\n"
        "/start — начать заново\n"
        "/help — помощь\n\n"
        "Или просто напиши — я помогу!"
    )


@dp.message()
async def handle_text(message: types.Message):
    session = get_session(message.from_user.id)
    market = session.get("market")
    history = session.get("history", [])

    # Показываем typing
    await message.chat.send_action("typing")

    # Спрашиваем Claude
    reply = await ask_claude(message.text, market)

    # Сохраняем в историю
    history.append({"role": "user", "content": message.text})
    history.append({"role": "assistant", "content": reply})
    session["history"] = history[-20:]  # последние 20 сообщений

    await message.answer(reply)


# ── Запуск ────────────────────────────────────────────────────────────────────
async def main():
    print("🐾 КотЭ (Python/Claude) запущен!")
    await dp.start_polling(bot)


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())