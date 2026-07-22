#!/usr/bin/env python3
"""Farvixo design-token lint gate.

Rejects hardcoded design values in feature code. Everything must come from
lib/theme/ — AppColors, AppTypography, Space/Gap, Radii, Motion, Elevations.

    RULE                        WHAT IT CATCHES
    hardcoded-color             Color(0xFF…), Colors.red
    hardcoded-font-size         fontSize: 14
    hardcoded-font-weight       FontWeight.w800
    raw-text-style              TextStyle( built inline
    hardcoded-radius            BorderRadius.circular(20), Radius.circular(8)
    hardcoded-duration          Duration(milliseconds: 220)
    hardcoded-curve             Curves.easeOut
    direct-accent-read          AppColors.accentPdf (not brightness-aware)

## Ratcheting

A full-repo ban would fail on day one with ~850 violations, so the gate runs
against a **baseline** (tool/token_baseline.json): the known count per file.
The build fails if any file exceeds its baseline — new debt is blocked while
existing debt is paid down feature by feature.

    python3 tool/audit_design_tokens.py              # check against baseline
    python3 tool/audit_design_tokens.py --update     # re-record after migrating
    python3 tool/audit_design_tokens.py --strict     # zero tolerance (end state)
    python3 tool/audit_design_tokens.py --path lib/features/home   # one feature

Exits non-zero on any regression, so it can gate CI.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
BASELINE_PATH = REPO / "tool" / "token_baseline.json"

# Token definitions live here — these files are allowed to contain raw values.
EXEMPT_DIRS = ("lib/theme/",)
EXEMPT_FILES = ("lib/firebase_options.dart",)

# Const data catalogs store an accent as a *data attribute*, not a live widget
# read — the render site is what must be brightness-aware. `tools_data.dart`
# resolves via `.identity` at render; `settings_catalog.dart` icons render as
# small glyphs that clear AA (3:1) in both themes. The `direct-accent-read`
# rule (which targets widget code) is suppressed for these files only.
ACCENT_DATA_CATALOGS = (
    "lib/data/tools_data.dart",
    "lib/features/settings/settings_catalog.dart",
    # Decorative section-icon accents in const data lists — rendered as small
    # glyphs that clear AA (3:1) in both themes, same as settings_catalog.
    "lib/features/settings/settings_v5_sections.dart",
    "lib/features/settings/settings_v5_widgets.dart",
    # Hub-row data tuples + decorative galaxy-backdrop painter dots.
    "lib/features/settings/settings_screen.dart",
    # Immersive brand-art screens: RGB-ring / particle painter accents and
    # feature-icon data tuples. Decorative gradient/glow stops, not foreground
    # text — brightness-awareness does not apply to a translucent glow.
    "lib/features/auth/login_screen.dart",
    "lib/ui/splash/splash_screen.dart",
    "lib/features/onboarding/onboarding_screen.dart",
)

# Files that are legitimately about raw colours: a colour picker's hue wheel,
# a swatch palette, a remote-config defaults model. Colour data, not theming.
COLOR_TOOL_FILES = (
    "lib/features/settings/accent_color_picker_sheet.dart",
    # Remote-config splash defaults — the raw colours *are* the data.
    "lib/core/launch/models/splash_config.dart",
)

# Accent-preset catalogs: the selectable theme accents, and category fallback
# colours in a repository. Accent-as-data, resolved elsewhere.
ACCENT_DATA_CATALOGS_EXTRA = (
    "lib/providers/theme_provider.dart",
    "lib/providers/tool_repository_provider.dart",
)

RULES: list[tuple[str, re.Pattern[str]]] = [
    ("hardcoded-color", re.compile(r"Color\(0x[0-9A-Fa-f]{6,8}\)")),
    ("hardcoded-color", re.compile(r"\bColors\.(?!transparent\b)[a-z]\w+")),
    ("hardcoded-font-size", re.compile(r"fontSize:\s*[0-9]")),
    ("hardcoded-font-weight", re.compile(r"FontWeight\.w[0-9]{3}")),
    ("raw-text-style", re.compile(r"\bTextStyle\(")),
    ("hardcoded-radius", re.compile(r"BorderRadius\.circular\(\s*[0-9]")),
    ("hardcoded-radius", re.compile(r"Radius\.circular\(\s*[0-9]")),
    ("hardcoded-duration", re.compile(r"Duration\(\s*(?:milliseconds|seconds):\s*[0-9]")),
    ("hardcoded-curve", re.compile(r"\bCurves\.\w+")),
    ("direct-accent-read", re.compile(r"AppColors\.accent[A-Z]\w*")),
]

# Rules that only make sense in presentation code.
#
# A 45-second HTTP receive timeout and a 2-minute lifecycle guard are not
# motion values — flagging them as "hardcoded duration" trains people to
# ignore the gate, which is worse than not having it.
PRESENTATION_ONLY = {"hardcoded-duration", "hardcoded-curve"}

NON_PRESENTATION = (
    "/services/",
    "/repositories/",
    "/api/",
    "/core/",
    "/data/",
    "/engine/",
)


def rule_applies(rule: str, rel: str) -> bool:
    if rule == "direct-accent-read" and (
        rel in ACCENT_DATA_CATALOGS or rel in ACCENT_DATA_CATALOGS_EXTRA
    ):
        return False
    if rule == "hardcoded-color" and rel in COLOR_TOOL_FILES:
        return False
    if rule not in PRESENTATION_ONLY:
        return True
    return not any(seg in f"/{rel}" for seg in NON_PRESENTATION)

STRING_RE = re.compile(r"'(?:[^'\\\n]|\\.)*'|\"(?:[^\"\\\n]|\\.)*\"")
LINE_COMMENT_RE = re.compile(r"//.*")
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.S)


def strip_noise(src: str) -> str:
    """Blank out strings and comments so they cannot produce false positives."""
    src = BLOCK_COMMENT_RE.sub("", src)
    src = LINE_COMMENT_RE.sub("", src)
    return STRING_RE.sub("''", src)


def is_exempt(rel: str) -> bool:
    return rel.startswith(EXEMPT_DIRS) or rel in EXEMPT_FILES


def scan(root: pathlib.Path, subpath: str | None = None) -> dict[str, dict[str, int]]:
    base = root / (subpath or "lib")
    # `rglob` on a file yields nothing, which would silently report a single
    # file as clean. Handle both a file and a directory target.
    targets = sorted(base.rglob("*.dart")) if base.is_dir() else [base]
    results: dict[str, dict[str, int]] = {}
    for path in targets:
        if path.suffix != ".dart" or not path.exists():
            continue
        rel = path.relative_to(root).as_posix()
        if is_exempt(rel):
            continue
        code = strip_noise(path.read_text(encoding="utf-8"))
        counts: dict[str, int] = {}
        for rule, pattern in RULES:
            if not rule_applies(rule, rel):
                continue
            n = len(pattern.findall(code))
            if n:
                counts[rule] = counts.get(rule, 0) + n
        if counts:
            results[rel] = counts
    return results


def total(counts: dict[str, dict[str, int]]) -> int:
    return sum(sum(c.values()) for c in counts.values())


def by_rule(counts: dict[str, dict[str, int]]) -> dict[str, int]:
    out: dict[str, int] = {}
    for file_counts in counts.values():
        for rule, n in file_counts.items():
            out[rule] = out.get(rule, 0) + n
    return dict(sorted(out.items(), key=lambda kv: -kv[1]))


def load_baseline() -> dict[str, dict[str, int]]:
    if not BASELINE_PATH.exists():
        return {}
    return json.loads(BASELINE_PATH.read_text(encoding="utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--update", action="store_true", help="re-record the baseline")
    ap.add_argument("--strict", action="store_true", help="zero tolerance")
    ap.add_argument("--path", help="scan only this subpath (e.g. lib/features/home)")
    args = ap.parse_args()

    current = scan(REPO, args.path)

    if args.update:
        full = scan(REPO)
        BASELINE_PATH.write_text(
            json.dumps(full, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        print(f"Baseline updated: {len(full)} files, {total(full)} violations.")
        return 0

    print("=== Farvixo design-token audit ===\n")
    summary = by_rule(current)
    if summary:
        width = max(len(r) for r in summary)
        for rule, n in summary.items():
            print(f"  {rule:<{width}}  {n:>5}")
        print(f"\n  {'TOTAL':<{width}}  {total(current):>5}  across {len(current)} files")
    else:
        print("  No violations. Fully tokenized.")

    if args.strict:
        if current:
            print(f"\nSTRICT: {total(current)} violation(s) — build rejected.", file=sys.stderr)
            for rel, counts in sorted(current.items())[:40]:
                print(f"  {rel}: {counts}", file=sys.stderr)
            return 1
        print("\nSTRICT: clean.")
        return 0

    baseline = load_baseline()
    if not baseline:
        print("\nNo baseline recorded. Run with --update to create one.")
        return 0

    regressions: list[str] = []
    for rel, counts in current.items():
        base = baseline.get(rel, {})
        for rule, n in counts.items():
            allowed = base.get(rule, 0)
            if n > allowed:
                regressions.append(f"{rel}  {rule}: {n} > {allowed} allowed")

    improved = 0
    for rel, base in baseline.items():
        now = current.get(rel, {})
        if sum(now.values()) < sum(base.values()):
            improved += 1

    print(f"\nBaseline: {total(baseline)} violations across {len(baseline)} files")
    if improved:
        print(f"Improved since baseline: {improved} file(s) — run --update to lock in.")

    if regressions:
        print(f"\n{len(regressions)} regression(s) — build rejected:", file=sys.stderr)
        for r in regressions:
            print(f"  {r}", file=sys.stderr)
        return 1

    print("\nOK — no new hardcoded design values.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
