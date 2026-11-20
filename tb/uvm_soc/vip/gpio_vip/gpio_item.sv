// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : GPIO UVM VIP (Corrected & Enhanced VIP)
// File         : gpio_item.sv
// Description  : Sequence item for GPIO transactions (drive & sample operations).
// ==============================================================================

`ifndef GPIO_ITEM_SV
`define GPIO_ITEM_SV

typedef enum bit [1:0] {
    GPIO_OP_DRIVE   = 2'b00,
    GPIO_OP_RELEASE = 2'b01,
    GPIO_OP_SAMPLE  = 2'b10
} gpio_op_e;

class gpio_item extends uvm_sequence_item;

    // Stimulus fields
    rand bit [31:0]   gpio_in;
    rand bit [31:0]   gpio_oe;
    rand gpio_op_e    op;
    rand int unsigned hold_cycles;
    int unsigned      trans_id; // Sequential transaction identifier (1..10)

    // Response / Monitored fields
    bit [31:0]        gpio_out;
    bit               gpio_irq;

    `uvm_object_utils_begin(gpio_item)
        `uvm_field_int(gpio_in,      UVM_ALL_ON)
        `uvm_field_int(gpio_oe,      UVM_ALL_ON)
        `uvm_field_enum(gpio_op_e, op, UVM_ALL_ON)
        `uvm_field_int(hold_cycles,  UVM_ALL_ON)
        `uvm_field_int(trans_id,     UVM_ALL_ON)
        `uvm_field_int(gpio_out,     UVM_ALL_ON)
        `uvm_field_int(gpio_irq,     UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_default_hold {
        hold_cycles inside {[2:10]};
    }

    function new(string name = "gpio_item");
        super.new(name);
        op = GPIO_OP_DRIVE;
        gpio_oe = 32'hFFFF_FFFF;
        gpio_in = 32'h0;
        hold_cycles = 10;
        trans_id = 0;
    endfunction

    virtual function string convert2string();
        return $sformatf("op=%s, in=0x%08h, oe=0x%08h, out=0x%08h, irq=%b, hold=%0d",
                        op.name(), gpio_in, gpio_oe, gpio_out, gpio_irq, hold_cycles);
    endfunction

endclass

`endif // GPIO_ITEM_SV
