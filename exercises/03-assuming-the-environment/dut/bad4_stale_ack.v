// BUG 4: reset does not clear the acknowledge.
//
// Everything else about this slave is correct -- the latency is right,
// one request draws one ack, it never answers without a request. The
// single fault is that `ack_o' is left out of the reset branch, so an
// acknowledge that was on the wire when reset arrived is still there on
// the clock after reset lets go.
//
// The whole of its misbehaviour is confined to ONE CLOCK: the first one
// after reset lets go. From the clock after that it is indistinguishable
// from good.v.
//
// Wishbone-style resets are SYNCHRONOUS, so a slave clears its outputs on
// a clock edge rather than the instant reset rises. One clock of overhang
// is therefore unavoidable and legal. Clause 5 is about the clock AFTER
// that one, by which time the slave has had an edge to tidy itself up and
// there is no excuse left.
//
// THE REASON THIS DESIGN IS HERE. It asks one question of your property
// set: does ANYTHING you wrote actually run on the first clock out of
// reset?
//
// Very often nothing does. Assertions about a slave are naturally written
// under a guard like
//
//     if (f_past_valid && !rst && !$past(rst)) ...
//
// and that guard excludes precisely that clock, because `!$past(rst)' is
// false on it. Clause 5 is the one clause written about that clock, so
// putting it inside such a block does not merely weaken it -- it makes it
// UNREACHABLE. The block's guard and the assertion's own condition
// contradict each other, so it never runs, never fails, and looks exactly
// like a property that holds.
//
// Clauses 4 and 7 would catch this design too, if they ran on that clock.
// They usually do not, for the same reason.
//
// This DUT exists because a reader's property set had exactly that dead
// assertion in it, got every other verdict right, and had no way of
// finding out.

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
            cnt <= 3'd0;                        // BUG: ack_o is not cleared
        end else if (ack_o || !req_i) begin
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
