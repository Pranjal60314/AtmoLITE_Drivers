`timescale 1ns/1ps
`include "hdr.v"

module hdr_tb;

reg clk;
reg reset;
reg data_valid;

reg [7:0] protocol;
reg [7:0] subprotocol;
reg [7:0] packet_nr;
reg [7:0] param0, param1, param2, param3;
reg [7:0] param4, param5, param6, param7;
reg [23:0] data_length;

wire [7:0] header_out [127:0];
wire [7:0] crc_out;

// Instantiate DUT
hdr_gntr uut(
.clk(clk),

.protocol(protocol),
.subprotocol(subprotocol),
.packet_nr(packet_nr),

.param0(param0),
.param1(param1),
.param2(param2),
.param3(param3),
.param4(param4),
.param5(param5),
.param6(param6),
.param7(param7),

.data_length(data_length),

.header_out(header_out),
.crc_out(crc_out)

);

// Clock generation
always #5 clk = ~clk;

integer i;

initial begin
$dumpfile("hdr.vcd");
$dumpvars(0, hdr_tb);

clk = 0;
reset = 1;
data_valid = 0;

// Init inputs
protocol = 8'hAA;
subprotocol = 8'hBB;
packet_nr = 8'h01;

param0 = 8'h11;
param1 = 8'h22;
param2 = 8'h33;
param3 = 8'h44;
param4 = 8'h55;
param5 = 8'h66;
param6 = 8'h77;
param7 = 8'h88;

data_length = 24'h000123;

#20;
reset = 0;

#10;
data_valid = 1;

#200;
data_valid = 0;

#50;

// Print header
$display("---- HEADER ----");
for (i = 0; i < 16; i = i + 1) begin
    $display("header[%0d] = %h", i, header_out[i]);
end

$display("CRC = %h", crc_out);

#20;
$finish;

end

endmodule