// ==============================================================================
// Module: veer_wrapper_axi32
// Project: RISC-V VeeR EL2 SoC Integration
// Description:
//   Wraps the CHIPS Alliance VeeR EL2 RISC-V Core (el2_veer_wrapper),
//   instantiates the internal SRAM interface (el2_mem_if), and integrates two
//   axi64_to_axi32_adapter instances to convert:
//     - 64-bit VeeR IFU AXI interface -> 32-bit AXI4 Master (M0: s00_axi)
//     - 64-bit VeeR LSU AXI interface -> 32-bit AXI4 Master (M1: s01_axi)
//
// Interrupts:
//   Connects external SoC interrupts to VeeR's internal PIC (el2_pic_ctrl):
//     Bit 1: UART Interrupt (uart_irq)
//     Bit 2: GPIO Interrupt (gpio_irq)
//     Bit 3: Timer Interrupt (timer_irq)
//     Bit 4: FFT Interrupt (fft_irq)
//     Bit 5: DMA Completion Interrupt (dma_irq)
//     Bit 6: DMA Error Interrupt (dma_error_irq)
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype none

module veer_wrapper_axi32
import el2_pkg::*;
#(
`include "el2_param.vh"
,
    parameter DATA_WIDTH      = 32,
    parameter ADDR_WIDTH      = 32,
    parameter STRB_WIDTH      = (DATA_WIDTH/8),
    parameter ID_WIDTH        = 8
)(
    input  wire                     clk,
    input  wire                     rst_l,          // Active-low core reset
    input  wire [31:1]              rst_vec,        // Boot PC / 2 (e.g. 31'h0002_0000 for 0x0004_0000)

    // Interrupts from SoC peripherals
    input  wire                     uart_irq,
    input  wire                     gpio_irq,
    input  wire                     timer_irq,
    input  wire                     fft_irq,
    input  wire                     dma_irq,
    input  wire                     dma_error_irq,

    // CPU Run Control
    input  wire                     mpc_reset_run_req,

    // Instruction Trace (for verification & debug)
    output wire [31:0]              trace_rv_i_insn_ip,
    output wire [31:0]              trace_rv_i_address_ip,
    output wire                     trace_rv_i_valid_ip,
    output wire                     trace_rv_i_exception_ip,
    output wire [4:0]               trace_rv_i_ecause_ip,
    output wire                     trace_rv_i_interrupt_ip,
    output wire [31:0]              trace_rv_i_tval_ip,

    // Core Status
    output wire                     o_cpu_halt_status,

    // ============================================================
    // M0: 32-bit AXI4 Master for IFU (s00_axi on interconnect)
    // ============================================================
    output wire [ID_WIDTH-1:0]      m0_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m0_axi_awaddr,
    output wire [7:0]               m0_axi_awlen,
    output wire [2:0]               m0_axi_awsize,
    output wire [1:0]               m0_axi_awburst,
    output wire                     m0_axi_awlock,
    output wire [3:0]               m0_axi_awcache,
    output wire [2:0]               m0_axi_awprot,
    output wire [3:0]               m0_axi_awqos,
    output wire [3:0]               m0_axi_awregion,
    output wire                     m0_axi_awvalid,
    input  wire                     m0_axi_awready,
    output wire [DATA_WIDTH-1:0]    m0_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m0_axi_wstrb,
    output wire                     m0_axi_wlast,
    output wire                     m0_axi_wvalid,
    input  wire                     m0_axi_wready,
    input  wire [ID_WIDTH-1:0]      m0_axi_bid,
    input  wire [1:0]               m0_axi_bresp,
    input  wire                     m0_axi_bvalid,
    output wire                     m0_axi_bready,
    output wire [ID_WIDTH-1:0]      m0_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m0_axi_araddr,
    output wire [7:0]               m0_axi_arlen,
    output wire [2:0]               m0_axi_arsize,
    output wire [1:0]               m0_axi_arburst,
    output wire                     m0_axi_arlock,
    output wire [3:0]               m0_axi_arcache,
    output wire [2:0]               m0_axi_arprot,
    output wire [3:0]               m0_axi_arqos,
    output wire [3:0]               m0_axi_arregion,
    output wire                     m0_axi_arvalid,
    input  wire                     m0_axi_arready,
    input  wire [ID_WIDTH-1:0]      m0_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m0_axi_rdata,
    input  wire [1:0]               m0_axi_rresp,
    input  wire                     m0_axi_rlast,
    input  wire                     m0_axi_rvalid,
    output wire                     m0_axi_rready,

    // ============================================================
    // M1: 32-bit AXI4 Master for LSU (s01_axi on interconnect)
    // ============================================================
    output wire [ID_WIDTH-1:0]      m1_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m1_axi_awaddr,
    output wire [7:0]               m1_axi_awlen,
    output wire [2:0]               m1_axi_awsize,
    output wire [1:0]               m1_axi_awburst,
    output wire                     m1_axi_awlock,
    output wire [3:0]               m1_axi_awcache,
    output wire [2:0]               m1_axi_awprot,
    output wire [3:0]               m1_axi_awqos,
    output wire [3:0]               m1_axi_awregion,
    output wire                     m1_axi_awvalid,
    input  wire                     m1_axi_awready,
    output wire [DATA_WIDTH-1:0]    m1_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m1_axi_wstrb,
    output wire                     m1_axi_wlast,
    output wire                     m1_axi_wvalid,
    input  wire                     m1_axi_wready,
    input  wire [ID_WIDTH-1:0]      m1_axi_bid,
    input  wire [1:0]               m1_axi_bresp,
    input  wire                     m1_axi_bvalid,
    output wire                     m1_axi_bready,
    output wire [ID_WIDTH-1:0]      m1_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m1_axi_araddr,
    output wire [7:0]               m1_axi_arlen,
    output wire [2:0]               m1_axi_arsize,
    output wire [1:0]               m1_axi_arburst,
    output wire                     m1_axi_arlock,
    output wire [3:0]               m1_axi_arcache,
    output wire [2:0]               m1_axi_arprot,
    output wire [3:0]               m1_axi_arqos,
    output wire [3:0]               m1_axi_arregion,
    output wire                     m1_axi_arvalid,
    input  wire                     m1_axi_arready,
    input  wire [ID_WIDTH-1:0]      m1_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m1_axi_rdata,
    input  wire [1:0]               m1_axi_rresp,
    input  wire                     m1_axi_rlast,
    input  wire                     m1_axi_rvalid,
    output wire                     m1_axi_rready
);

    wire rst_sync = ~rst_l;

    // ------------------------------------------------------------
    // Internal 64-bit AXI signals from VeeR EL2 IFU
    // ------------------------------------------------------------
    wire                            core_ifu_awvalid;
    wire                            core_ifu_awready;
    wire [pt.IFU_BUS_TAG-1:0]       core_ifu_awid;
    wire [31:0]                     core_ifu_awaddr;
    wire [3:0]                      core_ifu_awregion;
    wire [7:0]                      core_ifu_awlen;
    wire [2:0]                      core_ifu_awsize;
    wire [1:0]                      core_ifu_awburst;
    wire                            core_ifu_awlock;
    wire [3:0]                      core_ifu_awcache;
    wire [2:0]                      core_ifu_awprot;
    wire [3:0]                      core_ifu_awqos;

    wire                            core_ifu_wvalid;
    wire                            core_ifu_wready;
    wire [63:0]                     core_ifu_wdata;
    wire [7:0]                      core_ifu_wstrb;
    wire                            core_ifu_wlast;

    wire                            core_ifu_bvalid;
    wire                            core_ifu_bready;
    wire [1:0]                      core_ifu_bresp;
    wire [pt.IFU_BUS_TAG-1:0]       core_ifu_bid;

    wire                            core_ifu_arvalid;
    wire                            core_ifu_arready;
    wire [pt.IFU_BUS_TAG-1:0]       core_ifu_arid;
    wire [31:0]                     core_ifu_araddr;
    wire [3:0]                      core_ifu_arregion;
    wire [7:0]                      core_ifu_arlen;
    wire [2:0]                      core_ifu_arsize;
    wire [1:0]                      core_ifu_arburst;
    wire                            core_ifu_arlock;
    wire [3:0]                      core_ifu_arcache;
    wire [2:0]                      core_ifu_arprot;
    wire [3:0]                      core_ifu_arqos;

    wire                            core_ifu_rvalid;
    wire                            core_ifu_rready;
    wire [pt.IFU_BUS_TAG-1:0]       core_ifu_rid;
    wire [63:0]                     core_ifu_rdata;
    wire [1:0]                      core_ifu_rresp;
    wire                            core_ifu_rlast;

    // ------------------------------------------------------------
    // Internal 64-bit AXI signals from VeeR EL2 LSU
    // ------------------------------------------------------------
    wire                            core_lsu_awvalid;
    wire                            core_lsu_awready;
    wire [pt.LSU_BUS_TAG-1:0]       core_lsu_awid;
    wire [31:0]                     core_lsu_awaddr;
    wire [3:0]                      core_lsu_awregion;
    wire [7:0]                      core_lsu_awlen;
    wire [2:0]                      core_lsu_awsize;
    wire [1:0]                      core_lsu_awburst;
    wire                            core_lsu_awlock;
    wire [3:0]                      core_lsu_awcache;
    wire [2:0]                      core_lsu_awprot;
    wire [3:0]                      core_lsu_awqos;

    wire                            core_lsu_wvalid;
    wire                            core_lsu_wready;
    wire [63:0]                     core_lsu_wdata;
    wire [7:0]                      core_lsu_wstrb;
    wire                            core_lsu_wlast;

    wire                            core_lsu_bvalid;
    wire                            core_lsu_bready;
    wire [1:0]                      core_lsu_bresp;
    wire [pt.LSU_BUS_TAG-1:0]       core_lsu_bid;

    wire                            core_lsu_arvalid;
    wire                            core_lsu_arready;
    wire [pt.LSU_BUS_TAG-1:0]       core_lsu_arid;
    wire [31:0]                     core_lsu_araddr;
    wire [3:0]                      core_lsu_arregion;
    wire [7:0]                      core_lsu_arlen;
    wire [2:0]                      core_lsu_arsize;
    wire [1:0]                      core_lsu_arburst;
    wire                            core_lsu_arlock;
    wire [3:0]                      core_lsu_arcache;
    wire [2:0]                      core_lsu_arprot;
    wire [3:0]                      core_lsu_arqos;

    wire                            core_lsu_rvalid;
    wire                            core_lsu_rready;
    wire [pt.LSU_BUS_TAG-1:0]       core_lsu_rid;
    wire [63:0]                     core_lsu_rdata;
    wire [1:0]                      core_lsu_rresp;
    wire                            core_lsu_rlast;

    // ------------------------------------------------------------
    // Interrupt Vector Mapping into PIC (el2_pic_ctrl)
    // ------------------------------------------------------------
    wire [pt.PIC_TOTAL_INT:1]       extintsrc_req;
    assign extintsrc_req[1] = uart_irq;
    assign extintsrc_req[2] = gpio_irq;
    assign extintsrc_req[3] = timer_irq;
    assign extintsrc_req[4] = fft_irq;
    assign extintsrc_req[5] = dma_irq;
    assign extintsrc_req[6] = dma_error_irq;
    generate
        if (pt.PIC_TOTAL_INT > 6) begin : gen_pic_pad
            assign extintsrc_req[pt.PIC_TOTAL_INT:7] = '0;
        end
    endgenerate

    // ------------------------------------------------------------
    // Memory Interface
    // ------------------------------------------------------------
    el2_mem_if mem_export ();

    // ------------------------------------------------------------
    // VeeR EL2 Core Instance
    // ------------------------------------------------------------
    el2_veer_wrapper #(.pt(pt)) u_veer_core (
        .clk                        (clk),
        .rst_l                      (rst_l),
        .dbg_rst_l                  (rst_l),
        .rst_vec                    (rst_vec),
        .nmi_int                    (1'b0),
        .nmi_vec                    (31'h0),
        .jtag_id                    (31'h0),

        // Trace
        .trace_rv_i_insn_ip         (trace_rv_i_insn_ip),
        .trace_rv_i_address_ip      (trace_rv_i_address_ip),
        .trace_rv_i_valid_ip        (trace_rv_i_valid_ip),
        .trace_rv_i_exception_ip    (trace_rv_i_exception_ip),
        .trace_rv_i_ecause_ip       (trace_rv_i_ecause_ip),
        .trace_rv_i_interrupt_ip    (trace_rv_i_interrupt_ip),
        .trace_rv_i_tval_ip         (trace_rv_i_tval_ip),

        // LSU AXI
        .lsu_axi_awvalid            (core_lsu_awvalid),
        .lsu_axi_awready            (core_lsu_awready),
        .lsu_axi_awid               (core_lsu_awid),
        .lsu_axi_awaddr             (core_lsu_awaddr),
        .lsu_axi_awregion           (core_lsu_awregion),
        .lsu_axi_awlen              (core_lsu_awlen),
        .lsu_axi_awsize             (core_lsu_awsize),
        .lsu_axi_awburst            (core_lsu_awburst),
        .lsu_axi_awlock             (core_lsu_awlock),
        .lsu_axi_awcache            (core_lsu_awcache),
        .lsu_axi_awprot             (core_lsu_awprot),
        .lsu_axi_awqos              (core_lsu_awqos),

        .lsu_axi_wvalid             (core_lsu_wvalid),
        .lsu_axi_wready             (core_lsu_wready),
        .lsu_axi_wdata              (core_lsu_wdata),
        .lsu_axi_wstrb              (core_lsu_wstrb),
        .lsu_axi_wlast              (core_lsu_wlast),

        .lsu_axi_bvalid             (core_lsu_bvalid),
        .lsu_axi_bready             (core_lsu_bready),
        .lsu_axi_bresp              (core_lsu_bresp),
        .lsu_axi_bid                (core_lsu_bid),

        .lsu_axi_arvalid            (core_lsu_arvalid),
        .lsu_axi_arready            (core_lsu_arready),
        .lsu_axi_arid               (core_lsu_arid),
        .lsu_axi_araddr             (core_lsu_araddr),
        .lsu_axi_arregion           (core_lsu_arregion),
        .lsu_axi_arlen              (core_lsu_arlen),
        .lsu_axi_arsize             (core_lsu_arsize),
        .lsu_axi_arburst            (core_lsu_arburst),
        .lsu_axi_arlock             (core_lsu_arlock),
        .lsu_axi_arcache            (core_lsu_arcache),
        .lsu_axi_arprot             (core_lsu_arprot),
        .lsu_axi_arqos              (core_lsu_arqos),

        .lsu_axi_rvalid             (core_lsu_rvalid),
        .lsu_axi_rready             (core_lsu_rready),
        .lsu_axi_rid                (core_lsu_rid),
        .lsu_axi_rdata              (core_lsu_rdata),
        .lsu_axi_rresp              (core_lsu_rresp),
        .lsu_axi_rlast              (core_lsu_rlast),

        // IFU AXI
        .ifu_axi_awvalid            (core_ifu_awvalid),
        .ifu_axi_awready            (core_ifu_awready),
        .ifu_axi_awid               (core_ifu_awid),
        .ifu_axi_awaddr             (core_ifu_awaddr),
        .ifu_axi_awregion           (core_ifu_awregion),
        .ifu_axi_awlen              (core_ifu_awlen),
        .ifu_axi_awsize             (core_ifu_awsize),
        .ifu_axi_awburst            (core_ifu_awburst),
        .ifu_axi_awlock             (core_ifu_awlock),
        .ifu_axi_awcache            (core_ifu_awcache),
        .ifu_axi_awprot             (core_ifu_awprot),
        .ifu_axi_awqos              (core_ifu_awqos),

        .ifu_axi_wvalid             (core_ifu_wvalid),
        .ifu_axi_wready             (core_ifu_wready),
        .ifu_axi_wdata              (core_ifu_wdata),
        .ifu_axi_wstrb              (core_ifu_wstrb),
        .ifu_axi_wlast              (core_ifu_wlast),

        .ifu_axi_bvalid             (core_ifu_bvalid),
        .ifu_axi_bready             (core_ifu_bready),
        .ifu_axi_bresp              (core_ifu_bresp),
        .ifu_axi_bid                (core_ifu_bid),

        .ifu_axi_arvalid            (core_ifu_arvalid),
        .ifu_axi_arready            (core_ifu_arready),
        .ifu_axi_arid               (core_ifu_arid),
        .ifu_axi_araddr             (core_ifu_araddr),
        .ifu_axi_arregion           (core_ifu_arregion),
        .ifu_axi_arlen              (core_ifu_arlen),
        .ifu_axi_arsize             (core_ifu_arsize),
        .ifu_axi_arburst            (core_ifu_arburst),
        .ifu_axi_arlock             (core_ifu_arlock),
        .ifu_axi_arcache            (core_ifu_arcache),
        .ifu_axi_arprot             (core_ifu_arprot),
        .ifu_axi_arqos              (core_ifu_arqos),

        .ifu_axi_rvalid             (core_ifu_rvalid),
        .ifu_axi_rready             (core_ifu_rready),
        .ifu_axi_rid                (core_ifu_rid),
        .ifu_axi_rdata              (core_ifu_rdata),
        .ifu_axi_rresp              (core_ifu_rresp),
        .ifu_axi_rlast              (core_ifu_rlast),

        // SB AXI (Debug - unused)
        .sb_axi_awvalid             (),
        .sb_axi_awready             (1'b0),
        .sb_axi_awid                (),
        .sb_axi_awaddr              (),
        .sb_axi_awregion            (),
        .sb_axi_awlen               (),
        .sb_axi_awsize              (),
        .sb_axi_awburst             (),
        .sb_axi_awlock              (),
        .sb_axi_awcache             (),
        .sb_axi_awprot              (),
        .sb_axi_awqos               (),
        .sb_axi_wvalid              (),
        .sb_axi_wready              (1'b0),
        .sb_axi_wdata               (),
        .sb_axi_wstrb               (),
        .sb_axi_wlast               (),
        .sb_axi_bvalid              (1'b0),
        .sb_axi_bready              (),
        .sb_axi_bresp               (2'b00),
        .sb_axi_bid                 ({pt.SB_BUS_TAG{1'b0}}),
        .sb_axi_arvalid             (),
        .sb_axi_arready             (1'b0),
        .sb_axi_arid                (),
        .sb_axi_araddr              (),
        .sb_axi_arregion            (),
        .sb_axi_arlen               (),
        .sb_axi_arsize              (),
        .sb_axi_arburst             (),
        .sb_axi_arlock              (),
        .sb_axi_arcache             (),
        .sb_axi_arprot              (),
        .sb_axi_arqos               (),
        .sb_axi_rvalid              (1'b0),
        .sb_axi_rready              (),
        .sb_axi_rid                 ({pt.SB_BUS_TAG{1'b0}}),
        .sb_axi_rdata               (64'h0),
        .sb_axi_rresp               (2'b00),
        .sb_axi_rlast               (1'b0),

        // DMA AXI Slave (unused)
        .dma_axi_awvalid            (1'b0),
        .dma_axi_awready            (),
        .dma_axi_awid               ({pt.DMA_BUS_TAG{1'b0}}),
        .dma_axi_awaddr             (32'h0),
        .dma_axi_awsize             (3'b0),
        .dma_axi_awprot             (3'b0),
        .dma_axi_awlen              (8'b0),
        .dma_axi_awburst            (2'b0),
        .dma_axi_wvalid             (1'b0),
        .dma_axi_wready             (),
        .dma_axi_wdata              (64'h0),
        .dma_axi_wstrb              (8'h0),
        .dma_axi_wlast              (1'b0),
        .dma_axi_bvalid             (),
        .dma_axi_bready             (1'b0),
        .dma_axi_bresp              (),
        .dma_axi_bid                (),
        .dma_axi_arvalid            (1'b0),
        .dma_axi_arready            (),
        .dma_axi_arid               ({pt.DMA_BUS_TAG{1'b0}}),
        .dma_axi_araddr             (32'h0),
        .dma_axi_arsize             (3'b0),
        .dma_axi_arprot             (3'b0),
        .dma_axi_arlen              (8'b0),
        .dma_axi_arburst            (2'b0),
        .dma_axi_rvalid             (),
        .dma_axi_rready             (1'b0),
        .dma_axi_rid                (),
        .dma_axi_rdata              (),
        .dma_axi_rresp              (),
        .dma_axi_rlast              (),

        // Clock enables
        .lsu_bus_clk_en             (1'b1),
        .ifu_bus_clk_en             (1'b1),
        .dbg_bus_clk_en             (1'b1),
        .dma_bus_clk_en             (1'b1),

        // ECC status
        .iccm_ecc_single_error      (),
        .iccm_ecc_double_error      (),
        .dccm_ecc_single_error      (),
        .dccm_ecc_double_error      (),
        .dccm_write_readback_error  (),

        // Memory interfaces
        .el2_icache_export          (mem_export.veer_icache_src),
        .el2_mem_export             (mem_export.veer_sram_src),

        // Interrupts
        .timer_int                  (timer_irq),
        .soft_int                   (1'b0),
        .extintsrc_req              (extintsrc_req),

        // Performance counters
        .dec_tlu_perfcnt0           (),
        .dec_tlu_perfcnt1           (),
        .dec_tlu_perfcnt2           (),
        .dec_tlu_perfcnt3           (),

        // JTAG (tied off)
        .jtag_tck                   (1'b0),
        .jtag_tms                   (1'b0),
        .jtag_tdi                   (1'b0),
        .jtag_trst_n                (1'b0),
        .jtag_tdo                   (),
        .jtag_tdoEn                 (),

        .core_id                    (28'h0),

        // MPC / Run Control
        .mpc_debug_halt_req         (1'b0),
        .mpc_debug_run_req          (1'b0),
        .mpc_reset_run_req          (mpc_reset_run_req),
        .mpc_debug_halt_ack         (),
        .mpc_debug_run_ack          (),
        .debug_brkpt_status         (),

        .i_cpu_halt_req             (1'b0),
        .o_cpu_halt_ack             (),
        .o_cpu_halt_status          (o_cpu_halt_status),
        .o_debug_mode_status        (),
        .i_cpu_run_req              (1'b0),
        .o_cpu_run_ack              (),

        .scan_mode                  (1'b0),
        .mbist_mode                 (1'b0),

        // DMI (tied off)
        .dmi_core_enable            (1'b0),
        .dmi_uncore_enable          (1'b0),
        .dmi_uncore_en              (),
        .dmi_uncore_wr_en           (),
        .dmi_uncore_addr            (),
        .dmi_uncore_wdata           (),
        .dmi_uncore_rdata           (32'h0),
        .dmi_active                 ()
    );

    // ============================================================
    // IFU 64-to-32 AXI Adapter -> M0 (s00_axi)
    // ============================================================
    axi64_to_axi32_adapter #(
        .M_ID_WIDTH (pt.IFU_BUS_TAG),
        .S_ID_WIDTH (ID_WIDTH)
    ) u_ifu_adapter (
        .clk            (clk),
        .rst            (rst_sync),

        // 64-bit Master (from IFU)
        .m_axi_awvalid  (core_ifu_awvalid),
        .m_axi_awready  (core_ifu_awready),
        .m_axi_awid     (core_ifu_awid),
        .m_axi_awaddr   (core_ifu_awaddr),
        .m_axi_awlen    (core_ifu_awlen),
        .m_axi_awsize   (core_ifu_awsize),
        .m_axi_awburst  (core_ifu_awburst),
        .m_axi_awlock   (core_ifu_awlock),
        .m_axi_awcache  (core_ifu_awcache),
        .m_axi_awprot   (core_ifu_awprot),
        .m_axi_awqos    (core_ifu_awqos),
        .m_axi_awregion (core_ifu_awregion),

        .m_axi_wvalid   (core_ifu_wvalid),
        .m_axi_wready   (core_ifu_wready),
        .m_axi_wdata    (core_ifu_wdata),
        .m_axi_wstrb    (core_ifu_wstrb),
        .m_axi_wlast    (core_ifu_wlast),

        .m_axi_bvalid   (core_ifu_bvalid),
        .m_axi_bready   (core_ifu_bready),
        .m_axi_bresp    (core_ifu_bresp),
        .m_axi_bid      (core_ifu_bid),

        .m_axi_arvalid  (core_ifu_arvalid),
        .m_axi_arready  (core_ifu_arready),
        .m_axi_arid     (core_ifu_arid),
        .m_axi_araddr   (core_ifu_araddr),
        .m_axi_arlen    (core_ifu_arlen),
        .m_axi_arsize   (core_ifu_arsize),
        .m_axi_arburst  (core_ifu_arburst),
        .m_axi_arlock   (core_ifu_arlock),
        .m_axi_arcache  (core_ifu_arcache),
        .m_axi_arprot   (core_ifu_arprot),
        .m_axi_arqos    (core_ifu_arqos),
        .m_axi_arregion (core_ifu_arregion),

        .m_axi_rvalid   (core_ifu_rvalid),
        .m_axi_rready   (core_ifu_rready),
        .m_axi_rid      (core_ifu_rid),
        .m_axi_rdata    (core_ifu_rdata),
        .m_axi_rresp    (core_ifu_rresp),
        .m_axi_rlast    (core_ifu_rlast),

        // 32-bit Slave (to Interconnect M0)
        .s_axi_awvalid  (m0_axi_awvalid),
        .s_axi_awready  (m0_axi_awready),
        .s_axi_awid     (m0_axi_awid),
        .s_axi_awaddr   (m0_axi_awaddr),
        .s_axi_awlen    (m0_axi_awlen),
        .s_axi_awsize   (m0_axi_awsize),
        .s_axi_awburst  (m0_axi_awburst),
        .s_axi_awlock   (m0_axi_awlock),
        .s_axi_awcache  (m0_axi_awcache),
        .s_axi_awprot   (m0_axi_awprot),
        .s_axi_awqos    (m0_axi_awqos),
        .s_axi_awregion (m0_axi_awregion),

        .s_axi_wvalid   (m0_axi_wvalid),
        .s_axi_wready   (m0_axi_wready),
        .s_axi_wdata    (m0_axi_wdata),
        .s_axi_wstrb    (m0_axi_wstrb),
        .s_axi_wlast    (m0_axi_wlast),

        .s_axi_bvalid   (m0_axi_bvalid),
        .s_axi_bready   (m0_axi_bready),
        .s_axi_bresp    (m0_axi_bresp),
        .s_axi_bid      (m0_axi_bid),

        .s_axi_arvalid  (m0_axi_arvalid),
        .s_axi_arready  (m0_axi_arready),
        .s_axi_arid     (m0_axi_arid),
        .s_axi_araddr   (m0_axi_araddr),
        .s_axi_arlen    (m0_axi_arlen),
        .s_axi_arsize   (m0_axi_arsize),
        .s_axi_arburst  (m0_axi_arburst),
        .s_axi_arlock   (m0_axi_arlock),
        .s_axi_arcache  (m0_axi_arcache),
        .s_axi_arprot   (m0_axi_arprot),
        .s_axi_arqos    (m0_axi_arqos),
        .s_axi_arregion (m0_axi_arregion),

        .s_axi_rvalid   (m0_axi_rvalid),
        .s_axi_rready   (m0_axi_rready),
        .s_axi_rid      (m0_axi_rid),
        .s_axi_rdata    (m0_axi_rdata),
        .s_axi_rresp    (m0_axi_rresp),
        .s_axi_rlast    (m0_axi_rlast)
    );

    // ============================================================
    // LSU 64-to-32 AXI Adapter -> M1 (s01_axi)
    // ============================================================
    axi64_to_axi32_adapter #(
        .M_ID_WIDTH (pt.LSU_BUS_TAG),
        .S_ID_WIDTH (ID_WIDTH)
    ) u_lsu_adapter (
        .clk            (clk),
        .rst            (rst_sync),

        // 64-bit Master (from LSU)
        .m_axi_awvalid  (core_lsu_awvalid),
        .m_axi_awready  (core_lsu_awready),
        .m_axi_awid     (core_lsu_awid),
        .m_axi_awaddr   (core_lsu_awaddr),
        .m_axi_awlen    (core_lsu_awlen),
        .m_axi_awsize   (core_lsu_awsize),
        .m_axi_awburst  (core_lsu_awburst),
        .m_axi_awlock   (core_lsu_awlock),
        .m_axi_awcache  (core_lsu_awcache),
        .m_axi_awprot   (core_lsu_awprot),
        .m_axi_awqos    (core_lsu_awqos),
        .m_axi_awregion (core_lsu_awregion),

        .m_axi_wvalid   (core_lsu_wvalid),
        .m_axi_wready   (core_lsu_wready),
        .m_axi_wdata    (core_lsu_wdata),
        .m_axi_wstrb    (core_lsu_wstrb),
        .m_axi_wlast    (core_lsu_wlast),

        .m_axi_bvalid   (core_lsu_bvalid),
        .m_axi_bready   (core_lsu_bready),
        .m_axi_bresp    (core_lsu_bresp),
        .m_axi_bid      (core_lsu_bid),

        .m_axi_arvalid  (core_lsu_arvalid),
        .m_axi_arready  (core_lsu_arready),
        .m_axi_arid     (core_lsu_arid),
        .m_axi_araddr   (core_lsu_araddr),
        .m_axi_arlen    (core_lsu_arlen),
        .m_axi_arsize   (core_lsu_arsize),
        .m_axi_arburst  (core_lsu_arburst),
        .m_axi_arlock   (core_lsu_arlock),
        .m_axi_arcache  (core_lsu_arcache),
        .m_axi_arprot   (core_lsu_arprot),
        .m_axi_arqos    (core_lsu_arqos),
        .m_axi_arregion (core_lsu_arregion),

        .m_axi_rvalid   (core_lsu_rvalid),
        .m_axi_rready   (core_lsu_rready),
        .m_axi_rid      (core_lsu_rid),
        .m_axi_rdata    (core_lsu_rdata),
        .m_axi_rresp    (core_lsu_rresp),
        .m_axi_rlast    (core_lsu_rlast),

        // 32-bit Slave (to Interconnect M1)
        .s_axi_awvalid  (m1_axi_awvalid),
        .s_axi_awready  (m1_axi_awready),
        .s_axi_awid     (m1_axi_awid),
        .s_axi_awaddr   (m1_axi_awaddr),
        .s_axi_awlen    (m1_axi_awlen),
        .s_axi_awsize   (m1_axi_awsize),
        .s_axi_awburst  (m1_axi_awburst),
        .s_axi_awlock   (m1_axi_awlock),
        .s_axi_awcache  (m1_axi_awcache),
        .s_axi_awprot   (m1_axi_awprot),
        .s_axi_awqos    (m1_axi_awqos),
        .s_axi_awregion (m1_axi_awregion),

        .s_axi_wvalid   (m1_axi_wvalid),
        .s_axi_wready   (m1_axi_wready),
        .s_axi_wdata    (m1_axi_wdata),
        .s_axi_wstrb    (m1_axi_wstrb),
        .s_axi_wlast    (m1_axi_wlast),

        .s_axi_bvalid   (m1_axi_bvalid),
        .s_axi_bready   (m1_axi_bready),
        .s_axi_bresp    (m1_axi_bresp),
        .s_axi_bid      (m1_axi_bid),

        .s_axi_arvalid  (m1_axi_arvalid),
        .s_axi_arready  (m1_axi_arready),
        .s_axi_arid     (m1_axi_arid),
        .s_axi_araddr   (m1_axi_araddr),
        .s_axi_arlen    (m1_axi_arlen),
        .s_axi_arsize   (m1_axi_arsize),
        .s_axi_arburst  (m1_axi_arburst),
        .s_axi_arlock   (m1_axi_arlock),
        .s_axi_arcache  (m1_axi_arcache),
        .s_axi_arprot   (m1_axi_arprot),
        .s_axi_arqos    (m1_axi_arqos),
        .s_axi_arregion (m1_axi_arregion),

        .s_axi_rvalid   (m1_axi_rvalid),
        .s_axi_rready   (m1_axi_rready),
        .s_axi_rid      (m1_axi_rid),
        .s_axi_rdata    (m1_axi_rdata),
        .s_axi_rresp    (m1_axi_rresp),
        .s_axi_rlast    (m1_axi_rlast)
    );

endmodule
`default_nettype wire
