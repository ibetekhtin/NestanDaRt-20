"""
KOTЭ Backend — FastAPI Application
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime

from config import settings
from routers import markets, leads, bookings, clients, ai, sos, memory, webhooks


app = FastAPI(
    title="KOTЭ Backend API",
    description="Нестандартный Отдых — REST API для мобильного приложения и webhook relay",
    version="1.0.0",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(markets.router, prefix="/api/v1", tags=["markets"])
app.include_router(leads.router, prefix="/api/v1", tags=["leads"])
app.include_router(bookings.router, prefix="/api/v1", tags=["bookings"])
app.include_router(clients.router, prefix="/api/v1", tags=["clients"])
app.include_router(ai.router, prefix="/api/v1", tags=["ai"])
app.include_router(sos.router, prefix="/api/v1", tags=["sos"])
app.include_router(memory.router, prefix="/api/v1", tags=["memory"])
app.include_router(webhooks.router, prefix="/webhook", tags=["webhooks"])


@app.get("/api/v1/health")
async def health():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}


@app.get("/")
async def root():
    return {"service": "KOTЭ Backend", "version": "1.0.0", "docs": "/docs"}