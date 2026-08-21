// Fixtures for the harness self-test. Not an exercise -- these exist so
// that mk/run.sh can be shown to tell the four verdicts apart.

`default_nettype none

module tiny (
    input wire clk,
    input wire rst
);

    // Wide enough that k-induction cannot close by exhausting the state
    // space -- see the note in exercises/06.
    reg [15:0] c;
    always @(posedge clk)
        if (rst) c <= 16'd0;
        else     c <= c + 16'd2;            // only ever even

    initial assume(rst);

    reg pv = 1'b0;
    always @(posedge clk) pv <= 1'b1;

`ifdef WANT_FAIL
    // False, and cheaply so: the counter reaches 8 on the fifth step.
    always @(*) if (pv) assert(c < 16'd8);
`endif

`ifdef WANT_PASS
    // True and inductive.
    always @(*) if (pv) assert(c[0] == 1'b0);
`endif

`ifdef WANT_UNKNOWN
    // True -- the counter only takes even values, so it never equals 7 --
    // but NOT inductive: from an arbitrary odd state the next value is 7.
    // Base case passes, induction fails, sby says UNKNOWN.
    always @(*) if (pv) assert(c != 16'd7);
`endif

`ifndef NO_COVER
    always @(posedge clk) if (pv) cover(c == 16'd4);
`endif
    // With NO_COVER defined this module has no cover statements at all,
    // which is what the `verdict_empty' task needs: a cover run with
    // nothing to reach passes instantly, and the harness must not accept
    // that as a pass.

endmodule

`default_nettype wire
