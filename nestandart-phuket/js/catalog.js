/* ============================================================
   catalog.js — ЕДИНЫЙ СЛОЙ ДАННЫХ (синхронизация с Supabase)
   Туры, наборы и знания тянутся напрямую из базы — той же, что
   использует бот и приложение. Правка в базе → меняется ВЕЗДЕ сразу.
   anon-ключ публичный: доступ только на чтение активного контента (RLS).
   ============================================================ */
(function () {
  const SB_URL = 'https://cmmdrhususjuadqzyssc.supabase.co';
  const SB_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtbWRyaHVzdXNqdWFkcXp5c3NjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0OTQxODcsImV4cCI6MjA5NjA3MDE4N30.IDExX_9wO21I8HIs_rJzDwMwAdD5xIBH5zHI043FEhs';
  const H = { apikey: SB_ANON, Authorization: 'Bearer ' + SB_ANON };

  // курс баты→рубли (как на боте по умолчанию; можно заменить на live позже)
  const THB_RUB = 3.0;

  async function _get(path) {
    const r = await fetch(SB_URL + '/rest/v1/' + path, { headers: H });
    if (!r.ok) { console.warn('[catalog]', path, r.status); return []; }
    return r.json();
  }

  const Catalog = {
    THB_RUB,
    rub(thb) { return Math.round((thb || 0) * THB_RUB / 10) * 10; },

    /** Активные туры рынка (market: 'phuket'|'pattaya'|'vietnam'). */
    async tours(market = 'phuket') {
      return _get(`tours?market_id=eq.${market}&active=eq.true&select=*&order=sort_order`);
    },
    /** Туры по категории. */
    async toursByCategory(market, category) {
      return _get(`tours?market_id=eq.${market}&active=eq.true&category=eq.${encodeURIComponent(category)}&select=*&order=sort_order`);
    },
    /** Один тур по slug. */
    async tour(slug) {
      const d = await _get(`tours?slug=eq.${encodeURIComponent(slug)}&select=*&limit=1`);
      return d[0] || null;
    },
    /** Активные наборы рынка. */
    async packages(market = 'phuket') {
      return _get(`packages?market_id=eq.${market}&active=eq.true&select=*&order=sort_order`);
    },
    /** База знаний (места/советы) по городу. */
    async knowledge(city) {
      return _get(`knowledge?active=eq.true&city=eq.${encodeURIComponent(city)}&select=title,content,category,area,price_info,insider_tip&order=priority.desc`);
    },
  };

  window.Catalog = Catalog;
})();
