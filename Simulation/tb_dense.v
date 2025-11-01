`timescale 1ns / 1ps
module tb_dense;

    parameter N = 16;
    parameter Q = 8;
    parameter NUM_INPUTS = 4;

    reg clk, reset, start;
    reg signed [N-1:0] input_vec [0:NUM_INPUTS-1];
    reg signed [N-1:0] weight_vec [0:NUM_INPUTS-1];
    reg signed [N-1:0] bias;
    wire signed [N-1:0] output_val;
    wire done;

    // Instantiate DUT
    dense #(N, Q, NUM_INPUTS) uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .input_vec(input_vec),
        .weight_vec(weight_vec),
        .bias(bias),
        .output_val(output_val),
        .done(done)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Simulation control
    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        #10 reset = 0;

        // -------------------------------
        // Q8.8 Encoded Inputs
        // -------------------------------
        // Example inputs: [1.0, 2.0, 3.0, 4.0]
        input_vec[0] = 16'sh0100; // 1.00
        input_vec[1] = 16'sh0200; // 2.00
        input_vec[2] = 16'sh0300; // 3.00
        input_vec[3] = 16'sh0400; // 4.00

        // Example weights: [0.5, 1.0, 0.75, -0.5]
        weight_vec[0] = 16'sh0080; // 0.50
        weight_vec[1] = 16'sh0100; // 1.00
        weight_vec[2] = 16'sh00C0; // 0.75
        weight_vec[3] = 16'shFF80; // -0.50

        bias = 16'sh0040; // 0.25

        // -------------------------------
        // Start Operation
        // -------------------------------
        #10 start = 1;
        #10 start = 0;

        // Wait for done
        wait (done == 1);
        #10;

        $display("---------------------------------------------------");
        $display("Dense Layer Output (Q8.8) = %0d", output_val);
        $display("Dense Layer Output (Real) = %0.3f", $itor(output_val)/256.0);
        $display("---------------------------------------------------");

        #20 $finish;
    end

endmodule
        
         
     