`timescale 1ns/1ps
module tb_pooler_max2x2;
    reg clk, reset, valid_in;
    reg signed [15:0] din;     // Q8.8 input pixels
    wire signed [15:0] dout;   // Q8.8 output (max of 2x2)
    wire valid_out;

    // Instantiate the DUT (Device Under Test)
    pooler_max2x2 #(16) uut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .din(din),
        .dout(dout),
        .valid_out(valid_out)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Helper task to display Q8.8 values as real numbers
    task display_q8_8;
        input signed [15:0] val;
        real real_val;
        begin
            real_val = $itor(val) / 256.0;
            $display("   (%0d -> %0.4f)", val, real_val);
        end
    endtask

    initial begin
        $display("===== Starting Pooler Max 2x2 Test (Q8.8) =====");
        clk = 0;
        reset = 1;
        valid_in = 0;
        din = 0;
        #20 reset = 0;

        // Feed one 2x2 block of Q8.8 pixel values
        valid_in = 1;

        // Example 2x2 block: [0.5, 1.2; -0.3, 0.8]
        din = 16'sh0080;  #10;  // 0.5 * 256 = 128 = 0x0080
        din = 16'sh0133;  #10;  // 1.2 * 256 = 307 = 0x0133
        din = -16'sh004C; #10;  // -0.3 * 256 = -76 = 0xFFB4
        din = 16'sh00CC;  #10;  // 0.8 * 256 = 204 = 0x00CC

        valid_in = 0; #10;

        // Wait for valid_out
        wait(valid_out);
        $display("Max of 2x2 block (Q8.8):");
        display_q8_8(dout);

        #20;
        $display("===== Test Completed =====");
        $finish;
    end
endmodule
