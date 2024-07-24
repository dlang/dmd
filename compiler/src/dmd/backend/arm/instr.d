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

    enum uint nop = 0xD503201F;


    /************************************ Reserved ***********************************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#reserved                  */

    enum int udf = 0; // https://www.scs.stanford.edu/~zyedidia/arm64/udf_perm_undef.html


    /************************************ SME encodings *******************************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#sme                        */


    /************************************ SVE encodings *******************************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#sve                        */


    /************************************ Data Processing -- Immediate ****************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dpimm                      */

    /* Add offset to PC
     * ADR/ADRP Xd,label
     * https://www.scs.stanford.edu/~zyedidia/arm64/adr.html
     * https://www.scs.stanford.edu/~zyedidia/arm64/adrp.html
     */
    static uint adr(uint op, uint imm, ubyte Rd)
    {
        uint immlo = imm & 3;
        uint immhi = imm >> 2;
        return (op    << 31) |
               (immlo << 29) |
               (0x10  << 24) |
               (immhi <<  5) |
                Rd;
    }

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


    /****************************** Branches, Exception Generating and System instructions **************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#control                          */

    /* Unconditional branch (register)
     * BLR
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#branch_reg
     */
    static uint branch_reg(uint opc, uint op2, uint op3, ubyte Rn, uint op4)
    {
        return (0x6B << 25) | (opc << 21) | (op2 << 16) | (op3 << 10) | (Rn << 5) | op4;
    }

    /* Unconditional branch (immediate)
     * B/BL
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#branch_imm
     */
    static uint branch_imm(uint op, uint imm26)
    {
        return (op << 31) | (5 << 26) | imm26;
    }

    /* Compare and branch (immediate)
     * CBZ/CBNZ
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#compbranch
     */
    static uint compbranch(uint sf, uint op, uint imm19, ubyte Rt)
    {
        return (sf << 31) | (0x1A << 25) | (op << 24) | (imm19 << 5) | Rt;
    }

    /* Test and branch (immediate)
     * TBZ/TBNZ
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#testbranch
     */
    static uint testbranch(uint b5, uint op, uint b40, uint imm14, ubyte Rt)
    {
        return (b5 << 31) | (0x1B << 25) | (op << 24) | (b40 << 19) | (imm14 << 5) | Rt;
    }


    /****************************** Data Processing -- Register **********************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dpreg                     */

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
     * ADDPT/SUBPT
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_pt
     */
    static uint addsub_pt(uint sf, uint op, uint S, ubyte Rm, uint imm3, ubyte Rn, ubyte Rd)
    {
        return (sf << 31) | (op << 30) | (S << 29) | (0xD0 << 21) | (Rm << 16) | (1 << 13) | (imm3 << 10) | (Rn << 5) | Rd;
    }

    /* Rotate right into flags
     * RMIF
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#rmif
     */
    static uint rmif(uint sf, uint op, uint S, uint imm6, ubyte Rn, uint o2, uint mask)
    {
        return (sf << 31) | (op << 30) | (S << 29) | (0xC0 << 21) | (imm6 << 15) | (1 << 10) | (Rn << 5) | (o2 << 4) | mask;
    }

    /* Evaluate into flags
     * SETF8/SETF16
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#setf
     */
    static uint setf(uint sf, uint op, uint S, uint opcode2, uint sz, ubyte Rn, uint o3, uint mask)
    {
        return (sf << 31) | (op << 30) | (S << 29) | (0xD0 << 21) | (opcode2 << 15) | (sz << 14) | (2 << 10) | (Rn << 5) | (o3 << 4) | mask;
    }

    /* Conditional compare (register)
     * CCMN/CCMP
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#condcmp_reg
     */
    static uint condcmp_reg(uint sf, uint op, uint S, ubyte Rm, uint cond, uint o2, ubyte Rn, uint o3, uint nzcv)
    {
        return (sf << 31) | (op << 30) | (S << 29) | (0xD2 << 21) | (Rm << 16) | (cond << 12) | (o2 << 10) | (Rn << 5) | (o3 << 4) | nzcv;
    }

    /* Conditional compare (immediate)
     * CCMN/CCMP
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#condcmp_imm
     */
    static uint condcmp_imm(uint sf, uint op, uint S, uint imm5, uint cond, uint o2, ubyte Rn, uint o3, uint nzcv)
    {
        return (sf << 31) | (op << 30) | (S << 29) | (0xD2 << 21) | (imm5 << 16) | (cond << 12) | (1 << 11) | (o2 << 10) | (Rn << 5) | (o3 << 4) | nzcv;
    }

    /* Conditional select
     * CSEL/CSINC/CSINV/CSNEG
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#condsel
     */
    static uint condsel(uint sf, uint op, uint S, ubyte Rm, uint cond, uint o2, ubyte Rn, ubyte Rd)
    {
        return (sf << 31) | (op << 30) | (S << 29) | (0xD4 << 21) | (Rm << 16) | (cond << 12) | (o2 << 10) | (Rn << 5) | Rd;
    }

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


    /****************************** Data Processing -- Scalar Floating-Point and Advanced SIMD **/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#simd_dp                  */



    /****************************** Loads and Stores ********************************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst                     */

    /* Compare and swap pair
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#comswappr
     */
    static uint comswappr(uint sz, uint L, ubyte Rs, uint o0, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        return (sz << 30) | (0x10 << 23) | (L << 22) | (1 << 21) | (Rs << 16) | (o0 << 15) | (Rt2 << 10) | (Rn << 5) | Rt;
    }

    /* Advanced SIMD load/store multiple structures
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#asisdlse
     */
    static uint asisdlse(uint Q, uint L, uint opcode, uint size, ubyte Rn, ubyte Rt)
    {
        return (Q << 30) | (0x18 << 23) | (L << 22) | (opcode << 12) | (size << 10) | (Rn << 5) | Rt;
    }

    /* Load/store register pair
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldstpair_post
     */
    static uint ldstpair(uint opc, uint VR, uint opc2, uint L, uint imm7, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        assert(imm7 < 0x80);
        return (opc  << 30) |
               (5    << 27) |
               (VR   << 26) |
               (opc2 << 23) |
               (L    << 22) |
               (imm7 << 15) |
               (Rt2  << 10) |
               (Rn   <<  5) |
                Rt;
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
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldst_pos
     */
    static uint ldst_pos(uint size, uint VR, uint opc, uint imm12, ubyte Rn, ubyte Rt)
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

    /********* Branches, Exception Generating and System Instructions **********/

    /* BR Xn
     * https://www.scs.stanford.edu/~zyedidia/arm64/br.html
     */
    static uint br(ubyte Rn)
    {
        return branch_reg(0, 0x1F, 0, Rn, 0);
    }

    /* BLR Xn
     * https://www.scs.stanford.edu/~zyedidia/arm64/blr.html
     */
    static uint blr(ubyte Rn)
    {
        return branch_reg(1, 0x1F, 0, Rn, 0);
    }

    /* RET Xn
     * https://www.scs.stanford.edu/~zyedidia/arm64/ret.html
     */
    static ret(ubyte Rn = 30)
    {
        return branch_reg(2, 0x1F, 0, Rn, 0);
    }

    static assert(ret() == 0xd65f03c0);


    /****************************** Data Processing -- Register **********************************/
    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dpreg                     */


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

    /* Loads and Stores */

    /* Load/store no-allocate pair (offset)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldstnapair_offs
     */
    static uint ldstnapair_offs(uint opc, uint VR, uint L, uint imm7, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        return ldstpair(opc, VR, 0, L, imm7, Rt2, Rn, Rt);
    }

    /* Load/store register pair (post-indexed)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldstpair_post
     */
    static uint ldstpair_post(uint opc, uint VR, uint L, uint imm7, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        return ldstpair(opc, VR, 1, L, imm7, Rt2, Rn, Rt);
    }

    /* Load/store register pair (offset)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldstpair_off
     */
    static uint ldstpair_off(uint opc, uint VR, uint L, uint imm7, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        return ldstpair(opc, VR, 2, L, imm7, Rt2, Rn, Rt);
    }

    /* Load/store register pair (pre-indexed)
     * https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#ldstpair_pre
     */
    static uint ldstpair_pre(uint opc, uint VR, uint L, uint imm7, ubyte Rt2, ubyte Rn, ubyte Rt)
    {
        return ldstpair(opc, VR, 3, L, imm7, Rt2, Rn, Rt);
    }

    /* STR (immediate) Unsigned offset
     * https://www.scs.stanford.edu/~zyedidia/arm64/str_imm_gen.html
     */
    static uint str_imm_gen(uint is64, ubyte Rt, ubyte Rn, ulong offset)
    {
        // str Rt,[Rn,#offset]
        uint size = 2 + is64;
        uint imm12 = (cast(uint)offset >> (is64 ? 3 : 2)) & 0xFFF;
        return ldst_pos(size, 0, 0, imm12, Rn, Rt);
    }

    /* LDR (immediate) Unsigned offset
     * https://www.scs.stanford.edu/~zyedidia/arm64/ldr_imm_gen.html
     */
    static uint ldr_imm_gen(uint is64, ubyte Rt, ubyte Rn, ulong offset)
    {
        // ldr Rt,[Rn,#offset]
        uint size = 2 + is64;
        uint imm12 = (cast(uint)offset >> (is64 ? 3 : 2)) & 0xFFF;
        return ldst_pos(size, 0, 1, imm12, Rn, Rt);
    }
}
