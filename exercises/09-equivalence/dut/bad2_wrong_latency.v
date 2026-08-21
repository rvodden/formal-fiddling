// BUG 2: the right answer, one clock late.
//
// Somebody added a second pipeline stage to close timing. The FUNCTION is
// untouched -- every value this produces is a correct population count of
// something the module was given -- and the module is now out of step
// with everything downstream that was written against a one-clock
// latency.
//
// This is the bug that makes equivalence checking a different discipline
// from testing a function. Feed both versions the same stream and
// compare the multisets of outputs and they agree perfectly. Equivalence
// is a claim about WHEN as well as WHAT, and a property set that does not
// pin the latency down is not checking equivalence at all.

`default_nettype none

module popcount_pipe (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire [7:0] w_i,
    output wire [3:0] cnt_o
);

    reg [1:0] p0, p1, p2, p3;
    reg [3:0] stage2;                       // BUG: an extra clock of delay

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

    always @(posedge clk_i)
        if (rst_i) stage2 <= 4'd0;
        else       stage2 <= p0 + p1 + p2 + p3;

    assign cnt_o = stage2;

endmodule

`default_nettype wire
