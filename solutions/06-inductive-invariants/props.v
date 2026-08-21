// Reference solution for exercise 06 -- the invariant that makes
// induction close.
//
// The answer is one assertion. Everything else in this file is identical
// to the exercise.
//
// What is worth taking from it is not the line -- it is that the line was
// findable from the induction counterexample without knowing anything
// about FIFOs. The trace starts in a state where `count' and the pointer
// difference disagree; the fix is to assert that they do not. You do not
// need insight to run that loop, only the willingness to read the
// starting state of a trace that looks like nonsense and ask which part
// of the nonsense is impossible.

`default_nettype none

module props #(
    parameter AW = 4
) (
    input wire        clk,
    input wire        rst,
    input wire        push,
    input wire        pop,
    input wire [AW:0] count,
    input wire [AW:0] wptr,
    input wire [AW:0] rptr,
    input wire        full,
    input wire        empty
);

    localparam [AW:0] DEPTH = (1 << AW);

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ==================================================================
    // THE TARGET PROPERTY -- given. This is what we are trying to prove,
    // and it is true: an eight-deep FIFO never holds nine things.
    //
    // It passes `bmc'. It does not survive induction on its own, because
    // nothing here stops the solver starting with count at 16 and the
    // pointers saying empty -- at which point full is low, the push is
    // allowed, and count goes to 17 in one step.
    // ==================================================================
    always @(*)
        if (f_past_valid) assert(count <= DEPTH);

`ifdef STRENGTHEN
    // ==================================================================
    // THE INVARIANT.
    //
    // "count is the difference between the write and read pointers."
    //
    // Both pointers are AW+1 bits and the subtraction is unsigned, so it
    // wraps -- which is exactly the behaviour wanted. When wptr has
    // wrapped past the end and rptr has not, wptr - rptr still comes out
    // as the true occupancy, because that is what modular arithmetic on
    // one extra bit is for. No special case is needed for the wrap and
    // adding one would be a bug.
    //
    // Asserted, not assumed. It is a fact about the design, so it gets
    // proved along with everything else -- and once proved it is
    // available to the induction step, which may assume it about the
    // arbitrary starting state. That is what deletes the impossible
    // states that were breaking prove_weak.
    //
    // Assuming it instead would also turn prove_strong green and would be
    // worth nothing: the interesting half of the specification would have
    // been asserted by fiat, and the rest proved from it. Exercise 04 is
    // the same mistake wearing different clothes.
    //
    // This invariant is itself inductive, which is what makes the whole
    // thing terminate. Push moves wptr and count together; pop moves rptr
    // and count together; do both or neither and nothing moves. Every
    // transition preserves it, so the solver needs nothing further and
    // the loop stops here rather than demanding a second invariant to
    // support the first. Not every strengthening is so lucky.
    // ==================================================================
    always @(*)
        if (f_past_valid) assert(count == (wptr - rptr));


`endif

    // ==================================================================
    // COVER -- given. Reachability is a bounded question, so these run in
    // `mode cover' and have nothing to do with induction.
    // ==================================================================
    always @(posedge clk) if (f_past_valid && !rst) begin
        cover(full);                       // it can fill
        cover(empty && $past(!empty));     // and drain again
        cover(count == DEPTH / 2);         // and sit in the middle
    end

endmodule

`default_nettype wire
