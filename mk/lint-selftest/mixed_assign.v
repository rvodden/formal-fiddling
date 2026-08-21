// Fixture: one signal assigned with both `=' and `<=' in one block.
// Must be REJECTED.
`default_nettype none
module mixed_assign (input wire clk, input wire [3:0] gray);
    reg [3:0] count;
    always @(posedge clk) begin
        count = count + 4'd1;                    // BUG: both here...
        count <= gray;                           // ...and here
    end
    always @(*) assert(count == count);
endmodule
`default_nettype wire
