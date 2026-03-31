module uart_tx
#(
    parameter clk_frequency = 50000000;
    parameter baud_rate = 9600 ;)
(
    input wire clk,
    input wire reset,
    input reg [7:0] data_in,
    input data_valid,
    output reg tx,
    output reg busy
);
localparam BAUD_TICK = clk_frequency/baud_rate;

reg [15:0] baud_counter;
reg baud_tick;

localparam [1:0]
    IDLE = 2'b00;
    START = 2'b01;
    TX = 2'b10;
    DONE = 2'b11;

reg [1:0] state = IDLE;
reg [7:0] shift_reg;//for PISO
reg [2:0] bit_count;


always @(posedge clk) begin
    if (reset) begin
        baud_counter <= 0;
        baud_tick <= 1;
        state <= IDLE;
        busy <= 0;
    end else begin
        if (baud_counter == BAUD_TICK-1) begin
            baud_counter <= 0;
            baud_tick <= 1;
            end
        else begin
            baud_counter <= baud_counter + 1;
            baud_tick <= 0;
            end
        end
    
    case(state)
        IDLE:begin
            busy <= 0;
            if (data_valid) begin
                state <= START;
                busy <= 0;
                shift_reg <= data_in;
                end
            end
        START:begin
            busy <= 1;
            bit_count <= 0;
            state <= TX;
            end
        TX:begin
            tx <= shift_reg[0];
            if (bit_count == 7) begin
                state <= DONE;
            end
            else begin
                shift_reg <= shift_reg >> 1;
                bit_count <= bit_count + 1;
            end
        end
        DONE:begin
            state <= IDLE;
            busy <= 0;
        end
    endcase
    end
endmodule

module fifo_tx #
(   parameter reg_size = 256;//bytes
)(  input wire clk,
    input reg [reg_size : 0] input_register,
    input reg [7:0] data_length,
    output reg [7:0] data_tx,
    output wire busy)

    reg reset_uart;
    reg [7:0] data_in;
    reg data_valid;
    
    uart_tx tx_inst(
        .clk(clk),
        .reset(reset_uart),
        .data_in(data_in),
        .data_valid(data_valid),
        .tx(tx),
        .busy(uart_busy)
    );
endmodule