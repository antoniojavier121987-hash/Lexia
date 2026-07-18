"""
LEXIA - Generación de reportes en PDF
========================================
Genera el reporte final del análisis de un contrato: resumen, riesgos,
cláusulas importantes, explicaciones, recomendaciones y puntuación.
"""

import io
from datetime import datetime

from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
)

GREEN = colors.HexColor("#2E8B57")
RED = colors.HexColor("#C62828")
AMBER = colors.HexColor("#F9A825")
GRAY = colors.HexColor("#757575")

RISK_HEX = {"ALTO": "#C62828", "MEDIO": "#F9A825", "BAJO": "#2E8B57"}


def _risk_hex(level: str | None) -> str:
    if not level:
        return "#757575"
    return RISK_HEX.get(level.upper(), "#757575")


def generate_contract_report(contract) -> bytes:
    """
    Recibe un objeto Contract (con sus clauses cargadas) y devuelve los
    bytes del PDF generado, listos para enviar como respuesta HTTP o subir
    a Supabase Storage.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer, pagesize=letter,
        topMargin=2 * cm, bottomMargin=2 * cm, leftMargin=2 * cm, rightMargin=2 * cm,
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "LexiaTitle", parent=styles["Title"], textColor=GREEN, fontSize=22, spaceAfter=4
    )
    h2_style = ParagraphStyle(
        "LexiaH2", parent=styles["Heading2"], textColor=GREEN, spaceBefore=14, spaceAfter=6
    )
    body_style = ParagraphStyle("LexiaBody", parent=styles["BodyText"], spaceAfter=8, leading=15)
    small_style = ParagraphStyle("LexiaSmall", parent=styles["BodyText"], fontSize=9, textColor=GRAY)

    story = []

    # --- Portada / encabezado ---
    story.append(Paragraph("LEXIA — Reporte de Análisis de Contrato", title_style))
    story.append(Paragraph(f"Documento: {contract.original_filename}", small_style))
    story.append(Paragraph(f"Fecha del reporte: {datetime.utcnow().strftime('%d/%m/%Y')}", small_style))
    story.append(Spacer(1, 16))

    # --- Puntuación de riesgo general ---
    risk_hex = _risk_hex(contract.risk_level)
    score_table = Table(
        [[
            Paragraph(f"<b>Riesgo General</b>", body_style),
            Paragraph(
                f'<font color="{risk_hex}"><b>{int(contract.risk_score or 0)} / 100 — '
                f'{contract.risk_level or "SIN EVALUAR"}</b></font>', body_style
            ),
        ]],
        colWidths=[8 * cm, 8 * cm],
    )
    score_table.setStyle(TableStyle([
        ("BOX", (0, 0), (-1, -1), 1, colors.HexColor("#E0E0E0")),
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F5F5F5")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    story.append(score_table)
    story.append(Spacer(1, 12))

    if contract.contract_type:
        story.append(Paragraph(f"<b>Tipo de contrato:</b> {contract.contract_type}", body_style))

    # --- Resúmenes ---
    if contract.summary_executive:
        story.append(Paragraph("Resumen ejecutivo", h2_style))
        story.append(Paragraph(contract.summary_executive, body_style))

    if contract.summary_general:
        story.append(Paragraph("Resumen general", h2_style))
        story.append(Paragraph(contract.summary_general, body_style))

    # --- Riesgo por categoría ---
    if contract.risk_breakdown:
        story.append(Paragraph("Riesgo por categoría", h2_style))
        rows = [["Categoría", "Nivel"]]
        for category, level in contract.risk_breakdown.items():
            rows.append([category.capitalize(), level])
        cat_table = Table(rows, colWidths=[8 * cm, 8 * cm])
        cat_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), GREEN),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E0E0E0")),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#FAFAFA")]),
            ("LEFTPADDING", (0, 0), (-1, -1), 8),
            ("TOPPADDING", (0, 0), (-1, -1), 6),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ]))
        story.append(cat_table)

    # --- Cláusulas ---
    if contract.clauses:
        story.append(PageBreak())
        story.append(Paragraph("Cláusulas detectadas", h2_style))
        for clause in sorted(contract.clauses, key=lambda c: c.order_index):
            c_hex = _risk_hex(clause.risk_level)
            story.append(Paragraph(
                f'<font color="{c_hex}">●</font> <b>{clause.title or f"Cláusula {clause.order_index}"}</b> '
                f'<font color="{c_hex}">[{clause.risk_level or "N/D"}]</font>',
                body_style,
            ))
            if clause.plain_explanation:
                story.append(Paragraph(f"<i>{clause.plain_explanation}</i>", body_style))
            if clause.risk_reason:
                story.append(Paragraph(f"<b>Motivo del riesgo:</b> {clause.risk_reason}", small_style))
            story.append(Spacer(1, 8))

    # --- Aviso legal ---
    story.append(Spacer(1, 20))
    story.append(Paragraph(
        "LEXIA es una herramienta de apoyo para comprender contratos y no sustituye el "
        "asesoramiento de un abogado. Para decisiones legales importantes, consulta siempre "
        "con un profesional del derecho.",
        small_style,
    ))

    doc.build(story)
    return buffer.getvalue()
