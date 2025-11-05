`timescale 1ns / 1ps
module dense #(
    parameter N = 16,
    parameter Q = 8,
    parameter NUM_INPUTS = 4
)(
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire signed [N-1:0] input_vec [0:NUM_INPUTS-1],
    input  wire signed [N-1:0] weight_vec [0:NUM_INPUTS-1],
    input  wire signed [N-1:0] bias,
    output reg  signed [N-1:0] output_val,
    output reg  done
);

    reg signed [N-1:0] current_in, current_weight;
    reg [15:0] i;
    reg enable_mac;
    reg [1:0] state;

    wire signed [N-1:0] mac_out;

    mac_manual #(N, Q) mac_unit (
        .clk(clk),
        .reset(reset),
        .enable(enable_mac),
        .in_data(current_in),
        .weight(current_weight),
        .mac_out(mac_out)
    );

    localparam IDLE = 2'b00,
               LOAD = 2'b01,
               RUN  = 2'b10,
               DONE = 2'b11;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            i <= 0;
            enable_mac <= 0;
            done <= 0;
            output_val <= 0;
            current_in <= 0;
            current_weight <= 0;
            state <= IDLE;
        end else begin
            case (state)

                IDLE: begin
                    done <= 0;
                    enable_mac <= 0;
                    if (start) begin
                        i <= 0;
                        current_in <= input_vec[0];
                        current_weight <= weight_vec[0];
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    enable_mac <= 1;   // one MAC on first pair
                    state <= RUN;
                end

                RUN: begin
                    if (i < NUM_INPUTS - 1) begin
                        i <= i + 1;
                        current_in <= input_vec[i+1];
                        current_weight <= weight_vec[i+1];
                        enable_mac <= 1;
                    end else begin
                        enable_mac <= 0;
                        state <= DONE;
                    end
                end

                DONE: begin
                    output_val <= mac_out + bias;
                    done <= 1;
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
