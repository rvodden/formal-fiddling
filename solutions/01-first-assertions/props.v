// Reference solution for exercise 01 -- properties for a priority encoder.
//
// Five statements. The whole specification of a priority encoder is
// three of them; the other two are the cover statements that show the
// three mean something.

`default_nettype none

module props (
    input wire [7:0] req,
    input wire [2:0] idx,
    input wire       vld
);

    // P1. vld says precisely whether there was anything to find. Written
    //     as an equality rather than as two implications, because that is
    //     what "precisely" means and it is one line instead of two.
    //
    //     This is what catches bad2.
    always @(*) assert(vld == (req != 8'd0));

    // P2. The bit we named is actually set.
    //
    //     Necessary and nowhere near sufficient -- bad1 satisfies it
    //     happily, because the highest set bit is also a set bit. On its
    //     own this property proves the encoder returns *a* request, not
    //     *the* request.
    always @(*)
        if (vld) assert(req[idx] == 1'b1);

    // P3. Nothing below it is set. THIS is priority; P2 is not.
    //
    //     (8'd1 << idx) - 8'd1 is the mask of every bit below idx: for
    //     idx=3 that is 8'b00000111. Requiring req to have none of them
    //     set says no lower request was passed over, which is the entire
    //     content of the word "priority".
    //
    //     This is what catches bad1 and bad3, and it is the property that
    //     a first attempt usually leaves out.
    always @(*)
        if (vld) assert((req & ((8'd1 << idx) - 8'd1)) == 8'd0);

    // ------------------------------------------------------------------
    // Why P1..P3 are sufficient, which is worth checking rather than
    // assuming: if any bit is set then vld is high (P1), the named bit is
    // set (P2), and no lower bit is set (P3). "Set, with nothing set
    // below it" is a unique bit, so idx is pinned to exactly one value.
    // There is no room left for a wrong answer, and adding a fourth
    // property would be adding a property that can never fail.
    //
    // Confirming this is not pedantry. The usual failure of a property
    // set is being too weak, and the way you find out is by asking what a
    // malicious implementation could still get away with. Here: nothing.
    // ------------------------------------------------------------------

    // COVER. With no assumptions in the file these are all reachable
    // trivially, and this run is really a sanity check on the harness --
    // if `cover' fails here, the design is not connected to the
    // properties at all. Exercise 04 is where cover starts earning its
    // keep.
    always @(*) begin
        cover(vld);                        // something can be requested
        cover(!vld);                       // and nothing can be
        cover(vld && idx == 3'd7);         // the top bit can win, which it
                                           // only does when it is alone
    end

endmodule

`default_nettype wire
