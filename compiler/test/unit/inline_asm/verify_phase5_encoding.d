module inline_asm.verify_phase5_encoding;

/**
 * Verification program for Phase 5 encoding functions
 * Tests the encoding functions directly to verify correctness
 */

import dmd.backend.arm.instr : INSTR;
import core.stdc.stdio;

void verifyLDPEncoding()
{
    printf("Testing LDP (Load Pair) Encoding:\n");
    printf("==================================\n");

    // ldp x0, x1, [x2] - offset mode with zero offset
    uint enc = INSTR.ldstpair_off(2, 0, 1, 0, 1, 2, 0);
    printf("ldp x0, x1, [x2]           => 0x%08X\n", enc);
    assert(enc != 0, "LDP encoding should be non-zero");

    // ldp x3, x4, [x5, #16] - offset mode with immediate
    // Offset is in units of 8 bytes for 64-bit, so #16 = 2 * 8
    enc = INSTR.ldstpair_off(2, 0, 1, 2, 4, 5, 3);
    printf("ldp x3, x4, [x5, #16]      => 0x%08X\n", enc);

    // ldp x6, x7, [x8, #16]! - pre-indexed mode
    enc = INSTR.ldstpair_pre(2, 0, 1, 2, 7, 8, 6);
    printf("ldp x6, x7, [x8, #16]!     => 0x%08X\n", enc);

    // ldp x9, x10, [x11], #16 - post-indexed mode
    enc = INSTR.ldstpair_post(2, 0, 1, 2, 10, 11, 9);
    printf("ldp x9, x10, [x11], #16    => 0x%08X\n", enc);

    // ldp w12, w13, [x14] - 32-bit variant
    enc = INSTR.ldstpair_off(0, 0, 1, 0, 13, 14, 12);
    printf("ldp w12, w13, [x14]        => 0x%08X\n", enc);

    printf("\n");
}

void verifySTPEncoding()
{
    printf("Testing STP (Store Pair) Encoding:\n");
    printf("===================================\n");

    // stp x0, x1, [x2] - offset mode with zero offset
    uint enc = INSTR.ldstpair_off(2, 0, 0, 0, 1, 2, 0);
    printf("stp x0, x1, [x2]           => 0x%08X\n", enc);
    assert(enc != 0, "STP encoding should be non-zero");

    // stp x3, x4, [x5, #16] - offset mode with immediate
    enc = INSTR.ldstpair_off(2, 0, 0, 2, 4, 5, 3);
    printf("stp x3, x4, [x5, #16]      => 0x%08X\n", enc);

    // stp x6, x7, [x8, #16]! - pre-indexed mode
    enc = INSTR.ldstpair_pre(2, 0, 0, 2, 7, 8, 6);
    printf("stp x6, x7, [x8, #16]!     => 0x%08X\n", enc);

    // stp x9, x10, [x11], #16 - post-indexed mode
    enc = INSTR.ldstpair_post(2, 0, 0, 2, 10, 11, 9);
    printf("stp x9, x10, [x11], #16    => 0x%08X\n", enc);

    // stp w12, w13, [x14] - 32-bit variant
    enc = INSTR.ldstpair_off(0, 0, 0, 0, 13, 14, 12);
    printf("stp w12, w13, [x14]        => 0x%08X\n", enc);

    printf("\n");
}

void verifyLDPvsSTP()
{
    printf("Testing LDP vs STP Difference:\n");
    printf("==============================\n");

    uint ldp_enc = INSTR.ldstpair_off(2, 0, 1, 0, 2, 1, 0);
    uint stp_enc = INSTR.ldstpair_off(2, 0, 0, 0, 2, 1, 0);

    printf("ldp x0, x1, [x2] => 0x%08X\n", ldp_enc);
    printf("stp x0, x1, [x2] => 0x%08X\n", stp_enc);

    assert(ldp_enc != stp_enc, "LDP and STP should differ");
    printf("✓ LDP and STP have distinct encodings\n");

    printf("\n");
}

void verifyLDRBEncoding()
{
    printf("Testing LDRB (Load Byte) Encoding:\n");
    printf("===================================\n");

    // ldrb w0, [x1]
    uint enc = INSTR.ldrb_imm(0, 0, 1, 0);
    printf("ldrb w0, [x1]              => 0x%08X\n", enc);
    assert(enc != 0, "LDRB encoding should be non-zero");

    // Verify size field (bits [31:30] should be 00 for byte)
    uint size = (enc >> 30) & 3;
    assert(size == 0, "LDRB size field should be 0");

    // ldrb w2, [x3, #4]
    enc = INSTR.ldrb_imm(0, 2, 3, 4);
    printf("ldrb w2, [x3, #4]          => 0x%08X\n", enc);

    // ldrb w4, [x5, #255]
    enc = INSTR.ldrb_imm(0, 4, 5, 255);
    printf("ldrb w4, [x5, #255]        => 0x%08X\n", enc);

    printf("\n");
}

void verifySTRBEncoding()
{
    printf("Testing STRB (Store Byte) Encoding:\n");
    printf("====================================\n");

    // strb w0, [x1]
    uint enc = INSTR.strb_imm(0, 1, 0);
    printf("strb w0, [x1]              => 0x%08X\n", enc);
    assert(enc != 0, "STRB encoding should be non-zero");

    // Verify size field (bits [31:30] should be 00 for byte)
    uint size = (enc >> 30) & 3;
    assert(size == 0, "STRB size field should be 0");

    // strb w2, [x3, #4]
    enc = INSTR.strb_imm(2, 3, 4);
    printf("strb w2, [x3, #4]          => 0x%08X\n", enc);

    // strb w4, [x5, #255]
    enc = INSTR.strb_imm(4, 5, 255);
    printf("strb w4, [x5, #255]        => 0x%08X\n", enc);

    printf("\n");
}

void verifyLDRHEncoding()
{
    printf("Testing LDRH (Load Halfword) Encoding:\n");
    printf("=======================================\n");

    // ldrh w0, [x1]
    uint enc = INSTR.ldrh_imm(0, 0, 1, 0);
    printf("ldrh w0, [x1]              => 0x%08X\n", enc);
    assert(enc != 0, "LDRH encoding should be non-zero");

    // Verify size field (bits [31:30] should be 01 for halfword)
    uint size = (enc >> 30) & 3;
    assert(size == 1, "LDRH size field should be 1");

    // ldrh w2, [x3, #8]
    enc = INSTR.ldrh_imm(0, 2, 3, 8);
    printf("ldrh w2, [x3, #8]          => 0x%08X\n", enc);

    // ldrh w4, [x5, #510]
    enc = INSTR.ldrh_imm(0, 4, 5, 510);
    printf("ldrh w4, [x5, #510]        => 0x%08X\n", enc);

    printf("\n");
}

void verifySTRHEncoding()
{
    printf("Testing STRH (Store Halfword) Encoding:\n");
    printf("========================================\n");

    // strh w0, [x1]
    uint enc = INSTR.strh_imm(0, 1, 0);
    printf("strh w0, [x1]              => 0x%08X\n", enc);
    assert(enc != 0, "STRH encoding should be non-zero");

    // Verify size field (bits [31:30] should be 01 for halfword)
    uint size = (enc >> 30) & 3;
    assert(size == 1, "STRH size field should be 1");

    // strh w2, [x3, #8]
    enc = INSTR.strh_imm(2, 3, 8);
    printf("strh w2, [x3, #8]          => 0x%08X\n", enc);

    // strh w4, [x5, #510]
    enc = INSTR.strh_imm(4, 5, 510);
    printf("strh w4, [x5, #510]        => 0x%08X\n", enc);

    printf("\n");
}

void verifyLDRSBEncoding()
{
    printf("Testing LDRSB (Load Signed Byte) Encoding:\n");
    printf("===========================================\n");

    // ldrsb w0, [x1] - sign-extend to 32-bit
    uint enc = INSTR.ldrsb_imm(0, 0, 1, 0);
    printf("ldrsb w0, [x1]             => 0x%08X\n", enc);
    assert(enc != 0, "LDRSB encoding should be non-zero");

    // ldrsb x2, [x3] - sign-extend to 64-bit
    uint enc_x = INSTR.ldrsb_imm(1, 2, 3, 0);
    printf("ldrsb x2, [x3]             => 0x%08X\n", enc_x);

    // Verify that W and X variants are different
    assert(enc != enc_x, "LDRSB w and LDRSB x should differ");

    // ldrsb w4, [x5, #4]
    enc = INSTR.ldrsb_imm(0, 4, 5, 4);
    printf("ldrsb w4, [x5, #4]         => 0x%08X\n", enc);

    // ldrsb x6, [x7, #255]
    enc = INSTR.ldrsb_imm(1, 6, 7, 255);
    printf("ldrsb x6, [x7, #255]       => 0x%08X\n", enc);

    printf("\n");
}

void verifyLDRSHEncoding()
{
    printf("Testing LDRSH (Load Signed Halfword) Encoding:\n");
    printf("===============================================\n");

    // ldrsh w0, [x1] - sign-extend to 32-bit
    uint enc = INSTR.ldrsh_imm(0, 0, 1, 0);
    printf("ldrsh w0, [x1]             => 0x%08X\n", enc);
    assert(enc != 0, "LDRSH encoding should be non-zero");

    // ldrsh x2, [x3] - sign-extend to 64-bit
    uint enc_x = INSTR.ldrsh_imm(1, 2, 3, 0);
    printf("ldrsh x2, [x3]             => 0x%08X\n", enc_x);

    // Verify that W and X variants are different
    assert(enc != enc_x, "LDRSH w and LDRSH x should differ");

    // Verify size field (bits [31:30] should be 01 for halfword)
    uint size = (enc >> 30) & 3;
    assert(size == 1, "LDRSH size field should be 1");

    // ldrsh w4, [x5, #8]
    enc = INSTR.ldrsh_imm(0, 4, 5, 8);
    printf("ldrsh w4, [x5, #8]         => 0x%08X\n", enc);

    // ldrsh x6, [x7, #510]
    enc = INSTR.ldrsh_imm(1, 6, 7, 510);
    printf("ldrsh x6, [x7, #510]       => 0x%08X\n", enc);

    printf("\n");
}

void verifyLDRSWEncoding()
{
    printf("Testing LDRSW (Load Signed Word) Encoding:\n");
    printf("===========================================\n");

    // ldrsw x0, [x1] - sign-extend 32-bit to 64-bit
    uint enc = INSTR.ldrsw_imm(0, 1, 0);
    printf("ldrsw x0, [x1]             => 0x%08X\n", enc);
    assert(enc != 0, "LDRSW encoding should be non-zero");

    // Verify size field (bits [31:30] should be 10 for word)
    uint size = (enc >> 30) & 3;
    assert(size == 2, "LDRSW size field should be 2");

    // ldrsw x2, [x3, #8] - offset needs to be scaled: 8/4 = 2
    enc = INSTR.ldrsw_imm(2, 3, 2);
    printf("ldrsw x2, [x3, #8]         => 0x%08X\n", enc);

    // ldrsw x4, [x5, #1020] - offset needs to be scaled: 1020/4 = 255
    enc = INSTR.ldrsw_imm(255, 5, 4);
    printf("ldrsw x4, [x5, #1020]      => 0x%08X\n", enc);

    printf("\n");
}

void verifySizeFieldDistinctions()
{
    printf("Testing Size Field Distinctions:\n");
    printf("=================================\n");

    uint ldrb_enc = INSTR.ldrb_imm(0, 0, 1, 0);    // size = 00
    uint ldrh_enc = INSTR.ldrh_imm(0, 0, 1, 0);    // size = 01
    uint ldrsw_enc = INSTR.ldrsw_imm(0, 1, 0);     // size = 10

    printf("ldrb w0, [x1] => 0x%08X (size=%d)\n", ldrb_enc, (ldrb_enc >> 30) & 3);
    printf("ldrh w0, [x1] => 0x%08X (size=%d)\n", ldrh_enc, (ldrh_enc >> 30) & 3);
    printf("ldrsw x0, [x1] => 0x%08X (size=%d)\n", ldrsw_enc, (ldrsw_enc >> 30) & 3);

    // Verify all three have different size fields
    assert(((ldrb_enc >> 30) & 3) == 0, "LDRB size should be 0");
    assert(((ldrh_enc >> 30) & 3) == 1, "LDRH size should be 1");
    assert(((ldrsw_enc >> 30) & 3) == 2, "LDRSW size should be 2");

    // Verify all three produce different encodings
    assert(ldrb_enc != ldrh_enc, "LDRB and LDRH should differ");
    assert(ldrb_enc != ldrsw_enc, "LDRB and LDRSW should differ");
    assert(ldrh_enc != ldrsw_enc, "LDRH and LDRSW should differ");

    printf("✓ All size fields are distinct\n");

    printf("\n");
}

void verifyLoadStoreDistinctions()
{
    printf("Testing Load vs Store Distinctions:\n");
    printf("====================================\n");

    // Byte
    uint ldrb_enc = INSTR.ldrb_imm(0, 0, 1, 0);
    uint strb_enc = INSTR.strb_imm(0, 1, 0);
    printf("ldrb w0, [x1] => 0x%08X\n", ldrb_enc);
    printf("strb w0, [x1] => 0x%08X\n", strb_enc);
    assert(ldrb_enc != strb_enc, "LDRB and STRB should differ");

    // Halfword
    uint ldrh_enc = INSTR.ldrh_imm(0, 0, 1, 0);
    uint strh_enc = INSTR.strh_imm(0, 1, 0);
    printf("ldrh w0, [x1] => 0x%08X\n", ldrh_enc);
    printf("strh w0, [x1] => 0x%08X\n", strh_enc);
    assert(ldrh_enc != strh_enc, "LDRH and STRH should differ");

    printf("✓ Load and store encodings are distinct\n");

    printf("\n");
}

void verifyPairAddressingModes()
{
    printf("Testing Pair Instruction Addressing Modes:\n");
    printf("===========================================\n");

    uint ldp_offset = INSTR.ldstpair_off(2, 0, 1, 0, 2, 1, 0);  // [Xn, #imm]
    uint ldp_pre = INSTR.ldstpair_pre(2, 0, 1, 0, 2, 1, 0);     // [Xn, #imm]!
    uint ldp_post = INSTR.ldstpair_post(2, 0, 1, 0, 2, 1, 0);   // [Xn], #imm

    printf("ldp x0, x1, [x2]     => 0x%08X (offset)\n", ldp_offset);
    printf("ldp x0, x1, [x2]!    => 0x%08X (pre-indexed)\n", ldp_pre);
    printf("ldp x0, x1, [x2], #0 => 0x%08X (post-indexed)\n", ldp_post);

    assert(ldp_offset != ldp_pre, "Offset and pre-indexed should differ");
    assert(ldp_offset != ldp_post, "Offset and post-indexed should differ");
    assert(ldp_pre != ldp_post, "Pre-indexed and post-indexed should differ");

    printf("✓ All addressing modes are distinct\n");

    printf("\n");
}

void verifyRegisterEncodings()
{
    printf("Testing Register Encodings:\n");
    printf("===========================\n");

    // Test that different registers produce different encodings
    printf("LDRB with different registers:\n");
    for (ubyte r = 0; r < 5; r++)
    {
        uint enc = INSTR.ldrb_imm(0, r, r, 0);
        printf("  ldrb w%d, [x%d] => 0x%08X\n", r, r, enc);
    }

    // Verify two different registers produce different encodings
    uint enc0 = INSTR.ldrb_imm(0, 0, 0, 0);
    uint enc1 = INSTR.ldrb_imm(0, 1, 1, 0);
    assert(enc0 != enc1, "Different registers should produce different encodings");
    printf("✓ Register encodings are distinct\n");

    printf("\n");
}

unittest
{
    verifyLDPEncoding();
    verifySTPEncoding();
    verifyLDPvsSTP();
    verifyLDRBEncoding();
    verifySTRBEncoding();
    verifyLDRHEncoding();
    verifySTRHEncoding();
    verifyLDRSBEncoding();
    verifyLDRSHEncoding();
    verifyLDRSWEncoding();
    verifySizeFieldDistinctions();
    verifyLoadStoreDistinctions();
    verifyPairAddressingModes();
    verifyRegisterEncodings();
}
