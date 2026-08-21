# Coding style

Short version: **Verilog-2001**, lowRISC conventions where they apply,
4-space indent — the same as the Wishbone repository, and for the same
reasons. This document covers what is different because the code is
property files rather than designs.

The general guide is the
[lowRISC Verilog Coding Style Guide][lowrisc]. Where this document is
silent, assume lowRISC.

[lowrisc]: https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md

## Verilog-2001, with the formal extensions

The designs here are plain Verilog-2001. `assert`, `assume` and `cover`
are not — they arrive via `read -formal`, which is what makes yosys accept
them, along with `$past` and `(* anyconst *)`.

That is the whole extension surface used in this repo, and it is
deliberately small. `$onehot`, `$stable`, `$rose`, sequences and `|=>` all
exist in SystemVerilog and none of them appear here:

| instead of | this repo writes |
|---|---|
| `$onehot(d)` | `d != 0 && (d & (d-1)) == 0` |
| `$stable(x)` | `x == $past(x)` |
| `$rose(x)` | `x && !$past(x)` |
| `a \|=> b` | `if ($past(a)) assert(b)` |

The bit-twiddling identity for one-hot is worth knowing anyway:
subtracting one flips the lowest set bit to zero and sets everything below
it, so ANDing with the original clears exactly that bit and keeps every
other. Zero means there were no others.

The reason is the same as the Wishbone repo's: the interesting parts of
SystemVerilog do not survive every toolchain, and a property file that
runs everywhere is worth more than one that reads slightly better. Nothing
here needs a construct beyond the four above.

## Naming

| thing | style | example |
|---|---|---|
| module, file | `lower_snake_case`, file named for the module | `fifo_ptrs.v` |
| signal, instance | `lower_snake_case` | `skid_valid` |
| parameter, localparam | `UPPER_SNAKE_CASE` | `MAX_WAIT`, `DEPTH` |
| **formal-only signal** | **`f_` prefix** | `f_past_valid`, `f_wcount` |

Design ports carry `_i` / `_o`. Property module ports do not — they are
observers, not participants, and giving them directions suggests they
drive something.

### The `f_` prefix earns its keep

Anything that exists only for the proof gets `f_`. Counters, tracked
values, history registers, observation outputs.

It is not decoration. In a trace, `f_` tells you instantly which rows are
the design and which are your bookkeeping — and when a counterexample is
your property file's fault rather than the design's, which happens more
often than anyone expects, those rows are where you look. Exercise 10's
`f_outcount <= f_incount` produced a counterexample entirely about two
`f_` counters wrapping, with nothing wrong in the design at all.

It also makes a formal observation port obvious for what it is:

```verilog
output wire [DW-1:0] f_skid_data_o,     // drives nothing; for properties only
```

## File layout

Three kinds of file, and they are kept separate on purpose.

```
exercises/NN-name/
    <design>.v      or dut/good.v + dut/badN_*.v
    props.v         the property set -- what you write
    formal_top.v    the harness that bolts one to the other
    prove.sby       task definitions
    Makefile
```

The harness never changes when the design under test does, which is why
every DUT in a `dut/` directory declares the **same module name**. That is
what lets `prove.sby` swap one for another with a single `read` line and
leaves the exercise with exactly one variable in it.

Every synthesisable file gets `` `default_nettype none `` at the top and
`` `default_nettype wire `` at the bottom, property files included. A
typo'd signal name becoming a silent 1-bit wire is bad in a design and
worse in a property, where the result is a proof about something you did
not write.

## Property files

### Structure

In this order, with a banner comment between sections:

1. `initial assume(rst)` and `f_past_valid`
2. bookkeeping — counters, history registers, `anyconst` declarations
3. **assumptions**, numbered `A1`, `A2`, …
4. **assertions**, numbered `S1`, `S2`, … (or `C1`… where they are about
   contents)
5. **cover** statements

Assumptions before assertions, always, and never interleaved. A reader has
to be able to see the entire environment model in one place before
believing anything below it — the whole question about a property set is
"what did this take for granted", and an assumption buried between two
assertions is the one nobody audits.

### Number the properties

`A2`, `S4`, `C7`. They get referred to — in comments, in commit messages,
in the exercise text — and "the third assertion" stops being true the
moment somebody adds one.

### Every property gets a comment saying what it catches

```verilog
// S2. No grant to a master that was not asking.
//
//     Against $past(req), not req. The grant is registered...
```

Not what it says — the code says that. What it is **for**, which broken
design it catches, and any trap in writing it. A property whose comment
cannot name something it catches is a property to be suspicious of.

### Gate every assertion on `f_past_valid`

At step 0 the design has not been through a reset edge, so its registers
hold arbitrary values. Asserting anything about them proves nothing and
generates counterexamples that cannot happen.

### Write properties from the specification, not from the RTL

The strongest rule here, and the easiest to break while staring at the
code you are verifying.

A property file is a **second, independent statement** of what the design
must do. The proof is that the two agree. Derive it from the design and it
cannot disagree, so it checks nothing.

The concrete version is exercise 05: a watchdog whose counter is too
narrow to reach its timeout. Give the property file a counter of the same
width — "to match" — and the property reproduces the bug and passes.
Property counters are sized from what the **specification** talks about.

### Cover statements are not optional

Every property file here ships them, and at least one must be **deep** —
reachable only near the end of the unrolling. A cover set that is all
shallow passes at every depth and will never once warn you that the depth
is wrong.

Cover states the design is *supposed* to reach, never bugs.
`cover(count > DEPTH)` fails on a correct design too, which makes it an
assertion written inside out. The point of a cover statement is that it
keeps working after the bug is fixed.

## Designs

Ordinary Verilog-2001, plus two rules that come from being verified.

**Synchronous, active-high reset.** As in the Wishbone repo. There is not
one asynchronous reset here and there should not be.

**One bug per broken DUT, and say where it is.** Every file in a `dut/`
directory is a copy of `good.v` with one thing changed, marked `// BUG:`,
and a header explaining what the bug does *and why it is plausible* —
which test it survives, why somebody would write it. A broken DUT that is
obviously broken teaches nothing; the ones worth having are the ones that
pass a testbench.

## Testing the tests

Everything below is the same instinct as the Wishbone repo's
`make lint-selftest`, and it matters more here, because a formal harness
that has stopped working does not go quiet — it reports verdicts, which is
also what it does when it is fine.

### Mutation testing is the structure, not a discipline

Each exercise ships one correct design and several broken ones, and a
property set is finished only when it passes the first and fails all the
rest. That is mutation testing built into the directory layout: a property
that has never been seen to fail is decoration, and here every one of them
has been seen to fail on a named DUT.

The broken DUTs are hand-written rather than generated, because a
readable bug with a plausible story is worth more than a mechanical one.

### The bugs in one exercise should need different kinds of property

Exercise 10 is the clearest case:

| bug | needs |
|---|---|
| drops beats | a data property |
| duplicates beats | a counting property |
| withdraws an offer | a protocol property |

No one property catches two of them. That is deliberate, and it is what
stops a student passing an exercise with a single lucky assertion.

### `ERROR` is not `FAIL`

Most tasks in this repo are *supposed* to fail, so a property file that
does not compile would light up green across four exercises in five.
`mk/run.sh` therefore parses the verdict out of sby's summary rather than
using its exit status, which cannot tell a broken proof from a broken
build.

This is not hypothetical. It is what the first version did, and it went
unnoticed for several exercises because the output looked like progress.

### The harness self-tests before it judges you

`mk/selftest.sh` checks that `mk/run.sh` still tells `pass`, `fail`,
`unknown` and `error` apart — in **both** directions, so a runner that
said "pass" to everything would be caught too. `make` runs it first and
stops if it fails.

It has been seen to fail. Breaking `run.sh` so that ERROR reads as FAIL
makes it report exactly that, which is the only evidence that it works.

## Measure, do not assume

The Wishbone repo's habit, and it earned its keep here three times:

- **Exercise 03** claimed an exact-timing assertion made a bounded-response
  one redundant. It does not: exact timing is conditional on the answer
  arriving, so a slave that never answers satisfies it. The exercise gained
  a liveness property and a paragraph on safety versus liveness.
- **Exercise 06** warned that small designs let k-induction close by
  exhaustion, and implied it applied there. Checked at three depths: it
  does not — the effect is real, but on a 4-bit counter, not this FIFO. The
  warning now says what was measured.
- **Exercise 08** claimed cover would catch an over-strong fairness
  assumption. It does not. That assumption deletes a behaviour over time
  rather than a state, so every cover statement still passes. The corrected
  version is a better lesson than the original claim.

If a comment in this repo states a number or a consequence, it was run.

## Formatting

- 4-space indent, no tabs.
- 80-ish column soft limit.
- Align port declarations and runs of related assignments where it helps.
- Comments explain *why*. The code already says what.

## Toolchains this is tested against

| tool | version |
|---|---|
| yosys | 0.68 (yowasp) |
| SymbiYosys | as shipped with the above |
| z3 | 5.1.0 (`pip install z3-solver`) |

Any SMT solver SymbiYosys supports will do — boolector and yices are both
faster than z3 on this kind of problem. See the README for installation,
including the two shims a yowasp install needs.
