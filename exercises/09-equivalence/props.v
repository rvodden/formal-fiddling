// =====================================================================
// Exercise 09 -- equivalence: proving you did not change anything.
//
// Every other exercise here has verified a design against a
// specification written in properties. This one verifies a design
// against ANOTHER DESIGN, which is a different job and one you will do
// far more often.
//
// The situation is completely ordinary. There is a module that works. It
// does not meet timing, or it is too big, or it burns too much power. You
// rewrite it -- pipeline it, retime it, swap the adder chain for a tree,
// replace the loop with a lookup -- and now you have to answer one
// question: is it still the same thing?
//
// A testbench answers "it agreed on the vectors I tried". Equivalence
// checking answers the actual question.
//
// ---------------------------------------------------------------------
// THE HARNESS IS THE TECHNIQUE
//
// Look at formal_top.v. Both implementations are instantiated, both are
// fed the same undriven input, and nothing else joins them. That
// arrangement is called a MITER, and there is nothing more to the method
// than that -- no special mode, no separate tool. Two designs, one
// stimulus, one assertion that the outputs agree.
//
// What you are proving is stronger than any test could be. There are 256
// possible inputs here and a testbench could try all of them, so the
// exhaustiveness is not the interesting part. Widen the word to 32 bits
// and the reference and the tree still prove equivalent in about the same
// time, while the exhaustive test becomes four billion vectors. The proof
// does not care about the width because it never enumerates.
//
// ---------------------------------------------------------------------
// THE PART EVERYONE GETS WRONG: LATENCY
//
// The reference is combinational. The optimised version has a pipeline
// register, so its answer arrives one clock later. They are equivalent,
// and their outputs are never equal on the same clock.
//
//     assert(dut_cnt == ref_cnt);              // fails on a correct design
//     assert(dut_cnt == $past(ref_cnt));       // this is the claim
//
// So "equivalent" is never just "the outputs match". It is "the outputs
// match, with this much skew", and the skew is part of what you are
// asserting -- which is exactly why dut/bad2_wrong_latency.v is here. Its
// arithmetic is perfect. It produces a correct population count of
// something it was given, always. It is one clock later than it should
// be, and everything downstream that was written against a one-clock
// latency is now broken.
//
// A property set that does not pin the latency down will pass it. That is
// not equivalence checking; it is checking that two modules compute the
// same function, which is a weaker and much less useful claim.
//
// ---------------------------------------------------------------------
// WHAT TO DO
//
//   make good   must PASS  -- the pipelined tree, correct
//   make bad1   must FAIL  -- drops bit 7
//   make bad2   must FAIL  -- right answer, one clock late
//   make bad3   must FAIL  -- an OR where an addition was meant
//   make cover  must PASS
//
//   make        all five, with each verdict checked
//
// bad3 is the one worth reading afterwards. It is wrong for 64 of the 256
// possible inputs -- every input with both bit 2 and bit 3 set -- and
// right for the other 192. It is invisible to a one-hot walking-ones
// test, which is the test everybody writes for a popcount.
// =====================================================================

`default_nettype none

module props (
    input wire       clk,
    input wire       rst,
    input wire [7:0] w,
    input wire [3:0] ref_cnt,
    input wire [3:0] dut_cnt
);

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ------------------------------------------------------------------
    // TODO 1: the EQUIVALENCE assertion.
    //
    //   the pipelined output this clock equals the reference output of
    //   the previous clock
    //
    // Gate it on f_past_valid, on !rst, and on !$past(rst) -- the design
    // is coming out of reset with its pipeline registers cleared, and the
    // first clock after reset carries a zero that answers no input at
    // all.
    //
    // Note there is nothing to ASSUME here. `w' is a free 8-bit input,
    // every value of it is legal, and both implementations see the same
    // one because the harness wires them together. An equivalence proof
    // usually needs no assumptions at all, which is a pleasant change and
    // is one of the reasons it is such a good tool: there is almost
    // nowhere to over-constrain.
    //
    // (The exception is when the two designs have different input
    // contracts -- an optimised version that is only valid for aligned
    // addresses, say. Then you assume the contract, and you have to be
    // just as careful about it as in exercise 04, because you are now
    // proving equivalence only where the assumption holds.)
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 2: your COVER statements.
    //
    // The assertion above is inside a guard, so the usual question
    // applies: was it ever evaluated? And there is a sharper one here.
    // The reference and the pipeline agree trivially when everything is
    // zero, so a trace that only ever sees w = 0 proves nothing while
    // passing.
    //
    //   - a non-zero count coming out
    //   - the largest count, 8, which needs w to be all ones
    //   - both bits 2 and 3 set at once, which is the case bad3 gets
    //     wrong. If you cannot reach it, you have not tested for bad3 --
    //     you have merely not been shown it.
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
