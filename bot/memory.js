/**
 * Memory System — KOTЭ Bot
 * Manages client memory for AI context
 */

const { supabase } = require('./supabase');

/**
 * Get client memory for AI context
 */
async function getClientContext(clientId, marketId) {
  try {
    const { data } = await supabase.rpc('app_get_client_context', {
      p_client_id: clientId,
      p_market_id: marketId,
    });
    return data || [];
  } catch (e) {
    console.error('[Memory] Get context error:', e.message);
    return [];
  }
}

/**
 * Update client memory (upsert)
 */
async function updateMemory(clientId, marketId, key, value, importance = 5, expiresAt = null) {
  try {
    const { data } = await supabase.rpc('app_update_memory', {
      p_client_id: clientId,
      p_market_id: marketId,
      p_key: key,
      p_value: value,
      p_importance: importance,
      p_expires_at: expiresAt,
    });
    return data;
  } catch (e) {
    console.error('[Memory] Update error:', e.message);
    return null;
  }
}

/**
 * Build memory context string for AI prompt
 */
function buildMemoryContext(memoryArray) {
  if (!memoryArray || memoryArray.length === 0) return '';
  const items = memoryArray.map(m => `${m.key}=${m.value}`).join('; ');
  return `\nПамять клиента: ${items}`;
}

module.exports = {
  getClientContext,
  updateMemory,
  buildMemoryContext,
};