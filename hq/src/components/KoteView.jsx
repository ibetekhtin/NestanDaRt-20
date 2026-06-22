import { useState } from 'react';
import { useApp } from '../context/AppContext';
import { Bot, MessageSquare, Activity, ExternalLink, ChevronDown, ChevronUp, Clock, User } from 'lucide-react';

export default function KoteView() {
  const { conversations, clients, loading } = useApp();
  const [openConv, setOpenConv] = useState(null);
  const [searchTg, setSearchTg] = useState('');

  // Группируем диалоги по chat_id/client
  const byClient = conversations.reduce((acc, msg) => {
    const key = msg.tg_chat_id || msg.client_id || 'unknown';
    if (!acc[key]) acc[key] = { key, msgs: [], client: msg.clients };
    acc[key].msgs.push(msg);
    return acc;
  }, {});

  const threads = Object.values(byClient)
    .filter(t => !searchTg || String(t.key).includes(searchTg) || t.client?.name?.toLowerCase().includes(searchTg.toLowerCase()))
    .sort((a, b) => {
      const aLast = a.msgs[0]?.created_at || '';
      const bLast = b.msgs[0]?.created_at || '';
      return bLast.localeCompare(aLast);
    });

  const totalMsgs = conversations.length;
  const uniqueChats = Object.keys(byClient).length;
  const todayMsgs = conversations.filter(m => m.created_at?.startsWith(new Date().toISOString().slice(0, 10))).length;

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '28px' }}>
        <div>
          <h1 style={{ fontSize: '26px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <Bot size={26} color="var(--accent-cyan)" /> КотЭ — AI Агент
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Диалоги бота · n8n workflow doCUKEZQpLQjDmxP</p>
        </div>
        <a
          href="https://n8n.nestandart.online"
          target="_blank"
          rel="noreferrer"
          className="btn btn-primary"
          style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px' }}
        >
          <ExternalLink size={14} /> Открыть n8n
        </a>
      </div>

      {/* Статусная строка */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '14px', marginBottom: '28px' }}>
        <div className="glass-card" style={{ padding: '18px', borderLeft: '3px solid var(--accent-emerald)' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>Статус</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontWeight: '700', color: 'var(--accent-emerald)' }}>
            <Activity size={16} /> LIVE
          </div>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>@phuket_nestandart_bot</div>
        </div>
        <div className="glass-card" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>Всего сообщений</div>
          <div style={{ fontSize: '24px', fontWeight: '800' }}>{totalMsgs}</div>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>в базе знаний</div>
        </div>
        <div className="glass-card" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>Уникальных чатов</div>
          <div style={{ fontSize: '24px', fontWeight: '800', color: 'var(--accent-cyan)' }}>{uniqueChats}</div>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>разных клиентов</div>
        </div>
        <div className="glass-card" style={{ padding: '18px' }}>
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>Сегодня</div>
          <div style={{ fontSize: '24px', fontWeight: '800', color: 'var(--accent-amber)' }}>{todayMsgs}</div>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>сообщений</div>
        </div>
      </div>

      {/* AI модель */}
      <div className="glass-card" style={{ marginBottom: '24px', padding: '16px 20px', display: 'flex', gap: '24px', alignItems: 'center', flexWrap: 'wrap' }}>
        <div>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '2px' }}>AI каскад</div>
          <div style={{ fontWeight: '600', fontSize: '13px' }}>groq → aitunnel → openrouter → gemini-2.5-flash</div>
        </div>
        <div>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '2px' }}>n8n</div>
          <div style={{ fontWeight: '600', fontSize: '13px' }}>n8n.nestandart.online · v2.25.7</div>
        </div>
        <div>
          <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '2px' }}>Бэкенд</div>
          <div style={{ fontWeight: '600', fontSize: '13px' }}>nestandart.online/api/v1/ai/chat</div>
        </div>
        <div style={{ marginLeft: 'auto' }}>
          <a href="https://t.me/phuket_nestandart_bot" target="_blank" rel="noreferrer" className="btn" style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <MessageSquare size={13} /> Открыть бота
          </a>
        </div>
      </div>

      {/* Диалоги */}
      <div className="glass-card" style={{ padding: '0', overflow: 'hidden' }}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--glass-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h3 style={{ fontSize: '15px', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <MessageSquare size={16} color="var(--accent-cyan)" /> Диалоги
          </h3>
          <input
            type="text"
            placeholder="Поиск по chat_id или имени..."
            value={searchTg}
            onChange={e => setSearchTg(e.target.value)}
            style={{ width: '240px', background: 'var(--glass-bg)', border: '1px solid var(--glass-border)', color: 'var(--text-main)', borderRadius: '8px', padding: '6px 12px', fontSize: '12px', outline: 'none' }}
          />
        </div>

        {loading && <div style={{ padding: '24px', color: 'var(--text-muted)', fontSize: '13px' }}>Загрузка...</div>}

        {!loading && threads.length === 0 && (
          <div style={{ padding: '32px', textAlign: 'center', color: 'var(--text-muted)', fontSize: '13px' }}>
            {conversations.length === 0
              ? 'Диалоги ещё не записаны в Supabase. Таблица conversations пуста.'
              : 'Ничего не найдено по запросу.'
            }
          </div>
        )}

        <div style={{ maxHeight: '500px', overflowY: 'auto' }}>
          {threads.map(t => {
            const lastMsg = t.msgs[0];
            const isOpen = openConv === t.key;
            return (
              <div key={t.key} style={{ borderBottom: '1px solid var(--glass-border)' }}>
                <button
                  onClick={() => setOpenConv(isOpen ? null : t.key)}
                  style={{ width: '100%', background: 'none', border: 'none', cursor: 'pointer', padding: '12px 20px', textAlign: 'left', display: 'flex', alignItems: 'center', gap: '12px' }}
                >
                  <div style={{ width: '32px', height: '32px', borderRadius: '50%', background: 'rgba(0,229,255,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <User size={14} color="var(--accent-cyan)" />
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontWeight: '600', fontSize: '13px', color: 'var(--text-main)' }}>
                      {t.client?.name || `chat ${t.key}`}
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {lastMsg?.message || lastMsg?.user_message || '—'}
                    </div>
                  </div>
                  <div style={{ textAlign: 'right', flexShrink: 0 }}>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                      <Clock size={11} /> {lastMsg?.created_at ? new Date(lastMsg.created_at).toLocaleString('ru', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—'}
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--accent-cyan)', marginTop: '3px' }}>{t.msgs.length} сообщ.</div>
                  </div>
                  {isOpen ? <ChevronUp size={14} color="var(--text-muted)" /> : <ChevronDown size={14} color="var(--text-muted)" />}
                </button>

                {isOpen && (
                  <div style={{ padding: '0 20px 16px 64px', maxHeight: '300px', overflowY: 'auto' }}>
                    {[...t.msgs].reverse().map((m, i) => (
                      <div key={m.id || i} style={{ marginBottom: '10px' }}>
                        {(m.user_message || m.message) && (
                          <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '4px' }}>
                            <div style={{ maxWidth: '80%', background: 'rgba(0,229,255,0.1)', border: '1px solid rgba(0,229,255,0.2)', borderRadius: '12px 12px 4px 12px', padding: '8px 12px', fontSize: '12px', color: 'var(--text-main)' }}>
                              {m.user_message || m.message}
                            </div>
                          </div>
                        )}
                        {(m.bot_response || m.assistant_message) && (
                          <div style={{ display: 'flex', justifyContent: 'flex-start' }}>
                            <div style={{ maxWidth: '80%', background: 'rgba(255,255,255,0.04)', border: '1px solid var(--glass-border)', borderRadius: '12px 12px 12px 4px', padding: '8px 12px', fontSize: '12px', color: 'var(--text-muted)' }}>
                              🐱 {m.bot_response || m.assistant_message}
                            </div>
                          </div>
                        )}
                        <div style={{ fontSize: '10px', color: 'rgba(255,255,255,0.2)', textAlign: 'center', marginTop: '2px' }}>
                          {m.created_at ? new Date(m.created_at).toLocaleString('ru') : ''}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
