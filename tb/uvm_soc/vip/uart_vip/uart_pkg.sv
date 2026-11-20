// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : UART UVM VIP (Corrected & Enhanced VIP)
// File         : uart_pkg.sv
// Description  : UVM package containing all UART VIP classes.
// ==============================================================================

`ifndef UART_PKG_SV
`define UART_PKG_SV

package uart_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "uart_item.sv"
    `include "uart_sequencer.sv"
    `include "uart_driver.sv"
    `include "uart_monitor.sv"
    `include "uart_agent.sv"
endpackage

`endif // UART_PKG_SV
