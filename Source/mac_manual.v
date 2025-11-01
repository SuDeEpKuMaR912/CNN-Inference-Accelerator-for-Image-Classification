module mac_manual #(
    parameter N = 16,
    parameter Q = 8
)(
    input  wire clk,
    input  wire reset,
    input  wire enable,
    input  wire signed [N-1:0] in_data,
    input  wire signed [N-1:0] weight,
    output reg  signed [N-1:0] mac_out
);

    wire signed [N-1:0] mult_res;
    wire signed [N-1:0] add_res;

    // Reuse existing modules
    qmult #(Q, N) mult_unit (
        .a(in_data),
        .b(weight),
        .result(mult_res)
    );

    qadd #(N) add_unit (
        .a(mac_out),
        .b(mult_res),
        .result(add_res)
    );

    always @(posedge clk or posedge reset) begin
        if (reset)
            mac_out <= 0;
        else if (enable)
            mac_out <= add_res;
    end

endmodule
