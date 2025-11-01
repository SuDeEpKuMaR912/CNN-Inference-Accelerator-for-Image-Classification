`timescale 1ns / 1ps
module tb_sigmoid_lut;

    reg signed [15:0] in_val;
    wire signed [15:0] out_val;

    sigmoid_lut uut (.in_val(in_val), .out_val(out_val));

    initial begin
        $display("x (Q8.8)\tSigmoid (Q8.8)\tReal Out");

        in_val = -16'sh0800; #10;
        $display("-8.0\t%d\t%0.3f", out_val, $itor(out_val)/256.0);

        in_val = -16'sh0100; #10;
        $display("-1.0\t%d\t%0.3f", out_val, $itor(out_val)/256.0);

        in_val = 16'sh0000; #10;
        $display(" 0.0\t%d\t%0.3f", out_val, $itor(out_val)/256.0);

        in_val = 16'sh0100; #10;
        $display(" 1.0\t%d\t%0.3f", out_val, $itor(out_val)/256.0);

        in_val = 16'sh0800; #10;
        $display(" 8.0\t%d\t%0.3f", out_val, $itor(out_val)/256.0);

        $finish;
    end
endmodule

