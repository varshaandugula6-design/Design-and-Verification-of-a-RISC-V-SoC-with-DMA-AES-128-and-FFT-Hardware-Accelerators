// =============================================================================
// File        : tests/basic_rw_test.sv
// Description : TEST 2 — MASTER 0 WRITE/READ to all 7 slaves
//               TEST 3 — MASTER 1 WRITE/READ to all 7 slaves
//               TEST 4 — MASTER 2 WRITE/READ to all 7 slaves
//
// For each master:
//   1. Write a unique data value to a test address in each slave's region
//   2. Read back the same address
//   3. Verify returned data matches written data
//   4. Verify BRESP and RRESP are OKAY (2'b00)
//
// Address map (from DUT defaults, M_ADDR_WIDTH=24, auto-computed base):
//   Slave 0: 0x00000000  Slave 1: 0x01000000  Slave 2: 0x02000000
//   Slave 3: 0x03000000  Slave 4: 0x04000000  Slave 5: 0x05000000
//   Slave 6: 0x06000000
// =============================================================================

`timescale 1ns/1ps

// This file is `included into tb_top — exposes tasks basic_rw_test_m0/m1/m2
// and the shared helper basic_rw_one_master.

// ---------------------------------------------------------------------------
// TEST 2 — MASTER 0 write/read to all 7 slaves
// ---------------------------------------------------------------------------
task automatic basic_rw_test_m0(ref int fail_count);
    const logic [31:0] TEST_ADDR [0:6] = '{
        32'h0000_0100, 32'h0100_0100, 32'h0200_0100,
        32'h0300_0100, 32'h0400_0100, 32'h0500_0100, 32'h0600_0100
    };
    // Write data per slave: pattern = {0, slave, 0xAB, offset}
    const logic [31:0] WR_DATA [0:6] = '{
        32'h00AB_0000, 32'h01AB_0001, 32'h02AB_0002,
        32'h03AB_0003, 32'h04AB_0004, 32'h05AB_0005, 32'h06AB_0006
    };

    logic [31:0] rd_data;
    logic [1:0]  bresp, rresp;
    logic [7:0]  bid_out, rid_out;
    int s;
    int local_fails;
    local_fails = 0;

    $display("");
    $display("=================================================================");
    $display("[TEST2] MASTER 0 WRITE/READ — all 7 slaves");
    $display("=================================================================");

    for (s = 0; s < 7; s = s + 1) begin
        // --- WRITE ---
        scoreboard.record_write(0, TEST_ADDR[s], WR_DATA[s], 4'hF, 8'h10 + s);
        m0_bfm.axi_write(TEST_ADDR[s], WR_DATA[s], 4'hF, 8'h10 + s, bresp, bid_out);
        scoreboard.check_write_resp(0, TEST_ADDR[s], bresp, bid_out);
        if (bresp !== 2'b00) local_fails++;

        // --- READ BACK ---
        scoreboard.record_read(0, TEST_ADDR[s], 8'h20 + s);
        m0_bfm.axi_read(TEST_ADDR[s], 8'h20 + s, rd_data, rresp, rid_out);
        scoreboard.check_read_resp(0, TEST_ADDR[s], rd_data, WR_DATA[s], rresp, rid_out);
        if (rresp !== 2'b00 || rd_data !== WR_DATA[s]) local_fails++;

        $display("[TEST2]   slave%0d addr=0x%08X wr=0x%08X rd=0x%08X bresp=%0d rresp=%0d %s",
                 s, TEST_ADDR[s], WR_DATA[s], rd_data, bresp, rresp,
                 (rd_data===WR_DATA[s] && bresp===2'b00 && rresp===2'b00) ? "PASS" : "FAIL");
    end

    fail_count += local_fails;
    if (local_fails == 0)
        $display("[TEST2] MASTER 0 WRITE/READ ---> PASSED");
    else
        $display("[TEST2] MASTER 0 WRITE/READ ---> FAILED (%0d errors)", local_fails);
endtask

// ---------------------------------------------------------------------------
// TEST 3 — MASTER 1 write/read to all 7 slaves
// ---------------------------------------------------------------------------
task automatic basic_rw_test_m1(ref int fail_count);
    const logic [31:0] TEST_ADDR [0:6] = '{
        32'h0000_0200, 32'h0100_0200, 32'h0200_0200,
        32'h0300_0200, 32'h0400_0200, 32'h0500_0200, 32'h0600_0200
    };
    const logic [31:0] WR_DATA [0:6] = '{
        32'h10CD_0010, 32'h11CD_0011, 32'h12CD_0012,
        32'h13CD_0013, 32'h14CD_0014, 32'h15CD_0015, 32'h16CD_0016
    };

    logic [31:0] rd_data;
    logic [1:0]  bresp, rresp;
    logic [7:0]  bid_out, rid_out;
    int s;
    int local_fails;
    local_fails = 0;

    $display("");
    $display("=================================================================");
    $display("[TEST3] MASTER 1 WRITE/READ — all 7 slaves");
    $display("=================================================================");

    for (s = 0; s < 7; s = s + 1) begin
        scoreboard.record_write(1, TEST_ADDR[s], WR_DATA[s], 4'hF, 8'h30 + s);
        m1_bfm.axi_write(TEST_ADDR[s], WR_DATA[s], 4'hF, 8'h30 + s, bresp, bid_out);
        scoreboard.check_write_resp(1, TEST_ADDR[s], bresp, bid_out);
        if (bresp !== 2'b00) local_fails++;

        scoreboard.record_read(1, TEST_ADDR[s], 8'h40 + s);
        m1_bfm.axi_read(TEST_ADDR[s], 8'h40 + s, rd_data, rresp, rid_out);
        scoreboard.check_read_resp(1, TEST_ADDR[s], rd_data, WR_DATA[s], rresp, rid_out);
        if (rresp !== 2'b00 || rd_data !== WR_DATA[s]) local_fails++;

        $display("[TEST3]   slave%0d addr=0x%08X wr=0x%08X rd=0x%08X bresp=%0d rresp=%0d %s",
                 s, TEST_ADDR[s], WR_DATA[s], rd_data, bresp, rresp,
                 (rd_data===WR_DATA[s] && bresp===2'b00 && rresp===2'b00) ? "PASS" : "FAIL");
    end

    fail_count += local_fails;
    if (local_fails == 0)
        $display("[TEST3] MASTER 1 WRITE/READ ---> PASSED");
    else
        $display("[TEST3] MASTER 1 WRITE/READ ---> FAILED (%0d errors)", local_fails);
endtask

// ---------------------------------------------------------------------------
// TEST 4 — MASTER 2 write/read to all 7 slaves
// ---------------------------------------------------------------------------
task automatic basic_rw_test_m2(ref int fail_count);
    const logic [31:0] TEST_ADDR [0:6] = '{
        32'h0000_0300, 32'h0100_0300, 32'h0200_0300,
        32'h0300_0300, 32'h0400_0300, 32'h0500_0300, 32'h0600_0300
    };
    const logic [31:0] WR_DATA [0:6] = '{
        32'h20EF_0020, 32'h21EF_0021, 32'h22EF_0022,
        32'h23EF_0023, 32'h24EF_0024, 32'h25EF_0025, 32'h26EF_0026
    };

    logic [31:0] rd_data;
    logic [1:0]  bresp, rresp;
    logic [7:0]  bid_out, rid_out;
    int s;
    int local_fails;
    local_fails = 0;

    $display("");
    $display("=================================================================");
    $display("[TEST4] MASTER 2 WRITE/READ — all 7 slaves");
    $display("=================================================================");

    for (s = 0; s < 7; s = s + 1) begin
        scoreboard.record_write(2, TEST_ADDR[s], WR_DATA[s], 4'hF, 8'h50 + s);
        m2_bfm.axi_write(TEST_ADDR[s], WR_DATA[s], 4'hF, 8'h50 + s, bresp, bid_out);
        scoreboard.check_write_resp(2, TEST_ADDR[s], bresp, bid_out);
        if (bresp !== 2'b00) local_fails++;

        scoreboard.record_read(2, TEST_ADDR[s], 8'h60 + s);
        m2_bfm.axi_read(TEST_ADDR[s], 8'h60 + s, rd_data, rresp, rid_out);
        scoreboard.check_read_resp(2, TEST_ADDR[s], rd_data, WR_DATA[s], rresp, rid_out);
        if (rresp !== 2'b00 || rd_data !== WR_DATA[s]) local_fails++;

        $display("[TEST4]   slave%0d addr=0x%08X wr=0x%08X rd=0x%08X bresp=%0d rresp=%0d %s",
                 s, TEST_ADDR[s], WR_DATA[s], rd_data, bresp, rresp,
                 (rd_data===WR_DATA[s] && bresp===2'b00 && rresp===2'b00) ? "PASS" : "FAIL");
    end

    fail_count += local_fails;
    if (local_fails == 0)
        $display("[TEST4] MASTER 2 WRITE/READ ---> PASSED");
    else
        $display("[TEST4] MASTER 2 WRITE/READ ---> FAILED (%0d errors)", local_fails);
endtask
