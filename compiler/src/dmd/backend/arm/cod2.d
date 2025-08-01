/**
 * Code generation 2
 *
 * Includes:
 * - math operators (+ - * / %) and functions (abs, cos, sqrt)
 * - 'string' functions (strlen, memcpy, memset)
 * - pointers (address of / dereference)
 * - struct assign, constructor, destructor
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/arm/cod2.d, backend/cod2.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_arm_cod2.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/arm/cod2.d
 */

module dmd.backend.arm.cod2;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.codebuilder;
import dmd.backend.mem;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.oper;
import dmd.backend.ty;
import dmd.backend.type;
import dmd.backend.x86.xmm;
import dmd.backend.arm.cod1 : loadFromEA, storeToEA, getlvalue, CLIB_A, callclib;
import dmd.backend.arm.cod3 : conditionCode, genBranch, genCompBranch, gentstreg, movregconst, COND, loadFloatRegConst;
import dmd.backend.arm.instr;

nothrow:
@safe:

import dmd.backend.cg : segfl, stackfl;

__gshared int cdcmp_flag;

import dmd.backend.divcoeff : choose_multiplier, udiv_coefficients;

/*****************************
 * Handle operators which are more or less orthogonal
 * OPadd, OPmin, OPand, OPor, OPxor
 */

@trusted
void cdorth(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdorth(e = %p, pretregs = %s)\n",e,regm_str(pretregs));
    //elem_print(e);

    elem* e1 = e.E1;
    elem* e2 = e.E2;
    if (pretregs == 0)                   // if don't want result
    {
        codelem(cg,cdb,e1,pretregs,false); // eval left leaf
        pretregs = 0;                          // in case they got set
        codelem(cg,cdb,e2,pretregs,false);
        return;
    }

    const ty = tybasic(e.Ety);
    const ty1 = tybasic(e1.Ety);
    const ty2 = tybasic(e2.Ety);
    const sz = _tysize[ty];

    regm_t posregs = tyfloating(ty1) ? INSTR.FLOATREGS : cg.allregs;

    regm_t retregs1 = posregs;
    codelem(cg, cdb, e1, retregs1, false);
    reg_t Rn = findreg(retregs1);

    regm_t retregs2 = posregs & ~retregs1;
//printf("retregs1: %s retregs2: %s\n", regm_str(retregs1), regm_str(retregs2));
    scodelem(cg, cdb, e2, retregs2, retregs1, false);
    reg_t Rm = findreg(retregs2);

    regm_t retregs = pretregs & posregs;
    if (retregs == 0)                   /* if no return regs speced     */
        retregs = posregs;              // give us some
    reg_t Rd = allocreg(cdb, retregs, ty);

    regm_t PSW = pretregs & mPSW;

    if (tyfloating(ty1))
    {
        if (sz == 16)                   // 128 bit float
        {
            uint clib;
            switch (e.Eoper)
            {
                case OPadd: clib = CLIB_A.add; break;
                case OPmin: clib = CLIB_A.min; break;
                case OPmul: clib = CLIB_A.mul; break;
                case OPdiv: clib = CLIB_A.div; break;

                default:
                    assert(0);
            }
            callclib(cdb,e,clib,pretregs,0);
        }
        else
        {
            const ftype = INSTR.szToFtype(sz);
            switch (e.Eoper)
            {
                // FADD/FSUB (extended register)
                // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_ext
                case OPadd:
                    cdb.gen1(INSTR.fadd_float(ftype,Rm,Rn,Rd));     // FADD Rd,Rn,Rm
                    break;

                case OPmin:
                    cdb.gen1(INSTR.fsub_float(ftype,Rm,Rn,Rd));     // FSUB Rd,Rn,Rm
                    break;

                case OPmul:
                    cdb.gen1(INSTR.fmul_float(ftype,Rm,Rn,Rd));     // FMUL Rd,Rn,Rm
                    break;

                case OPdiv:
                    cdb.gen1(INSTR.fdiv_float(ftype,Rm,Rn,Rd));     // FDIV Rd,Rn,Rm
                    break;

                default:
                    assert(0);
            }
        }
        pretregs = retregs | PSW;
        fixresult(cdb,e,mask(Rd),pretregs);
        return;
    }

    switch (e.Eoper)
    {
        // ADDS/SUBS (extended register)
        // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_ext
        case OPadd:
        case OPmin:
        {
            uint sf = sz == 8;
            uint op = e.Eoper == OPadd ? 0 : 1;
            uint S = PSW != 0;
            uint opt = 0;
            uint option = tyToExtend(ty);
            uint imm3 = 0;
            cdb.gen1(INSTR.addsub_ext(sf, op, S, opt, Rm, option, imm3, Rn, Rd));
            PSW = 0;
            pretregs &= ~mPSW;
            break;
        }

        // Logical (shifted register)
        // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#log_shift
        case OPand:
        case OPor:
        case OPxor:
        {
            uint sf = sz == 8;
            uint opc = e.Eoper == OPand ? 0 :
                       e.Eoper == OPor  ? 1 : 2;
            if (PSW && e.Eoper == OPand)
            {
                opc = 3;        // ANDS
                pretregs &= ~mPSW;
            }
            uint shift = 0;
            uint N = 0;
            uint imm6 = 0;
            cdb.gen1(INSTR.log_shift(sf, opc, shift, N, Rm, imm6, Rn, Rd));
            break;
        }

        default:
            assert(0);
    }

    pretregs = retregs | PSW;
    fixresult(cdb,e,mask(Rd),pretregs);
}

/*************************************************
 * Convert from ty to <extend> type according to table:
 * Params:
 *      ty = basic ty
 * Output:
 *      <extend>
 */
Extend tyToExtend(tym_t ty)
{
    //debug printf("ty: %s\n", tym_str(ty));
    ty = tybasic(ty);
    assert(tyintegral(ty) || ty == TYnptr);
    Extend extend;
    const sz = tysize(ty);
    with (Extend) switch (sz)
    {
        case 1: extend = UXTB; break;
        case 2: extend = UXTH; break;
        case 4: extend = UXTW; break;
        case 16:               // in case TYucent for OPpair/OPrpair
        case 8: extend = LSL;  break;
        default:
            assert(0);
    }
    if (!tyuns(ty))
        extend = cast(Extend)(extend | 4);
    return extend;
}

/*****************************
 * Handle multiply, OPmul
 */

@trusted
void cdmul(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdmul(e = %p, pretregs = %s)\n",e,regm_str(pretregs));

    elem* e1 = e.E1;
    elem* e2 = e.E2;
    if (pretregs == 0)                   // if don't want result
    {
        codelem(cg,cdb,e1,pretregs,false); // eval left leaf
        pretregs = 0;                          // in case they got set
        codelem(cg,cdb,e2,pretregs,false);
        return;
    }

    const ty = tybasic(e.Ety);
    const ty1 = tybasic(e1.Ety);
    const ty2 = tybasic(e2.Ety);
    const sz = _tysize[ty];

    if (tyfloating(ty1))
    {
        cdorth(cg, cdb, e, pretregs);
        return;
    }

    regm_t posregs = cg.allregs;

    regm_t retregs1 = posregs;

    codelem(cg, cdb, e1, retregs1, false);
    regm_t retregs2 = cg.allregs & ~retregs1;
    scodelem(cg, cdb, e2, retregs2, retregs1, false);

    regm_t retregs = pretregs & cg.allregs;
    if (retregs == 0)                   /* if no return regs speced     */
                                        /* (like if wanted flags only)  */
        retregs = ALLREGS & posregs;    // give us some
    reg_t Rd = allocreg(cdb, retregs, ty);

    reg_t Rn = findreg(retregs1);
    reg_t Rm = findreg(retregs2);

    // http://www.scs.stanford.edu/~zyedidia/arm64/mul_madd.html
    // madd Rd,Rn,Rm,Rzr
    cdb.gen1(INSTR.madd(sz == 8, Rm, 31, Rn, Rd));

    fixresult(cdb,e,retregs,pretregs);
}

/*****************************
 * Handle OPdiv, OPmod and OPremquo.
 * Note that modulo isn't defined for doubles.
 */

@trusted
void cddiv(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cddiv(e = %p, pretregs = %s)\n",e,regm_str(pretregs));

    elem* e1 = e.E1;
    elem* e2 = e.E2;
    if (pretregs == 0)                   // if don't want result
    {
        codelem(cg,cdb,e1,pretregs,false); // eval left leaf
        pretregs = 0;                          // in case they got set
        codelem(cg,cdb,e2,pretregs,false);
        return;
    }

    const ty = tybasic(e.Ety);
    const ty1 = tybasic(e1.Ety);
    const ty2 = tybasic(e2.Ety);
    const sz = _tysize[ty];
    const uns = tyuns(ty1) || tyuns(ty2);  // 1 if unsigned operation, 0 if not

    if (tyfloating(ty1))
    {
        cdorth(cg, cdb, e, pretregs);
        return;
    }

    regm_t posregs = cg.allregs;

    regm_t retregs1 = posregs;

    codelem(cg, cdb, e1, retregs1, false);
    regm_t retregs2 = cg.allregs & ~retregs1;
    scodelem(cg, cdb, e2, retregs2, retregs1, false);

    regm_t retregs = pretregs & cg.allregs;
    if (retregs == 0)                   // if no return regs speced (i.e. flags only)
        retregs = ALLREGS & posregs;    // give us some

    reg_t Rdividend = findreg(retregs1);  // dividend
    reg_t Rdivisor  = findreg(retregs2);  // divisor

    reg_t Rquo;
    reg_t Rmod;
    final switch (e.Eoper)
    {
        case OPdiv:
            Rquo = allocreg(cdb, retregs, ty);
            break;
        case OPmod:
        {
            regm_t regm = cg.allregs & ~(retregs1 | retregs2);
            Rquo = allocreg(cdb, regm, ty);
            assert(Rquo != Rdividend && Rquo != Rdivisor);
            Rmod = allocreg(cdb, retregs, ty);
            break;
        }
        case OPremquo:
        {
            regm_t regm = cg.allregs & ~(retregs1 | retregs2);
            Rquo = allocreg(cdb, regm, ty);
            assert(Rquo != Rdividend && Rquo != Rdivisor);
            Rmod = findreg(regm & INSTR.MSW);
            assert(Rmod != Rquo);
            break;
        }
    }

    // http://www.scs.stanford.edu/~zyedidia/arm64/sdiv.html
    // http://www.scs.stanford.edu/~zyedidia/arm64/udiv.html

    bool sf = sz == 8;

    // DIV Rd, Rn, Rm
    uint ins = INSTR.sdiv_udiv(sf, uns, Rdivisor, Rdividend, Rquo);
    cdb.gen1(ins);
    retregs = mask(Rquo);

    if (e.Eoper == OPmod || e.Eoper == OPremquo)
    {
        uint ins2 = INSTR.msub(sf, Rdivisor, Rdividend, Rquo, Rmod);
        cdb.gen1(ins2);
        if (e.Eoper == OPmod)
            retregs = mask(Rmod);
        else
            // MSW = Modulo, LSW = Quotient
            retregs = mask(Rquo) | mask(Rmod);
    }

    fixresult(cdb,e,retregs,pretregs);
}

/***************************
 * Handle OPnot and OPbool.
 * Generate:
 *      c:      [evaluate e1]
 *      cfalse: [save reg code]
 *              clr     reg
 *              jmp     cnop
 *      ctrue:  [save reg code]
 *              clr     reg
 *              inc     reg
 *      cnop:   nop
 */

@trusted
void cdnot(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdnot() pretregs = %s\n", regm_str(pretregs));
    //elem_print(e);
    reg_t reg;
    regm_t forflags;
    elem* e1 = e.E1;

    if (pretregs == 0 ||
        pretregs == mPSW)
    {
        codelem(cgstate,cdb,e1,pretregs,false);      // evaluate e1 for cc
        return;
    }

    OPER op = e.Eoper;
    uint sz = tysize(e1.Ety);

    if (tyfloating(e1.Ety))
    {
        regm_t retregs1 = INSTR.FLOATREGS;
        codelem(cgstate,cdb,e.E1,retregs1,1);
        const V1 = findreg(retregs1);
        const ftype = INSTR.szToFtype(sz);
        cdb.gen1(INSTR.fcmpe_float(ftype,0,V1));        // FCMPE V1,#0.0

        regm_t retregs = pretregs & cgstate.allregs;
        if (!retregs)
            retregs = cgstate.allregs;
        const Rd = findreg(retregs);
        const cond = op == OPnot ? COND.ne : COND.eq;
        cdb.gen1(INSTR.cset(sz == 8,cond,Rd));          // CSET Rd,eq
        uint N,immr,imms;
        assert(encodeNImmrImms(0xFF,N,immr,imms));
        cdb.gen1(INSTR.log_imm(0,0,0,immr,imms,Rd,Rd)); // AND Rd,Rd,#0xFF
        pretregs &= ~mPSW;                              // flags already set
        fixresult(cdb,e,retregs,pretregs);
    }
    else
    {
        const posregs = cgstate.allregs;
        regm_t retregs1 = posregs;
        codelem(cgstate,cdb,e.E1,retregs1,false);
        const R1 = findreg(retregs1);       // source register

        regm_t retregs = pretregs & cg.allregs;
        if (retregs == 0)                   // if no return regs speced
                                            // (like if wanted flags only)
            retregs = ALLREGS & posregs;    // give us some
        const tym = tybasic(e.Ety);
        reg_t Rd = allocreg(cdb, retregs, tym); // destination register

        uint sf = sz == 8;

        cdb.gen1(INSTR.cmp_imm(sf,0,0,R1));  // CMP R1,#0
        COND cond = op == OPnot ? COND.ne : COND.eq;
        cdb.gen1(INSTR.cset(sf,cond,Rd));    // CSET Rd,EQ

        uint N,immr,imms;
        assert(encodeNImmrImms(0xFF,N,immr,imms));
        cdb.gen1(INSTR.log_imm(0,0,0,immr,imms,Rd,Rd)); // AND Rd,Rd,#0xFF

        fixresult(cdb,e,retregs,pretregs);
    }
}

/************************
 * Complement operator
 */

@trusted
void cdcom(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdcom()\n");
    //elem_print(e);
    if (pretregs == 0)
    {
        codelem(cgstate,cdb,e.E1,pretregs,false);
        return;
    }
    const tyml = tybasic(e.E1.Ety);
    const sz = _tysize[tyml];
    if (tyfloating(tyml))
    {
        assert(0);
    }

    regm_t retregs1 = cg.allregs;
    codelem(cgstate,cdb,e.E1,retregs1,false);

    regm_t retregs = pretregs & cg.allregs;
    if (retregs == 0)                   /* if no return regs speced     */
                                        /* (like if wanted flags only)  */
        retregs = cg.allregs;           // give us some
    reg_t Rd = allocreg(cdb, retregs, tyml);

    const Rm = findreg(retregs1);

    /* MVN Rd, Rm{, shift #amount }
     * https://www.scs.stanford.edu/~zyedidia/arm64/mvn_orn_log_shift.html
     */
    uint sf = sz == 8;
    cdb.gen1(INSTR.log_shift(sf, 1, 0, 1, Rm, 0, 31, Rd));
    //pretregs &= ~mPSW;             // flags not set

    fixresult(cdb,e,retregs,pretregs);
}

/************************
 * Bswap operator
 */

@trusted
void cdbswap(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdbswap()\n");
    //elem_print(e);
    if (pretregs == 0)
    {
        codelem(cgstate,cdb,e.E1,pretregs,false);
        return;
    }
    const tyml = tybasic(e.E1.Ety);
    const sz = _tysize[tyml];
    if (tyfloating(tyml))
    {
        assert(0);
    }

    const posregs = cgstate.allregs;
    regm_t retregs1 = posregs;
    codelem(cgstate,cdb,e.E1,retregs1,false);

    regm_t retregs = pretregs & cg.allregs;
    if (retregs == 0)                   /* if no return regs speced     */
                                        /* (like if wanted flags only)  */
        retregs = ALLREGS & posregs;    // give us some
    reg_t Rd = allocreg(cdb, retregs, tyml);

    const Rn = findreg(retregs1);

    /* REV16/REV32/REV64 Rd,Rn
     * https://www.scs.stanford.edu/~zyedidia/arm64/rev16_int.html
     * https://www.scs.stanford.edu/~zyedidia/arm64/rev32_int.html
     * https://www.scs.stanford.edu/~zyedidia/arm64/rev64_rev.html
     */
    uint sf = sz >= 4;
    uint S = 0;
    uint opcode2 = 0;
    uint opcode = sz == 2 ? 1 : sz == 4 ? 2 : 3;
    cdb.gen1(INSTR.dp_1src(sf, S, opcode2, opcode, Rn, Rd));
    fixresult(cdb,e,retregs,pretregs);
}

/*************************
 * ?: operator
 */

@trusted
void cdcond(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdcond(e = %p, pretregs = %s)\n",e,regm_str(pretregs));
    /* e1 ? e21 : e22
     */
    elem* e1 = e.E1;
    elem* e2 = e.E2;
    elem* e21 = e2.E1;
    elem* e22 = e2.E2;
    regm_t psw = pretregs & mPSW;               /* save PSW bit                 */
    const op1 = e1.Eoper;
    uint sz1 = tysize(e1.Ety);
    COND jop = conditionCode(e1);

    COND jop1 = conditionCode(e21);
    COND jop2 = conditionCode(e22);

    docommas(cdb,e1);
    cgstate.stackclean++;

    if (!OTrel(op1) && e1 == e21 && sz1 <= REGSIZE)
    {   // Recognize (e ? e : f)

        code* cnop1 = gen1(null, INSTR.nop);
        regm_t retregs = pretregs | mPSW;
        codelem(cgstate,cdb,e1,retregs,false);

        cse_flush(cdb,1);                // flush CSEs to memory
        genBranch(cdb,jop,FL.code,cast(block*)cnop1);
        freenode(e21);

        const regconsave = cgstate.regcon;
        const stackpushsave = cgstate.stackpush;

        retregs |= psw;
        if (retregs & cgstate.allregs)  // TODO AArch64 add support for fp registers
            cgstate.regimmed_set(findreg(retregs),0);
        codelem(cgstate,cdb,e22,retregs,false);

        andregcon(regconsave);
        assert(stackpushsave == cgstate.stackpush);

        pretregs = retregs;
        freenode(e2);
        cdb.append(cnop1);
        cgstate.stackclean--;
        return;
    }

    uint sz2;
    if (0 && OTrel(op1) && sz1 <= REGSIZE && tysize(e2.Ety) <= REGSIZE && // TODO AArch64
        !e1.Ecount &&
        (jop == COND.cs || jop == COND.cc) &&
        (sz2 = tysize(e2.Ety)) <= REGSIZE &&
        e21.Eoper == OPconst &&
        e22.Eoper == OPconst
       )
    {
        /* recognize (e1 ? v1 : v2) and generate
         *   EAX = 0 or -1
         *   and EAX,v1 - v2
         *   add EAX, v2
         * AArch64 can use:
         *    compare
         *    mov x1,v2
         *    mov x2,v1
         *    csel x0,x1,x0,cond
         */
        uint sz = tysize(e.Ety);
        uint rex = (I64 && sz == 8) ? REX_W : 0;
        uint grex = rex << 16;

        regm_t retregs;
        targ_size_t v1,v2;

        if (sz2 != 1 || I64)
        {
            retregs = pretregs & (ALLREGS | mBP);
            if (!retregs)
                retregs = ALLREGS;
        }
        else
        {
            retregs = pretregs & BYTEREGS;
            if (!retregs)
                retregs = BYTEREGS;
        }

        cg.cmp_flag = 1 | rex;
        v1 = cast(targ_size_t)e21.Vllong;
        v2 = cast(targ_size_t)e22.Vllong;
        if (jop == JNC)
        {   v1 = v2;
            v2 = cast(targ_size_t)e21.Vllong;
        }

        opcode_t opcode = 0x81;
        switch (sz2)
        {   case 1:     opcode--;
                        v1 = cast(byte) v1;
                        v2 = cast(byte) v2;
                        break;

            case 2:     v1 = cast(short) v1;
                        v2 = cast(short) v2;
                        break;

            case 4:     v1 = cast(int) v1;
                        v2 = cast(int) v2;
                        break;
            default:
                        break;
        }

        if (I64 && v1 != cast(targ_ullong)cast(targ_ulong)v1)
        {
            // only zero-extension from 32-bits is available for 'or'
        }
        else if (I64 && cast(targ_llong)v2 != cast(targ_llong)cast(targ_long)v2)
        {
            // only sign-extension from 32-bits is available for 'and'
        }
        else
        {
            codelem(cgstate,cdb,e1,retregs,false);
            const reg = findreg(retregs);

            if (v1 == 0 && v2 == ~cast(targ_size_t)0)
            {
                cdb.gen2(0xF6 + (opcode & 1),grex | modregrmx(3,2,reg));  // NOT reg
                if (I64 && sz2 == REGSIZE)
                    code_orrex(cdb.last(), REX_W);
                if (I64 && sz2 == 1 && reg >= 4)
                    code_orrex(cdb.last(), REX);
            }
            else
            {
                v1 -= v2;
                cdb.genc2(opcode,grex | modregrmx(3,4,reg),v1);   // AND reg,v1-v2
                if (I64 && sz2 == 1 && reg >= 4)
                    code_orrex(cdb.last(), REX);
                if (v2 == 1 && !I64)
                    cdb.gen1(0x40 + reg);                     // INC reg
                else if (v2 == -1L && !I64)
                    cdb.gen1(0x48 + reg);                     // DEC reg
                else
                {   cdb.genc2(opcode,grex | modregrmx(3,0,reg),v2);   // ADD reg,v2
                    if (I64 && sz2 == 1 && reg >= 4)
                        code_orrex(cdb.last(), REX);
                }
            }

            freenode(e21);
            freenode(e22);
            freenode(e2);

            fixresult(cdb,e,retregs,pretregs);
            cgstate.stackclean--;
            return;
        }
    }

    if (0 && op1 != OPcond && op1 != OPandand && op1 != OPoror && // TODO AArch64
        op1 != OPnot && op1 != OPbool &&
        e21.Eoper == OPconst &&
        sz1 <= REGSIZE &&
        pretregs & (mBP | ALLREGS) &&
        tysize(e21.Ety) <= REGSIZE && !tyfloating(e21.Ety))
    {   /* Recognize (e ? c : f) and generate:
         *  test e1
         *  reg = c;
         *  jop L1;
         *  reg = f;
         * L1:
         *  cnop1
         */

        code* cnop1 = gen1(null, INSTR.nop);
        regm_t retregs = mPSW;
        jop = conditionCode(e1);            // get jmp condition
        codelem(cgstate,cdb,e1,retregs,false);

        // Set the register with e21 without affecting the flags
        retregs = pretregs & (ALLREGS | mBP);
        if (retregs & ~cgstate.regcon.mvar)
            retregs &= ~cgstate.regcon.mvar;    // don't disturb register variables
        // NOTE: see my email (sign extension bug? possible fix, some questions
        const reg = regwithvalue(cdb,retregs,cast(targ_size_t)e21.Vllong,
                                 tysize(e21.Ety) == 8 ? 64|8 : 8);
        retregs = mask(reg);

        cse_flush(cdb,1);                // flush CSE's to memory
        genBranch(cdb,jop,FL.code,cast(block*)cnop1);
        freenode(e21);

        const regconsave = cgstate.regcon;
        const stackpushsave = cgstate.stackpush;

        codelem(cgstate,cdb,e22,retregs,false);

        andregcon(regconsave);
        assert(stackpushsave == cgstate.stackpush);

        freenode(e2);
        cdb.append(cnop1);
        fixresult(cdb,e,retregs,pretregs);
        cgstate.stackclean--;
        return;
    }

    code* cnop1 = gen1(null, INSTR.nop);
    code* cnop2 = gen1(null, INSTR.nop);         // dummy target addresses
    logexp(cdb,e1,false,FL.code,cnop1);  // evaluate condition
    const regconold = cgstate.regcon;
    const stackpushold = cgstate.stackpush;
    regm_t retregs = pretregs;
    CodeBuilder cdb1;
    cdb1.ctor();
    if (psw && jop1 != COND.ne)
    {
        retregs &= ~mPSW;
        if (!retregs)
            retregs = ALLREGS;
        codelem(cgstate,cdb1,e21,retregs,false);
        fixresult(cdb1,e21,retregs,pretregs);
    }
    else
        codelem(cgstate,cdb1,e21,retregs,false);

    if (CPP && e2.Eoper == OPcolon2)
    {
        code cs;

        // This is necessary so that any cleanup code on one branch
        // is redone on the other branch.
        cs.Iop = PSOP.mark2;
        cs.Iflags = 0;
        cs.Irex = 0;
        cdb.gen(&cs);
        cdb.append(cdb1);
        cs.Iop = PSOP.release2;
        cdb.gen(&cs);
    }
    else
        cdb.append(cdb1);

    const regconsave = cgstate.regcon;
    cgstate.regcon = cast()regconold;

    const stackpushsave = cgstate.stackpush;
    cgstate.stackpush = stackpushold;

    retregs |= psw;                     // PSW bit may have been trashed
    pretregs |= psw;
    CodeBuilder cdb2;
    cdb2.ctor();
    if (psw && jop2 != COND.ne)
    {
        retregs &= ~mPSW;
        if (!retregs)
            retregs = ALLREGS;
        codelem(cgstate,cdb2,e22,retregs,false);
        fixresult(cdb2,e22,retregs,pretregs);
    }
    else
        codelem(cgstate,cdb2,e22,retregs,false);   // use same regs as E1
    pretregs = retregs | psw;
    andregcon(regconold);
    andregcon(regconsave);
    assert(cgstate.stackpush == stackpushsave);
    freenode(e2);
    genBranch(cdb,COND.al,FL.code,cast(block*) cnop2);
    cdb.append(cnop1);
    cdb.append(cdb2);
    cdb.append(cnop2);

    cgstate.stackclean--;
}

// cdcomma (same for x86_64 and AArch64)

/*********************************
 * Do && and || operators.
 * Generate:
 *              (evaluate e1 and e2, if true goto cnop1)
 *      cnop3:  NOP
 *      cg:     [save reg code]         ;if we must preserve reg
 *              CLR     reg             ;false result (set Z also)
 *              JMP     cnop2
 *
 *      cnop1:  NOP                     ;if e1 evaluates to true
 *              [save reg code]         ;preserve reg
 *
 *              MOV     reg,1           ;true result
 *                  or
 *              CLR     reg             ;if return result in flags
 *              INC     reg
 *
 *      cnop2:  NOP                     ;mark end of code
 */

@trusted
void cdloglog(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    /* We can trip the assert with the following:
     *    if ( (b<=a) ? (c<b || a<=c) : c>=a )
     * We'll generate ugly code for it, but it's too obscure a case
     * to expend much effort on it.
     * assert(pretregs != mPSW);
     */

    //printf("cdloglog() pretregs: %s\n", regm_str(pretregs));
    cgstate.stackclean++;
    code* cnop1 = gen1(null, INSTR.nop);
    CodeBuilder cdb1;
    cdb1.ctor();
    cdb1.append(cnop1);
    code* cnop3 = gen1(null, INSTR.nop);
    elem* e2 = e.E2;
    (e.Eoper == OPoror)
        ? logexp(cdb,e.E1,1,FL.code,cnop1)
        : logexp(cdb,e.E1,0,FL.code,cnop3);
    con_t regconsave = cgstate.regcon;
    uint stackpushsave = cgstate.stackpush;
    if (pretregs == 0)                 // if don't want result
    {
        int noreturn = !el_returns(e2);
        codelem(cgstate,cdb,e2,pretregs,false);
        if (noreturn)
        {
            regconsave.used |= cgstate.regcon.used;
            cgstate.regcon = regconsave;
        }
        else
            andregcon(regconsave);
        assert(cgstate.stackpush == stackpushsave);
        cdb.append(cnop3);
        cdb.append(cdb1);        // eval code, throw away result
        cgstate.stackclean--;
        return;
    }

    if (tybasic(e2.Ety) == TYnoreturn)
    {
        regm_t retregs2 = 0;
        codelem(cgstate,cdb, e2, retregs2, false);
        regconsave.used |= cgstate.regcon.used;
        cgstate.regcon = regconsave;
        assert(cgstate.stackpush == stackpushsave);

        regm_t retregs = pretregs & cg.allregs;
        if (!retregs)
            retregs = cg.allregs;                                     // if mPSW only

        const reg = allocreg(cdb1,retregs,TYint);                     // allocate reg for result
        movregconst(cdb1,reg,e.Eoper == OPoror,pretregs & mPSW);
        cgstate.regcon.immed.mval &= ~mask(reg);                      // mark reg as unavail
        pretregs = retregs;

        cdb.append(cnop3);
        cdb.append(cdb1);        // eval code, throw away result
        cgstate.stackclean--;
        return;
    }

    code* cnop2 = gen1(null, INSTR.nop);
    uint sz = tysize(e.Ety);
    if (tybasic(e2.Ety) == TYbool &&
      sz == tysize(e2.Ety) &&
      !(pretregs & mPSW) &&
      e2.Eoper == OPcall)
    {
        codelem(cgstate,cdb,e2,pretregs,false);

        andregcon(regconsave);

        // stack depth should not change when evaluating E2
        assert(cgstate.stackpush == stackpushsave);

        assert(sz <= 4);                                       // result better be int
        regm_t retregs = pretregs & cgstate.allregs;
        const reg = allocreg(cdb1,retregs,TYint);              // allocate reg for result
        movregconst(cdb1,reg,e.Eoper == OPoror,0);             // reg = 1
        cgstate.regcon.immed.mval &= ~mask(reg);               // mark reg as unavail
        pretregs = retregs;
        if (e.Eoper == OPoror)
        {
            cdb.append(cnop3);
            genBranch(cdb,COND.al,FL.code,cast(block*) cnop2); // JMP cnop2
            cdb.append(cdb1);
            cdb.append(cnop2);
        }
        else
        {
            genBranch(cdb,COND.al,FL.code,cast(block*) cnop2); // JMP cnop2
            cdb.append(cnop3);
            cdb.append(cdb1);
            cdb.append(cnop2);
        }
        cgstate.stackclean--;
        return;
    }

    logexp(cdb,e2,1,FL.code,cnop1);
    andregcon(regconsave);

    // stack depth should not change when evaluating E2
    assert(cgstate.stackpush == stackpushsave);

    assert(sz <= 4);                                         // result better be int
    regm_t retregs = pretregs & cg.allregs;
    if (!retregs)
        retregs = cg.allregs;                                // if mPSW only
    CodeBuilder cdbcg;
    cdbcg.ctor();
    const reg = allocreg(cdbcg,retregs,TYint);               // allocate reg for result
    code* cd = cdbcg.finish();
    for (code* c1 = cd; c1; c1 = code_next(c1))              // for each instruction
        cdb1.gen(c1);                                        // duplicate it
    CodeBuilder cdbcg2;
    cdbcg2.ctor();
    movregconst(cdbcg2,reg,0,pretregs & mPSW);               // MOV reg,0
    cgstate.regcon.immed.mval &= ~mask(reg);                 // mark reg as unavail
    genBranch(cdbcg2,COND.al,FL.code,cast(block*) cnop2);    // JMP cnop2
    movregconst(cdb1,reg,1,pretregs & mPSW);                 // reg = 1
    cgstate.regcon.immed.mval &= ~mask(reg);                 // mark reg as unavail
    pretregs = retregs;
    cdb.append(cnop3);
    cdb.append(cd);
    cdb.append(cdbcg2);
    cdb.append(cdb1);
    cdb.append(cnop2);
    cgstate.stackclean--;
}


/*********************
 * Generate code for shift left or shift right (OPshl,OPshr,OPashr,OProl,OPror).
 */

@trusted
void cdshift(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdshift()\n");

    elem* e1 = e.E1;
    elem* e2 = e.E2;
    if (pretregs == 0)                   // if don't want result
    {
        codelem(cgstate,cdb,e1,pretregs,false); // eval left leaf
        pretregs = 0;                  // in case they got set
        codelem(cgstate,cdb,e.E2,pretregs,false);
        return;
    }

    tym_t tyml = tybasic(e1.Ety);
    int sz = _tysize[tyml];
    assert(!tyfloating(tyml));

    regm_t posregs = cg.allregs;
    regm_t retregs1 = posregs;
    codelem(cg, cdb, e1, retregs1, false);
    regm_t retregs2 = cg.allregs & ~retregs1;
    scodelem(cg, cdb, e2, retregs2, retregs1, false);

    regm_t retregs = pretregs & cg.allregs;
    if (retregs == 0)                   /* if no return regs speced     */
                                        /* (like if wanted flags only)  */
        retregs = ALLREGS & posregs;    // give us some
    reg_t Rd = allocreg(cdb, retregs, tyml);

    reg_t Rn = findreg(retregs1);
    reg_t Rm = findreg(retregs2);

    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_2src
     * https://www.scs.stanford.edu/~zyedidia/arm64/lsl_lslv.html
     * https://www.scs.stanford.edu/~zyedidia/arm64/lsr_lsrv.html
     * https://www.scs.stanford.edu/~zyedidia/arm64/asr_asrv.html
     * https://www.scs.stanford.edu/~zyedidia/arm64/ror_rorv.html
     */

    uint sf = sz == 8;
    uint S = 0;
    uint opcode;
    switch (e.Eoper)
    {
        case OPshl:     opcode = 0x8;   break;  // LSL Rd,Rn,Rm https://www.scs.stanford.edu/~zyedidia/arm64/lsl_lslv.html
        case OPshr:     opcode = 0x9;   break;
        case OPashr:    opcode = 0xA;   break;
        case OPror:     opcode = 0xB;   break;
        case OProl:     assert(0); // should have rewritten (a rol b) as (a ror -b)
        default:
            assert(0);
    }
    cdb.gen1(INSTR.dp_2src(sf, S, Rm, opcode, Rn, Rd));

    fixresult(cdb,e,retregs,pretregs);
}

/***************************
 * Perform a 'star' reference (indirection).
 */

@trusted
void cdind(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdind() pregregs: %s\n", regm_str(pretregs));
    //elem_print(e);
    if (pretregs == 0)
    {
        codelem(cgstate,cdb,e.E1,pretregs,false);
        return;
    }
    const tym = tybasic(e.Ety);
    const sz = _tysize[tym];
    const uns  = tyuns(tym) != 0;

    const tym1 = tybasic(e.E1.Ety);
    const sz1  = _tysize[tym1];

    const posregs = cg.allregs;
    regm_t retregs1 = posregs;
    codelem(cg,cdb,e.E1,retregs1,false);
    const Rn = findreg(retregs1);           // Rn is the pointer

    if (tyfloating(tym))
    {
        regm_t retregs = pretregs & INSTR.FLOATREGS;
        if (retregs == 0)                   /* if no return regs speced (such as mPSW)     */
            retregs = INSTR.FLOATREGS;      // give us some
        reg_t Rt = allocreg(cdb, retregs, tym);

        code cs;
        cs.base = Rn;
        cs.reg = NOREG;
        cs.index = NOREG;
        loadFromEA(cs, Rt, sz, sz);     // LDR reg,[cs.base]
        cdb.gen1(cs.Iop);

        fixresult(cdb,e,retregs,pretregs);
        return;
    }

    regm_t retregs = pretregs & cg.allregs;
    if (retregs == 0)                   /* if no return regs speced (such as mPSW)     */
        retregs = ALLREGS & posregs;    // give us some
    reg_t Rt = allocreg(cdb, retregs, tym);

    uint size;
    uint VR = 0;
    uint opc;

    if (sz == 2 * REGSIZE)
    {
        reg_t Rlsw = findreg(retregs & ALLREGS & INSTR.LSW);
        reg_t Rmsw = findreg(retregs & ALLREGS & INSTR.MSW);
        uint imm12 = 0;
        if (Rn == Rlsw)                 // collision, reverse load order
        {
            cdb.gen1(INSTR.ldst_pos(3,0,1,imm12+1,Rn,Rmsw));    // LDR 64
            cdb.gen1(INSTR.ldst_pos(3,0,1,imm12  ,Rn,Rlsw));
        }
        else
        {
            cdb.gen1(INSTR.ldst_pos(3,0,1,imm12  ,Rn,Rlsw));
            cdb.gen1(INSTR.ldst_pos(3,0,1,imm12+1,Rn,Rmsw));
        }
        fixresult(cdb,e,retregs,pretregs);
        return;
    }

    uint decode(uint to, uint from, bool uns) { return to * 4 * 2 + from * 2 + uns; }

    // TODO AArch64 consider loadFromEA() instead
    switch (decode(sz == 8 ? 8 : 4, sz, uns))
    {
    /*
        int  = *byte    ldrsb w0,[x1]   39C00020
        int  = *ubyte   ldrb  w0,[x1]   39400020
        int  = *short   ldrsh w0,[x1]   79C00020
        int  = *ushort  ldrh  w0,[x1]   79400020
        int  = *int     ldr   w0,[x1]   B9400020
        int  = *uint    ldr   w0,[x1]   B9400020

        long = *byte    ldrsb x0,[x1]   39800020
        long = *ubyte   ldrb  x0,[x1]   39400020
        long = *short   ldrsh x0,[x1]   79800020
        long = *ushort  ldrh  x0,[x1]   79400020
        long = *int     ldrsw x0,[x1]   B9800020
        long = *uint    ldr   x0,[x1]   B9400020
        long = *long    ldr   x0,[x1]   B9400020
     */

        case decode(4, 1, 0): size = 0; opc = 3; break; // ldrsb
        case decode(4, 1, 1): size = 0; opc = 1; break; // ldrb
        case decode(4, 2, 0): size = 1; opc = 2; break; // ldrsh
        case decode(4, 2, 1): size = 1; opc = 1; break; // ldrh
        case decode(4, 4, 0):
        case decode(4, 4, 1): size = 2; opc = 1; break; // ldr 32

        case decode(8, 1, 0): size = 0; opc = 2; break; // ldrsb
        case decode(8, 1, 1): size = 0; opc = 1; break; // ldrb
        case decode(8, 2, 0): size = 1; opc = 2; break; // ldrsh
        case decode(8, 2, 1): size = 1; opc = 1; break; // ldrh
        case decode(8, 4, 0): size = 2; opc = 2; break; // ldrsw
        case decode(8, 4, 1): size = 2; opc = 1; break; // ldr 32

        case decode(8, 8, 0):
        case decode(8, 8, 1): size = 3; opc = 1; break; // ldr 64
        default:
            printf("%d %d %d\n", sz, sz1, uns);
            assert(0);
    }

    uint imm12 = 0;
    cdb.gen1(INSTR.ldst_pos(size,VR,opc,imm12,Rn,Rt));

    fixresult(cdb,e,retregs,pretregs);
}

/*********************************
 * Generate code for memset(s,value,numbytes) intrinsic.
 *      (s OPmemset (numbytes OPparam value))
 */

@trusted
void cdmemset(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdmemset(pretregs = %s)\n", regm_str(pretregs));
    elem* e2 = e.E2;
    assert(e2.Eoper == OPparam);

    elem* evalue = e2.E2;
    elem* enumbytes = e2.E1;

    const sz = tysize(evalue.Ety);
    if (sz > 1)
    {
        cdmemsetn(cg, cdb, e, pretregs);
        return;
    }

    if (enumbytes.Eoper == OPconst ||
        evalue.Eoper == OPstrpar) // happens if evalue is a struct of 0 size
    {
        // Get nbytes into nbytesreg
        regm_t nbytesregs = cgstate.allregs & ~pretregs;
        if (!nbytesregs)
            nbytesregs = cgstate.allregs;
        codelem(cgstate,cdb,enumbytes,nbytesregs,false);

        ulong value = evalue.Eoper == OPstrpar ? 0 : el_tolong(evalue) & 0xFF;
        value |= value << 8;
        value |= value << 16;
        value |= value << 32;

        regm_t valueregs;
        reg_t valuereg;
        if (value == 0)
        {
            valueregs = 0;
            valuereg = 0x1F; // xzr
        }
        else
        {
            valueregs = cgstate.allregs & ~(pretregs | nbytesregs);
            if (!valueregs)
                valueregs = cgstate.allregs & ~nbytesregs;
            valuereg = regwithvalue(cdb, valueregs, value, 64);
            valueregs = mask(valuereg);
            getregs(cdb, valueregs);
            valuereg = findreg(valueregs);
            cgstate.regimmed_set(valuereg, value);
        }
        freenode(evalue);

        freenode(e2);

        // Get destination into dstreg
        regm_t dstregs = cgstate.allregs & ~(nbytesregs | valueregs);
        scodelem(cgstate,cdb,e.E1,dstregs,nbytesregs | valueregs,false);
        reg_t dstreg = findreg(dstregs);

        regm_t retregs;
        if (pretregs)                              // if need return value
        {
            retregs = pretregs & ~(nbytesregs | valueregs | dstregs);
            if (!retregs)
                retregs = cgstate.allregs & ~(nbytesregs | valueregs | dstregs);
            reg_t retreg = allocreg(cdb,retregs,TYnptr);
            genmovreg(cdb,retreg,dstreg);           // MOV retreg,dstreg
        }

        uint numbytes = cast(uint)el_tolong(enumbytes);
        if (const n = numbytes & ~(REGSIZE - 1))
        {
            regm_t limits = cgstate.allregs & ~(nbytesregs | valueregs | dstregs | retregs);
            reg_t limit = regwithvalue(cdb,limits,n / REGSIZE,64);      // MOV limit,#n / REGSIZE
            cdb.gen1(INSTR.addsub_ext(1,0,0,0,limit,6,3,dstreg,limit)); // ADD limit,dstreg,limit,UXTW #3

            code* cnop = gen1(null, INSTR.nop);
            cdb.append(cnop);

            cdb.gen1(INSTR.ldst_immpost(3,0,0,8,dstreg,valuereg));      // STR  valuereg,[dstreg],#8        // *dstreg++ = valuereg
            cdb.gen1(INSTR.cmp_shift(1,dstreg,0,0,limit));              // CMP  limit,dstreg
            genBranch(cdb,COND.ne,FL.code,cast(block*)cnop);            // JNE cnop
        }

        auto remainder = numbytes & (REGSIZE - 1);
        if (remainder >= 4)
        {
            cdb.gen1(INSTR.ldst_immpost(2,0,0,4,dstreg,valuereg));      // STR  valuereg,[dstreg],#4        // *dstreg++ = valuereg
            remainder -= 4;
        }
        for (; remainder; --remainder)
            cdb.gen1(INSTR.ldst_immpost(0,0,0,1,dstreg,valuereg));      // STRB valuereg,[dstreg],#1        // *dstreg++ = valuereg
        fixresult(cdb,e,retregs,pretregs);
        return;
    }

    /* ptr => x0
     * value => w1
     * num => x2
     */

    // Get nbytes into x2
    regm_t nbytesregs = mask(2);
    codelem(cgstate,cdb,enumbytes,nbytesregs,false);

    // Get value into w1
    regm_t valueregs = mask(1);
    scodelem(cgstate,cdb,evalue,valueregs,nbytesregs,false);

    freenode(e2);

    // Get destination into x0
    regm_t dstregs = mask(0);
    scodelem(cgstate,cdb,e.E1,dstregs,nbytesregs | valueregs,false);

    callclib(cdb,null,CLIB_A.memset,pretregs,0);        // memset(void* ptr, int value, size_t num)
}

/***********************************************
 * Do memset for values larger than a byte.
 * Has many similarities to cod4.cdeq().
 * Doesn't work for 16 bit code.
 */
@trusted
private void cdmemsetn(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdmemsetn(pretregs = %s)\n", regm_str(pretregs));
    elem* e2 = e.E2;
    assert(e2.Eoper == OPparam);

    /*  evalue: value to store
        szv: size in bytes of value
        tyv: type of value
        vregs: mask of registers for evalue
        Rv: register holding evalue
        Rvhi: MSW register holding evalue for 2*REGSIZE

        enelems: count of evalues to store
        cregs: mask of registers enelems is in
        Rc: register with count

        e.E1: pointer to destination
        dregs: mask of registers for pointer to destination
        Rd: pointer to destination, return value

        Rp: incrementing pointer
        Rlim: limit pointer value
     */

    // Set cregs to count of elems
    elem* enelems = e2.E1;
    regm_t cregs = cg.allregs & ~pretregs;
    if (!cregs)
        cregs = cg.allregs;
    codelem(cgstate,cdb,enelems,cregs,false);

    // Set vregs to value
    elem* evalue = e2.E2;
    tym_t tyv = tybasic(evalue.Ety);
    const szv = tysize(tyv);
    assert(cast(int)szv > 1);
    regm_t vregs = cgstate.allregs & ~cregs;
    scodelem(cgstate,cdb,evalue,vregs,cregs,false);

    /* Necessary because if evalue calls a function, and that function never returns,
     * it doesn't affect registers. Which means those registers can be used for enregistering
     * variables, and next pass fails because it can't use those registers, and so cannot
     * allocate registers for vregs. See ice11596.d
     */
    useregs(vregs);

    // Set [Rvhi,Rv] to value
    reg_t Rv = findreg(vregs);
    reg_t Rvhi = NOREG;
    if (szv == 2 * REGSIZE)
    {
        Rv   = findreg(vregs & INSTR.LSW);
        Rvhi = findreg(vregs & INSTR.MSW);
    }

    freenode(e2);

    // Set Rd to destination
    regm_t dregs = cg.allregs & ~(cregs | vregs);
    assert(dregs);
    scodelem(cgstate,cdb,e.E1,dregs,cregs | vregs,false);
    reg_t Rd = findreg(dregs);

    reg_t Rp = Rd;
    if (pretregs)                              // if need return value
    {
        regm_t mRp = pretregs & ~(dregs | cregs | vregs);
        if (!mRp)
            mRp = cgstate.allregs & ~(dregs | cregs | vregs);
        Rp = allocreg(cdb, mRp, TYnptr);
        getregs(cdb, mRp);
        genmovreg(cdb,Rp,Rd);            // MOV Rp,Rd
    }

    // allocate limit register Rl
    regm_t lims = cg.allregs & ~(dregs | cregs | vregs | mask(Rp));
    const Rl = allocreg(cdb, lims, TYnptr);

    getregs(cdb,mask(Rp) | lims);               // modify Rp,Rl

    /* Generate:
        cbz     Rc, L1
        add     Rl, Rd, Rc, uxtw #2
        mov     Rp, Rd
    L2: str     Rv, [Rp], #4
        cmp     Rp, Rl
        b.ne    L2
    L1: nop
     */
    reg_t Rc = findreg(cregs);
    code* c1 = gen1(null, INSTR.nop);
    uint sf = tysize(enelems.Ety) == 8;
    genCompBranch(cdb,sf,Rc,0,FL.code,cast(block*)c1);  // cbz Rc,c1

    // http://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#addsub_ext
    uint op = 0;                // add
    uint S = 0;                 // don't set flags
    uint opt = 0;
    uint option = tyToExtend(enelems.Ety);
    uint opc;
    uint imm3;
    INSTR.szToSizeOpc(szv,imm3,opc);    // shift 0..4
    if (szv == REGSIZE * 2)
    {
        imm3 = 3;
        opc = 0;
    }
    cdb.gen1(INSTR.addsub_ext(1,op,S,opt,Rc,option,imm3,Rd,Rl));

    if (Rp != Rd)
        genmovreg(cdb,Rp,Rd);

    cdb.gen1(INSTR.ldst_immpost(imm3,0,0,0,Rp,Rv));     // L2: STR  Rv,[Rp],#0        // *Rp++ = Rv
    code* L2 = cdb.last();
    if (szv == REGSIZE * 2)
        cdb.gen1(INSTR.ldst_immpost(imm3,0,0,0,Rp,Rvhi)); // L2: STR  Rvhi,[Rp],#0    // *Rp++ = Rvhi
    cdb.gen1(INSTR.cmp_shift(1,Rl,0,0,Rp));             // CMP Rp,Rl
    genBranch(cdb,COND.ne,FL.code,cast(block*)L2);      // b.ne L2
    cdb.append(c1);

    fixresult(cdb,e,dregs,pretregs);
}

/**********************
 * Do structure assignments.
 * This should be fixed so that (s1 = s2) is rewritten to (&s1 = &s2).
 * Mebbe call cdstreq() for double assignments???
 */

@trusted
void cdstreq(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    printf("cdstreq(e = %p, pretregs = %s)\n", e, regm_str(pretregs));
    elem_print(e);
    char need_DS = false;
    elem* e1 = e.E1;
    elem* e2 = e.E2;
    uint numbytes = cast(uint)type_size(e.ET);          // # of bytes in structure/union
    //printf("numbytes: %u\n", numbytes);

    docommas(cdb,e2);

    // load pointer to rvalue into source register
    regm_t srcregs = cgstate.allregs & ~pretregs;
    if (!srcregs)
        srcregs = cgstate.allregs;
    if (e2.Eoper == OPind)             // if (.. = *p)
    {
        codelem(cg,cdb,e2.E1,srcregs,false);
        freenode(e2);
    }
    else if (e2.Eoper == OPvar)
    {
        cdrelconst(cgstate,cdb,e2,srcregs);
        freenode(e2);
    }
    else
    {
        codelem(cgstate,cdb,e2,srcregs,false);
    }

    // load pointer to lvalue (destination) in DI
    regm_t dstregs = cgstate.allregs & ~pretregs;
    if (!dstregs)
        dstregs = cgstate.allregs;
    if (e1.Eoper == OPind)               // if (*p = ..)
    {
        scodelem(cg,cdb,e1.E1,dstregs,srcregs,false);
    }
    else
        cdrelconst(cg,cdb,e1,dstregs);
    freenode(e1);

    regm_t regm = cg.allregs & ~(srcregs | dstregs);
    allocreg(cdb, regm, TYint);
    reg_t Rv = findreg(regm);

    reg_t Rs = findreg(srcregs);
    reg_t Rd = findreg(dstregs);

    getregs(cdb,srcregs | dstregs | regm);
    if (numbytes <= REGSIZE * 7)
    {
        code csrc;
        csrc.base = Rs;
        csrc.index = NOREG;
        csrc.reg = NOREG;

        code cdst;
        cdst.base = Rd;
        cdst.index = NOREG;
        cdst.reg = NOREG;

        ulong offset;

        while (numbytes >= REGSIZE)
        {
            loadFromEA(csrc,Rv,8,8);
            cdb.genc1(csrc.Iop,0,FL.offset,offset);
            storeToEA(cdst,Rv,8);
            cdb.genc1(cdst.Iop,0,FL.offset,offset);
            offset += REGSIZE;
            numbytes -= REGSIZE;
        }

        while (numbytes >= 4)
        {
            loadFromEA(csrc,Rv,4,4);
            cdb.genc1(csrc.Iop,0,FL.offset,offset);
            storeToEA(cdst,Rv,4);
            cdb.genc1(csrc.Iop,0,FL.offset,offset);
            offset += 4;
            numbytes -= 4;
        }

        while (numbytes >= 2)
        {
            loadFromEA(csrc,Rv,4,2);
            cdb.genc1(csrc.Iop,0,FL.offset,offset);
            storeToEA(cdst,Rv,2);
            cdb.genc1(csrc.Iop,0,FL.offset,offset);
            offset += 2;
            numbytes -= 2;
        }

        if (numbytes)
        {
            loadFromEA(csrc,Rv,4,1);
            cdb.genc1(csrc.Iop,0,FL.offset,offset);
            storeToEA(cdst,Rv,1);
            cdb.genc1(csrc.Iop,0,FL.offset,offset);
        }
    }
    else
    {
        /*
            mov   Rc, #count*8
            mov   Ri, #0x0
        L2: ldr   Rv, [Rs, Ri]
            str   Rv, [Rd, Ri]
            add   Ri, Ri, #8
            cmp   Ri, Rc
            b.ne  L2
         */

        uint remainder = numbytes & (REGSIZE - 1);
        numbytes /= REGSIZE;            // number of words

        regm_t iregs = cg.allregs & ~(srcregs | dstregs | regm);
        reg_t Ri = allocreg(cdb,iregs,TYnptr);

        regm_t cregs = cg.allregs & ~(srcregs | dstregs | regm | iregs);
        reg_t Rc = allocreg(cdb,cregs,TYnptr);

        code csrc;
        csrc.base = Rs;
        csrc.index = Ri;
        csrc.reg = NOREG;
        csrc.Sextend = 3;                               // LSL

        code cdst;
        cdst.base = Rd;
        cdst.index = Ri;
        cdst.reg = NOREG;
        cdst.Sextend = 3;                               // LSL

        movregconst(cdb,Rc,numbytes * 8,0);             // mov   Rc,#count * 8
        movregconst(cdb,Ri,0,0);                        // mov   Ri,0

        loadFromEA(csrc,Rv,8,8);                        // L2:   ldr Rv,[Rs,Ri]
        cdb.genc1(csrc.Iop,0,FL.unde,0);
        code* L2 = cdb.last();
        storeToEA(cdst,Rv,8);                           // str  Rv,[Rd,Ri]
        cdb.genc1(cdst.Iop,0,FL.unde,0);

        cdb.gen1(INSTR.add_addsub_imm(1,0,8,Ri,Ri));    // add  Ri,Ri,#0x8 https://www.scs.stanford.edu/~zyedidia/arm64/add_addsub_imm.html
        cdb.gen1(INSTR.cmp_shift(0,Rc,0,0,Ri));         // cmp  Ri,Rc
        genBranch(cdb,COND.ne,FL.code,cast(block*)L2);  // b.ne L2

        uint offset = 0;
        if (remainder & 4)
        {
            loadFromEA(csrc,Rv,4,4);                    // ldr  Rv,[Rs,Ri]
            cdb.genc1(csrc.Iop,0,FL.unde,offset);
            storeToEA(cdst,Rv,4);                       // str  Rv,[Rd,Ri]
            cdb.genc1(cdst.Iop,0,FL.unde,offset);
            cdb.gen1(INSTR.add_addsub_imm(1,0,4,Ri,Ri)); // add  Ri,Ri,#0x4 https://www.scs.stanford.edu/~zyedidia/arm64/add_addsub_imm.html
            offset += 4;
        }
        if (remainder & 2)
        {
            loadFromEA(csrc,Rv,2,2);                    // ldrh  Rv,[Rs,Ri]
            cdb.genc1(csrc.Iop,0,FL.unde,offset);
            storeToEA(cdst,Rv,2);                       // strh  Rv,[Rd,Ri]
            cdb.genc1(cdst.Iop,0,FL.unde,offset);
            cdb.gen1(INSTR.add_addsub_imm(1,0,2,Ri,Ri)); // add  Ri,Ri,#0x2 https://www.scs.stanford.edu/~zyedidia/arm64/add_addsub_imm.html
            offset += 2;
        }
        if (remainder & 1)
        {
            loadFromEA(csrc,Rv,1,1);                    // ldrb  Rv,[Rs,Ri]
            cdb.genc1(csrc.Iop,0,FL.unde,offset);
            storeToEA(cdst,Rv,1);                       // strb  Rv,[Rd,Ri]
            cdb.genc1(cdst.Iop,0,FL.unde,offset);
        }
    }
    assert(!(pretregs & mPSW));
    if (pretregs)
    {   // ES:DI points past what we want

        //cdb.genc2(0x81,(rex << 16) | modregrm(3,5,DI), type_size(e.ET));   // SUB DI,numbytes

        const tym = tybasic(e.Ety);
        if (tym == TYucent)
        {
            /* https://issues.dlang.org/show_bug.cgi?id=22175
             * The trouble happens when the struct size does not fit exactly into
             * 2 registers. Then the type of e becomes a TYucent, not a TYstruct,
             * and we need to dereference DI to get the ucent
             */

            // dereference DI
            regm_t retregs = pretregs & ~srcregs;
            if (!retregs)
                retregs = cgstate.allregs & ~srcregs;
            allocreg(cdb,retregs,tym);

            reg_t msreg = findreg(retregs & INSTR.MSW);

            code cs;
            cs.base = Rs;
            cs.index = NOREG;
            cs.reg = NOREG;

            loadFromEA(cs,msreg,8,8);                   // ldr  msreg,[Rs,REGSIZE]
            cdb.genc1(cs.Iop,0,FL.offset,REGSIZE);

            reg_t lsreg = findreg(retregs & INSTR.LSW);
            loadFromEA(cs,lsreg,8,8);                   // ldr  lsreg,[Rs]
            cdb.genc1(cs.Iop,0,FL.offset,0);

            fixresult(cdb,e,retregs,pretregs);
            return;
        }

        fixresult(cdb,e,dstregs,pretregs);
    }
}

/**********************
 * Get the address of.
 * Is also called by cdstreq() to set up pointer to a structure.
 */

@trusted
void cdrelconst(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdrelconst(e = %p, pretregs = %s)\n", e, regm_str(pretregs));

    /* The following should not happen, but cgelem.c is a little stupid.
     * Assertion can be tripped by func("string" == 0); and similar
     * things. Need to add goals to optelem() to fix this completely.
     */
    //assert((pretregs & mPSW) == 0);
    if (pretregs & mPSW)
    {
        pretregs &= ~mPSW;
        gentstreg(cdb,31,1);            // SP is never 0
    }
    if (!pretregs)
        return;

    assert(e);
    tym_t tym = tybasic(e.Ety);
    switch (tym)
    {
        case TYstruct:
        case TYarray:
        case TYldouble:
        case TYildouble:
        case TYcldouble:
            tym = TYnptr;               // don't confuse allocreg()
            break;

        default:
            if (tyfunc(tym))
                tym = TYnptr;
            break;
    }
    //assert(tym & typtr);              // don't fail on (int)&a

    reg_t lreg = allocreg(cdb,pretregs,tym); // offset of the address
    getoffset(cg,cdb,e,lreg);
}

/*********************************
 * Load the offset portion of the address represented by e into
 * reg.
 */

@trusted
void getoffset(ref CGstate cg, ref CodeBuilder cdb,elem* e,reg_t reg)
{
    enum log = false;
    if (log) printf("getoffset(e = %p, reg = %s)\n", e, regm_str(mask(reg)));
    code cs;
    cs.Iflags = 0;
    ubyte rex = 0;
    cs.Irex = rex;
    assert(e.Eoper == OPvar || e.Eoper == OPrelconst);
    auto fl = el_fl(e);
    //printf("fl: %s\n", fl_str(fl));
    //symbol_print(*e.Vsym);
    switch (fl)
    {
        case FL.datseg:
            cs.IEV1.Vpointer = e.Vpointer;
            goto L3;

        case FL.tlsdata:
            if (config.exe & EX_posix)
            {
                if (log) printf("posix threaded\n");
                uint ins = INSTR.systemmove(1,INSTR.tpidr_el0,reg); // MRS reg,tpidr_el0
                cdb.gen1(ins);

                ins = INSTR.addsub_imm(1,0,0,1,0,reg,reg);          // ADD reg,reg,#0,lsl #12
                cdb.gencs1(ins,0,fl,e.Vsym);

                ins = INSTR.addsub_imm(1,0,0,0,0,reg,reg);          // ADD reg,reg,#0
                cdb.gencs1(ins,0,fl,e.Vsym);
                cdb.last.Iflags |= CFadd;
                return;
            }
            assert(0);
static if (0)
{
        if (config.exe & EX_posix)
        {
            if (config.flags3 & CFG3pic)
            {
                if (I64)
                {
                    /* Generate:
                     *   LEA DI,s@TLSGD[RIP]
                     */
                    //assert(reg == DI);
                    code css;
                    css.Irex = REX | REX_W;
                    css.Iop = LEA;
                    css.Irm = modregrm(0,reg,5);
                    if (reg & 8)
                        css.Irex |= REX_R;
                    css.Iflags = CFopsize;
                    css.IFL1 = fl;
                    css.IEV1.Vsym = e.Vsym;
                    css.IEV1.Voffset = e.Voffset;
                    cdb.gen(&css);
                }
                else
                {
                    /* Generate:
                     *   LEA EAX,s@TLSGD[1*EBX+0]
                     */
                    assert(reg == AX);
                    load_localgot(cdb);
                    code css;
                    css.Iflags = 0;
                    css.Iop = LEA;             // LEA
                    css.Irex = 0;
                    css.Irm = modregrm(0,AX,4);
                    css.Isib = modregrm(0,BX,5);
                    css.IFL1 = fl;
                    css.IEV1.Vsym = e.Vsym;
                    css.IEV1.Voffset = e.Voffset;
                    cdb.gen(&css);
                }
                return;
            }
            /* Generate:
             *      MOV reg,GS:[00000000]
             *      ADD reg, offset s@TLS_LE
             * for locals, and for globals:
             *      MOV reg,GS:[00000000]
             *      ADD reg, s@TLS_IE
             * note different fixup
             */
            int stack = 0;
            if (reg == STACK)
            {   regm_t retregs = ALLREGS;

                const regx = allocreg(cdb,retregs,TYoffset);
                reg = findreg(retregs);
                stack = 1;
            }

            code css;
            css.Irex = rex;
            css.Iop = 0x8B;
            css.Irm = modregrm(0, 0, BPRM);
            code_newreg(&css, reg);
            css.Iflags = CFgs;
            css.IFL1 = FL.const_;
            css.IEV1.Vuns = 0;
            cdb.gen(&css);               // MOV reg,GS:[00000000]

            if (e.Vsym.Sclass == SC.static_ || e.Vsym.Sclass == SC.locstat)
            {   // ADD reg, offset s
                cs.Irex = rex;
                cs.Iop = 0x81;
                cs.Irm = modregrm(3,0,reg & 7);
                if (reg & 8)
                    cs.Irex |= REX_B;
                cs.Iflags = CFoff;
                cs.IFL1 = fl;
                cs.IEV1.Vsym = e.Vsym;
                cs.IEV1.Voffset = e.Voffset;
            }
            else
            {   // ADD reg, s
                cs.Irex = rex;
                cs.Iop = 0x03;
                cs.Irm = modregrm(0,0,BPRM);
                code_newreg(&cs, reg);
                cs.Iflags = CFoff;
                cs.IFL1 = fl;
                cs.IEV1.Vsym = e.Vsym;
                cs.IEV1.Voffset = e.Voffset;
            }
            cdb.gen(&cs);                // ADD reg, xxxx

            if (stack)
            {
                cdb.genpush(reg);        // PUSH reg
                cdb.genadjesp(REGSIZE);
                cgstate.stackchanged = 1;
            }
        }
        else if (config.exe & EX_windos)
        {
            if (I64)
            {
            Lwin64:
                assert(reg != STACK);
                cs.IEV1.Vsym = e.Vsym;
                cs.IEV1.Voffset = e.Voffset;
                cs.Iop = 0xB8 + (reg & 7);      // MOV Ereg,offset s
                if (reg & 8)
                    cs.Irex |= REX_B;
                cs.Iflags = CFoff;              // want offset only
                cs.IFL1 = fl;
                cdb.gen(&cs);
                break;
            }
            goto L4;
        }
        else
        {
            goto L4;
        }
}

        case FL.func:
            fl = FL.extern_;                  /* don't want PC relative addresses */
            goto L4;

        case FL.extern_:
            if (config.exe & EX_posix && e.Vsym.ty() & mTYthread)
            {
                if (log) printf("posix extern threaded\n");
                regm_t scratch = ALLREGS & ~mask(reg);
                reg_t r = allocreg(cdb, scratch, TYoffset);
                uint ins = INSTR.systemmove(1,INSTR.tpidr_el0,r);  // MRS r,tpidr_el0
                cdb.gen1(ins);

                ins = INSTR.adr(1,0,reg);                          // ADRP reg,0<foo>
                cdb.gencs1(ins,0,fl,e.Vsym);

                ins = INSTR.ldr_imm_gen(1,reg,reg,0);              // LDR  reg,[reg]
                cdb.gencs1(ins,0,fl,e.Vsym);
                cdb.last.Iflags |= CFadd;

                cdb.gen1(INSTR.addsub_shift(1,0,0,0,reg,0,r,reg)); // ADD reg,r,reg
                return;
            }
//            if (config.exe & EX_WIN64 && e.Vsym.ty() & mTYthread)
//                goto Lwin64;
            goto L4;

        case FL.data:
        case FL.udata:
        case FL.got:
        case FL.gotoff:
        case FL.csdata:
        L4:
            cs.IEV1.Vsym = e.Vsym;
            cs.IEV1.Voffset = e.Voffset;
        L3:
            if (reg == STACK)
            {   cgstate.stackchanged = 1;
                cs.Iop = 0x68;              /* PUSH immed16                 */
                cdb.genadjesp(REGSIZE);
                cs.IFL1 = fl;
                cdb.gen(&cs);
            }
            else
            {
                uint ins = INSTR.adr(1,0,reg);                // ADRP reg,0<foo>
                cdb.gencs1(ins,0,fl,e.Vsym);

                cs.Iop = INSTR.addsub_imm(1,0,0,0,0,reg,reg); // ADD reg,reg,#0
                cs.Iflags |= CFadd;
                cs.IFL1 = fl;
                cdb.gen(&cs);

                if (e.Voffset)
                    cdb.gen1(INSTR.addsub_imm(1,0,0,0,cast(uint)e.Voffset,reg,reg)); // ADD reg,reg,#Voffset
            }
            break;

        case FL.reg:
            /* Allow this since the tree optimizer puts & in front of       */
            /* register doubles.                                            */
            goto L2;
        case FL.auto_:
        case FL.fast:
        case FL.bprel:
        case FL.fltreg:
            cgstate.reflocal = true;
            goto L2;
        case FL.para:
            cgstate.refparam = true;
        L2:
            if (reg == STACK)
            {   regm_t retregs = ALLREGS;

                const regx = allocreg(cdb,retregs,TYoffset);
                reg = findreg(retregs);
                loadea(cdb,e,cs,LEA,reg,0,0,0);    // LEA reg,EA
                if (I64)
                    code_orrex(cdb.last(), REX_W);
                cdb.genpush(reg);               // PUSH reg
                cdb.genadjesp(REGSIZE);
                cgstate.stackchanged = 1;
            }
            else
            {
                uint sh = 0;
                uint base = 0;
                cs.Iop = INSTR.addsub_imm(1,0,0,sh,base,cgstate.BP,reg); // ADD reg,BP,base
                cs.IFL1 = fl;
                cs.IEV1.Vsym = e.Vsym;
                cs.IEV1.Voffset = 0;
                cdb.gen(&cs);
                cdb.gen1(INSTR.addsub_imm(1,0,0,sh,cast(uint)e.Voffset,reg,reg)); // ADD reg,reg,Voffset
                // TODO AArch64 common subexpressions?
                //loadea(cdb,e,cs,LEA,reg,0,0,0);   // LEA reg,EA
            }
            break;

        default:
            debug
            {
                elem_print(e);
                printf("e.fl = %s\n", fl_str(el_fl(e)));
            }
            assert(0);
    }
}

/******************
 * OPneg, not OPsqrt OPsin OPcos OPrint
 */

@trusted
void cdneg(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdneg()\n");
    //elem_print(e);
    if (pretregs == 0)
    {
        codelem(cgstate,cdb,e.E1,pretregs,false);
        return;
    }
    const tyml = tybasic(e.E1.Ety);
    const sz = _tysize[tyml];
    if (tyfloating(tyml))
    {
        regm_t retregs = pretregs & INSTR.FLOATREGS;
        if (retregs == 0)                   /* if no return regs speced     */
                                            /* (like if wanted flags only)  */
            retregs = INSTR.FLOATREGS;      // give us some
        codelem(cgstate,cdb,e.E1,retregs,false);
        getregs(cdb,retregs);               // retregs will be destroyed

        const Vn = findreg(retregs);

        if (sz == 16)                   // 128 bit float
        {
            /* Generate:
                FMOV Xn,Vn.d[1] // upper 64 bits
                EOR  Xn,Xn,#0x8000_0000_0000_0000  // toggle sign bit
                FMOV Vn.d[1],Xn // store upper 64 bits
             */
            // Alloc Xn
            regm_t retregsx = cg.allregs;
            const Xn = allocreg(cdb,retregsx,TYllong); // scratch register Xn
            // https://www.scs.stanford.edu/~zyedidia/arm64/fmov_float_gen.html
            cdb.gen1(INSTR.fmov_float_gen(1,2,1,6,Vn,Xn)); // Top half of 128-bit to 64-bit
            uint N, immr, imms;
            assert(encodeNImmrImms(0x8000_0000_0000_0000,N,immr,imms));
            uint sf = 1, opc = 2;
            cdb.gen1(INSTR.log_imm(sf,opc,N,immr,imms,Xn,Xn)); // https://www.scs.stanford.edu/~zyedidia/arm64/eor_log_imm.html
            cdb.gen1(INSTR.fmov_float_gen(1,2,1,7,Xn,Vn)); // 64-bit to top half of 128-bit
        }
        else
        {
            const ftype = INSTR.szToFtype(sz);
            cdb.gen1(INSTR.fneg_float(ftype, Vn, Vn));
        }
        fixresult(cdb,e,retregs,pretregs);
        return;
    }


    regm_t retregs = pretregs & cg.allregs;
    if (retregs == 0)                   // if no return regs speced
        retregs = cg.allregs;           // give us some
    codelem(cg,cdb,e.E1,retregs,false);
    getregs(cdb,retregs);               // retregs will be destroyed
    const Rm = findreg(retregs);

    /* NEG  https://www.scs.stanford.edu/~zyedidia/arm64/neg_sub_addsub_shift.html
     * NEGS https://www.scs.stanford.edu/~zyedidia/arm64/negs_subs_addsub_shift.html
     */

    uint sf = sz == 8;
    uint S = (pretregs & mPSW) != 0;  // NEG/NEGS
    cdb.gen1(INSTR.addsub_shift(sf,1,S,0,Rm,0,31,Rm)); // NEG/NEGS <Rm>,<Rm>

    pretregs &= ~mPSW;             // flags already set
    fixresult(cdb,e,retregs,pretregs);
}

/******************
 * Absolute value operator, OPabs
 */


@trusted
void cdabs(ref CGstate cg, ref CodeBuilder cdb,elem* e, ref regm_t pretregs)
{
    //printf("cdabs(e = %p, pretregs = %s)\n", e, regm_str(pretregs));
    if (pretregs == 0)
    {
        codelem(cgstate,cdb,e.E1,pretregs,false);
        return;
    }
    const tyml = tybasic(e.E1.Ety);
    const sz = _tysize[tyml];
    if (tyfloating(tyml))
    {
        regm_t retregs = pretregs & INSTR.FLOATREGS;
        if (retregs == 0)                   /* if no return regs speced     */
                                            /* (like if wanted flags only)  */
            retregs = INSTR.FLOATREGS;      // give us some
        codelem(cgstate,cdb,e.E1,retregs,false);
        getregs(cdb,retregs);               // retregs will be destroyed

        const Vn = findreg(retregs);

        if (sz == 16)                   // 128 bit float
        {
            /* Generate:
                FMOV Xn,Vn.d[1] // upper 64 bits
                AND  Xn,Xn,#0x7FFF_FFFF_FFFF_FFFF  // clear sign bit
                FMOV Vn.d[1],Xn // store upper 64 bits
             */
            // Alloc Xn
            regm_t retregsx = cg.allregs;
            const Xn = allocreg(cdb,retregsx,TYllong); // scratch register Xn
            // https://www.scs.stanford.edu/~zyedidia/arm64/fmov_float_gen.html
            cdb.gen1(INSTR.fmov_float_gen(1,2,1,6,Vn,Xn)); // Top half of 128-bit to 64-bit
            uint N, immr, imms;
            assert(encodeNImmrImms(0x7FFF_FFFF_FFFF_FFFF,N,immr,imms));
            uint sf = 1, opc = 0;
            cdb.gen1(INSTR.log_imm(sf,opc,N,immr,imms,Xn,Xn)); // https://www.scs.stanford.edu/~zyedidia/arm64/eor_log_imm.html
            cdb.gen1(INSTR.fmov_float_gen(1,2,1,7,Xn,Vn)); // 64-bit to top half of 128-bit
        }
        else
        {
            const ftype = INSTR.szToFtype(sz);
            cdb.gen1(INSTR.fabs_float(ftype, Vn, Vn));
        }
        fixresult(cdb,e,retregs,pretregs);
        return;
    }

    const posregs = cgstate.allregs;
    regm_t retregs1 = posregs;
    codelem(cgstate,cdb,e.E1,retregs1,false);

    regm_t retregs = pretregs & cg.allregs;
    if (retregs == 0)                   /* if no return regs speced     */
                                        /* (like if wanted flags only)  */
        retregs = ALLREGS & posregs;    // give us some
    reg_t Rd = allocreg(cdb, retregs, tyml);

    const Rn = findreg(retregs1);

    /* CMP https://www.scs.stanford.edu/~zyedidia/arm64/cmp_subs_addsub_imm.html
     * CMP Rn,0
     */

    uint sf = sz == 8;
    uint op = 1;
    uint S = 1;
    uint sh = 0;
    uint imm12 = 0;
    uint ins = (sf     << 31) |
               (op     << 30) |
               (S      << 29) |
               (0x22   << 23) |
               (sh     << 22) |
               (imm12  << 10) |
               (Rn     <<  5) |
                0x1F;
    cdb.gen1(ins);

    /* CNEG https://www.scs.stanford.edu/~zyedidia/arm64/cneg_csneg.html
     * CNEG Rd,Rn,lt
     */
    op = 1;
    S = 0;
    uint Rm = Rn;
    uint cond = 0xA ^ 1; // LT
    uint o2 = 1;
    ins = (sf     << 31) |
          (op     << 30) |
          (S      << 29) |
          (0xD4   << 21) |
          (Rm     << 16) |
          (cond   << 12) |
          (0      << 11) |
          (o2     << 10) |
          (Rn     <<  5) |
           Rd;
    cdb.gen1(ins);

    pretregs &= ~mPSW;             // flags already set
    fixresult(cdb,e,retregs,pretregs);
}

/**************************
 * Post increment and post decrement.
 * OPpostinc, OPpostdec
 */
@trusted
void cdpost(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdpost(pretregs = %s)\n", regm_str(pretregs));
    //elem_print(e);
    const op = e.Eoper;                      // OPxxxx
    if (pretregs == 0)                       // if nothing to return
    {
        cdaddass(cgstate,cdb,e,pretregs);
        return;
    }

    const tym_t tyml = tybasic(e.E1.Ety);
    if (tyfloating(tyml))
    {
        floatPost(cg, cdb, e, pretregs);
        return;
    }
    if (0 && tyxmmreg(tyml)) // TODO AArch64
    {
        xmmpost(cdb,e,pretregs);
        return;
    }

    const sz = _tysize[tyml];
    elem* e2 = e.E2;
    assert(e2.Eoper == OPconst);

    regm_t possregs = cg.allregs;
    code cs;
    getlvalue(cdb,cs,e.E1,0);
    freenode(e.E1);
    if (cs.reg != NOREG && pretregs == mPSW)
    {
        gentstreg(cdb,cs.reg,sz == 8);          // CMP cs.reg,#0

        // If lvalue is a register variable, we must mark it as modified
        getregs(cdb,cs.reg);

        const n = e2.Vint;
        uint opx = e.Eoper == OPpostinc ? 0 : 1;
        uint ins = INSTR.addsub_imm(sz == 8,opx,0,0,n,cs.reg,cs.reg); // ADD/SUB cs.reg,cs.reg,n);
        cdb.gen1(ins);
        freenode(e2);
        return;
    }
    else if (sz <= REGSIZE)
    {
        regm_t idxregs;         // mask of index regs used
        if (cs.base != NOREG)
            idxregs |= mask(cs.base);
        if (cs.index != NOREG)
            idxregs |= mask(cs.index);
        regm_t retregs = possregs & ~idxregs & pretregs;
        if (retregs == 0)
            retregs = possregs & ~idxregs;

        const reg = allocreg(cdb,retregs,TYint);

        loadFromEA(cs,reg,sz == 8 ? 8 : 4,sz);

        cdb.gen(&cs);                     // LDR reg,EA

        if (pretregs & mPSW)
        {
            gentstreg(cdb,reg,sz == 8);   // CMP reg,#0
            pretregs &= ~mPSW;
        }

        /* If lvalue is a register variable, we must mark it as modified */
        getregs(cdb,reg);

        const n = e2.Vint;
        uint opx = e.Eoper == OPpostinc ? 0 : 1;
        uint ins = INSTR.addsub_imm(sz == 8,opx,0,0,n,reg,reg); // ADD/SUB cs.reg,cs.reg,n);
        cdb.gen1(ins);

        storeToEA(cs,reg,sz);
        cdb.gen(&cs);                        // STR reg,EA

        opx ^= 1;
        cdb.gen1(INSTR.addsub_imm(sz == 8,opx,0,0,n,reg,reg)); // SUB/ADD cs.reg,cs.reg,n);

        freenode(e2);
        fixresult(cdb,e,retregs,pretregs);
        return;
    }
    else if (0 && sz == 2 * REGSIZE)
    {
    /+    regm_t retregs = cgstate.allregs & ~idxregs & pretregs;
        if ((retregs & INSTR.LSW) == 0)
                retregs |= INSTR.LSW & ~idxregs;
        if ((retregs & INSTR.MSW) == 0)
                retregs |= ALLREGS & INSTR.MSW;
        assert(retregs & INSTR.MSW && retregs & INSTR.LSW);
        const reg = allocreg(cdb,retregs,tyml);
        uint sreg = findreg(retregs & INSTR.LSW);
        cs.Iop = 0x8B;
        cs.Irm |= modregrm(0,sreg,0);
        cdb.gen(&cs);                   // MOV sreg,EA
        NEWREG(cs.Irm,reg);
        getlvalue_msw(cs);
        cdb.gen(&cs);                   // MOV reg,EA+2
        cs.Iop = 0x81;
        cs.Irm &= ~cast(int)modregrm(0,7,0);     /* reg field = 0 for ADD        */
        if (op == OPpostdec)
            cs.Irm |= modregrm(0,5,0);  /* SUB                          */
        getlvalue_lsw(cs);
        cs.IFL2 = FL.const_;
        cs.IEV2.Vlong = e2.Vlong;
        cdb.gen(&cs);                   // ADD/SUB EA,const
        code_orflag(cdb.last(),CFpsw);
        getlvalue_msw(cs);
        cs.IEV2.Vlong = 0;
        if (op == OPpostinc)
            cs.Irm ^= modregrm(0,2,0);  /* ADC                          */
        else
            cs.Irm ^= modregrm(0,6,0);  /* SBB                          */
        cs.IEV2.Vlong = cast(targ_long)(e2.Vullong >> (REGSIZE * 8));
        cdb.gen(&cs);                   // ADC/SBB EA,0
        freenode(e2);
        fixresult(cdb,e,retregs,pretregs);
        return;
     +/
    }
    else
    {
        assert(0);
    }
}

/******************************
 * Do OPpostinc and OPpostdec on floating point lvalue
 */
@trusted
void floatPost(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("floatPost(pretregs = %s)\n", regm_str(pretregs));
    //elem_print(e);

    // Much similarity to xmmpost()

    elem* e1 = e.E1;
    elem* e2 = e.E2;
    const tym_t ty1 = tybasic(e.E1.Ety);
    const sz = _tysize[ty1];
    assert(sz <= 8);            // TODO AArch64 16 byte floats
    const ftype = INSTR.szToFtype(sz);

    regm_t retregs;
    reg_t reg;
    bool regvar = false;
    if (config.flags4 & CFG4optimized)
    {
        // Be careful of cases like (x = x+x+x). We cannot evaluate in
        // x if x is in a register.
        reg_t varreg;
        regm_t varregm;
        if (isregvar(e1,varregm,varreg) &&    // if lvalue is register variable
            doinreg(e1.Vsym,e2)         // and we can compute directly into it
           )
        {
            regvar = true;
            retregs = varregm;
            reg = varreg;               // evaluate directly in target register
            getregs(cdb,retregs);       // destroy these regs
        }
    }

    code cs;
    if (!regvar)
    {
        getlvalue(cdb,cs,e1,0,RM.rw);                // get EA
        retregs = INSTR.FLOATREGS & ~pretregs;
        if (!retregs)
            retregs = INSTR.FLOATREGS;
        reg = allocreg(cdb,retregs,ty1);
        loadFromEA(cs,reg,sz == 8 ? 8 : 4,sz);
        cdb.gen(&cs);
    }

    if (regvar && pretregs == mPSW)
    {
        tstresult(cdb, mask(reg),ty1,false);

        // If lvalue is a register variable, mark it as modified
        getregs(cdb,reg);

        regm_t vretregs = INSTR.FLOATREGS & ~mask(cs.reg);
        reg_t vreg = allocreg(cdb,vretregs,ty1);
        double value = sz == 8 ? e2.Vdouble : e2.Vfloat;
        uint opx = e.Eoper == OPpostinc ? 0 : 1;
        loadFloatRegConst(cdb,vreg,value,sz);                   // FMOV vreg,value

        switch (e.Eoper)
        {
            case OPpostinc:
                cdb.gen1(INSTR.fadd_float(ftype,vreg,reg,reg)); // FADD Rd,Rn,Rm
                break;

            case OPpostdec:
                cdb.gen1(INSTR.fsub_float(ftype,vreg,reg,reg)); // FSUB Rd,Rn,Rm
                break;

            default:
                assert(0);
        }

        freenode(e2);
        return;
    }

    // Result register
    regm_t resultregs = INSTR.FLOATREGS & pretregs & ~retregs;
    if (!resultregs)
        resultregs = INSTR.FLOATREGS & ~retregs;
    const resultreg = allocreg(cdb,resultregs, ty1);

    cdb.gen1(INSTR.fmov(ftype,reg,resultreg));  // FMOV resultreg,reg

    regm_t vretregs = INSTR.FLOATREGS & ~mask(reg) & ~mask(resultreg);
    reg_t vreg = allocreg(cdb,vretregs,ty1);
    double value = sz == 8 ? e2.Vdouble : e2.Vfloat;
    loadFloatRegConst(cdb,vreg,value,sz);       // FMOV vreg,value

    switch (e.Eoper)
    {
        case OPpostinc:
            cdb.gen1(INSTR.fadd_float(ftype,vreg,reg,reg)); // FADD Rd,Rn,Rm
            break;

        case OPpostdec:
            cdb.gen1(INSTR.fsub_float(ftype,vreg,reg,reg)); // FSUB Rd,Rn,Rm
            break;

        default:
            assert(0);
    }

    if (!regvar)
    {
        storeToEA(cs,reg,sz);
        cdb.gen(&cs);                         // STR reg,EA
    }

    if (e1.Ecount ||                          // if lvalue is a CSE or
        regvar)                               // rvalue can't be a CSE
    {
        getregs_imm(cdb,retregs);             // necessary if both lvalue and
                                              //  rvalue are CSEs (since a reg
                                              //  can hold only one e at a time)
        cssave(e1,retregs,!OTleaf(e1.Eoper)); // if lvalue is a CSE
    }

    fixresult(cdb,e,resultregs,pretregs);
    freenode(e1);
}

// cddctor
// cdddtor

/*****************************************
 */

@trusted
void cdhalt(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    assert(pretregs == 0);

    // https://www.scs.stanford.edu/~zyedidia/arm64/hlt.html
    uint imm16 = 0;
    uint ins = (0xD4  << 24) |
               (2     << 21) |
               (imm16 <<  5) |
               (0     <<  1) |
                0;
    cdb.gen1(ins);
}
