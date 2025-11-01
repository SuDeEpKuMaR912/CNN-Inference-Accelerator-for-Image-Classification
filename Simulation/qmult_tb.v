`timescale 1ns/1ps
module tb_qmult;
    reg  signed [15:0] a, b;
    wire signed [15:0] result;

    qmult uut(.a(a), .b(b), .result(result));

    // Convert real number → Q8.8 fixed point
    function signed [15:0] toQ8_8;
        input real val;
        toQ8_8 = val * 256; // 2^8 = 256
    endfunction

    // Convert back Q8.8 → real
    function real fromQ8_8;
        input signed [15:0] val;
        fromQ8_8 = val / 256.0;
    endfunction

    initial begin
        $monitor("a=%f, b=%f, result=%f",
                  fromQ8_8(a), fromQ8_8(b), fromQ8_8(result));

        a = toQ8_8(1.5); b = toQ8_8(2.0); #10;
        a = toQ8_8(-3.0); b = toQ8_8(0.5); #10;
        a = toQ8_8(0.25); b = toQ8_8(0.25); #10;
        $finish;
    end
endmodule
