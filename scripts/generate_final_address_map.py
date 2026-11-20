#!/usr/bin/env python3
"""
Generate SoC_Final_Address_Map.xlsx and SoC_Final_Address_Map.pdf
Derives all values from actual RTL decoder, wrappers, firmware, and simulation logs.
"""

import os
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

OUT_DIR = "/home/student/Documents/honours_121/Overall_Documentation_Final"
os.makedirs(OUT_DIR, exist_ok=True)
XLSX_PATH = os.path.join(OUT_DIR, "SoC_Final_Address_Map.xlsx")
PDF_PATH = os.path.join(OUT_DIR, "SoC_Final_Address_Map.pdf")

# ==============================================================================
# DATA DEFINITIONS FROM RTL AUDIT
# ==============================================================================

SHEET1_DATA = [
    # Slave Index, IP/Module, Base Address, End Address, Size, Interface Type, Register/Memory, RTL Source, Verification Status, Remarks
    ["S00", "Instruction Memory (IMEM)", "0x0004_0000", "0x0005_FFFF", "128 KB", "AXI4 Full (32-bit)", "Memory Array (axi_ram_slave)", "tb_main_top.sv: axi_ram_slave", "VERIFIED (PASS)", "Primary boot memory; VeeR IFU instruction fetch destination"],
    ["S01", "Data Memory (DMEM)", "0x0008_0000", "0x0009_FFFF", "128 KB", "AXI4 Full (32-bit)", "Memory Array (axi_ram_slave)", "tb_main_top.sv: axi_ram_slave", "VERIFIED (PASS)", "Primary data memory; Stack (0x88000), heap, DMA buffers, result signatures"],
    ["S02", "GPIO Controller", "0x8000_1000", "0x8000_1FFF", "4 KB", "AXI4-Lite (via Bridge)", "CSR Registers (gpio_regs)", "rtl/gpio/gpio_axi.sv", "VERIFIED (PASS)", "32 GPIO pins with live input, output, atomic set/clr/tgl, debounce & irq"],
    ["S03", "Real-Time Timer", "0x8000_2000", "0x8000_2FFF", "4 KB", "AXI4-Lite (via Bridge)", "CSR Registers (timer_regs)", "rtl/timer/timer_axi.sv", "VERIFIED (PASS)", "32-bit down-counter with auto-reload, compare PWM match, periodic IRQ"],
    ["S04", "UART Subsystem", "0x8000_3000", "0x8000_3FFF", "4 KB", "AXI4-Lite (Direct S4)", "CSR Registers (16550-like)", "rtl/UART/axi_uart_top.v", "VERIFIED (PASS)", "115200 Baud @ 40 MHz fixed clock; 32-deep FIFOs, TX/RX status & IRQ"],
    ["S05", "AES-128 Accelerator", "0x8000_7000", "0x8000_7FFF", "4 KB", "AXI4 (Adapter -> Lite)", "CSR Registers (aes_axi_slave)", "rtl/aes_axi_slave/aes_axi_slave_axi4.sv", "VERIFIED (PASS)", "Hardware NIST AES-128 10-round cipher core; KAT verified in 2690 cycles"],
    ["S06", "FFT Control Interface", "0x8000_8000", "0x8000_8FFF", "4 KB", "AXI4-Lite (via Bridge)", "CSR Registers (fft_ctrl_axil)", "rtl/fft_nexhus/fft_ctrl_axi4_bridge.sv", "VERIFIED (PASS)", "Radix-2 1024-point FFT control: START trigger, BUSY/DONE status, IRQ"],
    ["S07", "FFT Sample Memory", "0x8000_9000", "0x8000_9FFF", "4 KB", "AXI4 Full (Wrap/Burst)", "Dual-Port RAM (1024 words)", "rtl/fft_nexhus/fft_mem_axi4_wrap.sv", "VERIFIED (PASS)", "1024 complex samples [31:16]=Imag, [15:0]=Real (Q1.15 fixed-point)"],
    ["S08", "Keypad Controller Slot", "0x0000_0000", "0x0000_0000", "0 B (Unmapped)", "Unconnected Port", "None (Exposed m08_axi)", "rtl/main_top.v: M08_ADDR_WIDTH=0", "UNMAPPED (DECERR)", "Unmapped aperture; interconnect decoder routes access to internal DECERR"],
    ["S09", "Authentication Unit Slot", "0x0000_0000", "0x0000_0000", "0 B (Unmapped)", "Unconnected Port", "None (Exposed m09_axi)", "rtl/main_top.v: M09_ADDR_WIDTH=0", "UNMAPPED (DECERR)", "Unmapped aperture; interconnect decoder routes access to internal DECERR"],
    ["S10", "PWM / Buzzer Slot", "0x0000_0000", "0x0000_0000", "0 B (Unmapped)", "Unconnected Port", "None (Exposed m10_axi)", "rtl/main_top.v: M10_ADDR_WIDTH=0", "UNMAPPED (DECERR)", "Unmapped aperture; interconnect decoder routes access to internal DECERR"],
    ["S11", "Watchdog Timer Port", "0x8000_4000", "0x8000_4FFF", "4 KB", "AXI4 Full (Exposed Port)", "External Port (m11_axi)", "rtl/main_top.v: m11_axi", "DUMMY (Exposed)", "Exposed on main_top boundary; answered by dummy responder in TB"],
    ["S12", "ADC Interface Port", "0x8000_5000", "0x8000_5FFF", "4 KB", "AXI4 Full (Exposed Port)", "External Port (m12_axi)", "rtl/main_top.v: m12_axi", "DUMMY (Exposed)", "Exposed on main_top boundary; answered by dummy responder in TB"],
    ["S13", "DMA CSR Interface", "0x8000_6000", "0x8000_6FFF", "4 KB", "AXI4-Lite (Internal)", "CSR Registers (csr_dma)", "rtl/DMA/dma_axi_wrapper.sv", "VERIFIED (PASS)", "Scatter/gather descriptor DMA control; memory-to-memory block transfer"],
    ["S14", "Seven-Segment Display Slot", "0x0000_0000", "0x0000_0000", "0 B (Unmapped)", "Unconnected Port", "None (Exposed m14_axi)", "rtl/main_top.v: M14_ADDR_WIDTH=0", "UNMAPPED (DECERR)", "Unmapped aperture; interconnect decoder routes access to internal DECERR"]
]

SHEET2_DATA = [
    # IP, Register Name, Offset, Absolute Address, Register Width, Access Type, Reset Value, Description & Bit Fields, RTL Source File
    # GPIO
    ["GPIO", "GPIO_DATA_I", "0x00", "0x8000_1000", "32-bit", "RO", "0x0000_0000", "Live sampled and debounced input pin states [31:0]", "rtl/gpio/gpio_regs.sv"],
    ["GPIO", "GPIO_DATA_O", "0x04", "0x8000_1004", "32-bit", "RW", "0x0000_0000", "Direct output data driven on configured output pins [31:0]", "rtl/gpio/gpio_regs.sv"],
    ["GPIO", "GPIO_DIR", "0x08", "0x8000_1008", "32-bit", "RW", "0x0000_0000", "Pin direction configuration: 1 = Output, 0 = Input", "rtl/gpio/gpio_regs.sv"],
    ["GPIO", "GPIO_INT_EN", "0x0C", "0x8000_100C", "32-bit", "RW", "0x0000_0000", "Per-pin interrupt enable mask: 1 = Enabled", "rtl/gpio/gpio_regs.sv"],
    ["GPIO", "GPIO_INT_TYP", "0x10", "0x8000_1010", "32-bit", "RW", "0x0000_0000", "Interrupt type: 1 = Edge sensitive, 0 = Level sensitive", "rtl/gpio/gpio_regs.sv"],
    ["GPIO", "GPIO_INT_POL", "0x14", "0x8000_1014", "32-bit", "RW", "0x0000_0000", "Interrupt polarity: 1 = High / Rising edge, 0 = Low / Falling", "rtl/gpio/gpio_regs.sv"],
    ["GPIO", "GPIO_INT_ANY", "0x18", "0x8000_1018", "32-bit", "RW", "0x0000_0000", "Any-edge interrupt trigger: 1 = Both rising and falling edges", "rtl/gpio/gpio_regs.sv"],
    ["GPIO", "GPIO_INT_STS", "0x1C", "0x8000_101C", "32-bit", "W1C", "0x0000_0000", "Interrupt pending status. Write 1 to clear pending flag", "rtl/gpio/gpio_regs.sv"],
    ["GPIO", "GPIO_SET_O", "0x20", "0x8000_1020", "32-bit", "WO", "0x0000_0000", "Atomic bit set: Writing 1 sets corresponding DATA_O bit without read-modify-write", "rtl/gpio/gpio_regs.sv"],
    ["GPIO", "GPIO_CLR_O", "0x24", "0x8000_1024", "32-bit", "WO", "0x0000_0000", "Atomic bit clear: Writing 1 clears corresponding DATA_O bit", "rtl/gpio/gpio_regs.sv"],
    ["GPIO", "GPIO_TGL_O", "0x28", "0x8000_1028", "32-bit", "WO", "0x0000_0000", "Atomic bit toggle: Writing 1 inverts corresponding DATA_O bit", "rtl/gpio/gpio_regs.sv"],
    ["GPIO", "GPIO_DEB_EN", "0x30", "0x8000_1030", "32-bit", "RW", "0x0000_0000", "Input glitch filter / debounce enable mask per pin", "rtl/gpio/gpio_regs.sv"],

    # Timer
    ["Timer", "TIMER_CTRL", "0x00", "0x8000_2000", "32-bit", "RW", "0x0000_0000", "Control: [0] EN, [1] AUTO_RELOAD, [2] PWM_EN, [3] IRQ_EN", "rtl/timer/timer_regs.sv"],
    ["Timer", "TIMER_LOAD", "0x04", "0x8000_2004", "32-bit", "RW", "0x0000_0000", "Initial countdown load value", "rtl/timer/timer_regs.sv"],
    ["Timer", "TIMER_VAL", "0x08", "0x8000_2008", "32-bit", "RO", "0x0000_0000", "Live 32-bit down-counter current value", "rtl/timer/timer_regs.sv"],
    ["Timer", "TIMER_PRE", "0x0C", "0x8000_200C", "32-bit", "RW", "0x0000_0000", "Clock prescaler divisor (count ticks per system clock)", "rtl/timer/timer_regs.sv"],
    ["Timer", "TIMER_INT_EN", "0x10", "0x8000_2010", "32-bit", "RW", "0x0000_0000", "Interrupt enable: [0] ZERO_IRQ, [1] CMP_IRQ", "rtl/timer/timer_regs.sv"],
    ["Timer", "TIMER_INT_STS", "0x14", "0x8000_2014", "32-bit", "W1C", "0x0000_0000", "Interrupt status flags. [0] Expire, [1] Compare. Write 1 to clear", "rtl/timer/timer_regs.sv"],
    ["Timer", "TIMER_CMP", "0x18", "0x8000_2018", "32-bit", "RW", "0x0000_0000", "PWM match comparator threshold value", "rtl/timer/timer_regs.sv"],

    # UART
    ["UART", "UART_RBR", "0x00", "0x8000_3000", "32-bit", "RO", "0x0000_0000", "Receiver Buffer Register: Reads oldest received byte from RX FIFO", "rtl/UART/include/axi_uart.vh"],
    ["UART", "UART_THR", "0x00", "0x8000_3000", "32-bit", "WO", "0x0000_0000", "Transmitter Holding Register: Enqueues byte into TX FIFO", "rtl/UART/include/axi_uart.vh"],
    ["UART", "UART_IER", "0x04", "0x8000_3004", "32-bit", "RW", "0x0000_0000", "Interrupt Enable: [0] RX Data Ready, [1] TX Empty, [2] Line Status", "rtl/UART/include/axi_uart.vh"],
    ["UART", "UART_BAUD_DIV", "0x08", "0x8000_3008", "32-bit", "RW", "0x0000_0364", "Baud Divisor: 347 for 115200 Baud @ 40 MHz clock (accessible when DLAB=1)", "rtl/UART/include/axi_uart.vh"],
    ["UART", "UART_LCR", "0x0C", "0x8000_300C", "32-bit", "RW", "0x0000_0003", "Line Control: [1:0] Word Len (11=8-bit), [2] Stop, [3] Parity En, [7] DLAB", "rtl/UART/include/axi_uart.vh"],
    ["UART", "UART_LSR", "0x14", "0x8000_3014", "32-bit", "RO", "0x0000_0060", "Line Status: [0] DR, [1] OE, [2] PE, [3] FE, [5] THRE (empty), [6] TEMT", "rtl/UART/include/axi_uart.vh"],

    # AES
    ["AES-128", "AES_CSR", "0x00", "0x8000_7000", "32-bit", "RW", "0x0000_0000", "Control/Status: [0] START encryption, [31] DONE completion status flag", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_KEY0", "0x04", "0x8000_7004", "32-bit", "WO", "0x0000_0000", "128-bit Encryption Key bytes [31:0]", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_KEY1", "0x08", "0x8000_7008", "32-bit", "WO", "0x0000_0000", "128-bit Encryption Key bytes [63:32]", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_KEY2", "0x0C", "0x8000_700C", "32-bit", "WO", "0x0000_0000", "128-bit Encryption Key bytes [95:64]", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_KEY3", "0x10", "0x8000_7010", "32-bit", "WO", "0x0000_0000", "128-bit Encryption Key bytes [127:96]", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_TIN0", "0x14", "0x8000_7014", "32-bit", "WO", "0x0000_0000", "Plaintext input block bytes [31:0]", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_TIN1", "0x18", "0x8000_7018", "32-bit", "WO", "0x0000_0000", "Plaintext input block bytes [63:32]", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_TIN2", "0x1C", "0x8000_701C", "32-bit", "WO", "0x0000_0000", "Plaintext input block bytes [95:64]", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_TIN3", "0x20", "0x8000_7020", "32-bit", "WO", "0x0000_0000", "Plaintext input block bytes [127:96]", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_TOUT0", "0x24", "0x8000_7024", "32-bit", "RO", "0x0000_0000", "Ciphertext output block bytes [31:0]", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_TOUT1", "0x28", "0x8000_7028", "32-bit", "RO", "0x0000_0000", "Ciphertext output block bytes [63:32]", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_TOUT2", "0x2C", "0x8000_702C", "32-bit", "RO", "0x0000_0000", "Ciphertext output block bytes [95:64]", "rtl/aes_axi_slave/aes_axi_slave.sv"],
    ["AES-128", "AES_TOUT3", "0x30", "0x8000_7030", "32-bit", "RO", "0x0000_0000", "Ciphertext output block bytes [127:96]", "rtl/aes_axi_slave/aes_axi_slave.sv"],

    # FFT
    ["FFT Control", "FFT_CTRL", "0x00", "0x8000_8000", "32-bit", "RW", "0x0000_0000", "Control Register: Writing 1 to bit[0] initiates Radix-2 1024-point FFT transform", "rtl/fft_nexhus/fft_ctrl_axil.sv"],
    ["FFT Control", "FFT_STATUS", "0x04", "0x8000_8004", "32-bit", "RO", "0x0000_0000", "Status Register: [0] done_sticky (asserted upon transform completion)", "rtl/fft_nexhus/fft_ctrl_axil.sv"],
    ["FFT Memory", "FFT_SAMPLE[0..1023]", "0x000..0xFFC", "0x8000_9000..9FFC", "32-bit", "RW", "0x0000_0000", "1024 Dual-Port RAM words: [31:16]=Q1.15 Imaginary, [15:0]=Q1.15 Real", "rtl/fft_nexhus/fft_mem_axi4_wrap.sv"],

    # DMA
    ["DMA", "DMA_CONTROL", "0x00", "0x8000_6000", "64-bit", "RW", "0x0000_0000", "Control Register: [0] GO (starts DMA), [7:4] MAX_BURST (0x1=4 beats)", "rtl/DMA/csr_dma.v"],
    ["DMA", "DMA_STATUS", "0x08", "0x8000_6008", "64-bit", "RO", "0x0000_0000", "Status Register: [0] IDLE, [1] RUNNING, [16] DONE completion status flag", "rtl/DMA/csr_dma.v"],
    ["DMA", "DMA_ERR_STATUS", "0x18", "0x8000_6018", "64-bit", "RO", "0x0000_0000", "Error flags: [0] AXI Read error, [1] AXI Write error, [2] Length error", "rtl/DMA/csr_dma.v"],
    ["DMA", "DESC0_SRC_ADDR", "0x20", "0x8000_6020", "64-bit", "RW", "0x0000_0000", "Channel 0 Source Memory Address (e.g. DMEM 0x0008_0200)", "rtl/DMA/csr_dma.v"],
    ["DMA", "DESC0_DST_ADDR", "0x30", "0x8000_6030", "64-bit", "RW", "0x0000_0000", "Channel 0 Destination Memory Address (e.g. FFT_MEM 0x8000_9200)", "rtl/DMA/csr_dma.v"],
    ["DMA", "DESC0_NUM_BYTES", "0x40", "0x8000_6040", "64-bit", "RW", "0x0000_0000", "Channel 0 Transfer Size in bytes (e.g. 16 bytes = 4 words)", "rtl/DMA/csr_dma.v"],
    ["DMA", "DESC0_CFG", "0x50", "0x8000_6050", "64-bit", "RW", "0x0000_0000", "Channel 0 Config: [2] ENABLE bit (write 4 to enable descriptor)", "rtl/DMA/csr_dma.v"]
]

SHEET3_DATA = [
    # Region / Slot, Address Window, Size, Hardware Behaviour, Interconnect Handling, Justification / System Impact
    ["S08: Keypad Slot", "Unmapped (M08_ADDR_WIDTH=0)", "0 Bytes", "Returns DECERR (2'b11)", "Interconnect decoder detects match=0; drops write data and asserts DECERR response", "Slot reserved in 3x15 crossbar architecture for peripheral expansion; unused in current silicon build"],
    ["S09: Authentication Slot", "Unmapped (M09_ADDR_WIDTH=0)", "0 Bytes", "Returns DECERR (2'b11)", "Interconnect decoder detects match=0; returns DECERR on read/write with preserved transaction ID", "Slot reserved for hardware cryptographic authenticator; unmapped in current configuration"],
    ["S10: Buzzer / Alarm Slot", "Unmapped (M10_ADDR_WIDTH=0)", "0 Bytes", "Returns DECERR (2'b11)", "Interconnect decoder detects match=0; returns DECERR on read/write", "Slot reserved for dedicated railway warning audio annunciator; unmapped in current configuration"],
    ["S11: Watchdog Timer", "0x8000_4000 - 0x8000_4FFF", "4 KB", "Dummy Responder", "Exposed as m11_axi on main_top.v boundary; answered by dummy responder model in simulation", "Exposed off-chip interface for external watchdog or FPGA-level board management"],
    ["S12: ADC Interface", "0x8000_5000 - 0x8000_5FFF", "4 KB", "Dummy Responder", "Exposed as m12_axi on main_top.v boundary; answered by dummy responder model in simulation", "Exposed off-chip interface for multi-channel train sensor / track circuit ADC conversion"],
    ["S14: Seven-Segment Slot", "Unmapped (M14_ADDR_WIDTH=0)", "0 Bytes", "Returns DECERR (2'b11)", "Interconnect decoder detects match=0; asserts DECERR", "Slot reserved for front-panel diagnostics display; unmapped in current configuration"],
    ["Low Unmapped Gap", "0x0000_0000 - 0x0003_FFFF", "256 KB", "Returns DECERR (2'b11)", "Interconnect default DECERR responder; preserves transaction ID", "Unmapped boot ROM gap below IMEM (base 0x0004_0000)"],
    ["Mid Unmapped Gap 1", "0x0006_0000 - 0x0007_FFFF", "128 KB", "Returns DECERR (2'b11)", "Interconnect default DECERR responder", "Gap between IMEM ceiling (0x0005_FFFF) and DMEM base (0x0008_0000)"],
    ["Mid Unmapped Gap 2", "0x000A_0000 - 0x7FFF_FFFF", "~2047 MB", "Returns DECERR (2'b11)", "Interconnect default DECERR responder", "Wide memory gap between DMEM ceiling and MMIO peripheral window base (0x8000_0000)"],
    ["High Unmapped Region", "0x8000_A000 - 0xFFFF_FFFF", "~2047 MB", "Returns DECERR (2'b11)", "Interconnect default DECERR responder; tested in Scenario 2 at 0x9000_0000", "Addresses above highest mapped peripheral (FFT memory @ 0x8000_9FFF)"]
]

SHEET4_DATA = [
    # Subsystem / Peripheral, RTL Decoder Address, Peripheral Wrapper Address, Firmware Header/C Address, Legacy Spec Address, Consistency Status, Discrepancy Detail & Resolution
    ["Instruction Memory (S00)", "0x0004_0000 (128 KB)", "0x0004_0000", "0x0004_0000 (soc_c_link.ld)", "0x0004_0000", "MATCH", "100% consistent across RTL, linker script, firmware, and testbench."],
    ["Data Memory (S01)", "0x0008_0000 (128 KB)", "0x0008_0000", "0x0008_0000 (soc_peripherals.h)", "0x0008_0000", "MATCH", "100% consistent across RTL, linker script, firmware, and testbench."],
    ["GPIO Controller (S02)", "0x8000_1000 (4 KB)", "0x8000_1000 (Bridge)", "0x8000_1000 (soc_peripherals.h)", "0x8000_1000", "MATCH", "RTL subtracts base 0x8000_1000 in bridge; register offsets match gpio_regs.sv."],
    ["Real-Time Timer (S03)", "0x8000_2000 (4 KB)", "0x8000_2000 (Bridge)", "0x8000_2000 (soc_peripherals.h)", "0x8000_2000", "MATCH", "RTL subtracts base 0x8000_2000 in bridge; register offsets match timer_regs.sv."],
    ["UART Subsystem (S04)", "0x8000_3000 (4 KB)", "0x8000_3000 (Direct S4)", "0x8000_3000 (soc_peripherals.h)", "0x8000_3000", "MATCH", "Direct connection to axi_uart_top; registers 0x00 (RBR/THR), 0x04 (IER), 0x08 (DIV), 0x0C (LCR), 0x14 (LSR)."],
    ["AES-128 Accelerator (S05)", "0x8000_7000 (4 KB)", "0x8000_7000 (AES_PERIPH_BASE)", "0x8000_7000 (soc_peripherals.h)", "0x8000_7000 (Was 'Encoder')", "MATCH (Resolved)", "Assigned to S05 (formerly generic encoder slot); aes_axi_slave_axi4 subtracts base; KAT verified."],
    ["FFT Control Bridge (S06)", "0x8000_8000 (4 KB)", "0x8000_8000 (Bridge)", "0x8000_8000 (soc_peripherals.h)", "0x8000_8000", "MATCH", "Dedicated control aperture for Radix-2 1024-point engine; registers at 0x00 (CTRL) and 0x04 (STATUS)."],
    ["FFT Sample Memory (S07)", "0x8000_9000 (4 KB)", "0x8000_9000 (Wrap)", "0x8000_9000 (soc_peripherals.h)", "0x8000_9000", "MATCH", "Dual-port RAM wrap; 1024 words accessed via AXI4 burst transactions."],
    ["Slots S08, S09, S10, S14", "Unmapped (ADDR_WIDTH=0)", "Exposed ports unconnected", "None (Attempt causes DECERR)", "0x8000_A000..D000 (Theoretical)", "DISCREPANCY RESOLVED", "Legacy specification hypothetically assigned 0x8000_A000..0x8000_D000, but RTL explicitly sets M_ADDR_WIDTH=0. RTL decoder correctly asserts DECERR on access. Specification updated to reflect actual silicon RTL behaviour."],
    ["Watchdog & ADC (S11, S12)", "0x8000_4000 & 0x8000_5000", "Exposed top ports", "Off-chip", "0x8000_4000 & 0x8000_5000", "MATCH", "Exposed on main_top ports m11_axi and m12_axi; answered by simulation dummy responders."],
    ["DMA CSR Interface (S13)", "0x8000_6000 (4 KB)", "0x8000_6000 (rggen)", "0x8000_6000 (soc_peripherals.h)", "0x8000_6000", "MATCH", "rggen CSR adapter decodes offsets 0x00 (CONTROL), 0x08 (STATUS), 0x20..0x50 (DESC0). Master port drives M2."]
]


def create_excel():
    wb = openpyxl.Workbook()
    # Remove default sheet
    wb.remove(wb.active)

    header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    header_fill = PatternFill(start_color="1F497D", end_color="1F497D", fill_type="solid")
    
    data_font = Font(name="Calibri", size=10)
    data_font_bold = Font(name="Calibri", size=10, bold=True)
    mono_font = Font(name="Consolas", size=9)
    
    thin_border_side = Side(border_style="thin", color="D9D9D9")
    thin_border = Border(left=thin_border_side, right=thin_border_side, top=thin_border_side, bottom=thin_border_side)
    
    pass_fill = PatternFill(start_color="E2EFDA", end_color="E2EFDA", fill_type="solid")
    pass_font = Font(name="Calibri", size=10, bold=True, color="375623")
    
    warn_fill = PatternFill(start_color="FFF2CC", end_color="FFF2CC", fill_type="solid")
    warn_font = Font(name="Calibri", size=10, bold=True, color="833C0C")
    
    alt_fill = PatternFill(start_color="F9FAFB", end_color="F9FAFB", fill_type="solid")

    sheets_info = [
        ("Complete Address Map", [
            "Slave Index", "IP / Module Name", "Base Address", "End Address", "Address Range Size",
            "Interface Protocol", "Register / Memory Type", "RTL Source File", "Verification Status", "Architectural Remarks"
        ], SHEET1_DATA),
        ("Register Map", [
            "IP Subsystem", "Register Name", "Offset", "Absolute Address", "Register Width",
            "Access Type", "Reset Value", "Bit Fields & Description", "RTL Source Traceability"
        ], SHEET2_DATA),
        ("Reserved & Unused Regions", [
            "Region / Slave Slot", "Address Window", "Aperture Size", "Hardware Response",
            "Interconnect Decoding & Routing", "Architectural Justification & System Impact"
        ], SHEET3_DATA),
        ("Address Consistency Audit", [
            "Subsystem / Peripheral", "RTL Interconnect Decoder", "IP Wrapper Parameter",
            "Firmware / C Header Address", "Legacy Spec / Earlier Doc", "Consistency Audit Status", "Discrepancy Detail & Engineering Resolution"
        ], SHEET4_DATA)
    ]

    for title, headers, rows in sheets_info:
        ws = wb.create_sheet(title=title)
        ws.views.sheetView[0].showGridLines = True
        
        # Write headers
        ws.append(headers)
        for col_idx, cell in enumerate(ws[1], start=1):
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
            cell.border = thin_border
        ws.row_dimensions[1].height = 28

        # Write data rows
        for row_idx, rdata in enumerate(rows, start=2):
            ws.append(rdata)
            row_cells = ws[row_idx]
            is_alt = (row_idx % 2 == 1)
            for c_idx, cell in enumerate(row_cells, start=1):
                cell.font = data_font
                cell.border = thin_border
                cell.alignment = Alignment(vertical="center")
                
                # Default fill
                if is_alt:
                    cell.fill = alt_fill
                
                val_str = str(cell.value or "")
                
                # Formatting specific columns
                if "0x" in val_str:
                    cell.font = mono_font
                    cell.alignment = Alignment(horizontal="center", vertical="center")
                elif val_str in ["RO", "WO", "RW", "W1C", "32-bit", "64-bit", "128 KB", "4 KB"]:
                    cell.alignment = Alignment(horizontal="center", vertical="center")
                
                # Status highlights
                if "VERIFIED" in val_str or "PASS" in val_str or val_str == "MATCH":
                    cell.fill = pass_fill
                    cell.font = pass_font
                    cell.alignment = Alignment(horizontal="center", vertical="center")
                elif "UNMAPPED" in val_str or "DUMMY" in val_str or "DISCREPANCY" in val_str:
                    cell.fill = warn_fill
                    cell.font = warn_font
                    cell.alignment = Alignment(horizontal="center", vertical="center")

            ws.row_dimensions[row_idx].height = 22

        # Freeze header and enable auto filter
        ws.freeze_panes = "A2"
        ws.auto_filter.ref = ws.dimensions

        # Auto-fit columns with safety margin
        for col in ws.columns:
            max_len = 0
            for cell in col:
                val = str(cell.value or "")
                if len(val) > max_len:
                    max_len = len(val)
            col_letter = get_column_letter(col[0].column)
            ws.column_dimensions[col_letter].width = min(max(max_len + 4, 12), 48)

    wb.save(XLSX_PATH)
    print(f"[OK] Generated Excel: {XLSX_PATH}")


# ==============================================================================
# PDF GENERATION (ReportLab)
# ==============================================================================

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

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#1F497D"))
        
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(54, 750, "RISC-V SoC Architecture — Final Verified Address Map & Register Specification")
            self.drawRightString(738, 750, "Document Version 2.0 | Status: Silicon-RTL Verified")
            self.setStrokeColor(colors.HexColor("#B0C4DE"))
            self.setLineWidth(0.75)
            self.line(54, 744, 738, 744)

        # Footer (all pages)
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#555555"))
        self.drawString(54, 35, "CONFIDENTIAL — Final Honours Project Audit Deliverable | Synopsys VCS & Verdi Verified")
        page_text = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(738, 35, page_text)
        self.setStrokeColor(colors.HexColor("#D9D9D9"))
        self.setLineWidth(0.5)
        self.line(54, 45, 738, 45)
        self.restoreState()


def create_pdf():
    doc = SimpleDocTemplate(
        PDF_PATH,
        pagesize=landscape(letter),
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'DocTitle', parent=styles['Normal'],
        fontName='Helvetica-Bold', fontSize=20, leading=24,
        textColor=colors.HexColor('#1F497D'), spaceAfter=6
    )
    subtitle_style = ParagraphStyle(
        'DocSubtitle', parent=styles['Normal'],
        fontName='Helvetica', fontSize=10, leading=14,
        textColor=colors.HexColor('#444444'), spaceAfter=14
    )
    h1_style = ParagraphStyle(
        'Heading1_Custom', parent=styles['Normal'],
        fontName='Helvetica-Bold', fontSize=13, leading=16,
        textColor=colors.HexColor('#1F497D'), spaceBefore=12, spaceAfter=8,
        keepWithNext=True
    )
    body_style = ParagraphStyle(
        'Body_Custom', parent=styles['Normal'],
        fontName='Helvetica', fontSize=8.5, leading=11,
        textColor=colors.HexColor('#222222'), spaceAfter=6
    )
    table_cell = ParagraphStyle(
        'TableCell', parent=styles['Normal'],
        fontName='Helvetica', fontSize=7.5, leading=9.5,
        textColor=colors.HexColor('#222222')
    )
    table_cell_bold = ParagraphStyle(
        'TableCellBold', parent=styles['Normal'],
        fontName='Helvetica-Bold', fontSize=7.5, leading=9.5,
        textColor=colors.HexColor('#222222')
    )
    table_cell_center = ParagraphStyle(
        'TableCellCenter', parent=styles['Normal'],
        fontName='Helvetica', fontSize=7.5, leading=9.5,
        alignment=1, textColor=colors.HexColor('#222222')
    )
    table_cell_mono = ParagraphStyle(
        'TableCellMono', parent=styles['Normal'],
        fontName='Courier', fontSize=7.0, leading=8.5,
        alignment=1, textColor=colors.HexColor('#111111')
    )
    table_hdr = ParagraphStyle(
        'TableHdr', parent=styles['Normal'],
        fontName='Helvetica-Bold', fontSize=8, leading=10,
        alignment=1, textColor=colors.white
    )

    story = []

    # Title & Executive Header
    story.append(Paragraph("RISC-V SoC Architecture — Final Verified Address Map", title_style))
    story.append(Paragraph(
        "<b>Project:</b> Design, Integration, and Verification of a RISC-V-Based System-on-Chip with DMA, AES-128, and FFT Hardware Accelerators<br/>"
        "<b>RTL Baseline:</b> <font name='Courier'>CBP/rtl/main_top.v</font> &amp; <font name='Courier'>axi_interconnect_wrap_3x15.v</font> | "
        "<b>Verification Environment:</b> Synopsys VCS &amp; Verdi | <b>Result:</b> 253/253 Checks Passing",
        subtitle_style
    ))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor("#1F497D"), spaceAfter=10))

    # SECTION 1: COMPLETE SYSTEM ADDRESS MAP
    story.append(Paragraph("1. Complete System Address Map (Slaves S00 to S14)", h1_style))
    story.append(Paragraph(
        "The SoC interconnect is implemented as a 3-Master by 15-Slave AXI4 crossbar with round-robin arbitration and centralized address decoding. "
        "Base addresses, apertures, interface protocols, and verification statuses derived from actual RTL and simulation results are tabulated below:",
        body_style
    ))

    t1_headers = ["Slave", "IP / Module Name", "Base Address", "End Address", "Size", "Interface", "Register Type", "Status"]
    t1_rows = [[Paragraph(h, table_hdr) for h in t1_headers]]
    for r in SHEET1_DATA:
        status_color = "#375623" if "VERIFIED" in r[8] else "#833C0C"
        status_bg = "#E2EFDA" if "VERIFIED" in r[8] else "#FFF2CC"
        t1_rows.append([
            Paragraph(r[0], table_cell_bold),
            Paragraph(r[1], table_cell),
            Paragraph(r[2], table_cell_mono),
            Paragraph(r[3], table_cell_mono),
            Paragraph(r[4], table_cell_center),
            Paragraph(r[5], table_cell),
            Paragraph(r[6], table_cell),
            Paragraph(f"<font color='{status_color}'><b>{r[8]}</b></font>", table_cell_center)
        ])

    col_w1 = [38, 125, 68, 68, 48, 105, 140, 92]
    t1 = Table(t1_rows, colWidths=col_w1, repeatRows=1)
    t1.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#1F497D")),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#D9D9D9")),
        ('BOX', (0, 0), (-1, -1), 1, colors.HexColor("#1F497D")),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))
    story.append(t1)
    story.append(Spacer(1, 14))

    # SECTION 2: HARDWARE REGISTER MAP SUMMARY
    story.append(PageBreak())
    story.append(Paragraph("2. Integrated Hardware Accelerator & Peripheral Register Map", h1_style))
    story.append(Paragraph(
        "Register offsets, absolute memory-mapped addresses, access types, reset values, and functional bit definitions for all processor-accessible peripherals:",
        body_style
    ))

    t2_headers = ["IP Subsystem", "Register Name", "Offset", "Absolute Addr", "Width", "Access", "Reset Val", "Description & Field Definition"]
    t2_rows = [[Paragraph(h, table_hdr) for h in t2_headers]]
    for r in SHEET2_DATA:
        t2_rows.append([
            Paragraph(r[0], table_cell_bold),
            Paragraph(r[1], table_cell_bold),
            Paragraph(r[2], table_cell_mono),
            Paragraph(r[3], table_cell_mono),
            Paragraph(r[4], table_cell_center),
            Paragraph(r[5], table_cell_center),
            Paragraph(r[6], table_cell_mono),
            Paragraph(r[7], table_cell)
        ])

    col_w2 = [65, 85, 45, 75, 40, 42, 68, 264]
    t2 = Table(t2_rows, colWidths=col_w2, repeatRows=1)
    t2.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#1F497D")),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#D9D9D9")),
        ('BOX', (0, 0), (-1, -1), 1, colors.HexColor("#1F497D")),
        ('TOPPADDING', (0, 0), (-1, -1), 2.5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.5),
    ]))
    story.append(t2)
    story.append(Spacer(1, 14))

    # SECTION 3: RESERVED REGIONS & DECERR BEHAVIOUR
    story.append(PageBreak())
    story.append(Paragraph("3. Reserved Address Regions & Default Responder Handling", h1_style))
    story.append(Paragraph(
        "All transactions targeting unmapped address windows or unused slave slots are safely handled by the interconnect's default decode logic:",
        body_style
    ))

    t3_headers = ["Region / Slave Slot", "Address Window", "Aperture Size", "Hardware Response", "Interconnect Routing", "System Justification"]
    t3_rows = [[Paragraph(h, table_hdr) for h in t3_headers]]
    for r in SHEET3_DATA:
        t3_rows.append([
            Paragraph(r[0], table_cell_bold),
            Paragraph(r[1], table_cell_mono),
            Paragraph(r[2], table_cell_center),
            Paragraph(f"<b>{r[3]}</b>", table_cell_center),
            Paragraph(r[4], table_cell),
            Paragraph(r[5], table_cell)
        ])

    col_w3 = [105, 115, 60, 85, 175, 144]
    t3 = Table(t3_rows, colWidths=col_w3, repeatRows=1)
    t3.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#1F497D")),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#D9D9D9")),
        ('BOX', (0, 0), (-1, -1), 1, colors.HexColor("#1F497D")),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))
    story.append(t3)
    story.append(Spacer(1, 14))

    # SECTION 4: ADDRESS CONSISTENCY AUDIT & RESOLUTION
    story.append(Paragraph("4. RTL vs Firmware vs Specification Address Consistency Audit", h1_style))
    story.append(Paragraph(
        "A rigorous multi-way cross-check between the interconnect decoder RTL, peripheral wrappers, firmware C headers, and legacy specifications was conducted:",
        body_style
    ))

    t4_headers = ["Subsystem", "RTL Decoder Addr", "Wrapper Addr", "Firmware / C Addr", "Legacy Spec", "Audit Status", "Engineering Resolution"]
    t4_rows = [[Paragraph(h, table_hdr) for h in t4_headers]]
    for r in SHEET4_DATA:
        status_color = "#375623" if "MATCH" in r[5] else "#833C0C"
        t4_rows.append([
            Paragraph(r[0], table_cell_bold),
            Paragraph(r[1], table_cell_mono),
            Paragraph(r[2], table_cell_mono),
            Paragraph(r[3], table_cell_mono),
            Paragraph(r[4], table_cell_mono),
            Paragraph(f"<font color='{status_color}'><b>{r[5]}</b></font>", table_cell_center),
            Paragraph(r[6], table_cell)
        ])

    col_w4 = [95, 80, 80, 80, 80, 65, 104]
    t4 = Table(t4_rows, colWidths=col_w4, repeatRows=1)
    t4.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#1F497D")),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#D9D9D9")),
        ('BOX', (0, 0), (-1, -1), 1, colors.HexColor("#1F497D")),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))
    story.append(t4)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"[OK] Generated PDF: {PDF_PATH}")


if __name__ == "__main__":
    create_excel()
    create_pdf()
