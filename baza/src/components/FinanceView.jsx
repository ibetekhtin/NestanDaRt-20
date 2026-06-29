
import { useApp } from '../context/AppContext';
import { ArrowUpRight, Clock, XCircle } from 'lucide-react';

const STATUS_META = {
  succeeded: { label: 'Оплачен', color: 'var(--accent-emerald)', icon: ArrowUpRight },
  pending:   { label: 'Ожидает', color: 'var(--accent-amber)', icon: Clock },
  canceled:  { label: 'Отменён', color: 'var(--accent-rose)', icon: XCircle },
};

export default function FinanceView() {
  const { payments, bookings, loading } = useApp();

  const paid = payments.filter(p => p.status === 'succeeded');
  const pending = payments.filter(p => p.status === 'pending');
  const totalPaid = paid.reduce((sum, p) => sum + (p.amount || 0), 0);
  const totalPending = pending.reduce((sum, p) => sum + (p.amount || 0), 0);
  const expectedFromBookings = bookings
    .filter(b => b.status !== 'Отменён' && b.status !== 'Завершён')
    .reduce((sum, b) => sum + (b.total || 0), 0);

  return (
    <div>
      <div style={{ marginBottom: '32px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: '700' }}>Финансовый штаб 💰</h1>
        <p style={{ color: 'var(--text-muted)' }}>
          Платежи через YooKassa · {loading ? 'обновление...' : 'live из Supabase'}
        </p>
      </div>

      {/* Метрики */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '24px', marginBottom: '32px' }}>
        <div className="glass-card" style={{ borderLeft: '4px solid var(--accent-emerald)' }}>
          <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Получено</span>
          <h2 style={{ fontSize: '24px', color: 'var(--accent-emerald)' }}>+{totalPaid.toLocaleString()} ₽</h2>
          <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>{paid.length} платежей</p>
        </div>
        <div className="glass-card" style={{ borderLeft: '4px solid var(--accent-amber)' }}>
          <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Ожидает оплаты</span>
          <h2 style={{ fontSize: '24px', color: 'var(--accent-amber)' }}>{totalPending.toLocaleString()} ₽</h2>
          <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>{pending.length} счетов</p>
        </div>
        <div className="glass-card" style={{ borderLeft: '4px solid var(--accent-cyan)' }}>
          <span style={{ color: 'var(--text-muted)', fontSize: '13px' }}>В работе (заявки)</span>
          <h2 style={{ fontSize: '24px', color: 'var(--accent-cyan)' }}>{expectedFromBookings.toLocaleString()} ₽</h2>
          <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>потенциальная выручка</p>
        </div>
      </div>

      {/* История платежей */}
      <div className="glass-card">
        <h3 style={{ marginBottom: '16px' }}>История платежей</h3>
        {payments.length === 0 ? (
          <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>
            Платежей пока нет. Они появятся автоматически, когда клиенты начнут оплачивать через YooKassa.
          </p>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
              <thead>
                <tr style={{ borderBottom: '1px solid var(--glass-border)', color: 'var(--text-muted)', fontSize: '13px' }}>
                  <th style={{ padding: '10px' }}>Дата</th>
                  <th style={{ padding: '10px' }}>Тур</th>
                  <th style={{ padding: '10px' }}>Статус</th>
                  <th style={{ padding: '10px', textAlign: 'right' }}>Сумма</th>
                </tr>
              </thead>
              <tbody>
                {payments.map(p => {
                  const meta = STATUS_META[p.status] || STATUS_META.pending;
                  const Icon = meta.icon;
                  return (
                    <tr key={p.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.02)', fontSize: '14px' }}>
                      <td style={{ padding: '10px' }}>{p.paid_at?.slice(0, 10) || p.created_at?.slice(0, 10)}</td>
                      <td style={{ padding: '10px' }}>{p.bookings?.tour_name || '—'}</td>
                      <td style={{ padding: '10px' }}>
                        <span style={{ color: meta.color, display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                          <Icon size={14} /> {meta.label}
                        </span>
                      </td>
                      <td style={{ padding: '10px', textAlign: 'right', fontWeight: '600', color: meta.color }}>
                        {(p.amount || 0).toLocaleString()} {p.currency || 'RUB'}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
