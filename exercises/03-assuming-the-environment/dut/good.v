// A correct request/acknowledge slave.
//
// It answers a request `latency' clocks after it appears, where the
// latency is decided by the low two bits of the address and runs from 1
// to 4. The variable latency is deliberate: it means the address is part
// of the transaction's meaning for its whole duration, not just at the
// start, which is what makes the stability contract in props.v matter.
//
// Your properties must PASS against this -- but they will not do so until
// you have written the assumptions. See the header of props.v.

`default_nettype none

module req_ack_slave (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire       req_i,
    input  wire [2:0] addr_i,
    output reg        ack_o
);

    // 1, 2, 3 or 4 clocks, by address.
    wire [2:0] latency = {1'b0, addr_i[1:0]} + 3'd1;

    reg [2:0] cnt;

    always @(posedge clk_i) begin
        if (rst_i) begin
            cnt   <= 3'd0;
            ack_o <= 1'b0;
        end else if (ack_o || !req_i) begin
            // The request is over, either because we just answered it or
            // because the master withdrew it. Either way, start again.
            cnt   <= 3'd0;
            ack_o <= 1'b0;
        end else if (cnt + 3'd1 >= latency) begin
            ack_o <= 1'b1;
            cnt   <= 3'd0;
        end else begin
            cnt   <= cnt + 3'd1;
        end
    end

endmodule

`default_nettype wire
