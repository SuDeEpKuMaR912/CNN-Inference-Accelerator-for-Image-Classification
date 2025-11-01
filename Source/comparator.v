module comparator #(parameter N = 16)(
    input  signed [N-1:0] a,
    input  signed [N-1:0] b,
    output reg a_greater,
    output reg a_equal,
    output reg signed [N-1:0] max_val
);
    always @(*) begin
        if (a > b) begin
            a_greater = 1;
            a_equal = 0;
            max_val = a;
        end else if (a == b) begin
            a_greater = 0;
            a_equal = 1;
            max_val = a;  // or b, same
        end else begin
            a_greater = 0;
            a_equal = 0;
            max_val = b;
        end
    end
endmodule
