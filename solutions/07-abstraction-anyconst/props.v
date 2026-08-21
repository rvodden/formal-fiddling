// Reference solution for exercise 07 -- data integrity by abstraction.
//
// Two assertions, one assumption, three cover statements. That is a
// complete data-integrity proof for a FIFO of any depth and any width,
// and it does not grow if either does.

`default_nettype none

module props #(
    parameter AW = 2,
    parameter DW = 8
) (
    input wire          clk,
    input wire          rst,
    input wire          push,
    input wire [DW-1:0] wdata,
    input wire          pop,
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
    // THE LABEL. When the item at stream position f_index goes in, its
    // value is f_value.
    //
    // This is an assumption on an input, and it is the one assumption in
    // this repo that costs nothing -- because f_value is anyconst, so
    // whatever the design is handed at that position, there is a choice
    // of f_value equal to it. The solver picks both. No behaviour has
    // been removed; a name has been attached to one.
    // ------------------------------------------------------------------
    always @(*)
        if (do_push && f_wcount == f_index) assume(wdata == f_value);


    // ------------------------------------------------------------------
    // THE PROOF. When the item at stream position f_index comes out,
    // it is f_value.
    //
    // One line, and because f_index and f_value were the solver's to
    // choose, it says: for every position in the stream and every value
    // that could occupy it, what went in is what comes out. It catches
    // bad1, which hands out the neighbouring entry, and bad2, whose
    // overwrite destroys an entry that was already queued.
    //
    // Note it is checked on the pop, not held somewhere and checked
    // later. `rdata' is a first-word-fall-through output, valid whenever
    // the queue is non-empty, so the moment of the pop is the moment the
    // value is on the wire.
    // ------------------------------------------------------------------
    always @(*)
        if (f_past_valid && do_pop && f_rcount == f_index)
            assert(rdata == f_value);

    // ------------------------------------------------------------------
    // "ONCE, IN ORDER": the FIFO never hands out more than it was given.
    //
    // Nearly free, and it is what catches bad3 -- whose read pointer
    // never advances, so it happily serves an unlimited number of items
    // from a queue that only ever received a few.
    //
    // Worth noticing that this is a CONTROL property, and that the
    // exercise still needs one. Data integrity and counting are different
    // claims and neither implies the other: bad3 satisfies "what comes
    // out at position N is what went in at position N" for as long as it
    // has entries to be right about.
    // ------------------------------------------------------------------
    always @(*)
        if (f_past_valid) assert(f_rcount <= f_wcount);


    // ------------------------------------------------------------------
    // COVER -- and here they are load bearing rather than good practice.
    //
    // The assertion above lives inside `if (do_pop && f_rcount ==
    // f_index)'. If the solver never drives the trace to that condition,
    // the assertion is never evaluated and the task passes having checked
    // precisely nothing. Nothing in the assertion result distinguishes
    // that from a correct FIFO.
    //
    // C1 and C2 are the evidence that the tracked item existed and came
    // out again. Without them this exercise's PASS would be worth no more
    // than the hollow PASS in exercise 04.
    // ------------------------------------------------------------------
    always @(posedge clk) if (f_past_valid && !rst) begin

        // C1. The tracked item is actually pushed.
        cover(do_push && f_wcount == f_index);

        // C2. And is actually popped. This is the one that proves the
        //     assertion above ever ran.
        cover(do_pop && f_rcount == f_index);

        // C3. The queue fills. The pointer wrap is where bad1's
        //     off-by-one gets interesting, and a trace that never fills
        //     the queue never exercises it.
        cover(full);

    end

endmodule

`default_nettype wire
