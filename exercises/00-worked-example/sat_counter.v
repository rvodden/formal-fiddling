// =====================================================================
// The design under test for the worked example: a saturating counter.
//
// It counts up while inc_i is high and is supposed to STOP at LIMIT --
// that is the entire specification, and it fits in one sentence, which
// is unusual and convenient.
//
// As shipped it does not do that. The bug is one missing term and it is
// marked. Do not fix it here; the point of this exercise is to watch a
// solver find it for you.
// =====================================================================

`default_nettype none

module sat_counter #(
    parameter LIMIT = 10
) (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire       inc_i,
    output reg  [3:0] count_o
);

    always @(posedge clk_i) begin
        if (rst_i)
            count_o <= 4'd0;
`ifdef FIXED
        else if (inc_i && count_o < LIMIT[3:0])
            count_o <= count_o + 4'd1;
`else
        // BUG: nothing here stops at LIMIT. It counts to 15 and wraps.
        else if (inc_i)
            count_o <= count_o + 4'd1;
`endif
    end

endmodule

`default_nettype wire
