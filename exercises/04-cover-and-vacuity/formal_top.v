// Harness. push and pop are undriven inputs; the assumptions in props are
// the only thing making them behave.

`default_nettype none

module formal_top (
    input wire clk,
    input wire rst,
    input wire push,
    input wire pop
);

    localparam DEPTH = 4;

    wire [2:0] count;
    wire       full, empty;

    fifo_ctrl #(.DEPTH(DEPTH)) u_dut (
        .clk_i(clk), .rst_i(rst), .push_i(push), .pop_i(pop),
        .count_o(count), .full_o(full), .empty_o(empty));

    props #(.DEPTH(DEPTH)) u_props (
        .clk(clk), .rst(rst), .push(push), .pop(pop),
        .count(count), .full(full), .empty(empty));

endmodule

`default_nettype wire
