#!/usr/bin/env python3
"""Report a signal assigned with both `=' and `<=' in the same always block.

Blocking and non-blocking assignment are two different models of time.
Mixing them on ONE signal in ONE block is never intentional: it makes the
result depend on the order the simulator happens to evaluate statements,
which is exactly the property non-blocking assignment exists to remove.

Deliberately narrow. A blocking assignment to a loop counter or a local
temporary inside a clocked block is ordinary and correct, so this does not
complain about `=' on its own -- only about a signal that gets both.
"""
import re, sys

def strip(src):
    src = re.sub(r'/\*.*?\*/', ' ', src, flags=re.S)
    return '\n'.join(l.split('//')[0] for l in src.split('\n'))

def blocks(src):
    out = []
    for m in re.finditer(r'\balways\b', src):
        i, depth, started = m.end(), 0, False
        for t in re.finditer(r'\b(begin|end|endmodule)\b|;', src[i:]):
            w = t.group(0)
            if w == 'begin':
                depth += 1; started = True
            elif w == 'end':
                depth -= 1
                if started and depth == 0:
                    out.append((m.start(), src[i:i + t.end()])); break
            elif w == ';' and not started:
                out.append((m.start(), src[i:i + t.end()])); break
            elif w == 'endmodule':
                break
    return out

COND = re.compile(r'\b(?:if|while|for|case|casex|casez|repeat)\s*\((?:[^()]|\([^()]*\))*\)')

def assignments(text):
    """(name, op) for each assignment, one line at a time.

    Conditions are removed first: `<=' inside `if (a <= b)' is a
    comparison, not an assignment, and telling them apart by position is
    unreliable. Removing the parenthesised part leaves only statements.
    """
    for line in text.split('\n'):
        line = COND.sub(' ', line)
        m = re.search(r'(?<![\w.])([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?\s*(<=|=)(?!=)', line)
        if m:
            yield m.group(1), m.group(2)

def check(path):
    body = strip(open(path).read())
    found = []
    for pos, text in blocks(body):
        nb, bl = set(), set()
        for name, op in assignments(text):
            (nb if op == '<=' else bl).add(name)
        for name in sorted(nb & bl):
            found.append((body[:pos].count('\n') + 1, name))
    return found

if __name__ == '__main__':
    bad = 0
    for f in sys.argv[1:]:
        for line, name in check(f):
            print("    %s:%d: '%s' is assigned with both '=' and '<=' in one always block"
                  % (f, line, name))
            bad += 1
    sys.exit(1 if bad else 0)
