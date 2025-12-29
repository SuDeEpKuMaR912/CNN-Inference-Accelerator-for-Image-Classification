module relu #(
    parameter integer N = 16
)(
    input  wire                     clk,
    input  wire                     reset,

    input  wire signed [N-1:0]      din,
    input  wire                     din_valid,

    output reg  signed [N-1:0]      dout,
    output reg                      dout_valid
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        dout       <= 0;
        dout_valid <= 0;
    end else begin
        if (din_valid) begin
            dout       <= (din < 0) ? 0 : din;
            dout_valid <= 1;
        end else begin
            dout_valid <= 0;
        end
    end
end

endmodule

