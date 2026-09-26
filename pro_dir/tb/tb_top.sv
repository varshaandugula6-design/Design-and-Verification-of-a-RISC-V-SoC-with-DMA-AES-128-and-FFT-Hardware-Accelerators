// =============================================================================
// File        : tb_top.sv
// Description : Top-level testbench for axi_interconnect_wrap_3x7
//
// DUT verified from RTL:
//   Module  : axi_interconnect_wrap_3x7
//   DATA    : 32 bits
//   ADDR    : 32 bits
//   ID      : 8 bits
//   STRB    : 4 bits
//   Clock   : clk (posedge)
//   Reset   : rst (active HIGH, synchronous release)
//   Masters : s00_axi, s01_axi, s02_axi
//   Slaves  : m00_axi … m06_axi
//
// Address map (from DUT defaults M_ADDR_WIDTH=24, M_BASE_ADDR=0):
//   m00: 0x00000000 – 0x00FFFFFF   m01: 0x01000000 – 0x01FFFFFF
//   m02: 0x02000000 – 0x02FFFFFF   m03: 0x03000000 – 0x03FFFFFF
//   m04: 0x04000000 – 0x04FFFFFF   m05: 0x05000000 – 0x05FFFFFF
//   m06: 0x06000000 – 0x06FFFFFF
//   Unmapped: 0x07000000 and above
//
// Dependencies (no Xilinx IP required — all Alex Forencich open-source):
//   rtl/interconnect/axi_interconnect.v
//   rtl/interconnect/arbiter.v
//   rtl/interconnect/priority_encoder.v
//   scripts/axi_interconnect_wrap_3x7.v
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module tb_top;

// =============================================================================
// Parameters — match DUT defaults exactly
// =============================================================================
localparam DATA_WIDTH   = 32;
localparam ADDR_WIDTH   = 32;
localparam STRB_WIDTH   = DATA_WIDTH/8;   // 4
localparam ID_WIDTH     = 8;
localparam AWUSER_WIDTH = 1;
localparam WUSER_WIDTH  = 1;
localparam BUSER_WIDTH  = 1;
localparam ARUSER_WIDTH = 1;
localparam RUSER_WIDTH  = 1;

// Address map constants
localparam [ADDR_WIDTH-1:0] BASE_M [0:6] = '{
    32'h0000_0000, 32'h0100_0000, 32'h0200_0000,
    32'h0300_0000, 32'h0400_0000, 32'h0500_0000, 32'h0600_0000
};

localparam TIMEOUT_CYC = 10000;

// =============================================================================
// Clock and reset
// =============================================================================
logic clk;
logic rst;

initial clk = 1'b0;
always #5 clk = ~clk;   // 100 MHz

// =============================================================================
// DUT signal declarations
// =============================================================================

// ---------- s00_axi (Master 0) ----------
logic [ID_WIDTH-1:0]     s00_axi_awid;
logic [ADDR_WIDTH-1:0]   s00_axi_awaddr;
logic [7:0]              s00_axi_awlen;
logic [2:0]              s00_axi_awsize;
logic [1:0]              s00_axi_awburst;
logic                    s00_axi_awlock;
logic [3:0]              s00_axi_awcache;
logic [2:0]              s00_axi_awprot;
logic [3:0]              s00_axi_awqos;
logic [AWUSER_WIDTH-1:0] s00_axi_awuser;
logic                    s00_axi_awvalid;
wire                     s00_axi_awready;
logic [DATA_WIDTH-1:0]   s00_axi_wdata;
logic [STRB_WIDTH-1:0]   s00_axi_wstrb;
logic                    s00_axi_wlast;
logic [WUSER_WIDTH-1:0]  s00_axi_wuser;
logic                    s00_axi_wvalid;
wire                     s00_axi_wready;
wire  [ID_WIDTH-1:0]     s00_axi_bid;
wire  [1:0]              s00_axi_bresp;
wire  [BUSER_WIDTH-1:0]  s00_axi_buser;
wire                     s00_axi_bvalid;
logic                    s00_axi_bready;
logic [ID_WIDTH-1:0]     s00_axi_arid;
logic [ADDR_WIDTH-1:0]   s00_axi_araddr;
logic [7:0]              s00_axi_arlen;
logic [2:0]              s00_axi_arsize;
logic [1:0]              s00_axi_arburst;
logic                    s00_axi_arlock;
logic [3:0]              s00_axi_arcache;
logic [2:0]              s00_axi_arprot;
logic [3:0]              s00_axi_arqos;
logic [ARUSER_WIDTH-1:0] s00_axi_aruser;
logic                    s00_axi_arvalid;
wire                     s00_axi_arready;
wire  [ID_WIDTH-1:0]     s00_axi_rid;
wire  [DATA_WIDTH-1:0]   s00_axi_rdata;
wire  [1:0]              s00_axi_rresp;
wire                     s00_axi_rlast;
wire  [RUSER_WIDTH-1:0]  s00_axi_ruser;
wire                     s00_axi_rvalid;
logic                    s00_axi_rready;

// ---------- s01_axi (Master 1) ----------
logic [ID_WIDTH-1:0]     s01_axi_awid;
logic [ADDR_WIDTH-1:0]   s01_axi_awaddr;
logic [7:0]              s01_axi_awlen;
logic [2:0]              s01_axi_awsize;
logic [1:0]              s01_axi_awburst;
logic                    s01_axi_awlock;
logic [3:0]              s01_axi_awcache;
logic [2:0]              s01_axi_awprot;
logic [3:0]              s01_axi_awqos;
logic [AWUSER_WIDTH-1:0] s01_axi_awuser;
logic                    s01_axi_awvalid;
wire                     s01_axi_awready;
logic [DATA_WIDTH-1:0]   s01_axi_wdata;
logic [STRB_WIDTH-1:0]   s01_axi_wstrb;
logic                    s01_axi_wlast;
logic [WUSER_WIDTH-1:0]  s01_axi_wuser;
logic                    s01_axi_wvalid;
wire                     s01_axi_wready;
wire  [ID_WIDTH-1:0]     s01_axi_bid;
wire  [1:0]              s01_axi_bresp;
wire  [BUSER_WIDTH-1:0]  s01_axi_buser;
wire                     s01_axi_bvalid;
logic                    s01_axi_bready;
logic [ID_WIDTH-1:0]     s01_axi_arid;
logic [ADDR_WIDTH-1:0]   s01_axi_araddr;
logic [7:0]              s01_axi_arlen;
logic [2:0]              s01_axi_arsize;
logic [1:0]              s01_axi_arburst;
logic                    s01_axi_arlock;
logic [3:0]              s01_axi_arcache;
logic [2:0]              s01_axi_arprot;
logic [3:0]              s01_axi_arqos;
logic [ARUSER_WIDTH-1:0] s01_axi_aruser;
logic                    s01_axi_arvalid;
wire                     s01_axi_arready;
wire  [ID_WIDTH-1:0]     s01_axi_rid;
wire  [DATA_WIDTH-1:0]   s01_axi_rdata;
wire  [1:0]              s01_axi_rresp;
wire                     s01_axi_rlast;
wire  [RUSER_WIDTH-1:0]  s01_axi_ruser;
wire                     s01_axi_rvalid;
logic                    s01_axi_rready;

// ---------- s02_axi (Master 2) ----------
logic [ID_WIDTH-1:0]     s02_axi_awid;
logic [ADDR_WIDTH-1:0]   s02_axi_awaddr;
logic [7:0]              s02_axi_awlen;
logic [2:0]              s02_axi_awsize;
logic [1:0]              s02_axi_awburst;
logic                    s02_axi_awlock;
logic [3:0]              s02_axi_awcache;
logic [2:0]              s02_axi_awprot;
logic [3:0]              s02_axi_awqos;
logic [AWUSER_WIDTH-1:0] s02_axi_awuser;
logic                    s02_axi_awvalid;
wire                     s02_axi_awready;
logic [DATA_WIDTH-1:0]   s02_axi_wdata;
logic [STRB_WIDTH-1:0]   s02_axi_wstrb;
logic                    s02_axi_wlast;
logic [WUSER_WIDTH-1:0]  s02_axi_wuser;
logic                    s02_axi_wvalid;
wire                     s02_axi_wready;
wire  [ID_WIDTH-1:0]     s02_axi_bid;
wire  [1:0]              s02_axi_bresp;
wire  [BUSER_WIDTH-1:0]  s02_axi_buser;
wire                     s02_axi_bvalid;
logic                    s02_axi_bready;
logic [ID_WIDTH-1:0]     s02_axi_arid;
logic [ADDR_WIDTH-1:0]   s02_axi_araddr;
logic [7:0]              s02_axi_arlen;
logic [2:0]              s02_axi_arsize;
logic [1:0]              s02_axi_arburst;
logic                    s02_axi_arlock;
logic [3:0]              s02_axi_arcache;
logic [2:0]              s02_axi_arprot;
logic [3:0]              s02_axi_arqos;
logic [ARUSER_WIDTH-1:0] s02_axi_aruser;
logic                    s02_axi_arvalid;
wire                     s02_axi_arready;
wire  [ID_WIDTH-1:0]     s02_axi_rid;
wire  [DATA_WIDTH-1:0]   s02_axi_rdata;
wire  [1:0]              s02_axi_rresp;
wire                     s02_axi_rlast;
wire  [RUSER_WIDTH-1:0]  s02_axi_ruser;
wire                     s02_axi_rvalid;
logic                    s02_axi_rready;

// ---------- m00_axi (Slave 0) ----------
wire  [ID_WIDTH-1:0]     m00_axi_awid;
wire  [ADDR_WIDTH-1:0]   m00_axi_awaddr;
wire  [7:0]              m00_axi_awlen;
wire  [2:0]              m00_axi_awsize;
wire  [1:0]              m00_axi_awburst;
wire                     m00_axi_awlock;
wire  [3:0]              m00_axi_awcache;
wire  [2:0]              m00_axi_awprot;
wire  [3:0]              m00_axi_awqos;
wire  [3:0]              m00_axi_awregion;
wire  [AWUSER_WIDTH-1:0] m00_axi_awuser;
wire                     m00_axi_awvalid;
logic                    m00_axi_awready;
wire  [DATA_WIDTH-1:0]   m00_axi_wdata;
wire  [STRB_WIDTH-1:0]   m00_axi_wstrb;
wire                     m00_axi_wlast;
wire  [WUSER_WIDTH-1:0]  m00_axi_wuser;
wire                     m00_axi_wvalid;
logic                    m00_axi_wready;
logic [ID_WIDTH-1:0]     m00_axi_bid;
logic [1:0]              m00_axi_bresp;
logic [BUSER_WIDTH-1:0]  m00_axi_buser;
logic                    m00_axi_bvalid;
wire                     m00_axi_bready;
wire  [ID_WIDTH-1:0]     m00_axi_arid;
wire  [ADDR_WIDTH-1:0]   m00_axi_araddr;
wire  [7:0]              m00_axi_arlen;
wire  [2:0]              m00_axi_arsize;
wire  [1:0]              m00_axi_arburst;
wire                     m00_axi_arlock;
wire  [3:0]              m00_axi_arcache;
wire  [2:0]              m00_axi_arprot;
wire  [3:0]              m00_axi_arqos;
wire  [3:0]              m00_axi_arregion;
wire  [ARUSER_WIDTH-1:0] m00_axi_aruser;
wire                     m00_axi_arvalid;
logic                    m00_axi_arready;
logic [ID_WIDTH-1:0]     m00_axi_rid;
logic [DATA_WIDTH-1:0]   m00_axi_rdata;
logic [1:0]              m00_axi_rresp;
logic                    m00_axi_rlast;
logic [RUSER_WIDTH-1:0]  m00_axi_ruser;
logic                    m00_axi_rvalid;
wire                     m00_axi_rready;

// ---------- m01_axi (Slave 1) ----------
wire  [ID_WIDTH-1:0]     m01_axi_awid;
wire  [ADDR_WIDTH-1:0]   m01_axi_awaddr;
wire  [7:0]              m01_axi_awlen;
wire  [2:0]              m01_axi_awsize;
wire  [1:0]              m01_axi_awburst;
wire                     m01_axi_awlock;
wire  [3:0]              m01_axi_awcache;
wire  [2:0]              m01_axi_awprot;
wire  [3:0]              m01_axi_awqos;
wire  [3:0]              m01_axi_awregion;
wire  [AWUSER_WIDTH-1:0] m01_axi_awuser;
wire                     m01_axi_awvalid;
logic                    m01_axi_awready;
wire  [DATA_WIDTH-1:0]   m01_axi_wdata;
wire  [STRB_WIDTH-1:0]   m01_axi_wstrb;
wire                     m01_axi_wlast;
wire  [WUSER_WIDTH-1:0]  m01_axi_wuser;
wire                     m01_axi_wvalid;
logic                    m01_axi_wready;
logic [ID_WIDTH-1:0]     m01_axi_bid;
logic [1:0]              m01_axi_bresp;
logic [BUSER_WIDTH-1:0]  m01_axi_buser;
logic                    m01_axi_bvalid;
wire                     m01_axi_bready;
wire  [ID_WIDTH-1:0]     m01_axi_arid;
wire  [ADDR_WIDTH-1:0]   m01_axi_araddr;
wire  [7:0]              m01_axi_arlen;
wire  [2:0]              m01_axi_arsize;
wire  [1:0]              m01_axi_arburst;
wire                     m01_axi_arlock;
wire  [3:0]              m01_axi_arcache;
wire  [2:0]              m01_axi_arprot;
wire  [3:0]              m01_axi_arqos;
wire  [3:0]              m01_axi_arregion;
wire  [ARUSER_WIDTH-1:0] m01_axi_aruser;
wire                     m01_axi_arvalid;
logic                    m01_axi_arready;
logic [ID_WIDTH-1:0]     m01_axi_rid;
logic [DATA_WIDTH-1:0]   m01_axi_rdata;
logic [1:0]              m01_axi_rresp;
logic                    m01_axi_rlast;
logic [RUSER_WIDTH-1:0]  m01_axi_ruser;
logic                    m01_axi_rvalid;
wire                     m01_axi_rready;

// ---------- m02_axi (Slave 2) ----------
wire  [ID_WIDTH-1:0]     m02_axi_awid;
wire  [ADDR_WIDTH-1:0]   m02_axi_awaddr;
wire  [7:0]              m02_axi_awlen;
wire  [2:0]              m02_axi_awsize;
wire  [1:0]              m02_axi_awburst;
wire                     m02_axi_awlock;
wire  [3:0]              m02_axi_awcache;
wire  [2:0]              m02_axi_awprot;
wire  [3:0]              m02_axi_awqos;
wire  [3:0]              m02_axi_awregion;
wire  [AWUSER_WIDTH-1:0] m02_axi_awuser;
wire                     m02_axi_awvalid;
logic                    m02_axi_awready;
wire  [DATA_WIDTH-1:0]   m02_axi_wdata;
wire  [STRB_WIDTH-1:0]   m02_axi_wstrb;
wire                     m02_axi_wlast;
wire  [WUSER_WIDTH-1:0]  m02_axi_wuser;
wire                     m02_axi_wvalid;
logic                    m02_axi_wready;
logic [ID_WIDTH-1:0]     m02_axi_bid;
logic [1:0]              m02_axi_bresp;
logic [BUSER_WIDTH-1:0]  m02_axi_buser;
logic                    m02_axi_bvalid;
wire                     m02_axi_bready;
wire  [ID_WIDTH-1:0]     m02_axi_arid;
wire  [ADDR_WIDTH-1:0]   m02_axi_araddr;
wire  [7:0]              m02_axi_arlen;
wire  [2:0]              m02_axi_arsize;
wire  [1:0]              m02_axi_arburst;
wire                     m02_axi_arlock;
wire  [3:0]              m02_axi_arcache;
wire  [2:0]              m02_axi_arprot;
wire  [3:0]              m02_axi_arqos;
wire  [3:0]              m02_axi_arregion;
wire  [ARUSER_WIDTH-1:0] m02_axi_aruser;
wire                     m02_axi_arvalid;
logic                    m02_axi_arready;
logic [ID_WIDTH-1:0]     m02_axi_rid;
logic [DATA_WIDTH-1:0]   m02_axi_rdata;
logic [1:0]              m02_axi_rresp;
logic                    m02_axi_rlast;
logic [RUSER_WIDTH-1:0]  m02_axi_ruser;
logic                    m02_axi_rvalid;
wire                     m02_axi_rready;

// ---------- m03_axi (Slave 3) ----------
wire  [ID_WIDTH-1:0]     m03_axi_awid;
wire  [ADDR_WIDTH-1:0]   m03_axi_awaddr;
wire  [7:0]              m03_axi_awlen;
wire  [2:0]              m03_axi_awsize;
wire  [1:0]              m03_axi_awburst;
wire                     m03_axi_awlock;
wire  [3:0]              m03_axi_awcache;
wire  [2:0]              m03_axi_awprot;
wire  [3:0]              m03_axi_awqos;
wire  [3:0]              m03_axi_awregion;
wire  [AWUSER_WIDTH-1:0] m03_axi_awuser;
wire                     m03_axi_awvalid;
logic                    m03_axi_awready;
wire  [DATA_WIDTH-1:0]   m03_axi_wdata;
wire  [STRB_WIDTH-1:0]   m03_axi_wstrb;
wire                     m03_axi_wlast;
wire  [WUSER_WIDTH-1:0]  m03_axi_wuser;
wire                     m03_axi_wvalid;
logic                    m03_axi_wready;
logic [ID_WIDTH-1:0]     m03_axi_bid;
logic [1:0]              m03_axi_bresp;
logic [BUSER_WIDTH-1:0]  m03_axi_buser;
logic                    m03_axi_bvalid;
wire                     m03_axi_bready;
wire  [ID_WIDTH-1:0]     m03_axi_arid;
wire  [ADDR_WIDTH-1:0]   m03_axi_araddr;
wire  [7:0]              m03_axi_arlen;
wire  [2:0]              m03_axi_arsize;
wire  [1:0]              m03_axi_arburst;
wire                     m03_axi_arlock;
wire  [3:0]              m03_axi_arcache;
wire  [2:0]              m03_axi_arprot;
wire  [3:0]              m03_axi_arqos;
wire  [3:0]              m03_axi_arregion;
wire  [ARUSER_WIDTH-1:0] m03_axi_aruser;
wire                     m03_axi_arvalid;
logic                    m03_axi_arready;
logic [ID_WIDTH-1:0]     m03_axi_rid;
logic [DATA_WIDTH-1:0]   m03_axi_rdata;
logic [1:0]              m03_axi_rresp;
logic                    m03_axi_rlast;
logic [RUSER_WIDTH-1:0]  m03_axi_ruser;
logic                    m03_axi_rvalid;
wire                     m03_axi_rready;

// ---------- m04_axi (Slave 4) ----------
wire  [ID_WIDTH-1:0]     m04_axi_awid;
wire  [ADDR_WIDTH-1:0]   m04_axi_awaddr;
wire  [7:0]              m04_axi_awlen;
wire  [2:0]              m04_axi_awsize;
wire  [1:0]              m04_axi_awburst;
wire                     m04_axi_awlock;
wire  [3:0]              m04_axi_awcache;
wire  [2:0]              m04_axi_awprot;
wire  [3:0]              m04_axi_awqos;
wire  [3:0]              m04_axi_awregion;
wire  [AWUSER_WIDTH-1:0] m04_axi_awuser;
wire                     m04_axi_awvalid;
logic                    m04_axi_awready;
wire  [DATA_WIDTH-1:0]   m04_axi_wdata;
wire  [STRB_WIDTH-1:0]   m04_axi_wstrb;
wire                     m04_axi_wlast;
wire  [WUSER_WIDTH-1:0]  m04_axi_wuser;
wire                     m04_axi_wvalid;
logic                    m04_axi_wready;
logic [ID_WIDTH-1:0]     m04_axi_bid;
logic [1:0]              m04_axi_bresp;
logic [BUSER_WIDTH-1:0]  m04_axi_buser;
logic                    m04_axi_bvalid;
wire                     m04_axi_bready;
wire  [ID_WIDTH-1:0]     m04_axi_arid;
wire  [ADDR_WIDTH-1:0]   m04_axi_araddr;
wire  [7:0]              m04_axi_arlen;
wire  [2:0]              m04_axi_arsize;
wire  [1:0]              m04_axi_arburst;
wire                     m04_axi_arlock;
wire  [3:0]              m04_axi_arcache;
wire  [2:0]              m04_axi_arprot;
wire  [3:0]              m04_axi_arqos;
wire  [3:0]              m04_axi_arregion;
wire  [ARUSER_WIDTH-1:0] m04_axi_aruser;
wire                     m04_axi_arvalid;
logic                    m04_axi_arready;
logic [ID_WIDTH-1:0]     m04_axi_rid;
logic [DATA_WIDTH-1:0]   m04_axi_rdata;
logic [1:0]              m04_axi_rresp;
logic                    m04_axi_rlast;
logic [RUSER_WIDTH-1:0]  m04_axi_ruser;
logic                    m04_axi_rvalid;
wire                     m04_axi_rready;

// ---------- m05_axi (Slave 5) ----------
wire  [ID_WIDTH-1:0]     m05_axi_awid;
wire  [ADDR_WIDTH-1:0]   m05_axi_awaddr;
wire  [7:0]              m05_axi_awlen;
wire  [2:0]              m05_axi_awsize;
wire  [1:0]              m05_axi_awburst;
wire                     m05_axi_awlock;
wire  [3:0]              m05_axi_awcache;
wire  [2:0]              m05_axi_awprot;
wire  [3:0]              m05_axi_awqos;
wire  [3:0]              m05_axi_awregion;
wire  [AWUSER_WIDTH-1:0] m05_axi_awuser;
wire                     m05_axi_awvalid;
logic                    m05_axi_awready;
wire  [DATA_WIDTH-1:0]   m05_axi_wdata;
wire  [STRB_WIDTH-1:0]   m05_axi_wstrb;
wire                     m05_axi_wlast;
wire  [WUSER_WIDTH-1:0]  m05_axi_wuser;
wire                     m05_axi_wvalid;
logic                    m05_axi_wready;
logic [ID_WIDTH-1:0]     m05_axi_bid;
logic [1:0]              m05_axi_bresp;
logic [BUSER_WIDTH-1:0]  m05_axi_buser;
logic                    m05_axi_bvalid;
wire                     m05_axi_bready;
wire  [ID_WIDTH-1:0]     m05_axi_arid;
wire  [ADDR_WIDTH-1:0]   m05_axi_araddr;
wire  [7:0]              m05_axi_arlen;
wire  [2:0]              m05_axi_arsize;
wire  [1:0]              m05_axi_arburst;
wire                     m05_axi_arlock;
wire  [3:0]              m05_axi_arcache;
wire  [2:0]              m05_axi_arprot;
wire  [3:0]              m05_axi_arqos;
wire  [3:0]              m05_axi_arregion;
wire  [ARUSER_WIDTH-1:0] m05_axi_aruser;
wire                     m05_axi_arvalid;
logic                    m05_axi_arready;
logic [ID_WIDTH-1:0]     m05_axi_rid;
logic [DATA_WIDTH-1:0]   m05_axi_rdata;
logic [1:0]              m05_axi_rresp;
logic                    m05_axi_rlast;
logic [RUSER_WIDTH-1:0]  m05_axi_ruser;
logic                    m05_axi_rvalid;
wire                     m05_axi_rready;

// ---------- m06_axi (Slave 6) ----------
wire  [ID_WIDTH-1:0]     m06_axi_awid;
wire  [ADDR_WIDTH-1:0]   m06_axi_awaddr;
wire  [7:0]              m06_axi_awlen;
wire  [2:0]              m06_axi_awsize;
wire  [1:0]              m06_axi_awburst;
wire                     m06_axi_awlock;
wire  [3:0]              m06_axi_awcache;
wire  [2:0]              m06_axi_awprot;
wire  [3:0]              m06_axi_awqos;
wire  [3:0]              m06_axi_awregion;
wire  [AWUSER_WIDTH-1:0] m06_axi_awuser;
wire                     m06_axi_awvalid;
logic                    m06_axi_awready;
wire  [DATA_WIDTH-1:0]   m06_axi_wdata;
wire  [STRB_WIDTH-1:0]   m06_axi_wstrb;
wire                     m06_axi_wlast;
wire  [WUSER_WIDTH-1:0]  m06_axi_wuser;
wire                     m06_axi_wvalid;
logic                    m06_axi_wready;
logic [ID_WIDTH-1:0]     m06_axi_bid;
logic [1:0]              m06_axi_bresp;
logic [BUSER_WIDTH-1:0]  m06_axi_buser;
logic                    m06_axi_bvalid;
wire                     m06_axi_bready;
wire  [ID_WIDTH-1:0]     m06_axi_arid;
wire  [ADDR_WIDTH-1:0]   m06_axi_araddr;
wire  [7:0]              m06_axi_arlen;
wire  [2:0]              m06_axi_arsize;
wire  [1:0]              m06_axi_arburst;
wire                     m06_axi_arlock;
wire  [3:0]              m06_axi_arcache;
wire  [2:0]              m06_axi_arprot;
wire  [3:0]              m06_axi_arqos;
wire  [3:0]              m06_axi_arregion;
wire  [ARUSER_WIDTH-1:0] m06_axi_aruser;
wire                     m06_axi_arvalid;
logic                    m06_axi_arready;
logic [ID_WIDTH-1:0]     m06_axi_rid;
logic [DATA_WIDTH-1:0]   m06_axi_rdata;
logic [1:0]              m06_axi_rresp;
logic                    m06_axi_rlast;
logic [RUSER_WIDTH-1:0]  m06_axi_ruser;
logic                    m06_axi_rvalid;
wire                     m06_axi_rready;

// =============================================================================
// DUT — axi_interconnect_wrap_3x7
// Address map parameters set to non-overlapping 16 MB windows:
//   Slave N base = N << 24, width = 24 bits
// =============================================================================
axi_interconnect_wrap_3x7 #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .AWUSER_ENABLE(0),
    .AWUSER_WIDTH(AWUSER_WIDTH),
    .WUSER_ENABLE(0),
    .WUSER_WIDTH(WUSER_WIDTH),
    .BUSER_ENABLE(0),
    .BUSER_WIDTH(BUSER_WIDTH),
    .ARUSER_ENABLE(0),
    .ARUSER_WIDTH(ARUSER_WIDTH),
    .RUSER_ENABLE(0),
    .RUSER_WIDTH(RUSER_WIDTH),
    .FORWARD_ID(0),
    .M_REGIONS(1),
    .M00_BASE_ADDR(32'h0000_0000), .M00_ADDR_WIDTH(32'd24),
    .M01_BASE_ADDR(32'h0100_0000), .M01_ADDR_WIDTH(32'd24),
    .M02_BASE_ADDR(32'h0200_0000), .M02_ADDR_WIDTH(32'd24),
    .M03_BASE_ADDR(32'h0300_0000), .M03_ADDR_WIDTH(32'd24),
    .M04_BASE_ADDR(32'h0400_0000), .M04_ADDR_WIDTH(32'd24),
    .M05_BASE_ADDR(32'h0500_0000), .M05_ADDR_WIDTH(32'd24),
    .M06_BASE_ADDR(32'h0600_0000), .M06_ADDR_WIDTH(32'd24),
    .M00_CONNECT_READ(3'b111), .M00_CONNECT_WRITE(3'b111),
    .M01_CONNECT_READ(3'b111), .M01_CONNECT_WRITE(3'b111),
    .M02_CONNECT_READ(3'b111), .M02_CONNECT_WRITE(3'b111),
    .M03_CONNECT_READ(3'b111), .M03_CONNECT_WRITE(3'b111),
    .M04_CONNECT_READ(3'b111), .M04_CONNECT_WRITE(3'b111),
    .M05_CONNECT_READ(3'b111), .M05_CONNECT_WRITE(3'b111),
    .M06_CONNECT_READ(3'b111), .M06_CONNECT_WRITE(3'b111)
) dut (
    .clk(clk), .rst(rst),

    .s00_axi_awid(s00_axi_awid), .s00_axi_awaddr(s00_axi_awaddr),
    .s00_axi_awlen(s00_axi_awlen), .s00_axi_awsize(s00_axi_awsize),
    .s00_axi_awburst(s00_axi_awburst), .s00_axi_awlock(s00_axi_awlock),
    .s00_axi_awcache(s00_axi_awcache), .s00_axi_awprot(s00_axi_awprot),
    .s00_axi_awqos(s00_axi_awqos), .s00_axi_awuser(s00_axi_awuser),
    .s00_axi_awvalid(s00_axi_awvalid), .s00_axi_awready(s00_axi_awready),
    .s00_axi_wdata(s00_axi_wdata), .s00_axi_wstrb(s00_axi_wstrb),
    .s00_axi_wlast(s00_axi_wlast), .s00_axi_wuser(s00_axi_wuser),
    .s00_axi_wvalid(s00_axi_wvalid), .s00_axi_wready(s00_axi_wready),
    .s00_axi_bid(s00_axi_bid), .s00_axi_bresp(s00_axi_bresp),
    .s00_axi_buser(s00_axi_buser), .s00_axi_bvalid(s00_axi_bvalid),
    .s00_axi_bready(s00_axi_bready),
    .s00_axi_arid(s00_axi_arid), .s00_axi_araddr(s00_axi_araddr),
    .s00_axi_arlen(s00_axi_arlen), .s00_axi_arsize(s00_axi_arsize),
    .s00_axi_arburst(s00_axi_arburst), .s00_axi_arlock(s00_axi_arlock),
    .s00_axi_arcache(s00_axi_arcache), .s00_axi_arprot(s00_axi_arprot),
    .s00_axi_arqos(s00_axi_arqos), .s00_axi_aruser(s00_axi_aruser),
    .s00_axi_arvalid(s00_axi_arvalid), .s00_axi_arready(s00_axi_arready),
    .s00_axi_rid(s00_axi_rid), .s00_axi_rdata(s00_axi_rdata),
    .s00_axi_rresp(s00_axi_rresp), .s00_axi_rlast(s00_axi_rlast),
    .s00_axi_ruser(s00_axi_ruser), .s00_axi_rvalid(s00_axi_rvalid),
    .s00_axi_rready(s00_axi_rready),

    .s01_axi_awid(s01_axi_awid), .s01_axi_awaddr(s01_axi_awaddr),
    .s01_axi_awlen(s01_axi_awlen), .s01_axi_awsize(s01_axi_awsize),
    .s01_axi_awburst(s01_axi_awburst), .s01_axi_awlock(s01_axi_awlock),
    .s01_axi_awcache(s01_axi_awcache), .s01_axi_awprot(s01_axi_awprot),
    .s01_axi_awqos(s01_axi_awqos), .s01_axi_awuser(s01_axi_awuser),
    .s01_axi_awvalid(s01_axi_awvalid), .s01_axi_awready(s01_axi_awready),
    .s01_axi_wdata(s01_axi_wdata), .s01_axi_wstrb(s01_axi_wstrb),
    .s01_axi_wlast(s01_axi_wlast), .s01_axi_wuser(s01_axi_wuser),
    .s01_axi_wvalid(s01_axi_wvalid), .s01_axi_wready(s01_axi_wready),
    .s01_axi_bid(s01_axi_bid), .s01_axi_bresp(s01_axi_bresp),
    .s01_axi_buser(s01_axi_buser), .s01_axi_bvalid(s01_axi_bvalid),
    .s01_axi_bready(s01_axi_bready),
    .s01_axi_arid(s01_axi_arid), .s01_axi_araddr(s01_axi_araddr),
    .s01_axi_arlen(s01_axi_arlen), .s01_axi_arsize(s01_axi_arsize),
    .s01_axi_arburst(s01_axi_arburst), .s01_axi_arlock(s01_axi_arlock),
    .s01_axi_arcache(s01_axi_arcache), .s01_axi_arprot(s01_axi_arprot),
    .s01_axi_arqos(s01_axi_arqos), .s01_axi_aruser(s01_axi_aruser),
    .s01_axi_arvalid(s01_axi_arvalid), .s01_axi_arready(s01_axi_arready),
    .s01_axi_rid(s01_axi_rid), .s01_axi_rdata(s01_axi_rdata),
    .s01_axi_rresp(s01_axi_rresp), .s01_axi_rlast(s01_axi_rlast),
    .s01_axi_ruser(s01_axi_ruser), .s01_axi_rvalid(s01_axi_rvalid),
    .s01_axi_rready(s01_axi_rready),

    .s02_axi_awid(s02_axi_awid), .s02_axi_awaddr(s02_axi_awaddr),
    .s02_axi_awlen(s02_axi_awlen), .s02_axi_awsize(s02_axi_awsize),
    .s02_axi_awburst(s02_axi_awburst), .s02_axi_awlock(s02_axi_awlock),
    .s02_axi_awcache(s02_axi_awcache), .s02_axi_awprot(s02_axi_awprot),
    .s02_axi_awqos(s02_axi_awqos), .s02_axi_awuser(s02_axi_awuser),
    .s02_axi_awvalid(s02_axi_awvalid), .s02_axi_awready(s02_axi_awready),
    .s02_axi_wdata(s02_axi_wdata), .s02_axi_wstrb(s02_axi_wstrb),
    .s02_axi_wlast(s02_axi_wlast), .s02_axi_wuser(s02_axi_wuser),
    .s02_axi_wvalid(s02_axi_wvalid), .s02_axi_wready(s02_axi_wready),
    .s02_axi_bid(s02_axi_bid), .s02_axi_bresp(s02_axi_bresp),
    .s02_axi_buser(s02_axi_buser), .s02_axi_bvalid(s02_axi_bvalid),
    .s02_axi_bready(s02_axi_bready),
    .s02_axi_arid(s02_axi_arid), .s02_axi_araddr(s02_axi_araddr),
    .s02_axi_arlen(s02_axi_arlen), .s02_axi_arsize(s02_axi_arsize),
    .s02_axi_arburst(s02_axi_arburst), .s02_axi_arlock(s02_axi_arlock),
    .s02_axi_arcache(s02_axi_arcache), .s02_axi_arprot(s02_axi_arprot),
    .s02_axi_arqos(s02_axi_arqos), .s02_axi_aruser(s02_axi_aruser),
    .s02_axi_arvalid(s02_axi_arvalid), .s02_axi_arready(s02_axi_arready),
    .s02_axi_rid(s02_axi_rid), .s02_axi_rdata(s02_axi_rdata),
    .s02_axi_rresp(s02_axi_rresp), .s02_axi_rlast(s02_axi_rlast),
    .s02_axi_ruser(s02_axi_ruser), .s02_axi_rvalid(s02_axi_rvalid),
    .s02_axi_rready(s02_axi_rready),

    .m00_axi_awid(m00_axi_awid), .m00_axi_awaddr(m00_axi_awaddr),
    .m00_axi_awlen(m00_axi_awlen), .m00_axi_awsize(m00_axi_awsize),
    .m00_axi_awburst(m00_axi_awburst), .m00_axi_awlock(m00_axi_awlock),
    .m00_axi_awcache(m00_axi_awcache), .m00_axi_awprot(m00_axi_awprot),
    .m00_axi_awqos(m00_axi_awqos), .m00_axi_awregion(m00_axi_awregion),
    .m00_axi_awuser(m00_axi_awuser), .m00_axi_awvalid(m00_axi_awvalid),
    .m00_axi_awready(m00_axi_awready),
    .m00_axi_wdata(m00_axi_wdata), .m00_axi_wstrb(m00_axi_wstrb),
    .m00_axi_wlast(m00_axi_wlast), .m00_axi_wuser(m00_axi_wuser),
    .m00_axi_wvalid(m00_axi_wvalid), .m00_axi_wready(m00_axi_wready),
    .m00_axi_bid(m00_axi_bid), .m00_axi_bresp(m00_axi_bresp),
    .m00_axi_buser(m00_axi_buser), .m00_axi_bvalid(m00_axi_bvalid),
    .m00_axi_bready(m00_axi_bready),
    .m00_axi_arid(m00_axi_arid), .m00_axi_araddr(m00_axi_araddr),
    .m00_axi_arlen(m00_axi_arlen), .m00_axi_arsize(m00_axi_arsize),
    .m00_axi_arburst(m00_axi_arburst), .m00_axi_arlock(m00_axi_arlock),
    .m00_axi_arcache(m00_axi_arcache), .m00_axi_arprot(m00_axi_arprot),
    .m00_axi_arqos(m00_axi_arqos), .m00_axi_arregion(m00_axi_arregion),
    .m00_axi_aruser(m00_axi_aruser), .m00_axi_arvalid(m00_axi_arvalid),
    .m00_axi_arready(m00_axi_arready),
    .m00_axi_rid(m00_axi_rid), .m00_axi_rdata(m00_axi_rdata),
    .m00_axi_rresp(m00_axi_rresp), .m00_axi_rlast(m00_axi_rlast),
    .m00_axi_ruser(m00_axi_ruser), .m00_axi_rvalid(m00_axi_rvalid),
    .m00_axi_rready(m00_axi_rready),

    .m01_axi_awid(m01_axi_awid), .m01_axi_awaddr(m01_axi_awaddr),
    .m01_axi_awlen(m01_axi_awlen), .m01_axi_awsize(m01_axi_awsize),
    .m01_axi_awburst(m01_axi_awburst), .m01_axi_awlock(m01_axi_awlock),
    .m01_axi_awcache(m01_axi_awcache), .m01_axi_awprot(m01_axi_awprot),
    .m01_axi_awqos(m01_axi_awqos), .m01_axi_awregion(m01_axi_awregion),
    .m01_axi_awuser(m01_axi_awuser), .m01_axi_awvalid(m01_axi_awvalid),
    .m01_axi_awready(m01_axi_awready),
    .m01_axi_wdata(m01_axi_wdata), .m01_axi_wstrb(m01_axi_wstrb),
    .m01_axi_wlast(m01_axi_wlast), .m01_axi_wuser(m01_axi_wuser),
    .m01_axi_wvalid(m01_axi_wvalid), .m01_axi_wready(m01_axi_wready),
    .m01_axi_bid(m01_axi_bid), .m01_axi_bresp(m01_axi_bresp),
    .m01_axi_buser(m01_axi_buser), .m01_axi_bvalid(m01_axi_bvalid),
    .m01_axi_bready(m01_axi_bready),
    .m01_axi_arid(m01_axi_arid), .m01_axi_araddr(m01_axi_araddr),
    .m01_axi_arlen(m01_axi_arlen), .m01_axi_arsize(m01_axi_arsize),
    .m01_axi_arburst(m01_axi_arburst), .m01_axi_arlock(m01_axi_arlock),
    .m01_axi_arcache(m01_axi_arcache), .m01_axi_arprot(m01_axi_arprot),
    .m01_axi_arqos(m01_axi_arqos), .m01_axi_arregion(m01_axi_arregion),
    .m01_axi_aruser(m01_axi_aruser), .m01_axi_arvalid(m01_axi_arvalid),
    .m01_axi_arready(m01_axi_arready),
    .m01_axi_rid(m01_axi_rid), .m01_axi_rdata(m01_axi_rdata),
    .m01_axi_rresp(m01_axi_rresp), .m01_axi_rlast(m01_axi_rlast),
    .m01_axi_ruser(m01_axi_ruser), .m01_axi_rvalid(m01_axi_rvalid),
    .m01_axi_rready(m01_axi_rready),

    .m02_axi_awid(m02_axi_awid), .m02_axi_awaddr(m02_axi_awaddr),
    .m02_axi_awlen(m02_axi_awlen), .m02_axi_awsize(m02_axi_awsize),
    .m02_axi_awburst(m02_axi_awburst), .m02_axi_awlock(m02_axi_awlock),
    .m02_axi_awcache(m02_axi_awcache), .m02_axi_awprot(m02_axi_awprot),
    .m02_axi_awqos(m02_axi_awqos), .m02_axi_awregion(m02_axi_awregion),
    .m02_axi_awuser(m02_axi_awuser), .m02_axi_awvalid(m02_axi_awvalid),
    .m02_axi_awready(m02_axi_awready),
    .m02_axi_wdata(m02_axi_wdata), .m02_axi_wstrb(m02_axi_wstrb),
    .m02_axi_wlast(m02_axi_wlast), .m02_axi_wuser(m02_axi_wuser),
    .m02_axi_wvalid(m02_axi_wvalid), .m02_axi_wready(m02_axi_wready),
    .m02_axi_bid(m02_axi_bid), .m02_axi_bresp(m02_axi_bresp),
    .m02_axi_buser(m02_axi_buser), .m02_axi_bvalid(m02_axi_bvalid),
    .m02_axi_bready(m02_axi_bready),
    .m02_axi_arid(m02_axi_arid), .m02_axi_araddr(m02_axi_araddr),
    .m02_axi_arlen(m02_axi_arlen), .m02_axi_arsize(m02_axi_arsize),
    .m02_axi_arburst(m02_axi_arburst), .m02_axi_arlock(m02_axi_arlock),
    .m02_axi_arcache(m02_axi_arcache), .m02_axi_arprot(m02_axi_arprot),
    .m02_axi_arqos(m02_axi_arqos), .m02_axi_arregion(m02_axi_arregion),
    .m02_axi_aruser(m02_axi_aruser), .m02_axi_arvalid(m02_axi_arvalid),
    .m02_axi_arready(m02_axi_arready),
    .m02_axi_rid(m02_axi_rid), .m02_axi_rdata(m02_axi_rdata),
    .m02_axi_rresp(m02_axi_rresp), .m02_axi_rlast(m02_axi_rlast),
    .m02_axi_ruser(m02_axi_ruser), .m02_axi_rvalid(m02_axi_rvalid),
    .m02_axi_rready(m02_axi_rready),

    .m03_axi_awid(m03_axi_awid), .m03_axi_awaddr(m03_axi_awaddr),
    .m03_axi_awlen(m03_axi_awlen), .m03_axi_awsize(m03_axi_awsize),
    .m03_axi_awburst(m03_axi_awburst), .m03_axi_awlock(m03_axi_awlock),
    .m03_axi_awcache(m03_axi_awcache), .m03_axi_awprot(m03_axi_awprot),
    .m03_axi_awqos(m03_axi_awqos), .m03_axi_awregion(m03_axi_awregion),
    .m03_axi_awuser(m03_axi_awuser), .m03_axi_awvalid(m03_axi_awvalid),
    .m03_axi_awready(m03_axi_awready),
    .m03_axi_wdata(m03_axi_wdata), .m03_axi_wstrb(m03_axi_wstrb),
    .m03_axi_wlast(m03_axi_wlast), .m03_axi_wuser(m03_axi_wuser),
    .m03_axi_wvalid(m03_axi_wvalid), .m03_axi_wready(m03_axi_wready),
    .m03_axi_bid(m03_axi_bid), .m03_axi_bresp(m03_axi_bresp),
    .m03_axi_buser(m03_axi_buser), .m03_axi_bvalid(m03_axi_bvalid),
    .m03_axi_bready(m03_axi_bready),
    .m03_axi_arid(m03_axi_arid), .m03_axi_araddr(m03_axi_araddr),
    .m03_axi_arlen(m03_axi_arlen), .m03_axi_arsize(m03_axi_arsize),
    .m03_axi_arburst(m03_axi_arburst), .m03_axi_arlock(m03_axi_arlock),
    .m03_axi_arcache(m03_axi_arcache), .m03_axi_arprot(m03_axi_arprot),
    .m03_axi_arqos(m03_axi_arqos), .m03_axi_arregion(m03_axi_arregion),
    .m03_axi_aruser(m03_axi_aruser), .m03_axi_arvalid(m03_axi_arvalid),
    .m03_axi_arready(m03_axi_arready),
    .m03_axi_rid(m03_axi_rid), .m03_axi_rdata(m03_axi_rdata),
    .m03_axi_rresp(m03_axi_rresp), .m03_axi_rlast(m03_axi_rlast),
    .m03_axi_ruser(m03_axi_ruser), .m03_axi_rvalid(m03_axi_rvalid),
    .m03_axi_rready(m03_axi_rready),

    .m04_axi_awid(m04_axi_awid), .m04_axi_awaddr(m04_axi_awaddr),
    .m04_axi_awlen(m04_axi_awlen), .m04_axi_awsize(m04_axi_awsize),
    .m04_axi_awburst(m04_axi_awburst), .m04_axi_awlock(m04_axi_awlock),
    .m04_axi_awcache(m04_axi_awcache), .m04_axi_awprot(m04_axi_awprot),
    .m04_axi_awqos(m04_axi_awqos), .m04_axi_awregion(m04_axi_awregion),
    .m04_axi_awuser(m04_axi_awuser), .m04_axi_awvalid(m04_axi_awvalid),
    .m04_axi_awready(m04_axi_awready),
    .m04_axi_wdata(m04_axi_wdata), .m04_axi_wstrb(m04_axi_wstrb),
    .m04_axi_wlast(m04_axi_wlast), .m04_axi_wuser(m04_axi_wuser),
    .m04_axi_wvalid(m04_axi_wvalid), .m04_axi_wready(m04_axi_wready),
    .m04_axi_bid(m04_axi_bid), .m04_axi_bresp(m04_axi_bresp),
    .m04_axi_buser(m04_axi_buser), .m04_axi_bvalid(m04_axi_bvalid),
    .m04_axi_bready(m04_axi_bready),
    .m04_axi_arid(m04_axi_arid), .m04_axi_araddr(m04_axi_araddr),
    .m04_axi_arlen(m04_axi_arlen), .m04_axi_arsize(m04_axi_arsize),
    .m04_axi_arburst(m04_axi_arburst), .m04_axi_arlock(m04_axi_arlock),
    .m04_axi_arcache(m04_axi_arcache), .m04_axi_arprot(m04_axi_arprot),
    .m04_axi_arqos(m04_axi_arqos), .m04_axi_arregion(m04_axi_arregion),
    .m04_axi_aruser(m04_axi_aruser), .m04_axi_arvalid(m04_axi_arvalid),
    .m04_axi_arready(m04_axi_arready),
    .m04_axi_rid(m04_axi_rid), .m04_axi_rdata(m04_axi_rdata),
    .m04_axi_rresp(m04_axi_rresp), .m04_axi_rlast(m04_axi_rlast),
    .m04_axi_ruser(m04_axi_ruser), .m04_axi_rvalid(m04_axi_rvalid),
    .m04_axi_rready(m04_axi_rready),

    .m05_axi_awid(m05_axi_awid), .m05_axi_awaddr(m05_axi_awaddr),
    .m05_axi_awlen(m05_axi_awlen), .m05_axi_awsize(m05_axi_awsize),
    .m05_axi_awburst(m05_axi_awburst), .m05_axi_awlock(m05_axi_awlock),
    .m05_axi_awcache(m05_axi_awcache), .m05_axi_awprot(m05_axi_awprot),
    .m05_axi_awqos(m05_axi_awqos), .m05_axi_awregion(m05_axi_awregion),
    .m05_axi_awuser(m05_axi_awuser), .m05_axi_awvalid(m05_axi_awvalid),
    .m05_axi_awready(m05_axi_awready),
    .m05_axi_wdata(m05_axi_wdata), .m05_axi_wstrb(m05_axi_wstrb),
    .m05_axi_wlast(m05_axi_wlast), .m05_axi_wuser(m05_axi_wuser),
    .m05_axi_wvalid(m05_axi_wvalid), .m05_axi_wready(m05_axi_wready),
    .m05_axi_bid(m05_axi_bid), .m05_axi_bresp(m05_axi_bresp),
    .m05_axi_buser(m05_axi_buser), .m05_axi_bvalid(m05_axi_bvalid),
    .m05_axi_bready(m05_axi_bready),
    .m05_axi_arid(m05_axi_arid), .m05_axi_araddr(m05_axi_araddr),
    .m05_axi_arlen(m05_axi_arlen), .m05_axi_arsize(m05_axi_arsize),
    .m05_axi_arburst(m05_axi_arburst), .m05_axi_arlock(m05_axi_arlock),
    .m05_axi_arcache(m05_axi_arcache), .m05_axi_arprot(m05_axi_arprot),
    .m05_axi_arqos(m05_axi_arqos), .m05_axi_arregion(m05_axi_arregion),
    .m05_axi_aruser(m05_axi_aruser), .m05_axi_arvalid(m05_axi_arvalid),
    .m05_axi_arready(m05_axi_arready),
    .m05_axi_rid(m05_axi_rid), .m05_axi_rdata(m05_axi_rdata),
    .m05_axi_rresp(m05_axi_rresp), .m05_axi_rlast(m05_axi_rlast),
    .m05_axi_ruser(m05_axi_ruser), .m05_axi_rvalid(m05_axi_rvalid),
    .m05_axi_rready(m05_axi_rready),

    .m06_axi_awid(m06_axi_awid), .m06_axi_awaddr(m06_axi_awaddr),
    .m06_axi_awlen(m06_axi_awlen), .m06_axi_awsize(m06_axi_awsize),
    .m06_axi_awburst(m06_axi_awburst), .m06_axi_awlock(m06_axi_awlock),
    .m06_axi_awcache(m06_axi_awcache), .m06_axi_awprot(m06_axi_awprot),
    .m06_axi_awqos(m06_axi_awqos), .m06_axi_awregion(m06_axi_awregion),
    .m06_axi_awuser(m06_axi_awuser), .m06_axi_awvalid(m06_axi_awvalid),
    .m06_axi_awready(m06_axi_awready),
    .m06_axi_wdata(m06_axi_wdata), .m06_axi_wstrb(m06_axi_wstrb),
    .m06_axi_wlast(m06_axi_wlast), .m06_axi_wuser(m06_axi_wuser),
    .m06_axi_wvalid(m06_axi_wvalid), .m06_axi_wready(m06_axi_wready),
    .m06_axi_bid(m06_axi_bid), .m06_axi_bresp(m06_axi_bresp),
    .m06_axi_buser(m06_axi_buser), .m06_axi_bvalid(m06_axi_bvalid),
    .m06_axi_bready(m06_axi_bready),
    .m06_axi_arid(m06_axi_arid), .m06_axi_araddr(m06_axi_araddr),
    .m06_axi_arlen(m06_axi_arlen), .m06_axi_arsize(m06_axi_arsize),
    .m06_axi_arburst(m06_axi_arburst), .m06_axi_arlock(m06_axi_arlock),
    .m06_axi_arcache(m06_axi_arcache), .m06_axi_arprot(m06_axi_arprot),
    .m06_axi_arqos(m06_axi_arqos), .m06_axi_arregion(m06_axi_arregion),
    .m06_axi_aruser(m06_axi_aruser), .m06_axi_arvalid(m06_axi_arvalid),
    .m06_axi_arready(m06_axi_arready),
    .m06_axi_rid(m06_axi_rid), .m06_axi_rdata(m06_axi_rdata),
    .m06_axi_rresp(m06_axi_rresp), .m06_axi_rlast(m06_axi_rlast),
    .m06_axi_ruser(m06_axi_ruser), .m06_axi_rvalid(m06_axi_rvalid),
    .m06_axi_rready(m06_axi_rready)
);

// =============================================================================
// AXI Master BFMs
// =============================================================================
axi_master_bfm #(
    .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH), .MASTER_ID(0), .TIMEOUT_CYC(TIMEOUT_CYC)
) m0_bfm (
    .clk(clk), .rst(rst),
    .awid(s00_axi_awid), .awaddr(s00_axi_awaddr), .awlen(s00_axi_awlen),
    .awsize(s00_axi_awsize), .awburst(s00_axi_awburst), .awlock(s00_axi_awlock),
    .awcache(s00_axi_awcache), .awprot(s00_axi_awprot), .awqos(s00_axi_awqos),
    .awuser(s00_axi_awuser), .awvalid(s00_axi_awvalid), .awready(s00_axi_awready),
    .wdata(s00_axi_wdata), .wstrb(s00_axi_wstrb), .wlast(s00_axi_wlast),
    .wuser(s00_axi_wuser), .wvalid(s00_axi_wvalid), .wready(s00_axi_wready),
    .bid(s00_axi_bid), .bresp(s00_axi_bresp), .buser(s00_axi_buser),
    .bvalid(s00_axi_bvalid), .bready(s00_axi_bready),
    .arid(s00_axi_arid), .araddr(s00_axi_araddr), .arlen(s00_axi_arlen),
    .arsize(s00_axi_arsize), .arburst(s00_axi_arburst), .arlock(s00_axi_arlock),
    .arcache(s00_axi_arcache), .arprot(s00_axi_arprot), .arqos(s00_axi_arqos),
    .aruser(s00_axi_aruser), .arvalid(s00_axi_arvalid), .arready(s00_axi_arready),
    .rid(s00_axi_rid), .rdata(s00_axi_rdata), .rresp(s00_axi_rresp),
    .rlast(s00_axi_rlast), .ruser(s00_axi_ruser), .rvalid(s00_axi_rvalid),
    .rready(s00_axi_rready)
);

axi_master_bfm #(
    .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH), .MASTER_ID(1), .TIMEOUT_CYC(TIMEOUT_CYC)
) m1_bfm (
    .clk(clk), .rst(rst),
    .awid(s01_axi_awid), .awaddr(s01_axi_awaddr), .awlen(s01_axi_awlen),
    .awsize(s01_axi_awsize), .awburst(s01_axi_awburst), .awlock(s01_axi_awlock),
    .awcache(s01_axi_awcache), .awprot(s01_axi_awprot), .awqos(s01_axi_awqos),
    .awuser(s01_axi_awuser), .awvalid(s01_axi_awvalid), .awready(s01_axi_awready),
    .wdata(s01_axi_wdata), .wstrb(s01_axi_wstrb), .wlast(s01_axi_wlast),
    .wuser(s01_axi_wuser), .wvalid(s01_axi_wvalid), .wready(s01_axi_wready),
    .bid(s01_axi_bid), .bresp(s01_axi_bresp), .buser(s01_axi_buser),
    .bvalid(s01_axi_bvalid), .bready(s01_axi_bready),
    .arid(s01_axi_arid), .araddr(s01_axi_araddr), .arlen(s01_axi_arlen),
    .arsize(s01_axi_arsize), .arburst(s01_axi_arburst), .arlock(s01_axi_arlock),
    .arcache(s01_axi_arcache), .arprot(s01_axi_arprot), .arqos(s01_axi_arqos),
    .aruser(s01_axi_aruser), .arvalid(s01_axi_arvalid), .arready(s01_axi_arready),
    .rid(s01_axi_rid), .rdata(s01_axi_rdata), .rresp(s01_axi_rresp),
    .rlast(s01_axi_rlast), .ruser(s01_axi_ruser), .rvalid(s01_axi_rvalid),
    .rready(s01_axi_rready)
);

axi_master_bfm #(
    .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH),
    .STRB_WIDTH(STRB_WIDTH), .MASTER_ID(2), .TIMEOUT_CYC(TIMEOUT_CYC)
) m2_bfm (
    .clk(clk), .rst(rst),
    .awid(s02_axi_awid), .awaddr(s02_axi_awaddr), .awlen(s02_axi_awlen),
    .awsize(s02_axi_awsize), .awburst(s02_axi_awburst), .awlock(s02_axi_awlock),
    .awcache(s02_axi_awcache), .awprot(s02_axi_awprot), .awqos(s02_axi_awqos),
    .awuser(s02_axi_awuser), .awvalid(s02_axi_awvalid), .awready(s02_axi_awready),
    .wdata(s02_axi_wdata), .wstrb(s02_axi_wstrb), .wlast(s02_axi_wlast),
    .wuser(s02_axi_wuser), .wvalid(s02_axi_wvalid), .wready(s02_axi_wready),
    .bid(s02_axi_bid), .bresp(s02_axi_bresp), .buser(s02_axi_buser),
    .bvalid(s02_axi_bvalid), .bready(s02_axi_bready),
    .arid(s02_axi_arid), .araddr(s02_axi_araddr), .arlen(s02_axi_arlen),
    .arsize(s02_axi_arsize), .arburst(s02_axi_arburst), .arlock(s02_axi_arlock),
    .arcache(s02_axi_arcache), .arprot(s02_axi_arprot), .arqos(s02_axi_arqos),
    .aruser(s02_axi_aruser), .arvalid(s02_axi_arvalid), .arready(s02_axi_arready),
    .rid(s02_axi_rid), .rdata(s02_axi_rdata), .rresp(s02_axi_rresp),
    .rlast(s02_axi_rlast), .ruser(s02_axi_ruser), .rvalid(s02_axi_rvalid),
    .rready(s02_axi_rready)
);

// =============================================================================
// AXI Slave Models
// =============================================================================
axi_slave_model #(.SLAVE_ID(0), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
    .ID_WIDTH(ID_WIDTH), .STRB_WIDTH(STRB_WIDTH)) slave0 (
    .clk(clk), .rst(rst),
    .awid(m00_axi_awid), .awaddr(m00_axi_awaddr), .awlen(m00_axi_awlen),
    .awsize(m00_axi_awsize), .awburst(m00_axi_awburst), .awlock(m00_axi_awlock),
    .awcache(m00_axi_awcache), .awprot(m00_axi_awprot), .awqos(m00_axi_awqos),
    .awuser(m00_axi_awuser), .awvalid(m00_axi_awvalid), .awready(m00_axi_awready),
    .wdata(m00_axi_wdata), .wstrb(m00_axi_wstrb), .wlast(m00_axi_wlast),
    .wuser(m00_axi_wuser), .wvalid(m00_axi_wvalid), .wready(m00_axi_wready),
    .bid(m00_axi_bid), .bresp(m00_axi_bresp), .buser(m00_axi_buser),
    .bvalid(m00_axi_bvalid), .bready(m00_axi_bready),
    .arid(m00_axi_arid), .araddr(m00_axi_araddr), .arlen(m00_axi_arlen),
    .arsize(m00_axi_arsize), .arburst(m00_axi_arburst), .arlock(m00_axi_arlock),
    .arcache(m00_axi_arcache), .arprot(m00_axi_arprot), .arqos(m00_axi_arqos),
    .aruser(m00_axi_aruser), .arvalid(m00_axi_arvalid), .arready(m00_axi_arready),
    .rid(m00_axi_rid), .rdata(m00_axi_rdata), .rresp(m00_axi_rresp),
    .rlast(m00_axi_rlast), .ruser(m00_axi_ruser), .rvalid(m00_axi_rvalid),
    .rready(m00_axi_rready)
);

axi_slave_model #(.SLAVE_ID(1), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
    .ID_WIDTH(ID_WIDTH), .STRB_WIDTH(STRB_WIDTH)) slave1 (
    .clk(clk), .rst(rst),
    .awid(m01_axi_awid), .awaddr(m01_axi_awaddr), .awlen(m01_axi_awlen),
    .awsize(m01_axi_awsize), .awburst(m01_axi_awburst), .awlock(m01_axi_awlock),
    .awcache(m01_axi_awcache), .awprot(m01_axi_awprot), .awqos(m01_axi_awqos),
    .awuser(m01_axi_awuser), .awvalid(m01_axi_awvalid), .awready(m01_axi_awready),
    .wdata(m01_axi_wdata), .wstrb(m01_axi_wstrb), .wlast(m01_axi_wlast),
    .wuser(m01_axi_wuser), .wvalid(m01_axi_wvalid), .wready(m01_axi_wready),
    .bid(m01_axi_bid), .bresp(m01_axi_bresp), .buser(m01_axi_buser),
    .bvalid(m01_axi_bvalid), .bready(m01_axi_bready),
    .arid(m01_axi_arid), .araddr(m01_axi_araddr), .arlen(m01_axi_arlen),
    .arsize(m01_axi_arsize), .arburst(m01_axi_arburst), .arlock(m01_axi_arlock),
    .arcache(m01_axi_arcache), .arprot(m01_axi_arprot), .arqos(m01_axi_arqos),
    .aruser(m01_axi_aruser), .arvalid(m01_axi_arvalid), .arready(m01_axi_arready),
    .rid(m01_axi_rid), .rdata(m01_axi_rdata), .rresp(m01_axi_rresp),
    .rlast(m01_axi_rlast), .ruser(m01_axi_ruser), .rvalid(m01_axi_rvalid),
    .rready(m01_axi_rready)
);

axi_slave_model #(.SLAVE_ID(2), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
    .ID_WIDTH(ID_WIDTH), .STRB_WIDTH(STRB_WIDTH)) slave2 (
    .clk(clk), .rst(rst),
    .awid(m02_axi_awid), .awaddr(m02_axi_awaddr), .awlen(m02_axi_awlen),
    .awsize(m02_axi_awsize), .awburst(m02_axi_awburst), .awlock(m02_axi_awlock),
    .awcache(m02_axi_awcache), .awprot(m02_axi_awprot), .awqos(m02_axi_awqos),
    .awuser(m02_axi_awuser), .awvalid(m02_axi_awvalid), .awready(m02_axi_awready),
    .wdata(m02_axi_wdata), .wstrb(m02_axi_wstrb), .wlast(m02_axi_wlast),
    .wuser(m02_axi_wuser), .wvalid(m02_axi_wvalid), .wready(m02_axi_wready),
    .bid(m02_axi_bid), .bresp(m02_axi_bresp), .buser(m02_axi_buser),
    .bvalid(m02_axi_bvalid), .bready(m02_axi_bready),
    .arid(m02_axi_arid), .araddr(m02_axi_araddr), .arlen(m02_axi_arlen),
    .arsize(m02_axi_arsize), .arburst(m02_axi_arburst), .arlock(m02_axi_arlock),
    .arcache(m02_axi_arcache), .arprot(m02_axi_arprot), .arqos(m02_axi_arqos),
    .aruser(m02_axi_aruser), .arvalid(m02_axi_arvalid), .arready(m02_axi_arready),
    .rid(m02_axi_rid), .rdata(m02_axi_rdata), .rresp(m02_axi_rresp),
    .rlast(m02_axi_rlast), .ruser(m02_axi_ruser), .rvalid(m02_axi_rvalid),
    .rready(m02_axi_rready)
);

axi_slave_model #(.SLAVE_ID(3), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
    .ID_WIDTH(ID_WIDTH), .STRB_WIDTH(STRB_WIDTH)) slave3 (
    .clk(clk), .rst(rst),
    .awid(m03_axi_awid), .awaddr(m03_axi_awaddr), .awlen(m03_axi_awlen),
    .awsize(m03_axi_awsize), .awburst(m03_axi_awburst), .awlock(m03_axi_awlock),
    .awcache(m03_axi_awcache), .awprot(m03_axi_awprot), .awqos(m03_axi_awqos),
    .awuser(m03_axi_awuser), .awvalid(m03_axi_awvalid), .awready(m03_axi_awready),
    .wdata(m03_axi_wdata), .wstrb(m03_axi_wstrb), .wlast(m03_axi_wlast),
    .wuser(m03_axi_wuser), .wvalid(m03_axi_wvalid), .wready(m03_axi_wready),
    .bid(m03_axi_bid), .bresp(m03_axi_bresp), .buser(m03_axi_buser),
    .bvalid(m03_axi_bvalid), .bready(m03_axi_bready),
    .arid(m03_axi_arid), .araddr(m03_axi_araddr), .arlen(m03_axi_arlen),
    .arsize(m03_axi_arsize), .arburst(m03_axi_arburst), .arlock(m03_axi_arlock),
    .arcache(m03_axi_arcache), .arprot(m03_axi_arprot), .arqos(m03_axi_arqos),
    .aruser(m03_axi_aruser), .arvalid(m03_axi_arvalid), .arready(m03_axi_arready),
    .rid(m03_axi_rid), .rdata(m03_axi_rdata), .rresp(m03_axi_rresp),
    .rlast(m03_axi_rlast), .ruser(m03_axi_ruser), .rvalid(m03_axi_rvalid),
    .rready(m03_axi_rready)
);

axi_slave_model #(.SLAVE_ID(4), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
    .ID_WIDTH(ID_WIDTH), .STRB_WIDTH(STRB_WIDTH)) slave4 (
    .clk(clk), .rst(rst),
    .awid(m04_axi_awid), .awaddr(m04_axi_awaddr), .awlen(m04_axi_awlen),
    .awsize(m04_axi_awsize), .awburst(m04_axi_awburst), .awlock(m04_axi_awlock),
    .awcache(m04_axi_awcache), .awprot(m04_axi_awprot), .awqos(m04_axi_awqos),
    .awuser(m04_axi_awuser), .awvalid(m04_axi_awvalid), .awready(m04_axi_awready),
    .wdata(m04_axi_wdata), .wstrb(m04_axi_wstrb), .wlast(m04_axi_wlast),
    .wuser(m04_axi_wuser), .wvalid(m04_axi_wvalid), .wready(m04_axi_wready),
    .bid(m04_axi_bid), .bresp(m04_axi_bresp), .buser(m04_axi_buser),
    .bvalid(m04_axi_bvalid), .bready(m04_axi_bready),
    .arid(m04_axi_arid), .araddr(m04_axi_araddr), .arlen(m04_axi_arlen),
    .arsize(m04_axi_arsize), .arburst(m04_axi_arburst), .arlock(m04_axi_arlock),
    .arcache(m04_axi_arcache), .arprot(m04_axi_arprot), .arqos(m04_axi_arqos),
    .aruser(m04_axi_aruser), .arvalid(m04_axi_arvalid), .arready(m04_axi_arready),
    .rid(m04_axi_rid), .rdata(m04_axi_rdata), .rresp(m04_axi_rresp),
    .rlast(m04_axi_rlast), .ruser(m04_axi_ruser), .rvalid(m04_axi_rvalid),
    .rready(m04_axi_rready)
);

axi_slave_model #(.SLAVE_ID(5), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
    .ID_WIDTH(ID_WIDTH), .STRB_WIDTH(STRB_WIDTH)) slave5 (
    .clk(clk), .rst(rst),
    .awid(m05_axi_awid), .awaddr(m05_axi_awaddr), .awlen(m05_axi_awlen),
    .awsize(m05_axi_awsize), .awburst(m05_axi_awburst), .awlock(m05_axi_awlock),
    .awcache(m05_axi_awcache), .awprot(m05_axi_awprot), .awqos(m05_axi_awqos),
    .awuser(m05_axi_awuser), .awvalid(m05_axi_awvalid), .awready(m05_axi_awready),
    .wdata(m05_axi_wdata), .wstrb(m05_axi_wstrb), .wlast(m05_axi_wlast),
    .wuser(m05_axi_wuser), .wvalid(m05_axi_wvalid), .wready(m05_axi_wready),
    .bid(m05_axi_bid), .bresp(m05_axi_bresp), .buser(m05_axi_buser),
    .bvalid(m05_axi_bvalid), .bready(m05_axi_bready),
    .arid(m05_axi_arid), .araddr(m05_axi_araddr), .arlen(m05_axi_arlen),
    .arsize(m05_axi_arsize), .arburst(m05_axi_arburst), .arlock(m05_axi_arlock),
    .arcache(m05_axi_arcache), .arprot(m05_axi_arprot), .arqos(m05_axi_arqos),
    .aruser(m05_axi_aruser), .arvalid(m05_axi_arvalid), .arready(m05_axi_arready),
    .rid(m05_axi_rid), .rdata(m05_axi_rdata), .rresp(m05_axi_rresp),
    .rlast(m05_axi_rlast), .ruser(m05_axi_ruser), .rvalid(m05_axi_rvalid),
    .rready(m05_axi_rready)
);

axi_slave_model #(.SLAVE_ID(6), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
    .ID_WIDTH(ID_WIDTH), .STRB_WIDTH(STRB_WIDTH)) slave6 (
    .clk(clk), .rst(rst),
    .awid(m06_axi_awid), .awaddr(m06_axi_awaddr), .awlen(m06_axi_awlen),
    .awsize(m06_axi_awsize), .awburst(m06_axi_awburst), .awlock(m06_axi_awlock),
    .awcache(m06_axi_awcache), .awprot(m06_axi_awprot), .awqos(m06_axi_awqos),
    .awuser(m06_axi_awuser), .awvalid(m06_axi_awvalid), .awready(m06_axi_awready),
    .wdata(m06_axi_wdata), .wstrb(m06_axi_wstrb), .wlast(m06_axi_wlast),
    .wuser(m06_axi_wuser), .wvalid(m06_axi_wvalid), .wready(m06_axi_wready),
    .bid(m06_axi_bid), .bresp(m06_axi_bresp), .buser(m06_axi_buser),
    .bvalid(m06_axi_bvalid), .bready(m06_axi_bready),
    .arid(m06_axi_arid), .araddr(m06_axi_araddr), .arlen(m06_axi_arlen),
    .arsize(m06_axi_arsize), .arburst(m06_axi_arburst), .arlock(m06_axi_arlock),
    .arcache(m06_axi_arcache), .arprot(m06_axi_arprot), .arqos(m06_axi_arqos),
    .aruser(m06_axi_aruser), .arvalid(m06_axi_arvalid), .arready(m06_axi_arready),
    .rid(m06_axi_rid), .rdata(m06_axi_rdata), .rresp(m06_axi_rresp),
    .rlast(m06_axi_rlast), .ruser(m06_axi_ruser), .rvalid(m06_axi_rvalid),
    .rready(m06_axi_rready)
);

// =============================================================================
// Scoreboard (empty module with tasks — no ports)
// =============================================================================
axi_scoreboard scoreboard();

// =============================================================================
// AXI Protocol Assertions — one instance per upstream interface (s*_axi)
// and one per downstream interface (m*_axi)
// =============================================================================

// Upstream assertions
axi_assertions #(.LABEL("s00")) axi_chk_s00 (
    .clk(clk), .rst(rst),
    .awid(s00_axi_awid), .awaddr(s00_axi_awaddr), .awlen(s00_axi_awlen),
    .awvalid(s00_axi_awvalid), .awready(s00_axi_awready),
    .wdata(s00_axi_wdata), .wstrb(s00_axi_wstrb), .wlast(s00_axi_wlast),
    .wvalid(s00_axi_wvalid), .wready(s00_axi_wready),
    .bid(s00_axi_bid), .bresp(s00_axi_bresp), .bvalid(s00_axi_bvalid), .bready(s00_axi_bready),
    .arid(s00_axi_arid), .araddr(s00_axi_araddr), .arlen(s00_axi_arlen),
    .arvalid(s00_axi_arvalid), .arready(s00_axi_arready),
    .rid(s00_axi_rid), .rdata(s00_axi_rdata), .rresp(s00_axi_rresp),
    .rlast(s00_axi_rlast), .rvalid(s00_axi_rvalid), .rready(s00_axi_rready)
);

axi_assertions #(.LABEL("s01")) axi_chk_s01 (
    .clk(clk), .rst(rst),
    .awid(s01_axi_awid), .awaddr(s01_axi_awaddr), .awlen(s01_axi_awlen),
    .awvalid(s01_axi_awvalid), .awready(s01_axi_awready),
    .wdata(s01_axi_wdata), .wstrb(s01_axi_wstrb), .wlast(s01_axi_wlast),
    .wvalid(s01_axi_wvalid), .wready(s01_axi_wready),
    .bid(s01_axi_bid), .bresp(s01_axi_bresp), .bvalid(s01_axi_bvalid), .bready(s01_axi_bready),
    .arid(s01_axi_arid), .araddr(s01_axi_araddr), .arlen(s01_axi_arlen),
    .arvalid(s01_axi_arvalid), .arready(s01_axi_arready),
    .rid(s01_axi_rid), .rdata(s01_axi_rdata), .rresp(s01_axi_rresp),
    .rlast(s01_axi_rlast), .rvalid(s01_axi_rvalid), .rready(s01_axi_rready)
);

axi_assertions #(.LABEL("s02")) axi_chk_s02 (
    .clk(clk), .rst(rst),
    .awid(s02_axi_awid), .awaddr(s02_axi_awaddr), .awlen(s02_axi_awlen),
    .awvalid(s02_axi_awvalid), .awready(s02_axi_awready),
    .wdata(s02_axi_wdata), .wstrb(s02_axi_wstrb), .wlast(s02_axi_wlast),
    .wvalid(s02_axi_wvalid), .wready(s02_axi_wready),
    .bid(s02_axi_bid), .bresp(s02_axi_bresp), .bvalid(s02_axi_bvalid), .bready(s02_axi_bready),
    .arid(s02_axi_arid), .araddr(s02_axi_araddr), .arlen(s02_axi_arlen),
    .arvalid(s02_axi_arvalid), .arready(s02_axi_arready),
    .rid(s02_axi_rid), .rdata(s02_axi_rdata), .rresp(s02_axi_rresp),
    .rlast(s02_axi_rlast), .rvalid(s02_axi_rvalid), .rready(s02_axi_rready)
);

// Downstream assertions (m00..m06)
axi_assertions #(.LABEL("m00")) axi_chk_m00 (
    .clk(clk), .rst(rst),
    .awid(m00_axi_awid), .awaddr(m00_axi_awaddr), .awlen(m00_axi_awlen),
    .awvalid(m00_axi_awvalid), .awready(m00_axi_awready),
    .wdata(m00_axi_wdata), .wstrb(m00_axi_wstrb), .wlast(m00_axi_wlast),
    .wvalid(m00_axi_wvalid), .wready(m00_axi_wready),
    .bid(m00_axi_bid), .bresp(m00_axi_bresp), .bvalid(m00_axi_bvalid), .bready(m00_axi_bready),
    .arid(m00_axi_arid), .araddr(m00_axi_araddr), .arlen(m00_axi_arlen),
    .arvalid(m00_axi_arvalid), .arready(m00_axi_arready),
    .rid(m00_axi_rid), .rdata(m00_axi_rdata), .rresp(m00_axi_rresp),
    .rlast(m00_axi_rlast), .rvalid(m00_axi_rvalid), .rready(m00_axi_rready)
);

axi_assertions #(.LABEL("m01")) axi_chk_m01 (
    .clk(clk), .rst(rst),
    .awid(m01_axi_awid), .awaddr(m01_axi_awaddr), .awlen(m01_axi_awlen),
    .awvalid(m01_axi_awvalid), .awready(m01_axi_awready),
    .wdata(m01_axi_wdata), .wstrb(m01_axi_wstrb), .wlast(m01_axi_wlast),
    .wvalid(m01_axi_wvalid), .wready(m01_axi_wready),
    .bid(m01_axi_bid), .bresp(m01_axi_bresp), .bvalid(m01_axi_bvalid), .bready(m01_axi_bready),
    .arid(m01_axi_arid), .araddr(m01_axi_araddr), .arlen(m01_axi_arlen),
    .arvalid(m01_axi_arvalid), .arready(m01_axi_arready),
    .rid(m01_axi_rid), .rdata(m01_axi_rdata), .rresp(m01_axi_rresp),
    .rlast(m01_axi_rlast), .rvalid(m01_axi_rvalid), .rready(m01_axi_rready)
);

axi_assertions #(.LABEL("m02")) axi_chk_m02 (
    .clk(clk), .rst(rst),
    .awid(m02_axi_awid), .awaddr(m02_axi_awaddr), .awlen(m02_axi_awlen),
    .awvalid(m02_axi_awvalid), .awready(m02_axi_awready),
    .wdata(m02_axi_wdata), .wstrb(m02_axi_wstrb), .wlast(m02_axi_wlast),
    .wvalid(m02_axi_wvalid), .wready(m02_axi_wready),
    .bid(m02_axi_bid), .bresp(m02_axi_bresp), .bvalid(m02_axi_bvalid), .bready(m02_axi_bready),
    .arid(m02_axi_arid), .araddr(m02_axi_araddr), .arlen(m02_axi_arlen),
    .arvalid(m02_axi_arvalid), .arready(m02_axi_arready),
    .rid(m02_axi_rid), .rdata(m02_axi_rdata), .rresp(m02_axi_rresp),
    .rlast(m02_axi_rlast), .rvalid(m02_axi_rvalid), .rready(m02_axi_rready)
);

axi_assertions #(.LABEL("m03")) axi_chk_m03 (
    .clk(clk), .rst(rst),
    .awid(m03_axi_awid), .awaddr(m03_axi_awaddr), .awlen(m03_axi_awlen),
    .awvalid(m03_axi_awvalid), .awready(m03_axi_awready),
    .wdata(m03_axi_wdata), .wstrb(m03_axi_wstrb), .wlast(m03_axi_wlast),
    .wvalid(m03_axi_wvalid), .wready(m03_axi_wready),
    .bid(m03_axi_bid), .bresp(m03_axi_bresp), .bvalid(m03_axi_bvalid), .bready(m03_axi_bready),
    .arid(m03_axi_arid), .araddr(m03_axi_araddr), .arlen(m03_axi_arlen),
    .arvalid(m03_axi_arvalid), .arready(m03_axi_arready),
    .rid(m03_axi_rid), .rdata(m03_axi_rdata), .rresp(m03_axi_rresp),
    .rlast(m03_axi_rlast), .rvalid(m03_axi_rvalid), .rready(m03_axi_rready)
);

axi_assertions #(.LABEL("m04")) axi_chk_m04 (
    .clk(clk), .rst(rst),
    .awid(m04_axi_awid), .awaddr(m04_axi_awaddr), .awlen(m04_axi_awlen),
    .awvalid(m04_axi_awvalid), .awready(m04_axi_awready),
    .wdata(m04_axi_wdata), .wstrb(m04_axi_wstrb), .wlast(m04_axi_wlast),
    .wvalid(m04_axi_wvalid), .wready(m04_axi_wready),
    .bid(m04_axi_bid), .bresp(m04_axi_bresp), .bvalid(m04_axi_bvalid), .bready(m04_axi_bready),
    .arid(m04_axi_arid), .araddr(m04_axi_araddr), .arlen(m04_axi_arlen),
    .arvalid(m04_axi_arvalid), .arready(m04_axi_arready),
    .rid(m04_axi_rid), .rdata(m04_axi_rdata), .rresp(m04_axi_rresp),
    .rlast(m04_axi_rlast), .rvalid(m04_axi_rvalid), .rready(m04_axi_rready)
);

axi_assertions #(.LABEL("m05")) axi_chk_m05 (
    .clk(clk), .rst(rst),
    .awid(m05_axi_awid), .awaddr(m05_axi_awaddr), .awlen(m05_axi_awlen),
    .awvalid(m05_axi_awvalid), .awready(m05_axi_awready),
    .wdata(m05_axi_wdata), .wstrb(m05_axi_wstrb), .wlast(m05_axi_wlast),
    .wvalid(m05_axi_wvalid), .wready(m05_axi_wready),
    .bid(m05_axi_bid), .bresp(m05_axi_bresp), .bvalid(m05_axi_bvalid), .bready(m05_axi_bready),
    .arid(m05_axi_arid), .araddr(m05_axi_araddr), .arlen(m05_axi_arlen),
    .arvalid(m05_axi_arvalid), .arready(m05_axi_arready),
    .rid(m05_axi_rid), .rdata(m05_axi_rdata), .rresp(m05_axi_rresp),
    .rlast(m05_axi_rlast), .rvalid(m05_axi_rvalid), .rready(m05_axi_rready)
);

axi_assertions #(.LABEL("m06")) axi_chk_m06 (
    .clk(clk), .rst(rst),
    .awid(m06_axi_awid), .awaddr(m06_axi_awaddr), .awlen(m06_axi_awlen),
    .awvalid(m06_axi_awvalid), .awready(m06_axi_awready),
    .wdata(m06_axi_wdata), .wstrb(m06_axi_wstrb), .wlast(m06_axi_wlast),
    .wvalid(m06_axi_wvalid), .wready(m06_axi_wready),
    .bid(m06_axi_bid), .bresp(m06_axi_bresp), .bvalid(m06_axi_bvalid), .bready(m06_axi_bready),
    .arid(m06_axi_arid), .araddr(m06_axi_araddr), .arlen(m06_axi_arlen),
    .arvalid(m06_axi_arvalid), .arready(m06_axi_arready),
    .rid(m06_axi_rid), .rdata(m06_axi_rdata), .rresp(m06_axi_rresp),
    .rlast(m06_axi_rlast), .rvalid(m06_axi_rvalid), .rready(m06_axi_rready)
);

// =============================================================================
// Verdi / VCD waveform dump
// =============================================================================
initial begin
    $fsdbDumpfile("tb_top.fsdb");
    $fsdbDumpvars(0, tb_top);
end

// =============================================================================
// Include test tasks (must come after BFM/scoreboard instantiations)
// =============================================================================
`include "tests/reset_test.sv"
`include "tests/basic_rw_test.sv"
`include "tests/all_slaves_test.sv"
`include "tests/multi_master_test.sv"
`include "tests/random_test.sv"

// =============================================================================
// Main stimulus — sequential test execution
// =============================================================================
int global_fail_count;

initial begin
    global_fail_count = 0;

    $display("=========================================================");
    $display(" AXI Interconnect 3x7 Testbench");
    $display(" DUT: axi_interconnect_wrap_3x7");
    $display(" Address map: slave N → 0xN000000 (16 MB windows)");
    $display("=========================================================");

    // ----------------------------------------------------------------
    // TEST 1: RESET
    // ----------------------------------------------------------------
    reset_test(
        clk, rst,
        s00_axi_awvalid, s00_axi_wvalid, s00_axi_arvalid,
        s01_axi_awvalid, s01_axi_wvalid, s01_axi_arvalid,
        s02_axi_awvalid, s02_axi_wvalid, s02_axi_arvalid,
        global_fail_count
    );

    // Extra settling time after reset
    repeat (10) @(posedge clk);

    // ----------------------------------------------------------------
    // TEST 2: MASTER 0 WRITE/READ all 7 slaves
    // ----------------------------------------------------------------
    basic_rw_test_m0(global_fail_count);
    repeat (5) @(posedge clk);

    // ----------------------------------------------------------------
    // TEST 3: MASTER 1 WRITE/READ all 7 slaves
    // ----------------------------------------------------------------
    basic_rw_test_m1(global_fail_count);
    repeat (5) @(posedge clk);

    // ----------------------------------------------------------------
    // TEST 4: MASTER 2 WRITE/READ all 7 slaves
    // ----------------------------------------------------------------
    basic_rw_test_m2(global_fail_count);
    repeat (5) @(posedge clk);

    // ----------------------------------------------------------------
    // TEST 5: ALL SEVEN SLAVES accessed
    // ----------------------------------------------------------------
    all_slaves_test(global_fail_count);
    repeat (5) @(posedge clk);

    // ----------------------------------------------------------------
    // TEST 6: MULTIPLE MASTERS, DIFFERENT SLAVES
    // ----------------------------------------------------------------
    multi_master_test(global_fail_count);
    repeat (5) @(posedge clk);

    // ----------------------------------------------------------------
    // TEST 7: SAME SLAVE FROM MULTIPLE MASTERS
    // ----------------------------------------------------------------
    same_slave_multi_master_test(global_fail_count);
    repeat (5) @(posedge clk);

    // ----------------------------------------------------------------
    // TEST 8: READ TRANSACTIONS
    // ----------------------------------------------------------------
    read_transactions_test(global_fail_count);
    repeat (5) @(posedge clk);

    // ----------------------------------------------------------------
    // TEST 9: WRITE TRANSACTIONS with byte strobes
    // ----------------------------------------------------------------
    write_transactions_test(global_fail_count);
    repeat (5) @(posedge clk);

    // ----------------------------------------------------------------
    // TEST 10: BACK-TO-BACK TRANSACTIONS
    // ----------------------------------------------------------------
    back_to_back_test(global_fail_count);
    repeat (5) @(posedge clk);

    // ----------------------------------------------------------------
    // TEST 11: DIFFERENT DATA VALUES
    // ----------------------------------------------------------------
    different_data_test(global_fail_count);
    repeat (5) @(posedge clk);

    // ----------------------------------------------------------------
    // TEST 12: UNMAPPED ADDRESS
    // ----------------------------------------------------------------
    unmapped_addr_test(global_fail_count);
    repeat (5) @(posedge clk);

    // ----------------------------------------------------------------
    // CONSTRAINED RANDOM TEST
    // ----------------------------------------------------------------
    random_test(global_fail_count);
    repeat (10) @(posedge clk);

    // ----------------------------------------------------------------
    // FINAL SUMMARY
    // ----------------------------------------------------------------
    scoreboard.report();

    $display("");
    $display("=========================================================");
    $display(" FINAL SIMULATION RESULT");
    if (global_fail_count == 0)
        $display(" ALL TESTS PASSED");
    else
        $display(" SIMULATION FAILED — %0d total errors", global_fail_count);
    $display("=========================================================");

    $finish;
end

// =============================================================================
// Simulation watchdog — prevents infinite hang
// =============================================================================
initial begin
    #(TIMEOUT_CYC * 200 * 10ns);
    $display("[WATCHDOG] Simulation exceeded maximum time — forcing $finish");
    $finish;
end

endmodule : tb_top
`default_nettype wire
