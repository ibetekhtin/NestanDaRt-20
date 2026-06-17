"""Intent detection — mirrors n8n 🔍 Интент Code node logic."""

import re
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Optional


@dataclass
class Intent:
    interests: list[str] = field(default_factory=list)
    budget_level: Optional[str] = None
    arrival_date: Optional[str] = None
    group_size: Optional[int] = None
    has_children: Optional[bool] = None
    new_stage: Optional[str] = None
    last_tour_viewed: Optional[str] = None

    @property
    def has_updates(self) -> bool:
        return bool(
            self.interests or self.budget_level or self.last_tour_viewed
            or self.arrival_date or self.group_size or self.has_children is not None
        )


_MONTHS = [
    ("январ", "01"), ("феврал", "02"), ("март", "03"), ("апрел", "04"),
    ("май", "05"), ("мая", "05"), ("июн", "06"), ("июл", "07"),
    ("август", "08"), ("сентябр", "09"), ("октябр", "10"),
    ("ноябр", "11"), ("декабр", "12"),
]

_TOUR_MAP = [
    (r"джеймс.?бонд|james.?bond|бонд.?остров", "james"),
    (r"пхи.?пхи|phi.?phi", "phiphi-bamboo"),
    (r"симилан", "similan"),
    (r"мото.?тур|мотоцикл.?остров", "moto"),
    (r"рафтинг|слоны.?atv|atv.?слон", "raft"),
    (r"гиббон|зиплайн", "gibbon"),
    (r"као.?сок", "khaosok2"),
    (r"яхт", "yacht"),
    (r"vip.?сопров|персональный.?менеджер", "vip"),
    (r"фаер.?шоу|fire.?show", "fire"),
    (r"ко.?лан|ko.?lan", "kolan"),
    (r"тиффани", "tiffany"),
    (r"нонг.?нуч", "nong-nooch"),
    (r"рамаян|аквапарк", "aqua-ramayana"),
    (r"катамаран|закат", "sunset-cat"),
    (r"кхао.?кхео|сафари", "khao-kheo"),
]


def detect_intent(text: str) -> Intent:
    t = text.lower()
    intent = Intent()

    # Interests
    if re.search(r"остров|море|пляж|пхи|симил|джеймс|снорклинг|яхт|морск|дайв|кораллы|плавани", t):
        intent.interests.append("islands")
    if re.search(r"актив|рафтинг|atv|квадро|мото|зиплайн|гиббон|слон|адренал|спорт|экстрим", t):
        intent.interests.append("active")
    if re.search(r"природ|джунгли|као.?сок|водопад|лес|нацпарк|эко|нетронут", t):
        intent.interests.append("nature")
    if re.search(r"вечер|шоу|фаер|тиффани|муай|бокс|закат|романтик|ужин|кабаре", t):
        intent.interests.append("evening")
    if re.search(r"дети|ребенок|семья|детей|малыш|семейн|ребята|ребёнок", t):
        intent.interests.append("family")
    if re.search(r"vip|яхта|премиум|luxury|эксклюзив|персональн", t):
        intent.interests.append("vip")

    # Budget
    if re.search(r"недорого|дёшево|бюджетн|экономн", t):
        intent.budget_level = "low"
    elif re.search(r"vip|деньги.{0,10}не.{0,5}вопрос|любой бюджет|премиум", t):
        intent.budget_level = "vip"

    # Arrival date
    for name, num in _MONTHS:
        if name in t:
            year = "2026" if num >= "11" else "2027"
            intent.arrival_date = f"{year}-{num}"
            break
    if not intent.arrival_date:
        m = re.search(r"через (\d+) (день|дня|дней|недел)", t)
        if m:
            days = int(m.group(1)) * (7 if "недел" in m.group(2) else 1)
            intent.arrival_date = (date.today() + timedelta(days=days)).strftime("%Y-%m")

    # Group size
    m = re.search(r"нас\s+(\d+)|(\d+)\s*человек|(\d+)\s*взросл", t)
    if m:
        intent.group_size = int(next(x for x in m.groups() if x))
    else:
        for word, n in [("двое", 2), ("трое", 3), ("четверо", 4), ("пятеро", 5)]:
            if word in t:
                intent.group_size = n
                break

    if re.search(r"дети|ребенок|ребёнок|детей|малыш|с детьми", t):
        intent.has_children = True
    elif re.search(r"без детей|только взросл|не берём детей", t):
        intent.has_children = False

    # Funnel stage
    if re.search(r"забронир|оформ|хочу.{0,10}(тур|брон)|запис|оплат|купить|давай|беру|берём|пишите цену|как заброн", t):
        intent.new_stage = "booking"
    elif re.search(r"понравил|отлично|супер|незабываем|рекомендую|спасибо за тур|было здорово", t):
        intent.new_stage = "done"
    elif re.search(r"потом|подумаю|позже|не сейчас|может быть|посмотрим|пока не знаю", t):
        intent.new_stage = "thinking"
    elif re.search(r"не нужно|не надо|не интересно|нет спасибо|передумал|отменить", t):
        intent.new_stage = "cold"
    elif intent.interests or intent.budget_level or intent.arrival_date or intent.group_size:
        intent.new_stage = "interest"

    # Tour viewed
    for pattern, slug in _TOUR_MAP:
        if re.search(pattern, t):
            intent.last_tour_viewed = slug
            break

    return intent
