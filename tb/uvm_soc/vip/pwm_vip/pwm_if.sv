// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : PWM UVM VIP (Corrected & Enhanced VIP)
// File         : pwm_if.sv
// Description  : Interface for Real-Time Timer PWM waveform & interrupt lines.
//                Waveform observability signals for Verdi visibility.
// ==============================================================================

`ifndef PWM_IF_SV
`define PWM_IF_SV

interface pwm_if (
    input logic clk,   // 100 MHz system clock
    input logic rst_n  // Active-low synchronous reset
);
    // Preserves signals from original pwm_if.sv definition
    logic pwm_out_o;   // Monitored PWM waveform driven by DUT timer_pwm
    logic timer_irq;   // Monitored interrupt output driven by DUT timer_irq

    // -----------------------------------------------------------------------
    // PWM MONITOR Waveform Observability Signals (Verdi/FSDB visibility)
    // -----------------------------------------------------------------------
    logic       mon_measuring;         // HIGH while monitor is between rising edges (measuring one cycle)
    logic [7:0] mon_cycle_count;       // Rolling count of complete PWM cycles measured
    // Note: period_ns, high_time_ns, duty_cycle_pct are real-type in pwm_item;
    //       integer-scaled versions are exposed here for waveform visibility.
    logic [31:0] mon_period_ns_int;    // Period in ns, integer (truncated)
    logic [31:0] mon_high_time_ns_int; // High time in ns, integer (truncated)
    logic [6:0]  mon_duty_pct_int;     // Duty cycle %, integer (0-100)

    // -----------------------------------------------------------------------
    // PWM SCOREBOARD Waveform Observability Signals (Verdi/FSDB visibility)
    // -----------------------------------------------------------------------
    logic [6:0]  sb_expected_duty_int; // Expected duty cycle %, integer
    logic [6:0]  sb_actual_duty_int;   // Measured duty cycle %, integer
    logic        sb_match;             // 1 = Match within tolerance, 0 = Out of tolerance
    logic [7:0]  sb_total_checks;      // Running count of scoreboard checks

endinterface

`endif // PWM_IF_SV
