// Harness. clk, rst and inc are undriven inputs: the solver chooses them
// freely on every step. Every DUT in dut/ is called gray_counter.

`default_nettype none

module formal_top (
    input wire clk,
    input wire rst,
    input wire inc
);

    wire [3:0] gray;

    gray_counter u_dut (
        .clk_i(clk), .rst_i(rst), .inc_i(inc), .gray_o(gray));

    props u_props (
        .clk(clk), .rst(rst), .inc(inc), .gray(gray));

endmodule

`default_nettype wire
