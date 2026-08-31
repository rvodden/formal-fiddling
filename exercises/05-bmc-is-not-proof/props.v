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
// THE SPECIFICATION
//
// A watchdog timer, TIMEOUT = 40.
//
//   1. After reset, bark is low.
//   2. A kick, or a reset, restarts the count of quiet clocks.
//   3. If TIMEOUT quiet clocks go by, bark is asserted -- no later than
//      TIMEOUT + 1 clocks after the last kick or reset.
//
// This block is the contract. Everything else in this file is commentary
// and hints; where they disagree, this is what binds.
//
// The bound in clause 3 is TIMEOUT + 1 rather than TIMEOUT because the
// design's bark is registered: it decides on the clock the count reaches
// TIMEOUT and the output appears on the next one. One clock too tight
// and a correct watchdog fails; one too loose and a watchdog that barks
// late passes. Derive it from the specification rather than adjusting
// until the good case goes green -- that is fitting the property to the
// implementation.
//
// That off-by-one is the reason `make good' exists. Against a broken
// design, "exactly right" and "one clock too tight" look identical --
// both reject it. Only a correct watchdog separates them, and a property
// set with nothing correct to run against cannot be calibrated at all.
// Every other exercise ships a good design for this reason; this one did
// not, until a reader's too-tight assertion got all four depth verdicts
// right and had nothing to tell it.
//
// The design never barks at all, so it breaks clause 3 outright. The
// exercise is not about finding that. It is about the depth at which you
// are told.
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
//   kick      1     THE SOLVER   The signal that restarts the timeout.
//                                Free on every clock: the solver may
//                                kick constantly, never, or on whatever
//                                pattern makes your properties hardest.
//   bark      1     THE DUT      The watchdog's alarm. This design never
//                                raises it -- that is the bug -- so
//                                `cover(bark)' is unreachable at every
//                                depth and is the one cover statement
//                                NOT to write. See the TODO below.
//
// ---------------------------------------------------------------------
// WHAT TO DO
//
// Write a property set so that:
//
//   make good           PASS  -- a CORRECT watchdog, one bit wider. Your
//                             property must accept this as well as reject
//                             the broken one, and getting the bound one
//                             clock too tight fails here and nowhere else.
//   make shallow        PASS  -- bmc, depth 20. Says nothing is wrong.
//   make shallow_cover  FAIL  -- and this is why you should not believe it
//   make deep           FAIL  -- bmc, depth 64. The counterexample.
//   make deep_cover     PASS
//
//   make                all of them, with each verdict checked
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
// The number under discussion here is `depth' -- the one in prove.sby's
// [options] block, which says how many steps the solver unrolls. Nothing
// in this section is about what to aim a cover statement at; that is
// TODO 2, and the numbers are different on purpose.
//
// Here you can work it out: the bug needs the counter to pass 40, that
// takes 41 clocks from reset, so a DEPTH over about 42 finds it and 64
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
    // Write it as a BOUND on f_quiet rather than as "when f_quiet reaches
    // TIMEOUT, bark is high". The second is a clock too tight -- a
    // correct watchdog has not barked at that instant, only decided to --
    // and `make good' is what tells you so.
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
    //     about forty steps and is the one that fails at depth 20.
    //
    //     BELOW the bound your assertion sets, and that is not an
    //     accident. Your assertion says f_quiet never gets past
    //     TIMEOUT+1; a cover statement aimed at TIMEOUT+2 therefore
    //     describes a state that ONLY A BROKEN DESIGN can reach. It
    //     passes here, because the watchdog in this exercise is broken --
    //     and goes unreachable the moment somebody fixes it.
    //
    //     That is the `cover(bark)' mistake below, wearing the other
    //     face: one is unreachable because the design is broken, the
    //     other reachable because it is. Cover statements describe states
    //     the design is SUPPOSED to occupy, so they keep working when the
    //     bug is gone -- which is when you need them.
    //
    //     Do not take the depth number from the section above for this.
    //     42 is how far the SOLVER must unroll to find the bug; it is the
    //     one value that cannot serve as a cover target, for the reason
    //     just given.
    //   - the watchdog being kicked, so you know kicks are modelled
    //   - a short quiet spell, which is reachable at any depth and is
    //     there as a control: if this one fails too, something is wrong
    //     with the harness rather than with the depth
    //
    // GATE YOUR COVER STATEMENTS the same way you gate assertions, on
    // f_past_valid and !rst. f_quiet has no initial value, so on step 0
    // it holds whatever the solver likes -- including whatever number you
    // were hoping to see it count up to. An ungated `cover(f_quiet == N)'
    // is reported reached at step 1, from the pre-reset value, without a
    // single quiet clock having elapsed. It silences the very alarm this
    // exercise is built around.
    //
    // Do not write `cover(bark)' either. It is the obvious thing to want
    // and it is unreachable at EVERY depth, because the design never
    // barks -- so it fails both tasks and tells you nothing about either.
    //
    // Same rule as above, other direction: a cover statement aimed at the
    // bug is an assertion written inside out. `cover(bark)' asks for
    // something the broken design cannot do; `cover(f_quiet == TIMEOUT+2)'
    // asks for something only the broken design can do. Neither describes
    // the watchdog you are trying to verify. (Exercise 04's solution
    // makes the same point about the same mistake again.)
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
