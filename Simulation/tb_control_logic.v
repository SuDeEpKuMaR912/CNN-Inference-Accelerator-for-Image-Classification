`timescale 1ns/1ps
module tb_control_logic;

    reg clk, reset, start, pixel_in_valid;
    wire conv_en, pool_en, dense_en, done, global_valid;

    control_logic #(.IMG_WIDTH(4), .IMG_HEIGHT(4)) uut (
        .clk(clk), .reset(reset), .start(start),
        .pixel_in_valid(pixel_in_valid),
        .conv_en(conv_en), .pool_en(pool_en),
        .dense_en(dense_en), .done(done), .global_valid(global_valid)
    );

    // Clock
    always #5 clk = ~clk;

    initial begin
        $display("Time state conv pool dense done valid");

        clk = 0;
        reset = 1; start = 0; pixel_in_valid = 0;
        #20 reset = 0;

        // Start CNN
        #10 start = 1; #10 start = 0;

        // Feed 4×4 = 16 pixels
        repeat (16) begin
            pixel_in_valid = 1;
            #10;
        end
        pixel_in_valid = 0;

        // Run extra cycles for pipeline
        #200;

        $finish;
    end

    always @(posedge clk) begin
        $display("t=%0t conv=%b pool=%b dense=%b done=%b valid=%b",
            $time, conv_en, pool_en, dense_en, done, global_valid);
    end

endmodule
