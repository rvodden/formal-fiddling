// BUG 1: bit 7 was dropped on the way into the tree.
//
// The result is simply too small whenever bit 7 is set -- half of all
// inputs. This is the easy one, and it is here so that a property set
// that catches nothing at all is distinguishable from one that catches
// only the easy things.

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
            p3 <= w_i[6];           // BUG: w_i[7] is not counted
        end
    end

    assign cnt_o = p0 + p1 + p2 + p3;

endmodule

`default_nettype wire
