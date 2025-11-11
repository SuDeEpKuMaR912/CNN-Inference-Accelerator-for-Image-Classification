`timescale 1ns / 1ps
// conv.v - flattened-bus functional convolution (sequential, SystemVerilog-friendly)
// - Use for TB/debug. Later you can replace with line-buffer/mac-based design.
// - Produces OUT_SIDE = IMG_SIZE - K + 1 sized feature maps per filter.
//
// Ports expect packed flat buses:
//  feat_mem_flat        : [N*IMG_SIZE*IMG_SIZE-1 : 0]
//  weight_mem_flat      : [N*OUT_CHANNELS*K*K -1 : 0]   (filters packed contiguous)
//  bias_mem_flat        : [N*OUT_CHANNELS -1 : 0]
//  out_mem_flat         : [N*OUT_CHANNELS*OUT_SIDE*OUT_SIDE -1 : 0]  (driven by conv)

module conv #(
    parameter int N = 16,
    parameter int Q = 8,
    parameter int IMG_SIZE = 8,
    parameter int K = 3,
    parameter int OUT_CHANNELS = 4
)(
    input  wire clk,
    input  wire reset,
    input  wire start,

    // flattened packed buses
    input  wire signed [N*IMG_SIZE*IMG_SIZE-1:0]         feat_mem_flat,
    input  wire signed [N*OUT_CHANNELS*K*K-1:0]         weight_mem_flat,
    input  wire signed [N*OUT_CHANNELS-1:0]              bias_mem_flat,

    // outputs (driven by conv)
    output reg  signed [N*OUT_CHANNELS*(IMG_SIZE-K+1)*(IMG_SIZE-K+1)-1:0] out_mem_flat,

    output reg done
);

    localparam int OUT_SIDE = IMG_SIZE - K + 1;
    localparam int FEAT_ELEMS = IMG_SIZE * IMG_SIZE;
    localparam int K_ELEMS = K * K;
    localparam int DENSE_OUT_ELEMS = OUT_CHANNELS * OUT_SIDE * OUT_SIDE;

    // small helper functions to slice packed buses cleanly
    function automatic signed [N-1:0] get_feat(input int idx);
        get_feat = feat_mem_flat[idx*N +: N];
    endfunction

    function automatic signed [N-1:0] get_weight(input int filter_idx, input int kidx);
        // weight offset = (filter_idx * K_ELEMS + kidx)
        get_weight = weight_mem_flat[(filter_idx*K_ELEMS + kidx)*N +: N];
    endfunction

    function automatic signed [N-1:0] get_bias(input int filter_idx);
        get_bias = bias_mem_flat[filter_idx*N +: N];
    endfunction

    // write helper to write a result into out_mem_flat at position (filter, oy, ox)
    task automatic write_out(input int filter_idx, input int oy, input int ox, input signed [N-1:0] value);
        int out_index;
        out_index = filter_idx*OUT_SIDE*OUT_SIDE + oy*OUT_SIDE + ox;
        out_mem_flat[out_index*N +: N] = value;
    endtask

    // FSM counters
    typedef enum logic [2:0] {S_IDLE, S_START, S_COMPUTE, S_DONE} state_t;
    state_t state;

    int f, oy, ox, ky, kx;
    int feat_index;
    // accumulator width: use wider width to avoid overflow on multiply-accumulate
    // input N (16) * input N (16) -> 32-bit multiply, accumulation use 48-bit to be safe
    reg signed [47:0] acc;
    reg signed [31:0] prod;
    reg signed [N-1:0] bias_q;
    reg signed [N-1:0] out_q;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            done <= 0;
            state <= S_IDLE;
            out_mem_flat <= '0;
            f <= 0; oy <= 0; ox <= 0; ky <= 0; kx <= 0;
            acc <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        // initialize counters
                        f <= 0; oy <= 0; ox <= 0;
                        state <= S_START;
                    end
                end

                S_START: begin
                    // start computing first output
                    acc <= 0;
                    ky <= 0; kx <= 0;
                    state <= S_COMPUTE;
                end

                S_COMPUTE: begin
                    // sequentially iterate kernel elements and build accumulator
                    // compute feat index for current (oy,ox,ky,kx)
                    feat_index = (oy + ky)*IMG_SIZE + (ox + kx);
                    // multiply (sign-extend via cast to wider)
                    prod = $signed(get_feat(feat_index)) * $signed(get_weight(f, ky*K + kx));
                    acc = acc + $signed(prod);
                    // advance kernel iterators
                    if (kx + 1 < K) begin
                        kx = kx + 1;
                    end else begin
                        kx = 0;
                        if (ky + 1 < K) begin
                            ky = ky + 1;
                        end else begin
                            // finished kernel for this output position
                            // add bias then saturate/truncate to N bits (Q8.8 fixed)
                            bias_q = get_bias(f);
                            // acc currently raw sum of (Q8.8 * Q8.8) = Q16.16 formally.
                            // For this functional TB we assume weight/in/data are small, and simply shift acc appropriately:
                            // To keep things simple and consistent with earlier mac_manual behavior, we assume mac outputs in same Q8.8
                            // So we'll right-shift by Q (8) bits to approximate scaling back to Q8.8.
                            // Note: this is a simplification for the test bench; replace with exact fixed-point logic later.
                            acc = acc >>> Q; // scale back
                            acc = acc + $signed({{(48-N){bias_q[N-1]}}, bias_q}); // add bias (sign-extended)
                            // truncate/saturate to N bits (simple truncation)
                            out_q = acc[N-1:0];
                            write_out(f, oy, ox, out_q);

                            // prepare for next spatial position
                            acc <= 0;
                            ky <= 0; kx <= 0;
                            if (ox + 1 < OUT_SIDE) begin
                                ox = ox + 1;
                            end else begin
                                ox = 0;
                                if (oy + 1 < OUT_SIDE) begin
                                    oy = oy + 1;
                                end else begin
                                    // finished all spatial pos for this filter
                                    oy = 0; ox = 0;
                                    if (f + 1 < OUT_CHANNELS) begin
                                        f = f + 1;
                                    end else begin
                                        // finished all filters -> done
                                        state <= S_DONE;
                                    end
                                end
                            end
                        end
                    end
                end

                S_DONE: begin
                    done <= 1;
                    // hold results until reset; optionally allow restart if start is toggled again (not implemented)
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
