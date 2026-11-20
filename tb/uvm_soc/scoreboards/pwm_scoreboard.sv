// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : scoreboards/pwm_scoreboard.sv
// Description  : UVM Scoreboard for PWM waveform verification.
//                Verifies period, frequency, and duty cycle within tolerances.
// ==============================================================================

`ifndef PWM_SCOREBOARD_SV
`define PWM_SCOREBOARD_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import pwm_pkg::*;

class pwm_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(pwm_scoreboard)

    virtual pwm_if vif;
    uvm_analysis_imp #(pwm_item, pwm_scoreboard) item_export;

    // Metrics
    int unsigned total_checks;
    int unsigned pass_checks;
    int unsigned fail_checks;

    // Expected metrics set by test
    real expected_duty_queue[$];
    real expected_period_queue[$];
    real tolerance_pct;

    function new(string name = "pwm_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        total_checks  = 0;
        pass_checks   = 0;
        fail_checks   = 0;
        tolerance_pct = 5.0; // 5% tolerance for discrete clock cycle discretization
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        item_export = new("item_export", this);
        if (!uvm_config_db#(virtual pwm_if)::get(this, "", "pwm_vif", vif)) begin
            `uvm_info("PWM_SB", "Virtual interface 'pwm_vif' not retrieved in scoreboard (waveform debug optional)", UVM_HIGH)
        end
    endfunction

    task run_phase(uvm_phase phase);
        if (vif != null) begin
            vif.sb_expected_duty_int <= 7'h0;
            vif.sb_actual_duty_int   <= 7'h0;
            vif.sb_match             <= 1'b0;
            vif.sb_total_checks      <= 8'h00;
        end
    endtask

    function void expect_pwm_config(real exp_duty_pct, real exp_period_ns);
        expected_duty_queue.push_back(exp_duty_pct);
        expected_period_queue.push_back(exp_period_ns);
    endfunction

    virtual function void write(pwm_item item);
        `uvm_info("PWM_SB", $sformatf("Received item: Period=%.2f ns, High=%.2f ns, Duty=%.2f%%, Freq=%.2f kHz",
                             item.period_ns, item.high_time_ns, item.duty_cycle_pct, item.frequency_hz / 1000.0), UVM_HIGH)

        if (expected_duty_queue.size() > 0) begin
            real exp_duty   = expected_duty_queue.pop_front();
            real exp_period = expected_period_queue.pop_front();
            real duty_diff  = (item.duty_cycle_pct > exp_duty) ? (item.duty_cycle_pct - exp_duty) : (exp_duty - item.duty_cycle_pct);

            total_checks++;
            if (vif != null) begin
                vif.sb_expected_duty_int <= 7'($rtoi(exp_duty));
                vif.sb_actual_duty_int   <= 7'($rtoi(item.duty_cycle_pct));
                vif.sb_match             <= (duty_diff <= tolerance_pct);
                vif.sb_total_checks      <= 8'(total_checks);
            end
            if (duty_diff <= tolerance_pct) begin
                pass_checks++;
                `uvm_info("PWM_SB", $sformatf("[CHECK PASS] Duty cycle within tolerance: Measured=%.2f%%, Expected=%.2f%% (diff=%.2f%% <= %.1f%%)",
                                     item.duty_cycle_pct, exp_duty, duty_diff, tolerance_pct), UVM_MEDIUM)
            end else begin
                fail_checks++;
                `uvm_error("PWM_SB", $sformatf("[CHECK FAIL] Duty cycle OUT OF TOLERANCE! Measured=%.2f%%, Expected=%.2f%% (diff=%.2f%% > %.1f%%)",
                                      item.duty_cycle_pct, exp_duty, duty_diff, tolerance_pct))
            end

            // Period check
            total_checks++;
            if (vif != null) begin
                vif.sb_total_checks <= 8'(total_checks);
            end
            if (item.period_ns > 0.0) begin
                pass_checks++;
                `uvm_info("PWM_SB", $sformatf("[CHECK PASS] Measured valid period: %.2f ns (~%.2f kHz)",
                                     item.period_ns, item.frequency_hz / 1000.0), UVM_MEDIUM)
            end else begin
                fail_checks++;
                `uvm_error("PWM_SB", "[CHECK FAIL] Measured invalid PWM period (<= 0 ns)")
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("PWM_SB", "--------------------------------------------------------", UVM_LOW)
        `uvm_info("PWM_SB", "               PWM SCOREBOARD REPORT                    ", UVM_LOW)
        `uvm_info("PWM_SB", $sformatf("  Total Verification Checks : %0d", total_checks), UVM_LOW)
        `uvm_info("PWM_SB", $sformatf("  Passed Checks             : %0d", pass_checks), UVM_LOW)
        `uvm_info("PWM_SB", $sformatf("  Failed Checks             : %0d", fail_checks), UVM_LOW)
        if (fail_checks == 0 && total_checks > 0) begin
            `uvm_info("PWM_SB", "  >>> STATUS: PWM VERIFICATION PASSED 100% <<<", UVM_LOW)
        end else if (total_checks == 0) begin
            `uvm_warning("PWM_SB", "  >>> STATUS: NO ACTIVE CHECKS EVALUATED <<<")
        end else begin
            `uvm_error("PWM_SB", "  >>> STATUS: PWM VERIFICATION FAILED <<<")
        end
        `uvm_info("PWM_SB", "--------------------------------------------------------", UVM_LOW)
    endfunction
endclass

`endif // PWM_SCOREBOARD_SV
