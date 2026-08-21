// A correct 4-bit Gray counter. Holds while inc_i is low; advances by one
// Gray step while it is high. Your properties must PASS against this.

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

    assign gray_o = bin ^ (bin >> 1);

endmodule

`default_nettype wire
