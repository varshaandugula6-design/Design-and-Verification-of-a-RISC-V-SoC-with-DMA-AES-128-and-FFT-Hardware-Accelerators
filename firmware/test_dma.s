// ==============================================================================
// test_dma.s: RISC-V Firmware for DMA Controller Verification (S13 / 0x8000_6000)
// Configures DMA descriptor for memory transfer from DMEM (0x0008_0200)
// to FFT Memory (0x8000_9200), starts DMA, polls completion, and verifies data.
// ==============================================================================

    .org 0x00040000
    .globl _start

_start:
    li s0, 0x00080000       // s0 = DMEM base
    li s1, 0x80006000       // s1 = DMA CSR base
    li s2, 0x80009000       // s2 = FFT Memory base

    // Step 1: Populate source buffer in DMEM (offset 0x200)
    li t0, 0xA5A50001
    sw t0, 512(s0)          // DMEM[0x200]
    li t0, 0xA5A50002
    sw t0, 516(s0)          // DMEM[0x204]
    li t0, 0xA5A50003
    sw t0, 520(s0)          // DMEM[0x208]
    li t0, 0xA5A50004
    sw t0, 524(s0)          // DMEM[0x20C]

    // Step 2: Clear destination buffer in FFT memory (offset 0x200)
    sw zero, 512(s2)        // FFT_MEM[0x200]
    sw zero, 516(s2)        // FFT_MEM[0x204]
    sw zero, 520(s2)        // FFT_MEM[0x208]
    sw zero, 524(s2)        // FFT_MEM[0x20C]

    // Step 3: Program DMA Descriptor 0
    li t0, 0x00080200       // Source address: DMEM buffer
    sw t0, 32(s1)           // DESC0_SRC_ADDR (offset 0x20)

    li t0, 0x80009200       // Destination address: FFT memory buffer
    sw t0, 48(s1)           // DESC0_DST_ADDR (offset 0x30)

    li t0, 16               // 16 bytes = 4 words
    sw t0, 64(s1)           // DESC0_NUM_BYTES (offset 0x40)

    li t0, 4                // Descriptor enable = 1
    sw t0, 80(s1)           // DESC0_CFG (offset 0x50)

    // Step 4: Start DMA transfer (DMA_CONTROL = 0x11: go=1, max_burst=4)
    li t0, 0x11
    sw t0, 0(s1)            // DMA_CONTROL (offset 0x00)

    // Step 5: Poll DMA_STATUS (offset 0x08) until done (bit 16) is set
poll_dma_done:
    lw t1, 8(s1)            // Read DMA_STATUS
    lui t2, 16              // t2 = 0x00010000 (bit 16)
    and t3, t1, t2
    beqz t3, poll_dma_done

    // Step 6: Verify transferred data in destination buffer
    lw a0, 512(s2)          // Dest word 0
    sw a0, 0(s0)            // Log to DMEM[0]
    lw a1, 516(s2)          // Dest word 1
    sw a1, 4(s0)            // Log to DMEM[1]
    lw a2, 520(s2)          // Dest word 2
    sw a2, 8(s0)            // Log to DMEM[2]
    lw a3, 524(s2)          // Dest word 3
    sw a3, 12(s0)           // Log to DMEM[3]

    li t0, 0xA5A50001
    bne a0, t0, fail
    li t0, 0xA5A50002
    bne a1, t0, fail
    li t0, 0xA5A50003
    bne a2, t0, fail
    li t0, 0xA5A50004
    bne a3, t0, fail

    // All match! Pass signature
    li t0, 0xD11A0001       // DMA test pass signature
    sw t0, 16(s0)           // DMEM[4] = Signature
    j done

fail:
    li t0, 0xDEADBEEF
    sw t0, 16(s0)

done:
    j done
