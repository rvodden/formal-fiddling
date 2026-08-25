// =====================================================================
// Exercise 02 -- reasoning about time.
//
// Exercise 01 had no clock. Every property was a statement about one
// instant, and the solver only had to look at one instant to check it.
//
// Almost nothing you actually want to say about hardware is like that.
// "It holds its value", "it advances by one", "it responds within three
// clocks" are all statements relating a step to the steps around it, and
// this exercise is about how to write those.
//
// The design is a 4-bit GRAY counter. Its defining property is that
// exactly one output bit changes on each step -- which is why Gray codes
// are what you put across a clock domain crossing, where sampling a
// multi-bit value mid-change would otherwise hand you a number that was
// never counted to.
//
// ---------------------------------------------------------------------
// $past, AND WHY f_past_valid IS NOT OPTIONAL
//
// $past(x) is the value x had one clock ago. It is the whole vocabulary
// you need for this exercise:
//
//     always @(posedge clk)
//         if (f_past_valid && !rst && !$past(rst))
//             assert(gray == $past(gray));
//
// The guard is doing three separate jobs and all three are load bearing:
//
//   f_past_valid    On step 0 there IS no previous step. $past returns
//                   whatever the solver likes, and an assertion about it
//                   is a counterexample generator, not a property. The
//                   flag below is false on step 0 and true thereafter.
//
//   !rst            We are not making claims about a design being held
//                   in reset.
//
//   !$past(rst)     And it was not in reset last clock either -- because
//                   the transition OUT of reset is not an ordinary step
//                   and "the value did not change" is false across it,
//                   correctly and uninterestingly.
//
// Forget the third and you will get a counterexample on the first clock
// after reset in nearly every property you write from here to exercise
// 10. It is the single most common beginner's counterexample, and
// recognising it on sight -- "step 1, rst was high at step 0" -- will
// save you an enormous amount of time.
//
// One restriction to know before it bites you: $past may only appear
// INSIDE a clocked block. This does not compile --
//
//     wire [3:0] changed = gray ^ $past(gray);
//     ERROR: System function \$past is only allowed in clocked blocks.
//
// -- because $past is a reference to a previous sample rather than a
// function of the current one, and outside an `always @(posedge clk)'
// there is no edge to have sampled on.
//
// So where you want a named intermediate signal, keep the history in a
// register you declare yourself:
//
//     reg [3:0] gray_q;
//     always @(posedge clk) gray_q <= gray;
//     wire [3:0] changed = gray ^ gray_q;
//
// That is worth doing for anything you will want to read off a
// counterexample anyway, because a real signal gets its own row in the
// trace and a $past expression does not.
//
// ---------------------------------------------------------------------
// "EXACTLY ONE BIT CHANGED", WITHOUT $onehot
//
// The bits that changed between two values are their XOR. So the claim
// is that gray ^ $past(gray) has exactly one bit set.
//
// SystemVerilog spells that $onehot(). This repo is Verilog-2001 (see
// docs/style.md for why), so use the standard bit-twiddling identity:
//
//     d != 0  &&  (d & (d - 1)) == 0
//
// Subtracting one from a value flips its lowest set bit to zero and sets
// everything below it; ANDing with the original therefore clears that
// lowest bit and keeps every other set bit. The result is zero exactly
// when there were no other set bits. The `d != 0' term is what stops it
// accepting "nothing changed at all".
//
// ---------------------------------------------------------------------
// THE SPECIFICATION
//
// A 4-bit Gray counter, clocked, with a synchronous reset and an enable.
//
//   1. After reset, the counter reads 0.
//   2. On a clock where inc is low, the value is unchanged.
//   3. On a clock where inc is high, the counter advances one Gray step:
//      exactly one output bit changes.
//   4. Sixteen increments bring it back to 0, and no fewer do. It visits
//      all sixteen values before repeating.
//
// This block is the contract. Everything else in this file is commentary
// and hints; where they disagree, this is what binds.
//
// Clause 3 is what a Gray code IS. Clause 4 is what makes it a COUNTER,
// and it is not pedantry: a design that ticks 0000 -> 0001 -> 0011 ->
// 0010 -> 0000 for ever satisfies clauses 1 to 3 completely. One bit
// changes on every step including the wrap, it holds when told to, it
// starts at zero -- and it cannot count past three. That design is
// dut/bad4_short_cycle.v, and only clause 4 sees it.
//
// Clauses 3 and 4 are independent in both directions, which is why the
// exercise needs both: bad1 satisfies clause 4 and breaks clause 3, bad4
// satisfies clause 3 and breaks clause 4.
//
// CLAUSE 4 IS ITSELF TWO CLAIMS, and they come apart too.
//
//   "sixteen increments bring it back to 0, and no fewer do"  -- a claim
//   about the return PERIOD
//
//   "it visits all sixteen values before repeating"           -- a claim
//   about COVERAGE
//
// A design can satisfy the first and fail the second, by walking eight
// steps out along a path and retracing it home: one bit per step, at zero
// on the sixteenth increment and nowhere in between, and it only ever
// reaches nine of the sixteen values. That is dut/bad5_retrace.v.
//
// It is here because a reader's property set caught it and the reference
// solution did not. Checking the period is the obvious reading of clause
// 4, and it is half of it.
//
// ---------------------------------------------------------------------
// THE PORTS
//
// Every port here is an `input', including the ones carrying the design's
// outputs: a property module observes and never drives, which is also why
// they take no `_i' / `_o' suffix. What matters is where the value COMES
// FROM, because that is the assume/assert boundary -- you may `assume'
// about what the solver drives, and must `assert' about what the design
// drives.
//
//   name    width   comes from   what it is
//   ------------------------------------------------------------------
//   clk       1     harness      The clock.
//   rst       1     harness      Reset, synchronous, active high.
//   inc       1     THE SOLVER   Count-enable, free on every clock.
//                                Deliberately unconstrained: assuming
//                                anything about it here would narrow
//                                what you prove and buy nothing.
//   gray      4     THE DUT      The counter's output, in Gray code.
//                                All sixteen values are legal ones for
//                                it to show; what the specification
//                                constrains is the ORDER it shows them
//                                in, which is why every property in this
//                                file relates one clock to the next.
//
// ---------------------------------------------------------------------
// WHAT TO DO
//
//   make good   must PASS  -- a correct Gray counter
//   make bad1   must FAIL  -- no Gray encoding; it is a binary counter
//   make bad2   must FAIL  -- skips a value, so one step moves two bits
//   make bad3   must FAIL  -- free-running: it advances when told to hold
//   make bad4   must FAIL  -- a legal Gray cycle over four of the sixteen
//                             values. Clause 3 cannot see it.
//   make bad5   must FAIL  -- returns to zero on the sixteenth increment
//                             and no sooner, and still visits only nine
//                             of the sixteen values. Clause 4's first
//                             sentence cannot see it.
//   make cover  must PASS
//
//   make        all seven, with each verdict checked
//
// ---------------------------------------------------------------------
// bad3 IS THE POINT OF THIS EXERCISE
//
// bad1 and bad2 are caught by "exactly one bit changes per step". bad3 is
// not, and cannot be: every transition it makes is a perfectly legal Gray
// step. It is simply taking them when it was told to stand still.
//
// A property set that says only what the transitions look like, and
// nothing about when they may happen, will pass it. Getting bad3 to fail
// means writing down the other half of the specification -- the half
// about `inc' -- and it is the half people leave out, because "one bit
// changes at a time" feels like the definition of a Gray counter and it
// is only half of it.
// =====================================================================

`default_nettype none

module props (
    input wire       clk,
    input wire       rst,
    input wire       inc,
    input wire [3:0] gray
);

    // Given, because every property file needs them. See the header.
    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ------------------------------------------------------------------
    // TODO: your properties go here.
    //
    // One property per clause of the specification above. The wording
    // there is deliberately close to what you have to write:
    //
    //   - clause 1: coming out of reset, the counter reads zero
    //   - clause 2: while inc is low, the value does not change
    //   - clause 3: while inc is high, exactly one bit changes
    //   - clause 4, first sentence: it does not return to zero early.
    //     Count the increments since reset, modulo 16, and require the
    //     counter to read zero exactly when that count does.
    //   - clause 4, second sentence: it visits every value. Keep a bit
    //     per value, set the bit for whatever is on show at each
    //     increment, start a fresh set when the counter comes back to
    //     zero, and require a full set at the wrap. This is the one that
    //     catches bad5, and the first sentence cannot.
    //
    // A note on "while inc is high the value DOES change", because how
    // much you need it depends on how you write clause 3.
    //
    // "Exactly one bit changes" implies the value changes, so as a
    // statement about the specification it is redundant. But the natural
    // way to write "one bit" is the bit-twiddling identity
    //
    //     (changed & (changed - 1)) == 0
    //
    // and that is "AT MOST one bit" -- it is satisfied by changed == 0.
    // Written that way you do need the second half, either as `changed !=
    // 0' in the same assertion or as an assertion of its own. Both are
    // fine; what is not fine is writing only the identity and thinking it
    // says more than it does.
    //
    // No `assume' about inc is needed or wanted. inc is a free input and
    // every value of it on every step is legal stimulus; assuming
    // anything about it here would only narrow what you prove. Exercise
    // 03 is where inputs start having contracts.
    //
    // COVER, to show the model is reachable:
    //
    //   - the counter can be made to hold
    //   - the counter can be made to advance
    //   - it can reach the wrap, from 4'b1000 back to 4'b0000 -- the
    //     sixteenth increment, and a perfectly legal one-bit step.
    //     Covering it says your stimulus really does drive the counter
    //     all the way round within the depth prove.sby asks for, which
    //     is what clause 4 needs in order to have been tested at all.
    //
    // And one more, once you have written clause 4's second sentence:
    // cover the moment its assertion FIRES. That assertion necessarily
    // sits behind a guard -- "when the counter comes back to zero" -- and
    // an assertion behind a guard the solver controls may never be
    // evaluated at all. A run in which it never ran passes, and looks
    // exactly like a run in which it held. This is exercise 04's lesson
    // pointed at your own bookkeeping instead of at an assumption.
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
