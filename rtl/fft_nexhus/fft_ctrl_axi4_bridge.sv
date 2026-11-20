//=============================================================================
// fft_ctrl_axi4_bridge.sv
//
// AXI4 → AXI4-Lite bridge for the FFT control interface (S6 / M06).
//
// Architecture
// ------------
// The 3×15 interconnect presents a full AXI4 slave port on M06.
// fft_ctrl_axil only requires AXI4-Lite (no burst, no ID, no user/last).
//
// This bridge:
//   1. Accepts all AXI4 sideband signals from the interconnect.
//   2. Subtracts FFT_CTRL_BASE (0x8000_8000) from AWADDR/ARADDR so
//      fft_ctrl_axil sees local offsets 0x0000 (CTRL) / 0x0004 (STATUS).
//   3. Drives the 16-bit AXI4-Lite address port expected by fft_ctrl_axil.
//   4. Captures AWID/ARID in registers and returns them as BID/RID so
//      the interconnect's ID-forwarding logic is satisfied.
//   5. Drives RLAST = RVALID (single-beat, no burst decomposition needed).
//   6. Ties BUSER/RUSER to 0 (interconnect BUSER_ENABLE/RUSER_ENABLE = 0).
//
// Address note
//   System 0x8000_8000 → local 0x0000  (CTRL register)
//   System 0x8000_8004 → local 0x0004  (STATUS register)
//=============================================================================

`timescale 1ns/1ps
`default_nettype none

module fft_ctrl_axi4_bridge #(
    parameter DATA_WIDTH    = 32,
    parameter ADDR_WIDTH    = 32,
    parameter STRB_WIDTH    = (DATA_WIDTH/8),
    parameter ID_WIDTH      = 8,
    parameter AWUSER_WIDTH  = 1,
    parameter WUSER_WIDTH   = 1,
    parameter BUSER_WIDTH   = 1,
    parameter ARUSER_WIDTH  = 1,
    parameter RUSER_WIDTH   = 1,
    // SoC base address for the FFT control slave (0x8000_8000).
    // Subtracted before forwarding to fft_ctrl_axil.
    parameter [ADDR_WIDTH-1:0] FFT_CTRL_BASE = 32'h8000_8000,
    // Width of the AXI4-Lite address port of fft_ctrl_axil (= AXI_ADDR_W).
    parameter FFT_AXIL_AW   = 16
)(
    // Clock / Reset  (active-high synchronous reset to match main_top)
    input  wire                     clk,
    input  wire                     rst,

    //------------------------------------------------------------------
    // AXI4 slave port  (from interconnect m06_axi_*)
    //------------------------------------------------------------------
    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awlock,
    input  wire [3:0]               s_axi_awcache,
    input  wire [2:0]               s_axi_awprot,
    input  wire [3:0]               s_axi_awqos,
    input  wire [3:0]               s_axi_awregion,
    input  wire [AWUSER_WIDTH-1:0]  s_axi_awuser,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,

    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]   s_axi_wuser,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,

    output wire [ID_WIDTH-1:0]      s_axi_bid,
    output wire [1:0]               s_axi_bresp,
    output wire [BUSER_WIDTH-1:0]   s_axi_buser,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,

    input  wire [ID_WIDTH-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [7:0]               s_axi_arlen,
    input  wire [2:0]               s_axi_arsize,
    input  wire [1:0]               s_axi_arburst,
    input  wire                     s_axi_arlock,
    input  wire [3:0]               s_axi_arcache,
    input  wire [2:0]               s_axi_arprot,
    input  wire [3:0]               s_axi_arqos,
    input  wire [3:0]               s_axi_arregion,
    input  wire [ARUSER_WIDTH-1:0]  s_axi_aruser,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,

    output wire [ID_WIDTH-1:0]      s_axi_rid,
    output wire [DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rlast,
    output wire [RUSER_WIDTH-1:0]   s_axi_ruser,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready,

    //------------------------------------------------------------------
    // AXI4-Lite master port  (to fft_accel_top S_AXIL_*)
    //------------------------------------------------------------------
    output wire [FFT_AXIL_AW-1:0]  m_axil_awaddr,
    output wire                     m_axil_awvalid,
    input  wire                     m_axil_awready,

    output wire [DATA_WIDTH-1:0]    m_axil_wdata,
    output wire [STRB_WIDTH-1:0]    m_axil_wstrb,
    output wire                     m_axil_wvalid,
    input  wire                     m_axil_wready,

    input  wire [1:0]               m_axil_bresp,
    input  wire                     m_axil_bvalid,
    output wire                     m_axil_bready,

    output wire [FFT_AXIL_AW-1:0]  m_axil_araddr,
    output wire                     m_axil_arvalid,
    input  wire                     m_axil_arready,

    input  wire [DATA_WIDTH-1:0]    m_axil_rdata,
    input  wire [1:0]               m_axil_rresp,
    input  wire                     m_axil_rvalid,
    output wire                     m_axil_rready
);

    //------------------------------------------------------------------
    // Address translation: subtract SoC base, keep lower FFT_AXIL_AW bits
    //------------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] aw_local = s_axi_awaddr - FFT_CTRL_BASE;
    wire [ADDR_WIDTH-1:0] ar_local = s_axi_araddr - FFT_CTRL_BASE;

    //------------------------------------------------------------------
    // ID capture registers (AXI4-Lite has no IDs; we manage them here)
    //------------------------------------------------------------------
    reg [ID_WIDTH-1:0] wr_id_r;
    reg [ID_WIDTH-1:0] rd_id_r;

    always @(posedge clk) begin
        if (rst) begin
            wr_id_r <= {ID_WIDTH{1'b0}};
            rd_id_r <= {ID_WIDTH{1'b0}};
        end else begin
            // Capture at AW handshake
            if (s_axi_awvalid && m_axil_awready)
                wr_id_r <= s_axi_awid;
            // Capture at AR handshake
            if (s_axi_arvalid && m_axil_arready)
                rd_id_r <= s_axi_arid;
        end
    end

    //------------------------------------------------------------------
    // Write address channel
    //------------------------------------------------------------------
    assign m_axil_awaddr  = aw_local[FFT_AXIL_AW-1:0];
    assign m_axil_awvalid = s_axi_awvalid;
    assign s_axi_awready  = m_axil_awready;

    //------------------------------------------------------------------
    // Write data channel
    //------------------------------------------------------------------
    assign m_axil_wdata   = s_axi_wdata;
    assign m_axil_wstrb   = s_axi_wstrb;
    assign m_axil_wvalid  = s_axi_wvalid;
    assign s_axi_wready   = m_axil_wready;

    //------------------------------------------------------------------
    // Write response channel (add AXI4 ID/user sidebands)
    //------------------------------------------------------------------
    assign s_axi_bid      = wr_id_r;
    assign s_axi_bresp    = m_axil_bresp;
    assign s_axi_buser    = {BUSER_WIDTH{1'b0}};
    assign s_axi_bvalid   = m_axil_bvalid;
    assign m_axil_bready  = s_axi_bready;

    //------------------------------------------------------------------
    // Read address channel
    //------------------------------------------------------------------
    assign m_axil_araddr  = ar_local[FFT_AXIL_AW-1:0];
    assign m_axil_arvalid = s_axi_arvalid;
    assign s_axi_arready  = m_axil_arready;

    //------------------------------------------------------------------
    // Read data channel (add AXI4 ID/RLAST/user sidebands)
    //------------------------------------------------------------------
    assign s_axi_rid      = rd_id_r;
    assign s_axi_rdata    = m_axil_rdata;
    assign s_axi_rresp    = m_axil_rresp;
    assign s_axi_rlast    = m_axil_rvalid;  // single-beat: RLAST == RVALID
    assign s_axi_ruser    = {RUSER_WIDTH{1'b0}};
    assign s_axi_rvalid   = m_axil_rvalid;
    assign m_axil_rready  = s_axi_rready;

endmodule

`default_nettype wire
