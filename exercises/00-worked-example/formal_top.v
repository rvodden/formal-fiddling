// Harness: bolt the property set onto the design.
//
// Nothing drives clk, rst or inc -- they are inputs to this module and
// this module is the top. That is deliberate and it is the whole trick:
// an undriven input is a signal the solver may set to anything it likes
// on every step, which is precisely the exhaustive stimulus you are
// paying for. Whatever legal behaviour you need to pin down, you pin down
// with `assume' inside props, not by driving wires here.

`default_nettype none

module formal_top (
    input wire clk,
    input wire rst,
    input wire inc
);

    localparam LIMIT = 10;

    wire [3:0] count;

    sat_counter #(.LIMIT(LIMIT)) u_dut (
        .clk_i(clk), .rst_i(rst), .inc_i(inc), .count_o(count));

    props #(.LIMIT(LIMIT)) u_props (
        .clk(clk), .rst(rst), .inc(inc), .count(count));

endmodule

`default_nettype wire
