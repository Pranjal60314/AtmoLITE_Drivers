`timescale 1ns/1ps

module uart_tb;

    // Parameters
    parameter CLK_FREQ = 50000000;
    parameter BAUD_RATE = 9600; // Increased for faster simulation
    parameter PERIOD = 20;         // 50MHz clock period in ns

    // TB Signals
    reg clk = 0;
    reg reset = 0;
    reg [7:0] tx_data_in;
    reg tx_data_valid;
    
    wire tx_to_rx;      // The physical wire connecting TX to RX
    wire tx_busy;
    wire [7:0] rx_data_out;
    wire rx_ready;

    // 1. Instantiate UART Transmitter
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut_tx (
        .clk(clk),
        .reset(reset),
        .data_in(tx_data_in),
        .data_valid(tx_data_valid),
        .tx(tx_to_rx),
        .busy(tx_busy)
    );

    // 2. Instantiate UART Receiver
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut_rx (
        .clk(clk),
        .rx(tx_to_rx),
        .data_out(rx_data_out),
        .ready(rx_ready)
    );

    // Clock Generation
    always #(PERIOD/2) clk = ~clk;

    // Main Test Logic
    initial begin
        // Initialize
        reset = 1;
        tx_data_in = 8'h00;
        tx_data_valid = 0;
        
        // VCD dumping for waveform viewing
        $dumpfile("uart_sim.vcd");
        $dumpvars(0, uart_tb);

        // Release Reset
        #(PERIOD * 5);
        reset = 0;
        #(PERIOD * 10);

        // --- Test Case 1: Send 0xA5 ---
        send_byte(8'hA5);
        
        // Wait for Receiver to flag "ready"
        wait(rx_ready);
        @(posedge clk); // Small buffer
        if (rx_data_out == 8'hA5) 
            $display("[TIME %t] SUCCESS: Received 0xA5", $time);
        else 
            $display("[TIME %t] ERROR: Received %h, expected A5", $time, rx_data_out);

        #(PERIOD * 100);

        // --- Test Case 2: Send 0x3C ---
        send_byte(8'h3C);
        
        wait(rx_ready);
        @(posedge clk);
        if (rx_data_out == 8'h3C)
            $display("[TIME %t] SUCCESS: Received 0x3C", $time);
        else
            $display("[TIME %t] ERROR: Received %h, expected 3C", $time, rx_data_out);

        #(PERIOD * 1000);
        $display("Simulation Finished.");
        $finish;
    end

    // Task to handle TX handshaking
    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            while (tx_busy) @(posedge clk); // Wait if UART is currently busy
            tx_data_in <= data;
            tx_data_valid <= 1;
            @(posedge clk);
            tx_data_valid <= 0;
            $display("[TIME %t] TX: Sending Byte %h", $time, data);
            
        end
    endtask

endmodule