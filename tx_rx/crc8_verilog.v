`timescale 1ns / 1ps
module crc8_generator (
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  data_in,
    input  wire        data_valid,
    output reg  [7:0]  crc_out
);

    reg [7:0] crc_reg;
    reg [7:0] CRC_TABLE [0:255];

    wire [7:0] next_crc = CRC_TABLE[crc_reg ^ data_in];

    initial begin
    $readmemh("crc_table.hex", CRC_TABLE);
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            crc_reg <= 8'h00;
            crc_out <= 8'h00;
        end 
        else if (data_valid) begin
            crc_reg <= next_crc;
            crc_out <= next_crc; 
        end
    end

endmodule
