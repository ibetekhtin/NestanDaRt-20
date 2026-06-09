// ============================================================================
// КотЭ — AI модуль (Google Gemini)
// ============================================================================
// Единый модуль для общения с Gemini API.
// Использует SYSTEM_PROMPT из ai/kote_prompt.txt + историю из Supabase.
// ============================================================================

const { GoogleGenerativeAI } = require('@google/generative-ai');
const fs = require('fs');
const path = require('path');

const API_KEY = process.env.GEMINI_API_KEY;
if (!API_KEY) {
  console.error('[AI] GEMINI_API_KEY обязателен в .env');
  process.exit(1);
}

const genAI = new GoogleGenerativeAI(API_KEY);

// Читаем системный промпт из файла (чтобы правки не требовали перезапуска бота)
let systemPrompt = '';
try {
  const promptPath = path.join(__dirname, '..', 'ai', 'kote_prompt.txt');
  systemPrompt = fs.readFileSync(promptPath, 'utf-8');
} catch (e) {
  // Fallback если файла нет
  systemPrompt = 'Ты — КотЭ, дружелюбный AI-помощник. Отвечай на русском, кратко, с 🐾.';
}

// Кешируем модель
let model = null;
function getModel() {
  if (!model) {
    model = genAI.getGenerativeModel({
      model: 'gemini-2.0-flash',
      generationConfig: {
        maxOutputTokens: 600,
        temperature: 0.7,
      },
    });
  }
  return model;
}

/**
 * Получить ответ от Gemini на основе истории сообщений
 * @param {Array} history - массив сообщений [{role, content}]
 * @param {string} market - текущий рынок
 * @returns {Promise<string>}
 */
async function getAIResponse(history, market) {
  try {
    const m = getModel();

    // Формируем контекст: системный промпт + история
    const context = `${systemPrompt}\n\nТекущий рынок: ${market || 'не выбран'}\n\nИстория:\n`;

    const messages = history.map((h) => {
      const prefix = h.role === 'user' ? 'Пользователь' : h.role === 'assistant' ? 'КотЭ' : 'Система';
      return `${prefix}: ${h.content}`;
    });

    const prompt = context + messages.join('\n') + '\nКотЭ:';

    const result = await m.generateContent(prompt);
    const response = result.response.text();

    return response || '🐾 Извини, я временно не могу ответить. Попробуй позже.';
  } catch (error) {
    console.error('[AI] Ошибка Gemini:', error.message);
    if (error.message.includes('SAFETY')) {
      return '🐾 Я не могу ответить на этот запрос. Давай поговорим об отдыхе!';
    }
    if (error.message.includes('QUOTA')) {
      return '🐾 У меня сегодня лимит ответов. Напиши завтра или свяжись с менеджером!';
    }
    return '🐾 У меня сейчас техническая пауза. Напиши чуть позже!';
  }
}

module.exports = { getAIResponse };