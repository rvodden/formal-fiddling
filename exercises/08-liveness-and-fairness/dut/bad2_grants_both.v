// BUG 2: when both masters ask, both are granted.
//
// Perfectly fair -- nobody waits, ever, so the liveness property is
// delighted. It has simply stopped being an arbiter, which is a safety
// failure and needs a safety property to see it.
//
// bad1 and bad2 between them are why a property set needs both kinds. A
// set with only safety properties passes bad1; a set with only liveness
// properties passes bad2.

`default_nettype none

module arbiter (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire [1:0] req_i,
    output reg  [1:0] gnt_o
);

    always @(posedge clk_i)
        if (rst_i) gnt_o <= 2'b00;
        else       gnt_o <= req_i;          // BUG: grants everyone who asks

endmodule

`default_nettype wire
