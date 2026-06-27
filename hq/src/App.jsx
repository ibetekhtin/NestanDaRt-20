import { useState, useEffect } from 'react';
import { AppProvider, useApp } from './context/AppContext';
import { supabase, isSupabaseConfigured } from './supabase';
import {
  LayoutDashboard, Users, FolderKanban, Megaphone,
  DollarSign, BookOpen, LogOut
} from 'lucide-react';

import DashboardView from './components/DashboardView';
import CRMView from './components/CRMView';
import KanbanView from './components/KanbanView';
import ContentFactoryView from './components/ContentFactoryView';
import FinanceView from './components/FinanceView';
import WikiView from './components/WikiView';

const MARKETS = [
  { id: 'phuket', label: '🏝️ Пхукет' },
  { id: 'pattaya', label: '🌅 Паттайя' },
  { id: 'bali', label: '🌿 Бали' },
  { id: 'dubai', label: '🏙️ Дубай' },
];

function AppContent() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [session, setSession] = useState(null);
  const [authReady, setAuthReady] = useState(false);
  const [emailInput, setEmailInput] = useState('');
  const [passInput, setPassInput] = useState('');
  const [authError, setAuthError] = useState('');
  const { activeMarket, setActiveMarket, refetch } = useApp();

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (!isSupabaseConfigured) { setAuthReady(true); return; }
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setAuthReady(true);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_event, s) => setSession(s));
    return () => sub.subscription.unsubscribe();
  }, []);

  // После логина перезагружаем данные — RLS открывает доступ только authenticated
  useEffect(() => { if (session) refetch(); }, [session]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleLogin = async (e) => {
    e.preventDefault();
    setAuthError('');
    const { error } = await supabase.auth.signInWithPassword({ email: emailInput, password: passInput });
    if (error) setAuthError(error.message === 'Invalid login credentials' ? 'Неверный email или пароль' : error.message);
  };

  const handleLogout = () => supabase.auth.signOut();

  if (!authReady) {
    return <div style={{ display: 'flex', height: '100vh', justifyContent: 'center', alignItems: 'center', color: 'var(--text-muted)' }}>Загрузка...</div>;
  }

  if (isSupabaseConfigured && !session) {
    return (
      <div style={{ display: 'flex', height: '100vh', justifyContent: 'center', alignItems: 'center' }}>
        <form onSubmit={handleLogin} className="glass-card" style={{ width: '360px', textAlign: 'center' }}>
          <h2 style={{ marginBottom: '8px', color: 'var(--accent-cyan)' }}>ШТАБ</h2>
          <p style={{ color: 'var(--text-muted)', marginBottom: '24px' }}>Нестандартный Отдых®</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <input type="email" placeholder="Email администратора" required value={emailInput} onChange={e => setEmailInput(e.target.value)} />
            <input type="password" placeholder="Пароль" required value={passInput} onChange={e => setPassInput(e.target.value)} />
            {authError && <p style={{ color: 'var(--accent-rose)', fontSize: '13px', margin: 0 }}>{authError}</p>}
            <button type="submit" className="btn btn-primary">Войти в центр управления</button>
          </div>
        </form>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh' }}>
      {/* Боковая панель навигации */}
      <aside style={{ width: '280px', background: 'var(--bg-secondary)', borderRight: '1px solid var(--glass-border)', padding: '24px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
        <div style={{ padding: '0 8px 24px 8px', borderBottom: '1px solid var(--glass-border)', marginBottom: '16px' }}>
          <h2 style={{ color: 'var(--accent-cyan)', fontSize: '20px', fontWeight: '800' }}>ШТАБ</h2>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Операционный центр</span>
          <select
            value={activeMarket}
            onChange={e => setActiveMarket(e.target.value)}
            style={{ marginTop: '8px', width: '100%', background: 'var(--glass-bg)', border: '1px solid var(--glass-border)', color: 'var(--text-main)', borderRadius: '6px', padding: '4px 8px', fontSize: '13px', cursor: 'pointer' }}
          >
            {MARKETS.map(m => (
              <option key={m.id} value={m.id}>{m.label}</option>
            ))}
          </select>
        </div>

        <button className={`btn ${activeTab === 'dashboard' ? 'btn-primary' : ''}`} style={{ justifyContent: 'flex-start', width: '100%' }} onClick={() => setActiveTab('dashboard')}>
          <LayoutDashboard size={20} /> CEO Dashboard
        </button>
        <button className={`btn ${activeTab === 'crm' ? 'btn-primary' : ''}`} style={{ justifyContent: 'flex-start', width: '100%' }} onClick={() => setActiveTab('crm')}>
          <Users size={20} /> Клиенты
        </button>
        <button className={`btn ${activeTab === 'kanban' ? 'btn-primary' : ''}`} style={{ justifyContent: 'flex-start', width: '100%' }} onClick={() => setActiveTab('kanban')}>
          <FolderKanban size={20} /> Заявки
        </button>
        <button className={`btn ${activeTab === 'content' ? 'btn-primary' : ''}`} style={{ justifyContent: 'flex-start', width: '100%' }} onClick={() => setActiveTab('content')}>
          <Megaphone size={20} /> Контент-завод
        </button>
        <button className={`btn ${activeTab === 'finance' ? 'btn-primary' : ''}`} style={{ justifyContent: 'flex-start', width: '100%' }} onClick={() => setActiveTab('finance')}>
          <DollarSign size={20} /> Финансовый штаб
        </button>
        <button className={`btn ${activeTab === 'wiki' ? 'btn-primary' : ''}`} style={{ justifyContent: 'flex-start', width: '100%' }} onClick={() => setActiveTab('wiki')}>
          <BookOpen size={20} /> Wiki База знаний
        </button>

        <div style={{ marginTop: 'auto', paddingTop: '16px', borderTop: '1px solid var(--glass-border)' }}>
          {isSupabaseConfigured && session && (
            <button className="btn" style={{ width: '100%', justifyContent: 'center', marginBottom: '12px', fontSize: '13px' }} onClick={handleLogout}>
              <LogOut size={16} /> Выйти
            </button>
          )}
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', textAlign: 'center' }}>
            nestandart-phuket.ru © 2026
          </div>
        </div>
      </aside>

      {/* Основной контент */}
      <main style={{ flex: 1, padding: '40px', overflowY: 'auto', height: '100vh' }}>
        {activeTab === 'dashboard' && <DashboardView />}
        {activeTab === 'crm' && <CRMView />}
        {activeTab === 'kanban' && <KanbanView />}
        {activeTab === 'content' && <ContentFactoryView />}
        {activeTab === 'finance' && <FinanceView />}
        {activeTab === 'wiki' && <WikiView />}
      </main>
    </div>
  );
}

export default function App() {
  return (
    <AppProvider>
      <AppContent />
    </AppProvider>
  );
}
