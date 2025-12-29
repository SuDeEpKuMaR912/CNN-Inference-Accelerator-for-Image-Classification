module dense #(
    parameter int N = 16,
    parameter int Q = 8,
    parameter int NUM_INPUTS  = 36992,
    parameter int NUM_NEURONS = 512
)(
    input  wire                clk,
    input  wire                reset,
    input  wire                start,

    // Activations from flatten
    input  wire signed [N-1:0] din,
    input  wire                din_valid,
    output wire                din_ready,

    // Weights stream (from DMA/DDR)
    input  wire signed [N-1:0] w_tdata,
    input  wire                w_tvalid,
    output wire                w_tready,

    // Output neuron values
    output reg  signed [N-1:0] dout,
    output reg                 dout_valid,

    output reg                 busy,
    output reg                 done
);

    localparam int INPUTS_LOG2  = $clog2(NUM_INPUTS);
    localparam int NEURONS_LOG2 = $clog2(NUM_NEURONS);

    // simple FSM
    typedef enum logic [1:0] {S_IDLE, S_RUN, S_DONE} state_t;
    state_t state;

    // counters
    reg [INPUTS_LOG2-1:0]   idx;
    reg [NEURONS_LOG2-1:0]  neuron;

    // accumulator
    reg  signed [N-1:0] acc;

    // qmult: fixed-point multiply
    wire signed [N-1:0] prod;
    qmult #(.Q(Q), .N(N)) mul_i (
        .a(din),
        .b(w_tdata),
        .result(prod)
    );

    // qadd: acc + prod
    wire signed [N-1:0] sum;
    qadd #(.N(N)) add_i (
        .a(acc),
        .b(prod),
        .result(sum)
    );

    // back-pressure: we only accept data in RUN state
    assign din_ready  = (state == S_RUN);
    assign w_tready   = (state == S_RUN);

    // consume when both streams have valid data
    wire step_en = (state == S_RUN) && din_valid && w_tvalid;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= S_IDLE;
            busy       <= 1'b0;
            done       <= 1'b0;
            dout       <= '0;
            dout_valid <= 1'b0;
            idx        <= '0;
            neuron     <= '0;
            acc        <= '0;
        end else begin
            dout_valid <= 1'b0;  // default low each cycle
            done       <= 1'b0;  // done is a pulse

            case (state)
                //----------------------------------
                S_IDLE: begin
                    busy   <= 1'b0;
                    idx    <= '0;
                    neuron <= '0;
                    acc    <= '0;

                    if (start) begin
                        busy   <= 1'b1;
                        state  <= S_RUN;
                    end
                end

                //----------------------------------
                S_RUN: begin
                    if (step_en) begin
                        // we have one activation + one weight
                        if (idx == NUM_INPUTS-1) begin
                            // final MAC for this neuron -> sum is final output
                            dout       <= sum;
                            dout_valid <= 1'b1;

                            // prepare for next neuron
                            idx <= '0;
                            acc <= '0;

                            if (neuron == NUM_NEURONS-1) begin
                                // last neuron complete
                                busy   <= 1'b0;
                                done   <= 1'b1;
                                state  <= S_DONE;
                            end else begin
                                neuron <= neuron + 1'b1;
                            end
                        end else begin
                            // accumulate and continue inputs for this neuron
                            acc <= sum;
                            idx <= idx + 1'b1;
                        end
                    end
                end

                //----------------------------------
                S_DONE: begin
                    // wait for start to be deasserted and asserted again
                    if (!start) begin
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
