// BUG 3: address 7 decodes to nothing, and instead of saying so the
// slave simply never answers.
//
// On a real bus this is the single most common reason a board appears
// dead: one peripheral that never terminates its cycle, holding the bus
// forever, with no error and no timeout and nothing on any LED.
//
// Note that it is perfectly well behaved for the other seven addresses.

`default_nettype none

module req_ack_slave (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire       req_i,
    input  wire [2:0] addr_i,
    output reg        ack_o
);

    wire [2:0] latency = {1'b0, addr_i[1:0]} + 3'd1;
    wire       exists  = (addr_i != 3'd7);          // BUG: 7 is a hole

    reg [2:0] cnt;

    always @(posedge clk_i) begin
        if (rst_i) begin
            cnt   <= 3'd0;
            ack_o <= 1'b0;
        end else if (ack_o || !req_i) begin
            cnt   <= 3'd0;
            ack_o <= 1'b0;
        end else if (exists && cnt + 3'd1 >= latency) begin
            ack_o <= 1'b1;
            cnt   <= 3'd0;
        end else begin
            cnt   <= cnt + 3'd1;
        end
    end

endmodule

`default_nettype wire
