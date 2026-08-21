// Fixture: a typo'd signal name. `default_nettype none' is supposed to
// make this an error and yosys only warns, which is how it survives long
// enough to matter. Must be REJECTED.
`default_nettype none
module implicit_decl (input wire clk, input wire [3:0] gray);
    reg [3:0] old_gray;
    always @(posedge clk) old_grey <= grey;      // BUG: neither name exists
    always @(*) assert(old_gray == old_gray);
endmodule
`default_nettype wire
