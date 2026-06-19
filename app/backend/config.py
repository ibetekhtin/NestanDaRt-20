"""
KOTЭ Backend — Configuration (pydantic-settings)
"""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_KEY: str = ""
    SUPABASE_ANON_KEY: str = ""
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.0-flash"
    OPENROUTER_API_KEY: str = ""
    OPENROUTER_MODEL: str = "google/gemini-2.0-flash-exp:free"
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.3-70b-versatile"
    TELEGRAM_BOT_TOKEN: str = ""
    MANAGER_CHAT_ID: str = ""
    KOTE_RPC_SECRET: str = ""
    BACKEND_PORT: int = 8000
    N8N_HOST: str = "http://localhost:5678"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()