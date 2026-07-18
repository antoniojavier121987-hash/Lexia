"""
LEXIA - Esquemas de la API (Pydantic)
=======================================
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr


class SignupRequest(BaseModel):
    email: EmailStr
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class ClauseOut(BaseModel):
    order_index: int
    title: Optional[str]
    original_text: str
    plain_explanation: Optional[str]
    risk_level: Optional[str]
    risk_reason: Optional[str]
    category: Optional[str]

    class Config:
        from_attributes = True


class ContractSummaryOut(BaseModel):
    id: int
    original_filename: str
    contract_type: Optional[str]
    risk_score: Optional[float]
    risk_level: Optional[str]
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


class ContractDetailOut(BaseModel):
    id: int
    original_filename: str
    contract_type: Optional[str]
    summary_general: Optional[str]
    summary_executive: Optional[str]
    risk_score: Optional[float]
    risk_level: Optional[str]
    risk_breakdown: Optional[dict]
    status: str
    created_at: datetime
    clauses: list[ClauseOut] = []

    class Config:
        from_attributes = True


class ChatRequest(BaseModel):
    question: str


class ChatMessageOut(BaseModel):
    role: str
    content: str
    created_at: datetime

    class Config:
        from_attributes = True


class SimulateRequest(BaseModel):
    scenario: str


class SimulateResponse(BaseModel):
    answer: str


class CompareRequest(BaseModel):
    contract_id_a: int
    contract_id_b: int


class CompareResponse(BaseModel):
    summary: str
    new_clauses: list[str] = []
    removed_clauses: list[str] = []
    obligations_increased: list[str] = []
    risks_increased: list[str] = []
    risks_decreased: list[str] = []
    risk_score_change: Optional[str] = None
