// The same watchdog with the counter one bit wider -- i.e. correct.
//
// Byte for byte identical to watchdog.v except that `cnt' is six bits
// instead of five, so it can actually hold the 40 it is compared against.
// That is the whole fix.
//
// IT IS HERE SO THAT YOUR PROPERTY CAN BE CALIBRATED, and nothing else.
// The exercise is about depth, not about finding this bug -- you were
// told what the bug is in the header of watchdog.v.
//
// The reason it is needed: an assertion can be WRONG BY BEING TOO TIGHT,
// and with only a broken design to run against, too tight and exactly
// right look identical. Both reject the broken watchdog. Only a correct
// watchdog can tell them apart.
//
// The specific trap is one clock wide. `bark_o' is registered: the design
// decides on the clock where the count reaches TIMEOUT, and the output
// appears on the NEXT one. So at the moment the quiet spell has lasted
// exactly TIMEOUT clocks, a correct watchdog has not barked yet -- and a
// property that demands it has is rejecting correct hardware.
//
// This DUT exists because a reader's property set did exactly that, got
// every other verdict in the exercise right, and had nothing to tell it.

`default_nettype none

module watchdog #(
    parameter TIMEOUT = 40
) (
    input  wire clk_i,
    input  wire rst_i,
    input  wire kick_i,
    output reg  bark_o
);

    reg [5:0] cnt;                          // six bits: 0 to 63

    always @(posedge clk_i) begin
        if (rst_i || kick_i) begin
            cnt    <= 6'd0;
            bark_o <= 1'b0;
        end else if (cnt == TIMEOUT) begin
            bark_o <= 1'b1;
        end else begin
            cnt    <= cnt + 6'd1;
        end
    end

endmodule

`default_nettype wire
