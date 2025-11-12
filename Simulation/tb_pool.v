`timescale 1ns / 1ps
// -----------------------------------------------------------
// tb_pool.v
// Final Hierarchical 2x2 Max Pooling Testbench (patched for new pool.v)
// -----------------------------------------------------------
module tb_pool;

    // ---- Parameters ----
    localparam int N = 16;
    localparam int IN_SIZE = 8;
    localparam int OUT_SIDE = IN_SIZE / 2;
    localparam int OUT_CHANNELS = 4;
    localparam int PIXELS_PER_CH = IN_SIZE * IN_SIZE;

    // ---- DUT I/O ----
    reg clk = 0;
    reg reset = 1;
    reg signed [N-1:0] din;
    reg valid_in = 0;
    wire signed [N-1:0] pool_dout;
    wire pool_valid_out;

    // ---- Instantiate DUT ----
    pool #(
        .DATA_WIDTH(N),
        .IMG_WIDTH(IN_SIZE),
        .IMG_HEIGHT(IN_SIZE)
    ) dut (
        .clk(clk),
        .reset(reset),
        .din(din),
        .valid_in(valid_in),
        .pool_dout(pool_dout),
        .pool_valid_out(pool_valid_out)
    );

    // ---- Clock ----
    always #5 clk = ~clk; // 100 MHz

    // ---- Internal Variables ----
    integer ch, idx;
    reg signed [N-1:0] feat_mem [0:OUT_CHANNELS-1][0:PIXELS_PER_CH-1];
    integer pixel_no = 0;
    reg [31:0] cycle_count = 0;

    // ---- Test Procedure ----
    initial begin
        $display("=== TEST: 2x2 MAX POOLING (Combinational + Line Buffer) ===");

        // Generate simple gradient pattern per channel
        for (ch = 0; ch < OUT_CHANNELS; ch = ch + 1)
            for (idx = 0; idx < PIXELS_PER_CH; idx = idx + 1)
                feat_mem[ch][idx] = (idx + ch*10);

        // Reset
        reset = 1;
        #50;
        reset = 0;
        #50;

        // Feed all feature maps
        for (ch = 0; ch < OUT_CHANNELS; ch = ch + 1) begin
            $display("\n[TB] ===== Feeding Channel %0d =====", ch);
            for (idx = 0; idx < PIXELS_PER_CH; idx = idx + 1) begin
                @(posedge clk);
                din <= feat_mem[ch][idx];
                valid_in <= 1;
            end
            @(posedge clk);
            valid_in <= 0;
            repeat (20) @(posedge clk);  // pause between channels
        end

        $display("\n[TB] All channels fed. Waiting for remaining pool outputs...");
        repeat (200) @(posedge clk);
        $display("=== END OF TEST ===");
        $finish;
    end

    // ---- Print results ----
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;

        if (pool_valid_out) begin
            pixel_no <= pixel_no + 1;
            $display("[TB] Output #%0d @%0t -> int=%0d (Q8.8=%f)", pixel_no, $time, pool_dout, $itor(pool_dout)/256.0);

        end

        // Safety timeout
        if (cycle_count == 1_000_000) begin
            $display("[TB] TIMEOUT: Simulation aborted after 1M cycles");
            $finish;
        end
    end

endmodule
