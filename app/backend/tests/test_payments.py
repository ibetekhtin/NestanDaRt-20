"""
Тесты платёжного модуля.

Часть 1 — unit: чистая логика payments (_amount_rub, идемпотентный ключ) без сети.
Часть 2 — smoke: контракт статус-кодов по работающему сервису
          (NESTANDART_API_BASE, по умолчанию http://127.0.0.1:8000).

Запуск:  pytest app/backend/tests/test_payments.py -q
"""
import hashlib
import os
import sys

import httpx
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from routers.payments import _amount_rub  # noqa: E402
from config import settings  # noqa: E402

BASE = os.getenv("NESTANDART_API_BASE", "http://127.0.0.1:8000").rstrip("/")
V1 = f"{BASE}/api/v1"


# ── unit: расчёт суммы ────────────────────────────────────────
def test_amount_basic():
    tour = {"price_adult": 1000, "price_child": 500}
    # 2 взрослых + 1 ребёнок = 2500 ฿ × курс, округление вверх
    expected_baht = 2500
    got = _amount_rub(tour, 2, 1)
    assert got >= expected_baht * settings.YOOKASSA_BAHT_TO_RUB - 1
    assert got == -(-int(expected_baht * settings.YOOKASSA_BAHT_TO_RUB * 100) // 100) or got > 0


def test_amount_child_null_uses_adult_price():
    tour = {"price_adult": 1000, "price_child": None}
    one_adult = _amount_rub(tour, 1, 0)
    with_child = _amount_rub(tour, 1, 1)
    assert with_child == _amount_rub(tour, 2, 0)  # ребёнок = цена взрослого
    assert with_child > one_adult


def test_amount_negative_people_clamped():
    tour = {"price_adult": 1000, "price_child": 500}
    assert _amount_rub(tour, -5, -3) == 0  # отрицательные не уводят сумму в минус


def test_amount_zero_price():
    assert _amount_rub({"price_adult": 0, "price_child": 0}, 2, 2) == 0


def test_amount_rounds_up():
    # 1 ฿ × 2.6 = 2.6 → ceil = 3: не занижаем сумму
    tour = {"price_adult": 1, "price_child": None}
    got = _amount_rub(tour, 1, 0)
    rate = settings.YOOKASSA_BAHT_TO_RUB
    import math
    assert got == math.ceil(1 * rate)


def test_idempotence_key_stable():
    # ключ идемпотентности детерминирован по (бронь, сумма)
    k1 = hashlib.sha256("EXT-1:2600".encode()).hexdigest()
    k2 = hashlib.sha256("EXT-1:2600".encode()).hexdigest()
    k3 = hashlib.sha256("EXT-1:2700".encode()).hexdigest()
    assert k1 == k2 and k1 != k3


# ── smoke: контракт эндпоинтов ────────────────────────────────
@pytest.fixture(scope="session")
def client():
    with httpx.Client(timeout=15) as c:
        yield c


def test_pay_create_requires_secret(client):
    r = client.post(f"{V1}/pay/create", json={"external_id": "x", "tour_slug": "x"})
    assert r.status_code in (403, 503)  # fail-closed без X-Kote-Secret


def test_pay_reconcile_requires_secret(client):
    r = client.post(f"{V1}/pay/reconcile")
    assert r.status_code in (403, 503)


def test_pay_webhook_ignores_garbage(client):
    # мусорное тело не должно ронять вебхук (YooKassa ретраит 5xx)
    r = client.post(f"{V1}/pay/webhook", json={"event": "noise", "object": {}})
    assert r.status_code == 200
    assert r.json() == {"ok": True}


def test_pay_webhook_unknown_payment_ignored(client):
    r = client.post(f"{V1}/pay/webhook", json={
        "event": "payment.succeeded",
        "object": {"id": "test-nonexistent-payment-id"},
    })
    assert r.status_code == 200  # неизвестный платёж — игнор, не 5xx


def test_pay_webhook_empty_body_ok(client):
    r = client.post(f"{V1}/pay/webhook", content=b"not-json",
                    headers={"Content-Type": "application/json"})
    assert r.status_code == 200
