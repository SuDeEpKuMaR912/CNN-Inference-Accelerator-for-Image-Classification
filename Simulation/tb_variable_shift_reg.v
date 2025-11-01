`timescale 1ns/1ps
module tb_variable_shift_reg;
    reg clk, reset;
    reg  [15:0] din;
    wire [15:0] dout;

    variable_shift_reg #(16, 4) uut(
        .clk(clk), .reset(reset), .din(din), .dout(dout)
    );

    always #5 clk = ~clk; // 100MHz clock

    initial begin
        $monitor("Time=%0t din=%d dout=%d", $time, din, dout);

        clk = 0; reset = 1; din = 0; #12;
        reset = 0;

        din = 1; #10;
        din = 2; #10;
        din = 3; #10;
        din = 4; #10;
        din = 5; #10;
        $finish;
    end
endmodule
