/* ==============================================================================
 * soc_c_link.ld: Linker Script for RISC-V VeeR EL2 SoC C-Based Firmware
 * Memory Layout:
 *   IMEM (S0): 0x0004_0000 to 0x0005_FFFF (128 KB)
 *   DMEM (S1): 0x0008_0000 to 0x0009_FFFF (128 KB)
 * ==============================================================================
 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    imem (rx)  : ORIGIN = 0x00040000, LENGTH = 128K
    dmem (rwx) : ORIGIN = 0x00080000, LENGTH = 128K
}

SECTIONS
{
    .text 0x00040000 : {
        *(.text.init)
        *(.text .text.*)
    } > imem

    .rodata : ALIGN(4) {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    } > imem

    .data : ALIGN(4) {
        *(.data .data.*)
        *(.sdata .sdata.*)
    } > dmem AT > imem

    .bss : ALIGN(4) {
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
    } > dmem
}
