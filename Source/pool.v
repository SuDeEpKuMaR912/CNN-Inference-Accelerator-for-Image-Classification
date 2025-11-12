`timescale 1ns / 1ps
// pool.v - hierarchical streaming 2x2 maxpool (stride=2, non-overlapping)
// Uses line_buffer, max_reg, comparator. 4-cycle max per 2x2 block.

module pool #(
    parameter integer DATA_WIDTH = 16,
    parameter integer IMG_WIDTH  = 8,
    parameter integer IMG_HEIGHT = 8,
    parameter integer N = DATA_WIDTH,
    parameter integer IN_SIZE = IMG_WIDTH,
    parameter integer OUT_CHANNELS = 4
)(
    input  wire clk,
    input  wire reset,
    input  wire signed [DATA_WIDTH-1:0] din,
    input  wire valid_in,

    output reg  signed [DATA_WIDTH-1:0] pool_dout,
    output reg                          pool_valid_out
);

    // ===========================================
    // LINE BUFFER (produces 3x3 window + valid)
    // ===========================================
    wire signed [9*DATA_WIDTH-1:0] window_flat;
    wire                           window_valid;

    line_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH(IMG_WIDTH)
    ) lb (
        .clk(clk),
        .reset(reset),
        .din(din),
        .din_valid(valid_in),
        .window_flat(window_flat),
        .window_valid(window_valid)
    );

    // ===========================================
    // RASTER COUNTERS
    // ===========================================
    reg [31:0] col;
    reg [31:0] row;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            col <= 0;
            row <= 0;
        end else if (valid_in) begin
            if (col + 1 == IMG_WIDTH) begin
                col <= 0;
                if (row + 1 == IMG_HEIGHT) row <= 0; else row <= row + 1;
            end else begin
                col <= col + 1;
            end
        end
    end

    // ===========================================
    // DECODE 3x3 WINDOW
    // ===========================================
    wire signed [DATA_WIDTH-1:0] w_r3c2 = window_flat[9*DATA_WIDTH-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] w_r3c1 = window_flat[8*DATA_WIDTH-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] w_r3c0 = window_flat[7*DATA_WIDTH-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] w_r2c2 = window_flat[6*DATA_WIDTH-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] w_r2c1 = window_flat[5*DATA_WIDTH-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] w_r2c0 = window_flat[4*DATA_WIDTH-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] w_r1c2 = window_flat[3*DATA_WIDTH-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] w_r1c1 = window_flat[2*DATA_WIDTH-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] w_r1c0 = window_flat[1*DATA_WIDTH-1 -: DATA_WIDTH];

    // 2x2 pixels
    wire signed [DATA_WIDTH-1:0] a = w_r2c1; // top-left
    wire signed [DATA_WIDTH-1:0] b = w_r2c0; // top-right
    wire signed [DATA_WIDTH-1:0] c = w_r1c1; // bottom-left
    wire signed [DATA_WIDTH-1:0] d = w_r1c0; // bottom-right

    // ===========================================
    // FSM (fixed enum usage) + max_reg instance
    // ===========================================
    typedef enum logic [2:0] {
        S_IDLE  = 3'd0,
        S_LOAD1 = 3'd1,
        S_LOAD2 = 3'd2,
        S_LOAD3 = 3'd3,
        S_LOAD4 = 3'd4,
        S_DONE  = 3'd5
    } state_t;

    state_t state;

    // pixel buffer for the 4 values (signed regs)
    reg signed [DATA_WIDTH-1:0] pixel_buf [0:3];
    reg [1:0] pix_idx;

    // max_reg control signals / wires
    reg reset_max;
    reg valid_max;
    reg signed [DATA_WIDTH-1:0] din_max;
    wire signed [DATA_WIDTH-1:0] max_val;

    max_reg #(DATA_WIDTH) max_inst (
        .clk(clk),
        .reset(reset_max),
        .din(din_max),
        .valid(valid_max),
        .max_out(max_val)
    );

    // trigger when line buffer has a valid 3x3 window and we're at col>=1,row>=1 and aligned to stride-2
    wire have_2x2 = window_valid && (col >= 1) && (row >= 1);
    wire stride_ok = (col[0] == 1'b1) && (row[0] == 1'b1);
    wire trigger_block = have_2x2 && stride_ok && valid_in;

    // FSM: explicit enum assignments (no arithmetic on enum)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            pix_idx <= 0;
            pool_dout <= 0;
            pool_valid_out <= 0;
            reset_max <= 1;
            valid_max <= 0;
            din_max <= 0;
            pixel_buf[0] <= 0;
            pixel_buf[1] <= 0;
            pixel_buf[2] <= 0;
            pixel_buf[3] <= 0;
        end else begin
            pool_valid_out <= 0;
            valid_max <= 0;

            case (state)
                S_IDLE: begin
                    reset_max <= 1;
                    if (trigger_block) begin
                        // latch the 4 pixels to process
                        pixel_buf[0] <= a;
                        pixel_buf[1] <= b;
                        pixel_buf[2] <= c;
                        pixel_buf[3] <= d;
                        pix_idx <= 0;
                        reset_max <= 0; // release reset for max_reg
                        state <= S_LOAD1;
                    end
                end

                S_LOAD1: begin
                    // feed first pixel
                    valid_max <= 1;
                    din_max <= pixel_buf[0];
                    pix_idx <= 1;
                    state <= S_LOAD2;
                end

                S_LOAD2: begin
                    valid_max <= 1;
                    din_max <= pixel_buf[1];
                    pix_idx <= 2;
                    state <= S_LOAD3;
                end

                S_LOAD3: begin
                    valid_max <= 1;
                    din_max <= pixel_buf[2];
                    pix_idx <= 3;
                    state <= S_LOAD4;
                end

                S_LOAD4: begin
                    valid_max <= 1;
                    din_max <= pixel_buf[3];
                    // after last input, move to DONE to sample max_val next cycle
                    state <= S_DONE;
                end

                S_DONE: begin
                    pool_dout <= max_val;
                    pool_valid_out <= 1;
                    // re-assert reset_max to prepare next block (max_reg will be reset)
                    reset_max <= 1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
