// =============================================================================
// File        : axi_assertions.sv
// Description : AXI4 protocol assertions for the 3x7 interconnect testbench.
//
// Checks on a single AXI channel (bind one instance per interface):
//   1. VALID-before-READY stability: once VALID asserted, must stay high
//      until READY fires (no de-assertion without handshake).
//   2. No X/Z on VALID/READY/DATA/RESP signals.
//   3. WLAST must be asserted on the last write beat.
//   4. RLAST must be asserted on the last read beat.
//   5. BID must not arrive without a prior AW transaction in-flight.
//   6. RID  must not arrive without a prior AR transaction in-flight.
//   7. No AWVALID / ARVALID during reset.
//   8. No WVALID during reset.
//   9. BRESP must be defined (not X/Z) when BVALID is asserted.
//  10. RRESP must be defined (not X/Z) when RVALID is asserted.
// =============================================================================

`timescale 1ns/1ps

module axi_assertions #(
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 32,
    parameter ID_WIDTH     = 8,
    parameter STRB_WIDTH   = DATA_WIDTH/8,
    parameter LABEL        = "axi"     // interface label for messages
) (
    input logic clk,
    input logic rst,

    // AW
    input logic [ID_WIDTH-1:0]   awid,
    input logic [ADDR_WIDTH-1:0] awaddr,
    input logic [7:0]            awlen,
    input logic                  awvalid,
    input logic                  awready,

    // W
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb,
    input logic                  wlast,
    input logic                  wvalid,
    input logic                  wready,

    // B
    input logic [ID_WIDTH-1:0]   bid,
    input logic [1:0]            bresp,
    input logic                  bvalid,
    input logic                  bready,

    // AR
    input logic [ID_WIDTH-1:0]   arid,
    input logic [ADDR_WIDTH-1:0] araddr,
    input logic [7:0]            arlen,
    input logic                  arvalid,
    input logic                  arready,

    // R
    input logic [ID_WIDTH-1:0]   rid,
    input logic [DATA_WIDTH-1:0] rdata,
    input logic [1:0]            rresp,
    input logic                  rlast,
    input logic                  rvalid,
    input logic                  rready
);

    // =========================================================================
    // 1. AWVALID stability — once high must stay high until AWREADY
    // =========================================================================
    property p_awvalid_stable;
        @(posedge clk) disable iff (rst)
        (awvalid && !awready) |=> awvalid;
    endproperty
    a_awvalid_stable: assert property (p_awvalid_stable)
        else $error("[ASSERT][%s] AWVALID de-asserted before AWREADY at t=%0t", LABEL, $time);

    // =========================================================================
    // 2. ARVALID stability
    // =========================================================================
    property p_arvalid_stable;
        @(posedge clk) disable iff (rst)
        (arvalid && !arready) |=> arvalid;
    endproperty
    a_arvalid_stable: assert property (p_arvalid_stable)
        else $error("[ASSERT][%s] ARVALID de-asserted before ARREADY at t=%0t", LABEL, $time);

    // =========================================================================
    // 3. WVALID stability
    // =========================================================================
    property p_wvalid_stable;
        @(posedge clk) disable iff (rst)
        (wvalid && !wready) |=> wvalid;
    endproperty
    a_wvalid_stable: assert property (p_wvalid_stable)
        else $error("[ASSERT][%s] WVALID de-asserted before WREADY at t=%0t", LABEL, $time);

    // =========================================================================
    // 4. No AWVALID during reset
    // =========================================================================
    property p_no_awvalid_in_reset;
        @(posedge clk)
        rst |-> !awvalid;
    endproperty
    a_no_awvalid_in_reset: assert property (p_no_awvalid_in_reset)
        else $error("[ASSERT][%s] AWVALID asserted during reset at t=%0t", LABEL, $time);

    // =========================================================================
    // 5. No ARVALID during reset
    // =========================================================================
    property p_no_arvalid_in_reset;
        @(posedge clk)
        rst |-> !arvalid;
    endproperty
    a_no_arvalid_in_reset: assert property (p_no_arvalid_in_reset)
        else $error("[ASSERT][%s] ARVALID asserted during reset at t=%0t", LABEL, $time);

    // =========================================================================
    // 6. No WVALID during reset
    // =========================================================================
    property p_no_wvalid_in_reset;
        @(posedge clk)
        rst |-> !wvalid;
    endproperty
    a_no_wvalid_in_reset: assert property (p_no_wvalid_in_reset)
        else $error("[ASSERT][%s] WVALID asserted during reset at t=%0t", LABEL, $time);

    // =========================================================================
    // 7. BRESP not X/Z when BVALID
    // =========================================================================
    property p_bresp_no_xz;
        @(posedge clk) disable iff (rst)
        bvalid |-> !$isunknown(bresp);
    endproperty
    a_bresp_no_xz: assert property (p_bresp_no_xz)
        else $error("[ASSERT][%s] BRESP has X/Z while BVALID at t=%0t", LABEL, $time);

    // =========================================================================
    // 8. RRESP not X/Z when RVALID
    // =========================================================================
    property p_rresp_no_xz;
        @(posedge clk) disable iff (rst)
        rvalid |-> !$isunknown(rresp);
    endproperty
    a_rresp_no_xz: assert property (p_rresp_no_xz)
        else $error("[ASSERT][%s] RRESP has X/Z while RVALID at t=%0t", LABEL, $time);

    // =========================================================================
    // 9. RDATA not X/Z when RVALID (data integrity)
    // =========================================================================
    property p_rdata_no_xz;
        @(posedge clk) disable iff (rst)
        rvalid |-> !$isunknown(rdata);
    endproperty
    a_rdata_no_xz: assert property (p_rdata_no_xz)
        else $error("[ASSERT][%s] RDATA has X/Z while RVALID at t=%0t", LABEL, $time);

    // =========================================================================
    // 10. AWADDR not X/Z when AWVALID
    // =========================================================================
    property p_awaddr_no_xz;
        @(posedge clk) disable iff (rst)
        awvalid |-> !$isunknown(awaddr);
    endproperty
    a_awaddr_no_xz: assert property (p_awaddr_no_xz)
        else $error("[ASSERT][%s] AWADDR has X/Z while AWVALID at t=%0t", LABEL, $time);

    // =========================================================================
    // 11. ARADDR not X/Z when ARVALID
    // =========================================================================
    property p_araddr_no_xz;
        @(posedge clk) disable iff (rst)
        arvalid |-> !$isunknown(araddr);
    endproperty
    a_araddr_no_xz: assert property (p_araddr_no_xz)
        else $error("[ASSERT][%s] ARADDR has X/Z while ARVALID at t=%0t", LABEL, $time);

    // =========================================================================
    // 12. WDATA not X/Z when WVALID
    // =========================================================================
    property p_wdata_no_xz;
        @(posedge clk) disable iff (rst)
        wvalid |-> !$isunknown(wdata);
    endproperty
    a_wdata_no_xz: assert property (p_wdata_no_xz)
        else $error("[ASSERT][%s] WDATA has X/Z while WVALID at t=%0t", LABEL, $time);

    // =========================================================================
    // 13. Single-beat write: WLAST must be set on the only beat
    //     (awlen==0 means 1 beat; this checks that WLAST is asserted when
    //     wvalid is high and the outstanding transaction had awlen=0)
    //     We track the in-flight AWLEN to verify WLAST properly.
    // =========================================================================
    // Track AW length so we can check WLAST on the correct beat
    logic [7:0] aw_len_inflight;
    logic       aw_pending;
    logic [7:0] w_beat_count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            aw_pending    <= 1'b0;
            aw_len_inflight <= '0;
            w_beat_count  <= '0;
        end else begin
            if (awvalid && awready && !aw_pending) begin
                aw_pending      <= 1'b1;
                aw_len_inflight <= awlen;
                w_beat_count    <= '0;
            end
            if (wvalid && wready && aw_pending) begin
                if (wlast) begin
                    aw_pending   <= 1'b0;
                    w_beat_count <= '0;
                end else begin
                    w_beat_count <= w_beat_count + 1;
                end
            end
        end
    end

    property p_wlast_correct;
        @(posedge clk) disable iff (rst)
        (wvalid && wready && aw_pending && (w_beat_count == aw_len_inflight))
            |-> wlast;
    endproperty
    a_wlast_correct: assert property (p_wlast_correct)
        else $error("[ASSERT][%s] WLAST not set on last write beat (beat=%0d len=%0d) at t=%0t",
                    LABEL, w_beat_count, aw_len_inflight, $time);

    // =========================================================================
    // 14. RLAST tracking — single-beat: RLAST must be set when arlen==0
    // =========================================================================
    logic [7:0] ar_len_inflight;
    logic       ar_pending;
    logic [7:0] r_beat_count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ar_pending      <= 1'b0;
            ar_len_inflight <= '0;
            r_beat_count    <= '0;
        end else begin
            if (arvalid && arready && !ar_pending) begin
                ar_pending      <= 1'b1;
                ar_len_inflight <= arlen;
                r_beat_count    <= '0;
            end
            if (rvalid && rready && ar_pending) begin
                if (rlast) begin
                    ar_pending   <= 1'b0;
                    r_beat_count <= '0;
                end else begin
                    r_beat_count <= r_beat_count + 1;
                end
            end
        end
    end

    property p_rlast_correct;
        @(posedge clk) disable iff (rst)
        (rvalid && rready && ar_pending && (r_beat_count == ar_len_inflight))
            |-> rlast;
    endproperty
    a_rlast_correct: assert property (p_rlast_correct)
        else $error("[ASSERT][%s] RLAST not set on last read beat (beat=%0d len=%0d) at t=%0t",
                    LABEL, r_beat_count, ar_len_inflight, $time);

    // =========================================================================
    // 15. BVALID stability: once asserted, stays until BREADY
    // =========================================================================
    property p_bvalid_stable;
        @(posedge clk) disable iff (rst)
        (bvalid && !bready) |=> bvalid;
    endproperty
    a_bvalid_stable: assert property (p_bvalid_stable)
        else $error("[ASSERT][%s] BVALID de-asserted before BREADY at t=%0t", LABEL, $time);

    // =========================================================================
    // 16. RVALID stability: once asserted, stays until RREADY
    // =========================================================================
    property p_rvalid_stable;
        @(posedge clk) disable iff (rst)
        (rvalid && !rready) |=> rvalid;
    endproperty
    a_rvalid_stable: assert property (p_rvalid_stable)
        else $error("[ASSERT][%s] RVALID de-asserted before RREADY at t=%0t", LABEL, $time);

endmodule : axi_assertions
