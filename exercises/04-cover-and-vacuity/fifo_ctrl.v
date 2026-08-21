// =====================================================================
// The design under test for exercise 04: the occupancy counter of a
// four-deep FIFO.
//
// No storage -- just the count, the full flag and the empty flag, which
// is where FIFO bugs actually live. (Storage, and proving that what goes
// in comes out, is exercise 07.)
//
// It has a bug, and the bug is a real one: an off-by-one in `full_o'. Do
// not fix it. This exercise is not about the FIFO. It is about a property
// set that fails to notice.
// =====================================================================

`default_nettype none

module fifo_ctrl #(
    parameter DEPTH = 4
) (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire       push_i,
    input  wire       pop_i,
    output wire [2:0] count_o,
    output wire       full_o,
    output wire       empty_o
);

    reg [2:0] count;

    always @(posedge clk_i) begin
        if (rst_i)
            count <= 3'd0;
        else
            case ({push_i, pop_i})
                2'b10:   count <= count + 3'd1;
                2'b01:   count <= count - 3'd1;
                default: ;                     // both or neither: no change
            endcase
    end

    assign count_o = count;
    assign empty_o = (count == 3'd0);

    // BUG: off by one. This says "full" only once there are five things
    // in a four-deep queue, so a producer that politely waits for full_o
    // to clear is still invited to push a fifth.
    assign full_o  = (count == DEPTH[2:0] + 3'd1);

endmodule

`default_nettype wire
