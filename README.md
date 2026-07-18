# LEXIA — MVP del backend

Este es el **núcleo funcional (MVP)** de LEXIA: sube un contrato, se analiza
con IA, se detectan cláusulas y riesgos, y puedes conversar con la IA sobre
el contrato. Es la base real sobre la que se puede construir todo lo demás
que describe el documento del proyecto (app Flutter, comparador de
contratos, modo voz, multi-idioma, etc.) — no un producto terminado.

## Qué SÍ incluye este MVP

- Registro/login de usuarios (JWT)
- Subida de contratos: PDF (nativo o escaneado), DOCX, imágenes (JPG/PNG)
- OCR automático cuando el documento es una imagen o PDF escaneado
- Análisis con IA (Claude): detecta cláusulas, clasifica riesgo por
  categoría (financiero, legal, laboral, tributario, privacidad,
  permanencia), genera resumen general y ejecutivo, y una puntuación de
  riesgo global (0-100)
- Chat conversacional sobre el contrato analizado, con historial
- **Simulador de escenarios futuros** ("¿qué pasa si...?"), guardado en el
  mismo historial de chat
- **Comparador de contratos**: compara dos versiones ya analizadas y
  detecta cláusulas nuevas/eliminadas, cambios en obligaciones y riesgos
- **Reporte final en PDF** descargable, con resumen, riesgos y cláusulas
- Separación de datos por usuario (cada quien ve solo sus propios contratos)

## Qué NO incluye todavía (ver "Próximos pasos")

- La app móvil en Flutter YA incluye todo lo anterior (ver `mobile/README.md`)
- Explicación por voz (texto a voz / voz a texto)
- Multi-idioma
- Firebase Authentication (se usó JWT como base más simple para el MVP;
  migrar a Firebase Auth es un paso posterior — el almacenamiento de
  archivos ya usa Supabase Storage como pediste, no Firebase Storage)
- Modo oscuro/claro con selector visible (el tema ya está centralizado,
  falta el botón para alternar)
- Escaneo avanzado con detección de bordes/corrección de perspectiva
  automática (por ahora usa la cámara nativa simple)

## Arquitectura de producción

```
Flutter App  →  API FastAPI en Render  →  Supabase (Postgres + Storage)  →  IA (Claude)
```

No depende de ningún servidor físico ni de una PC encendida — todo corre
en la nube 24/7 con planes gratuitos para empezar.

## Despliegue paso a paso

### 1. Crear el proyecto en Supabase

1. Ve a [supabase.com](https://supabase.com) → crea un proyecto nuevo (plan gratuito)
2. En **Project Settings → Database**, copia la cadena de conexión (modo
   "Session") → la vas a necesitar como `DATABASE_URL`
3. En **Project Settings → API**, copia:
   - **Project URL** → `SUPABASE_URL`
   - **service_role key** (no la `anon`) → `SUPABASE_SERVICE_KEY`
4. Ve a **Storage** → crea un bucket llamado `contracts` (privado, no público)

### 2. Subir el código a GitHub

Render despliega directamente desde un repositorio de GitHub:

```bash
cd lexia/backend
git init
git add .
git commit -m "LEXIA backend inicial"
```

Crea un repositorio nuevo en GitHub y súbelo (`git remote add origin ...`, `git push`).

### 3. Crear el servicio en Render

1. Ve a [render.com](https://render.com) → **New → Web Service**
2. Conecta tu repositorio de GitHub
3. Render detectará el `render.yaml` automáticamente (Blueprint) — si no,
   elige manualmente: **Environment: Docker**, deja el `Dockerfile` que ya
   está en `backend/`
4. En la sección de variables de entorno, pega los valores reales que
   sacaste de Supabase (`DATABASE_URL`, `SUPABASE_URL`,
   `SUPABASE_SERVICE_KEY`) y tu clave de **Anthropic** (`ANTHROPIC_API_KEY`)
5. Plan: **Free**
6. Clic en **Create Web Service**

Render te da una URL pública automática, tipo:
```
https://lexia-api.onrender.com
```
Esa es la URL que la app Flutter va a usar para hablar con el backend.

### 4. Verificar que quedó funcionando

Abre en el navegador:
```
https://lexia-api.onrender.com/docs
```
Debe cargar la documentación interactiva de la API. Prueba el flujo:
`POST /api/auth/signup` → `POST /api/contracts/upload` → `POST /api/contracts/{id}/analyze`

**Nota sobre el plan gratuito de Render**: los servicios gratuitos se
"duermen" tras 15 minutos sin tráfico y tardan unos segundos en despertar
con la primera petición — es normal, no es un error. Para producción real
sin ese retraso, se necesita un plan de pago.

## Desarrollo local (opcional, para probar antes de desplegar)

Si quieres correrlo en tu propia máquina antes de subirlo a Render:

### Requisito: Tesseract OCR instalado en el sistema

```bash
# Linux (Debian/Ubuntu/Kali)
sudo apt install -y tesseract-ocr tesseract-ocr-spa

# Mac
brew install tesseract tesseract-lang
```

### Instalar y correr

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edita .env con tus valores reales de Supabase y Anthropic
uvicorn app.main:app --reload
```


## Flujo de prueba rápido (usando /docs)

1. `POST /api/auth/signup` — crea tu usuario, copia el `access_token`
2. En la esquina superior derecha de `/docs`, clic en "Authorize" y pega el
   token
3. `POST /api/contracts/upload` — sube un PDF o imagen de un contrato
4. `POST /api/contracts/{id}/analyze` — dispara el análisis con IA
5. `GET /api/contracts/{id}` — ve el resultado completo (cláusulas, riesgos, resumen)
6. `POST /api/contracts/{id}/chat` — pregunta algo sobre el contrato

## Próximos pasos recomendados (en orden de impacto)

1. **Texto a voz / voz a texto** — se integra en el lado de Flutter (con
   `flutter_tts` y `speech_to_text`), no requiere cambios grandes en este
   backend
2. **Multi-idioma** — agregar el idioma como parámetro en el prompt de
   análisis y de chat
3. **Migrar a Firebase Authentication** para producción real, como indica
   el documento original del proyecto (el resto de la arquitectura —
   Render + Supabase — ya queda igual)
4. **Verificación de correo electrónico** al registrarse
5. **Guardar el reporte PDF en Supabase Storage** además de generarlo al
   vuelo, para tener un historial descargable sin tener que regenerarlo
   cada vez

## Nota legal importante

Cada respuesta de LEXIA debe dejar claro que es una **herramienta de
apoyo y no sustituye el asesoramiento de un abogado**. Esto ya está
integrado en los prompts del sistema (`ai_analysis.py`) y en el endpoint
`/api/disclaimer`, pero la app Flutter debe mostrarlo de forma visible al
usuario, no solo en el backend.
