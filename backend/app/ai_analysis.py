"""
LEXIA - Análisis de contratos con IA
======================================
Usa Claude (Anthropic) para leer el contrato completo y devolver un
análisis estructurado: cláusulas, nivel de riesgo por cláusula, resumen
general/ejecutivo, y una puntuación de riesgo global.

IMPORTANTE: Este análisis es una herramienta de apoyo para entender el
contrato — NO sustituye la asesoría de un abogado. Esto debe quedar
siempre visible para el usuario final en la app (ver disclaimer en las
respuestas de la API).
"""

import json
import httpx

from .config import ANTHROPIC_API_KEY, ANTHROPIC_MODEL

ANALYSIS_SYSTEM_PROMPT = """Eres el motor de análisis legal de LEXIA, una aplicación que ayuda a
personas comunes (sin formación legal) a entender contratos antes de firmarlos.

Tu tarea: leer el contrato completo que te da el usuario y devolver ÚNICAMENTE un objeto JSON
válido (sin texto antes ni después, sin marcadores de código markdown) con esta estructura exacta:

{
  "contract_type": "tipo de contrato detectado, ej: 'Contrato de arrendamiento'",
  "summary_general": "resumen general de 3-5 líneas: qué es, duración, valor económico, obligaciones y derechos principales",
  "summary_executive": "resumen ejecutivo de máximo 2 líneas, explicado en menos de un minuto de lectura",
  "risk_score": 0-100 (número, más alto = más riesgoso para quien firma),
  "risk_level": "BAJO" | "MEDIO" | "ALTO",
  "risk_breakdown": {
    "financiero": "BAJO" | "MEDIO" | "ALTO",
    "legal": "BAJO" | "MEDIO" | "ALTO",
    "laboral": "BAJO" | "MEDIO" | "ALTO",
    "tributario": "BAJO" | "MEDIO" | "ALTO",
    "privacidad": "BAJO" | "MEDIO" | "ALTO",
    "permanencia": "BAJO" | "MEDIO" | "ALTO"
  },
  "clauses": [
    {
      "order_index": 1,
      "title": "título corto de la cláusula",
      "original_text": "el texto original relevante de la cláusula (puede ser un extracto)",
      "plain_explanation": "explicación en lenguaje sencillo, como si se lo explicaras a alguien sin conocimientos legales",
      "risk_level": "BAJO" | "MEDIO" | "ALTO",
      "risk_reason": "por qué tiene ese nivel de riesgo, en una oración",
      "category": "una categoría breve, ej: 'penalizacion', 'renovacion_automatica', 'costos_ocultos', 'renuncia_derechos', 'exclusion', 'responsabilidad_excesiva', 'plazo_importante', 'riesgo_financiero', 'riesgo_privacidad', 'clausula_ambigua', 'pago_recurrente', 'incremento_automatico', 'garantia', 'otro'"
    }
  ],
  "key_findings": ["lista de 3-6 hallazgos importantes en frases cortas, para el resumen final hablado"],
  "recommendation": "una recomendación breve y prudente para el usuario"
}

Reglas importantes:
- Identifica específicamente: cláusulas abusivas, penalizaciones, renovación automática, costos ocultos,
  renuncias de derechos, exclusiones, responsabilidades excesivas, plazos importantes, riesgos financieros/legales/
  laborales/fiscales/de privacidad, cláusulas ambiguas o contradictorias, pagos recurrentes, incrementos automáticos,
  intereses, multas, garantías, y derechos del consumidor afectados.
- Usa lenguaje sencillo en las explicaciones, evita jerga legal innecesaria.
- Sé preciso y prudente: no inventes cláusulas que no estén en el texto.
- Si el documento no parece ser un contrato, indícalo en "contract_type" y deja las demás secciones lo más vacías/neutras posible.
- Responde SOLO con el JSON, nada más.
"""

CHAT_SYSTEM_PROMPT = """Eres el asistente conversacional de LEXIA. El usuario ya tiene un contrato
analizado y te va a hacer preguntas sobre él (ej. "¿qué significa esta cláusula?", "explícamela
como si tuviera quince años", "¿qué pasa si dejo de pagar?").

Reglas:
- Responde ÚNICAMENTE basándote en el texto del contrato que se te da como contexto y en
  principios jurídicos generales de sentido común.
- Si la pregunta requiere asesoría legal específica para la situación del usuario (no algo que
  se pueda responder solo con el texto del contrato y principios generales), dilo claramente y
  recomienda consultar a un abogado.
- Usa lenguaje sencillo, cálido y directo. Nunca supongas que el usuario tiene conocimientos legales.
- Nunca sustituyes el asesoramiento de un abogado — puedes recordarlo brevemente cuando sea relevante,
  sin repetirlo de forma robótica en cada respuesta.
"""


async def _call_claude(system_prompt: str, user_content: str, max_tokens: int = 4096) -> str:
    if not ANTHROPIC_API_KEY:
        raise RuntimeError(
            "Falta ANTHROPIC_API_KEY en .env — necesaria para que LEXIA pueda analizar contratos."
        )

    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": ANTHROPIC_API_KEY,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": ANTHROPIC_MODEL,
                "max_tokens": max_tokens,
                "system": system_prompt,
                "messages": [{"role": "user", "content": user_content}],
            },
        )
        resp.raise_for_status()
        data = resp.json()
        return "".join(block.get("text", "") for block in data.get("content", []))


async def analyze_contract(contract_text: str) -> dict:
    """Analiza el contrato completo y devuelve el JSON estructurado."""
    raw = await _call_claude(ANALYSIS_SYSTEM_PROMPT, contract_text, max_tokens=8000)

    # El modelo puede a veces envolver el JSON en ```json ... ``` pese a la instrucción;
    # esto lo limpia por seguridad antes de parsear.
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.strip("`")
        if cleaned.lower().startswith("json"):
            cleaned = cleaned[4:]
    cleaned = cleaned.strip()

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"La IA no devolvió un JSON válido: {e}\nRespuesta cruda: {raw[:500]}")


SIMULATE_SYSTEM_PROMPT = """Eres el simulador de consecuencias futuras de LEXIA. El usuario te va a plantear
un escenario hipotético sobre su contrato (ej. "¿qué pasa si pierdo mi trabajo?", "¿qué pasa si dejo
de pagar?", "¿qué pasa si fallezco?").

Reglas:
- Responde ÚNICAMENTE con base en el texto del contrato que se te da como contexto y en principios
  jurídicos generales de sentido común — nunca inventes cláusulas que no existan en el documento.
- Sé claro y directo sobre las consecuencias concretas que se derivan del contrato en ese escenario
  (penalizaciones, plazos, obligaciones que seguirían vigentes, etc.).
- Si el contrato no dice nada sobre ese escenario específico, dilo claramente en vez de inventar una respuesta.
- Indica explícitamente cuando la situación descrita depende de la legislación aplicable o de
  circunstancias que requieren asesoría legal profesional para una respuesta definitiva.
- Usa lenguaje sencillo y directo, sin jerga legal innecesaria.
"""


async def simulate_scenario(contract_text: str, scenario_question: str) -> str:
    """Responde un escenario hipotético tipo '¿qué pasa si...?' usando el contrato como base."""
    context = (
        f"=== TEXTO DEL CONTRATO ===\n{contract_text}\n=== FIN DEL CONTRATO ===\n\n"
        f"Escenario planteado por el usuario: {scenario_question}"
    )
    return await _call_claude(SIMULATE_SYSTEM_PROMPT, context, max_tokens=1200)


COMPARE_SYSTEM_PROMPT = """Eres el comparador de contratos de LEXIA. Se te dan dos contratos ya
analizados (versión A y versión B) y debes identificar las diferencias relevantes entre ellos.

Devuelve ÚNICAMENTE un objeto JSON válido (sin texto antes ni después, sin marcadores de markdown)
con esta estructura exacta:

{
  "summary": "resumen breve de 2-4 líneas sobre qué cambió en general entre las dos versiones",
  "new_clauses": ["lista de cláusulas nuevas que aparecen en B pero no en A, en frases cortas"],
  "removed_clauses": ["lista de cláusulas que estaban en A pero ya no están en B"],
  "obligations_increased": ["obligaciones que aumentaron de A a B"],
  "risks_increased": ["riesgos que aumentaron de A a B"],
  "risks_decreased": ["riesgos que disminuyeron de A a B"],
  "risk_score_change": "descripción breve del cambio en la puntuación de riesgo general, ej: 'subió de 45 a 68'"
}

Sé preciso: no inventes diferencias que no estén respaldadas por el texto de ambos contratos.
Responde SOLO con el JSON, nada más.
"""


async def compare_contracts(contract_a_summary: dict, contract_b_summary: dict) -> dict:
    """
    Compara dos contratos ya analizados (recibe sus resúmenes estructurados,
    no el texto crudo completo, para mantener el análisis enfocado).
    """
    payload = (
        f"=== CONTRATO A ===\n{json.dumps(contract_a_summary, ensure_ascii=False, indent=2)}\n\n"
        f"=== CONTRATO B ===\n{json.dumps(contract_b_summary, ensure_ascii=False, indent=2)}"
    )
    raw = await _call_claude(COMPARE_SYSTEM_PROMPT, payload, max_tokens=3000)

    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.strip("`")
        if cleaned.lower().startswith("json"):
            cleaned = cleaned[4:]
    cleaned = cleaned.strip()

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"La IA no devolvió un JSON válido: {e}\nRespuesta cruda: {raw[:500]}")
    """
    Responde una pregunta del usuario sobre el contrato, usando el texto del
    contrato como contexto y el historial de la conversación previa.
    """
    context = f"=== TEXTO DEL CONTRATO ===\n{contract_text}\n=== FIN DEL CONTRATO ===\n\n"

    conversation = context
    for msg in history[-10:]:  # últimos 10 mensajes para no exceder contexto innecesariamente
        role = "Usuario" if msg["role"] == "user" else "LEXIA"
        conversation += f"{role}: {msg['content']}\n"
    conversation += f"Usuario: {question}\nLEXIA:"

    return await _call_claude(CHAT_SYSTEM_PROMPT, conversation, max_tokens=1500)
