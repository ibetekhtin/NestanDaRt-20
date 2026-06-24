"""
КотЭ — Telegram бот (Python / aiogram / AI Fallback Chain)

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
import re
import sys
from pathlib import Path

# Structured logging (единственная конфигурация на весь процесс)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("nestandart")

from aiogram import Bot, Dispatcher, F, types
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from aiogram.filters import Command, CommandStart
from aiogram.webhook.aiohttp_server import SimpleRequestHandler, setup_application
from aiohttp import web

from aiogram.types import (
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    KeyboardButton,
    ReplyKeyboardMarkup,
    ReplyKeyboardRemove,
)
from admin_notify import notify
from intent import detect_intent
from supabase_client import (
    bot_upsert_client,
    create_booking,
    create_payment_row,
    client_patch_booking,
    create_gift_certificate,
    credit_referrer_bonus,
    get_booking_full,
    get_client_birthday,
    get_client_consent,
    get_client_currency,
    get_client_discount,
    get_client_market,
    get_kote_context,
    get_or_create_ref_code,
    get_package_by_slug,
    get_ref_stats,
    get_tour_by_slug,
    learn_knowledge,
    mark_crypto_paid,
    mark_gift_paid_by_booking,
    mark_payment_succeeded,
    redeem_gift_rpc,
    save_conversation,
    set_client_consent,
    set_client_currency,
    set_client_discount,
    set_client_market,
    set_referred_by,
    spend_bonus_rpc,
    update_client_profile,
    update_client_stage,
    upsert_client_memory,
)
from providers import ask as ai_ask
from tools_places import nearby_places, maps_category_urls, format_places_message
import payments
import crypto as crypto_mod
import currency as cur_mod
import easter_eggs

# ── Рынки (единая точка входа со всех туннелей) ──────────────────────────────────
# id (markets.id) → (русское имя = tours.city, эмодзи)
MARKETS = {
    "phuket": ("Пхукет", "🏝️"),
    "pattaya": ("Паттайя", "🌅"),
    "vietnam": ("Вьетнам", "🇻🇳"),
}
MARKET_NAMES = {mid: name for mid, (name, _) in MARKETS.items()}
# Рынки, которые бот ПОКА не предлагает в первом вопросе (данные готовятся)
MARKETS_HIDDEN = {"vietnam"}
# Рынки без своего каталога туров (КотЭ работает как гид + собирает заявки)
MARKETS_NO_CATALOG: set[str] = set()


CONSENT_TEXT = (
    "🐾 Привет! Я КотЭ — твой помощник по отдыху в Таиланде.\n\n"
    "Чтобы заботиться о тебе по-настоящему — подбирать лучшее, дарить бонусы, "
    "поздравлять с праздниками и помогать 24/7 — я сохраняю и обрабатываю твои данные "
    "(имя, контакты, дата рождения, история поездок и пожеланий).\n\n"
    "Нажимая «Далее», ты соглашаешься на сбор и обработку персональных данных "
    "и получение полезных сообщений. Это нужно один раз 🐾"
)


def consent_keyboard() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[[
        InlineKeyboardButton(text="Далее ✅", callback_data="consent:yes"),
    ]])


async def _ask_consent(message: types.Message):
    await message.answer(CONSENT_TEXT, reply_markup=consent_keyboard())


def market_keyboard() -> InlineKeyboardMarkup:
    """Первый вопрос воронки — Пхукет или Паттайя. Ничего лишнего.
    Вьетнам пока НЕ предлагаем (данные готовятся, рынок ещё не запущен)."""
    return InlineKeyboardMarkup(inline_keyboard=[[
        InlineKeyboardButton(text="🏝️ Пхукет", callback_data="mkt:phuket"),
        InlineKeyboardButton(text="🌅 Паттайя", callback_data="mkt:pattaya"),
    ]])


def parse_start_market(arg: str) -> str | None:
    """Достаёт рынок из deep-link параметра (сайт/приложение/ВК/реклама).
    Поддерживает: 'phuket', 'pattaya', 'phuket_moto_tour', 'pattaya-kolan' и т.п."""
    if not arg:
        return None
    low = arg.lower().strip()
    for mid in MARKETS:
        if low == mid or low.startswith(mid + "_") or low.startswith(mid + "-"):
            return mid
    return None


# Распознавание рынка из свободного текста ("еду на пхукет", "хочу в паттайю")
_MARKET_KEYWORDS = {
    "phuket": ("пхукет", "пхукете", "пхукета", "пхукету", "phuket"),
    "pattaya": ("паттай", "патай", "паттая", "паттайю", "pattaya", "патая"),
    # Вьетнам пока не предлагаем автоматически — данные готовятся
}

# Полный список для «упоминания» рынка в тексте (вкл. скрытый Вьетнам — пасхалка).
# Бот не предлагает Вьетнам сам, но если клиент сам спросит — КотЭ всё знает и даже забронирует.
_MENTION_KEYWORDS = {
    "phuket": ("пхукет", "phuket"),
    "pattaya": ("паттай", "патай", "паттая", "pattaya", "патая"),
    "vietnam": ("вьетнам", "вьетнаме", "вьетнама", "нячанг", "дананг", "фукуок",
                "муйне", "хойан", "халонг", "хошимин", "vietnam", "nha trang", "da nang"),
}


def detect_mentioned_market(text: str) -> str | None:
    """Какой рынок упомянут в сообщении (для подмешивания его туров в контекст)."""
    low = text.lower()
    for mid, words in _MENTION_KEYWORDS.items():
        if any(w in low for w in words):
            return mid
    return None


def detect_market_from_text(text: str) -> str | None:
    low = text.lower()
    for mid, words in _MARKET_KEYWORDS.items():
        if any(w in low for w in words):
            return mid
    return None


# Валюта счёта: тенге/Казахстан → KZT, рубли/Россия → RUB
_CURRENCY_KEYWORDS = {
    "KZT": ("тенге", "тнг", "kzt", "казах", "казахстан", "алматы", "астан"),
    "RUB": ("рубл", "rub", "₽", "россия", "российск"),
}


def detect_currency_from_text(text: str) -> str | None:
    low = text.lower()
    for cur, words in _CURRENCY_KEYWORDS.items():
        if any(w in low for w in words):
            return cur
    return None


# Скидки (3 уровня):
#   запрос           → 1.5%
#   2-я секретка     → 2.5%  (наш обычный максимум)
#   1-я секретка     → 3.5%  (абсолютный максимум, исключение)
_DISCOUNT_REQUEST = ("скидк", "скидку", "скинь", "уступи", "подешевле",
                     "промокод", "discount", "дешевле можно", "можно дешевле")


# Определение пола по имени (для кото-гороскопа — только девушкам)
_FEMALE_NAMES = {
    "анастасия","настя","мария","маша","елена","лена","ольга","оля","наталья","наташа",
    "татьяна","таня","ирина","ира","екатерина","катя","света","светлана","анна","аня",
    "юлия","юля","дарья","даша","виктория","вика","ксения","ксюша","алина","полина",
    "валерия","лера","кристина","вероника","margarita","маргарита","рита","софия","соня",
    "людмила","люда","галина","галя","надежда","надя","любовь","люба","евгения","женя",
    "альбина","диана","карина","милана","арина","василиса","влада","эльвира","яна","инна",
    "лилия","лиля","оксана","жанна","нина","зоя","римма","элина","камила","азиза","динара",
}
_MALE_EXCEPTIONS = {"никита","илья","кузьма","фома","лука","савва","данила","гаврила","добрыня"}


def guess_gender(first_name: str | None) -> str | None:
    """Грубо угадывает пол по русскому имени: 'female' / 'male' / None."""
    if not first_name:
        return None
    n = first_name.strip().lower().split()[0] if first_name.strip() else ""
    if not n:
        return None
    if n in _FEMALE_NAMES:
        return "female"
    if n in _MALE_EXCEPTIONS:
        return "male"
    if n[-1] in ("а", "я") and len(n) > 2:
        return "female"
    return "male"


def detect_discount_level(text: str) -> float:
    """Возвращает % скидки по сообщению: 3.5 / 2.5 / 1.5 / 0."""
    low = text.lower()
    sasha_shosse = ("саша" in low) and ("шоссе" in low)
    if sasha_shosse and ("хуй" in low):
        return 3.5  # первая секретная фраза — абсолютный максимум
    if sasha_shosse and ("сушк" in low):
        return 2.5  # вторая секретная фраза — наш обычный максимум
    if any(w in low for w in _DISCOUNT_REQUEST):
        return 1.5  # обычная скидка по запросу
    return 0.0

# ── Config ─────────────────────────────────────────────────────────────────────
BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
WEBHOOK_URL = os.getenv("WEBHOOK_URL", "")  # empty = polling mode
WEBHOOK_PATH = "/bot/webhook"
HOST = "0.0.0.0"
PORT = int(os.getenv("BOT_PORT", "8080"))

if not BOT_TOKEN:
    raise SystemExit("TELEGRAM_BOT_TOKEN обязателен в .env")

bot = Bot(token=BOT_TOKEN, default=DefaultBotProperties(parse_mode=ParseMode.HTML))
dp = Dispatcher()

# ── Надёжная отправка (фолбэк при битом HTML + разбивка длинных) ─────────────────
from aiogram.exceptions import TelegramBadRequest

_TAG_RE = re.compile(r"<[^>]+>")
TG_LIMIT = 4000  # запас под лимит Telegram 4096


def _chunk(text: str, limit: int = TG_LIMIT) -> list[str]:
    """Бьёт длинный текст на части по границам строк."""
    if len(text) <= limit:
        return [text]
    parts, cur = [], ""
    for line in text.split("\n"):
        while len(line) > limit:
            if cur:
                parts.append(cur); cur = ""
            parts.append(line[:limit]); line = line[limit:]
        if len(cur) + len(line) + 1 > limit:
            parts.append(cur); cur = line
        else:
            cur = cur + "\n" + line if cur else line
    if cur:
        parts.append(cur)
    return parts


async def safe_send(chat_id, text: str, **kwargs) -> None:
    """Отправляет сообщение надёжно: при ошибке HTML — без разметки; длинное — частями."""
    if not text or not text.strip():
        return
    for ch in _chunk(text):
        try:
            await bot.send_message(chat_id, ch, **kwargs)
        except TelegramBadRequest:
            # Вероятно, кривой HTML в тексте модели → шлём как простой текст
            try:
                kw = {k: v for k, v in kwargs.items() if k != "parse_mode"}
                await bot.send_message(chat_id, _TAG_RE.sub("", ch), parse_mode=None, **kw)
            except Exception as e:
                log.warning(f"safe_send fallback failed: {e}")
        except Exception as e:
            log.warning(f"safe_send error: {e}")


# ── System Prompt ──────────────────────────────────────────────────────────────
_SYSTEM = (Path(__file__).parent / "prompt.txt").read_text()


# Вероятность, что КотЭ в этом сообщении ТОНКО намекнёт на существование пасхалок.
# 0.00005% = 5e-7 (примерно раз на 2 млн сообщений) — пусть будет настоящим волшебством.
HINT_PROBABILITY = 0.0000005


def _hint_directive() -> str:
    import random as _r
    if _r.random() < HINT_PROBABILITY:
        return ("\n\n=== РЕДЧАЙШИЙ МОМЕНТ ===\nМожешь ОДНОЙ тонкой фразой намекнуть, "
                "что у тебя, кота, припрятаны секретики — но не раскрывай какие. Лёгкое волшебство.")
    return ("\n\n=== ПРО ПАСХАЛКИ ===\nВ этом сообщении НЕ намекай на существование пасхалок. "
            "Просто будь собой; секретики срабатывают сами, если человек на них наткнётся.")


def _discount_block(discount: float, discount_event) -> str:
    """Инструктаж по скидке для КотЭ. Скидку применяет СЕРВЕР, КотЭ только сообщает."""
    lines = ["\n\n=== СКИДКА КЛИЕНТА ==="]
    if discount_event and discount_event[0] == "secret":
        lines.append(
            f"🎉 Человек только что назвал ТАЙНУЮ фразу и получил МАКСИМАЛЬНУЮ скидку {discount_event[1]:g}%! "
            "Искренне обрадуйся, по-кошачьи поздравь с секретным уровнем — это редкая удача. Не цитируй саму фразу."
        )
    elif discount_event and discount_event[0] == "request":
        lines.append(
            f"Человек попросил скидку — и ты с радостью даёшь {discount_event[1]:g}%. Скажи об этом тепло."
        )
    if discount and discount > 0:
        lines.append(
            f"Активная скидка клиента: {discount:g}%. Она УЖЕ применяется к цене автоматически при оформлении заказа. "
            "Можешь упомянуть её как приятный бонус."
        )
    else:
        lines.append("Скидки сейчас нет. Если человек попросит — полагается обычная 1.5%.")
    lines.append(
        "ПРАВИЛА СКИДОК (строго): процент-скидки действуют ТОЛЬКО на ПОШТУЧНЫЕ экскурсии "
        "(по запросу 1.5%, обычный максимум 2.5%, абсолютный 3.5% — только по тайной фразе). "
        "На НАБОРЫ и ПОДАРКИ процент-скидки НЕ распространяются — у наборов своя выгода: 500฿ с человека. "
        "БОЛЬШЕ 2.5% сам не предлагай. Скидку считает и применяет система — итоговую сумму сам не называешь."
    )
    return "\n".join(lines)


def _gender_block(gender: str | None) -> str:
    """Кото-гороскоп — приятный бонус ТОЛЬКО для девушек (если пол распознан)."""
    if gender == "female":
        return ("\n\n=== КОТО-ГОРОСКОП (можно девушкам, изредка) ===\n"
                "Если момент уютный, можешь по-доброму предложить или подарить кото-гороскоп на день — "
                "тёплый, с юмором, с кошачьим шармом: «звёзды (и мои усы) шепчут...». "
                "Свяжи с настроением и мягко с идеей куда сходить/поехать. Не навязывай, это милый жест.")
    return ("\n\n=== КОТО-ГОРОСКОП ===\nКото-гороскоп сейчас не предлагай.")


def _build_system(ctx: dict, market: str | None = None, extra_market: str | None = None,
                  discount: float = 0.0, discount_event=None, gender: str | None = None,
                  posture: str = "") -> str:
    """Build full system prompt with client context and catalog data.
    market — выбранный рынок (фильтр каталога).
    extra_market — упомянутый в сообщении рынок (напр. скрытый Вьетнам): его туры тоже подмешиваем.
    discount — текущая скидка клиента, %; discount_event — ('secret'|'request', pct) если только что выдали."""
    from datetime import datetime as _dt, timezone as _tz, timedelta as _td
    _now = _dt.now(_tz(_td(hours=7)))  # Таиланд/Вьетнам UTC+7
    current_date = _now.strftime("%d.%m.%Y")
    current_time = _now.strftime("%H:%M")
    market_name = MARKET_NAMES.get(market) if market else None
    extra_name = MARKET_NAMES.get(extra_market) if extra_market and extra_market != market else None

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

    # Tours catalog — фильтруем под выбранный рынок (если известен)
    tours_list = ctx.get("tours_catalog") or []
    if market in MARKETS_NO_CATALOG:
        # Рынок ещё без своих туров — не показываем чужие
        tours_list = []
    elif market_name:
        allowed = {market_name}
        if extra_name:
            allowed.add(extra_name)  # пасхалка: подмешиваем упомянутый рынок (Вьетнам)
        filtered = [t for t in tours_list if t.get("city") in allowed]
        if filtered:
            tours_list = filtered
    if market in MARKETS_NO_CATALOG:
        empty_msg = (
            f"Авторских туров по направлению «{market_name}» пока нет — рынок запускается. "
            "Работай как эксперт-гид: помогай советами, вдохновляй, а при интересе к брони — "
            "собери имя и контакт и скажи, что наш человек свяжется лично. Лид не теряем!"
        )
    else:
        empty_msg = "Каталог временно пуст — отправь к менеджеру @nestandart_phuket."
    tours = "\n".join(
        f"[{t.get('city', '')}] {t.get('t', '')} — {t.get('price', '')}฿"
        + (f" (дети {t['child']}฿)" if t.get("child") else "")
        + (f", {t['dur']}" if t.get("dur") else "")
        + (f" ⚠️ {t['season']}" if t.get("season") else "")
        + f" | start={t.get('slug', '')}"
        for t in tours_list
    ) or empty_msg

    # Knowledge pack
    knowledge_list = ctx.get("knowledge_pack") or []
    knowledge = "\n".join(
        f"• {k.get('t', '')} [{k.get('city', '')}]: {k.get('c', '')}"
        + (f"\n  💡 {k['tip']}" if k.get("tip") else "")
        for k in knowledge_list
    ) or "По этому вопросу знаний не нашлось — отвечай аккуратно, без выдумок."

    market_line = (
        f"\n\n=== РЫНОК КЛИЕНТА ===\n"
        f"Человек выбрал: {market_name}. Говори ТОЛЬКО про {market_name} — "
        f"туры, места, советы. Не упоминай другой рынок, пока человек сам не спросит."
        if market_name else ""
    )
    return (
        _SYSTEM
        + f"\n\n=== ТЕКУЩАЯ ДАТА И ВРЕМЯ (Таиланд/Вьетнам, UTC+7) ===\n{current_date}, {current_time}"
        + ("\n\n=== КОТО-СЕКРЕТИКИ НА СЕЙЧАС (используй к месту, без влияния на цену) ===\n"
           + easter_eggs.sample_eggs(12))
        + _hint_directive()
        + _discount_block(discount, discount_event)
        + _gender_block(gender)
        + posture
        + market_line
        + f"\n\n=== ПАМЯТЬ О КЛИЕНТЕ ===\n{client_memory}"
        + f"\n\n=== ИСТОРИЯ ДИАЛОГА ===\n{last_convs}"
        + f"\n\n=== ТУРЫ (живой каталог) ===\n{tours}"
        + f"\n\n=== ЗНАНИЯ (под вопрос клиента) ===\n{knowledge}"
    )




# ── Helpers ──────────────────────────────────────────────────────────────────
async def _ask_market(message: types.Message, first_name: str = "путник"):
    """Первый шаг воронки: выбор направления. Кнопки — и ничего лишнего."""
    await kote_photo(message.chat.id)  # первое впечатление — мордочка КотЭ (если задан URL)
    await message.answer(
        f"🐾 Привет, {first_name}! Я КотЭ — помогу с отдыхом.\n\n"
        "<b>Пхукет или Паттайя?</b>",
        reply_markup=market_keyboard(),
    )


async def _greet_for_market(message: types.Message, market: str, first_name: str = "путник"):
    """Приветствие после выбора рынка — дальше работает обычная воронка продаж."""
    name, emoji = MARKETS.get(market, ("отдых", "🐾"))
    if market in MARKETS_NO_CATALOG:
        await message.answer(
            f"{emoji} О, <b>{name}</b>! Отличный выбор — мы как раз заходим на этот рынок 🐾\n\n"
            "Авторские туры сюда вот-вот запустим, но я уже знаю кучу полезного: "
            "куда поехать, ночная жизнь, виза, деньги, как не попасть впросак. "
            "Спрашивай что угодно — а если захочешь забронировать, я передам тебя нашему человеку лично."
        )
        return
    await message.answer(
        f"{emoji} Отлично, <b>{name}</b>!\n\n"
        "Расскажи, что планируешь — море и острова, активный отдых, "
        "или хочется чего-то нестандартного? Подберу лучшее под тебя 🐾"
    )


# ── Веб-поиск: когда лезть в интернет ────────────────────────────────────────
# Явные просьбы / актуальные темы — точно в интернет.
_WEB_TRIGGERS = (
    "загугли", "погугли", "поищи", "найди в интернете", "в интернете",
    "актуальн", "сейчас ид", "сегодня в", "на этой неделе", "афиш", "расписани",
    "новост", "погода", "прогноз", "курс ", "сколько стоит сейчас",
    "когда откро", "во сколько откро", "часы работы", "график работы",
    "кто такой", "что такое", "адрес", "телефон", "как добраться до",
    "концерт", "вечеринк", "мероприят", "событи", "что нового",
)


# Вопросы про НАШИ туры/бронь/оплату — отвечаем из каталога, НЕ из интернета
_OUR_DOMAIN = ("тур", "экскурс", "бронир", "заброн", "оплат", "мототур", "автотур",
               "симилан", "пхи-пхи", "пхипхи", "джеймс", "мини-бас", "минибас", "пакет")


def _needs_web(text: str, ctx: dict) -> bool:
    """Решает, нужен ли веб-поиск. Консервативно — чтобы не жечь бюджет зря."""
    low = text.lower()
    # 1) явная просьба или актуальная тема — всегда в интернет
    if any(t in low for t in _WEB_TRIGGERS):
        return True
    # 2) вопрос про наши туры/бронь — это к каталогу, не в интернет
    if any(w in low for w in _OUR_DOMAIN):
        return False
    # 3) фактический вопрос, по которому база знаний пуста
    kn = ctx.get("knowledge_pack") or []
    words = low.split()
    is_question = "?" in text or (words and words[0] in (
        "где", "когда", "сколько", "какой", "какая", "какие", "что", "кто",
        "почему", "зачем", "как", "куда", "можно", "есть",
    ))
    if is_question and not kn and len(text) > 8:
        return True
    return False


# ── Чутьё на момент продажи (КотЭ сам понимает: дожимать или просто помогать) ──
_BUY_SIGNALS = ("хочу", "беру", "забронир", "заброн", "оплат", "куплю", "купить",
                "запиши", "записывай", "поехали", "давай оформ", "готов", "сколько стоит",
                "когда можно", "есть места", "свободно", "забронируй", "оформляй", "бронь")
_COLD_SIGNALS = ("дорого", "дороговато", "подума", "потом", "позже", "не уверен",
                 "не готов", "может быть", "как-нибудь", "не сейчас", "дорогова",
                 "надо посоветоваться", "посоветуюсь", "не знаю пока", "наверное нет")


def _sales_posture(text: str, ctx: dict) -> str:
    """Возвращает директиву по «моменту»: дожимать, мягко касаться или просто помогать."""
    low = text.lower()
    stage = ctx.get("client_stage") or "new"
    hot = any(s in low for s in _BUY_SIGNALS) or stage in ("booking",)
    cold = any(s in low for s in _COLD_SIGNALS)
    if cold and not hot:
        return ("\n\n=== МОМЕНТ: НЕ ДОЖИМАТЬ ===\n"
                "Человек сомневается/не готов. НЕ предлагай бронь, не дави. Просто помоги и ответь по делу, "
                "сними тревогу заботой. Мягко дай понять, что вернуться можно в любой момент. Без CTA.")
    if hot:
        return ("\n\n=== МОМЕНТ: ПОДХОДЯЩИЙ ===\n"
                "Человек проявляет готовность. Действуй чётко и элегантно: предложи конкретный вариант "
                "и помоги оформить бронь прямо сейчас. Без воды, по-деловому и тепло — как умеют только коты.")
    return ("\n\n=== МОМЕНТ: НЕЙТРАЛЬНЫЙ ===\n"
            "Сначала польза. Если в тему — лёгко, ненавязчиво коснись подходящей экскурсии. "
            "Почувствуй момент: рано — просто помогай и грей доверие.")


# ── Заказ и оплата ───────────────────────────────────────────────────────────
_ORDER_RE = re.compile(r"<order>\s*(\{.*?\})\s*</order>", re.DOTALL)
_LEARN_RE = re.compile(r"<learn>\s*(\{.*?\})\s*</learn>", re.DOTALL)


_PROFILE_RE = re.compile(r"<profile>\s*(\{.*?\})\s*</profile>", re.DOTALL)
_EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
_PHONE_RE = re.compile(r"(?<!\d)(\+?\d[\d\s\-()]{8,16}\d)(?!\d)")


async def capture_contacts(tg_chat_id: str, text: str) -> None:
    """Авто-сбор контактов из сообщения клиента (телефон/почта)."""
    fields = {}
    em = _EMAIL_RE.search(text)
    if em:
        fields["email"] = em.group(0)
    ph = _PHONE_RE.search(text)
    if ph:
        digits = re.sub(r"\D", "", ph.group(1))
        if 10 <= len(digits) <= 15:  # похоже на реальный номер
            fields["phone"] = ph.group(1).strip()
    if fields:
        await update_client_profile(tg_chat_id, **fields)


async def process_profile(reply: str, tg_chat_id: str) -> str:
    """КотЭ собрал данные клиента (<profile>{…}</profile>) — сохраняем в CRM."""
    m = _PROFILE_RE.search(reply)
    clean = _PROFILE_RE.sub("", reply).strip()
    if not m:
        return reply
    try:
        d = json.loads(m.group(1))
        # валидация даты рождения
        bd = (d.get("birthday") or "").strip()
        if bd and not re.match(r"^\d{4}-\d{2}-\d{2}$", bd):
            d.pop("birthday", None)
        await update_client_profile(tg_chat_id, **d)
    except Exception as e:
        log.warning(f"process_profile error: {e}")
    return clean or reply


async def process_learn(reply: str) -> str:
    """Если КотЭ нашёл новый факт (<learn>{…}</learn>) — сохраняет в базу на модерацию."""
    m = _LEARN_RE.search(reply)
    clean = _LEARN_RE.sub("", reply).strip()
    if not m:
        return reply
    try:
        d = json.loads(m.group(1))
        await learn_knowledge(
            title=d.get("title", ""), content=d.get("content", ""),
            city=d.get("city", "Общее"), category=d.get("category", "faq"),
            tip=d.get("tip", ""),
        )
    except Exception as e:
        log.warning(f"process_learn error: {e}")
    return clean or reply


def _short_id(uuid_str: str) -> str:
    return (uuid_str or "").split("-")[0].upper()[:6] or "ЗАКАЗ"


BIRTHDAY_PCT = 3.5  # скидка именинника в его день — на ВСЁ, стекается с выгодой набора


async def _is_birthday_today(tg_chat_id: str) -> bool:
    """True, если сегодня (UTC+7) день рождения клиента."""
    from datetime import datetime as _dt, timezone as _tz, timedelta as _td
    bd = await get_client_birthday(tg_chat_id)
    if not bd or len(bd) < 10:
        return False
    today = _dt.now(_tz(_td(hours=7))).strftime("%m-%d")
    return bd[5:10] == today


async def process_order(reply: str, ctx: dict, market: str, tg_chat_id: str, from_user) -> str:
    """
    Если в ответе КотЭ есть <order>{...}</order> — создаёт бронь + платёж
    и заменяет тег на блок с кликабельной ссылкой на оплату.
    Возвращает финальный текст для отправки клиенту.
    """
    m = _ORDER_RE.search(reply)
    if not m:
        return reply

    clean_text = _ORDER_RE.sub("", reply).strip()
    try:
        order = json.loads(m.group(1))
    except Exception as e:
        log.warning(f"order parse error: {e}")
        return clean_text or reply

    is_gift = bool(order.get("gift"))
    is_package = bool(order.get("package")) or is_gift  # подарок = всегда набор
    gift_recipient = (order.get("recipient") or "").strip()
    gift_message = (order.get("gift_message") or "").strip()

    slug = (order.get("tour_slug") or "").strip()
    pkg_slug = (order.get("package_slug") or "").strip()
    # Дата: ISO (для базы) + человеческое написание (для клиента)
    raw_date = (order.get("date") or "").strip()
    date_text = (order.get("date_text") or "").strip()
    date_iso = raw_date if re.match(r"^\d{4}-\d{2}-\d{2}$", raw_date) else None
    if not date_text:
        date_text = raw_date or date_iso or ""
    adults = int(order.get("adults") or 1)
    children = int(order.get("children") or 0)
    cust_name = order.get("name") or ctx.get("client_name") or (from_user.first_name or "Гость")
    client_id = ctx.get("client_id")
    discount = 0.0           # % скидка — ТОЛЬКО для поштучных экскурсий
    pkg_discount = 0         # 500฿/чел — ТОЛЬКО для наборов
    pkg_slug_used = None
    price_trusted = False    # ЦЕНА из базы (нельзя продать по выдуманной модели сумме)
    bday_pct = BIRTHDAY_PCT if await _is_birthday_today(tg_chat_id) else 0.0
    bday_applied = False     # для показа «скидка именинника»

    if is_package:
        # НАБОР (или подарок-набор): фиксированная цена (−500฿/чел уже в ней), % скидки НЕ применяются
        people = max(1, adults + children)
        tour_id = None
        pkg = await get_package_by_slug(pkg_slug) if pkg_slug else None
        if pkg:
            pkg_slug_used = pkg.get("slug")
            tour_name = "Набор «" + (pkg.get("title") or pkg_slug) + "»"
            total = (pkg.get("price_adult") or 0) * adults + (pkg.get("price_child") or 0) * children
            price_trusted = total > 0
        else:
            tour_name = "Набор «" + (order.get("tour_name") or "Пхукет") + "»"
            total = int(order.get("total") or order.get("amount") or 0)
        pkg_discount = PACKAGE_DISCOUNT_PER_PERSON * people  # для информационного показа выгоды
        full_thb = total
        # День рождения: 3.5% сверху на набор/подарок (стекается с выгодой набора)
        if bday_pct > 0 and price_trusted and total > 0:
            total = int(round(total * (1 - bday_pct / 100.0)))
            bday_applied = True
        if is_gift:
            tour_name = "🎁 Подарок: " + tour_name
            date_iso, date_text = None, ""
    else:
        # ПОШТУЧНАЯ экскурсия: % скидка применяется, 500฿ — нет
        tour = await get_tour_by_slug(slug) if slug else None
        if tour:
            tour_id = tour.get("id")
            tour_name = tour.get("title") or slug
            pa = tour.get("price_adult") or 0
            pc = tour.get("price_child") or 0
            total = pa * adults + pc * children
            price_trusted = total > 0
        else:
            tour_id = None
            tour_name = order.get("tour_name") or slug or "Экскурсия"
            total = int(order.get("total") or 0)
        discount = await get_client_discount(tg_chat_id)
        if bday_pct > discount:           # в день рождения — гарантированные 3.5%
            discount = bday_pct
            bday_applied = True
        full_thb = total
        if price_trusted and discount and discount > 0 and full_thb > 0:
            total = int(round(full_thb * (1 - discount / 100.0)))

    comment = f"Оформлено КотЭ ({MARKET_NAMES.get(market, market)})"
    if is_gift:
        comment = f"🎁 ПОДАРОК-набор. Получатель: {gift_recipient or '—'}. " + (f"Пожелание: {gift_message}" if gift_message else "")
    elif is_package:
        comment = f"Набор. " + comment
    if is_package and pkg_discount > 0:
        comment += f". Набор (выгода {pkg_discount}฿ в цене)"
    if discount and discount > 0:
        comment += f". Скидка {discount:g}% (было {full_thb}฿ → {total}฿)"
    if date_text and not date_iso:
        comment += f". Дата со слов клиента: {date_text}"
    booking = await create_booking(
        client_id=client_id, tour_id=tour_id, tour_name=tour_name,
        date_start=date_iso, adults=adults, children=children, total=total,
        comment=comment, source="telegram",
    )
    if not booking:
        log.warning("booking create failed")
        return (clean_text + "\n\n🐾 Ой, заминка с оформлением. Напиши менеджеру @nestandart_phuket — оформит вручную за минуту!").strip()

    booking_id = booking.get("id")
    num = _short_id(booking_id)
    people_line = f"{adults} взр." + (f" + {children} дет." if children else "")
    date_disp = date_text or date_iso or ""
    date_line = f"\n📅 {date_disp}" if date_disp else ""

    # БЕЗОПАСНОСТЬ: цена не подтверждена базой (нет тура/набора по slug) —
    # НЕ выставляем оплату по выдуманной сумме, передаём гиду для ручного расчёта.
    if not price_trusted:
        uname = from_user.username or "—"
        await notify.escalation(
            client=f"{cust_name} (@{uname})", chat_id=tg_chat_id,
            reason=f"Заказ без цены из базы: «{tour_name}», {people_line}. Нужен ручной расчёт.",
        )
        msg = (
            f"✅ <b>Заявка #{num} принята!</b>\n🏝 {tour_name}{date_line}\n👥 {people_line}\n\n"
            "Наш гид рассчитает точную стоимость и пришлёт ссылку на оплату совсем скоро 🐾\n"
            "Любой вопрос — я на связи. Менеджер: @nestandart_phuket"
        )
        return (clean_text + "\n\n" + msg).strip() if clean_text else msg

    # Подарок: создаём сертификат (issued → paid после оплаты)
    if is_gift and total > 0:
        await create_gift_certificate(
            amount_thb=total, buyer_client_id=client_id,
            recipient_name=gift_recipient, gift_message=gift_message, booking_id=booking_id,
            package_slug=pkg_slug_used,
        )

    # total — в БАТАХ (база). Списываем бонусы (только для обычных заказов, не для подарков).
    total_thb = total
    client_cur = await get_client_currency(tg_chat_id)
    applied_bonus = 0
    if not is_gift and total_thb > 0:
        applied_bonus = int(await spend_bonus_rpc(tg_chat_id, total_thb))
        total_thb = max(0, total_thb - applied_bonus)
    amount = await cur_mod.convert(total_thb, client_cur) if total_thb > 0 else 0

    # Полностью покрыто бонусом-подарком — доплата не нужна
    if not is_gift and amount == 0 and applied_bonus > 0:
        await client_patch_booking(booking_id, "Оплачено")
        await update_client_stage(tg_chat_id, "done")
        msg = (
            f"✅ <b>Заказ #{num} готов!</b>\n🏝 {tour_name}{date_line}\n👥 {people_line}\n\n"
            f"🎁 Полностью оплачено твоим подарочным бонусом! Доплачивать ничего не нужно 🐾\n"
            "Наш гид свяжется и расскажет детали. С тебя только отдых и хорошее настроение 🌴"
        )
        return (clean_text + "\n\n" + msg).strip() if clean_text else msg

    # Платёж ЮKassa (если ключи заданы) — в валюте клиента
    pay = None
    if amount > 0:
        pay = await payments.create_payment(
            amount=amount,
            currency=client_cur,
            description=f"{tour_name} — заказ {num}",
            metadata={"booking_id": booking_id, "tg_chat_id": tg_chat_id, "num": num},
        )
    await create_payment_row(
        booking_id=booking_id, amount=amount, currency=client_cur,
        payment_id=(pay or {}).get("payment_id"),
        confirmation_url=(pay or {}).get("confirmation_url"),
        status="pending", provider="yookassa",
    )

    # Крипто-оплата (NOWPayments) — если ключи заданы. Цена в USD из батов.
    crypto_inv = None
    if total_thb > 0 and crypto_mod.enabled():
        amount_usd = await cur_mod.convert(total_thb, "USD")
        crypto_inv = await crypto_mod.create_invoice(
            amount_usd=amount_usd, order_id=booking_id,
            description=f"{tour_name} — заказ {num}",
        )
        if crypto_inv:
            await create_payment_row(
                booking_id=booking_id, amount=amount_usd, currency="USD",
                payment_id=crypto_inv.get("invoice_id"),
                confirmation_url=crypto_inv.get("invoice_url"),
                status="pending", provider="nowpayments",
            )

    # Уведомление менеджеру (баты + валюта счёта)
    uname = from_user.username or "—"
    mgr_total = f"{cur_mod.fmt(amount, client_cur)} ({cur_mod.fmt_thb(total_thb)})" if amount else "—"
    await notify.new_booking(
        tour=tour_name, date=date_disp or "—",
        people=people_line, total=mgr_total,
        client=f"{cust_name} (@{uname}, chat {tg_chat_id})",
    )

    if amount:
        extra = ""
        if is_package:
            extra += "\n🎁 Цена набора уже выгоднее, чем брать экскурсии по отдельности!"
        if bday_applied:
            extra += "\n🎂 Скидка именинника 3.5% — с днём рождения! 🥳"
        if discount and discount > 0:
            extra += f"\n🎁 Скидка {discount:g}% уже учтена!"
        if applied_bonus > 0:
            extra += f"\n🎁 Бонус-подарок применён: −{cur_mod.fmt_thb(applied_bonus)}!"
        price_line = (
            f"\n💰 К оплате: <b>{cur_mod.fmt(amount, client_cur)}</b>"
            f"  <i>({cur_mod.fmt_thb(total_thb)} по курсу)</i>"
            + extra
        )
    else:
        price_line = ""
    title_line = "🎁 <b>Подарок оформлен!</b>" if is_gift else f"✅ <b>Заказ #{num} оформлен!</b>"
    head = (
        f"{title_line}\n"
        f"🏝 {tour_name}{date_line}\n👥 {people_line}{price_line}"
    )

    pay_lines = []
    if pay and pay.get("confirmation_url"):
        pay_lines.append(f"💳 <b><a href=\"{pay['confirmation_url']}\">Оплатить картой онлайн →</a></b>")
    if crypto_inv and crypto_inv.get("invoice_url"):
        pay_lines.append(
            f"🪙 <b><a href=\"{crypto_inv['invoice_url']}\">Оплатить криптой (TON/USDT/BTC…) →</a></b>"
        )

    after_pay = ("\n\nПосле оплаты пришлю тебе <b>подарочный код</b> с красивым сертификатом — "
                 "перешлёшь его, кому хочешь. Получатель активирует одной кнопкой 🎁"
                 ) if is_gift else (
                 "\n\nОплата безопасная. После оплаты сразу пришлю чек со всеми деталями 🐾")
    if pay_lines:
        block = (
            f"{head}\n\n"
            + "\n".join(pay_lines)
            + after_pay + "\n"
            f"Удобнее на сайте или в приложении? Скажи — без проблем.\n"
            f"Что-то не так — напиши, поможем. Менеджер: @nestandart_phuket"
        )
    else:
        tail = ("После оплаты пришлю подарочный код для пересылки 🎁" if is_gift
                else "После оплаты получишь чек со всеми деталями.")
        block = (
            f"{head}\n\n"
            f"💳 Сейчас пришлю ссылку на оплату — пара минут 🐾\n"
            f"Можно оплатить картой, криптой (TON/USDT/BTC), на сайте/в приложении или переводом — как удобнее.\n"
            f"{tail}\n"
            f"Любой вопрос — я на связи. Менеджер: @nestandart_phuket"
        )

    return (clean_text + "\n\n" + block).strip() if clean_text else block


async def _redeem_and_reply(message: types.Message, tg_chat_id: str, code: str, first_name: str):
    """Активирует подарочный код (одноразово) и отвечает клиенту."""
    code = (code or "").strip().upper()
    if not code:
        await message.answer("🎁 Кажется, код подарка пустой. Пришли его ещё раз — активирую!")
        return
    # клиент должен существовать (для зачисления)
    name = " ".join(filter(None, [message.from_user.first_name, message.from_user.last_name])) or "Гость"
    await bot_upsert_client(tg_chat_id, name)
    res = await redeem_gift_rpc(code, tg_chat_id)
    if res.get("ok"):
        cur = await get_client_currency(tg_chat_id)
        amt = await cur_mod.convert(float(res.get("amount") or 0), cur)
        await safe_send(
            message.chat.id,
            f"🎁 <b>Подарок активирован!</b> Мур-р-р, поздравляю, {first_name}! 🐾\n\n"
            f"На твой счёт зачислено <b>{cur_mod.fmt(amt, cur)}</b> — это подарок, который можно потратить "
            f"на любую нашу экскурсию. Просто выбери, что по душе, и я всё оформлю — подарок спишется сам.\n\n"
            "С чего начнём? Море, острова, природа или что-то нестандартное? 🌴"
        )
    else:
        err = res.get("error")
        msg = {
            "already_redeemed": "🙀 Этот подарок уже был активирован раньше — код одноразовый. Если это ошибка, напиши менеджеру @nestandart_phuket.",
            "not_paid": "🐾 Подарок ещё не оплачен дарителем. Как только оплата пройдёт — код заработает!",
            "not_found": "🤔 Такого кода подарка не нашёл. Проверь, всё ли верно, или напиши @nestandart_phuket.",
        }.get(err, "Не получилось активировать подарок. Напиши менеджеру @nestandart_phuket — поможем 🐾")
        await message.answer(msg)


# ── Handlers ───────────────────────────────────────────────────────────────────
@dp.message(CommandStart())
async def cmd_start(message: types.Message):
    tg_chat_id = str(message.chat.id)
    from_user = message.from_user
    name = " ".join(filter(None, [from_user.first_name, from_user.last_name])) or "Гость"
    first_name = from_user.first_name or "путник"

    await bot_upsert_client(tg_chat_id, name)
    await notify.new_lead(name=name, source="telegram", telegram=from_user.username or "")
    await update_client_stage(tg_chat_id, "new")

    # Deep-link со всех туннелей: /start phuket, /start pattaya_kolan, /start ref_kXXXXXXX…
    parts = (message.text or "").split(maxsplit=1)
    start_arg = parts[1].strip() if len(parts) > 1 else ""

    # Реф-атрибуцию фиксируем сразу (даже до согласия)
    if start_arg.lower().startswith("ref_"):
        rc = start_arg[4:].strip()
        if rc:
            await set_referred_by(tg_chat_id, rc)
        start_arg = ""

    # СОГЛАСИЕ один раз: пока не согласился — показываем экран «Далее»
    if not await get_client_consent(tg_chat_id):
        await _ask_consent(message)
        return

    # Подарок: пришёл по ссылке ?start=gift_<code> → активируем (одноразово)
    if start_arg.lower().startswith("gift_"):
        code = start_arg[5:].strip()
        await _redeem_and_reply(message, tg_chat_id, code, first_name)
        return

    market = parse_start_market(start_arg)

    if market:
        # Рынок известен из ссылки (сайт/приложение/ВК/реклама) — не спрашиваем
        await set_client_market(tg_chat_id, market)
        await _greet_for_market(message, market, first_name)
        return

    # Рынок уже сохранён ранее?
    saved = await get_client_market(tg_chat_id)
    if saved in MARKETS:
        await _greet_for_market(message, saved, first_name)
        return

    # Не знаем рынок — задаём ПЕРВЫЙ вопрос воронки
    await _ask_market(message, first_name)


@dp.callback_query(F.data == "consent:yes")
async def on_consent(callback: types.CallbackQuery):
    tg_chat_id = str(callback.message.chat.id)
    first_name = callback.from_user.first_name or "путник"
    name = " ".join(filter(None, [callback.from_user.first_name, callback.from_user.last_name])) or "Гость"
    await bot_upsert_client(tg_chat_id, name)
    await set_client_consent(tg_chat_id)
    try:
        await callback.message.edit_text("Спасибо! 🐾 Поехали 🌴")
    except Exception:
        pass
    # после согласия — первый вопрос воронки (рынок), если ещё не выбран
    saved = await get_client_market(tg_chat_id)
    if saved in MARKETS:
        await _greet_for_market(callback.message, saved, first_name)
    else:
        await _ask_market(callback.message, first_name)
    await callback.answer()


@dp.callback_query(F.data.startswith("mkt:"))
async def on_market_choice(callback: types.CallbackQuery):
    market = callback.data.split(":", 1)[1]
    if market not in MARKETS:
        await callback.answer()
        return
    tg_chat_id = str(callback.message.chat.id)
    first_name = callback.from_user.first_name or "путник"

    await set_client_market(tg_chat_id, market)
    await update_client_stage(tg_chat_id, "interest")

    name, emoji = MARKETS[market]
    # Убираем кнопки, фиксируем выбор
    try:
        await callback.message.edit_text(f"{emoji} Выбрано направление: <b>{name}</b>")
    except Exception:
        pass
    await _greet_for_market(callback.message, market, first_name)
    await callback.answer()


BOT_USERNAME = os.getenv("BOT_USERNAME", "phuket_nestandart_bot")
REF_PCT = 1.5  # % с покупок приглашённого — пригласившему (СБП)
PACKAGE_DISCOUNT_PER_PERSON = 500  # ฿ скидка с человека при покупке НАБОРА
KOTE_AVATAR_URL = os.getenv("KOTE_AVATAR_URL", "")  # картинка КотЭ для ключевых моментов


async def kote_photo(chat_id, caption: str | None = None) -> bool:
    """Шлёт картинку КотЭ (если задан KOTE_AVATAR_URL). Тихо пропускает, если нет."""
    if not KOTE_AVATAR_URL:
        return False
    try:
        await bot.send_photo(chat_id, KOTE_AVATAR_URL, caption=caption)
        return True
    except Exception as e:
        log.warning(f"kote_photo error: {e}")
        return False


@dp.message(Command("help"))
async def cmd_help(message: types.Message):
    await message.answer(
        "🐾 <b>КотЭ — помощник в путешествии</b>\n\n"
        "/start — начать заново\n"
        "/nearby — что рядом со мной\n"
        "/ref — пригласить друзей и получать бонусы\n"
        "/gift — активировать подарочный код 🎁\n\n"
        "Или просто напиши что интересует — отвечу!"
    )


@dp.message(Command("gift"))
async def cmd_gift(message: types.Message):
    tg_chat_id = str(message.chat.id)
    first_name = message.from_user.first_name or "путник"
    parts = (message.text or "").split(maxsplit=1)
    if len(parts) < 2:
        await message.answer("🎁 Пришли код подарка так: <code>/gift NO-XXXXXXXX</code> — и я его активирую!")
        return
    await _redeem_and_reply(message, tg_chat_id, parts[1], first_name)


@dp.message(Command("ref"))
async def cmd_ref(message: types.Message):
    tg_chat_id = str(message.chat.id)
    code = await get_or_create_ref_code(tg_chat_id)
    stats = await get_ref_stats(tg_chat_id)
    currency = await get_client_currency(tg_chat_id)
    bonus_thb = stats.get("bonus", 0.0)
    bonus_disp = cur_mod.fmt(await cur_mod.convert(bonus_thb, currency), currency) if bonus_thb else cur_mod.fmt(0, currency)
    link = f"https://t.me/{BOT_USERNAME}?start=ref_{code}" if code else "—"
    await safe_send(
        message.chat.id,
        "🎁 <b>СБП — СИСТЕМА БОНУСНЫХ ПРИГЛАШЕНИЙ</b>\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        f"Делись своей ссылкой — и получай <b>{REF_PCT:g}% с каждой покупки друга</b> 🐾\n"
        "Бонусы копятся и тратятся на наши экскурсии.\n\n"
        f"🔗 Твоя ссылка:\n{link}\n\n"
        f"👥 Приглашено друзей: <b>{stats.get('invited', 0)}</b>\n"
        f"💰 Твой бонус: <b>{bonus_disp}</b>\n\n"
        "Чем больше друзей — тем больше отдыха за наш счёт! Зови всех 🌴",
        disable_web_page_preview=True,
    )


@dp.message(Command("nearby"))
async def cmd_nearby(message: types.Message):
    kb = ReplyKeyboardMarkup(
        keyboard=[[KeyboardButton(text="📍 Поделиться геолокацией", request_location=True)]],
        resize_keyboard=True,
        one_time_keyboard=True,
    )
    await message.answer(
        "🐾 Поделись геолокацией — найду что интересного рядом!\n"
        "Рестораны, пляжи, бары, банкоматы — всё с оценками на Google Картах.",
        reply_markup=kb,
    )


_NEARBY_TRIGGERS = {
    "рядом", "поблизости", "неподалёку", "где я", "куда пойти",
    "что рядом", "ближайший", "ближайшая", "недалеко", "nearby",
    "куда сходить сегодня", "что посетить", "место рядом",
}


@dp.message(lambda m: m.location is not None)
async def handle_location(message: types.Message):
    lat = message.location.latitude
    lng = message.location.longitude
    tg_chat_id = str(message.chat.id)

    await message.answer("📍 Принял! Ищу что интересного рядом...", reply_markup=ReplyKeyboardRemove())
    await message.chat.do("typing")

    # Пробуем Google Places API (если ключ есть)
    places = await nearby_places(lat, lng, radius=1500)
    reply = format_places_message(places, lat, lng)
    await safe_send(message.chat.id, reply, disable_web_page_preview=True)

    # Сохраняем координаты в память клиента через AI ответ
    ctx = await get_kote_context(tg_chat_id, "моё местоположение") or {}
    client_id = ctx.get("client_id")
    if client_id:
        await save_conversation(
            client_id,
            f"[Геолокация: {lat:.4f}, {lng:.4f}]",
            reply[:200],
        )

    # AI-уточнение: куда именно интересно?
    market = await get_client_market(tg_chat_id)
    system = _build_system(ctx, market=market)
    ai_reply = await ai_ask(
        prompt=f"Пользователь поделился геолокацией (широта {lat:.4f}, долгота {lng:.4f}). "
               f"Спроси в одном коротком предложении: что его интересует — поесть, выпить, пляж, шопинг или что-то ещё?",
        system=system,
        max_tokens=120,
        temperature=0.7,
    )
    await safe_send(message.chat.id, ai_reply)


@dp.message()
async def handle_message(message: types.Message):
    if not message.text:
        # Фото/голос/стикер и пр. — мягко подскажем, что читаем текст
        if message.content_type not in ("text",):
            await safe_send(
                message.chat.id,
                "🐾 Мур, я пока читаю только текст. Напиши словами — и я всё подскажу!",
            )
        return

    # Проверяем не запрос ли это геолокации
    text_lower = message.text.lower().strip()
    if any(trigger in text_lower for trigger in _NEARBY_TRIGGERS):
        kb = ReplyKeyboardMarkup(
            keyboard=[[KeyboardButton(text="📍 Поделиться геолокацией", request_location=True)]],
            resize_keyboard=True,
            one_time_keyboard=True,
        )
        await message.answer(
            "🐾 Поделись геолокацией — покажу что есть рядом с хорошими отзывами!",
            reply_markup=kb,
        )
        return

    tg_chat_id = str(message.chat.id)
    from_user = message.from_user
    name = " ".join(filter(None, [from_user.first_name, from_user.last_name])) or "Гость"
    text = message.text.strip()
    first_name = from_user.first_name or "путник"

    # 1. Upsert client
    await bot_upsert_client(tg_chat_id, name)

    # 1b. СОГЛАСИЕ один раз: пока не согласился — показываем экран «Далее»
    if not await get_client_consent(tg_chat_id):
        await _ask_consent(message)
        return

    # 2. ВОРОНКА: первым делом — рынок. Без него дальше не идём.
    market = await get_client_market(tg_chat_id)
    if not market:
        # Может, человек сам назвал направление в сообщении?
        detected = detect_market_from_text(text)
        if detected:
            market = detected
            await set_client_market(tg_chat_id, market)
            await update_client_stage(tg_chat_id, "interest")
        else:
            await _ask_market(message, first_name)
            return

    # 2b. Валюта счёта — если человек упомянул тенге/рубли/страну, запомним
    cur_detected = detect_currency_from_text(text)
    if cur_detected:
        await set_client_currency(tg_chat_id, cur_detected)

    # 2d. CRM: авто-сбор контактов из сообщения (телефон/почта)
    await capture_contacts(tg_chat_id, text)

    # 2c. Скидки (применяет сервер, потолок 3.5%): 1-я секретка 3.5% / 2-я 2.5% / запрос 1.5%
    discount_event = None
    lvl = detect_discount_level(text)
    if lvl > 0:
        new_d = await set_client_discount(tg_chat_id, lvl)
        kind = "secret" if lvl >= 2.5 else "request"
        discount_event = (kind, new_d)

    await message.chat.do("typing")

    # 3. Load full context: history, tours, knowledge, memory
    ctx = await get_kote_context(tg_chat_id, text) or {}
    client_discount = await get_client_discount(tg_chat_id)

    # 4. Build prompt (каталог под выбранный рынок) + call AI (fallback chain)
    # Пасхалка: если клиент сам упомянул другой рынок (напр. Вьетнам) — подмешиваем его туры
    extra_market = detect_mentioned_market(text)
    gender = guess_gender(from_user.first_name)
    posture = _sales_posture(text, ctx)
    system = _build_system(ctx, market=market, extra_market=extra_market,
                           discount=client_discount, discount_event=discount_event,
                           gender=gender, posture=posture)
    online = _needs_web(text, ctx)
    reply = await ai_ask(
        prompt=text,
        system=system,
        max_tokens=700 if online else 600,
        temperature=0.85,
        online=online,
    )

    # 5. Если КотЭ оформил заказ (<order>…</order>) — создаём бронь + оплату
    final_reply = reply
    if "<order>" in reply:
        try:
            final_reply = await process_order(reply, ctx, market, tg_chat_id, from_user)
        except Exception as e:
            log.warning(f"process_order error: {e}")
            final_reply = _ORDER_RE.sub("", reply).strip() or reply

    # 5b. Самообучение: если КотЭ узнал новый факт (<learn>…</learn>) — в базу на модерацию
    if "<learn>" in final_reply:
        final_reply = await process_learn(final_reply)

    # 5c. CRM: если КотЭ собрал данные клиента (<profile>…</profile>) — в карточку
    if "<profile>" in final_reply:
        final_reply = await process_profile(final_reply, tg_chat_id)

    # 6. Send reply to Telegram (надёжно: фолбэк HTML + разбивка длинных)
    await safe_send(message.chat.id, final_reply, disable_web_page_preview=True)

    # 7. Save conversation to Supabase (сохраняем то, что увидел клиент)
    client_id = ctx.get("client_id")
    await save_conversation(client_id, text, final_reply)

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

    # 8. Update funnel stage + хендофф менеджеру на стадии брони
    if intent.new_stage:
        prev_stage = ctx.get("client_stage")
        await update_client_stage(tg_chat_id, intent.new_stage)
        if intent.new_stage == "booking" and prev_stage != "booking":
            uname = from_user.username or "—"
            await notify.escalation(
                client=f"{name} (@{uname})",
                chat_id=tg_chat_id,
                reason=f"Готов(а) к брони [{MARKET_NAMES.get(market, market)}]: «{text[:120]}»",
            )


def _format_receipt(booking: dict, amount: int, currency: str = "RUB") -> str:
    """Чек клиенту после успешной оплаты."""
    num = _short_id(booking.get("id"))
    tour_name = booking.get("tour_name") or "Экскурсия"
    date_start = booking.get("date_start") or "уточним"
    adults = booking.get("adults") or 0
    children = booking.get("children") or 0
    people_line = f"{adults} взр." + (f" + {children} дет." if children else "")
    cl = booking.get("clients") or {}
    cname = (cl.get("name") if isinstance(cl, dict) else None) or "Гость"
    return (
        "🧾 <b>Чек об оплате — Нестандартный Отдых</b>\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        f"✅ Оплачено: <b>{cur_mod.fmt(amount, currency)}</b>\n"
        f"🆔 Заказ: #{num}\n"
        f"🏝 Тур: {tour_name}\n"
        f"📅 Дата: {date_start}\n"
        f"👥 Гостей: {people_line}\n"
        f"👤 На имя: {cname}\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "Всё готово! 🐾 Наш гид свяжется с тобой заранее — расскажет, "
        "где и во сколько встречаемся. С тебя только отдых и хорошее настроение! 🌴\n\n"
        "Вопросы? Я всегда на связи. Менеджер: @nestandart_phuket"
    )


async def _deliver_gift_certificate(gift: dict) -> None:
    """После оплаты подарка — шлёт дарителю красивый сертификат с кодом и ссылкой активации."""
    buyer_chat = gift.get("buyer_chat")
    if not buyer_chat:
        return
    code = gift.get("code")
    amount_thb = int(float(gift.get("amount") or 0))
    recipient = gift.get("recipient") or "получателя"
    activate = f"https://t.me/{BOT_USERNAME}?start=gift_{code}"
    text = (
        "🎁 <b>ВАШ ПОДАРОЧНЫЙ СЕРТИФИКАТ ГОТОВ!</b>\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "🐾 «Нестандартный Отдых»\n"
        f"💎 Номинал: <b>{cur_mod.fmt_thb(amount_thb)}</b>\n"
        f"🎟️ Код: <code>{code}</code>\n"
        f"🎀 Для: {recipient}\n"
        "━━━━━━━━━━━━━━━━━━━━\n\n"
        "Просто перешли это сообщение тому, кого хочешь порадовать 💝\n"
        f"Активация одной кнопкой: {activate}\n\n"
        "Получатель нажмёт — и подарок зачислится ему на счёт. "
        "Код одноразовый: сработает только раз, никто другой им не воспользуется 🔒🐾"
    )
    await safe_send(buyer_chat, text, disable_web_page_preview=True)


async def yookassa_webhook(request: web.Request):
    """Вебхук ЮKassa: payment.succeeded → отметка оплаты + чек клиенту + уведомление."""
    try:
        peer = request.headers.get("X-Forwarded-For", "").split(",")[0].strip() or (
            request.remote or "")
        if peer and not payments.verify_webhook_ip(peer):
            log.warning(f"yookassa webhook from untrusted ip: {peer}")
            return web.Response(status=403, text="forbidden")

        data = await request.json()
        event = data.get("event")
        obj = data.get("object", {})
        if event != "payment.succeeded":
            return web.Response(text="ignored")

        payment_id = obj.get("id")
        meta = obj.get("metadata", {}) or {}
        amount = int(float(obj.get("amount", {}).get("value", 0)))
        pay_cur = obj.get("amount", {}).get("currency", "RUB")

        booking = await mark_payment_succeeded(payment_id)
        if not booking:
            log.warning(f"yookassa: booking not found for payment {payment_id}")
            return web.Response(text="ok")

        cl = booking.get("clients") or {}
        chat_id = (cl.get("tg_chat_id") if isinstance(cl, dict) else None) or meta.get("tg_chat_id")

        # Это покупка ПОДАРКА? Тогда активируем сертификат и шлём код дарителю.
        gift = await mark_gift_paid_by_booking(booking.get("id"))
        if gift and gift.get("code"):
            await _deliver_gift_certificate(gift)
        else:
            # Обычная бронь: чек клиенту + бонус пригласившему
            if chat_id:
                await safe_send(chat_id, _format_receipt(booking, amount, pay_cur))
            if chat_id and booking.get("total"):
                await credit_referrer_bonus(str(chat_id), float(booking["total"]))

        await notify.payment_ok(
            tour=booking.get("tour_name") or "—",
            amount=cur_mod.fmt(amount, pay_cur),
            client=(cl.get("name") if isinstance(cl, dict) else None) or "Гость",
            payment_id=payment_id or "—",
        )
        return web.Response(text="ok")
    except Exception as e:
        log.warning(f"yookassa_webhook error: {e}")
        return web.Response(text="error")


async def crypto_webhook(request: web.Request):
    """IPN NOWPayments: оплата криптой подтверждена → отметка + чек клиенту."""
    try:
        raw = await request.read()
        sig = request.headers.get("x-nowpayments-sig", "")
        if not crypto_mod.verify_ipn(raw, sig):
            log.warning("crypto IPN: bad signature")
            return web.Response(status=403, text="forbidden")

        data = json.loads(raw)
        status = data.get("payment_status", "")
        booking_id = data.get("order_id")
        if status not in crypto_mod.PAID_STATUSES:
            return web.Response(text="ignored")
        if not booking_id:
            return web.Response(text="ok")

        booking = await mark_crypto_paid(booking_id)
        if not booking:
            log.warning(f"crypto: booking not found {booking_id}")
            return web.Response(text="ok")

        amount_usd = int(float(data.get("price_amount", 0)))
        cl = booking.get("clients") or {}
        chat_id = cl.get("tg_chat_id") if isinstance(cl, dict) else None

        gift = await mark_gift_paid_by_booking(booking.get("id"))
        if gift and gift.get("code"):
            await _deliver_gift_certificate(gift)
        else:
            if chat_id:
                await safe_send(chat_id, _format_receipt(booking, amount_usd, "USD"))
            if chat_id and booking.get("total"):
                await credit_referrer_bonus(str(chat_id), float(booking["total"]))

        await notify.payment_ok(
            tour=booking.get("tour_name") or "—",
            amount=f"{cur_mod.fmt(amount_usd, 'USD')} (крипта)",
            client=(cl.get("name") if isinstance(cl, dict) else None) or "Гость",
            payment_id=str(data.get("payment_id") or booking_id),
        )
        return web.Response(text="ok")
    except Exception as e:
        log.warning(f"crypto_webhook error: {e}")
        return web.Response(text="error")


# ── Entry point ────────────────────────────────────────────────────────────────
async def main():
    if WEBHOOK_URL:
        log.info(f"Webhook mode: {WEBHOOK_URL}{WEBHOOK_PATH}")
        await bot.set_webhook(f"{WEBHOOK_URL}{WEBHOOK_PATH}")
        async def health(request):
            return web.Response(text="ok")

        app = web.Application()
        app.router.add_get("/health", health)
        app.router.add_post("/bot/yookassa", yookassa_webhook)
        app.router.add_post("/bot/crypto", crypto_webhook)
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
