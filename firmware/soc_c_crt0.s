# ==============================================================================
# soc_c_crt0.s: C runtime startup code for RISC-V VeeR EL2 SoC
# Initializes stack pointer and branches to main()
# ==============================================================================

    .section .text.init, "ax"
    .global _start
    .type _start, @function

_start:
    # Initialize stack pointer to upper DMEM region (0x00088000)
    # growing downward toward 0x00081000
    li sp, 0x00088000

    # Call C main
    call main

    # Halt in infinite loop
_loop:
    j _loop

    .size _start, . - _start
