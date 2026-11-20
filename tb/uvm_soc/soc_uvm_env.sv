// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : soc_uvm_env.sv
// Description  : Top-level UVM Environment integrating GPIO, UART & PWM VIP agents,
//                scoreboards, and the coordinated virtual sequencer.
// ==============================================================================

`ifndef SOC_UVM_ENV_SV
`define SOC_UVM_ENV_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

// Import VIP packages
import gpio_pkg::*;
import uart_pkg::*;
import pwm_pkg::*;

// Include scoreboards and virtual sequencer
`include "scoreboards/gpio_scoreboard.sv"
`include "scoreboards/uart_scoreboard.sv"
`include "scoreboards/pwm_scoreboard.sv"
`include "soc_virtual_sequencer.sv"

class soc_uvm_env extends uvm_env;
    `uvm_component_utils(soc_uvm_env)

    // VIP Agents
    gpio_agent             gpio_agt;
    uart_agent             uart_agt;
    pwm_agent              pwm_agt;

    // Scoreboards
    gpio_scoreboard        gpio_sb;
    uart_scoreboard        uart_sb;
    pwm_scoreboard         pwm_sb;

    // Virtual Sequencer
    soc_virtual_sequencer  v_seqr;

    function new(string name = "soc_uvm_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("SOC_ENV", "Building SoC UVM Environment...", UVM_MEDIUM)

        // Instantiate VIP Agents
        gpio_agt = gpio_agent::type_id::create("gpio_agt", this);
        uart_agt = uart_agent::type_id::create("uart_agt", this);
        pwm_agt  = pwm_agent::type_id::create("pwm_agt", this);

        // Instantiate Scoreboards
        gpio_sb  = gpio_scoreboard::type_id::create("gpio_sb", this);
        uart_sb  = uart_scoreboard::type_id::create("uart_sb", this);
        pwm_sb   = pwm_scoreboard::type_id::create("pwm_sb", this);

        // Instantiate Virtual Sequencer
        v_seqr   = soc_virtual_sequencer::type_id::create("v_seqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("SOC_ENV", "Connecting analysis ports to scoreboards and sequencers...", UVM_MEDIUM)

        // Connect Agent analysis ports to Scoreboards
        gpio_agt.ap.connect(gpio_sb.item_export);
        uart_agt.ap.connect(uart_sb.item_export);
        pwm_agt.ap.connect(pwm_sb.item_export);

        // Connect Virtual Sequencer handles
        v_seqr.gpio_seqr = gpio_agt.seqr;
        v_seqr.uart_seqr = uart_agt.seqr;
        v_seqr.pwm_seqr  = pwm_agt.seqr;
    endfunction

endclass

`endif // SOC_UVM_ENV_SV
