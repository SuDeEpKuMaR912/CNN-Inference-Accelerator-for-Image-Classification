`timescale 1ns / 1ps
module max_reg #(parameter N = 16)(
    input  wire clk,
    input  wire reset,
    input  wire signed [N-1:0] din,
    input  wire valid,
    output reg signed [N-1:0] max_out
);

    // comparator wires
    wire comp_a_greater;
    wire comp_a_equal;
    wire signed [N-1:0] comp_max;

    // Instantiate comparator: compare (din) vs current (max_out)
    comparator #(N) cmp (
        .a(din),
        .b(max_out),
        .a_greater(comp_a_greater),
        .a_equal(comp_a_equal),
        .max_val(comp_max)
    );

    // Most-negative value for N-bit signed: 1 followed by (N-1) zeros
    localparam signed [N-1:0] MIN_NEG = {1'b1, {(N-1){1'b0}}};

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            max_out <= MIN_NEG;
        end else if (valid) begin
            // update stored max with comparator result (comp_max)
            max_out <= comp_max;
        end
    end

endmodule
