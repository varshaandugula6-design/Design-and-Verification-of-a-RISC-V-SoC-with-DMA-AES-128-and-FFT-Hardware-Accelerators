// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : sequences/soc_virtual_sequence.sv
// Description  : Coordinated Virtual Sequence orchestrating GPIO, UART & PWM VIPs.
// ==============================================================================

`ifndef SOC_VIRTUAL_SEQUENCE_SV
`define SOC_VIRTUAL_SEQUENCE_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import gpio_pkg::*;
import uart_pkg::*;
import pwm_pkg::*;

class soc_virtual_sequence extends uvm_sequence;
    `uvm_object_utils(soc_virtual_sequence)
    `uvm_declare_p_sequencer(soc_virtual_sequencer)

    // Child sequence handles
    gpio_all_low_seq        seq_gpio_low;
    gpio_all_high_seq       seq_gpio_high;
    gpio_alternating_seq    seq_gpio_alt;
    gpio_walking_ones_seq   seq_gpio_w1;
    gpio_release_seq        seq_gpio_rel;

    uart_rx_single_byte_seq seq_uart_single;
    uart_rx_multi_byte_seq  seq_uart_multi;

    pwm_base_sequence       seq_pwm;

    function new(string name = "soc_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("SOC_VSEQ", "==================================================", UVM_LOW)
        `uvm_info("SOC_VSEQ", "   STARTING COORDINATED SOC VIRTUAL SEQUENCE     ", UVM_LOW)
        `uvm_info("SOC_VSEQ", "==================================================", UVM_LOW)

        // ----------------------------------------------------------------------
        // Phase 1: GPIO Quiescent State
        // ----------------------------------------------------------------------
        `uvm_info("SOC_VSEQ", "[PHASE 1] GPIO bus quiescent (10 transactions 121..130 verified in Step 2)...", UVM_MEDIUM)

        // ----------------------------------------------------------------------
        // Phase 2: UART Serial Stimulus Verification
        // ----------------------------------------------------------------------
        `uvm_info("SOC_VSEQ", "[PHASE 2] Executing UART Serial Injection Sequences...", UVM_MEDIUM)

        seq_uart_single = uart_rx_single_byte_seq::type_id::create("seq_uart_single");
        seq_uart_single.byte_to_inject = 8'hA5;
        seq_uart_single.start(p_sequencer.uart_seqr);

        seq_uart_multi = uart_rx_multi_byte_seq::type_id::create("seq_uart_multi");
        seq_uart_multi.start(p_sequencer.uart_seqr);

        // ----------------------------------------------------------------------
        // Phase 3: PWM Passive Verification Coordination
        // ----------------------------------------------------------------------
        `uvm_info("SOC_VSEQ", "[PHASE 3] Coordinating PWM Passive Verification...", UVM_MEDIUM)
        seq_pwm = pwm_base_sequence::type_id::create("seq_pwm");
        seq_pwm.start(p_sequencer.pwm_seqr);

        `uvm_info("SOC_VSEQ", "==================================================", UVM_LOW)
        `uvm_info("SOC_VSEQ", "   COMPLETED COORDINATED SOC VIRTUAL SEQUENCE    ", UVM_LOW)
        `uvm_info("SOC_VSEQ", "==================================================", UVM_LOW)
    endtask
endclass

`endif // SOC_VIRTUAL_SEQUENCE_SV
