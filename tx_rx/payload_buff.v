`timescale 1ns / 1ps
module payload_buffer #(
    parameter MAX_LEN = 256
)(
    input  wire        clk,
    input  wire [7:0]  wr_data,
    input  wire        wr_en,
    input  wire [7:0]  wr_addr,
    
    input  wire [7:0]  rd_addr,
    output wire [7:0]  rd_data
);
    reg [7:0] mem [0:MAX_LEN-1];

    always @(posedge clk) begin
        if (wr_en) mem[wr_addr] <= wr_data;
    end

    assign rd_data = mem[rd_addr];
endmodule