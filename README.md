# Getting your head around formal verification

A worked course in formal methods for Verilog, built around eleven
exercises that each ship one correct design, several broken ones, and a
harness that checks you can tell them apart.

You write the properties. The solver tells you whether they are any good —
and it is deliberately nasty about the things that are easy to get wrong
and hard to notice, because in this subject the failure modes are quiet.

---

## Why formal verification is confusing, and what fixes it

Almost every introduction starts the same way: here is `assert`, here is
`assume`, here is `cover`, now write some properties. Twenty minutes later
you have a file full of green ticks and no idea whether any of them mean
anything.

That is not a gap in your understanding. It is the actual difficulty of
the subject, and it has a name. **The failure mode of formal verification
is not a wrong answer — it is a right-looking answer to a question you did
not realise you were asking.**

- `assert` too little and the solver has nothing to break, so it passes.
- `assume` too much and the solver cannot build the trace that would
  expose the bug, so it passes.
- Set the depth too shallow and the bug is beyond the horizon, so it
  passes.
- Ask for a proof and get `UNKNOWN`, which is not failure and not success
  and is where most people give up.

Every one of those prints a clean run. None of them prints a warning. And
a PASS that means nothing is word-for-word identical to a PASS that means
everything.

So the exercises here are ordered by **the failure**, not by the feature
list. Each one puts you in a position where the next idea is the obvious
answer, and each one is checked against designs that are broken in
specific ways, so a property set that proves nothing is caught by the
harness rather than believed.

Read [`docs/formal-crib-sheet.md`](docs/formal-crib-sheet.md) once, then
come back to it whenever a run says something you did not expect. Section
2 explains what the tasks in an exercise actually are, and section 13 is a
symptom-to-cause table.

[`docs/style.md`](docs/style.md) is the coding style — Verilog-2001,
lowRISC conventions, and the conventions specific to property files.

---

## Getting set up

You need **yosys**, **SymbiYosys** and an **SMT solver**, plus
**verilator** for `make lint`.

The easiest route on any platform is the prebuilt
[OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build), a single
download containing all three. Add it to `PATH` and everything here works
with a bare `make`.

Otherwise, via pip:

```sh
pip install yowasp-yosys z3-solver
sudo apt install verilator          # or brew install verilator
```

`verilator` is only used by `make lint`, which skips itself and says so if
it is missing — but it is the check that lint mainly exists for, so it is
worth having.

`yowasp-yosys` brings SymbiYosys with it. This installs the binaries under
`yowasp-` names, so tell make about it:

```sh
make SBY=yowasp-sby
```

### One wrinkle with the pip install

SymbiYosys shells out to `yosys` and `yosys-smtbmc` by those exact names,
whatever it is called itself. A yowasp install has neither, so every task
dies with `command not found` before any solving happens. Two shims fix
it:

```sh
mkdir -p ~/.local/bin
printf '#!/bin/sh\nexec yowasp-yosys "$@"\n'        > ~/.local/bin/yosys
printf '#!/bin/sh\nexec yowasp-yosys-smtbmc "$@"\n' > ~/.local/bin/yosys-smtbmc
chmod +x ~/.local/bin/yosys ~/.local/bin/yosys-smtbmc
```

Those two are sufficient — checked, not guessed. `yosys-abc` is only
needed for the `abc` engines, which this repo does not use, and
`yosys-witness` is not called for any trace here.

The first `yowasp-*` command of a session prints *"Preparing to run… this
might take a while"* while it unpacks the WASM build. That is once, not
per invocation.

### How to run an exercise

```sh
cd exercises/01-first-assertions
make               # every task with its verdict checked, then the lint
make run           # just the tasks
make lint          # just the lint
make good          # just that one task, with sby's own output
make trace TASK=bad1   # the counterexample, as a table
make wave  TASK=bad1   # the same thing in gtkwave
make solution      # the reference property set
make clean
```

`make` fails loudly with a list of which tasks gave the wrong verdict and
why. `make solution` should always pass — if it does not, the harness is
broken, not you.

### `make lint`, and why the right verdicts are not enough

The tasks ask whether your properties get the right answers. The lint asks
whether the Verilog you wrote says what you meant — a different question,
and there is a whole class of bug living in the gap.

The one it mainly exists for is a **narrowed property**:

```verilog
wire       changed = gray ^ old_gray;      // 1 bit, wanted 4
assert((changed & (changed - 1)) == 0);    // "exactly one bit changed"
```

`changed` holds bit 0 and nothing else, so the assertion is true of both
values it can hold. It **can never fail** — against any design, ever. Every
task still runs, the broken designs it was meant to catch sail through,
and nothing in a verdict distinguishes that from a property that is
genuinely satisfied. In a design a width bug misbehaves; in a property
file it goes quiet.

It also promotes a warning yosys does not treat as fatal:

```verilog
old_grey <= grey;      // neither name declared; yosys invents both
```

`` `default_nettype none `` is supposed to make that a compile error. It
does not — yosys warns and carries on, leaving the real `old_gray` never
assigned while the line appears to update it.

`make lint-selftest` checks the lint still catches what it claims, using
the fixtures in `mk/lint-selftest/` — one file per bug, plus one with
nothing wrong. A lint that has quietly stopped working reports "clean",
which is also what it says when your file is fine.

**Read the specification first.** Every exercise's `props.v` opens with a
numbered `THE SPECIFICATION` block — the contract, stated before any hints
about how to write it. Where the block and the surrounding commentary
disagree, the block binds. It is the thing to argue with when you are
deciding whether some design in `dut/` ought to fail.

**What those tasks are.** `good`, `bad1`, `cover` and the rest are defined
in the exercise's `prove.sby`, and they mostly run *the same files*. Two
things vary: which design is read — every design in a `dut/` directory
declares the same module name, so swapping one for another is one line —
and which **mode** sby runs in.

| mode | the solver hunts for | it ignores |
|---|---|---|
| `bmc` | a trace that **breaks** an `assert` | your `cover` statements |
| `cover` | a trace that **reaches** each `cover` | your `assert` statements |
| `prove` | both halves of an induction proof | your `cover` statements |

So `make cover` is not a second opinion on your assertions — in that mode
they are not checked at all. It asks the opposite question, and an
unreachable cover statement is an alarm rather than a success. That is
what exercises 04 and 05 are about, and
[§2 of the crib sheet](docs/formal-crib-sheet.md) has the longer version.

The exercise's `Makefile` says what verdict each task *should* give:

```make
TASKS := good:pass bad1:fail bad2:fail bad3:fail cover:pass
```

Your property set is finished when every verdict matches — passing the
correct design **and failing every broken one**. `fail as expected` is
good news.

There are top-level versions: `make` runs the harness self-test, every
exercise, then the lint; `make solutions` and `make lint-solutions` do the
same against the references; `make selftest` and `make lint-selftest` are
the two self-tests on their own.

**On a fresh clone, `make` at the top level reports mostly FAIL.** That is
correct. The property files are stubs, so the broken designs pass, and
passing a broken design is exactly the wrong verdict. Filling them in is
the course.

### How long it takes

The whole suite against the references is about a minute and a half on the
yowasp/WASM build. A native yosys with boolector or yices is several times
faster. Individual exercises are seconds, except exercise 07, which is
about thirty because proving data integrity means proving the absence of a
counterexample rather than finding one.

---

## The exercises

| | Exercise | The failure it puts you in front of | What you meet |
|---|---|---|---|
| 00 | worked example | — read this one, do not write it | `assert`/`assume`/`cover`, and vacuity |
| 01 | first assertions | asserting the answer is *plausible* | exhaustive combinational proof |
| 02 | reasoning about time | "every transition is legal" is a third of a spec | `$past`, `f_past_valid` |
| 03 | assuming the environment | the correct design fails | `assume`, safety vs liveness |
| 04 | cover and vacuity | a hollow proof, and how to catch one | `cover` as an alarm |
| 05 | BMC is not proof | the bug past the horizon | depth, and what PASS means |
| 06 | inductive invariants | `UNKNOWN`, and the impossible state | `mode prove`, strengthening |
| 07 | abstraction | data integrity without a shadow model | `$anyconst` |
| 08 | liveness and fairness | starvation, invisible to safety | bounded liveness |
| 09 | equivalence | the right answer, one clock late | miters, latency |
| 10 | capstone: skid buffer | all of it at once, proved unboundedly | everything |

Every exercise ships a correct design and several broken ones. **A
property set is finished only when it passes the first and fails all the
rest** — which makes mutation testing the shape of the repository rather
than a discipline to remember. A property that has never been seen to fail
is decoration, and every property in `solutions/` has been seen to fail on
a named design.

---

### 00 — worked example

`exercises/00-worked-example/` · nothing to write

A saturating counter that does not saturate, and a fully commented
property file that catches it. Five tasks, and the fourth is the one to
sit with:

```
  buggy          fail     as expected
  fixed          pass     as expected
  cover          pass     as expected
  vacuous        pass     as expected      <- the same bug, now invisible
  vacuous_cover  fail     as expected      <- and this is how you catch it
```

`vacuous` is the identical broken counter with one extra assumption — a
plausible-looking one, of the sort that gets added to make a stubborn
proof close. It passes. The bug is not fixed, hidden, or worked around; it
is simply in a part of the state space the solver was told not to visit.

Run `make trace TASK=buggy` and read the table next to the crib sheet. Do
not move on until every row makes sense.

### 01 — your first assertions

An 8-bit priority encoder: `idx` names the lowest set bit, `vld` says
whether there was one.

Combinational, so `depth 1` is a *complete* proof — there is no deeper for
a bug to hide in. Enjoy it; from 02 onwards that stops being true.

**Watch for:** it is easy to catch the encoder with `vld` stuck high and
the one with a typo in its table, and let through the one that returns the
*highest* set bit. "`idx` points at a bit that is actually set" is true of
that one too. Priority is a claim about the bits it did **not** pick, and
you have to say so.

This is the commonest shape of a weak property: asserting that the answer
is plausible rather than that it is the answer.

### 02 — reasoning about time

A 4-bit Gray counter. Exactly one bit changes per step, which is why Gray
codes are what you put across a clock domain crossing.

**Watch for:** two of the four broken designs make nothing but legal Gray
steps, and no property about transitions can see either.

`bad3` is free-running — it advances when told to hold. `bad4` cycles
`0000 → 0001 → 0011 → 0010 → 0000` for ever: one bit changes on every step
including the wrap, it holds when told to, it resets to zero, and it
cannot count past three.

"One bit changes at a time" feels like the definition of a Gray counter.
It is a third of it. You also have to say when it may move, and that it
goes all the way round — which is why the exercise opens with a numbered
specification and why clauses 3 and 4 are independent in both directions:
`bad1` breaks 3 and satisfies 4, `bad4` the reverse.

### 03 — assuming the environment

A slave whose latency depends on its address. **Run `make good` before you
write any assumptions: the correct design fails.**

That counterexample is real — given those inputs, that is genuinely what
the hardware does — but the inputs cannot happen, because no legal master
moves an address mid-transaction. Deciding which of those two things you
are looking at, every time, is the central habit of the subject.

**Watch for:** `bad2` answers one clock early and its handshake is
otherwise flawless. And `bad3` never answers at all, which passes every
property of the form "the answer is correct" — because all of them are
conditional on an answer arriving. That is where safety and liveness part
company, and this exercise is where the distinction first bites.

### 04 — cover, and proving you proved something

Different in shape: the assumptions and assertions are **given**, the FIFO
has a real off-by-one, and the property aimed straight at it passes. Your
job is to write the cover statements that expose that.

The culprit is an assumption reading "the consumer is always ready" —
something people write for real, and for good reasons, when the downstream
block is a wire or does not exist yet. It means the queue never fills, so
the overflow is unreachable, so the assertion passes honestly and
uselessly.

The four required verdicts pin you tightly: cover statements that are
unreachable under the assumption *and* reachable without it. That rules out
the cheap answer — `cover(1'b0)` fails both.

**The rule worth taking away:** for every assumption, ask what it forbids,
and cover something on the far side of it.

### 05 — BMC is not proof

A watchdog with a five-bit counter compared against 40. It never barks —
not late, never.

The same design and the same properties, run twice, differing in one
number:

```
  shallow        pass     depth 20
  deep           fail     depth 64
```

**Watch for:** cover catches this too, for a completely different reason
than in exercise 04. Nothing is over-constrained here; twenty steps simply
never got within half the distance of the behaviour being claimed. So at
least one cover statement must be **deep**, or they all pass at every
depth and warn you of nothing.

**Also watch for:** the property file's counter is seven bits, not five.
Size it "to match the design" and it reproduces the bug inside the
property and the whole run passes. Properties come from the specification,
not from the RTL.

### 06 — induction, and the invariants that close it

`mode prove` is a genuinely unbounded proof: base case plus induction, and
the induction step starts from an **arbitrary** state — not one reachable
from reset. Any one.

The FIFO here knows its own occupancy twice over, in a counter and in its
pointers. In real silicon they cannot disagree. Induction does not start
in real silicon, so it starts them disagreeing and the proof falls over.

The result is `UNKNOWN`, not `FAIL`, and the difference is the whole
exercise:

> **FAIL** — a real trace from reset breaks your property. Go and read the
> design.
> **UNKNOWN** — the base case held, induction did not. Nobody has shown
> your property false. Your *property set* is not finished.

**Watch for:** the induction trace has no reset in it anywhere. Look at
step 0: `rst` is low, and the registers already disagree. That impossible
starting state *is* the answer — it is telling you which fact about your
design you have not written down.

### 07 — abstraction, and `$anyconst`

Data integrity: what goes in comes out, unchanged, once, in order. All
three broken FIFOs have flawless control, so every property from earlier
exercises passes all three.

The obvious approach — a shadow queue in the property file — means you now
have two FIFOs that might be wrong and a proof they agree, plus
`DEPTH × DW` extra state for the solver.

Instead, track exactly one item and refuse to say which:

```verilog
(* anyconst *) reg [CW:0]   f_index;    // some position in the stream
(* anyconst *) reg [DW-1:0] f_value;    // some value
```

Assume that item goes in with that value; assert it comes out with it.
Because both are arbitrary, that is a proof for every position and every
value at once. It is "let n be an arbitrary integer", and it does not grow
when the design does.

**Watch for:** the assumption constrains an input, and after exercise 04
that should make you uneasy. It is free here precisely because the thing
assumed is itself arbitrary — no behaviour is deleted, one is renamed.
Pin `f_value` to a constant and you are back in exercise 04.

### 08 — liveness, starvation and fairness

A two-master arbiter. `bad1` is strict priority: master 1 starves.
Its grant is one-hot, it never grants a master that did not ask, it never
grants two at once. **Every safety property passes.**

`bad2` grants everyone, so nobody ever waits and every liveness property
passes. The pair is deliberate: you need both kinds of claim.

**Watch for:** a liveness property is only meaningful once you say what
the environment must keep doing — and that fairness assumption is the
easiest place in the whole subject to over-constrain. Assume "a master
gives up after three clocks" and strict priority becomes fair.

**And here cover does not save you.** That was measured: add the
over-strong assumption and every cover statement still passes. It deletes
no *state* — contention still happens, it is merely guaranteed to end —
and cover asks about states. There is no tool for this one. Read your
assumptions and ask what a hostile environment would be allowed to do
without them.

### 09 — equivalence

You pipelined something to close timing. Is it still the same thing?

Two designs, one stimulus, one assertion that the outputs agree. That
arrangement is a **miter** and there is nothing more to the method. The
proof does not care about the input width, which is the whole reason to
use it: at 32 bits the exhaustive test is four billion vectors and the
proof takes the same time as at 8.

**Watch for:** `bad2` computes the right answer one clock late. Its
arithmetic is perfect. Compare the outputs of both versions over any
stream and the multisets agree exactly. Equivalence is a claim about
*when* as well as *what*, and a property set that does not pin the latency
down is not checking equivalence at all.

### 10 — the capstone

A skid buffer: the two-register stream slice that breaks the
combinational path in both directions without halving throughput. Every
AXI-Stream register slice is one of these.

Nothing new is introduced. The three bugs are chosen so that no single
property catches two of them:

| bug | needs |
|---|---|
| drops beats under backpressure | a data property (07) |
| duplicates beats | a counting property |
| withdraws an offer never taken | a protocol property (03) |

And `make prove` asks for the unbounded proof, which means running
exercise 06's loop on a design that did not have its invariant planted for
you. The reference takes three rounds to close it, and the third is
instructive: `f_outcount <= f_incount` is not inductive, because those
counters wrap and an absolute comparison between them becomes false with
nothing whatever wrong. Their difference is fine. **On a free-running
counter, assert about differences, never magnitudes.**

---

## Reading counterexamples

The counterexample *is* the output of a formal run. A failing property set
tells you almost nothing; the trace it hands back tells you everything,
and reading one is the skill this whole repository is trying to build.

```
$ make trace TASK=buggy

                          0    1    2    3    4    5    6    7    8    9   10   11  12*   13
  ------------------------------------------------------------------------------------------
  count                   0    0    1    2    3    4    5    6    7    8    9   10   11   11
  inc                     0    1    1    1    1    1    1    1    1    1    1    1    0    0
  rst                     1    0    0    0    0    0    0    0    0    0    0    0    0    0
  u_props.f_past_valid    0    1    1    1    1    1    1    1    1    1    1    1    1    1

  * step 12 is the step sby named.
  < step 11 is the state a CLOCKED assertion was evaluated on.
    An `always @(posedge clk)' assertion is checked on the edge LEAVING
    a state and reported one step later, so for those read the `<'
    column. For `always @(*)' the `*' column is the one that matters.
  (6 rows hidden as duplicates of a row above -- `--all' shows them.)
```

Two columns are marked because sby's step number means different things
for the two kinds of assertion, and nothing in its output says which kind
failed. Read `*` for `always @(*)`, `<` for `always @(posedge clk)`.

`make wave` still opens gtkwave, but a waveform viewer is a poor fit for
the first fortnight: these traces are eight to thirty steps long, which is
a table — and a table you can read in a terminal, paste into a commit
message, and diff against the one you got before your last edit.

The columns are sby's own step numbers, so the marked one is the step in
its summary line with no arithmetic in between.

---

## The harness proves itself first

Every result here is `mk/run.sh` comparing a verdict it parsed against a
verdict an exercise expected. If that parsing breaks it does not go quiet
— it reports something, and what it reports looks exactly like a result.

The specific danger is reading `ERROR` as `FAIL`. **Most tasks in this
repo are supposed to fail**, so a property file with a typo in it would go
green across four exercises in five and congratulate you on catching bugs
you had not caught.

That is not hypothetical. It is what the first version did, and it stayed
unnoticed for several exercises because the output looked like progress.
So `ERROR` is its own verdict, it matches nothing, and the verdict is
parsed out of sby's summary rather than taken from its exit status —
which cannot tell a broken proof from a broken build.

The same trap has a second door. A `cover` task with **no cover statements
to reach** passes instantly, and sby's PASS line is identical to the one a
real cover run prints — so an exercise could be completed with the cover
statements simply left out. That is the hollow PASS exercise 04 exists to
teach against, so the harness reports it as `empty`, which matches
nothing. (Found by a reader, whose exercise 01 went green without them.)

`make selftest` checks that the runner still tells `pass`, `fail`,
`unknown` and `error` apart, in both directions, and `make` runs it first
and stops if it fails. It has been seen to fail: break `run.sh` so ERROR
reads as FAIL and it reports exactly that. A self-test that has never
failed is decoration.

---

## Repository layout

```
docs/                the crib sheet and the coding style
mk/formal.mk         shared sby rules
mk/run.sh            run tasks, compare verdicts, explain the wrong ones
mk/trace.py          render a counterexample as a table
mk/selftest.sh       prove the runner still works
mk/selftest/         fixtures, one per verdict
mk/lint.sh           what the Verilog says, not what the verdicts say
mk/lint-*.py         the checks yosys and verilator do not do
mk/lint-selftest/    fixtures, one per bug the lint claims to catch
exercises/NN-*/      design(s) + property stub + harness + prove.sby
solutions/NN-*/      reference property sets
```

Each exercise has the same four parts, and the harness never changes when
the design under test does — which is why every design in a `dut/`
directory declares the same module name. `prove.sby` swaps one for another
with a single `read` line, leaving exactly one variable in the exercise.

---

## Suggested pace

- **One evening:** 00, 01, 02. You will be able to write properties.
- **A second:** 03, 04. You will stop believing PASS, which is the single
  most valuable thing here.
- **A third:** 05, 06. You will know what a proof is, and what `UNKNOWN`
  means.
- **A fourth:** 07, 08, 09. Three techniques you will reach for again.
- **A weekend:** 10, including `make prove`. Then point the same approach
  at something of your own.

The natural next step is the formal track in the Wishbone repository,
which is this material aimed at a real bus specification — or, better,
your own most recently debugged module. The thing that changes how you
write RTL is the first time a solver finds something in your own code that
you were sure was right.
