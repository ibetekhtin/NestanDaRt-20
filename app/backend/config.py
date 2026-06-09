"""
KOTЭ Backend — Configuration (pydantic-settings)
"""
from pydantic_settings import BaseSettings
import os


class Settings(BaseSettings):
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_KEY: str = ""
    SUPABASE_ANON_KEY: str = ""
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.0-flash"
    BACKEND_PORT: int = 8000
    N8N_HOST: str = "http://localhost:5678"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()