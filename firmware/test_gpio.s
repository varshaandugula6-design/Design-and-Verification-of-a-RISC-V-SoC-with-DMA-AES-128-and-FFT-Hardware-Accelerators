// ==============================================================================
// test_gpio.s: RISC-V Firmware for GPIO Controller Verification (S2 / 0x8000_1000)
// Configures direction, writes DATA_O, performs SET/CLR/TGL, reads DATA_I.
// Stores results and completion signature in DMEM (0x0008_0000).
// ==============================================================================

    .org 0x00040000
    .globl _start

_start:
    // Base registers
    li s0, 0x00080000       // s0 = DMEM base
    li s1, 0x80001000       // s1 = GPIO base (DATA_I)

    // Step 1: Set Direction Register (DIR at offset 0x08)
    // Pins [15:0] as outputs (1), Pins [31:16] as inputs (0) -> 0x0000FFFF
    li t0, 0x0000FFFF
    sw t0, 8(s1)            // GPIO_DIR = 0x0000_FFFF
    lw t1, 8(s1)            // Readback DIR
    sw t1, 0(s0)            // DMEM[0] = DIR readback (expected 0x0000_FFFF)

    // Step 2: Write Output Data (DATA_O at offset 0x04)
    li t0, 0x0000A55A
    sw t0, 4(s1)            // GPIO_DATA_O = 0x0000_A55A
    lw t1, 4(s1)            // Readback DATA_O
    sw t1, 4(s0)            // DMEM[1] = DATA_O readback (expected 0x0000_A55A)

    // Step 3: Atomic SET (SET_O at offset 0x20)
    // Set bits [7:4] with mask 0x000000A0 -> 0x0000_A5FA
    li t0, 0x000000A0
    sw t0, 32(s1)           // GPIO_SET_O = 0x0000_00A0
    lw t1, 4(s1)            // Readback DATA_O
    sw t1, 8(s0)            // DMEM[2] = DATA_O after SET (expected 0x0000_A5FA)

    // Step 4: Atomic CLR (CLR_O at offset 0x24)
    // Clear bits with mask 0x0000000A -> 0x0000_A5F0
    li t0, 0x0000000A
    sw t0, 36(s1)           // GPIO_CLR_O = 0x0000_000A
    lw t1, 4(s1)            // Readback DATA_O
    sw t1, 12(s0)           // DMEM[3] = DATA_O after CLR (expected 0x0000_A5F0)

    // Step 5: Atomic TGL (TGL_O at offset 0x28)
    // Toggle bits with mask 0x000000F0 -> 0x0000_A500
    li t0, 0x000000F0
    sw t0, 40(s1)           // GPIO_TGL_O = 0x0000_00F0
    lw t1, 4(s1)            // Readback DATA_O
    sw t1, 16(s0)           // DMEM[4] = DATA_O after TGL (expected 0x0000_A500)

    // Step 6: Disable debouncer (DEB_EN at offset 0x30) & read DATA_I (offset 0x00)
    sw zero, 48(s1)         // GPIO_DEB_EN = 0
    lw t1, 0(s1)            // Read DATA_I
    sw t1, 20(s0)           // DMEM[5] = DATA_I (pins [31:16] input values)

    // Completion signature
    li t0, 0x60100001       // GPIO test pass signature
    sw t0, 24(s0)           // DMEM[6] = Signature

done:
    j done
