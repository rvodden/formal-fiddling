// A correct skid buffer -- the standard two-register stream register
// slice. Your properties must PASS against this.
//
// It sits in a valid/ready stream and breaks the combinational path in
// both directions without costing throughput: one beat per clock, even
// under backpressure. The second register (the "skid") is what makes that
// possible -- when the output stage is blocked and a beat has already
// been accepted, it has somewhere to go.

`default_nettype none

module skid #(
    parameter DW = 4
) (
    input  wire          clk_i,
    input  wire          rst_i,

    // upstream
    input  wire          s_valid_i,
    input  wire [DW-1:0] s_data_i,
    output wire          s_ready_o,


    // Formal observation port. The skid register's contents are not
    // otherwise visible from outside, and a proof by induction needs to
    // say what is in it -- see props.v. It drives nothing, so synthesis
    // removes it; exposing internal state for verification like this is
    // ordinary practice and is much better than reaching into the
    // hierarchy from the property file, which ties the properties to one
    // particular implementation's signal names.
    output wire [DW-1:0] f_skid_data_o,

    // downstream
    output wire          m_valid_o,
    output wire [DW-1:0] m_data_o,
    input  wire          m_ready_i
);

    reg          skid_valid;
    reg [DW-1:0] skid_data;
    reg          out_valid;
    reg [DW-1:0] out_data;

    // We can take something new whenever the output register is empty or
    // is being emptied this clock.
    wire out_accept = m_ready_i || !out_valid;

    assign s_ready_o = !skid_valid;
    assign m_valid_o = out_valid;
    assign m_data_o  = out_data;
    assign f_skid_data_o = skid_data;

    always @(posedge clk_i) begin
        if (rst_i) begin
            skid_valid <= 1'b0;
            out_valid  <= 1'b0;
            skid_data  <= {DW{1'b0}};
            out_data   <= {DW{1'b0}};
        end else begin
            if (out_accept) begin
                if (skid_valid) begin
                    // Drain the skid into the output register.
                    out_data   <= skid_data;
                    out_valid  <= 1'b1;
                    skid_valid <= 1'b0;
                end else begin
                    // Straight through from upstream.
                    out_data  <= s_data_i;
                    out_valid <= s_valid_i;
                end
            end

            // Blocked, but we already said we were ready -- so whatever
            // arrives this clock has to be caught.
            if (!out_accept && s_valid_i && s_ready_o) begin
                skid_data  <= s_data_i;
                skid_valid <= 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
