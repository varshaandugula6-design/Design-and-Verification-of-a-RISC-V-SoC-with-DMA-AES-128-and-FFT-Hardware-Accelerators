// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// Environment  : SoC UVM Verification Environment
// File         : soc_uvm_compile.f
// Description  : VCS Compilation filelist for tb_soc_uvm_top with GPIO, UART & PWM VIPs.
// ==============================================================================

// VeeR EL2 configuration defines and include paths
+define+RV_OPENSOURCE
+incdir+../../rtl/Cores-VeeR-EL2/snapshots/default
+incdir+../../rtl/Cores-VeeR-EL2/design/include
+incdir+../../rtl/Cores-VeeR-EL2/design/lib
+incdir+../../rtl/Cores-VeeR-EL2/design/ifu
+incdir+../../rtl/Cores-VeeR-EL2/design/dec
+incdir+../../rtl/Cores-VeeR-EL2/design/dmi
+incdir+../../rtl/Cores-VeeR-EL2/design/lsu
+incdir+../../rtl/Cores-VeeR-EL2/design/exu
+incdir+../../rtl/common

// UART include headers
+incdir+../../rtl/UART/include

// AES include path for `include "timescale.v"
+incdir+../../rtl/verilog_aes

// DMA include path for dma_pkg.svh and rggen_rtl_macros.vh
+incdir+../../rtl/DMA

// UVM TB Include paths
+incdir+.
+incdir+vip/gpio_vip
+incdir+vip/uart_vip
+incdir+vip/pwm_vip
+incdir+scoreboards
+incdir+sequences

// ---- Interconnect RTL ----
../../rtl/interconnect/priority_encoder.v
../../rtl/interconnect/arbiter.v
../../rtl/interconnect/axi_interconnect.v
../../rtl/interconnect/axi_interconnect_wrap_3x15.v

// ---- UART RTL ----
../../rtl/UART/axi_internal_fifo.v
../../rtl/UART/uart_parity_bit_compute.v
../../rtl/UART/uart_transmitter.v
../../rtl/UART/uart_receiver.v
../../rtl/UART/uart_controller.v
../../rtl/UART/axi_uart_top.v

// ---- AES Core RTL (timescale.v listed first so `include finds it) ----
../../rtl/verilog_aes/timescale.v
../../rtl/verilog_aes/aes_rcon.v
../../rtl/verilog_aes/aes_sbox.v
../../rtl/verilog_aes/aes_inv_sbox.v
../../rtl/verilog_aes/aes_key_expand_128.v
../../rtl/verilog_aes/aes_cipher_top.v
../../rtl/verilog_aes/aes_inv_cipher_top.v

// ---- AES AXI Wrappers ----
../../rtl/aes_axi_slave/aes_axi_slave.sv
../../rtl/aes_axi_slave/aes_axi_slave_axi4.sv

// ---- FFT Leaf Primitives ----
../../rtl/fft_nexhus/xpm_memory_tdpram_model.sv
../../rtl/fft_nexhus/bram_memeory.sv
../../rtl/fft_nexhus/twiddle_rom.sv
../../rtl/fft_nexhus/add_sub_sat_s1_q15.sv
../../rtl/fft_nexhus/cmulq15.sv

// ---- FFT Butterfly / Stage Core ----
../../rtl/fft_nexhus/fft_atomic_p1.sv
../../rtl/fft_nexhus/fft_stage_core.sv
../../rtl/fft_nexhus/fft_stage_core_controller.sv

// ---- FFT Top-level Compute Engine ----
../../rtl/fft_nexhus/fft_top.sv
../../rtl/fft_nexhus/fft_loadstore_wrapper.sv

// ---- FFT AXI Control and Memory Slaves ----
../../rtl/fft_nexhus/fft_ctrl_axil.sv
../../rtl/fft_nexhus/fft_mem_axi4_slave.sv

// ---- FFT Accelerator Top ----
../../rtl/fft_nexhus/fft_accel_fft_top.sv

// ---- FFT SoC Integration Adapters (S6 bridge, S7 memory wrap) ----
../../rtl/fft_nexhus/fft_ctrl_axi4_bridge.sv
../../rtl/fft_nexhus/fft_mem_axi4_wrap.sv

// ---- DMA IP: Packages ----
../../rtl/DMA/amba_axi_pkg.sv
../../rtl/DMA/dma_utils_pkg.sv

// ---- DMA IP: rggen CSR Register Infrastructure ----
../../rtl/DMA/rggen_or_reducer.v
../../rtl/DMA/rggen_mux.v
../../rtl/DMA/rggen_bit_field.v
../../rtl/DMA/rggen_bit_field_w01trg.v
../../rtl/DMA/rggen_default_register.v
../../rtl/DMA/rggen_indirect_register.v
../../rtl/DMA/rggen_external_register.v
../../rtl/DMA/rggen_register_common.v
../../rtl/DMA/rggen_address_decoder.v
../../rtl/DMA/rggen_adapter_common.v
../../rtl/DMA/rggen_axi4lite_skid_buffer.v
../../rtl/DMA/rggen_axi4lite_bridge.v
../../rtl/DMA/rggen_axi4lite_adapter.v

// ---- DMA IP: CSR Register File ----
../../rtl/DMA/csr_dma.v

// ---- DMA IP: Functional Modules ----
../../rtl/DMA/dma_fifo.sv
../../rtl/DMA/dma_fsm.sv
../../rtl/DMA/dma_streamer.sv
../../rtl/DMA/dma_axi_if.sv
../../rtl/DMA/dma_func_wrapper.sv
../../rtl/DMA/dma_axi_wrapper.sv

// ---- VeeR EL2 Core RTL ----
../../rtl/Cores-VeeR-EL2/snapshots/default/common_defines.vh
../../rtl/Cores-VeeR-EL2/design/lib/el2_assert.sv
../../rtl/Cores-VeeR-EL2/design/el2_mubi_pkg.sv
../../rtl/Cores-VeeR-EL2/design/include/el2_def.sv
../../rtl/Cores-VeeR-EL2/design/el2_lockstep_pkg.sv
../../rtl/Cores-VeeR-EL2/design/lib/el2_mem_if.sv
../../rtl/Cores-VeeR-EL2/design/lib/beh_lib.sv
../../rtl/Cores-VeeR-EL2/design/lib/mem_lib.sv
../../rtl/Cores-VeeR-EL2/design/lib/el2_lib.sv
../../rtl/Cores-VeeR-EL2/design/el2_pmp.sv
../../rtl/Cores-VeeR-EL2/design/el2_pic_ctrl.sv
../../rtl/Cores-VeeR-EL2/design/el2_dma_ctrl.sv
../../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_aln_ctl.sv
../../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_compress_ctl.sv
../../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_ifc_ctl.sv
../../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_bp_ctl.sv
../../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_ic_mem.sv
../../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_mem_ctl.sv
../../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_iccm_mem.sv
../../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu.sv
../../rtl/Cores-VeeR-EL2/design/dec/el2_dec_decode_ctl.sv
../../rtl/Cores-VeeR-EL2/design/dec/el2_dec_gpr_ctl.sv
../../rtl/Cores-VeeR-EL2/design/dec/el2_dec_ib_ctl.sv
../../rtl/Cores-VeeR-EL2/design/dec/el2_dec_pmp_ctl.sv
../../rtl/Cores-VeeR-EL2/design/dec/el2_dec_tlu_ctl.sv
../../rtl/Cores-VeeR-EL2/design/dec/el2_dec_trigger.sv
../../rtl/Cores-VeeR-EL2/design/dec/el2_dec.sv
../../rtl/Cores-VeeR-EL2/design/exu/el2_exu_alu_ctl.sv
../../rtl/Cores-VeeR-EL2/design/exu/el2_exu_mul_ctl.sv
../../rtl/Cores-VeeR-EL2/design/exu/el2_exu_div_ctl.sv
../../rtl/Cores-VeeR-EL2/design/exu/el2_exu.sv
../../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_clkdomain.sv
../../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_addrcheck.sv
../../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_lsc_ctl.sv
../../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_stbuf.sv
../../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_bus_buffer.sv
../../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_bus_intf.sv
../../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_ecc.sv
../../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_dccm_mem.sv
../../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_dccm_ctl.sv
../../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_trigger.sv
../../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu.sv
../../rtl/Cores-VeeR-EL2/design/dbg/el2_dbg.sv
../../rtl/Cores-VeeR-EL2/design/dmi/dmi_mux.v
../../rtl/Cores-VeeR-EL2/design/dmi/dmi_wrapper.v
../../rtl/Cores-VeeR-EL2/design/dmi/dmi_jtag_to_core_sync.v
../../rtl/Cores-VeeR-EL2/design/dmi/rvjtag_tap.v
../../rtl/Cores-VeeR-EL2/design/lib/ahb_to_axi4.sv
../../rtl/Cores-VeeR-EL2/design/lib/axi4_to_ahb.sv
../../rtl/Cores-VeeR-EL2/design/el2_veer.sv
../../rtl/Cores-VeeR-EL2/design/el2_mem.sv
../../rtl/Cores-VeeR-EL2/design/el2_veer_wrapper.sv

// ---- VeeR AXI Adapters & 32-bit Wrapper ----
../../rtl/common/axi64_to_axi32_adapter.sv
../../rtl/veer_wrapper_axi32.sv

// ---- AXI4 to AXI4-Lite Bridge and Adapters ----
../../rtl/common/axi4lite_slave_adapter.sv
../../rtl/common/axi4_to_axi4lite_bridge.sv

// ---- GPIO IP RTL ----
../../rtl/gpio/gpio_bit.sv
../../rtl/gpio/gpio_wrapper.sv
../../rtl/gpio/gpio_regs.sv
../../rtl/gpio/gpio_axi.sv

// ---- Timer IP RTL ----
../../rtl/timer/timer_core.sv
../../rtl/timer/timer_regs.sv
../../rtl/timer/timer_axi.sv

// ---- SoC Top Module ----
../../rtl/main_top.v

// ---- Corrected UVM VIP Interfaces ----
vip/gpio_vip/gpio_if.sv
vip/uart_vip/uart_if.sv
vip/pwm_vip/pwm_if.sv

// ---- Corrected UVM VIP Packages ----
vip/gpio_vip/gpio_pkg.sv
vip/uart_vip/uart_pkg.sv
vip/pwm_vip/pwm_pkg.sv

// ---- Top-Level SoC UVM Testbench ----
tb_soc_uvm_top.sv
