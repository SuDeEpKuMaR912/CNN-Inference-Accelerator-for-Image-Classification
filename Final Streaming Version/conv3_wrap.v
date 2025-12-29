`timescale 1ns / 1ps

module conv3_wrap #(
    parameter int N          = 16,
    parameter int Q          = 8,
    parameter int IMG_WIDTH  = 36,
    parameter int IMG_HEIGHT = 36,
    parameter int K          = 3,
    parameter int IN_CH      = 64,
    parameter int OUT_CH     = 128,
    parameter int ADDR_WIDTH = 32
)(
    input  wire                     s_axi_aclk,
    input  wire                     s_axi_aresetn,

    // AXI4-Lite Write Address
    input  wire [31:0]              s_axi_awaddr,
    input  wire                     s_axi_awvalid,
    output reg                      s_axi_awready,

    // AXI4-Lite Write Data
    input  wire [31:0]              s_axi_wdata,
    input  wire [3:0]               s_axi_wstrb,
    input  wire                     s_axi_wvalid,
    output reg                      s_axi_wready,

    // AXI4-Lite Write Response
    output reg  [1:0]               s_axi_bresp,
    output reg                      s_axi_bvalid,
    input  wire                     s_axi_bready,

    // AXI4-Lite Read Address
    input  wire [31:0]              s_axi_araddr,
    input  wire                     s_axi_arvalid,
    output reg                      s_axi_arready,

    // AXI4-Lite Read Data
    output reg  [31:0]              s_axi_rdata,
    output reg  [1:0]               s_axi_rresp,
    output reg                      s_axi_rvalid,
    input  wire                     s_axi_rready,

    // Stream-style pixel input
    input  wire signed [N-1:0]      din,
    input  wire                     din_valid,
    input  wire                     start_external,
    // Conv output
    output wire signed [N-1:0]      dout,
    output wire                     dout_valid,

    output wire                     conv_busy,
    output wire                     conv_done
);

    // ---------------------------
    // Register Map
    // ---------------------------
    localparam ADDR_CONTROL = 32'h00;  // bit0 = start
    localparam ADDR_STATUS  = 32'h04;  // {done, busy}
    localparam ADDR_W_ADDR  = 32'h10;
    localparam ADDR_W_DATA  = 32'h14;
    localparam ADDR_W_WR    = 32'h18;
    localparam ADDR_B_ADDR  = 32'h1C;
    localparam ADDR_B_DATA  = 32'h20;
    localparam ADDR_B_WR    = 32'h24;

    // ---------------------------
    // Internal registers
    // ---------------------------
    reg [31:0] reg_control;
    reg [31:0] reg_w_addr;
    reg [31:0] reg_w_data;
    reg [31:0] reg_b_addr;
    reg [31:0] reg_b_data;

    reg done_latched;

    // ---------------------------------------------------------------
    // Internal strobe registers (set by AXI write, pulsed 1 cycle)
    // ---------------------------------------------------------------
    reg c3_pulse_start_reg, c3_pulse_start;
    reg c3_pulse_w_wr_reg, c3_pulse_w_wr;
    reg c3_pulse_b_wr_reg, c3_pulse_b_wr;

    // ---------------------------
    // AXI Write handshake
    // ---------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            s_axi_awready <= 1'b0;
        else
            s_axi_awready <= (!s_axi_awready && s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid);
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            s_axi_wready <= 1'b0;
        else
            s_axi_wready <= (!s_axi_wready && s_axi_wvalid && s_axi_awvalid && !s_axi_bvalid);
    end

    // ---------------------------
    // AXI Write logic
    // ---------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_bvalid      <= 1'b0;
            s_axi_bresp       <= 2'b00;
            reg_control       <= 0;
            reg_w_addr        <= 0;
            reg_w_data        <= 0;
            reg_b_addr        <= 0;
            reg_b_data        <= 0;
            c3_pulse_start_reg   <= 0;
            c3_pulse_w_wr_reg    <= 0;
            c3_pulse_b_wr_reg    <= 0;
        end else begin

            if (s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid) begin

                case (s_axi_awaddr)
                    ADDR_CONTROL: begin
                        reg_control <= s_axi_wdata;
                        if (s_axi_wdata[0])
                            c3_pulse_start_reg <= 1'b1;
                    end

                    ADDR_W_ADDR: reg_w_addr <= s_axi_wdata;
                    ADDR_W_DATA: reg_w_data <= s_axi_wdata;

                    ADDR_W_WR: if (s_axi_wdata[0])
                                   c3_pulse_w_wr_reg <= 1'b1;

                    ADDR_B_ADDR: reg_b_addr <= s_axi_wdata;
                    ADDR_B_DATA: reg_b_data <= s_axi_wdata;

                    ADDR_B_WR: if (s_axi_wdata[0])
                                   c3_pulse_b_wr_reg <= 1'b1;

                    default: ;
                endcase

                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // ---------------------------------------------
    // Pulse generator - produces 1-cycle pulses
    // ---------------------------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            c3_pulse_start    <= 0;
            c3_pulse_w_wr     <= 0;
            c3_pulse_b_wr     <= 0;
            c3_pulse_start_reg<= 0;
            c3_pulse_w_wr_reg <= 0;
            c3_pulse_b_wr_reg <= 0;
        end else begin
            c3_pulse_start <= c3_pulse_start_reg;
            c3_pulse_w_wr  <= c3_pulse_w_wr_reg;
            c3_pulse_b_wr  <= c3_pulse_b_wr_reg;

            c3_pulse_start_reg<= 0;
            c3_pulse_w_wr_reg <= 0;
            c3_pulse_b_wr_reg <= 0;
        end
    end

    // ---------------------------
    // AXI Read handshake
    // ---------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            s_axi_arready <= 1'b0;
        else
            s_axi_arready <= (!s_axi_arready && s_axi_arvalid && !s_axi_rvalid);
    end

    // ---------------------------
    // AXI Read logic
    // ---------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_rvalid <= 0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= 0;
            done_latched <= 0;
        end else begin

            if (conv_done)
                done_latched <= 1'b1;

            if (s_axi_arready && s_axi_arvalid) begin
                case (s_axi_araddr)
                    ADDR_CONTROL: s_axi_rdata <= reg_control;
                    ADDR_STATUS:  begin
                        s_axi_rdata <= {30'd0, done_latched, conv_busy};
                        done_latched <= 1'b0;
                    end
                    ADDR_W_ADDR: s_axi_rdata <= reg_w_addr;
                    ADDR_W_DATA: s_axi_rdata <= reg_w_data;
                    ADDR_B_ADDR: s_axi_rdata <= reg_b_addr;
                    ADDR_B_DATA: s_axi_rdata <= reg_b_data;
                    default: s_axi_rdata <= 32'd0;
                endcase

                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 0;
            end
        end
    end

    // ---------------------------
    // Address width for internal conv memory
    // ---------------------------
    localparam int WADDR_WIDTH = $clog2(OUT_CH*IN_CH*K*K);
    localparam int BADDR_WIDTH = $clog2(OUT_CH);

    wire [WADDR_WIDTH-1:0] weight_wr_addr_int = reg_w_addr[WADDR_WIDTH-1:0];
    wire [BADDR_WIDTH-1:0] bias_wr_addr_int   = reg_b_addr[BADDR_WIDTH-1:0];

    // ---------------------------
    // Conv core instance
    // ---------------------------
    wire signed [N-1:0] conv_dout;
    wire                conv_dout_valid;
    wire                conv_busy_w;
    wire                conv_done_w;
    wire final_start=c3_pulse_start | start_external;

    conv3 #(
        .N(N),
        .Q(Q),
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .K(K),
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH)
    ) u_conv (
        .clk            (s_axi_aclk),
        .reset          (~s_axi_aresetn),

        .din            (din),
        .din_valid      (din_valid),

        .weight_wr_en   (pulse_w_wr),
        .weight_wr_addr (weight_wr_addr_int),
        .weight_wr_data (reg_w_data[N-1:0]),

        .bias_wr_en     (pulse_b_wr),
        .bias_wr_addr   (bias_wr_addr_int),
        .bias_wr_data   (reg_b_data[N-1:0]),

        .start          (final_start),
        .busy           (conv_busy_w),
        .done           (conv_done_w),

        .dout           (conv_dout),
        .dout_valid     (conv_dout_valid)
    );

    assign dout       = conv_dout;
    assign dout_valid = conv_dout_valid;
    assign conv_busy  = conv_busy_w;
    assign conv_done  = conv_done_w;

endmodule
