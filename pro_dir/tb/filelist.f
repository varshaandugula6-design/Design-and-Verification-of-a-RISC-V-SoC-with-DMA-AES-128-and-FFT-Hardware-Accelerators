// =============================================================================
// filelist.f — VCS compilation filelist for axi_interconnect_wrap_3x7 TB
//
// Compilation order:
//   1. RTL dependencies (Verilog 2001)
//   2. DUT wrapper
//   3. Testbench components (SystemVerilog)
//   4. Top-level (includes test tasks via `include)
//
// Usage:
//   vcs -full64 -sverilog -debug_access+all -f filelist.f -o simv
//   ./simv
// =============================================================================

// ---- RTL: core interconnect (Verilog 2001) ----
../rtl/interconnect/priority_encoder.v
../rtl/interconnect/arbiter.v
../rtl/interconnect/axi_interconnect.v

// ---- DUT wrapper ----
../scripts/axi_interconnect_wrap_3x7.v

// ---- Testbench components (SystemVerilog) ----
// Note: axi_if.sv is not instantiated directly — it provides the interface
// definition.  The BFMs and slave models use flat port connections to match
// the DUT's flat signal style, so axi_if.sv is included for completeness
// but not required for compilation of the current tb_top.
// Uncomment if you wish to use the interface in a modport-based variant:
// ./axi_if.sv

./axi_master_bfm.sv
./axi_slave_model.sv
./axi_scoreboard.sv
./axi_assertions.sv

// ---- Top-level (includes test tasks inline) ----
./tb_top.sv
