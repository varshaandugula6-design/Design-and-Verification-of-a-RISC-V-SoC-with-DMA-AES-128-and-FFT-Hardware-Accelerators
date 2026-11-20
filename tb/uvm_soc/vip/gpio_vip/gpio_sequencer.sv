// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : GPIO UVM VIP (Corrected & Enhanced VIP)
// File         : gpio_sequencer.sv
// Description  : UVM Sequencer for GPIO sequence items.
// ==============================================================================

`ifndef GPIO_SEQUENCER_SV
`define GPIO_SEQUENCER_SV

class gpio_sequencer extends uvm_sequencer #(gpio_item);
    `uvm_component_utils(gpio_sequencer)

    function new(string name = "gpio_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

`endif // GPIO_SEQUENCER_SV
