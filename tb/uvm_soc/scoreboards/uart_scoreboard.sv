// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : scoreboards/uart_scoreboard.sv
// Description  : UVM Scoreboard for UART serial protocol checking.
//                Verifies framing, data integrity, and byte ordering.
// ==============================================================================

`ifndef UART_SCOREBOARD_SV
`define UART_SCOREBOARD_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import uart_pkg::*;

class uart_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(uart_scoreboard)

    virtual uart_if vif;
    uvm_analysis_imp #(uart_item, uart_scoreboard) item_export;

    // Metrics
    int unsigned total_checks;
    int unsigned pass_checks;
    int unsigned fail_checks;

    // Expected byte queue from test stimulus
    byte unsigned expected_tx_queue[$];

    function new(string name = "uart_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        total_checks = 0;
        pass_checks  = 0;
        fail_checks  = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        item_export = new("item_export", this);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "uart_vif", vif)) begin
            `uvm_info("UART_SB", "Virtual interface 'uart_vif' not retrieved in scoreboard (waveform debug optional)", UVM_HIGH)
        end
    endfunction

    task run_phase(uvm_phase phase);
        if (vif != null) begin
            vif.sb_expected_byte <= 8'h00;
            vif.sb_actual_byte   <= 8'h00;
            vif.sb_match         <= 1'b0;
            vif.sb_check_valid   <= 1'b0;
            vif.sb_total_checks  <= 8'h00;
        end
    endtask

    function void expect_tx_byte(byte unsigned b);
        expected_tx_queue.push_back(b);
    endfunction

    virtual function void write(uart_item item);
        `uvm_info("UART_SB", $sformatf("Received item: data=0x%02h ('%c'), framing_err=%b",
                               item.data, ((item.data >= 32 && item.data <= 126) ? item.data : "."), item.framing_error), UVM_HIGH)

        // 1. Check Framing Error
        total_checks++;
        if (vif != null) begin
            vif.sb_total_checks <= 8'(total_checks);
        end
        if (item.framing_error == 1'b0) begin
            pass_checks++;
            `uvm_info("UART_SB", "[CHECK PASS] Stop bit framing valid (no framing error)", UVM_MEDIUM)
        end else begin
            fail_checks++;
            `uvm_error("UART_SB", "[CHECK FAIL] Framing error detected on UART TX frame!")
        end

        // 2. Check Data Payload
        if (expected_tx_queue.size() > 0) begin
            byte unsigned exp = expected_tx_queue.pop_front();
            total_checks++;
            if (vif != null) begin
                vif.sb_expected_byte <= exp;
                vif.sb_actual_byte   <= item.data;
                vif.sb_match         <= (item.data === exp);
                vif.sb_check_valid   <= 1'b1;
                vif.sb_total_checks  <= 8'(total_checks);
            end
            if (item.data === exp) begin
                pass_checks++;
                `uvm_info("UART_SB", $sformatf("[CHECK PASS] Transmitted byte matches expected: Actual=0x%02h, Expected=0x%02h",
                                        item.data, exp), UVM_MEDIUM)
            end else begin
                fail_checks++;
                `uvm_error("UART_SB", $sformatf("[CHECK FAIL] Transmitted byte MISMATCH! Actual=0x%02h, Expected=0x%02h",
                                        item.data, exp))
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("UART_SB", "--------------------------------------------------------", UVM_LOW)
        `uvm_info("UART_SB", "               UART SCOREBOARD REPORT                   ", UVM_LOW)
        `uvm_info("UART_SB", $sformatf("  Total Verification Checks : %0d", total_checks), UVM_LOW)
        `uvm_info("UART_SB", $sformatf("  Passed Checks             : %0d", pass_checks), UVM_LOW)
        `uvm_info("UART_SB", $sformatf("  Failed Checks             : %0d", fail_checks), UVM_LOW)
        if (fail_checks == 0 && total_checks > 0) begin
            `uvm_info("UART_SB", "  >>> STATUS: UART VERIFICATION PASSED 100% <<<", UVM_LOW)
        end else if (total_checks == 0) begin
            `uvm_warning("UART_SB", "  >>> STATUS: NO ACTIVE CHECKS EVALUATED <<<")
        end else begin
            `uvm_error("UART_SB", "  >>> STATUS: UART VERIFICATION FAILED <<<")
        end
        `uvm_info("UART_SB", "--------------------------------------------------------", UVM_LOW)
    endfunction
endclass

`endif // UART_SCOREBOARD_SV
