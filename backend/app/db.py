"""
LEXIA - Conexión a base de datos
==================================
Usa SQLAlchemy, así que cambiar de SQLite (desarrollo) a PostgreSQL
(producción, como pide el documento del proyecto) es solo cuestión de
cambiar DATABASE_URL en .env — el resto del código no cambia.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

from .config import DATABASE_URL

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
