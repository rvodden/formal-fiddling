`default_nettype none

module formal_top (
    input wire       clk,
    input wire       rst,
    input wire       push,
    input wire [3:0] wdata,
    input wire       pop
);

    localparam AW = 2;
    localparam DW = 4;

    wire [DW-1:0] rdata;
    wire          full, empty;

    fifo #(.AW(AW), .DW(DW)) u_dut (
        .clk_i(clk), .rst_i(rst),
        .push_i(push), .wdata_i(wdata),
        .pop_i(pop), .rdata_o(rdata),
        .full_o(full), .empty_o(empty));

    props #(.AW(AW), .DW(DW)) u_props (
        .clk(clk), .rst(rst),
        .push(push), .wdata(wdata),
        .pop(pop), .rdata(rdata),
        .full(full), .empty(empty));

endmodule

`default_nettype wire
