// Reference solution for exercise 04 -- the cover statements that catch a
// hollow proof.
//
// Everything above the cover block is identical to the exercise file. The
// answer is three lines, and the interesting thing about them is how
// ordinary they are: none of them mentions the bug, the assertion, or the
// assumption they are testing. They just ask whether some perfectly
// unremarkable states of a FIFO can happen.
//
// That is what makes the technique usable. You do not need to suspect a
// particular over-constraint to catch it -- you need cover statements
// aimed at the states your design is supposed to be able to occupy, and
// an over-constraint that matters will collide with one of them.

`default_nettype none

module props #(
    parameter DEPTH = 4
) (
    input wire       clk,
    input wire       rst,
    input wire       push,
    input wire       pop,
    input wire [2:0] count,
    input wire       full,
    input wire       empty
);

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ==================================================================
    // ASSUMPTIONS -- given. Two of these are the honest description of a
    // well-behaved producer and consumer. The third is the problem.
    // ==================================================================

    // A1. A polite producer does not push into a full queue.
    always @(*)
        if (full) assume(!push);

    // A2. A polite consumer does not pop from an empty one.
    always @(*)
        if (empty) assume(!pop);

`ifndef HONEST
    // A3. "The consumer is always ready." Switched off by -DHONEST, which
    //     is what the `honest' and `honest_cover' tasks do.
    //
    //     Read it once more before you go looking for its damage. There
    //     is nothing false about it as a description of some real
    //     systems, and nothing about the way it is written that marks it
    //     out from A1 and A2 above.
    always @(*)
        if (!empty) assume(pop);
`endif

    // ==================================================================
    // ASSERTION -- given. This is the right property. It is aimed exactly
    // at the bug. Under A3 it passes anyway.
    // ==================================================================
    always @(*)
        if (f_past_valid) assert(count <= DEPTH[2:0]);

    // ==================================================================
    // COVER -- the alarm.
    //
    // Under A3 the first two are unreachable and `hollow_cover' fails,
    // which is the whole point of the exercise. With -DHONEST all three
    // are reachable and `honest_cover' passes.
    // ==================================================================

    always @(posedge clk) if (f_past_valid && !rst) begin

        // C1. The queue can fill to its stated depth.
        //
        //     This is the state the assertion is about. If you cannot
        //     reach it, you have not tested the assertion -- you have
        //     only failed to break it somewhere else. Any property with
        //     a threshold in it deserves a cover statement at that
        //     threshold, and this is the single highest-value cover
        //     statement in this file.
        cover(count == DEPTH[2:0]);

        // C2. The consumer can stall while data is waiting.
        //
        //     The most direct question you can ask of A3, because A3 is
        //     the sentence "this never happens" and this is the sentence
        //     "can this happen?". Backpressure is a first-class
        //     behaviour of every queue ever built, so being unable to
        //     reach it is a loud result.
        cover(!empty && !pop);

        // C3. Somewhere in the middle. Cheap, and it distinguishes "the
        //     occupancy moves" from "the occupancy is pinned near zero",
        //     which is exactly the damage A3 does.
        cover(count == 3'd2);

    end

    // ------------------------------------------------------------------
    // What NOT to write here, since the four required verdicts rule it
    // out and it is worth knowing why.
    //
    // `cover(count > DEPTH)' -- covering the bug itself -- looks like the
    // sharpest possible test and is the wrong tool. It fails under A3,
    // correctly, but it also fails on a FIFO that is CORRECT, because a
    // correct FIFO never exceeds its depth either. A cover statement that
    // fails on good designs is not an alarm; it is an assertion written
    // inside out.
    //
    // Cover statements describe states the design is SUPPOSED to be able
    // to occupy. Keep them that way and they stay valid when the bug is
    // fixed -- which is the point, because that is when they have to keep
    // guarding the assumptions.
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
