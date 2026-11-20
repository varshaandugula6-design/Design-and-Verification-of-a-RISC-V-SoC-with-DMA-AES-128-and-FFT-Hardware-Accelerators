//=============================================================================
// aes_axi_slave_axi4.sv
//
// AXI4-to-AXI4-Lite bridge + AES slave wrapper.
//
// Purpose
// -------
// The 3×15 interconnect (axi_interconnect_wrap_3x15) presents a full AXI4
// interface on each slave port, including burst signals that are absent from
// the AXI4-Lite specification.  aes_axi_slave is AXI4-Lite only.
//
// This module sits between interconnect slave port S5 (m05_axi_*) and the
// aes_axi_slave.  It accepts every AXI4 signal from the interconnect,
// discards burst/lock/cache/qos/region/user/last signals that have no
// meaning for a single-beat peripheral, and drives the AXI4-Lite interface
// expected by aes_axi_slave.
//
// Design rules (identical to how main_top.v handles UART on m04)
// --------------------------------------------------------------
// • Only single-beat (LEN=0) writes and reads are expected.  The bridge
//   does not decompose bursts; AES is a register-mapped peripheral so
//   all transactions from software will be single beats.
// • The bridge is purely combinational / single-cycle registered; no
//   FIFOs are required.
// • AXI4 ID signals (awid, bid, arid, rid) are captured/returned so the
//   interconnect's ID-forwarding logic is satisfied.  The 8-bit IDs
//   expected by the interconnect are sign-extended (zero-extended) from
//   the 8-bit IDs used here.
// • RLAST is driven from RVALID (single-beat: RLAST == RVALID).
//
// Address note
// ------------
// The interconnect delivers the FULL 32-bit address to the slave port.
// e.g. for base 0x8000_7000, a write to KEY0 (offset 0x04) arrives as
// 0x8000_7004.  aes_axi_slave decodes using absolute comparisons against
// CIPHER_BASE_ADDR=0x00000000 and INV_CIPHER_BASE_ADDR=0x00000100, so
// we must subtract the peripheral's AXI base address before passing it
// to the slave.  The AES_PERIPH_BASE parameter captures this offset.
//=============================================================================

`timescale 1ns / 1ps
`default_nettype none

module aes_axi_slave_axi4 #(
    parameter DATA_WIDTH      = 32,
    parameter ADDR_WIDTH      = 32,
    parameter STRB_WIDTH      = (DATA_WIDTH/8),
    parameter ID_WIDTH        = 8,
    parameter AWUSER_WIDTH    = 1,
    parameter WUSER_WIDTH     = 1,
    parameter BUSER_WIDTH     = 1,
    parameter ARUSER_WIDTH    = 1,
    parameter RUSER_WIDTH     = 1,
    // Base address assigned to this peripheral in the SoC address map.
    // Subtracted before forwarding to aes_axi_slave so that slave-internal
    // decode is relative to 0x0000_0000.
    parameter [ADDR_WIDTH-1:0] AES_PERIPH_BASE = 32'h8000_7000
)(
    // -----------------------------------------------------------------
    // Clock / Reset  (active-high synchronous reset, matches main_top)
    // -----------------------------------------------------------------
    input  wire                     clk,
    input  wire                     rst,          // active-high

    // =================================================================
    // AXI4 Slave port  (connects to interconnect m05_axi_* outputs)
    // =================================================================
    // Write address channel
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

    // Write data channel
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]   s_axi_wuser,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,

    // Write response channel
    output wire [ID_WIDTH-1:0]      s_axi_bid,
    output wire [1:0]               s_axi_bresp,
    output wire [BUSER_WIDTH-1:0]   s_axi_buser,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,

    // Read address channel
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

    // Read data channel
    output wire [ID_WIDTH-1:0]      s_axi_rid,
    output wire [DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rlast,
    output wire [RUSER_WIDTH-1:0]   s_axi_ruser,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready
);

    // -----------------------------------------------------------------
    // Internal AXI4-Lite wires connecting bridge logic to aes_axi_slave
    // -----------------------------------------------------------------
    wire                    aes_awready;
    wire                    aes_wready;
    wire [1:0]              aes_bresp;
    wire                    aes_bvalid;
    wire                    aes_arready;
    wire [DATA_WIDTH-1:0]   aes_rdata;
    wire [1:0]              aes_rresp;
    wire                    aes_rvalid;

    // -----------------------------------------------------------------
    // Address translation: subtract the SoC base address so that
    // aes_axi_slave sees addresses relative to 0x0000_0000.
    // e.g.  0x8000_7004  →  0x0000_0004  (KEY0)
    //       0x8000_7104  →  0x0000_0104  (inv KEY0)
    // -----------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] aes_awaddr_local = s_axi_awaddr - AES_PERIPH_BASE;
    wire [ADDR_WIDTH-1:0] aes_araddr_local = s_axi_araddr - AES_PERIPH_BASE;

    // -----------------------------------------------------------------
    // ID capture registers
    // Store the AXI4 transaction IDs so we can return them on B/R.
    // aes_axi_slave itself has no ID ports, so we manage them here.
    // -----------------------------------------------------------------
    reg [ID_WIDTH-1:0]  wr_id_r;
    reg [ID_WIDTH-1:0]  rd_id_r;

    // Capture write ID at AWVALID + AWREADY handshake
    always @(posedge clk) begin
        if (rst)
            wr_id_r <= {ID_WIDTH{1'b0}};
        else if (s_axi_awvalid && aes_awready)
            wr_id_r <= s_axi_awid;
    end

    // Capture read ID at ARVALID + ARREADY handshake
    always @(posedge clk) begin
        if (rst)
            rd_id_r <= {ID_WIDTH{1'b0}};
        else if (s_axi_arvalid && aes_arready)
            rd_id_r <= s_axi_arid;
    end

    // -----------------------------------------------------------------
    // AXI4 → AXI4-Lite signal mapping
    // All AXI4-only signals (len, size, burst, lock, cache, qos,
    // region, user, wlast) are accepted and silently ignored.
    // The core sees only the AXI4-Lite subset.
    // -----------------------------------------------------------------

    // Write address channel: pass addr/valid/prot; return ready from slave
    assign s_axi_awready = aes_awready;

    // Write data channel: pass data/strb/valid; return ready from slave
    assign s_axi_wready  = aes_wready;

    // Write response channel: return slave bresp/bvalid; add AXI4-only sideband
    assign s_axi_bid     = wr_id_r;
    assign s_axi_bresp   = aes_bresp;
    assign s_axi_buser   = {BUSER_WIDTH{1'b0}};
    assign s_axi_bvalid  = aes_bvalid;

    // Read address channel: pass addr/valid; return ready from slave
    assign s_axi_arready = aes_arready;

    // Read data channel: return slave rdata/rresp/rvalid; add AXI4-only sideband
    assign s_axi_rid     = rd_id_r;
    assign s_axi_rdata   = aes_rdata;
    assign s_axi_rresp   = aes_rresp;
    assign s_axi_rlast   = aes_rvalid;   // single-beat: RLAST == RVALID
    assign s_axi_ruser   = {RUSER_WIDTH{1'b0}};
    assign s_axi_rvalid  = aes_rvalid;

    // -----------------------------------------------------------------
    // AES AXI4-Lite slave instantiation
    // -----------------------------------------------------------------
    aes_axi_slave #(
        .C_S_AXI_DATA_WIDTH   (DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH   (ADDR_WIDTH),
        .CIPHER_BASE_ADDR     (32'h0000_0000),
        .INV_CIPHER_BASE_ADDR (32'h0000_0100)
    ) u_aes_axi_slave (
        .S_AXI_ACLK    (clk),
        .S_AXI_ARESETN (~rst),           // aes_axi_slave uses active-low reset

        // Write address channel
        .S_AXI_AWADDR  (aes_awaddr_local),
        .S_AXI_AWVALID (s_axi_awvalid),
        .S_AXI_AWREADY (aes_awready),

        // Write data channel
        .S_AXI_WDATA   (s_axi_wdata),
        .S_AXI_WSTRB   (s_axi_wstrb),
        .S_AXI_WVALID  (s_axi_wvalid),
        .S_AXI_WREADY  (aes_wready),

        // Write response channel
        .S_AXI_BRESP   (aes_bresp),
        .S_AXI_BVALID  (aes_bvalid),
        .S_AXI_BREADY  (s_axi_bready),

        // Read address channel
        .S_AXI_ARADDR  (aes_araddr_local),
        .S_AXI_ARVALID (s_axi_arvalid),
        .S_AXI_ARREADY (aes_arready),

        // Read data channel
        .S_AXI_RDATA   (aes_rdata),
        .S_AXI_RRESP   (aes_rresp),
        .S_AXI_RVALID  (aes_rvalid),
        .S_AXI_RREADY  (s_axi_rready)
    );

endmodule

`default_nettype wire
