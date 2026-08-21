// BUG 2: answers one clock early for every address but the first.
//
// The handshake is impeccable -- exactly one acknowledge per request,
// never outside a request, always within the bound. Only the TIMING is
// wrong, and only for three addresses out of four.
//
// This is the bug that a property set consisting of "the protocol looks
// well formed" will not catch, and it is the reason props.v asks you to
// state the latency exactly rather than as an upper bound.

`default_nettype none

module req_ack_slave (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire       req_i,
    input  wire [2:0] addr_i,
    output reg        ack_o
);

    wire [2:0] latency = {1'b0, addr_i[1:0]} + 3'd1;

    reg [2:0] cnt;

    always @(posedge clk_i) begin
        if (rst_i) begin
            cnt   <= 3'd0;
            ack_o <= 1'b0;
        end else if (ack_o || !req_i) begin
            cnt   <= 3'd0;
            ack_o <= 1'b0;
        end else if (cnt + 3'd2 >= latency) begin   // BUG: +2, not +1
            ack_o <= 1'b1;
            cnt   <= 3'd0;
        end else begin
            cnt   <= cnt + 3'd1;
        end
    end

endmodule

`default_nettype wire
