// =====================================================================
// Exercise 06 -- induction, and the invariants that make it close.
//
// Exercise 05 ended with a problem: `mode bmc' only ever proves "no
// counterexample within N steps", the N you need is generally unknowable,
// and making N large gets expensive fast.
//
// `mode prove' is the way out. It is a genuinely unbounded proof, and it
// works quite differently:
//
//   BASE CASE   the property holds for the first k steps from reset.
//               (This is just BMC, and it is the half you already know.)
//
//   INDUCTION   IF the property holds for k consecutive steps, THEN it
//               holds on the step after. No reset in sight -- the solver
//               starts from a completely ARBITRARY state.
//
// Prove both and you have the property for all time, at any depth,
// forever. That is a much better answer than exercise 05 could give, and
// sby says so: "successful proof by k-induction".
//
// ---------------------------------------------------------------------
// THE PRICE: "AN ARBITRARY STATE" INCLUDES STATES YOUR DESIGN CANNOT
// REACH
//
// This is the whole difficulty of induction and it is worth being blunt
// about, because it produces counterexamples that look insane.
//
// The induction step starts every register at whatever value the solver
// pleases. Not a state reachable from reset -- ANY state. If your design
// has two registers that always agree in practice, induction will
// cheerfully start them disagreeing and show you the wreckage.
//
// The design here has exactly that. It knows its own occupancy twice
// over: once in `count', and once in the difference between the write and
// read pointers. From reset those two can never disagree. Induction does
// not start from reset, so it starts them disagreeing, and the property
// falls over immediately.
//
// The result is not FAIL. It is UNKNOWN, and the distinction matters:
//
//   FAIL      the solver has a real trace from reset that breaks your
//             property. Your design is wrong. Go and read it.
//
//   UNKNOWN   the base case held; induction did not. Nobody has shown
//             your property is false -- it is almost certainly true --
//             but it is not INDUCTIVE, so induction cannot establish it.
//             Your design is probably fine. Your property set is not
//             finished.
//
// Reading UNKNOWN as failure and going to look for a bug that is not
// there is the standard way to lose a day to this.
//
// ---------------------------------------------------------------------
// THE FIX: SAY WHAT ELSE IS TRUE
//
// You close the gap by strengthening the property set -- adding
// assertions that rule out the unreachable states the solver keeps
// starting in. They are called INVARIANTS, and the good ones are usually
// the sentence you would say out loud if someone asked how the design
// works.
//
// Here that sentence is "count and the pointers agree". Write it down as
// an assertion and two things happen at once. It is proved, because from
// reset it is true. And it is available to the induction step, which may
// now assume it about the arbitrary starting state -- which deletes
// exactly the nonsense states that were breaking the proof.
//
// That is the loop, and it is the whole working method of induction:
//
//   1. run `mode prove'
//   2. UNKNOWN -> read the induction counterexample
//   3. find the impossible thing about its starting state
//   4. assert that it cannot happen
//   5. go to 1
//
// Each pass adds an invariant, and each invariant is a real fact about
// your design that you now have written down and proved. That is worth
// something on its own: a strengthened property set is documentation of
// how a module works, in a form that cannot rot.
//
// ---------------------------------------------------------------------
// WHAT TO DO
//
//   make bmc            PASS     -- bounded, as in every exercise so far
//   make prove_weak     UNKNOWN  -- given. The target property alone.
//   make prove_strong   PASS     -- YOUR invariant, and induction closes
//   make cover          PASS
//
//   make                all four, with each verdict checked
//
// Run `make prove_weak' first and read the induction trace:
//
//   make prove_weak
//   make trace TASK=prove_weak
//
// Two things about that trace are unlike any you have read so far.
//
// LOOK AT STEP 0. `rst' is low. There is no reset anywhere in the trace,
// and there was never going to be -- the induction step does not start
// at reset, it starts wherever the solver likes. Every BMC trace you
// have read began with `rst' high because it began at the beginning.
// This one has no beginning.
//
// AND STEP 0 IS NONSENSE. Compare `count' with `wptr - rptr' there and
// they disagree, which cannot happen in the hardware: reset starts them
// equal and every operation moves both. The solver has started the
// machine in a state it could never be in, and everything that follows is
// the perfectly correct consequence of an impossible premise.
//
// That impossible starting state IS the answer. It is telling you, in the
// only way available to it, which fact about your design you have not
// written down yet.
//
// (The trace is not short, by the way. Its length is k -- the induction
// depth the solver got to before giving up -- and has nothing to do with
// how far the violation is from reset, because it is not measured from
// reset. Read step 0 and the last two steps; the middle is padding.)
//
// ---------------------------------------------------------------------
// A CAUTION ABOUT SMALL DESIGNS
//
// k-induction gets to assume the k states it looks at are all DIFFERENT,
// because a repeated state would mean a loop and a loop needs no
// induction. On a design with fewer states than the depth you asked for,
// that turns induction into exhaustive search: it closes properties that
// are not inductive at all, and hides everything this exercise is about.
//
// It is easy to trip over. A 4-bit counter has 16 states, so at `depth
// 24' a distinctness constraint over 24 states is unsatisfiable past the
// sixteenth and k-induction proves whatever you like. The identical
// property over a 16-bit counter comes back UNKNOWN.
//
// It does NOT bite this exercise, which was checked rather than assumed:
// prove_weak returns UNKNOWN at AW = 1, 2 and 3, because even the
// smallest of those has 64 states against a depth of 14. Shrink the FIFO
// if you want to; the lesson survives. Just be aware of the effect
// before you conclude something cheerful from a small design closing.
// =====================================================================

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
    // TODO: your INVARIANT goes here.
    //
    // One assertion is enough. It is the sentence that says the design's
    // two ways of knowing its own occupancy agree:
    //
    //     count is the difference between the write and read pointers
    //
    // Both pointers are AW+1 bits, and the subtraction is meant to wrap,
    // which is exactly what an unsigned (AW+1)-bit subtraction does --
    // so `wptr - rptr' is already the right expression and needs no
    // special handling for the wrap case.
    //
    // Write it as an ASSERTION, not an assumption. It is a fact you are
    // claiming about the design, and it gets proved like any other; the
    // induction step then has it available for free. Writing it as an
    // assumption would also make prove_strong pass, and would be worth no
    // more than the earlier exercises' vacuous PASS -- you would have
    // assumed the interesting half of the specification and proved the
    // rest from it.
    //
    // If you would like the loop rather than the answer: comment out the
    // target assertion, run prove_weak with nothing but this invariant,
    // and check that the invariant is itself inductive. It is, and
    // confirming that is what makes the difference between an invariant
    // you found and an invariant you were told.
    // ==================================================================


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
