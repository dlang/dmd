/**
 * AArch64 instruction encodings
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/arm/instr.d, backend/cod3.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_arm_insrt.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/arm/instr.d
 */

module dmd.backend.arm.instr;

import core.stdc.stdio;

nothrow:
@safe:

/************************
 * AArch64 instructions
 */
struct INSTR
{
  pure nothrow:

    enum uint ret = 0xd65f03c0;
    enum uint nop = 0xD503201F;

    /* Add/subtract (immediate)
     * ADD/ADDS/SUB/SUBS Rd,Rn,#imm{, shift}
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_imm
     */
    static uint addsub_imm(uint sf, uint op, uint S, uint sh, uint imm12, ubyte Rn, ubyte Rd)
    {
        return (sf     << 31) |
               (op     << 30) |
               (S      << 29) |
               (0x22   << 23) |
               (sh     << 22) |
               (imm12  << 10) |
               (Rn     <<  5) |
                Rd;
    }

    /* Add/subtract (immdiate, with tags)
     */

    /* Min/max (immdiate)
     */

    /* Logical (immediate)
     * AND/ORR/EOR/ANDS Rd,Rn,#imm
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#log_imm
     */
    static uint log_imm(uint sf, uint opc, uint N, uint immr, uint imms, ubyte Rn, ubyte Rd)
    {
        return (sf   << 31) |
               (opc  << 29) |
               (0x24 << 23) |
               (N    << 22) |
               (immr << 16) |
               (imms << 10) |
               (Rn   <<  5) |
                Rd;
    }

    /* Move wide (immediate)
     * MOVN/MOVZ/MOVK Rd, #imm{, LSL #shift}
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#movewide
     */
     static uint movewide(uint sf, uint opc, uint hw, uint imm16, uint Rd)
     {
        return (sf    << 31) |
               (opc   << 29) |
               (0x25  << 23) |
               (hw    << 21) |
               (imm16 <<  5) |
                Rd;
     }

    /* Data-processing (1 source)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_1src
     */
    static uint dp_1src(uint sf, uint S, uint opcode2, uint opcode, ubyte Rn, ubyte Rd)
    {
        return (sf      << 31) |
               (1       << 30) |
               (S       << 29) |
               (0xD6    << 21) |
               (opcode2 << 16) |
               (opcode  << 10) |
               (Rn      <<  5) |
                Rd;
    }

    /* Data-processing (2 source)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_2src
     */
    static uint dp_2src(uint sf, uint S, uint Rm, uint opcode, ubyte Rn, ubyte Rd)
    {
        return (sf     << 31) |
               (0      << 30) |
               (S      << 29) |
               (0xD6   << 21) |
               (Rm     << 16) |
               (opcode << 10) |
               (Rn     <<  5) |
                Rd;
    }

    /* Logical (shifted register)
     * AND/BIC/ORR/ORN/EOR/ANDS/BICS Rd, Rn, Rm, {shift #amount}
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#log_shift
     */
    static uint log_shift_reg(uint sf, uint opc, uint shift, uint N, ubyte Rm, uint imm6, ubyte Rn, ubyte Rd)
    {
        return (sf    << 31) |
               (opc   << 29) |
               (0xA   << 24) |
               (shift << 22) |
               (N     << 21) |
               (Rm    << 16) |
               (imm6  << 10) |
               (Rn    <<  5) |
                Rd;
    }

    /* Add/Subtract (shifted register)
     * ADD/ADDS/SUB/SUBS
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_shift
     */
    static uint addsub_shift(uint sf, uint op, uint S, uint shift, ubyte Rm, uint imm6, ubyte Rn, ubyte Rd)
    {
        return (sf    << 31) |
               (op    << 30) |
               (S     << 29) |
               (0xA   << 24) |
               (shift << 22) |
               (0     << 21) |
               (Rm    << 16) |
               (imm6  << 10) |
               (Rn    <<  5) |
                Rd;
    }

    /* Add/subtract (extended register)
     * ADD/ADDS/SUB/SUBS Rd, Rn, Rm, {shift #amount}
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_ext
     */
    static uint addsub_ext(uint sf, uint op, uint S, uint opt, ubyte Rm, uint option, uint imm3, ubyte Rn, ubyte Rd)
    {
        return (sf   << 31) |
               (op   << 30) |
               (S    << 29) |
               (0xB  << 24) |
               (opt  << 22) |
               (1    << 21) |
               (Rm   << 16) |
               (option << 13) |
               (imm3 << 10) |
               (Rn   <<  5) |
                Rd;
    }

    /* Add/subtract (with carry)
     * ADC/ADCS/SBC/SBCS Rd, Rn, Rm
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_carry
     */
    static uint addsub_carry(uint sf, uint op, uint S, ubyte Rm, ubyte Rn, ubyte Rd)
    {
        return (sf   << 31) |
               (op   << 30) |
               (S    << 29) |
               (0xD0 << 24) |
               (Rm   << 16) |
               (Rn   <<  5) |
                Rd;
    }

    /* Add/subtract (checked pointer)
     */

    /* Rotate right into flags
     */

    /* Evaluate into flags
     */

    /* Conditional compare (register)
     */

    /* Conditional compare (immediate)
     */

    /* Conditional select
     */

    /* Data-processing (3 source)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_3src
     */
    static uint dp_3src(uint sf, uint op54, uint op31, uint Rm, uint o0, ubyte Ra, ubyte Rn, ubyte Rd)
    {
        uint ins = (sf   << 31) |
                   (op54 << 29) |
                   (0x1B << 24) |
                   (op31 << 21) |
                   (Rm   << 16) |
                   (o0   << 15) |
                   (Ra   << 10) |
                   (Rn   <<  5) |
                    Rd;
        return ins;
    }

    /* Load/store register (immediate post-indexed)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_immpost
     */
    static uint ldst_immpost(uint size, uint VR, uint opc, uint imm9, ubyte Rn, ubyte Rt)
    {
        return (size << 30) |
               (7    << 27) |
               (VR   << 26) |
               (opc  << 22) |
               (imm9 << 12) |
               (Rn   <<  5) |
                Rt;
    }

    /* Load/store register (unsigned immediate)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_post
     */
    static uint ldst_post(uint size, uint VR, uint opc, uint imm12, ubyte Rn, ubyte Rt)
    {
        return (size  << 30) |
               (7     << 27) |
               (VR    << 26) |
               (1     << 24) |
               (opc   << 22) |
               (imm12 << 10) |
               (Rn    <<  5) |
                Rt;
    }

    /* =============================================================================== */
    /* =============================================================================== */

    /* MADD
     * https://www.scs.stanford.edu/~zyedidia/arm64/madd.html
     */
    static uint madd(uint sf, ubyte Rm, ubyte Ra, ubyte Rn, ubyte Rd)
    {
        uint op54   = 0;
        uint op31   = 0;
        uint o0     = 0;
        return dp_3src(sf, op54, op31, Rm, o0, Ra, Rn, Rd);
    }

    /* MSUB Rd, Rn, Rm, Ra
     * https://www.scs.stanford.edu/~zyedidia/arm64/msub.html
     */
    static uint msub(uint sf, ubyte Rm, ubyte Ra, ubyte Rn, ubyte Rd)
    {
        uint op54   = 0;
        uint op31   = 0;
        uint o0     = 1;
        return dp_3src(sf, op54, op31, Rm, o0, Ra, Rn, Rd);
    }

    /* SDIV/UDIV Rd, Rn, Rm
     * http://www.scs.stanford.edu/~zyedidia/arm64/sdiv.html
     * http://www.scs.stanford.edu/~zyedidia/arm64/udiv.html
     */
    static uint sdiv_udiv(uint sf, bool uns, ubyte Rm, ubyte Rn, ubyte Rd)
    {
        uint S = 0;
        uint opcode = 2 + (uns ^ 1);
        return dp_2src(sf, S, Rm, opcode, Rn, Rd);
    }

    /* SUBS Rd, Rn, #imm{, shift }
     * https://www.scs.stanford.edu/~zyedidia/arm64/subs_addsub_imm.html
     */
    static uint subs_imm(uint sf, ubyte sh, uint imm12, ubyte Rn, ubyte Rd)
    {
        return addsub_imm(sf, 1, 1, sh, imm12, Rn, Rd);
    }

    /* CMP Rn, #imm{, shift}
     * http://www.scs.stanford.edu/~zyedidia/arm64/cmp_subs_addsub_imm.html
     */
    static uint cmp_imm(uint sf, ubyte sh, uint imm12, ubyte Rn)
    {
        return subs_imm(sf, sh, imm12, Rn, 31);
    }

    /* ORR Rd, Rn, Rm{, shift #amount}
     * https://www.scs.stanford.edu/~zyedidia/arm64/orr_log_shift.html
     */
    static uint orr_shifted_register(uint sf, uint shift, ubyte Rm, uint imm6, ubyte Rn, ubyte Rd)
    {
        uint opc = 1;
        uint N = 0;
        return log_shift_reg(sf, opc, shift, N, Rm, imm6, Rn, Rd);
    }

    /* MOV Rd, Rn, Rm{, shift #amount}
     * https://www.scs.stanford.edu/~zyedidia/arm64/mov_orr_log_shift.html
     */
    static uint mov_register(uint sf, ubyte Rm, ubyte Rd)
    {
        return orr_shifted_register(sf, 0, Rm, 0, 31, Rd);
    }

    /* STR (immediate) Unsigned offset
     * https://www.scs.stanford.edu/~zyedidia/arm64/str_imm_gen.html
     */
    static uint str_imm_gen(uint is64, ubyte Rt, ubyte Rn, ulong offset)
    {
        // str Rt,Rn,#offset
        uint size = 2 + is64;
        uint imm12 = cast(uint)offset >> (is64 ? 3 : 2);
        return ldst_post(size, 0, 0, imm12, Rn, Rt);
    }

}
