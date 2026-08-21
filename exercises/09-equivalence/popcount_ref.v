// THE REFERENCE. Combinational, obvious, slow, and not to be modified.
//
// This is the specification in executable form: it counts the set bits of
// an 8-bit word by adding them up, and it is correct because you can read
// it in one go and see that it is.
//
// It is also a long adder chain and it will not meet timing at any clock
// rate worth having, which is why somebody pipelined it. Proving that the
// pipelined version still does this is the exercise.

`default_nettype none

module popcount_ref (
    input  wire [7:0] w_i,
    output wire [3:0] cnt_o
);

    assign cnt_o = w_i[0] + w_i[1] + w_i[2] + w_i[3] +
                   w_i[4] + w_i[5] + w_i[6] + w_i[7];

endmodule

`default_nettype wire
