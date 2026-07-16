#!/usr/bin/env python3
# Strips line/block comments and string/template literals, then checks {}/()/[] balance.
import sys

def strip(s: str) -> str:
    out = []
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        two = s[i:i+2]
        # line comment
        if two == '//':
            while i < n and s[i] != '\n':
                i += 1
            continue
        # block comment
        if two == '/*':
            i += 2
            while i < n and s[i:i+2] != '*/':
                i += 1
            i += 2
            continue
        # string literal (double quote) — also handles Kotlin """" raw and ${} templates
        if c == '"':
            i += 1
            # triple quote
            if s[i:i+2] == '""':
                i += 2
                while i < n and s[i:i+3] != '"""':
                    i += 1
                i += 3
                continue
            while i < n:
                if s[i] == '\\':
                    i += 2
                    continue
                if s[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        # char literal
        if c == "'":
            i += 1
            while i < n:
                if s[i] == '\\':
                    i += 2
                    continue
                if s[i] == "'":
                    i += 1
                    break
                i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)

def balance(code: str):
    pairs = {'}': '{', ')': '(', ']': '['}
    opens = set(pairs.values())
    stack = []
    for ch in code:
        if ch in opens:
            stack.append(ch)
        elif ch in pairs:
            if not stack or stack[-1] != pairs[ch]:
                return False, f"mismatch at '{ch}', stack tail={stack[-3:]}"
            stack.pop()
    return len(stack) == 0, f"unclosed={stack}"

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    raw = f.read()
clean = strip(raw)
ok, msg = balance(clean)
print(f"{path}: balance_ok={ok} ({msg})")
sys.exit(0 if ok else 1)
