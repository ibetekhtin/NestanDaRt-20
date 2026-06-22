import { useApp } from '../context/AppContext';
import { Users, FolderKanban, DollarSign, Map, TrendingUp, Trophy, CheckCircle, RefreshCw } from 'lucide-react';

const STAGE_LABEL = { new: 'Новый', interest: 'Интерес', thinking: 'Думает', booking: 'Бронирует', done: 'Завершён', cold: 'Холодный' };
const STAGE_COLOR = { new: 'var(--accent-cyan)', interest: 'var(--accent-amber)', thinking: 'var(--accent-amber)', booking: 'var(--accent-emerald)', done: 'var(--text-muted)', cold: 'var(--text-muted)' };

export default function DashboardView() {
  const { stats, bookings, clients, loading, refetch } = useApp();

  if (loading) return (
    <div style={{ color: 'var(--text-muted)', padding: '40px', display: 'flex', alignItems: 'center', gap: '12px' }}>
      <RefreshCw size={18} style={{ animation: 'spin 1s linear infinite' }} /> Загружаем данные...
      <style>{`@keyframes spin { from{transform:rotate(0deg)} to{transform:rotate(360deg)} }`}</style>
    </div>
  );

  const recentBookings = bookings.slice(0, 6);

  return (
    <div>
      {/* Заголовок */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '28px' }}>
        <div>
          <h1 style={{ fontSize: '26px', fontWeight: '800' }}>CEO Dashboard</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Нестандартный Отдых® — оперативная сводка</p>
        </div>
        <button onClick={refetch} className="btn" style={{ fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px' }}>
          <RefreshCw size={14} /> Обновить
        </button>
      </div>

      {/* ══ КПТ — ГЛАВНАЯ МЕТРИКА ══ */}
      <div style={{
        background: 'linear-gradient(135deg, rgba(0,229,255,0.12), rgba(0,176,255,0.06))',
        border: '1px solid rgba(0,229,255,0.3)',
        borderRadius: '20px',
        padding: '28px 32px',
        marginBottom: '24px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        boxShadow: '0 0 40px rgba(0,229,255,0.08)',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          <div style={{
            width: '64px', height: '64px', borderRadius: '16px',
            background: 'linear-gradient(135deg, #00b0ff, #00e5ff)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 0 24px rgba(0,229,255,0.4)',
          }}>
            <Trophy size={30} color="#000" />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--accent-cyan)', fontWeight: '600', letterSpacing: '0.05em', marginBottom: '4px' }}>
              КПТ — КОЛИЧЕСТВО ПРОДАННЫХ ТУРОВ
            </div>
            <div style={{ fontSize: '52px', fontWeight: '900', lineHeight: 1, color: '#fff' }}>
              {stats.kpt}
            </div>
            <div style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
              {stats.completedTours} завершено · {stats.activeBookings} активных
            </div>
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>Единственная метрика</div>
          <div style={{
            fontSize: '11px', padding: '6px 14px', borderRadius: '20px',
            background: 'rgba(0,229,255,0.1)', color: 'var(--accent-cyan)',
            border: '1px solid rgba(0,229,255,0.2)', fontWeight: '600',
          }}>
            Каждый тур = КПТ+1
          </div>
        </div>
      </div>

      {/* Вторичные KPI */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '14px', marginBottom: '28px' }}>
        <div className="glass-card" style={{ padding: '18px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
            <span style={{ color: 'var(--text-muted)', fontSize: '12px' }}>Клиенты</span>
            <Users color="var(--accent-cyan)" size={16} />
          </div>
          <div style={{ fontSize: '26px', fontWeight: '800' }}>{stats.totalClients}</div>
          <div style={{ color: 'var(--accent-cyan)', fontSize: '11px', marginTop: '3px' }}>{stats.newLeads} новых лидов</div>
        </div>

        <div className="glass-card" style={{ padding: '18px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
            <span style={{ color: 'var(--text-muted)', fontSize: '12px' }}>Все заявки</span>
            <FolderKanban color="var(--accent-amber)" size={16} />
          </div>
          <div style={{ fontSize: '26px', fontWeight: '800' }}>{bookings.length}</div>
          <div style={{ color: 'var(--accent-amber)', fontSize: '11px', marginTop: '3px' }}>{stats.activeBookings} в работе</div>
        </div>

        <div className="glass-card" style={{ padding: '18px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
            <span style={{ color: 'var(--text-muted)', fontSize: '12px' }}>Выручка</span>
            <DollarSign color="var(--accent-emerald)" size={16} />
          </div>
          <div style={{ fontSize: '26px', fontWeight: '800', color: 'var(--accent-emerald)' }}>
            {stats.totalRevenue ? stats.totalRevenue.toLocaleString() : '—'}
          </div>
          <div style={{ color: 'var(--text-muted)', fontSize: '11px', marginTop: '3px' }}>RUB · оплачено</div>
        </div>

        <div className="glass-card" style={{ padding: '18px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
            <span style={{ color: 'var(--text-muted)', fontSize: '12px' }}>Экскурсии</span>
            <Map color="var(--accent-rose)" size={16} />
          </div>
          <div style={{ fontSize: '26px', fontWeight: '800' }}>{stats.totalTours}</div>
          <div style={{ color: 'var(--text-muted)', fontSize: '11px', marginTop: '3px' }}>активных в каталоге</div>
        </div>
      </div>

      {/* Таблицы */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
        {/* Последние заявки */}
        <div className="glass-card">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
            <CheckCircle size={16} color="var(--accent-emerald)" />
            <h3 style={{ fontSize: '15px', fontWeight: '700' }}>Последние заявки</h3>
          </div>
          {recentBookings.length === 0
            ? <p style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Заявок пока нет</p>
            : recentBookings.map(b => (
              <div key={b.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 0', borderBottom: '1px solid var(--glass-border)' }}>
                <div>
                  <div style={{ fontWeight: '600', fontSize: '13px' }}>{b.tour_name || b.tours?.title || '—'}</div>
                  <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>
                    {b.clients?.name || '—'} · {b.date_start || '—'}
                  </div>
                </div>
                <span style={{
                  fontSize: '11px', padding: '2px 8px', borderRadius: '20px',
                  background: b.status === 'Завершён' ? 'rgba(16,185,129,0.15)' : b.status === 'Подтверждён' ? 'rgba(0,229,255,0.1)' : 'rgba(255,255,255,0.06)',
                  color: b.status === 'Завершён' ? 'var(--accent-emerald)' : b.status === 'Подтверждён' ? 'var(--accent-cyan)' : 'var(--text-muted)',
                  fontWeight: '600',
                }}>
                  {b.status}
                </span>
              </div>
            ))
          }
        </div>

        {/* Воронка */}
        <div className="glass-card">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
            <TrendingUp size={16} color="var(--accent-amber)" />
            <h3 style={{ fontSize: '15px', fontWeight: '700' }}>Воронка клиентов</h3>
          </div>
          {Object.entries(STAGE_LABEL).map(([stage, label]) => {
            const count = clients.filter(c => c.stage === stage).length;
            const pct = clients.length ? Math.round((count / clients.length) * 100) : 0;
            return (
              <div key={stage} style={{ marginBottom: '10px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', marginBottom: '4px' }}>
                  <span style={{ color: 'var(--text-muted)' }}>{label}</span>
                  <span style={{ color: STAGE_COLOR[stage], fontWeight: '600' }}>{count}</span>
                </div>
                <div style={{ height: '3px', background: 'rgba(255,255,255,0.06)', borderRadius: '2px' }}>
                  <div style={{ width: `${pct}%`, height: '100%', background: STAGE_COLOR[stage], borderRadius: '2px', transition: 'width 0.5s' }} />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <style>{`@keyframes spin { from{transform:rotate(0deg)} to{transform:rotate(360deg)} }`}</style>
    </div>
  );
}
