#!/usr/bin/env python3
"""Rewrite inline `TextStyle(...)` into `AppTypography` roles.

Maps a literal `fontSize` onto the nearest role in the Farvixo scale, carries
`color` / `fontWeight` / `height` / `letterSpacing` across, and leaves anything
it cannot understand untouched — a partial migration you can verify beats a
clever one you cannot.

    python3 tool/migrate_textstyle.py lib/features/tools/tools_screen.dart
    python3 tool/migrate_textstyle.py --dry-run lib/features/settings

Always re-run tool/check_balance.py and tool/check_const.py afterwards: dropping
`const` is this script's job, and getting it wrong is the one failure mode that
does not show up until compile time.
"""

from __future__ import annotations

import pathlib
import re
import sys

# fontSize -> (role, is_dense_role)
SIZE_TO_ROLE = [
    (44, 'displayLarge'), (36, 'displayMedium'), (30, 'displaySmall'),
    (28, 'headlineLarge'), (26, 'metric'), (24, 'headlineMedium'),
    (22, 'headlineSmall'), (20, 'titleLarge'), (19, 'titleLarge'),
    (18, 'titleLarge'), (17, 'titleLarge'), (16, 'titleMedium'),
    (15.5, 'titleMedium'), (15, 'titleSmall'), (14.5, 'titleSmall'),
    (14, 'titleSmall'), (13.5, 'bodyMedium'), (13, 'bodyMedium'),
    (12.5, 'bodySmall'), (12, 'labelMedium'), (11.5, 'labelSmall'),
    (11, 'labelSmall'), (10.5, 'caption'), (10, 'caption'),
    (9.5, 'caption'), (9, 'caption'), (8.5, 'overline'), (8, 'badge'),
]

WEIGHT_TO_TOKEN = {
    '400': 'regular', '500': 'medium', '600': 'semibold',
    '700': 'bold', '800': 'extrabold', '900': 'black',
}


def nearest_role(size: float) -> str:
    return min(SIZE_TO_ROLE, key=lambda r: abs(r[0] - size))[1]


def split_args(body: str) -> list[str]:
    """Split a Dart argument list on top-level commas."""
    args, depth, current = [], 0, ''
    in_str, quote = False, ''
    i = 0
    while i < len(body):
        c = body[i]
        if in_str:
            current += c
            if c == '\\':
                current += body[i + 1] if i + 1 < len(body) else ''
                i += 2
                continue
            if c == quote:
                in_str = False
            i += 1
            continue
        if c in '"\'':
            in_str, quote = True, c
            current += c
        elif c in '([{':
            depth += 1
            current += c
        elif c in ')]}':
            depth -= 1
            current += c
        elif c == ',' and depth == 0:
            args.append(current.strip())
            current = ''
        else:
            current += c
        i += 1
    if current.strip():
        args.append(current.strip())
    return args


def find_textstyles(src: str) -> list[tuple[int, int, str]]:
    """Locate every `TextStyle(...)` call: (start, end, argument body)."""
    out = []
    for m in re.finditer(r'\bTextStyle\(', src):
        i, depth = m.end(), 1
        in_str, quote = False, ''
        while i < len(src) and depth:
            c = src[i]
            if in_str:
                if c == '\\':
                    i += 2
                    continue
                if c == quote:
                    in_str = False
            elif c in '"\'':
                in_str, quote = True, c
            elif c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
            i += 1
        if depth == 0:
            out.append((m.start(), i, src[m.end():i - 1]))
    return out


def convert(src: str) -> tuple[str, int, int]:
    """Returns (new source, converted count, skipped count)."""
    edits, skipped = [], 0

    for start, end, body in find_textstyles(src):
        args = split_args(body)
        named = {}
        ok = True
        for a in args:
            m = re.match(r'^(\w+)\s*:\s*(.+)$', a, re.S)
            if not m:
                ok = False
                break
            named[m.group(1)] = m.group(2).strip()
        if not ok or 'fontSize' not in named:
            skipped += 1
            continue

        try:
            size = float(named['fontSize'])
        except ValueError:
            skipped += 1  # e.g. `size * 0.4` — proportional, leave alone
            continue

        role = nearest_role(size)
        call = [f'AppTypography.{role}(context']

        if 'color' in named:
            call.append(f"color: {named['color']}")

        weight = named.get('fontWeight')
        if weight:
            wm = re.match(r'FontWeight\.w(\d00)$', weight)
            if wm:
                call.append(f'weight: FontWeights.{WEIGHT_TO_TOKEN[wm.group(1)]}')
            else:
                skipped += 1
                continue

        # Anything the role cannot express stays as a copyWith tail.
        tail = {k: v for k, v in named.items()
                if k not in ('fontSize', 'color', 'fontWeight')}
        text = ', '.join(call) + ')'
        if tail:
            inner = ', '.join(f'{k}: {v}' for k, v in tail.items())
            text += f'.copyWith({inner})'

        # A const constructor cannot hold a context-bound call.
        prefix_start = max(0, start - 8)
        prefix = src[prefix_start:start]
        drop_const = prefix.rstrip().endswith('const')
        edits.append((start, end, text, drop_const, prefix_start))

    if not edits:
        return src, 0, skipped

    out, last = [], 0
    for start, end, text, drop_const, prefix_start in edits:
        cut = start
        if drop_const:
            cut = src.rindex('const', prefix_start, start)
        out.append(src[last:cut])
        out.append(text)
        last = end
    out.append(src[last:])
    return ''.join(out), len(edits), skipped


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry = '--dry-run' in sys.argv
    if not args:
        print(__doc__)
        return 2

    files: list[pathlib.Path] = []
    for a in args:
        p = pathlib.Path(a)
        files += sorted(p.rglob('*.dart')) if p.is_dir() else [p]

    total_c = total_s = 0
    for f in files:
        src = f.read_text(encoding='utf-8')
        new, c, s = convert(src)
        total_c += c
        total_s += s
        if c and not dry:
            f.write_text(new, encoding='utf-8')
        if c or s:
            print(f'  {f}: {c} converted, {s} skipped')

    print(f'{total_c} converted, {total_s} skipped'
          f'{" (dry run)" if dry else ""}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
