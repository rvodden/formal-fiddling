// Harness. req is an undriven input, so the solver may set it to any of
// the 256 values on any step; that is the exhaustive stimulus.
//
// Every DUT in dut/ is called prio_encoder, so this file never changes.

`default_nettype none

module formal_top (
    input wire       clk,
    input wire [7:0] req
);

    wire [2:0] idx;
    wire       vld;

    prio_encoder u_dut (.req_i(req), .idx_o(idx), .vld_o(vld));

    props u_props (.req(req), .idx(idx), .vld(vld));

endmodule

`default_nettype wire
