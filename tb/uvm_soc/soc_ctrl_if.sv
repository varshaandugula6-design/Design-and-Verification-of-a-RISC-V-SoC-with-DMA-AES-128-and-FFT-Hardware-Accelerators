// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : soc_ctrl_if.sv
// Description  : Interface and AXI Master BFM tasks for SoC peripheral register
//                configuration (GPIO, UART, Timer) via interconnect Master 1.
// ==============================================================================

`ifndef SOC_CTRL_IF_SV
`define SOC_CTRL_IF_SV

interface soc_ctrl_if (
    input logic clk,
    input logic rst_n
);
    // AXI Master 1 (s01_axi) signals connected to DUT
    logic [7:0]   awid;
    logic [31:0]  awaddr;
    logic [7:0]   awlen;
    logic [2:0]   awsize;
    logic [1:0]   awburst;
    logic         awlock;
    logic [3:0]   awcache;
    logic [2:0]   awprot;
    logic [3:0]   awqos;
    logic         awuser;
    logic         awvalid;
    logic         awready;

    logic [31:0]  wdata;
    logic [3:0]   wstrb;
    logic         wlast;
    logic         wuser;
    logic         wvalid;
    logic         wready;

    logic [7:0]   bid;
    logic [1:0]   bresp;
    logic         buser;
    logic         bvalid;
    logic         bready;

    logic [7:0]   arid;
    logic [31:0]  araddr;
    logic [7:0]   arlen;
    logic [2:0]   arsize;
    logic [1:0]   arburst;
    logic         arlock;
    logic [3:0]   arcache;
    logic [2:0]   arprot;
    logic [3:0]   arqos;
    logic         aruser;
    logic         arvalid;
    logic         arready;

    logic [7:0]   rid;
    logic [31:0]  rdata;
    logic [1:0]   rresp;
    logic         rlast;
    logic         ruser;
    logic         rvalid;
    logic         rready;

    // Reset initialization task
    task automatic init_master();
        awid    <= 8'h0;
        awaddr  <= 32'h0;
        awlen   <= 8'h0;
        awsize  <= 3'b010; // 4 bytes (32-bit)
        awburst <= 2'b01;  // INCR
        awlock  <= 1'b0;
        awcache <= 4'h0;
        awprot  <= 3'h0;
        awqos   <= 4'h0;
        awuser  <= 1'b0;
        awvalid <= 1'b0;

        wdata   <= 32'h0;
        wstrb   <= 4'hF;
        wlast   <= 1'b0;
        wuser   <= 1'b0;
        wvalid  <= 1'b0;

        bready  <= 1'b0;

        arid    <= 8'h0;
        araddr  <= 32'h0;
        arlen   <= 8'h0;
        arsize  <= 3'b010;
        arburst <= 2'b01;
        arlock  <= 1'b0;
        arcache <= 4'h0;
        arprot  <= 3'h0;
        arqos   <= 4'h0;
        aruser  <= 1'b0;
        arvalid <= 1'b0;

        rready  <= 1'b0;
    endtask

    // Synchronous AXI Write Transaction
    task automatic axi_write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [7:0]  id = 8'h11,
        output logic [1:0]  resp
    );
        int timeout_cnt;
        @(posedge clk);
        awid    <= id;
        awaddr  <= addr;
        awlen   <= 8'h00; // single beat
        awsize  <= 3'b010;
        awburst <= 2'b01;
        awvalid <= 1'b1;

        wdata   <= data;
        wstrb   <= 4'hF;
        wlast   <= 1'b1;
        wvalid  <= 1'b1;
        bready  <= 1'b1;

        // Wait for AWREADY and WREADY
        fork
            begin
                timeout_cnt = 0;
                while (!awready && timeout_cnt < 200) begin
                    @(posedge clk);
                    timeout_cnt++;
                end
                @(posedge clk);
                awvalid <= 1'b0;
            end
            begin
                timeout_cnt = 0;
                while (!wready && timeout_cnt < 200) begin
                    @(posedge clk);
                    timeout_cnt++;
                end
                @(posedge clk);
                wvalid <= 1'b0;
                wlast  <= 1'b0;
            end
        join

        // Wait for BVALID
        timeout_cnt = 0;
        while (!bvalid && timeout_cnt < 200) begin
            @(posedge clk);
            timeout_cnt++;
        end
        resp = bresp;
        @(posedge clk);
        bready <= 1'b0;
    endtask

    // Synchronous AXI Read Transaction
    task automatic axi_read(
        input  logic [31:0] addr,
        input  logic [7:0]  id = 8'h12,
        output logic [31:0] data,
        output logic [1:0]  resp
    );
        int timeout_cnt;
        @(posedge clk);
        arid    <= id;
        araddr  <= addr;
        arlen   <= 8'h00;
        arsize  <= 3'b010;
        arburst <= 2'b01;
        arvalid <= 1'b1;
        rready  <= 1'b1;

        // Wait for ARREADY
        timeout_cnt = 0;
        while (!arready && timeout_cnt < 200) begin
            @(posedge clk);
            timeout_cnt++;
        end
        @(posedge clk);
        arvalid <= 1'b0;

        // Wait for RVALID
        timeout_cnt = 0;
        while (!rvalid && timeout_cnt < 200) begin
            @(posedge clk);
            timeout_cnt++;
        end
        data = rdata;
        resp = rresp;
        @(posedge clk);
        rready <= 1'b0;
    endtask

endinterface

`endif // SOC_CTRL_IF_SV
