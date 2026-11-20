// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : PWM UVM VIP (Corrected & Enhanced VIP)
// File         : pwm_sequencer.sv
// Description  : UVM Sequencer for PWM sequence items.
// ==============================================================================

`ifndef PWM_SEQUENCER_SV
`define PWM_SEQUENCER_SV

class pwm_sequencer extends uvm_sequencer #(pwm_item);
    `uvm_component_utils(pwm_sequencer)

    function new(string name = "pwm_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

`endif // PWM_SEQUENCER_SV
