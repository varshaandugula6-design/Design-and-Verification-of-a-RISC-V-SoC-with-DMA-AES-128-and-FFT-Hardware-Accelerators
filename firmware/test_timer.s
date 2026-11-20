// ==============================================================================
// test_timer.s: RISC-V Firmware for Real-Time Timer Verification (S3 / 0x8000_2000)
// Configures LOAD, CMP, PRE, enables expire interrupt, starts down-counting,
// polls countdown, clears interrupt, and stores results into DMEM.
// ==============================================================================

    .org 0x00040000
    .globl _start

_start:
    li s0, 0x00080000       // s0 = DMEM base
    li s1, 0x80002000       // s1 = Timer base (CTRL)

    // Step 1: Write LOAD register (offset 0x04) = 100
    li t0, 100
    sw t0, 4(s1)            // TIMER_LOAD = 100
    lw t1, 4(s1)            // Readback LOAD
    sw t1, 0(s0)            // DMEM[0] = LOAD readback (100)

    // Step 2: Write CMP register (offset 0x18) = 40
    li t0, 40
    sw t0, 24(s1)           // TIMER_CMP = 40
    lw t1, 24(s1)           // Readback CMP
    sw t1, 4(s0)            // DMEM[1] = CMP readback (40)

    // Step 3: Prescaler = 0 (offset 0x0C), Enable expire IRQ = 1 (offset 0x10)
    sw zero, 12(s1)         // TIMER_PRE = 0
    li t0, 1
    sw t0, 16(s1)           // TIMER_INT_EN = 1

    // Step 4: Configure quick countdown (LOAD = 20) and start timer (CTRL = 1)
    li t0, 20
    sw t0, 4(s1)            // TIMER_LOAD = 20
    li t0, 1
    sw t0, 0(s1)            // TIMER_CTRL = 1 (start down-counter)

    // Step 5: Poll INT_STS (offset 0x14) until expire interrupt is set
poll_irq:
    lw t1, 20(s1)           // Read TIMER_INT_STS
    andi t2, t1, 1          // Check bit 0 (expire flag)
    beqz t2, poll_irq       // Loop until expire flag asserts

    sw t1, 8(s0)            // DMEM[2] = INT_STS (bit 0 = 1)

    // Step 6: Clear expire interrupt by writing 1 to INT_STS (W1C)
    li t0, 1
    sw t0, 20(s1)           // Clear interrupt
    lw t1, 20(s1)           // Readback INT_STS
    sw t1, 12(s0)           // DMEM[3] = INT_STS after clear (expected 0)

    // Step 7: Stop timer
    sw zero, 0(s1)          // TIMER_CTRL = 0

    // Completion signature
    li t0, 0x713E0001       // TIMER test pass signature
    sw t0, 16(s0)           // DMEM[4] = Signature

done:
    j done
