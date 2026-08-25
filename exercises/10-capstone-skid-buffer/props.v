// =====================================================================
// Exercise 10 -- the capstone. A skid buffer, verified properly.
//
// Nothing new is introduced here. Everything you need is in exercises 01
// to 09, and the exercise is putting it together on a design worth
// verifying:
//
//   03  assume the upstream contract, assert the downstream one
//   03  a bounded liveness property, so a brick does not pass
//   04  cover statements aimed at what your assumptions forbid
//   06  an invariant, if you want the unbounded proof
//   07  $anyconst, to prove what goes in comes out
//   08  safety and liveness are different claims, and you need both
//
// ---------------------------------------------------------------------
// THE DESIGN, AND WHY IT IS THE RIGHT ONE TO FINISH ON
//
// A skid buffer is a two-register stream slice. It sits in a valid/ready
// stream, breaks the combinational path in both directions -- which is
// what you reach for when a long path between two blocks will not close
// timing -- and does it without halving throughput.
//
// That last part is the whole difficulty. The naive one-register version
// is easy and runs at one beat every two clocks. Making it full rate
// means accepting a beat before you know the output stage can take it,
// which means having somewhere to put it, which is the skid register. And
// that is where the bugs live.
//
// It is also a module you will genuinely write. Every AXI-Stream register
// slice is one of these. So is every "pipeline stage with backpressure"
// in every design that has backpressure at all.
//
// ---------------------------------------------------------------------
// THE SPECIFICATION
//
// A skid buffer in a valid/ready stream. MAX_WAIT = 2.
//
// The STREAM CONTRACT, which has three rules and applies to each end:
//
//   R1. A beat transfers on any clock where valid and ready are both
//       high.
//   R2. valid, once raised, stays raised until a transfer happens. An
//       offer may not be withdrawn.
//   R3. data does not change while valid is high and ready is not. The
//       offer on the table is a specific beat.
//
// Note ready carries no such obligation. A sink may raise and drop it
// however it likes, and a source may not wait for ready before asserting
// valid -- that is a deadlock, and it is the reason R2 exists.
//
// What this module owes:
//
//   1. R2 and R3 hold of its downstream port. (You ASSUME them of the
//      upstream and ASSERT them of the downstream: the same two
//      sentences, twice, pointing in opposite directions. That is the
//      whole obligation of a component in the middle of a stream, and
//      the shape of every interface proof you will ever write.)
//   2. Nothing is offered downstream on the clock after reset.
//   3. Every beat accepted upstream is delivered downstream exactly
//      once, unchanged, in order.
//   4. At most two beats are inside the module at any moment -- it has
//      two registers.
//   5. While the sink holds ready, a beat being offered is taken within
//      MAX_WAIT clocks.
//
// This block is the contract. Everything else in this file is commentary
// and hints; where they disagree, this is what binds.
//
// The three broken designs are chosen so that no single clause catches
// two of them: bad1 loses beats (clause 3), bad2 invents them (clause 3
// again, but only its counting half), and bad3 breaks clause 1 while
// losing and inventing nothing at all. Clause 5 is there so that a module
// which simply never passes anything on cannot satisfy the rest.
//
// ---------------------------------------------------------------------
// THE PORTS
//
// Every port here is an `input', including the ones carrying the design's
// outputs: a property module observes and never drives, which is also why
// they take no `_i' / `_o' suffix. What matters is where the value COMES
// FROM, because that is the assume/assert boundary -- you may `assume'
// about what the solver drives, and must `assert' about what the design
// drives.
//
// DW is 4 in the harness. The ports come in three groups, and knowing
// which group a port is in tells you what you may do with it.
//
//   name          width   comes from   what it is
//   ------------------------------------------------------------------
//   clk             1     harness      The clock.
//   rst             1     harness      Reset, synchronous, active high.
//
//   -- UPSTREAM: the source side. ASSUME the contract here. ------------
//   s_valid         1     THE SOLVER   The source is offering a beat.
//   s_data         DW     THE SOLVER   The beat it is offering.
//   s_ready         1     THE DUT      This module's answer: it has room.
//
//   -- DOWNSTREAM: the sink side. ASSERT the contract here. ------------
//   m_valid         1     THE DUT      This module is offering a beat.
//   m_data         DW     THE DUT      The beat it is offering.
//   m_ready         1     THE SOLVER   The sink is willing to take it.
//
//   -- WHITE BOX ------------------------------------------------------
//   f_skid_data    DW     THE DUT      The skid register's contents,
//                                      exposed for the proof alone. It
//                                      drives nothing and synthesis
//                                      removes it; the `f_' says so.
//
// NOTE THE ZIG-ZAG. Each side has one port driven by the solver and one
// driven by the design, and they are not the same port on both sides:
// `s_ready' is ours and `m_ready' is theirs. That is what makes this
// module a component in the MIDDLE of a stream rather than an endpoint,
// and getting it backwards -- assuming something about s_ready, say --
// would be assuming away the backpressure the whole design exists to
// survive.
//
// `f_skid_data' is the one port with no counterpart in the hardware
// interface. It is here because a proof by induction has to be able to
// say what is inside the buffer, and reaching into the hierarchy from a
// property file would tie these properties to one implementation's
// signal names.
//
// ---------------------------------------------------------------------
// WHAT TO DO
//
//   make good   must PASS  -- the correct skid buffer
//   make bad1   must FAIL  -- always ready; overwrites the skid register
//   make bad2   must FAIL  -- never clears it; duplicates beats
//   make bad3   must FAIL  -- withdraws an offer that was not taken
//   make prove  must PASS  -- the same properties, by induction, unbounded
//   make cover  must PASS
//
//   make        all six, with each verdict checked
//
// The three bugs are deliberately of three different kinds and no single
// property catches two of them:
//
//   bad1  loses data      -- needs a data property (exercise 07)
//   bad2  invents data    -- needs counting; data integrity alone passes it
//   bad3  breaks protocol -- loses and invents nothing; needs the contract
//
// A property set that catches all three is a property set with genuinely
// different kinds of claim in it, which is the thing this whole sequence
// has been driving at.
//
// ---------------------------------------------------------------------
// ABOUT `make prove'
//
// This is the one place the exercises ask for an unbounded proof, and it
// may well come back UNKNOWN before it comes back PASS. That is exercise
// 06 arriving on a real design rather than a demonstration.
//
// If it does: read the induction trace, find the impossible thing about
// step 0, and write it down as an invariant -- the loop from exercise 06,
// on a design that did not have it planted deliberately.
//
// One pointer, since hunting for the right hierarchical signal is not the
// skill being taught. The whole state of this module is visible from
// outside it. The output register is full exactly when m_valid is high,
// and the skid register is full exactly when s_ready is LOW -- because
// s_ready is asserted precisely while the skid is empty. So how many
// beats are inside can be written two ways, and asserting that the two
// agree is the kind of thing induction is asking you for.
//
// If you would rather not, the four bounded tasks are the exercise and
// `prove' is the encore. The reference solution takes it.
// =====================================================================

`default_nettype none

module props #(
    parameter DW = 4
) (
    input wire          clk,
    input wire          rst,

    // upstream: s_valid/s_data from the solver, s_ready from the DUT
    input wire          s_valid,
    input wire [DW-1:0] s_data,
    input wire          s_ready,
    input wire [DW-1:0] f_skid_data,       // white-box: the skid register

    // downstream: m_valid/m_data from the DUT, m_ready from the solver
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

    (* anyconst *) reg [CW:0]   f_index;
    (* anyconst *) reg [DW-1:0] f_value;

    always @(*) assume(f_index < 5'd8);

    // ------------------------------------------------------------------
    // TODO 1: ASSUME the upstream contract.
    //
    //   - nothing is offered during reset
    //   - s_valid, once high, stays high until a beat transfers
    //   - s_data does not move while s_valid is high and s_ready is not
    //
    // Do NOT assume anything about m_ready. A sink may stall whenever it
    // likes and for as long as it likes, and the whole reason this module
    // exists is to survive that. Assuming m_ready is eventually high --
    // or worse, always high -- makes bad1 pass, because bad1's fault is
    // only ever visible under backpressure. That is exercise 04 waiting
    // for you on a design you care about.
    //
    // (See the liveness note in TODO 3 for the one place m_ready does
    // need an assumption, and why it belongs there and not here.)
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 2: ASSERT the downstream contract -- the same three rules,
    // pointing the other way.
    //
    //   - nothing is offered on the clock after reset
    //   - m_valid, once high, stays high until a beat transfers
    //   - m_data does not move while m_valid is high and m_ready is not
    //
    // The middle one is what catches bad3.
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 3: ASSERT that the data is right.
    //
    //   - the beat at stream position f_index that went in comes out
    //     with the same value  (assume on the way in, assert on the way
    //     out -- exercise 07)
    //   - nothing is invented, and nothing is hoarded. The buffer has
    //     two registers, so the number of beats inside it -- put in,
    //     not yet taken out -- is always 0, 1 or 2. This is what catches
    //     bad2.
    //
    //     Write that as a claim about f_incount - f_outcount, not as a
    //     comparison like `f_outcount <= f_incount'. Those counters wrap,
    //     and once one has rolled through zero an absolute comparison
    //     between them is false with nothing whatever wrong. Their
    //     difference stays correct across the wrap -- modular arithmetic,
    //     exactly as for the FIFO pointers in exercise 06.
    //
    //     Bounded runs never reach the wrap so it passes either way. If
    //     you attempt `make prove', the version comparing magnitudes will
    //     hand you a counterexample about your own bookkeeping.
    //
    // And one bounded liveness property, so that a module which simply
    // never passes anything on cannot satisfy all of the above:
    //
    //   - while m_ready is held high, a beat that is being offered is
    //     taken within MAX_WAIT clocks
    //
    // This is the one place you may assume something about m_ready, and
    // it is worth being clear about why it is allowed. It is not a
    // blanket assumption that the sink is always ready -- it is the
    // fairness half of a liveness property, in exactly the sense of
    // exercise 08: a promise is only meaningful once you say what the
    // environment must keep doing. Scope it to the liveness property.
    // Hoist it to the top of the file and it becomes the over-constraint
    // that hides bad1.
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 4: COVER. More important here than anywhere.
    //
    //   - a beat goes in, and a beat comes out
    //   - the tracked beat goes in and comes out, or TODO 3's assertion
    //     never ran at all
    //   - BACKPRESSURE: m_valid high with m_ready low. If this is not
    //     reachable, you have assumed the stall away and bad1 is invisible
    //   - the buffer holding two beats at once, which is the only state
    //     the skid register exists for
    //   - back-to-back transfer: beats in and out on consecutive clocks,
    //     which is the throughput claim the whole design is for
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
