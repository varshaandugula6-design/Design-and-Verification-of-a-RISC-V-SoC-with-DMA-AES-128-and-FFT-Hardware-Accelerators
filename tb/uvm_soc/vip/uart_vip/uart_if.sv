// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : UART UVM VIP (Corrected & Enhanced VIP)
// File         : uart_if.sv
// Description  : Interface for 16550 UART serial pins & interrupt line.
//                Supports serial injection (uart_rx_i) and reception (uart_tx_o).
//                Waveform observability signals for Verdi visibility.
// ==============================================================================

`ifndef UART_IF_SV
`define UART_IF_SV

interface uart_if (
    input logic clk,       // 100 MHz AXI system clock
    input logic fixed_clk, // 40 MHz dedicated UART baud clock
    input logic rst_n      // Active-low synchronous reset
);
    // Preserves signals from original uart_if.sv definition
    logic uart_tx_o; // Monitored serial TX stream driven by DUT uart_tx
    logic uart_rx_i; // Serial RX stream driven by VIP driver into DUT uart_rx

    // Monitored interrupt line from DUT uart_irq
    logic uart_irq;

    // -----------------------------------------------------------------------
    // UART DRIVER Waveform Observability Signals (Verdi/FSDB visibility)
    // These are driven by the uart_driver run_phase to expose internal state.
    // -----------------------------------------------------------------------
    logic       drv_active;          // HIGH while driver is serialising a byte
    logic [7:0] drv_tx_data;         // Current byte being serialised (latched at frame start)
    logic [3:0] drv_bit_index;       // Current bit position: 0-7=data, 8=stop, 9=idle
    logic [1:0] drv_state;           // 0=IDLE, 1=START, 2=DATA, 3=STOP
    logic [7:0] drv_tx_count;        // Rolling count of bytes serialised (wraps at 255)

    // -----------------------------------------------------------------------
    // UART MONITOR Waveform Observability Signals (Verdi/FSDB visibility)
    // These are driven by the uart_monitor run_phase to expose decoding state.
    // -----------------------------------------------------------------------
    logic       mon_capturing;       // HIGH while monitor is capturing a frame
    logic [7:0] mon_shift_reg;       // Shift register accumulating received bits
    logic [3:0] mon_bit_index;       // Current bit being sampled (0-7)
    logic [7:0] mon_decoded_byte;    // Last fully decoded byte (latched at frame end)
    logic       mon_framing_error;   // HIGH if last frame had a framing error
    logic [7:0] mon_rx_count;        // Rolling count of bytes captured (wraps at 255)

    // -----------------------------------------------------------------------
    // UART SCOREBOARD Waveform Observability Signals (Verdi/FSDB visibility)
    // These are driven by the uart_scoreboard write() to expose comparison state.
    // -----------------------------------------------------------------------
    logic [7:0] sb_expected_byte;    // Expected byte popped from queue
    logic [7:0] sb_actual_byte;      // Actual byte received in write()
    logic       sb_match;            // 1 = Match, 0 = Mismatch
    logic       sb_check_valid;      // Active during payload check
    logic [7:0] sb_total_checks;     // Running count of scoreboard checks

endinterface

`endif // UART_IF_SV
