// Single source of truth for all markets
// New market = new entry here, nothing else changes

export const MARKETS = {
  phuket: {
    id: 'phuket',
    name: 'Пхукет',
    nameEn: 'Phuket',
    prep: 'на',
    loc: 'Пхукете',
    dat: 'Пхукету',
    acc: 'Пхукет',
    active: true,
    tg_bot: 'phuket_nestandart_bot',
    wa_phone: '66804894595',
    domain: 'nestandart-phuket.ru',
    theme: 'green', // CSS theme class
  },
  pattaya: {
    id: 'pattaya',
    name: 'Паттайя',
    nameEn: 'Pattaya',
    prep: 'в',
    loc: 'Паттайе',
    dat: 'Паттайе',
    acc: 'Паттайю',
    active: false, // coming soon
    tg_bot: 'phuket_nestandart_bot',
    wa_phone: '66804894595',
    domain: 'nestandart-pattaya.ru',
    theme: 'orange',
  },
  bali: {
    id: 'bali',
    name: 'Бали',
    nameEn: 'Bali',
    prep: 'на',
    loc: 'Бали',
    dat: 'Бали',
    acc: 'Бали',
    active: false,
    tg_bot: 'phuket_nestandart_bot',
    wa_phone: '66804894595',
    domain: 'nestandart-bali.ru',
    theme: 'green',
  },
  dubai: {
    id: 'dubai',
    name: 'Дубай',
    nameEn: 'Dubai',
    prep: 'в',
    loc: 'Дубае',
    dat: 'Дубаю',
    acc: 'Дубай',
    active: false,
    tg_bot: 'phuket_nestandart_bot',
    wa_phone: '66804894595',
    domain: 'nestandart-dubai.ru',
    theme: 'gold',
  },
};

export const ACTIVE_MARKETS = Object.values(MARKETS).filter(m => m.active);
export const DEFAULT_MARKET = 'phuket';