// Reference solution for exercise 05 -- one assertion, three cover
// statements, and a lesson about which number you are trusting.
//
// The assertion is the same bounded-liveness shape as exercise 03's S5.
// What matters here is not the property; it is that the identical
// property, over the identical design, returns PASS at depth 20 and a
// counterexample at depth 64.

`default_nettype none

module props #(
    parameter TIMEOUT = 40
) (
    input wire clk,
    input wire rst,
    input wire kick,
    input wire bark
);

    initial assume(rst);

    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ------------------------------------------------------------------
    // GIVEN: clocks since the last kick, bark or reset.
    //
    // Seven bits, not five. A counter in a property file has to be wide
    // enough for the values the SPECIFICATION talks about, and it is
    // worth noticing that making this one five bits wide -- to "match the
    // design" -- would reproduce the bug inside the property and the
    // whole run would pass.
    //
    // A property file that copies the design's mistakes agrees with it
    // perfectly and proves nothing. This is the strongest argument for
    // writing properties from the specification and not from the RTL, and
    // it is a mistake that is very easy to make while staring at the code
    // you are verifying.
    // ------------------------------------------------------------------
    reg [6:0] f_quiet;
    always @(posedge clk)
        if (rst || kick || bark) f_quiet <= 7'd0;
        else                     f_quiet <= f_quiet + 7'd1;

    // ------------------------------------------------------------------
    // THE ASSERTION. f_quiet is cleared by a kick, by reset, and by a
    // bark -- so f_quiet climbing past the timeout is exactly the
    // statement that no bark arrived when one was due.
    //
    // The bound is TIMEOUT+1 rather than TIMEOUT because the design's
    // bark is registered: it decides on the clock the count reaches
    // TIMEOUT and the output appears on the next one. Off-by-one in a
    // bound is not a small matter -- one clock too tight and a correct
    // design fails, one too loose and a design that barks a clock late
    // passes. It is worth deriving from the specification rather than
    // adjusting until the good case goes green, which is the same
    // procedure as fitting a curve to your data.
    // ------------------------------------------------------------------
    always @(*)
        if (f_past_valid && !rst) assert(f_quiet <= TIMEOUT[6:0] + 7'd1);


    // ------------------------------------------------------------------
    // COVER. C1 is the one that matters and it is the only one here that
    // is deep.
    // ------------------------------------------------------------------
    always @(posedge clk) if (f_past_valid && !rst) begin

        // C1. A quiet spell long enough to be interesting -- one clock
        //     short of the timeout, so it sits just before the assertion
        //     it is guarding rather than on top of it.
        //
        //     Reaching it takes about forty steps. At depth 20 it is
        //     unreachable and `shallow_cover' fails, which is the alarm
        //     this exercise exists to make ring: the depth 20 run above
        //     never got within half the distance of the behaviour it
        //     claimed to have checked.
        //
        //     A cover set with nothing deep in it passes at every depth
        //     and warns you of nothing, which is the state most property
        //     files are in.
        cover(f_quiet == TIMEOUT[6:0] - 7'd1);

        // C2. The watchdog can actually be kicked. Cheap, shallow, and it
        //     confirms kicks are modelled at all -- an assumption
        //     somewhere that accidentally tied kick low would otherwise
        //     leave every result in this file meaningless.
        cover(kick);

        // C3. A short quiet spell. A control: reachable at any depth, so
        //     if C3 fails as well then the problem is the harness and not
        //     the horizon. Distinguishing "too shallow" from "wired up
        //     wrong" costs one line and saves an afternoon.
        cover(f_quiet == 7'd3);

    end

    // ------------------------------------------------------------------
    // What is deliberately absent: `cover(bark)'.
    //
    // It is the first thing anyone reaches for and it is unreachable at
    // every depth, because the design never barks at all. It would fail
    // `shallow_cover' and `deep_cover' alike, and a cover statement that
    // fails whatever you do cannot distinguish anything from anything.
    //
    // Note that a correct watchdog would make it reachable, and on a
    // correct watchdog it would be a good cover statement to have. That
    // is the test: cover states the design is SUPPOSED to reach. When the
    // bug is fixed those statements keep working, which is when you need
    // them.
    // ------------------------------------------------------------------

endmodule

`default_nettype wire
