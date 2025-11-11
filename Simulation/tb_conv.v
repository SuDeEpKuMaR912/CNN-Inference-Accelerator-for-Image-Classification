`timescale 1ns / 1ps

module tb_conv;

    // Parameters
    parameter N = 16;
    parameter Q = 8;
    parameter IMG_SIZE = 8;
    parameter K = 3;
    parameter OUT_CHANNELS = 4;

    parameter OUT_SIDE = IMG_SIZE - K + 1;
    parameter FEAT_ELEMS = IMG_SIZE * IMG_SIZE;
    parameter K_ELEMS = K * K;

    // Clock/reset/start
    reg clk = 0;
    reg reset = 1;
    reg start = 0;

    // Flattened buses
    wire signed [N*IMG_SIZE*IMG_SIZE-1:0] feat_mem_flat_w;
    wire signed [N*OUT_CHANNELS*K*K-1:0]  weight_mem_flat_w;
    wire signed [N*OUT_CHANNELS-1:0]      bias_mem_flat_w;
    wire signed [N*OUT_CHANNELS*(OUT_SIDE)*(OUT_SIDE)-1:0] out_mem_flat_w;
    wire done_w;

    // Instantiate DUT
    conv #(
        .N(N),
        .Q(Q),
        .IMG_SIZE(IMG_SIZE),
        .K(K),
        .OUT_CHANNELS(OUT_CHANNELS)
    ) uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .feat_mem_flat(feat_mem_flat_w),
        .weight_mem_flat(weight_mem_flat_w),
        .bias_mem_flat(bias_mem_flat_w),
        .out_mem_flat(out_mem_flat_w),
        .done(done_w)
    );

    // Local memories
    reg signed [N-1:0] feat_mem [0:FEAT_ELEMS-1];
    reg signed [N-1:0] weight_mem [0:OUT_CHANNELS*K_ELEMS-1];
    reg signed [N-1:0] bias_mem [0:OUT_CHANNELS-1];

    reg signed [N*IMG_SIZE*IMG_SIZE-1:0] feat_mem_flat;
    reg signed [N*OUT_CHANNELS*K*K-1:0]  weight_mem_flat;
    reg signed [N*OUT_CHANNELS-1:0]      bias_mem_flat;

    assign feat_mem_flat_w   = feat_mem_flat;
    assign weight_mem_flat_w = weight_mem_flat;
    assign bias_mem_flat_w   = bias_mem_flat;

    // Clock generation
    always #5 clk = ~clk;

    // Loop variables
    integer i, f, k, oy, ox;
    integer cycle;
    integer timeout_cycles;
    integer out_index;
    integer val;

    // Task: pack feature, weight, and bias arrays into flattened buses
    task pack_flat_buses;
        integer idx;
        begin
            feat_mem_flat = 0;
            for (idx = 0; idx < FEAT_ELEMS; idx = idx + 1)
                feat_mem_flat[idx*N +: N] = feat_mem[idx];

            weight_mem_flat = 0;
            for (idx = 0; idx < OUT_CHANNELS*K_ELEMS; idx = idx + 1)
                weight_mem_flat[idx*N +: N] = weight_mem[idx];

            bias_mem_flat = 0;
            for (idx = 0; idx < OUT_CHANNELS; idx = idx + 1)
                bias_mem_flat[idx*N +: N] = bias_mem[idx];
        end
    endtask

    // Test procedure
    initial begin
        // Initialize feature map with 1..64
        for (i = 0; i < FEAT_ELEMS; i = i + 1)
            feat_mem[i] = i + 1;

        // Initialize weights and biases
        for (f = 0; f < OUT_CHANNELS; f = f + 1) begin
            for (k = 0; k < K_ELEMS; k = k + 1)
                weight_mem[f*K_ELEMS + k] = (f*K_ELEMS) + (k + 1);
            bias_mem[f] = f * 16;
        end

        pack_flat_buses();

        $display("=== TEST: CONV MODULE (%0dx%0d -> %0d OUT, %0d FILTERS) ===",
                 IMG_SIZE, IMG_SIZE, OUT_SIDE, OUT_CHANNELS);

        reset = 1; start = 0;
        #20 reset = 0; #20;

        $display("[TB] Applying start pulse @ %0t", $time);
        start = 1; #10; start = 0;

        // Wait for done or timeout
        timeout_cycles = 5000000;
        cycle = 0;

        while (!done_w && cycle < timeout_cycles) begin
            @(posedge clk);
            cycle = cycle + 1;
            if ((cycle % 100000) == 0)
                $display("[TB] progress: %0d cycles elapsed...", cycle);
        end

        if (!done_w)
            $display("[TB] TIMEOUT after %0d cycles -- aborting.", cycle);
        else
            $display("[TB] DONE detected @ %0t after %0d cycles", $time, cycle);

        $display("");
        for (f = 0; f < OUT_CHANNELS; f = f + 1) begin
            $display("----- OUTPUT FEATURE MAP %0d -----", f);
            for (oy = 0; oy < OUT_SIDE; oy = oy + 1) begin
                for (ox = 0; ox < OUT_SIDE; ox = ox + 1) begin
                    out_index = f*OUT_SIDE*OUT_SIDE + oy*OUT_SIDE + ox;
                    val = $signed(out_mem_flat_w[out_index*N +: N]);
                    $write("%6d ", val);
                end
                $write("\n");
            end
        end

        $display("=== TEST COMPLETE ===");
        #100 $finish;
    end

endmodule
