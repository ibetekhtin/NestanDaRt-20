
import { useApp } from '../context/AppContext';

const COLUMNS = [
  { id: 'Новый',       title: 'Новая заявка',  color: 'var(--accent-cyan)' },
  { id: 'Связались',   title: 'Связались',     color: 'var(--accent-amber)' },
  { id: 'Предоплата',  title: 'Предоплата',    color: '#a78bfa' },
  { id: 'Подтверждён', title: 'Подтверждён',   color: 'var(--accent-emerald)' },
  { id: 'Завершён',    title: 'Завершён',      color: '#6b7280' },
  { id: 'Отменён',     title: 'Отменён',       color: 'var(--accent-rose)' },
];

export default function KanbanView() {
  const { bookings, updateBookingStatus, loading } = useApp();

  return (
    <div>
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: '700' }}>Заявки</h1>
        <p style={{ color: 'var(--text-muted)' }}>{bookings.length} заявок · {loading ? 'обновление...' : 'актуально'}</p>
      </div>

      <div style={{ display: 'flex', gap: '16px', overflowX: 'auto', paddingBottom: '16px' }}>
        {COLUMNS.map(col => {
          const cards = bookings.filter(b => b.status === col.id);
          return (
            <div key={col.id} style={{ minWidth: '220px', flex: '0 0 220px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
                <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: col.color }} />
                <span style={{ fontWeight: '600', fontSize: '13px' }}>{col.title}</span>
                <span style={{ marginLeft: 'auto', fontSize: '12px', color: 'var(--text-muted)', background: 'rgba(255,255,255,0.06)', padding: '1px 6px', borderRadius: '10px' }}>{cards.length}</span>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                {cards.map(b => (
                  <div key={b.id} className="glass-card" style={{ padding: '14px', cursor: 'default' }}>
                    <div style={{ fontWeight: '600', fontSize: '13px', marginBottom: '6px' }}>{b.tour_name || b.tours?.title || '—'}</div>
                    <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '10px' }}>
                      {b.clients?.name || '—'}<br />
                      {b.date_start || '—'} · {b.adults || b.people_count || '?'} чел.<br />
                      {b.total ? `${b.total.toLocaleString()} ₽` : ''}
                    </div>
                    <select
                      value={b.status}
                      onChange={e => updateBookingStatus(b.id, e.target.value)}
                      style={{ width: '100%', fontSize: '11px', padding: '4px 6px', background: 'rgba(255,255,255,0.05)', border: '1px solid var(--glass-border)', color: col.color, borderRadius: '4px', cursor: 'pointer' }}
                    >
                      {COLUMNS.map(c => <option key={c.id} value={c.id}>{c.title}</option>)}
                    </select>
                  </div>
                ))}
                {cards.length === 0 && (
                  <div style={{ padding: '20px', textAlign: 'center', color: 'var(--text-muted)', fontSize: '12px', border: '1px dashed rgba(255,255,255,0.08)', borderRadius: '10px' }}>
                    Пусто
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
