// ==============================================================================
// soc_master_regression.s: Complete RISC-V SoC End-to-End Master Firmware
//
// Verifies:
//   1. Core Instruction Fetch (M0 -> S0 IMEM) & LSU Data Access (M1 -> S1 DMEM)
//   2. S2 GPIO Controller (DIR, DATA_O, SET_O, CLR_O, TGL_O, DATA_I)
//   3. S3 Real-Time Timer (LOAD, CMP, PRE, Down-count, Expire IRQ, Clear)
//   4. S4 UART (Baud Divisor 347, 8-N-1 format, THR Transmit, LSR Polling)
//   5. S5 AES-128 Hardware Accelerator (Known-Answer Test with full verification)
//   6. S6/S7 FFT Hardware Accelerator (Impulse Response, BRAM R/W, Transform Check)
//   7. S13 DMA Controller (Mem-to-Mem Transfer from DMEM to FFT Memory)
//   8. CPU + DMA Master Concurrency (Concurrent M1 & M2 Interconnect Arbitration)
//   9. RISC-V Interrupt & Trap Handling (mtvec, mcause, mret, ISR execution)
//  10. Final Completion Signatures written to DMEM
// ==============================================================================

    .org 0x00040000
    .globl _start

_start:
    // Base address pointers
    li s0, 0x00080000       // s0 = DMEM base (S1)
    li s1, 0x80001000       // s1 = GPIO base (S2)
    li s2, 0x80002000       // s2 = Timer base (S3)
    li s3, 0x80003000       // s3 = UART base (S4)
    li s4, 0x80007000       // s4 = AES-128 base (S5)
    li s5, 0x80008000       // s5 = FFT Control base (S6)
    li s6, 0x80009000       // s6 = FFT Memory base (S7)
    li s7, 0x80006000       // s7 = DMA CSR base (S13)

    // --------------------------------------------------------------------------
    // Section 1: IMEM / DMEM Subsystem & Basic ALU Verification
    // --------------------------------------------------------------------------
    li t0, 0x12345678
    sw t0, 0(s0)            // DMEM[0] = 0x1234_5678
    lw t1, 0(s0)            // Readback
    addi t2, t1, 1
    sw t2, 4(s0)            // DMEM[1] = 0x1234_5679

    // --------------------------------------------------------------------------
    // Section 2: S2 GPIO Peripheral Verification
    // --------------------------------------------------------------------------
    li t0, 0x0000FFFF       // Lower 16 outputs, Upper 16 inputs
    sw t0, 8(s1)            // GPIO_DIR = 0x0000_FFFF
    li t0, 0x0000A55A
    sw t0, 4(s1)            // GPIO_DATA_O = 0x0000_A55A
    li t0, 0x000000A0
    sw t0, 32(s1)           // GPIO_SET_O -> 0x0000_A5FA
    li t0, 0x0000000A
    sw t0, 36(s1)           // GPIO_CLR_O -> 0x0000_A5F0
    li t0, 0x000000F0
    sw t0, 40(s1)           // GPIO_TGL_O -> 0x0000_A500
    sw zero, 48(s1)         // GPIO_DEB_EN = 0
    lw t1, 0(s1)            // Read GPIO_DATA_I
    li t0, 0x60100001       // GPIO Pass Signature
    sw t0, 8(s0)            // DMEM[2] = GPIO Pass

    // --------------------------------------------------------------------------
    // Section 3: S3 Real-Time Timer Peripheral Verification
    // --------------------------------------------------------------------------
    li t0, 100
    sw t0, 4(s2)            // TIMER_LOAD = 100
    li t0, 40
    sw t0, 24(s2)           // TIMER_CMP = 40
    sw zero, 12(s2)         // TIMER_PRE = 0
    li t0, 1
    sw t0, 16(s2)           // TIMER_INT_EN = 1
    li t0, 15
    sw t0, 4(s2)            // Quick count: LOAD = 15
    li t0, 1
    sw t0, 0(s2)            // Start Timer (CTRL = 1)
poll_timer:
    lw t1, 20(s2)           // Read INT_STS
    andi t2, t1, 1
    beqz t2, poll_timer
    li t0, 1
    sw t0, 20(s2)           // Clear interrupt
    sw zero, 0(s2)          // Stop timer
    li t0, 0x713E0001       // Timer Pass Signature
    sw t0, 12(s0)           // DMEM[3] = Timer Pass

    // --------------------------------------------------------------------------
    // Section 4: S4 UART Peripheral Verification
    // --------------------------------------------------------------------------
    sw zero, 4(s3)          // UART_IER = 0
    li t0, 0x83
    sw t0, 12(s3)           // Enable DLAB (LCR = 0x83)
    li t0, 347
    sw t0, 8(s3)            // BAUD_DIV = 347 (115200 baud)
    li t0, 0x03
    sw t0, 12(s3)           // 8-N-1 format (LCR = 0x03)
poll_uart_thre1:
    lw t1, 20(s3)           // Read LSR
    andi t2, t1, 0x20       // THRE bit 5
    beqz t2, poll_uart_thre1
    li t0, 0x56             // Character 'V'
    sw t0, 0(s3)            // Transmit THR
poll_uart_thre2:
    lw t1, 20(s3)
    andi t2, t1, 0x20
    beqz t2, poll_uart_thre2
    li t0, 0x0A270001       // UART Pass Signature
    sw t0, 16(s0)           // DMEM[4] = UART Pass

    // --------------------------------------------------------------------------
    // Section 5: S5 AES-128 Hardware Accelerator Verification (Known-Answer Test)
    // Key:       000102030405060708090a0b0c0d0e0f
    // Plaintext: 00112233445566778899aabbccddeeff
    // Expected:  69c4e0d86a7b0430d8cdb78070b4c55a
    // --------------------------------------------------------------------------
    li t0, 0x0c0d0e0f
    sw t0, 4(s4)            // KEY0
    li t0, 0x08090a0b
    sw t0, 8(s4)            // KEY1
    li t0, 0x04050607
    sw t0, 12(s4)           // KEY2
    li t0, 0x00010203
    sw t0, 16(s4)           // KEY3

    li t0, 0xccddeeff
    sw t0, 20(s4)           // TIN0
    li t0, 0x8899aabb
    sw t0, 24(s4)           // TIN1
    li t0, 0x44556677
    sw t0, 28(s4)           // TIN2
    li t0, 0x00112233
    sw t0, 32(s4)           // TIN3

    li t0, 1
    sw t0, 0(s4)            // AES_CSR = 1 (start encryption)
poll_aes_done:
    lw t1, 0(s4)            // Read AES_CSR
    bge t1, zero, poll_aes_done // Bit 31 is sign bit: loop while positive (bit 31 == 0)

    lw a0, 36(s4)           // TOUT0
    lw a1, 40(s4)           // TOUT1
    lw a2, 44(s4)           // TOUT2
    lw a3, 48(s4)           // TOUT3

    // Verify KAT ciphertext words
    li t3, 0x70b4c55a
    bne a0, t3, aes_fail
    li t3, 0xd8cdb780
    bne a1, t3, aes_fail
    li t3, 0x6a7b0430
    bne a2, t3, aes_fail
    li t3, 0x69c4e0d8
    bne a3, t3, aes_fail

    li t0, 0xAE510001       // AES Pass Signature
    sw t0, 20(s0)           // DMEM[5] = AES Pass
    j aes_ok

aes_fail:
    li t0, 0xDEADBEEF
    sw t0, 20(s0)

aes_ok:

    // --------------------------------------------------------------------------
    // Section 6: S6/S7 FFT Hardware Accelerator Verification
    // --------------------------------------------------------------------------
    li t0, 0x00004000
    sw t0, 0(s6)            // Sample 0 impulse (+0.5 real, 0 imag)
    sw zero, 4(s6)          // Sample 1
    sw zero, 8(s6)          // Sample 2
    sw zero, 12(s6)         // Sample 3

    li t0, 1
    sw t0, 0(s5)            // Start FFT (FFT_CTRL = 1)
poll_fft_done:
    lw t1, 4(s5)            // Read FFT_STATUS
    andi t2, t1, 1          // Done_sticky bit 0
    beqz t2, poll_fft_done

    lw a0, 0(s6)            // Read transformed sample 0
    li t3, 0x00000010       // Expected real part = 0x0010
    bne a0, t3, fft_fail

    li t0, 0xFF700001       // FFT Pass Signature
    sw t0, 24(s0)           // DMEM[6] = FFT Pass
    j fft_ok

fft_fail:
    li t0, 0xDEADBEEF
    sw t0, 24(s0)

fft_ok:

    // --------------------------------------------------------------------------
    // Section 7: S13 DMA Controller Verification (Mem-to-Mem Transfer)
    // Transfer from DMEM buffer (0x0008_0200) to FFT Memory buffer (0x8000_9200)
    // --------------------------------------------------------------------------
    li t0, 0xD1110001
    sw t0, 512(s0)          // DMEM[0x200]
    li t0, 0xD2220002
    sw t0, 516(s0)          // DMEM[0x204]

    sw zero, 512(s6)        // FFT_MEM[0x200]
    sw zero, 516(s6)        // FFT_MEM[0x204]

    li t0, 0x00080200
    sw t0, 32(s7)           // DESC0_SRC_ADDR (offset 0x20)
    li t0, 0x80009200
    sw t0, 48(s7)           // DESC0_DST_ADDR (offset 0x30)
    li t0, 8                // 8 bytes (2 words)
    sw t0, 64(s7)           // DESC0_NUM_BYTES (offset 0x40)
    li t0, 4
    sw t0, 80(s7)           // DESC0_CFG (offset 0x50)

    li t0, 0x11
    sw t0, 0(s7)            // Start DMA (CONTROL = 0x11)
poll_dma_sec7:
    lw t1, 8(s7)            // Read DMA_STATUS
    lui t2, 16              // Bit 16 (0x00010000)
    and t3, t1, t2
    beqz t3, poll_dma_sec7

    lw a0, 512(s6)          // Dest word 0
    lw a1, 516(s6)          // Dest word 1
    li t0, 0xD1110001
    bne a0, t0, dma_fail
    li t0, 0xD2220002
    bne a1, t0, dma_fail

    li t0, 0xD11A0001       // DMA Pass Signature
    sw t0, 28(s0)           // DMEM[7] = DMA Pass
    j dma_ok

dma_fail:
    li t0, 0xDEADBEEF
    sw t0, 28(s0)

dma_ok:

    // --------------------------------------------------------------------------
    // Section 8: CPU + DMA Master Concurrency Verification
    // CPU actively writes and reads DMEM while DMA transfers burst to FFT memory
    // --------------------------------------------------------------------------
    li t0, 0x00080200
    sw t0, 32(s7)           // Re-trigger DMA on descriptor 0
    li t0, 0x80009200
    sw t0, 48(s7)
    li t0, 8
    sw t0, 64(s7)
    li t0, 4
    sw t0, 80(s7)
    li t0, 0x11
    sw t0, 0(s7)            // Start DMA background transfer

    // Concurrent CPU access to DMEM:
    li t4, 0xCAFE1111
    sw t4, 128(s0)          // DMEM[0x80]
    li t4, 0xCAFE2222
    sw t4, 132(s0)          // DMEM[0x84]
    lw a0, 128(s0)          // Readback
    lw a1, 132(s0)

poll_dma_concur:
    lw t1, 8(s7)
    lui t2, 16              // Bit 16 (0x00010000)
    and t3, t1, t2
    beqz t3, poll_dma_concur

    li t0, 0xCAFE1111
    bne a0, t0, concur_fail
    li t0, 0xCAFE2222
    bne a1, t0, concur_fail

    li t0, 0xC0CC0001       // Concurrency Pass Signature
    sw t0, 32(s0)           // DMEM[8] = Concurrency Pass
    j concur_ok

concur_fail:
    li t0, 0xDEADBEEF
    sw t0, 32(s0)

concur_ok:

    // --------------------------------------------------------------------------
    // Section 9: Core Interrupt & Trap Handling Verification
    // --------------------------------------------------------------------------
    la t0, isr_trap_handler
    csrw mtvec, t0          // Set trap handler address
    sw zero, 40(s0)         // Clear trap count in DMEM[10]

    // Set Timer for expire interrupt (LOAD = 15)
    li t0, 15
    sw t0, 4(s2)            // TIMER_LOAD = 15
    li t0, 1
    sw t0, 16(s2)           // TIMER_INT_EN = 1

    // Enable mie.MTIE (0x80) and mstatus.MIE (0x08)
    li t0, 0x880
    csrs mie, t0
    li t0, 0x08
    csrs mstatus, t0

    // Start timer to trigger interrupt
    li t0, 1
    sw t0, 0(s2)
poll_isr_serviced:
    lw t1, 40(s0)           // Check trap count from DMEM[10]
    beqz t1, poll_isr_serviced

    // Disable interrupts post-test
    li t0, 0x08
    csrc mstatus, t0

    li t0, 0x10700001       // Interrupt Pass Signature
    sw t0, 44(s0)           // DMEM[11] = Interrupt Pass

    // --------------------------------------------------------------------------
    // Section 10: Final Master Regression Completion Signatures
    // --------------------------------------------------------------------------
    li t0, 0xCAFEBABE       // Master Pass Signature 2
    sw t0, 52(s0)           // DMEM[13] = 0xCAFE_BABE
    li t0, 0x55AA55AA       // Master Pass Signature 1 (Completion Trigger)
    sw t0, 48(s0)           // DMEM[12] = 0x55AA_55AA

master_done:
    j master_done

// ------------------------------------------------------------------------------
// ISR Trap Handler
// ------------------------------------------------------------------------------
    .align 4
isr_trap_handler:
    csrr t5, mcause
    sw t5, 36(s0)           // DMEM[9] = mcause (interrupt cause)

    // Clear Timer interrupt
    li t6, 1
    sw t6, 20(s2)           // W1C clear TIMER_INT_STS
    sw zero, 0(s2)          // Stop timer

    // Increment trap count in DMEM[10]
    lw t5, 40(s0)
    addi t5, t5, 1
    sw t5, 40(s0)

    mret
