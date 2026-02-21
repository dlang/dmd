module inline_asm.verify_phase4_2_encoding;

/**
 * Verification program for Phase 4.2 logical instruction encodings
 * Tests the encoding functions directly to verify correctness
 */

import dmd.backend.arm.instr : INSTR;
import core.stdc.stdio;

void verifyBICEncoding()
{
    printf("Testing BIC (Bit Clear) Encoding:\n");
    printf("==================================\n");

    // bic x0, x1, x2 -> x0 = x1 & ~x2
    // Encoding: log_shift(sf, opc=0 (AND), shift, N=1 (NOT), Rm, imm6, Rn, Rd)
    uint enc = INSTR.log_shift(1, 0, 0, 1, 2, 0, 1, 0);
    printf("bic x0, x1, x2             => 0x%08X\n", enc);

    // Verify N bit (bit 21) is set for NOT
    assert((enc >> 21) & 1, "BIC should have N=1");

    // Verify opc field (bits [30:29]) is 0 for AND
    assert(((enc >> 29) & 3) == 0, "BIC should have opc=0");

    // Verify register fields
    assert((enc & 0x1F) == 0, "BIC Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "BIC Rn should be 1");
    assert(((enc >> 16) & 0x1F) == 2, "BIC Rm should be 2");
    assert((enc >> 31) & 1, "BIC 64-bit should have sf=1");

    // Test 32-bit variant
    uint enc_w = INSTR.log_shift(0, 0, 0, 1, 5, 0, 6, 7);
    printf("bic w7, w6, w5             => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "BIC 32-bit should have sf=0");

    // Test with different registers
    uint enc2 = INSTR.log_shift(1, 0, 0, 1, 10, 0, 11, 12);
    printf("bic x12, x11, x10          => 0x%08X\n", enc2);

    printf("\n");
}

void verifyBICWithShift()
{
    printf("Testing BIC with Shift Encoding:\n");
    printf("================================\n");

    // bic x0, x1, x2, lsl #3
    uint enc_lsl = INSTR.log_shift(1, 0, 0, 1, 2, 3, 1, 0);
    printf("bic x0, x1, x2, lsl #3     => 0x%08X\n", enc_lsl);

    // Verify shift amount in bits [15:10]
    uint shift_amt = (enc_lsl >> 10) & 0x3F;
    assert(shift_amt == 3, "BIC shift amount should be 3");

    // Verify shift type in bits [23:22]
    uint shift_type = (enc_lsl >> 22) & 3;
    assert(shift_type == 0, "LSL shift type should be 0");

    // Test other shift types
    uint enc_lsr = INSTR.log_shift(1, 0, 1, 1, 2, 4, 1, 0);
    printf("bic x0, x1, x2, lsr #4     => 0x%08X\n", enc_lsr);
    assert(((enc_lsr >> 22) & 3) == 1, "LSR shift type should be 1");
    assert(((enc_lsr >> 10) & 0x3F) == 4, "LSR shift amount should be 4");

    uint enc_asr = INSTR.log_shift(1, 0, 2, 1, 2, 8, 1, 0);
    printf("bic x0, x1, x2, asr #8     => 0x%08X\n", enc_asr);
    assert(((enc_asr >> 22) & 3) == 2, "ASR shift type should be 2");
    assert(((enc_asr >> 10) & 0x3F) == 8, "ASR shift amount should be 8");

    uint enc_ror = INSTR.log_shift(1, 0, 3, 1, 2, 16, 1, 0);
    printf("bic x0, x1, x2, ror #16    => 0x%08X\n", enc_ror);
    assert(((enc_ror >> 22) & 3) == 3, "ROR shift type should be 3");
    assert(((enc_ror >> 10) & 0x3F) == 16, "ROR shift amount should be 16");

    printf("\n");
}

void verifyBICvsAND()
{
    printf("Testing BIC vs AND Difference:\n");
    printf("==============================\n");

    uint and_enc = INSTR.log_shift(1, 0, 0, 0, 2, 0, 1, 0);  // AND
    uint bic_enc = INSTR.log_shift(1, 0, 0, 1, 2, 0, 1, 0);  // BIC

    printf("and x0, x1, x2 => 0x%08X\n", and_enc);
    printf("bic x0, x1, x2 => 0x%08X\n", bic_enc);
    printf("Difference     => 0x%08X\n", and_enc ^ bic_enc);

    // They should only differ in bit 21 (N field)
    uint diff = and_enc ^ bic_enc;
    assert(diff == (1 << 21), "AND and BIC should only differ in bit 21");

    // Verify N bit
    assert(!((and_enc >> 21) & 1), "AND should have N=0");
    assert((bic_enc >> 21) & 1, "BIC should have N=1");

    printf("✓ AND and BIC differ only in N bit (bit 21)\n");
    printf("\n");
}

void verifyTSTEncoding()
{
    printf("Testing TST (Test) Encoding:\n");
    printf("============================\n");

    // tst x1, x2 -> flags = x1 & x2
    // Encoding: log_shift(sf, opc=3 (ANDS), shift, N=0, Rm, imm6, Rn, Rd=31 (XZR))
    uint enc = INSTR.log_shift(1, 3, 0, 0, 2, 0, 1, 31);
    printf("tst x1, x2                 => 0x%08X\n", enc);

    // Verify Rd is 31 (XZR) - TST doesn't write result, only sets flags
    assert((enc & 0x1F) == 31, "TST should have Rd=31");

    // Verify opc field (bits [30:29]) is 3 for ANDS
    assert(((enc >> 29) & 3) == 3, "TST should have opc=3");

    // Verify N bit (bit 21) is 0 for normal (not inverted)
    assert(!((enc >> 21) & 1), "TST should have N=0");

    // Verify register fields
    assert(((enc >> 5) & 0x1F) == 1, "TST Rn should be 1");
    assert(((enc >> 16) & 0x1F) == 2, "TST Rm should be 2");
    assert((enc >> 31) & 1, "TST 64-bit should have sf=1");

    // Test 32-bit variant
    uint enc_w = INSTR.log_shift(0, 3, 0, 0, 5, 0, 6, 31);
    printf("tst w6, w5                 => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "TST 32-bit should have sf=0");

    // Test with different registers
    uint enc2 = INSTR.log_shift(1, 3, 0, 0, 10, 0, 11, 31);
    printf("tst x11, x10               => 0x%08X\n", enc2);

    printf("\n");
}

void verifyTSTWithShift()
{
    printf("Testing TST with Shift Encoding:\n");
    printf("================================\n");

    // tst x1, x2, lsl #3
    uint enc_lsl = INSTR.log_shift(1, 3, 0, 0, 2, 3, 1, 31);
    printf("tst x1, x2, lsl #3         => 0x%08X\n", enc_lsl);

    // Verify shift amount in bits [15:10]
    uint shift_amt = (enc_lsl >> 10) & 0x3F;
    assert(shift_amt == 3, "TST shift amount should be 3");

    // Verify shift type in bits [23:22]
    uint shift_type = (enc_lsl >> 22) & 3;
    assert(shift_type == 0, "LSL shift type should be 0");

    // Test other shift types
    uint enc_lsr = INSTR.log_shift(1, 3, 1, 0, 2, 4, 1, 31);
    printf("tst x1, x2, lsr #4         => 0x%08X\n", enc_lsr);
    assert(((enc_lsr >> 22) & 3) == 1, "LSR shift type should be 1");

    uint enc_asr = INSTR.log_shift(1, 3, 2, 0, 2, 8, 1, 31);
    printf("tst x1, x2, asr #8         => 0x%08X\n", enc_asr);
    assert(((enc_asr >> 22) & 3) == 2, "ASR shift type should be 2");

    uint enc_ror = INSTR.log_shift(1, 3, 3, 0, 2, 16, 1, 31);
    printf("tst x1, x2, ror #16        => 0x%08X\n", enc_ror);
    assert(((enc_ror >> 22) & 3) == 3, "ROR shift type should be 3");

    printf("\n");
}

void verifyTSTvsAND()
{
    printf("Testing TST vs AND Difference:\n");
    printf("==============================\n");

    uint and_enc = INSTR.log_shift(1, 0, 0, 0, 2, 0, 1, 0);   // AND
    uint tst_enc = INSTR.log_shift(1, 3, 0, 0, 2, 0, 1, 31);  // TST

    printf("and x0, x1, x2 => 0x%08X\n", and_enc);
    printf("tst x1, x2     => 0x%08X\n", tst_enc);

    assert(and_enc != tst_enc, "AND and TST should differ");

    // Verify opc field difference
    uint and_opc = (and_enc >> 29) & 3;
    uint tst_opc = (tst_enc >> 29) & 3;
    printf("AND opc: %u, TST opc: %u\n", and_opc, tst_opc);
    assert(and_opc == 0, "AND should have opc=0");
    assert(tst_opc == 3, "TST should have opc=3");

    // Verify Rd field difference
    assert((and_enc & 0x1F) == 0, "AND Rd should be 0");
    assert((tst_enc & 0x1F) == 31, "TST Rd should be 31");

    printf("✓ AND and TST have different opc and Rd fields\n");
    printf("\n");
}

void verifyRegisterEncodings()
{
    printf("Testing All Register Encodings:\n");
    printf("================================\n");

    // Test BIC with all registers
    printf("Testing BIC register encoding...\n");
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.log_shift(1, 0, 0, 1, r, 0, r, r);
        assert((enc & 0x1F) == r, "BIC Rd encoding failed");
        assert(((enc >> 5) & 0x1F) == r, "BIC Rn encoding failed");
        assert(((enc >> 16) & 0x1F) == r, "BIC Rm encoding failed");
    }
    printf("✓ BIC: All registers (0-30) encode correctly\n");

    // Test TST with all registers
    printf("Testing TST register encoding...\n");
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.log_shift(1, 3, 0, 0, r, 0, r, 31);
        assert((enc & 0x1F) == 31, "TST Rd should always be 31");
        assert(((enc >> 5) & 0x1F) == r, "TST Rn encoding failed");
        assert(((enc >> 16) & 0x1F) == r, "TST Rm encoding failed");
    }
    printf("✓ TST: All registers (0-30) encode correctly\n");

    printf("\n");
}

void verifyShiftRanges()
{
    printf("Testing Shift Amount Ranges:\n");
    printf("============================\n");

    // Test BIC 64-bit shift range (0-63)
    for (uint shift = 0; shift <= 63; shift++)
    {
        uint enc = INSTR.log_shift(1, 0, 0, 1, 1, shift, 2, 0);
        uint decoded = (enc >> 10) & 0x3F;
        assert(decoded == shift, "BIC 64-bit shift encoding failed");
    }
    printf("✓ BIC 64-bit shifts (0-63) encode correctly\n");

    // Test BIC 32-bit shift range (0-31)
    for (uint shift = 0; shift <= 31; shift++)
    {
        uint enc = INSTR.log_shift(0, 0, 0, 1, 1, shift, 2, 0);
        uint decoded = (enc >> 10) & 0x3F;
        assert(decoded == shift, "BIC 32-bit shift encoding failed");
    }
    printf("✓ BIC 32-bit shifts (0-31) encode correctly\n");

    // Test TST 64-bit shift range (0-63)
    for (uint shift = 0; shift <= 63; shift++)
    {
        uint enc = INSTR.log_shift(1, 3, 0, 0, 1, shift, 2, 31);
        uint decoded = (enc >> 10) & 0x3F;
        assert(decoded == shift, "TST 64-bit shift encoding failed");
    }
    printf("✓ TST 64-bit shifts (0-63) encode correctly\n");

    // Test TST 32-bit shift range (0-31)
    for (uint shift = 0; shift <= 31; shift++)
    {
        uint enc = INSTR.log_shift(0, 3, 0, 0, 1, shift, 2, 31);
        uint decoded = (enc >> 10) & 0x3F;
        assert(decoded == shift, "TST 32-bit shift encoding failed");
    }
    printf("✓ TST 32-bit shifts (0-31) encode correctly\n");

    printf("\n");
}

void verifyShiftTypes()
{
    printf("Testing All Shift Types:\n");
    printf("========================\n");

    // Test BIC with all shift types
    uint bic_lsl = INSTR.log_shift(1, 0, 0, 1, 1, 4, 2, 0);
    uint bic_lsr = INSTR.log_shift(1, 0, 1, 1, 1, 4, 2, 0);
    uint bic_asr = INSTR.log_shift(1, 0, 2, 1, 1, 4, 2, 0);
    uint bic_ror = INSTR.log_shift(1, 0, 3, 1, 1, 4, 2, 0);

    printf("BIC LSL => 0x%08X (shift type=%u)\n", bic_lsl, (bic_lsl >> 22) & 3);
    printf("BIC LSR => 0x%08X (shift type=%u)\n", bic_lsr, (bic_lsr >> 22) & 3);
    printf("BIC ASR => 0x%08X (shift type=%u)\n", bic_asr, (bic_asr >> 22) & 3);
    printf("BIC ROR => 0x%08X (shift type=%u)\n", bic_ror, (bic_ror >> 22) & 3);

    assert(((bic_lsl >> 22) & 3) == 0, "LSL should be 0");
    assert(((bic_lsr >> 22) & 3) == 1, "LSR should be 1");
    assert(((bic_asr >> 22) & 3) == 2, "ASR should be 2");
    assert(((bic_ror >> 22) & 3) == 3, "ROR should be 3");

    // All should be distinct
    assert(bic_lsl != bic_lsr, "LSL and LSR should differ");
    assert(bic_lsl != bic_asr, "LSL and ASR should differ");
    assert(bic_lsl != bic_ror, "LSL and ROR should differ");

    printf("✓ All four shift types encode correctly\n");
    printf("\n");
}

void verifyCommonPatterns()
{
    printf("Testing Common Usage Patterns:\n");
    printf("==============================\n");

    // Bit clear pattern
    printf("Bit clear pattern:\n");
    printf("  bic x0, x1, x2 => 0x%08X\n", INSTR.log_shift(1, 0, 0, 1, 2, 0, 1, 0));

    // Bit clear with shift
    printf("Bit clear with shift:\n");
    printf("  bic x0, x1, x2, lsl #8 => 0x%08X\n", INSTR.log_shift(1, 0, 0, 1, 2, 8, 1, 0));

    // Test bits pattern
    printf("Test bits pattern:\n");
    printf("  tst x1, x2 => 0x%08X\n", INSTR.log_shift(1, 3, 0, 0, 2, 0, 1, 31));

    // Test specific bit
    printf("Test specific bit:\n");
    printf("  tst x1, x2, lsl #15 => 0x%08X\n", INSTR.log_shift(1, 3, 0, 0, 2, 15, 1, 31));

    // Test for zero (test register against itself)
    printf("Test for zero:\n");
    printf("  tst x1, x1 => 0x%08X\n", INSTR.log_shift(1, 3, 0, 0, 1, 0, 1, 31));

    printf("\n");
}

void verifyEdgeCases()
{
    printf("Testing Edge Cases:\n");
    printf("===================\n");

    // BIC with all same registers (result = 0)
    uint bic_same = INSTR.log_shift(1, 0, 0, 1, 5, 0, 5, 5);
    printf("bic x5, x5, x5 => 0x%08X (result = x5 & ~x5 = 0)\n", bic_same);

    // TST register against itself
    uint tst_same = INSTR.log_shift(1, 3, 0, 0, 5, 0, 5, 31);
    printf("tst x5, x5 => 0x%08X (tests if x5 != 0)\n", tst_same);

    // BIC with maximum shift amounts
    uint bic_max64 = INSTR.log_shift(1, 0, 0, 1, 1, 63, 2, 0);
    printf("bic x0, x2, x1, lsl #63 => 0x%08X\n", bic_max64);
    assert(((bic_max64 >> 10) & 0x3F) == 63, "Max 64-bit shift should be 63");

    uint bic_max32 = INSTR.log_shift(0, 0, 0, 1, 1, 31, 2, 0);
    printf("bic w0, w2, w1, lsl #31 => 0x%08X\n", bic_max32);
    assert(((bic_max32 >> 10) & 0x3F) == 31, "Max 32-bit shift should be 31");

    // TST with maximum shift amounts
    uint tst_max64 = INSTR.log_shift(1, 3, 0, 0, 1, 63, 2, 31);
    printf("tst x2, x1, lsl #63 => 0x%08X\n", tst_max64);

    printf("\n");
}

void verifyRelationships()
{
    printf("Testing Instruction Relationships:\n");
    printf("==================================\n");

    // BIC = AND with N=1
    uint and_base = INSTR.log_shift(1, 0, 0, 0, 2, 0, 1, 0);
    uint bic_base = INSTR.log_shift(1, 0, 0, 1, 2, 0, 1, 0);

    printf("AND base encoding:         0x%08X (N=0)\n", and_base);
    printf("BIC base encoding:         0x%08X (N=1)\n", bic_base);
    printf("Difference (should be bit 21): 0x%08X\n", and_base ^ bic_base);

    assert((and_base ^ bic_base) == (1 << 21), "AND and BIC should only differ in N bit");

    // TST = ANDS with Rd=31
    uint ands_base = INSTR.log_shift(1, 3, 0, 0, 2, 0, 1, 0);
    uint tst_base = INSTR.log_shift(1, 3, 0, 0, 2, 0, 1, 31);

    printf("ANDS base encoding:        0x%08X (Rd=0)\n", ands_base);
    printf("TST base encoding:         0x%08X (Rd=31)\n", tst_base);

    assert(((ands_base >> 29) & 3) == ((tst_base >> 29) & 3), "ANDS and TST should have same opc");
    assert((ands_base & 0x1F) == 0, "ANDS Rd should be 0");
    assert((tst_base & 0x1F) == 31, "TST Rd should be 31");

    printf("✓ BIC is AND with N=1, TST is ANDS with Rd=31\n");
    printf("\n");
}

unittest
{
    verifyBICEncoding();
    verifyBICWithShift();
    verifyBICvsAND();
    verifyTSTEncoding();
    verifyTSTWithShift();
    verifyTSTvsAND();
    verifyRegisterEncodings();
    verifyShiftRanges();
    verifyShiftTypes();
    verifyCommonPatterns();
    verifyEdgeCases();
    verifyRelationships();
}
