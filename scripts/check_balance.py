#!/usr/bin/env python3
"""
Balance-checks every .swift file's braces/parens.

There's no Xcode/swiftc available in the shell this project is edited
from (see HANDOFF.md's "read this first" section), so this is the one
sanity check that can run after every hand-written change: it can't
catch type errors, availability errors, or anything the real Swift
compiler would — only a genuinely mismatched {}/(). Run it after any
batch of .swift edits, before telling JD to rebuild:

    python3 scripts/check_balance.py "Chalk That NFL"
"""
import sys, os

def check_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    depth_curly = 0
    depth_paren = 0
    i = 0
    n = len(text)
    in_line_comment = False
    in_block_comment = False
    in_string = False
    string_char = None
    while i < n:
        c = text[i]
        nxt = text[i+1] if i+1 < n else ''
        if in_line_comment:
            if c == '\n':
                in_line_comment = False
            i += 1
            continue
        if in_block_comment:
            if c == '*' and nxt == '/':
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue
        if in_string:
            if c == '\\':
                i += 2
                continue
            if c == string_char:
                in_string = False
            i += 1
            continue
        if c == '/' and nxt == '/':
            in_line_comment = True
            i += 2
            continue
        if c == '/' and nxt == '*':
            in_block_comment = True
            i += 2
            continue
        if c == '"':
            in_string = True
            string_char = '"'
            i += 1
            continue
        if c == '{':
            depth_curly += 1
        elif c == '}':
            depth_curly -= 1
        elif c == '(':
            depth_paren += 1
        elif c == ')':
            depth_paren -= 1
        i += 1
    return depth_curly, depth_paren

root = sys.argv[1] if len(sys.argv) > 1 else "Chalk That NFL"
bad = []
count = 0
for dirpath, dirnames, filenames in os.walk(root):
    for fn in filenames:
        if fn.endswith('.swift'):
            count += 1
            path = os.path.join(dirpath, fn)
            dc, dp = check_file(path)
            if dc != 0 or dp != 0:
                bad.append((path, dc, dp))

if bad:
    print(f"UNBALANCED FILES ({len(bad)}):")
    for path, dc, dp in bad:
        print(f"  {path}: curly={dc} paren={dp}")
    sys.exit(1)
else:
    print(f"All {count} Swift files balanced.")
