// Reference solution for exercise 09 -- equivalence with latency.
//
// One assertion and three cover statements. The assertion is one line and
// the only thing that makes it interesting is the $past.

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
    // THE EQUIVALENCE ASSERTION.
    //
    // The pipelined answer this clock is the reference answer of last
    // clock. That single $past is the difference between an equivalence
    // proof and a claim that two modules compute the same function --
    // and it is what catches bad2, whose arithmetic is flawless and
    // whose timing is not.
    //
    // The guard is three terms. f_past_valid because there is no previous
    // clock on step 0. !rst because a design being held in reset owes
    // nothing. !$past(rst) because on the first clock out of reset the
    // pipeline register still holds the zero that reset put there, and
    // that zero is not the answer to any input -- assert against it and
    // the correct design fails, which is a confusing half hour if you
    // have not met it before.
    // ------------------------------------------------------------------
    always @(posedge clk)
        if (f_past_valid && !rst && !$past(rst))
            assert(dut_cnt == $past(ref_cnt));


    // ------------------------------------------------------------------
    // COVER. C3 is the one that matters.
    // ------------------------------------------------------------------
    always @(posedge clk) if (f_past_valid && !rst) begin

        // C1. Something other than zero comes out. Two implementations
        //     that both output zero agree perfectly and prove nothing,
        //     and a trace in which w never leaves 0 would do exactly
        //     that.
        cover(dut_cnt != 4'd0);

        // C2. The full count. All ones is the input that exercises every
        //     adder in the tree at once and every carry in the reference
        //     chain, and it is cheap to ask for.
        cover(dut_cnt == 4'd8);

        // C3. Both bits of one pair set at the same time.
        //
        //     This is the case bad3 gets wrong -- its OR returns 1 where
        //     the addition returns 2 -- and it is the case a walking-ones
        //     test can never produce, because a walking-ones test never
        //     sets two bits at once.
        //
        //     Being unable to reach it would mean the bad3 result was
        //     luck rather than coverage. Naming the awkward input in a
        //     cover statement is the cheapest insurance in this file.
        cover(w[2] && w[3]);

    end

endmodule

`default_nettype wire
