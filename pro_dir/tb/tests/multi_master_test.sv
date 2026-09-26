// =============================================================================
// File        : tests/multi_master_test.sv
// Description : TEST 6 — MULTIPLE MASTERS (transactions from M0, M1, M2
//                         targeting different slaves)
//               TEST 7 — SAME SLAVE FROM MULTIPLE MASTERS (serialization)
//
// Methodology:
//   Since the BFM tasks are sequential, "simultaneous" multi-master access
//   is simulated by using fork..join_any to launch concurrent BFM calls.
//   Each master targets a different slave (TEST 6) or the same slave (TEST 7).
//   Responses are checked for correctness and delivered to the correct master.
// =============================================================================

`timescale 1ns/1ps

// Included into tb_top — not a standalone module.

// ---------------------------------------------------------------------------
// TEST 6 — Multiple masters, different slaves concurrently
// ---------------------------------------------------------------------------
task automatic multi_master_test(ref int fail_count);
    // Each master targets a different slave
    const logic [31:0] ADDR_M0 = 32'h0000_0A00;   // slave 0
    const logic [31:0] ADDR_M1 = 32'h0200_0A00;   // slave 2
    const logic [31:0] ADDR_M2 = 32'h0500_0A00;   // slave 5
    const logic [31:0] DATA_M0 = 32'hCAFE_0000;
    const logic [31:0] DATA_M1 = 32'hCAFE_0002;
    const logic [31:0] DATA_M2 = 32'hCAFE_0005;

    logic [31:0] rd0, rd1, rd2;
    logic [1:0]  br0, br1, br2, rr0, rr1, rr2;
    logic [7:0]  bid0, bid1, bid2, rid0, rid1, rid2;
    int local_fails;
    local_fails = 0;

    $display("");
    $display("=================================================================");
    $display("[TEST6] MULTI-MASTER — different slaves concurrently");
    $display("=================================================================");

    // Phase 1: fork writes from all 3 masters simultaneously
    $display("[TEST6] Phase 1: Concurrent writes M0→slave0, M1→slave2, M2→slave5");
    fork
        begin : fork_wr_m0
            m0_bfm.axi_write(ADDR_M0, DATA_M0, 4'hF, 8'h01, br0, bid0);
        end
        begin : fork_wr_m1
            m1_bfm.axi_write(ADDR_M1, DATA_M1, 4'hF, 8'h02, br1, bid1);
        end
        begin : fork_wr_m2
            m2_bfm.axi_write(ADDR_M2, DATA_M2, 4'hF, 8'h03, br2, bid2);
        end
    join

    scoreboard.check_write_resp(0, ADDR_M0, br0, bid0);
    scoreboard.check_write_resp(1, ADDR_M1, br1, bid1);
    scoreboard.check_write_resp(2, ADDR_M2, br2, bid2);

    if (br0 !== 2'b00) begin local_fails++; $display("[TEST6] FAIL M0 write bresp=%0d", br0); end
    if (br1 !== 2'b00) begin local_fails++; $display("[TEST6] FAIL M1 write bresp=%0d", br1); end
    if (br2 !== 2'b00) begin local_fails++; $display("[TEST6] FAIL M2 write bresp=%0d", br2); end

    // Phase 2: fork reads from all 3 masters simultaneously
    $display("[TEST6] Phase 2: Concurrent reads M0→slave0, M1→slave2, M2→slave5");
    fork
        begin : fork_rd_m0
            m0_bfm.axi_read(ADDR_M0, 8'h04, rd0, rr0, rid0);
        end
        begin : fork_rd_m1
            m1_bfm.axi_read(ADDR_M1, 8'h05, rd1, rr1, rid1);
        end
        begin : fork_rd_m2
            m2_bfm.axi_read(ADDR_M2, 8'h06, rd2, rr2, rid2);
        end
    join

    scoreboard.check_read_resp(0, ADDR_M0, rd0, DATA_M0, rr0, rid0);
    scoreboard.check_read_resp(1, ADDR_M1, rd1, DATA_M1, rr1, rid1);
    scoreboard.check_read_resp(2, ADDR_M2, rd2, DATA_M2, rr2, rid2);

    if (rr0 !== 2'b00 || rd0 !== DATA_M0) begin
        local_fails++;
        $display("[TEST6] FAIL M0 read expected=0x%08X got=0x%08X", DATA_M0, rd0);
    end
    if (rr1 !== 2'b00 || rd1 !== DATA_M1) begin
        local_fails++;
        $display("[TEST6] FAIL M1 read expected=0x%08X got=0x%08X", DATA_M1, rd1);
    end
    if (rr2 !== 2'b00 || rd2 !== DATA_M2) begin
        local_fails++;
        $display("[TEST6] FAIL M2 read expected=0x%08X got=0x%08X", DATA_M2, rd2);
    end

    if (local_fails == 0)
        $display("[TEST6] M0→slave0=0x%08X M1→slave2=0x%08X M2→slave5=0x%08X — all correct",
                 rd0, rd1, rd2);

    fail_count += local_fails;
    if (local_fails == 0)
        $display("[TEST6] MULTI-MASTER DIFFERENT SLAVES ---> PASSED");
    else
        $display("[TEST6] MULTI-MASTER DIFFERENT SLAVES ---> FAILED (%0d errors)", local_fails);
endtask

// ---------------------------------------------------------------------------
// TEST 7 — Same slave, multiple masters (arbitration/serialization)
// All 3 masters target slave 4 — interconnect must serialize them.
// We verify that all 3 responses arrive correctly (not necessarily in order).
// ---------------------------------------------------------------------------
task automatic same_slave_multi_master_test(ref int fail_count);
    const logic [31:0] SLAVE4_BASE = 32'h0400_0B00;
    const logic [31:0] ADDR_M0 = SLAVE4_BASE + 0;
    const logic [31:0] ADDR_M1 = SLAVE4_BASE + 4;
    const logic [31:0] ADDR_M2 = SLAVE4_BASE + 8;
    const logic [31:0] DATA_M0 = 32'h4444_0000;
    const logic [31:0] DATA_M1 = 32'h4444_0001;
    const logic [31:0] DATA_M2 = 32'h4444_0002;

    logic [31:0] rd0, rd1, rd2;
    logic [1:0]  br0, br1, br2, rr0, rr1, rr2;
    logic [7:0]  bid0, bid1, bid2, rid0, rid1, rid2;
    int local_fails;
    local_fails = 0;

    $display("");
    $display("=================================================================");
    $display("[TEST7] SAME SLAVE (slave4) FROM ALL 3 MASTERS — serialization");
    $display("=================================================================");
    $display("[TEST7] Note: interconnect serializes — responses may be reordered");

    // Fork all 3 write transactions to slave 4 simultaneously
    fork
        begin : s4_wr_m0
            m0_bfm.axi_write(ADDR_M0, DATA_M0, 4'hF, 8'h11, br0, bid0);
        end
        begin : s4_wr_m1
            m1_bfm.axi_write(ADDR_M1, DATA_M1, 4'hF, 8'h22, br1, bid1);
        end
        begin : s4_wr_m2
            m2_bfm.axi_write(ADDR_M2, DATA_M2, 4'hF, 8'h33, br2, bid2);
        end
    join

    $display("[TEST7] All 3 writes completed. BRESPs: M0=%0d M1=%0d M2=%0d",
             br0, br1, br2);
    $display("[TEST7] BIDs: M0=0x%02X M1=0x%02X M2=0x%02X", bid0, bid1, bid2);

    if (br0 !== 2'b00) begin local_fails++; $display("[TEST7] FAIL M0 BRESP=%0d exp OKAY", br0); end
    if (br1 !== 2'b00) begin local_fails++; $display("[TEST7] FAIL M1 BRESP=%0d exp OKAY", br1); end
    if (br2 !== 2'b00) begin local_fails++; $display("[TEST7] FAIL M2 BRESP=%0d exp OKAY", br2); end

    // Verify each master's written data is readable via its own port
    fork
        begin : s4_rd_m0
            m0_bfm.axi_read(ADDR_M0, 8'h44, rd0, rr0, rid0);
        end
        begin : s4_rd_m1
            m1_bfm.axi_read(ADDR_M1, 8'h55, rd1, rr1, rid1);
        end
        begin : s4_rd_m2
            m2_bfm.axi_read(ADDR_M2, 8'h66, rd2, rr2, rid2);
        end
    join

    $display("[TEST7] Readbacks: M0=0x%08X M1=0x%08X M2=0x%08X",
             rd0, rd1, rd2);

    if (rd0 !== DATA_M0 || rr0 !== 2'b00) begin
        local_fails++;
        $display("[TEST7] FAIL M0 read expected=0x%08X got=0x%08X rresp=%0d", DATA_M0, rd0, rr0);
    end
    if (rd1 !== DATA_M1 || rr1 !== 2'b00) begin
        local_fails++;
        $display("[TEST7] FAIL M1 read expected=0x%08X got=0x%08X rresp=%0d", DATA_M1, rd1, rr1);
    end
    if (rd2 !== DATA_M2 || rr2 !== 2'b00) begin
        local_fails++;
        $display("[TEST7] FAIL M2 read expected=0x%08X got=0x%08X rresp=%0d", DATA_M2, rd2, rr2);
    end

    fail_count += local_fails;
    if (local_fails == 0)
        $display("[TEST7] SAME SLAVE MULTI-MASTER ---> PASSED");
    else
        $display("[TEST7] SAME SLAVE MULTI-MASTER ---> FAILED (%0d errors)", local_fails);
endtask
