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
// WHAT TO DO
//
//   make good   must PASS  -- a correct Gray counter
//   make bad1   must FAIL  -- no Gray encoding; it is a binary counter
//   make bad2   must FAIL  -- skips a value, so one step moves two bits
//   make bad3   must FAIL  -- free-running: it advances when told to hold
//   make cover  must PASS
//
//   make        all five, with each verdict checked
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
    // Things worth stating. You do not need all of them and you may want
    // others:
    //
    //   - coming out of reset, the counter reads zero
    //   - while inc is low, the value does not change
    //   - while inc is high, exactly one bit changes
    //   - while inc is high, the value DOES change (which the "exactly
    //     one bit" property already implies -- worth convincing yourself
    //     of rather than writing twice)
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
    //   - it can reach the wrap, from 4'b1000 back to 4'b0000. That step
    //     is where bad2 lives, so covering it says your stimulus really
    //     does get that far within the depth prove.sby asks for.
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
