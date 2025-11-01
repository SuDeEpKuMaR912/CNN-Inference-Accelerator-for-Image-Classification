`timescale 1ns/1ps
module tb_comparator;
    reg signed [15:0] a, b;
    wire a_greater, a_equal;
    wire signed [15:0] max_val;

    comparator uut (
        .a(a),
        .b(b),
        .a_greater(a_greater),
        .a_equal(a_equal),
        .max_val(max_val)
    );

    initial begin
        $display("Time\t   a(raw)\t b(raw)\t max(raw)\t a>b\t a==b");
        $monitor("%0t\t %0d\t %0d\t %0d\t %b\t %b", $time, a, b, max_val, a_greater, a_equal);

        // Q8.8 inputs (scale by 256)
        a = 10 * 256;    b = 5  * 256;   #10;   // 10.0 vs 5.0
        a = -2 * 256;    b = 3  * 256;   #10;   // -2.0 vs 3.0
        a = 7  * 256;    b = 7  * 256;   #10;   // 7.0 vs 7.0 equal

        $display("\nHuman readable values (divide by 256):");
        $display("a = %0f, b = %0f, max = %0f", a/256.0, b/256.0, max_val/256.0);

        $finish;
    end
endmodule


