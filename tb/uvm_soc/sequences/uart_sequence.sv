// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : sequences/uart_sequence.sv
// Description  : UVM Sequences generating UART serial stimulus into DUT uart_rx.
// ==============================================================================

`ifndef UART_SEQUENCE_SV
`define UART_SEQUENCE_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import uart_pkg::*;

// ------------------------------------------------------------------------------
// Base UART Sequence
// ------------------------------------------------------------------------------
class uart_base_sequence extends uvm_sequence #(uart_item);
    `uvm_object_utils(uart_base_sequence)

    function new(string name = "uart_base_sequence");
        super.new(name);
    endfunction
endclass

// ------------------------------------------------------------------------------
// Sequence: Single-Byte RX Injection (Default 0x7E / Sync byte)
// ------------------------------------------------------------------------------
class uart_rx_single_byte_seq extends uart_base_sequence;
    `uvm_object_utils(uart_rx_single_byte_seq)

    rand bit [7:0] byte_to_inject;

    function new(string name = "uart_rx_single_byte_seq");
        super.new(name);
        byte_to_inject = 8'h7E;
    endfunction

    virtual task body();
        req = uart_item::type_id::create("uart_req_single");
        start_item(req);
        req.data       = byte_to_inject;
        req.dir        = UART_DIR_RX_INJECT;
        req.bit_cycles = 347; // 115200 Baud @ 40 MHz clock
        finish_item(req);
    endtask
endclass

// ------------------------------------------------------------------------------
// Sequence: Multi-Byte Stream Injection (0x5A, 0x3C, 0xC3, 0xA5)
// ------------------------------------------------------------------------------
class uart_rx_multi_byte_seq extends uart_base_sequence;
    `uvm_object_utils(uart_rx_multi_byte_seq)

    byte unsigned test_bytes[] = '{8'h5A, 8'h3C, 8'hC3, 8'hA5};

    function new(string name = "uart_rx_multi_byte_seq");
        super.new(name);
    endfunction

    virtual task body();
        foreach (test_bytes[i]) begin
            req = uart_item::type_id::create($sformatf("uart_req_multi_%0d", i));
            start_item(req);
            req.data       = test_bytes[i];
            req.dir        = UART_DIR_RX_INJECT;
            req.bit_cycles = 347;
            finish_item(req);
        end
    endtask
endclass

// ------------------------------------------------------------------------------
// Sequence: Walking-Ones Byte Injection (1 << i for i=0..7)
// ------------------------------------------------------------------------------
class uart_rx_walking_ones_seq extends uart_base_sequence;
    `uvm_object_utils(uart_rx_walking_ones_seq)

    function new(string name = "uart_rx_walking_ones_seq");
        super.new(name);
    endfunction

    virtual task body();
        for (int i = 0; i < 8; i++) begin
            req = uart_item::type_id::create($sformatf("uart_req_w1_%0d", i));
            start_item(req);
            req.data       = (8'h1 << i);
            req.dir        = UART_DIR_RX_INJECT;
            req.bit_cycles = 347;
            finish_item(req);
        end
    endtask
endclass

`endif // UART_SEQUENCE_SV
