`timescale 1ns/1ps
module tb_input_mux;

reg [1:0] sel;
reg signed [15:0] in_camera;
reg signed [15:0] in_test;
reg signed [15:0] in_mem;
wire signed [15:0] out_data;

input_mux uut (
    .sel(sel),
    .in_camera(in_camera),
    .in_test(in_test),
    .in_mem(in_mem),
    .out_data(out_data)
);

initial begin
    in_camera = 16'h0100; // +1.0 in Q8.8
    in_test   = 16'h0200; // +2.0 in Q8.8
    in_mem    = 16'h0300; // +3.0 in Q8.8

    $monitor("time=%0t sel=%b out=%h", $time, sel, out_data);

    sel = 2'b00; #10; // expect 0100
    sel = 2'b01; #10; // expect 0200
    sel = 2'b10; #10; // expect 0300
    sel = 2'b11; #10; // expect 0000 (default)

    #10 $finish;
end

endmodule

