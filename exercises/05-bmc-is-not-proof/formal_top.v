// Harness. kick is a free input: the solver may kick the watchdog on any
// step, or never.

`default_nettype none

module formal_top (
    input wire clk,
    input wire rst,
    input wire kick
);

    localparam TIMEOUT = 40;

    wire bark;

    watchdog #(.TIMEOUT(TIMEOUT)) u_dut (
        .clk_i(clk), .rst_i(rst), .kick_i(kick), .bark_o(bark));

    props #(.TIMEOUT(TIMEOUT)) u_props (
        .clk(clk), .rst(rst), .kick(kick), .bark(bark));

endmodule

`default_nettype wire
