/* ==============================================================================
 * soc_peripherals.h: Hardware Register Definitions & Memory Map for RISC-V SoC
 *
 * Project: Design, Integration, and Verification of a RISC-V-Based System-on-Chip
 *          with DMA, AES-128, and FFT Hardware Accelerators
 *
 * Verified against:
 *   - Interconnect: CBP/rtl/interconnect/axi_interconnect_wrap_3x15.v
 *   - Top Module:   CBP/rtl/main_top.v
 *   - AES:          CBP/rtl/aes_axi_slave/aes_axi_slave.sv
 *   - FFT:          CBP/rtl/fft_nexhus/fft_ctrl_axil.sv
 *   - DMA:          CBP/rtl/DMA/csr_dma.v
 *   - UART:         CBP/rtl/UART/include/axi_uart.vh
 *   - GPIO:         CBP/rtl/gpio/gpio_regs.sv
 *   - Timer:        CBP/rtl/timer/timer_regs.sv
 * ==============================================================================
 */

#ifndef SOC_PERIPHERALS_H_
#define SOC_PERIPHERALS_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* -----------------------------------------------------------------------------
 * 1. System Memory Map (Apertures & Base Addresses)
 * ----------------------------------------------------------------------------- */
#define IMEM_BASE           0x00040000U  /* S00: Instruction Memory (128 KB) */
#define DMEM_BASE           0x00080000U  /* S01: Data Memory (128 KB) */
#define GPIO_BASE           0x80001000U  /* S02: GPIO Controller (4 KB) */
#define TIMER_BASE          0x80002000U  /* S03: Real-Time Timer (4 KB) */
#define UART_BASE           0x80003000U  /* S04: UART Subsystem (4 KB) */
#define AES_BASE            0x80007000U  /* S05: AES-128 Accelerator (4 KB) */
#define FFT_CTRL_BASE       0x80008000U  /* S06: FFT Control Interface (4 KB) */
#define FFT_MEM_BASE        0x80009000U  /* S07: FFT Sample Memory (4 KB) */
#define DMA_CSR_BASE        0x80006000U  /* S13: DMA CSR Interface (4 KB) */

/* Pointer to Data Memory Base for Result Signatures */
#define DMEM_PTR            ((volatile uint32_t *)DMEM_BASE)

/* -----------------------------------------------------------------------------
 * 2. Verification Signatures
 * ----------------------------------------------------------------------------- */
#define SIG_PASS_GLOBAL     0xC001CAFEU  /* Standard C-Test Completion PASS */
#define SIG_FAIL_GLOBAL     0xDEADBEEFU  /* Failure Flag */
#define SIG_AES_KAT_PASS    0xAE510001U  /* AES KAT Completed Successfully */
#define SIG_FFT_PASS        0xFF700001U  /* FFT Transform Verification PASS */
#define SIG_DMA_PASS        0xD11A0001U  /* DMA Transfer Verification PASS */
#define SIG_UART_PASS       0x0A270001U  /* UART Baud/TX Verification PASS */
#define SIG_GPIO_PASS       0x60100001U  /* GPIO Pin Logic PASS */
#define SIG_TIMER_PASS      0x713E0001U  /* Timer Count/CMP PASS */
#define SIG_SOC_MASTER_PASS 0x55AA55AAU  /* Master Full Regression PASS */

/* -----------------------------------------------------------------------------
 * 3. GPIO Controller Registers (S02 / 0x8000_1000)
 * ----------------------------------------------------------------------------- */
#define GPIO_REG_DATA_I     (*(volatile uint32_t *)(GPIO_BASE + 0x00U))
#define GPIO_REG_DATA_O     (*(volatile uint32_t *)(GPIO_BASE + 0x04U))
#define GPIO_REG_DIR        (*(volatile uint32_t *)(GPIO_BASE + 0x08U))
#define GPIO_REG_INT_EN     (*(volatile uint32_t *)(GPIO_BASE + 0x0CU))
#define GPIO_REG_INT_TYP    (*(volatile uint32_t *)(GPIO_BASE + 0x10U))
#define GPIO_REG_INT_POL    (*(volatile uint32_t *)(GPIO_BASE + 0x14U))
#define GPIO_REG_INT_ANY    (*(volatile uint32_t *)(GPIO_BASE + 0x18U))
#define GPIO_REG_INT_STS    (*(volatile uint32_t *)(GPIO_BASE + 0x1CU))
#define GPIO_REG_SET_O      (*(volatile uint32_t *)(GPIO_BASE + 0x20U))
#define GPIO_REG_CLR_O      (*(volatile uint32_t *)(GPIO_BASE + 0x24U))
#define GPIO_REG_TGL_O      (*(volatile uint32_t *)(GPIO_BASE + 0x28U))
#define GPIO_REG_DEB_EN     (*(volatile uint32_t *)(GPIO_BASE + 0x30U))

/* -----------------------------------------------------------------------------
 * 4. Real-Time Timer Registers (S03 / 0x8000_2000)
 * ----------------------------------------------------------------------------- */
#define TIMER_REG_CTRL      (*(volatile uint32_t *)(TIMER_BASE + 0x00U))
#define TIMER_REG_LOAD      (*(volatile uint32_t *)(TIMER_BASE + 0x04U))
#define TIMER_REG_VAL       (*(volatile uint32_t *)(TIMER_BASE + 0x08U))
#define TIMER_REG_PRE       (*(volatile uint32_t *)(TIMER_BASE + 0x0CU))
#define TIMER_REG_INT_EN    (*(volatile uint32_t *)(TIMER_BASE + 0x10U))
#define TIMER_REG_INT_STS   (*(volatile uint32_t *)(TIMER_BASE + 0x14U))
#define TIMER_REG_CMP       (*(volatile uint32_t *)(TIMER_BASE + 0x18U))

/* -----------------------------------------------------------------------------
 * 5. UART Subsystem Registers (S04 / 0x8000_3000)
 * ----------------------------------------------------------------------------- */
#define UART_REG_RBR        (*(volatile uint32_t *)(UART_BASE + 0x00U)) /* Read: RX Buffer */
#define UART_REG_THR        (*(volatile uint32_t *)(UART_BASE + 0x00U)) /* Write: TX Holding */
#define UART_REG_IER        (*(volatile uint32_t *)(UART_BASE + 0x04U)) /* Interrupt Enable */
#define UART_REG_BAUD_DIV   (*(volatile uint32_t *)(UART_BASE + 0x08U)) /* Baud Rate Divisor */
#define UART_REG_LCR        (*(volatile uint32_t *)(UART_BASE + 0x0CU)) /* Line Control */
#define UART_REG_LSR        (*(volatile uint32_t *)(UART_BASE + 0x14U)) /* Line Status */

#define UART_LSR_DATA_READY (1U << 0)
#define UART_LSR_THRE       (1U << 5)  /* Transmitter Holding Reg Empty */
#define UART_LSR_TEMT       (1U << 6)  /* Transmitter Completely Empty */
#define UART_BAUD_115200    347U       /* 40 MHz / 115200 baud divisor */

/* -----------------------------------------------------------------------------
 * 6. AES-128 Hardware Accelerator Registers (S05 / 0x8000_7000)
 * ----------------------------------------------------------------------------- */
#define AES_REG_CSR         (*(volatile uint32_t *)(AES_BASE + 0x00U))
#define AES_REG_KEY0        (*(volatile uint32_t *)(AES_BASE + 0x04U))
#define AES_REG_KEY1        (*(volatile uint32_t *)(AES_BASE + 0x08U))
#define AES_REG_KEY2        (*(volatile uint32_t *)(AES_BASE + 0x0CU))
#define AES_REG_KEY3        (*(volatile uint32_t *)(AES_BASE + 0x10U))
#define AES_REG_TIN0        (*(volatile uint32_t *)(AES_BASE + 0x14U))
#define AES_REG_TIN1        (*(volatile uint32_t *)(AES_BASE + 0x18U))
#define AES_REG_TIN2        (*(volatile uint32_t *)(AES_BASE + 0x1CU))
#define AES_REG_TIN3        (*(volatile uint32_t *)(AES_BASE + 0x20U))
#define AES_REG_TOUT0       (*(volatile uint32_t *)(AES_BASE + 0x24U))
#define AES_REG_TOUT1       (*(volatile uint32_t *)(AES_BASE + 0x28U))
#define AES_REG_TOUT2       (*(volatile uint32_t *)(AES_BASE + 0x2CU))
#define AES_REG_TOUT3       (*(volatile uint32_t *)(AES_BASE + 0x30U))

#define AES_CSR_START       (1U << 0)
#define AES_CSR_DONE        (1U << 31)

/* Inverse Cipher (Decryption) Base */
#define AES_INV_BASE        0x80007100U
#define AES_INV_REG_CSR     (*(volatile uint32_t *)(AES_INV_BASE + 0x00U))
#define AES_INV_REG_KEY0    (*(volatile uint32_t *)(AES_INV_BASE + 0x04U))
#define AES_INV_REG_KEY1    (*(volatile uint32_t *)(AES_INV_BASE + 0x08U))
#define AES_INV_REG_KEY2    (*(volatile uint32_t *)(AES_INV_BASE + 0x0CU))
#define AES_INV_REG_KEY3    (*(volatile uint32_t *)(AES_INV_BASE + 0x10U))
#define AES_INV_REG_TIN0    (*(volatile uint32_t *)(AES_INV_BASE + 0x14U))
#define AES_INV_REG_TIN1    (*(volatile uint32_t *)(AES_INV_BASE + 0x18U))
#define AES_INV_REG_TIN2    (*(volatile uint32_t *)(AES_INV_BASE + 0x1CU))
#define AES_INV_REG_TIN3    (*(volatile uint32_t *)(AES_INV_BASE + 0x20U))
#define AES_INV_REG_TOUT0   (*(volatile uint32_t *)(AES_INV_BASE + 0x24U))
#define AES_INV_REG_TOUT1   (*(volatile uint32_t *)(AES_INV_BASE + 0x28U))
#define AES_INV_REG_TOUT2   (*(volatile uint32_t *)(AES_INV_BASE + 0x2CU))
#define AES_INV_REG_TOUT3   (*(volatile uint32_t *)(AES_INV_BASE + 0x30U))

/* -----------------------------------------------------------------------------
 * 7. FFT Hardware Accelerator Registers (S06 & S07)
 * ----------------------------------------------------------------------------- */
#define FFT_REG_CTRL        (*(volatile uint32_t *)(FFT_CTRL_BASE + 0x00U))
#define FFT_REG_STATUS      (*(volatile uint32_t *)(FFT_CTRL_BASE + 0x04U))

#define FFT_CTRL_START      (1U << 0)
#define FFT_STATUS_DONE     (1U << 0)

/* FFT Sample Memory Access: 1024 words (each contains [31:16]=Imag, [15:0]=Real) */
#define FFT_SAMPLE_RAM(idx) (*(volatile uint32_t *)(FFT_MEM_BASE + ((idx) * 4U)))

/* -----------------------------------------------------------------------------
 * 8. DMA Controller CSR Registers (S13 / 0x8000_6000)
 * ----------------------------------------------------------------------------- */
#define DMA_REG_CONTROL     (*(volatile uint32_t *)(DMA_CSR_BASE + 0x00U))
#define DMA_REG_STATUS      (*(volatile uint32_t *)(DMA_CSR_BASE + 0x08U))
#define DMA_REG_ERR_STATUS  (*(volatile uint32_t *)(DMA_CSR_BASE + 0x18U))
#define DMA_REG_DESC0_SRC   (*(volatile uint32_t *)(DMA_CSR_BASE + 0x20U))
#define DMA_REG_DESC0_DST   (*(volatile uint32_t *)(DMA_CSR_BASE + 0x30U))
#define DMA_REG_DESC0_BYTES (*(volatile uint32_t *)(DMA_CSR_BASE + 0x40U))
#define DMA_REG_DESC0_CFG   (*(volatile uint32_t *)(DMA_CSR_BASE + 0x50U))

#define DMA_CTRL_GO         (1U << 0)
#define DMA_CTRL_BURST4     (1U << 4)  /* max burst 4 beats */
#define DMA_STATUS_DONE     (1U << 16)
#define DMA_DESC_CFG_EN     (1U << 2)  /* Descriptor enable bit */

#ifdef __cplusplus
}
#endif

#endif /* SOC_PERIPHERALS_H_ */
