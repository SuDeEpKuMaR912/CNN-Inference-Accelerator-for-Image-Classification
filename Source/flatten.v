`timescale 1ns / 1ps
module flatten #(
    parameter WIDTH  = 4,
    parameter HEIGHT = 4,
    parameter N = 16
)(
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire signed [N*WIDTH*HEIGHT-1:0] feature_map_flat,  
    output reg  signed [N-1:0] flat_out,
    output reg  done
);

    integer i;
    reg [15:0] idx;
    reg active;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            idx <= 0;
            flat_out <= 0;
            done <= 0;
            active <= 0;
        end else if (start) begin
            idx <= 0;
            done <= 0;
            active <= 1;
        end else if (active) begin
            flat_out <= feature_map_flat[(idx+1)*N-1 -: N];  // extract N bits at a time
            idx <= idx + 1;
            if (idx == (WIDTH*HEIGHT - 1)) begin
                done <= 1;
                active <= 0;
            end
        end
    end
endmodule


