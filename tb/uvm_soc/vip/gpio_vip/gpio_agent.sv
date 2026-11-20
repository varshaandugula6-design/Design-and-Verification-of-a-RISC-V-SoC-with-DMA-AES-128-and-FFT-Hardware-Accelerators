// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : GPIO UVM VIP (Corrected & Enhanced VIP)
// File         : gpio_agent.sv
// Description  : UVM Agent instantiating driver, monitor, and sequencer for GPIO.
// ==============================================================================

`ifndef GPIO_AGENT_SV
`define GPIO_AGENT_SV

class gpio_agent extends uvm_agent;
    gpio_driver    drv;
    gpio_monitor   mon;
    gpio_sequencer seqr;
    uvm_analysis_port #(gpio_item) ap;

    `uvm_component_utils(gpio_agent)

    function new(string name = "gpio_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = gpio_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            drv  = gpio_driver::type_id::create("drv", this);
            seqr = gpio_sequencer::type_id::create("seqr", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(seqr.seq_item_export);
        end
        ap = mon.ap;
    endfunction
endclass

`endif // GPIO_AGENT_SV
