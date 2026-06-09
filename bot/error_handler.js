/**
 * Global Error Handler — KOTЭ Bot
 */

const logger = require('./logger');

function setupErrorHandlers(bot) {
  // Telegraf error handler
  bot.catch((err, ctx) => {
    logger.error('Bot', 'Unhandled error', {
      error: err.message,
      userId: ctx.from?.id,
      chatId: ctx.chat?.id,
    });

    if (ctx && ctx.reply) {
      ctx.reply('🐾 Что-то пошло не так. Попробуй ещё раз.').catch(() => {});
    }
  });

  // Node.js unhandled rejection
  process.on('unhandledRejection', (reason) => {
    logger.error('Process', 'Unhandled rejection', {
      reason: reason?.message || String(reason),
    });
  });

  // Node.js uncaught exception
  process.on('uncaughtException', (err) => {
    logger.error('Process', 'Uncaught exception', {
      error: err.message,
      stack: err.stack,
    });
    process.exit(1);
  });
}

module.exports = { setupErrorHandlers };