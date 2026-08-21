// A correct two-master round-robin arbiter.
//
// A grant lasts exactly one clock -- one transfer, then arbitrate again.
// That is what makes fairness achievable at all: an arbiter that lets an
// owner keep the bus for as long as it keeps asking cannot promise
// anybody anything, however fair its policy.

`default_nettype none

module arbiter (
    input  wire       clk_i,
    input  wire       rst_i,
    input  wire [1:0] req_i,
    output reg  [1:0] gnt_o
);

    reg last;                               // who went most recently

    always @(posedge clk_i) begin
        if (rst_i) begin
            gnt_o <= 2'b00;
            last  <= 1'b0;
        end else begin
            case (req_i)
                2'b00: gnt_o <= 2'b00;
                2'b01: begin gnt_o <= 2'b01; last <= 1'b0; end
                2'b10: begin gnt_o <= 2'b10; last <= 1'b1; end
                2'b11: if (last) begin gnt_o <= 2'b01; last <= 1'b0; end
                       else      begin gnt_o <= 2'b10; last <= 1'b1; end
            endcase
        end
    end

endmodule

`default_nettype wire
