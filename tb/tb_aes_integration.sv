//=============================================================================
// tb_aes_integration.sv
//
// AES-128 Integration Testbench
//
// Transaction path verified:
//   AXI Master BFM (M1 / s01_axi_*)
//       ↓
//   3×15 AXI4 Interconnect (axi_interconnect_wrap_3x15)
//       ↓
//   S5 slave port (m05_axi_*) at base address 0x8000_7000
//       ↓
//   AXI4-to-AXI4-Lite bridge (aes_axi_slave_axi4)
//       ↓
//   aes_axi_slave (AXI4-Lite register map)
//       ↓
//   aes_cipher_top / aes_inv_cipher_top (AES-128 encryption / decryption)
//
// Test vectors (FIPS-197 Appendix B):
//   KEY      = 000102030405060708090a0b0c0d0e0f
//   PLAIN    = 00112233445566778899aabbccddeeff
//   CIPHER   = 69c4e0d86a7b0430d8cdb78070b4c55a
//
// Test sequence:
//   1. Reset SoC
//   2. Write KEY registers (cipher)
//   3. Write PLAINTEXT registers (cipher)
//   4. Start encryption (CSR[0] = 1)
//   5. Poll CSR until DONE
//   6. Read CIPHERTEXT; compare to expected
//   7. Write KEY registers (inv cipher)
//   8. Assert KLD for inverse key expansion
//   9. Poll inv CSR until KDONE
//  10. Write CIPHERTEXT as plaintext to inv cipher TEXT_IN
//  11. Start decryption (inv CSR[0] = 1)
//  12. Poll inv CSR until DONE
//  13. Read inv CIPHERTEXT (i.e. decrypted plaintext); compare to original plain
//=============================================================================

`timescale 1ns / 1ps
`default_nettype none

module tb_aes_integration;

    // =========================================================================
    // 1. PARAMETERS
    // =========================================================================
    localparam integer DATA_WIDTH   = 32;
    localparam integer ADDR_WIDTH   = 32;
    localparam integer STRB_WIDTH   = DATA_WIDTH/8;
    localparam integer ID_WIDTH     = 8;
    localparam integer AWUSER_WIDTH = 1;
    localparam integer WUSER_WIDTH  = 1;
    localparam integer BUSER_WIDTH  = 1;
    localparam integer ARUSER_WIDTH = 1;
    localparam integer RUSER_WIDTH  = 1;

    // AES base address (must match main_top M05_BASE_ADDR)
    localparam logic [31:0] AES_BASE        = 32'h8000_7000;
    localparam logic [31:0] AES_INV_OFFSET  = 32'h0000_0100;  // inv cipher region

    // AES register offsets (byte)
    localparam logic [31:0] OFS_CSR  = 32'h00;
    localparam logic [31:0] OFS_KEY0 = 32'h04;
    localparam logic [31:0] OFS_KEY1 = 32'h08;
    localparam logic [31:0] OFS_KEY2 = 32'h0C;
    localparam logic [31:0] OFS_KEY3 = 32'h10;
    localparam logic [31:0] OFS_TIN0 = 32'h14;
    localparam logic [31:0] OFS_TIN1 = 32'h18;
    localparam logic [31:0] OFS_TIN2 = 32'h1C;
    localparam logic [31:0] OFS_TIN3 = 32'h20;
    localparam logic [31:0] OFS_TOUT0= 32'h24;
    localparam logic [31:0] OFS_TOUT1= 32'h28;
    localparam logic [31:0] OFS_TOUT2= 32'h2C;
    localparam logic [31:0] OFS_TOUT3= 32'h30;

    // FIPS-197 Appendix B test vector
    // key[127:0]  = 000102030405060708090a0b0c0d0e0f
    // plain[127:0]= 00112233445566778899aabbccddeeff
    // cipher[127:0]=69c4e0d86a7b0430d8cdb78070b4c55a
    //
    // aes_axi_slave stores:
    //   key   = {key3, key2, key1, key0}  → key[127:0]
    //   tin   = {tin3, tin2, tin1, tin0}  → text_in[127:0]
    // so:
    //   key0 = key[31:0]   = 0c0d0e0f
    //   key1 = key[63:32]  = 08090a0b
    //   key2 = key[95:64]  = 04050607
    //   key3 = key[127:96] = 00010203
    //
    //   tin0 = plain[31:0]   = ccddeeff
    //   tin1 = plain[63:32]  = 8899aabb
    //   tin2 = plain[95:64]  = 44556677
    //   tin3 = plain[127:96] = 00112233
    //
    //   expected tout0 = cipher[31:0]   = 70b4c55a
    //   expected tout1 = cipher[63:32]  = d8cdb780
    //   expected tout2 = cipher[95:64]  = 6a7b0430
    //   expected tout3 = cipher[127:96] = 69c4e0d8

    localparam logic [31:0] KEY0 = 32'h0c0d0e0f;
    localparam logic [31:0] KEY1 = 32'h08090a0b;
    localparam logic [31:0] KEY2 = 32'h04050607;
    localparam logic [31:0] KEY3 = 32'h00010203;

    localparam logic [31:0] TIN0 = 32'hccddeeff;
    localparam logic [31:0] TIN1 = 32'h8899aabb;
    localparam logic [31:0] TIN2 = 32'h44556677;
    localparam logic [31:0] TIN3 = 32'h00112233;

    localparam logic [31:0] EXP_TOUT0 = 32'h70b4c55a;
    localparam logic [31:0] EXP_TOUT1 = 32'hd8cdb780;
    localparam logic [31:0] EXP_TOUT2 = 32'h6a7b0430;
    localparam logic [31:0] EXP_TOUT3 = 32'h69c4e0d8;

    // After decryption the outputs should match the original plaintext
    localparam logic [31:0] EXP_INV_TOUT0 = TIN0;
    localparam logic [31:0] EXP_INV_TOUT1 = TIN1;
    localparam logic [31:0] EXP_INV_TOUT2 = TIN2;
    localparam logic [31:0] EXP_INV_TOUT3 = TIN3;

    // Timeout (max cycles before declaring a deadlock)
    localparam integer TIMEOUT_CYCLES = 500_000;

    // =========================================================================
    // 2. CLOCK / RESET
    // =========================================================================
    logic clk;
    logic fixed_clk;
    logic rst;

    initial begin clk = 1'b0; forever #5.0  clk      = ~clk;      end
    initial begin fixed_clk = 1'b0; #3.125; forever #12.5 fixed_clk = ~fixed_clk; end

    // =========================================================================
    // 3. DUT I/O SIGNALS
    // =========================================================================

    // UART (unused in this TB but required by main_top port list)
    logic uart_rx;
    wire  uart_tx;
    wire  uart_irq;

    // --- Master 0 (tied off, not used) ---
    logic [ID_WIDTH-1:0]     m0_awid    = '0;
    logic [ADDR_WIDTH-1:0]   m0_awaddr  = '0;
    logic [7:0]              m0_awlen   = '0;
    logic [2:0]              m0_awsize  = '0;
    logic [1:0]              m0_awburst = 2'b01;
    logic                    m0_awlock  = '0;
    logic [3:0]              m0_awcache = '0;
    logic [2:0]              m0_awprot  = '0;
    logic [3:0]              m0_awqos   = '0;
    logic [AWUSER_WIDTH-1:0] m0_awuser  = '0;
    logic                    m0_awvalid = '0;
    wire                     m0_awready;
    logic [DATA_WIDTH-1:0]   m0_wdata   = '0;
    logic [STRB_WIDTH-1:0]   m0_wstrb   = '0;
    logic                    m0_wlast   = '0;
    logic [WUSER_WIDTH-1:0]  m0_wuser   = '0;
    logic                    m0_wvalid  = '0;
    wire                     m0_wready;
    wire  [ID_WIDTH-1:0]     m0_bid;
    wire  [1:0]              m0_bresp;
    wire  [BUSER_WIDTH-1:0]  m0_buser;
    wire                     m0_bvalid;
    logic                    m0_bready  = '0;
    logic [ID_WIDTH-1:0]     m0_arid    = '0;
    logic [ADDR_WIDTH-1:0]   m0_araddr  = '0;
    logic [7:0]              m0_arlen   = '0;
    logic [2:0]              m0_arsize  = '0;
    logic [1:0]              m0_arburst = 2'b01;
    logic                    m0_arlock  = '0;
    logic [3:0]              m0_arcache = '0;
    logic [2:0]              m0_arprot  = '0;
    logic [3:0]              m0_arqos   = '0;
    logic [ARUSER_WIDTH-1:0] m0_aruser  = '0;
    logic                    m0_arvalid = '0;
    wire                     m0_arready;
    wire  [ID_WIDTH-1:0]     m0_rid;
    wire  [DATA_WIDTH-1:0]   m0_rdata;
    wire  [1:0]              m0_rresp;
    wire                     m0_rlast;
    wire  [RUSER_WIDTH-1:0]  m0_ruser;
    wire                     m0_rvalid;
    logic                    m0_rready  = '0;

    // --- Master 1 (primary test master / AXI BFM) ---
    logic [ID_WIDTH-1:0]     m1_awid;
    logic [ADDR_WIDTH-1:0]   m1_awaddr;
    logic [7:0]              m1_awlen;
    logic [2:0]              m1_awsize;
    logic [1:0]              m1_awburst;
    logic                    m1_awlock;
    logic [3:0]              m1_awcache;
    logic [2:0]              m1_awprot;
    logic [3:0]              m1_awqos;
    logic [AWUSER_WIDTH-1:0] m1_awuser;
    logic                    m1_awvalid;
    wire                     m1_awready;
    logic [DATA_WIDTH-1:0]   m1_wdata;
    logic [STRB_WIDTH-1:0]   m1_wstrb;
    logic                    m1_wlast;
    logic [WUSER_WIDTH-1:0]  m1_wuser;
    logic                    m1_wvalid;
    wire                     m1_wready;
    wire  [ID_WIDTH-1:0]     m1_bid;
    wire  [1:0]              m1_bresp;
    wire  [BUSER_WIDTH-1:0]  m1_buser;
    wire                     m1_bvalid;
    logic                    m1_bready;
    logic [ID_WIDTH-1:0]     m1_arid;
    logic [ADDR_WIDTH-1:0]   m1_araddr;
    logic [7:0]              m1_arlen;
    logic [2:0]              m1_arsize;
    logic [1:0]              m1_arburst;
    logic                    m1_arlock;
    logic [3:0]              m1_arcache;
    logic [2:0]              m1_arprot;
    logic [3:0]              m1_arqos;
    logic [ARUSER_WIDTH-1:0] m1_aruser;
    logic                    m1_arvalid;
    wire                     m1_arready;
    wire  [ID_WIDTH-1:0]     m1_rid;
    wire  [DATA_WIDTH-1:0]   m1_rdata;
    wire  [1:0]              m1_rresp;
    wire                     m1_rlast;
    wire  [RUSER_WIDTH-1:0]  m1_ruser;
    wire                     m1_rvalid;
    logic                    m1_rready;

    // --- Master 2 (tied off) ---
    logic [ID_WIDTH-1:0]     m2_awid    = '0;
    logic [ADDR_WIDTH-1:0]   m2_awaddr  = '0;
    logic [7:0]              m2_awlen   = '0;
    logic [2:0]              m2_awsize  = '0;
    logic [1:0]              m2_awburst = 2'b01;
    logic                    m2_awlock  = '0;
    logic [3:0]              m2_awcache = '0;
    logic [2:0]              m2_awprot  = '0;
    logic [3:0]              m2_awqos   = '0;
    logic [AWUSER_WIDTH-1:0] m2_awuser  = '0;
    logic                    m2_awvalid = '0;
    wire                     m2_awready;
    logic [DATA_WIDTH-1:0]   m2_wdata   = '0;
    logic [STRB_WIDTH-1:0]   m2_wstrb   = '0;
    logic                    m2_wlast   = '0;
    logic [WUSER_WIDTH-1:0]  m2_wuser   = '0;
    logic                    m2_wvalid  = '0;
    wire                     m2_wready;
    wire  [ID_WIDTH-1:0]     m2_bid;
    wire  [1:0]              m2_bresp;
    wire  [BUSER_WIDTH-1:0]  m2_buser;
    wire                     m2_bvalid;
    logic                    m2_bready  = '0;
    logic [ID_WIDTH-1:0]     m2_arid    = '0;
    logic [ADDR_WIDTH-1:0]   m2_araddr  = '0;
    logic [7:0]              m2_arlen   = '0;
    logic [2:0]              m2_arsize  = '0;
    logic [1:0]              m2_arburst = 2'b01;
    logic                    m2_arlock  = '0;
    logic [3:0]              m2_arcache = '0;
    logic [2:0]              m2_arprot  = '0;
    logic [3:0]              m2_arqos   = '0;
    logic [ARUSER_WIDTH-1:0] m2_aruser  = '0;
    logic                    m2_arvalid = '0;
    wire                     m2_arready;
    wire  [ID_WIDTH-1:0]     m2_rid;
    wire  [DATA_WIDTH-1:0]   m2_rdata;
    wire  [1:0]              m2_rresp;
    wire                     m2_rlast;
    wire  [RUSER_WIDTH-1:0]  m2_ruser;
    wire                     m2_rvalid;
    logic                    m2_rready  = '0;

    // --- Peripheral slave stubs (S0..S3, S6..S14) ---
    // These are currently not instantiated in main_top when width=0,
    // but the interconnect still has ports for them. Tie all slave
    // response signals to safe idle values.

    // S0..S3 and S6..S14: shared tie-off pattern
    // (main_top exposes them as ports; we provide stub responses)
    wire [ID_WIDTH-1:0]     sm00_awid; wire [ADDR_WIDTH-1:0] sm00_awaddr;
    wire [7:0] sm00_awlen; wire [2:0] sm00_awsize; wire [1:0] sm00_awburst;
    wire sm00_awlock; wire [3:0] sm00_awcache; wire [2:0] sm00_awprot;
    wire [3:0] sm00_awqos; wire [3:0] sm00_awregion;
    wire [AWUSER_WIDTH-1:0] sm00_awuser; wire sm00_awvalid;
    wire [DATA_WIDTH-1:0] sm00_wdata; wire [STRB_WIDTH-1:0] sm00_wstrb;
    wire sm00_wlast; wire [WUSER_WIDTH-1:0] sm00_wuser; wire sm00_wvalid;
    wire sm00_bready;
    wire [ID_WIDTH-1:0] sm00_arid; wire [ADDR_WIDTH-1:0] sm00_araddr;
    wire [7:0] sm00_arlen; wire [2:0] sm00_arsize; wire [1:0] sm00_arburst;
    wire sm00_arlock; wire [3:0] sm00_arcache; wire [2:0] sm00_arprot;
    wire [3:0] sm00_arqos; wire [3:0] sm00_arregion;
    wire [ARUSER_WIDTH-1:0] sm00_aruser; wire sm00_arvalid; wire sm00_rready;

    // S1..S14 stub: just use per-slave tie-off macros via generate loop.
    // For simplicity, declare all needed slave stubs manually since Verilog
    // iteration over port names is not practical without macros.

    // Helper macro to produce stub slave tie-off for unconnected peripherals
    // (tie awready=1, wready=1, bvalid=0, arready=1, rvalid=0)
    // These prevent the interconnect from hanging on unconnected slaves.

    // Rather than repeating 13 copies, use local wires and tie-off assigns.
    // Slaves S0..S3 have real addresses; their stubs respond with OKAY.
    // Slaves S6..S14 are at addr_width=0 (won't be selected), so tie safe.

    // ---- Stub declarations ----
    `define STUB_SLAVE(N) \
        wire [ID_WIDTH-1:0]     sm``N``_bid_w;     \
        wire [DATA_WIDTH-1:0]   sm``N``_rdata_w;   \
        wire [1:0]              sm``N``_rresp_w;   \
        wire [ID_WIDTH-1:0]     sm``N``_rid_w;     \
        assign sm``N``_bid_w   = '0;               \
        assign sm``N``_rdata_w = '0;               \
        assign sm``N``_rresp_w = 2'b00;            \
        assign sm``N``_rid_w   = '0;

    // We use individual wires to connect to main_top port; use a local
    // "stub slave" response block per port. For brevity, define response
    // constants for each port:

    // Slave stub response wires
    // (awready, wready, bvalid=0, bresp, arready, rvalid=0, rresp, rdata, rid, bid, rlast, buser, ruser)

    // =========================================================================
    // 4. DUT INSTANTIATION (main_top)
    // =========================================================================
    // Note: main_top's S5 (m05_axi_*) is now internal - no longer a port.
    //       S4 (UART) is also internal. All other slave ports are still external.
    //       We provide stub responses for all external slave ports.

    main_top #(
        .DATA_WIDTH      (DATA_WIDTH),
        .ADDR_WIDTH      (ADDR_WIDTH),
        .STRB_WIDTH      (STRB_WIDTH),
        .ID_WIDTH        (ID_WIDTH),
        .AWUSER_ENABLE   (0),
        .AWUSER_WIDTH    (AWUSER_WIDTH),
        .WUSER_ENABLE    (0),
        .WUSER_WIDTH     (WUSER_WIDTH),
        .BUSER_ENABLE    (0),
        .BUSER_WIDTH     (BUSER_WIDTH),
        .ARUSER_ENABLE   (0),
        .ARUSER_WIDTH    (ARUSER_WIDTH),
        .RUSER_ENABLE    (0),
        .RUSER_WIDTH     (RUSER_WIDTH),
        // Keep M05 at its new AES address (default in main_top)
        .M05_BASE_ADDR   (32'h8000_7000),
        .M05_ADDR_WIDTH  (32'd12)
    ) u_dut (
        .clk            (clk),
        .fixed_clk      (fixed_clk),
        .rst            (rst),

        .uart_rx        (uart_rx),
        .uart_tx        (uart_tx),
        .uart_irq       (uart_irq),

        // M0 (tied off)
        .s00_axi_awid    (m0_awid),    .s00_axi_awaddr  (m0_awaddr),
        .s00_axi_awlen   (m0_awlen),   .s00_axi_awsize  (m0_awsize),
        .s00_axi_awburst (m0_awburst), .s00_axi_awlock  (m0_awlock),
        .s00_axi_awcache (m0_awcache), .s00_axi_awprot  (m0_awprot),
        .s00_axi_awqos   (m0_awqos),   .s00_axi_awuser  (m0_awuser),
        .s00_axi_awvalid (m0_awvalid), .s00_axi_awready (m0_awready),
        .s00_axi_wdata   (m0_wdata),   .s00_axi_wstrb   (m0_wstrb),
        .s00_axi_wlast   (m0_wlast),   .s00_axi_wuser   (m0_wuser),
        .s00_axi_wvalid  (m0_wvalid),  .s00_axi_wready  (m0_wready),
        .s00_axi_bid     (m0_bid),     .s00_axi_bresp   (m0_bresp),
        .s00_axi_buser   (m0_buser),   .s00_axi_bvalid  (m0_bvalid),
        .s00_axi_bready  (m0_bready),
        .s00_axi_arid    (m0_arid),    .s00_axi_araddr  (m0_araddr),
        .s00_axi_arlen   (m0_arlen),   .s00_axi_arsize  (m0_arsize),
        .s00_axi_arburst (m0_arburst), .s00_axi_arlock  (m0_arlock),
        .s00_axi_arcache (m0_arcache), .s00_axi_arprot  (m0_arprot),
        .s00_axi_arqos   (m0_arqos),   .s00_axi_aruser  (m0_aruser),
        .s00_axi_arvalid (m0_arvalid), .s00_axi_arready (m0_arready),
        .s00_axi_rid     (m0_rid),     .s00_axi_rdata   (m0_rdata),
        .s00_axi_rresp   (m0_rresp),   .s00_axi_rlast   (m0_rlast),
        .s00_axi_ruser   (m0_ruser),   .s00_axi_rvalid  (m0_rvalid),
        .s00_axi_rready  (m0_rready),

        // M1 (primary test master)
        .s01_axi_awid    (m1_awid),    .s01_axi_awaddr  (m1_awaddr),
        .s01_axi_awlen   (m1_awlen),   .s01_axi_awsize  (m1_awsize),
        .s01_axi_awburst (m1_awburst), .s01_axi_awlock  (m1_awlock),
        .s01_axi_awcache (m1_awcache), .s01_axi_awprot  (m1_awprot),
        .s01_axi_awqos   (m1_awqos),   .s01_axi_awuser  (m1_awuser),
        .s01_axi_awvalid (m1_awvalid), .s01_axi_awready (m1_awready),
        .s01_axi_wdata   (m1_wdata),   .s01_axi_wstrb   (m1_wstrb),
        .s01_axi_wlast   (m1_wlast),   .s01_axi_wuser   (m1_wuser),
        .s01_axi_wvalid  (m1_wvalid),  .s01_axi_wready  (m1_wready),
        .s01_axi_bid     (m1_bid),     .s01_axi_bresp   (m1_bresp),
        .s01_axi_buser   (m1_buser),   .s01_axi_bvalid  (m1_bvalid),
        .s01_axi_bready  (m1_bready),
        .s01_axi_arid    (m1_arid),    .s01_axi_araddr  (m1_araddr),
        .s01_axi_arlen   (m1_arlen),   .s01_axi_arsize  (m1_arsize),
        .s01_axi_arburst (m1_arburst), .s01_axi_arlock  (m1_arlock),
        .s01_axi_arcache (m1_arcache), .s01_axi_arprot  (m1_arprot),
        .s01_axi_arqos   (m1_arqos),   .s01_axi_aruser  (m1_aruser),
        .s01_axi_arvalid (m1_arvalid), .s01_axi_arready (m1_arready),
        .s01_axi_rid     (m1_rid),     .s01_axi_rdata   (m1_rdata),
        .s01_axi_rresp   (m1_rresp),   .s01_axi_rlast   (m1_rlast),
        .s01_axi_ruser   (m1_ruser),   .s01_axi_rvalid  (m1_rvalid),
        .s01_axi_rready  (m1_rready),

        // M2 (tied off)
        .s02_axi_awid    (m2_awid),    .s02_axi_awaddr  (m2_awaddr),
        .s02_axi_awlen   (m2_awlen),   .s02_axi_awsize  (m2_awsize),
        .s02_axi_awburst (m2_awburst), .s02_axi_awlock  (m2_awlock),
        .s02_axi_awcache (m2_awcache), .s02_axi_awprot  (m2_awprot),
        .s02_axi_awqos   (m2_awqos),   .s02_axi_awuser  (m2_awuser),
        .s02_axi_awvalid (m2_awvalid), .s02_axi_awready (m2_awready),
        .s02_axi_wdata   (m2_wdata),   .s02_axi_wstrb   (m2_wstrb),
        .s02_axi_wlast   (m2_wlast),   .s02_axi_wuser   (m2_wuser),
        .s02_axi_wvalid  (m2_wvalid),  .s02_axi_wready  (m2_wready),
        .s02_axi_bid     (m2_bid),     .s02_axi_bresp   (m2_bresp),
        .s02_axi_buser   (m2_buser),   .s02_axi_bvalid  (m2_bvalid),
        .s02_axi_bready  (m2_bready),
        .s02_axi_arid    (m2_arid),    .s02_axi_araddr  (m2_araddr),
        .s02_axi_arlen   (m2_arlen),   .s02_axi_arsize  (m2_arsize),
        .s02_axi_arburst (m2_arburst), .s02_axi_arlock  (m2_arlock),
        .s02_axi_arcache (m2_arcache), .s02_axi_arprot  (m2_arprot),
        .s02_axi_arqos   (m2_arqos),   .s02_axi_aruser  (m2_aruser),
        .s02_axi_arvalid (m2_arvalid), .s02_axi_arready (m2_arready),
        .s02_axi_rid     (m2_rid),     .s02_axi_rdata   (m2_rdata),
        .s02_axi_rresp   (m2_rresp),   .s02_axi_rlast   (m2_rlast),
        .s02_axi_ruser   (m2_ruser),   .s02_axi_rvalid  (m2_rvalid),
        .s02_axi_rready  (m2_rready),

        // S0: IMEM stub
        .m00_axi_awid    (), .m00_axi_awaddr  (), .m00_axi_awlen   (),
        .m00_axi_awsize  (), .m00_axi_awburst (), .m00_axi_awlock  (),
        .m00_axi_awcache (), .m00_axi_awprot  (), .m00_axi_awqos   (),
        .m00_axi_awregion(), .m00_axi_awuser  (), .m00_axi_awvalid (),
        .m00_axi_awready (1'b1),
        .m00_axi_wdata   (), .m00_axi_wstrb   (), .m00_axi_wlast   (),
        .m00_axi_wuser   (), .m00_axi_wvalid  (), .m00_axi_wready  (1'b1),
        .m00_axi_bid     (8'h00), .m00_axi_bresp   (2'b00),
        .m00_axi_buser   (1'b0),  .m00_axi_bvalid  (1'b0),
        .m00_axi_bready  (),
        .m00_axi_arid    (), .m00_axi_araddr  (), .m00_axi_arlen   (),
        .m00_axi_arsize  (), .m00_axi_arburst (), .m00_axi_arlock  (),
        .m00_axi_arcache (), .m00_axi_arprot  (), .m00_axi_arqos   (),
        .m00_axi_arregion(), .m00_axi_aruser  (), .m00_axi_arvalid (),
        .m00_axi_arready (1'b1),
        .m00_axi_rid     (8'h00), .m00_axi_rdata   (32'h0),
        .m00_axi_rresp   (2'b00), .m00_axi_rlast   (1'b0),
        .m00_axi_ruser   (1'b0),  .m00_axi_rvalid  (1'b0),
        .m00_axi_rready  (),

        // S1: DMEM stub
        .m01_axi_awid    (), .m01_axi_awaddr  (), .m01_axi_awlen   (),
        .m01_axi_awsize  (), .m01_axi_awburst (), .m01_axi_awlock  (),
        .m01_axi_awcache (), .m01_axi_awprot  (), .m01_axi_awqos   (),
        .m01_axi_awregion(), .m01_axi_awuser  (), .m01_axi_awvalid (),
        .m01_axi_awready (1'b1),
        .m01_axi_wdata   (), .m01_axi_wstrb   (), .m01_axi_wlast   (),
        .m01_axi_wuser   (), .m01_axi_wvalid  (), .m01_axi_wready  (1'b1),
        .m01_axi_bid     (8'h00), .m01_axi_bresp   (2'b00),
        .m01_axi_buser   (1'b0),  .m01_axi_bvalid  (1'b0),
        .m01_axi_bready  (),
        .m01_axi_arid    (), .m01_axi_araddr  (), .m01_axi_arlen   (),
        .m01_axi_arsize  (), .m01_axi_arburst (), .m01_axi_arlock  (),
        .m01_axi_arcache (), .m01_axi_arprot  (), .m01_axi_arqos   (),
        .m01_axi_arregion(), .m01_axi_aruser  (), .m01_axi_arvalid (),
        .m01_axi_arready (1'b1),
        .m01_axi_rid     (8'h00), .m01_axi_rdata   (32'h0),
        .m01_axi_rresp   (2'b00), .m01_axi_rlast   (1'b0),
        .m01_axi_ruser   (1'b0),  .m01_axi_rvalid  (1'b0),
        .m01_axi_rready  (),

        // S2 (GPIO), S3 (Timer), S6 (FFT Control), S7 (FFT Memory) are internal to main_top -- no external ports.

        .m08_axi_awid    (), .m08_axi_awaddr  (), .m08_axi_awlen   (),
        .m08_axi_awsize  (), .m08_axi_awburst (), .m08_axi_awlock  (),
        .m08_axi_awcache (), .m08_axi_awprot  (), .m08_axi_awqos   (),
        .m08_axi_awregion(), .m08_axi_awuser  (), .m08_axi_awvalid (),
        .m08_axi_awready (1'b1),
        .m08_axi_wdata   (), .m08_axi_wstrb   (), .m08_axi_wlast   (),
        .m08_axi_wuser   (), .m08_axi_wvalid  (), .m08_axi_wready  (1'b1),
        .m08_axi_bid     (8'h00), .m08_axi_bresp   (2'b00),
        .m08_axi_buser   (1'b0),  .m08_axi_bvalid  (1'b0),
        .m08_axi_bready  (),
        .m08_axi_arid    (), .m08_axi_araddr  (), .m08_axi_arlen   (),
        .m08_axi_arsize  (), .m08_axi_arburst (), .m08_axi_arlock  (),
        .m08_axi_arcache (), .m08_axi_arprot  (), .m08_axi_arqos   (),
        .m08_axi_arregion(), .m08_axi_aruser  (), .m08_axi_arvalid (),
        .m08_axi_arready (1'b1),
        .m08_axi_rid     (8'h00), .m08_axi_rdata   (32'h0),
        .m08_axi_rresp   (2'b00), .m08_axi_rlast   (1'b0),
        .m08_axi_ruser   (1'b0),  .m08_axi_rvalid  (1'b0),
        .m08_axi_rready  (),

        .m09_axi_awid    (), .m09_axi_awaddr  (), .m09_axi_awlen   (),
        .m09_axi_awsize  (), .m09_axi_awburst (), .m09_axi_awlock  (),
        .m09_axi_awcache (), .m09_axi_awprot  (), .m09_axi_awqos   (),
        .m09_axi_awregion(), .m09_axi_awuser  (), .m09_axi_awvalid (),
        .m09_axi_awready (1'b1),
        .m09_axi_wdata   (), .m09_axi_wstrb   (), .m09_axi_wlast   (),
        .m09_axi_wuser   (), .m09_axi_wvalid  (), .m09_axi_wready  (1'b1),
        .m09_axi_bid     (8'h00), .m09_axi_bresp   (2'b00),
        .m09_axi_buser   (1'b0),  .m09_axi_bvalid  (1'b0),
        .m09_axi_bready  (),
        .m09_axi_arid    (), .m09_axi_araddr  (), .m09_axi_arlen   (),
        .m09_axi_arsize  (), .m09_axi_arburst (), .m09_axi_arlock  (),
        .m09_axi_arcache (), .m09_axi_arprot  (), .m09_axi_arqos   (),
        .m09_axi_arregion(), .m09_axi_aruser  (), .m09_axi_arvalid (),
        .m09_axi_arready (1'b1),
        .m09_axi_rid     (8'h00), .m09_axi_rdata   (32'h0),
        .m09_axi_rresp   (2'b00), .m09_axi_rlast   (1'b0),
        .m09_axi_ruser   (1'b0),  .m09_axi_rvalid  (1'b0),
        .m09_axi_rready  (),

        .m10_axi_awid    (), .m10_axi_awaddr  (), .m10_axi_awlen   (),
        .m10_axi_awsize  (), .m10_axi_awburst (), .m10_axi_awlock  (),
        .m10_axi_awcache (), .m10_axi_awprot  (), .m10_axi_awqos   (),
        .m10_axi_awregion(), .m10_axi_awuser  (), .m10_axi_awvalid (),
        .m10_axi_awready (1'b1),
        .m10_axi_wdata   (), .m10_axi_wstrb   (), .m10_axi_wlast   (),
        .m10_axi_wuser   (), .m10_axi_wvalid  (), .m10_axi_wready  (1'b1),
        .m10_axi_bid     (8'h00), .m10_axi_bresp   (2'b00),
        .m10_axi_buser   (1'b0),  .m10_axi_bvalid  (1'b0),
        .m10_axi_bready  (),
        .m10_axi_arid    (), .m10_axi_araddr  (), .m10_axi_arlen   (),
        .m10_axi_arsize  (), .m10_axi_arburst (), .m10_axi_arlock  (),
        .m10_axi_arcache (), .m10_axi_arprot  (), .m10_axi_arqos   (),
        .m10_axi_arregion(), .m10_axi_aruser  (), .m10_axi_arvalid (),
        .m10_axi_arready (1'b1),
        .m10_axi_rid     (8'h00), .m10_axi_rdata   (32'h0),
        .m10_axi_rresp   (2'b00), .m10_axi_rlast   (1'b0),
        .m10_axi_ruser   (1'b0),  .m10_axi_rvalid  (1'b0),
        .m10_axi_rready  (),

        .m11_axi_awid    (), .m11_axi_awaddr  (), .m11_axi_awlen   (),
        .m11_axi_awsize  (), .m11_axi_awburst (), .m11_axi_awlock  (),
        .m11_axi_awcache (), .m11_axi_awprot  (), .m11_axi_awqos   (),
        .m11_axi_awregion(), .m11_axi_awuser  (), .m11_axi_awvalid (),
        .m11_axi_awready (1'b1),
        .m11_axi_wdata   (), .m11_axi_wstrb   (), .m11_axi_wlast   (),
        .m11_axi_wuser   (), .m11_axi_wvalid  (), .m11_axi_wready  (1'b1),
        .m11_axi_bid     (8'h00), .m11_axi_bresp   (2'b00),
        .m11_axi_buser   (1'b0),  .m11_axi_bvalid  (1'b0),
        .m11_axi_bready  (),
        .m11_axi_arid    (), .m11_axi_araddr  (), .m11_axi_arlen   (),
        .m11_axi_arsize  (), .m11_axi_arburst (), .m11_axi_arlock  (),
        .m11_axi_arcache (), .m11_axi_arprot  (), .m11_axi_arqos   (),
        .m11_axi_arregion(), .m11_axi_aruser  (), .m11_axi_arvalid (),
        .m11_axi_arready (1'b1),
        .m11_axi_rid     (8'h00), .m11_axi_rdata   (32'h0),
        .m11_axi_rresp   (2'b00), .m11_axi_rlast   (1'b0),
        .m11_axi_ruser   (1'b0),  .m11_axi_rvalid  (1'b0),
        .m11_axi_rready  (),

        .m12_axi_awid    (), .m12_axi_awaddr  (), .m12_axi_awlen   (),
        .m12_axi_awsize  (), .m12_axi_awburst (), .m12_axi_awlock  (),
        .m12_axi_awcache (), .m12_axi_awprot  (), .m12_axi_awqos   (),
        .m12_axi_awregion(), .m12_axi_awuser  (), .m12_axi_awvalid (),
        .m12_axi_awready (1'b1),
        .m12_axi_wdata   (), .m12_axi_wstrb   (), .m12_axi_wlast   (),
        .m12_axi_wuser   (), .m12_axi_wvalid  (), .m12_axi_wready  (1'b1),
        .m12_axi_bid     (8'h00), .m12_axi_bresp   (2'b00),
        .m12_axi_buser   (1'b0),  .m12_axi_bvalid  (1'b0),
        .m12_axi_bready  (),
        .m12_axi_arid    (), .m12_axi_araddr  (), .m12_axi_arlen   (),
        .m12_axi_arsize  (), .m12_axi_arburst (), .m12_axi_arlock  (),
        .m12_axi_arcache (), .m12_axi_arprot  (), .m12_axi_arqos   (),
        .m12_axi_arregion(), .m12_axi_aruser  (), .m12_axi_arvalid (),
        .m12_axi_arready (1'b1),
        .m12_axi_rid     (8'h00), .m12_axi_rdata   (32'h0),
        .m12_axi_rresp   (2'b00), .m12_axi_rlast   (1'b0),
        .m12_axi_ruser   (1'b0),  .m12_axi_rvalid  (1'b0),
        .m12_axi_rready  (),

        // S13 (DMA CSR) is internal to main_top -- no external port.

        .m14_axi_awid    (), .m14_axi_awaddr  (), .m14_axi_awlen   (),
        .m14_axi_awsize  (), .m14_axi_awburst (), .m14_axi_awlock  (),
        .m14_axi_awcache (), .m14_axi_awprot  (), .m14_axi_awqos   (),
        .m14_axi_awregion(), .m14_axi_awuser  (), .m14_axi_awvalid (),
        .m14_axi_awready (1'b1),
        .m14_axi_wdata   (), .m14_axi_wstrb   (), .m14_axi_wlast   (),
        .m14_axi_wuser   (), .m14_axi_wvalid  (), .m14_axi_wready  (1'b1),
        .m14_axi_bid     (8'h00), .m14_axi_bresp   (2'b00),
        .m14_axi_buser   (1'b0),  .m14_axi_bvalid  (1'b0),
        .m14_axi_bready  (),
        .m14_axi_arid    (), .m14_axi_araddr  (), .m14_axi_arlen   (),
        .m14_axi_arsize  (), .m14_axi_arburst (), .m14_axi_arlock  (),
        .m14_axi_arcache (), .m14_axi_arprot  (), .m14_axi_arqos   (),
        .m14_axi_arregion(), .m14_axi_aruser  (), .m14_axi_arvalid (),
        .m14_axi_arready (1'b1),
        .m14_axi_rid     (8'h00), .m14_axi_rdata   (32'h0),
        .m14_axi_rresp   (2'b00), .m14_axi_rlast   (1'b0),
        .m14_axi_ruser   (1'b0),  .m14_axi_rvalid  (1'b0),
        .m14_axi_rready  (),

        // Dedicated GPIO and Timer
        .gpio_io         (),
        .gpio_irq        (),
        .timer_pwm       (),
        .timer_irq       (),

        // Completion interrupts
        .fft_irq         (),
        .dma_irq         (),
        .dma_error_irq   ()
    );

    // =========================================================================
    // 5. BFM TASKS (AXI4 single-beat write and read via M1 / s01_axi)
    // =========================================================================

    // -------------------------------------------------------------------------
    // axi_write: single-beat AXI4 write via M1
    //   addr  - 32-bit byte address
    //   data  - 32-bit write data
    //   id    - 8-bit transaction ID
    // -------------------------------------------------------------------------
    task automatic axi_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [7:0]  id
    );
        // Drive AW and W channels simultaneously (required for the AES bridge which
        // uses AWVALID && WVALID to issue AWREADY/WREADY together)
        @(posedge clk);
        #1;
        m1_awid    <= id;
        m1_awaddr  <= addr;
        m1_awlen   <= 8'h00;      // single beat
        m1_awsize  <= 3'b010;     // 4 bytes
        m1_awburst <= 2'b01;      // INCR
        m1_awlock  <= 1'b0;
        m1_awcache <= 4'b0000;
        m1_awprot  <= 3'b000;
        m1_awqos   <= 4'h0;
        m1_awuser  <= 1'b0;
        m1_awvalid <= 1'b1;
        m1_wdata   <= data;
        m1_wstrb   <= 4'hf;
        m1_wlast   <= 1'b1;
        m1_wuser   <= 1'b0;
        m1_wvalid  <= 1'b1;
        m1_bready  <= 1'b1;

        // Wait for both AW and W handshakes
        fork
            begin : aw_wait
                while (!m1_awready) @(posedge clk);
            end
            begin : w_wait
                while (!m1_wready) @(posedge clk);
            end
        join

        @(posedge clk); #1;
        m1_awvalid <= 1'b0;
        m1_wvalid  <= 1'b0;
        m1_wlast   <= 1'b0;

        // Wait for B response
        while (!m1_bvalid) @(posedge clk);
        @(posedge clk); #1;
        m1_bready <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // axi_read: single-beat AXI4 read via M1
    //   addr     - 32-bit byte address
    //   id       - 8-bit transaction ID
    //   rdata    - output, data returned
    // -------------------------------------------------------------------------
    task automatic axi_read(
        input  logic [31:0] addr,
        input  logic [7:0]  id,
        output logic [31:0] rdata
    );
        @(posedge clk); #1;
        m1_arid    <= id;
        m1_araddr  <= addr;
        m1_arlen   <= 8'h00;
        m1_arsize  <= 3'b010;
        m1_arburst <= 2'b01;
        m1_arlock  <= 1'b0;
        m1_arcache <= 4'b0000;
        m1_arprot  <= 3'b000;
        m1_arqos   <= 4'h0;
        m1_aruser  <= 1'b0;
        m1_arvalid <= 1'b1;
        m1_rready  <= 1'b1;

        while (!m1_arready) @(posedge clk);
        @(posedge clk); #1;
        m1_arvalid <= 1'b0;

        while (!m1_rvalid) @(posedge clk);
        rdata = m1_rdata;
        @(posedge clk); #1;
        m1_rready <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // poll_done: read CSR repeatedly until bit[31] (DONE) goes high
    //   base  - AES region base address
    //   id    - transaction ID
    // -------------------------------------------------------------------------
    task automatic poll_done(
        input  logic [31:0] base,
        input  logic [7:0]  id
    );
        logic [31:0] csr;
        integer cnt;
        cnt = 0;
        csr = 32'h0;
        do begin
            axi_read(base + OFS_CSR, id, csr);
            cnt++;
            if (cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL] TIMEOUT waiting for AES DONE at base=%08h", base);
                $finish;
            end
        end while (csr[31] == 1'b0);
    endtask

    // -------------------------------------------------------------------------
    // poll_kdone: read inv CSR until bit[30] (KDONE) goes high
    // -------------------------------------------------------------------------
    task automatic poll_kdone(
        input  logic [31:0] base,
        input  logic [7:0]  id
    );
        logic [31:0] csr;
        integer cnt;
        cnt = 0;
        csr = 32'h0;
        do begin
            axi_read(base + OFS_CSR, id, csr);
            cnt++;
            if (cnt > TIMEOUT_CYCLES) begin
                $display("[FAIL] TIMEOUT waiting for AES KDONE at base=%08h", base);
                $finish;
            end
        end while (csr[30] == 1'b0);
    endtask

    // =========================================================================
    // 6. INITIAL MASTER SIGNAL IDLE STATE
    // =========================================================================
    initial begin
        m1_awid    = '0;
        m1_awaddr  = '0;
        m1_awlen   = '0;
        m1_awsize  = 3'b010;
        m1_awburst = 2'b01;
        m1_awlock  = '0;
        m1_awcache = '0;
        m1_awprot  = '0;
        m1_awqos   = '0;
        m1_awuser  = '0;
        m1_awvalid = '0;
        m1_wdata   = '0;
        m1_wstrb   = '0;
        m1_wlast   = '0;
        m1_wuser   = '0;
        m1_wvalid  = '0;
        m1_bready  = '0;
        m1_arid    = '0;
        m1_araddr  = '0;
        m1_arlen   = '0;
        m1_arsize  = 3'b010;
        m1_arburst = 2'b01;
        m1_arlock  = '0;
        m1_arcache = '0;
        m1_arprot  = '0;
        m1_arqos   = '0;
        m1_aruser  = '0;
        m1_arvalid = '0;
        m1_rready  = '0;
        uart_rx    = 1'b1;  // UART idle
    end

    // =========================================================================
    // 7. TEST SEQUENCE
    // =========================================================================
    integer pass_count = 0;
    integer fail_count = 0;
    logic [31:0] rd;

    // Helper task to check a read value
    task automatic check(
        input string    label,
        input logic [31:0] got,
        input logic [31:0] exp
    );
        if (got === exp) begin
            $display("  [PASS] %-30s got=%08h", label, got);
            pass_count++;
        end else begin
            $display("  [FAIL] %-30s got=%08h  exp=%08h", label, got, exp);
            fail_count++;
        end
    endtask

    initial begin
        // ------------------------------------------------------------------
        // STEP 1: Reset the SoC
        // ------------------------------------------------------------------
        $display("=============================================================");
        $display(" tb_aes_integration: AES-128 via 3x15 AXI4 interconnect");
        $display("=============================================================");
        $display("[INFO] Step 1: Asserting reset ...");

        rst = 1'b1;
        repeat(10) @(posedge clk);
        rst = 1'b0;
        repeat(5)  @(posedge clk);

        $display("[INFO] Reset de-asserted.");

        // ------------------------------------------------------------------
        // STEP 2: Write AES KEY registers (normal cipher region)
        //   Base address = AES_BASE + 0x000 (CIPHER_BASE_ADDR offset = 0)
        // ------------------------------------------------------------------
        $display("[INFO] Step 2: Writing AES key (cipher) ...");
        axi_write(AES_BASE + OFS_KEY0, KEY0, 8'h01);
        axi_write(AES_BASE + OFS_KEY1, KEY1, 8'h02);
        axi_write(AES_BASE + OFS_KEY2, KEY2, 8'h03);
        axi_write(AES_BASE + OFS_KEY3, KEY3, 8'h04);

        // ------------------------------------------------------------------
        // STEP 3: Write plaintext registers (normal cipher)
        // ------------------------------------------------------------------
        $display("[INFO] Step 3: Writing plaintext ...");
        axi_write(AES_BASE + OFS_TIN0, TIN0, 8'h05);
        axi_write(AES_BASE + OFS_TIN1, TIN1, 8'h06);
        axi_write(AES_BASE + OFS_TIN2, TIN2, 8'h07);
        axi_write(AES_BASE + OFS_TIN3, TIN3, 8'h08);

        // ------------------------------------------------------------------
        // STEP 4: Start encryption (write CSR[0]=1)
        // ------------------------------------------------------------------
        $display("[INFO] Step 4: Starting encryption ...");
        axi_write(AES_BASE + OFS_CSR, 32'h0000_0001, 8'h09);

        // ------------------------------------------------------------------
        // STEP 5: Poll CSR until DONE (bit[31])
        // ------------------------------------------------------------------
        $display("[INFO] Step 5: Polling for encryption DONE ...");
        poll_done(AES_BASE, 8'h0A);
        $display("[INFO] Encryption complete.");

        // ------------------------------------------------------------------
        // STEP 6: Read ciphertext and compare
        // ------------------------------------------------------------------
        $display("[INFO] Step 6: Reading ciphertext ...");
        axi_read(AES_BASE + OFS_TOUT0, 8'h0B, rd); check("ENC TOUT0", rd, EXP_TOUT0);
        axi_read(AES_BASE + OFS_TOUT1, 8'h0C, rd); check("ENC TOUT1", rd, EXP_TOUT1);
        axi_read(AES_BASE + OFS_TOUT2, 8'h0D, rd); check("ENC TOUT2", rd, EXP_TOUT2);
        axi_read(AES_BASE + OFS_TOUT3, 8'h0E, rd); check("ENC TOUT3", rd, EXP_TOUT3);

        // ------------------------------------------------------------------
        // STEP 7: Write AES KEY registers (inverse cipher region)
        //   Base address = AES_BASE + AES_INV_OFFSET (0x100)
        // ------------------------------------------------------------------
        $display("[INFO] Step 7: Writing AES key (inv cipher) ...");
        axi_write(AES_BASE + AES_INV_OFFSET + OFS_KEY0, KEY0, 8'h11);
        axi_write(AES_BASE + AES_INV_OFFSET + OFS_KEY1, KEY1, 8'h12);
        axi_write(AES_BASE + AES_INV_OFFSET + OFS_KEY2, KEY2, 8'h13);
        axi_write(AES_BASE + AES_INV_OFFSET + OFS_KEY3, KEY3, 8'h14);

        // ------------------------------------------------------------------
        // STEP 8: Assert KLD to start inverse key expansion (CSR[1]=1)
        // ------------------------------------------------------------------
        $display("[INFO] Step 8: Triggering inverse key expansion (KLD) ...");
        axi_write(AES_BASE + AES_INV_OFFSET + OFS_CSR, 32'h0000_0002, 8'h15);

        // ------------------------------------------------------------------
        // STEP 9: Poll inv CSR until KDONE (bit[30])
        // ------------------------------------------------------------------
        $display("[INFO] Step 9: Polling for KDONE ...");
        poll_kdone(AES_BASE + AES_INV_OFFSET, 8'h16);
        $display("[INFO] Key expansion complete.");

        // ------------------------------------------------------------------
        // STEP 10: Write ciphertext to inv TEXT_IN registers
        // ------------------------------------------------------------------
        $display("[INFO] Step 10: Writing ciphertext to inv TEXT_IN ...");
        axi_write(AES_BASE + AES_INV_OFFSET + OFS_TIN0, EXP_TOUT0, 8'h17);
        axi_write(AES_BASE + AES_INV_OFFSET + OFS_TIN1, EXP_TOUT1, 8'h18);
        axi_write(AES_BASE + AES_INV_OFFSET + OFS_TIN2, EXP_TOUT2, 8'h19);
        axi_write(AES_BASE + AES_INV_OFFSET + OFS_TIN3, EXP_TOUT3, 8'h1A);

        // ------------------------------------------------------------------
        // STEP 11: Start decryption (inv CSR[0]=1)
        // ------------------------------------------------------------------
        $display("[INFO] Step 11: Starting decryption ...");
        axi_write(AES_BASE + AES_INV_OFFSET + OFS_CSR, 32'h0000_0001, 8'h1B);

        // ------------------------------------------------------------------
        // STEP 12: Poll inv CSR until DONE (bit[31])
        // ------------------------------------------------------------------
        $display("[INFO] Step 12: Polling for decryption DONE ...");
        poll_done(AES_BASE + AES_INV_OFFSET, 8'h1C);
        $display("[INFO] Decryption complete.");

        // ------------------------------------------------------------------
        // STEP 13: Read decrypted plaintext and compare to original
        // ------------------------------------------------------------------
        $display("[INFO] Step 13: Reading decrypted plaintext ...");
        axi_read(AES_BASE + AES_INV_OFFSET + OFS_TOUT0, 8'h1D, rd); check("DEC TOUT0 (=TIN0)", rd, EXP_INV_TOUT0);
        axi_read(AES_BASE + AES_INV_OFFSET + OFS_TOUT1, 8'h1E, rd); check("DEC TOUT1 (=TIN1)", rd, EXP_INV_TOUT1);
        axi_read(AES_BASE + AES_INV_OFFSET + OFS_TOUT2, 8'h1F, rd); check("DEC TOUT2 (=TIN2)", rd, EXP_INV_TOUT2);
        axi_read(AES_BASE + AES_INV_OFFSET + OFS_TOUT3, 8'h20, rd); check("DEC TOUT3 (=TIN3)", rd, EXP_INV_TOUT3);

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("=============================================================");
        $display(" RESULTS: %0d PASS  /  %0d FAIL", pass_count, fail_count);
        $display("=============================================================");
        if (fail_count == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" *** SOME TESTS FAILED ***");
        $display("=============================================================");

        $finish;
    end

    // =========================================================================
    // 8. GLOBAL TIMEOUT WATCHDOG
    // =========================================================================
    initial begin
        #(TIMEOUT_CYCLES * 10ns);
        $display("[ERROR] Global simulation timeout.");
        $finish;
    end

    // =========================================================================
    // 9. OPTIONAL VCD / FSDB DUMP
    // =========================================================================
    initial begin
        $fsdbDumpfile("aes_integration.fsdb");
        $fsdbDumpvars(0, tb_aes_integration);
    end

endmodule

`default_nettype wire
