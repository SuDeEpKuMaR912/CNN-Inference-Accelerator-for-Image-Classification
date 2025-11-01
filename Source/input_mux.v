`timescale 1ns / 1ps
module input_mux #(
    parameter N = 16   // Q8.8 data width
)(
    input  wire [1:0] sel,        // select signal
    input  wire signed [N-1:0] in_camera,   // image input from external source
    input  wire signed [N-1:0] in_test,     // testbench / manual input
    input  wire signed [N-1:0] in_mem,      // ROM/stored dataset input
    output reg  signed [N-1:0] out_data     // selected data out
);

always @(*) begin
    case(sel)
        2'b00: out_data = in_camera; // live image feed
        2'b01: out_data = in_test;   // testbench/manual
        2'b10: out_data = in_mem;    // BRAM/weights file sample
        default: out_data = 0;       // safe default
    endcase
end

endmodule

