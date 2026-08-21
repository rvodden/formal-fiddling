// Deliberately unbuildable. This is the important fixture: it stands in
// for the typo you put in your own property file, and the harness must
// report it as ERROR rather than counting it as a FAIL that some task was
// expecting anyway.

`default_nettype none

module broken_syntax (
    input wire clk
);

    this is not verilog and is not meant to be

endmodule
