"""
tools_places.py — Поиск мест рядом через OpenStreetMap Overpass API.

Бесплатно, без ключей. Для каждого места генерирует ссылку на Google Maps
с отзывами — пользователь видит реальные рейтинги.

Опционально: если задан GOOGLE_PLACES_API_KEY — добавляет рейтинги напрямую.
"""

import logging
import os
import urllib.parse
from dataclasses import dataclass, field
from typing import Optional

import httpx

log = logging.getLogger("kote.places")

OVERPASS_URL = "https://lz4.overpass-api.de/api/interpreter"
TIMEOUT = 10.0
GOOGLE_KEY = os.getenv("GOOGLE_PLACES_API_KEY", "")

# ── Категории ─────────────────────────────────────────────────────────────────

CATEGORY_QUERIES = {
    "ресторан":         '"amenity"~"restaurant|food_court"',
    "поесть":           '"amenity"~"restaurant|cafe|fast_food"',
    "кафе":             '"amenity"="cafe"',
    "бар":              '"amenity"~"bar|pub|biergarten"',
    "клуб":             '"amenity"~"bar|pub|nightclub"',
    "ночная жизнь":     '"amenity"~"bar|pub|nightclub"',
    "пляж":             '"natural"="beach"',
    "аптека":           '"amenity"="pharmacy"',
    "банкомат":         '"amenity"="atm"',
    "банк":             '"amenity"="bank"',
    "магазин":          '"shop"~"supermarket|mall|convenience"',
    "заправка":         '"amenity"="fuel"',
    "больница":         '"amenity"~"hospital|clinic"',
    "достопримечательность": '"tourism"~"attraction|museum|viewpoint"',
    "смотровая":        '"tourism"="viewpoint"',
    "храм":             '"amenity"~"place_of_worship"',
    "отель":            '"tourism"~"hotel|guest_house"',
    "обмен":            '"amenity"~"bureau_de_change"',
    "wifi":             '"amenity"~"cafe|library"',
}

DEFAULT_FILTERS = [
    '"amenity"~"restaurant|cafe|bar|pub|fast_food"',
    '"tourism"~"attraction|viewpoint"',
    '"natural"="beach"',
]

EMOJI = {
    "restaurant": "🍽️", "cafe": "☕", "bar": "🍹", "pub": "🍺",
    "fast_food": "🍔", "nightclub": "🎵", "beach": "🏖️",
    "pharmacy": "💊", "atm": "🏧", "bank": "🏦",
    "supermarket": "🛒", "attraction": "🎯", "viewpoint": "🌅",
    "place_of_worship": "🙏", "hotel": "🏨", "bureau_de_change": "💱",
    "hospital": "🏥", "clinic": "🏥",
}

# ── Модель ────────────────────────────────────────────────────────────────────

@dataclass
class Place:
    name: str
    lat: float
    lng: float
    kind: str = ""
    address: str = ""
    website: str = ""

    @property
    def emoji(self) -> str:
        return EMOJI.get(self.kind, "📍")

    @property
    def maps_url(self) -> str:
        q = urllib.parse.quote(f"{self.name} Phuket")
        return f"https://www.google.com/maps/search/{q}/@{self.lat},{self.lng},17z"

    @property
    def maps_coord_url(self) -> str:
        return f"https://maps.google.com/?q={self.lat},{self.lng}"


# ── Overpass ──────────────────────────────────────────────────────────────────

def _build_query(lat: float, lng: float, filters: list[str], radius: int, limit: int) -> str:
    parts = "\n".join(
        f'  node[{f}](around:{radius},{lat},{lng});'
        for f in filters
    )
    return f"""[out:json][timeout:{int(TIMEOUT)}];
(
{parts}
);
out {limit};"""


def _parse_element(el: dict) -> Optional[Place]:
    tags = el.get("tags", {})
    name = tags.get("name:ru") or tags.get("name") or tags.get("name:en")
    if not name:
        return None
    lat = el.get("lat") or el.get("center", {}).get("lat")
    lng = el.get("lon") or el.get("center", {}).get("lon")
    if not lat or not lng:
        return None

    kind = (
        tags.get("amenity") or tags.get("tourism") or
        tags.get("natural") or tags.get("shop") or ""
    )
    addr_parts = filter(None, [
        tags.get("addr:street"),
        tags.get("addr:housenumber"),
        tags.get("addr:city"),
    ])
    return Place(
        name=name, lat=lat, lng=lng, kind=kind,
        address=", ".join(addr_parts),
        website=tags.get("website") or tags.get("contact:website") or "",
    )


async def nearby_places(
    lat: float,
    lng: float,
    query: str = "",
    radius: int = 1500,
    limit: int = 5,
) -> list[Place]:
    """Ищет места рядом через Overpass API (OpenStreetMap). Ключ не нужен."""
    filters = _detect_filters(query)
    overpass_query = _build_query(lat, lng, filters, radius, limit * 3)

    try:
        encoded = urllib.parse.urlencode({"data": overpass_query})
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            r = await client.post(
                OVERPASS_URL,
                content=encoded,
                headers={
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "*/*",
                    "User-Agent": "KoteBot/1.0 (nestandart.online)",
                },
            )
        if r.status_code != 200:
            log.warning(f"Overpass HTTP {r.status_code}")
            return []
        elements = r.json().get("elements", [])
    except Exception as e:
        log.warning(f"Overpass error: {e}")
        return []

    places = []
    seen = set()
    for el in elements:
        p = _parse_element(el)
        if p and p.name not in seen:
            seen.add(p.name)
            places.append(p)
        if len(places) >= limit:
            break

    return places


def _detect_filters(query: str) -> list[str]:
    q = query.lower()
    for keyword, osm_filter in CATEGORY_QUERIES.items():
        if keyword in q:
            return [osm_filter]
    return DEFAULT_FILTERS


# ── Форматирование ────────────────────────────────────────────────────────────

def maps_category_urls(lat: float, lng: float) -> dict[str, str]:
    base = f"@{lat},{lng},15z"
    return {
        "🍜 Рестораны":    f"https://www.google.com/maps/search/restaurants/{base}",
        "🍹 Бары":         f"https://www.google.com/maps/search/bars/{base}",
        "🏖️ Пляжи":       f"https://www.google.com/maps/search/beach/{base}",
        "🛍️ Шопинг":      f"https://www.google.com/maps/search/shopping/{base}",
        "💊 Аптеки":       f"https://www.google.com/maps/search/pharmacy/{base}",
        "🏧 Банкоматы":    f"https://www.google.com/maps/search/ATM/{base}",
        "💱 Обменники":    f"https://www.google.com/maps/search/currency+exchange/{base}",
    }


def format_places_message(places: list[Place], lat: float, lng: float, query: str = "") -> str:
    if not places:
        urls = maps_category_urls(lat, lng)
        lines = ["📍 <b>Рядом с тобой</b> — выбери категорию:\n"]
        for label, url in urls.items():
            lines.append(f'{label}: <a href="{url}">открыть карту</a>')
        lines.append(
            f'\n🗺 <a href="https://maps.google.com/?q={lat},{lng}">Показать моё местоположение</a>'
        )
        return "\n".join(lines)

    import html as _html
    lines = [f"📍 <b>Рядом с тобой</b> ({len(places)} мест):\n"]
    for i, p in enumerate(places, 1):
        line = f'{i}. {p.emoji} <b>{_html.escape(p.name)}</b>'
        if p.address:
            line += f"\n    📌 {_html.escape(p.address)}"
        line += f'\n    <a href="{p.maps_url}">Открыть в Google Maps →</a>'
        lines.append(line)

    lines.append(
        f'\n🔍 <a href="https://www.google.com/maps/search/places/@{lat},{lng},15z">'
        f'Смотреть все места рядом</a>'
    )
    return "\n\n".join(lines)
