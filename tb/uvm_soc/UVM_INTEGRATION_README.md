# SoC UVM VIP Verification Environment Guide

**Project:** RISC-V SoC with DMA, AES-128, and FFT Hardware Accelerators  
**Verification Suite:** UVM 1.2 Multi-VIP Environment (GPIO, UART, PWM)  
**Location:** `tb/uvm_soc/` (physically located at `CBP/tb/uvm_soc/`)  
**Target Simulator:** Synopsys VCS U-2023.03 (64-bit) & Verdi  

---

## 1. Executive Summary

This directory contains the complete, self-contained, and non-intrusive **UVM Verification Environment** for verifying the peripheral subsystems of the integrated RISC-V System-on-Chip.

The environment integrates three dedicated Verification IPs (VIPs):
1. **GPIO UVM VIP** (`vip/gpio_vip/`): 32-bit bidirectional tri-state pin stimulus, atomic set/clear/toggle verification, and interrupt monitoring.
2. **UART UVM VIP** (`vip/uart_vip/`): 16550-compatible serial frame injection (TX) and reception (RX) at 115200 Baud with independent 40 MHz clock domain timing.
3. **PWM UVM VIP** (`vip/pwm_vip/`): Non-intrusive timing monitor measuring period, pulse width, frequency, and duty cycle accuracy of the Real-Time Timer PWM output.

> **CRITICAL ARCHITECTURAL GUARANTEE:**  
> All existing project RTL files (`main_top.v`, peripheral RTL), manual testbenches, and original VIP stubs remain **100% UNCHANGED and READ-ONLY**. All corrected VIP implementations, scoreboards, virtual sequencers, environment classes, and compile scripts reside exclusively inside `tb/uvm_soc/`.

---

## 2. Directory Structure

```text
tb/uvm_soc/
├── VIP_DUT_CONNECTIVITY.md       # Pin-by-pin mapping specification to main_top.v
├── UVM_INTEGRATION_README.md     # This comprehensive architecture and user guide
├── soc_uvm_compile.f             # Complete VCS compilation filelist
├── tb_soc_uvm_top.sv             # Top-level testbench module instantiating DUT & VIPs
├── soc_uvm_env.sv                # UVM Environment binding agents, scoreboards & sequencers
├── soc_uvm_test.sv               # Multi-phase coordinated UVM verification test suite
├── soc_virtual_sequencer.sv      # Virtual sequencer coordinating GPIO, UART & PWM sequencers
├── soc_ctrl_if.sv                # Single-beat AXI4 master BFM interface for register access
├── axi_ram_slave.sv              # Dual-port 128KB burst-capable AXI4 RAM model (IMEM & DMEM)
├── twiddle1024.mem               # Symlink to twiddle coefficients for FFT initialization
├── vip/
│   ├── gpio_vip/                 # Corrected & Enhanced GPIO VIP
│   │   ├── gpio_if.sv            # Tri-state bidirectional interface & IRQ line
│   │   ├── gpio_item.sv          # GPIO transaction class (DRIVE, RELEASE, SAMPLE)
│   │   ├── gpio_sequencer.sv     # Sequencer
│   │   ├── gpio_driver.sv        # Active tri-state bus driver
│   │   ├── gpio_monitor.sv       # Bus level & edge-sensitive monitor
│   │   ├── gpio_agent.sv         # UVM Agent encapsulating driver, monitor, sequencer
│   │   └── gpio_pkg.sv           # GPIO VIP package
│   ├── uart_vip/                 # Corrected & Enhanced UART VIP
│   │   ├── uart_if.sv            # Serial RX/TX and IRQ interface (dual-clock)
│   │   ├── uart_item.sv          # Serial frame transaction class (8-N-1)
│   │   ├── uart_sequencer.sv     # Sequencer
│   │   ├── uart_driver.sv        # Serial bit-stream generator for uart_rx
│   │   ├── uart_monitor.sv       # Center-sample serial frame decoder for uart_tx
│   │   ├── uart_agent.sv         # UVM Agent encapsulating driver, monitor, sequencer
│   │   └── uart_pkg.sv           # UART VIP package
│   └── pwm_vip/                  # Corrected & Enhanced PWM VIP
│       ├── pwm_if.sv             # Timer PWM waveform and IRQ interface
│       ├── pwm_item.sv           # Waveform timing metrics (period, duty cycle, frequency)
│       ├── pwm_sequencer.sv      # Sequencer
│       ├── pwm_driver.sv         # Passive driver
│       ├── pwm_monitor.sv        # Edge detection and pulse duty-cycle measurement
│       ├── pwm_agent.sv          # UVM Agent (passive monitoring)
│       └── pwm_pkg.sv            # PWM VIP package
├── scoreboards/
│   ├── gpio_scoreboard.sv        # Output data match & IRQ assertion checking
│   ├── uart_scoreboard.sv        # Serial frame & character payload checking
│   └── pwm_scoreboard.sv        # Duty cycle percentage tolerance checking (±5%)
└── sequences/
    ├── gpio_sequence.sv          # Directed & pattern-based GPIO sequences
    ├── uart_sequence.sv          # Serial injection sequences
    ├── pwm_sequence.sv           # Passive PWM coordination sequence
    └── soc_virtual_sequence.sv   # Virtual sequence orchestrating multi-peripheral scenarios
```

---

## 3. UVM VIP Implementation Details

### 3.1 GPIO VIP
- **Interface:** `gpio_if.sv` handles the physical 32-bit `inout` port `gpio_io[31:0]`.
- **Driver:** Employs tri-state logic: drives `gpio_in[i]` when `gpio_oe[i] == 1'b1`; releases to `1'bz` when `gpio_oe[i] == 1'b0`. This guarantees zero bus contention when DUT pins operate in output mode.
- **Monitor:** Continuously tracks transitions on `gpio_io` and captures interrupts on `gpio_irq`.
- **Scoreboard:** Validates direct output writes, atomic set (`GPIO_SET_O`), atomic clear (`GPIO_CLR_O`), and atomic toggle (`GPIO_TGL_O`).

### 3.2 UART VIP
- **Interface:** `uart_if.sv` provides `uart_rx_i` (stimulus) and `uart_tx_o` (monitored).
- **Driver:** Transmits standard 8-N-1 asynchronous frames (1 start bit, 8 data bits LSB first, no parity, 1 stop bit) at 115200 Baud using 347 cycles of `fixed_clk` (40 MHz).
- **Monitor:** Features falling-edge start-bit detection, 0.5-bit center alignment, and stop-bit framing validation.
- **Scoreboard:** Compares decoded bytes against an expected FIFO queue.

### 3.3 PWM VIP
- **Interface:** `pwm_if.sv` monitors `timer_pwm` and `timer_irq`.
- **Monitor:** Records rising and falling edge timestamps (`t_rise1`, `t_fall`, `t_rise2`) using the 100 MHz reference clock. Computes:
  $$\text{Duty Cycle} = \frac{T_{\text{high}}}{T_{\text{period}}} \times 100\%$$
- **Scoreboard:** Verifies measured duty cycle against programmed `TIMER_CMP` setting within a $\pm 5\%$ tolerance window.

---

## 4. Test Suite Execution Phases (`soc_uvm_test`)

The top test sequence executes five structured verification phases:

1. **Phase 1: Reset & Interconnect Initialization**
   - Asserts and deasserts synchronous system reset.
   - Confirms AXI interconnect ready status and memory model responsiveness.
2. **Phase 2: GPIO Subsystem Verification**
   - Configures `GPIO_DIR` for output mode (lower 16 pins).
   - Verifies direct register write (`0x0000_A55A`) and pattern verification.
   - Tests atomic bit manipulation: `GPIO_SET_O`, `GPIO_CLR_O`, `GPIO_TGL_O`.
   - Reconfigures upper 16 pins for input mode and drives external VIP stimulus (`0x5A5A_0000`), verifying correct readback via `GPIO_DATA_I`.
   - Enables edge interrupts and validates `gpio_irq` assertion.
3. **Phase 3: UART Subsystem Verification**
   - Programs baud rate divisor (DLAB=1, Divisor=347 for 115200 Baud).
   - Enables TX/RX FIFOs and interrupts (`IER`).
   - DUT Transmit Test: Writes characters (`0x41` 'A', `0x42` 'B') to `UART_THR`; VIP Monitor decodes and scoreboard verifies frame integrity.
   - DUT Receive Test: VIP Driver injects serial bytes (`0xA5`, `0x5A`) on `uart_rx`; reads back from `UART_RBR` via AXI BFM.
4. **Phase 4: Real-Time Timer / PWM Verification**
   - Configures Timer for periodic PWM mode (`TIMER_CTRL = 0x13`).
   - Sets period `TIMER_LOAD = 1000` cycles (10 µs period).
   - Test 4.1: High threshold `TIMER_CMP = 500` (50% duty cycle). VIP measures and verifies ~50.0%.
   - Test 4.2: High threshold `TIMER_CMP = 250` (25% duty cycle). VIP measures and verifies ~25.0%.
   - Test 4.3: Disables timer and confirms PWM output halts cleanly.
5. **Phase 5: Coordinated Virtual Sequence**
   - Virtual sequence runs coordinated concurrent operations across GPIO, UART, and PWM.

---

## 5. Compilation & Simulation Instructions

Execute the following commands from the `tb/uvm_soc/` directory:

### Step 1: VCS Compilation
```bash
cd /home/student/Documents/honours_121/CBP/tb/uvm_soc
vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
    -f soc_uvm_compile.f \
    -top tb_soc_uvm_top \
    -o simv_uvm \
    -l compile_uvm.log
```

### Step 2: Simulation Execution
```bash
./simv_uvm +UVM_VERBOSITY=UVM_MEDIUM -l sim_uvm.log
```

### Step 3: Simulation with Waveform Dumping (Optional)
```bash
./simv_uvm +UVM_VERBOSITY=UVM_MEDIUM +FSDB -l sim_uvm.log
```

---

## 6. Pass/Fail Criteria

A run is declared **PASSED** when:
1. UVM Report Summary outputs:
   - `UVM_FATAL : 0`
   - `UVM_ERROR : 0`
2. GPIO Scoreboard reports all output pattern and atomic bit checks matched with zero errors.
3. UART Scoreboard reports all transmitted and received characters matched with zero framing errors.
4. PWM Scoreboard reports measured duty cycles match programmed thresholds within $\pm 5\%$.
