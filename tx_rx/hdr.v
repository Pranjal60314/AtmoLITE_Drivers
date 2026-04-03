 module hdr #(

parameter [7:0] logical_address = 8'hFE

)(

input wire clk,
input wire resetn,
input wire [7:0] protocol, subprotocol, packet_nr,
input wire [7:0] param0, param1, param2, param3, param4, param5, param6, param7,
input wire [23:0] xlen,
input wire header_valid,
input wire [3:0] dout_index,
output reg [7:0] dout

);

reg [7:0] i_proto, i_sub, i_pkt;
reg [7:0] i_p[0:7];
reg [23:0] i_xlen;

always @(posedge clk) begin
    if (!resetn) begin
        i_proto <= 0; i_sub <= 0; i_pkt <= 0; i_xlen <= 0;
    end else if (header_valid) begin
        i_proto <= protocol;

    i_sub <= packet_nr;
    i_pkt <= subprotocol;
    i_p[0] <= param0; i_p[1] <= param1; i_p[2] <= param2; i_p[3] <= param3;
    i_p[4] <= param4; i_p[5] <= param5; i_p[6] <= param6; i_p[7] <= param7;
    i_xlen <= xlen;

end

end


always @(*) begin

case(dout_index)
    4'd0: dout = logical_address;
    4'd1: dout = i_proto;
    4'd2: dout = i_sub;
    4'd3: dout = i_pkt;
    4'd4: dout = i_p[0];
    4'd5: dout = i_p[1];
    4'd6: dout = i_p[2];
    4'd7: dout = i_p[3];
    4'd8: dout = i_p[4];
    4'd9: dout = i_p[5];
    4'd10: dout = i_p[6];
    4'd11: dout = i_p[7];
    4'd12: dout = i_xlen[7:0];
    4'd13: dout = i_xlen[15:8];
    4'd14: dout = i_xlen[23:16];

default: dout = 8'h00;

endcase

end

endmodule 