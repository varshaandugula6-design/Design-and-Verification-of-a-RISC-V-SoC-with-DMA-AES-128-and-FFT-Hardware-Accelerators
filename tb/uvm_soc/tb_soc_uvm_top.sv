// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : tb_soc_uvm_top.sv
// Description  : Independent top-level UVM Testbench module instantiating main_top,
//                RAM models, VIP interfaces (GPIO, UART, PWM), and running UVM tests.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype none

import uvm_pkg::*;
`include "uvm_macros.svh"

import gpio_pkg::*;
import uart_pkg::*;
import pwm_pkg::*;

`include "soc_ctrl_if.sv"
`include "axi_ram_slave.sv"
`include "soc_uvm_test.sv"

module tb_soc_uvm_top;

    parameter integer DATA_WIDTH = 32;
    parameter integer ADDR_WIDTH = 32;
    parameter integer STRB_WIDTH = (DATA_WIDTH/8);
    parameter integer ID_WIDTH   = 8;

    // ------------------------------------------------------------
    // Clocks and Resets
    // ------------------------------------------------------------
    logic clk;        // 100 MHz AXI system clock (period = 10.0 ns)
    logic fixed_clk;  // 40 MHz dedicated UART baud clock (period = 25.0 ns)
    logic rst;        // Active-high synchronous system reset

    initial begin
        clk = 1'b0;
        forever #5.0 clk = ~clk;
    end

    initial begin
        fixed_clk = 1'b0;
        #3.125;
        forever #12.5 fixed_clk = ~fixed_clk;
    end

    initial begin
        rst = 1'b1;
        #100;
        @(posedge clk);
        rst = 1'b0;
    end

    // ------------------------------------------------------------
    // VIP Virtual Interfaces
    // ------------------------------------------------------------
    gpio_if     u_gpio_if     (.clk(clk), .rst_n(~rst));
    uart_if     u_uart_if     (.clk(clk), .fixed_clk(fixed_clk), .rst_n(~rst));
    pwm_if      u_pwm_if      (.clk(clk), .rst_n(~rst));
    soc_ctrl_if u_soc_ctrl_if (.clk(clk), .rst_n(~rst));

    // Master 0 (VeeR IFU) - Idle
    logic [ID_WIDTH-1:0]     m0_awid = '0;
    logic [ADDR_WIDTH-1:0]   m0_awaddr = '0;
    logic [7:0]              m0_awlen = '0;
    logic [2:0]              m0_awsize = 3'b010;
    logic [1:0]              m0_awburst = 2'b01;
    logic                    m0_awlock = '0;
    logic [3:0]              m0_awcache = '0;
    logic [2:0]              m0_awprot = '0;
    logic [3:0]              m0_awqos = '0;
    logic                    m0_awuser = '0;
    logic                    m0_awvalid = '0;
    wire                     m0_awready;
    logic [DATA_WIDTH-1:0]   m0_wdata = '0;
    logic [STRB_WIDTH-1:0]   m0_wstrb = '0;
    logic                    m0_wlast = '0;
    logic                    m0_wuser = '0;
    logic                    m0_wvalid = '0;
    wire                     m0_wready;
    wire  [ID_WIDTH-1:0]     m0_bid;
    wire  [1:0]              m0_bresp;
    wire                     m0_buser;
    wire                     m0_bvalid;
    logic                    m0_bready = '0;
    logic [ID_WIDTH-1:0]     m0_arid = '0;
    logic [ADDR_WIDTH-1:0]   m0_araddr = '0;
    logic [7:0]              m0_arlen = '0;
    logic [2:0]              m0_arsize = 3'b010;
    logic [1:0]              m0_arburst = 2'b01;
    logic                    m0_arlock = '0;
    logic [3:0]              m0_arcache = '0;
    logic [2:0]              m0_arprot = '0;
    logic [3:0]              m0_arqos = '0;
    logic                    m0_aruser = '0;
    logic                    m0_arvalid = '0;
    wire                     m0_arready;
    wire  [ID_WIDTH-1:0]     m0_rid;
    wire  [DATA_WIDTH-1:0]   m0_rdata;
    wire  [1:0]              m0_rresp;
    wire                     m0_rlast;
    wire                     m0_ruser;
    wire                     m0_rvalid;
    logic                    m0_rready = '0;

    // Master 2 (DMA) - Idle
    logic [ID_WIDTH-1:0]     m2_awid = '0;
    logic [ADDR_WIDTH-1:0]   m2_awaddr = '0;
    logic [7:0]              m2_awlen = '0;
    logic [2:0]              m2_awsize = 3'b010;
    logic [1:0]              m2_awburst = 2'b01;
    logic                    m2_awlock = '0;
    logic [3:0]              m2_awcache = '0;
    logic [2:0]              m2_awprot = '0;
    logic [3:0]              m2_awqos = '0;
    logic                    m2_awuser = '0;
    logic                    m2_awvalid = '0;
    wire                     m2_awready;
    logic [DATA_WIDTH-1:0]   m2_wdata = '0;
    logic [STRB_WIDTH-1:0]   m2_wstrb = '0;
    logic                    m2_wlast = '0;
    logic                    m2_wuser = '0;
    logic                    m2_wvalid = '0;
    wire                     m2_wready;
    wire  [ID_WIDTH-1:0]     m2_bid;
    wire  [1:0]              m2_bresp;
    wire                     m2_buser;
    wire                     m2_bvalid;
    logic                    m2_bready = '0;
    logic [ID_WIDTH-1:0]     m2_arid = '0;
    logic [ADDR_WIDTH-1:0]   m2_araddr = '0;
    logic [7:0]              m2_arlen = '0;
    logic [2:0]              m2_arsize = 3'b010;
    logic [1:0]              m2_arburst = 2'b01;
    logic                    m2_arlock = '0;
    logic [3:0]              m2_arcache = '0;
    logic [2:0]              m2_arprot = '0;
    logic [3:0]              m2_arqos = '0;
    logic                    m2_aruser = '0;
    logic                    m2_arvalid = '0;
    wire                     m2_arready;
    wire  [ID_WIDTH-1:0]     m2_rid;
    wire  [DATA_WIDTH-1:0]   m2_rdata;
    wire  [1:0]              m2_rresp;
    wire                     m2_rlast;
    wire                     m2_ruser;
    wire                     m2_rvalid;
    logic                    m2_rready = '0;

    // Slave Port Wires
    wire [ID_WIDTH-1:0]      slv_awid    [0:14];
    wire [ADDR_WIDTH-1:0]    slv_awaddr  [0:14];
    wire [7:0]               slv_awlen   [0:14];
    wire [2:0]               slv_awsize  [0:14];
    wire [1:0]               slv_awburst [0:14];
    wire                     slv_awlock  [0:14];
    wire [3:0]               slv_awcache [0:14];
    wire [2:0]               slv_awprot  [0:14];
    wire [3:0]               slv_awqos   [0:14];
    wire [3:0]               slv_awregion[0:14];
    wire                     slv_awuser  [0:14];
    wire                     slv_awvalid [0:14];
    logic                    slv_awready [0:14];

    wire [DATA_WIDTH-1:0]    slv_wdata   [0:14];
    wire [STRB_WIDTH-1:0]    slv_wstrb   [0:14];
    wire                     slv_wlast   [0:14];
    wire                     slv_wuser   [0:14];
    wire                     slv_wvalid  [0:14];
    logic                    slv_wready  [0:14];

    logic [ID_WIDTH-1:0]     slv_bid     [0:14];
    logic [1:0]              slv_bresp   [0:14];
    logic                    slv_buser   [0:14];
    logic                    slv_bvalid  [0:14];
    wire                     slv_bready  [0:14];

    wire [ID_WIDTH-1:0]      slv_arid    [0:14];
    wire [ADDR_WIDTH-1:0]    slv_araddr  [0:14];
    wire [7:0]               slv_arlen   [0:14];
    wire [2:0]               slv_arsize  [0:14];
    wire [1:0]               slv_arburst [0:14];
    wire                     slv_arlock  [0:14];
    wire [3:0]               slv_arcache [0:14];
    wire [2:0]               slv_arprot  [0:14];
    wire [3:0]               slv_arqos   [0:14];
    wire [3:0]               slv_arregion[0:14];
    wire                     slv_aruser  [0:14];
    wire                     slv_arvalid [0:14];
    logic                    slv_arready [0:14];

    logic [ID_WIDTH-1:0]     slv_rid     [0:14];
    logic [DATA_WIDTH-1:0]   slv_rdata   [0:14];
    logic [1:0]              slv_rresp   [0:14];
    logic                    slv_rlast   [0:14];
    logic                    slv_ruser   [0:14];
    logic                    slv_rvalid  [0:14];
    wire                     slv_rready  [0:14];

    // Dummy responders for unmapped/uninstantiated slaves (S8..S14)
    genvar gi;
    generate
        for (gi = 8; gi <= 14; gi = gi + 1) begin : GEN_EXT_DUMMY
            always_comb begin
                slv_awready[gi] = 1'b1;
                slv_wready[gi]  = 1'b1;
                slv_bid[gi]     = slv_awid[gi];
                slv_bresp[gi]   = 2'b11; // DECERR
                slv_buser[gi]   = 1'b0;
                slv_bvalid[gi]  = slv_awvalid[gi] && slv_wvalid[gi];

                slv_arready[gi] = 1'b1;
                slv_rid[gi]     = slv_arid[gi];
                slv_rdata[gi]   = 32'h0;
                slv_rresp[gi]   = 2'b11; // DECERR
                slv_rlast[gi]   = 1'b1;
                slv_ruser[gi]   = 1'b0;
                slv_rvalid[gi]  = slv_arvalid[gi];
            end
        end
    endgenerate

    // Instantiate RAM Models for S00 (IMEM) and S01 (DMEM)
    axi_ram_slave #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .STRB_WIDTH (STRB_WIDTH),
        .ID_WIDTH   (ID_WIDTH),
        .MEM_WORDS  (32768),
        .INIT_TAG   (16'hCA00)
    ) u_imem_ram (
        .clk     (clk),
        .rst     (rst),
        .awid    (slv_awid[0]),
        .awaddr  (slv_awaddr[0]),
        .awlen   (slv_awlen[0]),
        .awsize  (slv_awsize[0]),
        .awburst (slv_awburst[0]),
        .awvalid (slv_awvalid[0]),
        .awready (slv_awready[0]),
        .wdata   (slv_wdata[0]),
        .wstrb   (slv_wstrb[0]),
        .wlast   (slv_wlast[0]),
        .wvalid  (slv_wvalid[0]),
        .wready  (slv_wready[0]),
        .bid     (slv_bid[0]),
        .bresp   (slv_bresp[0]),
        .bvalid  (slv_bvalid[0]),
        .bready  (slv_bready[0]),
        .arid    (slv_arid[0]),
        .araddr  (slv_araddr[0]),
        .arlen   (slv_arlen[0]),
        .arsize  (slv_arsize[0]),
        .arburst (slv_arburst[0]),
        .arvalid (slv_arvalid[0]),
        .arready (slv_arready[0]),
        .rid     (slv_rid[0]),
        .rdata   (slv_rdata[0]),
        .rresp   (slv_rresp[0]),
        .rlast   (slv_rlast[0]),
        .rvalid  (slv_rvalid[0]),
        .rready  (slv_rready[0])
    );

    axi_ram_slave #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .STRB_WIDTH (STRB_WIDTH),
        .ID_WIDTH   (ID_WIDTH),
        .MEM_WORDS  (32768),
        .INIT_TAG   (16'hCA01)
    ) u_dmem_ram (
        .clk     (clk),
        .rst     (rst),
        .awid    (slv_awid[1]),
        .awaddr  (slv_awaddr[1]),
        .awlen   (slv_awlen[1]),
        .awsize  (slv_awsize[1]),
        .awburst (slv_awburst[1]),
        .awvalid (slv_awvalid[1]),
        .awready (slv_awready[1]),
        .wdata   (slv_wdata[1]),
        .wstrb   (slv_wstrb[1]),
        .wlast   (slv_wlast[1]),
        .wvalid  (slv_wvalid[1]),
        .wready  (slv_wready[1]),
        .bid     (slv_bid[1]),
        .bresp   (slv_bresp[1]),
        .bvalid  (slv_bvalid[1]),
        .bready  (slv_bready[1]),
        .arid    (slv_arid[1]),
        .araddr  (slv_araddr[1]),
        .arlen   (slv_arlen[1]),
        .arsize  (slv_arsize[1]),
        .arburst (slv_arburst[1]),
        .arvalid (slv_arvalid[1]),
        .arready (slv_arready[1]),
        .rid     (slv_rid[1]),
        .rdata   (slv_rdata[1]),
        .rresp   (slv_rresp[1]),
        .rlast   (slv_rlast[1]),
        .rvalid  (slv_rvalid[1]),
        .rready  (slv_rready[1])
    );

    // Peripheral Interrupt Wires
    wire fft_irq;
    wire dma_irq;
    wire dma_error_irq;

    // CPU Control/Trace Wires (Held in reset during VIP tests)
    logic        cpu_rst_l = 1'b0;
    logic [31:1] cpu_rst_vec = 31'h0002_0000;
    logic        cpu_run_req = 1'b0;
    wire [31:0]  trace_rv_i_insn_ip;
    wire [31:0]  trace_rv_i_address_ip;
    wire         trace_rv_i_valid_ip;
    wire         trace_rv_i_exception_ip;
    wire [4:0]   trace_rv_i_ecause_ip;
    wire         trace_rv_i_interrupt_ip;
    wire [31:0]  trace_rv_i_tval_ip;
    wire         o_cpu_halt_status;

    // ============================================================
    // DUT INSTANTIATION (Actual main_top)
    // ============================================================
    main_top #(
        .DATA_WIDTH      (DATA_WIDTH),
        .ADDR_WIDTH      (ADDR_WIDTH),
        .STRB_WIDTH      (STRB_WIDTH),
        .ID_WIDTH        (ID_WIDTH)
    ) dut (
        .clk             (clk),
        .fixed_clk       (fixed_clk),
        .rst             (rst),

        // Dedicated UART External Pins & Interrupt -> UART VIP
        .uart_rx         (u_uart_if.uart_rx_i),
        .uart_tx         (u_uart_if.uart_tx_o),
        .uart_irq        (u_uart_if.uart_irq),

        // Dedicated GPIO External Pins & Interrupt -> GPIO VIP
        .gpio_io         (u_gpio_if.gpio_io),
        .gpio_irq        (u_gpio_if.gpio_irq),

        // Dedicated Timer PWM Output & Interrupt -> PWM VIP
        .timer_pwm       (u_pwm_if.pwm_out_o),
        .timer_irq       (u_pwm_if.timer_irq),

        // FFT and DMA completion interrupts
        .fft_irq         (fft_irq),
        .dma_irq         (dma_irq),
        .dma_error_irq   (dma_error_irq),

        // Master 0 (VeeR IFU) - Tied Idle
        .s00_axi_awid    (m0_awid),
        .s00_axi_awaddr  (m0_awaddr),
        .s00_axi_awlen   (m0_awlen),
        .s00_axi_awsize  (m0_awsize),
        .s00_axi_awburst (m0_awburst),
        .s00_axi_awlock  (m0_awlock),
        .s00_axi_awcache (m0_awcache),
        .s00_axi_awprot  (m0_awprot),
        .s00_axi_awqos   (m0_awqos),
        .s00_axi_awuser  (m0_awuser),
        .s00_axi_awvalid (m0_awvalid),
        .s00_axi_awready (m0_awready),
        .s00_axi_wdata   (m0_wdata),
        .s00_axi_wstrb   (m0_wstrb),
        .s00_axi_wlast   (m0_wlast),
        .s00_axi_wuser   (m0_wuser),
        .s00_axi_wvalid  (m0_wvalid),
        .s00_axi_wready  (m0_wready),
        .s00_axi_bid     (m0_bid),
        .s00_axi_bresp   (m0_bresp),
        .s00_axi_buser   (m0_buser),
        .s00_axi_bvalid  (m0_bvalid),
        .s00_axi_bready  (m0_bready),
        .s00_axi_arid    (m0_arid),
        .s00_axi_araddr  (m0_araddr),
        .s00_axi_arlen   (m0_arlen),
        .s00_axi_arsize  (m0_arsize),
        .s00_axi_arburst (m0_arburst),
        .s00_axi_arlock  (m0_arlock),
        .s00_axi_arcache (m0_arcache),
        .s00_axi_arprot  (m0_arprot),
        .s00_axi_arqos   (m0_arqos),
        .s00_axi_aruser  (m0_aruser),
        .s00_axi_arvalid (m0_arvalid),
        .s00_axi_arready (m0_arready),
        .s00_axi_rid     (m0_rid),
        .s00_axi_rdata   (m0_rdata),
        .s00_axi_rresp   (m0_rresp),
        .s00_axi_rlast   (m0_rlast),
        .s00_axi_ruser   (m0_ruser),
        .s00_axi_rvalid  (m0_rvalid),
        .s00_axi_rready  (m0_rready),

        // Master 1 (SoC Ctrl BFM for VIP verification)
        .s01_axi_awid    (u_soc_ctrl_if.awid),
        .s01_axi_awaddr  (u_soc_ctrl_if.awaddr),
        .s01_axi_awlen   (u_soc_ctrl_if.awlen),
        .s01_axi_awsize  (u_soc_ctrl_if.awsize),
        .s01_axi_awburst (u_soc_ctrl_if.awburst),
        .s01_axi_awlock  (u_soc_ctrl_if.awlock),
        .s01_axi_awcache (u_soc_ctrl_if.awcache),
        .s01_axi_awprot  (u_soc_ctrl_if.awprot),
        .s01_axi_awqos   (u_soc_ctrl_if.awqos),
        .s01_axi_awuser  (u_soc_ctrl_if.awuser),
        .s01_axi_awvalid (u_soc_ctrl_if.awvalid),
        .s01_axi_awready (u_soc_ctrl_if.awready),
        .s01_axi_wdata   (u_soc_ctrl_if.wdata),
        .s01_axi_wstrb   (u_soc_ctrl_if.wstrb),
        .s01_axi_wlast   (u_soc_ctrl_if.wlast),
        .s01_axi_wuser   (u_soc_ctrl_if.wuser),
        .s01_axi_wvalid  (u_soc_ctrl_if.wvalid),
        .s01_axi_wready  (u_soc_ctrl_if.wready),
        .s01_axi_bid     (u_soc_ctrl_if.bid),
        .s01_axi_bresp   (u_soc_ctrl_if.bresp),
        .s01_axi_buser   (u_soc_ctrl_if.buser),
        .s01_axi_bvalid  (u_soc_ctrl_if.bvalid),
        .s01_axi_bready  (u_soc_ctrl_if.bready),
        .s01_axi_arid    (u_soc_ctrl_if.arid),
        .s01_axi_araddr  (u_soc_ctrl_if.araddr),
        .s01_axi_arlen   (u_soc_ctrl_if.arlen),
        .s01_axi_arsize  (u_soc_ctrl_if.arsize),
        .s01_axi_arburst (u_soc_ctrl_if.arburst),
        .s01_axi_arlock  (u_soc_ctrl_if.arlock),
        .s01_axi_arcache (u_soc_ctrl_if.arcache),
        .s01_axi_arprot  (u_soc_ctrl_if.arprot),
        .s01_axi_arqos   (u_soc_ctrl_if.arqos),
        .s01_axi_aruser  (u_soc_ctrl_if.aruser),
        .s01_axi_arvalid (u_soc_ctrl_if.arvalid),
        .s01_axi_arready (u_soc_ctrl_if.arready),
        .s01_axi_rid     (u_soc_ctrl_if.rid),
        .s01_axi_rdata   (u_soc_ctrl_if.rdata),
        .s01_axi_rresp   (u_soc_ctrl_if.rresp),
        .s01_axi_rlast   (u_soc_ctrl_if.rlast),
        .s01_axi_ruser   (u_soc_ctrl_if.ruser),
        .s01_axi_rvalid  (u_soc_ctrl_if.rvalid),
        .s01_axi_rready  (u_soc_ctrl_if.rready),

        // Master 2 (DMA) - Tied Idle
        .s02_axi_awid    (m2_awid),
        .s02_axi_awaddr  (m2_awaddr),
        .s02_axi_awlen   (m2_awlen),
        .s02_axi_awsize  (m2_awsize),
        .s02_axi_awburst (m2_awburst),
        .s02_axi_awlock  (m2_awlock),
        .s02_axi_awcache (m2_awcache),
        .s02_axi_awprot  (m2_awprot),
        .s02_axi_awqos   (m2_awqos),
        .s02_axi_awuser  (m2_awuser),
        .s02_axi_awvalid (m2_awvalid),
        .s02_axi_awready (m2_awready),
        .s02_axi_wdata   (m2_wdata),
        .s02_axi_wstrb   (m2_wstrb),
        .s02_axi_wlast   (m2_wlast),
        .s02_axi_wuser   (m2_wuser),
        .s02_axi_wvalid  (m2_wvalid),
        .s02_axi_wready  (m2_wready),
        .s02_axi_bid     (m2_bid),
        .s02_axi_bresp   (m2_bresp),
        .s02_axi_buser   (m2_buser),
        .s02_axi_bvalid  (m2_bvalid),
        .s02_axi_bready  (m2_bready),
        .s02_axi_arid    (m2_arid),
        .s02_axi_araddr  (m2_araddr),
        .s02_axi_arlen   (m2_arlen),
        .s02_axi_arsize  (m2_arsize),
        .s02_axi_arburst (m2_arburst),
        .s02_axi_arlock  (m2_arlock),
        .s02_axi_arcache (m2_arcache),
        .s02_axi_arprot  (m2_arprot),
        .s02_axi_arqos   (m2_arqos),
        .s02_axi_aruser  (m2_aruser),
        .s02_axi_arvalid (m2_arvalid),
        .s02_axi_arready (m2_arready),
        .s02_axi_rid     (m2_rid),
        .s02_axi_rdata   (m2_rdata),
        .s02_axi_rresp   (m2_rresp),
        .s02_axi_rlast   (m2_rlast),
        .s02_axi_ruser   (m2_ruser),
        .s02_axi_rvalid  (m2_rvalid),
        .s02_axi_rready  (m2_rready),

        // Slave S0: IMEM
        .m00_axi_awid    (slv_awid[0]),    .m00_axi_awaddr  (slv_awaddr[0]),   .m00_axi_awlen   (slv_awlen[0]),   .m00_axi_awsize  (slv_awsize[0]),   .m00_axi_awburst (slv_awburst[0]),   .m00_axi_awlock  (slv_awlock[0]),   .m00_axi_awcache (slv_awcache[0]),   .m00_axi_awprot  (slv_awprot[0]),   .m00_axi_awqos   (slv_awqos[0]),   .m00_axi_awregion(slv_awregion[0]), .m00_axi_awuser  (slv_awuser[0]),   .m00_axi_awvalid (slv_awvalid[0]),   .m00_axi_awready (slv_awready[0]), .m00_axi_wdata   (slv_wdata[0]),   .m00_axi_wstrb   (slv_wstrb[0]),   .m00_axi_wlast   (slv_wlast[0]),   .m00_axi_wuser   (slv_wuser[0]),   .m00_axi_wvalid  (slv_wvalid[0]),   .m00_axi_wready  (slv_wready[0]),   .m00_axi_bid     (slv_bid[0]),     .m00_axi_bresp   (slv_bresp[0]),   .m00_axi_buser   (slv_buser[0]),   .m00_axi_bvalid  (slv_bvalid[0]),   .m00_axi_bready  (slv_bready[0]),   .m00_axi_arid    (slv_arid[0]),   .m00_axi_araddr  (slv_araddr[0]),   .m00_axi_arlen   (slv_arlen[0]),   .m00_axi_arsize  (slv_arsize[0]),   .m00_axi_arburst (slv_arburst[0]),   .m00_axi_arlock  (slv_arlock[0]),   .m00_axi_arcache (slv_arcache[0]),   .m00_axi_arprot  (slv_arprot[0]),   .m00_axi_arqos   (slv_arqos[0]),   .m00_axi_arregion(slv_arregion[0]), .m00_axi_aruser  (slv_aruser[0]),   .m00_axi_arvalid (slv_arvalid[0]),   .m00_axi_arready (slv_arready[0]), .m00_axi_rid     (slv_rid[0]),     .m00_axi_rdata   (slv_rdata[0]),   .m00_axi_rresp   (slv_rresp[0]),   .m00_axi_rlast   (slv_rlast[0]),   .m00_axi_ruser   (slv_ruser[0]),   .m00_axi_rvalid  (slv_rvalid[0]),   .m00_axi_rready  (slv_rready[0]),

        // Slave S1: DMEM
        .m01_axi_awid    (slv_awid[1]),    .m01_axi_awaddr  (slv_awaddr[1]),   .m01_axi_awlen   (slv_awlen[1]),   .m01_axi_awsize  (slv_awsize[1]),   .m01_axi_awburst (slv_awburst[1]),   .m01_axi_awlock  (slv_awlock[1]),   .m01_axi_awcache (slv_awcache[1]),   .m01_axi_awprot  (slv_awprot[1]),   .m01_axi_awqos   (slv_awqos[1]),   .m01_axi_awregion(slv_awregion[1]), .m01_axi_awuser  (slv_awuser[1]),   .m01_axi_awvalid (slv_awvalid[1]),   .m01_axi_awready (slv_awready[1]), .m01_axi_wdata   (slv_wdata[1]),   .m01_axi_wstrb   (slv_wstrb[1]),   .m01_axi_wlast   (slv_wlast[1]),   .m01_axi_wuser   (slv_wuser[1]),   .m01_axi_wvalid  (slv_wvalid[1]),   .m01_axi_wready  (slv_wready[1]),   .m01_axi_bid     (slv_bid[1]),     .m01_axi_bresp   (slv_bresp[1]),   .m01_axi_buser   (slv_buser[1]),   .m01_axi_bvalid  (slv_bvalid[1]),   .m01_axi_bready  (slv_bready[1]),   .m01_axi_arid    (slv_arid[1]),   .m01_axi_araddr  (slv_araddr[1]),   .m01_axi_arlen   (slv_arlen[1]),   .m01_axi_arsize  (slv_arsize[1]),   .m01_axi_arburst (slv_arburst[1]),   .m01_axi_arlock  (slv_arlock[1]),   .m01_axi_arcache (slv_arcache[1]),   .m01_axi_arprot  (slv_arprot[1]),   .m01_axi_arqos   (slv_arqos[1]),   .m01_axi_arregion(slv_arregion[1]), .m01_axi_aruser  (slv_aruser[1]),   .m01_axi_arvalid (slv_arvalid[1]),   .m01_axi_arready (slv_arready[1]), .m01_axi_rid     (slv_rid[1]),     .m01_axi_rdata   (slv_rdata[1]),   .m01_axi_rresp   (slv_rresp[1]),   .m01_axi_rlast   (slv_rlast[1]),   .m01_axi_ruser   (slv_ruser[1]),   .m01_axi_rvalid  (slv_rvalid[1]),   .m01_axi_rready  (slv_rready[1]),

        // Slaves S8..S14
        .m08_axi_awid    (slv_awid[8]),    .m08_axi_awaddr  (slv_awaddr[8]),   .m08_axi_awlen   (slv_awlen[8]),   .m08_axi_awsize  (slv_awsize[8]),   .m08_axi_awburst (slv_awburst[8]),   .m08_axi_awlock  (slv_awlock[8]),   .m08_axi_awcache (slv_awcache[8]),   .m08_axi_awprot  (slv_awprot[8]),   .m08_axi_awqos   (slv_awqos[8]),   .m08_axi_awregion(slv_awregion[8]), .m08_axi_awuser  (slv_awuser[8]),   .m08_axi_awvalid (slv_awvalid[8]),   .m08_axi_awready (slv_awready[8]), .m08_axi_wdata   (slv_wdata[8]),   .m08_axi_wstrb   (slv_wstrb[8]),   .m08_axi_wlast   (slv_wlast[8]),   .m08_axi_wuser   (slv_wuser[8]),   .m08_axi_wvalid  (slv_wvalid[8]),   .m08_axi_wready  (slv_wready[8]),   .m08_axi_bid     (slv_bid[8]),     .m08_axi_bresp   (slv_bresp[8]),   .m08_axi_buser   (slv_buser[8]),   .m08_axi_bvalid  (slv_bvalid[8]),   .m08_axi_bready  (slv_bready[8]),   .m08_axi_arid    (slv_arid[8]),   .m08_axi_araddr  (slv_araddr[8]),   .m08_axi_arlen   (slv_arlen[8]),   .m08_axi_arsize  (slv_arsize[8]),   .m08_axi_arburst (slv_arburst[8]),   .m08_axi_arlock  (slv_arlock[8]),   .m08_axi_arcache (slv_arcache[8]),   .m08_axi_arprot  (slv_arprot[8]),   .m08_axi_arqos   (slv_arqos[8]),   .m08_axi_arregion(slv_arregion[8]), .m08_axi_aruser  (slv_aruser[8]),   .m08_axi_arvalid (slv_arvalid[8]),   .m08_axi_arready (slv_arready[8]), .m08_axi_rid     (slv_rid[8]),     .m08_axi_rdata   (slv_rdata[8]),   .m08_axi_rresp   (slv_rresp[8]),   .m08_axi_rlast   (slv_rlast[8]),   .m08_axi_ruser   (slv_ruser[8]),   .m08_axi_rvalid  (slv_rvalid[8]),   .m08_axi_rready  (slv_rready[8]),
        .m09_axi_awid    (slv_awid[9]),    .m09_axi_awaddr  (slv_awaddr[9]),   .m09_axi_awlen   (slv_awlen[9]),   .m09_axi_awsize  (slv_awsize[9]),   .m09_axi_awburst (slv_awburst[9]),   .m09_axi_awlock  (slv_awlock[9]),   .m09_axi_awcache (slv_awcache[9]),   .m09_axi_awprot  (slv_awprot[9]),   .m09_axi_awqos   (slv_awqos[9]),   .m09_axi_awregion(slv_awregion[9]), .m09_axi_awuser  (slv_awuser[9]),   .m09_axi_awvalid (slv_awvalid[9]),   .m09_axi_awready (slv_awready[9]), .m09_axi_wdata   (slv_wdata[9]),   .m09_axi_wstrb   (slv_wstrb[9]),   .m09_axi_wlast   (slv_wlast[9]),   .m09_axi_wuser   (slv_wuser[9]),   .m09_axi_wvalid  (slv_wvalid[9]),   .m09_axi_wready  (slv_wready[9]),   .m09_axi_bid     (slv_bid[9]),     .m09_axi_bresp   (slv_bresp[9]),   .m09_axi_buser   (slv_buser[9]),   .m09_axi_bvalid  (slv_bvalid[9]),   .m09_axi_bready  (slv_bready[9]),   .m09_axi_arid    (slv_arid[9]),   .m09_axi_araddr  (slv_araddr[9]),   .m09_axi_arlen   (slv_arlen[9]),   .m09_axi_arsize  (slv_arsize[9]),   .m09_axi_arburst (slv_arburst[9]),   .m09_axi_arlock  (slv_arlock[9]),   .m09_axi_arcache (slv_arcache[9]),   .m09_axi_arprot  (slv_arprot[9]),   .m09_axi_arqos   (slv_arqos[9]),   .m09_axi_arregion(slv_arregion[9]), .m09_axi_aruser  (slv_aruser[9]),   .m09_axi_arvalid (slv_arvalid[9]),   .m09_axi_arready (slv_arready[9]), .m09_axi_rid     (slv_rid[9]),     .m09_axi_rdata   (slv_rdata[9]),   .m09_axi_rresp   (slv_rresp[9]),   .m09_axi_rlast   (slv_rlast[9]),   .m09_axi_ruser   (slv_ruser[9]),   .m09_axi_rvalid  (slv_rvalid[9]),   .m09_axi_rready  (slv_rready[9]),
        .m10_axi_awid    (slv_awid[10]),   .m10_axi_awaddr  (slv_awaddr[10]),  .m10_axi_awlen   (slv_awlen[10]),  .m10_axi_awsize  (slv_awsize[10]),  .m10_axi_awburst (slv_awburst[10]),  .m10_axi_awlock  (slv_awlock[10]),  .m10_axi_awcache (slv_awcache[10]),  .m10_axi_awprot  (slv_awprot[10]),  .m10_axi_awqos   (slv_awqos[10]),  .m10_axi_awregion(slv_awregion[10]),.m10_axi_awuser  (slv_awuser[10]),  .m10_axi_awvalid (slv_awvalid[10]),  .m10_axi_awready (slv_awready[10]),.m10_axi_wdata   (slv_wdata[10]),  .m10_axi_wstrb   (slv_wstrb[10]),  .m10_axi_wlast   (slv_wlast[10]),  .m10_axi_wuser   (slv_wuser[10]),  .m10_axi_wvalid  (slv_wvalid[10]),  .m10_axi_wready  (slv_wready[10]),  .m10_axi_bid     (slv_bid[10]),    .m10_axi_bresp   (slv_bresp[10]),  .m10_axi_buser   (slv_buser[10]),  .m10_axi_bvalid  (slv_bvalid[10]),  .m10_axi_bready  (slv_bready[10]),  .m10_axi_arid    (slv_arid[10]),  .m10_axi_araddr  (slv_araddr[10]),  .m10_axi_arlen   (slv_arlen[10]),  .m10_axi_arsize  (slv_arsize[10]),  .m10_axi_arburst (slv_arburst[10]),  .m10_axi_arlock  (slv_arlock[10]),  .m10_axi_arcache (slv_arcache[10]),  .m10_axi_arprot  (slv_arprot[10]),  .m10_axi_arqos   (slv_arqos[10]),  .m10_axi_arregion(slv_arregion[10]),.m10_axi_aruser  (slv_aruser[10]),  .m10_axi_arvalid (slv_arvalid[10]),  .m10_axi_arready (slv_arready[10]),.m10_axi_rid     (slv_rid[10]),    .m10_axi_rdata   (slv_rdata[10]),  .m10_axi_rresp   (slv_rresp[10]),  .m10_axi_rlast   (slv_rlast[10]),  .m10_axi_ruser   (slv_ruser[10]),  .m10_axi_rvalid  (slv_rvalid[10]),  .m10_axi_rready  (slv_rready[10]),
        .m11_axi_awid    (slv_awid[11]),   .m11_axi_awaddr  (slv_awaddr[11]),  .m11_axi_awlen   (slv_awlen[11]),  .m11_axi_awsize  (slv_awsize[11]),  .m11_axi_awburst (slv_awburst[11]),  .m11_axi_awlock  (slv_awlock[11]),  .m11_axi_awcache (slv_awcache[11]),  .m11_axi_awprot  (slv_awprot[11]),  .m11_axi_awqos   (slv_awqos[11]),  .m11_axi_awregion(slv_awregion[11]),.m11_axi_awuser  (slv_awuser[11]),  .m11_axi_awvalid (slv_awvalid[11]),  .m11_axi_awready (slv_awready[11]),.m11_axi_wdata   (slv_wdata[11]),  .m11_axi_wstrb   (slv_wstrb[11]),  .m11_axi_wlast   (slv_wlast[11]),  .m11_axi_wuser   (slv_wuser[11]),  .m11_axi_wvalid  (slv_wvalid[11]),  .m11_axi_wready  (slv_wready[11]),  .m11_axi_bid     (slv_bid[11]),    .m11_axi_bresp   (slv_bresp[11]),  .m11_axi_buser   (slv_buser[11]),  .m11_axi_bvalid  (slv_bvalid[11]),  .m11_axi_bready  (slv_bready[11]),  .m11_axi_arid    (slv_arid[11]),  .m11_axi_araddr  (slv_araddr[11]),  .m11_axi_arlen   (slv_arlen[11]),  .m11_axi_arsize  (slv_arsize[11]),  .m11_axi_arburst (slv_arburst[11]),  .m11_axi_arlock  (slv_arlock[11]),  .m11_axi_arcache (slv_arcache[11]),  .m11_axi_arprot  (slv_arprot[11]),  .m11_axi_arqos   (slv_arqos[11]),  .m11_axi_arregion(slv_arregion[11]),.m11_axi_aruser  (slv_aruser[11]),  .m11_axi_arvalid (slv_arvalid[11]),  .m11_axi_arready (slv_arready[11]),.m11_axi_rid     (slv_rid[11]),    .m11_axi_rdata   (slv_rdata[11]),  .m11_axi_rresp   (slv_rresp[11]),  .m11_axi_rlast   (slv_rlast[11]),  .m11_axi_ruser   (slv_ruser[11]),  .m11_axi_rvalid  (slv_rvalid[11]),  .m11_axi_rready  (slv_rready[11]),
        .m12_axi_awid    (slv_awid[12]),   .m12_axi_awaddr  (slv_awaddr[12]),  .m12_axi_awlen   (slv_awlen[12]),  .m12_axi_awsize  (slv_awsize[12]),  .m12_axi_awburst (slv_awburst[12]),  .m12_axi_awlock  (slv_awlock[12]),  .m12_axi_awcache (slv_awcache[12]),  .m12_axi_awprot  (slv_awprot[12]),  .m12_axi_awqos   (slv_awqos[12]),  .m12_axi_awregion(slv_awregion[12]),.m12_axi_awuser  (slv_awuser[12]),  .m12_axi_awvalid (slv_awvalid[12]),  .m12_axi_awready (slv_awready[12]),.m12_axi_wdata   (slv_wdata[12]),  .m12_axi_wstrb   (slv_wstrb[12]),  .m12_axi_wlast   (slv_wlast[12]),  .m12_axi_wuser   (slv_wuser[12]),  .m12_axi_wvalid  (slv_wvalid[12]),  .m12_axi_wready  (slv_wready[12]),  .m12_axi_bid     (slv_bid[12]),    .m12_axi_bresp   (slv_bresp[12]),  .m12_axi_buser   (slv_buser[12]),  .m12_axi_bvalid  (slv_bvalid[12]),  .m12_axi_bready  (slv_bready[12]),  .m12_axi_arid    (slv_arid[12]),  .m12_axi_araddr  (slv_araddr[12]),  .m12_axi_arlen   (slv_arlen[12]),  .m12_axi_arsize  (slv_arsize[12]),  .m12_axi_arburst (slv_arburst[12]),  .m12_axi_arlock  (slv_arlock[12]),  .m12_axi_arcache (slv_arcache[12]),  .m12_axi_arprot  (slv_arprot[12]),  .m12_axi_arqos   (slv_arqos[12]),  .m12_axi_arregion(slv_arregion[12]),.m12_axi_aruser  (slv_aruser[12]),  .m12_axi_arvalid (slv_arvalid[12]),  .m12_axi_arready (slv_arready[12]),.m12_axi_rid     (slv_rid[12]),    .m12_axi_rdata   (slv_rdata[12]),  .m12_axi_rresp   (slv_rresp[12]),  .m12_axi_rlast   (slv_rlast[12]),  .m12_axi_ruser   (slv_ruser[12]),  .m12_axi_rvalid  (slv_rvalid[12]),  .m12_axi_rready  (slv_rready[12]),
        .m14_axi_awid    (slv_awid[14]),   .m14_axi_awaddr  (slv_awaddr[14]),  .m14_axi_awlen   (slv_awlen[14]),  .m14_axi_awsize  (slv_awsize[14]),  .m14_axi_awburst (slv_awburst[14]),  .m14_axi_awlock  (slv_awlock[14]),  .m14_axi_awcache (slv_awcache[14]),  .m14_axi_awprot  (slv_awprot[14]),  .m14_axi_awqos   (slv_awqos[14]),  .m14_axi_awregion(slv_awregion[14]),.m14_axi_awuser  (slv_awuser[14]),  .m14_axi_awvalid (slv_awvalid[14]),  .m14_axi_awready (slv_awready[14]),.m14_axi_wdata   (slv_wdata[14]),  .m14_axi_wstrb   (slv_wstrb[14]),  .m14_axi_wlast   (slv_wlast[14]),  .m14_axi_wuser   (slv_wuser[14]),  .m14_axi_wvalid  (slv_wvalid[14]),  .m14_axi_wready  (slv_wready[14]),  .m14_axi_bid     (slv_bid[14]),    .m14_axi_bresp   (slv_bresp[14]),  .m14_axi_buser   (slv_buser[14]),  .m14_axi_bvalid  (slv_bvalid[14]),  .m14_axi_bready  (slv_bready[14]),  .m14_axi_arid    (slv_arid[14]),  .m14_axi_araddr  (slv_araddr[14]),  .m14_axi_arlen   (slv_arlen[14]),  .m14_axi_arsize  (slv_arsize[14]),  .m14_axi_arburst (slv_arburst[14]),  .m14_axi_arlock  (slv_arlock[14]),  .m14_axi_arcache (slv_arcache[14]),  .m14_axi_arprot  (slv_arprot[14]),  .m14_axi_arqos   (slv_arqos[14]),  .m14_axi_arregion(slv_arregion[14]),.m14_axi_aruser  (slv_aruser[14]),  .m14_axi_arvalid (slv_arvalid[14]),  .m14_axi_arready (slv_arready[14]),.m14_axi_rid     (slv_rid[14]),    .m14_axi_rdata   (slv_rdata[14]),  .m14_axi_rresp   (slv_rresp[14]),  .m14_axi_rlast   (slv_rlast[14]),  .m14_axi_ruser   (slv_ruser[14]),  .m14_axi_rvalid  (slv_rvalid[14]),  .m14_axi_rready  (slv_rready[14]),

        // RISC-V VeeR EL2 CPU Interface & Control
        .cpu_rst_l              (cpu_rst_l),
        .cpu_rst_vec            (cpu_rst_vec),
        .cpu_run_req            (cpu_run_req),
        .trace_rv_i_insn_ip     (trace_rv_i_insn_ip),
        .trace_rv_i_address_ip  (trace_rv_i_address_ip),
        .trace_rv_i_valid_ip    (trace_rv_i_valid_ip),
        .trace_rv_i_exception_ip(trace_rv_i_exception_ip),
        .trace_rv_i_ecause_ip   (trace_rv_i_ecause_ip),
        .trace_rv_i_interrupt_ip(trace_rv_i_interrupt_ip),
        .trace_rv_i_tval_ip     (trace_rv_i_tval_ip),
        .o_cpu_halt_status      (o_cpu_halt_status)
    );

    // ============================================================
    // UVM CONFIGURATION & TEST STARTUP
    // ============================================================
    initial begin
        string fsdb_name = "gpio_data_121_to_130.fsdb";
        string vcd_name  = "gpio_data_121_to_130.vcd";

        // Initialize Master BFM signals
        u_soc_ctrl_if.init_master();

        // Register Virtual Interfaces into UVM Config DB
        uvm_config_db#(virtual gpio_if)::set(null, "*", "gpio_vif", u_gpio_if);
        uvm_config_db#(virtual uart_if)::set(null, "*", "uart_vif", u_uart_if);
        uvm_config_db#(virtual pwm_if)::set(null, "*", "pwm_vif", u_pwm_if);
        uvm_config_db#(virtual soc_ctrl_if)::set(null, "*", "soc_ctrl_vif", u_soc_ctrl_if);

        // Waveform dump configuration
        void'($value$plusargs("FSDB_FILE=%s", fsdb_name));
        void'($value$plusargs("VCD_FILE=%s", vcd_name));

        if ($test$plusargs("FSDB")) begin
`ifdef DUMP_FSDB
            $fsdbDumpfile(fsdb_name);
            $fsdbDumpvars(0, tb_soc_uvm_top, "+all", "+mda", "+struct");
`endif
        end
        if ($test$plusargs("VCD")) begin
            $dumpfile(vcd_name);
            $dumpvars(0, tb_soc_uvm_top);
        end

        // Start common UVM test
        run_test("soc_uvm_test");
    end

    // Safety simulation watchdog timer
    initial begin
        #50_000_000; // 50 ms timeout
        `uvm_fatal("TIMEOUT", "Simulation Watchdog Timeout reached in tb_soc_uvm_top!")
    end

endmodule

`default_nettype wire
