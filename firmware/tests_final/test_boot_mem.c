/* ==============================================================================
 * test_boot_mem.c: RISC-V VeeR EL2 Boot & Memory Subsystem C Verification Test
 *
 * Objectives:
 *   1. Verify processor reset release, C runtime CRT0 execution, stack setup.
 *   2. Execute 32-bit ALU arithmetic, multiplication, logic and shifts.
 *   3. Perform read/write pattern verification across DMEM memory space.
 *   4. Record execution signature to DMEM[2].
 * ==============================================================================
 */

#include "soc_peripherals.h"

int main(void) {
    volatile uint32_t * const dmem = DMEM_PTR;
    uint32_t a = 0x12345678U;
    uint32_t b = 0x0FEDCBA9U;
    uint32_t sum, prod_low, xor_res, shf_res;
    uint32_t pattern_err = 0;

    /* 1. Arithmetic & Logical Tests */
    sum = a + b;                  /* 0x22222221 */
    xor_res = a ^ b;              /* 0x1DD99DD1 */
    shf_res = (a << 4) | (b >> 28);/* 0x23456780 */
    prod_low = a * 3U;            /* 0x369D0368 */

    uint32_t arith_combined = sum ^ xor_res ^ shf_res ^ prod_low;
    dmem[0] = arith_combined;

    /* 2. DMEM Memory Array Pattern Test (4 words at offsets 0x100..0x10C) */
    volatile uint32_t * const test_array = (volatile uint32_t *)(DMEM_BASE + 0x100U);
    for (uint32_t i = 0; i < 4; i++) {
        test_array[i] = (i * 0x11111111U) ^ 0xA5A55A5AU;
    }

    for (uint32_t i = 0; i < 4; i++) {
        uint32_t exp = (i * 0x11111111U) ^ 0xA5A55A5AU;
        if (test_array[i] != exp) {
            pattern_err++;
        }
    }

    if (pattern_err != 0) {
        dmem[2] = SIG_FAIL_GLOBAL;
        return 1;
    }

    dmem[1] = 0x5A5AA5A5U;  /* Pattern check passed */
    dmem[2] = SIG_PASS_GLOBAL;

    return 0;
}
