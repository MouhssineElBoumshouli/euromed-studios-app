"""Tiny Dart lexer helpers: find string literals and code spans while
skipping comments. Good enough for this codebase's own source."""


def string_end(s, i):
    """s[i] starts a string literal (optionally after r). Returns end index
    (exclusive) and the list of (start, end) of nested interpolations."""
    raw = False
    if s[i] == 'r':
        raw = True
        i += 1
    q = s[i]
    triple = s.startswith(q * 3, i)
    delim = q * 3 if triple else q
    j = i + len(delim)
    interps = []
    while j < len(s):
        if not raw and s[j] == '\\':
            j += 2
            continue
        if s.startswith(delim, j):
            return j + len(delim), interps
        if not raw and s[j] == '$' and j + 1 < len(s) and s[j + 1] == '{':
            k = code_end(s, j + 2, '}')
            interps.append((j, k + 1))
            j = k + 1
            continue
        if not triple and s[j] == '\n':
            raise ValueError(f'unterminated string at {i}')
        j += 1
    raise ValueError('unterminated string')


def is_string_start(s, i):
    c = s[i]
    if c in '\'"':
        return not (i > 0 and (s[i - 1].isalnum() or s[i - 1] == '_') and s[i - 1] != 'r') or True
    if c == 'r' and i + 1 < len(s) and s[i + 1] in '\'"':
        return i == 0 or not (s[i - 1].isalnum() or s[i - 1] == '_')
    return False


def code_end(s, i, closer):
    """From i inside code, find the index of the matching closer char."""
    pairs = {'(': ')', '[': ']', '{': '}'}
    stack = [closer]
    j = i
    while j < len(s):
        c = s[j]
        if s.startswith('//', j):
            j = s.index('\n', j)
            continue
        if s.startswith('/*', j):
            j = s.index('*/', j) + 2
            continue
        if c in '\'"' or (c == 'r' and j + 1 < len(s) and s[j + 1] in '\'"'
                          and not (s[j - 1].isalnum() or s[j - 1] == '_')):
            j, _ = string_end(s, j)
            continue
        if c in pairs:
            stack.append(pairs[c])
        elif c in ')]}':
            if c != stack[-1]:
                raise ValueError(f'bracket mismatch at {j}: {s[j-40:j+10]!r}')
            stack.pop()
            if not stack:
                return j
        j += 1
    raise ValueError('no closer')


def literals(s):
    """Yield (start, end) of every top-level string literal in s, plus the
    ones nested in interpolations (yielded separately)."""
    j = 0
    out = []
    while j < len(s):
        c = s[j]
        if s.startswith('//', j):
            n = s.find('\n', j)
            j = len(s) if n < 0 else n
            continue
        if s.startswith('/*', j):
            j = s.index('*/', j) + 2
            continue
        if c in '\'"' or (c == 'r' and j + 1 < len(s) and s[j + 1] in '\'"'
                          and not (j > 0 and (s[j - 1].isalnum() or s[j - 1] == '_'))):
            e, interps = string_end(s, j)
            out.append((j, e, interps))
            j = e
            continue
        j += 1
    return out
