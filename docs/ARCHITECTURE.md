# 🏗️ Architecture — KOTЭ SYSTEM

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
      │   Gemini AI  │     │   Supabase   │
      │  (2.0 Flash) │     │  (Postgres)  │
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
- **AI:** Gemini 2.0 Flash via `@google/generative-ai`

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
| AI | Google Gemini | 2.0 Flash |
| Database | Supabase (PostgreSQL) | 15+ |
| Automation | n8n | latest |
| Mobile | Expo + TypeScript | SDK 52 |
| Deploy | Docker Compose | 2.x |
| VPS | Hetzner | CPX21 |

## Multi-Market Architecture

Every table has `market_id TEXT REFERENCES markets(id)`. Adding a new market = 1 SQL INSERT. No code changes needed. All queries filter by market_id.