/* ==============================================================================
 * soc_c_test.c: C-Based Firmware for RISC-V VeeR EL2 SoC Peripheral Verification
 *
 * Operations:
 *   1. Basic 32-bit arithmetic operations (ALU add, multiply, logic)
 *   2. GPIO Controller (S2 / 0x8000_1000):
 *      - Configure DIR (0x8000_1008)
 *      - Write DATA_O (0x8000_1004)
 *      - Readback verification
 *      - Atomic SET_O (0x8000_1020)
 *   3. Real-Time Timer (S3 / 0x8000_2000):
 *      - Configure LOAD (0x8000_2004)
 *      - Configure CMP  (0x8000_2018)
 *      - Readback verification
 *   4. Results and Status signatures written to DMEM (0x0008_0000):
 *      - DMEM[0] = Arithmetic Result
 *      - DMEM[1] = GPIO DIR Readback
 *      - DMEM[2] = GPIO DATA_O Readback
 *      - DMEM[3] = GPIO DATA_O after Atomic SET
 *      - DMEM[4] = Timer LOAD Readback
 *      - DMEM[5] = Timer CMP Readback
 *      - DMEM[6] = PASS Signature (0xC001CAFE) or FAIL (0xDEADBEEF)
 * ==============================================================================
 */

#include <stdint.h>

// Memory Map
#define DMEM_BASE       0x00080000U
#define GPIO_BASE       0x80001000U
#define TIMER_BASE      0x80002000U

// GPIO Registers (gpio_regs.sv)
#define GPIO_DATA_I     (*(volatile uint32_t *)(GPIO_BASE + 0x00U))
#define GPIO_DATA_O     (*(volatile uint32_t *)(GPIO_BASE + 0x04U))
#define GPIO_DIR        (*(volatile uint32_t *)(GPIO_BASE + 0x08U))
#define GPIO_INT_EN     (*(volatile uint32_t *)(GPIO_BASE + 0x0CU))
#define GPIO_SET_O      (*(volatile uint32_t *)(GPIO_BASE + 0x20U))
#define GPIO_CLR_O      (*(volatile uint32_t *)(GPIO_BASE + 0x24U))
#define GPIO_TGL_O      (*(volatile uint32_t *)(GPIO_BASE + 0x28U))
#define GPIO_DEB_EN     (*(volatile uint32_t *)(GPIO_BASE + 0x30U))

// Timer Registers (timer_regs.sv)
#define TIMER_CTRL      (*(volatile uint32_t *)(TIMER_BASE + 0x00U))
#define TIMER_LOAD      (*(volatile uint32_t *)(TIMER_BASE + 0x04U))
#define TIMER_VAL       (*(volatile uint32_t *)(TIMER_BASE + 0x08U))
#define TIMER_PRE       (*(volatile uint32_t *)(TIMER_BASE + 0x0CU))
#define TIMER_INT_EN    (*(volatile uint32_t *)(TIMER_BASE + 0x10U))
#define TIMER_INT_STS   (*(volatile uint32_t *)(TIMER_BASE + 0x14U))
#define TIMER_CMP       (*(volatile uint32_t *)(TIMER_BASE + 0x18U))

// Signatures
#define TEST_PASS_SIG   0xC001CAFEU
#define TEST_FAIL_SIG   0xDEADBEEFU

// DMEM Base Pointer
#define DMEM_PTR        ((volatile uint32_t *)DMEM_BASE)

int main(void) {
    volatile uint32_t * const dmem = DMEM_PTR;
    uint32_t a, b, arith_res;
    uint32_t gpio_dir_rb, gpio_data_rb, gpio_set_rb;
    uint32_t timer_load_rb, timer_cmp_rb;

    // ------------------------------------------------------------
    // 1. Basic Arithmetic Operations
    // ------------------------------------------------------------
    a = 0x12345000U + 0x678U; // 0x12345678
    b = (a * 2U) + 1U;        // 0x2468ACF1
    arith_res = b ^ 0x00000000U;

    if (arith_res != 0x2468ACF1U) {
        dmem[6] = TEST_FAIL_SIG;
        return 1;
    }
    dmem[0] = arith_res;

    // ------------------------------------------------------------
    // 2. Access GPIO Registers: Configure Direction
    // ------------------------------------------------------------
    // Pins [15:0] as outputs (1), Pins [31:16] as inputs (0) -> 0x0000FFFF
    GPIO_DIR = 0x0000FFFFU;
    gpio_dir_rb = GPIO_DIR;
    dmem[1] = gpio_dir_rb;

    if (gpio_dir_rb != 0x0000FFFFU) {
        dmem[6] = TEST_FAIL_SIG;
        return 2;
    }

    // ------------------------------------------------------------
    // 3. Perform GPIO Write and Readback
    // ------------------------------------------------------------
    GPIO_DATA_O = 0x0000A55AU;
    gpio_data_rb = GPIO_DATA_O;
    dmem[2] = gpio_data_rb;

    if (gpio_data_rb != 0x0000A55AU) {
        dmem[6] = TEST_FAIL_SIG;
        return 3;
    }

    // ------------------------------------------------------------
    // 4. Perform Recognizable Sequence of MMIO: Atomic SET
    // ------------------------------------------------------------
    // Set bits [7:4] with mask 0x000000A0 -> 0x0000A5FA
    GPIO_SET_O = 0x000000A0U;
    gpio_set_rb = GPIO_DATA_O;
    dmem[3] = gpio_set_rb;

    if (gpio_set_rb != 0x0000A5FAU) {
        dmem[6] = TEST_FAIL_SIG;
        return 4;
    }

    // ------------------------------------------------------------
    // 5. Access Timer Registers
    // ------------------------------------------------------------
    TIMER_LOAD = 100U;
    TIMER_CMP  = 40U;
    timer_load_rb = TIMER_LOAD;
    timer_cmp_rb  = TIMER_CMP;
    dmem[4] = timer_load_rb;
    dmem[5] = timer_cmp_rb;

    if (timer_load_rb != 100U || timer_cmp_rb != 40U) {
        dmem[6] = TEST_FAIL_SIG;
        return 5;
    }

    // ------------------------------------------------------------
    // 6. Test Completion: Store PASS Signature
    // ------------------------------------------------------------
    dmem[6] = TEST_PASS_SIG;

    return 0;
}
