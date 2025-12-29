`timescale 1ns/1ps

module output_reg_axi #
(
    parameter integer N = 16
)
(
    input  wire                 S_AXI_ACLK,
    input  wire                 S_AXI_ARESETN,

    input  wire signed [N-1:0]  in_val,
    input  wire                 in_valid,

    input  wire [31:0]          S_AXI_AWADDR,
    input  wire                 S_AXI_AWVALID,
    output wire                 S_AXI_AWREADY,

    input  wire [31:0]          S_AXI_WDATA,
    input  wire [3:0]           S_AXI_WSTRB,
    input  wire                 S_AXI_WVALID,
    output wire                 S_AXI_WREADY,

    output reg  [1:0]           S_AXI_BRESP,
    output reg                  S_AXI_BVALID,
    input  wire                 S_AXI_BREADY,

    input  wire [31:0]          S_AXI_ARADDR,
    input  wire                 S_AXI_ARVALID,
    output reg                  S_AXI_ARREADY,

    output reg  [31:0]          S_AXI_RDATA,
    output reg                  S_AXI_RVALID,
    output wire [1:0]           S_AXI_RRESP,
    input  wire                 S_AXI_RREADY
);

    reg signed [N-1:0] result_reg;
    reg                result_valid_reg;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            result_reg       <= 0;
            result_valid_reg <= 0;
        end
        else if (in_valid) begin
            result_reg       <= in_val;
            result_valid_reg <= 1;
        end
    end

    assign S_AXI_AWREADY = 1'b1;
    assign S_AXI_WREADY  = 1'b1;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_BVALID <= 0;
            S_AXI_BRESP  <= 2'b00;
        end else begin
            if (S_AXI_WVALID && S_AXI_AWVALID) begin
                S_AXI_BVALID <= 1;
            end else if (S_AXI_BVALID && S_AXI_BREADY)
                S_AXI_BVALID <= 0;
        end
    end

    assign S_AXI_RRESP = 2'b00;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_ARREADY <= 0;
            S_AXI_RVALID  <= 0;
            S_AXI_RDATA   <= 0;
        end else begin

            if (S_AXI_ARVALID && !S_AXI_ARREADY) begin
                S_AXI_ARREADY <= 1;
                S_AXI_RVALID  <= 1;

                case (S_AXI_ARADDR[5:2])
                    4'h0: S_AXI_RDATA <= {16'd0, result_reg};
                    4'h1: S_AXI_RDATA <= {31'd0, result_valid_reg};
                    default: S_AXI_RDATA <= 32'd0;
                endcase
            end
            else begin
                S_AXI_ARREADY <= 0;

                if (S_AXI_RVALID && S_AXI_RREADY)
                    S_AXI_RVALID <= 0;
            end
        end
    end

endmodule
