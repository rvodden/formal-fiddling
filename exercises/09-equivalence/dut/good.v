// The optimised version: a two-level adder tree with a pipeline register
// in the middle. Latency one clock. Functionally identical to the
// reference, and your properties must PASS against it.

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
            p1 <= w_i[2] + w_i[3];
            p2 <= w_i[4] + w_i[5];
            p3 <= w_i[6] + w_i[7];
        end
    end

    assign cnt_o = p0 + p1 + p2 + p3;

endmodule

`default_nettype wire
