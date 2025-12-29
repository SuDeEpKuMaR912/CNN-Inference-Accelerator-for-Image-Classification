`timescale 1ns / 1ps

module dense2 #(
    parameter integer N = 16,
    parameter integer Q = 8,
    parameter integer ADDR_BITS = 20
)(
    input  wire                   clk,
    input  wire                   reset,

    input  wire                   start,            
    input  wire [31:0]            num_inputs,       
    input  wire [ADDR_BITS-1:0]   weight_base_addr, 
    input  wire [ADDR_BITS-1:0]   bias_base_addr,   

    output reg                    done,
    output wire                   busy,

    input  wire signed [N-1:0]    s_axis_tdata,
    input  wire                   s_axis_tvalid,
    output reg                    s_axis_tready,

    output reg signed [N-1:0]     m_axis_tdata,
    output reg                    m_axis_tvalid,
    input  wire                   m_axis_tready,

    output reg [ADDR_BITS-1:0]    weight_addr,
    input  wire signed [N-1:0]    weight_dout,

    output reg [ADDR_BITS-1:0]    bias_addr,
    input  wire signed [N-1:0]    bias_dout
);

    typedef enum logic [1:0] {IDLE, STREAM_IN, FINAL_OUT, DONE_ST} state_t;
    state_t state;

    assign busy = (state != IDLE);

    integer in_cnt;

    reg signed [47:0] acc;     
    reg signed [47:0] acc_shift;

    reg signed [N-1:0] current_input, current_weight;
    reg weight_read_pending;

    wire signed [N-1:0] prod_q;
    qmult #( .Q(Q), .N(N) ) qmult_inst (
        .a(current_input),
        .b(current_weight),
        .result(prod_q)
    );

    reg signed [N-1:0] acc_trunc;

    wire signed [N-1:0] qadd_res;
    qadd #( .N(N) ) qadd_inst (
        .a(acc_trunc),
        .b(bias_dout),
        .result(qadd_res)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done  <= 0;
            s_axis_tready <= 0;
            m_axis_tvalid <= 0;
            m_axis_tdata  <= 0;
            weight_addr   <= 0;
            bias_addr     <= 0;
            in_cnt <= 0;
            acc <= 0;
            acc_shift <= 0;
            current_input <= 0;
            current_weight <= 0;
            weight_read_pending <= 0;
        end else begin

            m_axis_tvalid <= 0;
            s_axis_tready <= 0;

            if (weight_read_pending) begin
                current_weight <= weight_dout;
                weight_read_pending <= 0;
            end

            case (state)

                IDLE: begin
                    done <= 0;
                    acc <= 0;
                    in_cnt <= 0;

                    if (start) begin
                        // prefetch bias
                        bias_addr <= bias_base_addr;
                        state <= STREAM_IN;
                    end
                end

                STREAM_IN: begin
                    s_axis_tready <= 1;

                    if (s_axis_tvalid && s_axis_tready) begin
                        current_input <= s_axis_tdata;

                        weight_addr <= weight_base_addr + in_cnt;
                        weight_read_pending <= 1;

                        acc <= acc + $signed({{(48-N){prod_q[N-1]}}, prod_q});

                        in_cnt <= in_cnt + 1;

                        if (in_cnt == num_inputs) begin
                            acc_shift <= acc >>> Q;
                            acc_trunc <= acc_shift[N-1:0]; 

                            state <= FINAL_OUT;
                        end
                    end
                end

                FINAL_OUT: begin
                    m_axis_tdata <= qadd_res;
                    m_axis_tvalid <= 1;

                    if (m_axis_tready) begin
                        state <= DONE_ST;
                    end
                end

                DONE_ST: begin
                    done <= 1;
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
