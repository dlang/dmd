module inline_asm.verify_phase2_encoding;

/**
 * Verification program for Phase 2 encoding functions
 * This tests the encoding functions directly without requiring AArch64 target
 */

import dmd.backend.arm.instr : INSTR;
import core.stdc.stdio;

void verifyPreIndexedEncoding()
{
    printf("Testing Pre-Indexed Encoding:\n");
    printf("==============================\n");

    // ldr x0, [x1, #8]!
    uint enc = INSTR.ldst_immpre(3, 0, 1, 8, 1, 0);
    printf("ldr x0, [x1, #8]!    => 0x%08X\n", enc);
    assert((enc & (3 << 10)) == (3 << 10), "Pre-indexed bits should be 0b11");

    // str x2, [x3, #16]!
    enc = INSTR.ldst_immpre(3, 0, 0, 16, 3, 2);
    printf("str x2, [x3, #16]!   => 0x%08X\n", enc);

    // ldr w4, [x5, #4]!
    enc = INSTR.ldst_immpre(2, 0, 1, 4, 5, 4);
    printf("ldr w4, [x5, #4]!    => 0x%08X\n", enc);

    // Test negative offset: ldr x6, [x7, #-8]!
    uint imm9 = cast(uint)(-8) & 0x1FF;
    enc = INSTR.ldst_immpre(3, 0, 1, imm9, 7, 6);
    printf("ldr x6, [x7, #-8]!   => 0x%08X\n", enc);

    printf("\n");
}

void verifyPostIndexedEncoding()
{
    printf("Testing Post-Indexed Encoding:\n");
    printf("==============================\n");

    // ldr x0, [x1], #8
    uint enc = INSTR.ldst_immpost(3, 0, 1, 8, 1, 0);
    printf("ldr x0, [x1], #8     => 0x%08X\n", enc);
    assert((enc & (3 << 10)) == (1 << 10), "Post-indexed bits should be 0b01");

    // str x2, [x3], #16
    enc = INSTR.ldst_immpost(3, 0, 0, 16, 3, 2);
    printf("str x2, [x3], #16    => 0x%08X\n", enc);

    // ldr w4, [x5], #4
    enc = INSTR.ldst_immpost(2, 0, 1, 4, 5, 4);
    printf("ldr w4, [x5], #4     => 0x%08X\n", enc);

    // Test negative offset: str x6, [x7], #-16
    uint imm9 = cast(uint)(-16) & 0x1FF;
    enc = INSTR.ldst_immpost(3, 0, 0, imm9, 7, 6);
    printf("str x6, [x7], #-16   => 0x%08X\n", enc);

    printf("\n");
}

void verifyExtendedRegisterOffset()
{
    printf("Testing Extended Register Offset:\n");
    printf("=================================\n");

    // ldr x0, [x1, x2, lsl #3]
    uint enc = INSTR.ldst_regoff(3, 0, 1, 2, 3, 1, 1, 0);
    printf("ldr x0, [x1, x2, lsl #3]   => 0x%08X\n", enc);

    // str x3, [x4, x5, lsl #3]
    enc = INSTR.ldst_regoff(3, 0, 0, 5, 3, 1, 4, 3);
    printf("str x3, [x4, x5, lsl #3]   => 0x%08X\n", enc);

    // ldr w6, [x7, x8, lsl #2]
    enc = INSTR.ldst_regoff(2, 0, 1, 8, 3, 1, 7, 6);
    printf("ldr w6, [x7, x8, lsl #2]   => 0x%08X\n", enc);

    // ldr x9, [x10, x11, uxtw #3]
    enc = INSTR.ldst_regoff(3, 0, 1, 11, 2, 1, 10, 9);
    printf("ldr x9, [x10, x11, uxtw #3] => 0x%08X\n", enc);

    // ldr x12, [x13, x14, sxtw #3]
    enc = INSTR.ldst_regoff(3, 0, 1, 14, 6, 1, 13, 12);
    printf("ldr x12, [x13, x14, sxtw #3] => 0x%08X\n", enc);

    // ldr x15, [x16, x17, sxtx #0]
    enc = INSTR.ldst_regoff(3, 0, 1, 17, 7, 0, 16, 15);
    printf("ldr x15, [x16, x17, sxtx #0] => 0x%08X\n", enc);

    // ldr x18, [x19, x20] - no extend (defaults to LSL)
    enc = INSTR.ldst_regoff(3, 0, 1, 20, 3, 0, 19, 18);
    printf("ldr x18, [x19, x20]         => 0x%08X\n", enc);

    printf("\n");
}

void verifyPrePostDifference()
{
    printf("Testing Pre vs Post Indexed Difference:\n");
    printf("========================================\n");

    uint pre_enc = INSTR.ldst_immpre(3, 0, 1, 8, 1, 0);
    uint post_enc = INSTR.ldst_immpost(3, 0, 1, 8, 1, 0);

    printf("Pre-indexed:  0x%08X\n", pre_enc);
    printf("Post-indexed: 0x%08X\n", post_enc);
    printf("Difference:   0x%08X\n", pre_enc ^ post_enc);

    uint diff = pre_enc ^ post_enc;
    assert(diff == (2 << 10), "Difference should only be in bits [11:10]");
    printf("✓ Only bits [11:10] differ\n");

    // Verify bit patterns
    printf("\nBit pattern analysis:\n");
    printf("Pre-indexed bits [11:10]:  %d%d\n", (pre_enc >> 11) & 1, (pre_enc >> 10) & 1);
    printf("Post-indexed bits [11:10]: %d%d\n", (post_enc >> 11) & 1, (post_enc >> 10) & 1);

    printf("\n");
}

void verifyStackOperations()
{
    printf("Testing Stack Operations (sp = x31):\n");
    printf("====================================\n");

    // str x29, [sp, #-16]!
    uint imm9 = cast(uint)(-16) & 0x1FF;
    uint enc = INSTR.ldst_immpre(3, 0, 0, imm9, 31, 29);
    printf("str x29, [sp, #-16]! => 0x%08X\n", enc);

    // ldr x29, [sp], #16
    enc = INSTR.ldst_immpost(3, 0, 1, 16, 31, 29);
    printf("ldr x29, [sp], #16   => 0x%08X\n", enc);

    // str x0, [sp, #-32]!
    imm9 = cast(uint)(-32) & 0x1FF;
    enc = INSTR.ldst_immpre(3, 0, 0, imm9, 31, 0);
    printf("str x0, [sp, #-32]!  => 0x%08X\n", enc);

    // ldr x0, [sp], #32
    enc = INSTR.ldst_immpost(3, 0, 1, 32, 31, 0);
    printf("ldr x0, [sp], #32    => 0x%08X\n", enc);

    printf("\n");
}

void verifyImmediateRanges()
{
    printf("Testing Immediate Range Limits:\n");
    printf("================================\n");

    // imm9 is 9-bit signed: -256 to +255

    // Maximum positive offset
    uint enc = INSTR.ldst_immpre(3, 0, 1, 255, 1, 0);
    printf("ldr x0, [x1, #255]!  => 0x%08X (max positive)\n", enc);

    // Maximum negative offset
    uint imm9 = cast(uint)(-256) & 0x1FF;
    enc = INSTR.ldst_immpre(3, 0, 1, imm9, 1, 0);
    printf("ldr x0, [x1, #-256]! => 0x%08X (max negative)\n", enc);

    // Zero offset
    enc = INSTR.ldst_immpre(3, 0, 1, 0, 1, 0);
    printf("ldr x0, [x1, #0]!    => 0x%08X (zero)\n", enc);

    printf("\n");
}

unittest
{
    verifyPreIndexedEncoding();
    verifyPostIndexedEncoding();
    verifyExtendedRegisterOffset();
    verifyPrePostDifference();
    verifyStackOperations();
    verifyImmediateRanges();
}
