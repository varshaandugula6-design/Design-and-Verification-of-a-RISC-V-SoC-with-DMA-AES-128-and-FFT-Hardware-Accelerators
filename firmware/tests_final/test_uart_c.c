/* ==============================================================================
 * test_uart_c.c: RISC-V VeeR EL2 C-Based Firmware for UART Subsystem
 *
 * Objectives:
 *   1. Configure UART Baud Rate Divisor = 347 (115200 Baud @ 40 MHz) via DLAB.
 *   2. Set frame format: 8 data bits, no parity, 1 stop bit (8-N-1).
 *   3. Poll LSR.THRE (Transmitter Holding Register Empty) status.
 *   4. Transmit verification byte 'V' (0x56) over serial link.
 *   5. Log UART status and completion signature to DMEM.
 * ==============================================================================
 */

#include "soc_peripherals.h"

int main(void) {
    volatile uint32_t * const dmem = DMEM_PTR;

    /* Step 1: Disable interrupts during baud rate configuration */
    UART_REG_IER = 0x00U;

    /* Step 2: Enable Divisor Latch Access (DLAB = 1, 8-N-1: LCR = 0x83) */
    UART_REG_LCR = 0x83U;

    /* Step 3: Program Baud Divisor (347 for 115200 baud @ 40 MHz) */
    UART_REG_BAUD_DIV = UART_BAUD_115200;

    /* Step 4: Disable DLAB, lock 8-N-1 frame format (LCR = 0x03) */
    UART_REG_LCR = 0x03U;

    /* Step 5: Verify LSR THRE bit is asserted */
    uint32_t initial_lsr = UART_REG_LSR;
    dmem[0] = initial_lsr;

    if ((initial_lsr & UART_LSR_THRE) == 0U) {
        dmem[6] = SIG_FAIL_GLOBAL;
        return 1;
    }

    /* Step 6: Transmit verification byte 'V' (0x56) */
    UART_REG_THR = (uint32_t)'V';

    /* Step 7: Wait until TX completes (LSR.THRE is set) */
    while ((UART_REG_LSR & UART_LSR_THRE) == 0U) {
        /* Busy wait */
    }

    uint32_t post_tx_lsr = UART_REG_LSR;
    dmem[1] = post_tx_lsr;

    /* Step 8: Log signatures */
    dmem[2] = SIG_UART_PASS;
    dmem[6] = SIG_PASS_GLOBAL;

    return 0;
}
