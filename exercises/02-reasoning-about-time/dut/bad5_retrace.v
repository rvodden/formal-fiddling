// BUG 5: a Gray walk that goes out and comes back.
//
// It steps eight times along a path through the sixteen values, then
// retraces the same path home:
//
//     0 -> 1 -> 3 -> 2 -> 6 -> 7 -> 5 -> 4 -> 12
//                                            |
//     0 <- 1 <- 3 <- 2 <- 6 <- 7 <- 5 <- 4 <-+
//
// Every step changes exactly one bit. It holds when told to hold. It
// resets to zero. And it returns to zero on the sixteenth increment and
// not before -- so it satisfies clause 4's FIRST sentence exactly.
//
// It visits nine of the sixteen values. Seven of them it never reaches at
// all, and eight of the ones it does reach it visits twice.
//
// This is the design that separates the two halves of clause 4. A
// property set that checks the return PERIOD passes it; only one that
// checks the counter visits every value sees anything wrong. The
// reference solution originally checked the period alone and passed this
// happily -- it is here because a reader's property set was stronger than
// the reference and caught it.
//
// It is not a contrived failure either. It is what a state machine does
// when its next-state table was written by walking out and copying the
// return path back in reverse, which is a very ordinary way to fill in
// sixteen case arms by hand.

`default_nettype none

module gray_counter (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire       inc_i,
    output reg  [3:0] gray_o
);

    reg [3:0] step;

    always @(posedge clk_i) begin
        if (rst_i) begin
            step   <= 4'd0;
            gray_o <= 4'd0;
        end else if (inc_i) begin
            step <= step + 4'd1;
            case (step)
                4'd0 : gray_o <= 4'd1;
                4'd1 : gray_o <= 4'd3;
                4'd2 : gray_o <= 4'd2;
                4'd3 : gray_o <= 4'd6;
                4'd4 : gray_o <= 4'd7;
                4'd5 : gray_o <= 4'd5;
                4'd6 : gray_o <= 4'd4;
                4'd7 : gray_o <= 4'd12;
                4'd8 : gray_o <= 4'd4;
                4'd9 : gray_o <= 4'd5;
                4'd10: gray_o <= 4'd7;
                4'd11: gray_o <= 4'd6;
                4'd12: gray_o <= 4'd2;
                4'd13: gray_o <= 4'd3;
                4'd14: gray_o <= 4'd1;
                4'd15: gray_o <= 4'd0;
            endcase
        end
    end

endmodule

`default_nettype wire
