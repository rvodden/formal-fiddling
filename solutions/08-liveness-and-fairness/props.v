// Reference solution for exercise 08 -- safety and liveness for a
// two-master arbiter.
//
// One fairness assumption, three safety assertions, one liveness
// assertion, three cover statements. The single most interesting line in
// the file is the assumption, and what is interesting about it is how
// little it says.

`default_nettype none

module props (
    input wire       clk,
    input wire       rst,
    input wire [1:0] req,
    input wire [1:0] gnt
);

    // The promise. Round robin with one-clock grants: a master waiting
    // behind the other one waits for that master's single clock and then
    // its own arbitration, so two is the worst case and three is the
    // bound with a clock of margin.
    //
    // Taken from the policy, not from watching what the design does.
    localparam MAX_WAIT = 3;

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ------------------------------------------------------------------
    // GIVEN: how long each master has been asking without being served.
    // Cleared by reset, by being granted, and by giving up.
    // ------------------------------------------------------------------
    reg [3:0] f_wait0, f_wait1;

    always @(posedge clk) begin
        if (rst || gnt[0] || !req[0]) f_wait0 <= 4'd0;
        else                          f_wait0 <= f_wait0 + 4'd1;

        if (rst || gnt[1] || !req[1]) f_wait1 <= 4'd0;
        else                          f_wait1 <= f_wait1 + 4'd1;
    end

    // ==================================================================
    // THE FAIRNESS ASSUMPTION -- what a master must keep doing for the
    // promise below to mean anything.
    // ==================================================================

    // A1. Nothing is asking during reset.
    always @(*)
        if (rst) assume(req == 2'b00);

    // A2. A master that has asked and not been served is still asking.
    //
    //     This is the entire fairness model, and what matters is what it
    //     leaves free. A master may start asking whenever it likes, may
    //     stop the moment it is served, may never ask at all, and may ask
    //     forever. In particular MASTER 0 MAY ASK FOREVER -- which is
    //     exactly the behaviour that starves master 1 under strict
    //     priority, and exactly the behaviour a careless fairness
    //     assumption deletes.
    //
    //     The tempting stronger version is "a master gives up after N
    //     clocks". It says contention always resolves itself, so no
    //     policy can starve anyone, and bad1 goes green.
    //
    //     What makes it worth dwelling on is that the cover statements
    //     below do NOT catch it -- checked, not assumed. Add it and all
    //     three still pass: contention is still reachable, both masters
    //     are still granted, a master is still seen waiting. It deletes
    //     no state, only a behaviour over time, and cover asks about
    //     states.
    //
    //     This is the limit of the exercise-04 defence, and it lands
    //     precisely on the assumptions liveness proofs depend on. Read
    //     them by hand. Ask what a hostile environment could do that this
    //     assumption now forbids, and whether that was the case the
    //     design existed to handle.
    always @(posedge clk)
        if (f_past_valid && !rst && !$past(rst)) begin
            if ($past(req[0]) && !$past(gnt[0])) assume(req[0]);
            if ($past(req[1]) && !$past(gnt[1])) assume(req[1]);
        end


    // ==================================================================
    // SAFETY -- nothing bad happens.
    // ==================================================================

    // S1. It is an arbiter. This is what catches bad2, and nothing about
    //     waiting times can see that bug: bad2 makes everyone's wait
    //     zero.
    always @(*)
        if (f_past_valid) assert(gnt != 2'b11);

    // S2. No grant to a master that was not asking.
    //
    //     Against $past(req), not req. The grant is registered, so it
    //     answers the request of the previous clock; comparing it against
    //     this clock's request fails on the correct design the moment a
    //     master is served and stops asking, which is every transfer.
    //     An off-by-one clock here is the most common way to spend an
    //     hour blaming a design that is fine.
    always @(posedge clk)
        if (f_past_valid && !rst && !$past(rst)) begin
            if (gnt[0]) assert($past(req[0]));
            if (gnt[1]) assert($past(req[1]));
        end

    // S3. Silent after reset.
    always @(posedge clk)
        if (f_past_valid && $past(rst)) assert(gnt == 2'b00);


    // ==================================================================
    // LIVENESS -- something good happens, and here is the clock by which.
    // ==================================================================

    // S4. Neither master waits longer than the policy promises.
    //
    //     One line, and it is the only line in this file that sees bad1
    //     or bad3. Strict priority makes master 1's wait unbounded;
    //     contention deadlock makes both unbounded. Every safety property
    //     above passes on both of them.
    //
    //     This is the shape of nearly every liveness property you will
    //     write in hardware: a counter that is cleared by the good thing
    //     happening, and an assertion that it never gets large. It is an
    //     ordinary safety property about the counter, which is why it
    //     settles on an ordinary SMT engine and why it survives `mode
    //     prove'.
    always @(*)
        if (f_past_valid && !rst) begin
            assert(f_wait0 <= MAX_WAIT);
            assert(f_wait1 <= MAX_WAIT);
        end


    // ==================================================================
    // COVER -- and C1 is the one guarding the assumption.
    // ==================================================================
    always @(posedge clk) if (f_past_valid && !rst) begin

        // C1. Both masters want the bus on the same clock.
        //
        //     THE most important cover statement in this file. It is the
        //     only situation in which an arbiter has a decision to make,
        //     so if it is unreachable then everything above has been
        //     proved about a component that never arbitrates. It is
        //     precisely what a too-strong fairness assumption destroys,
        //     and it would go unreachable silently.
        cover(req == 2'b11);

        // C2. Each master really is served. A fairness assumption that
        //     accidentally tied a request low would leave that master's
        //     wait counter pinned at zero and its liveness property
        //     trivially true.
        cover(gnt[0]);
        cover(gnt[1]);

        // C3. Somebody is served after actually having had to wait.
        //     Distinguishes a genuinely contended trace from one where
        //     the masters politely took turns without ever colliding --
        //     which satisfies C1 and C2 and still never tests the policy.
        cover(gnt[1] && $past(f_wait1) > 4'd0);

    end

endmodule

`default_nettype wire
