// ==============================================================================
// test_fft.s: RISC-V Firmware for FFT Hardware Accelerator Verification
// Interfaces: S6 FFT Control (0x8000_8000), S7 FFT Memory (0x8000_9000)
//
// Writes Q1.15 impulse sample at sample[0] = 0x0000_4000 (+0.5 real, 0 imag)
// Starts FFT engine, polls STATUS done_sticky, reads transformed output,
// verifies output real part == 0x0010, and logs status to DMEM.
// ==============================================================================

    .org 0x00040000
    .globl _start

_start:
    li s0, 0x00080000       // s0 = DMEM base
    li s1, 0x80008000       // s1 = FFT Control base
    li s2, 0x80009000       // s2 = FFT Memory base

    // Step 1: Write impulse at sample[0] = 0x0000_4000
    li t0, 0x00004000
    sw t0, 0(s2)            // FFT_MEM[0] = 0x0000_4000
    sw zero, 4(s2)          // FFT_MEM[1] = 0
    sw zero, 8(s2)          // FFT_MEM[2] = 0
    sw zero, 12(s2)         // FFT_MEM[3] = 0

    // Step 2: Trigger FFT computation (write 1 to FFT_CTRL at offset 0x00)
    li t0, 1
    sw t0, 0(s1)            // FFT_CTRL = 1

    // Step 3: Poll FFT_STATUS (offset 0x04) until bit 0 (done_sticky) is 1
poll_done:
    lw t1, 4(s1)            // Read FFT_STATUS
    andi t2, t1, 1          // Check bit 0 (done_sticky)
    beqz t2, poll_done

    // Step 4: Read back transformed sample[0]
    lw a0, 0(s2)            // Read output sample[0]
    sw a0, 0(s0)            // DMEM[0] = output sample[0] (expected 0x0000_0010)

    // Step 5: Verify against reference expectation
    li t3, 0x00000010
    bne a0, t3, fail

    // Pass signature
    li t0, 0xFF700001       // FFT test pass signature
    sw t0, 4(s0)            // DMEM[1] = Signature
    j done

fail:
    li t0, 0xDEADBEEF
    sw t0, 4(s0)

done:
    j done
