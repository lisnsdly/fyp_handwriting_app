#!/usr/bin/env python3
"""Generate Section 3.2 (Development Stack) PDF for the FYP report."""

import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_ROOT / ".pdf_tools"))

from fpdf import FPDF  # noqa: E402


class PDF(FPDF):
    def footer(self) -> None:
        self.set_y(-15)
        self.set_font("Helvetica", "I", 9)
        self.set_text_color(120, 120, 120)
        self.cell(0, 10, f"Page {self.page_no()}", align="C")


def main() -> None:
    out = _ROOT / "docs" / "Section_3.2_Development_Stack_and_Technical_Framework.pdf"
    out.parent.mkdir(parents=True, exist_ok=True)

    pdf = PDF()
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.add_page()
    pdf.set_margins(18, 18, 18)

    pdf.set_font("Helvetica", "B", 15)
    pdf.set_text_color(20, 20, 20)
    pdf.multi_cell(0, 8, "3.2 Development Stack and Technical Framework")
    pdf.ln(2)

    pdf.set_font("Helvetica", "", 11)
    pdf.multi_cell(
        0,
        6,
        "The following point-form list summarizes the technical framework. Each entry states the tool "
        "or library and briefly describes how it contributes to the implementation.",
    )
    pdf.ln(3)

    # Length and tone aligned with the report reference: bold label + colon, then ~two sentences.
    items = [
        (
            "Figma",
            "Leveraged for high-fidelity prototyping and UI/UX design. This tool allowed for the "
            "iterative testing of accessibility features, such as color contrast and element scaling, "
            "before the commencement of the development phase.",
        ),
        (
            "Flutter (Dart)",
            "Employed as the primary cross-platform framework to ensure seamless deployment on both "
            "Android and iOS from a single codebase. The Flutter rendering stack supports responsive, "
            "accessible, and custom UI components appropriate for low-vision interaction design.",
        ),
        (
            "Google ML Kit (Digital Ink Recognition)",
            "The google_mlkit_digital_ink_recognition plugin connects the handwriting canvas to "
            "on-device digital-ink models provided by Google ML Kit. Ink traces are interpreted "
            "locally so practice feedback can be generated without transmitting raw strokes to a "
            "remote backend.",
        ),
        (
            "Flutter APIs and flutter_tts",
            "Utilized to integrate Text-to-Speech (TTS) capabilities. This supports real-time, "
            "voice-guided instruction and uses the host platform speech engine, which aligns with "
            "native auditory feedback and screen-reader ecosystems.",
        ),
        (
            "Bilingual interface and localization approach",
            "English and Chinese interface strings, together with Cantonese and English voice output, "
            "are coordinated through Dart application state and saved preferences. Dynamic language "
            "switching is therefore handled in application logic rather than through intl or "
            "flutter_localizations dependencies.",
        ),
        (
            "shared_preferences, Semantics, and flutter_lints",
            "The shared_preferences plugin persists UI and voice language selections across sessions. "
            "Semantics metadata augments widgets for accessibility services, and flutter_lints enforces "
            "recommended static-analysis rules for maintainable Dart source.",
        ),
    ]

    pdf.set_text_color(30, 30, 30)
    blocks = []
    for title, body in items:
        blocks.append(f"<p>- <b>{title}:</b> {body}</p>")
    pdf.write_html("".join(blocks))

    pdf.output(str(out))
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
