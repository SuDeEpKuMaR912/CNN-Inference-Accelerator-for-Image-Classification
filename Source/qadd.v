module qadd #(parameter N = 16)(
    input  signed [N-1:0] a,
    input  signed [N-1:0] b,
    output signed [N-1:0] result
);
    assign result = a + b;
endmodule
