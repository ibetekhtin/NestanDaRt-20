"""Единый секрет-гейт для приватных эндпоинтов (fail-closed).

Используется как FastAPI-зависимость: `_=Depends(require_secret)`.
Заменяет 6 копий _check_secret с несогласованной (часть fail-open) семантикой.
"""
import hmac
from typing import Optional

from fastapi import Header, HTTPException

from config import settings


def require_secret(x_kote_secret: Optional[str] = Header(None)) -> None:
    expected = settings.KOTE_RPC_SECRET
    # fail-closed: незаданный секрет = мисконфигурация сервера, а не «всем можно»
    if not expected:
        raise HTTPException(status_code=503, detail="KOTE_RPC_SECRET not configured")
    if not x_kote_secret or not hmac.compare_digest(x_kote_secret, expected):
        raise HTTPException(status_code=403, detail="Forbidden")
