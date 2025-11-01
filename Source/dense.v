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

    // Internal signals
    reg signed [N-1:0] current_in;
    reg signed [N-1:0] current_weight;
    reg [7:0] i;
    reg enable_mac;
    reg [1:0] state;

    wire signed [N-1:0] mac_out;

    // Instantiate MAC
    mac_manual #(N, Q) mac_unit (
        .clk(clk),
        .reset(reset),
        .enable(enable_mac),
        .in_data(current_in),
        .weight(current_weight),
        .mac_out(mac_out)
    );

    // FSM States
    localparam IDLE = 2'b00,
               LOAD = 2'b01,
               RUNNING = 2'b10,
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
        end 
        else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        i <= 0;
                        enable_mac <= 0;
                        current_in <= input_vec[0];
                        current_weight <= weight_vec[0];
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Wait one clock for data to settle
                    enable_mac <= 1;
                    state <= RUNNING;
                end

                RUNNING: begin
                    enable_mac <= 1;
                    if (i < NUM_INPUTS - 1) begin
                        i <= i + 1;
                        current_in <= input_vec[i+1];
                        current_weight <= weight_vec[i+1];
                    end 
                    else begin
                        enable_mac <= 0;
                        output_val <= mac_out + bias;
                        done <= 1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    enable_mac <= 0;
                    done <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule


