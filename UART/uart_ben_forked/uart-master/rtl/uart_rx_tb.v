`timescale 1ns / 1ps

module tb_buffered_rx();

    // Parameters matching your system
    localparam CLK_HZ   = 50_000_000;
    localparam BIT_RATE = 115200;
    localparam BIT_TIME = 1_000_000_000 / BIT_RATE; // nanoseconds per bit
    localparam CLK_PERIOD = 20; // 50MHz

    reg clk = 0;
    reg resetn = 0;
    reg uart_rxd = 1;      // Idle high
    reg uart_rx_en = 1;
    reg rd_en = 0;

    wire [7:0] rd_data;
    wire fifo_empty;
    wire fifo_full;
    wire rx_break;

    // Instantiate the Buffered Receiver
    buffered_uart_rx #(
        .BIT_RATE(BIT_RATE),
        .CLK_HZ(CLK_HZ),
        .FIFO_DEPTH(4) // Small depth to test "Full" condition quickly
    ) dut (
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

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        // Setup Waveform Dumping (Arch Linux / Icarus style)
        $dumpfile(`VCD_FILE);
        $dumpvars(0, tb_buffered_rx);

        // Reset
        resetn = 0;
        #(CLK_PERIOD * 10);
        resetn = 1;
        #(CLK_PERIOD * 10);

        $display("[%0t] Starting Serial Data Injection...", $time);

        // --- STEP 1: Send 0xFE (1111 1110) ---
        // UART is LSB first: Start(0), 0, 1, 1, 1, 1, 1, 1, 1, Stop(1)
        send_serial_byte(8'hFE);
        
        // --- STEP 2: Send 0x55 (0101 0101) ---
        send_serial_byte(8'h55);

        // Wait a bit for the internal FSMs to settle
        #(BIT_TIME * 2);

        // --- STEP 3: Check if FIFO has data ---
        if (!fifo_empty) begin
            $display("[%0t] FIFO NOT EMPTY - Data is waiting!", $time);
            
            // Pop the first byte
            @(posedge clk);
            rd_en = 1;
            @(posedge clk);
            rd_en = 0;
            $display("[%0t] READ FROM FIFO: 0x%h (Expected 0xFE)", $time, rd_data);
            
            // Pop the second byte
            @(posedge clk);
            rd_en = 1;
            @(posedge clk);
            rd_en = 0;
            $display("[%0t] READ FROM FIFO: 0x%h (Expected 0x55)", $time, rd_data);
        end else begin
            $display("[%0t] ERROR: FIFO is empty, data was lost!", $time);
        end

        #(BIT_TIME * 5);
        $display("[%0t] Test Complete.", $time);
        $finish;
    end

    // Task to simulate a UART transmitter (PC side)
    task send_serial_byte(input [7:0] data);
        integer j;
        begin
            // Start Bit
            uart_rxd = 0;
            #(BIT_TIME);
            
            // Data Bits (LSB First)
            for (j = 0; j < 8; j = j + 1) begin
                uart_rxd = data[j];
                #(BIT_TIME);
            end
            
            // Stop Bit
            uart_rxd = 1;
            #(BIT_TIME);
            $display("[%0t] Serial Byte 0x%h finished sending.", $time, data);
        end
    endtask

endmodule