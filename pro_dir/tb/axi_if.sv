// =============================================================================
// File        : axi_if.sv
// Description : AXI4 interface definition for axi_interconnect_wrap_3x7 TB
// Parameters  : DATA_WIDTH=32, ADDR_WIDTH=32, ID_WIDTH=8
//               AWUSER_WIDTH=1, WUSER_WIDTH=1, BUSER_WIDTH=1
//               ARUSER_WIDTH=1, RUSER_WIDTH=1
// Directions  : Signals are declared from the MASTER perspective.
//               - Master drives: AW*, W*, BREADY, AR*, RREADY
//               - Slave  drives: AWREADY, WREADY, B*, ARREADY, R*
// =============================================================================

`timescale 1ns/1ps

interface axi_if #(
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 32,
    parameter ID_WIDTH     = 8,
    parameter STRB_WIDTH   = DATA_WIDTH/8,
    parameter AWUSER_WIDTH = 1,
    parameter WUSER_WIDTH  = 1,
    parameter BUSER_WIDTH  = 1,
    parameter ARUSER_WIDTH = 1,
    parameter RUSER_WIDTH  = 1
) (
    input logic clk,
    input logic rst
);

    // -----------------------------------------------------------------
    // Write Address Channel (AW)
    // -----------------------------------------------------------------
    logic [ID_WIDTH-1:0]     awid;
    logic [ADDR_WIDTH-1:0]   awaddr;
    logic [7:0]              awlen;
    logic [2:0]              awsize;
    logic [1:0]              awburst;
    logic                    awlock;
    logic [3:0]              awcache;
    logic [2:0]              awprot;
    logic [3:0]              awqos;
    logic [AWUSER_WIDTH-1:0] awuser;
    logic                    awvalid;
    logic                    awready;

    // -----------------------------------------------------------------
    // Write Data Channel (W)
    // -----------------------------------------------------------------
    logic [DATA_WIDTH-1:0]   wdata;
    logic [STRB_WIDTH-1:0]   wstrb;
    logic                    wlast;
    logic [WUSER_WIDTH-1:0]  wuser;
    logic                    wvalid;
    logic                    wready;

    // -----------------------------------------------------------------
    // Write Response Channel (B)
    // -----------------------------------------------------------------
    logic [ID_WIDTH-1:0]     bid;
    logic [1:0]              bresp;
    logic [BUSER_WIDTH-1:0]  buser;
    logic                    bvalid;
    logic                    bready;

    // -----------------------------------------------------------------
    // Read Address Channel (AR)
    // -----------------------------------------------------------------
    logic [ID_WIDTH-1:0]     arid;
    logic [ADDR_WIDTH-1:0]   araddr;
    logic [7:0]              arlen;
    logic [2:0]              arsize;
    logic [1:0]              arburst;
    logic                    arlock;
    logic [3:0]              arcache;
    logic [2:0]              arprot;
    logic [3:0]              arqos;
    logic [ARUSER_WIDTH-1:0] aruser;
    logic                    arvalid;
    logic                    arready;

    // -----------------------------------------------------------------
    // Read Data Channel (R)
    // -----------------------------------------------------------------
    logic [ID_WIDTH-1:0]     rid;
    logic [DATA_WIDTH-1:0]   rdata;
    logic [1:0]              rresp;
    logic                    rlast;
    logic [RUSER_WIDTH-1:0]  ruser;
    logic                    rvalid;
    logic                    rready;

    // -----------------------------------------------------------------
    // Slave-side port (used by BFM acting as slave / DUT m*_axi ports)
    // Input from master perspective means output here
    // -----------------------------------------------------------------
    modport slave_mp (
        input  awid, awaddr, awlen, awsize, awburst, awlock,
               awcache, awprot, awqos, awuser, awvalid,
        output awready,
        input  wdata, wstrb, wlast, wuser, wvalid,
        output wready,
        output bid, bresp, buser, bvalid,
        input  bready,
        input  arid, araddr, arlen, arsize, arburst, arlock,
               arcache, arprot, arqos, aruser, arvalid,
        output arready,
        output rid, rdata, rresp, rlast, ruser, rvalid,
        input  rready,
        input  clk, rst
    );

    // -----------------------------------------------------------------
    // Master-side port (used by BFM acting as master / DUT s*_axi ports)
    // -----------------------------------------------------------------
    modport master_mp (
        output awid, awaddr, awlen, awsize, awburst, awlock,
               awcache, awprot, awqos, awuser, awvalid,
        input  awready,
        output wdata, wstrb, wlast, wuser, wvalid,
        input  wready,
        input  bid, bresp, buser, bvalid,
        output bready,
        output arid, araddr, arlen, arsize, arburst, arlock,
               arcache, arprot, arqos, aruser, arvalid,
        input  arready,
        input  rid, rdata, rresp, rlast, ruser, rvalid,
        output rready,
        input  clk, rst
    );

    // -----------------------------------------------------------------
    // Passive monitor port (for assertions / scoreboard)
    // -----------------------------------------------------------------
    modport monitor_mp (
        input awid, awaddr, awlen, awsize, awburst, awlock,
              awcache, awprot, awqos, awuser, awvalid, awready,
        input wdata, wstrb, wlast, wuser, wvalid, wready,
        input bid, bresp, buser, bvalid, bready,
        input arid, araddr, arlen, arsize, arburst, arlock,
              arcache, arprot, arqos, aruser, arvalid, arready,
        input rid, rdata, rresp, rlast, ruser, rvalid, rready,
        input clk, rst
    );

    // -----------------------------------------------------------------
    // Helper task: idle / reset all master-driven signals to 0
    // Called from BFM to bring interface to known idle state
    // -----------------------------------------------------------------
    task automatic idle_master();
        awid    <= '0;
        awaddr  <= '0;
        awlen   <= '0;
        awsize  <= 3'b010;   // 4-byte
        awburst <= 2'b01;    // INCR
        awlock  <= 1'b0;
        awcache <= 4'b0000;
        awprot  <= 3'b000;
        awqos   <= 4'b0000;
        awuser  <= '0;
        awvalid <= 1'b0;

        wdata   <= '0;
        wstrb   <= '0;
        wlast   <= 1'b0;
        wuser   <= '0;
        wvalid  <= 1'b0;

        bready  <= 1'b0;

        arid    <= '0;
        araddr  <= '0;
        arlen   <= '0;
        arsize  <= 3'b010;
        arburst <= 2'b01;
        arlock  <= 1'b0;
        arcache <= 4'b0000;
        arprot  <= 3'b000;
        arqos   <= 4'b0000;
        aruser  <= '0;
        arvalid <= 1'b0;

        rready  <= 1'b0;
    endtask

    // -----------------------------------------------------------------
    // Helper task: idle / reset all slave-driven signals to 0
    // -----------------------------------------------------------------
    task automatic idle_slave();
        awready <= 1'b0;
        wready  <= 1'b0;
        bid     <= '0;
        bresp   <= 2'b00;
        buser   <= '0;
        bvalid  <= 1'b0;
        arready <= 1'b0;
        rid     <= '0;
        rdata   <= '0;
        rresp   <= 2'b00;
        rlast   <= 1'b0;
        ruser   <= '0;
        rvalid  <= 1'b0;
    endtask

endinterface : axi_if
