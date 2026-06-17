#!/usr/bin/env python3
"""Generate Sections 3.3 and 3.4 PDF with academic wording and a pipeline figure."""

import sys
from io import BytesIO
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_ROOT / ".pdf_tools"))

from fpdf import FPDF  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402


def _truetype(size: int):
    candidates = (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/Library/Fonts/Arial.ttf",
    )
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def render_pipeline_figure_png() -> Image.Image:
    """Two-row pipeline for legibility when the report is printed 2-up (two pages per sheet)."""
    w, h = 3200, 920
    img = Image.new("RGB", (w, h), (252, 253, 255))
    draw = ImageDraw.Draw(img)
    font_title = _truetype(30)
    font_small = _truetype(22)
    font_note = _truetype(20)

    stages = [
        (
            "(1) Session routing",
            "Home hub; glyph or\npoem selection",
        ),
        (
            "(2) Multimodal instruction",
            "Template + TTS\n(flutter_tts)",
        ),
        (
            "(3) Digital ink capture",
            "Strokes on canvas;\nzoom / HC",
        ),
        (
            "(4) On-device recognition",
            "ML Kit Digital Ink;\nscore + advance",
        ),
        (
            "(5) Feedback and storage",
            "UI + speech;\npreferences + logs",
        ),
    ]

    margin_x = 72
    gap = 44
    box_w = (w - 2 * margin_x - 2 * gap) // 3
    box_h = 280
    y_top = 56
    row_gap = 88

    def text_block_center(x: int, y: int, bw: int, bh: int, lines: list[str], ft) -> None:
        total_h = sum(
            draw.textbbox((0, 0), line, font=ft)[3] - draw.textbbox((0, 0), line, font=ft)[1] + 4
            for line in lines
        )
        cy = y + (bh - total_h) // 2
        for line in lines:
            bbox = draw.textbbox((0, 0), line, font=ft)
            tw = bbox[2] - bbox[0]
            draw.text((x + (bw - tw) // 2, cy), line, fill=(255, 255, 255), font=ft)
            cy += bbox[3] - bbox[1] + 4

    def draw_box(x0: int, y0: int, title: str, subtitle: str) -> None:
        draw.rounded_rectangle(
            [x0, y0, x0 + box_w, y0 + box_h],
            radius=16,
            fill=(10, 10, 63),
            outline=(74, 144, 226),
            width=4,
        )
        text_block_center(x0, y0 + 10, box_w, 72, [title], font_title)
        text_block_center(x0, y0 + 82, box_w, box_h - 92, subtitle.split("\n"), font_small)

    def h_arrow(x0: int, y_mid: int, x1: int) -> None:
        draw.line((x0, y_mid, x1, y_mid), fill=(50, 50, 100), width=5)
        draw.polygon(
            [(x1 + 16, y_mid), (x1 - 2, y_mid - 12), (x1 - 2, y_mid + 12)],
            fill=(50, 50, 100),
        )

    # Row 1: stages 1-3
    x1 = margin_x
    x2 = margin_x + box_w + gap
    x3 = margin_x + 2 * (box_w + gap)
    y_mid_top = y_top + box_h // 2
    draw_box(x1, y_top, stages[0][0], stages[0][1])
    h_arrow(x1 + box_w + 4, y_mid_top, x2 -4)
    draw_box(x2, y_top, stages[1][0], stages[1][1])
    h_arrow(x2 + box_w + 4, y_mid_top, x3 - 4)
    draw_box(x3, y_top, stages[2][0], stages[2][1])

    # Row 2: stages 4-5 aligned under stage 3 (continuing flow)
    y_bot = y_top + box_h + row_gap
    y_mid_bot = y_bot + box_h // 2
    x4 = x3
    x5 = x4 + box_w + gap

    xc_down = x3 + box_w // 2
    y_join_top = y_top + box_h
    y_join_bot = y_bot - 6
    draw.line((xc_down, y_join_top + 6, xc_down, y_join_bot), fill=(50, 50, 100), width=5)
    draw.polygon(
        [
            (xc_down, y_join_bot + 18),
            (xc_down - 12, y_join_bot + 2),
            (xc_down + 12, y_join_bot + 2),
        ],
        fill=(50, 50, 100),
    )

    draw_box(x4, y_bot, stages[3][0], stages[3][1])
    h_arrow(x4 + box_w + 4, y_mid_bot, x5 - 4)
    draw_box(x5, y_bot, stages[4][0], stages[4][1])

    note = (
        "Iterative loop: after (5), next target -> back to (2)-(4) until the drill or poem ends."
    )
    draw.text((margin_x, y_bot + box_h + 32), note, fill=(55, 65, 80), font=font_note)

    return img


class PDF(FPDF):
    def footer(self) -> None:
        self.set_y(-15)
        self.set_font("Helvetica", "I", 9)
        self.set_text_color(120, 120, 120)
        self.cell(0, 10, f"Page {self.page_no()}", align="C")


def main() -> None:
    out = _ROOT / "docs" / "Section_3.3_and_3.4_App_Components_and_Features.pdf"
    png_out = _ROOT / "docs" / "Figure_1_handwriting_practice_pipeline.png"
    out.parent.mkdir(parents=True, exist_ok=True)

    fig = render_pipeline_figure_png()
    fig.save(png_out, format="PNG")

    buf = BytesIO()
    fig.save(buf, format="PNG")
    buf.seek(0)

    pdf = PDF()
    pdf.set_auto_page_break(auto=True, margin=20)
    pdf.add_page()
    pdf.set_margins(18, 18, 18)

    html_opening = """
<p><b>3.3 App Components and Key Features</b></p>
<p>This subsection covers interface layout, on-device ML Kit inference, and local storage, using the
same terms as the codebase (Flutter/Dart, Digital Ink, <i>flutter_tts</i>, <i>shared_preferences</i>).
Figure 1 outlines the practice-time pipeline.</p>
"""

    html_body = """
<p><b>Frontend (presentation layer)</b></p>

<p>- <b>High-contrast presentation and enlarged typography.</b> Dark scaffold, large base text, and
global linear text scaling support low vision; long-press on the canvas toggles a higher-contrast
drawing view.</p>

<p>- <b>Navigation and task routing.</b> Home splits work into lowercase, uppercase, and numerals
(grid then shared workspace). <i>Poem Practice</i> appears when the UI language is English (short
phrases and longer verses).</p>

<p>- <b>Voice-guided writing workspace.</b> Template plus digital-ink canvas; TTS (Cantonese or
English) can differ from Chinese/English on-screen labels. Double-tap replay, pinch zoom, brush/eraser;
glyph drills add round presets and a progress bar.</p>

<p>- <b>Passage-oriented (poem) composition mode.</b> Scrollable passage; one active grapheme at a
time while speech tracks the current word and character.</p>

<p>- <b>Landscape layout and orientation control (poem practice only).</b> Only poem practice uses a
portrait/landscape split via <i>OrientationBuilder</i>: portrait stacks word, progress, and canvas;
landscape uses a ~100px left strip (word, progress, circular speak/clear/next) beside a full-height
wide canvas. Landscape follows physical rotation or an app-bar lock using
<i>SystemChrome.setPreferredOrientations</i> (landscape left/right vs portrait-up); dispose restores
portrait-up. Single-glyph practice has no such split.</p>

<p>- <b>Terminal analytics for passage tasks.</b> After the last token, TTS and a <i>Poem Summary</i>
dialog report accuracy, mean time per character, session duration, and difficult words.</p>

<p>- <b>Multilingual coverage.</b> Latin upper/lowercase, Arabic numerals, Traditional Chinese
numerals (1-10 in the grid); bilingual UI with Cantonese or English TTS.</p>

<p>- <b>Accessibility metadata.</b> Semantics describe canvas actions (replay, high contrast, zoom)
for screen readers.</p>

<p><b>Backend and local data handling (client-only)</b></p>

<p>Client-only: no login, no cloud ink API, no Firebase. ML Kit scores on-device.
<i>shared_preferences</i> holds UI/voice locales and JSON score lists per practice key (not synced).
High-contrast canvas is session state, not a saved theme.</p>

<p><b>3.4 Core Features</b></p>

<p><b>(1) Voice-guided handwriting practice.</b> Spoken steps scaffold graphemes, words, and short
lines. UI language and TTS are independent. On-device scoring drives spoken percentages and, in poem
mode, auto-advance or retry prompts.</p>

<p><b>(2) Poem practice with continuous writing and structured feedback.</b> Same ML Kit path as
drills inside English passages; TTS follows the active span; scrollable text keeps context. End of
session combines speech and summary UI (accuracy, timing, weak words).</p>

<p><b>(3) Multilingual script support.</b> Latin cases, Arabic digits, Traditional Chinese numerals,
bilingual UI, flexible TTS; custom fonts and accessibility features keep tasks readable with all
inference local.</p>
"""

    pdf.set_font("Helvetica", "", 11)
    pdf.set_text_color(25, 25, 25)
    pdf.write_html(html_opening.strip())

    pdf.ln(4)
    # Nearly full text width (A4 ~210 mm) so the figure stays readable at 2-up print.
    pdf.image(buf, x=10, w=190)
    pdf.ln(6)

    pdf.set_font("Helvetica", "I", 10)
    pdf.set_text_color(60, 60, 60)
    pdf.multi_cell(
        0,
        5,
        "Figure 1. On-device practice pipeline (HC = high-contrast canvas; TTS = text-to-speech). "
        "Arrows: main control/data flow in one session.",
    )
    pdf.ln(4)
    pdf.set_text_color(25, 25, 25)

    pdf.set_font("Helvetica", "", 11)
    pdf.write_html(html_body.strip())

    pdf.output(str(out))
    print(f"Wrote {out}")
    print(f"Wrote {png_out}")


if __name__ == "__main__":
    main()
