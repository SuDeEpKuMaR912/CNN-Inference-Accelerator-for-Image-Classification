`timescale 1ns / 1ps
module sigmoid_lut #(
    parameter N = 16,
    parameter Q = 8,
    parameter LUT_DEPTH = 64
)(
    input  wire signed [N-1:0] in_val,   // Q8.8 input (-8.0 to +8.0)
    output reg  signed [N-1:0] out_val   // Q8.8 output (0.0 to 1.0)
);

    // 64-entry LUT for sigmoid(-8 → +8)
    reg [N-1:0] LUT [0:LUT_DEPTH-1];

    // Load LUT values (generated offline in Q8.8)
    initial begin
        $readmemh("sigmoid_lut.mem", LUT);
    end

    wire [7:0] scaled_index;
    wire [5:0] index;

    // Convert signed Q8.8 input to LUT index (0-63)
    // Range map: -8.0 -> 0, 0.0 -> 32, +8.0 -> 63
    assign scaled_index = (in_val >>> Q) + 8'd32;

    // Clamp index safely between 0 and 63
    assign index = (scaled_index[7:0] > 8'd63) ? 6'd63 :
                   (scaled_index[7:0] < 8'd0 ) ? 6'd0  :
                                                 scaled_index[5:0];

    always @(*) begin
        out_val = LUT[index];
    end

endmodule

