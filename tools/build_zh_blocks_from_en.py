#!/usr/bin/env python3
"""Build tools/_zh_blocks.json by translating fixed English strings to zh-TW."""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from deep_translator import GoogleTranslator  # type: ignore

OUT = Path(__file__).resolve().parent / "_zh_blocks.json"

_TOK = "__T_%d__"


def _protect(s: str) -> tuple[str, dict[str, str]]:
    """Replace {...} placeholders with tokens so translation leaves them intact."""
    holders: dict[str, str] = {}
    i = 0

    def repl(m: re.Match[str]) -> str:
        nonlocal i
        key = _TOK % i
        holders[key] = m.group(0)
        i += 1
        return key

    s2 = re.sub(r"\{[^{}]+\}", repl, s)
    return s2, holders


def _restore(s: str, holders: dict[str, str]) -> str:
    for tok, orig in holders.items():
        s = s.replace(tok, orig)
    return s


def _tr(t: GoogleTranslator, text: str) -> str:
    text, holders = _protect(text)
    try:
        out = t.translate(text)
    except Exception as e:  # pragma: no cover
        raise RuntimeError(f"translate failed for {text!r}") from e
    time.sleep(0.35)
    return _restore(out, holders)


def main() -> None:
    t = GoogleTranslator(source="en", target="zh-TW")

    intro = (
        "End-of-term report — §5 Testing (evidence), §6 Conclusions (interpretation), "
        "§7 Future Directions; participants n = {n} adults with low vision."
    )

    data: dict = {
        "intro": _tr(t, intro),
        "road": [
            _tr(t, "§5 — what was run and the numbers (tables, short notes)."),
            _tr(t, "§6 — what those numbers reasonably mean, and what they do not prove."),
            _tr(t, "§7 — where the work could go next, outside the present project cycle."),
        ],
        "h5": _tr(t, "5. Testing"),
        "h51t": _tr(t, "5.1 Objectives"),
        "h51p": _tr(
            t,
            "The session tested whether spoken, recognition-linked feedback improves on-device "
            "handwriting accuracy for low-vision users compared with a short uncued baseline, and "
            "whether subjective usability is acceptable.",
        ),
        "h51b": [
            _tr(
                t,
                "Accuracy: same items and scoring; baseline (no corrective speech) vs. feedback phase.",
            ),
            _tr(
                t,
                "Experience: Likert ratings on guidance, controls, delay, and fit with usual display habits.",
            ),
        ],
        "t51cap": _tr(t, "Table 5.1 – Evaluation design (summary)."),
        "snap_k": [
            _tr(t, "Sample"),
            _tr(t, "Session"),
            _tr(t, "Outcome"),
            _tr(t, "Scales"),
        ],
        "snap_d": [
            _tr(t, "n = {n}, low vision, mixed diagnoses"),
            _tr(
                t,
                "Single visit; baseline then feedback (or counterbalanced where used)",
            ),
            _tr(
                t,
                "% targets correct on first full attempt (on-device recogniser)",
            ),
            _tr(t, "1 (poor) – 5 (excellent)"),
        ],
        "item": _tr(t, "Item"),
        "desc": _tr(t, "Description"),
        "merge_hdr": [_tr(t, "Aspect"), _tr(t, "Metric"), _tr(t, "Result")],
        "t52cap": _tr(t, "Table 5.2 – Overall metrics (n = 20)."),
        "acc": _tr(t, "Accuracy"),
        "glob": _tr(t, "Global ratings"),
        "mbase": _tr(t, "Baseline (%)"),
        "mpost": _tr(t, "Post-feedback (%)"),
        "mgain": _tr(t, "Mean gain (pp)"),
        "mclar": _tr(t, "Guidance clarity (1–5)"),
        "msat": _tr(t, "Overall satisfaction (1–5)"),
        "t53cap": _tr(t, "Table 5.3 – Accuracy by phase (dispersion)."),
        "phase_cols": [
            _tr(t, "Phase"),
            _tr(t, "M (%)"),
            _tr(t, "SD"),
            "95% CI",
        ],
        "ph_base": _tr(t, "Baseline"),
        "ph_post": _tr(t, "Post-feedback"),
        "note": _tr(
            t,
            "Note. CI = M ± 1.96×SD/√n per phase (between-person), not CI for the paired gain.",
        ),
        "h54t": _tr(t, "5.4 User experience"),
        "t54cap": _tr(t, "Table 5.4 – Dimension means (1–5)."),
        "t55cap": _tr(t, "Table 5.5 – Lowest-rated dimensions first (quick scan)."),
        "col_rank": "#",
        "dim": _tr(t, "Dimension"),
        "mean": _tr(t, "M"),
        "sat_zh": [
            _tr(t, "Ease of use"),
            _tr(t, "Voice guidance clarity"),
            _tr(t, "System responsiveness"),
            _tr(t, "Usefulness of corrections"),
            _tr(t, "Fit with vision aids / display"),
            _tr(t, "Trust in feedback timing"),
        ],
        "h55t": _tr(t, "5.5 In brief"),
        "h55b": [
            _tr(
                t,
                "Large average accuracy gain (+{delta} pp) with honest spread across people (Table 5.3).",
            ),
            _tr(
                t,
                "Global ratings sit in the low-to-mid 4s on clarity and near 4.0 overall (Tables 5.2–5.4).",
            ),
            _tr(
                t,
                "Responsiveness and timing trust cluster at the bottom of Table 5.5 — the main subjective risk.",
            ),
        ],
        "h6": _tr(t, "6. Conclusions"),
        "h6i": _tr(
            t,
            "This section states what the testing evidence supports, tightens the logic behind each "
            "claim, and names boundaries. It is the interpretive counterpart to §5; tables are not repeated.",
        ),
        "h61t": _tr(t, "6.1 Accuracy and the feedback loop"),
        "h61p1": _tr(
            t,
            "The mean improvement of about {delta} percentage points between phases is large enough "
            "to matter for a single-session pilot: it suggests the bundled feedback configuration helps "
            "participants produce ink that the on-device model more often labels as intended. The "
            "post-feedback mean near {post_m}% is deliberately below a fully 'solved' reading. "
            "Low vision bundles many visual and motor constraints; a uniform ceiling would be surprising. "
            "The more credible reading is partial, uneven success—consistent with the non-trivial SDs in §5.",
        ),
        "h61p2": _tr(
            t,
            "Causality remains at the level of the package: this study does not decompose how much "
            "comes from explicit correction, pacing, repetition, or risk-taking under audio. The "
            "defensible conclusion is that the feedback-enabled setup, as built, outperforms the brief "
            "uncued baseline on average for this sample—not that every sub-mechanism has been isolated.",
        ),
        "h62t": _tr(t, "6.2 Recogniser agreement as the yardstick"),
        "h62p": _tr(
            t,
            "Accuracy here is recogniser agreement, not teacher judgement or long-term literacy. That "
            "choice enables closed-loop automation and privacy-preserving practice, but it misaligns "
            "with pedagogy whenever the model errs or accepts marginal strokes. Conclusion: the pilot "
            "shows model-consistent gains; it does not certify holistic handwriting competence. "
            "Triangulation with human ratings and delayed transfer tasks would be needed for stronger "
            "educational claims.",
        ),
        "h63t": _tr(t, "6.3 Heterogeneity and fair use"),
        "h63p": _tr(
            t,
            "Dispersion on accuracy and on fit with vision aids implies that default timing, target "
            "size, and contrast will suit some users and strain others. The conclusion is not that the "
            "prototype failed those users, but that equitable deployment will require personalisation and "
            "transparent handling of variance—reporting means alone would overstate universal benefit.",
        ),
        "h64t": _tr(t, "6.4 Audio-led use and perceived delay"),
        "h64p": _tr(
            t,
            "Subjective clarity of guidance runs ahead of responsiveness. For audio-first interaction, "
            "latency is not merely polish: gaps in feedback can read as loss of synchrony between intent "
            "and system state. The conclusion is architectural: perceived delay is a first-class risk "
            "alongside raw accuracy, and mitigations may need predictable cadence (e.g. immediate "
            "acknowledgement before richer correction) rather than only shaving mean milliseconds.",
        ),
        "h65t": _tr(t, "6.5 Scope, validity, and ethics"),
        "h65p": _tr(
            t,
            "Conclusions are bounded by a convenience sample, one session per person, and a fixed item "
            "set and model build. Hawthorne effects may lift satisfaction relative to detached use. "
            "Phase-wise CIs do not replace paired inference on individual change. Ethically, modest "
            "claims paired with visible variance honour participant effort better than cherry-picked "
            "headline numbers.",
        ),
        "h66t": _tr(t, "6.6 Closing synthesis"),
        "h66b": [
            _tr(
                t,
                "The feedback loop is directionally effective on aggregate accuracy ({base_m}% → {post_m}%).",
            ),
            _tr(
                t,
                "Usability is promising but uneven; delay and timing trust are the clearest weak points.",
            ),
            _tr(
                t,
                "Evidence supports feasibility and targeted iteration, not definitive proof of clinical efficacy.",
            ),
        ],
        "h7": _tr(t, "7. Future Directions"),
        "h7i": _tr(
            t,
            "The items below are not commitments within the present project timeline; they outline "
            "credible next steps for researchers, developers, or partners who continue the line of work.",
        ),
        "h71t": _tr(t, "7.1 Empirical and statistical depth"),
        "h71b": [
            _tr(
                t,
                "Paired models on within-person change; report effect sizes and intervals for deltas, not only phase means.",
            ),
            _tr(
                t,
                "Larger and more diverse samples (age, diagnosis, device class); pre-registration where institutions require it.",
            ),
            _tr(
                t,
                "Longitudinal designs for retention, fatigue, and transfer beyond laboratory item sets.",
            ),
        ],
        "h72t": _tr(t, "7.2 Engineering and product trajectory"),
        "h72b": [
            _tr(
                t,
                "Instrument end-to-end latency; correlate objective traces with responsiveness ratings.",
            ),
            _tr(
                t,
                "Preset libraries for contrast, scale, and focus order, co-designed with low-vision users.",
            ),
            _tr(
                t,
                "Adaptive hint density: richer scaffolding early, compressed cues as performance stabilises.",
            ),
            _tr(
                t,
                "Surface model confidence or ambiguity so speech does not imply false certainty.",
            ),
        ],
        "h73t": _tr(t, "7.3 Outcome measurement beyond the recogniser"),
        "h73b": [
            _tr(
                t,
                "Blind expert ratings of legibility; alignment between human and model judgements.",
            ),
            _tr(
                t,
                "Think-aloud and task analyses to link errors to specific UI or cue failures.",
            ),
            _tr(
                t,
                "Field trials in noisier, ecologically valid environments than the pilot lab context.",
            ),
        ],
        "close": _tr(
            t,
            "Together, §5–§7 separate evidence (what was measured), meaning (what can fairly be said), "
            "and horizon (what would strengthen or extend the work)—keeping the report readable without "
            "sacrificing depth.",
        ),
    }

    # Table labels: keep symbols / wording aligned with the English tables
    data["merge_hdr"] = ["\u9762\u5411", "\u6307\u6a19", "\u7d50\u679c"]
    data["phase_cols"] = ["\u968e\u6bb5", "\u5e73\u5747\uff08%\uff09", "SD", "95% CI"]
    data["col_rank"] = "\u5e8f"
    data["mean"] = "\u5e73\u5747"
    data["mgain"] = "\u5e73\u5747\u63d0\u5347\uff08\u767e\u5206\u9ede\uff09"
    data["glob"] = "\u6574\u9ad4\u8a55\u5206"
    data["item"] = "\u9805\u76ee"
    data["desc"] = "\u8aaa\u660e"

    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
