`timescale 1ns / 1ps

module accelerator #(
    parameter int N = 16,
    parameter int Q = 8,
    parameter int FLAT_SIZE = 16,    
    parameter int DENSE1_OUT = 4      
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    output logic done_out,
    output logic signed [N-1:0] final_out
);

    logic signed [N-1:0] feature_mem [0:FLAT_SIZE-1];
    localparam int D1_WTOTAL = FLAT_SIZE * DENSE1_OUT;
    logic signed [N-1:0] dense1_w_flat [0:D1_WTOTAL-1];
    logic signed [N-1:0] dense1_b [0:DENSE1_OUT-1];

    logic signed [N-1:0] dense2_w [0:DENSE1_OUT-1];
    logic signed [N-1:0] dense2_b [0:0];

    logic signed [N-1:0] hidden [0:DENSE1_OUT-1];

    logic signed [N-1:0] tb_input_vec  [0:FLAT_SIZE-1];
    logic signed [N-1:0] tb_weight_vec [0:FLAT_SIZE-1];
    logic signed [N-1:0] tb_bias_vec [0:0];

    logic signed [N-1:0] tb_input_vec2  [0:DENSE1_OUT-1];
    logic signed [N-1:0] tb_weight_vec2 [0:DENSE1_OUT-1];
    logic signed [N-1:0] tb_bias2 [0:0];

    wire signed [N-1:0] dense_out_wire;
    wire dense_done_wire;
    logic dense_start;

    wire signed [N-1:0] dense2_out_wire;
    wire dense2_done_wire;
    logic dense2_start;

    dense #(.N(N), .Q(Q), .NUM_INPUTS(FLAT_SIZE)) dense_unit (
        .clk(clk), .reset(reset), .start(dense_start),
        .input_vec(tb_input_vec), .weight_vec(tb_weight_vec),
        .bias(tb_bias_vec[0]), .output_val(dense_out_wire), .done(dense_done_wire)
    );

    dense #(.N(N), .Q(Q), .NUM_INPUTS(DENSE1_OUT)) dense_unit2 (
        .clk(clk), .reset(reset), .start(dense2_start),
        .input_vec(tb_input_vec2), .weight_vec(tb_weight_vec2),
        .bias(tb_bias2[0]), .output_val(dense2_out_wire), .done(dense2_done_wire)
    );

    initial begin
        $display("[ACC] Loading mem files...");
        $readmemh("image_pixels.mem", feature_mem);
        $readmemh("dense1_w.mem", dense1_w_flat);
        $readmemh("dense1_b.mem", dense1_b);
        $readmemh("dense2_w.mem", dense2_w);
        $readmemh("dense2_b.mem", dense2_b);
        #1 $display("[ACC] Mem load done. FLAT=%0d D1=%0d D1WT=%0d",
                   FLAT_SIZE, DENSE1_OUT, D1_WTOTAL);
    end

    typedef enum logic [3:0] {
        S_IDLE=0, S_PREP_D1, S_ASSERT_D1, S_WAIT_D1, S_STORE,
        S_PREP_D2, S_ASSERT_D2, S_WAIT_D2, S_DONE
    } state_t;

    (* mark_debug = "true" *) state_t state;
    int neuron_idx, i, base_idx;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE; done_out <= 0; final_out <= 0;
            dense_start <= 0; dense2_start <= 0; neuron_idx <= 0;
        end else begin
            case(state)

            S_IDLE: begin
                done_out <= 0; dense_start <= 0; dense2_start <= 0;
                if (start) begin
                    $display("[ACC] S_IDLE -> start");
                    neuron_idx <= 0; state <= S_PREP_D1;
                end
            end

            S_PREP_D1: begin
                for (i = 0; i < FLAT_SIZE; i++) tb_input_vec[i] <= feature_mem[i];
                base_idx = neuron_idx * FLAT_SIZE;
                for (i = 0; i < FLAT_SIZE; i++) tb_weight_vec[i] <= dense1_w_flat[base_idx+i];
                tb_bias_vec[0] <= dense1_b[neuron_idx];
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
                    $display("[ACC] D1 done neuron=%0d out=%0d", neuron_idx, dense_out_wire);
                    state <= S_STORE;
                end else
                    $display("[ACC] wait D1 neuron=%0d", neuron_idx);
            end

            S_STORE: begin
                hidden[neuron_idx] <= dense_out_wire;
                $display("[ACC] STORE neuron=%0d val=%0d", neuron_idx, dense_out_wire);
                neuron_idx <= neuron_idx + 1;
                state <= (neuron_idx+1 < DENSE1_OUT) ? S_PREP_D1 : S_PREP_D2;
            end

            S_PREP_D2: begin
                for (i = 0; i < DENSE1_OUT; i++) begin
                    tb_input_vec2[i] <= hidden[i];
                    tb_weight_vec2[i] <= dense2_w[i];
                end
                tb_bias2[0] <= dense2_b[0];
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
                    final_out <= dense2_out_wire; done_out <= 1;
                    $display("[ACC] DONE final=%0d real=%f", dense2_out_wire, $itor(dense2_out_wire)/256.0);
                    state <= S_DONE;
                end else
                    $display("[ACC] wait D2...");
            end

            S_DONE: begin end

            endcase
        end
    end
endmodule
