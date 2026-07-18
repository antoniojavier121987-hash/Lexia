# LEXIA — App móvil (Flutter)

App móvil que consume el backend de LEXIA desplegado en Render. Cubre el
flujo principal: iniciar sesión, subir/escanear un contrato, ver el
análisis (resumen, riesgo general, cláusulas con semáforo de colores), y
conversar con la IA sobre el contrato.

## Qué incluye este MVP de la app

- Login y registro
- Subir contrato: cámara, galería, o archivo PDF/Word
- Pantalla de análisis: puntuación de riesgo general, resumen ejecutivo y
  general, riesgo por categoría, cláusulas expandibles con semáforo
  (verde/amarillo/rojo)
- Chat conversacional sobre el contrato, con preguntas sugeridas
- **Simulador de escenarios futuros**, con preguntas rápidas predefinidas
  ("¿qué pasa si pierdo mi trabajo?", etc.) y campo libre
- **Comparador de contratos**: elige otro contrato ya analizado y ve las
  diferencias (cláusulas nuevas/eliminadas, riesgos que subieron/bajaron)
- **Reporte en PDF**: se genera y se abre directo en el visor nativo del
  celular (o se puede compartir/guardar desde ahí)
- Historial de contratos analizados

## Qué falta (próximos pasos, ver también el README del backend)

- Escaneo real con detección de bordes/corrección de perspectiva (por ahora
  usa la cámara nativa simple; para el escaneo avanzado que describe el
  documento del proyecto, se integraría un paquete como `cunning_document_scanner`)
- Texto a voz / voz a texto
- Selector de modo de explicación (niño/adolescente/adulto/profesional)
- Selector de idioma
- Modo oscuro (el tema ya está centralizado en `main.dart`, falta el toggle)

## Instalación

### 1. Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado
- Un emulador Android/iOS, o un dispositivo físico conectado

### 2. Configurar la URL del backend

Edita `lib/config.dart` y coloca la URL real de tu backend en Render:

```dart
static const String apiBaseUrl = 'https://lexia-api.onrender.com';
```

### 3. Instalar dependencias y correr

```bash
cd mobile
flutter pub get
flutter run
```

Nota: como este código se escribió sin poder compilarlo en el entorno
donde se generó, es posible que al correr `flutter pub get` alguna versión
de paquete necesite un ajuste menor — si eso pasa, `flutter pub upgrade`
suele resolverlo.

## Estructura del proyecto

```
lib/
  main.dart                 - Punto de entrada, tema, decide login vs historial
  config.dart               - URL del backend
  models/                   - Contract, Clause, ChatMessage
  services/
    api_service.dart         - Todas las llamadas HTTP al backend
    auth_storage.dart        - Guarda el token de sesión de forma segura
  screens/
    login_screen.dart
    signup_screen.dart
    home_screen.dart         - Historial de contratos
    upload_screen.dart       - Subir/escanear contrato
    contract_detail_screen.dart - Resumen, riesgo, cláusulas
    chat_screen.dart         - Conversación con la IA
  widgets/
    risk_badge.dart          - Semáforo de riesgo (verde/amarillo/rojo)
    clause_card.dart         - Tarjeta expandible de cada cláusula
```
