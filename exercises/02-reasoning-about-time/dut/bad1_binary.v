// BUG 1: the Gray encoding was left out, so this is a plain binary
// counter wearing a Gray counter's name.
//
// Most of its steps change exactly one bit -- 0->1, 2->3, 4->5 -- so a
// short simulation looks entirely correct. It is the carries that break
// it: 1->2 changes two bits, 7->8 changes four.

`default_nettype none

module gray_counter (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire       inc_i,
    output wire [3:0] gray_o
);

    reg [3:0] bin;

    always @(posedge clk_i)
        if (rst_i)      bin <= 4'd0;
        else if (inc_i) bin <= bin + 4'd1;

    assign gray_o = bin;                  // BUG: no ^ (bin >> 1)

endmodule

`default_nettype wire
