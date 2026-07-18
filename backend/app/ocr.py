"""
LEXIA - Extracción de texto (OCR)
===================================
Soporta PDF (con texto embebido o escaneado), imágenes (JPG/PNG) y DOCX.

- PDF con texto real: se extrae directo (rápido, sin OCR)
- PDF escaneado (solo imágenes) o fotos: se usa Tesseract OCR
- DOCX: se lee directo con python-docx
"""

import os
import pytesseract
from PIL import Image
import pdfplumber
from docx import Document as DocxDocument


def extract_text_from_image(image_path: str) -> str:
    """OCR sobre una imagen (foto de un contrato, por ejemplo)."""
    image = Image.open(image_path)
    text = pytesseract.image_to_string(image, lang="spa+eng")
    return text.strip()


def extract_text_from_pdf(pdf_path: str) -> str:
    """
    Intenta extraer texto embebido primero (PDF nativo). Si una página no
    tiene texto (PDF escaneado como imagen), se le aplica OCR a esa página.
    """
    full_text = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            page_text = page.extract_text()
            if page_text and page_text.strip():
                full_text.append(page_text)
            else:
                # Página sin texto embebido: es una imagen escaneada, aplicamos OCR
                pil_image = page.to_image(resolution=300).original
                ocr_text = pytesseract.image_to_string(pil_image, lang="spa+eng")
                full_text.append(ocr_text)
    return "\n\n".join(full_text).strip()


def extract_text_from_docx(docx_path: str) -> str:
    doc = DocxDocument(docx_path)
    paragraphs = [p.text for p in doc.paragraphs if p.text.strip()]
    return "\n".join(paragraphs).strip()


def extract_text(file_path: str) -> str:
    """Punto de entrada único: detecta el tipo de archivo y extrae el texto."""
    ext = os.path.splitext(file_path)[1].lower()

    if ext == ".pdf":
        return extract_text_from_pdf(file_path)
    elif ext in (".jpg", ".jpeg", ".png", ".webp"):
        return extract_text_from_image(file_path)
    elif ext == ".docx":
        return extract_text_from_docx(file_path)
    else:
        raise ValueError(f"Tipo de archivo no soportado: {ext}")
