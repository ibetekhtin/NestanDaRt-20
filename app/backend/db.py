"""
Shared Supabase client — единственный инстанс на всё приложение.
Создаётся один раз при импорте; все роутеры делают `from db import sb`.
"""
from supabase import create_client, Client
from config import settings

sb: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)
