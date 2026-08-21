// BUG 1: picks the HIGHEST set bit, not the lowest. Every single-bit
// input still gives the right answer, so this survives a testbench that
// walks a one through req_i -- which is the testbench everyone writes.

`default_nettype none

module prio_encoder (
    input  wire [7:0] req_i,
    output reg  [2:0] idx_o,
    output wire       vld_o
);

    assign vld_o = |req_i;

    always @(*) begin
        casez (req_i)
            8'b1???????: idx_o = 3'd7;
            8'b01??????: idx_o = 3'd6;
            8'b001?????: idx_o = 3'd5;
            8'b0001????: idx_o = 3'd4;
            8'b00001???: idx_o = 3'd3;
            8'b000001??: idx_o = 3'd2;
            8'b0000001?: idx_o = 3'd1;
            8'b00000001: idx_o = 3'd0;
            default:     idx_o = 3'd0;
        endcase
    end

endmodule

`default_nettype wire
