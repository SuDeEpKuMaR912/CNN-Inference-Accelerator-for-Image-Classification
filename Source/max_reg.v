module max_reg #(parameter N = 16)(
    input clk,
    input reset,
    input signed [N-1:0] din,
    input valid,
    output reg signed [N-1:0] max_out
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            max_out <= -32768;   // minimum 16-bit signed value
        else if (valid) begin
            if (din > max_out)
                max_out <= din;
        end
    end
endmodule