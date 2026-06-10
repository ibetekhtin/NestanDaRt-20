// ============ НЕСТАНДАРТНЫЙ ОТДЫХ® ============

// === НАСТРОЙКИ ===
const TG_BOT = 'nestandart_phuket';
const WA_PHONE = '66804894595';

// === TELEGRAM WEB APP INIT ===
const isTelegram = !!(window.Telegram && window.Telegram.WebApp && window.Telegram.WebApp.initData);
const tg = isTelegram ? window.Telegram.WebApp : null;

if (isTelegram) {
  // Mark body for CSS targeting
  document.documentElement.classList.add('tg-app');
  document.body.classList.add('tg-app');

  // Expand to full height
  tg.expand();

  // Tell Telegram the app is ready to show
  tg.ready();

  // Disable vertical swipes (prevents closing on scroll)
  if (tg.disableVerticalSwipes) {
    tg.disableVerticalSwipes();
  }

  // Set header color to match our dark theme
  if (tg.setHeaderColor) {
    tg.setHeaderColor('#0A0A0A');
  }
  if (tg.setBackgroundColor) {
    tg.setBackgroundColor('#0A0A0A');
  }

  // Enable closing confirmation (prevent accidental close)
  if (tg.enableClosingConfirmation) {
    tg.enableClosingConfirmation();
  }

  // Use Telegram's back button for navigation
  if (tg.BackButton) {
    // Show back button when user scrolls down
    let lastScroll = 0;
    window.addEventListener('scroll', () => {
      if (window.scrollY > 400 && lastScroll <= 400) {
        tg.BackButton.show();
      }
      if (window.scrollY <= 100 && lastScroll > 100) {
        tg.BackButton.hide();
      }
      lastScroll = window.scrollY;
    }, { passive: true });

    // Back button scrolls to top
    tg.BackButton.onClick(() => {
      window.scrollTo({ top: 0, behavior: 'smooth' });
      tg.BackButton.hide();
    });
  }

  // Haptic feedback on button taps
  document.addEventListener('click', (e) => {
    const target = e.target.closest('.big-cta, .huge-cta, .m-btn, .filter-btn, .t-card, .cc-word, .cc-skip');
    if (target && tg.HapticFeedback) {
      tg.HapticFeedback.impactOccurred('light');
    }
  });

  // Use Main Button for primary CTA (Telegram native button at bottom)
  if (tg.MainButton) {
    tg.MainButton.setText('⮡ НАПИСАТЬ В TELEGRAM');
    tg.MainButton.color = '#C0FF00';
    tg.MainButton.textColor = '#0A0A0A';
    tg.MainButton.show();
    tg.MainButton.onClick(() => {
      window.open(`https://t.me/${TG_BOT}?start=general`, '_blank');
    });
  }

  console.log('[Nestandart] Running inside Telegram Web App');
  console.log('[Nestandart] User:', tg.initDataUnsafe?.user?.first_name || 'unknown');
}

// === CITY STATE ===
const CITIES = {
  phuket:  { name: 'Пхукет',  prep: 'на', loc: 'Пхукете',  dat: 'Пхукету', acc: 'Пхукет' },
  pattaya: { name: 'Паттайя', prep: 'в',  loc: 'Паттайе',  dat: 'Паттайе', acc: 'Паттайю' }
};
let currentCity = localStorage.getItem('nestandart_city') || null;

function applyCity(cityKey) {
  if (!CITIES[cityKey]) return;
  currentCity = cityKey;
  localStorage.setItem('nestandart_city', cityKey);
  const c = CITIES[cityKey];

  // Toggle color theme: Phuket = green-primary, Pattaya = orange-primary
  document.documentElement.classList.toggle('city-pattaya', cityKey === 'pattaya');
  document.body.classList.toggle('city-pattaya', cityKey === 'pattaya');

  // Update hero third line
  const heroPrep = document.getElementById('heroCityPrep');
  const heroCity = document.getElementById('heroCityName');
  if (heroPrep && heroCity) {
    heroCity.classList.add('swap');
    setTimeout(() => {
      heroPrep.textContent = c.prep;
      heroCity.textContent = c.loc;
      setTimeout(() => heroCity.classList.remove('swap'), 400);
    }, 200);
  }

  // Update nav city switch
  const csName = document.getElementById('csName');
  if (csName) csName.textContent = c.name;

  // Update brand in nav header
  const brandCity = document.getElementById('brandCity');
  if (brandCity) brandCity.textContent = c.prep + ' ' + c.loc;

  // Update footer brand
  const footerCity = document.getElementById('footerCity');
  if (footerCity) {
    footerCity.textContent = c.prep + ' ' + c.loc;
  }

  // Update tagline
  const taglineP = document.querySelector('.hero-tagline p');
  if (taglineP) {
    taglineP.innerHTML = `Авторские туры ${c.prep} ${c.loc}.<br>Экскурсии. VIP-сопровождение.`;
  }

  // Update marquee — accent on chosen city
  document.querySelectorAll('.marquee-track span').forEach(s => {
    const txt = s.textContent.trim();
    if (txt === 'ПХУКЕТ' || txt === 'ПАТТАЙЯ') {
      s.style.opacity = (txt.toLowerCase() === c.name.toLowerCase()) ? '1' : '0.5';
    }
  });

  // === SHOW/HIDE TOURS BY CITY ===
  const allCards = document.querySelectorAll('.t-card[data-city]');
  const dragTrack = document.getElementById('dragTrack');
  const pattayaSoon = document.getElementById('pattayaSoon');
  const filtersEl = document.querySelector('.filters');
  const dragWrapEl = document.getElementById('dragWrap');
  const toursHint = document.querySelector('.tours-hint');

  if (cityKey === 'phuket') {
    // Show Phuket tours
    allCards.forEach(card => {
      if (card.dataset.city === 'phuket' || card.dataset.city === 'both') {
        card.style.display = '';
      } else {
        card.style.display = 'none';
      }
    });
    if (pattayaSoon) pattayaSoon.style.display = 'none';
    if (dragWrapEl) dragWrapEl.style.display = '';
    if (filtersEl) filtersEl.style.display = '';
    if (toursHint) toursHint.style.display = '';
  } else if (cityKey === 'pattaya') {
    // Hide all Phuket tours, show placeholder
    allCards.forEach(card => {
      if (card.dataset.city === 'pattaya' || card.dataset.city === 'both') {
        card.style.display = '';
      } else {
        card.style.display = 'none';
      }
    });
    // Check if any pattaya cards exist
    const pattayaCards = document.querySelectorAll('.t-card[data-city="pattaya"]');
    if (pattayaCards.length === 0 && pattayaSoon) {
      pattayaSoon.style.display = 'flex';
      if (dragWrapEl) dragWrapEl.style.display = 'none';
      if (filtersEl) filtersEl.style.display = 'none';
      if (toursHint) toursHint.style.display = 'none';
    }
  }

  // Reset filter to "Все"
  document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
  const allBtn = document.querySelector('.filter-btn[data-filter="all"]');
  if (allBtn) allBtn.classList.add('active');

  // Scroll drag track to start
  if (dragTrack) dragTrack.scrollTo({ left: 0, behavior: 'smooth' });

  // Update document title
  document.title = `Нестандартный Отдых® — авторские туры ${c.prep} ${c.loc}`;

  // Update contact section text
  const contactSub = document.querySelector('.contact-sub');
  if (contactSub) contactSub.textContent = `Мы на связи 24/7, пока вы отдыхаете.`;

  // Update manifesto
  const manifText = document.querySelector('.manifesto-text');
  if (manifText) {
    manifText.textContent = `Нестандартный Отдых® — команда, которая объездила ${c.acc} вдоль и поперёк. Авторские маршруты, скрытые места, личный подход. Каждый маршрут — под вас. Каждый день — как вы хотите.`;
  }
}

// === LOADER ===
document.body.classList.add('loading');

const loader = document.getElementById('loader');
const loaderBar = document.getElementById('loaderBar');
const loaderPct = document.getElementById('loaderPct');
const cityChooser = document.getElementById('cityChooser');

let progress = 0;
const loaderInterval = setInterval(() => {
  progress += Math.random() * 12;
  if (progress >= 100) {
    progress = 100;
    clearInterval(loaderInterval);
    setTimeout(() => {
      loader.classList.add('hidden');

      // If city not chosen yet → show chooser. Otherwise → straight to site.
      if (!currentCity) {
        showCityChooser();
      } else {
        applyCity(currentCity);
        document.body.classList.remove('loading');
        startRandomGlitch();
      }
    }, 400);
  }
  loaderBar.style.width = progress + '%';
  loaderPct.textContent = String(Math.floor(progress)).padStart(3, '0');
}, 90);

// === CITY CHOOSER ===
function showCityChooser() {
  if (!cityChooser) {
    // Fallback if chooser missing
    applyCity('phuket');
    document.body.classList.remove('loading');
    startRandomGlitch();
    return;
  }
  cityChooser.classList.add('show');
}

function hideCityChooser() {
  if (!cityChooser) return;
  cityChooser.classList.add('hide');
  setTimeout(() => {
    cityChooser.style.display = 'none';
    document.body.classList.remove('loading');
    startRandomGlitch();
  }, 500);
}

// City word click handlers
document.querySelectorAll('.cc-word').forEach(w => {
  w.addEventListener('click', () => {
    const city = w.dataset.city;
    applyCity(city);
    hideCityChooser();
  });
});

// City switch button (in nav) - toggle between cities
const citySwitch = document.getElementById('citySwitch');
if (citySwitch) {
  citySwitch.addEventListener('click', () => {
    const next = currentCity === 'phuket' ? 'pattaya' : 'phuket';
    applyCity(next);
  });
}

// === RANDOM GLITCH on hero title ===
function startRandomGlitch() {
  const heroTitle = document.querySelector('.hero-title');
  if (!heroTitle) return;

  // === AUTO-FIT TITLE — guarantees it fits any screen ===
  fitHeroTitle();
  window.addEventListener('resize', fitHeroTitle);

  function triggerGlitch() {
    heroTitle.classList.add('glitch-active');
    setTimeout(() => {
      heroTitle.classList.remove('glitch-active');
    }, 200 + Math.random() * 300);
    setTimeout(triggerGlitch, 3000 + Math.random() * 5000);
  }
  setTimeout(triggerGlitch, 2000);
}

// Fit hero title to viewport width
function fitHeroTitle() {
  const title = document.querySelector('.hero-title');
  if (!title) return;
  const container = title.parentElement;
  if (!container) return;

  const maxW = container.clientWidth;
  const lines = title.querySelectorAll('.ht-line');
  if (!lines.length) return;

  // Reset
  title.style.fontSize = '';

  // Find widest line
  let widest = 0;
  lines.forEach(line => {
    if (line.scrollWidth > widest) widest = line.scrollWidth;
  });

  // If overflowing, scale down
  if (widest > maxW) {
    const currentSize = parseFloat(getComputedStyle(title).fontSize);
    const newSize = Math.floor(currentSize * (maxW / widest) * 0.95);
    title.style.fontSize = newSize + 'px';
  }
}

// === MOBILE MENU ===
const navToggle = document.getElementById('navToggle');
const mobileMenu = document.getElementById('mobileMenu');
if (navToggle && mobileMenu) {
  navToggle.addEventListener('click', () => mobileMenu.classList.toggle('open'));
  mobileMenu.querySelectorAll('a').forEach(a => {
    a.addEventListener('click', () => mobileMenu.classList.remove('open'));
  });
}

// === CITY ROTATOR (deprecated — replaced by explicit chooser) ===
// kept empty for backward compat

// === FILTERS ===
const filterBtns = document.querySelectorAll('.filter-btn');
const tCards = document.querySelectorAll('.t-card');

filterBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    filterBtns.forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    const filter = btn.dataset.filter;

    tCards.forEach(card => {
      if (filter === 'all' || card.dataset.cat === filter) {
        card.classList.remove('hidden');
      } else {
        card.classList.add('hidden');
      }
    });

    const track = document.getElementById('dragTrack');
    if (track) track.scrollTo({ left: 0, behavior: 'smooth' });
  });
});

// === DRAG SCROLL ===
const dragWrap = document.getElementById('dragWrap');
const dragTrack = document.getElementById('dragTrack');
const dragBar = document.getElementById('dragBar');
let hasDragged = false;

if (dragWrap && dragTrack) {
  let isDown = false;
  let startX = 0;
  let scrollLeft = 0;
  let moveDistance = 0;

  const updateProgress = () => {
    const maxScroll = dragTrack.scrollWidth - dragTrack.clientWidth;
    if (maxScroll <= 0) {
      dragBar.style.width = '100%';
      return;
    }
    const pct = (dragTrack.scrollLeft / maxScroll) * 100;
    dragBar.style.width = Math.max(10, pct) + '%';
  };

  dragWrap.addEventListener('mousedown', (e) => {
    isDown = true;
    moveDistance = 0;
    hasDragged = false;
    dragWrap.classList.add('dragging');
    startX = e.pageX - dragTrack.offsetLeft;
    scrollLeft = dragTrack.scrollLeft;
  });

  dragWrap.addEventListener('mouseleave', () => {
    isDown = false;
    dragWrap.classList.remove('dragging');
  });

  dragWrap.addEventListener('mouseup', () => {
    isDown = false;
    dragWrap.classList.remove('dragging');
    if (moveDistance > 5) hasDragged = true;
    setTimeout(() => { hasDragged = false; }, 50);
  });

  dragWrap.addEventListener('mousemove', (e) => {
    if (!isDown) return;
    e.preventDefault();
    const x = e.pageX - dragTrack.offsetLeft;
    const walk = (x - startX) * 1.5;
    moveDistance = Math.abs(walk);
    dragTrack.scrollLeft = scrollLeft - walk;
  });

  dragTrack.addEventListener('scroll', updateProgress);

  dragWrap.addEventListener('wheel', (e) => {
    if (Math.abs(e.deltaY) > Math.abs(e.deltaX)) {
      e.preventDefault();
      dragTrack.scrollLeft += e.deltaY;
    }
  }, { passive: false });

  setTimeout(updateProgress, 100);
}

// === BOT LINKS ===
function tgLink(tourId) {
  return `https://t.me/${TG_BOT}?start=${tourId}`;
}
function waLink(tourName) {
  const msg = encodeURIComponent(`Здравствуйте! Интересует тур: ${tourName}`);
  return `https://wa.me/${WA_PHONE}?text=${msg}`;
}

const bigBookBtn = document.getElementById('bigBookBtn');
if (bigBookBtn) bigBookBtn.href = tgLink('general');

// === BOOKING MODAL ===
const modal = document.getElementById('modal');
const modalTour = document.getElementById('modalTour');
const modalNum = document.getElementById('modalNum');
const modalTg = document.getElementById('modalTg');
const modalWa = document.getElementById('modalWa');

tCards.forEach(card => {
  card.addEventListener('click', (e) => {
    if (hasDragged) return;

    const tourId = card.dataset.id || 'general';
    const tourName = card.querySelector('h3')?.textContent || 'Тур';
    const tourNum = card.querySelector('.t-card-num')?.textContent || '00';

    if (modalTour) modalTour.textContent = tourName;
    if (modalNum) modalNum.textContent = tourNum;
    if (modalTg) modalTg.href = tgLink(tourId);
    if (modalWa) modalWa.href = waLink(tourName);

    modal.classList.add('open');
    document.body.style.overflow = 'hidden';
  });
});

function closeModal(e) {
  if (e.target.id === 'modal') closeModalForce();
}
function closeModalForce() {
  modal.classList.remove('open');
  document.body.style.overflow = '';
}

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') closeModalForce();
});

window.closeModal = closeModal;
window.closeModalForce = closeModalForce;

// === PARALLAX — desktop only, no mobile jank ===
const isMobile = () => window.innerWidth < 900 ||
  ('ontouchstart' in window) ||
  navigator.maxTouchPoints > 0;

const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (!isMobile() && !prefersReducedMotion) {
  // Scroll parallax — desktop only, limited to hero title
  const heroTitleEl = document.querySelector('.hero-title');
  let ticking = false;

  window.addEventListener('scroll', () => {
    if (!ticking) {
      requestAnimationFrame(() => {
        if (heroTitleEl) {
          const offset = window.scrollY * 0.12;
          heroTitleEl.style.transform = `translateY(${offset}px)`;
        }
        ticking = false;
      });
      ticking = true;
    }
  }, { passive: true });

  // Mouse parallax on hero — desktop only
  const heroSec = document.querySelector('.hero');
  const heroTit = document.querySelector('.hero-title');
  if (heroSec && heroTit) {
    let mx = 0, my = 0, tx = 0, ty = 0;
    heroSec.addEventListener('mousemove', (e) => {
      const r = heroSec.getBoundingClientRect();
      tx = ((e.clientX - r.left) / r.width - 0.5) * 22;
      ty = ((e.clientY - r.top) / r.height - 0.5) * 14;
    });
    heroSec.addEventListener('mouseleave', () => { tx = 0; ty = 0; });
    (function loop() {
      mx += (tx - mx) * 0.07;
      my += (ty - my) * 0.07;
      heroTit.querySelectorAll('.ht-line').forEach((line, i) => {
        const d = i === 0 ? 1 : i === 1 ? 1.2 : 0.8;
        line.style.transform = `translate(${mx * d}px, ${my * d}px)`;
      });
      requestAnimationFrame(loop);
    })();
  }
}

// === SCROLL REVEAL — IntersectionObserver (works on mobile too) ===
if ('IntersectionObserver' in window) {
  const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.style.opacity = '1';
        entry.target.style.transform = 'translateY(0)';
        revealObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.08, rootMargin: '0px 0px -30px 0px' });

  // Only animate cards and numbers, not marquee/hero
  document.querySelectorAll('.t-card, .blog-card, .m-num, .faq-item').forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(20px)';
    el.style.transition = 'opacity 0.4s ease, transform 0.4s ease';
    revealObserver.observe(el);
  });
}
