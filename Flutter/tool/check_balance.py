import pathlib, sys

def scan(src):
    """Char-level scanner: skips strings (raw, multiline, interpolated) and
    comments properly, then checks bracket balance."""
    i, n = 0, len(src)
    depth = {'(': 0, '[': 0, '{': 0}
    close = {')': '(', ']': '[', '}': '{'}
    interp = []  # stack of brace depths where ${ } interpolation opened
    while i < n:
        c = src[i]
        # comments
        if c == '/' and i + 1 < n:
            if src[i+1] == '/':
                while i < n and src[i] != '\n': i += 1
                continue
            if src[i+1] == '*':
                i += 2
                while i + 1 < n and not (src[i] == '*' and src[i+1] == '/'): i += 1
                i += 2
                continue
        # strings
        if c in '"\'' or (c == 'r' and i + 1 < n and src[i+1] in '"\''):
            raw = c == 'r'
            if raw: i += 1
            q = src[i]
            triple = src[i:i+3] in ('"""', "'''")
            term = src[i:i+3] if triple else q
            i += 3 if triple else 1
            while i < n:
                if not raw and src[i] == '\\': i += 2; continue
                if not raw and src[i] == '$' and i+1 < n and src[i+1] == '{':
                    # interpolation: fall back to counting inside
                    i += 2
                    d = 1
                    while i < n and d:
                        if src[i] == '{': d += 1
                        elif src[i] == '}': d -= 1
                        i += 1
                    continue
                if src[i:i+len(term)] == term: i += len(term); break
                if not triple and src[i] == '\n': break
                i += 1
            continue
        if c in depth: depth[c] += 1
        elif c in close: depth[close[c]] -= 1
        i += 1
    return depth

bad = 0; total = 0
targets = sys.argv[1:] or ['lib']
files = []
for t in targets:
    p = pathlib.Path(t)
    files += list(p.rglob('*.dart')) if p.is_dir() else [p]
for p in sorted(files):
    total += 1
    d = scan(p.read_text(encoding='utf-8'))
    if any(d.values()):
        print(f"  UNBALANCED {p}: parens {d['(']} brackets {d['[']} braces {d['{']}")
        bad += 1
print(f"{total} files checked, {bad} unbalanced")
