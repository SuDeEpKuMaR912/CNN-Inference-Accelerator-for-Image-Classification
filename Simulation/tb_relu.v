`timescale 1ns/1ps
module tb_relu;
    reg  signed [15:0] din;
    wire signed [15:0] dout;

    relu #(16) uut (.din(din), .dout(dout));

    initial begin
        $display("Time\tInput(Q8.8)\tOutput(Q8.8)");
        $monitor("%0t\t%d\t\t%d", $time, din, dout);

        // Test various values
        din =  3 * 256;  #10; // +3.0
        din = -2 * 256;  #10; // -2.0 → 0
        din =  0;        #10; // 0
        din =  7 * 256;  #10; // +7.0
        din = -5 * 256;  #10; // -5.0 → 0

        $display("ReLU Test done.");
        $finish;
    end
endmodule
