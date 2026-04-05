`timescale 1ns / 1ps

module control_module #(
    parameter BIT_RATE   = 9600,
    parameter CLK_HZ     = 50_000_000,
    parameter FIFO_DEPTH = 64
)(
    input wire clk,
    input wire resetn,

    // Header Inputs (to be latched)
    input wire [7:0]  protocol, subprotocol, packet_nr,
    input wire [7:0]  param0, param1, param2, param3, param4, param5, param6, param7,
    input wire [23:0] xlen,
    input wire        header_valid,
    input wire        start_trigger, 

    // Physical UART Pins
    output wire       tx,
    input  wire       rx,

    // Data Source (Internal Interface)
    input wire [7:0]  data_in,
    input wire        data_valid,

    // Response Interface (to upper layer)
    output wire [7:0] rd_data,     // Data from RX FIFO
    input  wire       rd_en,       // Read pulse for RX FIFO
    output wire       rx_empty     // RX FIFO status
);

    // --- State Definitions ---
    localparam IDLE           = 4'd0;
    localparam SEND_HDR       = 4'd1;
    localparam SEND_HDR_CRC   = 4'd2;
    localparam WAIT_CRC       = 4'd3;
    localparam SEND_DATA      = 4'd4;
    localparam SEND_DATA_CRC  = 4'd5;
    localparam RESET_CRC      = 4'd6;
    localparam WAIT_REPLY     = 4'd7;
    localparam COLLECT_BYTE   = 4'd8;
    localparam STORE_BYTE     = 4'd9;
    localparam CALC_CRC       = 4'd10;
    localparam VALIDATE_PACKET= 4'd11;
    localparam RETRY_GAP      = 4'd12;
    localparam ERROR_FATAL    = 4'd13;

    // --- Timing Constants ---
    localparam TIMEOUT_VAL = CLK_HZ/20; // 50ms
    localparam GAP_VAL     = CLK_HZ/1000; // 100ms

    // --- Internal Registers/Signals ---
    reg [3:0]  state;
    reg [31:0] timer;
    reg [2:0]  retries;
    reg [3:0]  hdr_idx;
    reg [23:0] data_cnt;
    reg [3:0]  rx_cnt;
    reg  hdr_sent;
    reg  data_sent;
    reg [7:0] rx_packet_buffer [0:15];


    // Connections to Sub-modules
    reg  tx_wr_en;
    reg  [7:0] tx_wr_data;
    wire tx_fifo_full;
    wire tx_busy;
    
    wire [7:0] hdr_dout;
    
    reg  reset_crc;
    reg  [7:0] crc_data_in;
    reg  crc_data_en;
    wire [7:0] crc_out;

    reg  rx_fifo_rd_en;
    wire [7:0] rx_fifo_data;
    wire rx_fifo_empty;

    wire [7:0] payload_dout;
    reg [7:0] payload_wr_ptr; 

    reg [7:0] response_buffer [4:14];
    reg       resp_valid_pulse;

    reg        rx_crc_en;
    reg        rx_crc_reset;
    reg  [7:0] rx_crc_data_in;
    wire [7:0] rx_crc_out;
    // --- Instantiations ---

    // 1. Header Snapshot/Mux
    hdr #(.logical_address(8'hFE)) hdr_inst (
        .clk(clk), .resetn(resetn),
        .protocol(protocol), .subprotocol(subprotocol), .packet_nr(packet_nr),
        .param0(param0), .param1(param1), .param2(param2), .param3(param3),
        .param4(param4), .param5(param5), .param6(param6), .param7(param7),
        .xlen(xlen), .header_valid(header_valid),
        .dout_index(hdr_idx), .dout(hdr_dout)
    );

    // 2. Transmit Buffer
    buffered_uart_tx #(.BIT_RATE(BIT_RATE), .CLK_HZ(CLK_HZ), .FIFO_DEPTH(FIFO_DEPTH)) btx_inst (
        .clk(clk), .resetn(resetn), .tx_en(1'b1),
        .wr_data(tx_wr_data), .wr_en(tx_wr_en), .fifo_full(tx_fifo_full),
        .uart_txd(tx), .tx_busy(tx_busy)
    );

    // 3. CRC Generator
    crc8_generator crc8_inst (
        .clk(clk), .reset(reset_crc),
        .data_in(crc_data_in), .data_valid(crc_data_en), .crc_out(crc_out)
    );

    // 4. Receive Buffer
    buffered_uart_rx #(.BIT_RATE(BIT_RATE), .CLK_HZ(CLK_HZ), .FIFO_DEPTH(FIFO_DEPTH)) rx_inst (
        .clk(clk), .resetn(resetn), .uart_rxd(rx), .uart_rx_en(1'b1),
        .rd_data(rx_fifo_data), .rd_en(rx_fifo_rd_en), .fifo_empty(rx_fifo_empty)
    );

    //5. Payload Buffer
    payload_buffer #(.MAX_LEN(256)) data_buf_inst (
        .clk(clk),
        // External Write Port (Loading the buffer)
        .wr_addr(payload_wr_ptr),
        .wr_data(data_in),
        .wr_en(data_valid),
        
        // Internal Read Port (Used by FSM)
        .rd_addr(data_cnt[7:0]), // data_cnt is our index
        .rd_data(payload_dout)
    );

    // Instantiate the RX CRC Unit
    crc8_generator rx_crc_inst (
        .clk(clk), 
        .reset(rx_crc_reset),
        .data_in(rx_crc_data_in), 
        .data_valid(rx_crc_en), 
        .crc_out(rx_crc_out)
    );


            
// --- Main Control FSM ---
    always @(posedge clk) begin

        if (!resetn || header_valid) 
            payload_wr_ptr <= 0;
        else if (data_valid) 
            payload_wr_ptr <= payload_wr_ptr + 1;//reset pointer on new header, increment on each valid data input

        if (!resetn) begin
            state <= IDLE;
            timer <= 0;
            retries <= 0;
            hdr_idx <= 0;
            data_cnt <= 0;
            tx_wr_en <= 0;
            crc_data_en <= 0;
            reset_crc <= 1;
            rx_fifo_rd_en <= 0;
            rx_cnt <= 0;
            hdr_sent <= 0;
            data_sent <= 0;
            resp_valid_pulse <= 0;
        end else begin
            tx_wr_en <= 0;
            crc_data_en <= 0;
            rx_fifo_rd_en <= 0;

            case (state)
                IDLE: begin
                    timer <= 0;
                    hdr_idx <= 0;
                    data_cnt <= 0;
                    rx_cnt <= 0;
                    reset_crc <= 1;
                    rx_crc_en <= 0;
                    rx_crc_reset <= 1;
                    hdr_sent <= 0;
                    data_sent <= 0;
                    $display("STATE: IDLE initialising HDR SEND");
                    if (start_trigger) begin
                        state <= SEND_HDR;
                        
                    end
                end

               SEND_HDR: begin
                reset_crc <= 0;
                    if (!tx_fifo_full) begin
                        tx_wr_data <= hdr_dout;
                        tx_wr_en   <= 1;
                        crc_data_in<= hdr_dout;
                        crc_data_en <= 1;
                        $display("DATA: 0x%h | CRC: 0x%h", uut.tx_wr_data , uut.crc_out);
                        if (hdr_idx == 4'd14) begin
                            state <= WAIT_CRC;
                            hdr_sent <= 1;
                        end
                        else hdr_idx <= hdr_idx + 1;
                    end
                end

                WAIT_CRC:begin
                    $display("WAITING FOR CRC COMPUTATION");
                    if (hdr_sent) state <= SEND_HDR_CRC;
                    if (data_sent) state <= SEND_DATA_CRC; // If no header, move to data phase
                end

                SEND_HDR_CRC: begin
                    if (!tx_fifo_full) begin
                        $display("FINAL HDR CRC: 0x%h", uut.crc_out );
                        tx_wr_data <= crc_out; // Send Byte 15
                        tx_wr_en   <= 1;
                        state      <= RESET_CRC;
                        
                    end
                    hdr_sent <= 0;
                end

                RESET_CRC:begin
                    $display("Reset CRC");
                    reset_crc <= 1;
                    state <= (xlen == 0) ? WAIT_REPLY : SEND_DATA;

                end

                SEND_DATA: begin
                        reset_crc <= 0;
                        if (!tx_fifo_full) begin
                            tx_wr_data  <= payload_dout; // From the new buffer
                            tx_wr_en    <= 1;
                            crc_data_in <= payload_dout;
                            crc_data_en <= 1;
                            $display("LOADING DATA BYTES: 0x%h |DATA_CNT: %d", uut.tx_wr_data, uut.data_cnt);
                            
                            if (data_cnt == (xlen - 1)) begin
                                state <= WAIT_CRC;
                                data_sent <= 1;
                            end
                            else  data_cnt <= data_cnt + 1; // data_cnt acts as the rd_addr
                        end
                    end

                SEND_DATA_CRC: begin
                    if (!tx_fifo_full) begin
                        tx_wr_data <= crc_out; // Send the Data CRC byte
                        tx_wr_en   <= 1;
                        state      <= WAIT_REPLY;
                        timer      <= 0;
                        $display("LOADING CRC BYTE: 0x%h",uut.crc_out);
                        
                    end
                    data_sent <= 0;
                end

                WAIT_REPLY: begin
                    rx_crc_en <= 0;
                    rx_crc_reset <= 0;
                    timer <= timer + 1;
                    if (timer%100000 == 0) begin
                        $display("WAITING FOR BYTES | TIMER: %d", uut.timer);
                    end
                    if (timer >= TIMEOUT_VAL) state <= RETRY_GAP;
                    
                    else if (!rx_fifo_empty) begin
                        rx_fifo_rd_en <= 1;
                        state <= COLLECT_BYTE;
                    end
                end

                COLLECT_BYTE: begin
                    $display("DATA COLLECTED: 0X%h", uut.rx_fifo_data);
                    rx_crc_en <= 0;
                    rx_fifo_rd_en <= 0;
                    state <= STORE_BYTE; 
                end

                STORE_BYTE: begin
                    $display("STORING BYTE: 0x%h", uut.rx_fifo_data);
                    rx_packet_buffer[rx_cnt] <= rx_fifo_data;
                    if (rx_cnt == 4'd15) begin
                        state <= CALC_CRC;
                        rx_cnt <= 0;
                    end else begin
                        rx_cnt <= rx_cnt + 1;
                        state  <= WAIT_REPLY;
                    end
                end

                CALC_CRC: begin
                    if (rx_cnt < 4'd15) begin
                        $display("CRC for RECEIVED DATA: 0x%h", uut.rx_crc_out);
                        rx_crc_data_in <= rx_packet_buffer[rx_cnt];
                        rx_crc_en      <= 1;
                        rx_cnt         <= rx_cnt + 1;
                        state          <= CALC_CRC;
                    end else begin
                        rx_crc_en      <= 0;
                        state          <= VALIDATE_PACKET;
                    end
                end

                VALIDATE_PACKET: begin
                    if (rx_packet_buffer[0] != 8'hFE)begin
                        state <= RETRY_GAP;
                        $display("HEADER MISMATCH");
                    end    
                    else if (rx_packet_buffer[1] != protocol)begin  
                        state <= RETRY_GAP; 
                        $display("PROTOCOL MISMATCH");
                        end
                    else if (rx_packet_buffer[2] != packet_nr)begin 
                        state <= RETRY_GAP; 
                        $display("PACKET NUMBER WRONG");
                        end
                    else if (rx_packet_buffer[3] != 8'h00) begin    
                        state <= RETRY_GAP;
                        $display("NACK RECEIVED"); 
                        end
                    else if (rx_packet_buffer[15] != rx_crc_out) begin   
                        state <= RETRY_GAP;
                        $display("CRC DENIED");
                        $display("CRC OUT: 0x%h | CRC SENT: 0x%h", uut.rx_crc_out, uut.rx_packet_buffer[15]); 
                        end 
                    else begin
                        $display("PACKET RECEIVED AND VALIDATED");
                        $display("RAW: %h_%h_%h_%h_%h_%h_%h_%h_%h_%h_%h_%h_%h_%h_%h_%h",
                                    rx_packet_buffer[0],  rx_packet_buffer[1],  rx_packet_buffer[2],  rx_packet_buffer[3],
                                    rx_packet_buffer[4],  rx_packet_buffer[5],  rx_packet_buffer[6],  rx_packet_buffer[7],
                                    rx_packet_buffer[8],  rx_packet_buffer[9],  rx_packet_buffer[10], rx_packet_buffer[11],
                                    rx_packet_buffer[12], rx_packet_buffer[13], rx_packet_buffer[14], rx_packet_buffer[15]
                                );
                        state <= IDLE;
                        resp_valid_pulse <= 1;
                    end

                end


                RETRY_GAP: begin
                    timer <= timer + 1;
                    if (timer%100000==0) begin
                    $display("Waiting before the next command -------------------| TIME: %d",uut.timer);
                    end
                    if (timer >= GAP_VAL) begin
                        timer <= 0;
                        if (retries < 3) begin
                            retries <= retries + 1;
                            hdr_idx <= 0;
                            data_cnt <= 0;
                            state <= SEND_HDR;
                            $display("RETRYING AGAIN");
                            reset_crc <= 1;
                        end else begin
                            $display("RETRIES EXCEEDED LIMIT -- GOING INTO FATAL ERROR MODE");
                            state <= ERROR_FATAL;
                        end
                    end
                end

                ERROR_FATAL: state <= ERROR_FATAL; // Stay until reset

                default: state <= IDLE;
            endcase
        end
    end

    // Direct wiring for the external system to read from RX FIFO
    assign rd_data  = rx_fifo_data;
    assign rx_empty = rx_fifo_empty;

//     //Monitor fo rdebugging blocks
//     // --- Dynamic State Debugger ---
// always @(posedge clk) begin
//     case (uut.state)
//         4'd0: $display("[%0t] [IDLE] Waiting for start trigger...", $time);

//         4'd1, 4'd2: begin // Header Bytes + CRC
//             if (uut.tx_wr_en) 
//                 $display("[%0t] [TX-HDR] Sending Byte %0d: 0x%h %0d| CRC_Accum: 0x%h", 
//                          $time, uut.hdr_idx, uut.tx_wr_data, uut.tx_wr_en, uut.crc_out);
//         end

//         4'd4, 4'd5: begin// Data Bytes + CRC
//             if (uut.tx_wr_en)
//                 $display("[%0t] [TX-DATA] Sending Byte %0d: 0x%h %0d| CRC_Accum: 0x%h", 
//                          $time, uut.data_cnt, uut.tx_wr_data, uut.tx_wr_en, uut.crc_out);
//         end

//         4'd7: begin // Wait for Reply
//             if (!uut.rx_fifo_empty)
//                 $display("[%0t] [RX-WAIT] Data detected in FIFO! Moving to Collect...", $time);
            
//             if (uut.timer % 50000 == 0)
//                 $display("[%0t] [RX-WAIT] Still waiting... Timer: %0d", $time, uut.timer);
//         end

//         4'd9: begin // Store Byte
//             $display("[%0t] [RX-STORE] Saved Packet[%0d] = 0x%h", 
//                      $time, uut.rx_cnt, uut.rx_fifo_data);
//         end

//         4'd10: begin // CRC Calculation
//             if (uut.rx_crc_en)
//                 $display("[%0t] [CRC-CALC] Feeding Index %0d: 0x%h | Intermediate CRC: 0x%h", 
//                          $time, uut.rx_cnt, uut.rx_crc_data_in, uut.rx_crc_out);
//         end

//         4'd11: begin// Validate Packet
//             $display("[%0t] [CHECK] Received CRC: 0x%h | Calculated CRC: 0x%h", 
//                      $time, uut.rx_packet_buffer[15], uut.rx_crc_out);
//             if (uut.rx_packet_buffer[15] != uut.rx_crc_out)
//                 $display(">>> CRC ERROR DETECTED <<<");
//         end

//         4'd12: begin // Retry Gap
//             if (uut.timer == 1)
//                 $display("[%0t] [RETRY] Attempt %0d failed. Entering Gap Wait.", $time, uut.retries);
//         end
        
//         4'd13: begin // Fatal Error
//             $display("[%0t] !!! FATAL ERROR: Max retries exceeded !!!", $time);
//             $stop; 
//         end
//     endcase
// end

endmodule