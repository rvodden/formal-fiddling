// A correct 8-bit priority encoder: idx_o names the LOWEST set bit of
// req_i, and vld_o says whether there was one. Your properties must PASS
// against this.

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
            8'b??100000: idx_o = 3'd5;
            8'b?1000000: idx_o = 3'd6;
            8'b10000000: idx_o = 3'd7;
            default:     idx_o = 3'd0;
        endcase
    end

endmodule

`default_nettype wire
