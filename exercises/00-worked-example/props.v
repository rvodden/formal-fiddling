// =====================================================================
// Exercise 00 -- a worked example. Nothing to write; read it, run it,
// and do not move on until the trace in `make trace TASK=buggy' makes
// complete sense.
//
// This file is a PROPERTY SET. It watches sat_counter and states, in a
// form a solver can reason about, what that counter is supposed to do.
// There are exactly three kinds of statement in the whole discipline and
// the difference between them is the entire game:
//
//   assert(p)   p must be true. The solver looks for ANY input sequence,
//               however perverse, that makes it false. If it finds one
//               you get a counterexample; if it does not, you have a
//               proof (up to a depth -- see exercise 05, which is about
//               that caveat and why it matters more than it sounds).
//
//   assume(p)   p is taken as given. The solver will only ever build
//               traces in which p holds. This is how you describe what
//               the OTHER side of an interface promises to do.
//
//   cover(p)    find me a trace where p is true. Not a requirement --
//               a question. It fails if p is unreachable.
//
// A simulation testbench checks the sequences you thought of. This checks
// all of them, to the depth you asked for. That is the whole reason to
// bother, and it is why a 40-line property file finds bugs a 900-line
// testbench walks straight past.
//
// ---------------------------------------------------------------------
// THE SPECIFICATION
//
// A saturating counter, LIMIT = 10.
//
//   1. After reset, count reads 0.
//   2. On a clock where inc is low, count is unchanged.
//   3. On a clock where inc is high and count is below LIMIT, count
//      increases by one.
//   4. count never exceeds LIMIT.
//
// This block is the contract. Everything else in this file is commentary
// and hints; where they disagree, this is what binds.
//
// Clause 4 is the whole of what "saturating" means, and it is the only
// clause this exercise asserts. The counter as shipped breaks clauses 3
// and 4 together: it keeps counting past LIMIT, round to 15, and wraps.
//
// ---------------------------------------------------------------------
// WHAT THE FIVE TASKS DO
//
//   make buggy          FAIL -- the counter as shipped sails past LIMIT
//   make fixed          PASS -- the same counter with the bug repaired
//   make cover          PASS -- proof that LIMIT is reachable at all
//   make vacuous        PASS -- and this one is a lie. Read on.
//   make vacuous_cover  FAIL -- which is how the lie gets caught
//
// `make' runs all five and checks each verdict is the one above.
//
// ---------------------------------------------------------------------
// THE TRAP, INTRODUCED HERE BECAUSE IT NEVER STOPS MATTERING
//
// The failure mode of formal verification is not a wrong counterexample.
// It is OVER-CONSTRAINING: assuming so much that the solver never builds
// the trace that would have exposed the bug.
//
// It does not warn you. There is no diagnostic. It says PASS, in exactly
// the same words it uses when your design is genuinely correct, and the
// two are indistinguishable from the summary line.
//
// The `vacuous' task below is a live demonstration on a bug you have
// already seen fail. One extra assumption -- a plausible-looking one --
// and the same broken counter is pronounced correct.
//
// The defence is `cover'. An assumption that has strangled the model
// takes the interesting states with it, and a cover statement aimed at
// one of those states stops being reachable. That is what `vacuous_cover'
// demonstrates, and it is why every property set in this repo ships cover
// statements alongside its assertions. They are not decoration and they
// are not coverage metrics in the simulation sense: they are the only
// evidence you have that your proof proved anything.
// =====================================================================

`default_nettype none

module props #(
    parameter LIMIT = 10
) (
    input wire       clk,
    input wire       rst,
    input wire       inc,
    input wire [3:0] count
);

    // ------------------------------------------------------------------
    // Two lines of boilerplate that every property file in this repo has,
    // and that are worth understanding rather than copying.
    // ------------------------------------------------------------------

    // At step 0 the design has not been through a reset edge, so every
    // register holds whatever the solver fancies. Asserting anything
    // about those values proves nothing -- and, worse, produces
    // counterexamples that could never happen on a real chip, which is a
    // spectacular way to waste an afternoon. `initial assume(rst)' says
    // the trace begins in reset.
    initial assume(rst);

    // f_past_valid is false on the very first step and true forever
    // after. Anything that looks backwards in time has to be gated on it,
    // because on step 0 there is no previous step to look at. Exercise 02
    // is entirely about this.
    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ------------------------------------------------------------------
    // The specification, in one line.
    // ------------------------------------------------------------------

    // THE assertion. "Saturating" means exactly this and nothing else.
    always @(*)
        if (f_past_valid) assert(count <= LIMIT[3:0]);

`ifdef OVERCONSTRAIN
    // ------------------------------------------------------------------
    // The trap, made concrete.
    //
    // Read this assumption on its own and it sounds almost reasonable --
    // something like "we never park the counter at its limit". It is the
    // sort of line that gets added to make a stubborn proof close, with a
    // comment saying "the hardware never does this anyway".
    //
    // What it actually does is delete every trace in which the counter
    // ever equals LIMIT. The bug is that the counter goes from LIMIT to
    // LIMIT+1 -- so deleting the state it starts from deletes the bug.
    // The assertion above is then true of everything that remains, and
    // the solver reports PASS with a completely straight face.
    //
    // Nothing here is a mistake a beginner makes and an expert does not.
    // It is a mistake everyone makes; the difference is only whether you
    // have a cover statement pointed at the state you just deleted.
    // ------------------------------------------------------------------
    always @(*)
        if (f_past_valid) assume(count != LIMIT[3:0]);
`endif

    // ------------------------------------------------------------------
    // COVER -- the evidence that any of the above meant anything.
    //
    // In `cover' mode the solver hunts for a trace that REACHES each of
    // these, and reports failure if it cannot. Run against the honest
    // property set they are all reachable. Run with OVERCONSTRAIN on, the
    // first one is not, and that unreachability is the only signal you
    // will ever get that the PASS above was hollow.
    // ------------------------------------------------------------------
    always @(posedge clk) if (f_past_valid && !rst) begin
        cover(count == LIMIT[3:0]);        // the counter can reach its limit
        cover(count == 4'd0 && !rst);      // and can be at rest, not in reset
    end

endmodule

`default_nettype wire
