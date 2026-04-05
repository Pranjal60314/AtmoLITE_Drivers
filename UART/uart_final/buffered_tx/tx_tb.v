`timescale 1ns / 1ps

module tb_buffered_uart_tx();

    // --- Parameters ---
    parameter CLK_HZ     = 50_000_000;
    parameter BIT_RATE   = 1_000_000; // 1MHz for faster simulation
    parameter FIFO_DEPTH = 8;
    localparam CLK_PERIOD = 20; // 50MHz
    localparam BIT_PERIOD = 1_000_000_000 / BIT_RATE;

    // --- Signals ---
    reg        clk;
    reg        resetn;
    reg        tx_en;
    reg  [7:0] wr_data;
    reg        wr_en;
    wire       fifo_full;
    wire       uart_txd;
    wire       tx_busy;

    // --- UUT (Unit Under Test) ---
    buffered_uart_tx #(
        .BIT_RATE(BIT_RATE),
        .CLK_HZ(CLK_HZ),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) uut (
        .clk(clk),
        .resetn(resetn),
        .tx_en(tx_en),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .fifo_full(fifo_full),
        .uart_txd(uart_txd),
        .tx_busy(tx_busy)
    );

    // --- Clock Generation ---
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Helper Task: Push to FIFO ---
    task push_byte(input [7:0] data);
        begin
            @(posedge clk);
            if (!fifo_full) begin
                wr_data = data;
                wr_en = 1;
                @(posedge clk);
                wr_en = 0;
                $display("[TIME %0t] Pushed 0x%h to FIFO", $time, data);
            end else begin
                $display("[TIME %0t] FIFO Full! Could not push 0x%h", $time, data);
            end
        end
    endtask

    // --- Helper Task: Monitor UART TXD ---
    // This logic decodes the serial line back into bytes for the console
    task monitor_uart;
        reg [7:0] rx_byte;
        integer j;
        begin
            forever begin
                @(negedge uart_txd); // Wait for start bit
                #(BIT_PERIOD + BIT_PERIOD/2); // Offset to middle of first data bit
                for (j = 0; j < 8; j = j + 1) begin
                    rx_byte[j] = uart_txd;
                    #(BIT_PERIOD);
                end
                $display("[UART MONITOR] Serial Line Sent: 0x%h", rx_byte);
            end
        end
    endtask

    // --- Main Test Procedure ---
    initial begin
        // Initialize
        clk = 0;
        resetn = 0;
        tx_en = 0;
        wr_data = 0;
        wr_en = 0;

        // Startup Monitor
        fork
            monitor_uart;
        join_none

        // Reset Sequence
        repeat(5) @(posedge clk);
        resetn = 1;
        repeat(5) @(posedge clk);

        $display("--- Starting Test: FIFO Fill and Drain ---");
        
        // 1. Fill the FIFO while tx_en is 0 (holding the data)
        push_byte(8'hA1);
        push_byte(8'hB2);
        push_byte(8'hC3);
        
        repeat(100) @(posedge clk);
        
        // 2. Enable Transmission
        $display("[TIME %0t] Enabling TX Path...", $time);
        tx_en = 1;

        // 3. Wait for bytes to clear
        wait(uut.fifo_empty && !uut.uart_busy);
        
        // 4. Test Burst mode (Pushing while it's sending)
        $display("--- Starting Test: Burst Write ---");
        push_byte(8'h11);
        push_byte(8'h22);
        push_byte(8'h33);
        push_byte(8'h44);

        // Wait for everything to finish
        wait(uut.fifo_empty && !uut.uart_busy);
        repeat(2000) @(posedge clk);

        $display("--- Testbench Completed ---");
        $finish;
    end

endmodule