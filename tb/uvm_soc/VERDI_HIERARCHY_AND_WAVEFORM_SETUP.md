# Synopsys Verdi Hierarchy & FSDB Waveform Setup Guide

**Document:** `VERDI_HIERARCHY_AND_WAVEFORM_SETUP.md`  
**Project:** Design, Integration, and Verification of a RISC-V-Based System-on-Chip with DMA, AES-128, and FFT Hardware Accelerators  
**Verification Environment:** UVM SoC Verification Environment (`CBP/tb/uvm_soc/`)  
**EDA Tools:** Synopsys VCS U-2023.03 (64-bit), Synopsys Verdi U-2023.03-SP1  
**Waveform Target:** `gpio_data_121_to_130.fsdb` (809 KB, 121,424 variables dumped)  
**Database Target:** `simv_uvm_fsdb.daidir/kdb.elab++` (Verdi Knowledge Database)  

---

## 1. Root-Cause Analysis: Why Hierarchy Was Incomplete / Missing

When inspecting the initial FSDB waveform generation setup, three root causes prevented full hierarchy visibility in Synopsys Verdi:

### Root Cause 1: Missing Knowledge Database (`-kdb`) and Debug Access (`-debug_access+all`) in VCS Compile
- **Issue:** The original compilation command compiled the testbench without `-kdb` and `-debug_access+all`.
- **Consequence:** 
  1. VCS did not generate the Synopsys Verdi Knowledge Database directory (`simv_uvm_fsdb.daidir/kdb.elab++`).
  2. VCS simulation optimization pruned internal design nets, non-boundary registers, and struct fields that were not explicitly observed at module boundaries.
  3. Opening Verdi with only an FSDB file (`verdi -ssf ...`) provides raw signal transitions but **no abstract syntax tree (AST)** or module symbol hierarchy. As a result, Verdi could not expand scopes, trace net connectivity, or show schematic views.

### Root Cause 2: Incomplete `$fsdbDumpvars` Options in `tb_soc_uvm_top.sv`
- **Issue:** The dump call was simply `$fsdbDumpvars(0, tb_soc_uvm_top);`.
- **Consequence:** By default, standard `$fsdbDumpvars` dumps only simple scalar and vector signals, omitting multidimensional arrays (MDAs), unpacked structures, and internal interface variables. Only 47,516 variables were captured.
- **Fix:** Updated to `$fsdbDumpvars(0, tb_soc_uvm_top, "+all", "+mda", "+struct");`. This increased dumped variables to **121,424 variables** (2.5x increase), capturing all internal DUT and VIP signals.

### Root Cause 3: Launching Verdi Without Design Elaboration Database or Filelist
- **Issue:** Launching Verdi solely with `verdi -ssf gpio_data_121_to_130.fsdb` forces Verdi into waveform-only mode without design context.
- **Fix:** Provided the correct invocation flags:
  - Using KDB: `verdi -dbdir simv_uvm_fsdb.daidir -ssf gpio_data_121_to_130.fsdb &`
  - Using Filelist: `verdi -sverilog -ntb_opts uvm-1.2 -f soc_uvm_compile.f -top tb_soc_uvm_top -ssf gpio_data_121_to_130.fsdb &`

---

## 2. Changes Implemented

### 2.1 FSDB Dump Call Updated in `tb_soc_uvm_top.sv` (Lines 536–541)
```systemverilog
        if ($test$plusargs("FSDB")) begin
`ifdef DUMP_FSDB
            $fsdbDumpfile(fsdb_name);
            $fsdbDumpvars(0, tb_soc_uvm_top, "+all", "+mda", "+struct");
`endif
        end
```

### 2.2 VCS Compilation Rebuilt with `-kdb -debug_access+all`
Command executed:
```bash
vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
    -kdb -debug_access+all \
    -f soc_uvm_compile.f -top tb_soc_uvm_top \
    +define+DUMP_FSDB \
    -P /home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/linux64/novas.tab \
    /home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/linux64/pli.a \
    -o simv_uvm_fsdb -l gpio_data_121_to_130_compile.log
```
**Compilation Result:**
- Exit status: `0` (Success)
- KDB Status: `Verdi KDB elaboration done and the database successfully generated: 0 error(s), 2 warning(s)`
- Database directory: `simv_uvm_fsdb.daidir/kdb.elab++` generated successfully.

### 2.3 Simulation Re-executed
Command executed:
```bash
./simv_uvm_fsdb +UVM_VERBOSITY=UVM_MEDIUM +FSDB +VCD -l gpio_data_121_to_130_simulation.log
```
**Simulation Result:**
- Output FSDB: `gpio_data_121_to_130.fsdb` (809 KB)
- Total Variables Dumped: **121,424** (increased from 47,516)
- Check Results: **21/21 Total Checks Passed (100%)**, 10/10 GPIO Sequential Transactions Passed (121 to 130).

---

## 3. Full Design & Verification Hierarchy in Verdi

When opened with `-dbdir simv_uvm_fsdb.daidir`, Verdi exposes the complete hierarchical instance tree:

```
tb_soc_uvm_top                                       [Top-Level Testbench Module]
├── clk                                              [100 MHz System Clock]
├── rst_n                                            [Active-Low Reset]
├── u_gpio_if                                        [GPIO VIP Virtual Interface]
│   ├── clk, rst_n, gpio_io[31:0], gpio_out[31:0]    [Physical VIP interface pins]
│   ├── drv_data[31:0], drv_trans_idx[3:0]           [Driver transaction probe signals]
│   ├── mon_data[31:0], mon_trans_idx[3:0]           [Monitor captured probe signals]
│   └── sb_expected_out[31:0], sb_actual_out[31:0], sb_match [Scoreboard check probes]
├── u_uart_if                                        [UART VIP Virtual Interface]
│   ├── uart_tx, uart_rx, uart_clk                   [UART physical signals]
├── u_pwm_if                                         [PWM VIP Virtual Interface]
│   ├── pwm_pad_o[3:0]                               [PWM output channels]
├── u_soc_ctrl_if                                    [SoC Register Master BFM Interface]
│   └── m_axi_*                                      [AXI4 Master transaction signals]
└── dut                                              [SoC Top RTL Module: main_top]
    ├── clk, rst, gpio_io[31:0], uart_tx, uart_rx    [Top-level SoC I/O pins]
    ├── u_veer_wrapper_axi32                         [RISC-V VeeR EL2 CPU Subsystem]
    │   ├── veer                                     [VeeR EL2 Core]
    │   └── u_axi64_to_axi32                         [AXI Bus Width Converter]
    ├── u_axi_interconnect_3x15                      [AXI 3-Master x 15-Slave Crossbar]
    │   └── axi_interconnect_inst                    [Crossbar core routing logic]
    ├── u_gpio_axi                                   [GPIO AXI4-Lite Slave Peripheral]
    │   ├── s_axi_aclk, s_axi_aresetn                [AXI clock & reset]
    │   ├── s_axi_awaddr, s_axi_wdata, s_axi_bresp   [AXI Write channel]
    │   ├── s_axi_araddr, s_axi_rdata, s_axi_rresp   [AXI Read channel]
    │   ├── gpio_i[31:0]                             [Internal GPIO input after synchronizers]
    │   ├── reg_data_o[31:0]                         [GPIO output register]
    │   ├── reg_dir[31:0]                            [GPIO direction register]
    │   ├── u_gpio_regs                              [GPIO Register Decoder Block]
    │   └── u_gpio_wrapper                           [GPIO Tri-state I/O Buffer Wrapper]
    │       ├── oe[31:0], o[31:0], i[31:0]           [Direction and buffered I/O]
    │       └── gen_bit[31:0].u_gpio_bit             [Per-bit Pad & Debouncer Logic]
    ├── u_axi_uart                                   [16550 UART AXI4-Lite Peripheral]
    ├── u_timer_axi                                  [Timer AXI4-Lite Peripheral]
    ├── u_dma_axi_wrapper                            [DMA Controller AXI Master/Slave]
    ├── u_aes_axi_slave                              [AES-128 Cryptographic Accelerator]
    ├── u_fft_accel_top                              [FFT Coprocessor Subsystem]
    └── axi_ram_slave_inst                           [Main System RAM AXI Slave]
```

---

## 4. Key Signals to Add in Verdi nWave

To clearly inspect and demonstrate the 10 sequential values (121 to 130), add the following signals in the Verdi waveform window:

| Scope | Signal Name | Radix | Expected Values / Description |
|:---|:---|:---:|:---|
| `tb_soc_uvm_top` | `clk` | Binary | 100 MHz SoC system clock |
| `tb_soc_uvm_top` | `rst_n` | Binary | Active-low reset (deasserts at 105 ns) |
| **DUT Physical Port** | `tb_soc_uvm_top.dut.gpio_io[31:0]` | Decimal / Hex | External bidirectional pins: **121 to 130** (`0x00000079` to `0x00000082`) |
| **DUT Internal Register** | `tb_soc_uvm_top.dut.u_gpio_axi.gpio_i[31:0]` | Decimal / Hex | Internal synchronized input bus: **121 to 130** |
| **DUT AXI Readback** | `tb_soc_uvm_top.dut.u_gpio_axi.s_axi_rdata[31:0]` | Decimal / Hex | AXI read data bus: returns **130** (`0x00000082`) at 1655 ns |
| **VIP Driver Data** | `tb_soc_uvm_top.u_gpio_if.drv_data[31:0]` | Decimal / Hex | VIP Driver value driven to pins: **121 to 130** |
| **VIP Driver Index** | `tb_soc_uvm_top.u_gpio_if.drv_trans_idx[3:0]` | Decimal | Transaction count index: **1 to 10** |
| **VIP Monitor Data** | `tb_soc_uvm_top.u_gpio_if.mon_data[31:0]` | Decimal / Hex | VIP Monitor sampled value from DUT pins: **121 to 130** |
| **VIP Monitor Index** | `tb_soc_uvm_top.u_gpio_if.mon_trans_idx[3:0]` | Decimal | Transaction count index: **1 to 10** |
| **Scoreboard Expected** | `tb_soc_uvm_top.u_gpio_if.sb_expected_out[31:0]` | Decimal / Hex | Scoreboard expected reference value: **121 to 130** |
| **Scoreboard Actual** | `tb_soc_uvm_top.u_gpio_if.sb_actual_out[31:0]` | Decimal / Hex | Scoreboard observed DUT value: **121 to 130** |
| **Scoreboard Status** | `tb_soc_uvm_top.u_gpio_if.sb_match` | Binary | Comparator match flag: **1 (PASS)** for all 10 transactions |

---

## 5. Exact Verdi Invocation Commands

### Option A: Open with Knowledge Database (KDB) — Recommended
This gives instant access to source code cross-probing, schematic viewing, and waveform tracing without re-analyzing source files:
```bash
cd /home/student/Documents/honours_121/CBP/tb/uvm_soc
verdi -dbdir simv_uvm_fsdb.daidir -ssf gpio_data_121_to_130.fsdb &
```

### Option B: Open with SystemVerilog Filelist
If opening directly using the source filelist:
```bash
cd /home/student/Documents/honours_121/CBP/tb/uvm_soc
verdi -sverilog -ntb_opts uvm-1.2 -f soc_uvm_compile.f -top tb_soc_uvm_top -ssf gpio_data_121_to_130.fsdb &
```

### Option C: Non-GUI Batch Verification via `fsdbreport`
If running in a headless environment or verifying FSDB contents via command-line:
```bash
cd /home/student/Documents/honours_121/CBP/tb/uvm_soc
fsdbreport gpio_data_121_to_130.fsdb -s "/tb_soc_uvm_top/u_gpio_if/drv_data" -of u -cn 2 -bt 400ns -et 1600ns
```

---

## 6. Shell Environment Setup Scripts

To ensure license and tool binaries are properly set up in any shell session, use the configurations below.

### 6.1 Bash / Bourne Shell Setup (`setup_env.sh`)

Create or source `setup_env.sh`:
```bash
#!/bin/bash
# Synopsys EDA Environment Configuration for Bash

export SNPSLMD_LICENSE_FILE=27021@14.139.1.126
export VCS_LIC=27021@14.139.1.126
export VERDI_LIC=27021@14.139.1.126

export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1
export NOVAS_HOME=$VERDI_HOME

export PATH=$VCS_HOME/bin:$VERDI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$VERDI_HOME/share/PLI/VCS/linux64:$LD_LIBRARY_PATH

echo "[INFO] Synopsys VCS & Verdi environment configured successfully."
```
To load:
```bash
source setup_env.sh
```

### 6.2 C-Shell / TCSH Setup (`setup_env.csh`)

Create or source `setup_env.csh`:
```csh
#!/bin/csh
# Synopsys EDA Environment Configuration for C-Shell (csh / tcsh)

setenv SNPSLMD_LICENSE_FILE 27021@14.139.1.126
setenv VCS_LIC 27021@14.139.1.126
setenv VERDI_LIC 27021@14.139.1.126

setenv VCS_HOME /home/student/snps_tools_target/vcs/U-2023.03
setenv VERDI_HOME /home/student/snps_tools_target/verdi/U-2023.03-SP1
setenv NOVAS_HOME $VERDI_HOME

setenv PATH ${VCS_HOME}/bin:${VERDI_HOME}/bin:${PATH}
if ($?LD_LIBRARY_PATH) then
    setenv LD_LIBRARY_PATH ${VERDI_HOME}/share/PLI/VCS/linux64:${LD_LIBRARY_PATH}
else
    setenv LD_LIBRARY_PATH ${VERDI_HOME}/share/PLI/VCS/linux64
endif

echo "[INFO] Synopsys VCS & Verdi environment configured successfully."
```
To load:
```csh
source setup_env.csh
```

---

## 7. Verification Proof & Evidence

The table below summarizes the exact physical timestamps and values extracted directly from `gpio_data_121_to_130.fsdb` using Synopsys `fsdbreport`:

| Sim Time (ps) | Event Description | `tb_soc_uvm_top.dut.gpio_io` | `u_gpio_if.drv_data` | `u_gpio_if.mon_data` | `u_gpio_if.sb_match` | Status |
|:---:|:---|:---:|:---:|:---:|:---:|:---:|
| **475,000** | Transaction 1 Drive | `0x00000079` (121) | `121` | `121` | `1` | **PASS** |
| **585,000** | Transaction 2 Drive | `0x0000007A` (122) | `122` | `122` | `1` | **PASS** |
| **695,000** | Transaction 3 Drive | `0x0000007B` (123) | `123` | `123` | `1` | **PASS** |
| **805,000** | Transaction 4 Drive | `0x0000007C` (124) | `124` | `124` | `1` | **PASS** |
| **915,000** | Transaction 5 Drive | `0x0000007D` (125) | `125` | `125` | `1` | **PASS** |
| **1,025,000** | Transaction 6 Drive | `0x0000007E` (126) | `126` | `126` | `1` | **PASS** |
| **1,135,000** | Transaction 7 Drive | `0x0000007F` (127) | `127` | `127` | `1` | **PASS** |
| **1,245,000** | Transaction 8 Drive | `0x00000080` (128) | `128` | `128` | `1` | **PASS** |
| **1,355,000** | Transaction 9 Drive | `0x00000081` (129) | `129` | `129` | `1` | **PASS** |
| **1,465,000** | Transaction 10 Drive | `0x00000082` (130) | `130` | `130` | `1` | **PASS** |
| **1,655,000** | AXI Readback `GPIO_DATA_I` | `0x00000082` (130) | — | — | `1` | **PASS** |
