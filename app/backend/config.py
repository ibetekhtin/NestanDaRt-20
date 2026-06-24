"""
NestanDaRt-20 Backend — Configuration (pydantic-settings)
"""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_KEY: str = ""
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.5-flash"
    OPENROUTER_API_KEY: str = ""
    OPENROUTER_MODEL: str = "google/gemini-2.5-flash-lite"
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.3-70b-versatile"
    TELEGRAM_BOT_TOKEN: str = ""
    MANAGER_CHAT_ID: str = ""
    KOTE_RPC_SECRET: str = ""
    # YooKassa (оплата). Пустые ключи → платежи мягко отключены.
    YOOKASSA_SHOP_ID: str = ""
    YOOKASSA_SECRET_KEY: str = ""
    YOOKASSA_RETURN_URL: str = "https://nestandart.online/"
    YOOKASSA_BAHT_TO_RUB: float = 2.6   # курс ฿→₽ для расчёта суммы (правится без кода)

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()