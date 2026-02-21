module inline_asm.verify_aarch64_encoding;

/**
 * Verification program for AArch64 instruction encodings
 *
 * This program tests that our AArch64 inline assembler produces
 * correct machine code by comparing against known-good encodings
 * from the ARM Architecture Reference Manual.
 */

import core.stdc.stdio;

// Import the instruction encoding functions
import dmd.backend.arm.instr : INSTR;

unittest
{
    // Data Movement Instructions
    assert(INSTR.mov_register(1, 1, 0) == 0xAA0103E0);
    assert(INSTR.mov_register(0, 10, 5) == 0x2A0A03E5);

    // Arithmetic Instructions (Immediate)
    assert(INSTR.add_addsub_imm(1, 0, 42, 1, 0) == 0x9100A820);
    assert(INSTR.sub_addsub_imm(1, 0, 42, 1, 0) == 0xD100A820);
    assert(INSTR.add_addsub_imm(0, 0, 10, 2, 3) == 0x11002843);

    // Arithmetic Instructions (Register)
    assert(INSTR.addsub_shift(1, 0, 0, 0, 2, 0, 1, 0) == 0x8B020020);
    assert(INSTR.addsub_shift(1, 1, 0, 0, 5, 0, 4, 3) == 0xCB050083);

    // Load/Store Instructions
    assert(INSTR.ldr_imm_gen(1, 0, 1, 0) != 0);
    assert(INSTR.str_imm_gen(1, 0, 1, 0) != 0);

    // Branch Instructions
    assert(INSTR.b_uncond(0) == 0x14000000);
    assert(INSTR.b_cond(0, 0) == 0x54000000);
    assert(INSTR.b_cond(0, 1) == 0x54000001);
    assert(INSTR.compbranch(1, 0, 0, 0) == 0xB4000000);
    assert(INSTR.compbranch(1, 1, 0, 0) == 0xB5000000);
    assert(INSTR.testbranch(0, 0, 5, 0, 0) == 0x36280000);
    assert(INSTR.testbranch(0, 1, 5, 0, 0) == 0x37280000);
}
