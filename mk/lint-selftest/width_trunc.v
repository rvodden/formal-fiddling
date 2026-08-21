// Fixture: THE one this lint exists for. A 4-bit expression assigned to a
// 1-bit wire, so `changed' holds bit 0 and the assertion below is true of
// every value it can hold -- it can never fail, against any design.
// Must be REJECTED.
`default_nettype none
module width_trunc (input wire clk, input wire rst, input wire [3:0] gray);
    reg [3:0] old_gray;
    always @(posedge clk) old_gray <= gray;
    wire changed = gray ^ old_gray;              // BUG: 1 bit, wanted 4
    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;
    always @(*) if (f_past_valid && !rst) assert((changed & (changed - 1)) == 0);
endmodule
`default_nettype wire
