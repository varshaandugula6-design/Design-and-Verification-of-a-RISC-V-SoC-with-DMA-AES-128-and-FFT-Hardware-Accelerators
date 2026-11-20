// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : UART UVM VIP (Corrected & Enhanced VIP)
// File         : uart_agent.sv
// Description  : UVM Agent instantiating driver, monitor, and sequencer for UART.
// ==============================================================================

`ifndef UART_AGENT_SV
`define UART_AGENT_SV

class uart_agent extends uvm_agent;
    uart_driver    drv;
    uart_monitor   mon;
    uart_sequencer seqr;
    uvm_analysis_port #(uart_item) ap;

    `uvm_component_utils(uart_agent)

    function new(string name = "uart_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = uart_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            drv  = uart_driver::type_id::create("drv", this);
            seqr = uart_sequencer::type_id::create("seqr", this);
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

`endif // UART_AGENT_SV
