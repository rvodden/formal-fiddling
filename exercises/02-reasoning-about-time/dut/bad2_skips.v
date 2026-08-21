// BUG 2: skips a value. The Gray encoding is right, but the underlying
// binary counter jumps from 7 to 9, so that one step changes several
// bits at once.
//
// This is what a real Gray counter bug looks like -- not a missing
// encode, but one state in the sequence that is wrong. It is invisible
// for fifteen of every sixteen steps.

`default_nettype none

module gray_counter (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire       inc_i,
    output wire [3:0] gray_o
);

    reg [3:0] bin;

    always @(posedge clk_i)
        if (rst_i)             bin <= 4'd0;
        else if (inc_i)        bin <= (bin == 4'd7) ? 4'd9 : bin + 4'd1;

    assign gray_o = bin ^ (bin >> 1);

endmodule

`default_nettype wire
