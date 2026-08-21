// A correct four-deep FIFO with storage. First-word-fall-through: rdata_o
// shows the head of the queue whenever the queue is not empty, with no
// read latency.

`default_nettype none

module fifo #(
    parameter AW = 2,                       // 4 entries
    parameter DW = 8
) (
    input  wire          clk_i,
    input  wire          rst_i,
    input  wire          push_i,
    input  wire [DW-1:0] wdata_i,
    input  wire          pop_i,
    output wire [DW-1:0] rdata_o,
    output wire          full_o,
    output wire          empty_o
);

    localparam DEPTH = (1 << AW);

    reg [DW-1:0] mem [0:DEPTH-1];
    reg [AW:0]   wptr, rptr;

    wire do_push = push_i && !full_o;
    wire do_pop  = pop_i  && !empty_o;

    always @(posedge clk_i) begin
        if (rst_i) begin
            wptr <= {(AW+1){1'b0}};
            rptr <= {(AW+1){1'b0}};
        end else begin
            if (do_push) wptr <= wptr + 1'b1;
            if (do_pop)  rptr <= rptr + 1'b1;
        end
    end

    always @(posedge clk_i)
        if (do_push) mem[wptr[AW-1:0]] <= wdata_i;

    assign rdata_o = mem[rptr[AW-1:0]];
    assign empty_o = (wptr == rptr);
    assign full_o  = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);

endmodule

`default_nettype wire
