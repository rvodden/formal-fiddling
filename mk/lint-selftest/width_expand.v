// Fixture: a literal wider than the register it lands in. Harmless here,
// but a sized literal is a claim about width and a wrong claim is worth a
// look. Must be REJECTED.
`default_nettype none
module width_expand (input wire clk, input wire rst);
    reg [3:0] old_gray;
    always @(posedge clk) if (rst) old_gray <= 8'b0;   // BUG: 8 into 4
                          else     old_gray <= old_gray;
    always @(*) assert(old_gray == old_gray);
endmodule
`default_nettype wire
