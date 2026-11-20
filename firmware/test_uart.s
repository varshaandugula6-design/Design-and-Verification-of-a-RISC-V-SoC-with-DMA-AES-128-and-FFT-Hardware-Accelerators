// ==============================================================================
// test_uart.s: RISC-V Firmware for UART Verification (S4 / 0x8000_3000)
// Configures 115200 Baud Divisor (347), 8-N-1 frame, transmits byte via THR,
// polls LSR.THRE, and logs status to DMEM.
// ==============================================================================

    .org 0x00040000
    .globl _start

_start:
    li s0, 0x00080000       // s0 = DMEM base
    li s1, 0x80003000       // s1 = UART base

    // Step 1: Disable IER
    sw zero, 4(s1)          // UART_IER = 0

    // Step 2: Enable DLAB (LCR = 0x83)
    li t0, 0x83
    sw t0, 12(s1)           // UART_LCR = 0x83

    // Step 3: Set Baud Divisor (347 for 115200 baud @ 40 MHz)
    li t0, 347
    sw t0, 8(s1)            // UART_BAUD_DIV = 347

    // Step 4: Disable DLAB, configure 8-N-1 (LCR = 0x03)
    li t0, 0x03
    sw t0, 12(s1)           // UART_LCR = 0x03

    // Step 5: Read LSR, verify THRE (bit 5) = 1
    lw t1, 20(s1)           // Read UART_LSR
    sw t1, 0(s0)            // DMEM[0] = initial LSR

    // Step 6: Transmit character 'V' (0x56) to THR
    li t0, 0x56
    sw t0, 0(s1)            // UART_THR = 'V'

    // Step 7: Poll LSR until THRE (bit 5) is set
poll_thre:
    lw t1, 20(s1)           // Read UART_LSR
    andi t2, t1, 0x20       // Check bit 5 (THRE)
    beqz t2, poll_thre

    sw t1, 4(s0)            // DMEM[1] = LSR after TX

    // Completion signature
    li t0, 0x0A270001       // UART test pass signature
    sw t0, 8(s0)            // DMEM[2] = Signature

done:
    j done
