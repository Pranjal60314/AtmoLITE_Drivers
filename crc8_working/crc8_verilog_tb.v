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

    send_byte(1);
    send_byte(2);
    send_byte(3);
    send_byte(4);
    send_byte(5);
    send_byte(6);
    send_byte(7);
    send_byte(8);
    send_byte(9);
    send_byte(10);
    send_byte(11);
    send_byte(12);
    send_byte(13);
    send_byte(14);
    send_byte(15);
    

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