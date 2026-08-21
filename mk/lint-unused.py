#!/usr/bin/env python3
"""Report nets that are declared inside a module and never mentioned again.

A declaration whose line carries the marker `lint-unused-ok` is skipped.
That exists for given-to-the-student code -- an exercise stub may hand
over storage that nothing reads until the exercise is done -- and not as
a way to quiet a real finding. If you are reaching for it in your own
code, delete the signal instead.

Nets only, not localparams. An unused constant costs no gates, and every
stub in this repo declares constants the exercise has not used yet, so
checking them means eight waiver markers to catch something harmless.

Deliberately syntactic. The obvious approach -- diff yosys's wire list
across `opt_clean -purge' -- does not work, because opt_clean also removes
redundant ALIASES. `wire [1:0] region = adr[7:6];' is read four times and
still disappears, merged into the signal it aliases. Wire-disappearance
answers a different question from the one we are asking.

Ports are excluded. An unused input is a legitimate design choice (a slave
that ignores SEL, say) and flagging rst_i on a combinational module would
be noise.
"""
import re, sys

DECL = re.compile(
    r'^[ \t]*(?:wire|reg|integer|genvar)\b'      # storage class
    r'(?:[ \t]+signed)?'
    r'(?:[ \t]*\[[^\]]*\])?'                     # optional packed range
    r'[ \t]+([^;=]+?)'                           # the name list
    r'[ \t]*(?:=|;|\[)', re.M)

def strip(src):
    src = re.sub(r'/\*.*?\*/', ' ', src, flags=re.S)
    return '\n'.join(l.split('//')[0] for l in src.split('\n'))

def ports(src):
    m = re.search(r'\bmodule\b[^;]*?\((.*?)\)\s*;', src, re.S)
    if not m:
        return set()
    return set(re.findall(r'([A-Za-z_]\w*)\s*(?=[,)\n]|$)', m.group(1)))


def reads(body, name):
    """Mentions that are not the target of an assignment."""
    n = 0
    for line in body.split('\n'):
        # split each statement at its assignment operator; the left side is
        # a write, everything right of it (and every condition) is a read.
        for stmt in re.split(r'[;,]', line):
            m = re.match(r'\s*(?:assign\s+)?([A-Za-z_]\w*)\s*'
                         r'(?:\[[^\]]*\])?\s*(<=|=)(?!=)', stmt)
            if m and m.group(1) == name:
                rhs = stmt[m.end():]
                n += len(re.findall(r'(?<![\w.])' + re.escape(name) + r'\b', rhs))
            else:
                n += len(re.findall(r'(?<![\w.])' + re.escape(name) + r'\b', stmt))
    return n

def check(path):
    raw  = open(path).read()
    body = strip(raw)
    skip = ports(body)
    waived = {n for n, l in enumerate(raw.split('\n'), 1) if 'lint-unused-ok' in l}
    found = []
    for m in DECL.finditer(body):
        for name in m.group(1).split(','):
            name = name.strip().split('[')[0].strip()
            if not re.fullmatch(r'[A-Za-z_]\w*', name or '') or name in skip:
                continue
            line = body[:m.start()].count('\n') + 1
            if line in waived:
                continue
            uses = len(re.findall(r'(?<![\w.])' + re.escape(name) + r'\b', body))
            if uses <= 1:
                found.append((body[:m.start()].count('\n') + 1, name, 'never used'))
            elif reads(body, name) <= 1:
                found.append((body[:m.start()].count('\n') + 1, name, 'written but never read'))
    return found

if __name__ == '__main__':
    bad = 0
    for f in sys.argv[1:]:
        for line, name, why in check(f):
            print("    %s:%d: '%s' is %s" % (f, line, name, why))
            bad += 1
    sys.exit(1 if bad else 0)
