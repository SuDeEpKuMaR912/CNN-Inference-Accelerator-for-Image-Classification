module pool3 #(
    parameter integer DATA_WIDTH = 16,
    parameter integer IMG_WIDTH  = 34,
    parameter integer IMG_HEIGHT = 34
)(
    input  wire clk,
    input  wire reset,

    input  wire start,          
    input  wire signed [DATA_WIDTH-1:0] din,
    input  wire valid_in,

    output reg  signed [DATA_WIDTH-1:0] pool_dout,
    output reg                          pool_valid_out,

    output wire busy,
    output reg  done                  
);

    wire signed [9*DATA_WIDTH-1:0] window_flat;
    wire window_valid;

    line_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH (IMG_WIDTH)
    ) lb (
        .clk(clk),
        .reset(reset),
        .din(din),
        .din_valid(valid_in),
        .window_flat(window_flat),
        .window_valid(window_valid)
    );


    reg [31:0] row, col;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            row <= 0;
            col <= 0;
        end 
        else if (valid_in) begin
            if (col + 1 == IMG_WIDTH) begin
                col <= 0;
                if (row + 1 == IMG_HEIGHT)
                    row <= 0;
                else
                    row <= row + 1;
            end else begin
                col <= col + 1;
            end
        end
    end

    wire signed [DATA_WIDTH-1:0] a = window_flat[5*DATA_WIDTH-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] b = window_flat[4*DATA_WIDTH-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] c = window_flat[2*DATA_WIDTH-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] d = window_flat[1*DATA_WIDTH-1 -: DATA_WIDTH];

    wire trigger_block =
        start &&
        window_valid &&
        (col >= 1) && (row >= 1) &&
        (col[0] == 1'b1) && (row[0] == 1'b1) &&
        valid_in;

    reg reset_max, valid_max;
    reg signed [DATA_WIDTH-1:0] din_max;
    wire signed [DATA_WIDTH-1:0] max_val;

    max_reg #(DATA_WIDTH) max_inst (
        .clk(clk),
        .reset(reset_max),
        .din(din_max),
        .valid(valid_max),
        .max_out(max_val)
    );

    localparam integer OUT_W = IMG_WIDTH  / 2;
    localparam integer OUT_H = IMG_HEIGHT / 2;
    localparam integer TOTAL_OUT = OUT_W * OUT_H;

    reg [31:0] pool_count;

    typedef enum logic [2:0] {
        S_IDLE  = 3'd0,
        S_LOAD1 = 3'd1,
        S_LOAD2 = 3'd2,
        S_LOAD3 = 3'd3,
        S_LOAD4 = 3'd4,
        S_STORE = 3'd5
    } state_t;

    state_t state;

    assign busy = (state != S_IDLE);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            pool_valid_out <= 0;
            valid_max <= 0;
            reset_max <= 1;
            pool_count <= 0;
            done <= 0;
        end else begin
            pool_valid_out <= 0;
            valid_max <= 0;
            done <= 0;

            case (state)

                S_IDLE: begin
                    reset_max <= 1;
                    if (start)
                        pool_count <= 0;     // reset pixel counter

                    if (trigger_block) begin
                        reset_max <= 0;
                        state <= S_LOAD1;
                    end
                end

                S_LOAD1: begin valid_max <= 1; din_max <= a; state <= S_LOAD2; end
                S_LOAD2: begin valid_max <= 1; din_max <= b; state <= S_LOAD3; end
                S_LOAD3: begin valid_max <= 1; din_max <= c; state <= S_LOAD4; end
                S_LOAD4: begin valid_max <= 1; din_max <= d; state <= S_STORE; end

                S_STORE: begin
                    pool_dout <= max_val;
                    pool_valid_out <= 1;
                    pool_count <= pool_count + 1;

                    if (pool_count + 1 == TOTAL_OUT)
                        done <= 1;

                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
