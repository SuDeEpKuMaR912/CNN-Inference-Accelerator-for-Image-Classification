`timescale 1ns / 1ps

module conv2 #(
    parameter int N = 16,        
    parameter int Q = 8,         
    parameter int IMG_WIDTH = 74,
    parameter int IMG_HEIGHT = 74,
    parameter int K = 3,
    parameter int IN_CH = 32,
    parameter int OUT_CH = 64
)(
    input  wire                        clk,
    input  wire                        reset,

    input  wire signed [N-1:0]         din,
    input  wire                        din_valid,

    
    input  wire                        weight_wr_en,
    input  wire [$clog2(OUT_CH*IN_CH*K*K)-1:0] weight_wr_addr, 
    input  wire signed [N-1:0]         weight_wr_data,

    input  wire                        bias_wr_en,
    input  wire [$clog2(OUT_CH)-1:0]   bias_wr_addr, 
    input  wire signed [N-1:0]         bias_wr_data,

    
    input  wire                        start, 
    output reg                         busy,
    output reg                         done,

    
    output reg signed [N-1:0]         dout,
    output reg                         dout_valid
);

    localparam int K_ELEMS = K * K;
    localparam int PIXELS_TOTAL = IMG_WIDTH * IMG_HEIGHT;

    
    reg signed [N-1:0] weight_mem [0:OUT_CH-1][0:IN_CH*K_ELEMS-1];
    reg signed [N-1:0] bias_mem   [0:OUT_CH-1];

    integer wf, wi;
    always @(posedge clk) begin
        if (weight_wr_en) begin
            
            weight_mem[ weight_wr_addr / (IN_CH*K_ELEMS) ][ weight_wr_addr % (IN_CH*K_ELEMS) ] <= weight_wr_data;
        end
        if (bias_wr_en) begin
            bias_mem[bias_wr_addr] <= bias_wr_data;
        end
    end

    
    wire signed [9*N-1:0] window_flat_ch [0:IN_CH-1];
    wire window_valid_ch [0:IN_CH-1];

    genvar chg;
    generate
      for (chg = 0; chg < IN_CH; chg = chg + 1) begin : LBS
        
        line_buffer #(.DATA_WIDTH(N), .IMG_WIDTH(IMG_WIDTH)) lb_inst (
            .clk(clk),
            .reset(reset),
            .din(din),
            .din_valid(din_valid),
            .window_flat(window_flat_ch[chg]),
            .window_valid(window_valid_ch[chg])
        );
      end
    endgenerate

    
    reg [$clog2(IN_CH)-1:0] in_ch_cntr;
    reg [31:0] col;
    reg [31:0] row;
    reg [31:0] pixel_cnt;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            in_ch_cntr <= 0;
            col <= 0; row <= 0; pixel_cnt <= 0;
        end else begin
            if (din_valid) begin
                
                if (in_ch_cntr + 1 == IN_CH) begin
                    in_ch_cntr <= 0;
                    
                    if (col + 1 == IMG_WIDTH) begin
                        col <= 0;
                        if (row + 1 == IMG_HEIGHT) row <= 0; else row <= row + 1;
                    end else begin
                        col <= col + 1;
                    end
                    pixel_cnt <= pixel_cnt + 1;
                end else begin
                    in_ch_cntr <= in_ch_cntr + 1;
                end
            end
        end
    end

    
    wire all_windows_valid;
    assign all_windows_valid = (&{ window_valid_ch[0], window_valid_ch[1], window_valid_ch[2], window_valid_ch[3], window_valid_ch[4], window_valid_ch[5], window_valid_ch[6], window_valid_ch[7] } ) ? 1'b1 : 1'b1;
    
    reg window_all_valid;
    integer chk;
    always @(*) begin
        window_all_valid = 1'b1;
        for (chk = 0; chk < IN_CH; chk = chk + 1)
            window_all_valid = window_all_valid & window_valid_ch[chk];
    end

    wire have_center = (col >= 1) && (row >= 1);
    wire emit_center = window_all_valid && (in_ch_cntr == IN_CH-1) && have_center && din_valid;

    
    reg signed [N-1:0] ws [0:IN_CH-1][0:K_ELEMS-1];
    integer r1, r2;
    
    always @(posedge clk) begin
        if (reset) begin
            for (r1 = 0; r1 < IN_CH; r1 = r1 + 1)
                for (r2 = 0; r2 < K_ELEMS; r2 = r2 + 1)
                    ws[r1][r2] <= 0;
        end else if (emit_center) begin
            for (r1 = 0; r1 < IN_CH; r1 = r1 + 1) begin
                // window_flat_ch[r1] is 9*N bits
                // map kidx 0..8 to slices (row-major chosen: top-left..bottom-right)
                // recall earlier ordering: {row3[2],row3[1],row3[0], row2[2],..., row1[0]}
                // Let's produce kidx mapping: [0]=row3c2 (top-left), [1]=row3c1, [2]=row3c0, [3]=row2c2, [4]=row2c1, [5]=row2c0, [6]=row1c2, [7]=row1c1, [8]=row1c0
                ws[r1][0] <= window_flat_ch[r1][9*N-1 -: N];
                ws[r1][1] <= window_flat_ch[r1][8*N-1 -: N];
                ws[r1][2] <= window_flat_ch[r1][7*N-1 -: N];
                ws[r1][3] <= window_flat_ch[r1][6*N-1 -: N];
                ws[r1][4] <= window_flat_ch[r1][5*N-1 -: N];
                ws[r1][5] <= window_flat_ch[r1][4*N-1 -: N];
                ws[r1][6] <= window_flat_ch[r1][3*N-1 -: N];
                ws[r1][7] <= window_flat_ch[r1][2*N-1 -: N];
                ws[r1][8] <= window_flat_ch[r1][1*N-1 -: N];
            end
        end
    end

    typedef enum logic [2:0] {S_IDLE=3'd0, S_START=3'd1, S_FILTER=3'd2, S_ACC_CHK=3'd3, S_STORE=3'd4, S_DONE=3'd5} state_t;
    state_t s;
    integer f_idx;
    integer ch_idx;
    integer kidx;

    reg signed [47:0] acc; // wide accumulator
    reg signed [31:0] prod;

    
    reg [31:0] out_row, out_col;
    reg [31:0] out_pixel_counter; // optional

    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            s <= S_IDLE;
            busy <= 0;
            done <= 0;
            dout <= 0;
            dout_valid <= 0;
            f_idx <= 0;
            ch_idx <= 0;
            kidx <= 0;
            acc <= 0;
            out_row <= 0; out_col <= 0; out_pixel_counter <= 0;
        end else begin
            
            dout_valid <= 0;

            case (s)
                S_IDLE: begin
                    busy <= 0;
                    done <= 0;
                    if (start) begin
                        
                        busy <= 1;
                        out_row <= 0; out_col <= 0;
                        s <= S_START;
                    end
                end

                S_START: begin
                    busy <= 1;
                    
                    if (emit_center) begin
                        
                        out_row <= row - 1;
                        out_col <= col - 1;
                        f_idx <= 0;
                        s <= S_FILTER;
                    end
                end

                S_FILTER: begin
                    
                    acc <= 0;
                    ch_idx <= 0;
                    kidx <= 0;
                    s <= S_ACC_CHK;
                end

                S_ACC_CHK: begin
                    
                    prod <= $signed(ws[ch_idx][kidx]) * $signed(weight_mem[f_idx][ ch_idx*K_ELEMS + kidx ]);
                    acc <= acc + prod;
                    
                    if (kidx + 1 < K_ELEMS) begin
                        kidx <= kidx + 1;
                    end else begin
                        kidx <= 0;
                        if (ch_idx + 1 < IN_CH) begin
                            ch_idx <= ch_idx + 1;
                        end else begin
                            
                            s <= S_STORE;
                        end
                    end
                end

                S_STORE: begin
                    
                    reg signed [47:0] acc_shifted;
                    acc_shifted = (acc >>> Q) + $signed({{(48-N){bias_mem[f_idx][N-1]}}, bias_mem[f_idx]});
                    dout <= acc_shifted[N-1:0];
                    dout_valid <= 1;

                    
                    if (f_idx + 1 < OUT_CH) begin
                        f_idx <= f_idx + 1;
                        s <= S_FILTER;
                    end else begin
                        
                        s <= S_START;
                    end
                end

                S_DONE: begin
                    busy <= 0;
                    done <= 1;
                end

                default: s <= S_IDLE;
            endcase
        end
    end

endmodule
