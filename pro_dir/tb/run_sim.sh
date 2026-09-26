#!/bin/bash
# =============================================================================
# run_sim.sh — Build and run the axi_interconnect_wrap_3x7 testbench
#
# Usage:
#   ./run_sim.sh                    # compile + run with defaults
#   ./run_sim.sh compile            # compile only
#   ./run_sim.sh run                # run only (assumes simv exists)
#   ./run_sim.sh verdi              # open last VCD in Verdi
#   ./run_sim.sh clean              # remove build artefacts
#
# Simulation plusargs (pass after --):
#   +RAND_SEED=<n>   constrained-random seed   (default 42)
#   +RAND_ITER=<n>   number of random iters    (default 50)
#
# Example:
#   ./run_sim.sh -- +RAND_SEED=12345 +RAND_ITER=200
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# VCS flags
# ---------------------------------------------------------------------------
VCS_OPTS="\
  -full64 \
  -sverilog \
  -debug_access+all \
  +define+SIMULATION \
  -timescale=1ns/1ps \
  -notice \
  -override_timescale=1ns/1ps \
  -top tb_top"

# For Verdi / fsdb waveform support
# Remove or change to $dumpfile/$dumpvars if Verdi is not installed.
# The tb_top.sv uses $fsdbDumpfile which requires Verdi/FSDB library.
# If Verdi is not available, change to VCD:
#   In tb_top.sv replace $fsdbDumpfile with $dumpfile and $fsdbDumpvars with $dumpvars
VERDI_OPTS=""
if command -v verdi &>/dev/null; then
    VERDI_OPTS="-P \${NOVAS_HOME}/share/PLI/VCS/linux64/novas.tab \${NOVAS_HOME}/share/PLI/VCS/linux64/pli.a"
fi

SIM_BINARY="./simv"
LOG_FILE="./sim.log"

# ---------------------------------------------------------------------------
cmd=${1:-all}
shift || true

case "$cmd" in
# ---------------------------------------------------------------------------
compile|all)
    echo "==================================================================="
    echo " Compiling axi_interconnect_wrap_3x7 testbench with VCS"
    echo "==================================================================="
    vcs $VCS_OPTS $VERDI_OPTS \
        -f filelist.f \
        -o simv \
        2>&1 | tee compile.log

    echo ""
    if [ -f simv ]; then
        echo "Compilation SUCCEEDED — simv created"
    else
        echo "Compilation FAILED — check compile.log"
        exit 1
    fi

    if [ "$cmd" = "compile" ]; then
        exit 0
    fi
    ;;&     # fall through to run

run|all)
    echo ""
    echo "==================================================================="
    echo " Running simulation"
    echo "==================================================================="
    $SIM_BINARY "$@" \
        +RAND_SEED=42 \
        +RAND_ITER=50 \
        2>&1 | tee "$LOG_FILE"

    echo ""
    echo "==================================================================="
    echo " Simulation finished — log: $LOG_FILE"
    echo "==================================================================="

    # Grep for final result
    if grep -q "ALL TESTS PASSED" "$LOG_FILE"; then
        echo " RESULT: ALL TESTS PASSED"
        exit 0
    elif grep -q "SIMULATION FAILED" "$LOG_FILE"; then
        echo " RESULT: SIMULATION FAILED"
        grep "SIMULATION FAILED" "$LOG_FILE"
        exit 1
    else
        echo " RESULT: Unknown (check $LOG_FILE)"
        exit 1
    fi
    ;;

verdi)
    echo "Opening Verdi..."
    if [ -f tb_top.fsdb ]; then
        verdi -sv -f filelist.f -ssf tb_top.fsdb &
    else
        echo "No FSDB file found. Run simulation first."
        exit 1
    fi
    ;;

clean)
    echo "Cleaning build artefacts..."
    rm -rf simv simv.daidir csrc DVEfiles ucli.key vc_hdrs.h
    rm -f compile.log sim.log tb_top.fsdb tb_top.vcd
    rm -f inter.vpd vcdplus.vpd
    echo "Done."
    ;;

help|*)
    echo "Usage: $0 [compile|run|all|verdi|clean] [-- plusargs...]"
    ;;
esac
