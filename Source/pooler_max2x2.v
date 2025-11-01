module pooler_max2x2 #(parameter N = 16)(
    input  wire clk,
    input  wire reset,
    input  wire valid_in,
    input  wire signed [N-1:0] din,
    output reg  signed [N-1:0] dout,
    output reg  valid_out
);
    reg [1:0] count; // counts pixels in a 2x2 block
    reg reset_max;   // local reset signal for max_reg

    wire signed [N-1:0] max_val;

    // Instantiate your max_reg here
    max_reg #(N) max_unit (
        .clk(clk),
        .reset(reset_max),
        .din(din),
        .valid(valid_in),
        .max_out(max_val)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 0;
            dout <= 0;
            valid_out <= 0;
            reset_max <= 1;
        end else if (valid_in) begin
            reset_max <= 0;
            count <= count + 1;

            if (count == 2'd3) begin
                dout <= max_val;
                valid_out <= 1;
                count <= 0;
                reset_max <= 1; // reset for next 2×2 block
            end else begin
                valid_out <= 0;
            end
        end
    end
endmodule
