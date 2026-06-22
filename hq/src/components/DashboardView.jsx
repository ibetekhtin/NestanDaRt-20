
import { useApp } from '../context/AppContext';
import { Users, FolderKanban, DollarSign, Map, TrendingUp, Star } from 'lucide-react';

const STAGE_LABEL = { new: 'Новый', interest: 'Интерес', thinking: 'Думает', booking: 'Бронирует', done: 'Завершён', cold: 'Холодный' };
const STAGE_COLOR = { new: 'var(--accent-cyan)', interest: 'var(--accent-amber)', thinking: 'var(--accent-amber)', booking: 'var(--accent-emerald)', done: 'var(--text-muted)', cold: 'var(--text-muted)' };

export default function DashboardView() {
  const { stats, bookings, clients, loading } = useApp();

  if (loading) return <div style={{ color: 'var(--text-muted)', padding: '40px' }}>Загружаем данные из Supabase...</div>;

  const recentBookings = bookings.slice(0, 5);

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: '700' }}>Дашборд CEO</h1>
          <p style={{ color: 'var(--text-muted)' }}>БАЗА · Нестандартный Отдых® — оперативная сводка</p>
        </div>
        <div className="glass-card" style={{ padding: '10px 20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
          <TrendingUp color="var(--accent-cyan)" size={18} />
          <span style={{ fontSize: '14px', fontWeight: '500' }}>Live · Supabase</span>
        </div>
      </div>

      {/* KPI */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: '16px', marginBottom: '32px' }}>
        <div className="glass-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
            <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Клиенты</span>
            <Users color="var(--accent-cyan)" size={18} />
          </div>
          <h2 style={{ fontSize: '28px', fontWeight: '700' }}>{stats.totalClients}</h2>
          <p style={{ color: 'var(--accent-cyan)', fontSize: '12px', marginTop: '4px' }}>{stats.newLeads} новых лидов</p>
        </div>

        <div className="glass-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
            <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Заявки</span>
            <FolderKanban color="var(--accent-amber)" size={18} />
          </div>
          <h2 style={{ fontSize: '28px', fontWeight: '700' }}>{bookings.length}</h2>
          <p style={{ color: 'var(--accent-amber)', fontSize: '12px', marginTop: '4px' }}>{stats.activeBookings} активных</p>
        </div>

        <div className="glass-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
            <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Выручка</span>
            <DollarSign color="var(--accent-emerald)" size={18} />
          </div>
          <h2 style={{ fontSize: '28px', fontWeight: '700', color: 'var(--accent-emerald)' }}>
            {stats.totalRevenue.toLocaleString()}
          </h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '12px', marginTop: '4px' }}>RUB · оплачено</p>
        </div>

        <div className="glass-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
            <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Туры</span>
            <Map color="var(--accent-rose)" size={18} />
          </div>
          <h2 style={{ fontSize: '28px', fontWeight: '700' }}>{stats.totalTours}</h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '12px', marginTop: '4px' }}>активных позиций</p>
        </div>

        <div className="glass-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
            <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Рейтинг</span>
            <Star color="var(--accent-amber)" size={18} />
          </div>
          <h2 style={{ fontSize: '28px', fontWeight: '700', color: 'var(--accent-amber)' }}>4.9</h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '12px', marginTop: '4px' }}>2000+ гостей</p>
        </div>
      </div>

      {/* Таблицы */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' }}>
        {/* Последние заявки */}
        <div className="glass-card">
          <h3 style={{ marginBottom: '16px', fontSize: '16px', fontWeight: '600' }}>Последние заявки</h3>
          {recentBookings.length === 0
            ? <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Заявок пока нет</p>
            : recentBookings.map(b => (
              <div key={b.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 0', borderBottom: '1px solid var(--glass-border)' }}>
                <div>
                  <div style={{ fontWeight: '500', fontSize: '14px' }}>{b.tour_name || b.tours?.title || '—'}</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{b.clients?.name || '—'} · {b.date_start || '—'}</div>
                </div>
                <span style={{ fontSize: '12px', padding: '2px 8px', borderRadius: '4px', background: 'rgba(255,255,255,0.06)', color: 'var(--accent-cyan)' }}>
                  {b.status}
                </span>
              </div>
            ))
          }
        </div>

        {/* Воронка клиентов */}
        <div className="glass-card">
          <h3 style={{ marginBottom: '16px', fontSize: '16px', fontWeight: '600' }}>Воронка клиентов</h3>
          {Object.entries(STAGE_LABEL).map(([stage, label]) => {
            const count = clients.filter(c => c.stage === stage).length;
            const pct = clients.length ? Math.round((count / clients.length) * 100) : 0;
            return (
              <div key={stage} style={{ marginBottom: '10px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '4px' }}>
                  <span>{label}</span>
                  <span style={{ color: STAGE_COLOR[stage] }}>{count}</span>
                </div>
                <div style={{ height: '3px', background: 'rgba(255,255,255,0.08)', borderRadius: '2px' }}>
                  <div style={{ width: `${pct}%`, height: '100%', background: STAGE_COLOR[stage], borderRadius: '2px', transition: 'width 0.4s' }} />
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
