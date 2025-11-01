`timescale 1ns / 1ps
module tb_mac_manual;

    reg clk, reset, enable;
    reg signed [15:0] in_data, weight;
    wire signed [15:0] mac_out;

    mac_manual uut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .in_data(in_data),
        .weight(weight),
        .mac_out(mac_out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; reset = 1; enable = 0;
        in_data = 0; weight = 0;
        #10 reset = 0;

        // Example: Q8.8 values (1.0 * 2.0) + (1.5 * 0.5)
        enable = 1;

        in_data = 16'sh0100; weight = 16'sh0200; #10;  // 1.0 × 2.0
        in_data = 16'sh0180; weight = 16'sh0080; #10;  // 1.5 × 0.5
        enable = 0;

        #10;
        $display("MAC Output (Q8.8) = %0d, Real ≈ %0.3f",
                 mac_out, $itor(mac_out)/256.0);
        $finish;
    end

endmodule

