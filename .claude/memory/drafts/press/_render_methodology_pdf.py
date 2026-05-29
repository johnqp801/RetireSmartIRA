#!/usr/bin/env python3
"""Render the Tax Data Methodology Brief markdown to a polished PDF."""

import re
import sys
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, KeepTogether, PageBreak, ListFlowable, ListItem
)


SRC = Path("/Users/johnurban/Projects/RetireSmartIRA/.worktrees/1.8.5-state-tax-refresh/.claude/memory/drafts/press/tax-data-methodology.md")
OUT = Path("/Users/johnurban/Projects/RetireSmartIRA/.worktrees/1.8.5-state-tax-refresh/.claude/memory/drafts/press/tax-data-methodology.pdf")


# ----------------- Styles -----------------

styles = getSampleStyleSheet()

title_style = ParagraphStyle(
    "TitleCustom",
    parent=styles["Title"],
    fontSize=22,
    leading=26,
    spaceAfter=8,
    textColor=colors.HexColor("#1a1a1a"),
    alignment=TA_LEFT,
    fontName="Helvetica-Bold",
)

meta_style = ParagraphStyle(
    "Meta",
    parent=styles["Normal"],
    fontSize=10,
    leading=14,
    textColor=colors.HexColor("#444444"),
    fontName="Helvetica",
)

h1_style = ParagraphStyle(
    "H1",
    parent=styles["Heading1"],
    fontSize=16,
    leading=20,
    spaceBefore=18,
    spaceAfter=8,
    textColor=colors.HexColor("#0a4f7a"),
    fontName="Helvetica-Bold",
)

h2_style = ParagraphStyle(
    "H2",
    parent=styles["Heading2"],
    fontSize=13,
    leading=17,
    spaceBefore=14,
    spaceAfter=6,
    textColor=colors.HexColor("#0a4f7a"),
    fontName="Helvetica-Bold",
)

h3_style = ParagraphStyle(
    "H3",
    parent=styles["Heading3"],
    fontSize=11,
    leading=14,
    spaceBefore=10,
    spaceAfter=4,
    textColor=colors.HexColor("#333333"),
    fontName="Helvetica-Bold",
)

body_style = ParagraphStyle(
    "Body",
    parent=styles["Normal"],
    fontSize=10,
    leading=14,
    spaceAfter=8,
    textColor=colors.HexColor("#1a1a1a"),
    fontName="Helvetica",
    alignment=TA_LEFT,
)

bullet_style = ParagraphStyle(
    "Bullet",
    parent=body_style,
    leftIndent=18,
    bulletIndent=4,
    spaceAfter=4,
)

quote_style = ParagraphStyle(
    "Quote",
    parent=body_style,
    leftIndent=18,
    rightIndent=18,
    fontName="Helvetica-Oblique",
    textColor=colors.HexColor("#444444"),
    borderColor=colors.HexColor("#cccccc"),
    borderWidth=0,
    borderPadding=6,
    spaceAfter=6,
)

quote_source_style = ParagraphStyle(
    "QuoteSource",
    parent=body_style,
    leftIndent=18,
    fontSize=9,
    textColor=colors.HexColor("#666666"),
    fontName="Helvetica-Oblique",
    spaceAfter=10,
)

footer_style = ParagraphStyle(
    "Footer",
    parent=body_style,
    fontSize=9,
    textColor=colors.HexColor("#666666"),
    fontName="Helvetica-Oblique",
    alignment=TA_CENTER,
)


# ----------------- Inline markdown → reportlab markup -----------------

def inline_md(text: str) -> str:
    """Convert markdown inline formatting to reportlab paraparser markup."""
    # Escape <, >, & first (before adding our own tags)
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    # Bold **text**
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    # Italic *text* (single asterisk)  — must not collide with bold
    text = re.sub(r"(?<!\*)\*([^*\n]+)\*(?!\*)", r"<i>\1</i>", text)
    # Inline code `text`
    text = re.sub(r"`([^`]+)`", r'<font face="Courier" color="#444444">\1</font>', text)
    # Links [text](url) — render as text in blue with underline
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<link href="\2"><font color="#0066cc">\1</font></link>', text)
    return text


# ----------------- Parse markdown into Platypus flowables -----------------

def parse_markdown_to_flowables(md_text: str):
    flowables = []
    lines = md_text.split("\n")
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]
        stripped = line.strip()

        # Skip blank lines (handled by spaceAfter on styles)
        if not stripped:
            i += 1
            continue

        # Horizontal rule
        if stripped == "---":
            flowables.append(Spacer(1, 6))
            flowables.append(HRFlowable(
                width="100%",
                thickness=0.5,
                color=colors.HexColor("#cccccc"),
                spaceBefore=2,
                spaceAfter=8,
            ))
            i += 1
            continue

        # Headings
        if stripped.startswith("# "):
            flowables.append(Paragraph(inline_md(stripped[2:]), title_style))
            i += 1
            continue
        if stripped.startswith("## "):
            flowables.append(Paragraph(inline_md(stripped[3:]), h1_style))
            i += 1
            continue
        if stripped.startswith("### "):
            flowables.append(Paragraph(inline_md(stripped[4:]), h2_style))
            i += 1
            continue
        if stripped.startswith("#### "):
            flowables.append(Paragraph(inline_md(stripped[5:]), h3_style))
            i += 1
            continue

        # Tables (markdown pipe tables)
        if stripped.startswith("|") and i + 1 < n and re.match(r"^\|[\s\-:|]+\|$", lines[i+1].strip()):
            table_rows = []
            while i < n and lines[i].strip().startswith("|"):
                row_line = lines[i].strip()
                # Skip the separator row
                if re.match(r"^\|[\s\-:|]+\|$", row_line):
                    i += 1
                    continue
                cells = [c.strip() for c in row_line.strip("|").split("|")]
                table_rows.append(cells)
                i += 1
            # Render table
            if table_rows:
                # Convert cells to Paragraphs for wrapping
                pdf_rows = []
                for row_idx, row in enumerate(table_rows):
                    pdf_row = []
                    for cell in row:
                        style = ParagraphStyle(
                            f"Cell{row_idx}",
                            parent=body_style,
                            fontSize=9,
                            leading=12,
                            spaceAfter=0,
                            fontName="Helvetica-Bold" if row_idx == 0 else "Helvetica",
                            textColor=colors.white if row_idx == 0 else colors.HexColor("#1a1a1a"),
                        )
                        pdf_row.append(Paragraph(inline_md(cell), style))
                    pdf_rows.append(pdf_row)

                # Compute column widths — narrow for numeric/count column if 3 cols
                ncols = len(pdf_rows[0])
                avail = 6.5 * inch
                if ncols == 3:
                    col_widths = [avail * 0.45, avail * 0.10, avail * 0.45]
                elif ncols == 2:
                    col_widths = [avail * 0.4, avail * 0.6]
                else:
                    col_widths = [avail / ncols] * ncols

                tbl = Table(pdf_rows, colWidths=col_widths, repeatRows=1)
                tbl.setStyle(TableStyle([
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0a4f7a")),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("ALIGN", (0, 0), (-1, -1), "LEFT"),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                    ("TOPPADDING", (0, 0), (-1, -1), 6),
                    ("LEFTPADDING", (0, 0), (-1, -1), 6),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                    ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#cccccc")),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f7f9fc")]),
                ]))
                flowables.append(Spacer(1, 4))
                flowables.append(tbl)
                flowables.append(Spacer(1, 8))
            continue

        # Blockquote
        if stripped.startswith(">"):
            quote_lines = []
            while i < n and lines[i].strip().startswith(">"):
                quote_lines.append(lines[i].strip()[1:].strip())
                i += 1
            quote_text = " ".join(quote_lines).strip()
            # Italic source attribution on its own line (starts with *Source:)
            # Split by interior blank "> " separators
            # For simplicity render as one block
            flowables.append(Paragraph(inline_md(quote_text), quote_style))
            continue

        # Bullet list
        if stripped.startswith("- ") or stripped.startswith("* "):
            items = []
            while i < n:
                ln = lines[i]
                ls = ln.strip()
                if not (ls.startswith("- ") or ls.startswith("* ")):
                    # Check for continuation (indented line under a bullet)
                    if items and ln.startswith("  ") and ls:
                        # append to last bullet
                        items[-1] = items[-1] + " " + ls
                        i += 1
                        continue
                    break
                items.append(ls[2:])
                i += 1
            list_items = [
                ListItem(Paragraph(inline_md(it), body_style), leftIndent=14, value="•")
                for it in items
            ]
            flowables.append(ListFlowable(
                list_items,
                bulletType="bullet",
                start="•",
                bulletColor=colors.HexColor("#0a4f7a"),
                leftIndent=14,
                bulletFontSize=10,
                spaceAfter=8,
            ))
            continue

        # Numbered list
        if re.match(r"^\d+\.\s", stripped):
            items = []
            while i < n:
                ln = lines[i]
                ls = ln.strip()
                m = re.match(r"^\d+\.\s+(.*)", ls)
                if not m:
                    if items and ln.startswith("   ") and ls:
                        items[-1] = items[-1] + " " + ls
                        i += 1
                        continue
                    break
                items.append(m.group(1))
                i += 1
            list_items = [
                ListItem(Paragraph(inline_md(it), body_style), leftIndent=18)
                for it in items
            ]
            flowables.append(ListFlowable(
                list_items,
                bulletType="1",
                bulletFontName="Helvetica-Bold",
                leftIndent=18,
                bulletFontSize=10,
                spaceAfter=8,
            ))
            continue

        # Paragraph (collect consecutive non-blank, non-special lines)
        para_lines = []
        while i < n:
            ln = lines[i]
            ls = ln.strip()
            if not ls:
                break
            if (ls.startswith("#") or ls.startswith(">") or ls.startswith("|")
                or ls.startswith("- ") or ls.startswith("* ")
                or re.match(r"^\d+\.\s", ls) or ls == "---"):
                break
            para_lines.append(ls)
            i += 1

        # Metadata-style paragraphs (lines starting with **Word:**) — render as compact lines
        if para_lines and all(re.match(r"^\*\*[^*]+:\*\*", pl) for pl in para_lines):
            for pl in para_lines:
                flowables.append(Paragraph(inline_md(pl), meta_style))
            flowables.append(Spacer(1, 6))
            continue

        paragraph_text = " ".join(para_lines)
        flowables.append(Paragraph(inline_md(paragraph_text), body_style))

    return flowables


# ----------------- Page header/footer -----------------

def add_page_decoration(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#888888"))
    # Footer: page number, document title
    canvas.drawString(0.75 * inch, 0.5 * inch, "RetireSmartIRA — Tax Data Methodology")
    canvas.drawRightString(letter[0] - 0.75 * inch, 0.5 * inch, f"Page {doc.page}")
    canvas.drawString(0.75 * inch, letter[1] - 0.5 * inch,
                      "RetireSmartIRA — Alamo Ventures Group LLC")
    canvas.drawRightString(letter[0] - 0.75 * inch, letter[1] - 0.5 * inch,
                           "Current release: v1.8.5 · May 27, 2026")
    # Thin line under header
    canvas.setStrokeColor(colors.HexColor("#cccccc"))
    canvas.setLineWidth(0.25)
    canvas.line(0.75 * inch, letter[1] - 0.55 * inch,
                letter[0] - 0.75 * inch, letter[1] - 0.55 * inch)
    canvas.restoreState()


def main():
    md_text = SRC.read_text(encoding="utf-8")
    flowables = parse_markdown_to_flowables(md_text)

    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=letter,
        leftMargin=0.75 * inch,
        rightMargin=0.75 * inch,
        topMargin=0.75 * inch,
        bottomMargin=0.75 * inch,
        title="RetireSmartIRA Tax Data Methodology",
        author="John Urban, Alamo Ventures Group LLC",
        subject="Tax data methodology for RetireSmartIRA — current release v1.8.5",
    )
    doc.build(flowables, onFirstPage=add_page_decoration, onLaterPages=add_page_decoration)
    print(f"Wrote {OUT}")
    print(f"Size: {OUT.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
