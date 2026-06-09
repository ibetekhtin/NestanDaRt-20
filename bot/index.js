// ============================================================================
// Нестандартный Отдых — Telegram Bot (КотЭ)
// ============================================================================
// Архитектура: User → Bot → AI (КотЭ) → Supabase → n8n → Provider → User
// Бот не хранит состояние. Всё через Supabase.
// ============================================================================

const { Telegraf, session } = require('telegraf');
const {
  upsertClient,
  getClientByTelegram,
  getServicesByMarket,
  createBooking,
  updateBookingStatus,
  getActiveMarkets,
  getMarketById,
  getClientBookings,
  saveMessage,
  getMessages,
} = require('./supabase');
const { getAIResponse } = require('./ai');

// --- Config ---
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
if (!BOT_TOKEN) {
  console.error('[Bot] TELEGRAM_BOT_TOKEN обязателен');
  process.exit(1);
}

const bot = new Telegraf(BOT_TOKEN);

// --- Константы ---
// Тип услуги → emoji. Единая точка правды для бота и сайта.
const TYPE_EMOJI = { tour: '🏖 Тур', transfer: '🚐 Трансфер', rental: '🛵 Аренда' };
// Дефолтный emoji для рынка
const MARKET_EMOJI_FALLBACK = '📍';

// --- Helpers ---

// Emoji для рынка: первый emoji-символ из name (например, "🏖 Пхукет" → 🏖)
function marketEmoji(name) {
  if (!name) return MARKET_EMOJI_FALLBACK;
  const first = name.trim().charAt(0);
  return /\p{Extended_Pictographic}/u.test(first) ? first : MARKET_EMOJI_FALLBACK;
}

// Безопасный ответ: всегда пытаемся ответить пользователю, не падаем
// extra — опциональный объект {reply_markup: ...} для inline-кнопок
async function safeReply(ctx, text, extra) {
  try {
    if (extra) {
      await ctx.reply(text, extra);
    } else {
      await ctx.reply(text);
    }
  } catch (e) {
    console.error('[Bot] Reply failed:', e.message);
  }
}

// Безопасный answerCbQuery
async function safeAnswerCb(ctx, text) {
  try {
    await ctx.answerCbQuery(text);
  } catch (e) {
    /* callback уже истёк — ок */
  }
}

// --- State (только сессия Telegram, НЕ бизнес-логика) ---
bot.use(session({ defaultSession: () => ({ market: null }) }));

// ============================================================================
// Middleware: base — загружаем клиента и рынок в ctx
// ============================================================================
bot.use(async (ctx, next) => {
  try {
    if (ctx.from && ctx.from.id) {
      const client = await getClientByTelegram(ctx.from.id);
      ctx.state.client = client;
      if (client && !ctx.session.market) {
        ctx.session.market = client.market_id;
      }
    }
  } catch (e) {
    console.error('[Bot] Middleware error:', e.message);
  }
  await next();
});

// ============================================================================
// Render: список услуг (общая функция для /services и callback type:)
// ============================================================================
async function renderServices(ctx, type) {
  const market = ctx.session.market;
  if (!market) {
    await safeReply(ctx, '⚠️ Сначала выбери направление через /start');
    return;
  }

  const services = await getServicesByMarket(market, type);
  if (!services.length) {
    await safeReply(ctx, `Нет доступных услуг${type ? ` типа «${TYPE_EMOJI[type] || type}»` : ''} в этом направлении.`);
    return;
  }

  const lines = services.map(
    (s, i) => `${i + 1}. *${s.title}*\n_${s.description || '-'}_\n💰 ${s.price} ${s.currency}`
  );

  await safeReply(ctx, lines.join('\n\n'));
  await safeReply(ctx, '👇 Выбери услугу для бронирования:', {
    reply_markup: {
      inline_keyboard: services.map((s) => [{ text: `📌 ${s.title}`, callback_data: `book:${s.id}` }]),
    },
  });
}

// ============================================================================
// Команды
// ============================================================================

bot.start(async (ctx) => {
  const name = ctx.from.first_name || 'Путник';
  ctx.session.market = null;

  let markets;
  try {
    markets = await getActiveMarkets();
  } catch (e) {
    console.error('[Bot] getActiveMarkets:', e.message);
    await safeReply(ctx, '🐾 Не могу загрузить направления. Попробуй позже.');
    return;
  }

  if (!markets.length) {
    await safeReply(ctx, '🐾 Нет доступных направлений. Попробуй позже.');
    return;
  }

  const currentClientMarket = ctx.state.client?.market_id;
  const sorted = [...markets].sort((a, b) => {
    if (a.id === currentClientMarket) return -1;
    if (b.id === currentClientMarket) return 1;
    return 0;
  });

  const buttons = sorted.map((m) => [
    {
      text: `${marketEmoji(m.name)} ${m.name}${m.id === currentClientMarket ? ' ✅' : ''}`,
      callback_data: `market:${m.id}`,
    },
  ]);

  await safeReply(ctx,
    `🐾 Привет, ${name}!\nЯ — КотЭ, твой помощник на отдыхе.\n\nВыбери направление:`
  );
  await safeReply(ctx, '👇 Направления:', {
    reply_markup: { inline_keyboard: buttons },
  });
});

bot.help(async (ctx) => {
  await safeReply(ctx,
    '🐾 *КотЭ — твой помощник*\n\n' +
      '*/start* — начать заново\n' +
      '*/services* — все услуги\n' +
      '*/bookings* — мои брони\n' +
      '*/help* — помощь\n\n' +
      'Или просто напиши — я помогу!'
  );
});

bot.command('services', async (ctx) => renderServices(ctx));

bot.command('bookings', async (ctx) => {
  const client = ctx.state.client;
  if (!client) {
    await safeReply(ctx, '⚠️ Сначала нажми /start');
    return;
  }

  let bookings;
  try {
    bookings = await getClientBookings(client.id);
  } catch (e) {
    console.error('[Bot] getClientBookings:', e.message);
    await safeReply(ctx, '🐾 Не могу загрузить брони. Попробуй позже.');
    return;
  }

  if (!bookings.length) {
    await safeReply(ctx, '📋 У тебя пока нет бронирований.');
    return;
  }

  const statusEmoji = { draft: '📝', pending: '⏳', confirmed: '✅', completed: '✔️', cancelled: '❌' };

  const lines = bookings.map(
    (b, i) =>
      `${i + 1}. ${statusEmoji[b.status] || '📌'} *${b.service_title}*\n📅 ${b.date}  💰 ${b.total} ${b.currency}`
  );

  await safeReply(ctx, '📋 *Твои брони:*\n\n' + lines.join('\n\n'));
});

// ============================================================================
// Callback: Выбор рынка
// ============================================================================

bot.action(/^market:(.+)$/, async (ctx) => {
  const marketId = ctx.match[1];

  let market;
  try {
    market = await getMarketById(marketId);
  } catch (e) {
    console.error('[Bot] getMarketById:', e.message);
    await safeAnswerCb(ctx, 'Ошибка');
    return;
  }

  if (!market || !market.active) {
    await safeAnswerCb(ctx, 'Это направление недоступно');
    return;
  }

  ctx.session.market = marketId;

  try {
    await upsertClient(marketId, ctx.from.id, ctx.from.first_name || 'Путник');
  } catch (e) {
    console.error('[Bot] upsertClient:', e.message);
    await safeAnswerCb(ctx, 'Ошибка сохранения');
    return;
  }

  await safeAnswerCb(ctx);
  await safeReply(ctx, `✅ ${market.name}\n\nЧто интересует?`);
  await safeReply(ctx, '👇 Категории:', {
    reply_markup: {
      inline_keyboard: [
        [{ text: '🏖 Туры', callback_data: 'type:tour' }],
        [{ text: '🚐 Трансферы', callback_data: 'type:transfer' }],
        [{ text: '🛵 Аренда', callback_data: 'type:rental' }],
      ],
    },
  });
});

// ============================================================================
// Callback: Показать услуги по типу
// ============================================================================

bot.action(/^type:(.+)$/, async (ctx) => {
  await safeAnswerCb(ctx);
  await renderServices(ctx, ctx.match[1]);
});

// ============================================================================
// Callback: Создать бронь
// ============================================================================

bot.action(/^book:(.+)$/, async (ctx) => {
  const serviceId = ctx.match[1];
  const market = ctx.session.market;

  if (!market) {
    await safeAnswerCb(ctx, 'Сначала выбери направление');
    return;
  }

  const client = ctx.state.client;
  if (!client) {
    await safeAnswerCb(ctx, '⚠️ Сначала нажми /start');
    return;
  }

  let services;
  try {
    services = await getServicesByMarket(market);
  } catch (e) {
    console.error('[Bot] getServicesByMarket:', e.message);
    await safeAnswerCb(ctx, 'Ошибка');
    return;
  }

  const service = services.find((s) => s.id === serviceId);
  if (!service) {
    await safeAnswerCb(ctx, '⚠️ Услуга не найдена');
    return;
  }

  const today = new Date().toISOString().split('T')[0];
  let booking;
  try {
    booking = await createBooking(market, client.id, serviceId, today, service.price);
  } catch (e) {
    console.error('[Bot] createBooking:', e.message);
    await safeAnswerCb(ctx, 'Ошибка создания');
    await safeReply(ctx, '🐾 Не удалось создать бронь. Попробуй ещё раз или свяжись с менеджером.');
    return;
  }

  await safeAnswerCb(ctx, '✅');
  await safeReply(ctx,
    `✅ Бронь создана!\n\n` +
      `📦 ${service.title}\n💰 ${service.price} ${service.currency}\n📅 ${today}\n🆔 ${booking.id.slice(0, 8)}`
  );
});

// ============================================================================
// Callback: Управление бронями (отмена)
// ============================================================================

bot.action(/^cancel_booking:(.+)$/, async (ctx) => {
  try {
    await updateBookingStatus(ctx.match[1], 'cancelled');
    await safeAnswerCb(ctx, '✅ Бронь отменена');
    await safeReply(ctx, '❌ Бронь отменена.');
  } catch (e) {
    console.error('[Bot] cancel:', e.message);
    await safeAnswerCb(ctx, 'Ошибка отмены');
  }
});

// ============================================================================
// Fallback: текст → AI (КотЭ)
// ============================================================================

bot.on('text', async (ctx) => {
  const userId = ctx.from.id;
  const text = ctx.message.text;
  const market = ctx.session.market;

  if (!market) {
    await safeReply(ctx, '⚠️ Сначала выбери направление через /start');
    return;
  }

  // Клиент уже должен быть в ctx.state.client (middleware)
  let client = ctx.state.client;
  if (!client) {
    try {
      client = await upsertClient(market, userId, ctx.from.first_name || 'Путник');
    } catch (e) {
      console.error('[Bot] upsertClient (text):', e.message);
      await safeReply(ctx, '🐾 Ошибка. Попробуй позже.');
      return;
    }
  }

  const sessionId = `tg:${userId}`;

  try {
    await saveMessage(market, client.id, sessionId, 'user', text);
  } catch (e) {
    // saveMessage уже логирует; продолжаем
  }

  let history = [];
  try {
    history = await getMessages(sessionId, 10);
  } catch (e) {
    console.error('[Bot] getMessages:', e.message);
  }

  try {
    await ctx.sendChatAction('typing');
  } catch (e) { /* не критично */ }

  let reply;
  try {
    reply = await getAIResponse(history, market);
  } catch (e) {
    console.error('[Bot] AI:', e.message);
    await safeReply(ctx, '🐾 Сейчас не могу ответить. Попробуй позже!');
    return;
  }

  try {
    await saveMessage(market, client.id, sessionId, 'assistant', reply);
  } catch (e) {
    // ок
  }

  await safeReply(ctx, reply);
});

// ============================================================================
// Error handling — глобальный
// ============================================================================

bot.catch((err, ctx) => {
  console.error('[Bot] Unhandled error:', err.message);
  if (ctx && ctx.reply) {
    ctx.reply('🐾 Что-то пошло не так. Попробуй ещё раз.').catch(() => {});
  }
});

// ============================================================================
// Graceful shutdown
// ============================================================================

async function shutdown(signal) {
  console.log(`\n[Bot] Получен сигнал ${signal}, завершение...`);
  await bot.stop();
  process.exit(0);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

// ============================================================================
// Start
// ============================================================================

bot.launch()
  .then(() => console.log('🐾 КотЭ-бот запущен!'))
  .catch((err) => {
    console.error('[Bot] Ошибка запуска:', err.message);
    process.exit(1);
  });
