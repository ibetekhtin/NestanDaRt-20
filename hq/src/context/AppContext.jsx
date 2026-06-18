import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase, isSupabaseConfigured } from '../supabase';

const AppContext = createContext();

const DEFAULT_MARKET = import.meta.env.VITE_DEFAULT_MARKET || 'phuket';

// City → market mapping — синхронизировано с shared/markets.js и DB
const MARKET_CITY = {
  phuket: 'Пхукет',
  pattaya: 'Паттайя',
  bali: 'Бали',
  dubai: 'Дубай',
  vietnam: 'Вьетнам',
  srilanka: 'Шри-Ланка',
};

export const AppProvider = ({ children }) => {
  const [activeMarket, setActiveMarket] = useState(DEFAULT_MARKET);
  const [loading, setLoading] = useState(false);

  const [tours, setTours] = useState([]);
  const [clients, setClients] = useState([]);
  const [bookings, setBookings] = useState([]);
  const [payments, setPayments] = useState([]);
  const [knowledge, setKnowledge] = useState([]);
  const [contentPlan, setContentPlan] = useState([]);

  const city = MARKET_CITY[activeMarket] || 'Пхукет';

  const fetchAll = useCallback(async () => {
    if (!isSupabaseConfigured) return;
    setLoading(true);
    try {
      const [toursRes, clientsRes, bookingsRes, paymentsRes, knowledgeRes, contentRes] = await Promise.all([
        supabase.from('tours').select('*').eq('city', city).order('sort_order'),
        supabase.from('clients').select('*').order('created_at', { ascending: false }),
        supabase.from('bookings').select('*, clients(name, phone, telegram), tours(title, city)').order('created_at', { ascending: false }),
        supabase.from('payments').select('*, bookings(tour_name, total)').order('created_at', { ascending: false }),
        supabase.from('knowledge').select('*').eq('city', city).eq('active', true).order('priority', { ascending: false }),
        supabase.from('content_plan').select('*').eq('city', city).order('date'),
      ]);
      if (toursRes.data)    setTours(toursRes.data);
      if (clientsRes.data)  setClients(clientsRes.data);
      if (bookingsRes.data) setBookings(bookingsRes.data);
      if (paymentsRes.data) setPayments(paymentsRes.data);
      if (knowledgeRes.data) setKnowledge(knowledgeRes.data);
      if (contentRes.data)  setContentPlan(contentRes.data);
    } finally {
      setLoading(false);
    }
  }, [city]);

  // Загрузка данных при смене рынка — асинхронный fetch, каскада рендеров нет
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { fetchAll(); }, [fetchAll]);

  // --- Clients (через RPC app_upsert_lead — единая точка записи) ---
  const addClient = async (client) => {
    if (!isSupabaseConfigured) return;
    const { data, error } = await supabase.rpc('app_upsert_lead', {
      p_name: client.name || '',
      p_phone: client.phone || '',
      p_telegram: client.telegram || '',
      p_tg_chat_id: client.tg_chat_id || client.telegram || '',
      p_source: client.source || 'hq',
      p_market_id: activeMarket,
    });
    if (error) { console.error('[HQ] addClient RPC error:', error); return null; }
    // После RPC перезагружаем список клиентов
    const { data: fresh } = await supabase.from('clients').select('*').order('created_at', { ascending: false });
    if (fresh) setClients(fresh);
    return data;
  };

  const updateClient = async (id, updates) => {
    if (!isSupabaseConfigured) return;
    const { data } = await supabase.from('clients').update(updates).eq('id', id).select().single();
    if (data) setClients(prev => prev.map(c => c.id === id ? data : c));
  };

  const updateClientStage = async (id, stage) => updateClient(id, { stage, last_contact: new Date().toISOString() });

  // --- Bookings ---
  const addBooking = async (booking) => {
    if (!isSupabaseConfigured) return;
    const { data, error } = await supabase.from('bookings').insert([{
      client_id: booking.client_id,
      tour_id: booking.tour_id,
      status: booking.status || 'draft',
      date_start: booking.date_start,
      date_end: booking.date_end,
      guests: booking.guests || 1,
      total: booking.total || 0,
      notes: booking.notes || '',
    }]).select('*, clients(name), tours(title)').single();
    if (error) { console.error('[HQ] addBooking error:', error); return null; }
    if (data) setBookings(prev => [data, ...prev]);
    return data;
  };

  const updateBookingStatus = async (id, status) => {
    if (!isSupabaseConfigured) return;
    const { data } = await supabase.from('bookings').update({ status }).eq('id', id).select().single();
    if (data) setBookings(prev => prev.map(b => b.id === id ? { ...b, status } : b));
  };

  // --- Content plan ---
  const addPost = async (post) => {
    if (!isSupabaseConfigured) return;
    const { data } = await supabase.from('content_plan').insert([{ ...post, city }]).select().single();
    if (data) setContentPlan(prev => [...prev, data]);
    return data;
  };

  const togglePostStatus = async (id) => {
    const post = contentPlan.find(p => p.id === id);
    if (!post || !isSupabaseConfigured) return;
    const status = post.status === 'ready' ? 'draft' : 'ready';
    const { data } = await supabase.from('content_plan').update({ status }).eq('id', id).select().single();
    if (data) setContentPlan(prev => prev.map(p => p.id === id ? data : p));
  };

  // --- Stats (derived) ---
  const stats = {
    totalClients: clients.length,
    activeBookings: bookings.filter(b => b.status === 'Подтверждён' || b.status === 'Активный').length,
    newLeads: clients.filter(c => c.stage === 'new' || c.stage === 'interest').length,
    totalRevenue: payments.filter(p => p.status === 'succeeded').reduce((sum, p) => sum + (p.amount || 0), 0),
    totalTours: tours.filter(t => t.active).length,
  };

  return (
    <AppContext.Provider value={{
      activeMarket, setActiveMarket,
      loading, refetch: fetchAll,
      tours, clients, bookings, payments, knowledge, contentPlan,
      stats,
      addClient, updateClient, updateClientStage,
      addBooking, updateBookingStatus,
      addPost, togglePostStatus,
    }}>
      {children}
    </AppContext.Provider>
  );
};

// eslint-disable-next-line react-refresh/only-export-components
export const useApp = () => useContext(AppContext);
