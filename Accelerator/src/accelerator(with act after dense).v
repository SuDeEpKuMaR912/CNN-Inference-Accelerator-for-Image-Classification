`timescale 1ns / 1ps
// accelerator.sv - Dense-only simulation with ReLU + Sigmoid activations
// Flow: Dense1 -> ReLU -> Dense2 -> Sigmoid
// ----------------------------------------------------------------------

module accelerator #(
    parameter int N = 16,
    parameter int Q = 8,
    parameter int FLAT_SIZE = 16,      // smaller for test
    parameter int DENSE1_OUT = 4       // smaller for test
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    output logic done_out,
    output logic signed [N-1:0] final_out
);

    // --------------------------
    // Internal memories
    // --------------------------
    logic signed [N-1:0] feature_mem [0:FLAT_SIZE-1];
    localparam int D1_WTOTAL = FLAT_SIZE * DENSE1_OUT;
    logic signed [N-1:0] dense1_w_flat [0:D1_WTOTAL-1];
    logic signed [N-1:0] dense1_b [0:DENSE1_OUT-1];
    logic signed [N-1:0] dense2_w [0:DENSE1_OUT-1];
    logic signed [N-1:0] dense2_b [0:0];
    logic signed [N-1:0] hidden [0:DENSE1_OUT-1];

    // Dense I/O arrays
    logic signed [N-1:0] tb_input_vec [0:FLAT_SIZE-1];
    logic signed [N-1:0] tb_weight_vec [0:FLAT_SIZE-1];
    logic signed [N-1:0] tb_bias_vec [0:0];

    logic signed [N-1:0] tb_input_vec2 [0:DENSE1_OUT-1];
    logic signed [N-1:0] tb_weight_vec2 [0:DENSE1_OUT-1];
    logic signed [N-1:0] tb_bias2 [0:0];

    // Dense module I/O
    logic dense_start, dense2_start;
    wire dense_done_wire, dense2_done_wire;
    wire signed [N-1:0] dense_out_wire, dense2_out_wire;

    // --------------------------
    // Activation module outputs
    // --------------------------
    wire signed [N-1:0] relu_out;
    wire signed [N-1:0] sigmoid_out;

    // --------------------------
    // Instantiate Dense + Activations
    // --------------------------
    dense #(.N(N), .Q(Q), .NUM_INPUTS(FLAT_SIZE)) dense_unit (
        .clk(clk),
        .reset(reset),
        .start(dense_start),
        .input_vec(tb_input_vec),
        .weight_vec(tb_weight_vec),
        .bias(tb_bias_vec[0]),
        .output_val(dense_out_wire),
        .done(dense_done_wire)
    );

    relu #(.N(N)) relu_inst (
        .din(dense_out_wire),
        .dout(relu_out)
    );

    dense #(.N(N), .Q(Q), .NUM_INPUTS(DENSE1_OUT)) dense_unit2 (
        .clk(clk),
        .reset(reset),
        .start(dense2_start),
        .input_vec(tb_input_vec2),
        .weight_vec(tb_weight_vec2),
        .bias(tb_bias2[0]),
        .output_val(dense2_out_wire),
        .done(dense2_done_wire)
    );

    sigmoid_lut #(.N(N), .Q(Q)) sigmoid_inst (
        .in_val(dense2_out_wire),
        .out_val(sigmoid_out)
    );

    // --------------------------
    // Load .mem files
    // --------------------------
    initial begin
        $display("[ACC] Loading mem files...");
        $readmemh("image_pixels.mem", feature_mem);
        $readmemh("dense1_w.mem", dense1_w_flat);
        $readmemh("dense1_b.mem", dense1_b);
        $readmemh("dense2_w.mem", dense2_w);
        $readmemh("dense2_b.mem", dense2_b);
        $display("[ACC] Mem load done. FLAT=%0d D1=%0d D1WT=%0d", FLAT_SIZE, DENSE1_OUT, D1_WTOTAL);
    end

    // --------------------------
    // FSM state control
    // --------------------------
    typedef enum logic [3:0] {
        S_IDLE = 4'd0,
        S_PREP_D1 = 4'd1,
        S_ASSERT_D1 = 4'd2,
        S_WAIT_D1 = 4'd3,
        S_STORE = 4'd4,
        S_PREP_D2 = 4'd5,
        S_ASSERT_D2 = 4'd6,
        S_WAIT_D2 = 4'd7,
        S_DONE = 4'd8
    } state_t;

    state_t state;
    int neuron_idx;
    int i;
    int base_idx;

    // --------------------------
    // FSM operation
    // --------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            done_out <= 0;
            final_out <= 0;
            dense_start <= 0;
            dense2_start <= 0;
            neuron_idx <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done_out <= 0;
                    if (start) begin
                        neuron_idx <= 0;
                        state <= S_PREP_D1;
                        $display("[ACC] S_IDLE -> start");
                    end
                end

                S_PREP_D1: begin
                    for (i = 0; i < FLAT_SIZE; i++) tb_input_vec[i] <= feature_mem[i];
                    base_idx = neuron_idx * FLAT_SIZE;
                    for (i = 0; i < FLAT_SIZE; i++) tb_weight_vec[i] <= dense1_w_flat[base_idx + i];
                    tb_bias_vec[0] <= dense1_b[neuron_idx];
                    dense_start <= 0;
                    $display("[ACC] PREP_D1 neuron=%0d base=%0d", neuron_idx, base_idx);
                    state <= S_ASSERT_D1;
                end

                S_ASSERT_D1: begin
                    dense_start <= 1;
                    $display("[ACC] ASSERT_D1 pulse start neuron=%0d", neuron_idx);
                    state <= S_WAIT_D1;
                end

                S_WAIT_D1: begin
                    dense_start <= 0;
                    if (dense_done_wire) begin
                        state <= S_STORE;
                        $display("[ACC] D1 done neuron=%0d out=%0d", neuron_idx, dense_out_wire);
                    end
                end

                S_STORE: begin
                    hidden[neuron_idx] <= relu_out; // Apply ReLU activation
                    $display("[ACC] STORE neuron=%0d val=%0d (ReLU=%0d)", neuron_idx, dense_out_wire, relu_out);
                    neuron_idx <= neuron_idx + 1;
                    if (neuron_idx + 1 < DENSE1_OUT) state <= S_PREP_D1;
                    else state <= S_PREP_D2;
                end

                S_PREP_D2: begin
                    for (i = 0; i < DENSE1_OUT; i++) begin
                        tb_input_vec2[i] <= hidden[i];
                        tb_weight_vec2[i] <= dense2_w[i];
                    end
                    tb_bias2[0] <= dense2_b[0];
                    dense2_start <= 0;
                    $display("[ACC] PREP_D2 last layer");
                    state <= S_ASSERT_D2;
                end

                S_ASSERT_D2: begin
                    dense2_start <= 1;
                    $display("[ACC] ASSERT_D2 pulse");
                    state <= S_WAIT_D2;
                end

                S_WAIT_D2: begin
                    dense2_start <= 0;
                    if (dense2_done_wire) begin
                        final_out <= sigmoid_out; // Apply sigmoid activation
                        done_out <= 1;
                        $display("[ACC] DONE final=%0d real=%f", sigmoid_out, $itor(sigmoid_out)/256.0);
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    // hold output
                end
            endcase
        end
    end

endmodule
