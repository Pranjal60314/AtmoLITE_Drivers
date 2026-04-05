`timescale 1ns / 1ps

module tb_buffered_uart_rx();

    // --- Parameters ---
    parameter CLK_HZ     = 50_000_000;
    parameter BIT_RATE   = 115200; // Standard Baud Rate
    parameter FIFO_DEPTH = 16;
    
    localparam CLK_PERIOD = 20; // 50MHz
    // Calculate bit period in nanoseconds
    localparam BIT_PERIOD = 1_000_000_000 / BIT_RATE;

    // --- Signals ---
    reg        clk;
    reg        resetn;
    reg        uart_rxd;
    reg        uart_rx_en;
    reg        rd_en;
    
    wire [7:0] rd_data;
    wire       fifo_empty;
    wire       fifo_full;
    wire       rx_break;

    // --- UUT (Unit Under Test) ---
    buffered_uart_rx #(
        .BIT_RATE(BIT_RATE),
        .CLK_HZ(CLK_HZ),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) uut (
        .clk(clk),
        .resetn(resetn),
        .uart_rxd(uart_rxd),
        .uart_rx_en(uart_rx_en),
        .rd_data(rd_data),
        .rd_en(rd_en),
        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .rx_break(rx_break)
    );

    // --- Clock Generation ---
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Helper Task: Simulate Incoming UART Byte ---
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            $display("[TIME %0t] Sending Byte: 0x%h", $time, data);
            
            // Start Bit (Logical 0)
            uart_rxd = 0;
            #(BIT_PERIOD);
            
            // Data Bits (LSB First)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rxd = data[i];
                #(BIT_PERIOD);
            end
            
            // Stop Bit (Logical 1)
            uart_rxd = 1;
            #(BIT_PERIOD);
            
            // Inter-packet gap
            #(BIT_PERIOD); 
        end
    endtask

    // --- Main Test Procedure ---
    initial begin
        // Initialize
        clk = 0;
        resetn = 0;
        uart_rxd = 1;      // Idle state for UART is high
        uart_rx_en = 0;
        rd_en = 0;

        // Reset Sequence
        repeat(5) @(posedge clk);
        resetn = 1;
        repeat(5) @(posedge clk);
        uart_rx_en = 1;
        $display("--- Reset Released, UART RX Enabled ---");

        // 1. Send several bytes to fill the FIFO
        send_uart_byte(8'hA5); // Test pattern 1
        send_uart_byte(8'h3C); // Test pattern 2
        send_uart_byte(8'hFF); // Test pattern 3

        // 2. Check if FIFO caught them
        repeat(10) @(posedge clk);
        if (!fifo_empty) begin
            $display("[TIME %0t] FIFO is not empty, starting readback...", $time);
        end

        // 3. Pulse rd_en to read the first byte (should be 0xA5)
        @(posedge clk);
        rd_en = 1;
        @(posedge clk);
        rd_en = 0;
        $display("[TIME %0t] Read Byte 1: 0x%h (Expected: 0xA5)", $time, rd_data);

        // 4. Read the second byte (should be 0x3C)
        repeat(2) @(posedge clk);
        rd_en = 1;
        @(posedge clk);
        rd_en = 0;
        $display("[TIME %0t] Read Byte 2: 0x%h (Expected: 0x3C)", $time, rd_data);

        // 5. Test a BREAK condition (Line low for a long time)
        $display("[TIME %0t] Simulating BREAK condition...", $time);
        uart_rxd = 0;
        #(BIT_PERIOD * 12); // Longer than a standard frame
        uart_rxd = 1;
        
        repeat(10) @(posedge clk);
        if (rx_break) $display("[SUCCESS] rx_break signal detected!");

        // 6. Final Read of remaining data
        wait(!fifo_empty);
        rd_en = 1;
        @(posedge clk);
        rd_en = 0;
        $display("[TIME %0t] Read Byte 3: 0x%h (Expected: 0xFF)", $time, rd_data);

        repeat(100) @(posedge clk);
        $display("--- Testbench Completed ---");
        $finish;
    end

endmodule