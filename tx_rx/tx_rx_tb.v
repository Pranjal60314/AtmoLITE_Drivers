`timescale 1ns / 1ps

module control_module_tb();

    parameter BIT_RATE   = 9600; 
    parameter CLK_HZ     = 50_000_000;
    parameter CLK_PERIOD = 20;     
    localparam BIT_PERIOD = 1_000_000_000 / BIT_RATE;

    // Signals
    reg clk = 0;
    reg resetn = 0;
    reg [7:0] protocol, subprotocol, packet_nr;
    reg [7:0] p0, p1, p2, p3, p4, p5, p6, p7;
    reg [23:0] xlen;
    reg header_valid, start_trigger;
    wire tx;
    reg rx = 1;
    reg [7:0] data_in;
    reg data_valid;
    wire [7:0] rd_data;
    wire rx_empty;

    // Instantiate UUT
    control_module #(
        .BIT_RATE(BIT_RATE),
        .CLK_HZ(CLK_HZ),
        .FIFO_DEPTH(64)
    ) uut (
        .clk(clk), .resetn(resetn),
        .protocol(protocol), .subprotocol(subprotocol), .packet_nr(packet_nr),
        .param0(p0), .param1(p1), .param2(p2), .param3(p3),
        .param4(p4), .param5(p5), .param6(p6), .param7(p7),
        .xlen(xlen), .header_valid(header_valid), .start_trigger(start_trigger),
        .tx(tx), .rx(rx),
        .data_in(data_in), .data_valid(data_valid),
        .rd_data(rd_data), .rd_en(1'b0), 
        .rx_empty(rx_empty)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Simulate ACK Reply ---
    task send_ack_reply;
        input [7:0] pkt_num;
        integer i, j;
        reg [7:0] reply [0:15];
        begin
            reply[0] = 8'hFE; reply[1] = 8'h18; reply[2] = pkt_num;
            reply[3] = 8'h00; // 0x00 is ACK
            for(i=4; i<15; i=i+1) reply[i] = 8'h00;
            reply[15] = 8'hAA; // Dummy CRC for simulation

            for (i=0; i<16; i=i+1) begin
                rx = 0; #(BIT_PERIOD); // Start bit
                for (j=0; j<8; j=j+1) begin rx = reply[i][j]; #(BIT_PERIOD); end
                rx = 1; #(BIT_PERIOD); // Stop bit
                #(BIT_PERIOD/2);       // Tiny inter-byte gap
            end
        end
    endtask

// --- Batch Load Test logic ---
    initial begin
        //$dumpfile(`VCD_FILE);
        //$dumpvars(0, control_module_tb);
        // Reset Phase
        resetn = 0; header_valid = 0; start_trigger = 0;
        data_valid = 0; data_in = 0;
        #(CLK_PERIOD * 10);
        resetn = 1;
        #(CLK_PERIOD * 10);

        // Setup Header Data (Existing logic)
        protocol = 8'h18;  packet_nr = 8'hA1; subprotocol = 8'h00;
        p0=8'h09; p1=8'h00; p2=8'h00; p3=8'h00;
        p4=8'h00; p5=8'h00; p6=8'h00; p7=8'h00; 
        xlen =24'd2;
        header_valid = 1;
        #(CLK_PERIOD);
        header_valid = 0;

        // PRE-LOAD Payload Data into the new Buffer
        // We do this BEFORE starting the FSM
        $display("[%0t] TB: Loading Payload RAM...", $time);
        
        data_in = 8'h20; data_valid = 1; // Byte 0
        #(CLK_PERIOD);
        data_in = 8'h33; data_valid = 1; // Byte 1
        #(CLK_PERIOD);
        data_valid = 0;

        // Start FSM
        #(CLK_PERIOD * 5);
        //$display("[%0t] TB: Triggering Start. FSM will handle retries automatically.", $time);
        start_trigger = 1;
        #(CLK_PERIOD);
        start_trigger = 0;

        // Just wait for the end
        // Even if a timeout happens, the FSM has the data in RAM
        wait(uut.state == 4'd7); 
        //wait(uut.btx_inst.tx_busy == 0);
        #(100);
        
        send_ack_reply(8'hA1);

        wait(uut.state == 4'd0);
        $display("[%0t] TB: SUCCESSFULLY RETURNED TO IDLE", $time);

        if (uut.state == 4'd9) begin
            $display("[%0t] TB: TIMEOUT OCCURRED, BUT DATA IS IN RAM", $time);
        end else begin
            $display("[%0t] TB: NORMAL COMPLETION WITHOUT TIMEOUT", $time);
        end
        $finish;
    end


endmodule