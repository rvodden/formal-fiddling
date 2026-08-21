// =====================================================================
// The design under test for exercise 05: a watchdog timer.
//
// It counts clocks since the last kick, and is supposed to bark when
// TIMEOUT of them have gone by without one. It never barks.
//
// The bug is one of the most ordinary in the language and it is not
// visible from the line it is on. Do not fix it -- this exercise is about
// how nearly you can miss it.
// =====================================================================

`default_nettype none

module watchdog #(
    parameter TIMEOUT = 40
) (
    input  wire clk_i,
    input  wire rst_i,
    input  wire kick_i,
    output reg  bark_o
);

    // BUG: five bits. This counter holds 0 to 31, and it is being
    // compared against 40.
    //
    // Verilog widens both sides of a comparison to the wider of the two,
    // so `cnt == TIMEOUT' is a perfectly legal six-bit comparison in
    // which the left-hand side can never exceed 31. It is never true. The
    // counter simply wraps at 32 and goes round again, forever, and the
    // watchdog waits quietly for a value it cannot reach.
    //
    // Nothing warns you. It elaborates, it simulates, it synthesises. On
    // a board it looks exactly like a watchdog that has not timed out
    // yet.
    reg [4:0] cnt;

    always @(posedge clk_i) begin
        if (rst_i || kick_i) begin
            cnt    <= 5'd0;
            bark_o <= 1'b0;
        end else if (cnt == TIMEOUT) begin
            bark_o <= 1'b1;
        end else begin
            cnt    <= cnt + 5'd1;
        end
    end

endmodule

`default_nettype wire
