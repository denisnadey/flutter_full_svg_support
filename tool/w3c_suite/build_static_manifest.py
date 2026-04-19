#!/usr/bin/env python3
"""Build a deterministic static W3C SVG manifest for visual tests.

Selection criteria (phase 1):
- status == accepted
- operator script contains "No interaction required"
- no SMIL/animation tags
- .svg only (exclude .svgz)
- viewBox == 0 0 480 360
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

RE_STATUS = re.compile(r'<d:SVGTestCase[^>]*status="([^"]+)"', re.IGNORECASE)
RE_OPERATOR = re.compile(
    r'<d:operatorScript[^>]*>(.*?)</d:operatorScript>', re.IGNORECASE | re.DOTALL
)
RE_PASS_CRITERIA = re.compile(
    r'<d:passCriteria[^>]*>(.*?)</d:passCriteria>', re.IGNORECASE | re.DOTALL
)
RE_VIEWBOX = re.compile(r'viewBox="([^"]+)"')
RE_TAGS = re.compile(r'<[^>]+>')
RE_ANIMATION = re.compile(
    r'<\s*(animate|set|animateMotion|animateTransform|animateColor)\b',
    re.IGNORECASE,
)
RE_SCRIPT = re.compile(r'<\s*script\b', re.IGNORECASE)
RE_SYSTEM_COLOR_KEYWORDS = re.compile(
    r'\b('
    r'ActiveBorder|ActiveCaption|AppWorkspace|Background|ButtonFace|'
    r'ButtonHighlight|ButtonShadow|ButtonText|CaptionText|GrayText|'
    r'Highlight|HighlightText|InactiveBorder|InactiveCaption|'
    r'InactiveCaptionText|InfoBackground|InfoText|Menu|MenuText|Scrollbar|'
    r'ThreeDDarkShadow|ThreeDFace|ThreeDHighlight|ThreeDLightShadow|'
    r'ThreeDShadow|Window|WindowFrame|WindowText'
    r')\b',
    re.IGNORECASE,
)
AMBIGUOUS_PASS_CRITERIA_PHRASES = (
    'no specific pass criteria',
    'might not match the reference image',
    'might not match the reference',
    'no error must be indicated',
    'except for variations in the labeling text',
    'except for possible variations in the labeling text',
    'except for possible variations in the labelling text',
    'except for variations in labeling text',
    'except for variations in labelling text',
    'except for variations in text',
    'text may show minor differences',
    'text which may show minor differences',
    'test passes if there is no red visible on the page',
    'may have any non-zero length',
    'which may vary',
)


def _sanitize_for_feature_checks(svg_text: str) -> str:
    sanitized = svg_text
    sanitized = re.sub(
        r'<d:SVGTestCase[\s\S]*?</d:SVGTestCase>',
        '',
        sanitized,
        flags=re.IGNORECASE,
    )
    sanitized = re.sub(
        r'<text[^>]*id="revision"[\s\S]*?</text>',
        '',
        sanitized,
        flags=re.IGNORECASE,
    )
    sanitized = re.sub(
        r'<rect[^>]*id="test-frame"[^>]*/>',
        '',
        sanitized,
        flags=re.IGNORECASE,
    )
    return sanitized


@dataclass
class ManifestEntry:
    name: str
    category: str
    svg_path: str
    png_path: str
    view_box: str



def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")



def _extract_status(svg_text: str) -> str:
    match = RE_STATUS.search(svg_text)
    return match.group(1).strip() if match else ""



def _extract_operator_text(svg_text: str) -> str:
    match = RE_OPERATOR.search(svg_text)
    if not match:
        return ""
    raw = RE_TAGS.sub(" ", match.group(1))
    return " ".join(raw.split()).lower()


def _extract_pass_criteria_text(svg_text: str) -> str:
    match = RE_PASS_CRITERIA.search(svg_text)
    if not match:
        return ""
    raw = RE_TAGS.sub(" ", match.group(1))
    return " ".join(raw.split()).lower()



def _extract_view_box(svg_text: str) -> str:
    match = RE_VIEWBOX.search(svg_text)
    if not match:
        return ""
    return " ".join(match.group(1).split())



def _has_animation(svg_text: str) -> bool:
    return RE_ANIMATION.search(svg_text) is not None


def _has_script(svg_text: str) -> bool:
    return RE_SCRIPT.search(svg_text) is not None


def _has_system_color_keywords(svg_text: str) -> bool:
    return RE_SYSTEM_COLOR_KEYWORDS.search(svg_text) is not None



def _category_from_name(name: str) -> str:
    return name.split("-", 1)[0] if "-" in name else "misc"


def _has_ambiguous_pass_criteria(svg_text: str) -> bool:
    pass_text = _extract_pass_criteria_text(svg_text)
    return any(phrase in pass_text for phrase in AMBIGUOUS_PASS_CRITERIA_PHRASES)



def _build_entries(repo_root: Path) -> list[ManifestEntry]:
    suite_root = repo_root / "W3C_SVG_11_TestSuite"
    svg_dir = suite_root / "svg"
    png_dir = suite_root / "png"

    entries: list[ManifestEntry] = []
    for svg_file in sorted(svg_dir.glob("*.svg")):
        svg_text = _read_text(svg_file)
        status = _extract_status(svg_text)
        if status != "accepted":
            continue

        operator_text = _extract_operator_text(svg_text)
        if "no interaction required" not in operator_text:
            continue

        check_text = _sanitize_for_feature_checks(svg_text)

        if _has_animation(check_text):
            continue

        if _has_script(check_text):
            continue

        if _has_system_color_keywords(check_text):
            continue

        if _has_ambiguous_pass_criteria(svg_text):
            continue

        view_box = _extract_view_box(svg_text)
        if view_box != "0 0 480 360":
            continue

        name = svg_file.stem
        png_file = png_dir / f"{name}.png"
        if not png_file.exists():
            continue

        entries.append(
            ManifestEntry(
                name=name,
                category=_category_from_name(name),
                svg_path=str(svg_file.relative_to(repo_root)).replace("\\", "/"),
                png_path=str(png_file.relative_to(repo_root)).replace("\\", "/"),
                view_box=view_box,
            )
        )

    return entries



def main() -> None:
    repo_root = Path(__file__).resolve().parents[2]
    output_path = (
        repo_root / "test" / "w3c" / "manifest" / "w3c_static_accepted_manifest.json"
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)

    entries = _build_entries(repo_root)
    payload = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "suiteRoot": "W3C_SVG_11_TestSuite",
        "criteria": {
            "status": "accepted",
            "operatorScriptContains": "no interaction required",
            "excludeAnimationTags": True,
            "excludeScriptTags": True,
            "excludeSystemColors": True,
            "excludeAmbiguousPassCriteria": True,
            "viewBox": "0 0 480 360",
            "extensions": [".svg"],
        },
        "selectedCount": len(entries),
        "entries": [
            {
                "name": entry.name,
                "category": entry.category,
                "svgPath": entry.svg_path,
                "pngPath": entry.png_path,
                "viewBox": entry.view_box,
            }
            for entry in entries
        ],
    }

    output_path.write_text(
        json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8"
    )

    print(f"Manifest saved: {output_path}")
    print(f"Selected entries: {len(entries)}")


if __name__ == "__main__":
    main()
