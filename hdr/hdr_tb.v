`timescale 1ns / 1ps

module hdr_tb;
    //inputs for the header
    reg clk;
    reg reset;

    reg [7:0] protocol, subprotocol, packet_nr;
    reg [7:0] param0, param1, param2, param3, param4, param5, param6, param7;
    reg [23:0] data_length;
    
    //outputs
    wire UART_TX;

    //inputs for the receiver
    reg rx_en;
    wire rx_break;
    wire rx_valid;
    wire [7:0] rx_data;

    //machine instantiation
    hdr #(
        .logical_address(8'hFE)
    ) uut (
        .clk(clk),
        .reset(reset),
        .protocol(8'hAA),
        .subprotocol(8'hBB),
        .packet_nr(8'h01),
        .param0(8'h11), .param1(8'h22), .param2(8'h33), .param3(8'h44),
        .param4(8'h55), .param5(8'h66), .param6(8'h77), .param7(8'h88),
        .data_length(24'h000123),
        .UART_TX(UART_TX)
    );

    uart_rx #(
        .BIT_RATE(9600), // bits / sec
        .CLK_HZ(50_000_000),
        .PAYLOAD_BITS(8),
        .STOP_BITS(1)
    ) rx_inst (
      .clk(clk), // Top level system clock input.
      .resetn(~reset), // Asynchronous active low reset.
      .uart_rxd(UART_TX), // UART Recieve pin.
      .uart_rx_en(rx_en), // Recieve enable
      .uart_rx_break(rx_break), // Did we get a BREAK message?
      .uart_rx_valid(rx_valid), // Valid data recieved and available.
      .uart_rx_data(rx_data)// The recieved data.
    );


    always #10 clk = ~clk;

    always @(posedge clk) begin
        if(rx_valid) begin
            $display("[TIME %time] Receiver byte: 0x%h",$time,rx_data);
        end
    end

    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0,hdr_tb);
        clk = 0;
        reset = 1;
        rx_en = 1;
        #100
        reset = 0;
        $display("Simulation Started. Monitoring UART_TX...");
        #20050000; // Run for 25ms instead of 20ms; 
        reset = 1;
        $display("Simulation Finished.");
        $finish;
    end

// parameter BIT_TIME = 104167;


// reg [7:0] rx_byte; // Temporary register to hold the bits
// integer i;         // Loop counter

// initial begin
//     forever begin
//         @(negedge UART_TX);
//         $display("\n--- NEW BYTE DETECTED AT %t ---", $time);
        
//         // Sample in the middle of the first data bit
//         #(BIT_TIME * 1.5); 
        
//         $write("DATA BITS: ");
//         for (i = 0; i < 8; i = i + 1) begin
//             $write("%b ", UART_TX);
//             rx_byte[i] = UART_TX; // Store bit (i=0 is LSB)
//             $display("[Time %t] Sampling Bit %0d: %b", $time, i, UART_TX);
//             #(BIT_TIME);
//         end
        
//         // Now rx_byte holds the full byte
//         $display("\nSTOP BIT : %b", UART_TX);
//         $display("HEX VALUE: 0x%h", rx_byte);
//         $display("---------------------------------");
//     end
// end



endmodule