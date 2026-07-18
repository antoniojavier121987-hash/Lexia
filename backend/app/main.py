"""
LEXIA - API principal (FastAPI)
=================================
Backend del MVP de LEXIA: sube un contrato, se le extrae el texto (OCR),
se analiza con IA (detección de cláusulas y riesgos), y el usuario puede
conversar con la IA sobre el contrato.

Arrancar con: uvicorn app.main:app --reload
"""

import os
import shutil
import uuid

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
import io
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from . import models, schemas, ocr, ai_analysis, storage, report
from .db import engine, get_db, Base
from .auth import hash_password, verify_password, create_access_token, get_current_user_email
from .config import TMP_DIR, MAX_UPLOAD_SIZE_MB

Base.metadata.create_all(bind=engine)

app = FastAPI(title="LEXIA API", version="0.1.0 (MVP)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # restringe esto a tu dominio/app real en producción
    allow_methods=["*"],
    allow_headers=["*"],
)

ALLOWED_EXTENSIONS = {".pdf", ".docx", ".jpg", ".jpeg", ".png", ".webp"}

DISCLAIMER = (
    "LEXIA es una herramienta de apoyo para comprender contratos y no sustituye "
    "el asesoramiento de un abogado. Para decisiones legales importantes, consulta "
    "siempre con un profesional del derecho."
)


@app.get("/")
def health_check():
    return {"status": "ok", "service": "LEXIA API"}


# ---------------------------------------------------------------------------
# Autenticación
# ---------------------------------------------------------------------------
@app.post("/api/auth/signup", response_model=schemas.TokenResponse)
def signup(data: schemas.SignupRequest, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == data.email).first()
    if existing:
        raise HTTPException(status_code=409, detail="Ya existe una cuenta con ese correo.")

    user = models.User(email=data.email, password_hash=hash_password(data.password))
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Ya existe una cuenta con ese correo.")

    return schemas.TokenResponse(access_token=create_access_token(data.email))


@app.post("/api/auth/login", response_model=schemas.TokenResponse)
def login(data: schemas.LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == data.email).first()
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Correo o contraseña incorrectos.")
    return schemas.TokenResponse(access_token=create_access_token(data.email))


# ---------------------------------------------------------------------------
# Subida y análisis de contratos
# ---------------------------------------------------------------------------
@app.post("/api/contracts/upload", response_model=schemas.ContractSummaryOut)
async def upload_contract(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    email: str = Depends(get_current_user_email),
):
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Tipo de archivo no soportado. Usa: {', '.join(ALLOWED_EXTENSIONS)}",
        )

    # Guardar TEMPORALMENTE en disco (Render es efímero, esto solo dura
    # el tiempo de esta petición) para poder aplicarle OCR
    stored_name = f"{uuid.uuid4().hex}{ext}"
    tmp_path = os.path.join(TMP_DIR, stored_name)

    with open(tmp_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    size_mb = os.path.getsize(tmp_path) / (1024 * 1024)
    if size_mb > MAX_UPLOAD_SIZE_MB:
        os.remove(tmp_path)
        raise HTTPException(status_code=400, detail=f"El archivo excede {MAX_UPLOAD_SIZE_MB}MB.")

    # Extraer texto (OCR si hace falta) mientras el archivo aún vive en /tmp
    try:
        extracted_text = ocr.extract_text(tmp_path)
    except Exception as e:
        os.remove(tmp_path)
        raise HTTPException(status_code=422, detail=f"No se pudo leer el documento: {e}")

    if not extracted_text.strip():
        os.remove(tmp_path)
        raise HTTPException(
            status_code=422,
            detail="No se pudo extraer texto del documento (¿imagen muy borrosa o vacía?).",
        )

    # Subir el archivo definitivo a Supabase Storage (persiste de verdad)
    remote_name = f"{email}/{stored_name}"
    try:
        storage.upload_file(tmp_path, remote_name)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Error subiendo el archivo a Supabase: {e}")
    finally:
        os.remove(tmp_path)  # limpiar el disco temporal de Render

    contract = models.Contract(
        owner_email=email,
        original_filename=file.filename,
        file_path=remote_name,
        extracted_text=extracted_text,
        status="subido",
    )
    db.add(contract)
    db.commit()
    db.refresh(contract)

    return contract


@app.post("/api/contracts/{contract_id}/analyze", response_model=schemas.ContractDetailOut)
async def analyze_contract(
    contract_id: int,
    db: Session = Depends(get_db),
    email: str = Depends(get_current_user_email),
):
    contract = _get_owned_contract(db, contract_id, email)

    contract.status = "procesando"
    db.commit()

    try:
        result = await ai_analysis.analyze_contract(contract.extracted_text)
    except Exception as e:
        contract.status = "error"
        db.commit()
        raise HTTPException(status_code=502, detail=f"Error al analizar el contrato: {e}")

    contract.contract_type = result.get("contract_type")
    contract.summary_general = result.get("summary_general")
    contract.summary_executive = result.get("summary_executive")
    contract.risk_score = result.get("risk_score")
    contract.risk_level = result.get("risk_level")
    contract.risk_breakdown = result.get("risk_breakdown")
    contract.status = "analizado"

    # Reemplaza cláusulas previas si el contrato se re-analiza
    db.query(models.Clause).filter(models.Clause.contract_id == contract.id).delete()
    for c in result.get("clauses", []):
        db.add(models.Clause(
            contract_id=contract.id,
            order_index=c.get("order_index", 0),
            title=c.get("title"),
            original_text=c.get("original_text", ""),
            plain_explanation=c.get("plain_explanation"),
            risk_level=c.get("risk_level"),
            risk_reason=c.get("risk_reason"),
            category=c.get("category"),
        ))

    db.commit()
    db.refresh(contract)
    return contract


@app.get("/api/contracts", response_model=list[schemas.ContractSummaryOut])
def list_contracts(db: Session = Depends(get_db), email: str = Depends(get_current_user_email)):
    return (
        db.query(models.Contract)
        .filter(models.Contract.owner_email == email)
        .order_by(models.Contract.created_at.desc())
        .all()
    )


@app.get("/api/contracts/{contract_id}", response_model=schemas.ContractDetailOut)
def get_contract(
    contract_id: int, db: Session = Depends(get_db), email: str = Depends(get_current_user_email)
):
    return _get_owned_contract(db, contract_id, email)


# ---------------------------------------------------------------------------
# Chat conversacional sobre el contrato
# ---------------------------------------------------------------------------
@app.post("/api/contracts/{contract_id}/chat", response_model=schemas.ChatMessageOut)
async def chat_with_contract(
    contract_id: int,
    data: schemas.ChatRequest,
    db: Session = Depends(get_db),
    email: str = Depends(get_current_user_email),
):
    contract = _get_owned_contract(db, contract_id, email)

    history = (
        db.query(models.ChatMessage)
        .filter(models.ChatMessage.contract_id == contract.id)
        .order_by(models.ChatMessage.created_at.asc())
        .all()
    )
    history_dicts = [{"role": m.role, "content": m.content} for m in history]

    user_msg = models.ChatMessage(contract_id=contract.id, role="user", content=data.question)
    db.add(user_msg)
    db.commit()

    try:
        answer = await ai_analysis.chat_about_contract(
            contract.extracted_text, history_dicts, data.question
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Error al responder: {e}")

    assistant_msg = models.ChatMessage(contract_id=contract.id, role="assistant", content=answer)
    db.add(assistant_msg)
    db.commit()
    db.refresh(assistant_msg)

    return assistant_msg


@app.get("/api/contracts/{contract_id}/chat", response_model=list[schemas.ChatMessageOut])
def get_chat_history(
    contract_id: int, db: Session = Depends(get_db), email: str = Depends(get_current_user_email)
):
    contract = _get_owned_contract(db, contract_id, email)
    return (
        db.query(models.ChatMessage)
        .filter(models.ChatMessage.contract_id == contract.id)
        .order_by(models.ChatMessage.created_at.asc())
        .all()
    )


@app.get("/api/contracts/{contract_id}/file-url")
def get_contract_file_url(
    contract_id: int, db: Session = Depends(get_db), email: str = Depends(get_current_user_email)
):
    contract = _get_owned_contract(db, contract_id, email)
    try:
        url = storage.get_signed_url(contract.file_path)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Error generando la URL del archivo: {e}")
    return {"url": url, "expires_in_seconds": 3600}


@app.get("/api/disclaimer")
def get_disclaimer():
    return {"disclaimer": DISCLAIMER}


# ---------------------------------------------------------------------------
# Simulador de escenarios futuros ("¿qué pasa si...?")
# ---------------------------------------------------------------------------
@app.post("/api/contracts/{contract_id}/simulate", response_model=schemas.SimulateResponse)
async def simulate_scenario(
    contract_id: int,
    data: schemas.SimulateRequest,
    db: Session = Depends(get_db),
    email: str = Depends(get_current_user_email),
):
    contract = _get_owned_contract(db, contract_id, email)
    if contract.status != "analizado":
        raise HTTPException(
            status_code=400, detail="Analiza el contrato antes de simular escenarios sobre él."
        )

    try:
        answer = await ai_analysis.simulate_scenario(contract.extracted_text, data.scenario)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Error al simular el escenario: {e}")

    # Se guarda en el mismo historial de chat, para que quede visible como
    # parte de la conversación con el usuario.
    db.add(models.ChatMessage(contract_id=contract.id, role="user", content=f"[Simulación] {data.scenario}"))
    db.add(models.ChatMessage(contract_id=contract.id, role="assistant", content=answer))
    db.commit()

    return schemas.SimulateResponse(answer=answer)


# ---------------------------------------------------------------------------
# Comparador de contratos (dos versiones)
# ---------------------------------------------------------------------------
@app.post("/api/contracts/compare", response_model=schemas.CompareResponse)
async def compare_two_contracts(
    data: schemas.CompareRequest,
    db: Session = Depends(get_db),
    email: str = Depends(get_current_user_email),
):
    contract_a = _get_owned_contract(db, data.contract_id_a, email)
    contract_b = _get_owned_contract(db, data.contract_id_b, email)

    for c, label in ((contract_a, "A"), (contract_b, "B")):
        if c.status != "analizado":
            raise HTTPException(
                status_code=400,
                detail=f"El contrato {label} todavía no ha sido analizado — analízalo antes de comparar.",
            )

    def _to_summary(c: models.Contract) -> dict:
        return {
            "contract_type": c.contract_type,
            "summary_general": c.summary_general,
            "risk_score": c.risk_score,
            "risk_level": c.risk_level,
            "risk_breakdown": c.risk_breakdown,
            "clauses": [
                {
                    "title": cl.title,
                    "original_text": cl.original_text,
                    "risk_level": cl.risk_level,
                    "category": cl.category,
                }
                for cl in c.clauses
            ],
        }

    try:
        result = await ai_analysis.compare_contracts(_to_summary(contract_a), _to_summary(contract_b))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Error al comparar los contratos: {e}")

    return schemas.CompareResponse(**result)


# ---------------------------------------------------------------------------
# Reporte final en PDF
# ---------------------------------------------------------------------------
@app.get("/api/contracts/{contract_id}/report")
def download_contract_report(
    contract_id: int, db: Session = Depends(get_db), email: str = Depends(get_current_user_email)
):
    contract = _get_owned_contract(db, contract_id, email)
    if contract.status != "analizado":
        raise HTTPException(
            status_code=400, detail="Analiza el contrato antes de generar el reporte."
        )

    try:
        pdf_bytes = report.generate_contract_report(contract)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generando el reporte: {e}")

    safe_name = os.path.splitext(contract.original_filename)[0]
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="LEXIA_reporte_{safe_name}.pdf"'},
    )


# ---------------------------------------------------------------------------
# Utilidades internas
# ---------------------------------------------------------------------------
def _get_owned_contract(db: Session, contract_id: int, email: str) -> models.Contract:
    contract = (
        db.query(models.Contract)
        .filter(models.Contract.id == contract_id, models.Contract.owner_email == email)
        .first()
    )
    if not contract:
        raise HTTPException(status_code=404, detail="Contrato no encontrado.")
    return contract
