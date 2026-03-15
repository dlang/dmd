module inline_asm.verify_phase4_encoding;

/**
 * Verification program for Phase 4.1 arithmetic instruction encodings
 * Tests the encoding functions directly to verify correctness
 */

import dmd.backend.arm.instr : INSTR;
import core.stdc.stdio;

void verifyMADDEncoding()
{
    printf("Testing MADD (Multiply-Add) Encoding:\n");
    printf("======================================\n");

    // madd x0, x1, x2, x3 -> x0 = x3 + x1 * x2
    // Encoding: madd(sf, Rm, Ra, Rn, Rd)
    uint enc = INSTR.madd(1, 2, 3, 1, 0);
    printf("madd x0, x1, x2, x3        => 0x%08X\n", enc);

    // Verify register fields
    assert((enc & 0x1F) == 0, "MADD Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "MADD Rn should be 1");
    assert(((enc >> 10) & 0x1F) == 3, "MADD Ra should be 3");
    assert(((enc >> 16) & 0x1F) == 2, "MADD Rm should be 2");
    assert((enc >> 31) & 1, "MADD 64-bit should have sf=1");

    // Test 32-bit variant
    uint enc_w = INSTR.madd(0, 5, 6, 7, 8);
    printf("madd w8, w7, w5, w6        => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "MADD 32-bit should have sf=0");

    // Test with different registers
    uint enc2 = INSTR.madd(1, 10, 11, 12, 13);
    printf("madd x13, x12, x10, x11    => 0x%08X\n", enc2);

    // Test MADD with XZR as Ra (equivalent to MUL)
    uint enc_mul = INSTR.madd(1, 2, 31, 1, 0);
    printf("madd x0, x1, x2, xzr (MUL) => 0x%08X\n", enc_mul);
    assert(((enc_mul >> 10) & 0x1F) == 31, "MADD with XZR should have Ra=31");

    printf("\n");
}

void verifyMSUBEncoding()
{
    printf("Testing MSUB (Multiply-Subtract) Encoding:\n");
    printf("==========================================\n");

    // msub x0, x1, x2, x3 -> x0 = x3 - x1 * x2
    // Encoding: msub(sf, Rm, Ra, Rn, Rd)
    uint enc = INSTR.msub(1, 2, 3, 1, 0);
    printf("msub x0, x1, x2, x3        => 0x%08X\n", enc);

    // Verify register fields
    assert((enc & 0x1F) == 0, "MSUB Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "MSUB Rn should be 1");
    assert(((enc >> 10) & 0x1F) == 3, "MSUB Ra should be 3");
    assert(((enc >> 16) & 0x1F) == 2, "MSUB Rm should be 2");

    // Test 32-bit variant
    uint enc_w = INSTR.msub(0, 5, 6, 7, 8);
    printf("msub w8, w7, w5, w6        => 0x%08X\n", enc_w);

    // Verify MADD vs MSUB difference (bit 15)
    uint madd_enc = INSTR.madd(1, 2, 3, 1, 0);
    uint diff = enc ^ madd_enc;
    printf("MADD vs MSUB difference    => 0x%08X\n", diff);
    assert(diff == (1 << 15), "MADD and MSUB should only differ in bit 15");

    printf("\n");
}

void verifySDIVEncoding()
{
    printf("Testing SDIV (Signed Division) Encoding:\n");
    printf("========================================\n");

    // sdiv x0, x1, x2 -> x0 = x1 / x2 (signed)
    // Encoding: sdiv_udiv(sf, uns=false, Rm, Rn, Rd)
    uint enc = INSTR.sdiv_udiv(1, false, 2, 1, 0);
    printf("sdiv x0, x1, x2            => 0x%08X\n", enc);

    // Verify register fields
    assert((enc & 0x1F) == 0, "SDIV Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "SDIV Rn should be 1");
    assert(((enc >> 16) & 0x1F) == 2, "SDIV Rm should be 2");
    assert((enc >> 31) & 1, "SDIV 64-bit should have sf=1");

    // Test 32-bit variant
    uint enc_w = INSTR.sdiv_udiv(0, false, 5, 6, 7);
    printf("sdiv w7, w6, w5            => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "SDIV 32-bit should have sf=0");

    // Test with different registers
    uint enc2 = INSTR.sdiv_udiv(1, false, 10, 11, 12);
    printf("sdiv x12, x11, x10         => 0x%08X\n", enc2);

    // Verify opcode field (bits [15:10])
    uint opcode = (enc >> 10) & 0x3F;
    printf("SDIV opcode (bits [15:10]) => 0x%02X\n", opcode);

    printf("\n");
}

void verifyUDIVEncoding()
{
    printf("Testing UDIV (Unsigned Division) Encoding:\n");
    printf("==========================================\n");

    // udiv x0, x1, x2 -> x0 = x1 / x2 (unsigned)
    // Encoding: sdiv_udiv(sf, uns=true, Rm, Rn, Rd)
    uint enc = INSTR.sdiv_udiv(1, true, 2, 1, 0);
    printf("udiv x0, x1, x2            => 0x%08X\n", enc);

    // Verify register fields
    assert((enc & 0x1F) == 0, "UDIV Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "UDIV Rn should be 1");
    assert(((enc >> 16) & 0x1F) == 2, "UDIV Rm should be 2");

    // Test 32-bit variant
    uint enc_w = INSTR.sdiv_udiv(0, true, 5, 6, 7);
    printf("udiv w7, w6, w5            => 0x%08X\n", enc_w);

    // Verify SDIV vs UDIV difference
    uint sdiv_enc = INSTR.sdiv_udiv(1, false, 2, 1, 0);
    uint diff = enc ^ sdiv_enc;
    printf("SDIV vs UDIV difference    => 0x%08X\n", diff);
    assert(diff != 0, "SDIV and UDIV should differ");

    // Verify opcode field
    uint opcode_udiv = (enc >> 10) & 0x3F;
    uint opcode_sdiv = (sdiv_enc >> 10) & 0x3F;
    printf("UDIV opcode: 0x%02X, SDIV opcode: 0x%02X\n", opcode_udiv, opcode_sdiv);
    assert(opcode_udiv != opcode_sdiv, "SDIV and UDIV opcodes should differ");

    printf("\n");
}

void verifyNEGEncoding()
{
    printf("Testing NEG (Negate) Encoding:\n");
    printf("==============================\n");

    // neg x0, x1 -> x0 = 0 - x1
    // Encoding: neg_sub_addsub_shift(sf, S, shift, Rm, imm6, Rd)
    uint enc = INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 0, 0);
    printf("neg x0, x1                 => 0x%08X\n", enc);

    // Verify register fields
    assert((enc & 0x1F) == 0, "NEG Rd should be 0");
    assert(((enc >> 16) & 0x1F) == 1, "NEG Rm should be 1");
    assert((enc >> 31) & 1, "NEG 64-bit should have sf=1");

    // Verify Rn is 31 (XZR) - NEG is SUB from zero
    uint rn = (enc >> 5) & 0x1F;
    printf("NEG Rn field (should be 31) => %u\n", rn);
    assert(rn == 31, "NEG should have Rn=31 (XZR)");

    // Test 32-bit variant
    uint enc_w = INSTR.neg_sub_addsub_shift(0, 0, 0, 5, 0, 6);
    printf("neg w6, w5                 => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "NEG 32-bit should have sf=0");

    printf("\n");
}

void verifyNEGWithShift()
{
    printf("Testing NEG with Shift Encoding:\n");
    printf("================================\n");

    // neg x0, x1, lsl #3
    uint enc_lsl = INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 3, 0);
    printf("neg x0, x1, lsl #3         => 0x%08X\n", enc_lsl);

    // Verify shift amount in bits [15:10]
    uint shift_amt = (enc_lsl >> 10) & 0x3F;
    assert(shift_amt == 3, "NEG shift amount should be 3");

    // Verify shift type in bits [23:22]
    uint shift_type = (enc_lsl >> 22) & 3;
    assert(shift_type == 0, "LSL shift type should be 0");

    // Test other shift types
    uint enc_lsr = INSTR.neg_sub_addsub_shift(1, 0, 1, 2, 4, 3);
    printf("neg x3, x2, lsr #4         => 0x%08X\n", enc_lsr);
    assert(((enc_lsr >> 22) & 3) == 1, "LSR shift type should be 1");
    assert(((enc_lsr >> 10) & 0x3F) == 4, "LSR shift amount should be 4");

    uint enc_asr = INSTR.neg_sub_addsub_shift(1, 0, 2, 5, 8, 6);
    printf("neg x6, x5, asr #8         => 0x%08X\n", enc_asr);
    assert(((enc_asr >> 22) & 3) == 2, "ASR shift type should be 2");
    assert(((enc_asr >> 10) & 0x3F) == 8, "ASR shift amount should be 8");

    uint enc_ror = INSTR.neg_sub_addsub_shift(1, 0, 3, 8, 16, 9);
    printf("neg x9, x8, ror #16        => 0x%08X\n", enc_ror);
    assert(((enc_ror >> 22) & 3) == 3, "ROR shift type should be 3");
    assert(((enc_ror >> 10) & 0x3F) == 16, "ROR shift amount should be 16");

    printf("\n");
}

void verifyRegisterFields()
{
    printf("Testing All Register Encodings:\n");
    printf("================================\n");

    // Test MADD with all registers 0-30
    printf("Testing MADD register encoding...\n");
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.madd(1, r, r, r, r);
        assert((enc & 0x1F) == r, "MADD Rd encoding failed");
        assert(((enc >> 5) & 0x1F) == r, "MADD Rn encoding failed");
        assert(((enc >> 10) & 0x1F) == r, "MADD Ra encoding failed");
        assert(((enc >> 16) & 0x1F) == r, "MADD Rm encoding failed");
    }
    printf("✓ MADD: All registers (0-30) encode correctly\n");

    // Test SDIV with all registers
    printf("Testing SDIV register encoding...\n");
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.sdiv_udiv(1, false, r, r, r);
        assert((enc & 0x1F) == r, "SDIV Rd encoding failed");
        assert(((enc >> 5) & 0x1F) == r, "SDIV Rn encoding failed");
        assert(((enc >> 16) & 0x1F) == r, "SDIV Rm encoding failed");
    }
    printf("✓ SDIV: All registers (0-30) encode correctly\n");

    // Test NEG with all registers
    printf("Testing NEG register encoding...\n");
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.neg_sub_addsub_shift(1, 0, 0, r, 0, r);
        assert((enc & 0x1F) == r, "NEG Rd encoding failed");
        assert(((enc >> 16) & 0x1F) == r, "NEG Rm encoding failed");
    }
    printf("✓ NEG: All registers (0-30) encode correctly\n");

    printf("\n");
}

void verifyShiftRanges()
{
    printf("Testing NEG Shift Amount Ranges:\n");
    printf("================================\n");

    // Test 64-bit shift range (0-63)
    for (uint shift = 0; shift <= 63; shift++)
    {
        uint enc = INSTR.neg_sub_addsub_shift(1, 0, 0, 1, shift, 0);
        uint decoded = (enc >> 10) & 0x3F;
        assert(decoded == shift, "64-bit shift encoding failed");
    }
    printf("✓ 64-bit shifts (0-63) encode correctly\n");

    // Test 32-bit shift range (0-31)
    for (uint shift = 0; shift <= 31; shift++)
    {
        uint enc = INSTR.neg_sub_addsub_shift(0, 0, 0, 1, shift, 0);
        uint decoded = (enc >> 10) & 0x3F;
        assert(decoded == shift, "32-bit shift encoding failed");
    }
    printf("✓ 32-bit shifts (0-31) encode correctly\n");

    printf("\n");
}

void verifyCommonPatterns()
{
    printf("Testing Common Usage Patterns:\n");
    printf("==============================\n");

    // Multiply-add pattern
    printf("Multiply-add pattern:\n");
    printf("  madd x0, x1, x2, x3 => 0x%08X\n", INSTR.madd(1, 2, 3, 1, 0));

    // Multiply (MADD with Ra=31)
    printf("Multiply (using MADD):\n");
    printf("  madd x0, x1, x2, xzr => 0x%08X\n", INSTR.madd(1, 2, 31, 1, 0));

    // Division pattern
    printf("Division pattern:\n");
    printf("  sdiv x0, x1, x2 => 0x%08X\n", INSTR.sdiv_udiv(1, false, 2, 1, 0));

    // Remainder computation (quotient * divisor)
    printf("Remainder computation:\n");
    printf("  sdiv x3, x1, x2 => 0x%08X\n", INSTR.sdiv_udiv(1, false, 2, 1, 3));
    printf("  msub x4, x3, x2, x1 => 0x%08X\n", INSTR.msub(1, 2, 1, 3, 4));

    // Negate pattern
    printf("Negate pattern:\n");
    printf("  neg x0, x1 => 0x%08X\n", INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 0, 0));

    // Negate shifted
    printf("Negate shifted:\n");
    printf("  neg x0, x1, lsl #2 => 0x%08X\n", INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 2, 0));

    printf("\n");
}

void verifyEdgeCases()
{
    printf("Testing Edge Cases:\n");
    printf("===================\n");

    // MADD with all same registers
    uint madd_same = INSTR.madd(1, 0, 0, 0, 0);
    printf("madd x0, x0, x0, x0 => 0x%08X\n", madd_same);
    assert((madd_same & 0x1F) == 0, "All Rd should be 0");
    assert(((madd_same >> 5) & 0x1F) == 0, "All Rn should be 0");
    assert(((madd_same >> 10) & 0x1F) == 0, "All Ra should be 0");
    assert(((madd_same >> 16) & 0x1F) == 0, "All Rm should be 0");

    // Division by same register (x/x = 1 if x != 0)
    uint div_same = INSTR.sdiv_udiv(1, false, 5, 5, 5);
    printf("sdiv x5, x5, x5 => 0x%08X\n", div_same);

    // NEG with maximum shift amounts
    uint neg_max64 = INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 63, 0);
    printf("neg x0, x1, lsl #63 => 0x%08X\n", neg_max64);
    assert(((neg_max64 >> 10) & 0x3F) == 63, "Max 64-bit shift should be 63");

    uint neg_max32 = INSTR.neg_sub_addsub_shift(0, 0, 0, 1, 31, 0);
    printf("neg w0, w1, lsl #31 => 0x%08X\n", neg_max32);
    assert(((neg_max32 >> 10) & 0x3F) == 31, "Max 32-bit shift should be 31");

    // MSUB with XZR (negate product)
    uint msub_xzr = INSTR.msub(1, 2, 31, 1, 0);
    printf("msub x0, x1, x2, xzr => 0x%08X\n", msub_xzr);
    assert(((msub_xzr >> 10) & 0x1F) == 31, "MSUB with XZR should have Ra=31");

    printf("\n");
}

unittest
{
    verifyMADDEncoding();
    verifyMSUBEncoding();
    verifySDIVEncoding();
    verifyUDIVEncoding();
    verifyNEGEncoding();
    verifyNEGWithShift();
    verifyRegisterFields();
    verifyShiftRanges();
    verifyCommonPatterns();
    verifyEdgeCases();
}
