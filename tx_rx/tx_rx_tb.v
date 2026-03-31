`timescale 1ns / 1ps

module uart_system_tb();

    // Parameters
    localparam CLK_HZ     = 50_000_000;
    localparam BIT_RATE   = 115200; // Fast for simulation
    localparam CLK_PERIOD = 20;     // 50MHz
    localparam FIFO_DEPTH = 32;

    // Clock and Reset
    reg clk = 0;
    reg resetn = 0;

    // TX Signals
    reg        tx_en = 1;
    reg  [7:0] tx_wr_data = 0;
    reg        tx_wr_en = 0;
    wire       tx_fifo_full;
    wire       uart_line;   // The physical TX pin
    wire       tx_system_busy;

    // RX Signals
    reg        rx_en = 1;
    reg        rx_rd_en = 0;
    wire [7:0] rx_rd_data;
    wire       rx_fifo_empty;
    wire       rx_fifo_full;
    wire       rx_break;

    // 1. Instantiate Buffered TX
    buffered_uart_tx #(
        .BIT_RATE(BIT_RATE),
        .CLK_HZ(CLK_HZ),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut_tx (
        .clk(clk),
        .resetn(resetn),
        .tx_en(tx_en),
        .wr_data(tx_wr_data),
        .wr_en(tx_wr_en),
        .fifo_full(tx_fifo_full),
        .uart_txd(uart_line), // Connect TX to our "wire"
        .tx_busy(tx_system_busy)
    );

    // 2. Instantiate Buffered RX
    buffered_uart_rx #(
        .BIT_RATE(BIT_RATE),
        .CLK_HZ(CLK_HZ),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut_rx (
        .clk(clk),
        .resetn(resetn),
        .uart_rxd(uart_line), // Loopback: Connect RX to the TX "wire"
        .uart_rx_en(rx_en),
        .rd_data(rx_rd_data),
        .rd_en(rx_rd_en),
        .fifo_empty(rx_fifo_empty),
        .fifo_full(rx_fifo_full),
        .rx_break(rx_break)
    );

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
    initial begin
        // Setup Waveform Dump for Arch/Icarus
        $dumpfile(`VCD_FILE);
        $dumpvars(0, uart_system_tb);

        // Reset Sequence
        resetn = 0;
        #(CLK_PERIOD * 20);
        resetn = 1;
        #(CLK_PERIOD * 20);

        $display("[%0t] Starting Loopback Test...", $time);

        // --- Step 1: Push 3 bytes into TX FIFO ---
        send_tx_byte(8'hA5);
        send_tx_byte(8'h3C);
        send_tx_byte(8'h7E);

        // --- Step 2: Wait for bits to fly across the "wire" ---
        // Each byte takes approx 87us at 115200 baud
        wait(rx_fifo_empty == 0);
        $display("[%0t] First byte detected in RX FIFO!", $time);
        
        // Wait until all 3 bytes are finished and sitting in RX FIFO
        #(CLK_PERIOD * 500000); 

        // --- Step 3: Read back from RX FIFO and Verify ---
        read_rx_byte(8'hA5);
        read_rx_byte(8'h3C);
        read_rx_byte(8'h7E);

        $display("[%0t] SUCCESS: All bytes matched!", $time);
        #(CLK_PERIOD * 100);
        $finish;
    end

        // --- TRANSMIT MONITOR ---
    always @(posedge clk) begin
        // When the glue logic in the TX buffer pulses 'uart_en', 
        // it means a byte is moving from FIFO to the UART Shifter.
        if (dut_tx.uart_en) begin
            $display("[%0t] >> PHYSICAL TX STARTING: Byte 0x%h", $time, dut_tx.fifo_dout);
        end
    end

    // --- RECEIVE MONITOR ---
    always @(posedge clk) begin
        // When the internal UART RX module says 'valid', 
        // it means it just finished shifting in a full byte from the wire.
        if (dut_rx.raw_rx_valid) begin
            $display("[%0t] << PHYSICAL RX COMPLETE: Byte 0x%h", $time, dut_rx.raw_rx_data);
        end
    end

    // --- Helper Tasks ---
    task send_tx_byte(input [7:0] data);
        begin
            @(posedge clk);
            if (!tx_fifo_full) begin
                tx_wr_data = data;
                tx_wr_en = 1;
                @(posedge clk);
                tx_wr_en = 0;
                $display("[%0t] TX_FIFO WRITE: 0x%h", $time, data);
            end
        end
    endtask

    task read_rx_byte(input [7:0] expected);
        begin
            @(posedge clk);
            if (!rx_fifo_empty) begin
                rx_rd_en = 1;
                @(posedge clk);
                rx_rd_en = 0;
                if (rx_rd_data === expected)
                    $display("[%0t] RX_FIFO READ:  0x%h (MATCH)", $time, rx_rd_data);
                else
                    $display("[%0t] ERROR: Expected 0x%h, Got 0x%h", $time, expected, rx_rd_data);
            end else begin
                $display("[%0t] ERROR: Attempted to read empty RX FIFO", $time);
            end
        end
    endtask

endmodule