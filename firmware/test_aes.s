// ==============================================================================
// test_aes.s: RISC-V Firmware for AES-128 Known-Answer Test (KAT) (S5 / 0x8000_7000)
//
// Known-Answer Test Vector:
//   Plaintext:  00112233445566778899aabbccddeeff
//   Key:        000102030405060708090a0b0c0d0e0f
//   Expected:   69c4e0d86a7b0430d8cdb78070b4c55a
//
// Writes Key & Plaintext, triggers encryption, polls done, reads Ciphertext,
// verifies against expected KAT values, and logs status to DMEM.
// ==============================================================================

    .org 0x00040000
    .globl _start

_start:
    li s0, 0x00080000       // s0 = DMEM base
    li s1, 0x80007000       // s1 = AES base (CSR)

    // Step 1: Write Key registers (AES_KEY0..3 at offsets 0x04, 0x08, 0x0C, 0x10)
    li t0, 0x0c0d0e0f
    sw t0, 4(s1)            // AES_KEY0
    li t0, 0x08090a0b
    sw t0, 8(s1)            // AES_KEY1
    li t0, 0x04050607
    sw t0, 12(s1)           // AES_KEY2
    li t0, 0x00010203
    sw t0, 16(s1)           // AES_KEY3

    // Step 2: Write Plaintext registers (AES_TIN0..3 at offsets 0x14, 0x18, 0x1C, 0x20)
    li t0, 0xccddeeff
    sw t0, 20(s1)           // AES_TIN0
    li t0, 0x8899aabb
    sw t0, 24(s1)           // AES_TIN1
    li t0, 0x44556677
    sw t0, 28(s1)           // AES_TIN2
    li t0, 0x00112233
    sw t0, 32(s1)           // AES_TIN3

    // Step 3: Trigger Encryption (write 1 to AES_CSR at offset 0x00)
    li t0, 1
    sw t0, 0(s1)            // AES_CSR = 1 (start)

    // Step 4: Poll AES_CSR until bit 31 (done) asserts
poll_done:
    lw t1, 0(s1)            // Read AES_CSR
    bge t1, zero, poll_done // bit 31 is sign bit: loop while positive (bit 31 == 0)

    // Step 5: Read Ciphertext registers (AES_TOUT0..3 at offsets 0x24, 0x28, 0x2C, 0x30)
    lw a0, 36(s1)           // AES_TOUT0
    sw a0, 0(s0)            // DMEM[0] = TOUT0 (expected 0x70b4c55a)
    lw a1, 40(s1)           // AES_TOUT1
    sw a1, 4(s0)            // DMEM[1] = TOUT1 (expected 0xd8cdb780)
    lw a2, 44(s1)           // AES_TOUT2
    sw a2, 8(s0)            // DMEM[2] = TOUT2 (expected 0x6a7b0430)
    lw a3, 48(s1)           // AES_TOUT3
    sw a3, 12(s0)           // DMEM[3] = TOUT3 (expected 0x69c4e0d8)

    // Step 6: Software verification against known answer
    li t3, 0x70b4c55a
    bne a0, t3, fail
    li t3, 0xd8cdb780
    bne a1, t3, fail
    li t3, 0x6a7b0430
    bne a2, t3, fail
    li t3, 0x69c4e0d8
    bne a3, t3, fail

    // All match! Store pass signature to DMEM[4]
    li t0, 0xAE510001       // AES test pass signature
    sw t0, 16(s0)           // DMEM[4] = Signature
    j done

fail:
    li t0, 0xDEADBEEF       // Failure flag
    sw t0, 16(s0)

done:
    j done
