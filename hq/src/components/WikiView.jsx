import { useState } from 'react';
import { useApp } from '../context/AppContext';
import { BookOpen, Search, ChevronDown, ChevronUp, Wifi, WifiOff } from 'lucide-react';

export default function WikiView() {
  const { knowledge, loading } = useApp();
  const [search, setSearch] = useState('');
  const [openId, setOpenId] = useState(null);

  const filtered = knowledge.filter(k =>
    !search ||
    k.question?.toLowerCase().includes(search.toLowerCase()) ||
    k.answer?.toLowerCase().includes(search.toLowerCase()) ||
    k.topic?.toLowerCase().includes(search.toLowerCase()) ||
    k.tags?.some(t => t.toLowerCase().includes(search.toLowerCase()))
  );

  // Группируем по topic
  const groups = filtered.reduce((acc, k) => {
    const key = k.topic || 'Общее';
    if (!acc[key]) acc[key] = [];
    acc[key].push(k);
    return acc;
  }, {});

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '28px' }}>
        <div>
          <h1 style={{ fontSize: '26px', fontWeight: '800' }}>Wiki — База знаний 📚</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>
            Регламенты, скрипты, факты о Пхукете · {knowledge.length} записей
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: knowledge.length ? 'var(--accent-emerald)' : 'var(--text-muted)' }}>
          {knowledge.length ? <Wifi size={14} /> : <WifiOff size={14} />}
          {knowledge.length ? 'Supabase · live' : 'Нет данных'}
        </div>
      </div>

      {/* Поиск */}
      <div style={{ position: 'relative', marginBottom: '24px' }}>
        <Search size={15} style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
        <input
          type="text"
          placeholder="Поиск по вопросам, ответам, тегам..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={{ width: '100%', paddingLeft: '40px', background: 'var(--glass-bg)', border: '1px solid var(--glass-border)', color: 'var(--text-main)', borderRadius: '10px', padding: '10px 16px 10px 40px', fontSize: '14px', outline: 'none' }}
        />
        {search && (
          <span style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', fontSize: '12px', color: 'var(--text-muted)' }}>
            {filtered.length} результатов
          </span>
        )}
      </div>

      {loading && <div style={{ color: 'var(--text-muted)', padding: '20px' }}>Загрузка...</div>}

      {!loading && knowledge.length === 0 && (
        <div className="glass-card" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
          <BookOpen size={32} style={{ marginBottom: '12px', opacity: 0.4 }} />
          <p>База знаний пуста или нет доступа к Supabase</p>
        </div>
      )}

      {/* Группы */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {Object.entries(groups).map(([topic, items]) => (
          <div key={topic} className="glass-card" style={{ padding: '0', overflow: 'hidden' }}>
            {/* Заголовок группы */}
            <div style={{
              padding: '14px 20px',
              borderBottom: '1px solid var(--glass-border)',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              background: 'rgba(0,229,255,0.04)',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <BookOpen size={15} color="var(--accent-cyan)" />
                <span style={{ fontWeight: '700', fontSize: '14px', color: 'var(--accent-cyan)' }}>{topic}</span>
              </div>
              <span style={{
                fontSize: '11px', padding: '2px 8px', borderRadius: '20px',
                background: 'rgba(0,229,255,0.1)', color: 'var(--accent-cyan)',
              }}>{items.length}</span>
            </div>

            {/* Записи */}
            <div style={{ padding: '8px 0' }}>
              {items.map((k) => (
                <div key={k.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.03)' }}>
                  <button
                    onClick={() => setOpenId(openId === k.id ? null : k.id)}
                    style={{
                      width: '100%', background: 'none', border: 'none', cursor: 'pointer',
                      padding: '12px 20px', textAlign: 'left', display: 'flex',
                      justifyContent: 'space-between', alignItems: 'center', gap: '12px',
                    }}
                  >
                    <span style={{ fontSize: '14px', fontWeight: '500', color: 'var(--text-main)', lineHeight: 1.4 }}>
                      {k.question}
                    </span>
                    {openId === k.id
                      ? <ChevronUp size={14} color="var(--text-muted)" style={{ flexShrink: 0 }} />
                      : <ChevronDown size={14} color="var(--text-muted)" style={{ flexShrink: 0 }} />
                    }
                  </button>

                  {openId === k.id && (
                    <div style={{ padding: '0 20px 16px 20px' }}>
                      <div style={{
                        background: 'rgba(0,0,0,0.2)', borderRadius: '10px', padding: '14px 16px',
                        fontSize: '13px', color: 'var(--text-muted)', lineHeight: '1.65',
                        whiteSpace: 'pre-wrap', border: '1px solid var(--glass-border)',
                      }}>
                        {k.answer}
                      </div>
                      {k.tags?.length > 0 && (
                        <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap', marginTop: '10px' }}>
                          {k.tags.map(tag => (
                            <span key={tag} style={{
                              fontSize: '11px', padding: '2px 8px', borderRadius: '20px',
                              background: 'rgba(245,158,11,0.1)', color: 'var(--accent-amber)',
                              border: '1px solid rgba(245,158,11,0.2)',
                            }}>#{tag}</span>
                          ))}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
