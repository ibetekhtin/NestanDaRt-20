"""
Smoke-тесты API kote-backend.

Бьют по работающему сервису (по умолчанию http://127.0.0.1:8000).
Переопределить: KOTE_API_BASE=https://nestandart.online pytest

Проверяют контракт статус-кодов: 200 на существующее, 404 на отсутствующее,
422 на невалидный body. Реальные данные БД не ассертим (smoke, не unit).

Запуск:
    pip install pytest httpx
    pytest app/backend/tests/ -q
"""
import os
import httpx
import pytest

BASE = os.getenv("KOTE_API_BASE", "http://127.0.0.1:8000").rstrip("/")
V1 = f"{BASE}/api/v1"


@pytest.fixture(scope="session")
def client():
    with httpx.Client(timeout=15) as c:
        yield c


def test_health(client):
    r = client.get(f"{BASE}/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_markets_list(client):
    r = client.get(f"{V1}/markets")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_market_not_found(client):
    assert client.get(f"{V1}/markets/no-such-market").status_code == 404


def test_tours_list(client):
    r = client.get(f"{V1}/tours")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_tour_by_slug_roundtrip(client):
    tours = client.get(f"{V1}/tours").json()
    if not tours:
        pytest.skip("каталог туров пуст")
    slug = tours[0]["slug"]
    r = client.get(f"{V1}/tours/{slug}")
    assert r.status_code == 200
    assert r.json()["slug"] == slug


def test_tour_not_found(client):
    # невалидный slug не должен ронять PostgREST UUID-парсингом (был баг → 500)
    assert client.get(f"{V1}/tours/definitely-not-a-tour").status_code == 404


def test_client_not_found(client):
    assert client.get(f"{V1}/clients/0000000000").status_code == 404


def test_booking_not_found(client):
    nil_uuid = "00000000-0000-0000-0000-000000000000"
    assert client.get(f"{V1}/bookings/{nil_uuid}").status_code == 404


def test_lead_validation_requires_identifier(client):
    # пустой лид без phone/tg/telegram/email → 400
    assert client.post(f"{V1}/leads", json={"name": "Test"}).status_code == 400


def test_lead_bad_body(client):
    # не-JSON-схема → 422 от pydantic
    assert client.post(f"{V1}/leads", json={"budget": "not-a-number"}).status_code == 422


def test_ai_ask(client):
    r = client.post(f"{V1}/ai/ask", json={
        "market_id": "phuket", "session_id": "smoke", "message": "Привет"
    })
    assert r.status_code == 200
    assert "reply" in r.json()


def test_webhook_requires_secret(client):
    # без заголовка X-Kote-Secret → 403 (fail-closed)
    r = client.post(f"{V1}/webhook/lead", json={"phone": "+70000000000"})
    assert r.status_code in (403, 503)
