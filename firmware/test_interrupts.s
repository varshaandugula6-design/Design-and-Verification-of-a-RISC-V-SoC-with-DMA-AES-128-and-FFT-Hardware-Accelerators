// ==============================================================================
// test_interrupts.s: RISC-V Firmware for Trap and Interrupt Handling Verification
// Tests mtvec registration, mstatus.MIE, mie.MTIE, real trap entry,
// interrupt status clearing, and mret return to main program.
// ==============================================================================

    .org 0x00040000
    .globl _start

_start:
    li s0, 0x00080000       // s0 = DMEM base
    li s1, 0x80002000       // s1 = Timer base

    // Step 1: Set up trap vector (mtvec = trap_handler)
    la t0, trap_handler
    csrw mtvec, t0

    // Step 2: Clear trap count in DMEM[1]
    sw zero, 4(s0)

    // Step 3: Configure Timer for quick countdown (LOAD = 15) and enable expire IRQ
    li t0, 15
    sw t0, 4(s1)            // TIMER_LOAD = 15
    li t0, 1
    sw t0, 16(s1)           // TIMER_INT_EN = 1

    // Step 4: Enable interrupts in core
    // mie.MTIE (bit 7 = 0x80) | mie.MEIE (bit 11 = 0x800) -> 0x880
    li t0, 0x880
    csrs mie, t0

    // mstatus.MIE (bit 3 = 0x08)
    li t0, 0x08
    csrs mstatus, t0

    // Step 5: Start Timer
    li t0, 1
    sw t0, 0(s1)            // TIMER_CTRL = 1

    // Step 6: Wait in main loop for trap handler to service the interrupt
wait_trap:
    lw t1, 4(s0)            // Read trap count from DMEM[1]
    beqz t1, wait_trap      // Loop until trap handler increments count

    // Step 7: Disable core interrupts
    li t0, 0x08
    csrc mstatus, t0

    // Write pass signature
    li t0, 0x10700001       // Interrupt test pass signature
    sw t0, 8(s0)            // DMEM[2] = Signature

done:
    j done

// ------------------------------------------------------------------------------
// Trap Handler
// ------------------------------------------------------------------------------
    .align 4
trap_handler:
    // Read and log mcause to DMEM[0]
    csrr t5, mcause
    sw t5, 0(s0)            // DMEM[0] = mcause

    // Clear Timer interrupt (TIMER_INT_STS offset 0x14)
    li t6, 1
    sw t6, 20(s1)           // W1C clear timer interrupt
    sw zero, 0(s1)          // Stop timer (TIMER_CTRL = 0)

    // Increment trap count in DMEM[1]
    lw t5, 4(s0)
    addi t5, t5, 1
    sw t5, 4(s0)            // DMEM[1] = trap count

    // Return from trap
    mret
