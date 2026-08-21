// =====================================================================
// Exercise 08 -- liveness, starvation, and the fairness you have to
// assume to get either.
//
// Every property in this repo so far, with one exception, has been a
// SAFETY property: nothing bad happens. Safety properties are the ones
// that come to mind unprompted, they are easy to write, and a bounded
// model checker settles them comfortably.
//
// The exception was S5 in exercise 03 -- "the acknowledge arrives at all"
// -- and it was there because the other four properties in that file
// were, between them, satisfied perfectly by a brick.
//
// This exercise is about the other kind. LIVENESS properties say
// something good eventually happens, and they are where arbiters,
// handshakes, retry loops and cache coherence actually go wrong.
//
// ---------------------------------------------------------------------
// THE DESIGN
//
// A two-master arbiter. A grant lasts one clock; then it arbitrates
// again. The specification is three sentences:
//
//   1. Never grant two masters at once.
//   2. Never grant a master that did not ask.
//   3. A master that keeps asking is granted within MAX_WAIT clocks.
//
// The first two are safety. The third is liveness, and it is the only one
// of the three that a starving arbiter breaks. dut/bad1_strict_priority.v
// satisfies 1 and 2 impeccably, forever, while master 1 waits forever.
//
// ---------------------------------------------------------------------
// LIVENESS NEEDS AN ASSUMPTION ABOUT THE ENVIRONMENT. ALWAYS.
//
// This is the part that is genuinely different, rather than just harder.
//
// "A master that keeps asking is granted within MAX_WAIT" is not even a
// well-formed claim until you have said what "keeps asking" means. If a
// master may raise req for one clock and drop it before the arbiter has
// answered, no arbiter on earth can promise it anything -- and the
// counterexample you get is a master that gave up, which is not a bug in
// the arbiter.
//
// So a liveness property comes in two halves and both are yours to
// write:
//
//   the FAIRNESS ASSUMPTION   what the environment must keep doing for
//                             the promise to be meaningful. Here: a
//                             master holds req until it is granted.
//
//   the LIVENESS ASSERTION    what the design then owes. Here: the wait
//                             is bounded.
//
// And now the trap, which is the whole reason this exercise is late in
// the sequence rather than early. The fairness assumption is an
// assumption, so everything from exercise 04 applies to it -- and
// liveness assumptions are the easiest place in all of formal
// verification to over-constrain, because a strong enough one makes any
// arbiter fair.
//
// Assume "a master drops its request after three clocks", for instance.
// It sounds like the same kind of statement about a well-behaved master.
// It is not. It says contention always ends by itself, so no policy can
// starve anybody, and bad1 -- strict priority -- passes.
//
// ---------------------------------------------------------------------
// AND HERE COVER DOES NOT SAVE YOU
//
// This was measured rather than assumed, and the result is worth more
// than the tidy version would have been.
//
// Add that assumption to the reference property set and run it. bad1
// goes green, as advertised. Now run the cover task: EVERY COVER
// STATEMENT STILL PASSES. Both masters can still be seen requesting on
// the same clock. Each is still granted. A master is still seen waiting
// before being served. Nothing anywhere reports a problem.
//
// Exercise 04's over-constraint deleted a STATE -- the queue could never
// be full -- and a cover statement aimed at that state found it
// immediately. This one deletes no state at all. Contention still
// happens; it is merely guaranteed to stop. What has been deleted is a
// BEHAVIOUR OVER TIME, and a cover statement asks about a single
// reachable instant, so there is nothing for it to fail on.
//
// So cover is a good alarm and it is not a complete one. Assumptions
// about how long something goes on -- about eventually, about giving up,
// about retry limits -- are exactly the ones it cannot see through, and
// they are exactly the ones liveness proofs need. There is no tool for
// this. The defence is to read every assumption and ask what a hostile
// environment would be allowed to do without it, and whether you have
// just quietly excused the design from the case it exists to handle.
//
// ASSUME WHAT KEEPS THE PROMISE MEANINGFUL, NOT WHAT MAKES IT EASY.
//
// ---------------------------------------------------------------------
// WHY THE BOUND IS A COUNTER AND NOT "EVENTUALLY"
//
// The property you want is unbounded: "eventually granted", no number.
// SystemVerilog spells it `s_eventually', SymbiYosys has a `mode live'
// for exactly this, and it does work.
//
// This repo uses a counter and a bound instead, for two reasons.
//
// The practical one: `mode live' needs an engine that does liveness
// (aiger with suprove, typically), which is a different tool from the
// SMT solver everything else here uses, and it is not in every install.
// A bounded liveness property is an ordinary safety property about a
// counter, so it runs on the engine you already have and settles in
// `mode prove' like anything else.
//
// The honest one: a bound is usually what you actually wanted. "Granted
// eventually" is satisfied by an arbiter that makes master 1 wait four
// million clocks. If you have a real-time requirement, "within N" is your
// specification and `s_eventually' is weaker than it. Reach for unbounded
// liveness when you genuinely cannot name a number -- and notice how
// rarely that is true of hardware.
//
// The cost is that you have to pick N. Pick it from the specification --
// from what the design PROMISES -- and not by raising it until the good
// design passes, which is fitting the property to the implementation and
// will happily accommodate a bug.
//
// ---------------------------------------------------------------------
// WHAT TO DO
//
//   make good   must PASS  -- round robin, one-clock grants
//   make bad1   must FAIL  -- strict priority: master 1 starves
//   make bad2   must FAIL  -- grants both at once
//   make bad3   must FAIL  -- grants nobody when both ask
//   make cover  must PASS
//
//   make        all five, with each verdict checked
//
// bad1 and bad2 are a matched pair and they are why you need both kinds
// of property. A set with only safety properties passes bad1 -- strict
// priority is a well-formed arbiter. A set with only liveness properties
// passes bad2 -- granting everybody means nobody ever waits.
// =====================================================================

`default_nettype none

module props (
    input wire       clk,
    input wire       rst,
    input wire [1:0] req,
    input wire [1:0] gnt
);

    // The promise. Round robin with one-clock grants: a master waiting
    // behind the other one waits for that master's single clock and then
    // its own arbitration, so two is the worst case and three is the
    // bound with a clock of margin.
    //
    // Taken from the policy, not from watching what the design does.
    localparam MAX_WAIT = 3;

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ------------------------------------------------------------------
    // GIVEN: how long each master has been asking without being served.
    // Cleared by reset, by being granted, and by giving up.
    // ------------------------------------------------------------------
    reg [3:0] f_wait0, f_wait1;

    always @(posedge clk) begin
        if (rst || gnt[0] || !req[0]) f_wait0 <= 4'd0;
        else                          f_wait0 <= f_wait0 + 4'd1;

        if (rst || gnt[1] || !req[1]) f_wait1 <= 4'd0;
        else                          f_wait1 <= f_wait1 + 4'd1;
    end

    // ------------------------------------------------------------------
    // TODO 1: the FAIRNESS ASSUMPTION.
    //
    //   a master that has asked and not been granted is still asking on
    //   the next clock
    //
    // Plus the usual: no requests during reset.
    //
    // Write the first as a clocked property in the shape you used in
    // exercise 03 -- if last clock req[i] was high and gnt[i] was not,
    // then req[i] is high now.
    //
    // Do NOT assume anything about a master eventually going away. That
    // is the over-constraint described in the header, and it makes bad1
    // pass.
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 2: the SAFETY assertions.
    //
    //   - never both grants at once
    //   - never a grant to a master that was not asking. Careful: the
    //     grant is REGISTERED, so it reflects the request of the previous
    //     clock. Compare against $past(req), not req, or the correct
    //     design will fail.
    //   - no grants on the clock after reset
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 3: the LIVENESS assertion.
    //
    //   - neither master waits longer than MAX_WAIT
    //
    // One line, using the counters above. This is what catches bad1 and
    // bad3, and neither of them is visible to anything in TODO 2.
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 4: your COVER statements.
    //
    // The most important one is the contention itself. Your fairness
    // assumption is a constraint on both masters at once, and if you have
    // written it too strongly the state where they both want the bus can
    // quietly stop being reachable -- at which point every property above
    // is about an arbiter that never has to arbitrate.
    //
    //   - both masters requesting on the same clock
    //   - each master actually being granted
    //   - a master being granted after having had to wait
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
