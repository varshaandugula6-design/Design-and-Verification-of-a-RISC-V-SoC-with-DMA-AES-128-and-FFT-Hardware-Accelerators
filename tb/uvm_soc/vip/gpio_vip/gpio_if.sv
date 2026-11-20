// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : GPIO UVM VIP (Corrected & Enhanced VIP)
// File         : gpio_if.sv
// Description  : Interface for 32-bit bidirectional General Purpose I/O.
//                Supports driving inputs to DUT and monitoring DUT outputs.
//                Waveform observability signals for Verdi visibility.
// ==============================================================================

`ifndef GPIO_IF_SV
`define GPIO_IF_SV

interface gpio_if (
    input logic clk,
    input logic rst_n
);
    // Signals corresponding to existing VIP definition
    logic [31:0] gpio_in;   // Stimulus driven by VIP Driver to DUT input pins
    logic [31:0] gpio_out;  // Monitored pin states (DUT outputs or active levels)
    logic [31:0] gpio_oe;   // Output enable driven by VIP Driver (1=Drive, 0=Hi-Z)

    // Physical bidirectional bus connected to DUT gpio_io[31:0]
    wire  [31:0] gpio_io;

    // Interrupt signal monitored from DUT
    logic        gpio_irq;

    // Tri-state buffer modeling physical off-chip driver:
    // When VIP driver asserts gpio_oe[i], it drives gpio_in[i] onto gpio_io[i].
    // Otherwise, the pin floats at Hi-Z, allowing DUT to drive outputs.
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : gen_bidir_io
            assign gpio_io[i] = gpio_oe[i] ? gpio_in[i] : 1'bz;
        end
    endgenerate

    // Monitor continuously captures the resolved logic levels on the bus
    assign gpio_out = gpio_io;

    // -----------------------------------------------------------------------
    // GPIO DRIVER Waveform Observability Signals (Verdi/FSDB visibility)
    // -----------------------------------------------------------------------
    logic [1:0]  drv_op;          // Current operation: 00=DRIVE, 01=RELEASE, 10=SAMPLE
    logic        drv_active;      // HIGH while driver is executing a transaction
    logic [7:0]  drv_tx_count;    // Rolling count of GPIO transactions issued
    logic [31:0] drv_data;        // Current 32-bit data value driven by driver
    logic [3:0]  drv_trans_idx;   // Current transaction index (1..10)

    // -----------------------------------------------------------------------
    // GPIO MONITOR Waveform Observability Signals (Verdi/FSDB visibility)
    // -----------------------------------------------------------------------
    logic [7:0]  mon_rx_count;    // Rolling count of GPIO bus state changes captured
    logic        mon_irq_prev;    // Previous IRQ level (edge detection reference)
    logic [31:0] mon_data;        // Current 32-bit data value sampled by monitor
    logic [3:0]  mon_trans_idx;   // Current transaction index (1..10)

    // -----------------------------------------------------------------------
    // GPIO SCOREBOARD Waveform Observability Signals (Verdi/FSDB visibility)
    // -----------------------------------------------------------------------
    logic [31:0] sb_expected_out;     // Expected output value from test
    logic [31:0] sb_actual_out;       // Actual output value received in write()
    logic        sb_match;            // 1 = Match, 0 = Mismatch
    logic [7:0]  sb_total_checks;     // Running count of scoreboard checks

endinterface

`endif // GPIO_IF_SV
