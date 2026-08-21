// BUG 1: after answering, ack_o is left high for a second clock even
// though the request has gone. An idle bus is left with an acknowledge
// sitting on it, which the next master to look will read as the answer to
// its own request.

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
    reg       hold;

    always @(posedge clk_i) begin
        if (rst_i) begin
            cnt   <= 3'd0;
            ack_o <= 1'b0;
            hold  <= 1'b0;
        end else if (ack_o) begin
            // BUG: holds the acknowledge up for one more clock, with no
            // request underneath it.
            cnt   <= 3'd0;
            ack_o <= hold;
            hold  <= 1'b0;
        end else if (!req_i) begin
            cnt   <= 3'd0;
            ack_o <= 1'b0;
        end else if (cnt + 3'd1 >= latency) begin
            ack_o <= 1'b1;
            hold  <= 1'b1;
            cnt   <= 3'd0;
        end else begin
            cnt   <= cnt + 3'd1;
        end
    end

endmodule

`default_nettype wire
