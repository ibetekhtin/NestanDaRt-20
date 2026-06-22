import { useState } from 'react';
import { useApp } from '../context/AppContext';
import { supabase } from '../supabase';
import { UserCheck, Gift, Plus, Star, TrendingUp, Handshake, CheckCircle, Clock, X } from 'lucide-react';

const LEVELS = {
  1: { label: 'Уровень 1', pct: 1.5, color: '#94a3b8', bg: 'rgba(148,163,184,0.12)', desc: 'Новый партнёр' },
  2: { label: 'Уровень 2', pct: 2.5, color: 'var(--accent-amber)', bg: 'rgba(245,158,11,0.12)', desc: 'Активный партнёр' },
  3: { label: 'Уровень 3', pct: 3.5, color: 'var(--accent-cyan)', bg: 'rgba(0,229,255,0.12)', desc: 'Топ-партнёр' },
};

export default function ReferralsView() {
  const { partners, clients, bookings, refetch } = useApp();
  const [showAdd, setShowAdd] = useState(false);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({ name: '', telegram: '', phone: '', promo: '', level: 1 });

  const referralClients = clients.filter(c => c.ref_code);
  const pendingBalance = partners.reduce((s, p) => s + (parseFloat(p.balance_thb) || 0), 0);

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    const { error } = await supabase.from('partners').insert([{
      name: form.name,
      telegram: form.telegram || null,
      phone: form.phone || null,
      promo: form.promo.toUpperCase() || null,
      level: Number(form.level),
      type: 'referral',
    }]);
    setSaving(false);
    if (!error) {
      setShowAdd(false);
      setForm({ name: '', telegram: '', phone: '', promo: '', level: 1 });
      refetch();
    } else {
      alert('Ошибка: ' + error.message);
    }
  };

  const handleLevelUp = async (partner, newLevel) => {
    await supabase.from('partners').update({ level: newLevel }).eq('id', partner.id);
    refetch();
  };

  const handlePayout = async (partner) => {
    if (!partner.balance_thb || partner.balance_thb <= 0) return;
    await supabase.from('partners').update({ balance_thb: 0 }).eq('id', partner.id);
    await supabase.from('referrals')
      .update({ status: 'paid', paid_at: new Date().toISOString() })
      .eq('partner_id', partner.id)
      .eq('status', 'pending');
    refetch();
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '28px' }}>
        <div>
          <h1 style={{ fontSize: '26px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <UserCheck size={26} color="var(--accent-emerald)" /> Реферальная система
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>3 уровня · макс. 3.5% с пакета экскурсий клиента</p>
        </div>
        <button className="btn btn-primary" onClick={() => setShowAdd(true)} style={{ fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px' }}>
          <Plus size={14} /> Добавить партнёра
        </button>
      </div>

      {/* Уровни — объяснение */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '14px', marginBottom: '24px' }}>
        {Object.entries(LEVELS).map(([lvl, info]) => (
          <div key={lvl} className="glass-card" style={{ padding: '18px', borderLeft: `3px solid ${info.color}`, background: info.bg }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' }}>
              {[...Array(Number(lvl))].map((_, i) => <Star key={i} size={13} color={info.color} fill={info.color} />)}
            </div>
            <div style={{ fontSize: '22px', fontWeight: '900', color: info.color }}>{info.pct}%</div>
            <div style={{ fontSize: '12px', fontWeight: '600', color: info.color, marginTop: '2px' }}>{info.label}</div>
            <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>{info.desc}</div>
          </div>
        ))}
      </div>

      {/* Сводка */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '14px', marginBottom: '28px' }}>
        <div className="glass-card" style={{ padding: '16px' }}>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '6px' }}>Партнёров</div>
          <div style={{ fontSize: '24px', fontWeight: '800', color: 'var(--accent-emerald)' }}>{partners.length}</div>
        </div>
        <div className="glass-card" style={{ padding: '16px' }}>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '6px' }}>Реф. клиенты</div>
          <div style={{ fontSize: '24px', fontWeight: '800', color: 'var(--accent-cyan)' }}>{referralClients.length}</div>
        </div>
        <div className="glass-card" style={{ padding: '16px' }}>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '6px' }}>Продаж через рефов</div>
          <div style={{ fontSize: '24px', fontWeight: '800', color: 'var(--accent-amber)' }}>
            {partners.reduce((s, p) => s + (p.total_sales || 0), 0)}
          </div>
        </div>
        <div className="glass-card" style={{ padding: '16px' }}>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '6px' }}>К выплате</div>
          <div style={{ fontSize: '24px', fontWeight: '800', color: pendingBalance > 0 ? 'var(--accent-rose)' : 'var(--text-muted)' }}>
            {pendingBalance.toFixed(0)}฿
          </div>
        </div>
      </div>

      {/* Таблица партнёров */}
      <div className="glass-card" style={{ padding: 0, overflow: 'hidden', marginBottom: '20px' }}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--glass-border)', display: 'flex', alignItems: 'center', gap: '8px' }}>
          <Handshake size={16} color="var(--accent-emerald)" />
          <h3 style={{ fontSize: '15px', fontWeight: '700' }}>Партнёры</h3>
        </div>

        {partners.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
            <Gift size={32} style={{ opacity: 0.3, marginBottom: '12px', display: 'block', margin: '0 auto 12px' }} />
            <p style={{ marginBottom: '16px' }}>Партнёры ещё не добавлены</p>
            <button className="btn btn-primary" onClick={() => setShowAdd(true)}>
              <Plus size={14} /> Добавить первого партнёра
            </button>
          </div>
        ) : (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 1fr 1fr 1fr 1fr', gap: '12px', padding: '10px 20px', fontSize: '11px', color: 'var(--text-muted)', borderBottom: '1px solid var(--glass-border)', background: 'rgba(255,255,255,0.02)' }}>
              <span>Партнёр</span><span>Промокод</span><span>Уровень</span><span>Продаж</span><span>Баланс</span><span>Действие</span>
            </div>
            {partners.map(p => {
              const lvlInfo = LEVELS[p.level] || LEVELS[1];
              return (
                <div key={p.id} style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 1fr 1fr 1fr 1fr', gap: '12px', padding: '14px 20px', borderBottom: '1px solid rgba(255,255,255,0.03)', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontWeight: '600', fontSize: '13px' }}>{p.name}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{p.telegram || p.phone || '—'}</div>
                  </div>

                  <div>
                    {p.promo
                      ? <span style={{ fontSize: '12px', padding: '3px 8px', borderRadius: '4px', background: 'rgba(245,158,11,0.1)', color: 'var(--accent-amber)', fontFamily: 'monospace', fontWeight: '700' }}>{p.promo}</span>
                      : <span style={{ color: 'var(--text-muted)', fontSize: '12px' }}>—</span>
                    }
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <span style={{ fontSize: '12px', padding: '3px 8px', borderRadius: '20px', background: lvlInfo.bg, color: lvlInfo.color, fontWeight: '700' }}>
                      {[...Array(p.level)].map((_, i) => '★').join('')} {lvlInfo.pct}%
                    </span>
                    {p.level < 3 && (
                      <button
                        onClick={() => handleLevelUp(p, p.level + 1)}
                        style={{ fontSize: '10px', padding: '2px 6px', borderRadius: '4px', background: 'rgba(255,255,255,0.06)', border: '1px solid var(--glass-border)', color: 'var(--text-muted)', cursor: 'pointer' }}
                        title="Повысить уровень"
                      >▲</button>
                    )}
                  </div>

                  <div style={{ fontSize: '14px', fontWeight: '700', color: 'var(--accent-cyan)' }}>{p.total_sales || 0}</div>

                  <div style={{ fontSize: '14px', fontWeight: '700', color: parseFloat(p.balance_thb) > 0 ? 'var(--accent-emerald)' : 'var(--text-muted)' }}>
                    {parseFloat(p.balance_thb || 0).toFixed(0)}฿
                  </div>

                  <div>
                    {parseFloat(p.balance_thb) > 0 ? (
                      <button
                        onClick={() => handlePayout(p)}
                        className="btn"
                        style={{ fontSize: '11px', padding: '4px 10px', color: 'var(--accent-emerald)', display: 'flex', alignItems: 'center', gap: '4px' }}
                      >
                        <CheckCircle size={12} /> Выплатить
                      </button>
                    ) : (
                      <span style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                        <Clock size={11} /> Ждём продаж
                      </span>
                    )}
                  </div>
                </div>
              );
            })}
          </>
        )}
      </div>

      {/* Принцип работы */}
      <div className="glass-card" style={{ padding: '20px', background: 'rgba(0,229,255,0.03)', border: '1px solid rgba(0,229,255,0.1)' }}>
        <div style={{ fontWeight: '700', fontSize: '14px', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
          <TrendingUp size={15} color="var(--accent-cyan)" /> Как работает
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', fontSize: '13px', color: 'var(--text-muted)', lineHeight: 1.7 }}>
          <div>
            <strong style={{ color: 'var(--text-main)' }}>Механика:</strong><br />
            1. Партнёр получает промокод (напр. <code style={{ background: 'rgba(255,255,255,0.05)', padding: '1px 5px', borderRadius: '3px' }}>ANNA</code>)<br />
            2. Клиент называет промокод КотЭ или на сайте<br />
            3. Промокод записывается в поле <code style={{ background: 'rgba(255,255,255,0.05)', padding: '1px 5px', borderRadius: '3px' }}>ref_code</code> клиента<br />
            4. При оплате тура — автоматически начисляется бонус<br />
            5. Партнёр видит баланс, ты нажимаешь «Выплатить»
          </div>
          <div>
            <strong style={{ color: 'var(--text-main)' }}>Формула начисления:</strong><br />
            Сумма тура в ฿ × % уровня партнёра<br />
            <span style={{ color: 'var(--accent-cyan)' }}>★ Ур.1: 1.5% · ★★ Ур.2: 2.5% · ★★★ Ур.3: 3.5%</span><br /><br />
            <strong style={{ color: 'var(--text-main)' }}>Повышение уровня:</strong><br />
            Вручную — кнопка ▲ рядом с уровнем партнёра
          </div>
        </div>
      </div>

      {/* Модалка добавления */}
      {showAdd && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 100 }}>
          <form onSubmit={handleSave} className="glass-card" style={{ width: '420px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3 style={{ color: 'var(--accent-emerald)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Handshake size={18} /> Новый партнёр
              </h3>
              <button type="button" onClick={() => setShowAdd(false)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
                <X size={18} />
              </button>
            </div>

            <input type="text" placeholder="Имя / название *" required value={form.name} onChange={e => setForm(p => ({...p, name: e.target.value}))} />
            <input type="text" placeholder="Telegram (@username)" value={form.telegram} onChange={e => setForm(p => ({...p, telegram: e.target.value}))} />
            <input type="text" placeholder="Телефон" value={form.phone} onChange={e => setForm(p => ({...p, phone: e.target.value}))} />
            <input type="text" placeholder="Промокод (напр. ANNA или SERGEY10)" value={form.promo} onChange={e => setForm(p => ({...p, promo: e.target.value.toUpperCase()}))} />

            {/* Выбор уровня */}
            <div>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '8px' }}>Начальный уровень</div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '8px' }}>
                {Object.entries(LEVELS).map(([lvl, info]) => (
                  <button
                    key={lvl}
                    type="button"
                    onClick={() => setForm(p => ({...p, level: Number(lvl)}))}
                    style={{
                      padding: '10px 8px', borderRadius: '10px', cursor: 'pointer', border: `2px solid ${form.level === Number(lvl) ? info.color : 'transparent'}`,
                      background: form.level === Number(lvl) ? info.bg : 'rgba(255,255,255,0.04)', transition: 'all 0.2s',
                    }}
                  >
                    <div style={{ fontSize: '16px', fontWeight: '900', color: info.color }}>{info.pct}%</div>
                    <div style={{ fontSize: '10px', color: 'var(--text-muted)', marginTop: '2px' }}>{info.label}</div>
                  </button>
                ))}
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '4px' }}>
              <button type="button" className="btn" onClick={() => setShowAdd(false)}>Отмена</button>
              <button type="submit" className="btn btn-primary" disabled={saving}>
                {saving ? 'Сохраняем...' : 'Добавить партнёра'}
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
