module inline_asm.verify_missing_features;

// Verification tests for missing features implementation
// Tests ADD/SUB optional shifts, ADDS, SUBS, ADCS, SBCS, and CMN

import dmd.backend.arm.instr : INSTR;
import core.stdc.stdio;

unittest
{
    verifyAddShifts();
    verifySubShifts();
    verifyAdds();
    verifySubs();
    verifyAdcs();
    verifySbcs();
    verifyCmn();
}

void verifyAddShifts()
{
    // ADD x0, x1, x2, lsl #3
    // sf=1, op=0, S=0, shift=0 (LSL), Rm=2, imm6=3, Rn=1, Rd=0
    uint encoding1 = INSTR.addsub_shift(1, 0, 0, 0, 2, 3, 1, 0);
    assert((encoding1 & 0x1F) == 0, "Rd should be 0");
    assert(((encoding1 >> 5) & 0x1F) == 1, "Rn should be 1");
    assert(((encoding1 >> 10) & 0x3F) == 3, "imm6 should be 3");
    assert(((encoding1 >> 16) & 0x1F) == 2, "Rm should be 2");
    assert(((encoding1 >> 22) & 0x3) == 0, "shift should be 0 (LSL)");
    assert((encoding1 >> 31) == 1, "sf should be 1 (64-bit)");

    // ADD w3, w4, w5, lsr #5
    // sf=0, op=0, S=0, shift=1 (LSR), Rm=5, imm6=5, Rn=4, Rd=3
    uint encoding2 = INSTR.addsub_shift(0, 0, 0, 1, 5, 5, 4, 3);
    assert((encoding2 & 0x1F) == 3, "Rd should be 3");
    assert(((encoding2 >> 5) & 0x1F) == 4, "Rn should be 4");
    assert(((encoding2 >> 10) & 0x3F) == 5, "imm6 should be 5");
    assert(((encoding2 >> 16) & 0x1F) == 5, "Rm should be 5");
    assert(((encoding2 >> 22) & 0x3) == 1, "shift should be 1 (LSR)");
    assert((encoding2 >> 31) == 0, "sf should be 0 (32-bit)");

    printf("ADD with optional shifts: OK\n");
}

void verifySubShifts()
{
    // SUB x6, x7, x8, asr #10
    // sf=1, op=1, S=0, shift=2 (ASR), Rm=8, imm6=10, Rn=7, Rd=6
    uint encoding1 = INSTR.addsub_shift(1, 1, 0, 2, 8, 10, 7, 6);
    assert((encoding1 & 0x1F) == 6, "Rd should be 6");
    assert(((encoding1 >> 5) & 0x1F) == 7, "Rn should be 7");
    assert(((encoding1 >> 10) & 0x3F) == 10, "imm6 should be 10");
    assert(((encoding1 >> 16) & 0x1F) == 8, "Rm should be 8");
    assert(((encoding1 >> 22) & 0x3) == 2, "shift should be 2 (ASR)");
    assert(((encoding1 >> 30) & 1) == 1, "op should be 1 (SUB)");

    printf("SUB with optional shifts: OK\n");
}

void verifyAdds()
{
    // ADDS x0, x1, x2 (register form, no shift)
    // sf=1, op=0, S=1, shift=0, Rm=2, imm6=0, Rn=1, Rd=0
    uint encoding1 = INSTR.addsub_shift(1, 0, 1, 0, 2, 0, 1, 0);
    assert(((encoding1 >> 29) & 1) == 1, "S should be 1 for ADDS");
    assert(((encoding1 >> 30) & 1) == 0, "op should be 0 for ADD");

    // ADDS x3, x4, #100 (immediate form)
    // sf=1, op=0, S=1, sh=0, imm12=100, Rn=4, Rd=3
    uint encoding2 = INSTR.addsub_imm(1, 0, 1, 0, 100, 4, 3);
    assert(((encoding2 >> 29) & 1) == 1, "S should be 1 for ADDS");
    assert(((encoding2 >> 30) & 1) == 0, "op should be 0 for ADD");
    assert((encoding2 & 0x1F) == 3, "Rd should be 3");
    assert(((encoding2 >> 5) & 0x1F) == 4, "Rn should be 4");
    assert(((encoding2 >> 10) & 0xFFF) == 100, "imm12 should be 100");

    // ADDS x5, x6, x7, lsl #2 (with shift)
    uint encoding3 = INSTR.addsub_shift(1, 0, 1, 0, 7, 2, 6, 5);
    assert(((encoding3 >> 29) & 1) == 1, "S should be 1 for ADDS");
    assert(((encoding3 >> 10) & 0x3F) == 2, "shift amount should be 2");

    printf("ADDS (flag-setting ADD): OK\n");
}

void verifySubs()
{
    // SUBS x0, x1, x2 (register form, no shift)
    // sf=1, op=1, S=1, shift=0, Rm=2, imm6=0, Rn=1, Rd=0
    uint encoding1 = INSTR.addsub_shift(1, 1, 1, 0, 2, 0, 1, 0);
    assert(((encoding1 >> 29) & 1) == 1, "S should be 1 for SUBS");
    assert(((encoding1 >> 30) & 1) == 1, "op should be 1 for SUB");

    // SUBS w3, w4, #50 (immediate form)
    // sf=0, op=1, S=1, sh=0, imm12=50, Rn=4, Rd=3
    uint encoding2 = INSTR.addsub_imm(0, 1, 1, 0, 50, 4, 3);
    assert(((encoding2 >> 29) & 1) == 1, "S should be 1 for SUBS");
    assert(((encoding2 >> 30) & 1) == 1, "op should be 1 for SUB");
    assert((encoding2 >> 31) == 0, "sf should be 0 for 32-bit");

    // SUBS x5, x6, x7, asr #3 (with shift)
    uint encoding3 = INSTR.addsub_shift(1, 1, 1, 2, 7, 3, 6, 5);
    assert(((encoding3 >> 29) & 1) == 1, "S should be 1 for SUBS");
    assert(((encoding3 >> 22) & 0x3) == 2, "shift type should be 2 (ASR)");

    printf("SUBS (flag-setting SUB): OK\n");
}

void verifyAdcs()
{
    // ADCS x0, x1, x2
    // sf=1, op=0, S=1, Rm=2, Rn=1, Rd=0
    uint encoding1 = INSTR.adcs(1, 2, 1, 0);

    // Extract fields
    uint rd = encoding1 & 0x1F;
    uint rn = (encoding1 >> 5) & 0x1F;
    uint rm = (encoding1 >> 16) & 0x1F;
    uint S = (encoding1 >> 29) & 1;
    uint op = (encoding1 >> 30) & 1;
    uint sf = encoding1 >> 31;

    assert(rd == 0, "Rd should be 0");
    assert(rn == 1, "Rn should be 1");
    assert(rm == 2, "Rm should be 2");
    assert(S == 1, "S should be 1 for ADCS");
    assert(op == 0, "op should be 0 for ADC");
    assert(sf == 1, "sf should be 1 for 64-bit");

    // Test 32-bit version
    uint encoding2 = INSTR.adcs(0, 5, 6, 7);
    assert((encoding2 >> 31) == 0, "sf should be 0 for 32-bit");
    assert(((encoding2 >> 29) & 1) == 1, "S should be 1");

    printf("ADCS (flag-setting ADC): OK\n");
}

void verifySbcs()
{
    // SBCS x3, x4, x5
    // sf=1, op=1, S=1, Rm=5, Rn=4, Rd=3
    uint encoding1 = INSTR.sbcs(1, 5, 4, 3);

    // Extract fields
    uint rd = encoding1 & 0x1F;
    uint rn = (encoding1 >> 5) & 0x1F;
    uint rm = (encoding1 >> 16) & 0x1F;
    uint S = (encoding1 >> 29) & 1;
    uint op = (encoding1 >> 30) & 1;
    uint sf = encoding1 >> 31;

    assert(rd == 3, "Rd should be 3");
    assert(rn == 4, "Rn should be 4");
    assert(rm == 5, "Rm should be 5");
    assert(S == 1, "S should be 1 for SBCS");
    assert(op == 1, "op should be 1 for SBC");
    assert(sf == 1, "sf should be 1 for 64-bit");

    // Test 32-bit version
    uint encoding2 = INSTR.sbcs(0, 10, 11, 12);
    assert((encoding2 >> 31) == 0, "sf should be 0 for 32-bit");
    assert(((encoding2 >> 29) & 1) == 1, "S should be 1");

    printf("SBCS (flag-setting SBC): OK\n");
}

void verifyCmn()
{
    // CMN x1, x2 (register form, no shift)
    // This is ADDS XZR, x1, x2
    // sf=1, op=0, S=1, shift=0, Rm=2, imm6=0, Rn=1, Rd=31 (XZR)
    uint encoding1 = INSTR.addsub_shift(1, 0, 1, 0, 2, 0, 1, 31);
    assert((encoding1 & 0x1F) == 31, "Rd should be 31 (XZR) for CMN");
    assert(((encoding1 >> 5) & 0x1F) == 1, "Rn should be 1");
    assert(((encoding1 >> 16) & 0x1F) == 2, "Rm should be 2");
    assert(((encoding1 >> 29) & 1) == 1, "S should be 1 (sets flags)");
    assert(((encoding1 >> 30) & 1) == 0, "op should be 0 (ADD)");

    // CMN x3, #42 (immediate form)
    // This is ADDS XZR, x3, #42
    // sf=1, op=0, S=1, sh=0, imm12=42, Rn=3, Rd=31
    uint encoding2 = INSTR.addsub_imm(1, 0, 1, 0, 42, 3, 31);
    assert((encoding2 & 0x1F) == 31, "Rd should be 31 (XZR) for CMN");
    assert(((encoding2 >> 5) & 0x1F) == 3, "Rn should be 3");
    assert(((encoding2 >> 10) & 0xFFF) == 42, "imm12 should be 42");
    assert(((encoding2 >> 29) & 1) == 1, "S should be 1");

    // CMN x4, x5, lsl #1 (with shift)
    uint encoding3 = INSTR.addsub_shift(1, 0, 1, 0, 5, 1, 4, 31);
    assert((encoding3 & 0x1F) == 31, "Rd should be 31 (XZR)");
    assert(((encoding3 >> 10) & 0x3F) == 1, "shift amount should be 1");

    // CMN w6, w7 (32-bit version)
    uint encoding4 = INSTR.addsub_shift(0, 0, 1, 0, 7, 0, 6, 31);
    assert((encoding4 >> 31) == 0, "sf should be 0 for 32-bit");
    assert((encoding4 & 0x1F) == 31, "Rd should be 31 (WZR)");

    printf("CMN (compare negative): OK\n");
}

