// BUG 3: contention deadlock. With one requester it is flawless; with
// two it grants nobody at all and stays that way for as long as both
// keep asking.
//
// The shape is familiar from real code -- a case statement whose 2'b11
// arm was never written, so contention falls into a default that does
// nothing. A single-master bring-up test passes. The system wedges the
// first time two things want the bus on the same clock.

`default_nettype none

module arbiter (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire [1:0] req_i,
    output reg  [1:0] gnt_o
);

    always @(posedge clk_i) begin
        if (rst_i) begin
            gnt_o <= 2'b00;
        end else begin
            case (req_i)
                2'b01:   gnt_o <= 2'b01;
                2'b10:   gnt_o <= 2'b10;
                default: gnt_o <= 2'b00;    // BUG: 2'b11 lands here
            endcase
        end
    end

endmodule

`default_nettype wire
