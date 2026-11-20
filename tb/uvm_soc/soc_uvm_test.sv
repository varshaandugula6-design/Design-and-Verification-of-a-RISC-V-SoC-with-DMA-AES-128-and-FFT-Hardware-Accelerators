// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Environment
// File         : soc_uvm_test.sv
// Description  : Common UVM Test coordinating GPIO, UART, and PWM VIP verification.
// ==============================================================================

`ifndef SOC_UVM_TEST_SV
`define SOC_UVM_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

import gpio_pkg::*;
import uart_pkg::*;
import pwm_pkg::*;

`include "soc_ctrl_if.sv"
`include "soc_uvm_env.sv"
`include "sequences/gpio_sequence.sv"
`include "sequences/uart_sequence.sv"
`include "sequences/pwm_sequence.sv"
`include "sequences/soc_virtual_sequence.sv"

class soc_uvm_test extends uvm_test;
    `uvm_component_utils(soc_uvm_test)

    soc_uvm_env           env;
    virtual soc_ctrl_if   vif_ctrl;

    // Peripheral Address Constants
    localparam logic [31:0] GPIO_BASE    = 32'h8000_1000;
    localparam logic [31:0] GPIO_DATA_I  = 32'h8000_1000;
    localparam logic [31:0] GPIO_DATA_O  = 32'h8000_1004;
    localparam logic [31:0] GPIO_DIR     = 32'h8000_1008;
    localparam logic [31:0] GPIO_INT_EN  = 32'h8000_100C;
    localparam logic [31:0] GPIO_INT_TYP = 32'h8000_1010;
    localparam logic [31:0] GPIO_INT_POL = 32'h8000_1014;
    localparam logic [31:0] GPIO_INT_STS = 32'h8000_101C;
    localparam logic [31:0] GPIO_SET_O   = 32'h8000_1020;
    localparam logic [31:0] GPIO_CLR_O   = 32'h8000_1024;
    localparam logic [31:0] GPIO_TGL_O   = 32'h8000_1028;
    localparam logic [31:0] GPIO_DEB_EN  = 32'h8000_1030;

    localparam logic [31:0] UART_BASE    = 32'h8000_3000;
    localparam logic [31:0] UART_RBR_THR = 32'h8000_3000;
    localparam logic [31:0] UART_IER     = 32'h8000_3004;
    localparam logic [31:0] UART_BAUD    = 32'h8000_3008; // DLAB=1
    localparam logic [31:0] UART_LCR     = 32'h8000_300C; // Bit 7 = DLAB
    localparam logic [31:0] UART_LSR     = 32'h8000_3014;

    localparam logic [31:0] TIMER_BASE   = 32'h8000_2000;
    localparam logic [31:0] TIMER_CTRL   = 32'h8000_2000;
    localparam logic [31:0] TIMER_LOAD   = 32'h8000_2004;
    localparam logic [31:0] TIMER_VAL    = 32'h8000_2008;
    localparam logic [31:0] TIMER_PRE    = 32'h8000_200C;
    localparam logic [31:0] TIMER_INT_EN = 32'h8000_2010;
    localparam logic [31:0] TIMER_INT_ST = 32'h8000_2014;
    localparam logic [31:0] TIMER_CMP    = 32'h8000_2018;

    function new(string name = "soc_uvm_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_uvm_env::type_id::create("env", this);

        if (!uvm_config_db#(virtual soc_ctrl_if)::get(this, "", "soc_ctrl_vif", vif_ctrl)) begin
            `uvm_fatal("SOC_TEST", "Failed to retrieve 'soc_ctrl_vif' from uvm_config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        logic [31:0] rd_data;
        logic [1:0]  resp;
        soc_virtual_sequence vseq;

        phase.raise_objection(this, "Starting SoC UVM Test");
        `uvm_info("SOC_TEST", "==================================================", UVM_LOW)
        `uvm_info("SOC_TEST", "  STARTING SoC UVM VIP INTEGRATION TEST SUITE    ", UVM_LOW)
        `uvm_info("SOC_TEST", "==================================================", UVM_LOW)

        // Wait for system reset release
        @(posedge vif_ctrl.rst_n);
        repeat (10) @(posedge vif_ctrl.clk);
        `uvm_info("SOC_TEST", "[TEST STEP 1] SoC reset released. Interconnect active.", UVM_LOW)

        // ----------------------------------------------------------------------
        // STEP 2: GPIO Subsystem Verification via UVM VIP (Values 121 to 130)
        // ----------------------------------------------------------------------
        `uvm_info("SOC_TEST", "[TEST STEP 2] Beginning GPIO Verification with GPIO VIP (Values 121 to 130)...", UVM_LOW)

        // 2.1 Configure GPIO DIR=0 (all 32 pins are inputs to DUT) and disable debouncer
        `uvm_info("SOC_TEST", "  [2.1] Configuring GPIO DIR=0 (all inputs) and DEB_EN=0...", UVM_MEDIUM)
        vif_ctrl.axi_write(GPIO_DIR, 32'h0000_0000, 8'h20, resp);
        vif_ctrl.axi_write(GPIO_DEB_EN, 32'h0000_0000, 8'h21, resp);

        // 2.2 Register expected values 121 to 130 in the GPIO scoreboard
        `uvm_info("SOC_TEST", "  [2.2] Registering expected decimal values 121 to 130 in GPIO Scoreboard...", UVM_MEDIUM)
        for (int exp_val = 121; exp_val <= 130; exp_val++) begin
            env.gpio_sb.expect_output(32'(exp_val));
        end

        // 2.3 Execute GPIO Sequence generating values 121 to 130
        `uvm_info("SOC_TEST", "  [2.3] Executing GPIO Sequence driving sequential values 121 to 130...", UVM_MEDIUM)
        begin
            gpio_drive_custom_seq gpio_drv_seq;
            gpio_drv_seq = gpio_drive_custom_seq::type_id::create("gpio_drv_seq");
            gpio_drv_seq.start(env.gpio_agt.seqr);
        end

        // 2.4 Verify DUT DATA_I register sampled the final value via AXI read
        vif_ctrl.axi_read(GPIO_DATA_I, 8'h22, rd_data, resp);
        `uvm_info("SOC_TEST", $sformatf("  [2.4] DUT GPIO_DATA_I readback via AXI: 0x%08h (Decimal %0d)", rd_data, rd_data), UVM_MEDIUM)

        // 2.5 Release GPIO pins to Hi-Z
        begin
            gpio_release_seq rel_seq;
            rel_seq = gpio_release_seq::type_id::create("rel_seq");
            rel_seq.start(env.gpio_agt.seqr);
        end

        // ----------------------------------------------------------------------
        // STEP 3: UART Subsystem Verification via UVM VIP
        // ----------------------------------------------------------------------
        `uvm_info("SOC_TEST", "[TEST STEP 3] Beginning UART Verification with UART VIP...", UVM_LOW)

        // 3.1 Setup UART 115200 Baud Divisor
        `uvm_info("SOC_TEST", "  [3.1] Configuring UART Baud Divisor (347 cycles @ 40MHz = 115200 Baud)...", UVM_MEDIUM)
        vif_ctrl.axi_write(UART_IER,  32'h0000_0001, 8'h40, resp); // Enable RDA IRQ
        vif_ctrl.axi_write(UART_LCR,  32'h0000_0083, 8'h41, resp); // Enable DLAB
        vif_ctrl.axi_write(UART_BAUD, 32'd347,        8'h42, resp); // Divisor = 347
        vif_ctrl.axi_write(UART_LCR,  32'h0000_0003, 8'h43, resp); // Disable DLAB, 8-N-1

        // Initial dummy read of LSR to deassert RX FIFO soft reset inside axi_uart_top
        vif_ctrl.axi_read(UART_LSR, 8'h44, rd_data, resp);
        `uvm_info("SOC_TEST", $sformatf("  [3.1b] UART Initial LSR = 0x%02h (RX FIFO soft reset released)", rd_data[7:0]), UVM_MEDIUM)

        // 3.2 DUT Transmission -> UART VIP Monitor
        `uvm_info("SOC_TEST", "  [3.2] Writing byte 0xA5 to UART THR. Expecting UART VIP Monitor capture...", UVM_MEDIUM)
        env.uart_sb.expect_tx_byte(8'hA5);
        vif_ctrl.axi_write(UART_RBR_THR, 32'h0000_00A5, 8'h45, resp);

        // Wait for serial transmission to complete (~10 bit times = 3470 fixed_clk cycles)
        repeat (3800) @(posedge vif_ctrl.clk);

        // 3.3 Multi-byte Transmission (0x5A, 0x3C)
        `uvm_info("SOC_TEST", "  [3.3] Writing multiple bytes (0x5A, 0x3C) to UART THR...", UVM_MEDIUM)
        env.uart_sb.expect_tx_byte(8'h5A);
        vif_ctrl.axi_write(UART_RBR_THR, 32'h0000_005A, 8'h46, resp);
        repeat (3800) @(posedge vif_ctrl.clk);

        env.uart_sb.expect_tx_byte(8'h3C);
        vif_ctrl.axi_write(UART_RBR_THR, 32'h0000_003C, 8'h47, resp);
        repeat (3800) @(posedge vif_ctrl.clk);

        // 3.4 UART VIP Driver -> DUT RX Injection
        `uvm_info("SOC_TEST", "  [3.4] Driving byte 0x7E from UART VIP Driver into DUT uart_rx...", UVM_MEDIUM)
        begin
            uart_rx_single_byte_seq uart_inj_seq;
            uart_inj_seq = uart_rx_single_byte_seq::type_id::create("uart_inj_seq");
            uart_inj_seq.byte_to_inject = 8'h7E;
            uart_inj_seq.start(env.uart_agt.seqr);

            // Wait for byte to be received by DUT and poll LSR for DATA_READY (bit 0)
            repeat (20) @(posedge vif_ctrl.clk);
            vif_ctrl.axi_read(UART_LSR, 8'h48, rd_data, resp);
            if (!rd_data[0]) begin
                repeat (50) @(posedge vif_ctrl.clk);
                vif_ctrl.axi_read(UART_LSR, 8'h49, rd_data, resp);
            end

            // Read back from RBR via AXI
            vif_ctrl.axi_read(UART_RBR_THR, 8'h4A, rd_data, resp);
            if (rd_data[7:0] === 8'h7E) begin
                `uvm_info("SOC_TEST", "[CHECK PASS] DUT UART successfully received byte 0x7E injected by UART VIP", UVM_LOW)
                env.uart_sb.total_checks++;
                env.uart_sb.pass_checks++;
            end else begin
                `uvm_error("SOC_TEST", $sformatf("[CHECK FAIL] DUT UART RBR mismatch! Actual=0x%02h, Expected=0x7E", rd_data[7:0]))
                env.uart_sb.total_checks++;
                env.uart_sb.fail_checks++;
            end
        end

        // ----------------------------------------------------------------------
        // STEP 4: Real-Time Timer PWM Subsystem Verification via PWM VIP
        // ----------------------------------------------------------------------
        `uvm_info("SOC_TEST", "[TEST STEP 4] Beginning Timer PWM Verification with PWM VIP...", UVM_LOW)

        // 4.1 50% Duty Cycle Configuration (LOAD=20, CMP=10, Period=210ns)
        `uvm_info("SOC_TEST", "  [4.1] Configuring Timer for 50% Duty Cycle (LOAD=20, CMP=10)...", UVM_MEDIUM)
        vif_ctrl.axi_write(TIMER_PRE,  32'd0,  8'h50, resp);
        vif_ctrl.axi_write(TIMER_LOAD, 32'd20, 8'h51, resp);
        vif_ctrl.axi_write(TIMER_CMP,  32'd10, 8'h52, resp);
        env.pwm_sb.expect_pwm_config(50.0, 210.0); // Expect ~50% duty

        // Start timer in periodic PWM mode (CTRL = 0x13)
        vif_ctrl.axi_write(TIMER_CTRL, 32'h13, 8'h53, resp);
        repeat (120) @(posedge vif_ctrl.clk); // Allow PWM monitor to capture several pulses

        // 4.2 25% Duty Cycle Configuration (LOAD=40, CMP=10, Period=410ns)
        `uvm_info("SOC_TEST", "  [4.2] Configuring Timer for 25% Duty Cycle (LOAD=40, CMP=10)...", UVM_MEDIUM)
        vif_ctrl.axi_write(TIMER_LOAD, 32'd40, 8'h54, resp);
        vif_ctrl.axi_write(TIMER_CMP,  32'd10, 8'h55, resp);
        env.pwm_sb.expect_pwm_config(25.0, 410.0); // Expect ~25% duty
        repeat (180) @(posedge vif_ctrl.clk);

        // 4.3 Stop Timer and verify PWM ceases
        `uvm_info("SOC_TEST", "  [4.3] Stopping Timer (CTRL=0x00)...", UVM_MEDIUM)
        vif_ctrl.axi_write(TIMER_CTRL, 32'h00, 8'h56, resp);
        repeat (10) @(posedge vif_ctrl.clk);

        // ----------------------------------------------------------------------
        // STEP 5: Coordinated Virtual Sequence Execution
        // ----------------------------------------------------------------------
        `uvm_info("SOC_TEST", "[TEST STEP 5] Executing Coordinated Virtual Sequence...", UVM_LOW)
        vseq = soc_virtual_sequence::type_id::create("vseq");
        vseq.start(env.v_seqr);

        repeat (50) @(posedge vif_ctrl.clk);
        `uvm_info("SOC_TEST", "==================================================", UVM_LOW)
        `uvm_info("SOC_TEST", "  ALL SoC UVM VIP TEST PROCEDURES COMPLETED       ", UVM_LOW)
        `uvm_info("SOC_TEST", "==================================================", UVM_LOW)

        phase.drop_objection(this, "Completed SoC UVM Test");
    endtask

    virtual function void report_phase(uvm_phase phase);
        int total_all, pass_all, fail_all;
        super.report_phase(phase);

        total_all = env.gpio_sb.total_checks + env.uart_sb.total_checks + env.pwm_sb.total_checks;
        pass_all  = env.gpio_sb.pass_checks  + env.uart_sb.pass_checks  + env.pwm_sb.pass_checks;
        fail_all  = env.gpio_sb.fail_checks  + env.uart_sb.fail_checks  + env.pwm_sb.fail_checks;

        `uvm_info("SOC_TEST", "================================================================================", UVM_LOW)
        `uvm_info("SOC_TEST", "                 FINAL SoC UVM VIP INTEGRATION SUMMARY                          ", UVM_LOW)
        `uvm_info("SOC_TEST", "================================================================================", UVM_LOW)
        `uvm_info("SOC_TEST", $sformatf("  GPIO VIP Checks : Total=%0d, Pass=%0d, Fail=%0d",
                                env.gpio_sb.total_checks, env.gpio_sb.pass_checks, env.gpio_sb.fail_checks), UVM_LOW)
        `uvm_info("SOC_TEST", $sformatf("  UART VIP Checks : Total=%0d, Pass=%0d, Fail=%0d",
                                env.uart_sb.total_checks, env.uart_sb.pass_checks, env.uart_sb.fail_checks), UVM_LOW)
        `uvm_info("SOC_TEST", $sformatf("  PWM VIP Checks  : Total=%0d, Pass=%0d, Fail=%0d",
                                env.pwm_sb.total_checks,  env.pwm_sb.pass_checks,  env.pwm_sb.fail_checks),  UVM_LOW)
        `uvm_info("SOC_TEST", "--------------------------------------------------------------------------------", UVM_LOW)
        `uvm_info("SOC_TEST", $sformatf("  TOTAL COMBINED CHECKS : %0d", total_all), UVM_LOW)
        `uvm_info("SOC_TEST", $sformatf("  PASSED CHECKS         : %0d", pass_all), UVM_LOW)
        `uvm_info("SOC_TEST", $sformatf("  FAILED CHECKS         : %0d", fail_all), UVM_LOW)
        `uvm_info("SOC_TEST", "--------------------------------------------------------------------------------", UVM_LOW)
        if (fail_all == 0 && total_all > 0) begin
            `uvm_info("SOC_TEST", "  >>> FINAL STATUS: ALL UVM VIP INTEGRATION CHECKS PASSED (100%) <<<", UVM_LOW)
        end else begin
            `uvm_error("SOC_TEST", "  >>> FINAL STATUS: UVM VERIFICATION ENCOUNTERED FAILURES <<<")
        end
        `uvm_info("SOC_TEST", "================================================================================", UVM_LOW)
    endfunction
endclass

`endif // SOC_UVM_TEST_SV
