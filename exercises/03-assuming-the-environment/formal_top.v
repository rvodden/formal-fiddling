// Harness. req, addr, rst and clk are undriven inputs, so the solver may
// do anything at all with them -- including things no legal master would
// do. Constraining it to legal master behaviour is your job, in props.v,
// with `assume'. Every DUT in dut/ is called req_ack_slave.

`default_nettype none

module formal_top (
    input wire       clk,
    input wire       rst,
    input wire       req,
    input wire [2:0] addr
);

    wire ack;

    req_ack_slave u_dut (
        .clk_i(clk), .rst_i(rst), .req_i(req), .addr_i(addr), .ack_o(ack));

    props u_props (
        .clk(clk), .rst(rst), .req(req), .addr(addr), .ack(ack));

endmodule

`default_nettype wire
