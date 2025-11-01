module line_buffer #(
    parameter DATA_WIDTH = 16,
    parameter IMG_WIDTH  = 4
)(
    input  wire clk,
    input  wire reset,
    input  wire signed [DATA_WIDTH-1:0] din,
    output wire signed [9*DATA_WIDTH-1:0] window_flat  // flattened 3x3 window
);

    wire signed [DATA_WIDTH-1:0] line1_out, line2_out;

    // --- Line Buffers (Vertical buffering) ---
    variable_shift_reg #(.WIDTH(DATA_WIDTH), .DEPTH(IMG_WIDTH)) L1 (
        .clk(clk), .reset(reset), .din(din),       .dout(line1_out)
    );

    variable_shift_reg #(.WIDTH(DATA_WIDTH), .DEPTH(IMG_WIDTH)) L2 (
        .clk(clk), .reset(reset), .din(line1_out), .dout(line2_out)
    );

    // --- Horizontal Shift Registers (3 per row) ---
    reg signed [DATA_WIDTH-1:0] row1[0:2];
    reg signed [DATA_WIDTH-1:0] row2[0:2];
    reg signed [DATA_WIDTH-1:0] row3[0:2];
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 3; i = i + 1) begin
                row1[i] <= 0;
                row2[i] <= 0;
                row3[i] <= 0;
            end
        end else begin
            row1[2] <= row1[1];
            row1[1] <= row1[0];
            row1[0] <= din;

            row2[2] <= row2[1];
            row2[1] <= row2[0];
            row2[0] <= line1_out;

            row3[2] <= row3[1];
            row3[1] <= row3[0];
            row3[0] <= line2_out;
        end
    end

    // --- Flatten the 3x3 window into one 144-bit bus (9 * 16) ---
    assign window_flat = {
        row3[2], row3[1], row3[0],
        row2[2], row2[1], row2[0],
        row1[2], row1[1], row1[0]
    };

endmodule
