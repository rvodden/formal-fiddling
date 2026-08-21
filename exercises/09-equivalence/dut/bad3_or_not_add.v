// BUG 3: an OR where an addition was meant.
//
// `w_i[2] | w_i[3]' is 1 when either bit is set and `w_i[2] + w_i[3]' is
// 2 when both are. They agree on three of the four combinations of that
// pair, so the module is right for 192 of the 256 possible inputs and
// short by one for the other 64.
//
// This is what an optimisation bug actually looks like. Nobody types an
// OR instead of a plus at random; they type it while replacing an adder
// with something cheaper, having convinced themselves the carry cannot
// happen. A directed test of one-hot inputs never sees it, because a
// one-hot input never sets both bits.

`default_nettype none

module popcount_pipe (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire [7:0] w_i,
    output wire [3:0] cnt_o
);

    reg [1:0] p0, p1, p2, p3;

    always @(posedge clk_i) begin
        if (rst_i) begin
            p0 <= 2'd0;  p1 <= 2'd0;  p2 <= 2'd0;  p3 <= 2'd0;
        end else begin
            p0 <= w_i[0] + w_i[1];
            p1 <= w_i[2] | w_i[3];  // BUG: OR, not add
            p2 <= w_i[4] + w_i[5];
            p3 <= w_i[6] + w_i[7];
        end
    end

    assign cnt_o = p0 + p1 + p2 + p3;

endmodule

`default_nettype wire
