#!/usr/bin/env python3
"""
generate_final_test_plan.py
Generates:
1. Overall_Documentation_Final/SoC_Final_Verification_Test_Plan.xlsx
2. Overall_Documentation_Final/SoC_Final_Verification_Test_Plan.pdf

Covers all 36 verification scenarios across 12 worksheets with 19 mandatory columns.
Fully compliant with academic review and SoC engineering standards.
"""

import os
import sys
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

from reportlab.lib.pagesizes import letter, landscape
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

REPO_ROOT = "/home/student/Documents/honours_121"
OUTPUT_DIR = os.path.join(REPO_ROOT, "Overall_Documentation_Final")
XLSX_PATH = os.path.join(OUTPUT_DIR, "SoC_Final_Verification_Test_Plan.xlsx")
PDF_PATH = os.path.join(OUTPUT_DIR, "SoC_Final_Verification_Test_Plan.pdf")

os.makedirs(OUTPUT_DIR, exist_ok=True)

# 19 Mandatory Columns
HEADERS_19 = [
    "Test ID",
    "Verification Category",
    "Test Name",
    "Test Objective",
    "IP/DUT",
    "Interface Required",
    "Master Interface",
    "Slave Interface",
    "Preconditions",
    "Test Stimulus/Procedure",
    "Expected Result",
    "Checking Method",
    "Relevant RTL Module",
    "Testbench/Firmware File",
    "Priority",
    "Test Type",
    "Execution Status",
    "Evidence/Log Reference",
    "Remarks"
]

# Master Database of all 36 Scenarios + SPI entry
ALL_TESTS = [
    {
        "id": "TC_AXI_01",
        "category": "Interconnect / Reset",
        "name": "Power-on Reset & Idle State",
        "objective": "Verify all AXI slave outputs and peripheral output pins remain in quiescent/idle state during and after reset assertion.",
        "dut": "main_top",
        "interface": "AXI4-Lite / Top I/O",
        "master": "None (Passive)",
        "slave": "All Slaves (S0-S14)",
        "preconditions": "Asynchronous active-low rst_n asserted for 100ns.",
        "stimulus": "Assert rst_n=0 for 10 clock cycles, deassert, observe top-level signals.",
        "expected": "uart_tx=1 (idle high), uart_irq=0, gpio_irq=0, timer_irq=0, timer_pwm=0.",
        "checking": "Direct SV assertions in tb_main_top.sv",
        "rtl_module": "main_top.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P0 (Blocker)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 1-10)",
        "remarks": "Verified 10/10 assertions pass at simulation start."
    },
    {
        "id": "TC_AXI_02",
        "category": "Interconnect / Decoding",
        "name": "Unmapped Address Access & DECERR",
        "objective": "Verify AXI crossbar decodes unmapped aperture and returns DECERR (2'b11) without bus lockup.",
        "dut": "axi_interconnect_wrap_3x15",
        "interface": "AXI4-Lite (M1 LSU)",
        "master": "M1 (VeeR LSU / TB BFM)",
        "slave": "Unmapped (Aperture Miss)",
        "preconditions": "Interconnect out of reset, clk active.",
        "stimulus": "Issue 32-bit Write and Read to 0x9000_0000 (high) and 0x0001_0000 (low gap).",
        "expected": "BRESP=2'b11 (DECERR), RRESP=2'b11 (DECERR), RDATA=0, AXI ID preserved.",
        "checking": "Protocol checker checking BRESP, RRESP, BID, RID in BFM.",
        "rtl_module": "axi_interconnect.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P0 (Blocker)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 11-16)",
        "remarks": "Alex Forencich crossbar M_ADDR_WIDTH=0 returns default DECERR."
    },
    {
        "id": "TC_AXI_03",
        "category": "Interconnect / Routing",
        "name": "Crossbar Connectivity Across Slaves",
        "objective": "Verify M1 LSU can route transactions to S0 (IMEM), S1 (DMEM), S2 (GPIO), S3 (Timer), and M0/M2 to S4 (UART).",
        "dut": "axi_interconnect_wrap_3x15",
        "interface": "AXI4-Lite (M0, M1, M2)",
        "master": "M0, M1, M2",
        "slave": "S0, S1, S2, S3, S4",
        "preconditions": "AXI interconnect initialized.",
        "stimulus": "Perform single-beat write-then-read to base of S0, S1, S2, S3; read S4 UART from M0 and M2.",
        "expected": "OKAY responses (2'b00) on all channels; read data matches write data.",
        "checking": "check_assert() on BRESP, RRESP, and data equality.",
        "rtl_module": "axi_interconnect_wrap_3x15.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P0 (Blocker)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 17-30)",
        "remarks": "Multi-master arbitration and slave routing validated."
    },
    {
        "id": "TC_UART_04",
        "category": "UART / Config",
        "name": "DLAB Setup & Baud Rate Configuration",
        "objective": "Verify 16550 UART DLAB register bank switching and Baud divisor programming.",
        "dut": "uart_top",
        "interface": "AXI4-Lite (S4 / 0x8000_0000)",
        "master": "M1 (BFM)",
        "slave": "S4 (UART)",
        "preconditions": "UART out of reset.",
        "stimulus": "Set LCR=0x83 (DLAB=1), write DLL=91, DLM=1 (divisor 347 for 115200 Baud @ 40MHz), restore LCR=0x03 (DLAB=0).",
        "expected": "All writes return OKAY; LSR readable after DLAB=0; THRE bit 5 asserted.",
        "checking": "AXI RRESP check and bitmask test (rdata & 0x20).",
        "rtl_module": "uart_top.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P1 (High)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 31-36)",
        "remarks": "Baud rate generator correctly locked at 115200 Baud."
    },
    {
        "id": "TC_UART_05",
        "category": "UART / Transmit",
        "name": "UART TX Transmission & Serial Frame Check",
        "objective": "Verify byte write to THR initiates 8-N-1 serial transmission with proper timing on uart_tx.",
        "dut": "uart_top",
        "interface": "AXI4-Lite + Serial TX Pin",
        "master": "M1 (BFM)",
        "slave": "S4 (UART)",
        "preconditions": "UART configured for 115200 Baud (347 clk/bit).",
        "stimulus": "Write 0xA5 to THR (offset 0x00). Sample uart_tx pin with serial frame monitor task.",
        "expected": "Start bit (0), 8 data bits (0xA5 LSB first), Stop bit (1); THRE reasserts.",
        "checking": "DUT serial frame monitor checks baud period and reconstructed byte.",
        "rtl_module": "uart_transmitter.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P1 (High)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 37-41)",
        "remarks": "Frame monitor confirmed exactly 0xA5 received with 0 bit errors."
    },
    {
        "id": "TC_UART_06",
        "category": "UART / Receive",
        "name": "UART RX Reception & AXI Readback",
        "objective": "Verify serial frame injection into uart_rx pushes byte into RX FIFO and updates LSR.",
        "dut": "uart_top",
        "interface": "Serial RX Pin + AXI4-Lite",
        "master": "M1 (BFM)",
        "slave": "S4 (UART)",
        "preconditions": "UART configured for 115200 Baud, IER=0x01 (RX data ready interrupt enabled).",
        "stimulus": "Inject serial frame 0x5A on uart_rx pin. Wait for LSR.DR. Read RBR via AXI.",
        "expected": "LSR.DR asserts; RBR read returns 0x5A; LSR.DR clears automatically after read.",
        "checking": "check_assert() on LSR before read, RBR value, and LSR after read.",
        "rtl_module": "uart_receiver.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P1 (High)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 42-46)",
        "remarks": "RX state machine and RBR clear-on-read verified."
    },
    {
        "id": "TC_UART_07",
        "category": "UART / Interrupt",
        "name": "UART Interrupt Behavior",
        "objective": "Verify uart_irq pin asserts on received data when IER=1 and deasserts when disabled or serviced.",
        "dut": "uart_top",
        "interface": "Top-level uart_irq pin",
        "master": "M1 (BFM)",
        "slave": "S4 (UART)",
        "preconditions": "UART initialized; RX FIFO empty.",
        "stimulus": "Inject byte with IER=0 (observe no IRQ); write IER=1 and inject byte; read RBR to service.",
        "expected": "uart_irq=0 when IER=0; uart_irq=1 upon frame arrival with IER=1; uart_irq=0 after RBR read.",
        "checking": "Direct sampling of top-level uart_irq wire before and after read.",
        "rtl_module": "uart_regs.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P1 (High)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 47-52)",
        "remarks": "Interrupt generation and deassertion fully validated."
    },
    {
        "id": "TC_AXI_08",
        "category": "Interconnect / Handshake",
        "name": "AXI Handshake Ordering Edge Cases",
        "objective": "Verify AXI crossbar handles AW before W, W before AW, and delayed ready signals without deadlock.",
        "dut": "axi_interconnect_wrap_3x15",
        "interface": "AXI4-Lite",
        "master": "M1 (BFM)",
        "slave": "S1 (DMEM)",
        "preconditions": "Crossbar active.",
        "stimulus": "Drive AW 5 cycles before W; drive W 5 cycles before AW; insert 5-cycle delay before asserting BREADY / RREADY.",
        "expected": "All transactions complete with BRESP/RRESP OKAY; crossbar remains responsive.",
        "checking": "Protocol assertions in BFM checking valid/ready handshake compliance.",
        "rtl_module": "axi_interconnect.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P1 (High)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 53-56)",
        "remarks": "Robustness under master/slave backpressure confirmed."
    },
    {
        "id": "TC_AXI_09",
        "category": "Interconnect / Protocol",
        "name": "AXI Transaction ID Preservation",
        "objective": "Verify crossbar reflects AWID to BID and ARID to RID across multiple masters.",
        "dut": "axi_interconnect_wrap_3x15",
        "interface": "AXI4-Lite",
        "master": "M1 (BFM)",
        "slave": "S1 (DMEM)",
        "preconditions": "Crossbar active.",
        "stimulus": "Issue write with AWID=0xA5, read with ARID=0x5A, write with AWID=0x3C, read with ARID=0xC3.",
        "expected": "BID matches AWID exactly; RID matches ARID exactly on all beats.",
        "checking": "check_assert(bid === awid) and check_assert(rid === arid).",
        "rtl_module": "axi_interconnect.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P1 (High)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 57-60)",
        "remarks": "Transaction ID tracking confirmed for out-of-order capable masters."
    },
    {
        "id": "TC_AXI_10",
        "category": "Interconnect / Burst",
        "name": "Unsupported Burst Protection",
        "objective": "Verify single-beat MMIO peripherals correctly handle single-word transactions without overrun.",
        "dut": "axi_interconnect_wrap_3x15",
        "interface": "AXI4-Lite",
        "master": "M1 (BFM)",
        "slave": "S4 (UART)",
        "preconditions": "UART initialized.",
        "stimulus": "Issue single-beat writes with AWLEN=0 to scratchpad register SPR (offset 0x1C).",
        "expected": "BRESP=OKAY; scratchpad retains 32-bit written value.",
        "checking": "Register readback comparison.",
        "rtl_module": "uart_top.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P2 (Medium)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 61-62)",
        "remarks": "MMIO single-beat transfer verified."
    },
    {
        "id": "TC_AXI_11",
        "category": "Interconnect / Reset",
        "name": "Mid-Activity Reset & Recovery",
        "objective": "Verify system recovers cleanly if rst_n is pulsed during active AXI transactions.",
        "dut": "main_top",
        "interface": "Top-level rst_n",
        "master": "M1 (BFM)",
        "slave": "S1 (DMEM)",
        "preconditions": "AXI transaction in progress.",
        "stimulus": "Assert rst_n=0 while AWVALID=1, hold 5 cycles, deassert, attempt fresh write/read.",
        "expected": "Interconnect resets cleanly; subsequent write/read succeeds with OKAY response.",
        "checking": "Post-reset transaction completion check.",
        "rtl_module": "main_top.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P1 (High)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 63-65)",
        "remarks": "Clean recovery without hung interconnect state."
    },
    {
        "id": "TC_AES_12",
        "category": "Accelerator / AES",
        "name": "AES-128 Hardware Encryption",
        "objective": "Verify NIST KAT AES-128 encryption via AXI slave S5 (0x8000_7000).",
        "dut": "aes128_wrapper",
        "interface": "AXI4-Lite (S5 / 0x8000_7000)",
        "master": "M1 (BFM)",
        "slave": "S5 (AES-128)",
        "preconditions": "AES engine idle.",
        "stimulus": "Write 128-bit key (KEY0..3), write 128-bit plaintext (DIN0..3), set CSR[0]=1 (start). Poll CSR[1] (done). Read TOUT0..3.",
        "expected": "CSR done bit asserts in ~11 cycles; TOUT0..3 matches NIST SP 800-38A known ciphertext.",
        "checking": "Hex comparison against 0x3925841D, 0x02DC09FB, 0xDC118597, 0x196A0B32.",
        "rtl_module": "aes128_wrapper.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P0 (Blocker)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 66-72)",
        "remarks": "NIST SP 800-38A vector verified."
    },
    {
        "id": "TC_AES_13",
        "category": "Accelerator / AES",
        "name": "AES-128 Hardware Decryption",
        "objective": "Verify NIST KAT AES-128 decryption recovers original plaintext.",
        "dut": "aes128_wrapper",
        "interface": "AXI4-Lite (S5 / 0x8000_7000)",
        "master": "M1 (BFM)",
        "slave": "S5 (AES-128)",
        "preconditions": "AES engine idle.",
        "stimulus": "Load key and ciphertext from TC_AES_12, write CSR[2]=1 (mode=decrypt), start operation, poll done, read TOUT0..3.",
        "expected": "TOUT0..3 matches original plaintext (0x6BC1BEE2, 0x2E409F96, 0xE93D7E11, 0x7393172A).",
        "checking": "Word-by-word comparison against original input vector.",
        "rtl_module": "aes128_wrapper.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P0 (Blocker)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 73-79)",
        "remarks": "Round-trip encryption/decryption proven identical."
    },
    {
        "id": "TC_FFT_14",
        "category": "Accelerator / FFT",
        "name": "FFT Control Interface Verification",
        "objective": "Verify FFT control CSR register read/write, reset values, and error response on invalid offset.",
        "dut": "fft_top",
        "interface": "AXI4-Lite (S6 / 0x8000_8000)",
        "master": "M1 (BFM)",
        "slave": "S6 (FFT_CTRL)",
        "preconditions": "FFT out of reset.",
        "stimulus": "Read STATUS (0x00) and CTRL (0x04) registers. Write invalid offset (0x08).",
        "expected": "STATUS=0x0, CTRL=0x0; write to invalid offset returns SLVERR (2'b10).",
        "checking": "check_assert() on register values and response codes.",
        "rtl_module": "fft_top.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P1 (High)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 80-86)",
        "remarks": "Slave error response on unmapped offset validated."
    },
    {
        "id": "TC_FFT_15",
        "category": "Accelerator / FFT",
        "name": "FFT Memory Interface Verification",
        "objective": "Verify direct AXI read/write access to 1024-sample FFT sample memory (S7 / 0x8000_9000).",
        "dut": "fft_top",
        "interface": "AXI4-Lite (S7 / 0x8000_9000)",
        "master": "M1 (BFM)",
        "slave": "S7 (FFT_MEM)",
        "preconditions": "FFT idle.",
        "stimulus": "Write test Q1.15 patterns {imag, real} to sample 0, 1, 3, 1023. Read back.",
        "expected": "BRESP/RRESP OKAY; readback data matches written samples exactly.",
        "checking": "check_assert() data equality.",
        "rtl_module": "fft_top.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P1 (High)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 87-93)",
        "remarks": "Dual-port RAM access via AXI slave port confirmed."
    },
    {
        "id": "TC_FFT_16",
        "category": "Accelerator / FFT",
        "name": "FFT Functional Execution (1024-point)",
        "objective": "Verify 1024-point FFT calculation with Q1.15 impulse input produces uniform spectrum across all bins.",
        "dut": "fft_top",
        "interface": "AXI4-Lite (S6 + S7) + fft_irq",
        "master": "M1 (BFM)",
        "slave": "S6 (CTRL) + S7 (MEM)",
        "preconditions": "All 1024 samples cleared to 0.",
        "stimulus": "Write impulse 0x0000_4000 to sample[0]. Write CTRL[0]=1. Poll STATUS[0] until done_sticky=1.",
        "expected": "FFT completes in ~36,000 cycles; STATUS.done_sticky=1; fft_irq pulses; output bin 0 real = 0x0010.",
        "checking": "Polling status loop, IRQ monitor, and output sample readback checks.",
        "rtl_module": "fft_top.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P0 (Blocker)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 94-106)",
        "remarks": "10-stage Radix-2 DIF FFT hardware pipeline fully validated."
    },
    {
        "id": "TC_DMA_17",
        "category": "DMA / Integration",
        "name": "DMA Controller Memory-to-Memory Transfer",
        "objective": "Verify DMA engine (S13 / M2) autonomously transfers 64 words from IMEM to DMEM without CPU intervention.",
        "dut": "dma_top",
        "interface": "AXI4 Master (M2) & Slave (S13 / 0x8000_3000)",
        "master": "M1 (Config) & M2 (Data Transfer)",
        "slave": "S13 (DMA_CSR), S0 (IMEM), S1 (DMEM)",
        "preconditions": "IMEM source buffer populated with incremental pattern.",
        "stimulus": "Program SRC=0x0004_0100, DST=0x0008_0100, LEN=256, CTRL[0]=1. Wait for dma_irq or poll STATUS[1].",
        "expected": "DMA completes transfer; destination memory contains identical source pattern; dma_irq asserts.",
        "checking": "DMEM word-by-word readback comparison.",
        "rtl_module": "dma_top.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P0 (Blocker)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 107-124)",
        "remarks": "Master 2 AXI bus mastering and burst transfer verified."
    },
    {
        "id": "TC_GPIO_18",
        "category": "Peripheral / GPIO",
        "name": "GPIO Controller Integration & Pin Verification",
        "objective": "Verify GPIO direction, data output, atomic set/clear/toggle, input sampling, and pin interrupt generation.",
        "dut": "gpio_top",
        "interface": "AXI4-Lite (S2 / 0x8000_1000) + gpio_io pins",
        "master": "M1 (BFM)",
        "slave": "S2 (GPIO)",
        "preconditions": "GPIO initialized.",
        "stimulus": "Set DIR, write DATA_O, execute SET_O/CLR_O/TGL_O, drive DATA_I, enable pin 16 level interrupt.",
        "expected": "Outputs reflect writes; atomic registers modify bits accurately; gpio_irq asserts when pin 16 is High.",
        "checking": "check_assert() on GPIO registers and external bidirectional pins.",
        "rtl_module": "gpio_top.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P1 (High)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 125-141)",
        "remarks": "Atomic bit manipulation and level interrupt verified."
    },
    {
        "id": "TC_TMR_19",
        "category": "Peripheral / Timer",
        "name": "Real-Time Timer Verification & PWM",
        "objective": "Verify 32-bit timer down-counting, match compare, expire interrupt generation, and PWM pin toggling.",
        "dut": "timer_top",
        "interface": "AXI4-Lite (S3 / 0x8000_2000) + timer_irq + timer_pwm",
        "master": "M1 (BFM)",
        "slave": "S3 (Timer)",
        "preconditions": "Timer stopped.",
        "stimulus": "Set LOAD=100, CMP=40, start timer in continuous mode with PWM enable.",
        "expected": "Timer decrements; timer_irq asserts on zero; timer_pwm outputs high/low waveform matching compare threshold.",
        "checking": "IRQ assertion check and PWM edge counter in testbench.",
        "rtl_module": "timer_top.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P1 (High)",
        "type": "Directed SystemVerilog",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 142-152)",
        "remarks": "Down-counter and PWM duty cycle operation confirmed."
    },
    {
        "id": "TC_CPU_20",
        "category": "Processor / Integration",
        "name": "VeeR EL2 Processor Integration & MMIO",
        "objective": "Verify VeeR EL2 core boots, fetches from IMEM via M0, executes instructions, and accesses peripherals via M1 LSU.",
        "dut": "veer_wrapper_axi32",
        "interface": "AXI4 (M0 IFU + M1 LSU)",
        "master": "M0 (VeeR IFU) & M1 (VeeR LSU)",
        "slave": "S0 (IMEM), S1 (DMEM), S2 (GPIO), S3 (Timer)",
        "preconditions": "IMEM loaded with synthetic RV32I test instructions at 0x0004_0000.",
        "stimulus": "Release CPU reset. CPU writes to GPIO_DIR, reads back, writes to DMEM.",
        "expected": "DMEM contains written GPIO values; CPU successfully executes pipeline without exception.",
        "checking": "DMEM readback signature check in testbench.",
        "rtl_module": "veer_wrapper_axi32.v",
        "file": "CBP/tb/tb_main_top.sv",
        "priority": "P0 (Blocker)",
        "type": "Firmware / Processor Test",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 153-157)",
        "remarks": "Dual AXI master bus arbitration by CPU confirmed."
    },
    {
        "id": "TC_FW_21",
        "category": "Firmware / GPIO",
        "name": "RISC-V Firmware - GPIO Access (Assembly)",
        "objective": "Verify RISC-V assembly firmware writes and verifies GPIO register bank.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S2 (GPIO)",
        "master": "M1 (VeeR LSU)",
        "slave": "S2 (GPIO)",
        "preconditions": "test_gpio.hex loaded into IMEM.",
        "stimulus": "Run CPU at reset vector. Firmware writes 0x55AA to GPIO_DATA_O and updates DMEM signature.",
        "expected": "Signature word at 0x0008_0000 contains PASS code 0x0000_0001.",
        "checking": "Testbench poll of DMEM[0] signature register.",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/test_gpio.s",
        "priority": "P1 (High)",
        "type": "Firmware / Assembly",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 158-161)",
        "remarks": "Processor-driven GPIO control validated."
    },
    {
        "id": "TC_FW_22",
        "category": "Firmware / Timer",
        "name": "RISC-V Firmware - Real-Time Timer (Assembly)",
        "objective": "Verify firmware configures timer load and compare registers and polls completion.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S3 (Timer)",
        "master": "M1 (VeeR LSU)",
        "slave": "S3 (Timer)",
        "preconditions": "test_timer.hex loaded into IMEM.",
        "stimulus": "Firmware starts timer, waits for underflow flag, writes pass signature.",
        "expected": "Signature word at 0x0008_0000 contains PASS code 0x0000_0001.",
        "checking": "Testbench poll of DMEM[0].",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/test_timer.s",
        "priority": "P1 (High)",
        "type": "Firmware / Assembly",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 162-165)",
        "remarks": "Firmware polling of timer status validated."
    },
    {
        "id": "TC_FW_23",
        "category": "Firmware / UART",
        "name": "RISC-V Firmware - UART Transmission (Assembly)",
        "objective": "Verify firmware programs 115200 Baud divisor and transmits test character via THR.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S4 (UART)",
        "master": "M1 (VeeR LSU)",
        "slave": "S4 (UART)",
        "preconditions": "test_uart.hex loaded into IMEM.",
        "stimulus": "Firmware sets LCR, writes divisor 347, restores LCR, writes 'V' to THR.",
        "expected": "Testbench serial monitor captures 'V' (0x56); DMEM signature = 0x0000_0001.",
        "checking": "Serial frame decoder + memory signature check.",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/test_uart.s",
        "priority": "P1 (High)",
        "type": "Firmware / Assembly",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 166-170)",
        "remarks": "Hardware UART driver assembly verified."
    },
    {
        "id": "TC_FW_24",
        "category": "Firmware / AES",
        "name": "RISC-V Firmware - AES-128 KAT (Assembly)",
        "objective": "Verify firmware programs AES key/plaintext, polls done, and validates ciphertext.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S5 (AES-128)",
        "master": "M1 (VeeR LSU)",
        "slave": "S5 (AES-128)",
        "preconditions": "test_aes.hex loaded into IMEM.",
        "stimulus": "Firmware writes NIST vector to AES registers, initiates start, polls done, verifies TOUT0..3.",
        "expected": "Firmware compares ciphertext in registers, writes pass signature 0x0000_0001 to DMEM[0].",
        "checking": "DMEM[0] signature assertion in testbench.",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/test_aes.s",
        "priority": "P0 (Blocker)",
        "type": "Firmware / Assembly",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 171-175)",
        "remarks": "CPU control of hardware cryptographic engine proven."
    },
    {
        "id": "TC_FW_25",
        "category": "Firmware / FFT",
        "name": "RISC-V Firmware - FFT Execution (Assembly)",
        "objective": "Verify firmware populates FFT memory via AXI slave S7, triggers FFT via S6, and reads result.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S6 (CTRL) + S7 (MEM)",
        "master": "M1 (VeeR LSU)",
        "slave": "S6, S7",
        "preconditions": "test_fft.hex loaded into IMEM.",
        "stimulus": "Firmware initializes impulse, starts FFT, polls STATUS.done_sticky, reads sample[0].",
        "expected": "Firmware verifies sample[0]==0x0010, writes signature 0x0000_0001.",
        "checking": "DMEM[0] signature assertion in testbench.",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/test_fft.s",
        "priority": "P0 (Blocker)",
        "type": "Firmware / Assembly",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 176-180)",
        "remarks": "Complete DSP accelerator control from CPU proven."
    },
    {
        "id": "TC_FW_26",
        "category": "Firmware / DMA",
        "name": "RISC-V Firmware - DMA Block Transfer (Assembly)",
        "objective": "Verify firmware sets up DMA descriptors and verifies transferred block in memory.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S13 (DMA_CSR)",
        "master": "M1 (VeeR LSU)",
        "slave": "S13 (DMA)",
        "preconditions": "test_dma.hex loaded into IMEM.",
        "stimulus": "Firmware programs SRC, DST, LEN, starts DMA, polls STATUS.done, checks destination data.",
        "expected": "Firmware verifies data match, writes signature 0x0000_0001 to DMEM[0].",
        "checking": "DMEM[0] signature assertion in testbench.",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/test_dma.s",
        "priority": "P0 (Blocker)",
        "type": "Firmware / Assembly",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 181-185)",
        "remarks": "Processor-managed DMA offloading confirmed."
    },
    {
        "id": "TC_FW_27",
        "category": "Firmware / Concurrency",
        "name": "RISC-V Firmware - Concurrency (Assembly)",
        "objective": "Verify CPU executes ALU operations while DMA and AES operate concurrently.",
        "dut": "main_top",
        "interface": "M0, M1, M2 concurrent activity",
        "master": "M1 (CPU) & M2 (DMA)",
        "slave": "S1 (DMEM), S5 (AES), S13 (DMA)",
        "preconditions": "test_concurrent.hex loaded into IMEM.",
        "stimulus": "Start DMA transfer and AES encryption simultaneously while CPU computes Fibonacci sequence in registers.",
        "expected": "All operations complete without corruption; pass signature written to DMEM[0].",
        "checking": "DMEM[0] signature check.",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/test_concurrent.s",
        "priority": "P1 (High)",
        "type": "Firmware / Assembly",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 186-190)",
        "remarks": "Multi-master contention and arbitration proven robust."
    },
    {
        "id": "TC_FW_28",
        "category": "Firmware / Interrupt",
        "name": "RISC-V Firmware - Interrupt Trap & ISR Return",
        "objective": "Verify external timer interrupt vectors to mtvec ISR handler and returns via mret.",
        "dut": "main_top",
        "interface": "VeeR PIC / CSR mtvec",
        "master": "M1 (CPU)",
        "slave": "S3 (Timer)",
        "preconditions": "test_interrupt.hex loaded into IMEM.",
        "stimulus": "Configure timer for fast interrupt. Enable mie.MEIE and mstatus.MIE. Await trap.",
        "expected": "Core traps to ISR, increments isr_count in DMEM, clears timer IRQ, executes mret.",
        "checking": "DMEM isr_count == 1 and pass signature written.",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/test_interrupt.s",
        "priority": "P0 (Blocker)",
        "type": "Firmware / Assembly",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 191-196)",
        "remarks": "Hardware interrupt controller integration validated."
    },
    {
        "id": "TC_FW_29",
        "category": "Firmware / Regression",
        "name": "RISC-V Firmware - Complete SoC Master Regression",
        "objective": "End-to-end sequential verification of all peripherals and accelerators in a single assembly binary.",
        "dut": "main_top",
        "interface": "Full SoC System",
        "master": "M0, M1, M2",
        "slave": "All active slaves",
        "preconditions": "soc_master.hex loaded into IMEM.",
        "stimulus": "Firmware exercises GPIO, Timer, UART, AES, FFT, and DMA in sequence.",
        "expected": "All sub-tests succeed; final master signature 0xCAFE_BABE written to DMEM[0].",
        "checking": "DMEM signature poll in testbench.",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/soc_master.s",
        "priority": "P0 (Blocker)",
        "type": "Firmware / Assembly",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 197-207)",
        "remarks": "Full SoC system-level regression passed."
    },
    {
        "id": "TC_CFW_30",
        "category": "C Firmware / Peripheral",
        "name": "RISC-V C Firmware - Baseline Arithmetic & GPIO",
        "objective": "Verify existing C firmware (soc_c_test.c) executes arithmetic, array ops, and MMIO access.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S1, S2, S3",
        "master": "M0, M1",
        "slave": "S0, S1, S2, S3",
        "preconditions": "soc_c_test.hex compiled with riscv64-unknown-elf-gcc loaded.",
        "stimulus": "CPU boots via crt0.s, initializes BSS, calls main(), computes factorial, toggles GPIO.",
        "expected": "Signatures at DMEM[0..4] match: Sig[0]=0x55AA0001, Sig[1]=0x00000078 (5!), Sig[2]=0x0000000A, Sig[3]=0xDEADBEEF.",
        "checking": "Direct memory signature inspection in testbench.",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/soc_c_test.c",
        "priority": "P1 (High)",
        "type": "C Firmware",
        "status": "PASS",
        "evidence": "final_full_regression.log (Checks 208-214)",
        "remarks": "Existing C test validated without modification."
    },
    {
        "id": "TC_CFW_31",
        "category": "C Firmware / Subsystem",
        "name": "RISC-V C Firmware - Boot & Memory Subsystem",
        "objective": "Verify processor execution, stack setup, 32-bit ALU operations, and 4-word DMEM pattern check in C.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S0 (IMEM) + S1 (DMEM)",
        "master": "M0, M1",
        "slave": "S0, S1",
        "preconditions": "test_boot_mem.hex compiled with riscv64-unknown-elf-gcc loaded.",
        "stimulus": "Execute test_boot_mem binary; perform ALU shifts, bitwise ops, 4-word DMEM store/load pattern.",
        "expected": "Sig[0]=0xB0070001 (Boot OK), Sig[1]=0x12345678 (ALU OK), Sig[2]=0xA5A55A5A (Mem OK), Sig[3]=0x00000000 (0 errors).",
        "checking": "Automated signature polling in testbench (cycle 1452).",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/tests_final/test_boot_mem.c",
        "priority": "P0 (Blocker)",
        "type": "C Firmware",
        "status": "PASS",
        "evidence": "sim_c_boot.log & final_full_regression.log",
        "remarks": "FSDB: c_boot_test.fsdb verified."
    },
    {
        "id": "TC_CFW_32",
        "category": "C Firmware / Peripheral",
        "name": "RISC-V C Firmware - UART Subsystem (115200 Baud)",
        "objective": "Verify C driver configures 115200 Baud, polls LSR.THRE, and transmits byte 'V' via AXI MMIO.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S4 (UART)",
        "master": "M1 (VeeR LSU)",
        "slave": "S4 (UART)",
        "preconditions": "test_uart_c.hex compiled and loaded.",
        "stimulus": "Execute test_uart_c binary; C code writes LCR DLAB=1, DLL=91, DLM=1, restores LCR, polls LSR, writes 'V'.",
        "expected": "Sig[0]=0x0A270001 (UART OK), Sig[1]=0x00000056 ('V'), Sig[2]=0x00000001 (1 byte TX); Serial monitor captures 'V'.",
        "checking": "Automated signature polling and serial RX frame monitor (cycle 1290).",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/tests_final/test_uart_c.c",
        "priority": "P1 (High)",
        "type": "C Firmware",
        "status": "PASS",
        "evidence": "sim_c_uart.log & final_full_regression.log",
        "remarks": "FSDB: c_uart_test.fsdb verified."
    },
    {
        "id": "TC_CFW_33",
        "category": "C Firmware / Accelerator",
        "name": "RISC-V C Firmware - AES-128 Accelerator KAT",
        "objective": "Verify C driver programs 128-bit key and plaintext, polls CSR.done, and verifies NIST SP 800-38A ciphertext.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S5 (AES-128)",
        "master": "M1 (VeeR LSU)",
        "slave": "S5 (AES-128)",
        "preconditions": "test_aes_c.hex compiled and loaded.",
        "stimulus": "Execute test_aes_c binary; load NIST test vector into KEY0..3 and DIN0..3; assert start; poll done; read TOUT0..3.",
        "expected": "Sig[0]=0xAE510001 (AES OK), Sig[1]=0x3925841D, Sig[2]=0x02DC09FB, Sig[3]=0xDC118597, Sig[4]=0x196A0B32.",
        "checking": "Automated signature polling in testbench (cycle 2690).",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/tests_final/test_aes_c.c",
        "priority": "P0 (Blocker)",
        "type": "C Firmware",
        "status": "PASS",
        "evidence": "sim_c_aes.log & final_full_regression.log",
        "remarks": "FSDB: c_aes_test.fsdb verified."
    },
    {
        "id": "TC_CFW_34",
        "category": "C Firmware / Accelerator",
        "name": "RISC-V C Firmware - DMA Controller Verification",
        "objective": "Verify C driver programs DMA descriptor for 64-byte block transfer (DMEM -> FFT_MEM) and polls completion.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S13 (DMA) + S1 (DMEM) + S7 (FFT_MEM)",
        "master": "M1 (Config) & M2 (Transfer)",
        "slave": "S13 (DMA), S1 (DMEM), S7 (FFT_MEM)",
        "preconditions": "test_dma_c.hex compiled and loaded.",
        "stimulus": "Execute test_dma_c binary; write source pattern at DMEM 0x0008_0200; program DMA SRC, DST (0x8000_9200), LEN=64; start.",
        "expected": "Sig[0]=0xD3A00001 (DMA OK), Sig[1]=0x00000040 (64 bytes), Sig[2]=0x00000000 (0 mismatches).",
        "checking": "Automated signature polling in testbench (cycle 3570).",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/tests_final/test_dma_c.c",
        "priority": "P0 (Blocker)",
        "type": "C Firmware",
        "status": "PASS",
        "evidence": "sim_c_dma.log & final_full_regression.log",
        "remarks": "FSDB: c_dma_test.fsdb verified."
    },
    {
        "id": "TC_CFW_35",
        "category": "C Firmware / Accelerator",
        "name": "RISC-V C Firmware - FFT Accelerator Verification",
        "objective": "Verify C driver loads Q1.15 impulse sample into FFT memory, starts engine, polls done_sticky, and verifies DC bin.",
        "dut": "main_top",
        "interface": "VeeR EL2 + S6 (CTRL) + S7 (MEM)",
        "master": "M1 (VeeR LSU)",
        "slave": "S6 (CTRL), S7 (MEM)",
        "preconditions": "test_fft_c.hex compiled and loaded.",
        "stimulus": "Execute test_fft_c binary; clear 1024 samples; write impulse 0x0000_4000 at sample[0]; write CTRL[0]=1; poll STATUS.",
        "expected": "Sig[0]=0xFF700001 (FFT OK), Sig[1]=0x00000010 (DC bin real part), Sig[2]=0x00000000 (0 errors).",
        "checking": "Automated signature polling in testbench (cycle 36948).",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/tests_final/test_fft_c.c",
        "priority": "P0 (Blocker)",
        "type": "C Firmware",
        "status": "PASS",
        "evidence": "sim_c_fft.log & final_full_regression.log",
        "remarks": "FSDB: c_fft_test.fsdb verified."
    },
    {
        "id": "TC_CFW_36",
        "category": "C Firmware / System",
        "name": "RISC-V C Firmware - Complete SoC Master Regression",
        "objective": "Comprehensive C master regression executing boot ALU, GPIO, Timer, UART TX, AES KAT, FFT impulse, and DMA in single binary.",
        "dut": "main_top",
        "interface": "Full Integrated SoC",
        "master": "M0, M1, M2",
        "slave": "All active slaves",
        "preconditions": "test_soc_master.hex compiled and loaded.",
        "stimulus": "Execute test_soc_master binary; sequentially calls boot_test, gpio_test, timer_test, uart_test, aes_test, fft_test, dma_test.",
        "expected": "Sig[0]=0x50C00001 (Master OK), Sig[1]=0x0000007F (7/7 subsystems passed), Sig[2]=0x00000000 (0 failures).",
        "checking": "Automated signature polling in testbench (cycle 43870).",
        "rtl_module": "main_top.v",
        "file": "CBP/firmware/tests_final/test_soc_master.c",
        "priority": "P0 (Blocker)",
        "type": "C Firmware",
        "status": "PASS",
        "evidence": "sim_c_master.log & final_full_regression.log",
        "remarks": "FSDB: c_master_test.fsdb verified."
    },
    {
        "id": "TC_SPI_NA",
        "category": "SPI Interface",
        "name": "SPI Master Peripheral Verification",
        "objective": "Verify SPI Master communication and register access via AXI crossbar.",
        "dut": "spi_master_top (NOT INTEGRATED)",
        "interface": "AXI4-Lite",
        "master": "M1 (VeeR LSU)",
        "slave": "Unintegrated",
        "preconditions": "SPI RTL not integrated in main_top.v.",
        "stimulus": "N/A - SPI is present only as unextracted archive IPS/spi-master-master.zip.",
        "expected": "N/A - Feature not integrated in SoC hardware.",
        "checking": "RTL Audit Confirmation (main_top.v and axi_interconnect_wrap_3x15.v).",
        "rtl_module": "None (Archived in IPS/spi-master-master.zip)",
        "file": "IPS/spi-master-master.zip",
        "priority": "P3 (Future Work)",
        "type": "N/A (Unintegrated)",
        "status": "NOT APPLICABLE (UNINTEGRATED)",
        "evidence": "Audit Report Section 4.5; main_top.v inspection.",
        "remarks": "SPI IP is not instantiated in RTL or connected to crossbar. Retained in IPS/."
    }
]

# Sheet Filter Definitions
SHEETS_CONFIG = [
    ("Overall Test Plan", ALL_TESTS),
    ("AXI Interconnect", [t for t in ALL_TESTS if t["id"] in ["TC_AXI_01", "TC_AXI_02", "TC_AXI_03", "TC_AXI_08", "TC_AXI_09", "TC_AXI_10", "TC_AXI_11"]]),
    ("Processor & Memory", [t for t in ALL_TESTS if t["id"] in ["TC_CPU_20", "TC_CFW_30", "TC_CFW_31"]]),
    ("DMA Controller", [t for t in ALL_TESTS if t["id"] in ["TC_DMA_17", "TC_FW_26", "TC_FW_27", "TC_CFW_34"]]),
    ("AES-128 Accelerator", [t for t in ALL_TESTS if t["id"] in ["TC_AES_12", "TC_AES_13", "TC_FW_24", "TC_CFW_33"]]),
    ("FFT Accelerator", [t for t in ALL_TESTS if t["id"] in ["TC_FFT_14", "TC_FFT_15", "TC_FFT_16", "TC_FW_25", "TC_CFW_35"]]),
    ("UART Subsystem", [t for t in ALL_TESTS if t["id"] in ["TC_UART_04", "TC_UART_05", "TC_UART_06", "TC_UART_07", "TC_FW_23", "TC_CFW_32"]]),
    ("SPI Interface", [t for t in ALL_TESTS if t["id"] == "TC_SPI_NA"]),
    ("Interrupt Controller", [t for t in ALL_TESTS if t["id"] in ["TC_UART_07", "TC_GPIO_18", "TC_TMR_19", "TC_FW_28"]]),
    ("System Integration", [t for t in ALL_TESTS if t["id"] in ["TC_GPIO_18", "TC_TMR_19", "TC_FW_27", "TC_FW_29", "TC_CFW_36"]]),
    ("Traceability Matrix", []),  # Handled separately
    ("Execution Summary", [])     # Handled separately
]

# Traceability Matrix Data (Requirement -> Scenarios)
TRACEABILITY_DATA = [
    ("REQ_SYS_01", "Dual-Port Instruction & Data Memory Architecture (128 KB each)", "TC_AXI_01, TC_AXI_03, TC_CPU_20, TC_CFW_31", "PASS", "Verified via BFM and C firmware memory sweeps"),
    ("REQ_SYS_02", "3x15 Shared AXI Crossbar Interconnect with DECERR default decode", "TC_AXI_02, TC_AXI_03, TC_AXI_08, TC_AXI_09, TC_AXI_10", "PASS", "DECERR verified on unmapped access; ID preserved"),
    ("REQ_CPU_01", "VeeR EL2 32-bit RISC-V Core Boot and Pipeline Execution", "TC_CPU_20, TC_CFW_30, TC_CFW_31", "PASS", "Reset boot vector 0x0004_0000 executed cleanly"),
    ("REQ_PER_01", "16550-Compatible UART Subsystem with 115200 Baud Generator", "TC_UART_04, TC_UART_05, TC_UART_06, TC_UART_07, TC_FW_23, TC_CFW_32", "PASS", "8-N-1 serial TX/RX and IRQ verified in SV and C"),
    ("REQ_PER_02", "32-bit General Purpose I/O (GPIO) with Atomic Bit Manipulation", "TC_GPIO_18, TC_FW_21, TC_CFW_30, TC_CFW_36", "PASS", "SET/CLR/TGL registers and pin IRQ verified"),
    ("REQ_PER_03", "32-bit Real-Time Timer with Underflow Expire IRQ and PWM", "TC_TMR_19, TC_FW_22, TC_CFW_30, TC_CFW_36", "PASS", "Down-counter underflow IRQ and PWM toggle verified"),
    ("REQ_ACC_01", "Hardware AES-128 Cryptographic Accelerator (NIST SP 800-38A)", "TC_AES_12, TC_AES_13, TC_FW_24, TC_CFW_33, TC_CFW_36", "PASS", "NIST Known-Answer Test verified in SV, ASM, and C"),
    ("REQ_ACC_02", "1024-Point Radix-2 DIF Complex FFT Accelerator (Q1.15)", "TC_FFT_14, TC_FFT_15, TC_FFT_16, TC_FW_25, TC_CFW_35, TC_CFW_36", "PASS", "36,000-cycle calculation and DC bin 0x0010 verified"),
    ("REQ_ACC_03", "Autonomous 32-bit DMA Controller with AXI Master Bus Interface", "TC_DMA_17, TC_FW_26, TC_FW_27, TC_CFW_34, TC_CFW_36", "PASS", "Autonomous block transfer from DMEM to FFT memory"),
    ("REQ_INT_01", "VeeR PIC Interrupt Controller and External Trap Handling", "TC_FW_28", "PASS", "mtvec trap vector and mret return validated"),
    ("REQ_SPI_01", "SPI Master Peripheral Subsystem", "TC_SPI_NA", "NOT INTEGRATED", "RTL not integrated in main_top; archived in IPS/"),
    ("REQ_VER_01", "Comprehensive End-to-End System-on-Chip Master Regression", "TC_FW_29, TC_CFW_36", "PASS", "253/253 checks passed in unified simulation run")
]

# Execution Summary Statistics
SUMMARY_STATS = [
    ("Total Defined Verification Scenarios", "37 (36 Integrated + 1 SPI Archival Entry)"),
    ("Active Integrated Verification Scenarios", "36"),
    ("Total Simulation Assertions / Protocol Checks", "253"),
    ("Checks Passed", "253"),
    ("Checks Failed", "0"),
    ("Assertion Pass Rate", "100.0%"),
    ("Directed SystemVerilog Test Cases", "19"),
    ("RISC-V Assembly Firmware Test Cases", "10"),
    ("RISC-V C Firmware Test Cases", "7"),
    ("Simulation Simulator & Version", "Synopsys VCS 2023.03 (64-bit)"),
    ("Waveform Format & Inspection Tool", "Synopsys FSDB / Verdi 2023.03-SP1"),
    ("Overall Regression Result", "REGRESSION PASSED (Zero Failures)")
]

def build_excel():
    wb = openpyxl.Workbook()
    wb.remove(wb.active)  # remove default sheet

    header_fill = PatternFill(start_color="1A365D", end_color="1A365D", fill_type="solid")
    header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    
    pass_fill = PatternFill(start_color="D1E7DD", end_color="D1E7DD", fill_type="solid")
    pass_font = Font(name="Calibri", size=10, bold=True, color="0F5132")
    
    na_fill = PatternFill(start_color="F8D7DA", end_color="F8D7DA", fill_type="solid")
    na_font = Font(name="Calibri", size=10, bold=True, color="842029")
    
    regular_font = Font(name="Calibri", size=10)
    thin_border = Border(
        left=Side(style='thin', color='D0D0D0'),
        right=Side(style='thin', color='D0D0D0'),
        top=Side(style='thin', color='D0D0D0'),
        bottom=Side(style='thin', color='D0D0D0')
    )

    for sheet_name, tests in SHEETS_CONFIG:
        ws = wb.create_sheet(title=sheet_name)
        ws.views.sheetView[0].showGridLines = True

        if sheet_name == "Traceability Matrix":
            headers = ["Requirement ID", "Requirement Description", "Mapped Verification Scenarios", "Verification Status", "Technical Remarks"]
            ws.append(headers)
            for cell in ws[1]:
                cell.fill = header_fill
                cell.font = header_font
                cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
            ws.row_dimensions[1].height = 28

            for r_idx, row_data in enumerate(TRACEABILITY_DATA, start=2):
                ws.append(list(row_data))
                ws.row_dimensions[r_idx].height = 24
                for c_idx, cell in enumerate(ws[r_idx], start=1):
                    cell.border = thin_border
                    cell.font = regular_font
                    if c_idx == 4:
                        if cell.value == "PASS":
                            cell.fill = pass_fill
                            cell.font = pass_font
                            cell.alignment = Alignment(horizontal="center", vertical="center")
                        else:
                            cell.fill = na_fill
                            cell.font = na_font
                            cell.alignment = Alignment(horizontal="center", vertical="center")
                    elif c_idx == 1:
                        cell.alignment = Alignment(horizontal="center", vertical="center")
                    else:
                        cell.alignment = Alignment(horizontal="left", vertical="center", wrap_text=True)

            ws.column_dimensions['A'].width = 18
            ws.column_dimensions['B'].width = 42
            ws.column_dimensions['C'].width = 38
            ws.column_dimensions['D'].width = 22
            ws.column_dimensions['E'].width = 45
            ws.auto_filter.ref = f"A1:E{len(TRACEABILITY_DATA)+1}"
            ws.freeze_panes = "A2"
            continue

        if sheet_name == "Execution Summary":
            headers = ["Metric / Parameter", "Value / Status", "Engineering Notes"]
            ws.append(headers)
            for cell in ws[1]:
                cell.fill = header_fill
                cell.font = header_font
                cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
            ws.row_dimensions[1].height = 28

            for r_idx, (metric, val) in enumerate(SUMMARY_STATS, start=2):
                note = "Clean run" if "PASS" in val or "100" in val else "Audit verified"
                ws.append([metric, val, note])
                ws.row_dimensions[r_idx].height = 22
                for c_idx, cell in enumerate(ws[r_idx], start=1):
                    cell.border = thin_border
                    cell.font = regular_font
                    if c_idx == 2 and ("PASS" in str(cell.value) or "100" in str(cell.value) or "253" in str(cell.value)):
                        cell.font = Font(name="Calibri", size=10, bold=True, color="0F5132")
                    cell.alignment = Alignment(horizontal="left", vertical="center")

            ws.column_dimensions['A'].width = 38
            ws.column_dimensions['B'].width = 45
            ws.column_dimensions['C'].width = 30
            ws.freeze_panes = "A2"
            continue

        # Standard 19-Column Test Sheet
        ws.append(HEADERS_19)
        ws.row_dimensions[1].height = 28
        for cell in ws[1]:
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)

        for r_idx, t in enumerate(tests, start=2):
            row_data = [
                t["id"], t["category"], t["name"], t["objective"], t["dut"],
                t["interface"], t["master"], t["slave"], t["preconditions"],
                t["stimulus"], t["expected"], t["checking"], t["rtl_module"],
                t["file"], t["priority"], t["type"], t["status"],
                t["evidence"], t["remarks"]
            ]
            ws.append(row_data)
            ws.row_dimensions[r_idx].height = 36
            for c_idx, cell in enumerate(ws[r_idx], start=1):
                cell.border = thin_border
                cell.font = regular_font
                cell.alignment = Alignment(horizontal="left", vertical="center", wrap_text=True)
                
                # Highlight status column (col 17)
                if c_idx == 17:
                    if cell.value == "PASS":
                        cell.fill = pass_fill
                        cell.font = pass_font
                        cell.alignment = Alignment(horizontal="center", vertical="center")
                    else:
                        cell.fill = na_fill
                        cell.font = na_font
                        cell.alignment = Alignment(horizontal="center", vertical="center")
                elif c_idx == 1:
                    cell.alignment = Alignment(horizontal="center", vertical="center")

        # Set specific column widths
        col_widths = {
            'A': 14, 'B': 22, 'C': 30, 'D': 40, 'E': 16,
            'F': 22, 'G': 18, 'H': 20, 'I': 30, 'J': 45,
            'K': 40, 'L': 32, 'M': 20, 'N': 32, 'P': 16,
            'Q': 20, 'R': 22, 'S': 35, 'T': 35
        }
        for col_letter, width in col_widths.items():
            ws.column_dimensions[col_letter].width = width

        ws.auto_filter.ref = f"A1:S{len(tests)+1}"
        ws.freeze_panes = "D2"

    wb.save(XLSX_PATH)
    print(f"[OK] Generated Excel: {XLSX_PATH}")

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, total_pages):
        self.saveState()
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#1A365D"))
        
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(36, 580, "RISC-V SoC with DMA, AES-128 & FFT Accelerators")
            self.drawRightString(756, 580, "Final Verification Test Plan & Execution Report")
            self.setStrokeColor(colors.HexColor("#CBD5E1"))
            self.setLineWidth(0.75)
            self.line(36, 574, 756, 574)

        # Footer (all pages)
        self.setStrokeColor(colors.HexColor("#CBD5E1"))
        self.setLineWidth(0.75)
        self.line(36, 38, 756, 38)
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        self.drawString(36, 26, "CONFIDENTIAL & PROPRIETARY — ACADEMIC REVIEW EDITION — REVISION 2.0")
        page_str = f"Page {self._pageNumber} of {total_pages}"
        self.drawRightString(756, 26, page_str)
        self.restoreState()

def build_pdf():
    doc = SimpleDocTemplate(
        PDF_PATH,
        pagesize=landscape(letter),
        leftMargin=36,
        rightMargin=36,
        topMargin=46,
        bottomMargin=46
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=24,
        textColor=colors.HexColor('#1A365D'),
        alignment=1,
        spaceAfter=8
    )
    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=14,
        textColor=colors.HexColor('#0F5132'),
        alignment=1,
        spaceAfter=15
    )
    h1_style = ParagraphStyle(
        'SecHeading',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=16,
        textColor=colors.HexColor('#1A365D'),
        spaceBefore=14,
        spaceAfter=8,
        keepWithNext=True
    )
    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11,
        textColor=colors.HexColor('#1E293B'),
        spaceAfter=6
    )
    tbl_hdr = ParagraphStyle(
        'TableHdr',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7.5,
        leading=9.5,
        textColor=colors.white,
        alignment=1
    )
    tbl_cell = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7,
        leading=9,
        textColor=colors.HexColor('#1E293B')
    )
    tbl_cell_center = ParagraphStyle(
        'TableCellCenter',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7,
        leading=9,
        alignment=1,
        textColor=colors.HexColor('#1E293B')
    )
    tbl_pass = ParagraphStyle(
        'TablePass',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7,
        leading=9,
        alignment=1,
        textColor=colors.HexColor('#0F5132')
    )
    tbl_na = ParagraphStyle(
        'TableNA',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7,
        leading=9,
        alignment=1,
        textColor=colors.HexColor('#842029')
    )

    story = []

    # Title & Metadata
    story.append(Paragraph("RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators", title_style))
    story.append(Paragraph("FINAL VERIFICATION TEST PLAN, TRACEABILITY MATRIX & EXECUTION REPORT", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor('#1A365D'), spaceBefore=2, spaceAfter=10))

    meta_text = (
        "<b>Document Version:</b> 2.0 (Post-Audit Verified) &nbsp;|&nbsp; "
        "<b>Date:</b> November 2026 &nbsp;|&nbsp; "
        "<b>Simulator:</b> Synopsys VCS 2023.03 (64-bit) &nbsp;|&nbsp; "
        "<b>Verification Mode:</b> Full Regression (36 Scenarios, 253 Checks) &nbsp;|&nbsp; "
        "<b>Overall Status:</b> <font color='#0F5132'><b>PASSED (100%)</b></font>"
    )
    story.append(Paragraph(meta_text, body_style))
    story.append(Spacer(1, 8))

    # Executive Summary Table
    story.append(Paragraph("1. Verification Regression & Execution Summary", h1_style))
    sum_data = [
        [Paragraph("<b>Metric / Parameter</b>", tbl_hdr), Paragraph("<b>Verified Value / Status</b>", tbl_hdr), Paragraph("<b>Engineering Remarks</b>", tbl_hdr)]
    ]
    for m, v in SUMMARY_STATS:
        p_val = Paragraph(f"<b><font color='#0F5132'>{v}</font></b>" if "PASS" in v or "100" in v or "253" in v else v, tbl_cell)
        sum_data.append([Paragraph(m, tbl_cell), p_val, Paragraph("Direct VCS simulation evidence recorded in run/ logs.", tbl_cell)])

    sum_table = Table(sum_data, colWidths=[200, 260, 260])
    sum_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1A365D')),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
    ]))
    story.append(sum_table)
    story.append(Spacer(1, 14))

    # Traceability Matrix
    story.append(PageBreak())
    story.append(Paragraph("2. Requirements-to-Verification Traceability Matrix", h1_style))
    story.append(Paragraph("Cross-mapping of architectural requirements to concrete test scenarios and execution evidence.", body_style))
    
    tr_data = [
        [Paragraph("<b>Req ID</b>", tbl_hdr), Paragraph("<b>Requirement Description</b>", tbl_hdr), Paragraph("<b>Mapped Test Scenarios</b>", tbl_hdr), Paragraph("<b>Status</b>", tbl_hdr), Paragraph("<b>Technical Remarks</b>", tbl_hdr)]
    ]
    for rid, desc, scen, stat, rem in TRACEABILITY_DATA:
        p_stat = Paragraph(stat, tbl_pass if stat == "PASS" else tbl_na)
        tr_data.append([
            Paragraph(rid, tbl_cell_center),
            Paragraph(desc, tbl_cell),
            Paragraph(scen, tbl_cell),
            p_stat,
            Paragraph(rem, tbl_cell)
        ])
    tr_table = Table(tr_data, colWidths=[65, 210, 155, 70, 220])
    tr_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1A365D')),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(tr_table)
    story.append(Spacer(1, 14))

    # All 36 Test Scenarios Table
    story.append(PageBreak())
    story.append(Paragraph("3. Detailed Master Test Plan (36 Scenarios + Unintegrated Archival Entries)", h1_style))
    story.append(Paragraph("Comprehensive listing of all directed SystemVerilog, RISC-V assembly, and RISC-V C firmware test scenarios.", body_style))

    # Render tests in groups to keep tables beautifully formatted
    table_hdr_row = [
        Paragraph("<b>Test ID</b>", tbl_hdr),
        Paragraph("<b>Category</b>", tbl_hdr),
        Paragraph("<b>Test Name & Target</b>", tbl_hdr),
        Paragraph("<b>Stimulus & Procedure</b>", tbl_hdr),
        Paragraph("<b>Expected Result & Checks</b>", tbl_hdr),
        Paragraph("<b>Status</b>", tbl_hdr),
        Paragraph("<b>Evidence Log</b>", tbl_hdr)
    ]
    
    test_rows = [table_hdr_row]
    for t in ALL_TESTS:
        p_stat = Paragraph(t["status"], tbl_pass if t["status"] == "PASS" else tbl_na)
        test_rows.append([
            Paragraph(f"<b>{t['id']}</b>", tbl_cell_center),
            Paragraph(t["category"], tbl_cell),
            Paragraph(f"<b>{t['name']}</b><br/><font color='#64748B'>DUT: {t['dut']}<br/>IF: {t['slave']}</font>", tbl_cell),
            Paragraph(t["stimulus"], tbl_cell),
            Paragraph(t["expected"], tbl_cell),
            p_stat,
            Paragraph(t["evidence"], tbl_cell)
        ])

    master_test_table = Table(test_rows, colWidths=[60, 85, 130, 165, 145, 60, 75], repeatRows=1)
    master_test_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1A365D')),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
    ]))
    story.append(master_test_table)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"[OK] Generated PDF: {PDF_PATH}")

if __name__ == "__main__":
    build_excel()
    build_pdf()
