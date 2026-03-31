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
                    end else begin
                        busy <= 0;
                    end
                end

                START: begin
                    tx <= 1'b0;
                    bit_count <= 0;
                    state <= DATA;
                end

                DATA: begin
                    tx <= shift_reg[0];
                    if (bit_count == 7) begin
                        state <= STOP;
                    end else begin
                        shift_reg <= shift_reg >> 1;
                        bit_count <= bit_count + 1;
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    state <= IDLE;
                end

            endcase
        end
    end

    endmodule

module uart_rx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 9600
)(
    input wire clk,
    input wire rx,
    output reg [7:0] data_out,
    output reg ready
);
    localparam TICK_COUNT = CLK_FREQ / BAUD_RATE;
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [1:0] state = IDLE;
    reg [15:0] timer = 0;
    reg [2:0] bit_idx = 0;

    always @(posedge clk) begin
    ready <= 0;

    case (state)

        IDLE: begin
            if (rx == 0) begin
                timer <= 0;
                state <= START;
            end
        end

        START: begin
            if (timer == TICK_COUNT/2) begin
                timer <= 0;
                bit_idx <= 0;
                state <= DATA;
            end else begin
                timer <= timer + 1;
            end
        end

        DATA: begin
            if (timer == TICK_COUNT - 1) begin
                timer <= 0;
                if (bit_idx == 7)
                    state <= STOP;
                else
                    bit_idx <= bit_idx + 1;
            end else begin
                timer <= timer + 1;
                if (timer == TICK_COUNT / 2) begin
                    data_out[bit_idx] <= rx;
                end
            end
        end

        STOP: begin
            if (timer == TICK_COUNT-1) begin
                timer <= 0;

                if (rx == 1) begin
                    ready <= 1;
                end

                state <= IDLE;
            end else begin
                    timer <= timer + 1;
                    end
                end
            endcase
        end
endmodule