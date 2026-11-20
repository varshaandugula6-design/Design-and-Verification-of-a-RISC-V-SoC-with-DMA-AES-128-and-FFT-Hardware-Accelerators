// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : sequences/pwm_sequence.sv
// Description  : UVM Sequence for PWM VIP (Passive monitor coordination).
// ==============================================================================

`ifndef PWM_SEQUENCE_SV
`define PWM_SEQUENCE_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import pwm_pkg::*;

class pwm_base_sequence extends uvm_sequence #(pwm_item);
    `uvm_object_utils(pwm_base_sequence)

    function new(string name = "pwm_base_sequence");
        super.new(name);
    endfunction

    virtual task body();
        // PWM is an output from the SoC Real-Time Timer.
        // Sequence remains passive while monitor captures output waveform.
        `uvm_info("PWM_SEQ", "PWM VIP is passive monitor-only; awaiting timer PWM output pulses.", UVM_MEDIUM)
    endtask
endclass

`endif // PWM_SEQUENCE_SV
