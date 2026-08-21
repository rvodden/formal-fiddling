// BUG 3: one line of the casez is wrong -- bit 5 reports index 6.
//
// This is the one worth dwelling on. It is wrong for exactly the inputs
// whose lowest set bit is 5 -- req[4:0] all clear, req[5] set, the top
// two bits free. That is 4 of the 256 possible values: one in sixty-four.
//
// A directed testbench that walks a single one through req_i does catch
// it, because 8'b00100000 is one of the four. A random testbench needs
// about sixty draws to expect a hit, and will report a clean run rather
// more often than anyone is comfortable with. A testbench that checks
// "the cases that seemed interesting" may never hit it at all.
//
// This is the shape almost every real encoder bug has: correct
// everywhere except one entry of a table that someone typed by hand.

`default_nettype none

module prio_encoder (
    input  wire [7:0] req_i,
    output reg  [2:0] idx_o,
    output wire       vld_o
);

    assign vld_o = |req_i;

    always @(*) begin
        casez (req_i)
            8'b???????1: idx_o = 3'd0;
            8'b??????10: idx_o = 3'd1;
            8'b?????100: idx_o = 3'd2;
            8'b????1000: idx_o = 3'd3;
            8'b???10000: idx_o = 3'd4;
            8'b??100000: idx_o = 3'd6;   // BUG: should be 3'd5
            8'b?1000000: idx_o = 3'd6;
            8'b10000000: idx_o = 3'd7;
            default:     idx_o = 3'd0;
        endcase
    end

endmodule

`default_nettype wire
