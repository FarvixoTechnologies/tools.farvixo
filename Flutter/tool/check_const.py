#!/usr/bin/env python3
"""Catch non-const expressions inside `const` constructor calls.

This is the most common compile break when migrating hardcoded values to
design tokens. A widget that was:

    const Text('Hi', style: TextStyle(fontSize: 12))

becomes:

    const Text('Hi', style: AppTypography.caption(context))   // does NOT compile

because a context-bound call is not a constant expression — the `const` has to
be dropped. `flutter analyze` catches this; this script catches it without a
Flutter SDK.

Usage:

    python3 tool/check_const.py [path ...]      # defaults to lib/

Exits non-zero if any violation is found.

Implementation note: source is tokenized with a real char-level scanner rather
than regex-stripped. A naive `re.sub(r'//.*', '', src)` corrupts any string
containing `//` — every https:// URL — which silently produces bogus spans and
false positives.
"""

from __future__ import annotations

import pathlib
import re
import sys

# Expressions that can never be part of a constant expression.
NONCONST = re.compile(
    r'(?:'
    r'AppTypography\.\w+\s*\(\s*context'
    r'|AppPalette\.of\s*\('
    r'|Theme\.of\s*\('
    r'|MediaQuery\.\w+\s*\('
    r'|\.withValues\s*\('
    r'|Color\.lerp\s*\('
    r'|Motion\.of\s*\(|Motion\.curveOf\s*\(|Motion\.stagger\s*\('
    r'|\.accentOf\s*\('
    r'|\.border\s*\(\s*context|\.tint\s*\(\s*context|\.wash\s*\(\s*context'
    r'|\.glow\s*\(\s*context|\.cardShadow\s*\(\s*context'
    r'|\.surfaceGradient\s*\(\s*context|\.gradient\s*\(\s*context'
    r'|\.copyWith\s*\('
    r')'
)

CONST_CTOR = re.compile(r'\bconst\s+[A-Z_]\w*(?:\.\w+)?\s*\(')


def blank_noncode(src: str) -> str:
    """Replace every comment and string literal with same-length spaces.

    Offsets are preserved, so line numbers and slices stay valid, but no
    comment or string content can be mistaken for code.
    """
    out = list(src)
    i, n = 0, len(src)

    def blank(a: int, b: int) -> None:
        for k in range(a, min(b, n)):
            if out[k] != '\n':
                out[k] = ' '

    while i < n:
        c = src[i]
        # comments
        if c == '/' and i + 1 < n:
            if src[i + 1] == '/':
                j = src.find('\n', i)
                j = n if j == -1 else j
                blank(i, j)
                i = j
                continue
            if src[i + 1] == '*':
                j = src.find('*/', i + 2)
                j = n if j == -1 else j + 2
                blank(i, j)
                i = j
                continue
        # strings (raw, triple, single/double)
        if c in '"\'' or (c == 'r' and i + 1 < n and src[i + 1] in '"\''):
            start = i
            raw = c == 'r'
            if raw:
                i += 1
            q = src[i]
            triple = src[i:i + 3] in ('"""', "'''")
            term = src[i:i + 3] if triple else q
            i += 3 if triple else 1
            while i < n:
                if not raw and src[i] == '\\':
                    i += 2
                    continue
                if src[i:i + len(term)] == term:
                    i += len(term)
                    break
                if not triple and src[i] == '\n':
                    break
                i += 1
            blank(start, i)
            continue
        i += 1
    return ''.join(out)


def const_spans(code: str):
    """Yield (start, end) offsets of each `const X(...)` argument list."""
    for m in CONST_CTOR.finditer(code):
        i, depth, n = m.end(), 1, len(code)
        while i < n and depth:
            if code[i] == '(':
                depth += 1
            elif code[i] == ')':
                depth -= 1
            i += 1
        if depth == 0:
            yield m.start(), i


def offending_const_keywords(src: str) -> list[int]:
    """Byte offsets of each `const` keyword whose constructor argument span
    contains a non-const expression. Innermost/last-first so removals don't
    shift earlier offsets."""
    code = blank_noncode(src)
    hits: list[int] = []
    for m in CONST_CTOR.finditer(code):
        # span from just after `const ` to the matching close paren
        kw = m.start()
        open_paren = code.index('(', kw)
        i, depth, n = open_paren + 1, 1, len(code)
        while i < n and depth:
            if code[i] == '(':
                depth += 1
            elif code[i] == ')':
                depth -= 1
            i += 1
        if depth == 0 and NONCONST.search(code[open_paren:i]):
            hits.append(kw)
    return hits


def fix_file(path: pathlib.Path) -> int:
    """Drop the `const` keyword from each constructor that now holds a
    context-bound call. Iterates until stable. Returns keywords removed."""
    removed = 0
    for _ in range(20):
        src = path.read_text(encoding='utf-8')
        hits = offending_const_keywords(src)
        if not hits:
            break
        # Remove the last (rightmost) hit each pass so offsets stay valid, and
        # only ever the outermost offender per constructor.
        kw = hits[-1]
        # `const ` → ``  (keep any leading whitespace before it)
        after = kw + len('const')
        while after < len(src) and src[after] == ' ':
            after += 1
        src = src[:kw] + src[after:]
        path.write_text(src, encoding='utf-8')
        removed += 1
    return removed


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    do_fix = '--fix' in sys.argv
    targets = args or ['lib']
    files: list[pathlib.Path] = []
    for t in targets:
        p = pathlib.Path(t)
        files += sorted(p.rglob('*.dart')) if p.is_dir() else [p]

    if do_fix:
        total = 0
        for path in files:
            n = fix_file(path)
            if n:
                print(f"  {path}: dropped {n} const")
                total += n
        print(f"{len(files)} files, {total} const removed")
        return 0

    violations = 0
    for path in files:
        code = blank_noncode(path.read_text(encoding='utf-8'))
        for a, b in const_spans(code):
            for m in NONCONST.finditer(code[a:b]):
                line = code[:a + m.start()].count('\n') + 1
                expr = m.group(0).strip()
                print(f"  {path}:{line}  non-const `{expr}` inside const constructor")
                violations += 1

    print(f"{len(files)} files checked, {violations} const violation(s)")
    return 1 if violations else 0


if __name__ == '__main__':
    raise SystemExit(main())
