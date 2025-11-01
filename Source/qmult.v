module qmult #(parameter Q = 8, N = 16)(
    input  signed [N-1:0] a,
    input  signed [N-1:0] b,
    output signed [N-1:0] result
);
    // Full precision result
    wire signed [2*N-1:0] mult_full;
    assign mult_full = a * b;

    // Adjust back to Q format (shift right by Q bits)
    assign result = mult_full >>> Q;
endmodule
