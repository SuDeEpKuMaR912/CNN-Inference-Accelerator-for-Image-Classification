`timescale 1ns / 1ps

module tb_accelerator;
    parameter CLK_PERIOD = 10;
    reg clk = 0, reset = 1, start = 0;
    wire done_out;
    wire signed [15:0] final_out;

    accelerator uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .done_out(done_out),
        .final_out(final_out)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $display("=== TB START ===");

        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        @(posedge clk);
        $display("[TB] Released reset");

        repeat(10) @(posedge clk);
        @(posedge clk) start = 1;
        @(posedge clk) start = 0;
        $display("[TB] Start pulse issued @ %0t", $time);

        fork
            begin
                wait(done_out);
                $display("[TB] DONE at %0t", $time);
                $display("[TB] final_out = %0d (real = %f)",
                         final_out, $itor(final_out)/256.0);
            end
            begin
                repeat(500000) @(posedge clk);
                $display("[TB] TIMEOUT - no done_out");
                $finish;
            end
        join_any
        disable fork;

        #100;
        $finish;
    end
endmodule
