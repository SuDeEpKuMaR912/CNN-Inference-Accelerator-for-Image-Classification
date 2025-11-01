`timescale 1ns/1ps
module tb_max_reg;
    reg clk, reset, valid;
    reg  signed [15:0] din;
    wire signed [15:0] max_out;

    max_reg uut (
        .clk(clk),
        .reset(reset),
        .din(din),
        .valid(valid),
        .max_out(max_out)
    );

    // Clock generation: 10ns period
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1; valid = 0; din = 0;
        #10 reset = 0; valid = 1;

        // Feed Q8.8 values (x256)
        din = 3 * 256;    #10;   // 3.0
        din = 7 * 256;    #10;   // 7.0
        din = 5 * 256;    #10;   // 5.0
        din = 2 * 256;    #10; 

        valid = 0; #10;

        $display("Final Max (raw Q8.8) = %0d", max_out);
        $display("Final Max (real) = %0f", max_out / 256.0);
        $finish;
    end
endmodule


