"""
LEXIA - Modelos de base de datos
==================================
"""

from datetime import datetime

from sqlalchemy import Column, Integer, String, Text, Float, DateTime, ForeignKey, JSON
from sqlalchemy.orm import relationship

from .db import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)


class Contract(Base):
    __tablename__ = "contracts"

    id = Column(Integer, primary_key=True, index=True)
    owner_email = Column(String, index=True, nullable=False)
    original_filename = Column(String, nullable=False)
    file_path = Column(String, nullable=False)  # ruta dentro del bucket de Supabase Storage
    extracted_text = Column(Text, nullable=True)  # texto crudo del OCR

    # Resultado del análisis de IA (se guarda todo el JSON estructurado)
    contract_type = Column(String, nullable=True)
    summary_general = Column(Text, nullable=True)
    summary_executive = Column(Text, nullable=True)
    risk_score = Column(Float, nullable=True)       # 0-100
    risk_level = Column(String, nullable=True)       # BAJO / MEDIO / ALTO
    risk_breakdown = Column(JSON, nullable=True)     # {"financiero": "ALTO", "legal": "MEDIO", ...}

    status = Column(String, default="subido")  # subido | procesando | analizado | error
    created_at = Column(DateTime, default=datetime.utcnow)

    clauses = relationship("Clause", back_populates="contract", cascade="all, delete-orphan")
    messages = relationship("ChatMessage", back_populates="contract", cascade="all, delete-orphan")


class Clause(Base):
    __tablename__ = "clauses"

    id = Column(Integer, primary_key=True, index=True)
    contract_id = Column(Integer, ForeignKey("contracts.id"), nullable=False)

    order_index = Column(Integer, nullable=False)
    title = Column(String, nullable=True)
    original_text = Column(Text, nullable=False)
    plain_explanation = Column(Text, nullable=True)
    risk_level = Column(String, nullable=True)  # BAJO / MEDIO / ALTO
    risk_reason = Column(Text, nullable=True)
    category = Column(String, nullable=True)  # ej: "penalizacion", "renovacion_automatica", etc.

    contract = relationship("Contract", back_populates="clauses")


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    contract_id = Column(Integer, ForeignKey("contracts.id"), nullable=False)
    role = Column(String, nullable=False)  # "user" | "assistant"
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    contract = relationship("Contract", back_populates="messages")
