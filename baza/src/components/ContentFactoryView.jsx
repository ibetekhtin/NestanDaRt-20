import { useState } from 'react';
import { useApp } from '../context/AppContext';
import { CheckCircle2, Clock, Plus } from 'lucide-react';

export default function ContentFactoryView() {
  const { contentPlan, addPost, togglePostStatus } = useApp();
  const [filterWeek, setFilterWeek] = useState(1);
  const [showAddModal, setShowAddModal] = useState(false);

  // Форма поста
  const [title, setTitle] = useState('');
  const [type, setType] = useState('Экспертный');
  const [text, setText] = useState('');
  const [week, setWeek] = useState(1);

  const handleSave = (e) => {
    e.preventDefault();
    if (!title) return;
    addPost({ title, type, body: text, week: Number(week), status: 'draft', date: new Date().toISOString().split('T')[0] });
    setTitle(''); setText(''); setShowAddModal(false);
  };

  const currentWeekPosts = contentPlan.filter(p => p.week === filterWeek);

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: '700' }}>Контент-завод 🎬</h1>
          <p style={{ color: 'var(--text-muted)' }}>Контент-план публикаций для Telegram @nestandart_phuket_channel</p>
        </div>
        <button className="btn btn-primary" onClick={() => setShowAddModal(true)}>
          <Plus size={18} /> Запланировать пост
        </button>
      </div>

      {/* Выбор недели */}
      <div style={{ display: 'flex', gap: '8px', marginBottom: '24px' }}>
        {[1, 2, 3, 4].map(w => (
          <button key={w} className={`btn ${filterWeek === w ? 'btn-primary' : ''}`} onClick={() => setFilterWeek(w)}>
            Неделя {w}
          </button>
        ))}
      </div>

      {/* Список постов */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {currentWeekPosts.map(post => (
          <div key={post.id} className="glass-card" style={{ borderLeft: `4px solid ${post.status === 'ready' ? 'var(--accent-emerald)' : 'var(--accent-rose)'}` }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '12px' }}>
              <div>
                <span style={{ fontSize: '11px', background: 'rgba(255,255,255,0.05)', color: 'var(--accent-cyan)', padding: '3px 8px', borderRadius: '4px', marginRight: '8px' }}>
                  {post.type}
                </span>
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{post.date}</span>
              </div>

              <button className="btn" style={{ padding: '4px 8px', fontSize: '12px' }} onClick={() => togglePostStatus(post.id)}>
                {post.status === 'ready' ? (
                  <span style={{ display: 'flex', alignItems: 'center', gap: '4px', color: 'var(--accent-emerald)' }}><CheckCircle2 size={14} /> Готов к публикации</span>
                ) : (
                  <span style={{ display: 'flex', alignItems: 'center', gap: '4px', color: 'var(--accent-rose)' }}><Clock size={14} /> В черновиках</span>
                )}
              </button>
            </div>
            <h3 style={{ fontSize: '18px', marginBottom: '8px' }}>{post.title}</h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '14px', whiteSpace: 'pre-wrap' }}>{post.body}</p>
          </div>
        ))}
      </div>

      {/* Модальное окно создания */}
      {showAddModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 100 }}>
          <form onSubmit={handleSave} className="glass-card" style={{ width: '450px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <h3 style={{ color: 'var(--accent-cyan)', marginBottom: '8px' }}>Новый пост</h3>
            <input type="text" placeholder="Заголовок поста *" required value={title} onChange={e => setTitle(e.target.value)} />
            <select value={type} onChange={e => setType(e.target.value)}>
              <option value="Экспертный">Экспертный</option>
              <option value="Личный">Личный</option>
              <option value="Промо">Промо</option>
              <option value="Мероприятия">Мероприятия</option>
            </select>
            <select value={week} onChange={e => setWeek(e.target.value)}>
              <option value={1}>Неделя 1</option>
              <option value={2}>Неделя 2</option>
              <option value={3}>Неделя 3</option>
              <option value={4}>Неделя 4</option>
            </select>
            <textarea placeholder="Текст публикации..." required rows={5} value={text} onChange={e => setText(e.target.value)} />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '12px' }}>
              <button type="button" className="btn" onClick={() => setShowAddModal(false)}>Отмена</button>
              <button type="submit" className="btn btn-primary">Запланировать</button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
