module inline_asm.verify_additional_encoding;

/**
 * Verification program for additional instruction encodings
 * Tests ADC, SBC, NEGS, and bitfield instruction (UBFM, SBFM, BFM) encodings
 */

import dmd.backend.arm.instr : INSTR;
import core.stdc.stdio;

void verifyADC()
{
    printf("Testing ADC (Add with Carry) Encoding:\n");
    printf("======================================\n");

    // adc x0, x1, x2 - add with carry
    uint enc = INSTR.adc(1, 2, 1, 0);
    printf("adc x0, x1, x2             => 0x%08X\n", enc);

    // Verify sf bit (bit 31) for 64-bit
    assert((enc >> 31) & 1, "ADC 64-bit should have sf=1");

    // Verify op bit (bit 30) - 0 for ADD
    assert(!((enc >> 30) & 1), "ADC should have op=0");

    // Verify S bit (bit 29) - 0 for ADC (no flags)
    assert(!((enc >> 29) & 1), "ADC should have S=0");

    // Verify register fields
    assert((enc & 0x1F) == 0, "ADC Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "ADC Rn should be 1");
    assert(((enc >> 16) & 0x1F) == 2, "ADC Rm should be 2");

    // Test 32-bit variant
    uint enc_w = INSTR.adc(0, 5, 6, 7);
    printf("adc w7, w6, w5             => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "ADC 32-bit should have sf=0");

    // Test different registers
    uint enc2 = INSTR.adc(1, 10, 11, 12);
    printf("adc x12, x11, x10          => 0x%08X\n", enc2);

    printf("\n");
}

void verifySBC()
{
    printf("Testing SBC (Subtract with Carry) Encoding:\n");
    printf("============================================\n");

    // sbc x0, x1, x2 - subtract with carry
    uint enc = INSTR.sbc(1, 2, 1, 0);
    printf("sbc x0, x1, x2             => 0x%08X\n", enc);

    // Verify sf bit (bit 31) for 64-bit
    assert((enc >> 31) & 1, "SBC 64-bit should have sf=1");

    // Verify op bit (bit 30) - 1 for SUB
    assert((enc >> 30) & 1, "SBC should have op=1");

    // Verify S bit (bit 29) - 0 for SBC (no flags)
    assert(!((enc >> 29) & 1), "SBC should have S=0");

    // Verify register fields
    assert((enc & 0x1F) == 0, "SBC Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "SBC Rn should be 1");
    assert(((enc >> 16) & 0x1F) == 2, "SBC Rm should be 2");

    // Test 32-bit variant
    uint enc_w = INSTR.sbc(0, 5, 6, 7);
    printf("sbc w7, w6, w5             => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "SBC 32-bit should have sf=0");

    // Test different registers
    uint enc2 = INSTR.sbc(1, 10, 11, 12);
    printf("sbc x12, x11, x10          => 0x%08X\n", enc2);

    printf("\n");
}

void verifyADCvsSBC()
{
    printf("Testing ADC vs SBC Difference:\n");
    printf("==============================\n");

    uint adc_enc = INSTR.adc(1, 2, 1, 0);
    uint sbc_enc = INSTR.sbc(1, 2, 1, 0);

    printf("adc x0, x1, x2 => 0x%08X\n", adc_enc);
    printf("sbc x0, x1, x2 => 0x%08X\n", sbc_enc);
    printf("Difference     => 0x%08X\n", adc_enc ^ sbc_enc);

    // They should only differ in bit 30 (op field)
    uint diff = adc_enc ^ sbc_enc;
    assert(diff == (1 << 30), "ADC and SBC should only differ in bit 30");

    // Verify op bit
    assert(!((adc_enc >> 30) & 1), "ADC should have op=0");
    assert((sbc_enc >> 30) & 1, "SBC should have op=1");

    printf("✓ ADC and SBC differ only in op bit (bit 30)\n");
    printf("\n");
}

void verifyNEGS()
{
    printf("Testing NEGS (Negate with Flags) Encoding:\n");
    printf("===========================================\n");

    // negs x0, x1 - negate and set flags
    uint enc = INSTR.neg_sub_addsub_shift(1, 1, 0, 1, 0, 0);
    printf("negs x0, x1                => 0x%08X\n", enc);

    // Verify sf bit (bit 31) for 64-bit
    assert((enc >> 31) & 1, "NEGS 64-bit should have sf=1");

    // Verify S bit (bit 29) - 1 for NEGS (set flags)
    assert((enc >> 29) & 1, "NEGS should have S=1");

    // Verify Rn is 31 (XZR) - NEG subtracts from zero
    assert(((enc >> 5) & 0x1F) == 31, "NEGS Rn should be 31 (XZR)");

    // Test 32-bit variant
    uint enc_w = INSTR.neg_sub_addsub_shift(0, 1, 0, 5, 0, 7);
    printf("negs w7, w5                => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "NEGS 32-bit should have sf=0");

    // Compare with NEG (without flags)
    uint neg_enc = INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 0, 0);
    uint negs_enc = INSTR.neg_sub_addsub_shift(1, 1, 0, 1, 0, 0);

    printf("neg x0, x1  => 0x%08X (S=0)\n", neg_enc);
    printf("negs x0, x1 => 0x%08X (S=1)\n", negs_enc);

    // They should only differ in S bit (bit 29)
    uint diff = neg_enc ^ negs_enc;
    assert(diff == (1 << 29), "NEG and NEGS should only differ in bit 29");

    printf("✓ NEG and NEGS differ only in S bit (bit 29)\n");
    printf("\n");
}

void verifyUBFM()
{
    printf("Testing UBFM (Unsigned Bitfield Move) Encoding:\n");
    printf("================================================\n");

    // ubfm x0, x1, #5, #10 - extract bits [10:5]
    uint enc = INSTR.ubfm(1, 1, 5, 10, 1, 0);
    printf("ubfm x0, x1, #5, #10       => 0x%08X\n", enc);

    // Verify sf bit (bit 31) for 64-bit
    assert((enc >> 31) & 1, "UBFM 64-bit should have sf=1");

    // Verify opc field (bits [30:29]) - 2 for UBFM
    uint opc = (enc >> 29) & 3;
    assert(opc == 2, "UBFM should have opc=2");

    // Verify N bit (bit 22) matches sf
    assert((enc >> 22) & 1, "UBFM 64-bit should have N=1");

    // Verify immr field (bits [21:16])
    uint immr = (enc >> 16) & 0x3F;
    assert(immr == 5, "UBFM immr should be 5");

    // Verify imms field (bits [15:10])
    uint imms = (enc >> 10) & 0x3F;
    assert(imms == 10, "UBFM imms should be 10");

    // Verify register fields
    assert((enc & 0x1F) == 0, "UBFM Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "UBFM Rn should be 1");

    // Test 32-bit variant
    uint enc_w = INSTR.ubfm(0, 0, 3, 7, 5, 6);
    printf("ubfm w6, w5, #3, #7        => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "UBFM 32-bit should have sf=0");
    assert(!((enc_w >> 22) & 1), "UBFM 32-bit should have N=0");

    printf("\n");
}

void verifySBFM()
{
    printf("Testing SBFM (Signed Bitfield Move) Encoding:\n");
    printf("==============================================\n");

    // sbfm x0, x1, #5, #10 - signed extract bits [10:5]
    uint enc = INSTR.sbfm(1, 1, 5, 10, 1, 0);
    printf("sbfm x0, x1, #5, #10       => 0x%08X\n", enc);

    // Verify sf bit (bit 31) for 64-bit
    assert((enc >> 31) & 1, "SBFM 64-bit should have sf=1");

    // Verify opc field (bits [30:29]) - 0 for SBFM
    uint opc = (enc >> 29) & 3;
    assert(opc == 0, "SBFM should have opc=0");

    // Verify N bit (bit 22) matches sf
    assert((enc >> 22) & 1, "SBFM 64-bit should have N=1");

    // Verify immr and imms fields
    uint immr = (enc >> 16) & 0x3F;
    uint imms = (enc >> 10) & 0x3F;
    assert(immr == 5, "SBFM immr should be 5");
    assert(imms == 10, "SBFM imms should be 10");

    // Verify register fields
    assert((enc & 0x1F) == 0, "SBFM Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "SBFM Rn should be 1");

    // Test 32-bit variant
    uint enc_w = INSTR.sbfm(0, 0, 3, 7, 5, 6);
    printf("sbfm w6, w5, #3, #7        => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "SBFM 32-bit should have sf=0");

    printf("\n");
}

void verifyBFM()
{
    printf("Testing BFM (Bitfield Move/Insert) Encoding:\n");
    printf("============================================\n");

    // bfm x0, x1, #5, #10 - insert bits from x1 into x0
    uint enc = INSTR.bfm(1, 1, 5, 10, 1, 0);
    printf("bfm x0, x1, #5, #10        => 0x%08X\n", enc);

    // Verify sf bit (bit 31) for 64-bit
    assert((enc >> 31) & 1, "BFM 64-bit should have sf=1");

    // Verify opc field (bits [30:29]) - 1 for BFM
    uint opc = (enc >> 29) & 3;
    assert(opc == 1, "BFM should have opc=1");

    // Verify N bit (bit 22) matches sf
    assert((enc >> 22) & 1, "BFM 64-bit should have N=1");

    // Verify immr and imms fields
    uint immr = (enc >> 16) & 0x3F;
    uint imms = (enc >> 10) & 0x3F;
    assert(immr == 5, "BFM immr should be 5");
    assert(imms == 10, "BFM imms should be 10");

    // Verify register fields
    assert((enc & 0x1F) == 0, "BFM Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "BFM Rn should be 1");

    // Test 32-bit variant
    uint enc_w = INSTR.bfm(0, 0, 3, 7, 5, 6);
    printf("bfm w6, w5, #3, #7         => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "BFM 32-bit should have sf=0");

    printf("\n");
}

void verifyBitfieldDifferences()
{
    printf("Testing Bitfield Instruction Differences:\n");
    printf("==========================================\n");

    // All three with same operands
    uint ubfm_enc = INSTR.ubfm(1, 1, 5, 10, 1, 0);
    uint sbfm_enc = INSTR.sbfm(1, 1, 5, 10, 1, 0);
    uint bfm_enc = INSTR.bfm(1, 1, 5, 10, 1, 0);

    printf("ubfm x0, x1, #5, #10 => 0x%08X (opc=2)\n", ubfm_enc);
    printf("sbfm x0, x1, #5, #10 => 0x%08X (opc=0)\n", sbfm_enc);
    printf("bfm x0, x1, #5, #10  => 0x%08X (opc=1)\n", bfm_enc);

    // Verify they differ only in opc field (bits [30:29])
    uint ubfm_opc = (ubfm_enc >> 29) & 3;
    uint sbfm_opc = (sbfm_enc >> 29) & 3;
    uint bfm_opc = (bfm_enc >> 29) & 3;

    assert(sbfm_opc == 0, "SBFM should have opc=0");
    assert(bfm_opc == 1, "BFM should have opc=1");
    assert(ubfm_opc == 2, "UBFM should have opc=2");

    // Everything except opc should be the same
    uint mask = ~(3 << 29);  // Mask out opc field
    assert((ubfm_enc & mask) == (sbfm_enc & mask), "UBFM and SBFM should differ only in opc");
    assert((ubfm_enc & mask) == (bfm_enc & mask), "UBFM and BFM should differ only in opc");

    printf("✓ All bitfield instructions differ only in opc field\n");
    printf("\n");
}

void verifyRegisterEncodings()
{
    printf("Testing Register Encodings:\n");
    printf("===========================\n");

    // Test ADC with all registers
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.adc(1, r, r, r);
        assert((enc & 0x1F) == r, "ADC Rd encoding failed");
        assert(((enc >> 5) & 0x1F) == r, "ADC Rn encoding failed");
        assert(((enc >> 16) & 0x1F) == r, "ADC Rm encoding failed");
    }
    printf("✓ ADC: All registers (0-30) encode correctly\n");

    // Test SBC with all registers
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.sbc(1, r, r, r);
        assert((enc & 0x1F) == r, "SBC Rd encoding failed");
        assert(((enc >> 5) & 0x1F) == r, "SBC Rn encoding failed");
        assert(((enc >> 16) & 0x1F) == r, "SBC Rm encoding failed");
    }
    printf("✓ SBC: All registers (0-30) encode correctly\n");

    // Test UBFM with all registers
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.ubfm(1, 1, 0, 10, r, r);
        assert((enc & 0x1F) == r, "UBFM Rd encoding failed");
        assert(((enc >> 5) & 0x1F) == r, "UBFM Rn encoding failed");
    }
    printf("✓ UBFM: All registers (0-30) encode correctly\n");

    printf("\n");
}

void verifyCommonPatterns()
{
    printf("Testing Common Usage Patterns:\n");
    printf("==============================\n");

    // Multi-word addition with carry
    printf("Multi-word addition:\n");
    printf("  adds x0, x1, x2  (sets carry)\n");
    printf("  adc x3, x4, x5   (uses carry) => 0x%08X\n", INSTR.adc(1, 5, 4, 3));

    // Multi-word subtraction with borrow
    printf("Multi-word subtraction:\n");
    printf("  subs x0, x1, x2  (sets borrow)\n");
    printf("  sbc x3, x4, x5   (uses borrow) => 0x%08X\n", INSTR.sbc(1, 5, 4, 3));

    // Extract and zero-extend bits
    printf("Extract bits 15-8, zero-extend:\n");
    printf("  ubfm x0, x1, #8, #15 => 0x%08X\n", INSTR.ubfm(1, 1, 8, 15, 1, 0));

    // Extract and sign-extend bits
    printf("Extract bits 15-8, sign-extend:\n");
    printf("  sbfm x0, x1, #8, #15 => 0x%08X\n", INSTR.sbfm(1, 1, 8, 15, 1, 0));

    // Insert bits into a field
    printf("Insert bits into field:\n");
    printf("  bfm x0, x1, #8, #15 => 0x%08X\n", INSTR.bfm(1, 1, 8, 15, 1, 0));

    printf("\n");
}

unittest
{
    verifyADC();
    verifySBC();
    verifyADCvsSBC();
    verifyNEGS();
    verifyUBFM();
    verifySBFM();
    verifyBFM();
    verifyBitfieldDifferences();
    verifyRegisterEncodings();
    verifyCommonPatterns();
}
