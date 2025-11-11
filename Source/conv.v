`timescale 1ns / 1ps

module conv #(
    parameter int N = 16,           // data width (Q format)
    parameter int Q = 8,            // fractional bits
    parameter int IMG_SIZE = 8,     // input feature map width/height
    parameter int K = 3,            // kernel size
    parameter int OUT_CHANNELS = 4  // number of filters
)(
    input  wire clk,
    input  wire reset,
    input  wire start,

    // flattened packed buses
    input  wire signed [N*IMG_SIZE*IMG_SIZE-1:0] feat_mem_flat,
    input  wire signed [N*OUT_CHANNELS*K*K-1:0] weight_mem_flat,
    input  wire signed [N*OUT_CHANNELS-1:0] bias_mem_flat,

    // outputs
    output reg  signed [N*OUT_CHANNELS*(IMG_SIZE-K+1)*(IMG_SIZE-K+1)-1:0] out_mem_flat,
    output reg  done
);

    // -------------------------------------------------------------------------
    // Local constants
    // -------------------------------------------------------------------------
    localparam int OUT_SIDE   = IMG_SIZE - K + 1;
    localparam int FEAT_ELEMS = IMG_SIZE * IMG_SIZE;
    localparam int K_ELEMS    = K * K;

    // -------------------------------------------------------------------------
    // Helper accessors
    // -------------------------------------------------------------------------
    function automatic signed [N-1:0] get_feat(input int idx);
        get_feat = feat_mem_flat[idx*N +: N];
    endfunction

    function automatic signed [N-1:0] get_weight(input int f_idx, input int k_idx);
        get_weight = weight_mem_flat[(f_idx*K_ELEMS + k_idx)*N +: N];
    endfunction

    function automatic signed [N-1:0] get_bias(input int f_idx);
        get_bias = bias_mem_flat[f_idx*N +: N];
    endfunction

    task automatic write_out(input int f_idx, input int oy, input int ox, input signed [N-1:0] val);
        int out_index;
        out_index = f_idx*OUT_SIDE*OUT_SIDE + oy*OUT_SIDE + ox;
        out_mem_flat[out_index*N +: N] = val;
    endtask

    // -------------------------------------------------------------------------
    // FSM + compute regs
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {S_IDLE, S_INIT, S_COMPUTE, S_STORE, S_DONE} state_t;
    state_t state;

    int f, oy, ox, ky, kx;
    int feat_index;
    reg signed [47:0] acc;
    reg signed [31:0] prod;
    reg signed [N-1:0] bias_q, out_q;

    // -------------------------------------------------------------------------
    // FSM logic
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            done <= 0;
            state <= S_IDLE;
            out_mem_flat <= '0;
            f <= 0; oy <= 0; ox <= 0; ky <= 0; kx <= 0;
            acc <= 0;
        end else begin
            case (state)

                // -------------------------------------------------------------
                // Wait for start
                // -------------------------------------------------------------
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        f <= 0; oy <= 0; ox <= 0;
                        ky <= 0; kx <= 0;
                        acc <= 0;
                        state <= S_INIT;
                        $display("[CONV] START @ %0t", $time);
                    end
                end

                // -------------------------------------------------------------
                // Initialize accumulation for current (f,oy,ox)
                // -------------------------------------------------------------
                S_INIT: begin
                    acc <= 0;
                    ky <= 0; kx <= 0;
                    state <= S_COMPUTE;
                end

                // -------------------------------------------------------------
                // MAC over KxK window
                // -------------------------------------------------------------
                S_COMPUTE: begin
                    feat_index = (oy + ky)*IMG_SIZE + (ox + kx);
                    prod = $signed(get_feat(feat_index)) * $signed(get_weight(f, ky*K + kx));
                    acc <= acc + prod;

                    if (kx + 1 < K) begin
                        kx <= kx + 1;
                    end else begin
                        kx <= 0;
                        if (ky + 1 < K) begin
                            ky <= ky + 1;
                        end else begin
                            // finished kernel window
                            state <= S_STORE;
                        end
                    end
                end

                // -------------------------------------------------------------
                // Add bias, scale, truncate, and store
                // -------------------------------------------------------------
                S_STORE: begin
                    bias_q = get_bias(f);
                    acc = acc >>> Q; // scale from Q16.16 -> Q8.8 approx
                    acc = acc + $signed({{(48-N){bias_q[N-1]}}, bias_q});
                    out_q = acc[N-1:0];
                    write_out(f, oy, ox, out_q);

                    // print debug for first few outputs
                    if (f == 0 && oy < 2 && ox < 2)
                        $display("[CONV] f=%0d (%0d,%0d) out=%0d", f, oy, ox, out_q);

                    // advance to next spatial position
                    acc <= 0;
                    ky <= 0; kx <= 0;
                    if (ox + 1 < OUT_SIDE) begin
                        ox <= ox + 1;
                        state <= S_INIT;
                    end else begin
                        ox <= 0;
                        if (oy + 1 < OUT_SIDE) begin
                            oy <= oy + 1;
                            state <= S_INIT;
                        end else begin
                            oy <= 0;
                            if (f + 1 < OUT_CHANNELS) begin
                                f <= f + 1;
                                state <= S_INIT;
                            end else begin
                                state <= S_DONE;
                            end
                        end
                    end
                end

                // -------------------------------------------------------------
                // Done state
                // -------------------------------------------------------------
                S_DONE: begin
                    done <= 1;
                    $display("[CONV] DONE @ %0t", $time);
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule
