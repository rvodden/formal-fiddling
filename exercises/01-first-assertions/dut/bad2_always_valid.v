// BUG 2: vld_o is stuck high, so an idle encoder claims to have found
// something at index 0. Downstream this is a phantom request that never
// goes away.

`default_nettype none

module prio_encoder (
    input  wire [7:0] req_i,
    output reg  [2:0] idx_o,
    output wire       vld_o
);

    assign vld_o = 1'b1;                  // BUG: should be |req_i

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
