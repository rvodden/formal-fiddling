// Fixture: a property file with nothing wrong with it. Must be ACCEPTED.
`default_nettype none
module clean (input wire clk, input wire rst, input wire [3:0] gray);
    reg [3:0] old_gray;
    always @(posedge clk) old_gray <= gray;
    wire [3:0] changed = gray ^ old_gray;
    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;
    always @(*) if (f_past_valid && !rst) assert(changed != 4'hF);
endmodule
`default_nettype wire
