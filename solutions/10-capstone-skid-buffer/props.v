// Reference solution for exercise 10 -- a complete property set for a
// skid buffer.
//
// Nothing in it is new. It is exercises 03, 04, 06, 07 and 08 applied at
// once to a module worth applying them to, and the thing to take from it
// is how the different KINDS of property divide the work: the contract
// properties catch bad3, the data property catches bad1, the counting
// property catches bad2, and no one of them catches another's bug.

`default_nettype none

module props #(
    parameter DW = 4
) (
    input wire          clk,
    input wire          rst,

    input wire          s_valid,
    input wire [DW-1:0] s_data,
    input wire          s_ready,
    input wire [DW-1:0] f_skid_data,       // white-box: the skid register

    input wire          m_valid,
    input wire [DW-1:0] m_data,
    input wire          m_ready
);

    localparam CW       = 4;                // stream-position counter width
    localparam MAX_WAIT = 2;                // beats out, once ready is held

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // A beat transfers when both sides agree. Naming them is worth it:
    // they appear in nearly every property below and in every trace.
    wire s_beat = s_valid && s_ready;
    wire m_beat = m_valid && m_ready;

    // ------------------------------------------------------------------
    // GIVEN: the counters and the tracked beat, exactly as in exercise 07.
    // ------------------------------------------------------------------
    reg [CW:0] f_incount, f_outcount;
    always @(posedge clk)
        if (rst) begin
            f_incount  <= {(CW+1){1'b0}};
            f_outcount <= {(CW+1){1'b0}};
        end else begin
            if (s_beat) f_incount  <= f_incount  + 1'b1;
            if (m_beat) f_outcount <= f_outcount + 1'b1;
        end

    // How many beats are inside the module: put in, not yet taken out.
    wire [CW:0] f_occupancy = f_incount - f_outcount;

    (* anyconst *) reg [CW:0]   f_index;
    (* anyconst *) reg [DW-1:0] f_value;

    always @(*) assume(f_index < 5'd8);

    // ==================================================================
    // A. THE UPSTREAM CONTRACT -- assumed. What the source promises.
    // ==================================================================

    // A1. Nothing offered during reset.
    always @(*)
        if (rst) assume(!s_valid);

    // A2. An offer is not withdrawn, and A3, the offer does not change
    //     underneath us. Both are conditional on no transfer having
    //     happened, because once a beat has gone the source is free.
    always @(posedge clk)
        if (f_past_valid && !rst && !$past(rst) && $past(s_valid) && !$past(s_beat)) begin
            assume(s_valid);
            assume(s_data == $past(s_data));
        end

    // Note what is NOT assumed: anything at all about m_ready. The sink
    // may stall for as long as it likes. bad1 only misbehaves under
    // backpressure, so an assumption that the sink is eventually -- or
    // always -- ready would hide it completely, and cover statement C3
    // below is the guard against having written one by accident.


    // ==================================================================
    // B. THE DOWNSTREAM CONTRACT -- asserted. The same three sentences,
    // pointing the other way. This is the whole obligation of a component
    // in the middle of a stream.
    // ==================================================================

    // B1. Nothing offered on the clock after reset.
    always @(posedge clk)
        if (f_past_valid && $past(rst)) assert(!m_valid);

    // B2. We do not withdraw an offer. THIS CATCHES bad3, and nothing
    //     else in the file does: bad3 neither loses nor duplicates a
    //     single beat, it just takes the offer off the table and puts it
    //     back.
    //
    // B3. And the offer does not change while it stands.
    always @(posedge clk)
        if (f_past_valid && !rst && !$past(rst) && $past(m_valid) && !$past(m_beat)) begin
            assert(m_valid);
            assert(m_data == $past(m_data));
        end


    // ==================================================================
    // C. THE DATA, AND HOW MUCH OF IT -- asserted.
    // ==================================================================

    // C1. The tracked beat goes in with value f_value...
    always @(*)
        if (s_beat && f_incount == f_index) assume(s_data == f_value);

    // C2. ...and comes out with value f_value.
    //
    //     THIS CATCHES bad1. When the skid register is overwritten the
    //     beat that was in it is destroyed, so the beat that eventually
    //     emerges at position f_index is a different one.
    //
    //     Because f_index and f_value are the solver's to choose, this
    //     one line covers every position and every value.
    always @(*)
        if (f_past_valid && m_beat && f_outcount == f_index)
            assert(m_data == f_value);

    // C3. Nothing is invented -- but NOT written as `f_outcount <=
    //     f_incount', and the reason is worth the paragraph.
    //
    //     Those counters wrap. They are CW+1 bits and they count beats
    //     forever, so sooner or later f_incount rolls through zero while
    //     f_outcount is still near the top, and an absolute comparison
    //     between them becomes false with nothing wrong at all. In `mode
    //     bmc' it passes, because 14 steps never reach the wrap. Under
    //     induction, which starts anywhere, the solver goes straight to
    //     it -- and the counterexample is about the property file's own
    //     bookkeeping rather than about the design, which is a genuinely
    //     annoying half hour.
    //
    //     Their DIFFERENCE is fine. Modular subtraction gives the true
    //     occupancy across the wrap, exactly as it did for the FIFO
    //     pointers in exercise 06, so long as the real occupancy stays
    //     below 2^(CW+1) -- and here it never exceeds 2.
    //
    //     So the counting property is C5 below, which pins the difference
    //     rather than comparing the counters. It catches bad2 for the
    //     same reason this would have: a buffer that hands the same beat
    //     out twice drives the difference somewhere it cannot be.
    //
    //     The general rule: on a free-running counter, assert about
    //     differences, never about magnitudes. A magnitude is a statement
    //     about how long the trace has been running, which is not
    //     something you meant to say.

    // C4. And nothing is hoarded. Two registers, so at most two beats can
    //     be inside at any moment.
    always @(*)
        if (f_past_valid) assert(f_occupancy <= 5'd2);

    // ==================================================================
    // C5. THE INVARIANT -- what makes `prove' close.
    //
    // Everything above passes in `mode bmc' without this line. `mode
    // prove' comes back UNKNOWN, and the induction trace says why: at
    // step 0 the counters claim a beat is inside the module while both of
    // its registers are empty. That state cannot be reached from reset --
    // every beat that increments f_incount lands in a register -- and the
    // solver, which does not start from reset, starts there anyway.
    //
    // This is exercise 06 exactly: two ways of knowing the same fact,
    // never checked against each other, and induction starting them
    // disagreeing. There the fact was a FIFO's occupancy; here it is this
    // buffer's.
    //
    // The pleasant part is that the module's entire state is visible at
    // its own interface, so the invariant needs no hierarchical peeking:
    //
    //     the output register is full   exactly when   m_valid
    //     the skid register is full     exactly when   !s_ready
    //
    // -- because s_ready is asserted precisely while the skid is empty.
    // So "how many beats are inside" can be written twice, once by
    // counting the interface and once by reading it, and asserting that
    // the two agree is the whole strengthening.
    //
    // Note it makes C4 redundant: an occupancy that equals a sum of two
    // bits is at most 2 by construction. C4 is kept because it is the
    // property a reader wants to see stated, and the cost of a
    // subsumed assertion is a few milliseconds.
    // ==================================================================
    always @(*)
        if (f_past_valid)
            assert(f_occupancy == ({4'd0, m_valid} + {4'd0, ~s_ready}));

    // C6. The skid register is only ever used while the output register
    //     is also occupied.
    //
    //     True by construction -- the buffer drains the skid whenever the
    //     output stage is free -- and induction has no way to know it, so
    //     it starts with a beat marooned in the skid behind an empty
    //     output register and everything downstream of that is nonsense.
    always @(*)
        if (f_past_valid && !s_ready) assert(m_valid);

    // C7 and C8. WHERE THE TRACKED BEAT IS, when it is inside.
    //
    //     C2 says the tracked beat is correct as it LEAVES. For a bounded
    //     proof from reset that is enough: the solver watched it go in,
    //     so it knows what it was.
    //
    //     Induction watched nothing. It starts with the beat already
    //     inside and the registers holding whatever it fancies, so it
    //     needs to be told what must be in them -- which is the general
    //     shape of making any data property inductive. C2 is about the
    //     boundary; these are about the storage behind it.
    //
    //     Positions follow from C6: f_outcount is the position of the
    //     next beat out, so the output register holds f_outcount, and the
    //     skid -- which is only occupied when the output is too -- holds
    //     the one after it.
    always @(*)
        if (f_past_valid && m_valid && f_outcount == f_index)
            assert(m_data == f_value);

    always @(*)
        if (f_past_valid && !s_ready && (f_outcount + 1'b1) == f_index)
            assert(f_skid_data == f_value);

    // ==================================================================
    // D. LIVENESS -- bounded, and with its fairness assumption scoped to
    // the property it belongs to.
    // ==================================================================

    // How long an offer has been standing while the sink is ready. Any
    // stall by the sink resets it, so this only ever measures the buffer
    // dragging its feet.
    reg [3:0] f_stuck;
    always @(posedge clk)
        if (rst || !m_valid || !m_ready || m_beat) f_stuck <= 4'd0;
        else                                       f_stuck <= f_stuck + 4'd1;

    // D1. With the sink ready, an offer is taken promptly.
    //
    //     Without this, a module that never asserts m_valid satisfies
    //     every property above -- A, B and C are all conditional on beats
    //     that happen. Exercise 03's S5 made the same point about the
    //     same gap.
    //
    //     m_ready appears here, and only here. That is the fairness half
    //     of a liveness property in the sense of exercise 08: a promise
    //     about how quickly a beat is taken is meaningless unless
    //     somebody is taking it. Scoped to this property it costs
    //     nothing; hoisted to the top of the file it would be the
    //     over-constraint that hides bad1.
    always @(*)
        if (f_past_valid && !rst) assert(f_stuck <= MAX_WAIT);


    // ==================================================================
    // E. COVER. C3 is the one guarding the whole exercise.
    // ==================================================================
    always @(posedge clk) if (f_past_valid && !rst) begin

        // E1. Beats move at all.
        cover(s_beat);
        cover(m_beat);

        // E2. The tracked beat exists and emerges. Without these, C2 is
        //     an assertion inside a condition that may never hold, and
        //     the data proof would be the hollow PASS of exercise 04.
        cover(s_beat && f_incount  == f_index);
        cover(m_beat && f_outcount == f_index);

        // E3. BACKPRESSURE. The single most important line here.
        //
        //     bad1 is correct in every trace where the sink never stalls.
        //     If this is unreachable then something has assumed the stall
        //     away and the bad1 result is worthless -- and nothing in the
        //     assertion results would say so.
        cover(m_valid && !m_ready);

        // E4. Both registers occupied at once. This is the only state the
        //     skid register exists for, and a property set that never
        //     reaches it has verified a plain one-deep buffer.
        cover(f_incount - f_outcount == 5'd2);

        // E5. Full throughput: beats in and out on the same clock, which
        //     is the entire reason to build a skid buffer instead of the
        //     simple register slice. Worth covering because it is the
        //     performance claim, and a design that quietly halved its
        //     throughput would satisfy every assertion in this file.
        cover(s_beat && m_beat);

    end

endmodule

`default_nettype wire
