`timescale 1ns / 1ps

module uart_tx_tb();

    reg clk = 0;
    reg resetn = 0;
    reg [7:0] test_data = 8'h00;
    reg wr_en = 0;
    
    wire uart_txd;
    wire fifo_full;
    wire tx_busy;

    // Instantiate the buffered UART system
    buffered_uart_tx #(
        .BIT_RATE(115200), // Fast baud for quick simulation
        .CLK_HZ(50000000)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .wr_data(test_data),
        .wr_en(wr_en),
        .fifo_full(fifo_full),
        .uart_txd(uart_txd),
        .tx_busy(tx_busy)
    );

    // Clock generation (50MHz)
    always #10 clk = ~clk;

    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, uart_tx_tb);
        // Reset
        resetn = 0;
        #100;
        resetn = 1;
        #100;

        // --- STEP 1: Load the FIFO with 3 specific values ---
        send_byte(8'hFE); // Logical Address
        send_byte(8'h0A); // Protocol
        send_byte(8'h55); // A pattern 01010101 to see toggling

        $display("[%0t] Done loading FIFO. Waiting for UART to drain...", $time);
        
        // --- STEP 2: Wait for transmission to finish ---
        wait(tx_busy == 0);
        $display("[%0t] SUCCESS: All data sent through UART line.", $time);
        
        #2000;
        $finish;
    end

    // Task to simplify sending data to the buffer
    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            if (!fifo_full) begin
                test_data = data;
                wr_en = 1;
                $display("[%0t] WRITING TO BUFFER: 0x%h", $time, data);
                @(posedge clk);
                wr_en = 0;
            end
        end
    endtask

    // --- DIAGNOSTIC MONITOR ---
    // This block "spies" on the internal FIFO-to-UART handshaking
    always @(posedge clk) begin
        if (dut.uart_en) begin
            $display("[%0t] >>> UART STARTING BYTE: 0x%h", $time, dut.fifo_dout);
        end
    end

endmodule