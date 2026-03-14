module crc8_generator (
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  data_in,
    input  wire        data_valid,
    output reg  [7:0]  crc_out
);

    reg [7:0] crc_reg;
    reg [7:0] CRC_TABLE [0:255];

    // Combinational logic to find the next CRC value
    // This matches: val = CRC_TABLE[val ^ data]
    wire [7:0] next_crc = CRC_TABLE[crc_reg ^ data_in];

    initial begin
    $readmemh("crc_table.hex", CRC_TABLE);
    // Add these lines:
    $display("DEBUG: Table Entry 0 is %h", CRC_TABLE[0]);
    $display("DEBUG: Table Entry 1 is %h", CRC_TABLE[1]);
end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            crc_reg <= 8'h00;
            crc_out <= 8'h00;
        end 
        else if (data_valid) begin
            crc_reg <= next_crc;
            crc_out <= next_crc; // Assign the NEW value to the output
        end
    end

endmodule
