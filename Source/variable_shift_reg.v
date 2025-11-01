module variable_shift_reg #(parameter WIDTH = 16, DEPTH = 4)(
    input                  clk,
    input                  reset,
    input      [WIDTH-1:0] din,
    output reg [WIDTH-1:0] dout
);
    reg [WIDTH-1:0] shift_reg [0:DEPTH-1];
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < DEPTH; i = i + 1)
                shift_reg[i] <= 0;
            dout <= 0;
        end else begin
            shift_reg[0] <= din;
            for (i = 1; i < DEPTH; i = i + 1)
                shift_reg[i] <= shift_reg[i-1];
            dout <= shift_reg[DEPTH-1];
        end
    end
endmodule
