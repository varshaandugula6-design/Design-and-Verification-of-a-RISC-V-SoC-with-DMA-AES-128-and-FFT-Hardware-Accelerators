// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : axi_ram_slave.sv
// Description  : Burst-capable AXI4 RAM Slave Model for IMEM (S0) and DMEM (S1).
// ==============================================================================

`ifndef AXI_RAM_SLAVE_SV
`define AXI_RAM_SLAVE_SV

`timescale 1ns / 1ps
`default_nettype none

module axi_ram_slave #(
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 32,
    parameter integer STRB_WIDTH = 4,
    parameter integer ID_WIDTH   = 8,
    parameter integer MEM_WORDS  = 32768, // 128 KB
    parameter bit [15:0] INIT_TAG = 16'hCA00
)(
    input  wire                    clk,
    input  wire                    rst,

    // Write Address Channel
    input  wire [ID_WIDTH-1:0]     awid,
    input  wire [ADDR_WIDTH-1:0]   awaddr,
    input  wire [7:0]              awlen,
    input  wire [2:0]              awsize,
    input  wire [1:0]              awburst,
    input  wire                    awvalid,
    output wire                    awready,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]   wdata,
    input  wire [STRB_WIDTH-1:0]   wstrb,
    input  wire                    wlast,
    input  wire                    wvalid,
    output wire                    wready,

    // Write Response Channel
    output reg  [ID_WIDTH-1:0]     bid,
    output reg  [1:0]              bresp,
    output reg                     bvalid,
    input  wire                    bready,

    // Read Address Channel
    input  wire [ID_WIDTH-1:0]     arid,
    input  wire [ADDR_WIDTH-1:0]   araddr,
    input  wire [7:0]              arlen,
    input  wire [2:0]              arsize,
    input  wire [1:0]              arburst,
    input  wire                    arvalid,
    output wire                    arready,

    // Read Data Channel
    output reg  [ID_WIDTH-1:0]     rid,
    output reg  [DATA_WIDTH-1:0]   rdata,
    output reg  [1:0]              rresp,
    output reg                     rlast,
    output reg                     rvalid,
    input  wire                    rready
);

    reg [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];
    integer init_k;

    initial begin
        for (init_k = 0; init_k < MEM_WORDS; init_k = init_k + 1) begin
            mem[init_k] = {INIT_TAG, 16'(init_k * 4)};
        end
    end

    // Write FSM
    localparam W_IDLE  = 2'd0;
    localparam W_BURST = 2'd1;
    localparam W_RESP  = 2'd2;

    reg [1:0]            w_state;
    reg [ID_WIDTH-1:0]   w_id_reg;
    reg [ADDR_WIDTH-1:0] w_addr_reg;
    reg [7:0]            w_len_reg;
    reg [7:0]            w_cnt;

    assign awready = (w_state == W_IDLE);
    assign wready  = (w_state == W_BURST);

    wire [ADDR_WIDTH-1:0] w_word_addr = (w_addr_reg >> 2) & (MEM_WORDS - 1);

    always @(posedge clk) begin
        if (rst) begin
            w_state    <= W_IDLE;
            w_id_reg   <= '0;
            w_addr_reg <= '0;
            w_len_reg  <= '0;
            w_cnt      <= '0;
            bvalid     <= 1'b0;
            bid        <= '0;
            bresp      <= 2'b00;
        end else begin
            case (w_state)
                W_IDLE: begin
                    if (awvalid && awready) begin
                        w_id_reg   <= awid;
                        w_addr_reg <= awaddr;
                        w_len_reg  <= awlen;
                        w_cnt      <= '0;
                        w_state    <= W_BURST;
                    end
                end

                W_BURST: begin
                    if (wvalid && wready) begin
                        if (wstrb[0]) mem[w_word_addr][ 7: 0] <= wdata[ 7: 0];
                        if (wstrb[1]) mem[w_word_addr][15: 8] <= wdata[15: 8];
                        if (wstrb[2]) mem[w_word_addr][23:16] <= wdata[23:16];
                        if (wstrb[3]) mem[w_word_addr][31:24] <= wdata[31:24];

                        w_addr_reg <= w_addr_reg + 4;
                        w_cnt      <= w_cnt + 1;

                        if (wlast || (w_cnt == w_len_reg)) begin
                            w_state <= W_RESP;
                            bvalid  <= 1'b1;
                            bid     <= w_id_reg;
                            bresp   <= 2'b00; // OKAY
                        end
                    end
                end

                W_RESP: begin
                    if (bvalid && bready) begin
                        bvalid  <= 1'b0;
                        w_state <= W_IDLE;
                    end
                end
            endcase
        end
    end

    // Read FSM
    localparam R_IDLE  = 2'd0;
    localparam R_BURST = 2'd1;

    reg [1:0]            r_state;
    reg [ID_WIDTH-1:0]   r_id_reg;
    reg [ADDR_WIDTH-1:0] r_addr_reg;
    reg [7:0]            r_len_reg;
    reg [7:0]            r_cnt;

    assign arready = (r_state == R_IDLE) && !rvalid;

    wire [ADDR_WIDTH-1:0] r_word_addr = (r_addr_reg >> 2) & (MEM_WORDS - 1);

    always @(posedge clk) begin
        if (rst) begin
            r_state    <= R_IDLE;
            r_id_reg   <= '0;
            r_addr_reg <= '0;
            r_len_reg  <= '0;
            r_cnt      <= '0;
            rvalid     <= 1'b0;
            rid        <= '0;
            rdata      <= '0;
            rresp      <= 2'b00;
            rlast      <= 1'b0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (arvalid && arready) begin
                        r_id_reg   <= arid;
                        r_addr_reg <= araddr;
                        r_len_reg  <= arlen;
                        r_cnt      <= '0;
                        r_state    <= R_BURST;

                        rvalid     <= 1'b1;
                        rid        <= arid;
                        rdata      <= mem[(araddr >> 2) & (MEM_WORDS - 1)];
                        rresp      <= 2'b00; // OKAY
                        rlast      <= (arlen == 8'd0);
                    end
                end

                R_BURST: begin
                    if (rvalid && rready) begin
                        if (r_cnt == r_len_reg) begin
                            rvalid  <= 1'b0;
                            rlast   <= 1'b0;
                            r_state <= R_IDLE;
                        end else begin
                            r_cnt      <= r_cnt + 1;
                            r_addr_reg <= r_addr_reg + 4;
                            rdata      <= mem[((r_addr_reg + 4) >> 2) & (MEM_WORDS - 1)];
                            rlast      <= (r_cnt + 1 == r_len_reg);
                        end
                    end
                end
            endcase
        end
    end

endmodule

`default_nettype wire

`endif // AXI_RAM_SLAVE_SV
