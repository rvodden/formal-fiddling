// =====================================================================
// Exercise 03 -- assuming the environment.
//
// So far every input has been free: any value, any step, all of it legal
// stimulus. That was true of a priority encoder and of a Gray counter's
// `inc', and it will not be true again.
//
// This design is a slave on a request/acknowledge interface. It answers a
// request `latency' clocks after it appears, where latency is 1 to 4
// depending on the address. A master talking to it has obligations, and
// they are not optional:
//
//   1. Once req is raised it stays raised until ack comes back.
//   2. The address does not move while a request is in flight.
//   3. No request is outstanding during reset.
//
// A real master obeys these. The solver, which is not a real master, does
// not -- unless you tell it to. That is what `assume' is for.
//
// ---------------------------------------------------------------------
// START HERE: RUN `make good' BEFORE YOU WRITE ANYTHING
//
// Write the assertions first, leave the assumptions out, and run it. The
// correct design FAILS.
//
// Read the counterexample -- `make trace TASK=good'. Exactly which one
// you get depends on which assertions you wrote, but it will be some
// version of the same thing: the solver started a transaction and then
// did something to it mid-flight that no master is permitted to do --
// moved the address, so the slave is counting to a latency that changed
// underneath it, or dropped the request entirely and then complained
// about the acknowledge that was already committed.
//
// The design is right. The counterexample is real, in the sense that the
// solver did not cheat: given those inputs, that is genuinely what the
// hardware does. It is simply that those inputs cannot happen, because no
// master is allowed to do that.
//
// THIS IS THE MOST IMPORTANT HABIT IN FORMAL VERIFICATION. Every
// counterexample you get is one of two things:
//
//   a real bug                         -> fix the design
//   stimulus the environment forbids   -> add an assumption
//
// and you have to decide which, every time, on the evidence. The trap is
// that adding an assumption always makes the red go away, so "add an
// assumption until it passes" is a procedure that terminates, feels like
// progress, and proves nothing. Exercise 04 is about what that wreckage
// looks like from the inside.
//
// ---------------------------------------------------------------------
// ASSUMPTIONS DO NOT HELP YOU FIND BUGS. THEY ONLY EVER HIDE THEM.
//
// Worth getting straight now, because it is not obvious and it decides
// how you should feel about adding one.
//
// An assumption deletes traces. It can only ever shrink the set of
// behaviours the solver searches. So it can never turn a passing property
// into a failing one, and it can never help catch a bug -- every one of
// bad1, bad2 and bad3 below would be caught by a property set with no
// assumptions in it whatsoever.
//
// What assumptions buy you is the ability to prove the GOOD design
// correct, by removing the counterexamples that were the environment's
// fault rather than the design's. That is the whole of their value, and
// the price is that every one of them is a chance to delete a bug along
// with the noise.
//
// So: the fewest assumptions that make `good' pass. Not one more.
//
// ---------------------------------------------------------------------
// WHAT TO DO
//
//   make good   must PASS  -- the correct slave, once you have assumed
//                             a legal master
//   make bad1   must FAIL  -- leaves ack up for a clock after the request
//   make bad2   must FAIL  -- answers one clock early, for 3 of 4 addresses
//   make bad3   must FAIL  -- address 7 is never answered at all
//   make cover  must PASS
//
//   make        all five, with each verdict checked
//
// bad2 is the one that decides whether your property set is any good. Its
// handshake is flawless -- one acknowledge per request, never outside a
// request, always within the bound. Only the timing is wrong. A property
// set that says "the protocol is well formed" passes it; you have to say
// what the latency IS.
// =====================================================================

`default_nettype none

module props (
    input wire       clk,
    input wire       rst,
    input wire       req,
    input wire [2:0] addr,
    input wire       ack
);

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ------------------------------------------------------------------
    // GIVEN: what the address means, and how long the request has been
    // waiting. Both are here because they are bookkeeping rather than
    // properties, and you will want them in nearly every assertion below.
    // ------------------------------------------------------------------

    // The latency the slave owes for this address. This duplicates a line
    // of the design, which is exactly right and worth being comfortable
    // with: a property file is a SECOND statement of the specification,
    // written independently, and the proof is that the two agree. If it
    // were derived from the design it could not disagree with it, and
    // would check nothing.
    wire [2:0] latency = {1'b0, addr[1:0]} + 3'd1;

    // Clocks the current request has been outstanding: zero on the step
    // the request appears, one on the next, and so on. It is cleared
    // whenever there is no request or one has just been answered.
    reg [3:0] f_outstanding;
    always @(posedge clk)
        if (rst || !req || ack) f_outstanding <= 4'd0;
        else                    f_outstanding <= f_outstanding + 4'd1;

    // ------------------------------------------------------------------
    // TODO 1: your ASSUMPTIONS -- what a legal master promises.
    //
    //   - nothing is outstanding while rst is high
    //   - a request that has not been answered does not go away, and its
    //     address does not move
    //
    // The second is the one that makes `good' pass. Write it as a clocked
    // property: if last clock there was a request and no acknowledge,
    // then this clock req is still high and addr is unchanged.
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 2: your ASSERTIONS -- what the slave owes.
    //
    //   - no acknowledge unless there is a request underneath it
    //   - no acknowledge on the clock after reset
    //   - one acknowledge per request, not two: ack does not stay up
    //   - the acknowledge arrives EXACTLY `latency' clocks after the
    //     request appeared -- not "within". f_outstanding above is
    //     counting for you, and note it reads `latency' at the moment of
    //     the acknowledge, which is only meaningful because you assumed
    //     the address holds still. This is what catches bad2.
    //   - the acknowledge arrives AT ALL, within 4 clocks -- 4 being the
    //     slowest address the map allows.
    //
    // Those last two look like the same property and they are not, which
    // is the trap in this exercise and the reason bad3 is here.
    //
    // "Arrives exactly on time" is conditional on arriving. Every word of
    // it is inside `if (ack)'. A slave that never acknowledges anything
    // satisfies it completely -- and satisfies "no ack without a request"
    // and "one ack per request" too, since it issues none. bad3 is
    // exactly that slave for address 7, and a property set without the
    // second of those two lines passes it.
    //
    // The names are worth learning here rather than later. Properties of
    // the form "nothing bad happens" are SAFETY properties, and they are
    // the ones that come to mind unprompted. "Something good eventually
    // happens" is LIVENESS, and a bounded liveness property -- something
    // good happens WITHIN N CLOCKS -- is how you write one that a bounded
    // model checker can actually settle. Exercise 08 is about how far
    // that can be pushed and where it stops.
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 3: your COVER statements.
    //
    //   - a request is answered at all
    //   - a request with the longest latency (address 3) is answered
    //   - two requests are answered in the same trace, so you know the
    //     slave can be used more than once
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
