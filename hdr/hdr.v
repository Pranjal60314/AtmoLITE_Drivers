module hdr #(
    parameter [7:0] logical_address = 8'hfe
) ( 
    input wire clk,
    input wire reset,
    input wire [7:0] protocol, subprotocol, packet_nr,
    input wire [7:0] param0, param1, param2, param3, param4, param5, param6, param7,
    input wire [23:0] data_length,
    output wire UART_TX
);

//UART Instantiation 
    reg reset_uart = 0;
    reg [7:0] data_in_uart;
    reg data_valid_uart = 0;
    wire uart_busy;

    uart_tx uart_inst(
        .clk(clk),
        .reset(reset_uart),
        .data_in(data_in_uart),
        .data_valid(data_valid_uart),
        .tx(UART_TX),
        .busy(uart_busy)
    );

//CRC8 instantiation
    reg reset_crc = 0;
    reg [7:0] data_in_crc;
    reg data_valid_crc = 0;
    reg [7:0] crc_out;

    initial begin
        $display("CRC_OUT -- ",crc_out);
    end

    crc8_generator crc_inst(
        .clk(clk),
        .reset(reset_crc),
        .data_in(data_in_crc),
        .data_valid(data_valid_crc),
        .crc_out(crc_out)
    );

    reg [4:0] index_uart = 0;
    reg uart_busy_prev;

always @(posedge clk) begin
    
        uart_busy_prev <= uart_busy;
        if (uart_busy_prev && !uart_busy) begin//to check for the negative edge of the UART line
            if (index_uart < 15) 
                index_uart <= index_uart + 1;
            else 
                index_uart <= 0;
        end
    
    // reseting the header file
        if (reset) begin
            index_uart <= 0;
            data_valid_uart <= 0;
            data_valid_crc <= 0;
            reset_crc <= 1;
            reset_uart <= 1;
        end 
        
    //posting the values in this files                                                                          //so basically I am sending the bytes in bursts  
        else begin                                                                                              //should I stream bits or  stream bytes 
            reset_crc <= 0;                                                                                     //or basically like what is UART does it stream data bytes or the whole thing in one go with a predefined byte size that is kind of makes sense
            
            reset_uart <= 0;

            if (!uart_busy && !data_valid_uart) begin
                data_valid_uart <= 1;
                
                data_valid_crc <= (index_uart < 15) ? 1 : 0; 

                case(index_uart)
                    0:  begin data_in_uart <= logical_address;    data_in_crc <= logical_address;    end
                    1:  begin data_in_uart <= protocol;           data_in_crc <= protocol;           end  
                    2:  begin data_in_uart <= subprotocol;        data_in_crc <= subprotocol;        end  
                    3:  begin data_in_uart <= packet_nr;          data_in_crc <= packet_nr;          end  
                    4:  begin data_in_uart <= param0;             data_in_crc <= param0;             end  
                    5:  begin data_in_uart <= param1;             data_in_crc <= param1;             end  
                    6:  begin data_in_uart <= param2;             data_in_crc <= param2;             end  
                    7:  begin data_in_uart <= param3;             data_in_crc <= param3;             end  
                    8:  begin data_in_uart <= param4;             data_in_crc <= param4;             end  
                    9:  begin data_in_uart <= param5;             data_in_crc <= param5;             end  
                    10: begin data_in_uart <= param6;             data_in_crc <= param6;             end  
                    11: begin data_in_uart <= param7;             data_in_crc <= param7;             end  
                    12: begin data_in_uart <= data_length[23:16]; data_in_crc <= data_length[23:16]; end  
                    13: begin data_in_uart <= data_length[15:8];  data_in_crc <= data_length[15:8];  end  
                    14: begin data_in_uart <= data_length[7:0];   data_in_crc <= data_length[7:0];   end  
                    15: begin data_in_uart <= crc_out;            data_valid_crc <= 0;               end  
                endcase
            end else begin
                data_valid_uart <= 0;
                data_valid_crc  <= 0;
            end
        end
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
