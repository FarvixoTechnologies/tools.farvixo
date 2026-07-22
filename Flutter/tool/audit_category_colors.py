#!/usr/bin/env python3
"""Audit Farvixo's per-category color ramp.

Parses lib/theme/app_colors.dart and verifies, for all tool categories:

  1. every token triplet (base / Light / Deep) exists
  2. every accent clears WCAG AA 3:1 against its own surface
     (dark accent vs #12121C, light accent vs #FFFFFF)
  3. no two categories are confusable — i.e. no pair sits within
     14 deg hue AND 0.12 lightness AND 0.30 saturation, in either theme

Run from the repo root:

    python3 tool/audit_category_colors.py

Exits non-zero on any violation, so it can gate CI.
"""

from __future__ import annotations

import colorsys
import pathlib
import re
import sys

SOURCE = pathlib.Path("lib/theme/app_colors.dart")

DARK_SURFACE = 0x12121C  # AppColors.bgSurface
LIGHT_SURFACE = 0xFFFFFF  # AppColors.lightSurface

MIN_CONTRAST = 3.0  # WCAG AA — UI components & large text
HUE_EPS = 14.0
LIGHTNESS_EPS_DARK = 0.12
LIGHTNESS_EPS_LIGHT = 0.10
SATURATION_EPS = 0.30

CATEGORIES = [
    "Pdf", "Image", "Video", "Audio", "Ai", "Dev", "Text", "Utility",
    "Ocr", "Qr", "Scanner", "Security", "Finance", "Business",
    "Government", "Converter", "Calculator", "Notes", "Cloud",
]


def parse_tokens(src: str) -> dict[str, int]:
    pattern = r"static const Color (accent\w+) =\s*Color\(0x([0-9A-Fa-f]{8})\)"
    return {m.group(1): int(m.group(2)[2:], 16) for m in re.finditer(pattern, src)}


def relative_luminance(rgb: int) -> float:
    def channel(value: int) -> float:
        v = value / 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4

    r, g, b = (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast(a: int, b: int) -> float:
    la, lb = relative_luminance(a), relative_luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def hls(rgb: int) -> tuple[float, float, float]:
    r, g, b = (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF
    h, lightness, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return h * 360, lightness, s


def hue_delta(a: float, b: float) -> float:
    d = abs(a - b)
    return min(d, 360 - d)


def main() -> int:
    if not SOURCE.exists():
        print(f"error: {SOURCE} not found — run from the repo root", file=sys.stderr)
        return 2

    tokens = parse_tokens(SOURCE.read_text(encoding="utf-8"))
    failures: list[str] = []

    # 1. completeness
    for name in CATEGORIES:
        for suffix in ("", "Light", "Deep"):
            key = f"accent{name}{suffix}"
            if key not in tokens:
                failures.append(f"missing token: AppColors.{key}")
    if failures:
        for f in failures:
            print(f"FAIL  {f}")
        return 1

    # 2. contrast
    print(f"{'CATEGORY':<13}{'DARK':>9}{'ratio':>8}{'LIGHT':>10}{'ratio':>8}")
    for name in CATEGORIES:
        dark, light = tokens[f"accent{name}"], tokens[f"accent{name}Light"]
        rd, rl = contrast(dark, DARK_SURFACE), contrast(light, LIGHT_SURFACE)
        flag = "" if rd >= MIN_CONTRAST and rl >= MIN_CONTRAST else "  <-- FAIL"
        print(f"{name:<13}{'#%06X' % dark:>9}{rd:>8.2f}{'#%06X' % light:>10}{rl:>8.2f}{flag}")
        if rd < MIN_CONTRAST:
            failures.append(f"{name}: dark accent {rd:.2f}:1 < {MIN_CONTRAST}:1")
        if rl < MIN_CONTRAST:
            failures.append(f"{name}: light accent {rl:.2f}:1 < {MIN_CONTRAST}:1")

    # 3. distinguishability
    for suffix, label, l_eps in (("", "dark", LIGHTNESS_EPS_DARK),
                                 ("Light", "light", LIGHTNESS_EPS_LIGHT)):
        clashes = []
        for i, a in enumerate(CATEGORIES):
            for b in CATEGORIES[i + 1:]:
                ha, la, sa = hls(tokens[f"accent{a}{suffix}"])
                hb, lb, sb = hls(tokens[f"accent{b}{suffix}"])
                if (hue_delta(ha, hb) < HUE_EPS
                        and abs(la - lb) < l_eps
                        and abs(sa - sb) < SATURATION_EPS):
                    clashes.append(f"{a} vs {b}")
        print(f"\nConfusable ({label} theme): {', '.join(clashes) if clashes else 'none'}")
        failures.extend(f"confusable in {label} theme: {c}" for c in clashes)

    if failures:
        print(f"\n{len(failures)} violation(s):", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 1

    print(f"\nOK — {len(CATEGORIES)} categories, AA contrast clean, no confusable pairs.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
