# Formal verification crib sheet

Read once, then come back to it whenever a run says something you did not
expect.

---

## 1. The one-paragraph version

You write down what a design must do, as `assert` statements, and what
its surroundings are allowed to do, as `assume` statements. A solver then
searches — not samples, searches — for an input sequence that breaks an
assertion while respecting every assumption. If it finds one you get a
counterexample trace. If it does not, you have a proof, and the fine
print on the word "proof" is section 6.

The whole discipline is three statements, and confusing two of them is
most of what goes wrong.

---

## 2. What a task actually is

Every exercise runs several **tasks** — `make good`, `make bad1`,
`make cover`. They are listed in that exercise's `prove.sby`, and the
thing to understand first is that they mostly **run the same files**.
What changes is the question being asked.

Here is `exercises/01-first-assertions/prove.sby`, with two of its five
tasks and all of its comments left out:

```
[options]
good:  mode bmc          <- can any assert() be broken?
bad1:  mode bmc
cover: mode cover        <- can every cover() be reached?

[script]
good:  read -formal good.v
bad1:  read -formal bad1_highest.v
cover: read -formal good.v
read -formal props.v     <- YOUR properties, in every task
```

Two knobs do all the work:

- **which design is read.** Every design in a `dut/` directory declares
  the *same module name*, so swapping a correct one for a broken one is a
  single line and the harness never changes.
- **which mode.** This is the one that surprises people.

| mode | the solver hunts for | it ignores | PASS | FAIL |
|---|---|---|---|---|
| `bmc` | a trace that **breaks** an `assert` | your `cover` statements | no counterexample found | here is one |
| `cover` | a trace that **reaches** each `cover` | your `assert` statements | every one was reachable | one was not |

If you have written no cover statements, a `cover` task passes instantly
and has checked nothing — so the harness reports that as `empty` rather
than as a pass. See below.
| `prove` | both halves of an induction proof | your `cover` statements | proved for all time | see §6 |

So **`make cover` is not a second opinion on your assertions.** In
`mode cover` the assertions are not checked at all, and in `mode bmc` the
cover statements are not. They are different questions about one file,
and you need both answers — section 7 is about why.

"Ignores" is meant literally, and it was checked rather than assumed. Give
a design an assertion that is false from step 1, and a cover statement
aimed at a state where it is false: `mode bmc` returns FAIL, and `mode
cover` returns PASS having reached that state. The assertions are not
checked, and they do not constrain the search either. A broken assertion
has no effect whatever on a cover run.

### FAIL is frequently the right answer

Each exercise's `Makefile` says what verdict every task *should* produce:

```make
TASKS := good:pass bad1:fail bad2:fail bad3:fail cover:pass
```

A bare `make` runs them all and compares. Your property set is finished
when every verdict matches — which means passing the correct design **and
failing every broken one**. A task printing `fail as expected` is good
news.

Two verdicts are never expected, only reported, and both exist because
sby prints them in words indistinguishable from a real result:

- **`error`** — the design did not build. Most tasks here are meant to
  fail, so a property file with a typo in it would otherwise go green
  nearly everywhere.
- **`empty`** — a `cover` task passed having reached *no cover statement
  at all*, because the file contains none. An empty cover set is
  satisfiable instantly. That is the hollow PASS of section 7, so the
  harness refuses to award it a tick.

### Running one at a time

`make good` runs that single task and shows sby's own output, which is
what you want while actually working. `make trace TASK=bad1` prints its
counterexample as a table. A task that PASSED has no counterexample, so
there is nothing for `trace` to show.

---

## 3. The three statements

| | asks | silence means | who it constrains |
|---|---|---|---|
| `assert(p)` | can this be broken? | good — nothing broke it | your design |
| `assume(p)` | — (a restriction, not a question) | — | the environment |
| `cover(p)` | can this be reached? | **bad** — it could not | — |

`assert` and `cover` are opposite in temperament and this is the single
most useful thing to internalise. An assertion that never fires is doing
its job. A cover statement that never fires is an alarm.

### assume is the dangerous one

An assumption **deletes traces**. It can only ever shrink the set of
behaviours searched, so:

- it can never turn a passing property into a failing one
- it can never help you find a bug
- every one of them is a chance to delete a bug along with the noise

What assumptions buy is the ability to prove a *correct* design correct,
by removing counterexamples that were the environment's fault. That is
their entire value. Write the fewest that do it.

The rule of thumb: **assume what keeps the promise meaningful, not what
makes it easy.**

---

## 4. Reading a counterexample

Every counterexample is one of two things and you must decide which,
every time:

- **a real bug** → fix the design
- **stimulus the environment forbids** → add an assumption

The trap is that adding an assumption always makes the red go away. "Add
assumptions until it passes" is a procedure that terminates, feels like
progress, and proves nothing.

`make trace TASK=<task>` prints the trace as a table. Things to look at
first:

- **step 0.** Is `rst` high? If not, you are reading an induction trace
  (section 6) and step 0 is allowed to be nonsense.
- **the marked steps.** `make trace` marks two columns, and which one you
  read depends on the assertion:

  | assertion | read |
  |---|---|
  | `always @(*)` | the `*` column — the step sby named |
  | `always @(posedge clk)` | the `<` column, one step earlier |

  A clocked assertion is checked on the edge *leaving* a state and
  reported against the state it arrives in, so sby's step number is one
  later than the values that break it. Measured, on one design with one
  violated condition written both ways: the combinational version is
  reported at step 4 and the clocked version at step 5, with the offending
  value first appearing at step 4 in both.

  Read the `*` column for a clocked assertion and it will look as though
  nothing is wrong — because at that step nothing is.
- **the inputs.** Did the environment do something a real one never
  would? That is an assumption you have not written.

---

## 5. The boilerplate, and why

Every property file here starts with two things:

```verilog
initial assume(rst);                 // the trace begins in reset

reg f_past_valid = 1'b0;             // false on step 0, true after
always @(posedge clk) f_past_valid <= 1'b1;
```

**`initial assume(rst)`** — without it the solver starts every register at
an arbitrary value and hands you counterexamples that no reset could
produce.

**`f_past_valid`** — on step 0 there is no previous step, so `$past`
returns whatever the solver likes. Gate anything that looks backwards on
it.

And the third term people forget:

```verilog
if (f_past_valid && !rst && !$past(rst)) ...
```

`!$past(rst)` excludes the transition *out of* reset, which is not an
ordinary step. Leave it out and you get a counterexample on the first
clock after reset in nearly every property you write. Recognising that on
sight — "step 1, and rst was high at step 0" — saves hours.

### `$past` only works inside a clocked block

```verilog
wire [3:0] changed = gray ^ $past(gray);
// ERROR: System function \$past is only allowed in clocked blocks.
```

Keep the history in a register you declare yourself. Worth doing anyway
for anything you want to see in a trace, since a real signal gets a row
and an expression does not.

---

## 6. `mode bmc` versus `mode prove`

### bmc — bounded model checking

Unrolls the design N steps from reset and searches every input sequence
of that length.

A PASS means **"no counterexample within N steps"**. Not "this is true".
A bug that takes N+1 steps to reach is outside the question that was
asked.

You cannot generally work out the N you need, and large N gets expensive
fast — the state space grows with the unrolling.

### prove — k-induction

Two obligations:

- **base case**: the property holds for the first k steps from reset.
  (This is just BMC.)
- **induction**: if it holds for k consecutive steps, it holds on the
  next. Starting from an **arbitrary** state.

Both, and the property is true for all time. sby says "successful proof
by k-induction".

### the three verdicts

| verdict | means | what to do |
|---|---|---|
| PASS | proved (or no counterexample within the depth) | — |
| FAIL | a real trace from reset breaks your property | read the design |
| **UNKNOWN** | base case held, induction did not | strengthen your properties |

**UNKNOWN is not failure.** Nobody has shown the property false; it is
almost certainly true. It is not *inductive*, so induction cannot
establish it. Reading UNKNOWN as "there is a bug" and going hunting is
the standard way to lose a day.

### strengthening

Induction starts from *any* state, including states your design cannot
reach. Two registers that always agree in practice will be started
disagreeing.

The fix is to write down what else is true, as assertions. They get proved
like anything else, and the induction step may then assume them about its
arbitrary starting state — which deletes the impossible states.

The loop:

1. run `mode prove`
2. UNKNOWN → read the induction counterexample
3. find the impossible thing about its starting state
4. assert that it cannot happen
5. go to 1

Assert, never assume. An invariant you assume is the interesting half of
the specification taken on trust.

### a caution on small designs

k-induction may assume its k states are all distinct. On a design with
fewer states than the depth, that becomes exhaustive search and closes
properties that are not inductive at all. A 4-bit counter at `depth 24`
proves things a 16-bit one does not.

---

## 7. Vacuity: the failure mode

Assume too much and the solver never builds the trace that would expose
the bug. **There is no diagnostic.** It says PASS, in the same words it
uses when the design is genuinely correct.

`cover` is the alarm. For every assumption, ask what it forbids, and
cover something on the far side of it.

### what cover catches

- **over-constraint** — an assumption deleted the state your assertion was
  about (exercise 04)
- **insufficient depth** — the unrolling never got near the behaviour you
  claimed to check (exercise 05)
- **a guarded assertion that never ran** — `if (tracked_beat) assert(...)`
  where the tracked beat never happened (exercise 07)

### what cover does not catch

Assumptions that delete a *behaviour over time* rather than a *state*.
"A master gives up after three clocks" leaves every state reachable —
contention still happens, it is just guaranteed to end — and hides a
starving arbiter completely (exercise 08). Cover asks about instants.

There is no tool for that one. Read every assumption and ask what a
hostile environment could do without it.

### cover statements describe states the design SHOULD reach

Not bugs. `cover(count > DEPTH)` fails on a correct design too, which
makes it an assertion written inside out. Good cover statements keep
working after the bug is fixed — which is exactly when they have to keep
guarding the assumptions.

---

## 8. Safety and liveness

**Safety**: nothing bad happens. These come to mind unprompted.

**Liveness**: something good eventually happens. These are where
arbiters, handshakes, retry loops and coherence protocols actually break.

The gap is easy to miss because safety properties are *conditional*:

```verilog
if (ack) assert(f_outstanding == latency);   // exact timing
```

Every word of that is inside `if (ack)`. A slave that never acknowledges
anything satisfies it perfectly, and satisfies "no ack without a request"
and "one ack per request" too — it issues none. It is a brick, and it
passes.

So: **for every handshake, assert that the answer arrives at all.**

```verilog
assert(f_outstanding <= MAX_WAIT);
```

### bounded liveness, and why not `s_eventually`

SystemVerilog has `s_eventually` and sby has `mode live`. This repo uses a
counter and a bound instead:

- **practical**: `mode live` needs a liveness engine (aiger + suprove),
  which is a different tool from the SMT solver everything else uses.
  Bounded liveness is an ordinary safety property about a counter, so it
  runs on the engine you already have and survives `mode prove`.
- **honest**: a bound is usually what you wanted. "Eventually granted" is
  satisfied by an arbiter that makes you wait four million clocks.

The cost is picking N. Take it from the specification, not by raising it
until the good design passes — that is fitting the property to the
implementation, and it will accommodate a bug just as happily.

### liveness needs a fairness assumption

"A master that keeps asking is granted within N" is not well formed until
you say what "keeps asking" means. The assumption is part of the property,
and it is the easiest place in all of formal verification to
over-constrain — see section 7.

---

## 9. Abstraction with `$anyconst`

To prove something about every item, prove it about one arbitrary item.

```verilog
(* anyconst *) reg [CW:0]   f_index;    // some position in the stream
(* anyconst *) reg [DW-1:0] f_value;    // some data value
```

`anyconst` means: the solver picks it, it may pick anything, and it holds
that value for the whole trace.

```verilog
// label it going in
if (do_push && f_wcount == f_index) assume(wdata == f_value);
// check it coming out
if (do_pop  && f_rcount == f_index) assert(rdata == f_value);
```

That is a complete data-integrity proof, for every position and every
value, in two lines. It does not grow with the depth or width of the
design — unlike a shadow model, which doubles your state and gives you a
second FIFO that might be wrong.

**Why the assume is free**: a harmful assumption deletes behaviours. This
one does not, because the thing assumed is itself arbitrary — for any
data the design could be handed there, some choice of `f_value` matches.
The solver chooses both, so any counterexample that existed still exists.
Nothing was removed; something was renamed.

Fix `f_value` at `8'hA5` instead and you have deleted 255 values out of
256, and you are back in section 7.

Always cover that the tracked item was pushed **and** popped. The
assertion lives inside a condition the solver controls, and if it never
holds, the run passes having checked nothing.

---

## 10. Equivalence checking

Two designs, one stimulus, one assertion that the outputs agree. The
arrangement is called a **miter** and there is no special mode or tool.

```verilog
popcount_ref  u_ref (.w_i(w), .cnt_o(ref_cnt));
popcount_pipe u_dut (.clk_i(clk), .w_i(w), .cnt_o(dut_cnt));
```

Use it whenever you rewrite something that works — pipelining, retiming,
swapping an adder chain for a tree. It answers "is it still the same
thing", which a testbench cannot.

**Latency is the part everyone gets wrong.**

```verilog
assert(dut_cnt == ref_cnt);           // fails on a correct pipelined design
assert(dut_cnt == $past(ref_cnt));    // the actual claim
```

"Equivalent" is never just "the outputs match" — it is "the outputs match,
with this much skew", and the skew is part of what you assert. A version
that computes the right answer one clock late is functionally identical
and breaks everything downstream.

Equivalence proofs usually need no assumptions at all, which is a pleasant
change: there is almost nowhere to over-constrain. The exception is a
design valid only under a contract (aligned addresses, say) — then you
assume the contract, and you have proved equivalence only where it holds.

---

## 11. Free inputs, and white-box observation

An undriven input at the top of the harness is one the solver may set to
anything on every step. That is the exhaustive stimulus, and it is why
harnesses here drive nothing: whatever legality you need, you get with
`assume`, not by wiring.

When a proof needs to talk about state that is not visible at the
interface — the contents of an internal register — add a formal
observation output:

```verilog
output wire [DW-1:0] f_skid_data_o,     // drives nothing; for properties only
```

Synthesis removes it. This is much better than reaching into the
hierarchy from the property file, which ties your properties to one
implementation's signal names.

Often you need less than you think: in a skid buffer, `m_valid` and
`!s_ready` already *are* the two valid bits.

---

## 12. Counters in property files

Two rules, both learned the hard way.

**Make them wide enough for the specification, not for the design.** A
property counter narrowed "to match the RTL" reproduces the RTL's
overflow bug inside the property, and the whole run passes. Exercise 05
is built on exactly this.

**Assert about differences, never magnitudes.** A free-running counter
wraps. `f_outcount <= f_incount` becomes false the moment one rolls
through zero, with nothing wrong at all — invisible to BMC, and the first
thing induction finds. `f_incount - f_outcount` stays correct across the
wrap, because modular subtraction is what you meant.

---

## 13. Symptoms and causes

| symptom | likely cause |
|---|---|
| correct design FAILs | missing assumption — the environment did something illegal (§4) |
| FAIL on step 1, `rst` high at step 0 | missing `!$past(rst)` in the guard (§5) |
| everything passes, including the broken DUTs | no assertion actually fires; check cover (§7) |
| `mode prove` says UNKNOWN | property is true but not inductive — strengthen (§6) |
| induction trace starts in an impossible state | that *is* the answer; assert it cannot happen (§6) |
| a cover statement is unreachable | over-constraint, or depth too shallow (§7) |
| `\$past is only allowed in clocked blocks` | move it inside `always @(posedge clk)` (§5) |
| task "fails" but nothing was checked | it did not compile — the harness reports ERROR separately |
| proof is slow | reduce depth, narrow the data, or find an invariant so induction closes |

---

## 14. Further reading

- **[SymbiYosys documentation](https://symbiyosys.readthedocs.io/)** —
  the tool. Modes, engines, and the `.sby` file format.
- **Dan Gisselquist's blog, [zipcpu.com](https://zipcpu.com/blog/)** — the
  best practical writing on formal verification for FPGA work that exists,
  and the source of the `fwb_*` property-file conventions.
- **[Yosys manual](https://yosyshq.readthedocs.io/projects/yosys/)** — for
  what `read -formal` and `prep` actually do.
- ***Handbook of Model Checking*** (Clarke, Henzinger, Veith, Bloem) — the
  theory, if you want to know why k-induction works.
