#!/usr/bin/env python3
# =====================================================================
# Render a SymbiYosys counterexample as a cycle-by-cycle table.
#
#   trace.py <trace.vcd> [--mark STEP] [--only sig,...] [--all] [--width N]
#
# ---------------------------------------------------------------------
# WHY THIS EXISTS
#
# The counterexample IS the output of a formal run. A property set that
# fails tells you almost nothing; the trace it hands back tells you
# everything, and reading one is the skill this whole repo is trying to
# build.
#
# gtkwave is the usual answer and `make wave' still opens it. But a
# waveform viewer is a poor fit for the first fortnight: the traces here
# are eight to thirty steps long and six to twenty signals wide, which is
# a table, and a table you can read in a terminal, paste into a commit
# message, and diff against the one you got before your last edit.
#
# ---------------------------------------------------------------------
# WHY IT SAMPLES ON smt_step AND NOT ON THE CLOCK
#
# yosys-smtbmc writes an integer `smt_step' into every trace it produces,
# and that is the BMC step number -- the same number sby quotes when it
# says "failed assertion ... step 10". Sampling on it means the column
# headings in this table are the step numbers in the summary line, with
# no arithmetic in between.
#
# Sampling on the clock instead would work right up until a trace whose
# clock is gated, divided, or (in the induction traces of exercise 06)
# not anchored to time zero at all, and would then quietly be off by one.
# The step counter is what the solver actually reasoned about.
#
# ---------------------------------------------------------------------
# WHY IDENTICAL SIGNALS ARE COLLAPSED BY DEFAULT
#
# A harness has the DUT and the property module watching the same wire,
# so `count', `u_dut.count_o' and `u_props.count' are three names for one
# thing and the raw trace prints all three. On a ten-signal design that is
# thirty rows, and the reader's job -- spot the step where the design went
# wrong -- gets three times harder for no information at all.
#
# So a hierarchical row whose value history is identical to one already
# shown is dropped. Top-level signals are never dropped: they are the
# harness's own ports, they are the vocabulary the exercise text uses, and
# a `rst' column that vanished because it happened to agree with something
# else all trace would be actively misleading -- in an induction trace,
# "rst is low on step 0" is the whole point.
#
# Two distinct HIERARCHICAL signals that agree for the whole of this trace
# still collapse, which is a real if minor loss. The count of what was
# hidden is printed, and `--all' brings it back.
# =====================================================================

import sys

STEP_HINT = "smt_step"


def parse(path):
    """Return (names, steps) where steps is a list of {name: value}."""
    id_of = {}          # vcd identifier -> full signal name
    widths = {}         # full signal name -> bit width
    scope = []
    step_id = None

    with open(path) as fh:
        text = fh.read()

    header, _, body = text.partition("$enddefinitions")

    # Walk the header token-wise: scopes nest, and a $var can appear at
    # any depth.
    tokens = header.split()
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok == "$scope":
            scope.append(tokens[i + 2])
            i += 4
        elif tok == "$upscope":
            if scope:
                scope.pop()
            i += 2
        elif tok == "$var":
            width = int(tokens[i + 2])
            ident = tokens[i + 3]
            name = tokens[i + 4]
            j = i + 5
            # A $var may carry a bit range: `$var wire 4 n0 c [3:0] $end'
            while tokens[j] != "$end":
                j += 1
            full = ".".join(scope[1:] + [name]) if len(scope) > 1 else name
            if name == STEP_HINT:
                step_id = ident
            id_of[ident] = full
            widths[full] = width
            i = j + 1
        else:
            i += 1

    if step_id is None:
        sys.exit(f"{path}: no {STEP_HINT} in this VCD -- is it a sby trace?")

    current = {}
    steps = []
    seen_step = None

    def flush(step_no):
        snap = dict(current)
        snap["__step__"] = step_no
        steps.append(snap)

    for line in body.splitlines():
        line = line.strip()
        if not line or line.startswith("$"):
            continue
        if line.startswith("#"):
            continue
        if line[0] in "bB":
            parts = line.split()
            if len(parts) != 2:
                continue
            val, ident = parts[0][1:], parts[1]
        elif line[0] in "01xXzZ":
            val, ident = line[0], line[1:]
        else:
            continue

        if ident == step_id:
            n = int(val, 2) if set(val) <= set("01") else None
            if n is not None and n != seen_step:
                if seen_step is not None:
                    flush(seen_step)
                seen_step = n
            continue

        name = id_of.get(ident)
        if name is not None:
            current[name] = val

    if seen_step is not None:
        flush(seen_step)

    names = [n for n in id_of.values()
             if n not in (STEP_HINT, "smt_clock") and not n.endswith("smt_clock")]
    # Drop yosys's own bookkeeping. `_witness_' scopes hold the machinery
    # that turns an assertion into something the solver can chew on --
    # anyinit_procdff_111 and friends -- and they are noise in a trace
    # whose entire purpose is to be read by a person.
    names = [n for n in names if "_witness_" not in n and not n.startswith("$")]
    # Drop the clock: every row is sampled at the same point in it, so the
    # column is a constant 1 and says nothing.
    names = [n for n in names if n.split(".")[-1] not in ("clk", "clock", "clk_i")]
    # Preserve declaration order, drop duplicates.
    seen = set()
    ordered = []
    for n in names:
        if n not in seen:
            seen.add(n)
            ordered.append(n)
    return ordered, widths, steps


def fmt(val, width):
    if val is None:
        return "-"
    if set(val) - set("01"):
        return "x" if width == 1 else val[:8]
    n = int(val, 2)
    if width == 1:
        return str(n)
    if width <= 4:
        return str(n)
    return "%0*x" % ((width + 3) // 4, n)


def main():
    args = sys.argv[1:]
    path = None
    mark = None
    only = None
    show_all = False
    per_row = 20

    i = 0
    while i < len(args):
        if args[i] == "--mark":
            mark = int(args[i + 1]); i += 2
        elif args[i] == "--only":
            only = args[i + 1].split(","); i += 2
        elif args[i] == "--all":
            show_all = True; i += 1
        elif args[i] == "--width":
            per_row = int(args[i + 1]); i += 2
        else:
            path = args[i]; i += 1

    if path is None:
        sys.exit("usage: trace.py <trace.vcd> [--mark STEP] [--only a,b] "
                 "[--all] [--width N]")

    names, widths, steps = parse(path)

    if not steps:
        sys.exit(f"{path}: no steps found")

    if only:
        names = [n for n in names
                 if any(n == o or n.split(".")[-1] == o for o in only)]

    hidden = 0
    if not show_all and not only:
        # Shallowest name first, so the top-level `count' is the one kept
        # and `u_dut.count_o' is the one dropped. Top-level rows are
        # exempt from dropping entirely -- see the header.
        order = sorted(range(len(names)), key=lambda i: (names[i].count("."), i))
        seen_hist = {}
        keep = set()
        for i in order:
            name = names[i]
            hist = tuple(st.get(name) for st in steps)
            top = "." not in name
            if hist in seen_hist and not top:
                hidden += 1
            else:
                seen_hist.setdefault(hist, name)
                keep.add(name)
        names = [n for n in names if n in keep]

    label_w = max([len(n) for n in names] + [6])
    cell_w = max([4] + [(widths.get(n, 1) + 3) // 4 for n in names])

    print()
    for start in range(0, len(steps), per_row):
        chunk = steps[start:start + per_row]

        head = " " * (label_w + 2)
        for s in chunk:
            n = s["__step__"]
            tag = f"{n}*" if (mark is not None and n == mark) else str(n)
            head += tag.rjust(cell_w + 1)
        print(head)
        print("  " + "-" * (label_w + (cell_w + 1) * len(chunk)))

        for name in names:
            row = "  " + name.ljust(label_w)
            w = widths.get(name, 1)
            for s in chunk:
                row += fmt(s.get(name), w).rjust(cell_w + 1)
            print(row)
        print()

    if mark is not None:
        print(f"  * step {mark} is where the assertion failed.")
    if hidden:
        print(f"  ({hidden} row{'s' if hidden > 1 else ''} hidden as duplicates "
              f"of a row above -- `--all' shows them.)")
    print()


if __name__ == "__main__":
    main()
