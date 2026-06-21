import { useEffect, useState } from 'react';
import { supabase, isSupabaseConfigured } from '../supabase';
import { MessageSquare, Users, FolderKanban, CreditCard, TrendingUp } from 'lucide-react';

const pct = (a, b) => (b > 0 ? Math.round((a / b) * 100) : 0);

export default function FunnelView() {
  const [data, setData] = useState(null);
  const [err, setErr] = useState(null);

  useEffect(() => {
    if (!isSupabaseConfigured) { setErr('Supabase не настроен'); return; }
    supabase.rpc('get_funnel_stats').then(({ data, error }) => {
      if (error) setErr(error.message); else setData(data);
    });
  }, []);

  if (err) return <div style={{ color: 'var(--accent-amber)', padding: '40px' }}>Ошибка: {err}</div>;
  if (!data) return <div style={{ color: 'var(--text-muted)', padding: '40px' }}>Загружаем воронку...</div>;

  const stages = [
    { key: 'messages', label: 'Сообщения', icon: MessageSquare, color: 'var(--accent-cyan)' },
    { key: 'clients', label: 'Клиенты', icon: Users, color: 'var(--accent-cyan)' },
    { key: 'bookings', label: 'Брони', icon: FolderKanban, color: 'var(--accent-amber)' },
    { key: 'paid', label: 'Оплачено', icon: CreditCard, color: 'var(--accent-emerald)' },
  ];
  const top = Math.max(data.messages || 1, 1);
  const entries = (obj) => Object.entries(obj || {}).sort((a, b) => b[1] - a[1]);

  return (
    <div>
      <div style={{ marginBottom: '32px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: '700' }}>Воронка продаж</h1>
        <p style={{ color: 'var(--text-muted)' }}>Сообщения → клиенты → брони → оплаты · Live · Supabase</p>
      </div>

      {/* Воронка по стадиям */}
      <div className="glass-card" style={{ marginBottom: '24px', padding: '24px' }}>
        {stages.map((s, i) => {
          const val = data[s.key] || 0;
          const width = Math.max((val / top) * 100, 3);
          const prev = i > 0 ? (data[stages[i - 1].key] || 0) : null;
          const Icon = s.icon;
          return (
            <div key={s.key} style={{ marginBottom: i < stages.length - 1 ? '18px' : 0 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                <span style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '14px' }}>
                  <Icon size={16} color={s.color} /> {s.label}
                </span>
                <span style={{ fontWeight: 700, fontSize: '18px' }}>
                  {val.toLocaleString()}
                  {prev !== null && <span style={{ color: 'var(--text-muted)', fontSize: '12px', marginLeft: '8px' }}>{pct(val, prev)}% от пред.</span>}
                </span>
              </div>
              <div style={{ height: '14px', background: 'rgba(255,255,255,0.06)', borderRadius: '7px', overflow: 'hidden' }}>
                <div style={{ width: `${width}%`, height: '100%', background: s.color, borderRadius: '7px', transition: 'width .4s' }} />
              </div>
            </div>
          );
        })}
        <div style={{ marginTop: '20px', display: 'flex', gap: '24px', flexWrap: 'wrap' }}>
          <div><span style={{ color: 'var(--text-muted)', fontSize: '12px' }}>Конверсия клиент→бронь</span>
            <div style={{ fontSize: '20px', fontWeight: 700, color: 'var(--accent-amber)' }}>{pct(data.bookings, data.clients)}%</div></div>
          <div><span style={{ color: 'var(--text-muted)', fontSize: '12px' }}>Конверсия бронь→оплата</span>
            <div style={{ fontSize: '20px', fontWeight: 700, color: 'var(--accent-emerald)' }}>{pct(data.paid, data.bookings)}%</div></div>
          <div><span style={{ color: 'var(--text-muted)', fontSize: '12px' }}>Выручка (оплачено)</span>
            <div style={{ fontSize: '20px', fontWeight: 700, color: 'var(--accent-emerald)' }}>{(data.revenue || 0).toLocaleString()} ₽</div></div>
        </div>
      </div>

      {/* Разбивки */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
        {[['Брони по источникам', data.by_source, 'var(--accent-cyan)'], ['Брони по статусам', data.by_status, 'var(--accent-amber)']].map(([title, obj, color]) => {
          const rows = entries(obj);
          const max = Math.max(...rows.map((r) => r[1]), 1);
          return (
            <div key={title} className="glass-card" style={{ padding: '20px' }}>
              <h3 style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px', fontSize: '15px' }}>
                <TrendingUp size={16} color={color} /> {title}
              </h3>
              {rows.length === 0 && <p style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Нет данных</p>}
              {rows.map(([k, v]) => (
                <div key={k} style={{ marginBottom: '10px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '3px' }}>
                    <span>{k}</span><span style={{ fontWeight: 600 }}>{v}</span>
                  </div>
                  <div style={{ height: '8px', background: 'rgba(255,255,255,0.06)', borderRadius: '4px', overflow: 'hidden' }}>
                    <div style={{ width: `${(v / max) * 100}%`, height: '100%', background: color, borderRadius: '4px' }} />
                  </div>
                </div>
              ))}
            </div>
          );
        })}
      </div>
    </div>
  );
}
