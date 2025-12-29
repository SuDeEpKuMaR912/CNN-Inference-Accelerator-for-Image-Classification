`timescale 1ns/1ps

module sigmoid_lut #(
    parameter N = 16,
    parameter Q = 8,
    parameter LUT_DEPTH = 64
)(
    input  wire clk,
    input  wire reset,

    input  wire signed [N-1:0] in_val,
    input  wire                din_valid,

    output reg  signed [N-1:0] out_val,
    output reg                 out_valid
);

    reg signed [N-1:0] LUT [0:LUT_DEPTH-1];

    initial begin
        $readmemh("sigmoid_lut.mem", LUT);
    end

    wire [7:0] scaled_index;
    wire [5:0] index;

    assign scaled_index = (in_val >>> Q) + 8'd32;

    assign index = (scaled_index > 8'd63) ? 6'd63 :
                   (scaled_index < 8'd0 ) ? 6'd0  :
                                             scaled_index[5:0];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            out_val   <= 0;
            out_valid <= 0;
        end else begin
            if (din_valid) begin
                out_val   <= LUT[index];
                out_valid <= 1;
            end else begin
                out_valid <= 0;
            end
        end
    end

endmodule
