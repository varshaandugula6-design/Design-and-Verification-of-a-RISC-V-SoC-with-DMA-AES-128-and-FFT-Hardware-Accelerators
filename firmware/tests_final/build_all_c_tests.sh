#!/bin/bash
# ==============================================================================
# build_all_c_tests.sh: Batch Build Script for All RISC-V SoC C Firmware Tests
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FW_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOOLCHAIN_PREFIX="/opt/riscv/bin/riscv64-unknown-elf-"

TESTS=(
    "test_boot_mem"
    "test_uart_c"
    "test_aes_c"
    "test_dma_c"
    "test_fft_c"
    "test_soc_master"
)

echo "================================================================================"
echo "          COMPILING FINAL RISC-V C-BASED FIRMWARE SUITE (rv32im / ilp32)        "
echo "================================================================================"
echo "Toolchain: ${TOOLCHAIN_PREFIX}gcc"
echo "Linker:    ${FW_DIR}/soc_c_link.ld"
echo "Startup:   ${FW_DIR}/soc_c_crt0.s"
echo "Headers:   ${SCRIPT_DIR}/soc_peripherals.h"
echo "--------------------------------------------------------------------------------"

for TEST_NAME in "${TESTS[@]}"; do
    echo ">>> Building ${TEST_NAME}..."
    
    # 1. Compile and link with rv32im / ilp32 / no-relax
    ${TOOLCHAIN_PREFIX}gcc \
        -march=rv32im \
        -mabi=ilp32 \
        -mno-relax \
        -O2 \
        -nostdlib \
        -ffreestanding \
        -Wall \
        -Wextra \
        -I"${SCRIPT_DIR}" \
        -T "${FW_DIR}/soc_c_link.ld" \
        "${FW_DIR}/soc_c_crt0.s" \
        "${SCRIPT_DIR}/${TEST_NAME}.c" \
        -o "${SCRIPT_DIR}/${TEST_NAME}.elf"
    
    # 2. Generate disassembly for audit and debug
    ${TOOLCHAIN_PREFIX}objdump -d -S "${SCRIPT_DIR}/${TEST_NAME}.elf" > "${SCRIPT_DIR}/${TEST_NAME}.dis"
    
    # 3. Extract pure text/rodata binary
    ${TOOLCHAIN_PREFIX}objcopy -O binary -j .text -j .rodata "${SCRIPT_DIR}/${TEST_NAME}.elf" "${SCRIPT_DIR}/${TEST_NAME}.bin"
    
    # 4. Generate Verilog $readmemh hex file (32-bit little-endian words)
    python3 -c "
with open('${SCRIPT_DIR}/${TEST_NAME}.bin', 'rb') as f:
    data = f.read()

lines = []
for i in range(0, len(data), 4):
    chunk = data[i:i+4]
    word = int.from_bytes(chunk.ljust(4, b'\x00'), byteorder='little')
    lines.append(f'{word:08x}\n')

with open('${SCRIPT_DIR}/${TEST_NAME}.hex', 'w') as f:
    f.writelines(lines)

print(f'    Generated {len(lines)} words ({len(data)} bytes) -> ${TEST_NAME}.hex')
"
done

echo "================================================================================"
echo "          ALL C TESTS COMPILED SUCCESSFULLY WITHOUT ERRORS                      "
echo "================================================================================"
