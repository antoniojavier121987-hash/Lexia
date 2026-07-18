"""
LEXIA - Configuración central
================================
Lee las variables de entorno y centraliza rutas/constantes usadas en
toda la aplicación.

Arquitectura de producción: Flutter App -> API FastAPI en Render -> Supabase -> IA
"""

import os
from dotenv import load_dotenv

load_dotenv()

# Base de datos: Supabase Postgres. Consigue esta cadena en tu proyecto de
# Supabase -> Project Settings -> Database -> Connection string (modo "Session").
# Ejemplo: postgresql://postgres:[email protected]:5432/postgres
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./lexia.db")

# Supabase Storage — para guardar los PDFs/imágenes de contratos y los reportes
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")  # service_role key (NO la anon key)
SUPABASE_BUCKET = os.getenv("SUPABASE_BUCKET", "contracts")

# Carpeta local TEMPORAL (Render tiene disco efímero — solo se usa un instante
# para poder aplicar OCR antes de subir el archivo final a Supabase Storage)
TMP_DIR = os.getenv("TMP_DIR", "/tmp/lexia_uploads")
os.makedirs(TMP_DIR, exist_ok=True)

# Motor de IA (Anthropic Claude) — necesario para el análisis de contratos
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-sonnet-4-6")

# Autenticación básica de la API (para el MVP; en producción usar Firebase Auth
# como indica el documento del proyecto, esto es un placeholder funcional)
JWT_SECRET = os.getenv("JWT_SECRET", "cambia-esto-por-un-valor-largo-y-secreto")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "1440"))  # 24h

MAX_UPLOAD_SIZE_MB = int(os.getenv("MAX_UPLOAD_SIZE_MB", "20"))

# Render asigna el puerto dinámicamente en esta variable
PORT = int(os.getenv("PORT", "8000"))

