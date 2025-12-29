`timescale 1ns/1ps

module control_logic #(
    parameter IMG_WIDTH  = 150,
    parameter IMG_HEIGHT = 150
)(

    input  wire         S_AXI_ACLK,
    input  wire         S_AXI_ARESETN,

    input  wire [31:0]  S_AXI_AWADDR,
    input  wire         S_AXI_AWVALID,
    output wire         S_AXI_AWREADY,

    input  wire [31:0]  S_AXI_WDATA,
    input  wire [3:0]   S_AXI_WSTRB,
    input  wire         S_AXI_WVALID,
    output wire         S_AXI_WREADY,

    output wire [1:0]   S_AXI_BRESP,
    output reg          S_AXI_BVALID,
    input  wire         S_AXI_BREADY,

    input  wire [31:0]  S_AXI_ARADDR,
    input  wire         S_AXI_ARVALID,
    output wire         S_AXI_ARREADY,

    output reg [31:0]   S_AXI_RDATA,
    output wire [1:0]   S_AXI_RRESP,
    output reg          S_AXI_RVALID,
    input  wire         S_AXI_RREADY,

    input wire          pixel_in_valid,

    input wire  [2:0]   conv_done,     // 3 convs
    input wire  [2:0]   pool_done,     // 3 pools
    input wire          flatten_done,
    input wire  [1:0]   dense_done,    // 2 dense layers

    output reg  [2:0]   conv_start,
    output reg  [2:0]   pool_start,
    output reg          flatten_start,
    output reg  [1:0]   dense_start,

    output wire         busy
);

    assign S_AXI_AWREADY = 1'b1;
    assign S_AXI_WREADY  = 1'b1;
    assign S_AXI_BRESP   = 2'b00;
    assign S_AXI_ARREADY = 1'b1;
    assign S_AXI_RRESP   = 2'b00;

    reg start_reg;
    reg done_reg;


    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            start_reg   <= 1'b0;
            S_AXI_BVALID <= 1'b0;
        end else begin
            if (S_AXI_WVALID && S_AXI_AWVALID) begin
                case (S_AXI_AWADDR[5:2])
                    4'h0: start_reg <= S_AXI_WDATA[0];
                endcase
                S_AXI_BVALID <= 1'b1;
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end
        end
    end

    reg [31:0] read_data;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RDATA  <= 32'd0;
        end else begin
            if (S_AXI_ARVALID) begin
                case (S_AXI_ARADDR[5:2])
                    4'h0: read_data <= {31'd0, start_reg};
                    4'h1: read_data <= {31'd0, busy};
                    4'h2: read_data <= {31'd0, done_reg};
                    default: read_data <= 32'd0;
                endcase

                S_AXI_RDATA  <= read_data;
                S_AXI_RVALID <= 1'b1;
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

    localparam integer TOTAL_PIX = IMG_WIDTH * IMG_HEIGHT;

    typedef enum logic [3:0] {
        S_IDLE      = 4'd0,
        S_LOAD      = 4'd1,
        S_CONV1     = 4'd2,
        S_POOL1     = 4'd3,
        S_CONV2     = 4'd4,
        S_POOL2     = 4'd5,
        S_CONV3     = 4'd6,
        S_POOL3     = 4'd7,
        S_FLAT      = 4'd8,
        S_DENSE1    = 4'd9,
        S_DENSE2    = 4'd10,
        S_DONE      = 4'd11
    } state_t;

    state_t state, next_state;

    reg [31:0] pix_count;

    assign busy = (state != S_IDLE);


    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            state <= S_IDLE;
            pix_count <= 32'd0;
        end else begin
            state <= next_state;

            if (state == S_LOAD && pixel_in_valid)
                pix_count <= pix_count + 1;
            else if (state == S_IDLE)
                pix_count <= 0;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)

            S_IDLE:     if (start_reg) next_state = S_LOAD;
            S_LOAD:     if (pix_count == TOTAL_PIX-1) next_state = S_CONV1;

            S_CONV1:    if (conv_done[0]) next_state = S_POOL1;
            S_POOL1:    if (pool_done[0]) next_state = S_CONV2;

            S_CONV2:    if (conv_done[1]) next_state = S_POOL2;
            S_POOL2:    if (pool_done[1]) next_state = S_CONV3;

            S_CONV3:    if (conv_done[2]) next_state = S_POOL3;
            S_POOL3:    if (pool_done[2]) next_state = S_FLAT;

            S_FLAT:     if (flatten_done) next_state = S_DENSE1;

            S_DENSE1:   if (dense_done[0]) next_state = S_DENSE2;
            S_DENSE2:   if (dense_done[1]) next_state = S_DONE;

            S_DONE:     next_state = S_IDLE;

        endcase
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            conv_start   <= 3'b000;
            pool_start   <= 3'b000;
            flatten_start<= 1'b0;
            dense_start  <= 2'b00;
            done_reg     <= 1'b0;
        end else begin
            conv_start   <= 3'b000;
            pool_start   <= 3'b000;
            flatten_start<= 1'b0;
            dense_start  <= 2'b00;
            done_reg     <= 1'b0;

            case (next_state)
                S_CONV1:  if (state != S_CONV1) conv_start[0] <= 1;
                S_POOL1:  if (state != S_POOL1) pool_start[0] <= 1;

                S_CONV2:  if (state != S_CONV2) conv_start[1] <= 1;
                S_POOL2:  if (state != S_POOL2) pool_start[1] <= 1;

                S_CONV3:  if (state != S_CONV3) conv_start[2] <= 1;
                S_POOL3:  if (state != S_POOL3) pool_start[2] <= 1;

                S_FLAT:   if (state != S_FLAT) flatten_start <= 1;

                S_DENSE1: if (state != S_DENSE1) dense_start[0] <= 1;
                S_DENSE2: if (state != S_DENSE2) dense_start[1] <= 1;

                S_DONE:   done_reg <= 1;
            endcase
        end
    end

endmodule
