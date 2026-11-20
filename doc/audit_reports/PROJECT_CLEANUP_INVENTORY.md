# Project Cleanup Inventory Report

**Project:** Design, Integration, and Verification of a RISC-V-Based System-on-Chip with DMA, AES-128, and FFT Hardware Accelerators  
**Target Directory:** `/home/student/Documents/honours_121/CBP/`  
**UVM Verification Directory:** `/home/student/Documents/honours_121/CBP/tb/uvm_soc/`  
**Generated Date:** 2026-11-07  
**Inventory Scope:** Comprehensive audit of RTL, UVM Verification, Standalone TBs, Firmware, Scripts, Build Artifacts, Waveforms, and Logs.

---

## 1. Inventory Summary Table

| Category | Total Items | Retained (Keep) | Archival Candidates | Deletion Candidates |
|:---|:---:|:---:|:---:|:---:|
| **1. SoC RTL Source Files** | 12 Subdirectories | 12 Subdirectories (100%) | 0 | 0 |
| **2. Firmware & C Test Suite** | 67 Files | 67 Files (100%) | 0 | 0 |
| **3. Standalone Component TBs** | 4 Directories / 5 TBs | 4 Directories / 5 TBs (100%) | 0 | 0 |
| **4. UVM SoC Verification Sources** | 22 Source Files | 22 Source Files (100%) | 0 | 0 |
| **5. VCS Filelists & Configurations** | 8 Filelists / Scripts | 8 Filelists / Scripts (100%) | 0 | 0 |
| **6. Verification Evidence & FSDBs** | 24 Files | 24 Files (100%) | 0 | 0 |
| **7. Generated Build Binaries & Daidir**| 12 Targets | 2 Active Targets | 8 Obsolete Targets | 2 Obsolete Targets |
| **8. Duplicate Waveforms & Temp Files**| 11 Files | 0 | 4 Duplicate VCD/Bak | 7 Empty/Scratch Logs |

---

## 2. Comprehensive Inventory by Directory and File

### Category 1: RTL & Core Architecture (`CBP/rtl/`)

| File / Directory | Purpose | Dependency | Recommendation |
|:---|:---|:---:|:---:|
| `rtl/main_top.v` | SoC Top-Level Hardware Integration module | Production RTL Top; instantiated in all TBs | **KEEP (Preserve)** |
| `rtl/Cores-VeeR-EL2/` | Western Digital VeeR EL2 4-stage RISC-V RV32IMC Core Subsystem | Required for CPU execution and bus transactions | **KEEP (Preserve)** |
| `rtl/interconnect/` | 3 Master x 15 Slave AXI4 Interconnect Crossbar + Arbiters | Central SoC interconnect routing fabric | **KEEP (Preserve)** |
| `rtl/gpio/` | 32-bit Bidirectional GPIO Controller with AXI4-Lite Slave | Peripheral RTL verified by GPIO VIP | **KEEP (Preserve)** |
| `rtl/UART/` | 16550-compatible UART Controller with AXI4-Lite Slave | Peripheral RTL verified by UART VIP | **KEEP (Preserve)** |
| `rtl/timer/` | Dual 32-bit Timer / PWM Controller with AXI4-Lite Slave | Peripheral RTL verified by PWM VIP | **KEEP (Preserve)** |
| `rtl/DMA/` | Multi-channel Scatter-Gather DMA Controller (AXI Master & Slave)| High-throughput Direct Memory Access engine | **KEEP (Preserve)** |
| `rtl/verilog_aes/` | NIST FIPS-197 Compliant AES-128 Encryption/Decryption Core | Cryptographic hardware accelerator core | **KEEP (Preserve)** |
| `rtl/aes_axi_slave/` | AXI4 Full/Lite Memory-Mapped Adapters for AES Accelerator | Peripheral interface to AES core | **KEEP (Preserve)** |
| `rtl/fft_nexhus/` | 1024-point Radix-2/4 Complex FFT/IFFT Hardware Accelerator | Signal processing hardware coprocessor | **KEEP (Preserve)** |
| `rtl/common/` | AXI width adapters, converters, bridges, and protocol shims | Interconnect protocol adaptation | **KEEP (Preserve)** |

---

### Category 2: Firmware & C Test Suite (`CBP/firmware/`)

| File / Directory | Purpose | Dependency | Recommendation |
|:---|:---|:---:|:---:|
| `firmware/soc_c_test.c` | Bare-metal C verification program exercising SoC peripherals | Tested in firmware regression | **KEEP (Preserve)** |
| `firmware/soc_c_link.ld` | GNU Linker script mapping text, data, and stack to SoC memory | Required for compiling C tests | **KEEP (Preserve)** |
| `firmware/soc_c_crt0.s` | Startup bootstrap code setting up stack pointer and trap vectors | Required for C runtime entry | **KEEP (Preserve)** |
| `firmware/build_c_test.sh` | Shell script invoking RISC-V GCC toolchain | Script for regenerating ELF/HEX | **KEEP (Preserve)** |
| `firmware/soc_c_test.bin / .elf / .hex / .dis` | Compiled executable, memory image, and disassembly of C test | Firmware execution in memory models | **KEEP (Preserve)** |
| `firmware/soc_master_regression.*` | Comprehensive multi-peripheral regression firmware (`.s`, `.hex`, `.svh`) | Main manual regression test | **KEEP (Preserve)** |
| `firmware/test_aes.*`, `test_dma.*`, `test_fft.*`, `test_gpio.*`, `test_uart.*`, `test_timer.*`, `test_interrupts.*`, `test_concurrency.*` | Targeted assembly test programs and Verilog memory headers (`.s`, `.hex`, `.svh`) | Hardware verification suite | **KEEP (Preserve)** |
| `firmware/tests_final/` | Final unified C test suite for AES, DMA, FFT, UART, Boot, and Master (`.c`, `.elf`, `.hex`, `.dis`, `.sh`) | Final academic deliverable tests | **KEEP (Preserve)** |

---

### Category 3: Standalone Component Testbenches (`CBP/tb/`)

| File / Directory | Purpose | Dependency | Recommendation |
|:---|:---|:---:|:---:|
| `tb/tb_main_top.sv` | Complete SoC integration SystemVerilog manual testbench | Full SoC manual verification testbench | **KEEP (Preserve)** |
| `tb/tb_axi_interconnect_3x15.sv`| Standalone 3x15 AXI crossbar unit testbench | Interconnect unit verification | **KEEP (Preserve)** |
| `tb/tb_aes_integration.sv` | Standalone AES hardware accelerator integration testbench | AES unit verification | **KEEP (Preserve)** |
| `tb/tb_veer_standalone.sv` | Standalone RISC-V VeeR EL2 core unit testbench | CPU standalone verification | **KEEP (Preserve)** |
| `tb/axi_uart_tb.sv` | Standalone UART 16550 unit testbench | UART unit verification | **KEEP (Preserve)** |
| `tb/gpio_uvm_tb/` | Standalone GPIO UVM Verification IP package & component TB | Independent GPIO VIP archive | **KEEP (Preserve)** |
| `tb/uart_uvm_tb/` | Standalone UART UVM Verification IP package & component TB | Independent UART VIP archive | **KEEP (Preserve)** |
| `tb/pwm_uvm_tb/` | Standalone PWM UVM Verification IP package & component TB | Independent PWM VIP archive | **KEEP (Preserve)** |

---

### Category 4: UVM SoC Verification Environment (`CBP/tb/uvm_soc/`)

| File / Directory | Purpose | Dependency | Recommendation |
|:---|:---|:---:|:---:|
| `tb_soc_uvm_top.sv` | Top-level UVM Testbench module connecting DUT to VIP interfaces | Master UVM testbench top | **KEEP (Preserve)** |
| `soc_uvm_test.sv` | UVM Test class coordinating peripheral configurations and checks | Referenced by `run_test()` | **KEEP (Preserve)** |
| `soc_uvm_env.sv` | UVM Environment building agents, sequencers, and scoreboards | Instantiated in `soc_uvm_test` | **KEEP (Preserve)** |
| `soc_ctrl_if.sv` | SoC Control Master BFM Interface for AXI CSR read/write | Required for register configuration | **KEEP (Preserve)** |
| `axi_ram_slave.sv` | Synthesizable AXI4-Lite Dual-Port RAM Slave Model | Memory slave for SoC interconnect | **KEEP (Preserve)** |
| `soc_virtual_sequencer.sv`| UVM Virtual Sequencer referencing sub-agent sequencers | Coordinated sequence execution | **KEEP (Preserve)** |
| `twiddle1024.mem` | Symlink to `rtl/fft_nexhus/memory/twiddle1024.mem` | FFT ROM initialization | **KEEP (Preserve)** |
| `soc_uvm_compile.f` | Master VCS compilation filelist | VCS build filelist | **KEEP (Preserve)** |
| `setup_env.sh` / `setup_env.csh` | Synopsys VCS & Verdi environment setup scripts | Shell environment configuration | **KEEP (Preserve)** |
| `open_verdi_gpio.sh` | Automated shell script to open Verdi with preloaded signals | Quick inspection utility | **KEEP (Preserve)** |
| `gpio_signals_121_to_130.rc` | Verdi signal restore file mapping radix, cursor, and signals | Preloads GPIO signals in nWave | **KEEP (Preserve)** |
| `load_gpio_signals.cmd` | Verdi interactive command playback script | Verdi macro script | **KEEP (Preserve)** |
| `novas.conf`, `novas.rc` | Verdi window geometry and GUI configuration files | Verdi tool settings | **KEEP (Preserve)** |
| `verdi_config_file` | Verdi runtime setup file | Verdi tool settings | **KEEP (Preserve)** |
| `vip/gpio_vip/` | Complete GPIO UVM VIP (Agent, Driver, Monitor, Sequencer, Item, Pkg, Interface) | GPIO verification | **KEEP (Preserve)** |
| `vip/uart_vip/` | Complete UART UVM VIP (Agent, Driver, Monitor, Sequencer, Item, Pkg, Interface) | UART verification | **KEEP (Preserve)** |
| `vip/pwm_vip/` | Complete PWM UVM VIP (Agent, Driver, Monitor, Sequencer, Item, Pkg, Interface) | PWM verification | **KEEP (Preserve)** |
| `sequences/` | UVM Sequences (`gpio_sequence.sv`, `uart_sequence.sv`, `pwm_sequence.sv`, `soc_virtual_sequence.sv`) | Stimulus generation | **KEEP (Preserve)** |
| `scoreboards/` | UVM Scoreboards (`gpio_scoreboard.sv`, `uart_scoreboard.sv`, `pwm_scoreboard.sv`) | Self-checking comparators | **KEEP (Preserve)** |

---

### Category 5: Verification Evidence, Logs & Reports (`tb/uvm_soc/`)

| File / Directory | Purpose | Dependency | Recommendation |
|:---|:---|:---:|:---:|
| `gpio_data_121_to_130.fsdb` (809 KB) | Verdi FSDB Waveform containing 121,424 dumped variables with KDB | Primary verification waveform | **KEEP (Preserve)** |
| `soc_uvm.fsdb` (248 KB) | Initial SoC UVM VIP integration FSDB waveform | Baseline integration waveform | **KEEP (Preserve)** |
| `gpio_data_121_to_130_simulation.log` | Full simulation execution log of the 121..130 test suite | Simulation pass/fail evidence | **KEEP (Preserve)** |
| `gpio_data_121_to_130_verification.log` | Consolidated transaction trace table & comparison log | Formal verification report | **KEEP (Preserve)** |
| `gpio_data_121_to_130_compile.log` | VCS compilation log with KDB and debug flags | Build validation evidence | **KEEP (Preserve)** |
| `sim_uvm.log` | Baseline simulation log of initial VIP run | Referenced in prompt 3.D | **KEEP (Preserve)** |
| `sim_uvm_fsdb.log` | Initial FSDB simulation log | Referenced in prompt 3.D | **KEEP (Preserve)** |
| `logs/` | Directory archiving duplicate/synchronized test run logs | Clean log archive | **KEEP (Preserve)** |
| `reports/` | Directory containing signal report dumps and connectivity reports | Clean report archive | **KEEP (Preserve)** |
| `GPIO_LOG_VERDI_COMPARISON.md` | Formal Markdown comparison report between simulation and Verdi | Deliverable documentation | **KEEP (Preserve)** |
| `VERDI_HIERARCHY_AND_WAVEFORM_SETUP.md` | Comprehensive Verdi setup, hierarchy paths, and diagnostics | Deliverable documentation | **KEEP (Preserve)** |
| `UVM_INTEGRATION_README.md` | Architectural readme of the SoC UVM VIP integration | Deliverable documentation | **KEEP (Preserve)** |
| `VIP_DUT_CONNECTIVITY.md` | DUT port to VIP virtual interface pin connectivity specification | Deliverable documentation | **KEEP (Preserve)** |
| `VIP_VIRTUAL_INTERFACE_AND_WAVEFORM_VERIFICATION.md` | Comprehensive virtual interface verification report | Deliverable documentation | **KEEP (Preserve)** |

---

### Category 6: Simulation Binaries, Build Directories & Temporary Files (`tb/uvm_soc/`)

| File / Directory | Purpose | Size | Recommendation |
|:---|:---|:---:|:---:|
| `simv_uvm_fsdb` | Active VCS simulation executable (compiled with `-kdb`) | 2.1 MB | **KEEP (Preserve)** |
| `simv_uvm_fsdb.daidir/` | Active VCS simulation daidir containing `kdb.elab++` | 64 MB | **KEEP (Preserve)** |
| `gpio_data_121_to_130.vcd` | Massive plain text VCD dump from simulation; 100% duplicate of `gpio_data_121_to_130.fsdb` | **4.67 GB** | **DELETE / ARCHIVE** (Unnecessary duplicate; frees 4.67 GB) |
| `soc_uvm.vcd` | Plain text VCD dump from initial run; 100% duplicate of `soc_uvm.fsdb` | 14.4 MB | **DELETE / ARCHIVE** (Unnecessary duplicate) |
| `gpio_data_121_to_130.fsdb.bak` | Outdated incomplete backup of FSDB before dump options fix | 242 KB | **DELETE** (Outdated duplicate) |
| `simv_uvm` | Outdated VCS executable built before FSDB PLI and KDB were added | 1.9 MB | **ARCHIVE** (Superseded by `simv_uvm_fsdb`) |
| `simv_uvm.daidir/` | Outdated daidir directory built without KDB | 4 KB | **ARCHIVE** (Superseded by `simv_uvm_fsdb.daidir`) |
| `compile_uvm.log` | Outdated compile log from initial build | 69 KB | **ARCHIVE** (Superseded by `gpio_data_121_to_130_compile.log`) |
| `compile_uvm_fsdb.log` | Outdated intermediate compile log | 70 KB | **ARCHIVE** (Superseded by `gpio_data_121_to_130_compile.log`) |
| `sim_uvm_waveform.log` | Duplicate copy of `sim_uvm.log` | 27 KB | **ARCHIVE** (Redundant duplicate) |
| `ucli.key` | Empty zero-byte VCS interactive debugger key file | 0 B | **DELETE** (Unnecessary zero-byte artifact) |
| `tr_db.log` | VCS UVM transaction recording debug log | 8 KB | **DELETE / ARCHIVE** (Regeneratable debug output) |
| `novas_dump.log` | Verdi FSDB dumper low-level debug trace | 26 KB | **ARCHIVE** (Regeneratable debug output) |
| `vc_hdrs.h` | Auto-generated C header from VCS elaboration | 14 KB | **KEEP** (Clean, needed for recompilation) |
| `csrc/` | Intermediate VCS compilation object directory | 46 MB | **KEEP** (Maintains fast incremental compilation) |
| `verdiLog/` | Runtime directory generated by Verdi GUI sessions | 4 KB | **KEEP** (Contains active session configurations) |

---

### Category 7: Standalone Run Directory Artifacts (`CBP/run/`)

| File / Directory | Purpose | Size | Recommendation |
|:---|:---|:---:|:---:|
| `run/*.fsdb` (20 files) | Verification waveforms from manual testbenches (including `main_top.fsdb` [76 MB], `c_master_test.fsdb` [7.4 MB]) | ~140 MB | **KEEP (Preserve)** (Important verification evidence) |
| `run/*.log` (30 files) | Regression logs from manual testbench and C tests | ~1 MB | **KEEP (Preserve)** (Important verification evidence) |
| `run/run_integration.f`, `run_aes.f`, `run_main.f`, `run_veer_standalone.f` | VCS filelists for manual testbenches | ~15 KB | **KEEP (Preserve)** |
| `run/simv` & `simv.daidir/` | Latest manual testbench simulation executable | 2 MB | **KEEP (Preserve)** |
| `run/simv_aes`, `simv_aes_reg`, `simv_ic`, `simv_test`, `simv_uart`, `simv_veer_*` | Obsolete individual unit test simulation binaries & daidir directories from October runs | ~15 MB | **ARCHIVE** |
| `run/main_top.vcd` | Plain text VCD duplicate of `main_top.fsdb` | 198 KB | **DELETE / ARCHIVE** (Duplicate of `main_top.fsdb`) |
| `run/ucli.key` | Empty zero-byte VCS debugger key file | 0 B | **DELETE** |
| `run/csrc/` | Incremental compilation cache for manual testbenches | 24 MB | **KEEP** |
