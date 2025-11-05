`timescale 1ns / 1ps

module tb_accelerator;
    parameter CLK_PERIOD = 10; // 100 MHz
    reg clk = 0, reset = 1, start = 0;

    wire done_out;
    wire signed [15:0] final_out;

    // Instantiate DUT
    accelerator uut(
        .clk(clk),
        .reset(reset),
        .start(start),
        .done_out(done_out),
        .final_out(final_out)
    );

    // Clock
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $display("=== TB START ===");

        // Reset pulse
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        @(posedge clk);
        $display("[TB] Released reset");

        // Wait a bit then pulse start
        repeat(2) @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        $display("[TB] Start pulse issued @ %0t", $time);

        fork
            // Wait for done
            begin
                wait(done_out == 1);
                $display("[TB] DONE at %0t", $time);
                $display("[TB] final_out = %0d (real = %f)", final_out, $itor(final_out)/256.0);
                #50;
                $finish;
            end

            //Timeout guard
            begin
                repeat(50000) @(posedge clk); // 50k cycles = 500us sim
                $display("[TB] TIMEOUT - no done_out, stopping sim");
                $finish;
            end
        join_any

        disable fork;
    end
endmodule
