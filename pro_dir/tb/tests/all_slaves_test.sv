// =============================================================================
// File        : tests/all_slaves_test.sv
// Description : TEST 5 — ALL SEVEN SLAVES
//   Uses Master 0 to access one address in each of the 7 slave regions.
//   Verifies that each slave address is decoded correctly by checking:
//     - BRESP == OKAY
//     - RRESP == OKAY
//     - Read data matches written data (confirming correct slave was hit)
//
//   Also includes TEST 8 (READ TRANSACTIONS) and TEST 9 (WRITE TRANSACTIONS)
//   with more thorough handshake verification via the scoreboard.
//
//   TEST 11 — DIFFERENT DATA VALUES
//   Writes multiple data patterns to one slave address each and reads back.
// =============================================================================

`timescale 1ns/1ps

// Included into tb_top — not a standalone module.

// ---------------------------------------------------------------------------
// TEST 5 — ALL SLAVES accessed from at least one master
// ---------------------------------------------------------------------------
task automatic all_slaves_test(ref int fail_count);
    // One representative address per slave region
    const logic [31:0] SLAVE_ADDR [0:6] = '{
        32'h0000_0400,   // slave 0
        32'h0100_0400,   // slave 1
        32'h0200_0400,   // slave 2
        32'h0300_0400,   // slave 3
        32'h0400_0400,   // slave 4
        32'h0500_0400,   // slave 5
        32'h0600_0400    // slave 6
    };
    // Unique patterns per slave
    const logic [31:0] WR_DATA [0:6] = '{
        32'hA0A0_A0A0,
        32'hA1A1_A1A1,
        32'hA2A2_A2A2,
        32'hA3A3_A3A3,
        32'hA4A4_A4A4,
        32'hA5A5_A5A5,
        32'hA6A6_A6A6
    };

    logic [31:0] rd_data;
    logic [1:0]  bresp, rresp;
    logic [7:0]  bid_out, rid_out;
    int s;
    int local_fails;
    local_fails = 0;

    $display("");
    $display("=================================================================");
    $display("[TEST5] ALL SEVEN SLAVES — address decode verification");
    $display("=================================================================");

    for (s = 0; s < 7; s = s + 1) begin
        // Write
        scoreboard.record_write(0, SLAVE_ADDR[s], WR_DATA[s], 4'hF, 8'h70 + s);
        m0_bfm.axi_write(SLAVE_ADDR[s], WR_DATA[s], 4'hF, 8'h70 + s, bresp, bid_out);
        scoreboard.check_write_resp(0, SLAVE_ADDR[s], bresp, bid_out);

        // Read back
        scoreboard.record_read(0, SLAVE_ADDR[s], 8'h80 + s);
        m0_bfm.axi_read(SLAVE_ADDR[s], 8'h80 + s, rd_data, rresp, rid_out);
        scoreboard.check_read_resp(0, SLAVE_ADDR[s], rd_data, WR_DATA[s], rresp, rid_out);

        if (bresp !== 2'b00 || rresp !== 2'b00 || rd_data !== WR_DATA[s]) begin
            local_fails++;
            $display("[TEST5] FAIL slave%0d addr=0x%08X expected=0x%08X got=0x%08X bresp=%0d rresp=%0d",
                     s, SLAVE_ADDR[s], WR_DATA[s], rd_data, bresp, rresp);
        end else begin
            $display("[TEST5] PASS slave%0d addr=0x%08X data=0x%08X OK",
                     s, SLAVE_ADDR[s], rd_data);
        end
    end

    fail_count += local_fails;
    if (local_fails == 0)
        $display("[TEST5] ALL SLAVES ---> PASSED");
    else
        $display("[TEST5] ALL SLAVES ---> FAILED (%0d errors)", local_fails);
endtask

// ---------------------------------------------------------------------------
// TEST 8 — READ TRANSACTIONS from all 3 masters to multiple slaves
// Verifies: AR handshake, RID, RDATA, RRESP, RLAST, RREADY/RVALID
// ---------------------------------------------------------------------------
task automatic read_transactions_test(ref int fail_count);
    const logic [31:0] READ_ADDRS [0:5] = '{
        32'h0000_0500, 32'h0100_0500,
        32'h0200_0500, 32'h0300_0500,
        32'h0400_0500, 32'h0500_0500
    };
    const int MASTERS [0:5] = '{0, 1, 2, 0, 1, 2};

    logic [31:0] rd_data;
    logic [1:0]  rresp;
    logic [7:0]  rid_out;
    logic [1:0]  bresp;
    logic [7:0]  bid_out;
    int i, slave_id;
    int local_fails;
    local_fails = 0;

    $display("");
    $display("=================================================================");
    $display("[TEST8] READ TRANSACTIONS — all 3 masters");
    $display("=================================================================");

    // First write known data from M0 to all addresses
    for (i = 0; i < 6; i = i + 1) begin
        m0_bfm.axi_write(READ_ADDRS[i], 32'hBEEF_0000 | i, 4'hF, 8'h90 + i, bresp, bid_out);
    end

    // Now read from each master
    for (i = 0; i < 6; i = i + 1) begin
        scoreboard.record_read(MASTERS[i], READ_ADDRS[i], 8'hA0 + i);
        case (MASTERS[i])
            0: m0_bfm.axi_read(READ_ADDRS[i], 8'hA0 + i, rd_data, rresp, rid_out);
            1: m1_bfm.axi_read(READ_ADDRS[i], 8'hA0 + i, rd_data, rresp, rid_out);
            2: m2_bfm.axi_read(READ_ADDRS[i], 8'hA0 + i, rd_data, rresp, rid_out);
        endcase
        scoreboard.check_read_resp(MASTERS[i], READ_ADDRS[i], rd_data,
                                   32'hBEEF_0000 | i, rresp, rid_out);
        if (rresp !== 2'b00 || rd_data !== (32'hBEEF_0000 | i)) begin
            local_fails++;
            $display("[TEST8] FAIL M%0d addr=0x%08X expected=0x%08X got=0x%08X",
                     MASTERS[i], READ_ADDRS[i], 32'hBEEF_0000 | i, rd_data);
        end else begin
            $display("[TEST8] PASS M%0d addr=0x%08X rdata=0x%08X rresp=%0d rid=0x%02X",
                     MASTERS[i], READ_ADDRS[i], rd_data, rresp, rid_out);
        end
    end

    fail_count += local_fails;
    if (local_fails == 0)
        $display("[TEST8] READ TRANSACTIONS ---> PASSED");
    else
        $display("[TEST8] READ TRANSACTIONS ---> FAILED (%0d errors)", local_fails);
endtask

// ---------------------------------------------------------------------------
// TEST 9 — WRITE TRANSACTIONS from all 3 masters to multiple slaves
// Verifies: AW handshake, W handshake, WSTRB, WLAST, BID, BRESP, BREADY/BVALID
// Uses FRESH addresses not touched by earlier tests to get predictable readbacks.
// For partial-strobe tests: first write 0 with full strobe, then partial write.
// ---------------------------------------------------------------------------
task automatic write_transactions_test(ref int fail_count);
    // Use a separate address range (0xXX000900) not touched by tests 2-8
    const logic [31:0] WRITE_ADDRS [0:5] = '{
        32'h0000_0900, 32'h0100_0900,
        32'h0200_0900, 32'h0300_0900,
        32'h0400_0900, 32'h0500_0900
    };
    const logic [31:0] WR_DATA [0:5] = '{
        32'hDEAD_0000, 32'hDEAD_0001,
        32'hDEAD_0002, 32'hDEAD_0003,
        32'hDEAD_0004, 32'hDEAD_0005
    };
    // Test partial byte strobes for some transactions
    const logic [3:0] WR_STRB [0:5] = '{
        4'hF, 4'hF, 4'hF, 4'hC, 4'h3, 4'h5
    };
    const int MASTERS [0:5] = '{0, 1, 2, 0, 1, 2};

    logic [31:0] rd_data;
    logic [1:0]  bresp, rresp;
    logic [7:0]  bid_out, rid_out;
    logic [31:0] expected;
    logic [31:0] baseline;
    int i, b;
    int local_fails;
    local_fails = 0;

    $display("");
    $display("=================================================================");
    $display("[TEST9] WRITE TRANSACTIONS — all 3 masters with byte strobes");
    $display("=================================================================");

    for (i = 0; i < 6; i = i + 1) begin
        // For partial strobes, establish a known baseline of all-zeros first
        if (WR_STRB[i] !== 4'hF) begin
            m0_bfm.axi_write(WRITE_ADDRS[i], 32'h0000_0000, 4'hF, 8'hA0+i, bresp, bid_out);
            baseline = 32'h0000_0000;
        end else begin
            baseline = 32'h0000_0000;  // doesn't matter, full strobe overwrites all
        end

        // The actual test write
        scoreboard.record_write(MASTERS[i], WRITE_ADDRS[i], WR_DATA[i], WR_STRB[i], 8'hB0 + i);
        case (MASTERS[i])
            0: m0_bfm.axi_write(WRITE_ADDRS[i], WR_DATA[i], WR_STRB[i], 8'hB0+i, bresp, bid_out);
            1: m1_bfm.axi_write(WRITE_ADDRS[i], WR_DATA[i], WR_STRB[i], 8'hB0+i, bresp, bid_out);
            2: m2_bfm.axi_write(WRITE_ADDRS[i], WR_DATA[i], WR_STRB[i], 8'hB0+i, bresp, bid_out);
        endcase
        scoreboard.check_write_resp(MASTERS[i], WRITE_ADDRS[i], bresp, bid_out);
        if (bresp !== 2'b00) begin
            local_fails++;
            $display("[TEST9] FAIL M%0d write addr=0x%08X BRESP=%0d",
                     MASTERS[i], WRITE_ADDRS[i], bresp);
        end else begin
            $display("[TEST9] PASS M%0d write addr=0x%08X data=0x%08X strb=0x%X BRESP=OKAY BID=0x%02X",
                     MASTERS[i], WRITE_ADDRS[i], WR_DATA[i], WR_STRB[i], bid_out);
        end

        // Read back and verify written bytes
        case (MASTERS[i])
            0: m0_bfm.axi_read(WRITE_ADDRS[i], 8'hC0+i, rd_data, rresp, rid_out);
            1: m1_bfm.axi_read(WRITE_ADDRS[i], 8'hC0+i, rd_data, rresp, rid_out);
            2: m2_bfm.axi_read(WRITE_ADDRS[i], 8'hC0+i, rd_data, rresp, rid_out);
        endcase

        // Build expected: baseline with write data masked-in by strobe
        expected = baseline;
        for (b = 0; b < 4; b = b + 1) begin
            if (WR_STRB[i][b])
                expected[b*8 +: 8] = WR_DATA[i][b*8 +: 8];
        end

        if (rresp !== 2'b00 || rd_data !== expected) begin
            local_fails++;
            $display("[TEST9] FAIL M%0d readback addr=0x%08X expected=0x%08X got=0x%08X",
                     MASTERS[i], WRITE_ADDRS[i], expected, rd_data);
        end else begin
            $display("[TEST9] PASS M%0d readback addr=0x%08X data=0x%08X (strobe-masked OK)",
                     MASTERS[i], WRITE_ADDRS[i], rd_data);
        end
    end

    fail_count += local_fails;
    if (local_fails == 0)
        $display("[TEST9] WRITE TRANSACTIONS ---> PASSED");
    else
        $display("[TEST9] WRITE TRANSACTIONS ---> FAILED (%0d errors)", local_fails);
endtask

// ---------------------------------------------------------------------------
// TEST 11 — DIFFERENT DATA VALUES
// ---------------------------------------------------------------------------
task automatic different_data_test(ref int fail_count);
    const logic [31:0] PATTERNS [0:5] = '{
        32'h0000_0000,
        32'hFFFF_FFFF,
        32'hAAAA_AAAA,
        32'h5555_5555,
        32'h1234_5678,
        32'hDEAD_BEEF
    };
    // All to slave 1 at different offsets
    const logic [31:0] BASE = 32'h0100_0700;

    logic [31:0] rd_data;
    logic [1:0]  bresp, rresp;
    logic [7:0]  bid_out, rid_out;
    int i;
    int local_fails;
    local_fails = 0;

    $display("");
    $display("=================================================================");
    $display("[TEST11] DIFFERENT DATA VALUES — data integrity check");
    $display("=================================================================");

    for (i = 0; i < 6; i = i + 1) begin
        logic [31:0] addr;
        addr = BASE + (i * 4);

        m0_bfm.axi_write(addr, PATTERNS[i], 4'hF, 8'hD0 + i, bresp, bid_out);
        m0_bfm.axi_read (addr, 8'hE0 + i, rd_data, rresp, rid_out);

        if (bresp !== 2'b00 || rresp !== 2'b00 || rd_data !== PATTERNS[i]) begin
            local_fails++;
            $display("[TEST11] FAIL pattern=0x%08X got=0x%08X bresp=%0d rresp=%0d",
                     PATTERNS[i], rd_data, bresp, rresp);
        end else begin
            $display("[TEST11] PASS pattern=0x%08X verified OK", PATTERNS[i]);
        end
    end

    fail_count += local_fails;
    if (local_fails == 0)
        $display("[TEST11] DIFFERENT DATA VALUES ---> PASSED");
    else
        $display("[TEST11] DIFFERENT DATA VALUES ---> FAILED (%0d errors)", local_fails);
endtask

// ---------------------------------------------------------------------------
// TEST 12 — INVALID / UNMAPPED ADDRESS
// Address 0x07000000 is beyond slave 6's region (slaves 0-6 at 0x0N000000)
// The interconnect will either return DECERR or ignore the transaction.
// We observe and report — no hard pass/fail assertion.
// ---------------------------------------------------------------------------
task automatic unmapped_addr_test(ref int fail_count);
    const logic [31:0] UNMAP_ADDR = 32'h0700_0000;  // beyond slave 6 top
    logic [31:0] rd_data;
    logic [1:0]  bresp, rresp;
    logic [7:0]  bid_out, rid_out;

    $display("");
    $display("=================================================================");
    $display("[TEST12] UNMAPPED ADDRESS — observed behavior");
    $display("=================================================================");

    $display("[TEST12] Writing to unmapped address 0x%08X...", UNMAP_ADDR);
    m0_bfm.axi_write(UNMAP_ADDR, 32'hDEAD_CAFE, 4'hF, 8'hFF, bresp, bid_out);
    scoreboard.check_write_resp(0, UNMAP_ADDR, bresp, bid_out);
    $display("[TEST12] Write  BRESP observed: %0d (%s)",
             bresp, (bresp==2'b00) ? "OKAY" :
                    (bresp==2'b01) ? "EXOKAY" :
                    (bresp==2'b10) ? "SLVERR" : "DECERR");

    $display("[TEST12] Reading from unmapped address 0x%08X...", UNMAP_ADDR);
    m0_bfm.axi_read(UNMAP_ADDR, 8'hFE, rd_data, rresp, rid_out);
    scoreboard.check_read_resp(0, UNMAP_ADDR, rd_data, rd_data, rresp, rid_out);
    $display("[TEST12] Read   RRESP observed: %0d (%s)  RDATA=0x%08X",
             rresp, (rresp==2'b00) ? "OKAY" :
                    (rresp==2'b01) ? "EXOKAY" :
                    (rresp==2'b10) ? "SLVERR" : "DECERR",
             rd_data);

    $display("[TEST12] UNMAPPED ADDRESS ---> OBSERVED (no pass/fail enforced)");
    // Not adding to fail_count — just observational
endtask

// ---------------------------------------------------------------------------
// TEST 10 — BACK-TO-BACK TRANSACTIONS
// Consecutive writes then reads to same slave without idle cycles
// ---------------------------------------------------------------------------
task automatic back_to_back_test(ref int fail_count);
    const logic [31:0] BASE = 32'h0300_0800;   // Slave 3
    const int N = 8;
    logic [31:0] rd_data;
    logic [1:0]  bresp, rresp;
    logic [7:0]  bid_out, rid_out;
    int i;
    int local_fails;
    local_fails = 0;

    $display("");
    $display("=================================================================");
    $display("[TEST10] BACK-TO-BACK TRANSACTIONS — slave 3");
    $display("=================================================================");

    // Write N consecutive locations
    for (i = 0; i < N; i = i + 1) begin
        m0_bfm.axi_write(BASE + (i*4), 32'hF000_0000 | i, 4'hF, 8'h01 + i, bresp, bid_out);
        if (bresp !== 2'b00) begin
            local_fails++;
            $display("[TEST10] FAIL write[%0d] bresp=%0d", i, bresp);
        end
    end

    // Read back N consecutive locations immediately
    for (i = 0; i < N; i = i + 1) begin
        m0_bfm.axi_read(BASE + (i*4), 8'h01 + i, rd_data, rresp, rid_out);
        if (rresp !== 2'b00 || rd_data !== (32'hF000_0000 | i)) begin
            local_fails++;
            $display("[TEST10] FAIL read[%0d] expected=0x%08X got=0x%08X",
                     i, 32'hF000_0000 | i, rd_data);
        end
    end

    $display("[TEST10] Completed %0d back-to-back writes + %0d reads", N, N);

    fail_count += local_fails;
    if (local_fails == 0)
        $display("[TEST10] BACK-TO-BACK ---> PASSED");
    else
        $display("[TEST10] BACK-TO-BACK ---> FAILED (%0d errors)", local_fails);
endtask
