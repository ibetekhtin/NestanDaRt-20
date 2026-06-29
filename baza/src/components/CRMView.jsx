import { useState } from 'react';
import { useApp } from '../context/AppContext';
import { Plus, Search } from 'lucide-react';

const STAGES = ['new', 'interest', 'thinking', 'booking', 'done', 'cold'];
const STAGE_LABEL = { new: 'Новый', interest: 'Интерес', thinking: 'Думает', booking: 'Бронирует', done: 'Завершён', cold: 'Холодный' };
const STAGE_COLOR = { new: 'var(--accent-cyan)', interest: 'var(--accent-amber)', thinking: 'var(--accent-amber)', booking: 'var(--accent-emerald)', done: 'var(--text-muted)', cold: '#555' };
const SOURCES = ['Telegram', 'Бот', 'ВКонтакте', 'Сайт', 'Рекомендация', 'Instagram', 'Другое'];

export default function CRMView() {
  const { clients, addClient, updateClientStage, loading } = useApp();
  const [search, setSearch] = useState('');
  const [filterStage, setFilterStage] = useState('all');
  const [showAdd, setShowAdd] = useState(false);
  const [form, setForm] = useState({ name: '', phone: '', telegram: '', source: 'Telegram', notes: '' });

  const handleSave = async (e) => {
    e.preventDefault();
    if (!form.name) return;
    await addClient({ ...form, stage: 'new' });
    setForm({ name: '', phone: '', telegram: '', source: 'Telegram', notes: '' });
    setShowAdd(false);
  };

  const filtered = clients.filter(c => {
    const q = search.toLowerCase();
    const matchSearch = !q || (c.name || '').toLowerCase().includes(q) || (c.phone || '').includes(q) || (c.telegram || '').toLowerCase().includes(q);
    const matchStage = filterStage === 'all' || c.stage === filterStage;
    return matchSearch && matchStage;
  });

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: '700' }}>База клиентов</h1>
          <p style={{ color: 'var(--text-muted)' }}>{clients.length} контактов · {loading ? 'обновление...' : 'актуально'}</p>
        </div>
        <button className="btn btn-primary" onClick={() => setShowAdd(true)}>
          <Plus size={18} /> Добавить клиента
        </button>
      </div>

      {/* Фильтры */}
      <div style={{ display: 'flex', gap: '12px', marginBottom: '24px', flexWrap: 'wrap' }}>
        <div style={{ position: 'relative', flex: 1, minWidth: '200px' }}>
          <Search size={16} style={{ position: 'absolute', left: '12px', top: '13px', color: 'var(--text-muted)' }} />
          <input type="text" placeholder="Имя, телефон, Telegram..." style={{ paddingLeft: '38px', width: '100%' }} value={search} onChange={e => setSearch(e.target.value)} />
        </div>
        <select value={filterStage} onChange={e => setFilterStage(e.target.value)} style={{ minWidth: '140px' }}>
          <option value="all">Все этапы</option>
          {STAGES.map(s => <option key={s} value={s}>{STAGE_LABEL[s]}</option>)}
        </select>
      </div>

      {/* Список */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '16px' }}>
        {filtered.length === 0 && <p style={{ color: 'var(--text-muted)', gridColumn: '1/-1' }}>Клиентов не найдено</p>}
        {filtered.map(c => (
          <div key={c.id} className="glass-card" style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <h3 style={{ fontSize: '16px', fontWeight: '600' }}>{c.name}</h3>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{c.source || '—'}</span>
              </div>
              <select
                value={c.stage || 'new'}
                onChange={e => updateClientStage(c.id, e.target.value)}
                style={{ fontSize: '11px', padding: '2px 6px', borderRadius: '4px', background: 'rgba(255,255,255,0.06)', border: '1px solid var(--glass-border)', color: STAGE_COLOR[c.stage] || 'var(--text-muted)', cursor: 'pointer' }}
              >
                {STAGES.map(s => <option key={s} value={s}>{STAGE_LABEL[s]}</option>)}
              </select>
            </div>
            <div style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'flex', flexDirection: 'column', gap: '3px' }}>
              {c.phone && <div>📞 {c.phone}</div>}
              {c.telegram && <div>✈️ {c.telegram}</div>}
              {c.email && <div>✉️ {c.email}</div>}
              {c.language && c.language !== 'ru' && <div>🌐 {c.language}</div>}
            </div>
            {c.notes && (
              <p style={{ fontSize: '12px', background: 'rgba(0,0,0,0.2)', padding: '8px', borderRadius: '6px', color: 'var(--text-muted)', margin: 0 }}>
                {c.notes}
              </p>
            )}
          </div>
        ))}
      </div>

      {/* Модал добавления */}
      {showAdd && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 100 }} onClick={e => e.target === e.currentTarget && setShowAdd(false)}>
          <form onSubmit={handleSave} className="glass-card" style={{ width: '440px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <h3 style={{ color: 'var(--accent-cyan)' }}>Новый клиент</h3>
            <input placeholder="Имя *" required value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
            <input placeholder="Телефон" value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))} />
            <input placeholder="Telegram (@username или chat_id)" value={form.telegram} onChange={e => setForm(f => ({ ...f, telegram: e.target.value }))} />
            <select value={form.source} onChange={e => setForm(f => ({ ...f, source: e.target.value }))}>
              {SOURCES.map(s => <option key={s}>{s}</option>)}
            </select>
            <textarea placeholder="Заметки" rows={3} value={form.notes} onChange={e => setForm(f => ({ ...f, notes: e.target.value }))} />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
              <button type="button" className="btn" onClick={() => setShowAdd(false)}>Отмена</button>
              <button type="submit" className="btn btn-primary">Сохранить</button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
