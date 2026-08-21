// Reference solution for exercise 03 -- assumptions and assertions for a
// request/acknowledge slave.
//
// Two assumptions, four assertions, three cover statements. The shape --
// ASSUME what the other side promises, ASSERT what this side owes -- is
// the one that carries over unchanged to AXI, AHB, Wishbone and every
// other interface you will ever verify. Get it backwards and you either
// prove nothing (assume everything) or spend a day chasing
// counterexamples that could not happen.

`default_nettype none

module props (
    input wire       clk,
    input wire       rst,
    input wire       req,
    input wire [2:0] addr,
    input wire       ack
);

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    wire [2:0] latency = {1'b0, addr[1:0]} + 3'd1;

    reg [3:0] f_outstanding;
    always @(posedge clk)
        if (rst || !req || ack) f_outstanding <= 4'd0;
        else                    f_outstanding <= f_outstanding + 4'd1;

    // ==================================================================
    // ASSUMPTIONS -- what a legal master does.
    // ==================================================================

    // A1. Nothing outstanding during reset. Without this the solver
    //     starts a transaction, asserts reset underneath it, and hands
    //     you a counterexample about a state no system ever occupies.
    always @(*)
        if (rst) assume(!req);

    // A2. A request that has not been answered does not move.
    //
    //     THIS is the assumption the exercise is about. Leave it out and
    //     the correct slave fails: the solver raises a request at address
    //     3 (latency 4), changes it to address 0 (latency 1) two clocks
    //     later, and the slave answers against a latency that changed
    //     under it.
    //
    //     Note what it does NOT say. It says nothing about which address
    //     a master may pick, when it may start a request, how long it may
    //     leave the bus idle, or whether it must ever make a request at
    //     all. Every one of those stays free, and every one of them stays
    //     part of what has been proved. An assumption should pin down
    //     exactly the obligation being relied on and nothing else --
    //     because everything it pins down beyond that is behaviour the
    //     proof silently stops covering.
    always @(posedge clk)
        if (f_past_valid && !rst && !$past(rst) && $past(req) && !$past(ack)) begin
            assume(req);
            assume(addr == $past(addr));
        end

    // ==================================================================
    // ASSERTIONS -- what the slave owes.
    // ==================================================================

    // Every assertion is gated on f_past_valid: at step 0 the slave's
    // registers have not been through a reset edge, so their values are
    // arbitrary and asserting anything about them proves nothing.

    // S1. No acknowledge without a request under it.
    //
    //     This is what catches bad1, and it is not fussiness. An ack left
    //     on an idle bus is read by the next master to look as the answer
    //     to its own request -- so the fault appears in a module that is
    //     entirely correct, which is a memorable afternoon.
    always @(*)
        if (f_past_valid && !rst && !req) assert(!ack);

    // S2. Silent for the clock after reset. Reset here is synchronous, so
    //     an acknowledge already registered before rst went high is still
    //     on the wire for one more clock -- this is about the clock after
    //     that one.
    always @(posedge clk)
        if (f_past_valid && $past(rst)) assert(!ack);

    // S3. One acknowledge per request. The slave clears its own ack; it
    //     does not wait to be asked.
    always @(posedge clk)
        if (f_past_valid && !rst && $past(ack)) assert(!ack);

    // S4. The acknowledge lands EXACTLY on time.
    //
    //     `latency' is read at the instant of the acknowledge, which is
    //     only a meaningful thing to do because A2 assumed the address
    //     holds still for the whole transaction. Remove A2 and this
    //     property stops being well defined, which is precisely why the
    //     good design fails without it.
    //
    //     This is what catches bad2, whose handshake is otherwise
    //     perfect.
    always @(*)
        if (f_past_valid && !rst && ack)
            assert(f_outstanding == {1'b0, latency});

    // S5. The acknowledge arrives AT ALL, within the longest latency the
    //     address map allows.
    //
    //     It is tempting to think S4 has already covered this -- it pins
    //     the acknowledge to an exact clock, and what more is there to
    //     say? But read S4 again: every word of it is conditional on
    //     `ack'. It constrains acknowledges that happen. It is completely
    //     silent about a slave that never acknowledges anything, and is
    //     therefore satisfied, perfectly and vacuously, by a brick.
    //
    //     That is bad3: address 7 decodes to nothing and it simply never
    //     answers. S1 to S4 all pass against it.
    //
    //     The distinction has a name. S1..S4 are SAFETY properties --
    //     nothing bad happens. S5 is the useful, bounded form of a
    //     LIVENESS property -- something good does happen, and here is
    //     the clock by which. Almost every property set that is missing
    //     something is missing a liveness property, because the safety
    //     ones are the ones that come to mind. Exercise 08 is about how
    //     far this can be pushed, and where it stops.
    //
    //     The bound is 4 because that is the slowest address in the map.
    //     A number pulled from the design rather than from the
    //     specification would be a property that agrees with whatever the
    //     design does, which is no property at all.
    localparam MAX_WAIT = 4;

    always @(*)
        if (f_past_valid && !rst) assert(f_outstanding <= MAX_WAIT[3:0]);

    // ==================================================================
    // COVER -- the evidence that the four above were proved about
    // something rather than about nothing.
    // ==================================================================

    // A counter for the last cover statement: two completed transactions
    // in one trace. One is not enough to show the slave is reusable --
    // a design that answers once and then wedges satisfies every
    // assertion above, because every assertion above is about
    // acknowledges that happen and none of them insists any ever does.
    // That gap is real, it is called liveness, and exercise 08 is about
    // how far you can close it.
    reg [3:0] f_acks;
    always @(posedge clk)
        if (rst)      f_acks <= 4'd0;
        else if (ack) f_acks <= f_acks + 4'd1;

    always @(posedge clk) if (f_past_valid && !rst) begin
        cover(ack);                                  // anything is answered
        cover(ack && f_outstanding == 4'd4);         // the slowest address too
        cover(f_acks == 4'd2);                       // and it can be reused
    end

endmodule

`default_nettype wire
