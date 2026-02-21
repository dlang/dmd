module inline_asm.verify_phase6_encoding;

/**
 * Verification program for Phase 6 function call instruction encodings
 * Tests the encoding functions directly to verify correctness
 */

import dmd.backend.arm.instr : INSTR;
import core.stdc.stdio;

void verifyBLEncoding()
{
    printf("Testing BL (Branch with Link) Encoding:\n");
    printf("========================================\n");

    // bl with offset 0
    uint enc = INSTR.bl(0);
    printf("bl #0                    => 0x%08X\n", enc);
    assert((enc & (1 << 31)) != 0, "BL should have op=1 (bit 31 set)");
    assert((enc >> 26) == 0x25, "BL should have bits [30:26] = 0b10101");

    // bl with offset 0x100 (256 instructions forward = 1KB)
    enc = INSTR.bl(0x100);
    printf("bl #0x100                => 0x%08X\n", enc);
    assert((enc & 0x3FFFFFF) == 0x100, "BL offset encoding incorrect");

    // bl with maximum positive offset
    enc = INSTR.bl(0x1FFFFFF);
    printf("bl #0x1FFFFFF (max+)     => 0x%08X\n", enc);

    // bl with maximum negative offset (sign-extended)
    enc = INSTR.bl(0x2000000);  // Represents -0x2000000 in 26-bit signed
    printf("bl #0x2000000 (max-)     => 0x%08X\n", enc);

    printf("\n");
}

void verifyBLREncoding()
{
    printf("Testing BLR (Branch with Link to Register) Encoding:\n");
    printf("====================================================\n");

    // blr x0
    uint enc = INSTR.blr(0);
    printf("blr x0                   => 0x%08X\n", enc);
    uint opc = (enc >> 21) & 3;
    assert(opc == 1, "BLR should have opc=1");

    // blr x15
    enc = INSTR.blr(15);
    printf("blr x15                  => 0x%08X\n", enc);
    uint reg = (enc >> 5) & 0x1F;
    assert(reg == 15, "BLR register encoding incorrect");

    // blr x30 (link register)
    enc = INSTR.blr(30);
    printf("blr x30                  => 0x%08X\n", enc);

    printf("\n");
}

void verifyBREncoding()
{
    printf("Testing BR (Branch to Register) Encoding:\n");
    printf("==========================================\n");

    // br x0
    uint enc = INSTR.br(0);
    printf("br x0                    => 0x%08X\n", enc);
    uint opc = (enc >> 21) & 3;
    assert(opc == 0, "BR should have opc=0");

    // br x15
    enc = INSTR.br(15);
    printf("br x15                   => 0x%08X\n", enc);
    uint reg = (enc >> 5) & 0x1F;
    assert(reg == 15, "BR register encoding incorrect");

    // br x30
    enc = INSTR.br(30);
    printf("br x30                   => 0x%08X\n", enc);

    printf("\n");
}

void verifyRETEncoding()
{
    printf("Testing RET (Return) Encoding:\n");
    printf("==============================\n");

    // ret (defaults to x30)
    uint enc = INSTR.ret();
    printf("ret                      => 0x%08X\n", enc);
    assert(enc == 0xd65f03c0, "Default RET encoding should be 0xd65f03c0");
    uint opc = (enc >> 21) & 3;
    assert(opc == 2, "RET should have opc=2");

    // ret x30 (explicit)
    enc = INSTR.ret(30);
    printf("ret x30                  => 0x%08X\n", enc);
    assert(enc == 0xd65f03c0, "Explicit ret x30 should match default");

    // ret x0
    enc = INSTR.ret(0);
    printf("ret x0                   => 0x%08X\n", enc);
    uint reg = (enc >> 5) & 0x1F;
    assert(reg == 0, "RET x0 register encoding incorrect");

    // ret x15
    enc = INSTR.ret(15);
    printf("ret x15                  => 0x%08X\n", enc);

    printf("\n");
}

void verifyBranchRegOpcodes()
{
    printf("Testing Branch Register Opcode Differences:\n");
    printf("============================================\n");

    uint br_enc = INSTR.br(0);
    uint blr_enc = INSTR.blr(0);
    uint ret_enc = INSTR.ret(0);

    printf("br x0  => 0x%08X (opc=%d)\n", br_enc, (br_enc >> 21) & 3);
    printf("blr x0 => 0x%08X (opc=%d)\n", blr_enc, (blr_enc >> 21) & 3);
    printf("ret x0 => 0x%08X (opc=%d)\n", ret_enc, (ret_enc >> 21) & 3);

    // Verify opcodes
    assert(((br_enc >> 21) & 3) == 0, "BR opc should be 0");
    assert(((blr_enc >> 21) & 3) == 1, "BLR opc should be 1");
    assert(((ret_enc >> 21) & 3) == 2, "RET opc should be 2");

    // Verify all three are distinct
    assert(br_enc != blr_enc, "BR and BLR should differ");
    assert(br_enc != ret_enc, "BR and RET should differ");
    assert(blr_enc != ret_enc, "BLR and RET should differ");

    printf("✓ All three instructions have distinct opcodes\n");
    printf("\n");
}

void verifyBvsBL()
{
    printf("Testing B vs BL Difference:\n");
    printf("===========================\n");

    uint b_enc = INSTR.b_uncond(0);
    uint bl_enc = INSTR.bl(0);

    printf("b  #0  => 0x%08X (op=%d)\n", b_enc, (b_enc >> 31) & 1);
    printf("bl #0  => 0x%08X (op=%d)\n", bl_enc, (bl_enc >> 31) & 1);

    // B has op=0 (bit 31), BL has op=1
    assert((b_enc & (1 << 31)) == 0, "B should have op=0");
    assert((bl_enc & (1 << 31)) != 0, "BL should have op=1");

    // Rest of encoding should be identical
    assert((b_enc & 0x7FFFFFFF) == (bl_enc & 0x7FFFFFFF),
           "B and BL should only differ in bit 31");

    printf("✓ B and BL differ only in bit 31 (op field)\n");
    printf("\n");
}

void verifyRegisterEncodings()
{
    printf("Testing All Register Encodings:\n");
    printf("================================\n");

    // Test all registers for BLR
    printf("BLR register encoding validation...\n");
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.blr(r);
        uint decoded = (enc >> 5) & 0x1F;
        assert(decoded == r, "BLR register encoding failed");
    }
    printf("✓ BLR: All registers (x0-x30) encode correctly\n");

    // Test all registers for BR
    printf("BR register encoding validation...\n");
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.br(r);
        uint decoded = (enc >> 5) & 0x1F;
        assert(decoded == r, "BR register encoding failed");
    }
    printf("✓ BR: All registers (x0-x30) encode correctly\n");

    // Test all registers for RET
    printf("RET register encoding validation...\n");
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.ret(r);
        uint decoded = (enc >> 5) & 0x1F;
        assert(decoded == r, "RET register encoding failed");
    }
    printf("✓ RET: All registers (x0-x30) encode correctly\n");

    printf("\n");
}

void verifyBLOffsetRange()
{
    printf("Testing BL Offset Range:\n");
    printf("========================\n");

    // The imm26 field is a signed 26-bit offset in units of 4 bytes
    // Range: ±128MB (±0x2000000 instructions * 4 bytes)

    // Small offsets
    for (uint offset = 0; offset < 10; offset++)
    {
        uint enc = INSTR.bl(offset);
        uint decoded = enc & 0x3FFFFFF;
        assert(decoded == offset, "BL small offset encoding failed");
    }
    printf("✓ Small offsets (0-9) encode correctly\n");

    // Large positive offset
    uint enc = INSTR.bl(0x1FFFFFF);  // Maximum positive
    uint decoded = enc & 0x3FFFFFF;
    assert(decoded == 0x1FFFFFF, "BL max positive offset failed");
    printf("✓ Maximum positive offset (0x1FFFFFF) encodes correctly\n");

    // Large negative offset (represented as large unsigned in 26 bits)
    enc = INSTR.bl(0x3FFFFFF);  // -1 in 26-bit signed
    decoded = enc & 0x3FFFFFF;
    assert(decoded == 0x3FFFFFF, "BL -1 offset failed");
    printf("✓ Negative offset (-1 as 0x3FFFFFF) encodes correctly\n");

    printf("\n");
}

void verifyCommonPatterns()
{
    printf("Testing Common Usage Patterns:\n");
    printf("==============================\n");

    // Function call pattern
    printf("Function call pattern:\n");
    printf("  bl func => 0x%08X\n", INSTR.bl(0x10));

    // Indirect call pattern
    printf("Indirect call pattern:\n");
    printf("  blr x9 => 0x%08X\n", INSTR.blr(9));

    // Standard return
    printf("Standard return:\n");
    printf("  ret    => 0x%08X\n", INSTR.ret());

    // Tail call pattern
    printf("Tail call pattern:\n");
    printf("  br x0  => 0x%08X\n", INSTR.br(0));

    printf("\n");
}

unittest
{
    verifyBLEncoding();
    verifyBLREncoding();
    verifyBREncoding();
    verifyRETEncoding();
    verifyBranchRegOpcodes();
    verifyBvsBL();
    verifyRegisterEncodings();
    verifyBLOffsetRange();
    verifyCommonPatterns();
}
