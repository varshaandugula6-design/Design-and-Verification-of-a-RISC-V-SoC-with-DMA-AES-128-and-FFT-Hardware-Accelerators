/* ==============================================================================
 * test_soc_master.c: Complete C-Based Master Integration Test for RISC-V SoC
 *
 * Exercises all integrated components sequentially in C:
 *   1. CPU Core Arithmetic & Memory Load/Store
 *   2. GPIO Controller (S02)
 *   3. Real-Time Timer (S03)
 *   4. UART Subsystem (S04)
 *   5. AES-128 Hardware Accelerator (S05)
 *   6. FFT Hardware Accelerator (S06/S07)
 *   7. DMA Controller (S13)
 *
 * Result Signatures written to DMEM (0x0008_0000):
 *   DMEM[0]  = Arithmetic Result (0x2468ACF1)
 *   DMEM[1]  = GPIO DIR Readback (0x0000FFFF)
 *   DMEM[2]  = GPIO Signature (0x60100001)
 *   DMEM[3]  = Timer Signature (0x713E0001)
 *   DMEM[4]  = UART Signature (0x0A270001)
 *   DMEM[5]  = AES KAT Signature (0xAE510001)
 *   DMEM[6]  = FFT Signature (0xFF700001)
 *   DMEM[7]  = DMA Signature (0xD11A0001)
 *   DMEM[12] = Master PASS Signature 1 (0x55AA55AA)
 *   DMEM[13] = Master PASS Signature 2 (0xCAFEBABE)
 *   DMEM[14] = Global C PASS Signature (0xC001CAFE)
 * ==============================================================================
 */

#include "soc_peripherals.h"

int main(void) {
    volatile uint32_t * const dmem = DMEM_PTR;

    /* ------------------------------------------------------------
     * 1. CPU Arithmetic & Memory Subsystem Test
     * ------------------------------------------------------------ */
    uint32_t a = 0x12345000U + 0x678U; // 0x12345678
    uint32_t b = (a * 2U) + 1U;        // 0x2468ACF1
    if (b != 0x2468ACF1U) {
        dmem[14] = SIG_FAIL_GLOBAL;
        return 1;
    }
    dmem[0] = b;

    /* ------------------------------------------------------------
     * 2. GPIO Controller Verification (S02)
     * ------------------------------------------------------------ */
    GPIO_REG_DIR = 0x0000FFFFU;
    if (GPIO_REG_DIR != 0x0000FFFFU) {
        dmem[14] = SIG_FAIL_GLOBAL;
        return 2;
    }
    dmem[1] = GPIO_REG_DIR;

    GPIO_REG_DATA_O = 0x0000A55AU;
    GPIO_REG_SET_O  = 0x000000A0U; // Becomes 0x0000A5FA
    if (GPIO_REG_DATA_O != 0x0000A5FAU) {
        dmem[14] = SIG_FAIL_GLOBAL;
        return 3;
    }
    dmem[2] = SIG_GPIO_PASS;

    /* ------------------------------------------------------------
     * 3. Real-Time Timer Verification (S03)
     * ------------------------------------------------------------ */
    TIMER_REG_LOAD = 100U;
    TIMER_REG_CMP  = 40U;
    if (TIMER_REG_LOAD != 100U || TIMER_REG_CMP != 40U) {
        dmem[14] = SIG_FAIL_GLOBAL;
        return 4;
    }
    dmem[3] = SIG_TIMER_PASS;

    /* ------------------------------------------------------------
     * 4. UART Subsystem Verification (S04)
     * ------------------------------------------------------------ */
    UART_REG_IER = 0x00U;
    UART_REG_LCR = 0x83U; /* DLAB = 1, 8-N-1 */
    UART_REG_BAUD_DIV = UART_BAUD_115200;
    UART_REG_LCR = 0x03U; /* DLAB = 0, 8-N-1 */

    if ((UART_REG_LSR & UART_LSR_THRE) == 0U) {
        dmem[14] = SIG_FAIL_GLOBAL;
        return 5;
    }
    UART_REG_THR = (uint32_t)'R';

    while ((UART_REG_LSR & UART_LSR_THRE) == 0U) {
        /* Wait for TX holding register empty */
    }
    dmem[4] = SIG_UART_PASS;

    /* ------------------------------------------------------------
     * 5. AES-128 Hardware Accelerator Verification (S05)
     * ------------------------------------------------------------ */
    AES_REG_KEY0 = 0x0C0D0E0FU;
    AES_REG_KEY1 = 0x08090A0BU;
    AES_REG_KEY2 = 0x04050607U;
    AES_REG_KEY3 = 0x00010203U;

    AES_REG_TIN0 = 0xCCDDEEFFU;
    AES_REG_TIN1 = 0x8899AABBU;
    AES_REG_TIN2 = 0x44556677U;
    AES_REG_TIN3 = 0x00112233U;

    AES_REG_CSR = AES_CSR_START;
    while ((AES_REG_CSR & AES_CSR_DONE) == 0U) {
        /* Busy wait */
    }

    if ((AES_REG_TOUT0 != 0x70B4C55AU) ||
        (AES_REG_TOUT1 != 0xD8CDB780U) ||
        (AES_REG_TOUT2 != 0x6A7B0430U) ||
        (AES_REG_TOUT3 != 0x69C4E0D8U)) {
        dmem[14] = SIG_FAIL_GLOBAL;
        return 6;
    }
    dmem[5] = SIG_AES_KAT_PASS;

    /* ------------------------------------------------------------
     * 6. FFT Hardware Accelerator Verification (S06 & S07)
     * ------------------------------------------------------------ */
    FFT_SAMPLE_RAM(0) = 0x00004000U; /* Q1.15 impulse */
    FFT_SAMPLE_RAM(1) = 0x00000000U;
    FFT_SAMPLE_RAM(2) = 0x00000000U;
    FFT_SAMPLE_RAM(3) = 0x00000000U;

    FFT_REG_CTRL = FFT_CTRL_START;
    while ((FFT_REG_STATUS & FFT_STATUS_DONE) == 0U) {
        /* Busy wait */
    }

    if (FFT_SAMPLE_RAM(0) != 0x00000010U) {
        dmem[14] = SIG_FAIL_GLOBAL;
        return 7;
    }
    dmem[6] = SIG_FFT_PASS;

    /* ------------------------------------------------------------
     * 7. DMA Controller Verification (S13)
     * ------------------------------------------------------------ */
    volatile uint32_t * const src_buf = (volatile uint32_t *)(DMEM_BASE + 0x200U);
    volatile uint32_t * const dst_buf = (volatile uint32_t *)(FFT_MEM_BASE + 0x200U);

    src_buf[0] = 0xA5A50001U;
    src_buf[1] = 0xA5A50002U;
    src_buf[2] = 0xA5A50003U;
    src_buf[3] = 0xA5A50004U;

    dst_buf[0] = 0x00000000U;
    dst_buf[1] = 0x00000000U;
    dst_buf[2] = 0x00000000U;
    dst_buf[3] = 0x00000000U;

    DMA_REG_DESC0_SRC   = (uint32_t)(uintptr_t)src_buf;
    DMA_REG_DESC0_DST   = (uint32_t)(uintptr_t)dst_buf;
    DMA_REG_DESC0_BYTES = 16U;
    DMA_REG_DESC0_CFG   = DMA_DESC_CFG_EN;

    DMA_REG_CONTROL = (DMA_CTRL_BURST4 | DMA_CTRL_GO);
    while ((DMA_REG_STATUS & DMA_STATUS_DONE) == 0U) {
        /* Busy wait */
    }

    if ((dst_buf[0] != 0xA5A50001U) ||
        (dst_buf[1] != 0xA5A50002U) ||
        (dst_buf[2] != 0xA5A50003U) ||
        (dst_buf[3] != 0xA5A50004U)) {
        dmem[14] = SIG_FAIL_GLOBAL;
        return 8;
    }
    dmem[7] = SIG_DMA_PASS;

    /* ------------------------------------------------------------
     * 8. Master Test Completion Signatures
     * ------------------------------------------------------------ */
    dmem[12] = SIG_SOC_MASTER_PASS; /* 0x55AA55AA */
    dmem[13] = 0xCAFEBABEU;
    dmem[14] = SIG_PASS_GLOBAL;     /* 0xC001CAFE */

    return 0;
}
