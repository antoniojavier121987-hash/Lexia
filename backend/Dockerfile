# LEXIA backend - Dockerfile para Render
# Render no permite instalar paquetes del sistema (como Tesseract OCR) en su
# entorno nativo de Python, así que usamos un contenedor Docker que sí puede.

FROM python:3.11-slim

# Tesseract OCR (con idioma español) + dependencias necesarias para pdfplumber/Pillow
RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-spa \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Render inyecta el puerto real en la variable $PORT
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
