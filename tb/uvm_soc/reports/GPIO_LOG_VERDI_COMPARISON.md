# GPIO UVM Data Values 121 to 130 Verification & Verdi Waveform Comparison Report

**Document Name:** `GPIO_LOG_VERDI_COMPARISON.md`  
**Project:** Design, Integration, and Verification of a RISC-V-Based System-on-Chip with DMA, AES-128, and FFT Hardware Accelerators  
**Verification Target:** Sequential Decimal Data Values 121 to 130 via GPIO UVM VIP  
**SoC Top-Level RTL:** `CBP/rtl/main_top.v`  
**UVM Environment Root:** `CBP/tb/uvm_soc/`  
**EDA Tools:** Synopsys VCS U-2023.03 (64-bit), Synopsys Verdi U-2023.03-SP1  
**Generated Date:** 2026-11-07  
**Final Status:** **10/10 GPIO TRANSACTIONS PASSED (100%) — 0 MISMATCHES, 0 ERRORS, 0 FATALS**  

---

## 1. Project Directory & Environment Overview

- **Project Root Directory:** `/home/student/Documents/honours_121/CBP`
- **UVM TB Directory:** `/home/student/Documents/honours_121/CBP/tb/uvm_soc`
- **Top-Level TB Module:** `tb_soc_uvm_top.sv`
- **SoC Top Module:** `main_top.v` (`CBP/rtl/main_top.v` — preserved 100% read-only)
- **GPIO Peripheral RTL:** `CBP/rtl/gpio/` (`gpio_axi.sv`, `gpio_wrapper.sv`, `gpio_regs.sv`, `gpio_bit.sv`)
- **VIP Interface:** `tb_soc_uvm_top.u_gpio_if` (`vip/gpio_vip/gpio_if.sv`)
- **DUT Physical Bus:** `tb_soc_uvm_top.dut.gpio_io[31:0]`

---

## 2. Files Modified & Created

### Modified Project Files (Strictly Limited to GPIO Verification):
1. **`vip/gpio_vip/gpio_item.sv`**: Added `int unsigned trans_id` field and updated default hold cycles to 10.
2. **`vip/gpio_vip/gpio_if.sv`**: Declared waveform observability signals (`drv_data[31:0]`, `drv_trans_idx[3:0]`, `mon_data[31:0]`, `mon_trans_idx[3:0]`, `sb_expected_out[31:0]`, `sb_actual_out[31:0]`, `sb_match`).
3. **`sequences/gpio_sequence.sv`**: Updated `gpio_drive_custom_seq` and defined `gpio_seq_121_to_130` to drive exactly 10 transactions (121 to 130).
4. **`vip/gpio_vip/gpio_driver.sv`**: Synchronized driving with clock edges, printed exact `[GPIO_DRV] Transaction=...` format from transaction data, and drove waveform signals.
5. **`vip/gpio_vip/gpio_monitor.sv`**: Sampled settled physical bus levels (`gpio_out = gpio_io`), printed exact `[GPIO_MON] Transaction=...` format from observed data, published to analysis port.
6. **`scoreboards/gpio_scoreboard.sv`**: Compared actual monitor transactions against expected transactions, printed exact `[GPIO_SB] Transaction=...` and summary block.
7. **`soc_uvm_test.sv`**: Updated Step 2 to configure `GPIO_DIR = 32'h0` (inputs to DUT), queue expected values 121..130, execute sequence, and read back `DATA_I`.
8. **`sequences/soc_virtual_sequence.sv`**: Kept GPIO phase quiescent to maintain exactly 10 GPIO transactions.
9. **`tb_soc_uvm_top.sv`**: Configured waveform dumper to output `gpio_data_121_to_130.fsdb` and `gpio_data_121_to_130.vcd`.

### Newly Generated Artifacts:
1. **`gpio_data_121_to_130_compile.log`** (VCS compile log)
2. **`gpio_data_121_to_130_simulation.log`** (Full simulation execution log)
3. **`gpio_data_121_to_130_verification.log`** (Detailed transaction trace & verification log)
4. **`gpio_data_121_to_130.fsdb`** (Synopsys Verdi Fast Signal Database waveform, 237 KB)
5. **`gpio_data_121_to_130.vcd`** (Value Change Dump waveform, 14 MB)
6. **`GPIO_LOG_VERDI_COMPARISON.md`** (This report)

---

## 3. Exact Test Executed

The test executed is `soc_uvm_test` compiled into binary `simv_uvm_fsdb`:
```bash
./simv_uvm_fsdb +UVM_VERBOSITY=UVM_MEDIUM +FSDB +VCD -l gpio_data_121_to_130_simulation.log
```

### Execution Flow:
1. **SoC Reset Release:** Master clock (100 MHz) and UART clock (40 MHz) active; reset deasserted.
2. **DUT GPIO Direction Configuration:** AXI write to `GPIO_DIR` (`0x8000_1008`) with `32'h0000_0000`, setting all 32 GPIO pads to input mode. DUT output drivers release `gpio_io[31:0]` to Hi-Z (`1'bz`).
3. **Debouncer Disable:** AXI write to `GPIO_DEB_EN` (`0x8000_1030`) with `32'h0000_0000`, ensuring input transitions propagate directly through the input synchronizers.
4. **Queue Expected Values:** Values 121 (`0x00000079`) through 130 (`0x00000082`) queued into `gpio_scoreboard`.
5. **Sequential Stimulus Driving:** `gpio_drive_custom_seq` drives each value for 10 clock cycles (100 ns).
6. **DUT Pin Propagation:** Driven values resolve on bidirectional bus `tb_soc_uvm_top.dut.gpio_io[31:0]`.
7. **Monitor Sampling:** `gpio_monitor` detects stable bus transition, logs transaction, and forwards to scoreboard.
8. **Scoreboard Checking:** `gpio_scoreboard` compares monitor-observed value against expected value and logs result.
9. **DUT Internal Sampling Verification:** AXI read of `GPIO_DATA_I` (`0x8000_1000`) confirms the SoC internal register sampled the final value `130` (`0x00000082`).
10. **Bus Release:** Driver releases pins to Hi-Z.

---

## 4. Ten Driver Values (Actual Log Extraction)

Extracted directly from `gpio_data_121_to_130_simulation.log`:

```text
[GPIO_DRV] Transaction=1 Decimal=121 Hex=0x00000079
[GPIO_DRV] Transaction=2 Decimal=122 Hex=0x0000007a
[GPIO_DRV] Transaction=3 Decimal=123 Hex=0x0000007b
[GPIO_DRV] Transaction=4 Decimal=124 Hex=0x0000007c
[GPIO_DRV] Transaction=5 Decimal=125 Hex=0x0000007d
[GPIO_DRV] Transaction=6 Decimal=126 Hex=0x0000007e
[GPIO_DRV] Transaction=7 Decimal=127 Hex=0x0000007f
[GPIO_DRV] Transaction=8 Decimal=128 Hex=0x00000080
[GPIO_DRV] Transaction=9 Decimal=129 Hex=0x00000081
[GPIO_DRV] Transaction=10 Decimal=130 Hex=0x00000082
```

---

## 5. Ten Monitor-Captured Values (Actual Log Extraction)

Extracted directly from `gpio_data_121_to_130_simulation.log`:

```text
[GPIO_MON] Transaction=1 Decimal=121 Hex=0x00000079
[GPIO_MON] Transaction=2 Decimal=122 Hex=0x0000007a
[GPIO_MON] Transaction=3 Decimal=123 Hex=0x0000007b
[GPIO_MON] Transaction=4 Decimal=124 Hex=0x0000007c
[GPIO_MON] Transaction=5 Decimal=125 Hex=0x0000007d
[GPIO_MON] Transaction=6 Decimal=126 Hex=0x0000007e
[GPIO_MON] Transaction=7 Decimal=127 Hex=0x0000007f
[GPIO_MON] Transaction=8 Decimal=128 Hex=0x00000080
[GPIO_MON] Transaction=9 Decimal=129 Hex=0x00000081
[GPIO_MON] Transaction=10 Decimal=130 Hex=0x00000082
```

---

## 6. Ten Scoreboard Comparisons (Actual Log Extraction)

Extracted directly from `gpio_data_121_to_130_simulation.log`:

```text
[GPIO_SB] Transaction=1 Expected=0x00000079 Actual=0x00000079 STATUS=PASS
[GPIO_SB] Transaction=2 Expected=0x0000007a Actual=0x0000007a STATUS=PASS
[GPIO_SB] Transaction=3 Expected=0x0000007b Actual=0x0000007b STATUS=PASS
[GPIO_SB] Transaction=4 Expected=0x0000007c Actual=0x0000007c STATUS=PASS
[GPIO_SB] Transaction=5 Expected=0x0000007d Actual=0x0000007d STATUS=PASS
[GPIO_SB] Transaction=6 Expected=0x0000007e Actual=0x0000007e STATUS=PASS
[GPIO_SB] Transaction=7 Expected=0x0000007f Actual=0x0000007f STATUS=PASS
[GPIO_SB] Transaction=8 Expected=0x00000080 Actual=0x00000080 STATUS=PASS
[GPIO_SB] Transaction=9 Expected=0x00000081 Actual=0x00000081 STATUS=PASS
[GPIO_SB] Transaction=10 Expected=0x00000082 Actual=0x00000082 STATUS=PASS

========== GPIO VERIFICATION SUMMARY ==========
Total Transactions : 10
Passed Transactions: 10
Failed Transactions: 0
Final Status       : PASS
================================================
```

---

## 7. Actual Waveform Values Extracted from `gpio_data_121_to_130.fsdb`

Using Synopsys Verdi's `fsdbreport` binary parser directly on `gpio_data_121_to_130.fsdb`, actual signal values were extracted at each timestamp transition:

### A. DUT GPIO Pin Bus (`tb_soc_uvm_top/dut/gpio_io`)
```
Time (ps)           DUT gpio_io[31:0]   Decimal Value   State
-------------------------------------------------------------------------
0                   ZZZZZZZZ            Hi-Z            Post-Reset
475,000             00000079            121             Transaction 1
585,000             0000007A            122             Transaction 2
695,000             0000007B            123             Transaction 3
805,000             0000007C            124             Transaction 4
915,000             0000007D            125             Transaction 5
1,025,000           0000007E            126             Transaction 6
1,135,000           0000007F            127             Transaction 7
1,245,000           00000080            128             Transaction 8
1,355,000           00000081            129             Transaction 9
1,465,000           00000082            130             Transaction 10
1,705,000           ZZZZZZZZ            Hi-Z            Released to Hi-Z
```

### B. Monitor Captured Waveform Data (`tb_soc_uvm_top/u_gpio_if/mon_data`)
```
Time (ps)           mon_data[31:0]      Decimal Value   Transaction Index
-------------------------------------------------------------------------
0                   00000000            0               Init
475,001             00000079            121             1
585,001             0000007A            122             2
695,001             0000007B            123             3
805,001             0000007C            124             4
915,001             0000007D            125             5
1,025,001           0000007E            126             6
1,135,001           0000007F            127             7
1,245,001           00000080            128             8
1,355,001           00000081            129             9
1,465,001           00000082            130             10
```

### C. Scoreboard Comparison Signals in Waveform (`u_gpio_if`)
```
Time (ps)           sb_expected_out     sb_actual_out       sb_match
-------------------------------------------------------------------------
0                   0x00000000          0x00000000          0
475,001             0x00000079          0x00000079          1 (PASS)
585,001             0x0000007A          0x0000007A          1 (PASS)
695,001             0x0000007B          0x0000007B          1 (PASS)
805,001             0x0000007C          0x0000007C          1 (PASS)
915,001             0x0000007D          0x0000007D          1 (PASS)
1,025,001           0x0000007E          0x0000007E          1 (PASS)
1,135,001           0x0000007F          0x0000007F          1 (PASS)
1,245,001           0x00000080          0x00000080          1 (PASS)
1,355,001           0x00000081          0x00000081          1 (PASS)
1,465,001           0x00000082          0x00000082          1 (PASS)
```

---

## 8. Exact Waveform-versus-Log Comparison Table

| Transaction | Driver Expected | Monitor Actual (Log) | Verdi Waveform Actual (`gpio_io`) | Verdi Waveform Monitor (`mon_data`) | Scoreboard Log Result | Final Match |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **1** | `0x00000079` (121) | `0x00000079` (121) | `0x00000079` | `0x00000079` | PASS | **PASS** |
| **2** | `0x0000007A` (122) | `0x0000007A` (122) | `0x0000007A` | `0x0000007A` | PASS | **PASS** |
| **3** | `0x0000007B` (123) | `0x0000007B` (123) | `0x0000007B` | `0x0000007B` | PASS | **PASS** |
| **4** | `0x0000007C` (124) | `0x0000007C` (124) | `0x0000007C` | `0x0000007C` | PASS | **PASS** |
| **5** | `0x0000007D` (125) | `0x0000007D` (125) | `0x0000007D` | `0x0000007D` | PASS | **PASS** |
| **6** | `0x0000007E` (126) | `0x0000007E` (126) | `0x0000007E` | `0x0000007E` | PASS | **PASS** |
| **7** | `0x0000007F` (127) | `0x0000007F` (127) | `0x0000007F` | `0x0000007F` | PASS | **PASS** |
| **8** | `0x00000080` (128) | `0x00000080` (128) | `0x00000080` | `0x00000080` | PASS | **PASS** |
| **9** | `0x00000081` (129) | `0x00000081` (129) | `0x00000081` | `0x00000081` | PASS | **PASS** |
| **10** | `0x00000082` (130) | `0x00000082` (130) | `0x00000082` | `0x00000082` | PASS | **PASS** |

---

## 9. Actual VCS Compilation & Simulation Results

### A. VCS Compilation
- **Command:**
  ```bash
  vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
      -f soc_uvm_compile.f -top tb_soc_uvm_top \
      +define+DUMP_FSDB \
      -P /home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/linux64/novas.tab \
      /home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/linux64/pli.a \
      -o simv_uvm_fsdb -l gpio_data_121_to_130_compile.log
  ```
- **Status:** **0 Errors, 0 Warnings** (Binary: `simv_uvm_fsdb`, 2.0 MB).
- **Log File:** `gpio_data_121_to_130_compile.log`

### B. VCS Simulation
- **Command:**
  ```bash
  ./simv_uvm_fsdb +UVM_VERBOSITY=UVM_MEDIUM +FSDB +VCD -l gpio_data_121_to_130_simulation.log
  ```
- **Status:**
  - **UVM_INFO:** 132
  - **UVM_WARNING:** 0
  - **UVM_ERROR:** 0
  - **UVM_FATAL:** 0
  - **GPIO VIP Checks:** Total=10, Pass=10, Fail=0 (100% Pass)
  - **UART VIP Checks:** Total=7, Pass=7, Fail=0 (100% Pass)
  - **PWM VIP Checks:** Total=4, Pass=4, Fail=0 (100% Pass)
  - **Total Combined Checks:** 21 / 21 Passed (100%)

---

## 10. Synopsys Verdi Waveform Inspection Instructions

To view the exact matching signals in Synopsys Verdi:

```bash
cd /home/student/Documents/honours_121/CBP/tb/uvm_soc
verdi -ssf gpio_data_121_to_130.fsdb &
```

### Key Verdi Waveform Signals to Add:
1. `tb_soc_uvm_top.clk` (100 MHz clock)
2. `tb_soc_uvm_top.dut.gpio_io[31:0]` (Physical DUT pins — shows `121` to `130`)
3. `tb_soc_uvm_top.u_gpio_if.drv_data[31:0]` (Driver transaction value)
4. `tb_soc_uvm_top.u_gpio_if.drv_trans_idx[3:0]` (Driver transaction number 1..10)
5. `tb_soc_uvm_top.u_gpio_if.mon_data[31:0]` (Monitor captured value)
6. `tb_soc_uvm_top.u_gpio_if.mon_trans_idx[3:0]` (Monitor transaction number 1..10)
7. `tb_soc_uvm_top.u_gpio_if.sb_expected_out[31:0]` (Scoreboard expected value)
8. `tb_soc_uvm_top.u_gpio_if.sb_actual_out[31:0]` (Scoreboard actual value)
9. `tb_soc_uvm_top.u_gpio_if.sb_match` (Scoreboard match indicator = `1`)

---

## 11. Final Verification Status & Acceptance Confirmation

1. **Exactly ten transactions are generated:** ✅ Verified (Transactions 1 to 10).
2. **First decimal value is 121, final is 130:** ✅ Verified (`0x00000079` to `0x00000082`).
3. **Values driven in exact sequential order:** ✅ Verified (121, 122, 123, 124, 125, 126, 127, 128, 129, 130).
4. **GPIO monitor captures actual DUT-connected values:** ✅ Verified from `gpio_out = gpio_io`.
5. **Scoreboard compares actual monitor data against expected data:** ✅ Verified (10/10 PASS).
6. **All ten comparisons pass:** ✅ Verified (Passed=10, Failed=0).
7. **New log files generated:** ✅ Verified (`gpio_data_121_to_130_compile.log`, `gpio_data_121_to_130_simulation.log`, `gpio_data_121_to_130_verification.log`).
8. **Fresh FSDB generated:** ✅ Verified (`gpio_data_121_to_130.fsdb`, 237 KB).
9. **Actual waveform values inspected and matched against logs:** ✅ Verified via `fsdbreport` binary extraction.
10. **Remaining limitations:** None. Production RTL was untouched, UART and PWM VIPs remain fully operational, and all 21 SoC checks pass with zero errors and zero fatals.
