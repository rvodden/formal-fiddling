// =====================================================================
// Exercise 07 -- abstraction, and how to prove a thing about everything
// by proving it about one arbitrary thing.
//
// Everything so far has been about CONTROL: flags, handshakes,
// occupancy, timing. Control is what property sets usually check, because
// control is what is easy to say.
//
// This exercise is about DATA. The claim is the one a FIFO actually
// exists to make:
//
//     what goes in comes out, unchanged, once, in order
//
// and all three broken FIFOs in dut/ have flawless control. They never
// overflow visibly, their flags are right, their handshakes are right. A
// property set from any earlier exercise here passes all three.
//
// ---------------------------------------------------------------------
// THE OBVIOUS APPROACH, AND WHY IT COLLAPSES
//
// Model the FIFO. Keep a shadow queue in the property file, push what the
// design pushes, pop what the design pops, compare.
//
// It works, and it is a bad idea, for two reasons that get worse
// together. You have written a second FIFO, so now you have two FIFOs
// that might be wrong and a proof that they agree. And you have handed
// the solver DEPTH x DW extra state bits to reason about, which is the
// fastest way to turn a two-second proof into one you abandon.
//
// ---------------------------------------------------------------------
// THE TRICK: ONE ARBITRARY ITEM
//
// Instead of tracking every item, track exactly one -- and refuse to say
// which.
//
//     (* anyconst *) reg [CW:0]   f_index;   // some position in the stream
//     (* anyconst *) reg [DW-1:0] f_value;   // some data value
//
// `anyconst' means: the solver picks this value, it may pick ANY value,
// and it must hold that value for the entire trace. Unconstrained but
// constant.
//
// Then, in three lines:
//
//   * count the items pushed and the items popped
//   * ASSUME that the item pushed at position f_index has value f_value
//   * ASSERT that the item popped at position f_index has value f_value
//
// And that is the whole proof. Because f_index and f_value are arbitrary,
// a proof for them is a proof for every position and every value at once
// -- the solver had free choice and could not find a pair that breaks it.
// It is the ordinary "let n be an arbitrary integer" of a mathematics
// textbook, and it costs two constants and two counters instead of a
// whole second copy of the design's storage.
//
// This technique scales to things a shadow model cannot touch: a 4 KB
// cache, a network-on-chip, a DDR controller with reordering. The
// abstraction does not grow with the design.
//
// ---------------------------------------------------------------------
// "BUT YOU ASSUMED THE DATA" -- NO, AND THIS IS THE SUBTLE PART
//
// The assumption above constrains the input. After four exercises of
// being told assumptions are how you fool yourself, it should make you
// uneasy. Here is why it is free.
//
// A harmful assumption deletes behaviours from the proof. This one does
// not, because the thing being assumed is itself arbitrary: for every
// data value the FIFO could be handed at that position, there is a choice
// of f_value that matches it. The solver hunting for a counterexample
// gets to choose f_value, so any counterexample that exists at all still
// exists under the assumption. Nothing has been removed -- the same
// behaviours have been relabelled.
//
// That is the test to apply to any abstraction: does it delete
// behaviours, or only rename them? Fix f_value at 8'hA5 instead of
// leaving it anyconst and you have deleted 255 of 256, and you are back
// in exercise 04.
//
// ---------------------------------------------------------------------
// THE SPECIFICATION
//
// A four-deep FIFO with storage, first-word-fall-through.
//
//   1. After reset, the FIFO is empty.
//   2. A push when not full accepts wdata; a pop when not empty removes
//      the oldest entry.
//   3. rdata always shows the oldest unread entry while the FIFO is not
//      empty -- there is no read latency.
//   4. Every value pushed comes out unchanged, exactly once, in the
//      order it went in.
//   5. The FIFO never delivers more entries than were put into it.
//
// This block is the contract. Everything else in this file is commentary
// and hints; where they disagree, this is what binds.
//
// Clauses 1 to 3 are about CONTROL and clauses 4 and 5 are about DATA,
// and all three broken FIFOs in dut/ satisfy the control clauses
// perfectly. A property set from any earlier exercise passes all three.
//
// Clauses 4 and 5 are also independent of each other: a FIFO whose read
// pointer never advances hands out a correct value at every position it
// is asked about, for as long as it has entries to be right about, and
// only clause 5 notices that it never runs out.
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
// The harness instantiates AW = 2 and DW = 4: a four-deep FIFO carrying
// four-bit values. Note DW -- the default in the parameter list below is
// 8, and the harness passes 4. Reading widths off a parameter default is
// a good way to misread a trace.
//
//   name    width   comes from   what it is
//   ------------------------------------------------------------------
//   clk       1     harness      The clock.
//   rst       1     harness      Reset, synchronous, active high.
//   push      1     THE SOLVER   Request to add an entry.
//   wdata    DW     THE SOLVER   The value being offered. Free -- and
//                                the one place in this repo where an
//                                assumption about a data input costs
//                                nothing, because the value it is
//                                pinned to is itself arbitrary. See the
//                                header.
//   pop       1     THE SOLVER   Request to remove an entry.
//   rdata    DW     THE DUT      The value on offer at the head.
//                                First-word-fall-through: valid whenever
//                                the queue is not empty, with no read
//                                latency, so the moment of the pop is
//                                the moment the value is on the wire.
//   full      1     THE DUT      No room.
//   empty     1     THE DUT      Nothing to take.
//
// ---------------------------------------------------------------------
// WHAT TO DO
//
//   make good   must PASS  -- a correct FIFO
//   make bad1   must FAIL  -- reads one past the head
//   make bad2   must FAIL  -- overwrites when full
//   make bad3   must FAIL  -- read pointer never advances
//   make cover  must PASS
//
//   make        all five, with each verdict checked
//
// If your property set passes bad1, bad2 and bad3, you have written a
// control property and not a data property. That is the entire lesson,
// and it is worth arriving at honestly before reading the solution.
// =====================================================================

`default_nettype none

module props #(
    parameter AW = 2,
    parameter DW = 8
) (
    input wire          clk,
    input wire          rst,
    // driven by the solver
    input wire          push,
    input wire [DW-1:0] wdata,
    input wire          pop,

    // driven by the DUT
    input wire [DW-1:0] rdata,
    input wire          full,
    input wire          empty
);

    localparam DEPTH = (1 << AW);
    localparam CW    = 4;                   // stream-position counter width

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // The design's own accept conditions, restated. A push only counts if
    // the queue had room; a pop only counts if it had something in it.
    wire do_push = push && !full;
    wire do_pop  = pop  && !empty;

    // ------------------------------------------------------------------
    // GIVEN: the abstraction, and the bookkeeping it needs.
    // ------------------------------------------------------------------

    // The one item we are tracking, and what it is worth. The solver
    // chooses both, freely, once, for the whole trace.
    (* anyconst *) reg [CW:0]   f_index;
    (* anyconst *) reg [DW-1:0] f_value;

    // Keep the tracked position inside the range the trace can reach.
    // Without this the solver picks f_index = 97, nothing ever reaches
    // position 97 within the depth, and every property below is
    // vacuously true -- a PASS that means nothing, exactly as in exercise
    // 04. The cover statements you write are what would catch it.
    always @(*) assume(f_index < 5'd8);

    // How many items have been pushed, and popped, since reset. These are
    // STREAM POSITIONS, not addresses: item number 6 is the seventh thing
    // ever pushed, wherever in the memory it happened to land.
    reg [CW:0] f_wcount, f_rcount;
    always @(posedge clk) begin
        if (rst) begin
            f_wcount <= {(CW+1){1'b0}};
            f_rcount <= {(CW+1){1'b0}};
        end else begin
            if (do_push) f_wcount <= f_wcount + 1'b1;
            if (do_pop)  f_rcount <= f_rcount + 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // TODO 1: the ASSUMPTION that labels our item.
    //
    //   when the item at stream position f_index is being pushed, its
    //   data is f_value
    //
    // One line. See the header for why this costs nothing.
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 2: the ASSERTION that checks it.
    //
    //   when the item at stream position f_index is being popped, the
    //   data coming out is f_value
    //
    // One line, and it is the entire data-integrity proof.
    //
    // Add one more while you are here, which is the "once, in order" half
    // of the claim and is nearly free:
    //
    //   the FIFO never hands out more items than were put in, i.e.
    //   f_rcount <= f_wcount
    //
    // That is what catches a FIFO inventing entries. bad3 trips it.
    // ------------------------------------------------------------------


    // ------------------------------------------------------------------
    // TODO 3: your COVER statements.
    //
    // These matter more here than anywhere else in the repo, because the
    // assertion above is INSIDE a condition that the solver controls. If
    // the tracked item is never pushed, or never popped, the assertion is
    // never evaluated and the run passes without checking anything at
    // all. That is the exercise-04 failure with a new coat on.
    //
    // So cover, at minimum:
    //
    //   - the tracked item being pushed   (f_wcount reaching f_index)
    //   - the tracked item being popped   (f_rcount reaching f_index)
    //   - the queue full at some point, so the wrap is exercised
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
