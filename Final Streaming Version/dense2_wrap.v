`timescale 1ns/1ps

module dense2_wrap #(
    parameter integer N = 16,
    parameter integer Q = 8,
    parameter integer NUM_INPUTS  = 512,
    parameter integer NUM_NEURONS = 1,
    parameter integer WADDR_BITS = 10,   
    parameter integer BADDR_BITS = 1
)(
    input  wire                 s_axi_aclk,
    input  wire                 s_axi_aresetn,

    input  wire [31:0]          s_axi_awaddr,
    input  wire                 s_axi_awvalid,
    output reg                  s_axi_awready,

    input  wire [31:0]          s_axi_wdata,
    input  wire [3:0]           s_axi_wstrb,
    input  wire                 s_axi_wvalid,
    output reg                  s_axi_wready,

    output reg  [1:0]           s_axi_bresp,
    output reg                  s_axi_bvalid,
    input  wire                 s_axi_bready,

    input  wire [31:0]          s_axi_araddr,
    input  wire                 s_axi_arvalid,
    output reg                  s_axi_arready,

    output reg  [31:0]          s_axi_rdata,
    output reg  [1:0]           s_axi_rresp,
    output reg                  s_axi_rvalid,
    input  wire                 s_axi_rready,

    input  wire                 start_external,

    input  wire signed [N-1:0]  din,
    input  wire                 din_valid,

    output wire signed [N-1:0]  dout,
    output wire                 dout_valid,

    output wire                 dense_busy,
    output wire                 dense_done
);

    localparam ADDR_CONTROL = 32'h00; 
    localparam ADDR_STATUS  = 32'h04; 
    localparam ADDR_W_ADDR  = 32'h10;
    localparam ADDR_W_DATA  = 32'h14;
    localparam ADDR_W_WR    = 32'h18;
    localparam ADDR_B_ADDR  = 32'h1C;
    localparam ADDR_B_DATA  = 32'h20;
    localparam ADDR_B_WR    = 32'h24;

    reg [31:0] reg_control;
    reg [31:0] reg_w_addr;
    reg [31:0] reg_w_data;
    reg [31:0] reg_b_addr;
    reg [31:0] reg_b_data;

    reg pulse_start, pulse_w_wr, pulse_b_wr;
    reg done_latched;

    always @(posedge s_axi_aclk) begin
        if(!s_axi_aresetn)
            s_axi_awready <= 0;
        else
            s_axi_awready <= (!s_axi_awready && s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid);
    end

    always @(posedge s_axi_aclk) begin
        if(!s_axi_aresetn)
            s_axi_wready <= 0;
        else
            s_axi_wready <= (!s_axi_wready && s_axi_wvalid && s_axi_awvalid && !s_axi_bvalid);
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_bvalid <= 0;
            reg_control  <= 0;
            reg_w_addr   <= 0;
            reg_w_data   <= 0;
            reg_b_addr   <= 0;
            reg_b_data   <= 0;
            pulse_start  <= 0;
            pulse_w_wr   <= 0;
            pulse_b_wr   <= 0;
        end
        else begin
            if (s_axi_awready && s_axi_awvalid &&
                s_axi_wready  && s_axi_wvalid) begin

                case (s_axi_awaddr)
                    ADDR_CONTROL: begin
                        reg_control <= s_axi_wdata;
                        if (s_axi_wdata[0])
                            pulse_start <= 1;
                    end
                    ADDR_W_ADDR: reg_w_addr <= s_axi_wdata;
                    ADDR_W_DATA: reg_w_data <= s_axi_wdata;
                    ADDR_W_WR:   if (s_axi_wdata[0]) pulse_w_wr <= 1;

                    ADDR_B_ADDR: reg_b_addr <= s_axi_wdata;
                    ADDR_B_DATA: reg_b_data <= s_axi_wdata;
                    ADDR_B_WR:   if (s_axi_wdata[0]) pulse_b_wr <= 1;
                endcase

                s_axi_bvalid <= 1;
                s_axi_bresp  <= 2'b00;
            end
            else if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 0;

            if (pulse_start) pulse_start <= 0;
            if (pulse_w_wr)  pulse_w_wr  <= 0;
            if (pulse_b_wr)  pulse_b_wr  <= 0;
        end
    end

    always @(posedge s_axi_aclk) begin
        if(!s_axi_aresetn) begin
            s_axi_rvalid <= 0;
            s_axi_rdata  <= 0;
            done_latched <= 0;
        end
        else begin
            if (dense_done)
                done_latched <= 1;

            if (s_axi_arvalid && !s_axi_rvalid) begin
                case (s_axi_araddr)
                    ADDR_CONTROL: s_axi_rdata <= reg_control;
                    ADDR_STATUS:  s_axi_rdata <= {30'd0, done_latched, dense_busy};
                    ADDR_W_ADDR:  s_axi_rdata <= reg_w_addr;
                    ADDR_W_DATA:  s_axi_rdata <= reg_w_data;
                    ADDR_B_ADDR:  s_axi_rdata <= reg_b_addr;
                    ADDR_B_DATA:  s_axi_rdata <= reg_b_data;
                    default:      s_axi_rdata <= 0;
                endcase

                s_axi_rvalid <= 1;
                s_axi_rresp  <= 2'b00;
                done_latched <= 0;
            end
            else if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 0;
        end
    end

    reg signed [N-1:0] weight_mem [0:(NUM_INPUTS*NUM_NEURONS)-1];
    reg signed [N-1:0] bias_mem   [0:NUM_NEURONS-1];

    always @(posedge s_axi_aclk) begin
        if (pulse_w_wr)
            weight_mem[reg_w_addr[WADDR_BITS-1:0]] <= reg_w_data[N-1:0];
        if (pulse_b_wr)
            bias_mem[reg_b_addr[BADDR_BITS-1:0]] <= reg_b_data[N-1:0];
    end

    wire signed [N-1:0] dense_dout_w;
    wire                dense_dout_valid_w;
    wire                busy_w;
    wire                done_w;

    dense2 #(
        .N(N),
        .Q(Q),
        .ADDR_BITS(WADDR_BITS)
    ) u_dense (
        .clk        (s_axi_aclk),
        .reset      (~s_axi_aresetn),

        .start      (pulse_start | start_external),

        .done       (done_w),
        .busy       (busy_w),

        .s_axis_tdata (din),
        .s_axis_tvalid(din_valid),
        .s_axis_tready(),     

        .m_axis_tdata (dense_dout_w),
        .m_axis_tvalid(dense_dout_valid_w),
        .m_axis_tready(1'b1),   

        .weight_addr(),        
        .weight_dout(),

        .bias_addr(),
        .bias_dout()
    );

    assign dout       = dense_dout_w;
    assign dout_valid = dense_dout_valid_w;
    assign dense_busy = busy_w;
    assign dense_done = done_w;

endmodule
