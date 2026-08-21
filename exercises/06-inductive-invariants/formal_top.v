`default_nettype none

module formal_top (
    input wire clk,
    input wire rst,
    input wire push,
    input wire pop
);

    localparam AW = 3;

    wire [AW:0] count, wptr, rptr;
    wire        full, empty;

    fifo_ptrs #(.AW(AW)) u_dut (
        .clk_i(clk), .rst_i(rst), .push_i(push), .pop_i(pop),
        .count_o(count), .wptr_o(wptr), .rptr_o(rptr),
        .full_o(full), .empty_o(empty));

    props #(.AW(AW)) u_props (
        .clk(clk), .rst(rst), .push(push), .pop(pop),
        .count(count), .wptr(wptr), .rptr(rptr),
        .full(full), .empty(empty));

endmodule

`default_nettype wire
