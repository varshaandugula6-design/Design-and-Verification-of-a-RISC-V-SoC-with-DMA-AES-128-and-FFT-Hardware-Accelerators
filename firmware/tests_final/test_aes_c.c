/* ==============================================================================
 * test_aes_c.c: RISC-V VeeR EL2 C-Based Firmware for AES-128 Hardware Accelerator
 *
 * Objectives:
 *   1. Program 128-bit Encryption Key into AES_KEY0..3 registers (S05 / 0x8000_7000).
 *   2. Program 128-bit Known-Answer Plaintext into AES_TIN0..3 registers.
 *   3. Issue start command via AES_CSR (bit 0 = 1).
 *   4. Poll completion status via AES_CSR (bit 31 = 1).
 *   5. Retrieve 128-bit Ciphertext from AES_TOUT0..3 registers.
 *   6. Validate against NIST FIPS-197 Known-Answer Test (KAT) specification.
 *   7. Store result signatures to DMEM.
 * ==============================================================================
 */

#include "soc_peripherals.h"

int main(void) {
    volatile uint32_t * const dmem = DMEM_PTR;

    /* Known-Answer Test Vectors:
     * Key:       00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f
     * Plaintext: 00 11 22 33 44 55 66 77 88 99 aa bb cc dd ee ff
     * Ciphertext:69 c4 e0 d8 6a 7b 04 30 d8 cd b7 80 70 b4 c5 5a
     */
    const uint32_t exp_tout0 = 0x70B4C55AU;
    const uint32_t exp_tout1 = 0xD8CDB780U;
    const uint32_t exp_tout2 = 0x6A7B0430U;
    const uint32_t exp_tout3 = 0x69C4E0D8U;

    /* Step 1: Program 128-bit Key registers */
    AES_REG_KEY0 = 0x0C0D0E0FU;
    AES_REG_KEY1 = 0x08090A0BU;
    AES_REG_KEY2 = 0x04050607U;
    AES_REG_KEY3 = 0x00010203U;

    /* Step 2: Program 128-bit Plaintext registers */
    AES_REG_TIN0 = 0xCCDDEEFFU;
    AES_REG_TIN1 = 0x8899AABBU;
    AES_REG_TIN2 = 0x44556677U;
    AES_REG_TIN3 = 0x00112233U;

    /* Step 3: Trigger Encryption */
    AES_REG_CSR = AES_CSR_START;

    /* Step 4: Poll CSR until bit 31 (done) asserts */
    while ((AES_REG_CSR & AES_CSR_DONE) == 0U) {
        /* Wait for 10-round AES pipelined engine */
    }

    /* Step 5: Read Ciphertext registers */
    uint32_t tout0 = AES_REG_TOUT0;
    uint32_t tout1 = AES_REG_TOUT1;
    uint32_t tout2 = AES_REG_TOUT2;
    uint32_t tout3 = AES_REG_TOUT3;

    /* Log results to DMEM */
    dmem[0] = tout0;
    dmem[1] = tout1;
    dmem[2] = tout2;
    dmem[3] = tout3;

    /* Step 6: Verify results against KAT */
    if ((tout0 != exp_tout0) ||
        (tout1 != exp_tout1) ||
        (tout2 != exp_tout2) ||
        (tout3 != exp_tout3)) {
        dmem[4] = SIG_FAIL_GLOBAL;
        dmem[6] = SIG_FAIL_GLOBAL;
        return 1;
    }

    /* Step 7: Store Pass Signatures */
    dmem[4] = SIG_AES_KAT_PASS;
    dmem[6] = SIG_PASS_GLOBAL;

    return 0;
}
