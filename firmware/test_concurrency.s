// ==============================================================================
// test_concurrency.s: RISC-V Firmware for Master Concurrency Verification
// Tests simultaneous AXI bus access:
//   - VeeR EL2 LSU (M1) performs continuous reads & writes to DMEM (S1)
//   - DMA Master (M2) performs memory-to-memory burst transfers to FFT Mem (S7)
//   - Interconnect arbitrates concurrently without lockup or data corruption.
// ==============================================================================

    .org 0x00040000
    .globl _start

_start:
    li s0, 0x00080000       // s0 = DMEM base
    li s1, 0x80006000       // s1 = DMA CSR base
    li s2, 0x80009000       // s2 = FFT Memory base

    // Step 1: Initialize DMA source buffer in DMEM (offset 0x400..0x43C = 16 words)
    li t0, 0x11110000
    sw t0, 1024(s0)
    li t0, 0x22220000
    sw t0, 1028(s0)
    li t0, 0x33330000
    sw t0, 1032(s0)
    li t0, 0x44440000
    sw t0, 1036(s0)

    // Clear destination in FFT memory (offset 0x400..0x43C)
    sw zero, 1024(s2)
    sw zero, 1028(s2)
    sw zero, 1032(s2)
    sw zero, 1036(s2)

    // Step 2: Configure DMA Descriptor 0
    li t0, 0x00080400       // Source: DMEM[0x400]
    sw t0, 32(s1)           // DESC0_SRC_ADDR
    li t0, 0x80009400       // Destination: FFT_MEM[0x400]
    sw t0, 48(s1)           // DESC0_DST_ADDR
    li t0, 16               // 16 bytes = 4 words
    sw t0, 64(s1)           // DESC0_NUM_BYTES
    li t0, 4                // Enable = 1
    sw t0, 80(s1)           // DESC0_CFG

    // Step 3: Start DMA transfer (go=1, max_burst=4)
    li t0, 0x11
    sw t0, 0(s1)            // DMA_CONTROL

    // Step 4: CONCURRENT CPU ACTIVITY:
    // While DMA is actively executing across M2, CPU performs concurrent LSU writes/reads to DMEM
    li t4, 0xCAFE0001
    sw t4, 256(s0)          // DMEM[0x100]
    li t4, 0xCAFE0002
    sw t4, 260(s0)          // DMEM[0x104]
    li t4, 0xCAFE0003
    sw t4, 264(s0)          // DMEM[0x108]
    li t4, 0xCAFE0004
    sw t4, 268(s0)          // DMEM[0x10C]

    // Read back CPU data to verify integrity
    lw a0, 256(s0)
    lw a1, 260(s0)
    lw a2, 264(s0)
    lw a3, 268(s0)

    // Step 5: Wait for DMA completion
poll_dma:
    lw t1, 8(s1)            // Read DMA_STATUS
    lui t2, 16              // Bit 16 (0x00010000)
    and t3, t1, t2
    beqz t3, poll_dma

    // Step 6: Verify DMA transferred words in FFT memory
    lw t4, 1024(s2)
    sw t4, 0(s0)            // Log word 0 to DMEM[0]
    lw t5, 1028(s2)
    sw t5, 4(s0)            // Log word 1 to DMEM[1]

    // Step 7: Check CPU readback integrity
    li t0, 0xCAFE0001
    bne a0, t0, fail
    li t0, 0xCAFE0002
    bne a1, t0, fail
    li t0, 0xCAFE0003
    bne a2, t0, fail
    li t0, 0xCAFE0004
    bne a3, t0, fail

    // Check DMA data integrity
    li t0, 0x11110000
    bne t4, t0, fail
    li t0, 0x22220000
    bne t5, t0, fail

    // All match! Pass signature
    li t0, 0xC0CC0001       // Concurrency pass signature
    sw t0, 16(s0)           // DMEM[4] = Signature
    j done

fail:
    li t0, 0xDEADBEEF
    sw t0, 16(s0)

done:
    j done
