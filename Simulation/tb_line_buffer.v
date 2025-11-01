`timescale 1ns / 1ps
module tb_line_buffer;

    reg clk, reset;
    reg signed [15:0] din;
    wire signed [9*16-1:0] window_flat;

    line_buffer #(16, 4) uut (
        .clk(clk),
        .reset(reset),
        .din(din),
        .window_flat(window_flat)
    );

    always #5 clk = ~clk;

    integer i;
    reg signed [15:0] pixels [0:15]; // 4x4 image

    // Function to extract each 16-bit value from window_flat
    function signed [15:0] get_pix;
        input integer idx;
        begin
            get_pix = window_flat[(idx+1)*16-1 -: 16];
        end
    endfunction

    initial begin
        for (i = 0; i < 16; i = i + 1)
            pixels[i] = (i + 1) <<< 8; // Q8.8 values

        clk = 0;
        reset = 1;
        din = 0;
        #10 reset = 0;

        for (i = 0; i < 16; i = i + 1) begin
            din = pixels[i];
            #10;
            $display("Pixel=%0d => Window: [%0d,%0d,%0d | %0d,%0d,%0d | %0d,%0d,%0d]",
                din,
                get_pix(0), get_pix(1), get_pix(2),
                get_pix(3), get_pix(4), get_pix(5),
                get_pix(6), get_pix(7), get_pix(8)
            );
        end
        $finish;
    end

endmodule
