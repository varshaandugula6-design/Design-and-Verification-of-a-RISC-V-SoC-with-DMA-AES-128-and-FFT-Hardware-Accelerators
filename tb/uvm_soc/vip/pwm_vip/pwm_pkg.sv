// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : PWM UVM VIP (Corrected & Enhanced VIP)
// File         : pwm_pkg.sv
// Description  : UVM package containing all PWM VIP classes.
// ==============================================================================

`ifndef PWM_PKG_SV
`define PWM_PKG_SV

package pwm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "pwm_item.sv"
    `include "pwm_sequencer.sv"
    `include "pwm_driver.sv"
    `include "pwm_monitor.sv"
    `include "pwm_agent.sv"
endpackage

`endif // PWM_PKG_SV
