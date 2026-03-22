
module hdr_gntr #(
        parameter reg [7:0] logical_address = 8'hfe //default address of the device
    )
    ( input wire clk,//input wire rst
    
    input wire [7:0] protocol,          //Protocol Field
    input wire [7:0] subprotocol,
    input wire [7:0] packet_nr,
    input wire [7:0] param0,
        input wire [7:0] param1,
        input wire [7:0] param2,
        input wire [7:0] param3,
        input wire [7:0] param4,
        input wire [7:0] param5,
        input wire [7:0] param6,
        input wire [7:0] param7,
    input wire [23:0] data_length,
    
    output reg [7:0] header_out [127:0], //header files
    output reg [7:0] crc_out,              // **  debugging purposes, can be removed in final version   **

    output wire UART_TX
    );
    
    reg [7:0] data_in_crc;
    reg reset_crc;
    reg data_valid_crc;

    crc8_generator uut(
        .clk(clk),
        .reset(reset_crc),
        .data_in(data_in_crc),
        .data_valid(data_valid_crc),
        .crc_out(crc_out)
    );

    reg [7:0] data_in_uart;
    reg data_valid_uart = 1;
    reg reset_uart;

    uart_tx uart_inst(
        .clk(clk),
        .reset(reset_uart),
        .data_in(data_in_uart),
        .data_valid(data_valid_uart),
        .tx(UART_TX)
    );

    localparam [1:0]
        IDLE = 2'b00,
        SEND = 2'b01,
        DONE = 2'b10,
        UART_SEND = 2'b11;

    reg [1:0] state;
    reg [3:0] byte_count;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                header_out[0] <= logical_address;
                header_out[1] <= protocol;
                header_out[2] <= subprotocol;
                header_out[3] <= packet_nr;
                header_out[4] <= param0;
                header_out[5] <= param1;
                header_out[6] <= param2;
                header_out[7] <= param3;
                header_out[8] <= param4;
                header_out[9] <= param5;
                header_out[10] <= param6;
                header_out[11] <= param7;
                header_out[12] <= data_length[23:16];
                header_out[13] <= data_length[15:8];
                header_out[14] <= data_length[7:0];

                if (data_valid) begin
                    state <= SEND;
                    byte_count <= 0;
                end
            end

            SEND: begin
                data_valid_crc <= 1;
                data_in_crc <= header_out[byte_count];
                byte_count <= byte_count + 1;

                if (byte_count == 15) begin
                    data_valid_crc <= 0;
                    state <= DONE;
                end
            end

            DONE: begin
                header_out[15] <= crc_out;
                byte_count <= 0;
                state <= UART_SEND;

            end 

            UART_SEND: begin
                if (data_valid_uart) begin
                    data_in_uart <= header_out[byte_count];
                    data_valid_uart <= 0;
                    byte_count <= byte_count + 1;
                    if (byte_count == 16) begin
                        data_valid_uart <= 0;
                        state <= IDLE;
                    end
                end else begin
                    data_valid_uart <= 0;
                end
            end
            default:
                state <= IDLE;

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
        end

        always @(posedge clk or posedge reset) begin
            if (reset) begin
                crc_reg <= 8'h00;
                crc_out <= 8'h00;
            end 
            else if (data_valid) begin
                crc_reg <= next_crc;
                crc_out <= next_crc; 
            end
        end

    endmodule

module uart_tx #(
    parameter CLK_FREQ = 50000000,   // 50 MHz
    parameter BAUD_RATE = 9600
    )(
    input wire clk,
    input wire reset,
    input wire [7:0] data_in,
    input wire data_valid,
    output reg tx,
    output reg busy
    );

    localparam BAUD_TICK = CLK_FREQ / BAUD_RATE;

    reg [15:0] baud_counter = 0;
    reg baud_tick = 0;

    always @(posedge clk) begin
        if (reset) begin
            baud_counter <= 0;
            baud_tick <= 0;
        end else begin
            if (baud_counter == BAUD_TICK-1) begin
                baud_counter <= 0;
                baud_tick <= 1;
            end else begin
                baud_counter <= baud_counter + 1;
                baud_tick <= 0;
            end
        end
    end

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state = IDLE;
    reg [7:0] shift_reg;
    reg [2:0] bit_count;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            tx <= 1'b1; // idle line
            busy <= 0;
        end else if (baud_tick) begin
            case (state)

                IDLE: begin
                    tx <= 1'b1;
                    busy <= 0;
                    if (data_valid) begin
                        shift_reg <= data_in;
                        state <= START;
                        busy <= 1;
                    end
                end

                START: begin
                    tx <= 1'b0;
                    bit_count <= 0;
                    state <= DATA;
                end

                DATA: begin
                    tx <= shift_reg[0];           // LSB first
                    shift_reg <= shift_reg >> 1;
                    bit_count <= bit_count + 1;

                    if (bit_count == 7)
                        state <= STOP;
                end

                STOP: begin
                    tx <= 1'b1;
                    state <= IDLE;
                end

            endcase
        end
    end

    endmodule


