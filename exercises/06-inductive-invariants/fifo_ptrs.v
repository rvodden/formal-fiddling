// =====================================================================
// The design under test for exercise 06: the pointer arithmetic of a
// FIFO -- eight deep, as the harness instantiates it. It is CORRECT.
// Nothing here needs fixing.
//
// The thing to notice about it is that it knows how full it is in two
// separate ways, and never checks them against each other:
//
//   * the pointers. wptr and rptr are one bit wider than the address
//     they carry, and that extra bit is the wrap flag -- equal pointers
//     mean empty, pointers differing only in the wrap bit mean full.
//     This is the standard trick and it is how full_o and empty_o are
//     computed.
//
//   * `count', a plain up/down counter maintained alongside them.
//
// Two registers holding the same fact is completely ordinary hardware --
// you keep `count' because the pointer comparison is slow, or because
// something downstream wants an occupancy figure. In real silicon they
// agree, because reset starts them agreeing and every subsequent
// operation moves both.
//
// A solver doing induction does not start at reset. That is the whole of
// exercise 06.
// =====================================================================

`default_nettype none

module fifo_ptrs #(
    parameter AW = 4                        // formal_top.v uses 3, for 8
) (
    input  wire        clk_i,
    input  wire        rst_i,
    input  wire        push_i,
    input  wire        pop_i,
    output wire [AW:0] count_o,
    output wire [AW:0] wptr_o,
    output wire [AW:0] rptr_o,
    output wire        full_o,
    output wire        empty_o
);

    localparam [AW:0] DEPTH = (1 << AW);

    // One bit wider than the address: the top bit is the wrap flag.
    reg [AW:0] wptr, rptr;
    reg [AW:0] count;

    wire do_push = push_i && !full_o;
    wire do_pop  = pop_i  && !empty_o;

    always @(posedge clk_i) begin
        if (rst_i) begin
            wptr  <= {(AW+1){1'b0}};
            rptr  <= {(AW+1){1'b0}};
            count <= {(AW+1){1'b0}};
        end else begin
            if (do_push) wptr <= wptr + 1'b1;
            if (do_pop)  rptr <= rptr + 1'b1;

            case ({do_push, do_pop})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: ;                   // both or neither
            endcase
        end
    end

    assign empty_o = (wptr == rptr);
    assign full_o  = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);

    assign count_o = count;
    assign wptr_o  = wptr;
    assign rptr_o  = rptr;

endmodule

`default_nettype wire
