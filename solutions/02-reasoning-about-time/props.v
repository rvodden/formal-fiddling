// Reference solution for exercise 02 -- properties for a Gray counter.
//
// Four assertions and three cover statements, one assertion per clause of
// the specification. Between them they leave a wrong implementation
// nowhere to go -- and it takes all four: each of the four broken designs
// in dut/ is caught by a different one.

`default_nettype none

module props (
    input wire       clk,
    input wire       rst,
    input wire       inc,
    input wire [3:0] gray
);

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // The bits that differ between this step and the last one. Naming it
    // is worth a line: it appears in two properties and, because it is a
    // real signal, it shows up as its own row in every counterexample you
    // read -- which saves doing the XOR in your head off the trace.
    //
    // It is written with an explicit history register rather than as
    // `wire [3:0] changed = gray ^ $past(gray);', because that does not
    // compile:
    //
    //     ERROR: System function \$past is only allowed in clocked blocks.
    //
    // $past is not a function of the current value; it is a reference to
    // a previous sample, and yosys will only let you take one where there
    // is an edge to sample on. Inside `always @(posedge clk)' it is fine.
    // In a continuous assignment there is no clock, so it is not.
    reg [3:0] gray_q;
    always @(posedge clk) gray_q <= gray;

    wire [3:0] changed = gray ^ gray_q;

    // P1. Reset means zero. Checked on the clock AFTER rst was seen high,
    //     because the counter's reset is synchronous -- it clears on the
    //     edge, not the instant rst rises.
    always @(posedge clk)
        if (f_past_valid && $past(rst)) assert(gray == 4'd0);

    // P2. Told to hold, it holds.
    //
    //     This is the property that catches bad3, and it is the half of
    //     the specification that gets forgotten. Every transition bad3
    //     makes is a legal Gray step; its fault is taking them
    //     unbidden, and only a property mentioning `inc' can see that.
    always @(posedge clk)
        if (f_past_valid && !rst && !$past(rst) && !$past(inc))
            assert(changed == 4'd0);

    // P3. Told to advance, exactly one bit moves.
    //
    //     `changed != 0' rules out standing still; `(changed &
    //     (changed-1)) == 0' rules out moving more than one bit. Together
    //     they are $onehot(changed), written in Verilog-2001.
    //
    //     This catches bad1 (a binary counter moves two bits at 1->2) and
    //     bad2 (the 7->9 skip moves three).
    always @(posedge clk)
        if (f_past_valid && !rst && !$past(rst) && $past(inc))
            assert(changed != 4'd0 && (changed & (changed - 4'd1)) == 4'd0);

    // P4. It does not come back to zero early -- clause 4, the one that
    //     makes it a counter rather than merely a Gray code.
    //
    //     f_inc counts increments since reset, modulo 16, so it IS the
    //     value the counter is supposed to be showing (in binary). The
    //     counter reads zero exactly when f_inc does, and at no other
    //     time. Written as an equality in both directions, because
    //     "returns to zero no earlier than the sixteenth increment" and
    //     "does return to zero on the sixteenth" are both wanted and one
    //     line covers them.
    //
    //     This is what catches bad4, whose four-state cycle is back at
    //     zero after four increments, and incidentally bad2, whose skip
    //     shortens the cycle to fifteen. Nothing in P1..P3 can see
    //     either: every step both of them take is a legal one-bit Gray
    //     step.
    //
    //     Note it does NOT subsume P3. bad1 -- a plain binary counter --
    //     satisfies P4 perfectly, since it too is at zero exactly every
    //     sixteen increments. The two clauses are independent in both
    //     directions, which is why the specification states both.
    reg [3:0] f_inc;
    always @(posedge clk)
        if (rst)      f_inc <= 4'd0;
        else if (inc) f_inc <= f_inc + 4'd1;

    always @(*)
        if (f_past_valid && !rst) assert((gray == 4'd0) == (f_inc == 4'd0));

    // ------------------------------------------------------------------
    // Note what is NOT here: any assumption about `inc'. It is a free
    // input, every pattern of it is legal, and constraining it could only
    // shrink what has been proved. Compare exercise 03, where the input
    // does have a contract and leaving it unstated makes the proof
    // impossible rather than merely weaker.
    //
    // Note also that P3 subsumes "the value changes when inc is high":
    // `changed != 0' says exactly that. Adding it separately would be
    // adding an assertion that can never fail on its own, which costs
    // solver time and buys nothing. An assertion that cannot fail is the
    // formal equivalent of a test that has never been seen to fail.
    // ------------------------------------------------------------------

    // COVER. The wrap is the one that matters: it is the step bad2
    // corrupts, and covering it proves the depth in prove.sby really is
    // enough to drive the counter all the way round. A property set that
    // catches bad2 only because the solver happened to reach step 16 is
    // one `depth' edit away from silently catching nothing.
    always @(posedge clk) if (f_past_valid && !rst) begin
        cover(!$past(inc));                              // it can be held
        cover($past(inc) && changed != 4'd0);            // and advanced
        cover($past(gray) == 4'b1000 && gray == 4'd0);   // and wrapped
    end

endmodule

`default_nettype wire
