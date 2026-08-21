// BUG 4: a perfectly good Gray code that is not a counter.
//
// It cycles 0000 -> 0001 -> 0011 -> 0010 -> 0000 for ever. Exactly one
// bit changes on every step, INCLUDING the wrap back to zero. It holds
// when inc is low. It resets to zero.
//
// So it satisfies clauses 1, 2 and 3 of the specification completely,
// and it cannot count past three. Only clause 4 -- sixteen increments to
// get back to zero, and no fewer -- sees anything wrong with it.
//
// This is the counterpart to bad3. There the transitions were all legal
// and it took them when it should have held; here the transitions are
// all legal and it takes them in a circle four steps wide. "Every
// transition is legal" is a weaker statement than people expect, and it
// takes two more clauses to pin down what the design actually has to do.
//
// It is also the shape of a real bug: a state machine whose next-state
// table was written out by hand and stops short, or a counter whose
// width was reduced during an optimisation pass while the encoding was
// left alone.

`default_nettype none

module gray_counter (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire       inc_i,
    output reg  [3:0] gray_o
);

    always @(posedge clk_i) begin
        if (rst_i)
            gray_o <= 4'd0;
        else if (inc_i)
            case (gray_o)
                4'b0000: gray_o <= 4'b0001;
                4'b0001: gray_o <= 4'b0011;
                4'b0011: gray_o <= 4'b0010;
                default: gray_o <= 4'b0000;   // BUG: a four-state cycle
            endcase
    end

endmodule

`default_nettype wire
