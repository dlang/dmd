module inline_asm.verify_phase4_3_encoding;

/**
 * Verification program for Phase 4.3 shift and bit manipulation instruction encodings
 * Tests the encoding functions directly to verify correctness
 */

import dmd.backend.arm.instr : INSTR;
import core.stdc.stdio;

void verifyLSL_Immediate()
{
    printf("Testing LSL (Logical Shift Left) Immediate Encoding:\n");
    printf("====================================================\n");

    // lsl x0, x1, #5 - shift x1 left by 5 bits
    // LSL is an alias for UBFM with specific parameters
    uint enc = INSTR.lsl_ubfm(1, 5, 1, 0);
    printf("lsl x0, x1, #5             => 0x%08X\n", enc);

    // Verify sf bit (bit 31) for 64-bit
    assert((enc >> 31) & 1, "LSL 64-bit should have sf=1");

    // Test 32-bit variant
    uint enc_w = INSTR.lsl_ubfm(0, 3, 5, 7);
    printf("lsl w7, w5, #3             => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "LSL 32-bit should have sf=0");

    // Test maximum shift amounts
    uint enc_max64 = INSTR.lsl_ubfm(1, 63, 1, 0);
    printf("lsl x0, x1, #63            => 0x%08X\n", enc_max64);

    uint enc_max32 = INSTR.lsl_ubfm(0, 31, 1, 0);
    printf("lsl w0, w1, #31            => 0x%08X\n", enc_max32);

    // Test shift by 0 (no-op)
    uint enc_zero = INSTR.lsl_ubfm(1, 0, 1, 0);
    printf("lsl x0, x1, #0             => 0x%08X\n", enc_zero);

    printf("\n");
}

void verifyLSR_Immediate()
{
    printf("Testing LSR (Logical Shift Right) Immediate Encoding:\n");
    printf("======================================================\n");

    // lsr x0, x1, #5 - shift x1 right by 5 bits (logical)
    uint enc = INSTR.lsr_ubfm(1, 5, 1, 0);
    printf("lsr x0, x1, #5             => 0x%08X\n", enc);

    // Verify sf bit for 64-bit
    assert((enc >> 31) & 1, "LSR 64-bit should have sf=1");

    // Test 32-bit variant
    uint enc_w = INSTR.lsr_ubfm(0, 3, 5, 7);
    printf("lsr w7, w5, #3             => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "LSR 32-bit should have sf=0");

    // Test maximum shift amounts
    uint enc_max64 = INSTR.lsr_ubfm(1, 63, 1, 0);
    printf("lsr x0, x1, #63            => 0x%08X\n", enc_max64);

    uint enc_max32 = INSTR.lsr_ubfm(0, 31, 1, 0);
    printf("lsr w0, w1, #31            => 0x%08X\n", enc_max32);

    printf("\n");
}

void verifyASR_Immediate()
{
    printf("Testing ASR (Arithmetic Shift Right) Immediate Encoding:\n");
    printf("=========================================================\n");

    // asr x0, x1, #5 - shift x1 right by 5 bits (arithmetic)
    uint enc = INSTR.asr_sbfm(1, 5, 1, 0);
    printf("asr x0, x1, #5             => 0x%08X\n", enc);

    // Verify sf bit for 64-bit
    assert((enc >> 31) & 1, "ASR 64-bit should have sf=1");

    // Test 32-bit variant
    uint enc_w = INSTR.asr_sbfm(0, 3, 5, 7);
    printf("asr w7, w5, #3             => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "ASR 32-bit should have sf=0");

    // Test maximum shift amounts
    uint enc_max64 = INSTR.asr_sbfm(1, 63, 1, 0);
    printf("asr x0, x1, #63            => 0x%08X\n", enc_max64);

    uint enc_max32 = INSTR.asr_sbfm(0, 31, 1, 0);
    printf("asr w0, w1, #31            => 0x%08X\n", enc_max32);

    printf("\n");
}

void verifyROR_Immediate()
{
    printf("Testing ROR (Rotate Right) Immediate Encoding:\n");
    printf("===============================================\n");

    // ror x0, x1, #5 - rotate x1 right by 5 bits
    uint enc = INSTR.ror_extr(1, 5, 1, 0);
    printf("ror x0, x1, #5             => 0x%08X\n", enc);

    // Verify sf bit for 64-bit
    assert((enc >> 31) & 1, "ROR 64-bit should have sf=1");

    // Test 32-bit variant
    uint enc_w = INSTR.ror_extr(0, 3, 5, 7);
    printf("ror w7, w5, #3             => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "ROR 32-bit should have sf=0");

    // Test maximum rotate amounts
    uint enc_max64 = INSTR.ror_extr(1, 63, 1, 0);
    printf("ror x0, x1, #63            => 0x%08X\n", enc_max64);

    uint enc_max32 = INSTR.ror_extr(0, 31, 1, 0);
    printf("ror w0, w1, #31            => 0x%08X\n", enc_max32);

    printf("\n");
}

void verifyLSLV_Register()
{
    printf("Testing LSLV (Logical Shift Left Variable) Register Encoding:\n");
    printf("==============================================================\n");

    // lslv x0, x1, x2 - shift x1 left by amount in x2
    uint enc = INSTR.lslv(1, 2, 1, 0);
    printf("lsl x0, x1, x2             => 0x%08X\n", enc);

    // Verify sf bit for 64-bit
    assert((enc >> 31) & 1, "LSLV 64-bit should have sf=1");

    // Verify register fields
    assert((enc & 0x1F) == 0, "LSLV Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "LSLV Rn should be 1");
    assert(((enc >> 16) & 0x1F) == 2, "LSLV Rm should be 2");

    // Test 32-bit variant
    uint enc_w = INSTR.lslv(0, 5, 6, 7);
    printf("lsl w7, w6, w5             => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "LSLV 32-bit should have sf=0");

    // Test different registers
    uint enc2 = INSTR.lslv(1, 10, 11, 12);
    printf("lsl x12, x11, x10          => 0x%08X\n", enc2);

    printf("\n");
}

void verifyLSRV_Register()
{
    printf("Testing LSRV (Logical Shift Right Variable) Register Encoding:\n");
    printf("===============================================================\n");

    // lsrv x0, x1, x2 - shift x1 right by amount in x2
    uint enc = INSTR.lsrv(1, 2, 1, 0);
    printf("lsr x0, x1, x2             => 0x%08X\n", enc);

    // Verify sf bit for 64-bit
    assert((enc >> 31) & 1, "LSRV 64-bit should have sf=1");

    // Verify register fields
    assert((enc & 0x1F) == 0, "LSRV Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "LSRV Rn should be 1");
    assert(((enc >> 16) & 0x1F) == 2, "LSRV Rm should be 2");

    // Test 32-bit variant
    uint enc_w = INSTR.lsrv(0, 5, 6, 7);
    printf("lsr w7, w6, w5             => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "LSRV 32-bit should have sf=0");

    printf("\n");
}

void verifyASRV_Register()
{
    printf("Testing ASRV (Arithmetic Shift Right Variable) Register Encoding:\n");
    printf("==================================================================\n");

    // asrv x0, x1, x2 - shift x1 right by amount in x2 (arithmetic)
    uint enc = INSTR.asrv(1, 2, 1, 0);
    printf("asr x0, x1, x2             => 0x%08X\n", enc);

    // Verify sf bit for 64-bit
    assert((enc >> 31) & 1, "ASRV 64-bit should have sf=1");

    // Verify register fields
    assert((enc & 0x1F) == 0, "ASRV Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "ASRV Rn should be 1");
    assert(((enc >> 16) & 0x1F) == 2, "ASRV Rm should be 2");

    // Test 32-bit variant
    uint enc_w = INSTR.asrv(0, 5, 6, 7);
    printf("asr w7, w6, w5             => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "ASRV 32-bit should have sf=0");

    printf("\n");
}

void verifyRORV_Register()
{
    printf("Testing RORV (Rotate Right Variable) Register Encoding:\n");
    printf("========================================================\n");

    // rorv x0, x1, x2 - rotate x1 right by amount in x2
    uint enc = INSTR.rorv(1, 2, 1, 0);
    printf("ror x0, x1, x2             => 0x%08X\n", enc);

    // Verify sf bit for 64-bit
    assert((enc >> 31) & 1, "RORV 64-bit should have sf=1");

    // Verify register fields
    assert((enc & 0x1F) == 0, "RORV Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "RORV Rn should be 1");
    assert(((enc >> 16) & 0x1F) == 2, "RORV Rm should be 2");

    // Test 32-bit variant
    uint enc_w = INSTR.rorv(0, 5, 6, 7);
    printf("ror w7, w6, w5             => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "RORV 32-bit should have sf=0");

    printf("\n");
}

void verifyEXTR()
{
    printf("Testing EXTR (Extract) Encoding:\n");
    printf("================================\n");

    // extr x0, x1, x2, #8 - extract from x1:x2 at bit 8
    uint enc = INSTR.extr(1, 2, 8, 1, 0);
    printf("extr x0, x1, x2, #8        => 0x%08X\n", enc);

    // Verify sf bit for 64-bit
    assert((enc >> 31) & 1, "EXTR 64-bit should have sf=1");

    // Verify register fields
    assert((enc & 0x1F) == 0, "EXTR Rd should be 0");
    assert(((enc >> 5) & 0x1F) == 1, "EXTR Rn should be 1");
    assert(((enc >> 16) & 0x1F) == 2, "EXTR Rm should be 2");

    // Verify LSB field (bits [15:10])
    uint lsb = (enc >> 10) & 0x3F;
    assert(lsb == 8, "EXTR LSB should be 8");

    // Test 32-bit variant
    uint enc_w = INSTR.extr(0, 5, 4, 6, 7);
    printf("extr w7, w6, w5, #4        => 0x%08X\n", enc_w);
    assert(!((enc_w >> 31) & 1), "EXTR 32-bit should have sf=0");

    // Test various LSB values
    for (uint lsb_val = 0; lsb_val <= 63; lsb_val++)
    {
        uint test_enc = INSTR.extr(1, 2, lsb_val, 1, 0);
        uint decoded_lsb = (test_enc >> 10) & 0x3F;
        assert(decoded_lsb == lsb_val, "EXTR LSB encoding failed");
    }
    printf("✓ EXTR LSB values (0-63) encode correctly\n");

    printf("\n");
}

void verifyVariableShiftDistinction()
{
    printf("Testing Variable Shift Instruction Distinction:\n");
    printf("================================================\n");

    // All four variable shift instructions with same registers
    uint lslv = INSTR.lslv(1, 2, 1, 0);
    uint lsrv = INSTR.lsrv(1, 2, 1, 0);
    uint asrv = INSTR.asrv(1, 2, 1, 0);
    uint rorv = INSTR.rorv(1, 2, 1, 0);

    printf("lsl x0, x1, x2 => 0x%08X (opcode=%u)\n", lslv, (lslv >> 10) & 0x3F);
    printf("lsr x0, x1, x2 => 0x%08X (opcode=%u)\n", lsrv, (lsrv >> 10) & 0x3F);
    printf("asr x0, x1, x2 => 0x%08X (opcode=%u)\n", asrv, (asrv >> 10) & 0x3F);
    printf("ror x0, x1, x2 => 0x%08X (opcode=%u)\n", rorv, (rorv >> 10) & 0x3F);

    // Verify they're all different
    assert(lslv != lsrv, "LSLV and LSRV should differ");
    assert(lslv != asrv, "LSLV and ASRV should differ");
    assert(lslv != rorv, "LSLV and RORV should differ");
    assert(lsrv != asrv, "LSRV and ASRV should differ");
    assert(lsrv != rorv, "LSRV and RORV should differ");
    assert(asrv != rorv, "ASRV and RORV should differ");

    // Verify opcode field (bits [15:10])
    uint lslv_opc = (lslv >> 10) & 0x3F;
    uint lsrv_opc = (lsrv >> 10) & 0x3F;
    uint asrv_opc = (asrv >> 10) & 0x3F;
    uint rorv_opc = (rorv >> 10) & 0x3F;

    assert(lslv_opc == 0x08, "LSLV opcode should be 0x08");
    assert(lsrv_opc == 0x09, "LSRV opcode should be 0x09");
    assert(asrv_opc == 0x0A, "ASRV opcode should be 0x0A");
    assert(rorv_opc == 0x0B, "RORV opcode should be 0x0B");

    printf("✓ All variable shift opcodes are correct\n");
    printf("\n");
}

void verifyShiftRanges()
{
    printf("Testing Shift Amount Ranges:\n");
    printf("============================\n");

    // Test all valid 64-bit immediate shifts for LSL
    for (uint shift = 0; shift <= 63; shift++)
    {
        uint enc = INSTR.lsl_ubfm(1, shift, 1, 0);
        // Just verify it doesn't crash - full validation would check bit fields
    }
    printf("✓ LSL 64-bit shifts (0-63) encode without error\n");

    // Test all valid 32-bit immediate shifts for LSL
    for (uint shift = 0; shift <= 31; shift++)
    {
        uint enc = INSTR.lsl_ubfm(0, shift, 1, 0);
    }
    printf("✓ LSL 32-bit shifts (0-31) encode without error\n");

    // Test all valid shifts for LSR
    for (uint shift = 0; shift <= 63; shift++)
    {
        uint enc = INSTR.lsr_ubfm(1, shift, 1, 0);
    }
    printf("✓ LSR 64-bit shifts (0-63) encode without error\n");

    // Test all valid shifts for ASR
    for (uint shift = 0; shift <= 63; shift++)
    {
        uint enc = INSTR.asr_sbfm(1, shift, 1, 0);
    }
    printf("✓ ASR 64-bit shifts (0-63) encode without error\n");

    // Test all valid rotates for ROR
    for (uint shift = 0; shift <= 63; shift++)
    {
        uint enc = INSTR.ror_extr(1, shift, 1, 0);
    }
    printf("✓ ROR 64-bit rotates (0-63) encode without error\n");

    printf("\n");
}

void verifyRegisterEncodings()
{
    printf("Testing Register Encodings:\n");
    printf("===========================\n");

    // Test variable shift instructions with all registers
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.lslv(1, r, r, r);
        assert((enc & 0x1F) == r, "LSLV Rd encoding failed");
        assert(((enc >> 5) & 0x1F) == r, "LSLV Rn encoding failed");
        assert(((enc >> 16) & 0x1F) == r, "LSLV Rm encoding failed");
    }
    printf("✓ LSLV: All registers (0-30) encode correctly\n");

    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.lsrv(1, r, r, r);
        assert((enc & 0x1F) == r, "LSRV Rd encoding failed");
        assert(((enc >> 5) & 0x1F) == r, "LSRV Rn encoding failed");
        assert(((enc >> 16) & 0x1F) == r, "LSRV Rm encoding failed");
    }
    printf("✓ LSRV: All registers (0-30) encode correctly\n");

    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.asrv(1, r, r, r);
        assert((enc & 0x1F) == r, "ASRV Rd encoding failed");
        assert(((enc >> 5) & 0x1F) == r, "ASRV Rn encoding failed");
        assert(((enc >> 16) & 0x1F) == r, "ASRV Rm encoding failed");
    }
    printf("✓ ASRV: All registers (0-30) encode correctly\n");

    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.rorv(1, r, r, r);
        assert((enc & 0x1F) == r, "RORV Rd encoding failed");
        assert(((enc >> 5) & 0x1F) == r, "RORV Rn encoding failed");
        assert(((enc >> 16) & 0x1F) == r, "RORV Rm encoding failed");
    }
    printf("✓ RORV: All registers (0-30) encode correctly\n");

    printf("\n");
}

void verifyCommonPatterns()
{
    printf("Testing Common Usage Patterns:\n");
    printf("==============================\n");

    // Multiply by 2 (LSL by 1)
    printf("Multiply by 2:\n");
    printf("  lsl x0, x1, #1 => 0x%08X\n", INSTR.lsl_ubfm(1, 1, 1, 0));

    // Multiply by 16 (LSL by 4)
    printf("Multiply by 16:\n");
    printf("  lsl x0, x1, #4 => 0x%08X\n", INSTR.lsl_ubfm(1, 4, 1, 0));

    // Divide by 2 (LSR by 1, unsigned)
    printf("Divide by 2 (unsigned):\n");
    printf("  lsr x0, x1, #1 => 0x%08X\n", INSTR.lsr_ubfm(1, 1, 1, 0));

    // Divide by 2 (ASR by 1, signed)
    printf("Divide by 2 (signed):\n");
    printf("  asr x0, x1, #1 => 0x%08X\n", INSTR.asr_sbfm(1, 1, 1, 0));

    // Extract high 32 bits
    printf("Extract high 32 bits of 64-bit value:\n");
    printf("  lsr x0, x1, #32 => 0x%08X\n", INSTR.lsr_ubfm(1, 32, 1, 0));

    // Rotate for hash functions
    printf("Rotate for hash mixing:\n");
    printf("  ror x0, x1, #13 => 0x%08X\n", INSTR.ror_extr(1, 13, 1, 0));

    printf("\n");
}

unittest
{
    verifyLSL_Immediate();
    verifyLSR_Immediate();
    verifyASR_Immediate();
    verifyROR_Immediate();
    verifyLSLV_Register();
    verifyLSRV_Register();
    verifyASRV_Register();
    verifyRORV_Register();
    verifyEXTR();
    verifyVariableShiftDistinction();
    verifyShiftRanges();
    verifyRegisterEncodings();
    verifyCommonPatterns();
}
