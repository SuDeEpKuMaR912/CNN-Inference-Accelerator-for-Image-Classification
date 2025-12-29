module dense1_wrap #(
    parameter integer N = 16,
    parameter integer Q = 8,
    parameter integer NUM_INPUTS  = 36992,
    parameter integer NUM_NEURONS = 512,
    parameter integer WADDR_BITS=1,
    parameter integer BADDR_BITS=1
)(  
    input  wire                 s_axi_aclk,
    input  wire                 s_axi_aresetn,

    // AXI-Lite Control
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

    // External Start Trigger
    input  wire                 start_external,

    // Activation Stream Input
    input  wire signed [N-1:0]  din,
    input  wire                 din_valid,
    output wire                 din_ready,

    // Weight streaming input
    input  wire signed [N-1:0]  w_tdata,
    input  wire                 w_tvalid,
    output wire                 w_tready,

    // Output feature
    output wire signed [N-1:0]  dout,
    output wire                 dout_valid,

    output wire                 dense_busy,
    output wire                 dense_done
);

    //=============================================
    // AXI CONTROL REGISTERS
    //=============================================
    reg start_reg = 0, done_latched = 0;

    // WRITE SIDE
    always @(posedge s_axi_aclk) begin
        if(!s_axi_aresetn) begin
            start_reg <= 0;
            s_axi_awready <= 0; 
            s_axi_wready <= 0;
            s_axi_bvalid <= 0;
            s_axi_bresp  <= 0;
        end else begin
            s_axi_awready <= s_axi_awvalid && !s_axi_awready;
            s_axi_wready  <= s_axi_wvalid  && !s_axi_wready;

            if(s_axi_awvalid && s_axi_wvalid && s_axi_awaddr==0)
                start_reg <= s_axi_wdata[0];

            if(s_axi_awvalid && s_axi_wvalid) begin
                s_axi_bvalid <= 1;
                s_axi_bresp  <= 0;
            end else if(s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 0;

            if(dense_done) done_latched <= 1;
        end
    end

    // READ SIDE
    always @(posedge s_axi_aclk) begin
        if(!s_axi_aresetn) begin
            s_axi_arready<=0; s_axi_rvalid<=0;
        end else begin
            s_axi_arready<= s_axi_arvalid && !s_axi_rvalid;

            if(s_axi_arvalid) begin
                case(s_axi_araddr)
                    0: s_axi_rdata <= {31'd0,start_reg};
                    4: s_axi_rdata <= {30'd0,done_latched,dense_busy};
                    default: s_axi_rdata<=0;
                endcase
                s_axi_rvalid<=1;
            end else if(s_axi_rvalid && s_axi_rready)
                s_axi_rvalid<=0;
        end
    end


    //======================================================
    //================ STREAMING DENSE CORE ================
    //======================================================
    dense #(
        .N(N), .Q(Q),
        .NUM_INPUTS(NUM_INPUTS),
        .NUM_NEURONS(NUM_NEURONS)
    ) core (
        .clk(s_axi_aclk),
        .reset(~s_axi_aresetn),

        .start(start_reg | start_external),
        .busy(dense_busy),
        .done(dense_done),

        .din(din),
        .din_valid(din_valid),
        .din_ready(din_ready),

        .w_tdata(w_tdata),
        .w_tvalid(w_tvalid),
        .w_tready(w_tready),

        .dout(dout),
        .dout_valid(dout_valid)
    );

endmodule
