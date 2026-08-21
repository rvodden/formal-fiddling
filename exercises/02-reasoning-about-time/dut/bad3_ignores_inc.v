// BUG 3: free-running. Every step it takes is a legal Gray step, so a
// property set that only checks "one bit changes at a time" passes this
// happily -- and the counter is nonetheless completely wrong, because it
// advances when it was told to hold.
//
// The lesson is that "every transition is legal" is not the same claim as
// "it transitions when it should". You need both.

`default_nettype none

module gray_counter (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire       inc_i,
    output wire [3:0] gray_o
);

    reg [3:0] bin;

    always @(posedge clk_i)
        if (rst_i) bin <= 4'd0;
        else       bin <= bin + 4'd1;     // BUG: inc_i is not consulted

    assign gray_o = bin ^ (bin >> 1);

endmodule

`default_nettype wire
