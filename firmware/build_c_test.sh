#!/bin/bash
# ==============================================================================
# build_c_test.sh: Compile C-based firmware for RISC-V VeeR EL2 SoC
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLCHAIN_PREFIX="/opt/riscv/bin/riscv64-unknown-elf-"

echo "=== Compiling C Firmware (soc_c_test.c) ==="
${TOOLCHAIN_PREFIX}gcc \
    -march=rv32im \
    -mabi=ilp32 \
    -mno-relax \
    -O2 \
    -nostdlib \
    -ffreestanding \
    -Wall \
    -Wextra \
    -T "${SCRIPT_DIR}/soc_c_link.ld" \
    "${SCRIPT_DIR}/soc_c_crt0.s" \
    "${SCRIPT_DIR}/soc_c_test.c" \
    -o "${SCRIPT_DIR}/soc_c_test.elf"

echo "=== Disassembling ELF ==="
${TOOLCHAIN_PREFIX}objdump -d -S "${SCRIPT_DIR}/soc_c_test.elf" > "${SCRIPT_DIR}/soc_c_test.dis"

echo "=== Extracting Raw Binary ==="
${TOOLCHAIN_PREFIX}objcopy -O binary -j .text -j .rodata "${SCRIPT_DIR}/soc_c_test.elf" "${SCRIPT_DIR}/soc_c_test.bin"

echo "=== Generating HEX for Testbench ($readmemh) ==="
python3 -c "
with open('${SCRIPT_DIR}/soc_c_test.bin', 'rb') as f:
    data = f.read()

lines = []
for i in range(0, len(data), 4):
    word = int.from_bytes(data[i:i+4], byteorder='little')
    lines.append(f'{word:08x}\n')

with open('${SCRIPT_DIR}/soc_c_test.hex', 'w') as f:
    f.writelines(lines)

print(f'Successfully generated ${SCRIPT_DIR}/soc_c_test.hex ({len(lines)} words, {len(data)} bytes)')
"
