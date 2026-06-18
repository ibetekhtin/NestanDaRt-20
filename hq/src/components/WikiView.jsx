import { useState } from 'react';
import { BookMarked, MessageSquare } from 'lucide-react';

const WIKI_CATEGORIES = [
  {
    title: '💬 Шаблоны ответов и скрипты',
    items: [
      { q: 'Первый контакт (запрос в бота/директ)', a: 'Здравствуйте! Рад приветствовать вас на Пхукете 🏝️ Меня зовут Котэ. С радостью помогу сделать ваш отдых ярким и нестандартным! Напишите, пожалуйста, вас интересуют авторские туры, аренда мото/авто или проживание на острове?' },
      { q: 'Скрипт по аренде байков', a: 'Для аренды байка вам понадобятся: загранпаспорт, водительские права категории А (желательно МВУ) и залог. Стоимость аренды Honda ADV 160 составляет от 600 THB в день в зависимости от срока. Доставка до отеля возможна. Оформляем договор, шлемы предоставляются бесплатно.' }
    ]
  },
  {
    title: '🚗 Логистика и Услуги',
    items: [
      { q: 'Где забирать байки и машины?', a: 'Наш основной офис аренды мото и авто находится недалеко от Патонга. Также у нас работает бесконтактная доставка к отелям по всему острову. Подробности можно уточнить у менеджера в ВК (vk.me/ibetekhtin).' },
      { q: 'Недвижимость на острове', a: 'Покупка, долгосрочная аренда вилл и кондоминиумов на Пхукете — все вопросы направляйте напрямую Илье Бетехтину в ВК: vk.me/ibetekhtin.' }
    ]
  },
  {
    title: '🏝️ Ресурсы экосистемы',
    items: [
      { q: 'Официальные ресурсы «Нестандартный Отдых»', a: 'Сайт: nestandart.online\nКанал: @nestandart_phuket_channel\nАфиша: @nestandart_phuket_events\nАдминистратор/бронь: @nestandart_phuket' }
    ]
  }
];

export default function WikiView() {
  const [search, setSearch] = useState('');

  return (
    <div>
      <div style={{ marginBottom: '32px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: '700' }}>База знаний (Wiki) 📚</h1>
        <p style={{ color: 'var(--text-muted)' }}>Регламенты, шаблоны общения с клиентами и полезная справочная информация</p>
      </div>

      <div style={{ marginBottom: '24px' }}>
        <input type="text" placeholder="Поиск по базе знаний..." style={{ width: '100%' }} value={search} onChange={e => setSearch(e.target.value)} />
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
        {WIKI_CATEGORIES.map((cat, idx) => {
          const filteredItems = cat.items.filter(item => 
            item.q.toLowerCase().includes(search.toLowerCase()) || 
            item.a.toLowerCase().includes(search.toLowerCase())
          );

          if (filteredItems.length === 0) return null;

          return (
            <div key={idx} className="glass-card">
              <h3 style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--accent-cyan)', marginBottom: '16px', borderBottom: '1px solid var(--glass-border)', paddingBottom: '8px' }}>
                <BookMarked size={20} /> {cat.title}
              </h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {filteredItems.map((item, iIdx) => (
                  <div key={iIdx} style={{ background: 'rgba(0,0,0,0.15)', padding: '16px', borderRadius: '8px' }}>
                    <h4 style={{ fontWeight: '600', fontSize: '15px', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <MessageSquare size={16} color="var(--accent-amber)" /> {item.q}
                    </h4>
                    <p style={{ color: 'var(--text-muted)', fontSize: '14px', whiteSpace: 'pre-wrap', lineHeight: '1.5' }}>{item.a}</p>
                  </div>
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
