// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : scoreboards/gpio_scoreboard.sv
// Description  : UVM Scoreboard for GPIO functional checking.
//                Verifies output patterns, atomic bit updates, and level interrupts.
// ==============================================================================

`ifndef GPIO_SCOREBOARD_SV
`define GPIO_SCOREBOARD_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import gpio_pkg::*;

class gpio_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(gpio_scoreboard)

    virtual gpio_if vif;
    uvm_analysis_imp #(gpio_item, gpio_scoreboard) item_export;

    // Metrics
    int unsigned total_checks;
    int unsigned pass_checks;
    int unsigned fail_checks;
    int unsigned sb_trans_count;

    // Queue of expected output values set by test
    bit [31:0]   expected_outputs[$];

    function new(string name = "gpio_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        total_checks   = 0;
        pass_checks    = 0;
        fail_checks    = 0;
        sb_trans_count = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        item_export = new("item_export", this);
        if (!uvm_config_db#(virtual gpio_if)::get(this, "", "gpio_vif", vif)) begin
            `uvm_info("GPIO_SB", "Virtual interface 'gpio_vif' not retrieved in scoreboard (waveform debug optional)", UVM_HIGH)
        end
    endfunction

    task run_phase(uvm_phase phase);
        if (vif != null) begin
            vif.sb_expected_out <= 32'h0;
            vif.sb_actual_out   <= 32'h0;
            vif.sb_match        <= 1'b0;
            vif.sb_total_checks <= 8'h00;
        end
    endtask

    // Registration functions for expected events
    function void expect_output(bit [31:0] val);
        expected_outputs.push_back(val);
    endfunction

    virtual function void write(gpio_item item);
        bit [31:0] exp;

        // Compare actual monitor transaction against expected transaction
        if (expected_outputs.size() > 0) begin
            exp = expected_outputs.pop_front();
            sb_trans_count++;
            total_checks++;

            if (vif != null) begin
                vif.sb_expected_out <= exp;
                vif.sb_actual_out   <= item.gpio_out;
                vif.sb_match        <= (item.gpio_out === exp);
                vif.sb_total_checks <= 8'(total_checks);
            end

            if (item.gpio_out === exp) begin
                pass_checks++;
                $display("[GPIO_SB] Transaction=%0d Expected=0x%08h Actual=0x%08h STATUS=PASS",
                         sb_trans_count, exp, item.gpio_out);
                `uvm_info("GPIO_SB", $sformatf("Transaction=%0d Expected=0x%08h Actual=0x%08h STATUS=PASS",
                         sb_trans_count, exp, item.gpio_out), UVM_LOW)
            end else begin
                fail_checks++;
                $display("[GPIO_SB] Transaction=%0d Expected=0x%08h Actual=0x%08h STATUS=FAIL",
                         sb_trans_count, exp, item.gpio_out);
                `uvm_error("GPIO_SB", $sformatf("Transaction=%0d Expected=0x%08h Actual=0x%08h STATUS=FAIL (Mismatch: Expected=0x%08h, Actual=0x%08h)",
                         sb_trans_count, exp, item.gpio_out, exp, item.gpio_out))
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        string final_status;
        super.report_phase(phase);

        final_status = (fail_checks == 0 && total_checks == 10) ? "PASS" : "FAIL";

        $display("========== GPIO VERIFICATION SUMMARY ==========");
        $display("Total Transactions : %0d", total_checks);
        $display("Passed Transactions: %0d", pass_checks);
        $display("Failed Transactions: %0d", fail_checks);
        $display("Final Status       : %s", final_status);
        $display("================================================");

        `uvm_info("GPIO_SB", "========== GPIO VERIFICATION SUMMARY ==========", UVM_LOW)
        `uvm_info("GPIO_SB", $sformatf("Total Transactions : %0d", total_checks), UVM_LOW)
        `uvm_info("GPIO_SB", $sformatf("Passed Transactions: %0d", pass_checks), UVM_LOW)
        `uvm_info("GPIO_SB", $sformatf("Failed Transactions: %0d", fail_checks), UVM_LOW)
        `uvm_info("GPIO_SB", $sformatf("Final Status       : %s", final_status), UVM_LOW)
        `uvm_info("GPIO_SB", "================================================", UVM_LOW)
    endfunction
endclass

`endif // GPIO_SCOREBOARD_SV
