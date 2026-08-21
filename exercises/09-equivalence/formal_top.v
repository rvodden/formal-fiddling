// Harness for an EQUIVALENCE proof, sometimes called a miter.
//
// Both implementations are instantiated side by side and fed the same
// undriven input, so on every step the solver picks one value of w and
// hands it to both. Nothing else connects them; the only thing that will
// ever relate their outputs is a property you write.
//
// This is the whole structure of equivalence checking, and it is worth
// noticing how little there is to it. There is no special mode and no
// special tool -- just two designs, one stimulus, and an assertion that
// their outputs agree.

`default_nettype none

module formal_top (
    input wire       clk,
    input wire       rst,
    input wire [7:0] w
);

    wire [3:0] ref_cnt;
    wire [3:0] dut_cnt;

    popcount_ref u_ref (
        .w_i(w), .cnt_o(ref_cnt));

    popcount_pipe u_dut (
        .clk_i(clk), .rst_i(rst), .w_i(w), .cnt_o(dut_cnt));

    props u_props (
        .clk(clk), .rst(rst), .w(w),
        .ref_cnt(ref_cnt), .dut_cnt(dut_cnt));

endmodule

`default_nettype wire
