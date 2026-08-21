// =====================================================================
// Exercise 05 -- BMC is not proof.
//
// Everything so far has run in `mode bmc' and every PASS has been quietly
// misread. This is what one actually means:
//
//     "I unrolled the design for N steps from reset and searched every
//      input sequence of that length. There is no counterexample of
//      length N or less."
//
// Not "this property is true". A bug that takes N+1 steps to reach is
// not merely undetected -- it is outside the question that was asked.
//
// Up to now the depths have been generous relative to the designs, so the
// distinction has not cost anything. Here it costs everything.
//
// ---------------------------------------------------------------------
// THE DESIGN
//
// A watchdog. It counts clocks since the last kick and is supposed to
// bark once TIMEOUT = 40 of them have gone by without one. Its counter is
// five bits wide, so it counts 0 to 31 and wraps, and the value 40 is
// one it can never hold. It never barks. Not late -- never.
//
// This is a bad bug in a component whose entire job is to be the last
// line of defence. On a board it is invisible, because a watchdog that
// has not barked looks exactly like a watchdog that has not needed to.
//
// ---------------------------------------------------------------------
// WHAT TO DO
//
// Write a property set so that:
//
//   make shallow        PASS  -- bmc, depth 20. Says nothing is wrong.
//   make shallow_cover  FAIL  -- and this is why you should not believe it
//   make deep           FAIL  -- bmc, depth 64. The counterexample.
//   make deep_cover     PASS
//
//   make                all four, with each verdict checked
//
// The two `bmc' tasks run the same design against the same properties,
// and differ in one number. One of them reports a clean run.
//
// ---------------------------------------------------------------------
// COVER TELLS YOU YOUR DEPTH IS TOO SHALLOW, TOO
//
// In exercise 04 an unreachable cover statement meant an assumption had
// strangled the model. Here nothing is assumed at all, and the same
// alarm goes off for a completely different reason: 20 steps is not
// enough to get anywhere near a 40-clock timeout, so a cover statement
// asking to see one is asking for something outside the unrolling.
//
// This is the same tool doing the same job. A cover statement asks
// whether the search reached a state; it does not care whether the reason
// it could not was an over-constraint or a horizon that stops short. Both
// mean the assertions above it were never really exercised, and both are
// invisible in the assertion result.
//
// So the discipline is: SOMETHING IN YOUR COVER SET MUST BE DEEP. If
// every cover statement you write is reachable in five steps, they will
// all pass at any depth you choose and will never once warn you that the
// depth is wrong.
//
// ---------------------------------------------------------------------
// HOW DEEP IS DEEP ENOUGH -- AND THE HONEST ANSWER
//
// Here you can work it out: the bug needs the counter to pass 40, that
// takes 41 clocks from reset, so anything over about 42 finds it and 64
// is comfortable.
//
// You could work it out because this design has one counter and a number
// written on it. That is not the usual case. For a FIFO, a bus bridge or
// an arbiter there is no arithmetic that tells you the depth at which the
// last bug stops hiding, and picking a big number and hoping is exactly
// as rigorous as it sounds. Note also what "pick a bigger number" costs:
// the state space the solver explores grows with the unrolling, and
// depths in the low hundreds are where runs start taking minutes and then
// hours.
//
// The way out is not a bigger number. It is `mode prove' -- k-induction,
// which reasons about an arbitrary step rather than the first N, and
// gives you an answer that does not have a horizon in it at all.
//
// That is exercise 06, and it has a price of its own.
// =====================================================================

`default_nettype none

module props #(
    parameter TIMEOUT = 40
) (
    input wire clk,
    input wire rst,
    input wire kick,
    input wire bark
);

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ------------------------------------------------------------------
    // GIVEN: clocks since the last kick, bark or reset.
    //
    // Seven bits, not five. A counter in a property file has to be wide
    // enough for the values the SPECIFICATION talks about, and it is
    // worth noticing that making this one five bits wide -- to "match the
    // design" -- would reproduce the bug inside the property and the
    // whole run would pass.
    //
    // A property file that copies the design's mistakes agrees with it
    // perfectly and proves nothing. This is the strongest argument for
    // writing properties from the specification and not from the RTL, and
    // it is a mistake that is very easy to make while staring at the code
    // you are verifying.
    // ------------------------------------------------------------------
    reg [6:0] f_quiet;
    always @(posedge clk)
        if (rst || kick || bark) f_quiet <= 7'd0;
        else                     f_quiet <= f_quiet + 7'd1;

    // ------------------------------------------------------------------
    // TODO 1: your ASSERTION.
    //
    //   - the watchdog barks within TIMEOUT+1 clocks of the last kick.
    //     Equivalently: f_quiet never gets past TIMEOUT+1. Since f_quiet
    //     is cleared by a bark, letting it climb past the timeout is
    //     precisely the statement that no bark arrived.
    //
    // This is a bounded liveness property, the same shape as S5 in
    // exercise 03. It is the only kind of "something must eventually
    // happen" a bounded model checker can settle, and exercise 08 is
    // about what that costs you.
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 2: your COVER statements.
    //
    // At least one of them must need more than 20 steps to reach, or
    // `shallow_cover' will pass and the exercise's alarm will never
    // sound. Some worth having:
    //
    //   - a long quiet spell: f_quiet reaching TIMEOUT - 1, which takes
    //     about forty steps and is the one that fails at depth 20
    //   - the watchdog being kicked, so you know kicks are modelled
    //   - a short quiet spell, which is reachable at any depth and is
    //     there as a control: if this one fails too, something is wrong
    //     with the harness rather than with the depth
    //
    // Do not write `cover(bark)'. It is the obvious thing to want and it
    // is unreachable at EVERY depth, because the design never barks --
    // so it fails both tasks and tells you nothing about either. Cover
    // statements describe states the design is supposed to be able to
    // reach; a cover statement aimed at the bug is an assertion written
    // inside out. (Exercise 04's solution makes the same point about the
    // same mistake, from the other direction.)
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
