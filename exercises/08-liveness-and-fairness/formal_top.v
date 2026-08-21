`default_nettype none

module formal_top (
    input wire       clk,
    input wire       rst,
    input wire [1:0] req
);

    wire [1:0] gnt;

    arbiter u_dut (.clk_i(clk), .rst_i(rst), .req_i(req), .gnt_o(gnt));

    props u_props (.clk(clk), .rst(rst), .req(req), .gnt(gnt));

endmodule

`default_nettype wire
