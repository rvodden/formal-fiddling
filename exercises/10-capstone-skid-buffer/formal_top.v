`default_nettype none

module formal_top (
    input wire       clk,
    input wire       rst,
    input wire       s_valid,
    input wire [3:0] s_data,
    input wire       m_ready
);

    localparam DW = 4;

    wire          s_ready;
    wire          m_valid;
    wire [DW-1:0] m_data;
    wire [DW-1:0] f_skid_data;

    skid #(.DW(DW)) u_dut (
        .clk_i(clk), .rst_i(rst),
        .s_valid_i(s_valid), .s_data_i(s_data), .s_ready_o(s_ready),
        .f_skid_data_o(f_skid_data),
        .m_valid_o(m_valid), .m_data_o(m_data), .m_ready_i(m_ready));

    props #(.DW(DW)) u_props (
        .clk(clk), .rst(rst),
        .s_valid(s_valid), .s_data(s_data), .s_ready(s_ready),
        .f_skid_data(f_skid_data),
        .m_valid(m_valid), .m_data(m_data), .m_ready(m_ready));

endmodule

`default_nettype wire
