module control_logic #(
    parameter IMG_WIDTH = 150,
    parameter IMG_HEIGHT = 150
)(
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire pixel_in_valid,

    output reg conv_en,
    output reg pool_en,
    output reg dense_en,
    output reg done,
    output wire global_valid
);

localparam S_IDLE = 0,
           S_LOAD = 1,
           S_CONV = 2,
           S_POOL = 3,
           S_DENSE = 4,
           S_DONE = 5;

reg [2:0] state, next_state;

localparam TOTAL_PIX = IMG_WIDTH * IMG_HEIGHT;
integer pix_count;

// Global valid goes high whenever any stage is active
assign global_valid = conv_en | pool_en | dense_en;

// State register
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= S_IDLE;
        pix_count <= 0;
    end else begin
        state <= next_state;
        if (state == S_LOAD && pixel_in_valid)
            pix_count <= pix_count + 1;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case(state)
        S_IDLE:  if (start) next_state = S_LOAD;

        S_LOAD:  if (pix_count == TOTAL_PIX-1) next_state = S_CONV;

        S_CONV:  next_state = S_POOL;   // assume conv runs fixed cycles later

        S_POOL:  next_state = S_DENSE;  // same idea for pool

        S_DENSE: next_state = S_DONE;

        S_DONE:  next_state = S_IDLE;
    endcase
end

// Output enable logic
always @(*) begin
    conv_en  = (state == S_CONV);
    pool_en  = (state == S_POOL);
    dense_en = (state == S_DENSE);
    done     = (state == S_DONE);
end

endmodule
