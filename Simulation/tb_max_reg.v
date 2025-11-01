`timescale 1ns / 1ps
module tb_max_reg;
    parameter N = 16;

    reg clk;
    reg reset;
    reg valid;
    reg signed [N-1:0] din;
    wire signed [N-1:0] max_out;

    // DUT
    max_reg #(N) uut (
        .clk(clk),
        .reset(reset),
        .din(din),
        .valid(valid),
        .max_out(max_out)
    );

    // Generate clock
    always #5 clk = ~clk;

    // Helper task to print Q8.8 as real
    task print_q8;
        input signed [N-1:0] val;
        real r;
        begin
            r = $itor(val) / 256.0;
            $display("  Q8.8 = 0x%0h => %0d (real = %0.3f)", val, val, r);
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        valid = 0;
        din = 0;
        #20;

        reset = 0;
        #10;

        $display("Feeding sequence (Q8.8 values): 3, 7, 5, 2");
        // Convert to Q8.8 integers: value * 256
        // 3.0 -> 0x0300, 7.0 -> 0x0700, etc.
        valid = 1;

        din = 16'sh0300; #10; // 3.0
        $display("After input 3.0 -> max_out = %0d (real=%0.3f)", max_out, $itor(max_out)/256.0);

        din = 16'sh0700; #10; // 7.0
        $display("After input 7.0 -> max_out = %0d (real=%0.3f)", max_out, $itor(max_out)/256.0);

        din = 16'sh0500; #10; // 5.0
        $display("After input 5.0 -> max_out = %0d (real=%0.3f)", max_out, $itor(max_out)/256.0);

        din = 16'sh0200; #10; // 2.0
        $display("After input 2.0 -> max_out = %0d (real=%0.3f)", max_out, $itor(max_out)/256.0);

        valid = 0; #10;

        $display("Final stored max (Q8.8): %0d, Real = %0.3f", max_out, $itor(max_out)/256.0);
        $finish;
    end

endmodule
