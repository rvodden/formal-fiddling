// Fixture: one register driven from two always blocks. Simulation runs
// both; synthesis picks one and discards the other. Must be REJECTED.
`default_nettype none
module multi_driver (input wire clk, input wire rst, input wire [3:0] gray);
    reg [3:0] count;
    always @(posedge clk) if (rst) count <= 4'd0;      // BUG: two blocks,
    always @(posedge clk) count <= gray;               //      one register
    always @(*) assert(count == count);
endmodule
`default_nettype wire
