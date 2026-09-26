// =============================================================================
// File        : axi_master_bfm.sv
// Description : AXI4 Master Bus Functional Model
//               Drives one upstream (s*_axi) port of the DUT.
//               Exposes axi_write / axi_read tasks called from test programs.
// Parameters extracted from DUT:
//   DATA_WIDTH = 32, ADDR_WIDTH = 32, ID_WIDTH = 8
//   FORWARD_ID = 0  → DUT does NOT forward IDs verbatim; responses may
//                     carry interconnect-assigned IDs.  We check by AWID
//                     echo on BRESP only when FORWARD_ID=1.  With FORWARD_ID=0
//                     we simply accept whatever BID/RID the DUT returns and
//                     record it in the scoreboard.
// =============================================================================

`timescale 1ns/1ps

module axi_master_bfm #(
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 32,
    parameter ID_WIDTH     = 8,
    parameter STRB_WIDTH   = DATA_WIDTH/8,
    parameter AWUSER_WIDTH = 1,
    parameter WUSER_WIDTH  = 1,
    parameter BUSER_WIDTH  = 1,
    parameter ARUSER_WIDTH = 1,
    parameter RUSER_WIDTH  = 1,
    parameter MASTER_ID    = 0,        // 0,1,2 — for logging
    parameter TIMEOUT_CYC  = 10000     // cycles before timeout error
) (
    // Clk/rst exposed separately so the module can use them independently
    input  logic clk,
    input  logic rst,

    // ----- Write Address Channel -----
    output logic [ID_WIDTH-1:0]     awid,
    output logic [ADDR_WIDTH-1:0]   awaddr,
    output logic [7:0]              awlen,
    output logic [2:0]              awsize,
    output logic [1:0]              awburst,
    output logic                    awlock,
    output logic [3:0]              awcache,
    output logic [2:0]              awprot,
    output logic [3:0]              awqos,
    output logic [AWUSER_WIDTH-1:0] awuser,
    output logic                    awvalid,
    input  logic                    awready,

    // ----- Write Data Channel -----
    output logic [DATA_WIDTH-1:0]   wdata,
    output logic [STRB_WIDTH-1:0]   wstrb,
    output logic                    wlast,
    output logic [WUSER_WIDTH-1:0]  wuser,
    output logic                    wvalid,
    input  logic                    wready,

    // ----- Write Response Channel -----
    input  logic [ID_WIDTH-1:0]     bid,
    input  logic [1:0]              bresp,
    input  logic [BUSER_WIDTH-1:0]  buser,
    input  logic                    bvalid,
    output logic                    bready,

    // ----- Read Address Channel -----
    output logic [ID_WIDTH-1:0]     arid,
    output logic [ADDR_WIDTH-1:0]   araddr,
    output logic [7:0]              arlen,
    output logic [2:0]              arsize,
    output logic [1:0]              arburst,
    output logic                    arlock,
    output logic [3:0]              arcache,
    output logic [2:0]              arprot,
    output logic [3:0]              arqos,
    output logic [ARUSER_WIDTH-1:0] aruser,
    output logic                    arvalid,
    input  logic                    arready,

    // ----- Read Data Channel -----
    input  logic [ID_WIDTH-1:0]     rid,
    input  logic [DATA_WIDTH-1:0]   rdata,
    input  logic [1:0]              rresp,
    input  logic                    rlast,
    input  logic [RUSER_WIDTH-1:0]  ruser,
    input  logic                    rvalid,
    output logic                    rready
);

    // =========================================================================
    // Idle initialisation — all master-driven outputs to benign values
    // =========================================================================
    initial begin
        awid    = '0;
        awaddr  = '0;
        awlen   = 8'h00;
        awsize  = 3'b010;    // 4-byte beats
        awburst = 2'b01;     // INCR
        awlock  = 1'b0;
        awcache = 4'h0;
        awprot  = 3'h0;
        awqos   = 4'h0;
        awuser  = '0;
        awvalid = 1'b0;

        wdata   = '0;
        wstrb   = '0;
        wlast   = 1'b0;
        wuser   = '0;
        wvalid  = 1'b0;

        bready  = 1'b0;

        arid    = '0;
        araddr  = '0;
        arlen   = 8'h00;
        arsize  = 3'b010;
        arburst = 2'b01;
        arlock  = 1'b0;
        arcache = 4'h0;
        arprot  = 3'h0;
        arqos   = 4'h0;
        aruser  = '0;
        arvalid = 1'b0;

        rready  = 1'b0;
    end

    // =========================================================================
    // Shared timeout counter helper
    // =========================================================================
    task automatic wait_clk_or_timeout(
        input  logic       cond_sig,
        output logic       timed_out
    );
        integer cnt;
        timed_out = 1'b0;
        cnt = 0;
        while (!cond_sig) begin
            @(posedge clk);
            cnt = cnt + 1;
            if (cnt >= TIMEOUT_CYC) begin
                $display("[ERROR] Master %0d TIMEOUT waiting for handshake at time %0t",
                         MASTER_ID, $time);
                timed_out = 1'b1;
                return;
            end
        end
    endtask

    // =========================================================================
    // axi_write — single-beat AXI4 write transaction
    //   addr   : target address
    //   data   : 32-bit write data
    //   strb   : byte strobes (4-bit)
    //   txn_id : AWID to use
    //   o_bresp: returned write response
    //   o_bid  : returned BID (may differ from txn_id when FORWARD_ID=0)
    // =========================================================================
    task automatic axi_write(
        input  logic [ADDR_WIDTH-1:0]  addr,
        input  logic [DATA_WIDTH-1:0]  data,
        input  logic [STRB_WIDTH-1:0]  strb,
        input  logic [ID_WIDTH-1:0]    txn_id,
        output logic [1:0]             o_bresp,
        output logic [ID_WIDTH-1:0]    o_bid
    );
        logic timed_out;

        // ---- AW phase ----
        @(posedge clk);
        awid    <= txn_id;
        awaddr  <= addr;
        awlen   <= 8'h00;    // 1 beat
        awsize  <= 3'b010;   // 4 bytes
        awburst <= 2'b01;    // INCR
        awlock  <= 1'b0;
        awcache <= 4'h0;
        awprot  <= 3'h0;
        awqos   <= 4'h0;
        awuser  <= '0;
        awvalid <= 1'b1;

        // Wait for AWREADY
        @(posedge clk);
        begin : aw_wait
            integer cnt;
            cnt = 0;
            while (!awready) begin
                @(posedge clk);
                cnt = cnt + 1;
                if (cnt >= TIMEOUT_CYC) begin
                    $display("[ERROR] Master %0d: AWREADY timeout addr=0x%08X t=%0t",
                             MASTER_ID, addr, $time);
                    awvalid <= 1'b0;
                    return;
                end
            end
        end
        awvalid <= 1'b0;

        // ---- W phase (same cycle or next) ----
        @(posedge clk);
        wdata  <= data;
        wstrb  <= strb;
        wlast  <= 1'b1;
        wuser  <= '0;
        wvalid <= 1'b1;

        @(posedge clk);
        begin : w_wait
            integer cnt;
            cnt = 0;
            while (!wready) begin
                @(posedge clk);
                cnt = cnt + 1;
                if (cnt >= TIMEOUT_CYC) begin
                    $display("[ERROR] Master %0d: WREADY timeout addr=0x%08X t=%0t",
                             MASTER_ID, addr, $time);
                    wvalid <= 1'b0;
                    wlast  <= 1'b0;
                    return;
                end
            end
        end
        wvalid <= 1'b0;
        wlast  <= 1'b0;

        // ---- B phase ----
        bready <= 1'b1;
        @(posedge clk);
        begin : b_wait
            integer cnt;
            cnt = 0;
            while (!bvalid) begin
                @(posedge clk);
                cnt = cnt + 1;
                if (cnt >= TIMEOUT_CYC) begin
                    $display("[ERROR] Master %0d: BVALID timeout addr=0x%08X t=%0t",
                             MASTER_ID, addr, $time);
                    bready <= 1'b0;
                    return;
                end
            end
        end
        o_bresp = bresp;
        o_bid   = bid;
        bready <= 1'b0;

        @(posedge clk);  // idle cycle
    endtask

    // =========================================================================
    // axi_read — single-beat AXI4 read transaction
    //   addr   : target address
    //   txn_id : ARID
    //   o_rdata: returned read data
    //   o_rresp: returned read response
    //   o_rid  : returned RID
    // =========================================================================
    task automatic axi_read(
        input  logic [ADDR_WIDTH-1:0]  addr,
        input  logic [ID_WIDTH-1:0]    txn_id,
        output logic [DATA_WIDTH-1:0]  o_rdata,
        output logic [1:0]             o_rresp,
        output logic [ID_WIDTH-1:0]    o_rid
    );
        // ---- AR phase ----
        @(posedge clk);
        arid    <= txn_id;
        araddr  <= addr;
        arlen   <= 8'h00;   // 1 beat
        arsize  <= 3'b010;
        arburst <= 2'b01;
        arlock  <= 1'b0;
        arcache <= 4'h0;
        arprot  <= 3'h0;
        arqos   <= 4'h0;
        aruser  <= '0;
        arvalid <= 1'b1;

        @(posedge clk);
        begin : ar_wait
            integer cnt;
            cnt = 0;
            while (!arready) begin
                @(posedge clk);
                cnt = cnt + 1;
                if (cnt >= TIMEOUT_CYC) begin
                    $display("[ERROR] Master %0d: ARREADY timeout addr=0x%08X t=%0t",
                             MASTER_ID, addr, $time);
                    arvalid <= 1'b0;
                    return;
                end
            end
        end
        arvalid <= 1'b0;

        // ---- R phase ----
        rready <= 1'b1;
        @(posedge clk);
        begin : r_wait
            integer cnt;
            cnt = 0;
            while (!rvalid) begin
                @(posedge clk);
                cnt = cnt + 1;
                if (cnt >= TIMEOUT_CYC) begin
                    $display("[ERROR] Master %0d: RVALID timeout addr=0x%08X t=%0t",
                             MASTER_ID, addr, $time);
                    rready <= 1'b0;
                    return;
                end
            end
        end
        o_rdata = rdata;
        o_rresp = rresp;
        o_rid   = rid;
        // Confirm RLAST
        if (!rlast) begin
            $display("[WARN] Master %0d: RLAST not set on single-beat read at 0x%08X",
                     MASTER_ID, addr);
        end
        rready <= 1'b0;

        @(posedge clk);  // idle cycle
    endtask

endmodule : axi_master_bfm
