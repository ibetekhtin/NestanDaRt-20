// ============================================================================
// Supabase Client — бот не хранит состояние, только Supabase
// ============================================================================

const { createClient } = require('@supabase/supabase-js');

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY;

if (!url || !key) {
  console.error('[Bot] SUPABASE_URL и SUPABASE_KEY обязательны в .env');
  process.exit(1);
}

const supabase = createClient(url, key);

// --- Helpers: Market ---
async function getActiveMarkets() {
  const { data } = await supabase.from('markets').select('*').eq('active', true);
  return data || [];
}

async function getMarketById(id) {
  const { data } = await supabase.from('markets').select('*').eq('id', id).single();
  return data;
}

// --- Helpers: Client ---
async function upsertClient(marketId, telegramId, name, phone) {
  const { data, error } = await supabase
    .from('clients')
    .upsert(
      { market_id: marketId, telegram_id: String(telegramId), name, phone: phone || null },
      { onConflict: 'telegram_id' }
    )
    .select()
    .single();
  if (error) throw error;
  return data;
}

async function getClientByTelegram(telegramId) {
  const { data } = await supabase
    .from('clients')
    .select('*')
    .eq('telegram_id', String(telegramId))
    .single();
  return data;
}

// --- Helpers: Services ---
async function getServicesByMarket(marketId, type) {
  let query = supabase.from('services').select('*').eq('market_id', marketId).eq('available', true);
  if (type) query = query.eq('type', type);
  const { data } = await query;
  return data || [];
}

// --- Helpers: Bookings ---
async function createBooking(marketId, clientId, serviceId, date, total) {
  const { data, error } = await supabase
    .from('bookings')
    .insert({
      market_id: marketId,
      client_id: clientId,
      service_id: serviceId,
      date,
      total,
      status: 'draft',
    })
    .select()
    .single();
  if (error) throw error;
  return data;
}

async function updateBookingStatus(bookingId, status) {
  const { data, error } = await supabase
    .from('bookings')
    .update({ status })
    .eq('id', bookingId)
    .select()
    .single();
  if (error) throw error;
  return data;
}

async function getClientBookings(clientId) {
  const { data } = await supabase
    .from('booking_details')
    .select('*')
    .eq('client_id', clientId)
    .order('date', { ascending: false })
    .limit(20);
  return data || [];
}

async function getBookingDetails(bookingId) {
  const { data } = await supabase
    .from('booking_details')
    .select('*')
    .eq('id', bookingId)
    .single();
  return data;
}

// --- Helpers: Messages ---
async function saveMessage(marketId, clientId, sessionId, role, content) {
  const { error } = await supabase.from('messages').insert({
    market_id: marketId,
    client_id: clientId || null,
    session_id: sessionId,
    role,
    content,
  });
  if (error) console.error('[Bot] Message save error:', error);
}

async function getMessages(sessionId, limit = 20) {
  const { data } = await supabase
    .from('messages')
    .select('role, content')
    .eq('session_id', sessionId)
    .order('created_at', { ascending: false })
    .limit(limit);
  return (data || []).reverse();
}

module.exports = {
  supabase,
  getActiveMarkets,
  getMarketById,
  upsertClient,
  getClientByTelegram,
  getServicesByMarket,
  createBooking,
  updateBookingStatus,
  getClientBookings,
  getBookingDetails,
  saveMessage,
  getMessages,
};
