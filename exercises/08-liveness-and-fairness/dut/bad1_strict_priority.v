// BUG 1: strict priority. Master 0 wins every contested clock, so master
// 1 gets the bus only when master 0 does not want it.
//
// This is a real arbiter -- people ship it deliberately, and for a
// latency-critical port against a background DMA it is the right answer.
// It is only a bug because the specification here promises a bound to
// BOTH masters, and strict priority cannot give one to the loser.
//
// Nothing about it is malformed. The grant is one-hot, it never grants a
// master that did not ask, it never grants two at once. Every SAFETY
// property in props.v passes. Only the liveness property sees it, and
// that is the point of this exercise: starvation is invisible to
// "nothing bad happens" and is the thing arbiters actually get wrong.

`default_nettype none

module arbiter (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire [1:0] req_i,
    output reg  [1:0] gnt_o
);

    always @(posedge clk_i) begin
        if (rst_i)
            gnt_o <= 2'b00;
        else if (req_i[0])                  // BUG: master 0 always wins
            gnt_o <= 2'b01;
        else if (req_i[1])
            gnt_o <= 2'b10;
        else
            gnt_o <= 2'b00;
    end

endmodule

`default_nettype wire
