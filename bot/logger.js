/**
 * Structured JSON Logger — KOTЭ Bot
 */

const LOG_LEVEL = process.env.BOT_LOG_LEVEL || 'info';

const LEVELS = { debug: 0, info: 1, warn: 2, error: 3 };
const currentLevel = LEVELS[LOG_LEVEL] || 1;

function log(level, component, message, data = {}) {
  if (LEVELS[level] < currentLevel) return;

  const entry = {
    ts: new Date().toISOString(),
    level,
    component,
    message,
    ...data,
  };

  const line = JSON.stringify(entry);

  if (level === 'error') {
    console.error(line);
  } else if (level === 'warn') {
    console.warn(line);
  } else {
    console.log(line);
  }
}

module.exports = {
  debug: (component, message, data) => log('debug', component, message, data),
  info: (component, message, data) => log('info', component, message, data),
  warn: (component, message, data) => log('warn', component, message, data),
  error: (component, message, data) => log('error', component, message, data),
};