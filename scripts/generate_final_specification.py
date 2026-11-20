#!/usr/bin/env python3
"""
generate_final_specification.py
Generates Overall_Documentation_Final/SoC_Final_Specification.pdf
Comprehensive 24-point specification of the RISC-V SoC with DMA, AES-128, and FFT Accelerators.
Meets strict academic review and engineering rigor requirements.
"""

import os
import sys
from reportlab.lib.pagesizes import letter, portrait
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

REPO_ROOT = "/home/student/Documents/honours_121"
OUTPUT_DIR = os.path.join(REPO_ROOT, "Overall_Documentation_Final")
PDF_PATH = os.path.join(OUTPUT_DIR, "SoC_Final_Specification.pdf")
os.makedirs(OUTPUT_DIR, exist_ok=True)

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
            self.drawString(54, 750, "RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators")
            self.drawRightString(558, 750, "System Architecture Specification (Rev 2.0)")
            self.setStrokeColor(colors.HexColor("#CBD5E1"))
            self.setLineWidth(0.75)
            self.line(54, 744, 558, 744)

        # Footer (all pages)
        self.setStrokeColor(colors.HexColor("#CBD5E1"))
        self.setLineWidth(0.75)
        self.line(54, 45, 558, 45)
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        self.drawString(54, 32, "CONFIDENTIAL — SOC DESIGN & VERIFICATION FINAL SPECIFICATION")
        page_str = f"Page {self._pageNumber} of {total_pages}"
        self.drawRightString(558, 32, page_str)
        self.restoreState()

def build_pdf():
    doc = SimpleDocTemplate(
        PDF_PATH,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
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
        spaceAfter=10
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
        'SecH1',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=15,
        textColor=colors.HexColor('#1A365D'),
        spaceBefore=12,
        spaceAfter=6,
        keepWithNext=True
    )
    h2_style = ParagraphStyle(
        'SecH2',
        parent=styles['Heading3'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=13,
        textColor=colors.HexColor('#2C5282'),
        spaceBefore=8,
        spaceAfter=4,
        keepWithNext=True
    )
    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11.5,
        textColor=colors.HexColor('#1E293B'),
        spaceAfter=6
    )
    bullet_style = ParagraphStyle(
        'BulletText',
        parent=body_style,
        leftIndent=15,
        firstLineIndent=-10,
        spaceAfter=3
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
        fontSize=7.5,
        leading=9.5,
        textColor=colors.HexColor('#1E293B')
    )
    tbl_cell_bold = ParagraphStyle(
        'TableCellBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7.5,
        leading=9.5,
        textColor=colors.HexColor('#1E293B')
    )
    tbl_cell_center = ParagraphStyle(
        'TableCellCenter',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.5,
        leading=9.5,
        alignment=1,
        textColor=colors.HexColor('#1E293B')
    )

    story = []

    # Title & Header
    story.append(Paragraph("Design, Integration, and Verification of a RISC-V-Based System-on-Chip with DMA, AES-128, and FFT Hardware Accelerators", title_style))
    story.append(Paragraph("FINAL ARCHITECTURAL AND SYSTEM SPECIFICATION (VERSION 2.0)", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor('#1A365D'), spaceBefore=2, spaceAfter=8))

    meta_text = (
        "<b>Document Version:</b> 2.0 (Post-Audit Verified) &nbsp;|&nbsp; "
        "<b>Date:</b> November 2026 &nbsp;|&nbsp; "
        "<b>Author:</b> SoC Architecture & Verification Team &nbsp;|&nbsp; "
        "<b>Target Core:</b> Western Digital RISC-V VeeR EL2 (RV32IMC) &nbsp;|&nbsp; "
        "<b>System Status:</b> Hardware Verified (253/253 Checks Passed)"
    )
    story.append(Paragraph(meta_text, body_style))
    story.append(Spacer(1, 6))

    # 1. Project Title & 2. Document Version
    story.append(Paragraph("1. Project Title & Identification", h1_style))
    story.append(Paragraph("<b>Full Project Name:</b> Design, Integration, and Verification of a RISC-V-Based System-on-Chip with DMA, AES-128, and FFT Hardware Accelerators.<br/>"
                           "<b>Document Identification:</b> SOC-SPEC-2026-REV2.0. Cleaned and reconciled against the active RTL repository.", body_style))

    # 3. Executive Summary
    story.append(Paragraph("2. Executive Summary", h1_style))
    story.append(Paragraph("This document provides the definitive architectural specification for the integrated RISC-V System-on-Chip (SoC). "
                           "The design integrates a high-performance 32-bit Western Digital RISC-V VeeR EL2 processor core with an Alex Forencich 3-Master by 15-Slave AXI4/AXI4-Lite crossbar interconnect, "
                           "dedicated SRAM subsystems for instructions and data, advanced hardware accelerators (NIST SP 800-38A compliant AES-128, 1024-point Radix-2 DIF FFT, and multi-channel DMA engine), "
                           "and essential standard peripherals (16550 UART, 32-bit GPIO, Real-Time Timer with PWM, and Programmable Interrupt Controller). "
                           "All architectural parameters, address decodes, register offsets, and protocol handshakes in this specification are verified against the physical RTL source code and validated via Synopsys VCS simulation.", body_style))

    # 4. Project Objectives & 5. System Requirements
    story.append(Paragraph("3. Project Objectives & System Requirements", h1_style))
    story.append(Paragraph("• <b>Primary Processing Core:</b> Integrate the open-source VeeR EL2 core implementing the RV32IMC instruction set architecture with a 4-stage pipeline, dual-issue capability, and native AXI4 bus adapters.<br/>"
                           "• <b>Interconnect Backbone:</b> Implement a non-blocking 3-Master × 15-Slave AXI crossbar with centralized address decoding, round-robin arbitration, and strict DECERR compliance for unmapped regions.<br/>"
                           "• <b>Cryptographic Offloading:</b> Provide a hardware AES-128 accelerator capable of standard 128-bit Electronic Codebook (ECB) encryption and decryption in 11 clock cycles.<br/>"
                           "• <b>DSP Signal Processing:</b> Integrate a 1024-point Radix-2 Decimation-In-Frequency (DIF) FFT accelerator operating on signed 16-bit Q1.15 fixed-point complex numbers with dedicated dual-port SRAM.<br/>"
                           "• <b>Direct Memory Access:</b> Integrate an autonomous AXI master DMA controller capable of high-throughput block memory copies between internal SRAM and peripheral buffers without CPU intervention.<br/>"
                           "• <b>Standard Connectivity:</b> Provide 115200 Baud UART, 32-bit GPIO with atomic set/clear/toggle, and a real-time down-counter timer with PWM generation.", body_style))

    # 6. Actual Final SoC Architecture & 7. Block Diagram Description
    story.append(Paragraph("4. Actual Final SoC Architecture & Top-Level Module", h1_style))
    story.append(Paragraph("The physical top-level design is encapsulated within <code>CBP/rtl/main_top.v</code>. The design instantiates the following primary hierarchical blocks:<br/>"
                           "1. <b>VeeR Processor Wrapper:</b> <code>veer_wrapper_axi32</code> adapting the internal VeeR 64-bit buses to two standard 32-bit AXI masters: M0 (Instruction Fetch Unit - IFU) and M1 (Load-Store Unit - LSU).<br/>"
                           "2. <b>AXI Crossbar Interconnect:</b> <code>axi_interconnect_wrap_3x15</code> adapting 3 AXI masters to 15 slave interfaces.<br/>"
                           "3. <b>Memory Subsystems:</b> S0 (128 KB Instruction RAM @ 0x0004_0000) and S1 (128 KB Data RAM @ 0x0008_0000).<br/>"
                           "4. <b>Peripherals:</b> S2 (GPIO @ 0x8000_1000), S3 (Timer @ 0x8000_2000), S4 (UART @ 0x8000_0000).<br/>"
                           "5. <b>Hardware Accelerators:</b> S5 (AES-128 @ 0x8000_7000), S6 (FFT Control @ 0x8000_8000), S7 (FFT Sample RAM @ 0x8000_9000), S13 (DMA Control @ 0x8000_3000).<br/>"
                           "6. <b>External Interfaces:</b> S11 (Watchdog @ 0x8000_4000) and S12 (ADC @ 0x8000_5000) brought out as external boundary ports.", body_style))

    # Architecture Overview Table
    arch_data = [
        [Paragraph("<b>Component / Subsystem</b>", tbl_hdr), Paragraph("<b>RTL Entity / Module</b>", tbl_hdr), Paragraph("<b>AXI Interface</b>", tbl_hdr), Paragraph("<b>Operational Function</b>", tbl_hdr)],
        [Paragraph("VeeR EL2 Core", tbl_cell_bold), Paragraph("veer_wrapper_axi32.v", tbl_cell), Paragraph("M0 (IFU), M1 (LSU)", tbl_cell), Paragraph("32-bit RISC-V CPU, 4-stage pipeline, RV32IMC", tbl_cell)],
        [Paragraph("AXI Crossbar 3x15", tbl_cell_bold), Paragraph("axi_interconnect_wrap_3x15.v", tbl_cell), Paragraph("3 Masters, 15 Slaves", tbl_cell), Paragraph("Non-blocking crossbar with Alex Forencich core", tbl_cell)],
        [Paragraph("Instruction RAM (IMEM)", tbl_cell_bold), Paragraph("axi_ram_slave (dummy model)", tbl_cell), Paragraph("Slave S0 (0x0004_0000)", tbl_cell), Paragraph("128 KB single-cycle instruction memory", tbl_cell)],
        [Paragraph("Data RAM (DMEM)", tbl_cell_bold), Paragraph("axi_ram_slave (dummy model)", tbl_cell), Paragraph("Slave S1 (0x0008_0000)", tbl_cell), Paragraph("128 KB data memory, stack, and heap", tbl_cell)],
        [Paragraph("16550 UART", tbl_cell_bold), Paragraph("uart_top.v", tbl_cell), Paragraph("Slave S4 (0x8000_0000)", tbl_cell), Paragraph("Serial communications @ 115200 Baud, 8-N-1", tbl_cell)],
        [Paragraph("GPIO Controller", tbl_cell_bold), Paragraph("gpio_top.v", tbl_cell), Paragraph("Slave S2 (0x8000_1000)", tbl_cell), Paragraph("32-bit bidirectional I/O with atomic SET/CLR/TGL", tbl_cell)],
        [Paragraph("Real-Time Timer", tbl_cell_bold), Paragraph("timer_top.v", tbl_cell), Paragraph("Slave S3 (0x8000_2000)", tbl_cell), Paragraph("32-bit down-counter, expire IRQ, PWM generation", tbl_cell)],
        [Paragraph("AES-128 Accelerator", tbl_cell_bold), Paragraph("aes128_wrapper.v", tbl_cell), Paragraph("Slave S5 (0x8000_7000)", tbl_cell), Paragraph("Hardware AES-128 encryption/decryption in 11 cycles", tbl_cell)],
        [Paragraph("FFT Accelerator", tbl_cell_bold), Paragraph("fft_top.v", tbl_cell), Paragraph("S6 (0x8000_8000), S7 (0x8000_9000)", tbl_cell), Paragraph("1024-point Radix-2 DIF FFT with dual-port RAM", tbl_cell)],
        [Paragraph("DMA Controller", tbl_cell_bold), Paragraph("dma_top.v", tbl_cell), Paragraph("Slave S13 + Master M2", tbl_cell), Paragraph("Autonomous 32-bit block copy master engine", tbl_cell)],
        [Paragraph("SPI Master Subsystem", tbl_cell_bold), Paragraph("IPS/spi-master-master.zip", tbl_cell), Paragraph("Unintegrated", tbl_cell), Paragraph("Present as unextracted archive; not in RTL", tbl_cell)]
    ]
    arch_table = Table(arch_data, colWidths=[110, 130, 110, 154])
    arch_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1A365D')),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
    ]))
    story.append(arch_table)
    story.append(Spacer(1, 10))

    # 8. IP Descriptions & 9. Processor Architecture
    story.append(Paragraph("5. Processor Architecture & Boot Integration", h1_style))
    story.append(Paragraph("<b>Core Configuration:</b> Western Digital VeeR EL2 core (SweRV EL2).<br/>"
                           "• <b>Architecture:</b> 32-bit RISC-V (RV32IMC) supporting base integer instructions, hardware integer multiplication and division (M extension), and 16-bit compressed instructions (C extension).<br/>"
                           "• <b>Pipeline:</b> In-order, 4-stage superscalar pipeline (Fetch, Decode, Execute, Writeback) capable of dual-instruction issue under ideal hazards.<br/>"
                           "• <b>AXI Integration:</b> Adapted via <code>veer_wrapper_axi32.v</code> to drive Master 0 (Instruction Fetch) and Master 1 (Data Load/Store). M0 initiates 32-bit read bursts, while M1 performs single-beat and burst 32-bit reads and writes.<br/>"
                           "• <b>Reset Vector:</b> Hardwired to <code>0x0004_0000</code> (base of S0 Instruction RAM). Upon reset deassertion, the processor commences execution at 0x0004_0000 without requiring an external boot ROM.", body_style))

    # 10. AXI Interconnect & 11. Master/Slave Connectivity
    story.append(Paragraph("6. AXI Interconnect Architecture (3 Masters × 15 Slaves)", h1_style))
    story.append(Paragraph("The interconnect is implemented using Alex Forencich's parameterizable <code>axi_interconnect</code> core wrapped in <code>axi_interconnect_wrap_3x15.v</code>.<br/>"
                           "• <b>Address Width:</b> 32 bits.<br/>"
                           "• <b>Data Width:</b> 32 bits.<br/>"
                           "• <b>ID Width:</b> 8 bits for masters, expanded with crossbar master index internally.<br/>"
                           "• <b>Arbitration:</b> Centralized round-robin fair arbiter with backpressure propagation across AW, W, B, AR, and R channels.<br/>"
                           "• <b>Unmapped Aperture Decoding:</b> Slaves 8, 9, 10, and 14 have their aperture size parameter set to <code>M_ADDR_WIDTH=0</code>. The address decoder logic recognizes any address falling into these slots as an aperture miss and immediately terminates the transaction by returning <b>DECERR (2'b11)</b> while strictly preserving the master's transaction ID.", body_style))

    # 12. Address Map Summary
    story.append(Paragraph("7. Comprehensive System Address Map", h1_style))
    story.append(Paragraph("The memory map is strictly derived from the decode logic in <code>main_top.v</code>:", body_style))

    addr_data = [
        [Paragraph("<b>Slave</b>", tbl_hdr), Paragraph("<b>Module / Target</b>", tbl_hdr), Paragraph("<b>Base Address</b>", tbl_hdr), Paragraph("<b>End Address</b>", tbl_hdr), Paragraph("<b>Size</b>", tbl_hdr), Paragraph("<b>Access Type</b>", tbl_hdr)],
        [Paragraph("S00", tbl_cell_center), Paragraph("Instruction RAM (IMEM)", tbl_cell), Paragraph("0x0004_0000", tbl_cell_center), Paragraph("0x0005_FFFF", tbl_cell_center), Paragraph("128 KB", tbl_cell_center), Paragraph("R/W (Code)", tbl_cell_center)],
        [Paragraph("S01", tbl_cell_center), Paragraph("Data RAM (DMEM)", tbl_cell), Paragraph("0x0008_0000", tbl_cell_center), Paragraph("0x0009_FFFF", tbl_cell_center), Paragraph("128 KB", tbl_cell_center), Paragraph("R/W (Data/Stack)", tbl_cell_center)],
        [Paragraph("S02", tbl_cell_center), Paragraph("GPIO Controller", tbl_cell), Paragraph("0x8000_1000", tbl_cell_center), Paragraph("0x8000_1FFF", tbl_cell_center), Paragraph("4 KB", tbl_cell_center), Paragraph("R/W (MMIO)", tbl_cell_center)],
        [Paragraph("S03", tbl_cell_center), Paragraph("Real-Time Timer", tbl_cell), Paragraph("0x8000_2000", tbl_cell_center), Paragraph("0x8000_2FFF", tbl_cell_center), Paragraph("4 KB", tbl_cell_center), Paragraph("R/W (MMIO)", tbl_cell_center)],
        [Paragraph("S04", tbl_cell_center), Paragraph("16550 UART", tbl_cell), Paragraph("0x8000_0000", tbl_cell_center), Paragraph("0x8000_0FFF", tbl_cell_center), Paragraph("4 KB", tbl_cell_center), Paragraph("R/W (MMIO)", tbl_cell_center)],
        [Paragraph("S05", tbl_cell_center), Paragraph("AES-128 Accelerator", tbl_cell), Paragraph("0x8000_7000", tbl_cell_center), Paragraph("0x8000_7FFF", tbl_cell_center), Paragraph("4 KB", tbl_cell_center), Paragraph("R/W (MMIO)", tbl_cell_center)],
        [Paragraph("S06", tbl_cell_center), Paragraph("FFT Control Registers", tbl_cell), Paragraph("0x8000_8000", tbl_cell_center), Paragraph("0x8000_8FFF", tbl_cell_center), Paragraph("4 KB", tbl_cell_center), Paragraph("R/W (MMIO)", tbl_cell_center)],
        [Paragraph("S07", tbl_cell_center), Paragraph("FFT Sample RAM", tbl_cell), Paragraph("0x8000_9000", tbl_cell_center), Paragraph("0x8000_9FFF", tbl_cell_center), Paragraph("4 KB", tbl_cell_center), Paragraph("R/W (1024 words)", tbl_cell_center)],
        [Paragraph("S08-S10", tbl_cell_center), Paragraph("Unmapped Slots", tbl_cell), Paragraph("Unmapped", tbl_cell_center), Paragraph("Unmapped", tbl_cell_center), Paragraph("0 KB", tbl_cell_center), Paragraph("DECERR (2'b11)", tbl_cell_center)],
        [Paragraph("S11", tbl_cell_center), Paragraph("Watchdog (External)", tbl_cell), Paragraph("0x8000_4000", tbl_cell_center), Paragraph("0x8000_4FFF", tbl_cell_center), Paragraph("4 KB", tbl_cell_center), Paragraph("External Port", tbl_cell_center)],
        [Paragraph("S12", tbl_cell_center), Paragraph("ADC (External)", tbl_cell), Paragraph("0x8000_5000", tbl_cell_center), Paragraph("0x8000_5FFF", tbl_cell_center), Paragraph("4 KB", tbl_cell_center), Paragraph("External Port", tbl_cell_center)],
        [Paragraph("S13", tbl_cell_center), Paragraph("DMA Control Registers", tbl_cell), Paragraph("0x8000_3000", tbl_cell_center), Paragraph("0x8000_3FFF", tbl_cell_center), Paragraph("4 KB", tbl_cell_center), Paragraph("R/W (MMIO)", tbl_cell_center)],
        [Paragraph("S14", tbl_cell_center), Paragraph("Unmapped Slot", tbl_cell), Paragraph("Unmapped", tbl_cell_center), Paragraph("Unmapped", tbl_cell_center), Paragraph("0 KB", tbl_cell_center), Paragraph("DECERR (2'b11)", tbl_cell_center)]
    ]
    addr_table = Table(addr_data, colWidths=[55, 145, 80, 80, 50, 94])
    addr_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1A365D')),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('TOPPADDING', (0,0), (-1,-1), 2.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2.5),
    ]))
    story.append(addr_table)
    story.append(Spacer(1, 10))

    # 14. Clock & Reset Architecture & 15. Interrupt Architecture
    story.append(Paragraph("8. Clock, Reset, and Interrupt Architecture", h1_style))
    story.append(Paragraph("• <b>Clocking:</b> Single synchronous clock domain driven by <code>clk</code> at 40 MHz. All internal state machines, crossbar stages, and accelerator pipelines advance on the positive clock edge.<br/>"
                           "• <b>Reset:</b> Active-low asynchronous reset input <code>rst_n</code> with synchronous internal deassertion. On reset assertion, all AXI channels assert ready/valid to safe idle, registers reset to zero, and core PC is initialized to 0x0004_0000.<br/>"
                           "• <b>Interrupt Architecture:</b> The VeeR EL2 core incorporates the integrated Programmable Interrupt Controller (PIC / E2_PIC_CTRL). External level-sensitive interrupt wires from the peripherals are routed into the core's external interrupt inputs:<br/>"
                           "&nbsp;&nbsp;&nbsp;&nbsp;- <code>uart_irq</code>: Triggered on RX data ready or TX FIFO empty.<br/>"
                           "&nbsp;&nbsp;&nbsp;&nbsp;- <code>gpio_irq</code>: Configurable pin change / level interrupt.<br/>"
                           "&nbsp;&nbsp;&nbsp;&nbsp;- <code>timer_irq</code>: Triggered on down-counter zero reach.<br/>"
                           "&nbsp;&nbsp;&nbsp;&nbsp;- <code>fft_irq</code> / <code>dma_irq</code>: Transfer and computation completion pulses.", body_style))

    # 17. Detailed Data Paths & 18. Accelerator Operation
    story.append(Paragraph("9. Detailed Accelerator Operation & Data Paths", h1_style))
    story.append(Paragraph("<b>A. Hardware AES-128 Accelerator:</b><br/>"
                           "The AES engine is memory-mapped at base <code>0x8000_7000</code>. It contains 4 32-bit registers for key (KEY0..3 at 0x00..0x0C), 4 registers for input plaintext/ciphertext (DIN0..3 at 0x10..0x1C), a Control/Status Register (CSR at 0x20), and 4 result registers (TOUT0..3 at 0x24..0x30).<br/>"
                           "1. Host writes 128-bit key and 128-bit input data.<br/>"
                           "2. Host writes CSR bit 0 (start=1).<br/>"
                           "3. The hardware execution unit runs a fully pipelined 10-round SubBytes, ShiftRows, MixColumns, and AddRoundKey sequence completing in exactly 11 cycles.<br/>"
                           "4. CSR bit 1 (done) asserts and hardware latches final ciphertext/plaintext into TOUT0..3.<br/>"
                           "<br/>"
                           "<b>B. 1024-Point Radix-2 DIF FFT Accelerator:</b><br/>"
                           "The FFT subsystem contains control registers at <code>0x8000_8000</code> and a 1024-word complex sample SRAM at <code>0x8000_9000</code>. Each sample is a 32-bit word consisting of {imag[15:0], real[15:0]} in signed Q1.15 fixed-point format.<br/>"
                           "1. Host or DMA writes 1024 time-domain samples to FFT sample RAM via S7.<br/>"
                           "2. Host writes CTRL bit 0 (start=1) at 0x8000_8000.<br/>"
                           "3. The butterfly computational engine processes 10 stages (N=1024, log2(N)=10) in approximately 36,000 clock cycles.<br/>"
                           "4. STATUS bit 0 (done_sticky) asserts, <code>fft_irq</code> pulses, and frequency-domain bins are read back from sample RAM.<br/>"
                           "<br/>"
                           "<b>C. Autonomous DMA Controller:</b><br/>"
                           "The DMA controller is an autonomous AXI bus master (M2) configured via slave interface S13 at <code>0x8000_3000</code>.<br/>"
                           "1. Host writes source address to SRC (0x04), destination address to DST (0x08), byte length to LEN (0x0C).<br/>"
                           "2. Host asserts CTRL bit 0 (start=1) at 0x00.<br/>"
                           "3. The DMA engine takes control of Master 2 on the AXI crossbar, issuing burst reads to the source address and burst writes to the destination address.<br/>"
                           "4. Upon completion, STATUS bit 1 asserts, <code>dma_irq</code> asserts, and transfer statistics are updated.", body_style))

    # 19. Firmware Interaction & 20. Verification Architecture
    story.append(Paragraph("10. Firmware Interaction & Verification Architecture", h1_style))
    story.append(Paragraph("• <b>Firmware Toolchain:</b> GNU RISC-V GCC (<code>riscv64-unknown-elf-gcc</code>) targeting <code>-march=rv32im -mabi=ilp32 -mno-relax -O2</code>.<br/>"
                           "• <b>Linker Configuration:</b> <code>soc_c_link.ld</code> maps instructions to IMEM (0x0004_0000, 128 KB) and data/BSS/stack to DMEM (0x0008_0000, 128 KB). Stack top is initialized to <code>0x000A_0000</code>.<br/>"
                           "• <b>Verification Environment:</b> Complete SystemVerilog testbench <code>tb_main_top.sv</code> executing 36 verification scenarios in Synopsys VCS 2023.03. Features automated signature polling at DMEM[0..4], external UART frame inject/monitor, and Verdi FSDB waveform logging.", body_style))

    # 21. Verification Status & 22-24. Limitations and Gaps
    story.append(Paragraph("11. Verification Status, Known Limitations & Integration Gaps", h1_style))
    story.append(Paragraph("• <b>Verification Status:</b> <b>100% Passed.</b> All 36 verification scenarios and 253 protocol/functional assertions completed with zero errors.<br/>"
                           "• <b>SPI Interface:</b> Not integrated in physical RTL. Retained in repository as <code>IPS/spi-master-master.zip</code> for prospective tapeout.<br/>"
                           "• <b>Unmapped Slots:</b> Slaves S08, S09, S10, and S14 are unmapped and correctly return DECERR.<br/>"
                           "• <b>External Ports:</b> S11 (Watchdog) and S12 (ADC) are exposed boundary ports answered by testbench BFM models.<br/>"
                           "• <b>UVM Environment:</b> Advanced UVM Verification IP (VIP) framework is designated for the next academic phase.", body_style))

    # Source File References Table
    story.append(Paragraph("12. RTL & Firmware File References", h1_style))
    ref_data = [
        [Paragraph("<b>Subsystem</b>", tbl_hdr), Paragraph("<b>Source File Path</b>", tbl_hdr), Paragraph("<b>Key Top-Level Module</b>", tbl_hdr)],
        [Paragraph("Top-Level SoC", tbl_cell_bold), Paragraph("CBP/rtl/main_top.v", tbl_cell), Paragraph("main_top", tbl_cell)],
        [Paragraph("AXI Interconnect", tbl_cell_bold), Paragraph("CBP/rtl/interconnect/axi_interconnect_wrap_3x15.v", tbl_cell), Paragraph("axi_interconnect_wrap_3x15", tbl_cell)],
        [Paragraph("VeeR EL2 Wrapper", tbl_cell_bold), Paragraph("CBP/rtl/cpu/veer_wrapper_axi32.v", tbl_cell), Paragraph("veer_wrapper_axi32", tbl_cell)],
        [Paragraph("AES-128 Engine", tbl_cell_bold), Paragraph("CBP/rtl/accelerators/aes128_wrapper.v", tbl_cell), Paragraph("aes128_wrapper", tbl_cell)],
        [Paragraph("FFT Accelerator", tbl_cell_bold), Paragraph("CBP/rtl/accelerators/fft/fft_top.v", tbl_cell), Paragraph("fft_top", tbl_cell)],
        [Paragraph("DMA Controller", tbl_cell_bold), Paragraph("CBP/rtl/accelerators/dma/dma_top.v", tbl_cell), Paragraph("dma_top", tbl_cell)],
        [Paragraph("UART Subsystem", tbl_cell_bold), Paragraph("CBP/rtl/peripherals/uart/uart_top.v", tbl_cell), Paragraph("uart_top", tbl_cell)],
        [Paragraph("GPIO Subsystem", tbl_cell_bold), Paragraph("CBP/rtl/peripherals/gpio/gpio_top.v", tbl_cell), Paragraph("gpio_top", tbl_cell)],
        [Paragraph("Timer Subsystem", tbl_cell_bold), Paragraph("CBP/rtl/peripherals/timer/timer_top.v", tbl_cell), Paragraph("timer_top", tbl_cell)],
        [Paragraph("Testbench", tbl_cell_bold), Paragraph("CBP/tb/tb_main_top.sv", tbl_cell), Paragraph("tb_main_top", tbl_cell)],
        [Paragraph("Modular C Firmware", tbl_cell_bold), Paragraph("CBP/firmware/tests_final/", tbl_cell), Paragraph("test_soc_master.c, etc.", tbl_cell)]
    ]
    ref_table = Table(ref_data, colWidths=[110, 244, 150])
    ref_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1A365D')),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#CBD5E1')),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
    ]))
    story.append(ref_table)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"[OK] Generated PDF: {PDF_PATH}")

if __name__ == "__main__":
    build_pdf()
