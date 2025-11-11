`timescale 1ns / 1ps
// -----------------------------------------------------------
// tb_conv_debug.v  -  Debug-focused testbench for conv.v
// Works with the flattened-bus sequential conv module.
// -----------------------------------------------------------

module tb_conv;

    // ---- Parameters ----
    localparam int N = 16;
    localparam int Q = 8;
    localparam int IMG_SIZE = 8;
    localparam int K = 3;
    localparam int OUT_CHANNELS = 4;
    localparam int OUT_SIDE = IMG_SIZE - K + 1;

    // ---- Signals ----
    reg clk = 0;
    reg reset = 1;
    reg start = 0;
    wire done;

    // Flattened packed buses
    reg  signed [N*IMG_SIZE*IMG_SIZE-1:0] feat_mem_flat;
    reg  signed [N*OUT_CHANNELS*K*K-1:0] weight_mem_flat;
    reg  signed [N*OUT_CHANNELS-1:0] bias_mem_flat;
    wire signed [N*OUT_CHANNELS*OUT_SIDE*OUT_SIDE-1:0] out_mem_flat;

    // ---- Clock ----
    always #5 clk = ~clk;  // 100 MHz

    // ---- DUT ----
    conv #(
        .N(N), .Q(Q),
        .IMG_SIZE(IMG_SIZE),
        .K(K),
        .OUT_CHANNELS(OUT_CHANNELS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .feat_mem_flat(feat_mem_flat),
        .weight_mem_flat(weight_mem_flat),
        .bias_mem_flat(bias_mem_flat),
        .out_mem_flat(out_mem_flat),
        .done(done)
    );

    // ---- Test Procedure ----
    integer i, j, c, k;
    integer cycle_count = 0;
    localparam MAX_CYCLES = 100000;  // quick timeout for debug

    initial begin
        $display("\n=== DEBUG TEST: CONV MODULE (8x8 -> 6x6 OUT, 4 FILTERS) ===\n");

        // Reset
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        $display("[TB] Reset released @ %0t", $time);

        // Initialize feature map
        for (i = 0; i < IMG_SIZE*IMG_SIZE; i = i + 1)
            feat_mem_flat[i*N +: N] = i * 8;

        // Initialize weights and biases
        for (c = 0; c < OUT_CHANNELS; c = c + 1)
            for (k = 0; k < K*K; k = k + 1)
                weight_mem_flat[(c*K*K + k)*N +: N] = (k + c + 1);

        for (c = 0; c < OUT_CHANNELS; c = c + 1)
            bias_mem_flat[c*N +: N] = c * 32;

        // Start
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        $display("[TB] Start pulse issued @ %0t", $time);

        // ---- Main Monitor ----
        fork
            begin
                while (!done && cycle_count < MAX_CYCLES) begin
                    @(posedge clk);
                    cycle_count++;
                    if (cycle_count % 1000 == 0)
                        $display("[TB] Cycle %0d ... still running", cycle_count);
                end

                if (done)
                    $display("\n[TB] DONE detected @ %0t after %0d cycles\n", $time, cycle_count);
                else begin
                    $display("\n[TB] TIMEOUT @ %0t after %0d cycles\n", $time, cycle_count);
                    $finish;
                end
            end

            begin : DUT_MONITOR
                forever begin
                    @(posedge clk);
                    // Print DUT's internal FSM progress
                    $display("[FSM] f=%0d oy=%0d ox=%0d ky=%0d kx=%0d acc=%0d done=%b",
                              dut.f, dut.oy, dut.ox, dut.ky, dut.kx, dut.acc, dut.done);
                    if (dut.done) disable DUT_MONITOR;
                end
            end
        join_any
        disable fork;

        // ---- Output results ----
        for (c = 0; c < OUT_CHANNELS; c = c + 1) begin
            $display("----- OUTPUT FEATURE MAP %0d -----", c);
            for (i = 0; i < OUT_SIDE; i = i + 1) begin
                for (j = 0; j < OUT_SIDE; j = j + 1)
                    $write("%6d ", out_mem_flat[(c*OUT_SIDE*OUT_SIDE + (i*OUT_SIDE + j))*N +: N]);
                $write("\n");
            end
        end

        $display("\n=== TEST COMPLETE ===");
        #50;
        $finish;
    end

endmodule
