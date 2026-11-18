"""Lists every French text in app/lib, as catalogue keys.

A key is the text with each inserted value written {0}, {1}...
Run from the repo root: python3 tools/l10n/extract.py > /tmp/keys.json
"""
import glob, json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from dartlex import literals

ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'app', 'lib')
SKIP = ('core/l10n/',)
IDENT = re.compile(r'\$([A-Za-z_][A-Za-z0-9_]*)')


def unescape(t):
    out, i = [], 0
    while i < len(t):
        if t[i] == '\\' and i + 1 < len(t):
            n = t[i + 1]
            out.append({'n': '\n', 't': '\t'}.get(n, n))
            i += 2
        else:
            out.append(t[i])
            i += 1
    return ''.join(out)


def body(s, start, end, interps, counter):
    """Text of one literal with values as {n}."""
    raw = s[start] == 'r'
    q0 = start + (1 if raw else 0)
    q = s[q0]
    dl = 3 if s.startswith(q * 3, q0) else 1
    a, b = q0 + dl, end - dl
    parts, i = [], a
    for (x, y) in interps:
        parts.append(('t', s[i:x]))
        parts.append(('v', s[x:y]))
        i = y
    parts.append(('t', s[i:b]))
    out = []
    for kind, txt in parts:
        if kind == 'v':
            out.append('{%d}' % counter[0]); counter[0] += 1
        elif raw:
            out.append(txt)
        else:
            # $name values.
            pos = 0
            for m in IDENT.finditer(txt):
                if m.start() > 0 and txt[m.start() - 1] == '\\':
                    continue
                out.append(unescape(txt[pos:m.start()]))
                out.append('{%d}' % counter[0]); counter[0] += 1
                pos = m.end()
            out.append(unescape(txt[pos:]))
    return ''.join(out)


def looks_like_text(k):
    core = re.sub(r'\{\d+\}', '', k)
    if not re.search(r'[A-Za-zÀ-ÿ]{2,}', core):
        return False
    if re.match(r'^[a-z_][A-Za-z0-9_.]*$', k):      # identifiers, keys
        return False
    if k.startswith(('/', 'assets/', 'package:', 'http', 'sb-', 'ES-')) or '://' in k:
        return False
    if re.match(r'^[A-Za-z0-9_.\-]+@', k):
        return False
    if re.search(r'[À-ÿ’]', k) or ' ' in core.strip() or core[:1].isupper():
        return True
    return False


def scan(src, keys, where):
    lits = literals(src)
    i = 0
    while i < len(lits):
        group = [lits[i]]
        while i + 1 < len(lits):
            between = src[group[-1][1]:lits[i + 1][0]]
            between = re.sub(r'//[^\n]*', '', between)
            if between.strip() == '':
                group.append(lits[i + 1]); i += 1
            else:
                break
        counter = [0]
        key = ''.join(body(src, a, b, it, counter) for a, b, it in group)
        if looks_like_text(key):
            keys.setdefault(key, set()).add(where)
        for a, b, it in group:
            for x, y in it:
                scan(src[x + 2:y - 1], keys, where)
        i += 1


def main():
    keys = {}
    for f in sorted(glob.glob(f'{ROOT}/**/*.dart', recursive=True)):
        rel = os.path.relpath(f, ROOT)
        if rel.startswith(SKIP):
            continue
        src = open(f, encoding='utf-8').read()
        scan(src, keys, rel)
    json.dump({k: sorted(v) for k, v in sorted(keys.items())}, sys.stdout,
              ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
