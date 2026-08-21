// =====================================================================
// Exercise 04 -- cover, and proving that you proved something.
//
// This exercise is different in shape from the others. The assumptions
// and the assertions are already written, below, and they are not the
// part you are meant to change. The FIFO has a real bug in it. The
// property set below passes anyway.
//
// Your job is to write the COVER statements that expose that.
//
// ---------------------------------------------------------------------
// WHAT IS ACTUALLY WRONG HERE
//
// The design's `full_o' is off by one: it flags full at five entries in a
// four-deep queue, so a producer that correctly waits for room is still
// waved through into a fifth push. The assertion below -- the count never
// exceeds DEPTH -- is precisely the property that ought to catch it.
//
// Run `make hollow'. It passes.
//
// The culprit is A3, and it is worth looking at before you read another
// word, because the thing to take from this exercise is what an
// over-constraint LOOKS LIKE in a file, when nobody has told you there is
// one in it. It is not written in red. It does not look like a mistake.
// It looks like modelling.
//
// ---------------------------------------------------------------------
// WHY ANYONE WOULD EVER WRITE A3
//
// Because it is usually true and it makes proofs close.
//
// "The consumer is always ready" is an assumption people write for real
// and for good reasons: the downstream block is a wire, or a register
// file that never stalls, or it simply is not built yet and the FIFO has
// to be verified today. Written down at the top of a session it sounds
// like scoping. Read six weeks later it sounds like a fact about the
// system.
//
// What it actually says here is that the queue is drained on every clock
// it is not empty. So the occupancy never gets past one. So it never
// reaches four, so it never reaches five, so the off-by-one in `full_o'
// is in a part of the state space the solver was told not to visit -- and
// the assertion aimed straight at it passes, honestly and uselessly.
//
// No warning is printed. There is no diagnostic for this, in any tool,
// because from the inside it is indistinguishable from a design that is
// simply correct. The PASS you get is word for word the PASS you would
// get if the FIFO were right.
//
// ---------------------------------------------------------------------
// COVER IS THE ONLY ALARM THERE IS
//
// An assertion asks "can this be broken?" and silence is the good answer.
// A cover statement asks "can this be reached?" and silence is the BAD
// answer -- which is what makes it the only statement in the language
// that can tell you your model has been strangled.
//
// The rule that follows is worth adopting permanently: for every
// assumption you write, ask what it forbids, and cover something on the
// far side of it. An assumption whose exclusions you have not covered is
// an assumption you are trusting rather than checking.
//
// ---------------------------------------------------------------------
// WHAT TO DO
//
// Write cover statements at the bottom of this file so that:
//
//   make hollow        PASS  -- given. The bug, hidden by A3.
//   make hollow_cover  FAIL  -- YOUR covers, refusing to be reached
//                               while A3 is in force. This is the alarm.
//   make honest        FAIL  -- given. Same design, A3 switched off,
//                               and now the bug is plainly visible.
//   make honest_cover  PASS  -- YOUR covers, all reachable once the
//                               model is free again.
//
//   make               all four, with each verdict checked
//
// Note what those four demand of you, taken together: cover statements
// that are unreachable under A3 and reachable without it. That is a
// tighter specification than it first looks, and it rules out the cheap
// answer of covering something impossible. `cover(1'b0)' fails
// hollow_cover and fails honest_cover too.
//
// You need at least one that aims squarely at the space A3 deletes.
// =====================================================================

`default_nettype none

module props #(
    parameter DEPTH = 4
) (
    input wire       clk,
    input wire       rst,
    input wire       push,
    input wire       pop,
    input wire [2:0] count,
    input wire       full,
    input wire       empty
);

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ==================================================================
    // ASSUMPTIONS -- given. Two of these are the honest description of a
    // well-behaved producer and consumer. The third is the problem.
    // ==================================================================

    // A1. A polite producer does not push into a full queue.
    always @(*)
        if (full) assume(!push);

    // A2. A polite consumer does not pop from an empty one.
    always @(*)
        if (empty) assume(!pop);

`ifndef HONEST
    // A3. "The consumer is always ready." Switched off by -DHONEST, which
    //     is what the `honest' and `honest_cover' tasks do.
    //
    //     Read it once more before you go looking for its damage. There
    //     is nothing false about it as a description of some real
    //     systems, and nothing about the way it is written that marks it
    //     out from A1 and A2 above.
    always @(*)
        if (!empty) assume(pop);
`endif

    // ==================================================================
    // ASSERTION -- given. This is the right property. It is aimed exactly
    // at the bug. Under A3 it passes anyway.
    // ==================================================================
    always @(*)
        if (f_past_valid) assert(count <= DEPTH[2:0]);

    // ==================================================================
    // TODO: your COVER statements go here.
    //
    // Aim at what A3 forbids. Some things worth being able to reach:
    //
    //   - the queue actually filling up -- count reaching DEPTH
    //   - a consumer that stalls: data waiting, and no pop this clock
    //   - the queue half full, to show it is not simply pinned at 0 or 1
    //
    // The second is the most direct: A3 says in so many words that it
    // never happens, so a cover statement asking for it is a question
    // whose answer is the assumption itself.
    // ==================================================================

endmodule

`default_nettype wire
