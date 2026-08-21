// =====================================================================
// Exercise 01 -- your first assertions, on combinational logic.
//
// The design is an 8-bit priority encoder. `idx_o' names the LOWEST set
// bit of `req_i'; `vld_o' says whether there was one at all. That is the
// entire specification and it fits in two sentences -- which is the
// point, because you are about to discover how many separate claims are
// hiding inside those two sentences.
//
// ---------------------------------------------------------------------
// WHY START WITH COMBINATIONAL LOGIC
//
// Because here formal verification is not "better testing". It is a
// different category of answer, and the difference is arithmetic.
//
// This encoder has 8 inputs, so 256 possible values. You could loop over
// all 256 in a testbench in about a microsecond and be genuinely, totally
// finished -- exhaustive, no argument.
//
// Now make it 32 bits wide, which is an ordinary thing to want. That is
// 4,294,967,296 values. At a hundred million a second, an exhaustive
// simulation is forty-three seconds -- still fine. At 64 bits it is six
// hundred years.
//
// The solver does not enumerate. It reasons about the structure of the
// logic, so a 64-bit encoder proves in about the same time as an 8-bit
// one. The width simply stops being a consideration, and that is a thing
// simulation can never offer you at any budget.
//
// So: 8 bits here because it keeps the counterexamples readable. Nothing
// you write below would need changing at 64.
//
// ---------------------------------------------------------------------
// DEPTH 1 IS A COMPLETE PROOF HERE, AND THAT IS UNUSUAL
//
// prove.sby runs these at `depth 2'. For combinational logic that is not
// a bounded check that might miss something deeper: the design has no
// state, so there is no "deeper". Every possible behaviour of a
// combinational block is visible in one step, and a solver that fails to
// break it in one step cannot break it in a million.
//
// Enjoy it. From exercise 02 onwards there is state, and from exercise 05
// onwards the gap between "no counterexample within N steps" and "proved"
// is the thing that will bite you.
//
// ---------------------------------------------------------------------
// WHAT TO DO
//
//   make good   must PASS  -- a correct encoder
//   make bad1   must FAIL  -- picks the highest set bit, not the lowest
//   make bad2   must FAIL  -- vld_o stuck high
//   make bad3   must FAIL  -- one line of the table reports the wrong index
//   make cover  must PASS  -- your assumptions left something reachable
//
//   make        all five, with each verdict checked
//
// Write the fewest properties that get all five right, then compare with
// solutions/01-first-assertions/props.v.
//
// ---------------------------------------------------------------------
// A WARNING ABOUT bad1, WHICH IS THE INTERESTING ONE
//
// It is easy to write a property set that catches bad2 and bad3 and lets
// bad1 through, and the way it happens is instructive.
//
// "idx_o points at a bit that is actually set" is true of bad1 -- the
// highest set bit is a set bit. If that is all you assert, the encoder is
// free to pick any set bit it fancies and you have proved nothing about
// priority at all. Priority is a statement about the bits it did NOT
// pick, and you have to say so explicitly.
//
// This is the single most common shape of a weak property: asserting that
// the answer is plausible rather than that it is the answer.
// =====================================================================

`default_nettype none

module props (
    input wire [7:0] req,
    input wire [2:0] idx,
    input wire       vld
);

    // ------------------------------------------------------------------
    // TODO: your assertions go here.
    //
    // There is no clock and no reset in this module, and no `assume'
    // either -- req is an 8-bit input with no illegal values, so there is
    // nothing about the environment to constrain. Every statement you
    // write is `always @(*) assert(...)'.
    //
    // Things worth stating. You do not need all of them and you may want
    // others:
    //
    //   - if no bit of req is set, vld is low
    //   - if any bit of req is set, vld is high
    //   - when vld is high, the bit req[idx] is actually set
    //   - when vld is high, NO BIT BELOW idx is set. This is the one that
    //     catches bad1, and it is the only statement here that says
    //     anything about priority.
    //
    // For that last one: the bits below idx are the mask (1 << idx) - 1.
    // A variable shift is a legal thing to write in a property and the
    // solver handles it without complaint, but if you would rather not,
    // there is a neat alternative -- for every bit position i, if req[i]
    // is set then idx <= i. That is eight statements, or one generate
    // loop, and it says the same thing.
    //
    // COVER, to show the model is not strangled. With no assumptions at
    // all these are all trivially reachable, which is exactly the point:
    // you should see what a healthy cover run looks like before exercise
    // 04 shows you a sick one.
    //
    //   - a trace where vld is high
    //   - a trace where vld is low
    //   - a trace where idx is 7
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
