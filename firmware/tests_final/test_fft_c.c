/* ==============================================================================
 * test_fft_c.c: RISC-V VeeR EL2 C-Based Firmware for FFT Hardware Accelerator
 *
 * Objectives:
 *   1. Program a unit impulse signal into FFT Sample Memory (S07 / 0x8000_9000):
 *      sample[0] = 0x0000_4000 (Q1.15 real = +0.5, imag = 0.0).
 *   2. Clear remaining sample memory locations.
 *   3. Issue start command via FFT Control register (S06 / 0x8000_8000, offset 0x00).
 *   4. Poll completion status via FFT_STATUS (offset 0x04, bit 0 = done_sticky).
 *   5. Retrieve transformed frequency-domain output sample[0].
 *   6. Verify that real part equals 0x0010 (mathematically expected scaled DC bin).
 *   7. Store result signatures to DMEM.
 * ==============================================================================
 */

#include "soc_peripherals.h"

int main(void) {
    volatile uint32_t * const dmem = DMEM_PTR;

    /* Step 1: Write impulse at sample 0 */
    FFT_SAMPLE_RAM(0) = 0x00004000U; /* Q1.15: Real = +0.5, Imag = 0 */
    FFT_SAMPLE_RAM(1) = 0x00000000U;
    FFT_SAMPLE_RAM(2) = 0x00000000U;
    FFT_SAMPLE_RAM(3) = 0x00000000U;

    /* Step 2: Trigger FFT computation engine */
    FFT_REG_CTRL = FFT_CTRL_START;

    /* Step 3: Poll FFT_STATUS until bit 0 (done_sticky) asserts */
    while ((FFT_REG_STATUS & FFT_STATUS_DONE) == 0U) {
        /* Busy wait for Radix-2 1024-point butterfly pipelined computation */
    }

    /* Step 4: Read back transformed sample 0 */
    uint32_t out_sample0 = FFT_SAMPLE_RAM(0);
    dmem[0] = out_sample0;

    /* Step 5: Verify against reference expectation (DC bin = 0x0000_0010) */
    const uint32_t exp_dc = 0x00000010U;
    if (out_sample0 != exp_dc) {
        dmem[1] = SIG_FAIL_GLOBAL;
        dmem[6] = SIG_FAIL_GLOBAL;
        return 1;
    }

    /* Step 6: Store Pass Signatures */
    dmem[1] = SIG_FFT_PASS;
    dmem[6] = SIG_PASS_GLOBAL;

    return 0;
}
