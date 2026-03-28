`timescale 1ns/1ps

module crc8_tb;

reg clk;
reg reset;
reg data_valid;
reg [7:0] data_in;
wire [7:0] crc_out;

crc8_generator uut(
    .clk(clk),
    .reset(reset),
    .data_in(data_in),
    .data_valid(data_valid),
    .crc_out(crc_out)
);

always #5 clk = ~clk;

initial begin
    $dumpfile(`VCD_FILE);
    $dumpvars(0, crc8_tb);
    clk = 0;
    reset = 1;
    data_valid = 0;

    #10 reset = 0;

    send_byte(8'hfe);
    send_byte(8'hAA);
    send_byte(8'hBB);
    send_byte(8'h01);
    send_byte(8'h11);
    send_byte(8'h11);
    send_byte(8'h22);
    send_byte(8'h33);
    send_byte(8'h44);
    send_byte(8'h55);
    send_byte(8'h66);
    send_byte(8'h77);
    send_byte(8'h88);
    send_byte(8'h99);
    send_byte(8'h23);
    send_byte(8'h01);
    send_byte(8'h00);
    

    #20;
    $display("CRC = %h", crc_out);
    $finish;
end

task send_byte;
input [7:0] data;
begin
    @(posedge clk);
    #1;
    data_in = data;
    data_valid = 1;
    @(posedge clk);
    #1;
    data_valid = 0;
end
endtask

endmodule