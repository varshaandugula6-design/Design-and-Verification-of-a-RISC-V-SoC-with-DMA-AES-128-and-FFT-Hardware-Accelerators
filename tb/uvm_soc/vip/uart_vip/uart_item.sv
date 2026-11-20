// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : UART UVM VIP (Corrected & Enhanced VIP)
// File         : uart_item.sv
// Description  : Sequence item for UART byte transactions (8-N-1 format).
// ==============================================================================

`ifndef UART_ITEM_SV
`define UART_ITEM_SV

typedef enum bit {
    UART_DIR_RX_INJECT = 1'b0, // VIP driver injects into DUT uart_rx
    UART_DIR_TX_MON    = 1'b1  // VIP monitor observes from DUT uart_tx
} uart_dir_e;

class uart_item extends uvm_sequence_item;

    // Byte data payload
    rand bit [7:0]  data;

    // Direction and timing configuration
    rand uart_dir_e dir;
    int unsigned    bit_cycles; // Cycles of 40MHz clock per bit (default 347 for 115200 Baud)

    // Status and protocol checks
    bit             framing_error;
    bit             parity_error;

    `uvm_object_utils_begin(uart_item)
        `uvm_field_int(data,          UVM_ALL_ON)
        `uvm_field_enum(uart_dir_e, dir, UVM_ALL_ON)
        `uvm_field_int(bit_cycles,    UVM_ALL_ON)
        `uvm_field_int(framing_error, UVM_ALL_ON)
        `uvm_field_int(parity_error,  UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "uart_item");
        super.new(name);
        data = 8'h00;
        dir = UART_DIR_RX_INJECT;
        bit_cycles = 347; // 115200 Baud with 40 MHz baud clock
        framing_error = 0;
        parity_error = 0;
    endfunction

    virtual function string convert2string();
        return $sformatf("dir=%s, data=0x%02h ('%c'), bit_cycles=%0d, framing_err=%b",
                        dir.name(), data, ((data >= 32 && data <= 126) ? data : "."), bit_cycles, framing_error);
    endfunction

endclass

`endif // UART_ITEM_SV
