/* ==============================================================================
 * test_dma_c.c: RISC-V VeeR EL2 C-Based Firmware for DMA Controller
 *
 * Objectives:
 *   1. Populate memory-to-memory source buffer in DMEM (0x0008_0200).
 *   2. Clear destination buffer in FFT Sample Memory (0x8000_9200).
 *   3. Program Channel 0 Descriptor (Source, Destination, Length, Config).
 *   4. Initiate DMA transfer via DMA_CONTROL (go=1, burst=4).
 *   5. Poll DMA_STATUS until transfer completion (bit 16 = 1).
 *   6. Verify that transferred data at destination matches source data word-for-word.
 *   7. Store status signatures to DMEM.
 * ==============================================================================
 */

#include "soc_peripherals.h"

int main(void) {
    volatile uint32_t * const dmem = DMEM_PTR;
    volatile uint32_t * const src_buf = (volatile uint32_t *)(DMEM_BASE + 0x200U);
    volatile uint32_t * const dst_buf = (volatile uint32_t *)(FFT_MEM_BASE + 0x200U);

    const uint32_t words_to_transfer = 4U;
    const uint32_t bytes_to_transfer = words_to_transfer * sizeof(uint32_t);

    /* Step 1: Initialize source buffer with known pattern */
    src_buf[0] = 0xA5A50001U;
    src_buf[1] = 0xA5A50002U;
    src_buf[2] = 0xA5A50003U;
    src_buf[3] = 0xA5A50004U;

    /* Step 2: Clear destination buffer */
    dst_buf[0] = 0x00000000U;
    dst_buf[1] = 0x00000000U;
    dst_buf[2] = 0x00000000U;
    dst_buf[3] = 0x00000000U;

    /* Step 3: Configure DMA Descriptor 0 */
    DMA_REG_DESC0_SRC   = (uint32_t)(uintptr_t)src_buf;
    DMA_REG_DESC0_DST   = (uint32_t)(uintptr_t)dst_buf;
    DMA_REG_DESC0_BYTES = bytes_to_transfer;
    DMA_REG_DESC0_CFG   = DMA_DESC_CFG_EN;

    /* Step 4: Trigger DMA Engine (go=1, burst=4 beats -> 0x11) */
    DMA_REG_CONTROL = (DMA_CTRL_BURST4 | DMA_CTRL_GO);

    /* Step 5: Poll DMA_STATUS until done (bit 16) is asserted */
    while ((DMA_REG_STATUS & DMA_STATUS_DONE) == 0U) {
        /* Busy wait for AXI master burst read/write completion */
    }

    /* Step 6: Verify transferred data in destination buffer */
    uint32_t err_cnt = 0;
    for (uint32_t i = 0; i < words_to_transfer; i++) {
        uint32_t val = dst_buf[i];
        dmem[i] = val;  /* Log to DMEM[0..3] */
        if (val != src_buf[i]) {
            err_cnt++;
        }
    }

    if (err_cnt != 0U) {
        dmem[4] = SIG_FAIL_GLOBAL;
        dmem[6] = SIG_FAIL_GLOBAL;
        return 1;
    }

    /* Step 7: Store Pass Signatures */
    dmem[4] = SIG_DMA_PASS;
    dmem[6] = SIG_PASS_GLOBAL;

    return 0;
}
