// =============================================================================
// File        : axi_scoreboard.sv
// Description : Self-checking scoreboard for axi_interconnect_wrap_3x7 TB.
//
// Address Map (verified from DUT defaults, M_ADDR_WIDTH=24, M_BASE_ADDR=0):
//   Slave 0 (m00): 0x00000000 – 0x00FFFFFF  (16 MB)
//   Slave 1 (m01): 0x01000000 – 0x01FFFFFF
//   Slave 2 (m02): 0x02000000 – 0x02FFFFFF
//   Slave 3 (m03): 0x03000000 – 0x03FFFFFF
//   Slave 4 (m04): 0x04000000 – 0x04FFFFFF
//   Slave 5 (m05): 0x05000000 – 0x05FFFFFF
//   Slave 6 (m06): 0x06000000 – 0x06FFFFFF
//   Unmapped:      0x07000000 and above
//
// Usage from tb_top:
//   scoreboard.record_write(master_id, addr, data, strb, txn_id);
//   scoreboard.check_write_resp(master_id, addr, actual_bresp, actual_bid);
//   scoreboard.record_read(master_id, addr, txn_id);
//   scoreboard.check_read_resp(master_id, addr, actual_rdata, actual_rresp, actual_rid);
//   scoreboard.check_slave_activity(expected_slave, active_slaves_mask);
//   scoreboard.report();
// =============================================================================

`timescale 1ns/1ps

module axi_scoreboard #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 8,
    parameter STRB_WIDTH = 4,
    parameter NUM_SLAVES = 7,
    parameter NUM_MASTERS = 3
) ();

    // =========================================================================
    // Address map constants (match DUT parameter defaults)
    // M_ADDR_WIDTH = 24 bits → 16 MB windows, base = N << 24
    // =========================================================================
    localparam [ADDR_WIDTH-1:0] BASE [0:6] = '{
        32'h0000_0000,
        32'h0100_0000,
        32'h0200_0000,
        32'h0300_0000,
        32'h0400_0000,
        32'h0500_0000,
        32'h0600_0000
    };
    localparam [ADDR_WIDTH-1:0] MASK = 32'h00FF_FFFF;  // 24-bit window

    // =========================================================================
    // Statistics counters
    // =========================================================================
    int pass_count;
    int fail_count;
    int total_writes;
    int total_reads;

    initial begin
        pass_count   = 0;
        fail_count   = 0;
        total_writes = 0;
        total_reads  = 0;
    end

    // =========================================================================
    // Address→slave decoder
    // Returns -1 if unmapped
    // =========================================================================
    function automatic int addr_to_slave(input logic [ADDR_WIDTH-1:0] addr);
        int i;
        for (i = 0; i < NUM_SLAVES; i = i + 1) begin
            if ((addr & ~MASK) == BASE[i])
                return i;
        end
        return -1;
    endfunction

    // =========================================================================
    // Expected read data formula (must match axi_slave_model)
    // Returns default signature; write-through not tracked here — callers
    // pass the expected value explicitly after a write.
    // =========================================================================
    function automatic [DATA_WIDTH-1:0] expected_default_rdata(
        input int slave_id,
        input logic [ADDR_WIDTH-1:0] addr
    );
        expected_default_rdata = {slave_id[3:0], 4'hF, 8'h00, addr[15:0]};
    endfunction

    // =========================================================================
    // record_write: log a write transaction, compute expected slave
    // =========================================================================
    task automatic record_write(
        input int                     master_id,
        input logic [ADDR_WIDTH-1:0]  addr,
        input logic [DATA_WIDTH-1:0]  data,
        input logic [STRB_WIDTH-1:0]  strb,
        input logic [ID_WIDTH-1:0]    txn_id
    );
        int exp_slave;
        exp_slave = addr_to_slave(addr);
        total_writes++;
        $display("[SCB] WRITE  M%0d addr=0x%08X data=0x%08X strb=0x%X id=0x%02X → expected slave %0d",
                 master_id, addr, data, strb, txn_id, exp_slave);
    endtask

    // =========================================================================
    // check_write_resp: verify BRESP is OKAY for mapped, report for unmapped
    // =========================================================================
    task automatic check_write_resp(
        input int                     master_id,
        input logic [ADDR_WIDTH-1:0]  addr,
        input logic [1:0]             actual_bresp,
        input logic [ID_WIDTH-1:0]    actual_bid
    );
        int exp_slave;
        string resp_str;
        exp_slave = addr_to_slave(addr);

        case (actual_bresp)
            2'b00: resp_str = "OKAY";
            2'b01: resp_str = "EXOKAY";
            2'b10: resp_str = "SLVERR";
            2'b11: resp_str = "DECERR";
        endcase

        if (exp_slave >= 0) begin
            // Mapped address — expect OKAY
            if (actual_bresp == 2'b00) begin
                pass_count++;
                $display("[SCB] PASS  write resp M%0d addr=0x%08X slave%0d BRESP=%s BID=0x%02X",
                         master_id, addr, exp_slave, resp_str, actual_bid);
            end else begin
                fail_count++;
                $display("[ERROR][SCB] FAIL write resp M%0d addr=0x%08X expected slave%0d OKAY, got %s BID=0x%02X",
                         master_id, addr, exp_slave, resp_str, actual_bid);
            end
        end else begin
            // Unmapped — just report actual behaviour
            $display("[SCB] INFO  write to UNMAPPED addr=0x%08X M%0d BRESP=%s BID=0x%02X (no OKAY expectation)",
                     addr, master_id, resp_str, actual_bid);
        end
    endtask

    // =========================================================================
    // record_read: log a read transaction
    // =========================================================================
    task automatic record_read(
        input int                     master_id,
        input logic [ADDR_WIDTH-1:0]  addr,
        input logic [ID_WIDTH-1:0]    txn_id
    );
        int exp_slave;
        exp_slave = addr_to_slave(addr);
        total_reads++;
        $display("[SCB] READ   M%0d addr=0x%08X id=0x%02X → expected slave %0d",
                 master_id, addr, txn_id, exp_slave);
    endtask

    // =========================================================================
    // check_read_resp: verify rdata matches slave signature and resp is OKAY
    //   expected_data: caller supplies what was expected (either default sig
    //                  or what was previously written)
    // =========================================================================
    task automatic check_read_resp(
        input int                     master_id,
        input logic [ADDR_WIDTH-1:0]  addr,
        input logic [DATA_WIDTH-1:0]  actual_rdata,
        input logic [DATA_WIDTH-1:0]  expected_data,
        input logic [1:0]             actual_rresp,
        input logic [ID_WIDTH-1:0]    actual_rid
    );
        int exp_slave;
        string resp_str;
        exp_slave = addr_to_slave(addr);

        case (actual_rresp)
            2'b00: resp_str = "OKAY";
            2'b01: resp_str = "EXOKAY";
            2'b10: resp_str = "SLVERR";
            2'b11: resp_str = "DECERR";
        endcase

        if (exp_slave >= 0) begin
            // Check response code
            if (actual_rresp !== 2'b00) begin
                fail_count++;
                $display("[ERROR][SCB] FAIL read resp M%0d addr=0x%08X exp OKAY got %s",
                         master_id, addr, resp_str);
            end
            // Check data
            if (actual_rdata === expected_data) begin
                pass_count++;
                $display("[SCB] PASS  read  data M%0d addr=0x%08X slave%0d rdata=0x%08X RID=0x%02X",
                         master_id, addr, exp_slave, actual_rdata, actual_rid);
            end else begin
                fail_count++;
                $display("[ERROR][SCB] FAIL read  data M%0d addr=0x%08X slave%0d expected=0x%08X actual=0x%08X RID=0x%02X",
                         master_id, addr, exp_slave, expected_data, actual_rdata, actual_rid);
            end
        end else begin
            // Unmapped — report
            $display("[SCB] INFO  read from UNMAPPED addr=0x%08X M%0d RRESP=%s RDATA=0x%08X (observed)",
                     addr, master_id, resp_str, actual_rdata);
        end
    endtask

    // =========================================================================
    // check_slave_activity:
    //   Assert that the expected slave's AWVALID/ARVALID is high, and no
    //   other slave port has AWVALID/ARVALID high simultaneously.
    //   active_aw_mask / active_ar_mask = per-slave bit vector sampled from DUT
    // =========================================================================
    task automatic check_exclusive_slave_select(
        input int  expected_slave,
        input logic [NUM_SLAVES-1:0] active_aw_mask,
        input string txn_label
    );
        int i;
        if (expected_slave < 0) begin
            $display("[SCB] INFO  %s targets unmapped address, active_aw=%07b",
                     txn_label, active_aw_mask);
            return;
        end

        // Expected slave must be active
        if (!active_aw_mask[expected_slave]) begin
            fail_count++;
            $display("[ERROR][SCB] %s: expected slave %0d AWVALID=0, active_aw=%07b",
                     txn_label, expected_slave, active_aw_mask);
        end else begin
            pass_count++;
            $display("[SCB] PASS  %s: slave%0d selected correctly active_aw=%07b",
                     txn_label, expected_slave, active_aw_mask);
        end

        // No other slave should be active for the same transaction
        for (i = 0; i < NUM_SLAVES; i = i + 1) begin
            if (i != expected_slave && active_aw_mask[i]) begin
                fail_count++;
                $display("[ERROR][SCB] %s: UNEXPECTED slave%0d also active! active_aw=%07b",
                         txn_label, i, active_aw_mask);
            end
        end
    endtask

    // =========================================================================
    // report — print final summary
    // =========================================================================
    task automatic report();
        $display("=================================================================");
        $display("[SCB] SCOREBOARD FINAL REPORT");
        $display("[SCB]   Total writes      : %0d", total_writes);
        $display("[SCB]   Total reads       : %0d", total_reads);
        $display("[SCB]   Checks passed     : %0d", pass_count);
        $display("[SCB]   Checks failed     : %0d", fail_count);
        if (fail_count == 0)
            $display("[SCB]   OVERALL RESULT   : PASS");
        else
            $display("[SCB]   OVERALL RESULT   : FAIL  (%0d failures)", fail_count);
        $display("=================================================================");
    endtask

    // =========================================================================
    // Helper: print per-test header
    // =========================================================================
    task automatic test_header(input string name);
        $display("");
        $display("=================================================================");
        $display("[TEST] %s", name);
        $display("=================================================================");
    endtask

    // =========================================================================
    // Helper: print per-test result
    // =========================================================================
    task automatic test_result(input string name, input int local_fails);
        if (local_fails == 0)
            $display("[TEST] %s  ---> PASSED", name);
        else
            $display("[TEST] %s  ---> FAILED (%0d errors)", name, local_fails);
    endtask

endmodule : axi_scoreboard
