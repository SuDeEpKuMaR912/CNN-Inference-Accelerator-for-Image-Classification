module relu #(parameter N = 16)(
    input  signed [N-1:0] din,
    output signed [N-1:0] dout
);
    assign dout = (din[15] == 1'b1) ? 16'sd0 : din;
endmodule

