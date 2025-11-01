`timescale 1ns / 1ps
module tb_flatten;
    reg clk, reset, start;
    reg [255:0] feature_map_flat;  // 16-bit * 16 elements
    wire signed [15:0] flat_out;
    wire done;

    flatten uut (.clk(clk), .reset(reset), .start(start), .feature_map_flat(feature_map_flat), .flat_out(flat_out), .done(done));

    always #5 clk = ~clk;

    initial begin
        clk = 0; reset = 1; start = 0; feature_map_flat = 0;
        #10 reset = 0; start = 1;
        feature_map_flat = {
            16'h000F, 16'h000E, 16'h000D, 16'h000C,
            16'h000B, 16'h000A, 16'h0009, 16'h0008,
            16'h0007, 16'h0006, 16'h0005, 16'h0004,
            16'h0003, 16'h0002, 16'h0001, 16'h0000
        };
        #10 start = 0;

        #200;
        $finish;
    end
endmodule

