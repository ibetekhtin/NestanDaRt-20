# 🏗️ Architecture — KOTЭ SYSTEM

> **Актуально на 21.06.2026:** боевой бот КотЭ работает как **n8n workflow** (`doCUKEZQpLQjDmxP`), не как отдельный JS/Telegraf-сервис (тот — легаси, не развёрнут). Мозг — **Groq `llama-3.3-70b-versatile`** (не Gemini), но с 21.06 n8n зовёт его **через backend** (`/api/v1/ai/chat`), а не напрямую — это даёт боту весь каскад резерва: groq→aitunnel→openrouter→gemini (см. `AI_ARCHITECTURE.md`).

## System Overview

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│  Telegram   │   │   Website   │   │   Mobile    │
│  Bot (JS)   │   │   (HTML)    │   │  (Expo)     │
└──────┬──────┘   └──────┬──────┘   └──────┬──────┘
       │                 │                  │
       │           ┌─────┴──────┐           │
       │           │  Backend   │           │
       └──────────►│ (FastAPI)  │◄──────────┘
                   └─────┬──────┘
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
      ┌──────────────┐     ┌──────────────┐
      │   Groq AI    │     │   Supabase   │
      │ (llama-3.3)  │     │  (Postgres)  │
      └──────────────┘     └──────┬───────┘
                                  │
                           ┌──────┴───────┐
                           │     n8n      │
                           │  Workflows   │
                           └──────┬───────┘
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
              ┌──────────┐ ┌──────────┐ ┌──────────┐
              │ Provider │ │ Manager  │ │  Client  │
              │  (Hotel) │ │(Telegram)│ │(Telegram)│
              └──────────┘ └──────────┘ └──────────┘
```

## Components

### 1. Telegram Bot (`bot/`)
- **Stack:** Node.js + Telegraf 4.x
- **Role:** Primary client interface
- **Features:** Market selection, service browsing, booking, AI chat, SOS
- **State:** Stateless — all data in Supabase
- **AI:** Groq `llama-3.3-70b-versatile` (live-бот в n8n зовёт backend `/api/v1/ai/chat` → каскад groq→aitunnel→openrouter→gemini)

### 2. Backend API (`app/backend/`)
- **Stack:** Python + FastAPI
- **Role:** REST API for mobile app + webhook relay
- **Auth:** Supabase JWT
- **Docs:** Auto-generated at `/docs` (Swagger)

### 3. Supabase (PostgreSQL)
- **Role:** Single Source of Truth
- **Tables:** 13 tables + 3 views
- **Features:** RLS, RPC functions, triggers, auto-audit

### 4. n8n Workflows
- **Role:** Event-driven automation
- **Flows:** 8 workflows (leads, bookings, SOS, reminders, reports, memory)

### 5. Website (`website/`)
- **Stack:** Static HTML + Supabase JS SDK
- **Role:** Marketing/catalog page

### 6. Mobile App (`mobile/`)
- **Stack:** React Native (Expo) + TypeScript
- **API:** Through Backend, not direct Supabase

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Bot | Node.js + Telegraf | 20.x / 4.16 |
| Backend | Python + FastAPI | 3.12 / 0.115 |
| AI | Groq (+ aitunnel/openrouter/gemini fallback) | llama-3.3-70b |
| Database | Supabase (PostgreSQL) | 15+ |
| Automation | n8n | latest |
| Mobile | Expo + TypeScript | SDK 52 |
| Deploy | Docker Compose | 2.x |
| VPS | Hetzner | CPX21 |

## Multi-Market Architecture

Every table has `market_id TEXT REFERENCES markets(id)`. Adding a new market = 1 SQL INSERT. No code changes needed. All queries filter by market_id.