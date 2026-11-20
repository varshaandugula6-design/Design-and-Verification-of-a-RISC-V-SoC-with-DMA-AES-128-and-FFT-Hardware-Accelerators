// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : soc_virtual_sequencer.sv
// Description  : Virtual Sequencer coordinating GPIO, UART, and PWM sequencers.
// ==============================================================================

`ifndef SOC_VIRTUAL_SEQUENCER_SV
`define SOC_VIRTUAL_SEQUENCER_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import gpio_pkg::*;
import uart_pkg::*;
import pwm_pkg::*;

class soc_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(soc_virtual_sequencer)

    // Sub-sequencer handles
    gpio_sequencer gpio_seqr;
    uart_sequencer uart_seqr;
    pwm_sequencer  pwm_seqr;

    function new(string name = "soc_virtual_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

`endif // SOC_VIRTUAL_SEQUENCER_SV
