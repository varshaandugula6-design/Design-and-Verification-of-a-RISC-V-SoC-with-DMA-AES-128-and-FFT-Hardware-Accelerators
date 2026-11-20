/*
================================================================================
 Project        : Fail-Safe Railway Level-Crossing Control System (Honours CBP)
 Module         : main_top
 Description    : System Top-Level Module integrating 3-Master x 15-Slave AXI4
                  interconnect and direct S4 UART connection.

 Architecture:
   - Masters:
       M0 = VeeR EL2 IFU (s00_axi)
       M1 = VeeR EL2 LSU (s01_axi)
       M2 = DMA Controller (s02_axi)
   - Slaves:
       S0  = Instruction Memory (m00_axi) [0x0004_0000 - 0x0005_FFFF]
       S1  = Data Memory        (m01_axi) [0x0008_0000 - 0x0009_FFFF]
       S2  = GPIO Controller    (m02_axi) [0x8000_1000 - 0x8000_1FFF] (internal)
       S3  = Real-Time Timer    (m03_axi) [0x8000_2000 - 0x8000_2FFF] (internal)
       S4  = UART Subsystem     (internal to axi_uart_top) [0x8000_3000 - 0x8000_3FFF]
       S5  = AES-128 Accelerator(m05_axi) [0x8000_7000 - 0x8000_7FFF] (internal)
       S6  = FFT Control       (m06_axi) [0x8000_8000 - 0x8000_8FFF] (internal)
       S7  = FFT Memory        (m07_axi) [0x8000_9000 - 0x8000_9FFF] (internal)
       S8  = Keypad Controller  (m08_axi)
       S9  = Authentication     (m09_axi)
       S10 = PWM / Buzzer       (m10_axi)
       S11 = Watchdog Timer     (m11_axi) [0x8000_4000 - 0x8000_4FFF]
       S12 = ADC Interface      (m12_axi) [0x8000_5000 - 0x8000_5FFF]
       S13 = DMA Registers      (m13_axi) [0x8000_6000 - 0x8000_6FFF]
       S14 = Seven-Segment Disp (m14_axi)
================================================================================
*/

`timescale 1ns / 1ps
`default_nettype none

// Import DMA/AXI package types at compilation-unit scope so that
// struct ports on dma_axi_wrapper are visible inside main_top.
import amba_axi_pkg::*;

module main_top #(
    parameter DATA_WIDTH      = 32,
    parameter ADDR_WIDTH      = 32,
    parameter STRB_WIDTH      = (DATA_WIDTH/8),
    parameter ID_WIDTH        = 8,
    parameter AWUSER_ENABLE   = 0,
    parameter AWUSER_WIDTH    = 1,
    parameter WUSER_ENABLE    = 0,
    parameter WUSER_WIDTH     = 1,
    parameter BUSER_ENABLE    = 0,
    parameter BUSER_WIDTH     = 1,
    parameter ARUSER_ENABLE   = 0,
    parameter ARUSER_WIDTH    = 1,
    parameter RUSER_ENABLE    = 0,
    parameter RUSER_WIDTH     = 1,

    // ------------------------------------------------------------
    // Documented Project Base Addresses & Apertures
    // ------------------------------------------------------------
    parameter M00_BASE_ADDR   = 32'h0004_0000,          // S0:  IMEM
    parameter M00_ADDR_WIDTH  = 32'd17,                 // 128 KB (0x0004_0000 - 0x0005_FFFF)

    parameter M01_BASE_ADDR   = 32'h0008_0000,          // S1:  DMEM
    parameter M01_ADDR_WIDTH  = 32'd17,                 // 128 KB (0x0008_0000 - 0x0009_FFFF)

    parameter M02_BASE_ADDR   = 32'h8000_1000,          // S2:  GPIO
    parameter M02_ADDR_WIDTH  = 32'd12,                 // 4 KB (0x8000_1000 - 0x8000_1FFF)

    parameter M03_BASE_ADDR   = 32'h8000_2000,          // S3:  Timer
    parameter M03_ADDR_WIDTH  = 32'd12,                 // 4 KB (0x8000_2000 - 0x8000_2FFF)

    parameter M04_BASE_ADDR   = 32'h8000_3000,          // S4:  UART (TARGET)
    parameter M04_ADDR_WIDTH  = 32'd12,                 // 4 KB (0x8000_3000 - 0x8000_3FFF)

    // S5: AES-128 Accelerator (was "Encoder Interface", now assigned to AES)
    parameter M05_BASE_ADDR   = 32'h8000_7000,          // S5:  AES-128 Accelerator
    parameter M05_ADDR_WIDTH  = 32'd12,                 // 4 KB (0x8000_7000 - 0x8000_7FFF)

    parameter M06_BASE_ADDR   = 32'h8000_8000,          // S6:  FFT Control
    parameter M06_ADDR_WIDTH  = 32'd12,                 // 4 KB (0x8000_8000 - 0x8000_8FFF)

    parameter M07_BASE_ADDR   = 32'h8000_9000,          // S7:  FFT Memory
    parameter M07_ADDR_WIDTH  = 32'd12,                 // 4 KB (0x8000_9000 - 0x8000_9FFF)

    parameter M08_BASE_ADDR   = 32'h0000_0000,          // S8:  Keypad Controller
    parameter M08_ADDR_WIDTH  = 32'd0,

    parameter M09_BASE_ADDR   = 32'h0000_0000,          // S9:  Authentication Unit
    parameter M09_ADDR_WIDTH  = 32'd0,

    parameter M10_BASE_ADDR   = 32'h0000_0000,          // S10: PWM / Buzzer Alarm
    parameter M10_ADDR_WIDTH  = 32'd0,

    parameter M11_BASE_ADDR   = 32'h8000_4000,          // S11: Watchdog Timer
    parameter M11_ADDR_WIDTH  = 32'd12,                 // 4 KB (0x8000_4000 - 0x8000_4FFF)

    parameter M12_BASE_ADDR   = 32'h8000_5000,          // S12: ADC Interface
    parameter M12_ADDR_WIDTH  = 32'd12,                 // 4 KB (0x8000_5000 - 0x8000_5FFF)

    parameter M13_BASE_ADDR   = 32'h8000_6000,          // S13: DMA Registers
    parameter M13_ADDR_WIDTH  = 32'd12,                 // 4 KB (0x8000_6000 - 0x8000_6FFF)

    parameter M14_BASE_ADDR   = 32'h0000_0000,          // S14: Seven-Segment Display
    parameter M14_ADDR_WIDTH  = 32'd0
)
(
    // ------------------------------------------------------------
    // Clocks and Resets
    // ------------------------------------------------------------
    input  wire                     clk,            // AXI system clock
    input  wire                     fixed_clk,      // Dedicated UART baud clock
    input  wire                     rst,            // Active-high synchronous reset

    // ------------------------------------------------------------
    // Dedicated UART External Pins & Interrupt
    // ------------------------------------------------------------
    input  wire                     uart_rx,
    output wire                     uart_tx,
    output wire                     uart_irq,

    // ------------------------------------------------------------
    // FFT completion interrupt
    // ------------------------------------------------------------
    output wire                     fft_irq,

    // ------------------------------------------------------------
    // DMA completion and error interrupts (DMA instantiated internally)
    // ------------------------------------------------------------
    output wire                     dma_irq,
    output wire                     dma_error_irq,

    // ------------------------------------------------------------
    // Dedicated GPIO External Pins & Interrupt (GPIO instantiated internally)
    // ------------------------------------------------------------
    inout  wire [31:0]              gpio_io,
    output wire                     gpio_irq,

    // ------------------------------------------------------------
    // Dedicated Timer PWM Output & Interrupt (Timer instantiated internally)
    // ------------------------------------------------------------
    output wire                     timer_pwm,
    output wire                     timer_irq,

    // ============================================================
    // Master Interfaces (Inputs to Interconnect)
    // ============================================================
    // M0: VeeR EL2 IFU
    input  wire [ID_WIDTH-1:0]      s00_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s00_axi_awaddr,
    input  wire [7:0]               s00_axi_awlen,
    input  wire [2:0]               s00_axi_awsize,
    input  wire [1:0]               s00_axi_awburst,
    input  wire                     s00_axi_awlock,
    input  wire [3:0]               s00_axi_awcache,
    input  wire [2:0]               s00_axi_awprot,
    input  wire [3:0]               s00_axi_awqos,
    input  wire [AWUSER_WIDTH-1:0]  s00_axi_awuser,
    input  wire                     s00_axi_awvalid,
    output wire                     s00_axi_awready,
    input  wire [DATA_WIDTH-1:0]    s00_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s00_axi_wstrb,
    input  wire                     s00_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]   s00_axi_wuser,
    input  wire                     s00_axi_wvalid,
    output wire                     s00_axi_wready,
    output wire [ID_WIDTH-1:0]      s00_axi_bid,
    output wire [1:0]               s00_axi_bresp,
    output wire [BUSER_WIDTH-1:0]   s00_axi_buser,
    output wire                     s00_axi_bvalid,
    input  wire                     s00_axi_bready,
    input  wire [ID_WIDTH-1:0]      s00_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s00_axi_araddr,
    input  wire [7:0]               s00_axi_arlen,
    input  wire [2:0]               s00_axi_arsize,
    input  wire [1:0]               s00_axi_arburst,
    input  wire                     s00_axi_arlock,
    input  wire [3:0]               s00_axi_arcache,
    input  wire [2:0]               s00_axi_arprot,
    input  wire [3:0]               s00_axi_arqos,
    input  wire [ARUSER_WIDTH-1:0]  s00_axi_aruser,
    input  wire                     s00_axi_arvalid,
    output wire                     s00_axi_arready,
    output wire [ID_WIDTH-1:0]      s00_axi_rid,
    output wire [DATA_WIDTH-1:0]    s00_axi_rdata,
    output wire [1:0]               s00_axi_rresp,
    output wire                     s00_axi_rlast,
    output wire [RUSER_WIDTH-1:0]   s00_axi_ruser,
    output wire                     s00_axi_rvalid,
    input  wire                     s00_axi_rready,

    // M1: VeeR EL2 LSU
    input  wire [ID_WIDTH-1:0]      s01_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s01_axi_awaddr,
    input  wire [7:0]               s01_axi_awlen,
    input  wire [2:0]               s01_axi_awsize,
    input  wire [1:0]               s01_axi_awburst,
    input  wire                     s01_axi_awlock,
    input  wire [3:0]               s01_axi_awcache,
    input  wire [2:0]               s01_axi_awprot,
    input  wire [3:0]               s01_axi_awqos,
    input  wire [AWUSER_WIDTH-1:0]  s01_axi_awuser,
    input  wire                     s01_axi_awvalid,
    output wire                     s01_axi_awready,
    input  wire [DATA_WIDTH-1:0]    s01_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s01_axi_wstrb,
    input  wire                     s01_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]   s01_axi_wuser,
    input  wire                     s01_axi_wvalid,
    output wire                     s01_axi_wready,
    output wire [ID_WIDTH-1:0]      s01_axi_bid,
    output wire [1:0]               s01_axi_bresp,
    output wire [BUSER_WIDTH-1:0]   s01_axi_buser,
    output wire                     s01_axi_bvalid,
    input  wire                     s01_axi_bready,
    input  wire [ID_WIDTH-1:0]      s01_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s01_axi_araddr,
    input  wire [7:0]               s01_axi_arlen,
    input  wire [2:0]               s01_axi_arsize,
    input  wire [1:0]               s01_axi_arburst,
    input  wire                     s01_axi_arlock,
    input  wire [3:0]               s01_axi_arcache,
    input  wire [2:0]               s01_axi_arprot,
    input  wire [3:0]               s01_axi_arqos,
    input  wire [ARUSER_WIDTH-1:0]  s01_axi_aruser,
    input  wire                     s01_axi_arvalid,
    output wire                     s01_axi_arready,
    output wire [ID_WIDTH-1:0]      s01_axi_rid,
    output wire [DATA_WIDTH-1:0]    s01_axi_rdata,
    output wire [1:0]               s01_axi_rresp,
    output wire                     s01_axi_rlast,
    output wire [RUSER_WIDTH-1:0]   s01_axi_ruser,
    output wire                     s01_axi_rvalid,
    input  wire                     s01_axi_rready,

    // M2: DMA Controller / External M2 Master Interface
    input  wire [ID_WIDTH-1:0]      s02_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s02_axi_awaddr,
    input  wire [7:0]               s02_axi_awlen,
    input  wire [2:0]               s02_axi_awsize,
    input  wire [1:0]               s02_axi_awburst,
    input  wire                     s02_axi_awlock,
    input  wire [3:0]               s02_axi_awcache,
    input  wire [2:0]               s02_axi_awprot,
    input  wire [3:0]               s02_axi_awqos,
    input  wire [AWUSER_WIDTH-1:0]  s02_axi_awuser,
    input  wire                     s02_axi_awvalid,
    output wire                     s02_axi_awready,
    input  wire [DATA_WIDTH-1:0]    s02_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s02_axi_wstrb,
    input  wire                     s02_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]   s02_axi_wuser,
    input  wire                     s02_axi_wvalid,
    output wire                     s02_axi_wready,
    output wire [ID_WIDTH-1:0]      s02_axi_bid,
    output wire [1:0]               s02_axi_bresp,
    output wire [BUSER_WIDTH-1:0]   s02_axi_buser,
    output wire                     s02_axi_bvalid,
    input  wire                     s02_axi_bready,
    input  wire [ID_WIDTH-1:0]      s02_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s02_axi_araddr,
    input  wire [7:0]               s02_axi_arlen,
    input  wire [2:0]               s02_axi_arsize,
    input  wire [1:0]               s02_axi_arburst,
    input  wire                     s02_axi_arlock,
    input  wire [3:0]               s02_axi_arcache,
    input  wire [2:0]               s02_axi_arprot,
    input  wire [3:0]               s02_axi_arqos,
    input  wire [ARUSER_WIDTH-1:0]  s02_axi_aruser,
    input  wire                     s02_axi_arvalid,
    output wire                     s02_axi_arready,
    output wire [ID_WIDTH-1:0]      s02_axi_rid,
    output wire [DATA_WIDTH-1:0]    s02_axi_rdata,
    output wire [1:0]               s02_axi_rresp,
    output wire                     s02_axi_rlast,
    output wire [RUSER_WIDTH-1:0]   s02_axi_ruser,
    output wire                     s02_axi_rvalid,
    input  wire                     s02_axi_rready,

    // ============================================================
    // Exposed Peripheral/Memory Slave Interfaces (S0, S1, S8..S12, S14)
    // S2  is connected internally to GPIO.
    // S3  is connected internally to Timer.
    // S4  is connected internally to UART.
    // S5  is connected internally to AES-128.
    // S6  is connected internally to FFT Control.
    // S7  is connected internally to FFT Memory.
    // S13 is connected internally to DMA CSR (m13_axi_* are internal wires).
    // ============================================================
    // S0: IMEM
    output wire [ID_WIDTH-1:0]      m00_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m00_axi_awaddr,
    output wire [7:0]               m00_axi_awlen,
    output wire [2:0]               m00_axi_awsize,
    output wire [1:0]               m00_axi_awburst,
    output wire                     m00_axi_awlock,
    output wire [3:0]               m00_axi_awcache,
    output wire [2:0]               m00_axi_awprot,
    output wire [3:0]               m00_axi_awqos,
    output wire [3:0]               m00_axi_awregion,
    output wire [AWUSER_WIDTH-1:0]  m00_axi_awuser,
    output wire                     m00_axi_awvalid,
    input  wire                     m00_axi_awready,
    output wire [DATA_WIDTH-1:0]    m00_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m00_axi_wstrb,
    output wire                     m00_axi_wlast,
    output wire [WUSER_WIDTH-1:0]   m00_axi_wuser,
    output wire                     m00_axi_wvalid,
    input  wire                     m00_axi_wready,
    input  wire [ID_WIDTH-1:0]      m00_axi_bid,
    input  wire [1:0]               m00_axi_bresp,
    input  wire [BUSER_WIDTH-1:0]   m00_axi_buser,
    input  wire                     m00_axi_bvalid,
    output wire                     m00_axi_bready,
    output wire [ID_WIDTH-1:0]      m00_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m00_axi_araddr,
    output wire [7:0]               m00_axi_arlen,
    output wire [2:0]               m00_axi_arsize,
    output wire [1:0]               m00_axi_arburst,
    output wire                     m00_axi_arlock,
    output wire [3:0]               m00_axi_arcache,
    output wire [2:0]               m00_axi_arprot,
    output wire [3:0]               m00_axi_arqos,
    output wire [3:0]               m00_axi_arregion,
    output wire [ARUSER_WIDTH-1:0]  m00_axi_aruser,
    output wire                     m00_axi_arvalid,
    input  wire                     m00_axi_arready,
    input  wire [ID_WIDTH-1:0]      m00_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m00_axi_rdata,
    input  wire [1:0]               m00_axi_rresp,
    input  wire                     m00_axi_rlast,
    input  wire [RUSER_WIDTH-1:0]   m00_axi_ruser,
    input  wire                     m00_axi_rvalid,
    output wire                     m00_axi_rready,

    // S1: DMEM
    output wire [ID_WIDTH-1:0]      m01_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m01_axi_awaddr,
    output wire [7:0]               m01_axi_awlen,
    output wire [2:0]               m01_axi_awsize,
    output wire [1:0]               m01_axi_awburst,
    output wire                     m01_axi_awlock,
    output wire [3:0]               m01_axi_awcache,
    output wire [2:0]               m01_axi_awprot,
    output wire [3:0]               m01_axi_awqos,
    output wire [3:0]               m01_axi_awregion,
    output wire [AWUSER_WIDTH-1:0]  m01_axi_awuser,
    output wire                     m01_axi_awvalid,
    input  wire                     m01_axi_awready,
    output wire [DATA_WIDTH-1:0]    m01_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m01_axi_wstrb,
    output wire                     m01_axi_wlast,
    output wire [WUSER_WIDTH-1:0]   m01_axi_wuser,
    output wire                     m01_axi_wvalid,
    input  wire                     m01_axi_wready,
    input  wire [ID_WIDTH-1:0]      m01_axi_bid,
    input  wire [1:0]               m01_axi_bresp,
    input  wire [BUSER_WIDTH-1:0]   m01_axi_buser,
    input  wire                     m01_axi_bvalid,
    output wire                     m01_axi_bready,
    output wire [ID_WIDTH-1:0]      m01_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m01_axi_araddr,
    output wire [7:0]               m01_axi_arlen,
    output wire [2:0]               m01_axi_arsize,
    output wire [1:0]               m01_axi_arburst,
    output wire                     m01_axi_arlock,
    output wire [3:0]               m01_axi_arcache,
    output wire [2:0]               m01_axi_arprot,
    output wire [3:0]               m01_axi_arqos,
    output wire [3:0]               m01_axi_arregion,
    output wire [ARUSER_WIDTH-1:0]  m01_axi_aruser,
    output wire                     m01_axi_arvalid,
    input  wire                     m01_axi_arready,
    input  wire [ID_WIDTH-1:0]      m01_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m01_axi_rdata,
    input  wire [1:0]               m01_axi_rresp,
    input  wire                     m01_axi_rlast,
    input  wire [RUSER_WIDTH-1:0]   m01_axi_ruser,
    input  wire                     m01_axi_rvalid,
    output wire                     m01_axi_rready,

    // S2: GPIO Controller -- connected internally via axi4_to_axi4lite_bridge
    // m02_axi_* are declared as internal wires below; not exposed as module ports.

    // S3: Real-Time Timer -- connected internally via axi4_to_axi4lite_bridge
    // m03_axi_* are declared as internal wires below; not exposed as module ports.

    // S5: AES-128 Accelerator -- connected internally (same pattern as S4/UART)
    // m05_axi_* are declared as internal wires below; not exposed as module ports.

    // S6: FFT Control -- connected internally to fft_ctrl_axi4_bridge
    // m06_axi_* are declared as internal wires below; not exposed as module ports.

    // S7: FFT Memory -- connected internally to fft_mem_axi4_wrap
    // m07_axi_* are declared as internal wires below; not exposed as module ports.

    // S8: Keypad Controller
    output wire [ID_WIDTH-1:0]      m08_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m08_axi_awaddr,
    output wire [7:0]               m08_axi_awlen,
    output wire [2:0]               m08_axi_awsize,
    output wire [1:0]               m08_axi_awburst,
    output wire                     m08_axi_awlock,
    output wire [3:0]               m08_axi_awcache,
    output wire [2:0]               m08_axi_awprot,
    output wire [3:0]               m08_axi_awqos,
    output wire [3:0]               m08_axi_awregion,
    output wire [AWUSER_WIDTH-1:0]  m08_axi_awuser,
    output wire                     m08_axi_awvalid,
    input  wire                     m08_axi_awready,
    output wire [DATA_WIDTH-1:0]    m08_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m08_axi_wstrb,
    output wire                     m08_axi_wlast,
    output wire [WUSER_WIDTH-1:0]   m08_axi_wuser,
    output wire                     m08_axi_wvalid,
    input  wire                     m08_axi_wready,
    input  wire [ID_WIDTH-1:0]      m08_axi_bid,
    input  wire [1:0]               m08_axi_bresp,
    input  wire [BUSER_WIDTH-1:0]   m08_axi_buser,
    input  wire                     m08_axi_bvalid,
    output wire                     m08_axi_bready,
    output wire [ID_WIDTH-1:0]      m08_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m08_axi_araddr,
    output wire [7:0]               m08_axi_arlen,
    output wire [2:0]               m08_axi_arsize,
    output wire [1:0]               m08_axi_arburst,
    output wire                     m08_axi_arlock,
    output wire [3:0]               m08_axi_arcache,
    output wire [2:0]               m08_axi_arprot,
    output wire [3:0]               m08_axi_arqos,
    output wire [3:0]               m08_axi_arregion,
    output wire [ARUSER_WIDTH-1:0]  m08_axi_aruser,
    output wire                     m08_axi_arvalid,
    input  wire                     m08_axi_arready,
    input  wire [ID_WIDTH-1:0]      m08_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m08_axi_rdata,
    input  wire [1:0]               m08_axi_rresp,
    input  wire                     m08_axi_rlast,
    input  wire [RUSER_WIDTH-1:0]   m08_axi_ruser,
    input  wire                     m08_axi_rvalid,
    output wire                     m08_axi_rready,

    // S9: Authentication Unit
    output wire [ID_WIDTH-1:0]      m09_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m09_axi_awaddr,
    output wire [7:0]               m09_axi_awlen,
    output wire [2:0]               m09_axi_awsize,
    output wire [1:0]               m09_axi_awburst,
    output wire                     m09_axi_awlock,
    output wire [3:0]               m09_axi_awcache,
    output wire [2:0]               m09_axi_awprot,
    output wire [3:0]               m09_axi_awqos,
    output wire [3:0]               m09_axi_awregion,
    output wire [AWUSER_WIDTH-1:0]  m09_axi_awuser,
    output wire                     m09_axi_awvalid,
    input  wire                     m09_axi_awready,
    output wire [DATA_WIDTH-1:0]    m09_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m09_axi_wstrb,
    output wire                     m09_axi_wlast,
    output wire [WUSER_WIDTH-1:0]   m09_axi_wuser,
    output wire                     m09_axi_wvalid,
    input  wire                     m09_axi_wready,
    input  wire [ID_WIDTH-1:0]      m09_axi_bid,
    input  wire [1:0]               m09_axi_bresp,
    input  wire [BUSER_WIDTH-1:0]   m09_axi_buser,
    input  wire                     m09_axi_bvalid,
    output wire                     m09_axi_bready,
    output wire [ID_WIDTH-1:0]      m09_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m09_axi_araddr,
    output wire [7:0]               m09_axi_arlen,
    output wire [2:0]               m09_axi_arsize,
    output wire [1:0]               m09_axi_arburst,
    output wire                     m09_axi_arlock,
    output wire [3:0]               m09_axi_arcache,
    output wire [2:0]               m09_axi_arprot,
    output wire [3:0]               m09_axi_arqos,
    output wire [3:0]               m09_axi_arregion,
    output wire [ARUSER_WIDTH-1:0]  m09_axi_aruser,
    output wire                     m09_axi_arvalid,
    input  wire                     m09_axi_arready,
    input  wire [ID_WIDTH-1:0]      m09_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m09_axi_rdata,
    input  wire [1:0]               m09_axi_rresp,
    input  wire                     m09_axi_rlast,
    input  wire [RUSER_WIDTH-1:0]   m09_axi_ruser,
    input  wire                     m09_axi_rvalid,
    output wire                     m09_axi_rready,

    // S10: PWM / Buzzer
    output wire [ID_WIDTH-1:0]      m10_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m10_axi_awaddr,
    output wire [7:0]               m10_axi_awlen,
    output wire [2:0]               m10_axi_awsize,
    output wire [1:0]               m10_axi_awburst,
    output wire                     m10_axi_awlock,
    output wire [3:0]               m10_axi_awcache,
    output wire [2:0]               m10_axi_awprot,
    output wire [3:0]               m10_axi_awqos,
    output wire [3:0]               m10_axi_awregion,
    output wire [AWUSER_WIDTH-1:0]  m10_axi_awuser,
    output wire                     m10_axi_awvalid,
    input  wire                     m10_axi_awready,
    output wire [DATA_WIDTH-1:0]    m10_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m10_axi_wstrb,
    output wire                     m10_axi_wlast,
    output wire [WUSER_WIDTH-1:0]   m10_axi_wuser,
    output wire                     m10_axi_wvalid,
    input  wire                     m10_axi_wready,
    input  wire [ID_WIDTH-1:0]      m10_axi_bid,
    input  wire [1:0]               m10_axi_bresp,
    input  wire [BUSER_WIDTH-1:0]   m10_axi_buser,
    input  wire                     m10_axi_bvalid,
    output wire                     m10_axi_bready,
    output wire [ID_WIDTH-1:0]      m10_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m10_axi_araddr,
    output wire [7:0]               m10_axi_arlen,
    output wire [2:0]               m10_axi_arsize,
    output wire [1:0]               m10_axi_arburst,
    output wire                     m10_axi_arlock,
    output wire [3:0]               m10_axi_arcache,
    output wire [2:0]               m10_axi_arprot,
    output wire [3:0]               m10_axi_arqos,
    output wire [3:0]               m10_axi_arregion,
    output wire [ARUSER_WIDTH-1:0]  m10_axi_aruser,
    output wire                     m10_axi_arvalid,
    input  wire                     m10_axi_arready,
    input  wire [ID_WIDTH-1:0]      m10_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m10_axi_rdata,
    input  wire [1:0]               m10_axi_rresp,
    input  wire                     m10_axi_rlast,
    input  wire [RUSER_WIDTH-1:0]   m10_axi_ruser,
    input  wire                     m10_axi_rvalid,
    output wire                     m10_axi_rready,

    // S11: Watchdog Timer
    output wire [ID_WIDTH-1:0]      m11_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m11_axi_awaddr,
    output wire [7:0]               m11_axi_awlen,
    output wire [2:0]               m11_axi_awsize,
    output wire [1:0]               m11_axi_awburst,
    output wire                     m11_axi_awlock,
    output wire [3:0]               m11_axi_awcache,
    output wire [2:0]               m11_axi_awprot,
    output wire [3:0]               m11_axi_awqos,
    output wire [3:0]               m11_axi_awregion,
    output wire [AWUSER_WIDTH-1:0]  m11_axi_awuser,
    output wire                     m11_axi_awvalid,
    input  wire                     m11_axi_awready,
    output wire [DATA_WIDTH-1:0]    m11_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m11_axi_wstrb,
    output wire                     m11_axi_wlast,
    output wire [WUSER_WIDTH-1:0]   m11_axi_wuser,
    output wire                     m11_axi_wvalid,
    input  wire                     m11_axi_wready,
    input  wire [ID_WIDTH-1:0]      m11_axi_bid,
    input  wire [1:0]               m11_axi_bresp,
    input  wire [BUSER_WIDTH-1:0]   m11_axi_buser,
    input  wire                     m11_axi_bvalid,
    output wire                     m11_axi_bready,
    output wire [ID_WIDTH-1:0]      m11_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m11_axi_araddr,
    output wire [7:0]               m11_axi_arlen,
    output wire [2:0]               m11_axi_arsize,
    output wire [1:0]               m11_axi_arburst,
    output wire                     m11_axi_arlock,
    output wire [3:0]               m11_axi_arcache,
    output wire [2:0]               m11_axi_arprot,
    output wire [3:0]               m11_axi_arqos,
    output wire [3:0]               m11_axi_arregion,
    output wire [ARUSER_WIDTH-1:0]  m11_axi_aruser,
    output wire                     m11_axi_arvalid,
    input  wire                     m11_axi_arready,
    input  wire [ID_WIDTH-1:0]      m11_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m11_axi_rdata,
    input  wire [1:0]               m11_axi_rresp,
    input  wire                     m11_axi_rlast,
    input  wire [RUSER_WIDTH-1:0]   m11_axi_ruser,
    input  wire                     m11_axi_rvalid,
    output wire                     m11_axi_rready,

    // S12: ADC Interface
    output wire [ID_WIDTH-1:0]      m12_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m12_axi_awaddr,
    output wire [7:0]               m12_axi_awlen,
    output wire [2:0]               m12_axi_awsize,
    output wire [1:0]               m12_axi_awburst,
    output wire                     m12_axi_awlock,
    output wire [3:0]               m12_axi_awcache,
    output wire [2:0]               m12_axi_awprot,
    output wire [3:0]               m12_axi_awqos,
    output wire [3:0]               m12_axi_awregion,
    output wire [AWUSER_WIDTH-1:0]  m12_axi_awuser,
    output wire                     m12_axi_awvalid,
    input  wire                     m12_axi_awready,
    output wire [DATA_WIDTH-1:0]    m12_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m12_axi_wstrb,
    output wire                     m12_axi_wlast,
    output wire [WUSER_WIDTH-1:0]   m12_axi_wuser,
    output wire                     m12_axi_wvalid,
    input  wire                     m12_axi_wready,
    input  wire [ID_WIDTH-1:0]      m12_axi_bid,
    input  wire [1:0]               m12_axi_bresp,
    input  wire [BUSER_WIDTH-1:0]   m12_axi_buser,
    input  wire                     m12_axi_bvalid,
    output wire                     m12_axi_bready,
    output wire [ID_WIDTH-1:0]      m12_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m12_axi_araddr,
    output wire [7:0]               m12_axi_arlen,
    output wire [2:0]               m12_axi_arsize,
    output wire [1:0]               m12_axi_arburst,
    output wire                     m12_axi_arlock,
    output wire [3:0]               m12_axi_arcache,
    output wire [2:0]               m12_axi_arprot,
    output wire [3:0]               m12_axi_arqos,
    output wire [3:0]               m12_axi_arregion,
    output wire [ARUSER_WIDTH-1:0]  m12_axi_aruser,
    output wire                     m12_axi_arvalid,
    input  wire                     m12_axi_arready,
    input  wire [ID_WIDTH-1:0]      m12_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m12_axi_rdata,
    input  wire [1:0]               m12_axi_rresp,
    input  wire                     m12_axi_rlast,
    input  wire [RUSER_WIDTH-1:0]   m12_axi_ruser,
    input  wire                     m12_axi_rvalid,
    output wire                     m12_axi_rready,

    // S13: DMA Registers -- connected internally to dma_axi_wrapper CSR slave.
    // m13_axi_* are declared as internal wires below; not exposed as module ports.

    // S14: Seven-Segment Display
    output wire [ID_WIDTH-1:0]      m14_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m14_axi_awaddr,
    output wire [7:0]               m14_axi_awlen,
    output wire [2:0]               m14_axi_awsize,
    output wire [1:0]               m14_axi_awburst,
    output wire                     m14_axi_awlock,
    output wire [3:0]               m14_axi_awcache,
    output wire [2:0]               m14_axi_awprot,
    output wire [3:0]               m14_axi_awqos,
    output wire [3:0]               m14_axi_awregion,
    output wire [AWUSER_WIDTH-1:0]  m14_axi_awuser,
    output wire                     m14_axi_awvalid,
    input  wire                     m14_axi_awready,
    output wire [DATA_WIDTH-1:0]    m14_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m14_axi_wstrb,
    output wire                     m14_axi_wlast,
    output wire [WUSER_WIDTH-1:0]   m14_axi_wuser,
    output wire                     m14_axi_wvalid,
    input  wire                     m14_axi_wready,
    input  wire [ID_WIDTH-1:0]      m14_axi_bid,
    input  wire [1:0]               m14_axi_bresp,
    input  wire [BUSER_WIDTH-1:0]   m14_axi_buser,
    input  wire                     m14_axi_bvalid,
    output wire                     m14_axi_bready,
    output wire [ID_WIDTH-1:0]      m14_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m14_axi_araddr,
    output wire [7:0]               m14_axi_arlen,
    output wire [2:0]               m14_axi_arsize,
    output wire [1:0]               m14_axi_arburst,
    output wire                     m14_axi_arlock,
    output wire [3:0]               m14_axi_arcache,
    output wire [2:0]               m14_axi_arprot,
    output wire [3:0]               m14_axi_arqos,
    output wire [3:0]               m14_axi_arregion,
    output wire [ARUSER_WIDTH-1:0]  m14_axi_aruser,
    output wire                     m14_axi_arvalid,
    input  wire                     m14_axi_arready,
    input  wire [ID_WIDTH-1:0]      m14_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m14_axi_rdata,
    input  wire [1:0]               m14_axi_rresp,
    input  wire                     m14_axi_rlast,
    input  wire [RUSER_WIDTH-1:0]   m14_axi_ruser,
    input  wire                     m14_axi_rvalid,
    output wire                     m14_axi_rready,

    // ============================================================
    // RISC-V VeeR EL2 Control & Status Ports
    // ============================================================
    input  wire                     cpu_rst_l = 1'b0,
    input  wire [31:1]              cpu_rst_vec = 31'h0002_0000,
    input  wire                     cpu_run_req = 1'b1,
    output wire [31:0]              trace_rv_i_insn_ip,
    output wire [31:0]              trace_rv_i_address_ip,
    output wire                     trace_rv_i_valid_ip,
    output wire                     trace_rv_i_exception_ip,
    output wire [4:0]               trace_rv_i_ecause_ip,
    output wire                     trace_rv_i_interrupt_ip,
    output wire [31:0]              trace_rv_i_tval_ip,
    output wire                     o_cpu_halt_status
);

    // ============================================================
    // Internal Wires for Slave S2 (m02) to GPIO Connection
    // ============================================================
    wire [ID_WIDTH-1:0]      m02_axi_awid;
    wire [ADDR_WIDTH-1:0]    m02_axi_awaddr;
    wire [7:0]               m02_axi_awlen;
    wire [2:0]               m02_axi_awsize;
    wire [1:0]               m02_axi_awburst;
    wire                     m02_axi_awlock;
    wire [3:0]               m02_axi_awcache;
    wire [2:0]               m02_axi_awprot;
    wire [3:0]               m02_axi_awqos;
    wire [3:0]               m02_axi_awregion;
    wire [AWUSER_WIDTH-1:0]  m02_axi_awuser;
    wire                     m02_axi_awvalid;
    wire                     m02_axi_awready;

    wire [DATA_WIDTH-1:0]    m02_axi_wdata;
    wire [STRB_WIDTH-1:0]    m02_axi_wstrb;
    wire                     m02_axi_wlast;
    wire [WUSER_WIDTH-1:0]   m02_axi_wuser;
    wire                     m02_axi_wvalid;
    wire                     m02_axi_wready;

    wire [ID_WIDTH-1:0]      m02_axi_bid;
    wire [1:0]               m02_axi_bresp;
    wire [BUSER_WIDTH-1:0]   m02_axi_buser;
    wire                     m02_axi_bvalid;
    wire                     m02_axi_bready;

    wire [ID_WIDTH-1:0]      m02_axi_arid;
    wire [ADDR_WIDTH-1:0]    m02_axi_araddr;
    wire [7:0]               m02_axi_arlen;
    wire [2:0]               m02_axi_arsize;
    wire [1:0]               m02_axi_arburst;
    wire                     m02_axi_arlock;
    wire [3:0]               m02_axi_arcache;
    wire [2:0]               m02_axi_arprot;
    wire [3:0]               m02_axi_arqos;
    wire [3:0]               m02_axi_arregion;
    wire [ARUSER_WIDTH-1:0]  m02_axi_aruser;
    wire                     m02_axi_arvalid;
    wire                     m02_axi_arready;

    wire [ID_WIDTH-1:0]      m02_axi_rid;
    wire [DATA_WIDTH-1:0]    m02_axi_rdata;
    wire [1:0]               m02_axi_rresp;
    wire                     m02_axi_rlast;
    wire [RUSER_WIDTH-1:0]   m02_axi_ruser;
    wire                     m02_axi_rvalid;
    wire                     m02_axi_rready;

    // ============================================================
    // Internal Wires for Slave S3 (m03) to Timer Connection
    // ============================================================
    wire [ID_WIDTH-1:0]      m03_axi_awid;
    wire [ADDR_WIDTH-1:0]    m03_axi_awaddr;
    wire [7:0]               m03_axi_awlen;
    wire [2:0]               m03_axi_awsize;
    wire [1:0]               m03_axi_awburst;
    wire                     m03_axi_awlock;
    wire [3:0]               m03_axi_awcache;
    wire [2:0]               m03_axi_awprot;
    wire [3:0]               m03_axi_awqos;
    wire [3:0]               m03_axi_awregion;
    wire [AWUSER_WIDTH-1:0]  m03_axi_awuser;
    wire                     m03_axi_awvalid;
    wire                     m03_axi_awready;

    wire [DATA_WIDTH-1:0]    m03_axi_wdata;
    wire [STRB_WIDTH-1:0]    m03_axi_wstrb;
    wire                     m03_axi_wlast;
    wire [WUSER_WIDTH-1:0]   m03_axi_wuser;
    wire                     m03_axi_wvalid;
    wire                     m03_axi_wready;

    wire [ID_WIDTH-1:0]      m03_axi_bid;
    wire [1:0]               m03_axi_bresp;
    wire [BUSER_WIDTH-1:0]   m03_axi_buser;
    wire                     m03_axi_bvalid;
    wire                     m03_axi_bready;

    wire [ID_WIDTH-1:0]      m03_axi_arid;
    wire [ADDR_WIDTH-1:0]    m03_axi_araddr;
    wire [7:0]               m03_axi_arlen;
    wire [2:0]               m03_axi_arsize;
    wire [1:0]               m03_axi_arburst;
    wire                     m03_axi_arlock;
    wire [3:0]               m03_axi_arcache;
    wire [2:0]               m03_axi_arprot;
    wire [3:0]               m03_axi_arqos;
    wire [3:0]               m03_axi_arregion;
    wire [ARUSER_WIDTH-1:0]  m03_axi_aruser;
    wire                     m03_axi_arvalid;
    wire                     m03_axi_arready;

    wire [ID_WIDTH-1:0]      m03_axi_rid;
    wire [DATA_WIDTH-1:0]    m03_axi_rdata;
    wire [1:0]               m03_axi_rresp;
    wire                     m03_axi_rlast;
    wire [RUSER_WIDTH-1:0]   m03_axi_ruser;
    wire                     m03_axi_rvalid;
    wire                     m03_axi_rready;

    // ============================================================
    // AXI4-Lite wires between bridges and GPIO / Timer IPs
    // ============================================================
    wire [ADDR_WIDTH-1:0]    gpio_axil_awaddr;
    wire [2:0]               gpio_axil_awprot;
    wire                     gpio_axil_awvalid;
    wire                     gpio_axil_awready;
    wire [DATA_WIDTH-1:0]    gpio_axil_wdata;
    wire [STRB_WIDTH-1:0]    gpio_axil_wstrb;
    wire                     gpio_axil_wvalid;
    wire                     gpio_axil_wready;
    wire [1:0]               gpio_axil_bresp;
    wire                     gpio_axil_bvalid;
    wire                     gpio_axil_bready;
    wire [ADDR_WIDTH-1:0]    gpio_axil_araddr;
    wire [2:0]               gpio_axil_arprot;
    wire                     gpio_axil_arvalid;
    wire                     gpio_axil_arready;
    wire [DATA_WIDTH-1:0]    gpio_axil_rdata;
    wire [1:0]               gpio_axil_rresp;
    wire                     gpio_axil_rvalid;
    wire                     gpio_axil_rready;

    wire [ADDR_WIDTH-1:0]    timer_axil_awaddr;
    wire [2:0]               timer_axil_awprot;
    wire                     timer_axil_awvalid;
    wire                     timer_axil_awready;
    wire [DATA_WIDTH-1:0]    timer_axil_wdata;
    wire [STRB_WIDTH-1:0]    timer_axil_wstrb;
    wire                     timer_axil_wvalid;
    wire                     timer_axil_wready;
    wire [1:0]               timer_axil_bresp;
    wire                     timer_axil_bvalid;
    wire                     timer_axil_bready;
    wire [ADDR_WIDTH-1:0]    timer_axil_araddr;
    wire [2:0]               timer_axil_arprot;
    wire                     timer_axil_arvalid;
    wire                     timer_axil_arready;
    wire [DATA_WIDTH-1:0]    timer_axil_rdata;
    wire [1:0]               timer_axil_rresp;
    wire                     timer_axil_rvalid;
    wire                     timer_axil_rready;

    // ============================================================
    // Internal Wires for Slave S4 (m04) to UART Connection
    // ============================================================
    wire [ID_WIDTH-1:0]      m04_axi_awid;
    wire [ADDR_WIDTH-1:0]    m04_axi_awaddr;
    wire [7:0]               m04_axi_awlen;
    wire [2:0]               m04_axi_awsize;
    wire [1:0]               m04_axi_awburst;
    wire                     m04_axi_awlock;
    wire [3:0]               m04_axi_awcache;
    wire [2:0]               m04_axi_awprot;
    wire [3:0]               m04_axi_awqos;
    wire [3:0]               m04_axi_awregion;
    wire [AWUSER_WIDTH-1:0]  m04_axi_awuser;
    wire                     m04_axi_awvalid;
    wire                     m04_axi_awready;

    wire [DATA_WIDTH-1:0]    m04_axi_wdata;
    wire [STRB_WIDTH-1:0]    m04_axi_wstrb;
    wire                     m04_axi_wlast;
    wire [WUSER_WIDTH-1:0]   m04_axi_wuser;
    wire                     m04_axi_wvalid;
    wire                     m04_axi_wready;

    wire [ID_WIDTH-1:0]      m04_axi_bid;
    wire [1:0]               m04_axi_bresp;
    wire [BUSER_WIDTH-1:0]   m04_axi_buser;
    wire                     m04_axi_bvalid;
    wire                     m04_axi_bready;

    wire [ID_WIDTH-1:0]      m04_axi_arid;
    wire [ADDR_WIDTH-1:0]    m04_axi_araddr;
    wire [7:0]               m04_axi_arlen;
    wire [2:0]               m04_axi_arsize;
    wire [1:0]               m04_axi_arburst;
    wire                     m04_axi_arlock;
    wire [3:0]               m04_axi_arcache;
    wire [2:0]               m04_axi_arprot;
    wire [3:0]               m04_axi_arqos;
    wire [3:0]               m04_axi_arregion;
    wire [ARUSER_WIDTH-1:0]  m04_axi_aruser;
    wire                     m04_axi_arvalid;
    wire                     m04_axi_arready;

    wire [ID_WIDTH-1:0]      m04_axi_rid;
    wire [DATA_WIDTH-1:0]    m04_axi_rdata;
    wire [1:0]               m04_axi_rresp;
    wire                     m04_axi_rlast;
    wire [RUSER_WIDTH-1:0]   m04_axi_ruser;
    wire                     m04_axi_rvalid;
    wire                     m04_axi_rready;

    // ============================================================
    // Internal Wires for Slave S5 (m05) to AES Connection
    // ============================================================
    wire [ID_WIDTH-1:0]      m05_axi_awid;
    wire [ADDR_WIDTH-1:0]    m05_axi_awaddr;
    wire [7:0]               m05_axi_awlen;
    wire [2:0]               m05_axi_awsize;
    wire [1:0]               m05_axi_awburst;
    wire                     m05_axi_awlock;
    wire [3:0]               m05_axi_awcache;
    wire [2:0]               m05_axi_awprot;
    wire [3:0]               m05_axi_awqos;
    wire [3:0]               m05_axi_awregion;
    wire [AWUSER_WIDTH-1:0]  m05_axi_awuser;
    wire                     m05_axi_awvalid;
    wire                     m05_axi_awready;

    wire [DATA_WIDTH-1:0]    m05_axi_wdata;
    wire [STRB_WIDTH-1:0]    m05_axi_wstrb;
    wire                     m05_axi_wlast;
    wire [WUSER_WIDTH-1:0]   m05_axi_wuser;
    wire                     m05_axi_wvalid;
    wire                     m05_axi_wready;

    wire [ID_WIDTH-1:0]      m05_axi_bid;
    wire [1:0]               m05_axi_bresp;
    wire [BUSER_WIDTH-1:0]   m05_axi_buser;
    wire                     m05_axi_bvalid;
    wire                     m05_axi_bready;

    wire [ID_WIDTH-1:0]      m05_axi_arid;
    wire [ADDR_WIDTH-1:0]    m05_axi_araddr;
    wire [7:0]               m05_axi_arlen;
    wire [2:0]               m05_axi_arsize;
    wire [1:0]               m05_axi_arburst;
    wire                     m05_axi_arlock;
    wire [3:0]               m05_axi_arcache;
    wire [2:0]               m05_axi_arprot;
    wire [3:0]               m05_axi_arqos;
    wire [3:0]               m05_axi_arregion;
    wire [ARUSER_WIDTH-1:0]  m05_axi_aruser;
    wire                     m05_axi_arvalid;
    wire                     m05_axi_arready;

    wire [ID_WIDTH-1:0]      m05_axi_rid;
    wire [DATA_WIDTH-1:0]    m05_axi_rdata;
    wire [1:0]               m05_axi_rresp;
    wire                     m05_axi_rlast;
    wire [RUSER_WIDTH-1:0]   m05_axi_ruser;
    wire                     m05_axi_rvalid;
    wire                     m05_axi_rready;

    // ============================================================
    // Internal Wires for Slave S6 (m06) to FFT Control Connection
    // ============================================================
    wire [ID_WIDTH-1:0]      m06_axi_awid;
    wire [ADDR_WIDTH-1:0]    m06_axi_awaddr;
    wire [7:0]               m06_axi_awlen;
    wire [2:0]               m06_axi_awsize;
    wire [1:0]               m06_axi_awburst;
    wire                     m06_axi_awlock;
    wire [3:0]               m06_axi_awcache;
    wire [2:0]               m06_axi_awprot;
    wire [3:0]               m06_axi_awqos;
    wire [3:0]               m06_axi_awregion;
    wire [AWUSER_WIDTH-1:0]  m06_axi_awuser;
    wire                     m06_axi_awvalid;
    wire                     m06_axi_awready;

    wire [DATA_WIDTH-1:0]    m06_axi_wdata;
    wire [STRB_WIDTH-1:0]    m06_axi_wstrb;
    wire                     m06_axi_wlast;
    wire [WUSER_WIDTH-1:0]   m06_axi_wuser;
    wire                     m06_axi_wvalid;
    wire                     m06_axi_wready;

    wire [ID_WIDTH-1:0]      m06_axi_bid;
    wire [1:0]               m06_axi_bresp;
    wire [BUSER_WIDTH-1:0]   m06_axi_buser;
    wire                     m06_axi_bvalid;
    wire                     m06_axi_bready;

    wire [ID_WIDTH-1:0]      m06_axi_arid;
    wire [ADDR_WIDTH-1:0]    m06_axi_araddr;
    wire [7:0]               m06_axi_arlen;
    wire [2:0]               m06_axi_arsize;
    wire [1:0]               m06_axi_arburst;
    wire                     m06_axi_arlock;
    wire [3:0]               m06_axi_arcache;
    wire [2:0]               m06_axi_arprot;
    wire [3:0]               m06_axi_arqos;
    wire [3:0]               m06_axi_arregion;
    wire [ARUSER_WIDTH-1:0]  m06_axi_aruser;
    wire                     m06_axi_arvalid;
    wire                     m06_axi_arready;

    wire [ID_WIDTH-1:0]      m06_axi_rid;
    wire [DATA_WIDTH-1:0]    m06_axi_rdata;
    wire [1:0]               m06_axi_rresp;
    wire                     m06_axi_rlast;
    wire [RUSER_WIDTH-1:0]   m06_axi_ruser;
    wire                     m06_axi_rvalid;
    wire                     m06_axi_rready;

    // ============================================================
    // Internal Wires for S7 (m07) to FFT Memory Connection
    // ============================================================
    wire [ID_WIDTH-1:0]      m07_axi_awid;
    wire [ADDR_WIDTH-1:0]    m07_axi_awaddr;
    wire [7:0]               m07_axi_awlen;
    wire [2:0]               m07_axi_awsize;
    wire [1:0]               m07_axi_awburst;
    wire                     m07_axi_awlock;
    wire [3:0]               m07_axi_awcache;
    wire [2:0]               m07_axi_awprot;
    wire [3:0]               m07_axi_awqos;
    wire [3:0]               m07_axi_awregion;
    wire [AWUSER_WIDTH-1:0]  m07_axi_awuser;
    wire                     m07_axi_awvalid;
    wire                     m07_axi_awready;

    wire [DATA_WIDTH-1:0]    m07_axi_wdata;
    wire [STRB_WIDTH-1:0]    m07_axi_wstrb;
    wire                     m07_axi_wlast;
    wire [WUSER_WIDTH-1:0]   m07_axi_wuser;
    wire                     m07_axi_wvalid;
    wire                     m07_axi_wready;

    wire [ID_WIDTH-1:0]      m07_axi_bid;
    wire [1:0]               m07_axi_bresp;
    wire [BUSER_WIDTH-1:0]   m07_axi_buser;
    wire                     m07_axi_bvalid;
    wire                     m07_axi_bready;

    wire [ID_WIDTH-1:0]      m07_axi_arid;
    wire [ADDR_WIDTH-1:0]    m07_axi_araddr;
    wire [7:0]               m07_axi_arlen;
    wire [2:0]               m07_axi_arsize;
    wire [1:0]               m07_axi_arburst;
    wire                     m07_axi_arlock;
    wire [3:0]               m07_axi_arcache;
    wire [2:0]               m07_axi_arprot;
    wire [3:0]               m07_axi_arqos;
    wire [3:0]               m07_axi_arregion;
    wire [ARUSER_WIDTH-1:0]  m07_axi_aruser;
    wire                     m07_axi_arvalid;
    wire                     m07_axi_arready;

    wire [ID_WIDTH-1:0]      m07_axi_rid;
    wire [DATA_WIDTH-1:0]    m07_axi_rdata;
    wire [1:0]               m07_axi_rresp;
    wire                     m07_axi_rlast;
    wire [RUSER_WIDTH-1:0]   m07_axi_ruser;
    wire                     m07_axi_rvalid;
    wire                     m07_axi_rready;

    // ============================================================
    // Internal Wires for M0 (ic_s00_axi) — Interconnect M0 Master Port
    // Multiplexed between VeeR EL2 IFU and external s00_axi_* ports.
    // ============================================================
    wire [ID_WIDTH-1:0]      ic_s00_axi_awid;
    wire [ADDR_WIDTH-1:0]    ic_s00_axi_awaddr;
    wire [7:0]               ic_s00_axi_awlen;
    wire [2:0]               ic_s00_axi_awsize;
    wire [1:0]               ic_s00_axi_awburst;
    wire                     ic_s00_axi_awlock;
    wire [3:0]               ic_s00_axi_awcache;
    wire [2:0]               ic_s00_axi_awprot;
    wire [3:0]               ic_s00_axi_awqos;
    wire [AWUSER_WIDTH-1:0]  ic_s00_axi_awuser;
    wire                     ic_s00_axi_awvalid;
    wire                     ic_s00_axi_awready;

    wire [DATA_WIDTH-1:0]    ic_s00_axi_wdata;
    wire [STRB_WIDTH-1:0]    ic_s00_axi_wstrb;
    wire                     ic_s00_axi_wlast;
    wire [WUSER_WIDTH-1:0]   ic_s00_axi_wuser;
    wire                     ic_s00_axi_wvalid;
    wire                     ic_s00_axi_wready;

    wire [ID_WIDTH-1:0]      ic_s00_axi_bid;
    wire [1:0]               ic_s00_axi_bresp;
    wire [BUSER_WIDTH-1:0]   ic_s00_axi_buser;
    wire                     ic_s00_axi_bvalid;
    wire                     ic_s00_axi_bready;

    wire [ID_WIDTH-1:0]      ic_s00_axi_arid;
    wire [ADDR_WIDTH-1:0]    ic_s00_axi_araddr;
    wire [7:0]               ic_s00_axi_arlen;
    wire [2:0]               ic_s00_axi_arsize;
    wire [1:0]               ic_s00_axi_arburst;
    wire                     ic_s00_axi_arlock;
    wire [3:0]               ic_s00_axi_arcache;
    wire [2:0]               ic_s00_axi_arprot;
    wire [3:0]               ic_s00_axi_arqos;
    wire [ARUSER_WIDTH-1:0]  ic_s00_axi_aruser;
    wire                     ic_s00_axi_arvalid;
    wire                     ic_s00_axi_arready;

    wire [ID_WIDTH-1:0]      ic_s00_axi_rid;
    wire [DATA_WIDTH-1:0]    ic_s00_axi_rdata;
    wire [1:0]               ic_s00_axi_rresp;
    wire                     ic_s00_axi_rlast;
    wire [RUSER_WIDTH-1:0]   ic_s00_axi_ruser;
    wire                     ic_s00_axi_rvalid;
    wire                     ic_s00_axi_rready;

    // ============================================================
    // Internal Wires for M1 (ic_s01_axi) — Interconnect M1 Master Port
    // Multiplexed between VeeR EL2 LSU and external s01_axi_* ports.
    // ============================================================
    wire [ID_WIDTH-1:0]      ic_s01_axi_awid;
    wire [ADDR_WIDTH-1:0]    ic_s01_axi_awaddr;
    wire [7:0]               ic_s01_axi_awlen;
    wire [2:0]               ic_s01_axi_awsize;
    wire [1:0]               ic_s01_axi_awburst;
    wire                     ic_s01_axi_awlock;
    wire [3:0]               ic_s01_axi_awcache;
    wire [2:0]               ic_s01_axi_awprot;
    wire [3:0]               ic_s01_axi_awqos;
    wire [AWUSER_WIDTH-1:0]  ic_s01_axi_awuser;
    wire                     ic_s01_axi_awvalid;
    wire                     ic_s01_axi_awready;

    wire [DATA_WIDTH-1:0]    ic_s01_axi_wdata;
    wire [STRB_WIDTH-1:0]    ic_s01_axi_wstrb;
    wire                     ic_s01_axi_wlast;
    wire [WUSER_WIDTH-1:0]   ic_s01_axi_wuser;
    wire                     ic_s01_axi_wvalid;
    wire                     ic_s01_axi_wready;

    wire [ID_WIDTH-1:0]      ic_s01_axi_bid;
    wire [1:0]               ic_s01_axi_bresp;
    wire [BUSER_WIDTH-1:0]   ic_s01_axi_buser;
    wire                     ic_s01_axi_bvalid;
    wire                     ic_s01_axi_bready;

    wire [ID_WIDTH-1:0]      ic_s01_axi_arid;
    wire [ADDR_WIDTH-1:0]    ic_s01_axi_araddr;
    wire [7:0]               ic_s01_axi_arlen;
    wire [2:0]               ic_s01_axi_arsize;
    wire [1:0]               ic_s01_axi_arburst;
    wire                     ic_s01_axi_arlock;
    wire [3:0]               ic_s01_axi_arcache;
    wire [2:0]               ic_s01_axi_arprot;
    wire [3:0]               ic_s01_axi_arqos;
    wire [ARUSER_WIDTH-1:0]  ic_s01_axi_aruser;
    wire                     ic_s01_axi_arvalid;
    wire                     ic_s01_axi_arready;

    wire [ID_WIDTH-1:0]      ic_s01_axi_rid;
    wire [DATA_WIDTH-1:0]    ic_s01_axi_rdata;
    wire [1:0]               ic_s01_axi_rresp;
    wire                     ic_s01_axi_rlast;
    wire [RUSER_WIDTH-1:0]   ic_s01_axi_ruser;
    wire                     ic_s01_axi_rvalid;
    wire                     ic_s01_axi_rready;

    // ============================================================
    // VeeR EL2 Core 32-bit AXI Masters (from veer_wrapper_axi32)
    // ============================================================
    wire [ID_WIDTH-1:0]      veer_m0_axi_awid;
    wire [ADDR_WIDTH-1:0]    veer_m0_axi_awaddr;
    wire [7:0]               veer_m0_axi_awlen;
    wire [2:0]               veer_m0_axi_awsize;
    wire [1:0]               veer_m0_axi_awburst;
    wire                     veer_m0_axi_awlock;
    wire [3:0]               veer_m0_axi_awcache;
    wire [2:0]               veer_m0_axi_awprot;
    wire [3:0]               veer_m0_axi_awqos;
    wire [3:0]               veer_m0_axi_awregion;
    wire                     veer_m0_axi_awvalid;
    wire                     veer_m0_axi_awready;
    wire [DATA_WIDTH-1:0]    veer_m0_axi_wdata;
    wire [STRB_WIDTH-1:0]    veer_m0_axi_wstrb;
    wire                     veer_m0_axi_wlast;
    wire                     veer_m0_axi_wvalid;
    wire                     veer_m0_axi_wready;
    wire [ID_WIDTH-1:0]      veer_m0_axi_bid;
    wire [1:0]               veer_m0_axi_bresp;
    wire                     veer_m0_axi_bvalid;
    wire                     veer_m0_axi_bready;
    wire [ID_WIDTH-1:0]      veer_m0_axi_arid;
    wire [ADDR_WIDTH-1:0]    veer_m0_axi_araddr;
    wire [7:0]               veer_m0_axi_arlen;
    wire [2:0]               veer_m0_axi_arsize;
    wire [1:0]               veer_m0_axi_arburst;
    wire                     veer_m0_axi_arlock;
    wire [3:0]               veer_m0_axi_arcache;
    wire [2:0]               veer_m0_axi_arprot;
    wire [3:0]               veer_m0_axi_arqos;
    wire [3:0]               veer_m0_axi_arregion;
    wire                     veer_m0_axi_arvalid;
    wire                     veer_m0_axi_arready;
    wire [ID_WIDTH-1:0]      veer_m0_axi_rid;
    wire [DATA_WIDTH-1:0]    veer_m0_axi_rdata;
    wire [1:0]               veer_m0_axi_rresp;
    wire                     veer_m0_axi_rlast;
    wire                     veer_m0_axi_rvalid;
    wire                     veer_m0_axi_rready;

    wire [ID_WIDTH-1:0]      veer_m1_axi_awid;
    wire [ADDR_WIDTH-1:0]    veer_m1_axi_awaddr;
    wire [7:0]               veer_m1_axi_awlen;
    wire [2:0]               veer_m1_axi_awsize;
    wire [1:0]               veer_m1_axi_awburst;
    wire                     veer_m1_axi_awlock;
    wire [3:0]               veer_m1_axi_awcache;
    wire [2:0]               veer_m1_axi_awprot;
    wire [3:0]               veer_m1_axi_awqos;
    wire [3:0]               veer_m1_axi_awregion;
    wire                     veer_m1_axi_awvalid;
    wire                     veer_m1_axi_awready;
    wire [DATA_WIDTH-1:0]    veer_m1_axi_wdata;
    wire [STRB_WIDTH-1:0]    veer_m1_axi_wstrb;
    wire                     veer_m1_axi_wlast;
    wire                     veer_m1_axi_wvalid;
    wire                     veer_m1_axi_wready;
    wire [ID_WIDTH-1:0]      veer_m1_axi_bid;
    wire [1:0]               veer_m1_axi_bresp;
    wire                     veer_m1_axi_bvalid;
    wire                     veer_m1_axi_bready;
    wire [ID_WIDTH-1:0]      veer_m1_axi_arid;
    wire [ADDR_WIDTH-1:0]    veer_m1_axi_araddr;
    wire [7:0]               veer_m1_axi_arlen;
    wire [2:0]               veer_m1_axi_arsize;
    wire [1:0]               veer_m1_axi_arburst;
    wire                     veer_m1_axi_arlock;
    wire [3:0]               veer_m1_axi_arcache;
    wire [2:0]               veer_m1_axi_arprot;
    wire [3:0]               veer_m1_axi_arqos;
    wire [3:0]               veer_m1_axi_arregion;
    wire                     veer_m1_axi_arvalid;
    wire                     veer_m1_axi_arready;
    wire [ID_WIDTH-1:0]      veer_m1_axi_rid;
    wire [DATA_WIDTH-1:0]    veer_m1_axi_rdata;
    wire [1:0]               veer_m1_axi_rresp;
    wire                     veer_m1_axi_rlast;
    wire                     veer_m1_axi_rvalid;
    wire                     veer_m1_axi_rready;

    // ============================================================
    // Internal Wires for M2 (ic_s02_axi) — Interconnect M2 Master Port
    // Multiplexed between internal DMA and external s02_axi_* ports.
    // ============================================================
    wire [ID_WIDTH-1:0]      ic_s02_axi_awid;
    wire [ADDR_WIDTH-1:0]    ic_s02_axi_awaddr;
    wire [7:0]               ic_s02_axi_awlen;
    wire [2:0]               ic_s02_axi_awsize;
    wire [1:0]               ic_s02_axi_awburst;
    wire                     ic_s02_axi_awlock;
    wire [3:0]               ic_s02_axi_awcache;
    wire [2:0]               ic_s02_axi_awprot;
    wire [3:0]               ic_s02_axi_awqos;
    wire [AWUSER_WIDTH-1:0]  ic_s02_axi_awuser;
    wire                     ic_s02_axi_awvalid;
    wire                     ic_s02_axi_awready;

    wire [DATA_WIDTH-1:0]    ic_s02_axi_wdata;
    wire [STRB_WIDTH-1:0]    ic_s02_axi_wstrb;
    wire                     ic_s02_axi_wlast;
    wire [WUSER_WIDTH-1:0]   ic_s02_axi_wuser;
    wire                     ic_s02_axi_wvalid;
    wire                     ic_s02_axi_wready;

    wire [ID_WIDTH-1:0]      ic_s02_axi_bid;
    wire [1:0]               ic_s02_axi_bresp;
    wire [BUSER_WIDTH-1:0]   ic_s02_axi_buser;
    wire                     ic_s02_axi_bvalid;
    wire                     ic_s02_axi_bready;

    wire [ID_WIDTH-1:0]      ic_s02_axi_arid;
    wire [ADDR_WIDTH-1:0]    ic_s02_axi_araddr;
    wire [7:0]               ic_s02_axi_arlen;
    wire [2:0]               ic_s02_axi_arsize;
    wire [1:0]               ic_s02_axi_arburst;
    wire                     ic_s02_axi_arlock;
    wire [3:0]               ic_s02_axi_arcache;
    wire [2:0]               ic_s02_axi_arprot;
    wire [3:0]               ic_s02_axi_arqos;
    wire [ARUSER_WIDTH-1:0]  ic_s02_axi_aruser;
    wire                     ic_s02_axi_arvalid;
    wire                     ic_s02_axi_arready;

    wire [ID_WIDTH-1:0]      ic_s02_axi_rid;
    wire [DATA_WIDTH-1:0]    ic_s02_axi_rdata;
    wire [1:0]               ic_s02_axi_rresp;
    wire                     ic_s02_axi_rlast;
    wire [RUSER_WIDTH-1:0]   ic_s02_axi_ruser;
    wire                     ic_s02_axi_rvalid;
    wire                     ic_s02_axi_rready;

    // ============================================================
    // Internal Wires for S13 (m13_axi) — DMA CSR Slave
    // The DMA CSR slave port is connected internally.
    // ============================================================
    wire [ID_WIDTH-1:0]      m13_axi_awid;
    wire [ADDR_WIDTH-1:0]    m13_axi_awaddr;
    wire [7:0]               m13_axi_awlen;
    wire [2:0]               m13_axi_awsize;
    wire [1:0]               m13_axi_awburst;
    wire                     m13_axi_awlock;
    wire [3:0]               m13_axi_awcache;
    wire [2:0]               m13_axi_awprot;
    wire [3:0]               m13_axi_awqos;
    wire [3:0]               m13_axi_awregion;
    wire [AWUSER_WIDTH-1:0]  m13_axi_awuser;
    wire                     m13_axi_awvalid;
    wire                     m13_axi_awready;

    wire [DATA_WIDTH-1:0]    m13_axi_wdata;
    wire [STRB_WIDTH-1:0]    m13_axi_wstrb;
    wire                     m13_axi_wlast;
    wire [WUSER_WIDTH-1:0]   m13_axi_wuser;
    wire                     m13_axi_wvalid;
    wire                     m13_axi_wready;

    wire [ID_WIDTH-1:0]      m13_axi_bid;
    wire [1:0]               m13_axi_bresp;
    wire [BUSER_WIDTH-1:0]   m13_axi_buser;
    wire                     m13_axi_bvalid;
    wire                     m13_axi_bready;

    wire [ID_WIDTH-1:0]      m13_axi_arid;
    wire [ADDR_WIDTH-1:0]    m13_axi_araddr;
    wire [7:0]               m13_axi_arlen;
    wire [2:0]               m13_axi_arsize;
    wire [1:0]               m13_axi_arburst;
    wire                     m13_axi_arlock;
    wire [3:0]               m13_axi_arcache;
    wire [2:0]               m13_axi_arprot;
    wire [3:0]               m13_axi_arqos;
    wire [3:0]               m13_axi_arregion;
    wire [ARUSER_WIDTH-1:0]  m13_axi_aruser;
    wire                     m13_axi_arvalid;
    wire                     m13_axi_arready;

    wire [ID_WIDTH-1:0]      m13_axi_rid;
    wire [DATA_WIDTH-1:0]    m13_axi_rdata;
    wire [1:0]               m13_axi_rresp;
    wire                     m13_axi_rlast;
    wire [RUSER_WIDTH-1:0]   m13_axi_ruser;
    wire                     m13_axi_rvalid;
    wire                     m13_axi_rready;

    // ============================================================
    // FFT AXI4-Lite control wires (fft_ctrl_axi4_bridge → fft_accel_top)
    // ============================================================
    localparam FFT_AXIL_AW = 16;

    wire [FFT_AXIL_AW-1:0]  fft_axil_awaddr;
    wire                     fft_axil_awvalid;
    wire                     fft_axil_awready;
    wire [DATA_WIDTH-1:0]    fft_axil_wdata;
    wire [STRB_WIDTH-1:0]    fft_axil_wstrb;
    wire                     fft_axil_wvalid;
    wire                     fft_axil_wready;
    wire [1:0]               fft_axil_bresp;
    wire                     fft_axil_bvalid;
    wire                     fft_axil_bready;
    wire [FFT_AXIL_AW-1:0]  fft_axil_araddr;
    wire                     fft_axil_arvalid;
    wire                     fft_axil_arready;
    wire [DATA_WIDTH-1:0]    fft_axil_rdata;
    wire [1:0]               fft_axil_rresp;
    wire                     fft_axil_rvalid;
    wire                     fft_axil_rready;

    // FFT AXI4 memory wires (fft_mem_axi4_wrap → fft_accel_top)
    localparam FFT_ID_W   = 4;
    localparam FFT_ADDR_W = 16;

    wire [FFT_ID_W-1:0]      fft_mem_awid;
    wire [FFT_ADDR_W-1:0]    fft_mem_awaddr;
    wire [7:0]               fft_mem_awlen;
    wire [2:0]               fft_mem_awsize;
    wire [1:0]               fft_mem_awburst;
    wire                     fft_mem_awvalid;
    wire                     fft_mem_awready;
    wire [DATA_WIDTH-1:0]    fft_mem_wdata;
    wire [STRB_WIDTH-1:0]    fft_mem_wstrb;
    wire                     fft_mem_wlast;
    wire                     fft_mem_wvalid;
    wire                     fft_mem_wready;
    wire [FFT_ID_W-1:0]      fft_mem_bid;
    wire [1:0]               fft_mem_bresp;
    wire                     fft_mem_bvalid;
    wire                     fft_mem_bready;
    wire [FFT_ID_W-1:0]      fft_mem_arid;
    wire [FFT_ADDR_W-1:0]    fft_mem_araddr;
    wire [7:0]               fft_mem_arlen;
    wire [2:0]               fft_mem_arsize;
    wire [1:0]               fft_mem_arburst;
    wire                     fft_mem_arvalid;
    wire                     fft_mem_arready;
    wire [FFT_ID_W-1:0]      fft_mem_rid;
    wire [DATA_WIDTH-1:0]    fft_mem_rdata;
    wire [1:0]               fft_mem_rresp;
    wire                     fft_mem_rlast;
    wire                     fft_mem_rvalid;
    wire                     fft_mem_rready;

    // ============================================================
    // Existing 3-Master x 15-Slave Interconnect Instantiation
    // ============================================================
    axi_interconnect_wrap_3x15 #(
        .DATA_WIDTH         (DATA_WIDTH),
        .ADDR_WIDTH         (ADDR_WIDTH),
        .STRB_WIDTH         (STRB_WIDTH),
        .ID_WIDTH           (ID_WIDTH),
        .AWUSER_ENABLE      (AWUSER_ENABLE),
        .AWUSER_WIDTH       (AWUSER_WIDTH),
        .WUSER_ENABLE       (WUSER_ENABLE),
        .WUSER_WIDTH        (WUSER_WIDTH),
        .BUSER_ENABLE       (BUSER_ENABLE),
        .BUSER_WIDTH        (BUSER_WIDTH),
        .ARUSER_ENABLE      (ARUSER_ENABLE),
        .ARUSER_WIDTH       (ARUSER_WIDTH),
        .RUSER_ENABLE       (RUSER_ENABLE),
        .RUSER_WIDTH        (RUSER_WIDTH),

        .M00_BASE_ADDR      (M00_BASE_ADDR),
        .M00_ADDR_WIDTH     (M00_ADDR_WIDTH),
        .M01_BASE_ADDR      (M01_BASE_ADDR),
        .M01_ADDR_WIDTH     (M01_ADDR_WIDTH),
        .M02_BASE_ADDR      (M02_BASE_ADDR),
        .M02_ADDR_WIDTH     (M02_ADDR_WIDTH),
        .M03_BASE_ADDR      (M03_BASE_ADDR),
        .M03_ADDR_WIDTH     (M03_ADDR_WIDTH),
        .M04_BASE_ADDR      (M04_BASE_ADDR),
        .M04_ADDR_WIDTH     (M04_ADDR_WIDTH),
        .M05_BASE_ADDR      (M05_BASE_ADDR),
        .M05_ADDR_WIDTH     (M05_ADDR_WIDTH),
        .M06_BASE_ADDR      (M06_BASE_ADDR),
        .M06_ADDR_WIDTH     (M06_ADDR_WIDTH),
        .M07_BASE_ADDR      (M07_BASE_ADDR),
        .M07_ADDR_WIDTH     (M07_ADDR_WIDTH),
        .M08_BASE_ADDR      (M08_BASE_ADDR),
        .M08_ADDR_WIDTH     (M08_ADDR_WIDTH),
        .M09_BASE_ADDR      (M09_BASE_ADDR),
        .M09_ADDR_WIDTH     (M09_ADDR_WIDTH),
        .M10_BASE_ADDR      (M10_BASE_ADDR),
        .M10_ADDR_WIDTH     (M10_ADDR_WIDTH),
        .M11_BASE_ADDR      (M11_BASE_ADDR),
        .M11_ADDR_WIDTH     (M11_ADDR_WIDTH),
        .M12_BASE_ADDR      (M12_BASE_ADDR),
        .M12_ADDR_WIDTH     (M12_ADDR_WIDTH),
        .M13_BASE_ADDR      (M13_BASE_ADDR),
        .M13_ADDR_WIDTH     (M13_ADDR_WIDTH),
        .M14_BASE_ADDR      (M14_BASE_ADDR),
        .M14_ADDR_WIDTH     (M14_ADDR_WIDTH)
    ) u_axi_interconnect_3x15 (
        .clk                (clk),
        .rst                (rst),

        // M0 Master (VeeR IFU)
        .s00_axi_awid       (ic_s00_axi_awid),
        .s00_axi_awaddr     (ic_s00_axi_awaddr),
        .s00_axi_awlen      (ic_s00_axi_awlen),
        .s00_axi_awsize     (ic_s00_axi_awsize),
        .s00_axi_awburst    (ic_s00_axi_awburst),
        .s00_axi_awlock     (ic_s00_axi_awlock),
        .s00_axi_awcache    (ic_s00_axi_awcache),
        .s00_axi_awprot     (ic_s00_axi_awprot),
        .s00_axi_awqos      (ic_s00_axi_awqos),
        .s00_axi_awuser     (ic_s00_axi_awuser),
        .s00_axi_awvalid    (ic_s00_axi_awvalid),
        .s00_axi_awready    (ic_s00_axi_awready),
        .s00_axi_wdata      (ic_s00_axi_wdata),
        .s00_axi_wstrb      (ic_s00_axi_wstrb),
        .s00_axi_wlast      (ic_s00_axi_wlast),
        .s00_axi_wuser      (ic_s00_axi_wuser),
        .s00_axi_wvalid     (ic_s00_axi_wvalid),
        .s00_axi_wready     (ic_s00_axi_wready),
        .s00_axi_bid        (ic_s00_axi_bid),
        .s00_axi_bresp      (ic_s00_axi_bresp),
        .s00_axi_buser      (ic_s00_axi_buser),
        .s00_axi_bvalid     (ic_s00_axi_bvalid),
        .s00_axi_bready     (ic_s00_axi_bready),
        .s00_axi_arid       (ic_s00_axi_arid),
        .s00_axi_araddr     (ic_s00_axi_araddr),
        .s00_axi_arlen      (ic_s00_axi_arlen),
        .s00_axi_arsize     (ic_s00_axi_arsize),
        .s00_axi_arburst    (ic_s00_axi_arburst),
        .s00_axi_arlock     (ic_s00_axi_arlock),
        .s00_axi_arcache    (ic_s00_axi_arcache),
        .s00_axi_arprot     (ic_s00_axi_arprot),
        .s00_axi_arqos      (ic_s00_axi_arqos),
        .s00_axi_aruser     (ic_s00_axi_aruser),
        .s00_axi_arvalid    (ic_s00_axi_arvalid),
        .s00_axi_arready    (ic_s00_axi_arready),
        .s00_axi_rid        (ic_s00_axi_rid),
        .s00_axi_rdata      (ic_s00_axi_rdata),
        .s00_axi_rresp      (ic_s00_axi_rresp),
        .s00_axi_rlast      (ic_s00_axi_rlast),
        .s00_axi_ruser      (ic_s00_axi_ruser),
        .s00_axi_rvalid     (ic_s00_axi_rvalid),
        .s00_axi_rready     (ic_s00_axi_rready),

        // M1 Master (VeeR LSU)
        .s01_axi_awid       (ic_s01_axi_awid),
        .s01_axi_awaddr     (ic_s01_axi_awaddr),
        .s01_axi_awlen      (ic_s01_axi_awlen),
        .s01_axi_awsize     (ic_s01_axi_awsize),
        .s01_axi_awburst    (ic_s01_axi_awburst),
        .s01_axi_awlock     (ic_s01_axi_awlock),
        .s01_axi_awcache    (ic_s01_axi_awcache),
        .s01_axi_awprot     (ic_s01_axi_awprot),
        .s01_axi_awqos      (ic_s01_axi_awqos),
        .s01_axi_awuser     (ic_s01_axi_awuser),
        .s01_axi_awvalid    (ic_s01_axi_awvalid),
        .s01_axi_awready    (ic_s01_axi_awready),
        .s01_axi_wdata      (ic_s01_axi_wdata),
        .s01_axi_wstrb      (ic_s01_axi_wstrb),
        .s01_axi_wlast      (ic_s01_axi_wlast),
        .s01_axi_wuser      (ic_s01_axi_wuser),
        .s01_axi_wvalid     (ic_s01_axi_wvalid),
        .s01_axi_wready     (ic_s01_axi_wready),
        .s01_axi_bid        (ic_s01_axi_bid),
        .s01_axi_bresp      (ic_s01_axi_bresp),
        .s01_axi_buser      (ic_s01_axi_buser),
        .s01_axi_bvalid     (ic_s01_axi_bvalid),
        .s01_axi_bready     (ic_s01_axi_bready),
        .s01_axi_arid       (ic_s01_axi_arid),
        .s01_axi_araddr     (ic_s01_axi_araddr),
        .s01_axi_arlen      (ic_s01_axi_arlen),
        .s01_axi_arsize     (ic_s01_axi_arsize),
        .s01_axi_arburst    (ic_s01_axi_arburst),
        .s01_axi_arlock     (ic_s01_axi_arlock),
        .s01_axi_arcache    (ic_s01_axi_arcache),
        .s01_axi_arprot     (ic_s01_axi_arprot),
        .s01_axi_arqos      (ic_s01_axi_arqos),
        .s01_axi_aruser     (ic_s01_axi_aruser),
        .s01_axi_arvalid    (ic_s01_axi_arvalid),
        .s01_axi_arready    (ic_s01_axi_arready),
        .s01_axi_rid        (ic_s01_axi_rid),
        .s01_axi_rdata      (ic_s01_axi_rdata),
        .s01_axi_rresp      (ic_s01_axi_rresp),
        .s01_axi_rlast      (ic_s01_axi_rlast),
        .s01_axi_ruser      (ic_s01_axi_ruser),
        .s01_axi_rvalid     (ic_s01_axi_rvalid),
        .s01_axi_rready     (ic_s01_axi_rready),

        // M2 Master (DMA Controller)
        .s02_axi_awid       (ic_s02_axi_awid),
        .s02_axi_awaddr     (ic_s02_axi_awaddr),
        .s02_axi_awlen      (ic_s02_axi_awlen),
        .s02_axi_awsize     (ic_s02_axi_awsize),
        .s02_axi_awburst    (ic_s02_axi_awburst),
        .s02_axi_awlock     (ic_s02_axi_awlock),
        .s02_axi_awcache    (ic_s02_axi_awcache),
        .s02_axi_awprot     (ic_s02_axi_awprot),
        .s02_axi_awqos      (ic_s02_axi_awqos),
        .s02_axi_awuser     (ic_s02_axi_awuser),
        .s02_axi_awvalid    (ic_s02_axi_awvalid),
        .s02_axi_awready    (ic_s02_axi_awready),
        .s02_axi_wdata      (ic_s02_axi_wdata),
        .s02_axi_wstrb      (ic_s02_axi_wstrb),
        .s02_axi_wlast      (ic_s02_axi_wlast),
        .s02_axi_wuser      (ic_s02_axi_wuser),
        .s02_axi_wvalid     (ic_s02_axi_wvalid),
        .s02_axi_wready     (ic_s02_axi_wready),
        .s02_axi_bid        (ic_s02_axi_bid),
        .s02_axi_bresp      (ic_s02_axi_bresp),
        .s02_axi_buser      (ic_s02_axi_buser),
        .s02_axi_bvalid     (ic_s02_axi_bvalid),
        .s02_axi_bready     (ic_s02_axi_bready),
        .s02_axi_arid       (ic_s02_axi_arid),
        .s02_axi_araddr     (ic_s02_axi_araddr),
        .s02_axi_arlen      (ic_s02_axi_arlen),
        .s02_axi_arsize     (ic_s02_axi_arsize),
        .s02_axi_arburst    (ic_s02_axi_arburst),
        .s02_axi_arlock     (ic_s02_axi_arlock),
        .s02_axi_arcache    (ic_s02_axi_arcache),
        .s02_axi_arprot     (ic_s02_axi_arprot),
        .s02_axi_arqos      (ic_s02_axi_arqos),
        .s02_axi_aruser     (ic_s02_axi_aruser),
        .s02_axi_arvalid    (ic_s02_axi_arvalid),
        .s02_axi_arready    (ic_s02_axi_arready),
        .s02_axi_rid        (ic_s02_axi_rid),
        .s02_axi_rdata      (ic_s02_axi_rdata),
        .s02_axi_rresp      (ic_s02_axi_rresp),
        .s02_axi_rlast      (ic_s02_axi_rlast),
        .s02_axi_ruser      (ic_s02_axi_ruser),
        .s02_axi_rvalid     (ic_s02_axi_rvalid),
        .s02_axi_rready     (ic_s02_axi_rready),

        // S0: IMEM
        .m00_axi_awid       (m00_axi_awid),
        .m00_axi_awaddr     (m00_axi_awaddr),
        .m00_axi_awlen      (m00_axi_awlen),
        .m00_axi_awsize     (m00_axi_awsize),
        .m00_axi_awburst    (m00_axi_awburst),
        .m00_axi_awlock     (m00_axi_awlock),
        .m00_axi_awcache    (m00_axi_awcache),
        .m00_axi_awprot     (m00_axi_awprot),
        .m00_axi_awqos      (m00_axi_awqos),
        .m00_axi_awregion   (m00_axi_awregion),
        .m00_axi_awuser     (m00_axi_awuser),
        .m00_axi_awvalid    (m00_axi_awvalid),
        .m00_axi_awready    (m00_axi_awready),
        .m00_axi_wdata      (m00_axi_wdata),
        .m00_axi_wstrb      (m00_axi_wstrb),
        .m00_axi_wlast      (m00_axi_wlast),
        .m00_axi_wuser      (m00_axi_wuser),
        .m00_axi_wvalid     (m00_axi_wvalid),
        .m00_axi_wready     (m00_axi_wready),
        .m00_axi_bid        (m00_axi_bid),
        .m00_axi_bresp      (m00_axi_bresp),
        .m00_axi_buser      (m00_axi_buser),
        .m00_axi_bvalid     (m00_axi_bvalid),
        .m00_axi_bready     (m00_axi_bready),
        .m00_axi_arid       (m00_axi_arid),
        .m00_axi_araddr     (m00_axi_araddr),
        .m00_axi_arlen      (m00_axi_arlen),
        .m00_axi_arsize     (m00_axi_arsize),
        .m00_axi_arburst    (m00_axi_arburst),
        .m00_axi_arlock     (m00_axi_arlock),
        .m00_axi_arcache    (m00_axi_arcache),
        .m00_axi_arprot     (m00_axi_arprot),
        .m00_axi_arqos      (m00_axi_arqos),
        .m00_axi_arregion   (m00_axi_arregion),
        .m00_axi_aruser     (m00_axi_aruser),
        .m00_axi_arvalid    (m00_axi_arvalid),
        .m00_axi_arready    (m00_axi_arready),
        .m00_axi_rid        (m00_axi_rid),
        .m00_axi_rdata      (m00_axi_rdata),
        .m00_axi_rresp      (m00_axi_rresp),
        .m00_axi_rlast      (m00_axi_rlast),
        .m00_axi_ruser      (m00_axi_ruser),
        .m00_axi_rvalid     (m00_axi_rvalid),
        .m00_axi_rready     (m00_axi_rready),

        // S1: DMEM
        .m01_axi_awid       (m01_axi_awid),
        .m01_axi_awaddr     (m01_axi_awaddr),
        .m01_axi_awlen      (m01_axi_awlen),
        .m01_axi_awsize     (m01_axi_awsize),
        .m01_axi_awburst    (m01_axi_awburst),
        .m01_axi_awlock     (m01_axi_awlock),
        .m01_axi_awcache    (m01_axi_awcache),
        .m01_axi_awprot     (m01_axi_awprot),
        .m01_axi_awqos      (m01_axi_awqos),
        .m01_axi_awregion   (m01_axi_awregion),
        .m01_axi_awuser     (m01_axi_awuser),
        .m01_axi_awvalid    (m01_axi_awvalid),
        .m01_axi_awready    (m01_axi_awready),
        .m01_axi_wdata      (m01_axi_wdata),
        .m01_axi_wstrb      (m01_axi_wstrb),
        .m01_axi_wlast      (m01_axi_wlast),
        .m01_axi_wuser      (m01_axi_wuser),
        .m01_axi_wvalid     (m01_axi_wvalid),
        .m01_axi_wready     (m01_axi_wready),
        .m01_axi_bid        (m01_axi_bid),
        .m01_axi_bresp      (m01_axi_bresp),
        .m01_axi_buser      (m01_axi_buser),
        .m01_axi_bvalid     (m01_axi_bvalid),
        .m01_axi_bready     (m01_axi_bready),
        .m01_axi_arid       (m01_axi_arid),
        .m01_axi_araddr     (m01_axi_araddr),
        .m01_axi_arlen      (m01_axi_arlen),
        .m01_axi_arsize     (m01_axi_arsize),
        .m01_axi_arburst    (m01_axi_arburst),
        .m01_axi_arlock     (m01_axi_arlock),
        .m01_axi_arcache    (m01_axi_arcache),
        .m01_axi_arprot     (m01_axi_arprot),
        .m01_axi_arqos      (m01_axi_arqos),
        .m01_axi_arregion   (m01_axi_arregion),
        .m01_axi_aruser     (m01_axi_aruser),
        .m01_axi_arvalid    (m01_axi_arvalid),
        .m01_axi_arready    (m01_axi_arready),
        .m01_axi_rid        (m01_axi_rid),
        .m01_axi_rdata      (m01_axi_rdata),
        .m01_axi_rresp      (m01_axi_rresp),
        .m01_axi_rlast      (m01_axi_rlast),
        .m01_axi_ruser      (m01_axi_ruser),
        .m01_axi_rvalid     (m01_axi_rvalid),
        .m01_axi_rready     (m01_axi_rready),

        // S2: GPIO
        .m02_axi_awid       (m02_axi_awid),
        .m02_axi_awaddr     (m02_axi_awaddr),
        .m02_axi_awlen      (m02_axi_awlen),
        .m02_axi_awsize     (m02_axi_awsize),
        .m02_axi_awburst    (m02_axi_awburst),
        .m02_axi_awlock     (m02_axi_awlock),
        .m02_axi_awcache    (m02_axi_awcache),
        .m02_axi_awprot     (m02_axi_awprot),
        .m02_axi_awqos      (m02_axi_awqos),
        .m02_axi_awregion   (m02_axi_awregion),
        .m02_axi_awuser     (m02_axi_awuser),
        .m02_axi_awvalid    (m02_axi_awvalid),
        .m02_axi_awready    (m02_axi_awready),
        .m02_axi_wdata      (m02_axi_wdata),
        .m02_axi_wstrb      (m02_axi_wstrb),
        .m02_axi_wlast      (m02_axi_wlast),
        .m02_axi_wuser      (m02_axi_wuser),
        .m02_axi_wvalid     (m02_axi_wvalid),
        .m02_axi_wready     (m02_axi_wready),
        .m02_axi_bid        (m02_axi_bid),
        .m02_axi_bresp      (m02_axi_bresp),
        .m02_axi_buser      (m02_axi_buser),
        .m02_axi_bvalid     (m02_axi_bvalid),
        .m02_axi_bready     (m02_axi_bready),
        .m02_axi_arid       (m02_axi_arid),
        .m02_axi_araddr     (m02_axi_araddr),
        .m02_axi_arlen      (m02_axi_arlen),
        .m02_axi_arsize     (m02_axi_arsize),
        .m02_axi_arburst    (m02_axi_arburst),
        .m02_axi_arlock     (m02_axi_arlock),
        .m02_axi_arcache    (m02_axi_arcache),
        .m02_axi_arprot     (m02_axi_arprot),
        .m02_axi_arqos      (m02_axi_arqos),
        .m02_axi_arregion   (m02_axi_arregion),
        .m02_axi_aruser     (m02_axi_aruser),
        .m02_axi_arvalid    (m02_axi_arvalid),
        .m02_axi_arready    (m02_axi_arready),
        .m02_axi_rid        (m02_axi_rid),
        .m02_axi_rdata      (m02_axi_rdata),
        .m02_axi_rresp      (m02_axi_rresp),
        .m02_axi_rlast      (m02_axi_rlast),
        .m02_axi_ruser      (m02_axi_ruser),
        .m02_axi_rvalid     (m02_axi_rvalid),
        .m02_axi_rready     (m02_axi_rready),

        // S3: Timer
        .m03_axi_awid       (m03_axi_awid),
        .m03_axi_awaddr     (m03_axi_awaddr),
        .m03_axi_awlen      (m03_axi_awlen),
        .m03_axi_awsize     (m03_axi_awsize),
        .m03_axi_awburst    (m03_axi_awburst),
        .m03_axi_awlock     (m03_axi_awlock),
        .m03_axi_awcache    (m03_axi_awcache),
        .m03_axi_awprot     (m03_axi_awprot),
        .m03_axi_awqos      (m03_axi_awqos),
        .m03_axi_awregion   (m03_axi_awregion),
        .m03_axi_awuser     (m03_axi_awuser),
        .m03_axi_awvalid    (m03_axi_awvalid),
        .m03_axi_awready    (m03_axi_awready),
        .m03_axi_wdata      (m03_axi_wdata),
        .m03_axi_wstrb      (m03_axi_wstrb),
        .m03_axi_wlast      (m03_axi_wlast),
        .m03_axi_wuser      (m03_axi_wuser),
        .m03_axi_wvalid     (m03_axi_wvalid),
        .m03_axi_wready     (m03_axi_wready),
        .m03_axi_bid        (m03_axi_bid),
        .m03_axi_bresp      (m03_axi_bresp),
        .m03_axi_buser      (m03_axi_buser),
        .m03_axi_bvalid     (m03_axi_bvalid),
        .m03_axi_bready     (m03_axi_bready),
        .m03_axi_arid       (m03_axi_arid),
        .m03_axi_araddr     (m03_axi_araddr),
        .m03_axi_arlen      (m03_axi_arlen),
        .m03_axi_arsize     (m03_axi_arsize),
        .m03_axi_arburst    (m03_axi_arburst),
        .m03_axi_arlock     (m03_axi_arlock),
        .m03_axi_arcache    (m03_axi_arcache),
        .m03_axi_arprot     (m03_axi_arprot),
        .m03_axi_arqos      (m03_axi_arqos),
        .m03_axi_arregion   (m03_axi_arregion),
        .m03_axi_aruser     (m03_axi_aruser),
        .m03_axi_arvalid    (m03_axi_arvalid),
        .m03_axi_arready    (m03_axi_arready),
        .m03_axi_rid        (m03_axi_rid),
        .m03_axi_rdata      (m03_axi_rdata),
        .m03_axi_rresp      (m03_axi_rresp),
        .m03_axi_rlast      (m03_axi_rlast),
        .m03_axi_ruser      (m03_axi_ruser),
        .m03_axi_rvalid     (m03_axi_rvalid),
        .m03_axi_rready     (m03_axi_rready),

        // S4: UART (connected internally to UART logic below)
        .m04_axi_awid       (m04_axi_awid),
        .m04_axi_awaddr     (m04_axi_awaddr),
        .m04_axi_awlen      (m04_axi_awlen),
        .m04_axi_awsize     (m04_axi_awsize),
        .m04_axi_awburst    (m04_axi_awburst),
        .m04_axi_awlock     (m04_axi_awlock),
        .m04_axi_awcache    (m04_axi_awcache),
        .m04_axi_awprot     (m04_axi_awprot),
        .m04_axi_awqos      (m04_axi_awqos),
        .m04_axi_awregion   (m04_axi_awregion),
        .m04_axi_awuser     (m04_axi_awuser),
        .m04_axi_awvalid    (m04_axi_awvalid),
        .m04_axi_awready    (m04_axi_awready),
        .m04_axi_wdata      (m04_axi_wdata),
        .m04_axi_wstrb      (m04_axi_wstrb),
        .m04_axi_wlast      (m04_axi_wlast),
        .m04_axi_wuser      (m04_axi_wuser),
        .m04_axi_wvalid     (m04_axi_wvalid),
        .m04_axi_wready     (m04_axi_wready),
        .m04_axi_bid        (m04_axi_bid),
        .m04_axi_bresp      (m04_axi_bresp),
        .m04_axi_buser      (m04_axi_buser),
        .m04_axi_bvalid     (m04_axi_bvalid),
        .m04_axi_bready     (m04_axi_bready),
        .m04_axi_arid       (m04_axi_arid),
        .m04_axi_araddr     (m04_axi_araddr),
        .m04_axi_arlen      (m04_axi_arlen),
        .m04_axi_arsize     (m04_axi_arsize),
        .m04_axi_arburst    (m04_axi_arburst),
        .m04_axi_arlock     (m04_axi_arlock),
        .m04_axi_arcache    (m04_axi_arcache),
        .m04_axi_arprot     (m04_axi_arprot),
        .m04_axi_arqos      (m04_axi_arqos),
        .m04_axi_arregion   (m04_axi_arregion),
        .m04_axi_aruser     (m04_axi_aruser),
        .m04_axi_arvalid    (m04_axi_arvalid),
        .m04_axi_arready    (m04_axi_arready),
        .m04_axi_rid        (m04_axi_rid),
        .m04_axi_rdata      (m04_axi_rdata),
        .m04_axi_rresp      (m04_axi_rresp),
        .m04_axi_rlast      (m04_axi_rlast),
        .m04_axi_ruser      (m04_axi_ruser),
        .m04_axi_rvalid     (m04_axi_rvalid),
        .m04_axi_rready     (m04_axi_rready),

        // S5: Encoder
        .m05_axi_awid       (m05_axi_awid),
        .m05_axi_awaddr     (m05_axi_awaddr),
        .m05_axi_awlen      (m05_axi_awlen),
        .m05_axi_awsize     (m05_axi_awsize),
        .m05_axi_awburst    (m05_axi_awburst),
        .m05_axi_awlock     (m05_axi_awlock),
        .m05_axi_awcache    (m05_axi_awcache),
        .m05_axi_awprot     (m05_axi_awprot),
        .m05_axi_awqos      (m05_axi_awqos),
        .m05_axi_awregion   (m05_axi_awregion),
        .m05_axi_awuser     (m05_axi_awuser),
        .m05_axi_awvalid    (m05_axi_awvalid),
        .m05_axi_awready    (m05_axi_awready),
        .m05_axi_wdata      (m05_axi_wdata),
        .m05_axi_wstrb      (m05_axi_wstrb),
        .m05_axi_wlast      (m05_axi_wlast),
        .m05_axi_wuser      (m05_axi_wuser),
        .m05_axi_wvalid     (m05_axi_wvalid),
        .m05_axi_wready     (m05_axi_wready),
        .m05_axi_bid        (m05_axi_bid),
        .m05_axi_bresp      (m05_axi_bresp),
        .m05_axi_buser      (m05_axi_buser),
        .m05_axi_bvalid     (m05_axi_bvalid),
        .m05_axi_bready     (m05_axi_bready),
        .m05_axi_arid       (m05_axi_arid),
        .m05_axi_araddr     (m05_axi_araddr),
        .m05_axi_arlen      (m05_axi_arlen),
        .m05_axi_arsize     (m05_axi_arsize),
        .m05_axi_arburst    (m05_axi_arburst),
        .m05_axi_arlock     (m05_axi_arlock),
        .m05_axi_arcache    (m05_axi_arcache),
        .m05_axi_arprot     (m05_axi_arprot),
        .m05_axi_arqos      (m05_axi_arqos),
        .m05_axi_arregion   (m05_axi_arregion),
        .m05_axi_aruser     (m05_axi_aruser),
        .m05_axi_arvalid    (m05_axi_arvalid),
        .m05_axi_arready    (m05_axi_arready),
        .m05_axi_rid        (m05_axi_rid),
        .m05_axi_rdata      (m05_axi_rdata),
        .m05_axi_rresp      (m05_axi_rresp),
        .m05_axi_rlast      (m05_axi_rlast),
        .m05_axi_ruser      (m05_axi_ruser),
        .m05_axi_rvalid     (m05_axi_rvalid),
        .m05_axi_rready     (m05_axi_rready),

        // S6: PID
        .m06_axi_awid       (m06_axi_awid),
        .m06_axi_awaddr     (m06_axi_awaddr),
        .m06_axi_awlen      (m06_axi_awlen),
        .m06_axi_awsize     (m06_axi_awsize),
        .m06_axi_awburst    (m06_axi_awburst),
        .m06_axi_awlock     (m06_axi_awlock),
        .m06_axi_awcache    (m06_axi_awcache),
        .m06_axi_awprot     (m06_axi_awprot),
        .m06_axi_awqos      (m06_axi_awqos),
        .m06_axi_awregion   (m06_axi_awregion),
        .m06_axi_awuser     (m06_axi_awuser),
        .m06_axi_awvalid    (m06_axi_awvalid),
        .m06_axi_awready    (m06_axi_awready),
        .m06_axi_wdata      (m06_axi_wdata),
        .m06_axi_wstrb      (m06_axi_wstrb),
        .m06_axi_wlast      (m06_axi_wlast),
        .m06_axi_wuser      (m06_axi_wuser),
        .m06_axi_wvalid     (m06_axi_wvalid),
        .m06_axi_wready     (m06_axi_wready),
        .m06_axi_bid        (m06_axi_bid),
        .m06_axi_bresp      (m06_axi_bresp),
        .m06_axi_buser      (m06_axi_buser),
        .m06_axi_bvalid     (m06_axi_bvalid),
        .m06_axi_bready     (m06_axi_bready),
        .m06_axi_arid       (m06_axi_arid),
        .m06_axi_araddr     (m06_axi_araddr),
        .m06_axi_arlen      (m06_axi_arlen),
        .m06_axi_arsize     (m06_axi_arsize),
        .m06_axi_arburst    (m06_axi_arburst),
        .m06_axi_arlock     (m06_axi_arlock),
        .m06_axi_arcache    (m06_axi_arcache),
        .m06_axi_arprot     (m06_axi_arprot),
        .m06_axi_arqos      (m06_axi_arqos),
        .m06_axi_arregion   (m06_axi_arregion),
        .m06_axi_aruser     (m06_axi_aruser),
        .m06_axi_arvalid    (m06_axi_arvalid),
        .m06_axi_arready    (m06_axi_arready),
        .m06_axi_rid        (m06_axi_rid),
        .m06_axi_rdata      (m06_axi_rdata),
        .m06_axi_rresp      (m06_axi_rresp),
        .m06_axi_rlast      (m06_axi_rlast),
        .m06_axi_ruser      (m06_axi_ruser),
        .m06_axi_rvalid     (m06_axi_rvalid),
        .m06_axi_rready     (m06_axi_rready),

        // S7: PWM Generator
        .m07_axi_awid       (m07_axi_awid),
        .m07_axi_awaddr     (m07_axi_awaddr),
        .m07_axi_awlen      (m07_axi_awlen),
        .m07_axi_awsize     (m07_axi_awsize),
        .m07_axi_awburst    (m07_axi_awburst),
        .m07_axi_awlock     (m07_axi_awlock),
        .m07_axi_awcache    (m07_axi_awcache),
        .m07_axi_awprot     (m07_axi_awprot),
        .m07_axi_awqos      (m07_axi_awqos),
        .m07_axi_awregion   (m07_axi_awregion),
        .m07_axi_awuser     (m07_axi_awuser),
        .m07_axi_awvalid    (m07_axi_awvalid),
        .m07_axi_awready    (m07_axi_awready),
        .m07_axi_wdata      (m07_axi_wdata),
        .m07_axi_wstrb      (m07_axi_wstrb),
        .m07_axi_wlast      (m07_axi_wlast),
        .m07_axi_wuser      (m07_axi_wuser),
        .m07_axi_wvalid     (m07_axi_wvalid),
        .m07_axi_wready     (m07_axi_wready),
        .m07_axi_bid        (m07_axi_bid),
        .m07_axi_bresp      (m07_axi_bresp),
        .m07_axi_buser      (m07_axi_buser),
        .m07_axi_bvalid     (m07_axi_bvalid),
        .m07_axi_bready     (m07_axi_bready),
        .m07_axi_arid       (m07_axi_arid),
        .m07_axi_araddr     (m07_axi_araddr),
        .m07_axi_arlen      (m07_axi_arlen),
        .m07_axi_arsize     (m07_axi_arsize),
        .m07_axi_arburst    (m07_axi_arburst),
        .m07_axi_arlock     (m07_axi_arlock),
        .m07_axi_arcache    (m07_axi_arcache),
        .m07_axi_arprot     (m07_axi_arprot),
        .m07_axi_arqos      (m07_axi_arqos),
        .m07_axi_arregion   (m07_axi_arregion),
        .m07_axi_aruser     (m07_axi_aruser),
        .m07_axi_arvalid    (m07_axi_arvalid),
        .m07_axi_arready    (m07_axi_arready),
        .m07_axi_rid        (m07_axi_rid),
        .m07_axi_rdata      (m07_axi_rdata),
        .m07_axi_rresp      (m07_axi_rresp),
        .m07_axi_rlast      (m07_axi_rlast),
        .m07_axi_ruser      (m07_axi_ruser),
        .m07_axi_rvalid     (m07_axi_rvalid),
        .m07_axi_rready     (m07_axi_rready),

        // S8: Keypad Controller
        .m08_axi_awid       (m08_axi_awid),
        .m08_axi_awaddr     (m08_axi_awaddr),
        .m08_axi_awlen      (m08_axi_awlen),
        .m08_axi_awsize     (m08_axi_awsize),
        .m08_axi_awburst    (m08_axi_awburst),
        .m08_axi_awlock     (m08_axi_awlock),
        .m08_axi_awcache    (m08_axi_awcache),
        .m08_axi_awprot     (m08_axi_awprot),
        .m08_axi_awqos      (m08_axi_awqos),
        .m08_axi_awregion   (m08_axi_awregion),
        .m08_axi_awuser     (m08_axi_awuser),
        .m08_axi_awvalid    (m08_axi_awvalid),
        .m08_axi_awready    (m08_axi_awready),
        .m08_axi_wdata      (m08_axi_wdata),
        .m08_axi_wstrb      (m08_axi_wstrb),
        .m08_axi_wlast      (m08_axi_wlast),
        .m08_axi_wuser      (m08_axi_wuser),
        .m08_axi_wvalid     (m08_axi_wvalid),
        .m08_axi_wready     (m08_axi_wready),
        .m08_axi_bid        (m08_axi_bid),
        .m08_axi_bresp      (m08_axi_bresp),
        .m08_axi_buser      (m08_axi_buser),
        .m08_axi_bvalid     (m08_axi_bvalid),
        .m08_axi_bready     (m08_axi_bready),
        .m08_axi_arid       (m08_axi_arid),
        .m08_axi_araddr     (m08_axi_araddr),
        .m08_axi_arlen      (m08_axi_arlen),
        .m08_axi_arsize     (m08_axi_arsize),
        .m08_axi_arburst    (m08_axi_arburst),
        .m08_axi_arlock     (m08_axi_arlock),
        .m08_axi_arcache    (m08_axi_arcache),
        .m08_axi_arprot     (m08_axi_arprot),
        .m08_axi_arqos      (m08_axi_arqos),
        .m08_axi_arregion   (m08_axi_arregion),
        .m08_axi_aruser     (m08_axi_aruser),
        .m08_axi_arvalid    (m08_axi_arvalid),
        .m08_axi_arready    (m08_axi_arready),
        .m08_axi_rid        (m08_axi_rid),
        .m08_axi_rdata      (m08_axi_rdata),
        .m08_axi_rresp      (m08_axi_rresp),
        .m08_axi_rlast      (m08_axi_rlast),
        .m08_axi_ruser      (m08_axi_ruser),
        .m08_axi_rvalid     (m08_axi_rvalid),
        .m08_axi_rready     (m08_axi_rready),

        // S9: Authentication
        .m09_axi_awid       (m09_axi_awid),
        .m09_axi_awaddr     (m09_axi_awaddr),
        .m09_axi_awlen      (m09_axi_awlen),
        .m09_axi_awsize     (m09_axi_awsize),
        .m09_axi_awburst    (m09_axi_awburst),
        .m09_axi_awlock     (m09_axi_awlock),
        .m09_axi_awcache    (m09_axi_awcache),
        .m09_axi_awprot     (m09_axi_awprot),
        .m09_axi_awqos      (m09_axi_awqos),
        .m09_axi_awregion   (m09_axi_awregion),
        .m09_axi_awuser     (m09_axi_awuser),
        .m09_axi_awvalid    (m09_axi_awvalid),
        .m09_axi_awready    (m09_axi_awready),
        .m09_axi_wdata      (m09_axi_wdata),
        .m09_axi_wstrb      (m09_axi_wstrb),
        .m09_axi_wlast      (m09_axi_wlast),
        .m09_axi_wuser      (m09_axi_wuser),
        .m09_axi_wvalid     (m09_axi_wvalid),
        .m09_axi_wready     (m09_axi_wready),
        .m09_axi_bid        (m09_axi_bid),
        .m09_axi_bresp      (m09_axi_bresp),
        .m09_axi_buser      (m09_axi_buser),
        .m09_axi_bvalid     (m09_axi_bvalid),
        .m09_axi_bready     (m09_axi_bready),
        .m09_axi_arid       (m09_axi_arid),
        .m09_axi_araddr     (m09_axi_araddr),
        .m09_axi_arlen      (m09_axi_arlen),
        .m09_axi_arsize     (m09_axi_arsize),
        .m09_axi_arburst    (m09_axi_arburst),
        .m09_axi_arlock     (m09_axi_arlock),
        .m09_axi_arcache    (m09_axi_arcache),
        .m09_axi_arprot     (m09_axi_arprot),
        .m09_axi_arqos      (m09_axi_arqos),
        .m09_axi_arregion   (m09_axi_arregion),
        .m09_axi_aruser     (m09_axi_aruser),
        .m09_axi_arvalid    (m09_axi_arvalid),
        .m09_axi_arready    (m09_axi_arready),
        .m09_axi_rid        (m09_axi_rid),
        .m09_axi_rdata      (m09_axi_rdata),
        .m09_axi_rresp      (m09_axi_rresp),
        .m09_axi_rlast      (m09_axi_rlast),
        .m09_axi_ruser      (m09_axi_ruser),
        .m09_axi_rvalid     (m09_axi_rvalid),
        .m09_axi_rready     (m09_axi_rready),

        // S10: Buzzer
        .m10_axi_awid       (m10_axi_awid),
        .m10_axi_awaddr     (m10_axi_awaddr),
        .m10_axi_awlen      (m10_axi_awlen),
        .m10_axi_awsize     (m10_axi_awsize),
        .m10_axi_awburst    (m10_axi_awburst),
        .m10_axi_awlock     (m10_axi_awlock),
        .m10_axi_awcache    (m10_axi_awcache),
        .m10_axi_awprot     (m10_axi_awprot),
        .m10_axi_awqos      (m10_axi_awqos),
        .m10_axi_awregion   (m10_axi_awregion),
        .m10_axi_awuser     (m10_axi_awuser),
        .m10_axi_awvalid    (m10_axi_awvalid),
        .m10_axi_awready    (m10_axi_awready),
        .m10_axi_wdata      (m10_axi_wdata),
        .m10_axi_wstrb      (m10_axi_wstrb),
        .m10_axi_wlast      (m10_axi_wlast),
        .m10_axi_wuser      (m10_axi_wuser),
        .m10_axi_wvalid     (m10_axi_wvalid),
        .m10_axi_wready     (m10_axi_wready),
        .m10_axi_bid        (m10_axi_bid),
        .m10_axi_bresp      (m10_axi_bresp),
        .m10_axi_buser      (m10_axi_buser),
        .m10_axi_bvalid     (m10_axi_bvalid),
        .m10_axi_bready     (m10_axi_bready),
        .m10_axi_arid       (m10_axi_arid),
        .m10_axi_araddr     (m10_axi_araddr),
        .m10_axi_arlen      (m10_axi_arlen),
        .m10_axi_arsize     (m10_axi_arsize),
        .m10_axi_arburst    (m10_axi_arburst),
        .m10_axi_arlock     (m10_axi_arlock),
        .m10_axi_arcache    (m10_axi_arcache),
        .m10_axi_arprot     (m10_axi_arprot),
        .m10_axi_arqos      (m10_axi_arqos),
        .m10_axi_arregion   (m10_axi_arregion),
        .m10_axi_aruser     (m10_axi_aruser),
        .m10_axi_arvalid    (m10_axi_arvalid),
        .m10_axi_arready    (m10_axi_arready),
        .m10_axi_rid        (m10_axi_rid),
        .m10_axi_rdata      (m10_axi_rdata),
        .m10_axi_rresp      (m10_axi_rresp),
        .m10_axi_rlast      (m10_axi_rlast),
        .m10_axi_ruser      (m10_axi_ruser),
        .m10_axi_rvalid     (m10_axi_rvalid),
        .m10_axi_rready     (m10_axi_rready),

        // S11: Watchdog
        .m11_axi_awid       (m11_axi_awid),
        .m11_axi_awaddr     (m11_axi_awaddr),
        .m11_axi_awlen      (m11_axi_awlen),
        .m11_axi_awsize     (m11_axi_awsize),
        .m11_axi_awburst    (m11_axi_awburst),
        .m11_axi_awlock     (m11_axi_awlock),
        .m11_axi_awcache    (m11_axi_awcache),
        .m11_axi_awprot     (m11_axi_awprot),
        .m11_axi_awqos      (m11_axi_awqos),
        .m11_axi_awregion   (m11_axi_awregion),
        .m11_axi_awuser     (m11_axi_awuser),
        .m11_axi_awvalid    (m11_axi_awvalid),
        .m11_axi_awready    (m11_axi_awready),
        .m11_axi_wdata      (m11_axi_wdata),
        .m11_axi_wstrb      (m11_axi_wstrb),
        .m11_axi_wlast      (m11_axi_wlast),
        .m11_axi_wuser      (m11_axi_wuser),
        .m11_axi_wvalid     (m11_axi_wvalid),
        .m11_axi_wready     (m11_axi_wready),
        .m11_axi_bid        (m11_axi_bid),
        .m11_axi_bresp      (m11_axi_bresp),
        .m11_axi_buser      (m11_axi_buser),
        .m11_axi_bvalid     (m11_axi_bvalid),
        .m11_axi_bready     (m11_axi_bready),
        .m11_axi_arid       (m11_axi_arid),
        .m11_axi_araddr     (m11_axi_araddr),
        .m11_axi_arlen      (m11_axi_arlen),
        .m11_axi_arsize     (m11_axi_arsize),
        .m11_axi_arburst    (m11_axi_arburst),
        .m11_axi_arlock     (m11_axi_arlock),
        .m11_axi_arcache    (m11_axi_arcache),
        .m11_axi_arprot     (m11_axi_arprot),
        .m11_axi_arqos      (m11_axi_arqos),
        .m11_axi_arregion   (m11_axi_arregion),
        .m11_axi_aruser     (m11_axi_aruser),
        .m11_axi_arvalid    (m11_axi_arvalid),
        .m11_axi_arready    (m11_axi_arready),
        .m11_axi_rid        (m11_axi_rid),
        .m11_axi_rdata      (m11_axi_rdata),
        .m11_axi_rresp      (m11_axi_rresp),
        .m11_axi_rlast      (m11_axi_rlast),
        .m11_axi_ruser      (m11_axi_ruser),
        .m11_axi_rvalid     (m11_axi_rvalid),
        .m11_axi_rready     (m11_axi_rready),

        // S12: ADC
        .m12_axi_awid       (m12_axi_awid),
        .m12_axi_awaddr     (m12_axi_awaddr),
        .m12_axi_awlen      (m12_axi_awlen),
        .m12_axi_awsize     (m12_axi_awsize),
        .m12_axi_awburst    (m12_axi_awburst),
        .m12_axi_awlock     (m12_axi_awlock),
        .m12_axi_awcache    (m12_axi_awcache),
        .m12_axi_awprot     (m12_axi_awprot),
        .m12_axi_awqos      (m12_axi_awqos),
        .m12_axi_awregion   (m12_axi_awregion),
        .m12_axi_awuser     (m12_axi_awuser),
        .m12_axi_awvalid    (m12_axi_awvalid),
        .m12_axi_awready    (m12_axi_awready),
        .m12_axi_wdata      (m12_axi_wdata),
        .m12_axi_wstrb      (m12_axi_wstrb),
        .m12_axi_wlast      (m12_axi_wlast),
        .m12_axi_wuser      (m12_axi_wuser),
        .m12_axi_wvalid     (m12_axi_wvalid),
        .m12_axi_wready     (m12_axi_wready),
        .m12_axi_bid        (m12_axi_bid),
        .m12_axi_bresp      (m12_axi_bresp),
        .m12_axi_buser      (m12_axi_buser),
        .m12_axi_bvalid     (m12_axi_bvalid),
        .m12_axi_bready     (m12_axi_bready),
        .m12_axi_arid       (m12_axi_arid),
        .m12_axi_araddr     (m12_axi_araddr),
        .m12_axi_arlen      (m12_axi_arlen),
        .m12_axi_arsize     (m12_axi_arsize),
        .m12_axi_arburst    (m12_axi_arburst),
        .m12_axi_arlock     (m12_axi_arlock),
        .m12_axi_arcache    (m12_axi_arcache),
        .m12_axi_arprot     (m12_axi_arprot),
        .m12_axi_arqos      (m12_axi_arqos),
        .m12_axi_arregion   (m12_axi_arregion),
        .m12_axi_aruser     (m12_axi_aruser),
        .m12_axi_arvalid    (m12_axi_arvalid),
        .m12_axi_arready    (m12_axi_arready),
        .m12_axi_rid        (m12_axi_rid),
        .m12_axi_rdata      (m12_axi_rdata),
        .m12_axi_rresp      (m12_axi_rresp),
        .m12_axi_rlast      (m12_axi_rlast),
        .m12_axi_ruser      (m12_axi_ruser),
        .m12_axi_rvalid     (m12_axi_rvalid),
        .m12_axi_rready     (m12_axi_rready),

        // S13: DMA Registers
        .m13_axi_awid       (m13_axi_awid),
        .m13_axi_awaddr     (m13_axi_awaddr),
        .m13_axi_awlen      (m13_axi_awlen),
        .m13_axi_awsize     (m13_axi_awsize),
        .m13_axi_awburst    (m13_axi_awburst),
        .m13_axi_awlock     (m13_axi_awlock),
        .m13_axi_awcache    (m13_axi_awcache),
        .m13_axi_awprot     (m13_axi_awprot),
        .m13_axi_awqos      (m13_axi_awqos),
        .m13_axi_awregion   (m13_axi_awregion),
        .m13_axi_awuser     (m13_axi_awuser),
        .m13_axi_awvalid    (m13_axi_awvalid),
        .m13_axi_awready    (m13_axi_awready),
        .m13_axi_wdata      (m13_axi_wdata),
        .m13_axi_wstrb      (m13_axi_wstrb),
        .m13_axi_wlast      (m13_axi_wlast),
        .m13_axi_wuser      (m13_axi_wuser),
        .m13_axi_wvalid     (m13_axi_wvalid),
        .m13_axi_wready     (m13_axi_wready),
        .m13_axi_bid        (m13_axi_bid),
        .m13_axi_bresp      (m13_axi_bresp),
        .m13_axi_buser      (m13_axi_buser),
        .m13_axi_bvalid     (m13_axi_bvalid),
        .m13_axi_bready     (m13_axi_bready),
        .m13_axi_arid       (m13_axi_arid),
        .m13_axi_araddr     (m13_axi_araddr),
        .m13_axi_arlen      (m13_axi_arlen),
        .m13_axi_arsize     (m13_axi_arsize),
        .m13_axi_arburst    (m13_axi_arburst),
        .m13_axi_arlock     (m13_axi_arlock),
        .m13_axi_arcache    (m13_axi_arcache),
        .m13_axi_arprot     (m13_axi_arprot),
        .m13_axi_arqos      (m13_axi_arqos),
        .m13_axi_arregion   (m13_axi_arregion),
        .m13_axi_aruser     (m13_axi_aruser),
        .m13_axi_arvalid    (m13_axi_arvalid),
        .m13_axi_arready    (m13_axi_arready),
        .m13_axi_rid        (m13_axi_rid),
        .m13_axi_rdata      (m13_axi_rdata),
        .m13_axi_rresp      (m13_axi_rresp),
        .m13_axi_rlast      (m13_axi_rlast),
        .m13_axi_ruser      (m13_axi_ruser),
        .m13_axi_rvalid     (m13_axi_rvalid),
        .m13_axi_rready     (m13_axi_rready),

        // S14: Seven-Segment
        .m14_axi_awid       (m14_axi_awid),
        .m14_axi_awaddr     (m14_axi_awaddr),
        .m14_axi_awlen      (m14_axi_awlen),
        .m14_axi_awsize     (m14_axi_awsize),
        .m14_axi_awburst    (m14_axi_awburst),
        .m14_axi_awlock     (m14_axi_awlock),
        .m14_axi_awcache    (m14_axi_awcache),
        .m14_axi_awprot     (m14_axi_awprot),
        .m14_axi_awqos      (m14_axi_awqos),
        .m14_axi_awregion   (m14_axi_awregion),
        .m14_axi_awuser     (m14_axi_awuser),
        .m14_axi_awvalid    (m14_axi_awvalid),
        .m14_axi_awready    (m14_axi_awready),
        .m14_axi_wdata      (m14_axi_wdata),
        .m14_axi_wstrb      (m14_axi_wstrb),
        .m14_axi_wlast      (m14_axi_wlast),
        .m14_axi_wuser      (m14_axi_wuser),
        .m14_axi_wvalid     (m14_axi_wvalid),
        .m14_axi_wready     (m14_axi_wready),
        .m14_axi_bid        (m14_axi_bid),
        .m14_axi_bresp      (m14_axi_bresp),
        .m14_axi_buser      (m14_axi_buser),
        .m14_axi_bvalid     (m14_axi_bvalid),
        .m14_axi_bready     (m14_axi_bready),
        .m14_axi_arid       (m14_axi_arid),
        .m14_axi_araddr     (m14_axi_araddr),
        .m14_axi_arlen      (m14_axi_arlen),
        .m14_axi_arsize     (m14_axi_arsize),
        .m14_axi_arburst    (m14_axi_arburst),
        .m14_axi_arlock     (m14_axi_arlock),
        .m14_axi_arcache    (m14_axi_arcache),
        .m14_axi_arprot     (m14_axi_arprot),
        .m14_axi_arqos      (m14_axi_arqos),
        .m14_axi_arregion   (m14_axi_arregion),
        .m14_axi_aruser     (m14_axi_aruser),
        .m14_axi_arvalid    (m14_axi_arvalid),
        .m14_axi_arready    (m14_axi_arready),
        .m14_axi_rid        (m14_axi_rid),
        .m14_axi_rdata      (m14_axi_rdata),
        .m14_axi_rresp      (m14_axi_rresp),
        .m14_axi_rlast      (m14_axi_rlast),
        .m14_axi_ruser      (m14_axi_ruser),
        .m14_axi_rvalid     (m14_axi_rvalid),
        .m14_axi_rready     (m14_axi_rready)
    );

    // ============================================================
    // S2: GPIO Controller (AXI4 → AXI4-Lite Bridge + gpio_axi)
    // Base Address : 0x8000_1000
    // ============================================================
    axi4_to_axi4lite_bridge #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .STRB_WIDTH     (STRB_WIDTH),
        .ID_WIDTH       (ID_WIDTH),
        .USER_WIDTH     (AWUSER_WIDTH)
    ) u_gpio_bridge (
        .aclk           (clk),
        .aresetn        (~rst),

        // Upstream AXI4 slave port (from interconnect m02)
        .s_awid         (m02_axi_awid),
        .s_awaddr       (m02_axi_awaddr),
        .s_awlen        (m02_axi_awlen),
        .s_awsize       (m02_axi_awsize),
        .s_awburst      (m02_axi_awburst),
        .s_awlock       (m02_axi_awlock),
        .s_awcache      (m02_axi_awcache),
        .s_awprot       (m02_axi_awprot),
        .s_awqos        (m02_axi_awqos),
        .s_awregion     (m02_axi_awregion),
        .s_awuser       (m02_axi_awuser),
        .s_awvalid      (m02_axi_awvalid),
        .s_awready      (m02_axi_awready),

        .s_wdata        (m02_axi_wdata),
        .s_wstrb        (m02_axi_wstrb),
        .s_wlast        (m02_axi_wlast),
        .s_wuser        (m02_axi_wuser),
        .s_wvalid       (m02_axi_wvalid),
        .s_wready       (m02_axi_wready),

        .s_bid          (m02_axi_bid),
        .s_bresp        (m02_axi_bresp),
        .s_buser        (m02_axi_buser),
        .s_bvalid       (m02_axi_bvalid),
        .s_bready       (m02_axi_bready),

        .s_arid         (m02_axi_arid),
        .s_araddr       (m02_axi_araddr),
        .s_arlen        (m02_axi_arlen),
        .s_arsize       (m02_axi_arsize),
        .s_arburst      (m02_axi_arburst),
        .s_arlock       (m02_axi_arlock),
        .s_arcache      (m02_axi_arcache),
        .s_arprot       (m02_axi_arprot),
        .s_arqos        (m02_axi_arqos),
        .s_arregion     (m02_axi_arregion),
        .s_aruser       (m02_axi_aruser),
        .s_arvalid      (m02_axi_arvalid),
        .s_arready      (m02_axi_arready),

        .s_rid          (m02_axi_rid),
        .s_rdata        (m02_axi_rdata),
        .s_rresp        (m02_axi_rresp),
        .s_rlast        (m02_axi_rlast),
        .s_ruser        (m02_axi_ruser),
        .s_rvalid       (m02_axi_rvalid),
        .s_rready       (m02_axi_rready),

        // Downstream AXI4-Lite master port (to gpio_axi)
        .m_awaddr       (gpio_axil_awaddr),
        .m_awprot       (gpio_axil_awprot),
        .m_awvalid      (gpio_axil_awvalid),
        .m_awready      (gpio_axil_awready),

        .m_wdata        (gpio_axil_wdata),
        .m_wstrb        (gpio_axil_wstrb),
        .m_wvalid       (gpio_axil_wvalid),
        .m_wready       (gpio_axil_wready),

        .m_bresp        (gpio_axil_bresp),
        .m_bvalid       (gpio_axil_bvalid),
        .m_bready       (gpio_axil_bready),

        .m_araddr       (gpio_axil_araddr),
        .m_arprot       (gpio_axil_arprot),
        .m_arvalid      (gpio_axil_arvalid),
        .m_arready      (gpio_axil_arready),

        .m_rdata        (gpio_axil_rdata),
        .m_rresp        (gpio_axil_rresp),
        .m_rvalid       (gpio_axil_rvalid),
        .m_rready       (gpio_axil_rready)
    );

    gpio_axi #(
        .NUM_BITS       (32)
    ) u_gpio_axi (
        .s_axi_aclk     (clk),
        .s_axi_aresetn  (~rst),

        .s_axi_awaddr   (gpio_axil_awaddr),
        .s_axi_awprot   (gpio_axil_awprot),
        .s_axi_awvalid  (gpio_axil_awvalid),
        .s_axi_awready  (gpio_axil_awready),

        .s_axi_wdata    (gpio_axil_wdata),
        .s_axi_wstrb    (gpio_axil_wstrb),
        .s_axi_wvalid   (gpio_axil_wvalid),
        .s_axi_wready   (gpio_axil_wready),

        .s_axi_bresp    (gpio_axil_bresp),
        .s_axi_bvalid   (gpio_axil_bvalid),
        .s_axi_bready   (gpio_axil_bready),

        .s_axi_araddr   (gpio_axil_araddr),
        .s_axi_arprot   (gpio_axil_arprot),
        .s_axi_arvalid  (gpio_axil_arvalid),
        .s_axi_arready  (gpio_axil_arready),

        .s_axi_rdata    (gpio_axil_rdata),
        .s_axi_rresp    (gpio_axil_rresp),
        .s_axi_rvalid   (gpio_axil_rvalid),
        .s_axi_rready   (gpio_axil_rready),

        .io             (gpio_io),
        .intr           (gpio_irq)
    );

    // ============================================================
    // S3: Real-Time Timer (AXI4 → AXI4-Lite Bridge + timer_axi)
    // Base Address : 0x8000_2000
    // ============================================================
    axi4_to_axi4lite_bridge #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .STRB_WIDTH     (STRB_WIDTH),
        .ID_WIDTH       (ID_WIDTH),
        .USER_WIDTH     (AWUSER_WIDTH)
    ) u_timer_bridge (
        .aclk           (clk),
        .aresetn        (~rst),

        // Upstream AXI4 slave port (from interconnect m03)
        .s_awid         (m03_axi_awid),
        .s_awaddr       (m03_axi_awaddr),
        .s_awlen        (m03_axi_awlen),
        .s_awsize       (m03_axi_awsize),
        .s_awburst      (m03_axi_awburst),
        .s_awlock       (m03_axi_awlock),
        .s_awcache      (m03_axi_awcache),
        .s_awprot       (m03_axi_awprot),
        .s_awqos        (m03_axi_awqos),
        .s_awregion     (m03_axi_awregion),
        .s_awuser       (m03_axi_awuser),
        .s_awvalid      (m03_axi_awvalid),
        .s_awready      (m03_axi_awready),

        .s_wdata        (m03_axi_wdata),
        .s_wstrb        (m03_axi_wstrb),
        .s_wlast        (m03_axi_wlast),
        .s_wuser        (m03_axi_wuser),
        .s_wvalid       (m03_axi_wvalid),
        .s_wready       (m03_axi_wready),

        .s_bid          (m03_axi_bid),
        .s_bresp        (m03_axi_bresp),
        .s_buser        (m03_axi_buser),
        .s_bvalid       (m03_axi_bvalid),
        .s_bready       (m03_axi_bready),

        .s_arid         (m03_axi_arid),
        .s_araddr       (m03_axi_araddr),
        .s_arlen        (m03_axi_arlen),
        .s_arsize       (m03_axi_arsize),
        .s_arburst      (m03_axi_arburst),
        .s_arlock       (m03_axi_arlock),
        .s_arcache      (m03_axi_arcache),
        .s_arprot       (m03_axi_arprot),
        .s_arqos        (m03_axi_arqos),
        .s_arregion     (m03_axi_arregion),
        .s_aruser       (m03_axi_aruser),
        .s_arvalid      (m03_axi_arvalid),
        .s_arready      (m03_axi_arready),

        .s_rid          (m03_axi_rid),
        .s_rdata        (m03_axi_rdata),
        .s_rresp        (m03_axi_rresp),
        .s_rlast        (m03_axi_rlast),
        .s_ruser        (m03_axi_ruser),
        .s_rvalid       (m03_axi_rvalid),
        .s_rready       (m03_axi_rready),

        // Downstream AXI4-Lite master port (to timer_axi)
        .m_awaddr       (timer_axil_awaddr),
        .m_awprot       (timer_axil_awprot),
        .m_awvalid      (timer_axil_awvalid),
        .m_awready      (timer_axil_awready),

        .m_wdata        (timer_axil_wdata),
        .m_wstrb        (timer_axil_wstrb),
        .m_wvalid       (timer_axil_wvalid),
        .m_wready       (timer_axil_wready),

        .m_bresp        (timer_axil_bresp),
        .m_bvalid       (timer_axil_bvalid),
        .m_bready       (timer_axil_bready),

        .m_araddr       (timer_axil_araddr),
        .m_arprot       (timer_axil_arprot),
        .m_arvalid      (timer_axil_arvalid),
        .m_arready      (timer_axil_arready),

        .m_rdata        (timer_axil_rdata),
        .m_rresp        (timer_axil_rresp),
        .m_rvalid       (timer_axil_rvalid),
        .m_rready       (timer_axil_rready)
    );

    timer_axi u_timer_axi (
        .aclk           (clk),
        .aresetn        (~rst),

        .awaddr         (timer_axil_awaddr),
        .awprot         (timer_axil_awprot),
        .awvalid        (timer_axil_awvalid),
        .awready        (timer_axil_awready),

        .wdata          (timer_axil_wdata),
        .wstrb          (timer_axil_wstrb),
        .wvalid         (timer_axil_wvalid),
        .wready         (timer_axil_wready),

        .bresp          (timer_axil_bresp),
        .bvalid         (timer_axil_bvalid),
        .bready         (timer_axil_bready),

        .araddr         (timer_axil_araddr),
        .arprot         (timer_axil_arprot),
        .arvalid        (timer_axil_arvalid),
        .arready        (timer_axil_arready),

        .rdata          (timer_axil_rdata),
        .rresp          (timer_axil_rresp),
        .rvalid         (timer_axil_rvalid),
        .rready         (timer_axil_rready),

        .ext_meas_i     (1'b0),
        .capture_i      (1'b0),
        .pwm_o          (timer_pwm),
        .trigger_o      (),
        .irq            (timer_irq)
    );

    // ============================================================
    // Direct Signal Adaptation for S4 UART (axi_uart_top)
    // ============================================================
    wire [11:0] uart_bid_w;
    wire [11:0] uart_rid_w;

    wire uart_awready_w;
    wire uart_wready_w;
    wire uart_bvalid_w;
    wire [1:0] uart_bresp_w;
    wire uart_arready_w;
    wire [31:0] uart_rdata_w;
    wire [1:0] uart_rresp_w;
    wire uart_rvalid_w;

    // Connect slave response signals back to interconnect m04
    assign m04_axi_awready = uart_awready_w;
    assign m04_axi_wready  = uart_wready_w;
    assign m04_axi_bid     = uart_bid_w[7:0];
    assign m04_axi_bresp   = uart_bresp_w;
    assign m04_axi_buser   = {BUSER_WIDTH{1'b0}};
    assign m04_axi_bvalid  = uart_bvalid_w;

    assign m04_axi_arready = uart_arready_w;
    assign m04_axi_rid     = uart_rid_w[7:0];
    assign m04_axi_rdata   = uart_rdata_w;
    assign m04_axi_rresp   = uart_rresp_w;
    assign m04_axi_rlast   = uart_rvalid_w; // Single-beat read terminates on valid data beat
    assign m04_axi_ruser   = {RUSER_WIDTH{1'b0}};
    assign m04_axi_rvalid  = uart_rvalid_w;

    axi_uart_top u_axi_uart (
        .fixed_clk_i      (fixed_clk),
        .axi_aclk_i       (clk),
        .axi_aresetn_i    (~rst),

        // Read address channel
        .axi_arid_i       ({4'b0000, m04_axi_arid}),
        .axi_araddr_i     (m04_axi_araddr[4:0]),
        .axi_arvalid_i    (m04_axi_arvalid),
        .axi_arready_o    (uart_arready_w),

        // Read data channel
        .axi_rid_o        (uart_rid_w),
        .axi_rdata_o      (uart_rdata_w),
        .axi_rresp_o      (uart_rresp_w),
        .axi_rvalid_o     (uart_rvalid_w),
        .axi_rready_i     (m04_axi_rready),

        // Write address channel
        .axi_awid_i       ({4'b0000, m04_axi_awid}),
        .axi_awaddr_i     (m04_axi_awaddr[4:0]),
        .axi_awvalid_i    (m04_axi_awvalid),
        .axi_awready_o    (uart_awready_w),

        // Write data channel
        .axi_wdata_i      (m04_axi_wdata),
        .axi_wstrb_i      (m04_axi_wstrb),
        .axi_wvalid_i     (m04_axi_wvalid),
        .axi_wready_o     (uart_wready_w),

        // Write response channel
        .axi_bid_o        (uart_bid_w),
        .axi_bresp_o      (uart_bresp_w),
        .axi_bvalid_o     (uart_bvalid_w),
        .axi_bready_i     (m04_axi_bready),

        // UART pins and interrupt
        .read_interrupt_o (uart_irq),
        .uart_rx_i        (uart_rx),
        .uart_tx_o        (uart_tx)
    );

    // ============================================================
    // S5: AES-128 Accelerator  (AXI4 → AXI4-Lite bridge + AES slave)
    // ============================================================
    aes_axi_slave_axi4 #(
        .DATA_WIDTH    (DATA_WIDTH),
        .ADDR_WIDTH    (ADDR_WIDTH),
        .STRB_WIDTH    (STRB_WIDTH),
        .ID_WIDTH      (ID_WIDTH),
        .AWUSER_WIDTH  (AWUSER_WIDTH),
        .WUSER_WIDTH   (WUSER_WIDTH),
        .BUSER_WIDTH   (BUSER_WIDTH),
        .ARUSER_WIDTH  (ARUSER_WIDTH),
        .RUSER_WIDTH   (RUSER_WIDTH),
        .AES_PERIPH_BASE (M05_BASE_ADDR)   // strip SoC base before AES slave decode
    ) u_aes_axi_slave_axi4 (
        .clk            (clk),
        .rst            (rst),

        // Write address channel
        .s_axi_awid     (m05_axi_awid),
        .s_axi_awaddr   (m05_axi_awaddr),
        .s_axi_awlen    (m05_axi_awlen),
        .s_axi_awsize   (m05_axi_awsize),
        .s_axi_awburst  (m05_axi_awburst),
        .s_axi_awlock   (m05_axi_awlock),
        .s_axi_awcache  (m05_axi_awcache),
        .s_axi_awprot   (m05_axi_awprot),
        .s_axi_awqos    (m05_axi_awqos),
        .s_axi_awregion (m05_axi_awregion),
        .s_axi_awuser   (m05_axi_awuser),
        .s_axi_awvalid  (m05_axi_awvalid),
        .s_axi_awready  (m05_axi_awready),

        // Write data channel
        .s_axi_wdata    (m05_axi_wdata),
        .s_axi_wstrb    (m05_axi_wstrb),
        .s_axi_wlast    (m05_axi_wlast),
        .s_axi_wuser    (m05_axi_wuser),
        .s_axi_wvalid   (m05_axi_wvalid),
        .s_axi_wready   (m05_axi_wready),

        // Write response channel
        .s_axi_bid      (m05_axi_bid),
        .s_axi_bresp    (m05_axi_bresp),
        .s_axi_buser    (m05_axi_buser),
        .s_axi_bvalid   (m05_axi_bvalid),
        .s_axi_bready   (m05_axi_bready),

        // Read address channel
        .s_axi_arid     (m05_axi_arid),
        .s_axi_araddr   (m05_axi_araddr),
        .s_axi_arlen    (m05_axi_arlen),
        .s_axi_arsize   (m05_axi_arsize),
        .s_axi_arburst  (m05_axi_arburst),
        .s_axi_arlock   (m05_axi_arlock),
        .s_axi_arcache  (m05_axi_arcache),
        .s_axi_arprot   (m05_axi_arprot),
        .s_axi_arqos    (m05_axi_arqos),
        .s_axi_arregion (m05_axi_arregion),
        .s_axi_aruser   (m05_axi_aruser),
        .s_axi_arvalid  (m05_axi_arvalid),
        .s_axi_arready  (m05_axi_arready),

        // Read data channel
        .s_axi_rid      (m05_axi_rid),
        .s_axi_rdata    (m05_axi_rdata),
        .s_axi_rresp    (m05_axi_rresp),
        .s_axi_rlast    (m05_axi_rlast),
        .s_axi_ruser    (m05_axi_ruser),
        .s_axi_rvalid   (m05_axi_rvalid),
        .s_axi_rready   (m05_axi_rready)
    );

    // ============================================================
    // S6: FFT Control — AXI4 → AXI4-Lite bridge
    // Strips SoC base 0x8000_8000, presents 16-bit local address
    // to fft_accel_top S_AXIL_* port.
    // ============================================================
    fft_ctrl_axi4_bridge #(
        .DATA_WIDTH    (DATA_WIDTH),
        .ADDR_WIDTH    (ADDR_WIDTH),
        .STRB_WIDTH    (STRB_WIDTH),
        .ID_WIDTH      (ID_WIDTH),
        .AWUSER_WIDTH  (AWUSER_WIDTH),
        .WUSER_WIDTH   (WUSER_WIDTH),
        .BUSER_WIDTH   (BUSER_WIDTH),
        .ARUSER_WIDTH  (ARUSER_WIDTH),
        .RUSER_WIDTH   (RUSER_WIDTH),
        .FFT_CTRL_BASE (M06_BASE_ADDR),   // 0x8000_8000
        .FFT_AXIL_AW   (FFT_AXIL_AW)     // 16
    ) u_fft_ctrl_bridge (
        .clk              (clk),
        .rst              (rst),

        // AXI4 slave port from interconnect m06
        .s_axi_awid       (m06_axi_awid),
        .s_axi_awaddr     (m06_axi_awaddr),
        .s_axi_awlen      (m06_axi_awlen),
        .s_axi_awsize     (m06_axi_awsize),
        .s_axi_awburst    (m06_axi_awburst),
        .s_axi_awlock     (m06_axi_awlock),
        .s_axi_awcache    (m06_axi_awcache),
        .s_axi_awprot     (m06_axi_awprot),
        .s_axi_awqos      (m06_axi_awqos),
        .s_axi_awregion   (m06_axi_awregion),
        .s_axi_awuser     (m06_axi_awuser),
        .s_axi_awvalid    (m06_axi_awvalid),
        .s_axi_awready    (m06_axi_awready),
        .s_axi_wdata      (m06_axi_wdata),
        .s_axi_wstrb      (m06_axi_wstrb),
        .s_axi_wlast      (m06_axi_wlast),
        .s_axi_wuser      (m06_axi_wuser),
        .s_axi_wvalid     (m06_axi_wvalid),
        .s_axi_wready     (m06_axi_wready),
        .s_axi_bid        (m06_axi_bid),
        .s_axi_bresp      (m06_axi_bresp),
        .s_axi_buser      (m06_axi_buser),
        .s_axi_bvalid     (m06_axi_bvalid),
        .s_axi_bready     (m06_axi_bready),
        .s_axi_arid       (m06_axi_arid),
        .s_axi_araddr     (m06_axi_araddr),
        .s_axi_arlen      (m06_axi_arlen),
        .s_axi_arsize     (m06_axi_arsize),
        .s_axi_arburst    (m06_axi_arburst),
        .s_axi_arlock     (m06_axi_arlock),
        .s_axi_arcache    (m06_axi_arcache),
        .s_axi_arprot     (m06_axi_arprot),
        .s_axi_arqos      (m06_axi_arqos),
        .s_axi_arregion   (m06_axi_arregion),
        .s_axi_aruser     (m06_axi_aruser),
        .s_axi_arvalid    (m06_axi_arvalid),
        .s_axi_arready    (m06_axi_arready),
        .s_axi_rid        (m06_axi_rid),
        .s_axi_rdata      (m06_axi_rdata),
        .s_axi_rresp      (m06_axi_rresp),
        .s_axi_rlast      (m06_axi_rlast),
        .s_axi_ruser      (m06_axi_ruser),
        .s_axi_rvalid     (m06_axi_rvalid),
        .s_axi_rready     (m06_axi_rready),

        // AXI4-Lite master port → fft_accel_top S_AXIL_*
        .m_axil_awaddr    (fft_axil_awaddr),
        .m_axil_awvalid   (fft_axil_awvalid),
        .m_axil_awready   (fft_axil_awready),
        .m_axil_wdata     (fft_axil_wdata),
        .m_axil_wstrb     (fft_axil_wstrb),
        .m_axil_wvalid    (fft_axil_wvalid),
        .m_axil_wready    (fft_axil_wready),
        .m_axil_bresp     (fft_axil_bresp),
        .m_axil_bvalid    (fft_axil_bvalid),
        .m_axil_bready    (fft_axil_bready),
        .m_axil_araddr    (fft_axil_araddr),
        .m_axil_arvalid   (fft_axil_arvalid),
        .m_axil_arready   (fft_axil_arready),
        .m_axil_rdata     (fft_axil_rdata),
        .m_axil_rresp     (fft_axil_rresp),
        .m_axil_rvalid    (fft_axil_rvalid),
        .m_axil_rready    (fft_axil_rready)
    );

    // ============================================================
    // S7: FFT Memory — AXI4 adapter (8-bit → 4-bit ID narrowing)
    // System address 0x8000_9000 - 0x8000_8000 = local 0x1000 = MEM_BASE
    // ============================================================
    fft_mem_axi4_wrap #(
        .DATA_WIDTH    (DATA_WIDTH),
        .ADDR_WIDTH    (ADDR_WIDTH),
        .STRB_WIDTH    (STRB_WIDTH),
        .ID_WIDTH      (ID_WIDTH),
        .FFT_ID_W      (FFT_ID_W),
        .FFT_ADDR_W    (FFT_ADDR_W),
        .AWUSER_WIDTH  (AWUSER_WIDTH),
        .WUSER_WIDTH   (WUSER_WIDTH),
        .BUSER_WIDTH   (BUSER_WIDTH),
        .ARUSER_WIDTH  (ARUSER_WIDTH),
        .RUSER_WIDTH   (RUSER_WIDTH),
        .FFT_MEM_BASE  (M06_BASE_ADDR)    // 0x8000_8000 (0x9000-0x8000=0x1000=MEM_BASE)
    ) u_fft_mem_wrap (
        .clk              (clk),
        .rst              (rst),

        // AXI4 slave port from interconnect m07
        .s_axi_awid       (m07_axi_awid),
        .s_axi_awaddr     (m07_axi_awaddr),
        .s_axi_awlen      (m07_axi_awlen),
        .s_axi_awsize     (m07_axi_awsize),
        .s_axi_awburst    (m07_axi_awburst),
        .s_axi_awlock     (m07_axi_awlock),
        .s_axi_awcache    (m07_axi_awcache),
        .s_axi_awprot     (m07_axi_awprot),
        .s_axi_awqos      (m07_axi_awqos),
        .s_axi_awregion   (m07_axi_awregion),
        .s_axi_awuser     (m07_axi_awuser),
        .s_axi_awvalid    (m07_axi_awvalid),
        .s_axi_awready    (m07_axi_awready),
        .s_axi_wdata      (m07_axi_wdata),
        .s_axi_wstrb      (m07_axi_wstrb),
        .s_axi_wlast      (m07_axi_wlast),
        .s_axi_wuser      (m07_axi_wuser),
        .s_axi_wvalid     (m07_axi_wvalid),
        .s_axi_wready     (m07_axi_wready),
        .s_axi_bid        (m07_axi_bid),
        .s_axi_bresp      (m07_axi_bresp),
        .s_axi_buser      (m07_axi_buser),
        .s_axi_bvalid     (m07_axi_bvalid),
        .s_axi_bready     (m07_axi_bready),
        .s_axi_arid       (m07_axi_arid),
        .s_axi_araddr     (m07_axi_araddr),
        .s_axi_arlen      (m07_axi_arlen),
        .s_axi_arsize     (m07_axi_arsize),
        .s_axi_arburst    (m07_axi_arburst),
        .s_axi_arlock     (m07_axi_arlock),
        .s_axi_arcache    (m07_axi_arcache),
        .s_axi_arprot     (m07_axi_arprot),
        .s_axi_arqos      (m07_axi_arqos),
        .s_axi_arregion   (m07_axi_arregion),
        .s_axi_aruser     (m07_axi_aruser),
        .s_axi_arvalid    (m07_axi_arvalid),
        .s_axi_arready    (m07_axi_arready),
        .s_axi_rid        (m07_axi_rid),
        .s_axi_rdata      (m07_axi_rdata),
        .s_axi_rresp      (m07_axi_rresp),
        .s_axi_rlast      (m07_axi_rlast),
        .s_axi_ruser      (m07_axi_ruser),
        .s_axi_rvalid     (m07_axi_rvalid),
        .s_axi_rready     (m07_axi_rready),

        // AXI4 master port → fft_accel_top S_AXI_*
        .m_axi_awid       (fft_mem_awid),
        .m_axi_awaddr     (fft_mem_awaddr),
        .m_axi_awlen      (fft_mem_awlen),
        .m_axi_awsize     (fft_mem_awsize),
        .m_axi_awburst    (fft_mem_awburst),
        .m_axi_awvalid    (fft_mem_awvalid),
        .m_axi_awready    (fft_mem_awready),
        .m_axi_wdata      (fft_mem_wdata),
        .m_axi_wstrb      (fft_mem_wstrb),
        .m_axi_wlast      (fft_mem_wlast),
        .m_axi_wvalid     (fft_mem_wvalid),
        .m_axi_wready     (fft_mem_wready),
        .m_axi_bid        (fft_mem_bid),
        .m_axi_bresp      (fft_mem_bresp),
        .m_axi_bvalid     (fft_mem_bvalid),
        .m_axi_bready     (fft_mem_bready),
        .m_axi_arid       (fft_mem_arid),
        .m_axi_araddr     (fft_mem_araddr),
        .m_axi_arlen      (fft_mem_arlen),
        .m_axi_arsize     (fft_mem_arsize),
        .m_axi_arburst    (fft_mem_arburst),
        .m_axi_arvalid    (fft_mem_arvalid),
        .m_axi_arready    (fft_mem_arready),
        .m_axi_rid        (fft_mem_rid),
        .m_axi_rdata      (fft_mem_rdata),
        .m_axi_rresp      (fft_mem_rresp),
        .m_axi_rlast      (fft_mem_rlast),
        .m_axi_rvalid     (fft_mem_rvalid),
        .m_axi_rready     (fft_mem_rready)
    );

    // ============================================================
    // FFT Accelerator Top
    // S6 AXI4-Lite control → S_AXIL_*
    // S7 AXI4 memory       → S_AXI_*
    // irq output           → fft_irq top-level port
    // ============================================================
    fft_accel_top #(
        .N           (1024),
        .AXI_ADDR_W  (FFT_AXIL_AW),  // 16
        .AXI_DATA_W  (DATA_WIDTH),    // 32
        .AXI_ID_W    (FFT_ID_W)       // 4
    ) u_fft_accel (
        .clk              (clk),
        .rst_n            (~rst),      // active-low reset

        .irq              (fft_irq),

        // AXI4-Lite control (from fft_ctrl_axi4_bridge)
        .S_AXIL_AWADDR    (fft_axil_awaddr),
        .S_AXIL_AWVALID   (fft_axil_awvalid),
        .S_AXIL_AWREADY   (fft_axil_awready),
        .S_AXIL_WDATA     (fft_axil_wdata),
        .S_AXIL_WSTRB     (fft_axil_wstrb),
        .S_AXIL_WVALID    (fft_axil_wvalid),
        .S_AXIL_WREADY    (fft_axil_wready),
        .S_AXIL_BRESP     (fft_axil_bresp),
        .S_AXIL_BVALID    (fft_axil_bvalid),
        .S_AXIL_BREADY    (fft_axil_bready),
        .S_AXIL_ARADDR    (fft_axil_araddr),
        .S_AXIL_ARVALID   (fft_axil_arvalid),
        .S_AXIL_ARREADY   (fft_axil_arready),
        .S_AXIL_RDATA     (fft_axil_rdata),
        .S_AXIL_RRESP     (fft_axil_rresp),
        .S_AXIL_RVALID    (fft_axil_rvalid),
        .S_AXIL_RREADY    (fft_axil_rready),

        // AXI4 memory (from fft_mem_axi4_wrap)
        .S_AXI_AWID       (fft_mem_awid),
        .S_AXI_AWADDR     (fft_mem_awaddr),
        .S_AXI_AWLEN      (fft_mem_awlen),
        .S_AXI_AWSIZE     (fft_mem_awsize),
        .S_AXI_AWBURST    (fft_mem_awburst),
        .S_AXI_AWVALID    (fft_mem_awvalid),
        .S_AXI_AWREADY    (fft_mem_awready),
        .S_AXI_WDATA      (fft_mem_wdata),
        .S_AXI_WSTRB      (fft_mem_wstrb),
        .S_AXI_WLAST      (fft_mem_wlast),
        .S_AXI_WVALID     (fft_mem_wvalid),
        .S_AXI_WREADY     (fft_mem_wready),
        .S_AXI_BID        (fft_mem_bid),
        .S_AXI_BRESP      (fft_mem_bresp),
        .S_AXI_BVALID     (fft_mem_bvalid),
        .S_AXI_BREADY     (fft_mem_bready),
        .S_AXI_ARID       (fft_mem_arid),
        .S_AXI_ARADDR     (fft_mem_araddr),
        .S_AXI_ARLEN      (fft_mem_arlen),
        .S_AXI_ARSIZE     (fft_mem_arsize),
        .S_AXI_ARBURST    (fft_mem_arburst),
        .S_AXI_ARVALID    (fft_mem_arvalid),
        .S_AXI_ARREADY    (fft_mem_arready),
        .S_AXI_RID        (fft_mem_rid),
        .S_AXI_RDATA      (fft_mem_rdata),
        .S_AXI_RRESP      (fft_mem_rresp),
        .S_AXI_RLAST      (fft_mem_rlast),
        .S_AXI_RVALID     (fft_mem_rvalid),
        .S_AXI_RREADY     (fft_mem_rready)
    );

    // ============================================================
    // S13 / M2: DMA Controller
    // CSR slave  = m13_axi_* (S13, 0x8000_6000, AXI4 from interconnect,
    //              mapped to AXI4-Lite CSR interface; AWLEN/ARBURST fields
    //              ignored by CSR — interconnect issues single-beat transfers)
    // AXI master = s02_axi_* (M2, full AXI4 with bursts)
    // ============================================================

    // AXI4-Lite CSR mosi/miso structs assembled from m13_axi_* wires
    // The interconnect drives full AXI4; we use only the AXI4-Lite
    // compatible subset (drop AWLEN, AWSIZE, AWBURST, ARLEN, etc.).
    // Single-beat register accesses from the CPU use AWLEN=0, ARBURST=INCR.

    s_axil_mosi_t  dma_csr_mosi;
    s_axil_miso_t  dma_csr_miso;

    // Build MOSI struct from interconnect m13 wires
    always_comb begin
        dma_csr_mosi.awid    = m13_axi_awid;
        dma_csr_mosi.awaddr  = m13_axi_awaddr;
        dma_csr_mosi.awprot  = axi_prot_t'(m13_axi_awprot);
        dma_csr_mosi.awvalid = m13_axi_awvalid;
        dma_csr_mosi.wdata   = m13_axi_wdata;
        dma_csr_mosi.wstrb   = m13_axi_wstrb;
        dma_csr_mosi.wvalid  = m13_axi_wvalid;
        dma_csr_mosi.bready  = m13_axi_bready;
        dma_csr_mosi.arid    = m13_axi_arid;
        dma_csr_mosi.araddr  = m13_axi_araddr;
        dma_csr_mosi.arprot  = axi_prot_t'(m13_axi_arprot);
        dma_csr_mosi.arvalid = m13_axi_arvalid;
        dma_csr_mosi.rready  = m13_axi_rready;
    end

    // Drive m13 response wires from MISO struct
    assign m13_axi_awready = dma_csr_miso.awready;
    assign m13_axi_wready  = dma_csr_miso.wready;
    assign m13_axi_bid     = dma_csr_miso.bid;
    assign m13_axi_bresp   = dma_csr_miso.bresp;
    assign m13_axi_buser   = {BUSER_WIDTH{1'b0}};
    assign m13_axi_bvalid  = dma_csr_miso.bvalid;
    assign m13_axi_arready = dma_csr_miso.arready;
    assign m13_axi_rid     = dma_csr_miso.rid;
    assign m13_axi_rdata   = dma_csr_miso.rdata;
    assign m13_axi_rresp   = dma_csr_miso.rresp;
    assign m13_axi_rlast   = dma_csr_miso.rvalid; // single-beat: rlast = rvalid
    assign m13_axi_ruser   = {RUSER_WIDTH{1'b0}};
    assign m13_axi_rvalid  = dma_csr_miso.rvalid;

    // DMA AXI master structs
    s_axi_mosi_t   dma_m_mosi;
    s_axi_miso_t   dma_m_miso;

    // Track if DMA transfer is active on M2
    reg dma_m2_active;
    always @(posedge clk or posedge rst) begin
        if (rst)
            dma_m2_active <= 1'b0;
        else if (dma_irq || dma_error_irq)
            dma_m2_active <= 1'b0;
        else if (dma_m_mosi.arvalid || dma_m_mosi.awvalid)
            dma_m2_active <= 1'b1;
    end

    wire dma_m2_sel = dma_m2_active || dma_m_mosi.arvalid || dma_m_mosi.awvalid || dma_m_mosi.wvalid;

    // Drive interconnect ic_s02 inputs from either internal DMA or external port
    assign ic_s02_axi_awid    = dma_m2_sel ? dma_m_mosi.awid    : s02_axi_awid;
    assign ic_s02_axi_awaddr  = dma_m2_sel ? dma_m_mosi.awaddr  : s02_axi_awaddr;
    assign ic_s02_axi_awlen   = dma_m2_sel ? dma_m_mosi.awlen   : s02_axi_awlen;
    assign ic_s02_axi_awsize  = dma_m2_sel ? dma_m_mosi.awsize  : s02_axi_awsize;
    assign ic_s02_axi_awburst = dma_m2_sel ? dma_m_mosi.awburst : s02_axi_awburst;
    assign ic_s02_axi_awlock  = dma_m2_sel ? dma_m_mosi.awlock  : s02_axi_awlock;
    assign ic_s02_axi_awcache = dma_m2_sel ? dma_m_mosi.awcache : s02_axi_awcache;
    assign ic_s02_axi_awprot  = dma_m2_sel ? dma_m_mosi.awprot  : s02_axi_awprot;
    assign ic_s02_axi_awqos   = dma_m2_sel ? dma_m_mosi.awqos   : s02_axi_awqos;
    assign ic_s02_axi_awuser  = dma_m2_sel ? dma_m_mosi.awuser  : s02_axi_awuser;
    assign ic_s02_axi_awvalid = dma_m2_sel ? dma_m_mosi.awvalid : s02_axi_awvalid;

    assign ic_s02_axi_wdata   = dma_m2_sel ? dma_m_mosi.wdata   : s02_axi_wdata;
    assign ic_s02_axi_wstrb   = dma_m2_sel ? dma_m_mosi.wstrb   : s02_axi_wstrb;
    assign ic_s02_axi_wlast   = dma_m2_sel ? dma_m_mosi.wlast   : s02_axi_wlast;
    assign ic_s02_axi_wuser   = dma_m2_sel ? dma_m_mosi.wuser   : s02_axi_wuser;
    assign ic_s02_axi_wvalid  = dma_m2_sel ? dma_m_mosi.wvalid  : s02_axi_wvalid;

    assign ic_s02_axi_bready  = dma_m2_sel ? dma_m_mosi.bready  : s02_axi_bready;

    assign ic_s02_axi_arid    = dma_m2_sel ? dma_m_mosi.arid    : s02_axi_arid;
    assign ic_s02_axi_araddr  = dma_m2_sel ? dma_m_mosi.araddr  : s02_axi_araddr;
    assign ic_s02_axi_arlen   = dma_m2_sel ? dma_m_mosi.arlen   : s02_axi_arlen;
    assign ic_s02_axi_arsize  = dma_m2_sel ? dma_m_mosi.arsize  : s02_axi_arsize;
    assign ic_s02_axi_arburst = dma_m2_sel ? dma_m_mosi.arburst : s02_axi_arburst;
    assign ic_s02_axi_arlock  = dma_m2_sel ? dma_m_mosi.arlock  : s02_axi_arlock;
    assign ic_s02_axi_arcache = dma_m2_sel ? dma_m_mosi.arcache : s02_axi_arcache;
    assign ic_s02_axi_arprot  = dma_m2_sel ? dma_m_mosi.arprot  : s02_axi_arprot;
    assign ic_s02_axi_arqos   = dma_m2_sel ? dma_m_mosi.arqos   : s02_axi_arqos;
    assign ic_s02_axi_aruser  = dma_m2_sel ? dma_m_mosi.aruser  : s02_axi_aruser;
    assign ic_s02_axi_arvalid = dma_m2_sel ? dma_m_mosi.arvalid : s02_axi_arvalid;

    assign ic_s02_axi_rready  = dma_m2_sel ? dma_m_mosi.rready  : s02_axi_rready;

    // Route interconnect ic_s02 responses to external s02_axi_* outputs
    assign s02_axi_awready = !dma_m2_sel ? ic_s02_axi_awready : 1'b0;
    assign s02_axi_wready  = !dma_m2_sel ? ic_s02_axi_wready  : 1'b0;
    assign s02_axi_bid     = ic_s02_axi_bid;
    assign s02_axi_bresp   = ic_s02_axi_bresp;
    assign s02_axi_buser   = ic_s02_axi_buser;
    assign s02_axi_bvalid  = !dma_m2_sel ? ic_s02_axi_bvalid  : 1'b0;
    assign s02_axi_arready = !dma_m2_sel ? ic_s02_axi_arready : 1'b0;
    assign s02_axi_rid     = ic_s02_axi_rid;
    assign s02_axi_rdata   = ic_s02_axi_rdata;
    assign s02_axi_rresp   = ic_s02_axi_rresp;
    assign s02_axi_rlast   = ic_s02_axi_rlast;
    assign s02_axi_ruser   = ic_s02_axi_ruser;
    assign s02_axi_rvalid  = !dma_m2_sel ? ic_s02_axi_rvalid  : 1'b0;

    // Route interconnect ic_s02 responses to internal DMA master MISO struct
    always_comb begin
        dma_m_miso.awready = dma_m2_sel ? ic_s02_axi_awready : 1'b0;
        dma_m_miso.wready  = dma_m2_sel ? ic_s02_axi_wready  : 1'b0;
        dma_m_miso.bid     = ic_s02_axi_bid;
        dma_m_miso.bresp   = axi_resp_t'(ic_s02_axi_bresp);
        dma_m_miso.buser   = ic_s02_axi_buser;
        dma_m_miso.bvalid  = dma_m2_sel ? ic_s02_axi_bvalid  : 1'b0;
        dma_m_miso.arready = dma_m2_sel ? ic_s02_axi_arready : 1'b0;
        dma_m_miso.rid     = ic_s02_axi_rid;
        dma_m_miso.rdata   = ic_s02_axi_rdata;
        dma_m_miso.rresp   = axi_resp_t'(ic_s02_axi_rresp);
        dma_m_miso.rlast   = ic_s02_axi_rlast;
        dma_m_miso.ruser   = ic_s02_axi_ruser;
        dma_m_miso.rvalid  = dma_m2_sel ? ic_s02_axi_rvalid  : 1'b0;
    end

    dma_axi_wrapper #(
        .DMA_ID_VAL  (2)    // Master ID 2 = DMA Controller (M2)
    ) u_dma (
        .clk            (clk),
        .rst            (rst),
        // CSR slave — AXI4-Lite from interconnect S13 (0x8000_6000)
        .dma_csr_mosi_i (dma_csr_mosi),
        .dma_csr_miso_o (dma_csr_miso),
        // AXI master — full AXI4 to interconnect M2
        .dma_m_mosi_o   (dma_m_mosi),
        .dma_m_miso_i   (dma_m_miso),
        // Completion and error IRQs
        .dma_done_o     (dma_irq),
        .dma_error_o    (dma_error_irq)
    );

    // ============================================================
    // RISC-V VeeR EL2 Processor Instance
    // Integrates 64-bit Core with 64-to-32 AXI Adapters for M0 & M1
    // ============================================================
    veer_wrapper_axi32 #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .STRB_WIDTH (STRB_WIDTH),
        .ID_WIDTH   (ID_WIDTH)
    ) u_veer_top (
        .clk                     (clk),
        .rst_l                   (cpu_rst_l & ~rst),
        .rst_vec                 (cpu_rst_vec),

        // SoC Interrupts to VeeR PIC
        .uart_irq                (uart_irq),
        .gpio_irq                (gpio_irq),
        .timer_irq               (timer_irq),
        .fft_irq                 (fft_irq),
        .dma_irq                 (dma_irq),
        .dma_error_irq           (dma_error_irq),

        .mpc_reset_run_req       (cpu_run_req),

        // Trace and Debug Ports
        .trace_rv_i_insn_ip      (trace_rv_i_insn_ip),
        .trace_rv_i_address_ip   (trace_rv_i_address_ip),
        .trace_rv_i_valid_ip     (trace_rv_i_valid_ip),
        .trace_rv_i_exception_ip (trace_rv_i_exception_ip),
        .trace_rv_i_ecause_ip    (trace_rv_i_ecause_ip),
        .trace_rv_i_interrupt_ip (trace_rv_i_interrupt_ip),
        .trace_rv_i_tval_ip      (trace_rv_i_tval_ip),
        .o_cpu_halt_status       (o_cpu_halt_status),

        // M0 32-bit AXI Master (IFU)
        .m0_axi_awid             (veer_m0_axi_awid),
        .m0_axi_awaddr           (veer_m0_axi_awaddr),
        .m0_axi_awlen            (veer_m0_axi_awlen),
        .m0_axi_awsize           (veer_m0_axi_awsize),
        .m0_axi_awburst          (veer_m0_axi_awburst),
        .m0_axi_awlock           (veer_m0_axi_awlock),
        .m0_axi_awcache          (veer_m0_axi_awcache),
        .m0_axi_awprot           (veer_m0_axi_awprot),
        .m0_axi_awqos            (veer_m0_axi_awqos),
        .m0_axi_awregion         (veer_m0_axi_awregion),
        .m0_axi_awvalid          (veer_m0_axi_awvalid),
        .m0_axi_awready          (veer_m0_axi_awready),
        .m0_axi_wdata            (veer_m0_axi_wdata),
        .m0_axi_wstrb            (veer_m0_axi_wstrb),
        .m0_axi_wlast            (veer_m0_axi_wlast),
        .m0_axi_wvalid           (veer_m0_axi_wvalid),
        .m0_axi_wready           (veer_m0_axi_wready),
        .m0_axi_bid              (veer_m0_axi_bid),
        .m0_axi_bresp            (veer_m0_axi_bresp),
        .m0_axi_bvalid           (veer_m0_axi_bvalid),
        .m0_axi_bready           (veer_m0_axi_bready),
        .m0_axi_arid             (veer_m0_axi_arid),
        .m0_axi_araddr           (veer_m0_axi_araddr),
        .m0_axi_arlen            (veer_m0_axi_arlen),
        .m0_axi_arsize           (veer_m0_axi_arsize),
        .m0_axi_arburst          (veer_m0_axi_arburst),
        .m0_axi_arlock           (veer_m0_axi_arlock),
        .m0_axi_arcache          (veer_m0_axi_arcache),
        .m0_axi_arprot           (veer_m0_axi_arprot),
        .m0_axi_arqos            (veer_m0_axi_arqos),
        .m0_axi_arregion         (veer_m0_axi_arregion),
        .m0_axi_arvalid          (veer_m0_axi_arvalid),
        .m0_axi_arready          (veer_m0_axi_arready),
        .m0_axi_rid              (veer_m0_axi_rid),
        .m0_axi_rdata            (veer_m0_axi_rdata),
        .m0_axi_rresp            (veer_m0_axi_rresp),
        .m0_axi_rlast            (veer_m0_axi_rlast),
        .m0_axi_rvalid           (veer_m0_axi_rvalid),
        .m0_axi_rready           (veer_m0_axi_rready),

        // M1 32-bit AXI Master (LSU)
        .m1_axi_awid             (veer_m1_axi_awid),
        .m1_axi_awaddr           (veer_m1_axi_awaddr),
        .m1_axi_awlen            (veer_m1_axi_awlen),
        .m1_axi_awsize           (veer_m1_axi_awsize),
        .m1_axi_awburst          (veer_m1_axi_awburst),
        .m1_axi_awlock           (veer_m1_axi_awlock),
        .m1_axi_awcache          (veer_m1_axi_awcache),
        .m1_axi_awprot           (veer_m1_axi_awprot),
        .m1_axi_awqos            (veer_m1_axi_awqos),
        .m1_axi_awregion         (veer_m1_axi_awregion),
        .m1_axi_awvalid          (veer_m1_axi_awvalid),
        .m1_axi_awready          (veer_m1_axi_awready),
        .m1_axi_wdata            (veer_m1_axi_wdata),
        .m1_axi_wstrb            (veer_m1_axi_wstrb),
        .m1_axi_wlast            (veer_m1_axi_wlast),
        .m1_axi_wvalid           (veer_m1_axi_wvalid),
        .m1_axi_wready           (veer_m1_axi_wready),
        .m1_axi_bid              (veer_m1_axi_bid),
        .m1_axi_bresp            (veer_m1_axi_bresp),
        .m1_axi_bvalid           (veer_m1_axi_bvalid),
        .m1_axi_bready           (veer_m1_axi_bready),
        .m1_axi_arid             (veer_m1_axi_arid),
        .m1_axi_araddr           (veer_m1_axi_araddr),
        .m1_axi_arlen            (veer_m1_axi_arlen),
        .m1_axi_arsize           (veer_m1_axi_arsize),
        .m1_axi_arburst          (veer_m1_axi_arburst),
        .m1_axi_arlock           (veer_m1_axi_arlock),
        .m1_axi_arcache          (veer_m1_axi_arcache),
        .m1_axi_arprot           (veer_m1_axi_arprot),
        .m1_axi_arqos            (veer_m1_axi_arqos),
        .m1_axi_arregion         (veer_m1_axi_arregion),
        .m1_axi_arvalid          (veer_m1_axi_arvalid),
        .m1_axi_arready          (veer_m1_axi_arready),
        .m1_axi_rid              (veer_m1_axi_rid),
        .m1_axi_rdata            (veer_m1_axi_rdata),
        .m1_axi_rresp            (veer_m1_axi_rresp),
        .m1_axi_rlast            (veer_m1_axi_rlast),
        .m1_axi_rvalid           (veer_m1_axi_rvalid),
        .m1_axi_rready           (veer_m1_axi_rready)
    );

    // ============================================================
    // Master M0 (IFU) Multiplexing Logic
    // Glitch-free, drain-safe handover between external BFM and VeeR IFU.
    // Switching is only permitted when the M0 interconnect port is completely idle.
    // ============================================================
    reg [7:0] m0_inflight_wr;
    reg [7:0] m0_inflight_rd;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            m0_inflight_wr <= 8'd0;
            m0_inflight_rd <= 8'd0;
        end else begin
            if ((ic_s00_axi_awvalid && ic_s00_axi_awready) && !(ic_s00_axi_bvalid && ic_s00_axi_bready))
                m0_inflight_wr <= m0_inflight_wr + 8'd1;
            else if (!(ic_s00_axi_awvalid && ic_s00_axi_awready) && (ic_s00_axi_bvalid && ic_s00_axi_bready))
                m0_inflight_wr <= m0_inflight_wr - 8'd1;

            if ((ic_s00_axi_arvalid && ic_s00_axi_arready) && !(ic_s00_axi_rvalid && ic_s00_axi_rready && ic_s00_axi_rlast))
                m0_inflight_rd <= m0_inflight_rd + 8'd1;
            else if (!(ic_s00_axi_arvalid && ic_s00_axi_arready) && (ic_s00_axi_rvalid && ic_s00_axi_rready && ic_s00_axi_rlast))
                m0_inflight_rd <= m0_inflight_rd - 8'd1;
        end
    end
    wire m0_bus_idle = (m0_inflight_wr == 8'd0) && (m0_inflight_rd == 8'd0) && 
                       !ic_s00_axi_awvalid && !ic_s00_axi_arvalid && !ic_s00_axi_wvalid;

    reg cpu_m0_sel_q;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cpu_m0_sel_q <= 1'b0;
        end else if (m0_bus_idle) begin
            cpu_m0_sel_q <= cpu_rst_l;
        end
    end
    wire cpu_m0_sel = cpu_m0_sel_q;

    assign ic_s00_axi_awid    = cpu_m0_sel ? veer_m0_axi_awid    : s00_axi_awid;
    assign ic_s00_axi_awaddr  = cpu_m0_sel ? veer_m0_axi_awaddr  : s00_axi_awaddr;
    assign ic_s00_axi_awlen   = cpu_m0_sel ? veer_m0_axi_awlen   : s00_axi_awlen;
    assign ic_s00_axi_awsize  = cpu_m0_sel ? veer_m0_axi_awsize  : s00_axi_awsize;
    assign ic_s00_axi_awburst = cpu_m0_sel ? veer_m0_axi_awburst : s00_axi_awburst;
    assign ic_s00_axi_awlock  = cpu_m0_sel ? veer_m0_axi_awlock  : s00_axi_awlock;
    assign ic_s00_axi_awcache = cpu_m0_sel ? veer_m0_axi_awcache : s00_axi_awcache;
    assign ic_s00_axi_awprot  = cpu_m0_sel ? veer_m0_axi_awprot  : s00_axi_awprot;
    assign ic_s00_axi_awqos   = cpu_m0_sel ? veer_m0_axi_awqos   : s00_axi_awqos;
    assign ic_s00_axi_awuser  = cpu_m0_sel ? '0                  : s00_axi_awuser;
    assign ic_s00_axi_awvalid = cpu_m0_sel ? veer_m0_axi_awvalid : s00_axi_awvalid;

    assign ic_s00_axi_wdata   = cpu_m0_sel ? veer_m0_axi_wdata   : s00_axi_wdata;
    assign ic_s00_axi_wstrb   = cpu_m0_sel ? veer_m0_axi_wstrb   : s00_axi_wstrb;
    assign ic_s00_axi_wlast   = cpu_m0_sel ? veer_m0_axi_wlast   : s00_axi_wlast;
    assign ic_s00_axi_wuser   = cpu_m0_sel ? '0                  : s00_axi_wuser;
    assign ic_s00_axi_wvalid  = cpu_m0_sel ? veer_m0_axi_wvalid  : s00_axi_wvalid;

    assign ic_s00_axi_bready  = cpu_m0_sel ? veer_m0_axi_bready  : s00_axi_bready;

    assign ic_s00_axi_arid    = cpu_m0_sel ? veer_m0_axi_arid    : s00_axi_arid;
    assign ic_s00_axi_araddr  = cpu_m0_sel ? veer_m0_axi_araddr  : s00_axi_araddr;
    assign ic_s00_axi_arlen   = cpu_m0_sel ? veer_m0_axi_arlen   : s00_axi_arlen;
    assign ic_s00_axi_arsize  = cpu_m0_sel ? veer_m0_axi_arsize  : s00_axi_arsize;
    assign ic_s00_axi_arburst = cpu_m0_sel ? veer_m0_axi_arburst : s00_axi_arburst;
    assign ic_s00_axi_arlock  = cpu_m0_sel ? veer_m0_axi_arlock  : s00_axi_arlock;
    assign ic_s00_axi_arcache = cpu_m0_sel ? veer_m0_axi_arcache : s00_axi_arcache;
    assign ic_s00_axi_arprot  = cpu_m0_sel ? veer_m0_axi_arprot  : s00_axi_arprot;
    assign ic_s00_axi_arqos   = cpu_m0_sel ? veer_m0_axi_arqos   : s00_axi_arqos;
    assign ic_s00_axi_aruser  = cpu_m0_sel ? '0                  : s00_axi_aruser;
    assign ic_s00_axi_arvalid = cpu_m0_sel ? veer_m0_axi_arvalid : s00_axi_arvalid;

    assign ic_s00_axi_rready  = cpu_m0_sel ? veer_m0_axi_rready  : s00_axi_rready;

    // Responses back to M0 master
    assign s00_axi_awready     = !cpu_m0_sel ? ic_s00_axi_awready : 1'b0;
    assign s00_axi_wready      = !cpu_m0_sel ? ic_s00_axi_wready  : 1'b0;
    assign s00_axi_bid         = ic_s00_axi_bid;
    assign s00_axi_bresp       = ic_s00_axi_bresp;
    assign s00_axi_buser       = ic_s00_axi_buser;
    assign s00_axi_bvalid      = !cpu_m0_sel ? ic_s00_axi_bvalid  : 1'b0;
    assign s00_axi_arready     = !cpu_m0_sel ? ic_s00_axi_arready : 1'b0;
    assign s00_axi_rid         = ic_s00_axi_rid;
    assign s00_axi_rdata       = ic_s00_axi_rdata;
    assign s00_axi_rresp       = ic_s00_axi_rresp;
    assign s00_axi_rlast       = ic_s00_axi_rlast;
    assign s00_axi_ruser       = ic_s00_axi_ruser;
    assign s00_axi_rvalid      = !cpu_m0_sel ? ic_s00_axi_rvalid  : 1'b0;

    assign veer_m0_axi_awready = cpu_m0_sel ? ic_s00_axi_awready : 1'b0;
    assign veer_m0_axi_wready  = cpu_m0_sel ? ic_s00_axi_wready  : 1'b0;
    assign veer_m0_axi_bid     = ic_s00_axi_bid;
    assign veer_m0_axi_bresp   = ic_s00_axi_bresp;
    assign veer_m0_axi_bvalid  = cpu_m0_sel ? ic_s00_axi_bvalid  : 1'b0;
    assign veer_m0_axi_arready = cpu_m0_sel ? ic_s00_axi_arready : 1'b0;
    assign veer_m0_axi_rid     = ic_s00_axi_rid;
    assign veer_m0_axi_rdata   = ic_s00_axi_rdata;
    assign veer_m0_axi_rresp   = ic_s00_axi_rresp;
    assign veer_m0_axi_rlast   = ic_s00_axi_rlast;
    assign veer_m0_axi_rvalid  = cpu_m0_sel ? ic_s00_axi_rvalid  : 1'b0;

    // ============================================================
    // Master M1 (LSU) Multiplexing Logic
    // Glitch-free, drain-safe handover between external BFM and VeeR LSU.
    // Switching is only permitted when the M1 interconnect port is completely idle.
    // ============================================================
    reg [7:0] m1_inflight_wr;
    reg [7:0] m1_inflight_rd;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            m1_inflight_wr <= 8'd0;
            m1_inflight_rd <= 8'd0;
        end else begin
            if ((ic_s01_axi_awvalid && ic_s01_axi_awready) && !(ic_s01_axi_bvalid && ic_s01_axi_bready))
                m1_inflight_wr <= m1_inflight_wr + 8'd1;
            else if (!(ic_s01_axi_awvalid && ic_s01_axi_awready) && (ic_s01_axi_bvalid && ic_s01_axi_bready))
                m1_inflight_wr <= m1_inflight_wr - 8'd1;

            if ((ic_s01_axi_arvalid && ic_s01_axi_arready) && !(ic_s01_axi_rvalid && ic_s01_axi_rready && ic_s01_axi_rlast))
                m1_inflight_rd <= m1_inflight_rd + 8'd1;
            else if (!(ic_s01_axi_arvalid && ic_s01_axi_arready) && (ic_s01_axi_rvalid && ic_s01_axi_rready && ic_s01_axi_rlast))
                m1_inflight_rd <= m1_inflight_rd - 8'd1;
        end
    end
    wire m1_bus_idle = (m1_inflight_wr == 8'd0) && (m1_inflight_rd == 8'd0) && 
                       !ic_s01_axi_awvalid && !ic_s01_axi_arvalid && !ic_s01_axi_wvalid;

    reg cpu_m1_sel_q;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cpu_m1_sel_q <= 1'b0;
        end else if (m1_bus_idle) begin
            cpu_m1_sel_q <= cpu_rst_l;
        end
    end
    wire cpu_m1_sel = cpu_m1_sel_q;

    assign ic_s01_axi_awid    = cpu_m1_sel ? veer_m1_axi_awid    : s01_axi_awid;
    assign ic_s01_axi_awaddr  = cpu_m1_sel ? veer_m1_axi_awaddr  : s01_axi_awaddr;
    assign ic_s01_axi_awlen   = cpu_m1_sel ? veer_m1_axi_awlen   : s01_axi_awlen;
    assign ic_s01_axi_awsize  = cpu_m1_sel ? veer_m1_axi_awsize  : s01_axi_awsize;
    assign ic_s01_axi_awburst = cpu_m1_sel ? veer_m1_axi_awburst : s01_axi_awburst;
    assign ic_s01_axi_awlock  = cpu_m1_sel ? veer_m1_axi_awlock  : s01_axi_awlock;
    assign ic_s01_axi_awcache = cpu_m1_sel ? veer_m1_axi_awcache : s01_axi_awcache;
    assign ic_s01_axi_awprot  = cpu_m1_sel ? veer_m1_axi_awprot  : s01_axi_awprot;
    assign ic_s01_axi_awqos   = cpu_m1_sel ? veer_m1_axi_awqos   : s01_axi_awqos;
    assign ic_s01_axi_awuser  = cpu_m1_sel ? '0                  : s01_axi_awuser;
    assign ic_s01_axi_awvalid = cpu_m1_sel ? veer_m1_axi_awvalid : s01_axi_awvalid;

    assign ic_s01_axi_wdata   = cpu_m1_sel ? veer_m1_axi_wdata   : s01_axi_wdata;
    assign ic_s01_axi_wstrb   = cpu_m1_sel ? veer_m1_axi_wstrb   : s01_axi_wstrb;
    assign ic_s01_axi_wlast   = cpu_m1_sel ? veer_m1_axi_wlast   : s01_axi_wlast;
    assign ic_s01_axi_wuser   = cpu_m1_sel ? '0                  : s01_axi_wuser;
    assign ic_s01_axi_wvalid  = cpu_m1_sel ? veer_m1_axi_wvalid  : s01_axi_wvalid;

    assign ic_s01_axi_bready  = cpu_m1_sel ? veer_m1_axi_bready  : s01_axi_bready;

    assign ic_s01_axi_arid    = cpu_m1_sel ? veer_m1_axi_arid    : s01_axi_arid;
    assign ic_s01_axi_araddr  = cpu_m1_sel ? veer_m1_axi_araddr  : s01_axi_araddr;
    assign ic_s01_axi_arlen   = cpu_m1_sel ? veer_m1_axi_arlen   : s01_axi_arlen;
    assign ic_s01_axi_arsize  = cpu_m1_sel ? veer_m1_axi_arsize  : s01_axi_arsize;
    assign ic_s01_axi_arburst = cpu_m1_sel ? veer_m1_axi_arburst : s01_axi_arburst;
    assign ic_s01_axi_arlock  = cpu_m1_sel ? veer_m1_axi_arlock  : s01_axi_arlock;
    assign ic_s01_axi_arcache = cpu_m1_sel ? veer_m1_axi_arcache : s01_axi_arcache;
    assign ic_s01_axi_arprot  = cpu_m1_sel ? veer_m1_axi_arprot  : s01_axi_arprot;
    assign ic_s01_axi_arqos   = cpu_m1_sel ? veer_m1_axi_arqos   : s01_axi_arqos;
    assign ic_s01_axi_aruser  = cpu_m1_sel ? '0                  : s01_axi_aruser;
    assign ic_s01_axi_arvalid = cpu_m1_sel ? veer_m1_axi_arvalid : s01_axi_arvalid;

    assign ic_s01_axi_rready  = cpu_m1_sel ? veer_m1_axi_rready  : s01_axi_rready;

    // Responses back to M1 master
    assign s01_axi_awready     = !cpu_m1_sel ? ic_s01_axi_awready : 1'b0;
    assign s01_axi_wready      = !cpu_m1_sel ? ic_s01_axi_wready  : 1'b0;
    assign s01_axi_bid         = ic_s01_axi_bid;
    assign s01_axi_bresp       = ic_s01_axi_bresp;
    assign s01_axi_buser       = ic_s01_axi_buser;
    assign s01_axi_bvalid      = !cpu_m1_sel ? ic_s01_axi_bvalid  : 1'b0;
    assign s01_axi_arready     = !cpu_m1_sel ? ic_s01_axi_arready : 1'b0;
    assign s01_axi_rid         = ic_s01_axi_rid;
    assign s01_axi_rdata       = ic_s01_axi_rdata;
    assign s01_axi_rresp       = ic_s01_axi_rresp;
    assign s01_axi_rlast       = ic_s01_axi_rlast;
    assign s01_axi_ruser       = ic_s01_axi_ruser;
    assign s01_axi_rvalid      = !cpu_m1_sel ? ic_s01_axi_rvalid  : 1'b0;

    assign veer_m1_axi_awready = cpu_m1_sel ? ic_s01_axi_awready : 1'b0;
    assign veer_m1_axi_wready  = cpu_m1_sel ? ic_s01_axi_wready  : 1'b0;
    assign veer_m1_axi_bid     = ic_s01_axi_bid;
    assign veer_m1_axi_bresp   = ic_s01_axi_bresp;
    assign veer_m1_axi_bvalid  = cpu_m1_sel ? ic_s01_axi_bvalid  : 1'b0;
    assign veer_m1_axi_arready = cpu_m1_sel ? ic_s01_axi_arready : 1'b0;
    assign veer_m1_axi_rid     = ic_s01_axi_rid;
    assign veer_m1_axi_rdata   = ic_s01_axi_rdata;
    assign veer_m1_axi_rresp   = ic_s01_axi_rresp;
    assign veer_m1_axi_rlast   = ic_s01_axi_rlast;
    assign veer_m1_axi_rvalid  = cpu_m1_sel ? ic_s01_axi_rvalid  : 1'b0;

endmodule

`default_nettype wire
