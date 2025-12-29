`timescale 1ns / 1ps

module flatten #(
    parameter N = 16,
    parameter TOTAL_ELEMS = 36992      
)(
    input  wire clk,
    input  wire reset,
    input  wire start,

    input  wire signed [N-1:0] din,
    input  wire                din_valid,

    output reg  signed [N-1:0] dout,
    output reg                 dout_valid,
    input  wire                dout_ready,

    output reg                 done
);

    reg active;
    reg [31:0] count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            active     <= 0;
            count      <= 0;
            dout       <= 0;
            dout_valid <= 0;
            done       <= 0;
        end

        else if (start) begin
            active     <= 1;
            count      <= 0;
            done       <= 0;
        end

        else if (active) begin

            
            if (din_valid) begin
                
                if (!dout_valid || (dout_valid && dout_ready)) begin
                    dout       <= din;
                    dout_valid <= 1;
                    count      <= count + 1;
                end
            end

            
            if (count == TOTAL_ELEMS && dout_valid && dout_ready) begin
                active     <= 0;
                dout_valid <= 0;
                done       <= 1;
            end
        end

        else begin
            dout_valid <= 0;
        end
    end

endmodule
