import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../supabase';
import { useApp } from '../context/AppContext';
import {
  Waves, Bike, TreePine, Globe2, Search, Pencil,
  Check, X, TrendingUp, Hash, Star, Clock, ToggleLeft, ToggleRight, RefreshCw
} from 'lucide-react';

// ─── Классификация туров ──────────────────────────────────────────────────────

const SEA_SLUGS = /phiphi|similan|^james|ph-james|ph-racha|ph-coral|ph-trydive|ph-sup|ph-jetski|ph-11islands|ph-andaman-pearl|ph-maiton|ph-phangnga|ph-sunset-cat|ph-island-private|^yacht|ph-fishing|^khaolak/;
const AUTHOR_SLUGS = /^moto|^auto$|^minibus/;

function getCategory(slug) {
  if (AUTHOR_SLUGS.test(slug)) return 'author';
  if (SEA_SLUGS.test(slug)) return 'sea';
  return 'land';
}

function getEmoji(slug) {
  if (/^moto/.test(slug)) return '🏍';
  if (/^auto$/.test(slug)) return '🚗';
  if (/^minibus/.test(slug)) return '🚌';
  if (/phiphi|11islands|andaman-pearl|maiton|island-private/.test(slug)) return '🏝️';
  if (/similan/.test(slug)) return '🌊';
  if (/james/.test(slug)) return '🎬';
  if (/racha|coral/.test(slug)) return '🏖️';
  if (/trydive/.test(slug)) return '🤿';
  if (/ph-sup/.test(slug)) return '🏄';
  if (/jetski/.test(slug)) return '🚤';
  if (/khaolak/.test(slug)) return '🐢';
  if (/khaosok/.test(slug)) return '🌿';
  if (/raft/.test(slug)) return '🏞️';
  if (/splash|andamanda|bluetree/.test(slug)) return '💦';
  if (/plane/.test(slug)) return '✈️';
  if (/helicopter/.test(slug)) return '🚁';
  if (/elephant/.test(slug)) return '🐘';
  if (/atv|gokart/.test(slug)) return '🏎️';
  if (/hanuman|gibbon/.test(slug)) return '🦅';
  if (/tiger/.test(slug)) return '🐯';
  if (/muaythai/.test(slug)) return '🥊';
  if (/cooking/.test(slug)) return '🍜';
  if (/parasail|flyboard|kite/.test(slug)) return '🪁';
  if (/wakeboard|windsurf/.test(slug)) return '🏄';
  if (/fishing/.test(slug)) return '🎣';
  if (/oldtown|bigbuddha/.test(slug)) return '🏛️';
  if (/gastro/.test(slug)) return '🌃';
  if (/spa/.test(slug)) return '💆';
  if (/photo/.test(slug)) return '📸';
  if (/wedding/.test(slug)) return '💍';
  if (/fire/.test(slug)) return '🔥';
  if (/yacht/.test(slug)) return '⛵';
  if (/simon|carnival|fantasea/.test(slug)) return '🎭';
  if (/aquarium/.test(slug)) return '🐠';
  if (/zoo/.test(slug)) return '🦁';
  if (/monkey/.test(slug)) return '🐒';
  if (/nightlife/.test(slug)) return '🌙';
  if (/romantic/.test(slug)) return '🌹';
  if (/phangnga/.test(slug)) return '🛶';
  if (/sunset-cat/.test(slug)) return '🌅';
  if (/avatar/.test(slug)) return '🧬';
  if (/vip/.test(slug)) return '👑';
  return '🗺️';
}

// ─── Конфиги вкладок ─────────────────────────────────────────────────────────

const TABS = [
  { id: 'all',    label: 'Все',          Icon: Globe2,    color: 'var(--accent-cyan)',    bg: 'rgba(0,229,255,0.08)' },
  { id: 'sea',    label: 'Морские',      Icon: Waves,     color: '#38bdf8',               bg: 'rgba(56,189,248,0.08)' },
  { id: 'author', label: 'Авторские',    Icon: Bike,      color: 'var(--accent-amber)',   bg: 'rgba(245,158,11,0.08)' },
  { id: 'land',   label: 'Сухопутные',   Icon: TreePine,  color: 'var(--accent-emerald)', bg: 'rgba(16,185,129,0.08)' },
];

const TAB_COLOR = {
  all:    'var(--accent-cyan)',
  sea:    '#38bdf8',
  author: 'var(--accent-amber)',
  land:   'var(--accent-emerald)',
};

// ─── Компонент карточки тура ──────────────────────────────────────────────────

function TourCard({ tour, onSave, activeTab }) {
  const [editing, setEditing]   = useState(false);
  const [adultVal, setAdultVal] = useState(String(tour.price_adult));
  const [childVal, setChildVal] = useState(String(tour.price_child));
  const [saving, setSaving]     = useState(false);
  const [saved, setSaved]       = useState(false);
  const [toggling, setToggling] = useState(false);

  const accentColor = TAB_COLOR[activeTab] || 'var(--accent-cyan)';

  const handleSave = async () => {
    const adult = parseInt(adultVal, 10);
    const child = parseInt(childVal, 10);
    if (isNaN(adult) || isNaN(child)) return;
    setSaving(true);
    await onSave(tour.slug, adult, child);
    setSaving(false);
    setSaved(true);
    setEditing(false);
    setTimeout(() => setSaved(false), 2000);
  };

  const handleToggleActive = async () => {
    setToggling(true);
    await onSave(tour.slug, tour.price_adult, tour.price_child, !tour.active);
    setToggling(false);
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') handleSave();
    if (e.key === 'Escape') { setEditing(false); setAdultVal(String(tour.price_adult)); setChildVal(String(tour.price_child)); }
  };

  const cat = getCategory(tour.slug);
  const catColors = { sea: '#38bdf8', author: 'var(--accent-amber)', land: 'var(--accent-emerald)' };
  const catLabels = { sea: 'Море', author: 'Авторский', land: 'Суша' };
  const cardColor = catColors[cat];

  return (
    <div style={{
      background: 'var(--glass-bg)',
      border: `1px solid ${tour.active ? 'var(--glass-border)' : 'rgba(255,255,255,0.03)'}`,
      borderRadius: '14px',
      padding: '20px',
      display: 'flex',
      flexDirection: 'column',
      gap: '14px',
      transition: 'all 0.25s ease',
      opacity: tour.active ? 1 : 0.5,
      position: 'relative',
      overflow: 'hidden',
    }}>
      {/* Цветная полоска слева */}
      <div style={{
        position: 'absolute', left: 0, top: 0, bottom: 0, width: '3px',
        background: cardColor, borderRadius: '14px 0 0 14px',
        opacity: tour.active ? 1 : 0.3,
      }} />

      {/* Шапка карточки */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '8px' }}>
        <div style={{ display: 'flex', gap: '10px', alignItems: 'center', flex: 1, minWidth: 0 }}>
          <span style={{ fontSize: '22px', flexShrink: 0 }}>{getEmoji(tour.slug)}</span>
          <div style={{ minWidth: 0 }}>
            <div style={{
              fontSize: '13px', fontWeight: '600', lineHeight: '1.3',
              color: tour.active ? 'var(--text-main)' : 'var(--text-muted)',
              overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap'
            }}>
              {tour.title}
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>
              {tour.slug}
            </div>
          </div>
        </div>

        {/* Переключатель активности */}
        <button
          onClick={handleToggleActive}
          disabled={toggling}
          style={{
            background: 'none', border: 'none', cursor: 'pointer',
            padding: '2px', flexShrink: 0, opacity: toggling ? 0.5 : 1,
          }}
          title={tour.active ? 'Скрыть тур' : 'Показать тур'}
        >
          {tour.active
            ? <ToggleRight size={22} color="var(--accent-emerald)" />
            : <ToggleLeft size={22} color="var(--text-muted)" />
          }
        </button>
      </div>

      {/* Метки */}
      <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
        <span style={{
          fontSize: '10px', fontWeight: '600', padding: '2px 8px', borderRadius: '20px',
          background: `${cardColor}18`, color: cardColor, border: `1px solid ${cardColor}30`
        }}>
          {catLabels[cat]}
        </span>
        {tour.duration && (
          <span style={{
            fontSize: '10px', padding: '2px 8px', borderRadius: '20px',
            background: 'rgba(255,255,255,0.04)', color: 'var(--text-muted)',
            border: '1px solid var(--glass-border)',
            display: 'flex', alignItems: 'center', gap: '4px'
          }}>
            <Clock size={9} /> {tour.duration}
          </span>
        )}
        {saved && (
          <span style={{
            fontSize: '10px', padding: '2px 8px', borderRadius: '20px',
            background: 'rgba(16,185,129,0.15)', color: 'var(--accent-emerald)',
            border: '1px solid rgba(16,185,129,0.3)',
          }}>
            ✓ Сохранено
          </span>
        )}
      </div>

      {/* Цены */}
      <div style={{
        background: 'rgba(0,0,0,0.2)', borderRadius: '10px', padding: '12px 14px',
        border: '1px solid var(--glass-border)',
      }}>
        {editing ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '10px', color: 'var(--text-muted)', marginBottom: '4px' }}>Взрослый ฿</div>
                <input
                  type="number"
                  value={adultVal}
                  onChange={e => setAdultVal(e.target.value)}
                  onKeyDown={handleKeyDown}
                  autoFocus
                  style={{
                    width: '100%', background: 'rgba(0,229,255,0.08)', border: `1px solid ${accentColor}50`,
                    color: 'var(--text-main)', borderRadius: '6px', padding: '6px 10px',
                    fontSize: '15px', fontWeight: '700', outline: 'none',
                  }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '10px', color: 'var(--text-muted)', marginBottom: '4px' }}>Ребёнок ฿</div>
                <input
                  type="number"
                  value={childVal}
                  onChange={e => setChildVal(e.target.value)}
                  onKeyDown={handleKeyDown}
                  style={{
                    width: '100%', background: 'rgba(0,229,255,0.08)', border: `1px solid ${accentColor}50`,
                    color: 'var(--text-main)', borderRadius: '6px', padding: '6px 10px',
                    fontSize: '15px', fontWeight: '700', outline: 'none',
                  }}
                />
              </div>
            </div>
            <div style={{ display: 'flex', gap: '6px' }}>
              <button
                onClick={handleSave}
                disabled={saving}
                style={{
                  flex: 1, padding: '7px', borderRadius: '8px', border: 'none', cursor: 'pointer',
                  background: 'linear-gradient(135deg, #00b0ff, #00e5ff)', color: '#000',
                  fontWeight: '700', fontSize: '12px', display: 'flex', alignItems: 'center',
                  justifyContent: 'center', gap: '4px',
                }}
              >
                {saving ? <RefreshCw size={12} style={{ animation: 'spin 1s linear infinite' }} /> : <Check size={12} />}
                {saving ? 'Сохраняем...' : 'Сохранить'}
              </button>
              <button
                onClick={() => { setEditing(false); setAdultVal(String(tour.price_adult)); setChildVal(String(tour.price_child)); }}
                style={{
                  padding: '7px 12px', borderRadius: '8px', border: '1px solid var(--glass-border)',
                  cursor: 'pointer', background: 'var(--glass-bg)', color: 'var(--text-muted)',
                }}
              >
                <X size={12} />
              </button>
            </div>
          </div>
        ) : (
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div style={{ fontSize: '10px', color: 'var(--text-muted)', marginBottom: '2px' }}>Взрослый / Ребёнок</div>
              <div style={{ display: 'flex', gap: '6px', alignItems: 'baseline' }}>
                <span style={{ fontSize: '18px', fontWeight: '800', color: accentColor }}>
                  {tour.price_adult.toLocaleString()}฿
                </span>
                {tour.price_child !== tour.price_adult && (
                  <span style={{ fontSize: '13px', color: 'var(--text-muted)', fontWeight: '600' }}>
                    / {tour.price_child.toLocaleString()}฿
                  </span>
                )}
              </div>
            </div>
            <button
              onClick={() => setEditing(true)}
              style={{
                background: 'rgba(0,229,255,0.08)', border: '1px solid rgba(0,229,255,0.2)',
                borderRadius: '8px', padding: '7px 10px', cursor: 'pointer',
                color: 'var(--accent-cyan)', display: 'flex', alignItems: 'center', gap: '5px',
                fontSize: '12px', fontWeight: '500', transition: 'all 0.2s',
              }}
            >
              <Pencil size={12} /> Изменить
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Главный компонент ────────────────────────────────────────────────────────

export default function ToursView() {
  const { activeMarket } = useApp();
  const [tours, setTours]         = useState([]);
  const [loading, setLoading]     = useState(true);
  const [activeTab, setActiveTab] = useState('all');
  const [search, setSearch]       = useState('');

  const fetchTours = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('tours')
      .select('slug, title, price_adult, price_child, duration, active, sort_order, category')
      .eq('market_id', activeMarket)
      .order('sort_order', { ascending: true });
    if (!error) setTours(data || []);
    setLoading(false);
  }, [activeMarket]);

  useEffect(() => { fetchTours(); }, [fetchTours]);

  const handleSave = async (slug, priceAdult, priceChild, active) => {
    const updateObj = { price_adult: priceAdult, price_child: priceChild };
    if (active !== undefined) updateObj.active = active;
    const { error } = await supabase
      .from('tours')
      .update(updateObj)
      .eq('slug', slug)
      .eq('market_id', activeMarket);
    if (!error) {
      setTours(prev => prev.map(t =>
        t.slug === slug ? { ...t, price_adult: priceAdult, price_child: priceChild, ...(active !== undefined ? { active } : {}) } : t
      ));
    }
  };

  // Фильтрация
  const filtered = tours.filter(t => {
    const catMatch = activeTab === 'all' || getCategory(t.slug) === activeTab;
    const searchMatch = !search || t.title.toLowerCase().includes(search.toLowerCase()) || t.slug.includes(search.toLowerCase());
    return catMatch && searchMatch;
  });

  // Статистика по активным турам
  const stats = (tab) => {
    const src = tab === 'all' ? tours : tours.filter(t => getCategory(t.slug) === tab);
    const active = src.filter(t => t.active);
    return {
      total: src.length,
      active: active.length,
      avgPrice: active.length ? Math.round(active.reduce((s, t) => s + t.price_adult, 0) / active.length) : 0,
      minPrice: active.length ? Math.min(...active.map(t => t.price_adult)) : 0,
      maxPrice: active.length ? Math.max(...active.map(t => t.price_adult)) : 0,
    };
  };

  const currentStats = stats(activeTab === 'all' ? 'all' : activeTab);
  const accentColor = TAB_COLOR[activeTab] || 'var(--accent-cyan)';

  return (
    <div>
      {/* Заголовок */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '28px' }}>
        <div>
          <h1 style={{ fontSize: '26px', fontWeight: '800', marginBottom: '4px' }}>
            Каталог экскурсий
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>
            Редактируй цены — они сразу обновятся в боте, сайте и приложении
          </p>
        </div>
        <button
          onClick={fetchTours}
          className="btn"
          style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px' }}
        >
          <RefreshCw size={14} /> Обновить
        </button>
      </div>

      {/* Вкладки */}
      <div style={{ display: 'flex', gap: '8px', marginBottom: '24px', flexWrap: 'wrap' }}>
        {TABS.map(({ id, label, Icon, color, bg }) => {
          const s = stats(id === 'all' ? 'all' : id);
          const isActive = activeTab === id;
          return (
            <button
              key={id}
              onClick={() => setActiveTab(id)}
              style={{
                display: 'flex', alignItems: 'center', gap: '8px',
                padding: '10px 18px', borderRadius: '12px', cursor: 'pointer',
                border: isActive ? `1px solid ${color}60` : '1px solid var(--glass-border)',
                background: isActive ? bg : 'var(--glass-bg)',
                color: isActive ? color : 'var(--text-muted)',
                fontWeight: isActive ? '700' : '500', fontSize: '14px',
                transition: 'all 0.2s ease',
                boxShadow: isActive ? `0 0 20px ${color}20` : 'none',
              }}
            >
              <Icon size={16} />
              {label}
              <span style={{
                fontSize: '11px', fontWeight: '700',
                background: isActive ? `${color}25` : 'rgba(255,255,255,0.05)',
                color: isActive ? color : 'var(--text-muted)',
                padding: '1px 7px', borderRadius: '20px',
              }}>
                {s.total}
              </span>
            </button>
          );
        })}
      </div>

      {/* Статистика */}
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
        gap: '12px', marginBottom: '24px',
      }}>
        {[
          { label: 'Всего туров', value: currentStats.total, icon: Hash, suffix: '' },
          { label: 'Активных', value: currentStats.active, icon: TrendingUp, suffix: '' },
          { label: 'Средняя цена', value: currentStats.avgPrice.toLocaleString(), icon: Star, suffix: '฿' },
          { label: 'Диапазон', value: `${currentStats.minPrice.toLocaleString()}–${currentStats.maxPrice.toLocaleString()}`, icon: Star, suffix: '฿' },
        ].map(({ label, value, icon: Icon, suffix }) => (
          <div key={label} style={{
            background: `linear-gradient(135deg, ${accentColor}08, transparent)`,
            border: `1px solid ${accentColor}20`,
            borderRadius: '12px', padding: '16px 18px',
          }}>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '6px' }}>{label}</div>
            <div style={{ fontSize: '20px', fontWeight: '800', color: accentColor }}>
              {value}{suffix}
            </div>
          </div>
        ))}
      </div>

      {/* Поиск */}
      <div style={{ position: 'relative', marginBottom: '20px' }}>
        <Search size={15} style={{
          position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)',
          color: 'var(--text-muted)',
        }} />
        <input
          type="text"
          placeholder="Поиск по названию или slug..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={{
            width: '100%', paddingLeft: '40px', paddingRight: '16px',
            background: 'var(--glass-bg)', border: '1px solid var(--glass-border)',
            color: 'var(--text-main)', borderRadius: '10px', padding: '10px 16px 10px 40px',
            fontSize: '14px', outline: 'none',
          }}
        />
      </div>

      {/* Сетка карточек */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px', color: 'var(--text-muted)' }}>
          <RefreshCw size={24} style={{ animation: 'spin 1s linear infinite', marginBottom: '12px' }} />
          <div>Загружаем каталог...</div>
        </div>
      ) : filtered.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '60px', color: 'var(--text-muted)' }}>
          Ничего не найдено
        </div>
      ) : (
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
          gap: '14px',
        }}>
          {filtered.map(tour => (
            <TourCard
              key={tour.slug}
              tour={tour}
              onSave={handleSave}
              activeTab={activeTab}
            />
          ))}
        </div>
      )}

      <style>{`
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
      `}</style>
    </div>
  );
}
