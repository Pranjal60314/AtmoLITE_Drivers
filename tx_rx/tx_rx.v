module top_system_controller #(
        parameter BIT_RATE   = 9600,
        parameter CLK_HZ     = 50_000_000,
        parameter FIFO_DEPTH = 32,
        parameter DATA_LEN   = 256
    )(
        input  wire        clk,
        input  wire        resetn,
        input  wire        start_trigger,  // Signal to begin transmission

        //Header Fields
        input wire [7:0] protocol, subprotocol, packet_nr,
        input wire [7:0] param0, param1, param2, param3, 
        input wire [7:0] param4, param5, param6, param7,
        input wire [23:0] data_length,
        input wire data_en;
        
        // Physical UART Pins
        output wire        uart_txd,
        input  wire        uart_rxd,
        
        output wire        system_busy,
        output wire        fifo_tx_full
    );
        //internal data storage
        reg 

        // --- Internal Interconnects ---
        reg  [7:0]  master_data_bus;    // The "T-Junction" bus
        reg         master_wr_en;       // The "Pulse" for both FIFO and CRC
        
        wire [7:0]  hdr_dout;
        reg  [3:0]  hdr_index;
        
        wire [7:0]  crc_result;
        reg         crc_reset;
        
        reg  [7:0]  data_addr;
        wire [7:0]  user_data_out;      // From your data storage/RAM
        
        // --- 1. Header Provider (Passive) ---
        hdr #(.logical_address(8'hFE)) header_inst (
            .index(hdr_index),
            .protocol(protocol), .subprotocol(subprotocol), .packet_nr(packet_nr),
            .param0(param0), .param1(param1), .param2(param2), .param3(param3),
            .param4(param4), .param5(param5), .param6(param6), .param7(param7),
            .data_length(data_length),
            .dout(hdr_dout)
        );

        // --- 2. Streaming CRC Engine ---
        crc8_generator crc_inst (
            .clk(clk),
            .reset(crc_reset),
            .data_in(master_data_bus),
            .data_valid(master_wr_en),  // Calculates ONLY when we write to FIFO
            .crc_out(crc_result)
        );

        // --- 3. Buffered UART Transmitter ---
        buffered_uart_tx #(
            .BIT_RATE(BIT_RATE), .CLK_HZ(CLK_HZ), .FIFO_DEPTH(FIFO_DEPTH)
        ) uart_tx_block (
            .clk(clk),
            .resetn(resetn),
            .tx_en(1'b1),
            .wr_data(master_data_bus),
            .wr_en(master_wr_en),
            .fifo_full(fifo_tx_full),
            .uart_txd(uart_txd),
            .uart_busy(system_busy)
        );

        // --- 4. The Master State Machine ---
        localparam IDLE      = 3'd0;
        localparam SEND_HDR  = 3'd1;
        localparam PUSH_CRC  = 3'd2;
        localparam SEND_BODY = 3'd3;
        localparam DONE      = 3'd4;

        reg [2:0] state;
        reg [8:0] body_counter;

        always @(posedge clk) begin
            if (!resetn) begin
                state        <= IDLE;
                master_wr_en <= 0;
                crc_reset    <= 1;
                hdr_index    <= 0;
                data_addr    <= 0;
                body_counter <= 0;
            end else begin
                case (state)
                    IDLE: begin
                        master_wr_en <= 0;
                        crc_reset    <= 1;
                        hdr_index    <= 0;
                        data_addr    <= 0;
                        body_counter <= 0;
                        if (start_trigger) state <= SEND_HDR;
                    end

                    SEND_HDR: begin
                        crc_reset <= 0; // Start the math
                        if (!fifo_tx_full) begin
                            master_data_bus <= hdr_dout;
                            master_wr_en    <= 1;
                            if (hdr_index == 14) begin
                                state <= PUSH_CRC;
                            end else begin
                                hdr_index <= hdr_index + 1;
                            end
                        end else master_wr_en <= 0;
                    end

                    PUSH_CRC: begin
                        if (!fifo_tx_full) begin
                            master_data_bus <= crc_result;
                            master_wr_en    <= 1;
                            state           <= SEND_BODY;
                        end else master_wr_en <= 0;
                    end

                    SEND_BODY: begin
                        // Note: Here you would ideally reset CRC if the body 
                        // needs its own separate checksum.
                        if (!fifo_tx_full) begin
                            master_data_bus <= user_data_out; // From your 256-byte source
                            master_wr_en    <= 1;
                            data_addr       <= data_addr + 1;
                            if (body_counter == (DATA_LEN - 1)) begin
                                state <= DONE;
                            end else begin
                                body_counter <= body_counter + 1;
                            end
                        end else master_wr_en <= 0;
                    end

                    DONE: begin
                        master_wr_en <= 0;
                        state <= IDLE;
                    end
                    
                    default: state <= IDLE;
                endcase
            end
        end

    endmodule

module hdr #(
    parameter [7:0] logical_address = 8'hfe
) ( 
    input wire [3:0] index,          // The "Selector" from the Command Module
    
    // Header Fields
    input wire [7:0] protocol, subprotocol, packet_nr,
    input wire [7:0] param0, param1, param2, param3, 
    input wire [7:0] param4, param5, param6, param7,
    input wire [23:0] data_length,       // CRC comes from a separate calculator

    output reg [7:0] dout            // The specific byte requested
);

    always @(*) begin
        case(index)
            4'd0:  dout = logical_address;
            4'd1:  dout = protocol;
            4'd2:  dout = subprotocol;
            4'd3:  dout = packet_nr;
            4'd4:  dout = param0;
            4'd5:  dout = param1;
            4'd6:  dout = param2;
            4'd7:  dout = param3;
            4'd8:  dout = param4;
            4'd9:  dout = param5;
            4'd10: dout = param6;
            4'd11: dout = param7;
            4'd12: dout = data_length[7:0];
            4'd13: dout = data_length[15:8];
            4'd14: dout = data_length[23:16];
            default: dout = 8'h00;
        endcase
    end

endmodule

module crc8_generator (
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  data_in,
    input  wire        data_valid,
    output reg  [7:0]  crc_out
    );

    reg [7:0] crc_reg;
    reg [7:0] CRC_TABLE [0:255];

    wire [7:0] next_crc = CRC_TABLE[crc_reg ^ data_in];

    initial begin
    $readmemh("crc_table.hex", CRC_TABLE);
    $display("CRC_TABLE LOADED");
    //$writememh("debug_table.txt", CRC_TABLE);
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            crc_reg <= 8'h00;
            crc_out <= 8'h00;
        end 
        else if (data_valid) begin
            crc_reg <= next_crc;
            crc_out <= next_crc;
            //$display() 
        end
    end
    endmodule

module buffered_uart_tx #(
        parameter BIT_RATE = 9600,//BAUD RATE = 115200
        parameter CLK_HZ   = 50000000,
        parameter FIFO_DEPTH = 32
    )(
        input wire clk,
        input wire resetn,

        input wire tx_en,//enables transmit must be used carefully cuz it stops transmission
        
        input  wire [7:0] wr_data,
        input  wire wr_en,
        output wire fifo_full,
        
        // Physical Line
        output wire uart_txd,
        output wire uart_busy// UART is transmitting
    );

        wire [7:0] fifo_dout;
        wire fifo_empty;
        reg fifo_rd_en;
        reg uart_en;

        fifo #(.DEPTH(FIFO_DEPTH), .WIDTH(8)) tx_buffer (
            .clk(clk),
            .rst(!resetn),
            .wr_en(wr_en),
            .rd_en(fifo_rd_en),
            .din(wr_data),
            .dout(fifo_dout),
            .full(fifo_full),
            .empty(fifo_empty)
        );

        uart_tx #(
            .BIT_RATE(BIT_RATE),
            .CLK_HZ(CLK_HZ)
        ) physical_tx (
            .clk(clk),
            .resetn(resetn),
            .uart_txd(uart_txd),
            .uart_tx_busy(uart_busy),
            .uart_tx_en(uart_en),
            .uart_tx_data(fifo_dout)
        );

        always @(posedge clk) begin
            if (!resetn) begin
                fifo_rd_en <= 0;
                uart_en    <= 0;
            end else begin
                if (tx_en && !fifo_empty && !uart_busy && !uart_en) begin
                    fifo_rd_en <= 1;
                    uart_en    <= 1;
                end else begin
                    fifo_rd_en <= 0;
                    uart_en    <= 0;
                end
            end
        end


    endmodule

module buffered_uart_rx #(
        parameter BIT_RATE = 9600,
        parameter CLK_HZ   = 50000000,
        parameter FIFO_DEPTH = 32
    )(
        input  wire       clk,
        input  wire       resetn,

        input  wire       uart_rxd,
        input  wire       uart_rx_en,

        output wire [7:0] rd_data,     // Data out from FIFO
        input  wire       rd_en,       // System pulses this to "pop" a byte
        output wire       fifo_empty,  // High if no data is available
        output wire       fifo_full,   // High if buffer is overflowing
        output wire       rx_break     // BREAK condition detected
    );

        wire [7:0] raw_rx_data;
        wire       raw_rx_valid;

        uart_rx #(
            .BIT_RATE(BIT_RATE),
            .CLK_HZ(CLK_HZ)
        ) physical_rx (
            .clk(clk),
            .resetn(resetn),
            .uart_rxd(uart_rxd),
            .uart_rx_en(uart_rx_en),
            .uart_rx_break(rx_break),
            .uart_rx_valid(raw_rx_valid),
            .uart_rx_data(raw_rx_data)
        );

        fifo #(.DEPTH(FIFO_DEPTH), .WIDTH(8)) rx_buffer (
            .clk(clk),
            .rst(!resetn),          
            .wr_en(raw_rx_valid),   
            .rd_en(rd_en),          
            .din(raw_rx_data),
            .dout(rd_data),
            .full(fifo_full),
            .empty(fifo_empty)
        );

    endmodule

module fifo #(
        parameter DEPTH = 32,
        parameter WIDTH = 8
    )(
        input wire clk,
        input wire rst,

        input wire wr_en,
        input wire rd_en,
        input wire [WIDTH-1:0] din,

        output reg [WIDTH-1:0] dout,
        output wire full,
        output wire empty
    );
        reg [WIDTH-1:0] mem [0:DEPTH-1];
        reg [$clog2(DEPTH):0] wr_ptr, rd_ptr;

        assign empty = (wr_ptr == rd_ptr);
        assign full  = (wr_ptr - rd_ptr == DEPTH);

        always @(posedge clk) begin
            if (rst) begin
                wr_ptr <= 0;
                rd_ptr <= 0;
            end else begin
                // write
                if (wr_en && !full) begin
                    mem[wr_ptr[$clog2(DEPTH)-1:0]] <= din;
                    wr_ptr <= wr_ptr + 1;
                end

                // read
                if (rd_en && !empty) begin
                    dout <= mem[rd_ptr[$clog2(DEPTH)-1:0]];
                    rd_ptr <= rd_ptr + 1;
                end
            end
        end

    endmodule



    // 
    // Module: uart_rx 
    // 
    // Notes:
    // - UART reciever module.
    //

module uart_rx
    #(
        parameter   BIT_RATE        = 9600, // bits / sec
        parameter   CLK_HZ          = 50_000_000,
        parameter   PAYLOAD_BITS    = 8,
        parameter   STOP_BITS       = 1
    )(
    input  wire       clk          , // Top level system clock input.
    input  wire       resetn       , // Asynchronous active low reset.
    input  wire       uart_rxd     , // UART Recieve pin.
    input  wire       uart_rx_en   , // Recieve enable
    output wire       uart_rx_break, // Did we get a BREAK message?
    output wire       uart_rx_valid, // Valid data recieved and available.
    output reg  [PAYLOAD_BITS-1:0] uart_rx_data   // The recieved data.
    );

    // --------------------------------------------------------------------------- 
    // External parameters.
    // 

    //
    // Input bit rate of the UART line.
    //parameter   BIT_RATE        = 9600; // bits / sec
    localparam  BIT_P           = 1_000_000_000 * 1/BIT_RATE; // nanoseconds

    //
    // Clock frequency in hertz.
    //parameter   CLK_HZ          =    50_000_000;
    localparam  CLK_P           = 1_000_000_000 * 1/CLK_HZ; // nanoseconds

    //
    // Number of data bits recieved per UART packet.
    //parameter   PAYLOAD_BITS    = 8;

    //
    // Number of stop bits indicating the end of a packet.
    //parameter   STOP_BITS       = 1;

    // -------------------------------------------------------------------------- 
    // Internal parameters.
    // 

    //
    // Number of clock cycles per uart bit.
    localparam       CYCLES_PER_BIT     = BIT_P / CLK_P;

    //
    // Size of the registers which store sample counts and bit durations.
    localparam       COUNT_REG_LEN      = 1+$clog2(CYCLES_PER_BIT);

    // -------------------------------------------------------------------------- 
    // Internal registers.
    // 

    //
    // Internally latched value of the uart_rxd line. Helps break long timing
    // paths from input pins into the logic.
    reg rxd_reg;
    reg rxd_reg_0;

    //
    // Storage for the recieved serial data.
    reg [PAYLOAD_BITS-1:0] recieved_data;

    //
    // Counter for the number of cycles over a packet bit.
    reg [COUNT_REG_LEN-1:0] cycle_counter;

    //
    // Counter for the number of recieved bits of the packet.
    reg [3:0] bit_counter;

    //
    // Sample of the UART input line whenever we are in the middle of a bit frame.
    reg bit_sample;

    //
    // Current and next states of the internal FSM.
    reg [2:0] fsm_state;
    reg [2:0] n_fsm_state;

    localparam FSM_IDLE = 0;
    localparam FSM_START= 1;
    localparam FSM_RECV = 2;
    localparam FSM_STOP = 3;

    // --------------------------------------------------------------------------- 
    // Output assignment
    // 

    assign uart_rx_break = uart_rx_valid && ~|recieved_data;
    assign uart_rx_valid = fsm_state == FSM_STOP && n_fsm_state == FSM_IDLE;

    always @(posedge clk) begin
        if(!resetn) begin
            uart_rx_data  <= {PAYLOAD_BITS{1'b0}};
        end else if (fsm_state == FSM_STOP) begin
            uart_rx_data  <= recieved_data;
        end
    end

    // --------------------------------------------------------------------------- 
    // FSM next state selection.
    // 

    wire next_bit     = cycle_counter == CYCLES_PER_BIT ||
                            fsm_state       == FSM_STOP && 
                            cycle_counter   == CYCLES_PER_BIT/2;
    wire payload_done = bit_counter   == PAYLOAD_BITS  ;

    //
    // Handle picking the next state.
    always @(*) begin : p_n_fsm_state
        case(fsm_state)
            FSM_IDLE : n_fsm_state = rxd_reg      ? FSM_IDLE : FSM_START;
            FSM_START: n_fsm_state = next_bit     ? FSM_RECV : FSM_START;
            FSM_RECV : n_fsm_state = payload_done ? FSM_STOP : FSM_RECV ;
            FSM_STOP : n_fsm_state = next_bit     ? FSM_IDLE : FSM_STOP ;
            default  : n_fsm_state = FSM_IDLE;
        endcase
    end

    // --------------------------------------------------------------------------- 
    // Internal register setting and re-setting.
    // 

    //
    // Handle updates to the recieved data register.
    integer i = 0;
    always @(posedge clk) begin : p_recieved_data
        if(!resetn) begin
            recieved_data <= {PAYLOAD_BITS{1'b0}};
        end else if(fsm_state == FSM_IDLE             ) begin
            recieved_data <= {PAYLOAD_BITS{1'b0}};
        end else if(fsm_state == FSM_RECV && next_bit ) begin
            recieved_data[PAYLOAD_BITS-1] <= bit_sample;
            for ( i = PAYLOAD_BITS-2; i >= 0; i = i - 1) begin
                recieved_data[i] <= recieved_data[i+1];
            end
        end
    end

    //
    // Increments the bit counter when recieving.
    always @(posedge clk) begin : p_bit_counter
        if(!resetn) begin
            bit_counter <= 4'b0;
        end else if(fsm_state != FSM_RECV) begin
            bit_counter <= {COUNT_REG_LEN{1'b0}};
        end else if(fsm_state == FSM_RECV && next_bit) begin
            bit_counter <= bit_counter + 1'b1;
        end
    end

    //
    // Sample the recieved bit when in the middle of a bit frame.
    always @(posedge clk) begin : p_bit_sample
        if(!resetn) begin
            bit_sample <= 1'b0;
        end else if (cycle_counter == CYCLES_PER_BIT/2) begin
            bit_sample <= rxd_reg;
        end
    end


    //
    // Increments the cycle counter when recieving.
    always @(posedge clk) begin : p_cycle_counter
        if(!resetn) begin
            cycle_counter <= {COUNT_REG_LEN{1'b0}};
        end else if(next_bit) begin
            cycle_counter <= {COUNT_REG_LEN{1'b0}};
        end else if(fsm_state == FSM_START || 
                    fsm_state == FSM_RECV  || 
                    fsm_state == FSM_STOP   ) begin
            cycle_counter <= cycle_counter + 1'b1;
        end
    end


    //
    // Progresses the next FSM state.
    always @(posedge clk) begin : p_fsm_state
        if(!resetn) begin
            fsm_state <= FSM_IDLE;
        end else begin
            fsm_state <= n_fsm_state;
        end
    end


    //
    // Responsible for updating the internal value of the rxd_reg.
    always @(posedge clk) begin : p_rxd_reg
        if(!resetn) begin
            rxd_reg     <= 1'b1;
            rxd_reg_0   <= 1'b1;
        end else if(uart_rx_en) begin
            rxd_reg     <= rxd_reg_0;
            rxd_reg_0   <= uart_rxd;
        end
    end


    endmodule

module uart_tx
        #(
            parameter   BIT_RATE        = 9600, // bits / sec
            parameter   CLK_HZ          = 50_000_000,
            parameter   PAYLOAD_BITS    = 8,
            parameter   STOP_BITS       = 1
        )(
        input  wire         clk         , // Top level system clock input.
        input  wire         resetn      , // Asynchronous active low reset.
        output wire         uart_txd    , // UART transmit pin.
        output wire         uart_tx_busy, // Module busy sending previous item.
        input  wire         uart_tx_en  , // Send the data on uart_tx_data
        input  wire [PAYLOAD_BITS-1:0]   uart_tx_data  // The data to be sent
        );

        // Input bit rate of the UART line.
        //parameter   BIT_RATE        = 9600; // bits / sec
        localparam  BIT_P           = 1_000_000_000 * 1/BIT_RATE; // nanoseconds

        // Clock frequency in hertz.
        //parameter   CLK_HZ          =    50_000_000;
        localparam  CLK_P           = 1_000_000_000 * 1/CLK_HZ; // nanoseconds

        // Number of data bits recieved per UART packet.
        //parameter   PAYLOAD_BITS    = 8;

        // Number of stop bits indicating the end of a packet.
        //parameter   STOP_BITS       = 1;

        //
        // Number of clock cycles per uart bit.
        localparam       CYCLES_PER_BIT     = BIT_P / CLK_P;

        // Size of the registers which store sample counts and bit durations.
        localparam       COUNT_REG_LEN      = 1+$clog2(CYCLES_PER_BIT);

        // Internally latched value of the uart_txd line. Helps break long timing
        // paths from the logic to the output pins.
        reg txd_reg;

        // Storage for the serial data to be sent.
        reg [PAYLOAD_BITS-1:0] data_to_send;

        // Counter for the number of cycles over a packet bit.
        reg [COUNT_REG_LEN-1:0] cycle_counter;

        //
        // Counter for the number of sent bits of the packet.
        reg [3:0] bit_counter;

        // Current and next states of the internal FSM.
        reg [2:0] fsm_state;
        reg [2:0] n_fsm_state;

        localparam FSM_IDLE = 0;
        localparam FSM_START= 1;
        localparam FSM_SEND = 2;
        localparam FSM_STOP = 3;

        assign uart_tx_busy = fsm_state != FSM_IDLE;
        assign uart_txd     = txd_reg;

        wire next_bit     = cycle_counter == CYCLES_PER_BIT;
        wire payload_done = bit_counter   == PAYLOAD_BITS  ;
        wire stop_done    = bit_counter   == STOP_BITS && fsm_state == FSM_STOP;

        // Handle picking the next state.
        always @(*) begin : p_n_fsm_state
            case(fsm_state)
                FSM_IDLE : n_fsm_state = uart_tx_en   ? FSM_START: FSM_IDLE ;
                FSM_START: n_fsm_state = next_bit     ? FSM_SEND : FSM_START;
                FSM_SEND : n_fsm_state = payload_done ? FSM_STOP : FSM_SEND ;
                FSM_STOP : n_fsm_state = stop_done    ? FSM_IDLE : FSM_STOP ;
                default  : n_fsm_state = FSM_IDLE;
            endcase
        end

        // Handle updates to the sent data register.
        integer i = 0;
        always @(posedge clk) begin : p_data_to_send
            if(!resetn) begin
                data_to_send <= {PAYLOAD_BITS{1'b0}};
            end else if(fsm_state == FSM_IDLE && uart_tx_en) begin
                data_to_send <= uart_tx_data;
            end else if(fsm_state       == FSM_SEND       && next_bit ) begin
                for ( i = PAYLOAD_BITS-2; i >= 0; i = i - 1) begin
                    data_to_send[i] <= data_to_send[i+1];
                end
            end
        end

        // Increments the bit counter each time a new bit frame is sent.
        always @(posedge clk) begin : p_bit_counter
            if(!resetn) begin
                bit_counter <= 4'b0;
            end else if(fsm_state != FSM_SEND && fsm_state != FSM_STOP) begin
                bit_counter <= {COUNT_REG_LEN{1'b0}};
            end else if(fsm_state == FSM_SEND && n_fsm_state == FSM_STOP) begin
                bit_counter <= {COUNT_REG_LEN{1'b0}};
            end else if(fsm_state == FSM_STOP&& next_bit) begin
                bit_counter <= bit_counter + 1'b1;
            end else if(fsm_state == FSM_SEND && next_bit) begin
                bit_counter <= bit_counter + 1'b1;
            end
        end

        // Increments the cycle counter when sending.
        always @(posedge clk) begin : p_cycle_counter
            if(!resetn) begin
                cycle_counter <= {COUNT_REG_LEN{1'b0}};
            end else if(next_bit) begin
                cycle_counter <= {COUNT_REG_LEN{1'b0}};
            end else if(fsm_state == FSM_START || 
                        fsm_state == FSM_SEND  || 
                        fsm_state == FSM_STOP   ) begin
                cycle_counter <= cycle_counter + 1'b1;
            end
        end

        // Progresses the next FSM state.
        always @(posedge clk) begin : p_fsm_state
            if(!resetn) begin
                fsm_state <= FSM_IDLE;
            end else begin
                fsm_state <= n_fsm_state;
            end
        end

        // Responsible for updating the internal value of the txd_reg.
        always @(posedge clk) begin : p_txd_reg
            if(!resetn) begin
                txd_reg <= 1'b1;
            end else if(fsm_state == FSM_IDLE) begin
                txd_reg <= 1'b1;
            end else if(fsm_state == FSM_START) begin
                txd_reg <= 1'b0;
            end else if(fsm_state == FSM_SEND) begin
                txd_reg <= data_to_send[0];
            end else if(fsm_state == FSM_STOP) begin
                txd_reg <= 1'b1;
            end
        end

        endmodule

