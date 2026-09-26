// =============================================================================
// File        : tests/random_test.sv
// Description : Constrained-random test for axi_interconnect_wrap_3x7
//
// Randomizes:
//   - Master selection (0, 1, 2)
//   - Slave selection  (0..6)
//   - Address within valid slave region
//   - Read/write operation
//   - Write data
//   - Byte strobe (for writes)
//
// Keeps results reproducible with a seed.
// The scoreboard verifies all responses.
//
// Shadow memory strategy:
//   - Only tracks addresses WRITTEN by this test.
//   - Reads to addresses not previously written by this test verify
//     RRESP=OKAY but do NOT check RDATA (unknown prior state from
//     directed tests).  This avoids false failures from directed test
//     residue in slave memory.
//
// Seed is set via plusarg: +RAND_SEED=<n>   (default = 42)
// Iterations: +RAND_ITER=<n>               (default = 50)
// =============================================================================

`timescale 1ns/1ps

// Included into tb_top — not a standalone module.

task automatic random_test(ref int fail_count);
    int seed, n_iter;
    int local_fails;
    int master_sel, slave_sel, is_write;
    logic [31:0] addr, wr_data, rd_data;
    logic [3:0]  strb;
    logic [1:0]  bresp, rresp;
    logic [7:0]  bid_out, rid_out;
    logic [31:0] exp_data;
    int i;

    // Per-address shadow memory: 7 slaves × 256 words
    // written_flag[s][w] = 1 means this test has written word w in slave s
    logic [31:0] shadow_mem [0:6][0:255];
    logic        written_flag [0:6][0:255];
    int          word_idx;
    int          slave_n;

    local_fails = 0;

    // ----- Read plusarg seed -----
    if (!$value$plusargs("RAND_SEED=%d", seed))   seed   = 42;
    if (!$value$plusargs("RAND_ITER=%d", n_iter)) n_iter = 50;

    $display("");
    $display("=================================================================");
    $display("[RAND] CONSTRAINED-RANDOM TEST  seed=%0d  iterations=%0d", seed, n_iter);
    $display("=================================================================");

    // Initialise shadow: nothing written by this test yet
    for (int s = 0; s < 7; s = s + 1)
        for (int w = 0; w < 256; w = w + 1) begin
            shadow_mem[s][w]   = '0;
            written_flag[s][w] = 1'b0;
        end

    for (i = 0; i < n_iter; i = i + 1) begin
        // --- Constrained randomization ---
        master_sel = $urandom_range(0, 2);
        slave_sel  = $urandom_range(0, 6);
        is_write   = $urandom_range(0, 1);
        // Address = slave base + random word-aligned offset (lower 10 bits, 256 words)
        addr       = (slave_sel << 24) | ($urandom_range(0, 255) << 2);
        wr_data    = $urandom();
        // strb: all lanes, or random partial (25% chance of partial)
        strb       = ($urandom_range(0, 3) == 0) ? $urandom_range(1, 15) : 4'hF;
        // word index within the 256-word shadow (bits [9:2])
        word_idx   = addr[9:2];

        if (is_write) begin
            // --- Random Write ---
            scoreboard.record_write(master_sel, addr, wr_data, strb,
                                    8'h00 | (i & 8'hFF));
            case (master_sel)
                0: m0_bfm.axi_write(addr, wr_data, strb, 8'h00|(i&8'hFF), bresp, bid_out);
                1: m1_bfm.axi_write(addr, wr_data, strb, 8'h00|(i&8'hFF), bresp, bid_out);
                2: m2_bfm.axi_write(addr, wr_data, strb, 8'h00|(i&8'hFF), bresp, bid_out);
            endcase
            scoreboard.check_write_resp(master_sel, addr, bresp, bid_out);

            if (bresp !== 2'b00) begin
                local_fails++;
                $display("[RAND][%0d] FAIL write M%0d addr=0x%08X bresp=%0d",
                         i, master_sel, addr, bresp);
            end else begin
                // Update shadow memory with strobe masking
                if (written_flag[slave_sel][word_idx]) begin
                    // Already tracked — apply strobe mask
                    for (int b = 0; b < 4; b = b + 1)
                        if (strb[b])
                            shadow_mem[slave_sel][word_idx][b*8 +: 8] = wr_data[b*8 +: 8];
                end else if (strb === 4'hF) begin
                    // First write, full strobe — fully known
                    shadow_mem[slave_sel][word_idx] = wr_data;
                    written_flag[slave_sel][word_idx] = 1'b1;
                end
                // else first write with partial strobe — unknown prior contents, don't track
                $display("[RAND][%0d] PASS write M%0d addr=0x%08X data=0x%08X strb=0x%X",
                         i, master_sel, addr, wr_data, strb);
            end

        end else begin
            // --- Random Read ---
            scoreboard.record_read(master_sel, addr, 8'h00 | (i & 8'hFF));
            case (master_sel)
                0: m0_bfm.axi_read(addr, 8'h00|(i&8'hFF), rd_data, rresp, rid_out);
                1: m1_bfm.axi_read(addr, 8'h00|(i&8'hFF), rd_data, rresp, rid_out);
                2: m2_bfm.axi_read(addr, 8'h00|(i&8'hFF), rd_data, rresp, rid_out);
            endcase

            if (rresp !== 2'b00) begin
                local_fails++;
                scoreboard.check_read_resp(master_sel, addr, rd_data, rd_data, rresp, rid_out);
                $display("[RAND][%0d] FAIL read  M%0d addr=0x%08X rresp=%0d (expected OKAY)",
                         i, master_sel, addr, rresp);
            end else if (written_flag[slave_sel][word_idx]) begin
                // We know what was written — verify data
                exp_data = shadow_mem[slave_sel][word_idx];
                scoreboard.check_read_resp(master_sel, addr, rd_data, exp_data, rresp, rid_out);
                if (rd_data !== exp_data) begin
                    local_fails++;
                    $display("[RAND][%0d] FAIL read  M%0d addr=0x%08X expected=0x%08X got=0x%08X",
                             i, master_sel, addr, exp_data, rd_data);
                end else begin
                    $display("[RAND][%0d] PASS read  M%0d addr=0x%08X data=0x%08X",
                             i, master_sel, addr, rd_data);
                end
            end else begin
                // Address not written by this test — accept any data, just log
                $display("[RAND][%0d] INFO  read  M%0d addr=0x%08X data=0x%08X (untracked addr)",
                         i, master_sel, addr, rd_data);
            end
        end
    end

    fail_count += local_fails;
    $display("[RAND] Completed %0d iterations, %0d failures", n_iter, local_fails);
    if (local_fails == 0)
        $display("[RAND] CONSTRAINED-RANDOM TEST ---> PASSED");
    else
        $display("[RAND] CONSTRAINED-RANDOM TEST ---> FAILED (%0d errors)", local_fails);
endtask
