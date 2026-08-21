#!/usr/bin/env python3
"""Report module-level `integer' loop variables used by only one block.

A loop counter shared between two always blocks is a multiply-driven
register, which yosys reports and mk/lint.sh already fails on. This
catches the state one step earlier: a counter that is declared where it
COULD be shared but currently is not. Moving it inside the block that
uses it makes the bug impossible rather than merely detected.

The two halves of that advice go together: a declaration inside
begin/end requires the block to be NAMED. iverilog accepts an unnamed
one (it is a SystemVerilog relaxation); yosys does not see the
declaration at all, decides the name is a wire, and then complains that
a for-loop is driving a wire -- an error that points nowhere near the
real problem. So the message says both.

`genvar' is deliberately not checked. A genvar belongs to generate
scope, and telling anyone to move one inside an always block would be
wrong.
"""
import re, sys

def strip(src):
    src = re.sub(r'/\*.*?\*/', ' ', src, flags=re.S)
    return '\n'.join(l.split('//')[0] for l in src.split('\n'))

def blocks(src):
    """(kind, text) for each always/initial block, begin/end matched."""
    out = []
    for m in re.finditer(r'\b(always|initial)\b', src):
        i, depth, started = m.end(), 0, False
        for t in re.finditer(r'\b(begin|end|endmodule)\b|;', src[i:]):
            w = t.group(0)
            if w == 'begin':
                depth += 1; started = True
            elif w == 'end':
                depth -= 1
                if started and depth == 0:
                    out.append((m.group(1), src[i:i + t.end()])); break
            elif w == ';' and not started:
                out.append((m.group(1), src[i:i + t.end()])); break
            elif w == 'endmodule':
                break
    return out

def check(path):
    body = strip(open(path).read())
    bl = blocks(body)
    found = []
    for m in re.finditer(r'^\s{0,8}integer\s+([A-Za-z_]\w*)\s*;', body, re.M):
        name = m.group(1)
        pat = r'(?<![\w.])' + re.escape(name) + r'\b'
        inside = [b for b in bl if re.search(pat, b[1])]
        total  = len(re.findall(pat, body))
        in_blk = sum(len(re.findall(pat, b[1])) for b in inside)
        # every use is inside one block, and the declaration is outside it
        if len(inside) == 1 and in_blk == total - 1:
            found.append((body[:m.start()].count('\n') + 1, name, inside[0][0]))
    return found

if __name__ == '__main__':
    bad = 0
    for f in sys.argv[1:]:
        for line, name, kind in check(f):
            print("    %s:%d: '%s' is only used by one %s block -- declare it there"
                  % (f, line, name, kind))
            bad += 1
    sys.exit(1 if bad else 0)
