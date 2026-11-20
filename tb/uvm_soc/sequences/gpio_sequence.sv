// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : sequences/gpio_sequence.sv
// Description  : UVM Sequences generating GPIO pin stimulus.
// ==============================================================================

`ifndef GPIO_SEQUENCE_SV
`define GPIO_SEQUENCE_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import gpio_pkg::*;

// ------------------------------------------------------------------------------
// Base GPIO Sequence
// ------------------------------------------------------------------------------
class gpio_base_sequence extends uvm_sequence #(gpio_item);
    `uvm_object_utils(gpio_base_sequence)

    function new(string name = "gpio_base_sequence");
        super.new(name);
    endfunction
endclass

// ------------------------------------------------------------------------------
// Sequence: Drive All Pins LOW (0x0000_0000)
// ------------------------------------------------------------------------------
class gpio_all_low_seq extends gpio_base_sequence;
    `uvm_object_utils(gpio_all_low_seq)

    function new(string name = "gpio_all_low_seq");
        super.new(name);
    endfunction

    virtual task body();
        req = gpio_item::type_id::create("req");
        start_item(req);
        req.op          = GPIO_OP_DRIVE;
        req.gpio_in     = 32'h0000_0000;
        req.gpio_oe     = 32'hFFFF_FFFF;
        req.hold_cycles = 10;
        finish_item(req);
    endtask
endclass

// ------------------------------------------------------------------------------
// Sequence: Drive All Pins HIGH (0xFFFF_FFFF)
// ------------------------------------------------------------------------------
class gpio_all_high_seq extends gpio_base_sequence;
    `uvm_object_utils(gpio_all_high_seq)

    function new(string name = "gpio_all_high_seq");
        super.new(name);
    endfunction

    virtual task body();
        req = gpio_item::type_id::create("req");
        start_item(req);
        req.op          = GPIO_OP_DRIVE;
        req.gpio_in     = 32'hFFFF_FFFF;
        req.gpio_oe     = 32'hFFFF_FFFF;
        req.hold_cycles = 10;
        finish_item(req);
    endtask
endclass

// ------------------------------------------------------------------------------
// Sequence: Alternating Bit Patterns (0xAAAA_AAAA and 0x5555_5555)
// ------------------------------------------------------------------------------
class gpio_alternating_seq extends gpio_base_sequence;
    `uvm_object_utils(gpio_alternating_seq)

    function new(string name = "gpio_alternating_seq");
        super.new(name);
    endfunction

    virtual task body();
        // Pattern 1: 0xAAAA_AAAA
        req = gpio_item::type_id::create("req_alt1");
        start_item(req);
        req.op          = GPIO_OP_DRIVE;
        req.gpio_in     = 32'hAAAA_AAAA;
        req.gpio_oe     = 32'hFFFF_FFFF;
        req.hold_cycles = 8;
        finish_item(req);

        // Pattern 2: 0x5555_5555
        req = gpio_item::type_id::create("req_alt2");
        start_item(req);
        req.op          = GPIO_OP_DRIVE;
        req.gpio_in     = 32'h5555_5555;
        req.gpio_oe     = 32'hFFFF_FFFF;
        req.hold_cycles = 8;
        finish_item(req);
    endtask
endclass

// ------------------------------------------------------------------------------
// Sequence: Walking-One Pattern (1 << i across all 32 pins)
// ------------------------------------------------------------------------------
class gpio_walking_ones_seq extends gpio_base_sequence;
    `uvm_object_utils(gpio_walking_ones_seq)

    function new(string name = "gpio_walking_ones_seq");
        super.new(name);
    endfunction

    virtual task body();
        for (int i = 0; i < 32; i++) begin
            req = gpio_item::type_id::create($sformatf("req_w1_%0d", i));
            start_item(req);
            req.op          = GPIO_OP_DRIVE;
            req.gpio_in     = (32'h1 << i);
            req.gpio_oe     = 32'hFFFF_FFFF;
            req.hold_cycles = 4;
            finish_item(req);
        end
    endtask
endclass

// ------------------------------------------------------------------------------
// Sequence: Walking-Zero Pattern (~(1 << i) across all 32 pins)
// ------------------------------------------------------------------------------
class gpio_walking_zeros_seq extends gpio_base_sequence;
    `uvm_object_utils(gpio_walking_zeros_seq)

    function new(string name = "gpio_walking_zeros_seq");
        super.new(name);
    endfunction

    virtual task body();
        for (int i = 0; i < 32; i++) begin
            req = gpio_item::type_id::create($sformatf("req_w0_%0d", i));
            start_item(req);
            req.op          = GPIO_OP_DRIVE;
            req.gpio_in     = ~(32'h1 << i);
            req.gpio_oe     = 32'hFFFF_FFFF;
            req.hold_cycles = 4;
            finish_item(req);
        end
    endtask
endclass

// ------------------------------------------------------------------------------
// Sequence: Release Pins (Hi-Z for DUT Output Drive)
// ------------------------------------------------------------------------------
class gpio_release_seq extends gpio_base_sequence;
    `uvm_object_utils(gpio_release_seq)

    function new(string name = "gpio_release_seq");
        super.new(name);
    endfunction

    virtual task body();
        req = gpio_item::type_id::create("req_rel");
        start_item(req);
        req.op          = GPIO_OP_RELEASE;
        req.gpio_in     = 32'h0;
        req.gpio_oe     = 32'h0;
        req.hold_cycles = 5;
        finish_item(req);
    endtask
endclass

// ------------------------------------------------------------------------------
// Sequence: Sequential Data Values 121 to 130 (10 Transactions)
// ------------------------------------------------------------------------------
class gpio_seq_121_to_130 extends gpio_base_sequence;
    `uvm_object_utils(gpio_seq_121_to_130)

    function new(string name = "gpio_seq_121_to_130");
        super.new(name);
    endfunction

    virtual task body();
        for (int val = 121; val <= 130; val++) begin
            req = gpio_item::type_id::create($sformatf("gpio_req_%0d", val));
            start_item(req);
            req.op          = GPIO_OP_DRIVE;
            req.gpio_in     = 32'(val);
            req.gpio_oe     = 32'hFFFF_FFFF;
            req.hold_cycles = 10;
            req.trans_id    = (val - 120);
            finish_item(req);
        end
    endtask
endclass

// ------------------------------------------------------------------------------
// Sequence: Specific Data Vector Drive (Executes 121 to 130 Sequence)
// ------------------------------------------------------------------------------
class gpio_drive_custom_seq extends gpio_base_sequence;
    `uvm_object_utils(gpio_drive_custom_seq)

    function new(string name = "gpio_drive_custom_seq");
        super.new(name);
    endfunction

    virtual task body();
        for (int val = 121; val <= 130; val++) begin
            req = gpio_item::type_id::create($sformatf("gpio_req_%0d", val));
            start_item(req);
            req.op          = GPIO_OP_DRIVE;
            req.gpio_in     = 32'(val);
            req.gpio_oe     = 32'hFFFF_FFFF;
            req.hold_cycles = 10;
            req.trans_id    = (val - 120);
            finish_item(req);
        end
    endtask
endclass

typedef gpio_seq_121_to_130 gpio_sequence;

`endif // GPIO_SEQUENCE_SV
