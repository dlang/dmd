/**
 * Code generation 1
 *
 * Handles function calls: putting arguments in registers / on the stack, and jumping to the function.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/arm/cod1.d, backend/cod1.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_arm_cod1.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/arm/cod1.d
 */

module dmd.backend.arm.cod1;

import core.bitop;
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
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.rtlsym;
import dmd.backend.ty;
import dmd.backend.type;
import dmd.backend.arm.cod3 : COND, genBranch, conditionCode, gentstreg;
import dmd.backend.arm.instr;
import dmd.backend.x86.cod1 : cdisscaledindex, ssindex_array;

import dmd.backend.cg : segfl, stackfl;

nothrow:
@safe:

/************************************
 * Given cs which has the Effective Address encoded into it,
 * create a load instruction to reg, and write it to cs.Iop
 * Params:
 *      cs = EA information
 *      reg = destination register
 *      szw = number of bytes to write - 4,8
 *      szr = number of bytes to read - 1,2,4,8
 */
void loadFromEA(ref code cs, reg_t reg, uint szw, uint szr)
{
    if (cs.reg != NOREG)
    {
        if (cs.reg != reg)  // do not mov onto itself
            cs.Iop = INSTR.mov_register(szw == 8,cs.reg,reg);  // MOV reg,cs.reg
        cs.IFL1 = FLunde;
    }
    else if (cs.index != NOREG)
    {
        // LDRB/LDRH/LDR reg,[cs.base,cs.index,extend S]
        if (szr == 1)
            cs.Iop = INSTR.ldrb_reg(szw == 8, cs.index, cs.Sextend & 7, cs.Sextend >> 3, cs.base, reg);
        else if (szr == 2)
            cs.Iop = INSTR.ldrh_reg(szw == 8, cs.index, cs.Sextend & 7, cs.Sextend >> 3, cs.base, reg);
        else
            cs.Iop = INSTR.ldr_reg_gen(szw == 8, cs.index, cs.Sextend & 7, cs.Sextend >> 3, cs.base, reg);
    }
    else if (cs.base != NOREG)
    {
        // LDRB/LDRH/LDR reg,[cs.base, #0]
        if (szr == 1)
            cs.Iop = INSTR.ldrb_imm(szw == 8, reg, cs.base, 0);
        else if (szr == 2)
            cs.Iop = INSTR.ldrh_imm(szw == 8, reg, cs.base, 0);
        else
            cs.Iop = INSTR.ldr_imm_gen(szw == 8, reg, cs.base, 0);
    }
    else
        assert(0);
}
/************************************
 * Given cs which has the Effective Address encoded into it,
 * create a store instruction to reg, and write it to cs.Iop
 * Params:
 *      cs = EA information
 *      reg = source register
 *      sz = number of bytes to store - 1,2,4,8
 */
void storeToEA(ref code cs, reg_t reg, uint sz)
{
    if (cs.reg != NOREG)
    {
        if (cs.reg != reg)  // do not mov onto itself
            cs.Iop = INSTR.mov_register(sz == 8,reg,cs.reg);  // MOV cs.reg,reg
        cs.IFL1 = FLunde;
    }
    else if (cs.index != NOREG)
    {
        // STRB/STRH/STR reg,[cs.base,cs.index,extend S]
        if (sz == 1)
            cs.Iop = INSTR.strb_reg(cs.index, cs.Sextend & 7, cs.Sextend >> 3, cs.base, reg);
        else if (sz == 2)
            cs.Iop = INSTR.strh_reg(cs.index, cs.Sextend & 7, cs.Sextend >> 3, cs.base, reg);
        else
            cs.Iop = INSTR.str_reg_gen(sz == 8, cs.index, cs.Sextend & 7, cs.Sextend >> 3, cs.base, reg);
    }
    else if (cs.base != NOREG)
    {
        // STRB/STRH/STR reg,[cs.base, #0]
        if (sz == 1)
            cs.Iop = INSTR.strb_imm(reg, cs.base, 0);
        else if (sz == 2)
            cs.Iop = INSTR.strh_imm(reg, cs.base, 0);
        else
            cs.Iop = INSTR.str_imm_gen(sz == 8, reg, cs.base, 0);
    }
    else
        assert(0);
}

/**************************
 * Determine if e is a scaled index addressing mode.
 *
 * size S extend
 * 0    0 UXTW      *(int*)((char*)p + u);
 * 0    0 LSL       *(int*)((char*)p + l)
 * 0    0 SXTW      *(int*)((char*)p + i);
 * 0    0 SXTX
 * 0    1 UXTW #2   *(int*)((char*)p + u*4)
 * 0    1 LSL  #2   *(int*)((char*)p + l*4)
 * 0    1 SXTW #2   *(int*)((char*)p + i*4)
 * 0    1 SXTX #2
 * 1    0 UXTW      *(long*)((char*)p + u)
 * 1    0 LSL       *(long*)((char*)p + l)
 * 1    0 SXTW      *(long*)((char*)p + i)
 * 1    0 SXTX
 * 1    1 UXTW #3   *(long*)((char*)p + u*8)
 * 1    1 LSL  #3   *(long*)((char*)p + l*8)
 * 1    1 SXTW #3   *(long*)((char*)p + i*8)
 * 1    1 SXTX #3
 * Or:
 *      SXTB unsigned = FALSE; len = 8;
 *      SXTH unsigned = FALSE; len = 16;
 *      SXTW unsigned = FALSE; len = 32;
 *      SXTX unsigned = FALSE; len = 64;
 *      UXTB unsigned = TRUE;  len = 8;
 *      UXTH unsigned = TRUE;  len = 16;
 *      UXTW unsigned = TRUE;  len = 32;
 *      UXTX unsigned = TRUE;  len = 64;
 * References:
 *      https://stackoverflow.com/questions/72041372/what-do-the-uxtx-and-sxtx-extensions-mean-for-32-bit-aarch64-adds-instruct
 *      https://www.scs.stanford.edu/~zyedidia/arm64/ldr_reg_gen.html
 *      https://www.scs.stanford.edu/~zyedidia/arm64/shared_pseudocode.html#impl-aarch64.ExtendReg.4
 * Returns:
 *      0       not a scaled index addressing mode
 *      !=0     the scaling shift count
 */

@trusted
int isscaledindex(tym_t ty, elem *e)
{
    const size = tysize(ty);    // size of load
    if (size != 4 && size != 8)
        return 0;

    uint S;
    uint option;
    e = *el_scancommas(&e);
    if (e.Eoper == OPshl &&
        !e.Ecount &&
        e.E2.Eoper == OPconst)
    {
        const shift = e.E2.Vuns;
        if (shift == 2 && size == 4 ||
            shift == 3 && size == 8)
        {
            const tym = e.E1.Ety;
            const sz = tysize(tym);
            const uns = tyuns(tym);
            S = 1;
            if (sz == 4)
                option = uns ? Extend.UXTW : Extend.SXTW;
            else if (sz == 8)
                option = Extend.LSL;
            else
                return 0;
            return (S << 3) | option;
        }
        return 0;
    }
    else
    {
        const tym = e.Ety;
        const sz = tysize(tym);
        const uns = tyuns(tym);
        S = 0;
        if (sz == 4)
            option = uns ? Extend.UXTW : Extend.SXTW;
        else if (sz == 8)
            option = Extend.LSL;
        else
            return 0;
        return (S << 3) | option;
    }
}


// void genEEcode
// uint gensaverestore
// void genstackclean

/*********************************
 * Generate code for a logical expression.
 * Input:
 *      e       elem
 *      jcond
 *         bit 1 if true then goto jump address if e
 *               if false then goto jump address if !e
 *         2    don't call save87()
 *      fltarg   FLcode or FLblock, flavor of target if e evaluates to jcond
 *      targ    either code or block pointer to destination
 */

@trusted
void logexp(ref CodeBuilder cdb, elem *e, uint jcond, uint fltarg, code *targ)
{
    //printf("logexp(e = %p, jcond = %d)\n", e, jcond); elem_print(e);
    if (tybasic(e.Ety) == TYnoreturn)
    {
        con_t regconsave = cgstate.regcon;
        regm_t retregs = 0;
        codelem(cgstate,cdb,e,retregs,0);
        regconsave.used |= cgstate.regcon.used;
        cgstate.regcon = regconsave;
        return;
    }

    int no87 = 1;
    docommas(cdb, e);             // scan down commas
    cgstate.stackclean++;

    if (!OTleaf(e.Eoper) && !e.Ecount)     // if operator and not common sub
    {
        switch (e.Eoper)
        {
            case OPoror:
            {
                con_t regconsave;
                if (jcond & 1)
                {
                    logexp(cdb, e.E1, jcond, fltarg, targ);
                    regconsave = cgstate.regcon;
                    logexp(cdb, e.E2, jcond, fltarg, targ);
                }
                else
                {
                    code *cnop = gen1(null, INSTR.nop);
                    logexp(cdb, e.E1, jcond | 1, FLcode, cnop);
                    regconsave = cgstate.regcon;
                    logexp(cdb, e.E2, jcond, fltarg, targ);
                    cdb.append(cnop);
                }
                andregcon(regconsave);
                freenode(e);
                cgstate.stackclean--;
                return;
            }

            case OPandand:
            {
                con_t regconsave;
                if (jcond & 1)
                {
                    code *cnop = gen1(null, INSTR.nop);    // a dummy target address
                    logexp(cdb, e.E1, jcond & ~1, FLcode, cnop);
                    regconsave = cgstate.regcon;
                    logexp(cdb, e.E2, jcond, fltarg, targ);
                    cdb.append(cnop);
                }
                else
                {
                    logexp(cdb, e.E1, jcond, fltarg, targ);
                    regconsave = cgstate.regcon;
                    logexp(cdb, e.E2, jcond, fltarg, targ);
                }
                andregcon(regconsave);
                freenode(e);
                cgstate.stackclean--;
                return;
            }

            case OPnot:
                jcond ^= 1;
                goto case OPbool;

            case OPbool:
            case OPs8_16:
            case OPu8_16:
            case OPs16_32:
            case OPu16_32:
            case OPs32_64:
            case OPu32_64:
            case OPu32_d:
            case OPd_ld:
                logexp(cdb, e.E1, jcond, fltarg, targ);
                freenode(e);
                cgstate.stackclean--;
                return;

            case OPcond:
            {
                code *cnop2 = gen1(null, INSTR.nop);   // addresses of start of leaves
                code *cnop = gen1(null, INSTR.nop);
                logexp(cdb, e.E1, false, FLcode, cnop2);   // eval condition
                con_t regconold = cgstate.regcon;
                logexp(cdb, e.E2.E1, jcond, fltarg, targ);
                genBranch(cdb, COND.al, FLcode, cast(block *) cnop); // skip second leaf

                con_t regconsave = cgstate.regcon;
                cgstate.regcon = regconold;

                cdb.append(cnop2);
                logexp(cdb, e.E2.E2, jcond, fltarg, targ);
                andregcon(regconold);
                andregcon(regconsave);
                freenode(e.E2);
                freenode(e);
                cdb.append(cnop);
                cgstate.stackclean--;
                return;
            }

            default:
                break;
        }
    }

    /* Special code for signed long compare.
     * Not necessary for I64 until we do cents.
     */
    static if (0)
    if (OTrel2(e.Eoper) &&               // if < <= >= >
        !e.Ecount &&
        ( (I16 && tybasic(e.E1.Ety) == TYlong  && tybasic(e.E2.Ety) == TYlong) ||
          (I32 && tybasic(e.E1.Ety) == TYllong && tybasic(e.E2.Ety) == TYllong))
       )
    {
        longcmp(cdb, e, jcond != 0, fltarg, targ);
        cgstate.stackclean--;
        return;
    }

    regm_t retregs = mPSW;                // return result in flags
    COND cond = conditionCode(e);         // get jump opcode
    if (!(jcond & 1))
        cond ^= 1;                      // toggle jump condition(s)
    codelem(cgstate,cdb, e, retregs, true);         // evaluate elem
    if (no87)
        cse_flush(cdb,no87);              // flush CSE's to memory
    genBranch(cdb, cond, fltarg, cast(block *) targ); // generate jmp instruction
    cgstate.stackclean--;
}

/******************************
 * Routine to aid in setting things up for gen().
 * Look for common subexpression.
 * Can handle indirection operators, but not if they are common subs.
 * Params:
 *      cdb     = generated code sink
 *      e       = elem where we get some of the data from
 *      cs      = partially filled code to add
 *      op      = opcode
 *      reg     = destination register
 *      offset  = data to be added to Voffset field
 *      keepmsk = mask of registers we must not destroy
 *      desmsk  = mask of registers destroyed by executing the instruction
 *      rmx     = RM.load/store
 */

@trusted
void loadea(ref CodeBuilder cdb,elem *e,ref code cs,uint op,reg_t reg,targ_size_t offset,
            regm_t keepmsk,regm_t desmsk, RM rmx = RM.rw)
{
    code* c, cg, cd;

    debug
    if (debugw)
        printf("loadea: e=%p cs=%p op=x%x reg=%s offset=%lld keepmsk=%s desmsk=%s\n",
               e, &cs, op, regstring[reg], cast(ulong)offset, regm_str(keepmsk), regm_str(desmsk));
    assert(e);
    cs.Iflags = 0;
    cs.Iop = op;
    tym_t tym = e.Ety;
    int sz = tysize(tym);

    /* Determine if location we want to get is in a register. If so,      */
    /* substitute the register for the EA.                                */
    /* Note that operators don't go through this. CSE'd operators are     */
    /* picked up by comsub().                                             */
    if (e.Ecount &&                      /* if cse                        */
        e.Ecount != e.Ecomsub)           /* and cse was generated         */
    {
        assert(OTleaf(e.Eoper));         /* can't handle operands         */
        regm_t rm = cgstate.regcon.cse.mval & ~cgstate.regcon.cse.mops & ~cgstate.regcon.mvar; // possible regs
        if (sz == REGSIZE * 2)          // value is in 2 registers
        {
            if (offset)
                rm &= mMSW;             /* only high words      */
            else
                rm &= mLSW;             /* only low words       */
        }
        for (uint i = 0; rm; i++)
        {
            if (mask(i) & rm)
            {
                if (cgstate.regcon.cse.value[i] == e) // if register has elem
                {
                    getregs(cdb, desmsk);
                    if (i != reg)
                        cdb.gen1(INSTR.mov_register(sz == 8,cast(reg_t)i,reg));  // MOV reg,i
                    return;
                }
                rm &= ~mask(i);
            }
        }
    }

    getlvalue(cdb, cs, e, keepmsk, rmx);
    cs.IEV1.Voffset += offset;

    loadFromEA(cs,reg,sz == 8 ? 8 : 4,sz);

    getregs(cdb, desmsk);                  // save any regs we destroy
    cdb.gen(&cs);
}

// uint getaddrmode
// void setaddrmode
// getlvalue_msw
// getlvalue_lsw

/******************
 * Compute Effective Address (EA).
 * Set in pcs the EA info. The EA addressing modes are:
 *      1. reg - (not NOREG)
 *      2. [base + offset] - (not NOREG), IFL1, IEV1.Vsymbol and IEV1.Voffset
 *      3. [base + index*size] - (base and index are not NOREG)
 * Generate to cdb any code needed
 * Params:
 *      cdb = sink for any code generated
 *      pcs = set to addressing mode
 *      e   = the lvalue elem
 *      keepmsk = mask of registers we must not destroy or use
 *      rm = RM.store a store operation into the lvalue only
 *           RM.load a read operation from the lvalue only
 *           RM.rw load and store
 * References:
 *      addressing modes https://devblogs.microsoft.com/oldnewthing/20220728-00/?p=106912
 */

@trusted
void getlvalue(ref CodeBuilder cdb,ref code pcs,elem *e,regm_t keepmsk,RM rm = RM.rw)
{
    FL fl;
    uint opsave;
    elem* e1, e11, e12;
    bool e1isadd, e1free;
    reg_t reg;
    tym_t e1ty;
    Symbol* s;

    //printf("getlvalue(e = %p, keepmsk = %s)\n", e, regm_str(keepmsk));
    //elem_print(e);
    assert(e);
    elem_debug(e);
    if (e.Eoper == OPvar || e.Eoper == OPrelconst)
    {
        s = e.Vsym;
        fl = s.Sfl;
        if (tyfloating(s.ty()))
            objmod.fltused();
        //symbol_print(*s);
    }
    else
        fl = FLoper;
    enum BP = 29;
    enum SP = 31;
    pcs.IFL1 = cast(ubyte)fl;
    pcs.Iflags = CFoff;                  /* only want offsets            */
    pcs.reg = NOREG;
    pcs.base = NOREG;
    pcs.index = NOREG;
    pcs.Sextend = 0;
    pcs.IEV1.Vsym = null;
    pcs.IEV1.Voffset = 0;

    tym_t ty = e.Ety;
    uint sz = tysize(ty);
    if (tyfloating(ty))
        objmod.fltused();
    if (ty & mTYvolatile)
        pcs.Iflags |= CFvolatile;

    void Lptr(){
        if (config.flags3 & CFG3ptrchk)
            cod3_ptrchk(cdb, pcs, keepmsk);        // validate pointer code
    }

    //printf("fl: %s\n", fl_str(fl));
    switch (fl)
    {
        case FLoper:
            debug
            if (debugw) printf("getlvalue(e = %p, keepmsk = %s)\n", e, regm_str(keepmsk));

            switch (e.Eoper)
            {
                case OPadd:                 // this way when we want to do LEA
                    e1 = e;
                    e1free = false;
                    e1isadd = true;
                    break;

                case OPind:
                case OPpostinc:             // when doing (*p++ = ...)
                case OPpostdec:             // when doing (*p-- = ...)
                case OPbt:
                case OPbtc:
                case OPbtr:
                case OPbts:
                case OPvecfill:
                    e1 = e.E1;
                    e1free = true;
                    e1isadd = e1.Eoper == OPadd;
                    break;

                default:
                    printf("function: %s\n", funcsym_p.Sident.ptr);
                    elem_print(e);
                    assert(0);
            }
            e1ty = tybasic(e1.Ety);
            if (e1isadd)
            {
                e12 = e1.E2;
                e11 = e1.E1;
            }

            /* First see if we can replace *(e+&v) with
             *      MOV     idxreg,e
             *      EA =    [ES:] &v+idxreg
             */
            FL f = FLconst;

            /* Is address of `s` relative to RIP ?
             */
            static bool relativeToRIP(Symbol* s)
            {
                if (config.exe == EX_WIN64)
                    return true;
                if (config.flags3 & CFG3pie)
                {
                    if (s.Sfl == FLtlsdata || s.ty() & mTYthread)
                    {
                        if (s.Sclass == SC.global || s.Sclass == SC.static_ || s.Sclass == SC.locstat)
                            return false;
                    }
                    return true;
                }
                else
                    return (config.flags3 & CFG3pic) != 0;
            }

            if (0 && e1isadd &&
                ((e12.Eoper == OPrelconst &&
                  !relativeToRIP(e12.Vsym)
                 ) ||
                 (e12.Eoper == OPconst && !e1.Ecount && el_signx32(e12))) &&
                e1.Ecount == e1.Ecomsub &&
                (!e1.Ecount || (~keepmsk & ALLREGS & mMSW)) &&
                tysize(e11.Ety) == REGSIZE
               )
            {
                f = el_fl(e12);
                uint t;            /* component of r/m field */
                int ss;
                int ssi;

                if (e12.Eoper == OPrelconst)
                    f = el_fl(e12);
                /*assert(datafl[f]);*/              /* what if addr of func? */
                /* Any register can be an index register        */
                regm_t idxregs = cgstate.allregs & ~keepmsk;
                assert(idxregs);

                /* See if e1.E1 can be a scaled index  */
                ss = isscaledindex(ty, e11);
                if (ss)
                {
                    /* Load index register with result of e11.E1       */
                    cdisscaledindex(cdb, e11, idxregs, keepmsk);
                    reg = findreg(idxregs);
                    {
                        t = stackfl[f] ? 2 : 0;
                        pcs.Irm = modregrm(t, 0, 4);
                        pcs.Isib = modregrm(ss, reg & 7, 5);
                        if (reg & 8)
                            pcs.Irex |= REX_X;
                    }
                }
                else if ((e11.Eoper == OPmul || e11.Eoper == OPshl) &&
                         !e11.Ecount &&
                         e11.E2.Eoper == OPconst &&
                         (ssi = ssindex(e11.Eoper, e11.E2.Vuns)) != 0
                        )
                {
                    regm_t scratchm;

                    char ssflags = ssindex_array[ssi].ssflags;
                    if (ssflags & SSFLnobp && stackfl[f])
                        goto L6;

                    // Load index register with result of e11.E1
                    scodelem(cgstate,cdb, e11.E1, idxregs, keepmsk, true);
                    reg = findreg(idxregs);

                    int ss1 = ssindex_array[ssi].ss1;
                    if (ssflags & SSFLlea)
                    {
                        assert(!stackfl[f]);
                        pcs.Irm = modregrm(2,0,4);
                        pcs.Isib = modregrm(ss1, reg & 7, reg & 7);
                        if (reg & 8)
                            pcs.Irex |= REX_X | REX_B;
                    }
                    else
                    {
                        int rbase;

                        scratchm = ALLREGS & ~keepmsk;
                        const r = allocreg(cdb, scratchm, TYint);

                        if (ssflags & SSFLnobase1)
                        {
                            t = 0;
                            rbase = 5;
                        }
                        else
                        {
                            t = 0;
                            rbase = reg;
                        }

                        cdb.gen2sib(LEA, modregxrm(t, r, 4), modregrm(ss1, reg & 7 ,rbase & 7));
                        if (reg & 8)
                            code_orrex(cdb.last(), REX_X);
                        if (rbase & 8)
                            code_orrex(cdb.last(), REX_B);
                        code_orrex(cdb.last(), REX_W);

                        if (ssflags & SSFLnobase1)
                        {
                            cdb.last().IFL1 = FLconst;
                            cdb.last().IEV1.Vuns = 0;
                        }

                        if (ssflags & SSFLnobase)
                        {
                            t = stackfl[f] ? 2 : 0;
                            rbase = 5;
                        }
                        else
                        {
                            t = 2;
                            rbase = r;
                            assert(rbase != BP);
                        }
                        pcs.Irm = modregrm(t, 0, 4);
                        pcs.Isib = modregrm(ssindex_array[ssi].ss2, r & 7, rbase & 7);
                        if (r & 8)
                            pcs.Irex |= REX_X;
                        if (rbase & 8)
                            pcs.Irex |= REX_B;
                    }
                    freenode(e11.E2);
                    freenode(e11);
                }
                else
                {
                 L6:
                    /* Load index register with result of e11   */
                    scodelem(cgstate,cdb, e11, idxregs, keepmsk, true);
                    setaddrmode(pcs, idxregs);
                    if (stackfl[f])             /* if we need [EBP] too */
                    {
                        uint idx = pcs.Irm & 7;
                        if (pcs.Irex & REX_B)
                            pcs.Irex = (pcs.Irex & ~REX_B) | REX_X;
                        pcs.Isib = modregrm(0, idx, BP);
                        pcs.Irm = modregrm(2, 0, 4);
                    }
                }

                if (f == FLpara)
                    cgstate.refparam = true;
                else if (f == FLauto || f == FLbprel || f == FLfltreg || f == FLfast)
                    cgstate.reflocal = true;
                else
                    assert(f != FLreg);
                pcs.IFL1 = cast(ubyte)f;
                if (f != FLconst)
                    pcs.IEV1.Vsym = e12.Vsym;
                pcs.IEV1.Voffset = e12.Voffset; /* += ??? */

                /* If e1 is a CSE, we must generate an addressing mode      */
                /* but also leave EA in registers so others can use it      */
                if (e1.Ecount)
                {
                    regm_t regs = IDXREGS & ~keepmsk;
                    reg = allocreg(cdb, regs, TYoffset);

                    opsave = pcs.Iop;
                    const flagsave = pcs.Iflags;
                    ubyte rexsave = pcs.Irex;
                    pcs.Iop = LEA;
                    code_newreg(&pcs, reg);
                    pcs.Iflags &= ~CFopsize;
                    pcs.Irex |= REX_W;
                    cdb.gen(&pcs);                 // LEA reg,EA
                    cssave(e1,regs,true);
                    pcs.Iflags = flagsave;
                    pcs.Irex = rexsave;
                    pcs.Iop = opsave;
                    pcs.IFL1 = FLoffset;
                    pcs.IEV1.Vuns = 0;
                    setaddrmode(pcs, regs);
                }
                freenode(e12);
                if (e1free)
                    freenode(e1);
                return Lptr();
            }

            regm_t idxregs;
            idxregs = cgstate.allregs & ~keepmsk; // only these can be index regs
            assert(idxregs);
            if ((sz == REGSIZE || sz == 4) &&
                rm == RM.store)
                idxregs |= cgstate.regcon.mvar;

            pcs.IFL1 = FLoffset;
            pcs.IEV1.Vuns = 0;

            /* see if we can replace *(e+c) with
             *      MOV     idxreg,e
             *      EA =    c[idxreg]
             */
            if (0 && e1isadd &&
                e12.Eoper == OPconst &&
                (el_signx32(e12)) &&
                (tysize(e12.Ety) == REGSIZE || (tysize(e12.Ety) == 4)) &&
                (!e1.Ecount || !e1free)
               )
            {
                int ss;

                pcs.IEV1.Vuns = e12.Vuns;
                freenode(e12);
                if (e1free) freenode(e1);
                if (e11.Eoper == OPadd && !e11.Ecount &&
                    tysize(e11.Ety) == REGSIZE)
                {
                    e12 = e11.E2;
                    e11 = e11.E1;
                    e1 = e1.E1;
                    e1free = true;
                    goto L4;
                }
                if ((ss = isscaledindex(ty, e11)) != 0)
                {   // (v * scale) + const
                    cdisscaledindex(cdb, e11, idxregs, keepmsk);
                    reg = findreg(idxregs);
                    pcs.Irm = modregrm(0, 0, 4);
                    pcs.Isib = modregrm(ss, reg & 7, 5);
                    if (reg & 8)
                        pcs.Irex |= REX_X;
                }
                else
                {
                    scodelem(cgstate,cdb, e11, idxregs, keepmsk, true); // load index reg
                    setaddrmode(pcs, idxregs);
                }
                return Lptr();
            }

            /* Look for *(v1 + v2)
             *      EA = [v1][v2]
             */

            if (0 && e1isadd && (!e1.Ecount || !e1free) &&
                (_tysize[e1ty] == REGSIZE || (I64 && _tysize[e1ty] == 4)))
            {
            L4:
                regm_t idxregs2;
                uint base, index;

                // Look for *(v1 + v2 << scale)
                int ss = isscaledindex(ty, e12);
                if (ss)
                {
                    scodelem(cgstate,cdb, e11, idxregs, keepmsk, true);
                    idxregs2 = cgstate.allregs & ~(idxregs | keepmsk);
                    cdisscaledindex(cdb, e12, idxregs2, keepmsk | idxregs);
                }

                // Look for *(v1 << scale + v2)
                else if ((ss = isscaledindex(ty, e11)) != 0)
                {
                    idxregs2 = idxregs;
                    cdisscaledindex(cdb, e11, idxregs2, keepmsk);
                    idxregs = cgstate.allregs & ~(idxregs2 | keepmsk);
                    scodelem(cgstate,cdb, e12, idxregs, keepmsk | idxregs2, true);
                }
                // Look for *(((v1 << scale) + c1) + v2)
                else if (e11.Eoper == OPadd && !e11.Ecount &&
                         e11.E2.Eoper == OPconst &&
                         (ss = isscaledindex(ty, e11.E1)) != 0
                        )
                {
                    pcs.IEV1.Vuns = e11.E2.Vuns;
                    idxregs2 = idxregs;
                    cdisscaledindex(cdb, e11.E1, idxregs2, keepmsk);
                    idxregs = cgstate.allregs & ~(idxregs2 | keepmsk);
                    scodelem(cgstate,cdb, e12, idxregs, keepmsk | idxregs2, true);
                    freenode(e11.E2);
                    freenode(e11);
                }
                else
                {
                    scodelem(cgstate,cdb, e11, idxregs, keepmsk, true);
                    idxregs2 = cgstate.allregs & ~(idxregs | keepmsk);
                    scodelem(cgstate,cdb, e12, idxregs2, keepmsk | idxregs, true);
                }
                base = findreg(idxregs);
                index = findreg(idxregs2);
                pcs.Irm  = modregrm(2, 0, 4);
                pcs.Isib = modregrm(ss, index & 7, base & 7);
                if (index & 8)
                    pcs.Irex |= REX_X;
                if (base & 8)
                    pcs.Irex |= REX_B;
                if (e1free)
                    freenode(e1);

                return Lptr();
            }

            /* give up and replace *e1 with
             *      MOV     idxreg,e
             *      EA =    0[idxreg]
             * pinholeopt() will usually correct the 0, we need it in case
             * we have a pointer to a long and need an offset to the second
             * word.
             */
            assert(e1free);
            scodelem(cgstate,cdb, e1, idxregs, keepmsk, true);  // load index register
            pcs.base = findreg(idxregs);

            return Lptr();

        case FLdatseg:
            assert(0);

        static if (0)
        {
            pcs.base = BP;
            pcs.IEVpointer1 = e.EVpointer;
            break;
        }

        case FLfltreg:
            cgstate.reflocal = true;
            pcs.base = BP;
            break;

        case FLreg:
            goto L2;

        case FLpara:
            if (s.Sclass == SC.shadowreg)
                goto case FLfast;
        Lpara:
            cgstate.refparam = true;
            pcs.base = BP;
            goto L2;

        case FLauto:
        case FLfast:
            if (regParamInPreg(*s))
            {
//printf("regParamInPreg()\n");
                regm_t pregm = s.Spregm();
                /* See if the parameter is still hanging about in a register,
                 * and so can we load from that register instead.
                 */
                if (cgstate.regcon.params & pregm /*&& s.Spreg2 == NOREG && !(pregm & XMMREGS)*/)
                {
                    if (/*rm == RM.load &&*/ !cgstate.anyiasm)
                    {
                        auto voffset = e.Voffset;
                        if (sz <= REGSIZE)
                        {
                            const reg_t preg = (voffset >= REGSIZE) ? s.Spreg2 : s.Spreg;
                            if (voffset >= REGSIZE)
                                voffset -= REGSIZE;

                            /* preg could be NOREG if it's a variadic function and we're
                             * in Win64 shadow regs and we're offsetting to get to the start
                             * of the variadic args.
                             */
                            if (preg != NOREG && cgstate.regcon.params & mask(preg))
                            {
                                //printf("sz %d, preg %s, Voffset %d\n", cast(int)sz, regm_str(mask(preg)), cast(int)voffset);
                                if (mask(preg) & XMMREGS)
                                {
                                    /* The following fails with this from std.math on Linux64:
                                        void main()
                                        {
                                            alias T = float;
                                            T x = T.infinity;
                                            T e = T.infinity;
                                            int eptr;
                                            T v = frexp(x, eptr);
                                            assert(isIdentical(e, v));
                                        }
                                     */
                                }
                                else if (voffset == 0)
                                {
                                    pcs.reg = preg;
                                    cgstate.regcon.used |= mask(preg);
                                    break;
                                }
                            }
                        }
                    }
                    else
                        cgstate.regcon.params &= ~pregm;
                }
            }
            if (s.Sclass == SC.shadowreg)
                goto Lpara;
            goto case FLbprel;

        case FLbprel:
            cgstate.reflocal = true;
            pcs.base = BP;
            goto L2;

        case FLextern:
            if (s.Sident[0] == '_' && memcmp(s.Sident.ptr + 1,"tls_array".ptr,10) == 0)
            {
                if (config.exe & EX_windos)
                {
                    if (I64)
                    {   // GS:[88]
                        pcs.Irm = modregrm(0, 0, 4);
                        pcs.Isib = modregrm(0, 4, 5);  // don't use [RIP] addressing
                        pcs.IFL1 = FLconst;
                        pcs.IEV1.Vuns = 88;
                        pcs.Iflags = CFgs;
                        pcs.Irex |= REX_W;
                        break;
                    }
                    else
                    {
                        pcs.Iflags |= CFfs;    // add FS: override
                    }
                }
                else if (config.exe & (EX_OSX | EX_OSX64))
                {
                }
                else if (config.exe & EX_posix)
                    assert(0);
            }
            goto L3;

        case FLtlsdata:
            if (config.exe & EX_posix)
                goto L3;
            assert(0);

        case FLdata:
        case FLudata:
        case FLcsdata:
        case FLgot:
        case FLgotoff:
        L3:
            pcs.base = BP;
        L2:
            if (rm != RM.store)                    // if not store only
                s.Sflags |= SFLread;               // assume we are doing a read

            if (fl == FLreg)
            {
                //printf("test: FLreg, %s %d cgstate.regcon.mvar = %s\n",
                // s.Sident.ptr, cast(int)e.Voffset, regm_str(cgstate.regcon.mvar));
                if (!(s.Sregm & cgstate.regcon.mvar))
                    symbol_print(*s);
                assert(s.Sregm & cgstate.regcon.mvar);

                /* Attempting to paint a float as an integer or an integer as a float
                 * will cause serious problems since the EA is loaded separatedly from
                 * the opcode. The only way to deal with this is to prevent enregistering
                 * such variables.
                 */
                if (tyxmmreg(ty) && !(s.Sregm & XMMREGS) ||
                    !tyxmmreg(ty) && (s.Sregm & XMMREGS))
                    cgreg_unregister(s.Sregm);

                if (
                    s.Sclass == SC.regpar ||
                    s.Sclass == SC.parameter)
                {   cgstate.refparam = true;
                    cgstate.reflocal = true;        // kludge to set up prolog
                }
                pcs.base = NOREG;
                pcs.index = NOREG;
                pcs.reg = s.Sreglsw;
                if (e.Voffset == REGSIZE && sz == REGSIZE)
                    pcs.reg = s.Sregmsw;
                break;
            }
            if (config.flags3 & CFG3pic &&
                (fl == FLtlsdata || s.ty() & mTYthread))
            {
                assert(0);
            }
            pcs.IEV1.Vsym = s;
            pcs.IEV1.Voffset = e.Voffset;
            //pcs.Sextend = tyToExtend(ty);  only need to worry about this if pcs.index is set
            if (sz == 1)
            {
                s.Sflags |= GTbyte;
                if (e.Voffset)
                {
                    debug if (debugr) printf("'%s' not reg cand due to byte offset\n", s.Sident.ptr);
                    s.Sflags &= ~GTregcand;
                }
            }
            else if (sz == 2 && tyxmmreg(s.ty()) && config.fpxmmregs)
            {
                debug if (debugr) printf("'%s' not XMM reg cand due to short access\n", s.Sident.ptr);
                s.Sflags &= ~GTregcand;
            }
            else if (e.Voffset || sz > tysize(s.Stype.Tty))
            {
                debug if (debugr) printf("'%s' not reg cand due to offset or size\n", s.Sident.ptr);
                s.Sflags &= ~GTregcand;
            }
            else if (tyvector(s.Stype.Tty) && sz < tysize(s.Stype.Tty))
            {
                // https://issues.dlang.org/show_bug.cgi?id=21673
                // https://issues.dlang.org/show_bug.cgi?id=21676
                // https://issues.dlang.org/show_bug.cgi?id=23009
                // PR: https://github.com/dlang/dmd/pull/13977
                // cannot read or write to partial vector
                debug if (debugr) printf("'%s' not reg cand due to vector type\n", s.Sident.ptr);
                s.Sflags &= ~GTregcand;
            }

            if (config.fpxmmregs && tyfloating(s.ty()) && !tyfloating(ty))
            {
                debug if (debugr) printf("'%s' not reg cand due to mix float and int\n", s.Sident.ptr);
                // Can't successfully mix XMM register variables accessed as integers
                s.Sflags &= ~GTregcand;
            }
            break;

        case FLpseudo:
            {
                getregs(cdb, mask(s.Sreglsw));
                pcs.reg = s.Sreglsw;
                break;
            }

        case FLfardata:
        case FLfunc:                                /* reading from code seg */
            if (config.exe & EX_flat)
                goto L3;
            assert(0);

        case FLstack:
            pcs.base = SP;
            pcs.IEV1.Vsym = s;
            pcs.IEV1.Voffset = e.Voffset;
            break;

        default:
            symbol_print(*s);
            assert(0);
    }
}

// fltregs

/*****************************
 * Given a result in registers, test it for true or false.
 * Will fail if TYfptr and the reg is ES!
 * If saveflag is true, preserve the contents of the
 * registers.
 */
@trusted
void tstresult(ref CodeBuilder cdb, regm_t regm, tym_t tym, bool saveflag)
{
    reg_t scrreg;                      // scratch register
    regm_t scrregm;

    //if (!(regm & (mBP | ALLREGS)))
        //printf("tstresult(regm = %s, tym = x%x, saveflag = %d)\n",
            //regm_str(regm),tym,saveflag);

    tym = tybasic(tym);
    reg_t reg = findreg(regm);
    uint sz = _tysize[tym];
    assert(regm & cgstate.allregs);
static if (0)
{
    assert(regm & (XMMREGS | mBP | ALLREGS));
    if (sz == 1)
    {
        assert(regm & BYTEREGS);
        genregs(cdb, 0x84, reg, reg);        // TEST regL,regL
        if (I64 && reg >= 4)
            code_orrex(cdb.last(), REX);
        return;
    }
    if (regm & XMMREGS)
    {
        regm_t xregs = XMMREGS & ~regm;
        const xreg = allocreg(cdb,xregs, TYdouble);
        opcode_t op = 0;
        if (tym == TYdouble || tym == TYidouble || tym == TYcdouble)
            op = 0x660000;
        cdb.gen2(op | XORPS, modregrm(3, xreg-XMM0, xreg-XMM0));      // XORPS xreg,xreg
        cdb.gen2(op | UCOMISS, modregrm(3, xreg-XMM0, reg-XMM0));     // UCOMISS xreg,reg
        if (tym == TYcfloat || tym == TYcdouble)
        {   code *cnop = gennop(null);
            genjmp(cdb, JNE, FLcode, cast(block *) cnop); // JNE     L1
            genjmp(cdb,  JP, FLcode, cast(block *) cnop); // JP      L1
            reg = findreg(regm & ~mask(reg));
            cdb.gen2(op | UCOMISS, modregrm(3, xreg-XMM0, reg-XMM0)); // UCOMISS xreg,reg
            cdb.append(cnop);
        }
        return;
    }
}
    if (sz <= REGSIZE)
    {
        if (tym == TYfloat)
        {
            if (saveflag)
            {
                scrregm = cgstate.allregs & ~regm;              // possible scratch regs
                scrreg = allocreg(cdb, scrregm, TYoffset); // allocate scratch reg
                genmovreg(cdb, scrreg, reg);  // MOV scrreg,msreg
                reg = scrreg;
            }
            getregs(cdb, mask(reg));
            cdb.gen2(0xD1, modregrmx(3, 4, reg)); // SHL reg,1
            return;
        }
    }

    gentstreg(cdb,reg,sz == 8);                 // CMP reg,#0


static if (0)
{
    if (saveflag || tyfv(tym))
    {
    L1:
        scrregm = ALLREGS & ~regm;              // possible scratch regs
        scrreg = allocreg(cdb, scrregm, TYoffset); // allocate scratch reg
        if (I32 || sz == REGSIZE * 2)
        {
            assert(regm & mMSW && regm & mLSW);

            reg = findregmsw(regm);
            if (I32)
            {
                if (tyfv(tym))
                    genregs(cdb, MOVZXw, scrreg, reg); // MOVZX scrreg,msreg
                else
                {
                    genmovreg(cdb, scrreg, reg);      // MOV scrreg,msreg
                    if (tym == TYdouble || tym == TYdouble_alias)
                        cdb.gen2(0xD1, modregrm(3, 4, scrreg)); // SHL scrreg,1
                }
            }
            else
            {
                genmovreg(cdb, scrreg, reg);  // MOV scrreg,msreg
                if (tym == TYfloat)
                    cdb.gen2(0xD1, modregrm(3, 4, scrreg)); // SHL scrreg,1
            }
            reg = findreglsw(regm);
            genorreg(cdb, scrreg, reg);           // OR scrreg,lsreg
        }
        else if (sz == 8)
        {
            // !I32
            genmovreg(cdb, scrreg, AX);           // MOV scrreg,AX
            if (tym == TYdouble || tym == TYdouble_alias)
                cdb.gen2(0xD1 ,modregrm(3, 4, scrreg));         // SHL scrreg,1
            genorreg(cdb, scrreg, BX);            // OR scrreg,BX
            genorreg(cdb, scrreg, CX);            // OR scrreg,CX
            genorreg(cdb, scrreg, DX);            // OR scrreg,DX
        }
        else
            assert(0);
    }
    else
    {
        if (I32 || sz == REGSIZE * 2)
        {
            // can't test ES:LSW for 0
            assert(regm & mMSW & ALLREGS && regm & (mLSW | mBP));

            reg = findregmsw(regm);
            if (cgstate.regcon.mvar & mask(reg))        // if register variable
                goto L1;                        // don't trash it
            getregs(cdb, mask(reg));            // we're going to trash reg
            if (tyfloating(tym) && sz == 2 * _tysize[TYint])
                cdb.gen2(0xD1, modregrm(3 ,4, reg));   // SHL reg,1
            genorreg(cdb, reg, findreglsw(regm));     // OR reg,reg+1
            if (I64)
                code_orrex(cdb.last(), REX_W);
       }
        else if (sz == 8)
        {   assert(regm == DOUBLEREGS_16);
            getregs(cdb,mAX);                  // allocate AX
            if (tym == TYdouble || tym == TYdouble_alias)
                cdb.gen2(0xD1, modregrm(3, 4, AX));       // SHL AX,1
            genorreg(cdb, AX, BX);          // OR AX,BX
            genorreg(cdb, AX, CX);          // OR AX,CX
            genorreg(cdb, AX, DX);          // OR AX,DX
        }
        else
            assert(0);
    }
    code_orflag(cdb.last(),CFpsw);
}
}


/******************************
 * Given the result of an expression is in retregs,
 * generate necessary code to return result in outretregs.
 */
@trusted
void fixresult(ref CodeBuilder cdb, elem *e, regm_t retregs, ref regm_t outretregs)
{
    //printf("arm.fixresult(e = %p, retregs = %s, outretregs = %s)\n",e,regm_str(retregs),regm_str(outretregs));
    if (outretregs == 0) return;           // if don't want result
    assert(e && retregs);                 // need something to work with
    regm_t forccs = outretregs & mPSW;
    //regm_t forregs = outretregs & (mST01 | mST0 | mBP | ALLREGS | mES | mSTACK | XMMREGS);
    regm_t forregs = outretregs & cgstate.allregs;
    tym_t tym = tybasic(e.Ety);

    if (tym == TYstruct)
    {
        if (e.Eoper == OPpair || e.Eoper == OPrpair)
        {
            tym = TYucent;
        }
        else
            // Hack to support cdstreq()
            tym = TYnptr;
    }
    int sz = _tysize[tym];

    reg_t reg,rreg;
    if ((retregs & forregs) == retregs)   // if already in right registers
        outretregs = retregs;
    else if (forregs)             // if return the result in registers
    {
        bool opsflag = false;
        rreg = allocreg(cdb, outretregs, tym);  // allocate return regs
        if (0 && retregs & XMMREGS)
        {
            reg = findreg(retregs & XMMREGS);
            if (mask(rreg) & XMMREGS)
                genmovreg(cdb, rreg, reg, tym);
            else
            {
                // MOVSD floatreg, XMM?
                cdb.genxmmreg(xmmstore(tym), reg, 0, tym);
                // MOV rreg,floatreg
                cdb.genfltreg(0x8B,rreg,0);
                if (sz == 8)
                {
                    if (I32)
                    {
                        rreg = findregmsw(outretregs);
                        cdb.genfltreg(0x8B, rreg,4);
                    }
                    else
                        code_orrex(cdb.last(),REX_W);
                }
            }
        }
/+
        else if (forregs & XMMREGS)
        {
            reg = findreg(retregs & (mBP | ALLREGS));
            switch (sz)
            {
                case 4:
                    cdb.gen2(LODD, modregxrmx(3, rreg - XMM0, reg)); // MOVD xmm,reg
                    break;

                case 8:
                    if (I32)
                    {
                        cdb.genfltreg(0x89, reg, 0);
                        reg = findregmsw(retregs);
                        cdb.genfltreg(0x89, reg, 4);
                        cdb.genxmmreg(xmmload(tym), rreg, 0, tym); // MOVQ xmm,mem
                    }
                    else
                    {
                        cdb.gen2(LODD /* [sic!] */, modregxrmx(3, rreg - XMM0, reg));
                        code_orrex(cdb.last(), REX_W); // MOVQ xmm,reg
                    }
                    break;

                default:
                    assert(false);
            }
        }
+/
        else if (sz > REGSIZE)
        {
            reg_t msreg = findregmsw(retregs);
            reg_t lsreg = findreglsw(retregs);
            reg_t msrreg = findregmsw(outretregs);
            reg_t lsrreg = findreglsw(outretregs);

            genmovreg(cdb, msrreg, msreg); // MOV msrreg,msreg
            genmovreg(cdb, lsrreg, lsreg); // MOV lsrreg,lsreg
        }
        else
        {
            assert(!(retregs & XMMREGS));
            assert(!(forregs & XMMREGS));
            reg = findreg(retregs & cgstate.allregs);
            if (sz <= 4)
                genmovreg(cdb, rreg, reg, TYint);  // only move 32 bits, and zero the top 32 bits
            else
                genmovreg(cdb, rreg, reg);    // MOV rreg,reg
        }
        cssave(e,retregs | outretregs,opsflag);
        // Commented out due to Bugzilla 8840
        //forregs = 0;    // don't care about result in reg cuz real result is in rreg
        retregs = outretregs & ~mPSW;
    }
    if (forccs)                           // if return result in flags
    {
        tstresult(cdb, retregs, tym, forregs != 0);
    }
}

// cdfunc
/*******************************
 * Generate code sequence for function call.
 */

@trusted
void cdfunc(ref CGstate cg, ref CodeBuilder cdb, elem* e, ref regm_t pretregs)
{
    //printf("cdfunc()\n"); elem_print(e);
    assert(e);
    uint numpara = 0;               // bytes of parameters
    uint stackpushsave = cgstate.stackpush;   // so we can compute # of parameters
printf("stackpushsave: %d\n", stackpushsave);
    cgstate.stackclean++;
    regm_t keepmsk = 0;
    int xmmcnt = 0;
    tym_t tyf = tybasic(e.E1.Ety);        // the function type

    // Easier to deal with parameters as an array: parameters[0..np]
    int np = OTbinary(e.Eoper) ? el_nparams(e.E2) : 0;
    Parameter *parameters = cast(Parameter *)alloca(np * Parameter.sizeof);

    if (np)
    {
        int n = 0;
        fillParameters(e.E2, parameters, &n);
        assert(n == np);
    }

    Symbol *sf = null;                  // symbol of the function being called
    if (e.E1.Eoper == OPvar)
        sf = e.E1.Vsym;

    /* Assume called function access statics
     */
    if (config.exe & (EX_LINUX | EX_LINUX64 | EX_OSX | EX_FREEBSD | EX_FREEBSD64 | EX_OPENBSD | EX_OPENBSD64) &&
        config.flags3 & CFG3pic)
        cgstate.accessedTLS = true;

    /* Special handling for call to __tls_get_addr, we must save registers
     * before evaluating the parameter, so that the parameter load and call
     * are adjacent.
     */
    if (np == 1 && sf)
    {
        if (sf == tls_get_addr_sym)
            getregs(cdb, ~sf.Sregsaved & cg.allregs); // XMMREGS?
    }

    uint stackalign = REGSIZE;
    if (tyf == TYf16func)
        stackalign = 2;
    // Figure out which parameters go in registers.
    // Compute numpara, the total bytes pushed on the stack
    FuncParamRegs fpr = FuncParamRegs_create(tyf);
    for (int i = np; --i >= 0;)
    {
        elem *ep = parameters[i].e;
        uint psize = cast(uint)_align(stackalign, paramsize(ep, tyf));     // align on stack boundary
        if (config.exe == EX_WIN64)
        {
            //printf("[%d] size = %u, numpara = %d ep = %p %s\n", i, psize, numpara, ep, tym_str(ep.Ety));
            debug
            if (psize > REGSIZE) elem_print(e);

            assert(psize <= REGSIZE);
            psize = REGSIZE;
        }
        //printf("[%d] size = %u, numpara = %d %s\n", i, psize, numpara, tym_str(ep.Ety));
        if (FuncParamRegs_alloc(fpr, ep.ET, ep.Ety, parameters[i].reg, parameters[i].reg2))
        {
            if (config.exe == EX_WIN64)
                numpara += REGSIZE;             // allocate stack space for it anyway
            continue;   // goes in register, not stack
        }

        // Parameter i goes on the stack
        parameters[i].reg = NOREG;
        uint alignsize = el_alignsize(ep);
        parameters[i].numalign = 0;
        if (alignsize > stackalign &&
            (I64 || (alignsize >= 16 &&
                (config.exe & (EX_OSX | EX_LINUX) && (tyaggregate(ep.Ety) || tyvector(ep.Ety))))))
        {
            if (alignsize > STACKALIGN)
            {
                STACKALIGN = alignsize;
                cgstate.enforcealign = true;
            }
            uint newnumpara = (numpara + (alignsize - 1)) & ~(alignsize - 1);
            parameters[i].numalign = newnumpara - numpara;
            numpara = newnumpara;
            assert(config.exe != EX_WIN64);
        }
        numpara += psize;
    }

    if (config.exe == EX_WIN64)
    {
        if (numpara < 4 * REGSIZE)
            numpara = 4 * REGSIZE;
    }

    //printf("numpara = %d, cgstate.stackpush = %d\n", numpara, stackpush);
    assert((numpara & (REGSIZE - 1)) == 0);
    assert((cgstate.stackpush & (REGSIZE - 1)) == 0);

    /* Should consider reordering the order of evaluation of the parameters
     * so that args that go into registers are evaluated after args that get
     * pushed. We can reorder args that are constants or relconst's.
     */

    /* There's only one way to call functions (unlike for x86_64).
     * The SP is moved down by the aggregate size of the arguments that go on the
     * stack, and the arguments are then moved into the stack.
     * The x86_64 ways do not work because BP cannot have negative offsets, and so
     * BP at the bottom would be in the way
     */

     /* Check for obsolete operators
      */
    foreach (i; 0 .. np)
    {
        elem* ep = parameters[i].e;
        int preg = parameters[i].reg;
        //printf("parameter[%d] = %d, np = %d\n", i, preg, np);
        if (preg == NOREG)
        {
            switch (ep.Eoper)
            {
                case OPstrctor:
                case OPstrthis:
                case OPstrpar:
                case OPnp_fp:
                    assert(0);

                default:
                    break;
            }
        }
    }

    /* stack for parameters is allocated all at once - no pushing
     * and ensure it is aligned
     */
printf("STACKALIGN: %d\n", STACKALIGN);
    uint numalign = -numpara & (STACKALIGN - 1);
printf("numalign: %d numpara: %d\n", numalign, numpara);
    cod3_stackadj(cdb, numalign + numpara);
    cdb.genadjesp(numalign + numpara);
    cgstate.stackpush += numalign + numpara;
    stackpushsave += numalign + numpara;

    assert(cgstate.stackpush == stackpushsave);
    if (config.exe == EX_WIN64)
    {
        //printf("np = %d, numpara = %d, cgstate.stackpush = %d\n", np, numpara, stackpush);
        assert(numpara == ((np < 4) ? 4 * REGSIZE : np * REGSIZE));

        // Allocate stack space for four entries anyway
        // https://msdn.microsoft.com/en-US/library/ew5tede7%28v=vs.100%29
    }

    CodeBuilder cdbrestore;
    cdbrestore.ctor();
    regm_t saved = 0;
    targ_size_t funcargtossave = cgstate.funcargtos;
    targ_size_t funcargtos = numpara;
    //printf("funcargtos1 = %d\n", cast(int)funcargtos);

    /* Parameters go into the registers RDI,RSI,RDX,RCX,R8,R9
     * float and double parameters go into XMM0..XMM7
     * For variadic functions, count of XMM registers used goes in AL
     */
    foreach (i; 0 .. np)
    {
        elem* ep = parameters[i].e;
        reg_t preg = parameters[i].reg;
        //printf("parameter[%d] = %d, np = %d\n", i, preg, np);
        if (preg == NOREG)
        {
            /* Move parameter on stack, but keep track of registers used
             * in the process. If they interfere with keepmsk, we'll have
             * to save/restore them.
             */
            CodeBuilder cdbsave;
            cdbsave.ctor();
            regm_t overlap = cgstate.msavereg & keepmsk;
            cgstate.msavereg |= keepmsk;
            CodeBuilder cdbparams;
            cdbparams.ctor();

            // Alignment for parameter comes after it was placed on stack
            const uint numalignx = parameters[i].numalign;
            funcargtos -= _align(stackalign, paramsize(ep, tyf)) + numalignx;

            movParams(cdbparams, ep, stackalign, cast(uint)funcargtos, tyf);
            regm_t tosave = keepmsk & ~cgstate.msavereg;
            cgstate.msavereg &= ~keepmsk | overlap;

            // tosave is the mask to save and restore
            for (reg_t j = 0; tosave; j++)
            {
                regm_t mi = mask(j);
                assert(j <= XMM7);
                if (mi & tosave)
                {
                    uint idx;
                    cgstate.regsave.save(cdbsave, j, idx);
                    cgstate.regsave.restore(cdbrestore, j, idx);
                    saved |= mi;
                    keepmsk &= ~mi;             // don't need to keep these for rest of params
                    tosave &= ~mi;
                }
            }

            cdb.append(cdbsave);
            cdb.append(cdbparams);
        }
        else
        {
            // Goes in register preg, not stack
            regm_t retregs = mask(preg);
            if (retregs & XMMREGS)
                ++xmmcnt;
            reg_t preg2 = parameters[i].reg2;
            reg_t mreg,lreg;
            if (preg2 != NOREG || tybasic(ep.Ety) == TYcfloat)
            {
                assert(ep.Eoper != OPstrthis);
                if (mask(preg2) & XMMREGS)
                    ++xmmcnt;
                if (tybasic(ep.Ety) == TYcfloat)
                {
                    lreg = ST01;
                    mreg = NOREG;
                }
                else if (tyrelax(ep.Ety) == TYcent)
                {
                    lreg = mask(preg ) & mLSW ? cast(reg_t)preg  : AX;
                    mreg = mask(preg2) & mMSW ? cast(reg_t)preg2 : DX;
                }
                else
                {
                    lreg = XMM0;
                    mreg = XMM1;
                }
                retregs = (mask(mreg) | mask(lreg)) & ~mask(NOREG);
                CodeBuilder cdbsave;
                cdbsave.ctor();
                if (keepmsk & retregs)
                {
                    regm_t tosave = keepmsk & retregs;

                    // tosave is the mask to save and restore
                    for (reg_t j = 0; tosave; j++)
                    {
                        regm_t mi = mask(j);
                        assert(j <= XMM7);
                        if (mi & tosave)
                        {
                            uint idx;
                            cgstate.regsave.save(cdbsave, j, idx);
                            cgstate.regsave.restore(cdbrestore, j, idx);
                            saved |= mi;
                            keepmsk &= ~mi;             // don't need to keep these for rest of params
                            tosave &= ~mi;
                        }
                    }
                }
                cdb.append(cdbsave);

                scodelem(cgstate,cdb, ep, retregs, keepmsk, false);

                // Move result [mreg,lreg] into parameter registers from [preg2,preg]
                retregs = 0;
                if (preg != lreg)
                    retregs |= mask(preg);
                if (preg2 != mreg)
                    retregs |= mask(preg2);
                retregs &= ~mask(NOREG);
                getregs(cdb,retregs);

                tym_t ty1 = tybasic(ep.Ety);
                tym_t ty2 = ty1;
                if (ep.Ety & mTYgprxmm)
                {
                    ty1 = TYllong;
                    ty2 = TYdouble;
                }
                else if (ep.Ety & mTYxmmgpr)
                {
                    ty1 = TYdouble;
                    ty2 = TYllong;
                }
                else if (ty1 == TYstruct)
                {
                    type* targ1 = ep.ET.Ttag.Sstruct.Sarg1type;
                    type* targ2 = ep.ET.Ttag.Sstruct.Sarg2type;
                    if (targ1)
                        ty1 = targ1.Tty;
                    if (targ2)
                        ty2 = targ2.Tty;
                }
                else if (tyrelax(ty1) == TYcent)
                    ty1 = ty2 = TYllong;
                else if (tybasic(ty1) == TYcdouble)
                    ty1 = ty2 = TYdouble;

                if (tybasic(ep.Ety) == TYcfloat)
                {
                    assert(I64);
                    assert(lreg == ST01 && mreg == NOREG);
                    // spill
                    pop87();
                    pop87();
                    cdb.genfltreg(0xD9, 3, tysize(TYfloat));
                    genfwait(cdb);
                    cdb.genfltreg(0xD9, 3, 0);
                    genfwait(cdb);
                    // reload
                    if (config.exe == EX_WIN64)
                    {
                        cdb.genfltreg(LOD, preg, 0);
                        code_orrex(cdb.last(), REX_W);
                    }
                    else
                    {
                        assert(mask(preg) & XMMREGS);
                        cdb.genxmmreg(xmmload(TYdouble), cast(reg_t) preg, 0, TYdouble);
                    }
                }
                else foreach (v; 0 .. 2)
                {
                    if (v ^ (preg != mreg))
                        genmovreg(cdb, preg, lreg, ty1);
                    else
                        genmovreg(cdb, preg2, mreg, ty2);
                }

                retregs = (mask(preg) | mask(preg2)) & ~mask(NOREG);
            }
            else if (ep.Eoper == OPstrthis)
            {
                getregs(cdb,retregs);
                // LEA preg,np[RSP]
                uint delta = cgstate.stackpush - ep.Vuns;   // stack delta to parameter
                cdb.genc1(LEA,
                        (modregrm(0,4,SP) << 8) | modregxrm(2,preg,4), FLconst,delta);
                if (I64)
                    code_orrex(cdb.last(), REX_W);
            }
            else if (ep.Eoper == OPstrpar && config.exe == EX_WIN64 && type_size(ep.ET) == 0)
            {
                retregs = 0;
                scodelem(cgstate,cdb, ep.E1, retregs, keepmsk, false);
                freenode(ep);
            }
            else
            {
                scodelem(cgstate,cdb, ep, retregs, keepmsk, false);
            }
            keepmsk |= retregs;      // don't change preg when evaluating func address
        }
    }

    if (config.exe == EX_WIN64)
    {   // Allocate stack space for four entries anyway
        // https://msdn.microsoft.com/en-US/library/ew5tede7%28v=vs.100%29
        {   uint sz = 4 * REGSIZE;
            cod3_stackadj(cdb, sz);
            cdb.genadjesp(sz);
            cgstate.stackpush += sz;
        }

        /* Variadic functions store XMM parameters into their corresponding GP registers
         */
        for (int i = 0; i < np; i++)
        {
            int preg = parameters[i].reg;
            regm_t retregs = mask(preg);
            if (retregs & XMMREGS)
            {
                reg_t reg;
                switch (preg)
                {
                    case XMM0: reg = CX; break;
                    case XMM1: reg = DX; break;
                    case XMM2: reg = R8; break;
                    case XMM3: reg = R9; break;

                    default:   assert(0);
                }
                getregs(cdb,mask(reg));
                //cdb.gen2(STOD,(REX_W << 16) | modregxrmx(3,preg-XMM0,reg)); // MOVD reg,preg
            }
        }
    }

    // Restore any register parameters we saved
    getregs(cdb,saved);
    cdb.append(cdbrestore);
    keepmsk |= saved;

    // Variadic functions store the number of XMM registers used in AL
    if (config.exe != EX_WIN64 && e.Eflags & EFLAGS_variadic && !cg.AArch64)
    {
        getregs(cdb,mAX);
        movregconst(cdb,AX,xmmcnt,1);
        keepmsk |= mAX;
    }

    //printf("funcargtos: %d cgstate.funcargtos: %d\n", cast(int)funcargtos, cast(int)cgstate.funcargtos);
    assert(funcargtos == 0 && cgstate.funcargtos == ~0);
    cgstate.stackclean--;

    funccall(cdb,e,numpara,numalign,pretregs,keepmsk,false);
    cgstate.funcargtos = funcargtossave;
}

/******************************
 * Call function. All parameters have already been pushed onto the stack.
 * Params:
 *      e          = function call
 *      numpara    = size in bytes of all the parameters
 *      numalign   = amount the stack was aligned by before the parameters were pushed
 *      pretregs   = where return value goes
 *      keepmsk    = registers to not change when evaluating the function address
 *      usefuncarg = using cgstate.funcarg, so no need to adjust stack after func return
 */

@trusted
private void funccall(ref CodeBuilder cdb, elem* e, uint numpara, uint numalign,
                      ref regm_t pretregs,regm_t keepmsk, bool usefuncarg)
{
    //printf("funccall(e = %p, pretregs = %s, numpara = %d, numalign = %d, usefuncarg=%d)\n",e,regm_str(pretregs),numpara,numalign,usefuncarg);
    //printf("  from %s\n", funcsym_p.Sident.ptr);
    //elem_print(e);
    cgstate.calledafunc = 1;
    // Determine if we need frame for function prolog/epilog

    if (config.memmodel == Vmodel)
    {
        if (tyfarfunc(funcsym_p.ty()))
            cgstate.needframe = true;
    }

    regm_t retregs;
    Symbol* s;

    elem* e1 = e.E1;
    tym_t tym1 = tybasic(e1.Ety);
    char farfunc = tyfarfunc(tym1) || tym1 == TYifunc;

    CodeBuilder cdbe;
    cdbe.ctor();

    if (e1.Eoper == OPvar)
    {   // Call function directly

        if (!tyfunc(tym1))
            printf("%s\n", tym_str(tym1));
        assert(tyfunc(tym1));
        s = e1.Vsym;
        if (s.Sflags & SFLexit)
        { }
        else if (s != tls_get_addr_sym)
            save87(cdb);               // assume 8087 regs are all trashed

        // Function calls may throw Errors, unless marked that they don't
        if (s == funcsym_p || !s.Sfunc || !(s.Sfunc.Fflags3 & Fnothrow))
            funcsym_p.Sfunc.Fflags3 &= ~Fnothrow;

        if (s.Sflags & SFLexit)
        {
            // Function doesn't return, so don't worry about registers
            // it may use
        }
        else if (!tyfunc(s.ty()) || !(config.flags4 & CFG4optimized))
            // so we can replace func at runtime
            getregs(cdbe,~fregsaved & cgstate.allregs); // XMMREGS ?
        else
            getregs(cdbe,~s.Sregsaved & cgstate.allregs); // XMMREGS ?
        if (strcmp(s.Sident.ptr, "alloca") == 0)
        {
            s = getRtlsym(RTLSYM.ALLOCA);
            makeitextern(s);
            int areg = CX;
            if (config.exe == EX_WIN64)
                areg = DX;
            getregs(cdbe, mask(areg));
            cdbe.genc(LEA, modregrm(2, areg, BPRM), FLallocatmp, 0, 0, 0);  // LEA areg,&localsize[BP]
            if (I64)
                code_orrex(cdbe.last(), REX_W);
            cgstate.Alloca.size = REGSIZE;
        }
        if (sytab[s.Sclass] & SCSS)    // if function is on stack (!)
        {
            retregs = cgstate.allregs & ~keepmsk;
            s.Sflags &= ~GTregcand;
            s.Sflags |= SFLread;
            cdrelconst(cgstate,cdbe,e1,retregs);
            if (farfunc)
            {
                const reg = findregmsw(retregs);
                const lsreg = findreglsw(retregs);
                cgstate.floatreg = true;         // use float register
                cgstate.reflocal = true;
                cdbe.genc1(0x89,                 // MOV floatreg+2,reg
                        modregrm(2, reg, BPRM), FLfltreg, REGSIZE);
                cdbe.genc1(0x89,                 // MOV floatreg,lsreg
                        modregrm(2, lsreg, BPRM), FLfltreg, 0);
                if (tym1 == TYifunc)
                    cdbe.gen1(0x9C);             // PUSHF
                cdbe.genc1(0xFF,                 // CALL [floatreg]
                        modregrm(2, 3, BPRM), FLfltreg, 0);
            }
            else
            {
                const reg = findreg(retregs);
                cdbe.gen2(0xFF, modregrmx(3, 2, reg));   // CALL reg
                if (I64)
                    code_orrex(cdbe.last(), REX_W);
            }
        }
        else
        {
            FL fl = FLfunc;
            if (!tyfunc(s.ty()))
                fl = el_fl(e1);
            if (tym1 == TYifunc)
                cdbe.gen1(0x9C);                             // PUSHF
            if (config.exe & (EX_windos | EX_OSX | EX_OSX64))
            {
                cdbe.gencs(farfunc ? 0x9A : 0xE8,0,fl,s);    // CALL extern
            }
            else
            {
                assert(!farfunc);
                if (s != tls_get_addr_sym)
                {
                    //printf("call %s\n", s.Sident.ptr);
                    load_localgot(cdb);
                    cdbe.gencs1(INSTR.branch_imm(1, 0), 0, fl, s);    // CALL extern
                }
                else if (I64)
                {
                    /* Prepend 66 66 48 so GNU linker has patch room
                     */
                    assert(!farfunc);
                    cdbe.gen1(0x66);
                    cdbe.gen1(0x66);
                    cdbe.gencs(0xE8, 0, fl, s);      // CALL extern
                    cdbe.last().Irex = REX | REX_W;
                }
                else
                    cdbe.gencs(0xE8, 0, fl, s);    // CALL extern
            }
            code_orflag(cdbe.last(), farfunc ? (CFseg | CFoff) : (CFselfrel | CFoff));
        }
    }
    else
    {   // Call function via pointer

        // Function calls may throw Errors
        funcsym_p.Sfunc.Fflags3 &= ~Fnothrow;

        if (e1.Eoper != OPind) { printf("e1.fl: %s, e1.Eoper: %s\n", fl_str(el_fl(e1)), oper_str(e1.Eoper)); }
        assert(e1.Eoper == OPind);
        elem *e11 = e1.E1;
        tym_t e11ty = tybasic(e11.Ety);
        load_localgot(cdb);
        if (config.exe & (EX_LINUX | EX_FREEBSD | EX_OPENBSD | EX_SOLARIS)) // 32 bit only
        {
            if (config.flags3 & CFG3pic)
                keepmsk |= mBX;
        }

        /* Mask of registers destroyed by the function call
         */
        regm_t desmsk = cgstate.allregs & ~fregsaved; // XMMREGS?
        //printf("desmsk: %s\n", regm_str(desmsk));

        // if we can't use loadea()
        if (1)
        //if ((!OTleaf(e11.Eoper) || e11.Eoper == OPconst) &&
            //(e11.Eoper != OPind || e11.Ecount))
        {
            retregs = cgstate.allregs & ~keepmsk;
            cgstate.stackclean++;
            scodelem(cgstate,cdbe,e11,retregs,keepmsk,true);
            cgstate.stackclean--;
            // Kill registers destroyed by an arbitrary function call
            getregs(cdbe,desmsk);
            const reg = findreg(retregs);

            cdbe.gen1(INSTR.blr(reg));  // BLR reg
        }
        else
        {
            code cs;
            cs.Iflags = 0;
            cgstate.stackclean++;
            loadea(cdbe, e11, cs, 0xFF, farfunc ? 3 : 2, 0, keepmsk, desmsk);
            cgstate.stackclean--;
            freenode(e11);
        }
        s = null;
    }
    cdb.append(cdbe);
    freenode(e1);

    /* See if we will need the frame pointer.
       Calculate it here so we can possibly use BP to fix the stack.
     */
static if (0)
{
    if (!cgstate.needframe)
    {
        // If there is a register available for this basic block
        if (config.flags4 & CFG4optimized && (cgstate.allregs & ~cgstate.regcon.used))
        { }
        else
        {
            foreach (s; globsym[])
            {
                if (s.Sflags & GTregcand && type_size(s.Stype) != 0)
                {
                    if (config.flags4 & CFG4optimized)
                    {   // If symbol is live in this basic block and
                        // isn't already in a register
                        if (s.Srange && vec_testbit(cgstate.dfoidx, s.Srange) &&
                            s.Sfl != FLreg)
                        {   // Then symbol must be allocated on stack
                            cgstate.needframe = true;
                            break;
                        }
                    }
                    else
                    {   if (cgstate.mfuncreg == 0)      // if no registers left
                        {   cgstate.needframe = true;
                            break;
                        }
                    }
                }
            }
        }
    }
}

    reg_t reg1, reg2;
    retregs = allocretregs(e.Ety, e.ET, tym1, reg1, reg2);

    assert(retregs || !pretregs);

    if (!usefuncarg)
    {
        // If stack needs cleanup
        if  (s && s.Sflags & SFLexit)
        {
            if (config.fulltypes && TARGET_WINDOS)
            {
                // the stack walker evaluates the return address, not a byte of the
                // call instruction, so ensure there is an instruction byte after
                // the call that still has the same line number information
                cdb.gen1(config.target_cpu >= TARGET_80286 ? UD2 : INT3);
            }
            /* Function never returns, so don't need to generate stack
             * cleanup code. But still need to log the stack cleanup
             * as if it did return.
             */
            cdb.genadjesp(-(numpara + numalign));
            cgstate.stackpush -= numpara + numalign;
        }
        else if ((OTbinary(e.Eoper) || config.exe == EX_WIN64) &&
            (!typfunc(tym1) || config.exe == EX_WIN64))
        {
            if (tym1 == TYhfunc)
            {   // Hidden parameter is popped off by the callee
                cdb.genadjesp(-REGSIZE);
                cgstate.stackpush -= REGSIZE;
                if (numpara + numalign > REGSIZE)
                    genstackclean(cdb, numpara + numalign - REGSIZE, retregs);
            }
            else
                genstackclean(cdb, numpara + numalign, retregs);
        }
        else
        {
            cdb.genadjesp(-numpara);  // popped off by the callee's 'RET numpara'
            cgstate.stackpush -= numpara;
            if (numalign)               // callee doesn't know about alignment adjustment
                genstackclean(cdb,numalign,retregs);
        }
    }

    /* Special handling for functions that return one part
       in XMM0 and the other part in AX
     */
    if (pretregs && retregs)
    {
        if (reg1 == NOREG || reg2 == NOREG)
        {}
        else if ((0 == (mask(reg1) & XMMREGS)) ^ (0 == (mask(reg2) & XMMREGS)))
        {
            reg_t lreg, mreg;
            if (mask(reg1) & XMMREGS)
            {
                lreg = XMM0;
                mreg = XMM1;
            }
            else
            {
                lreg = mask(reg1) & mLSW ? reg1 : AX;
                mreg = mask(reg2) & mMSW ? reg2 : DX;
            }
            for (int v = 0; v < 2; v++)
            {
                if (v ^ (reg2 != lreg))
                    genmovreg(cdb,lreg,reg1);
                else
                    genmovreg(cdb,mreg,reg2);
            }
            retregs = mask(lreg) | mask(mreg);
        }
    }

    /* Special handling for functions which return complex float in XMM0 or RAX. */

    if (I64
        && config.exe != EX_WIN64 // broken
        && pretregs && tybasic(e.Ety) == TYcfloat)
    {
        assert(reg2 == NOREG);
        // spill
        if (config.exe == EX_WIN64)
        {
            assert(reg1 == AX);
            cdb.genfltreg(STO, reg1, 0);
            code_orrex(cdb.last(), REX_W);
        }
        else
        {
            assert(reg1 == XMM0);
            cdb.genxmmreg(xmmstore(TYdouble), reg1, 0, TYdouble);
        }
        // reload real
        push87(cdb);
        cdb.genfltreg(0xD9, 0, 0);
        genfwait(cdb);
        // reload imaginary
        push87(cdb);
        cdb.genfltreg(0xD9, 0, tysize(TYfloat));
        genfwait(cdb);

        retregs = mST01;
    }

    fixresult(cdb, e, retregs, pretregs);
}

/***************************
 * Generate code to move argument e on the stack.
 */

@trusted
private void movParams(ref CodeBuilder cdb, elem* e, uint stackalign, uint funcargtos, tym_t tyf)
{
    //printf("movParams(e = %p, stackalign = %d, funcargtos = %d)\n", e, stackalign, funcargtos);
    //printf("movParams()\n"); elem_print(e);
    assert(e && e.Eoper != OPparam);

    tym_t tym = tybasic(e.Ety);
    if (tyfloating(tym))
        objmod.fltused();

    targ_size_t szb = paramsize(e, tyf);          // size before alignment
    targ_size_t sz = _align(stackalign, szb);     // size after alignment
    assert((sz & (stackalign - 1)) == 0);         // ensure that alignment worked
    assert((sz & (REGSIZE - 1)) == 0);
    //printf("szb = %d sz = %d\n", cast(int)szb, cast(int)sz);

    switch (e.Eoper)
    {
        case OPstrctor:
        case OPstrthis:
        case OPstrpar:
        case OPnp_fp:
            assert(0);

        default:
            break;
    }
    regm_t retregs = cgstate.allregs;
    if (tyvector(tym) ||
        config.fpxmmregs && tyxmmreg(tym) &&
        // If not already in x87 register from function call return
        !((e.Eoper == OPcall || e.Eoper == OPucall) && I32))
    {
        retregs = XMMREGS;
        codelem(cgstate,cdb, e, retregs, false);
        const op = xmmstore(tym);
        const r = findreg(retregs);
        cdb.genc1(op, modregxrm(2, r - XMM0, BPRM), FLfuncarg, funcargtos - sz);   // MOV funcarg[EBP],r
        checkSetVex(cdb.last(),tym);
        return;
    }
    else if (tyfloating(tym))
    {
        assert(0);
    }
    scodelem(cgstate,cdb, e, retregs, 0, true);
    if (sz <= REGSIZE)
    {
        reg_t reg = findreg(retregs);
        code cs;
        cs.reg = NOREG;
        cs.base = 31;
        cs.index = NOREG;
        cs.IFL1 = FLunde;
        storeToEA(cs, reg, cast(uint)sz);
        cs.Iop = setField(cs.Iop,21,10,funcargtos >> field(cs.Iop,31,30));
        cdb.gen(&cs);
    }
    else if (sz == REGSIZE * 2)
    {
        int grex = I64 ? REX_W << 16 : 0;
        uint r = findregmsw(retregs);
        cdb.genc1(0x89, grex | modregxrm(2, r, BPRM), FLfuncarg, funcargtos - REGSIZE);    // MOV -REGSIZE[EBP],r
        r = findreglsw(retregs);
        cdb.genc1(0x89, grex | modregxrm(2, r, BPRM), FLfuncarg, funcargtos - REGSIZE * 2); // MOV -2*REGSIZE[EBP],r
        assert(0);
    }
    else
        assert(0);
}

/******************************
 * Generate code to load data into registers.
 * Called for OPconst and OPvar.
 */
@trusted
void loaddata(ref CodeBuilder cdb, elem* e, ref regm_t outretregs)
{
static if (1)
{
    reg_t reg;
    reg_t nreg;
    reg_t sreg;
    opcode_t op;
    tym_t tym;
    code cs;
    regm_t flags, forregs, regm;

    debug
    {
        if (debugw)
            printf("loaddata(e = %p,outretregs = %s)\n",e,regm_str(outretregs));
        //elem_print(e);
    }

    assert(e);
    elem_debug(e);
    if (outretregs == 0)
        return;
    tym = tybasic(e.Ety);
    if (tym == TYstruct)
    {
        cdrelconst(cgstate,cdb,e,outretregs);
        return;
    }
    if (tyfloating(tym))
    {
        objmod.fltused();
        if (config.fpxmmregs &&
            (tym == TYcfloat || tym == TYcdouble) &&
            (outretregs & (XMMREGS | mPSW))
           )
        {
            cloadxmm(cdb, e, outretregs);
            return;
        }
    }

    if (outretregs == mPSW)
    {
        regm_t retregs = cgstate.allregs;
        loaddata(cdb, e, retregs);
        fixresult(cdb, e, retregs, outretregs);
        return;
    }

    /* not for flags only */
    int sz = _tysize[tym];
    cs.Iflags = 0;
    flags = outretregs & mPSW;             /* save original                */
    forregs = outretregs & cgstate.allregs;     // XMMREGS ?
    //if (outretregs & mSTACK)
        //forregs |= DOUBLEREGS;
    if (e.Eoper == OPconst)
    {
        if (tyvector(tym) && forregs & XMMREGS)
        {
            assert(!flags);
            const xreg = allocreg(cdb, forregs, tym);     // allocate registers
            movxmmconst(cdb, xreg, tym, &e.EV, flags);
            fixresult(cdb, e, forregs, outretregs);
            return;
        }

        targ_size_t value = e.Vint;
        if (sz == 8)
            value = cast(targ_size_t)e.Vullong;

        if (sz == REGSIZE && reghasvalue(forregs, value, reg))
            forregs = mask(reg);

        regm_t save = cgstate.regcon.immed.mval;
        reg = allocreg(cdb, forregs, tym);        // allocate registers
        cgstate.regcon.immed.mval = save;               // allocreg could unnecessarily clear .mval
        if (sz <= REGSIZE)
        {
            if (sz == 1)
                flags |= 1;
            else if (!I16 && sz == SHORTSIZE &&
                     !(mask(reg) & cgstate.regcon.mvar) &&
                     !(config.flags4 & CFG4speed)
                    )
                flags |= 2;
            if (sz == 8)
                flags |= 64;
            if (isXMMreg(reg))
            {
                movxmmconst(cdb, reg, tym, &e.EV, 0);
                flags = 0;
            }
            else
            {
                movregconst(cdb, reg, value, flags);
                flags = 0;                          // flags are already set
            }
        }
        else if (sz == 16)
        {
            movregconst(cdb, findreglsw(forregs), cast(targ_size_t)e.Vcent.lo, 64);
            movregconst(cdb, findregmsw(forregs), cast(targ_size_t)e.Vcent.hi, 64);
        }
        else
            assert(0);
        // Flags may already be set
        outretregs &= flags | ~mPSW;
        fixresult(cdb, e, forregs, outretregs);
        return;
    }
    else
    {
        // See if we can use register that parameter was passed in
        //printf("xyzzy1 %s %d %d\n", e.Vsym.Sident.ptr, cast(int)cgstate.regcon.params, regParamInPreg(e.Vsym));
        if (cgstate.regcon.params &&
            regParamInPreg(*e.Vsym) &&
            !cgstate.anyiasm &&   // may have written to the memory for the parameter
            (cgstate.regcon.params & mask(e.Vsym.Spreg) && e.Voffset == 0 ||
             cgstate.regcon.params & mask(e.Vsym.Spreg2) && e.Voffset == REGSIZE) &&
            sz <= REGSIZE)                  // make sure no 'paint' to a larger size happened
        {
            const reg_t preg = e.Voffset ? e.Vsym.Spreg2 : e.Vsym.Spreg;
            const regm_t pregm = mask(preg);

            if (!(sz <= 2 && pregm & XMMREGS))   // no SIMD instructions to load 1 or 2 byte quantities
            {
                if (debugr)
                    printf("%s.%d is fastpar and using register %s\n",
                           e.Vsym.Sident.ptr,
                           cast(int)e.Voffset,
                           regm_str(pregm));

                cgstate.mfuncreg &= ~pregm;
                cgstate.regcon.used |= pregm;
                fixresult(cdb,e,pregm,outretregs);
                return;
            }
        }

        reg = allocreg(cdb, forregs, tym);            // allocate registers

        if (sz == 1)
        {   regm_t nregm;

            debug
            if (!(forregs & BYTEREGS))
            {
                elem_print(e);
                printf("forregs = %s\n", regm_str(forregs));
            }

            opcode_t opmv = 0x8A;                               // byte MOV
            if (config.exe & (EX_OSX | EX_OSX64))
            {
                if (movOnly(e))
                    opmv = 0x8B;
            }
            assert(forregs & BYTEREGS);
            if (!I16)
            {
                if (config.target_cpu >= TARGET_PentiumPro && config.flags4 & CFG4speed &&
                    // Workaround for OSX linker bug:
                    //   ld: GOT load reloc does not point to a movq instruction in test42 for x86_64
                    !(config.exe & EX_OSX64 && !(sytab[e.Vsym.Sclass] & SCSS))
                   )
                {
//                    opmv = tyuns(tym) ? MOVZXb : MOVSXb;      // MOVZX/MOVSX
                }
                loadea(cdb, e, cs, opmv, reg, 0, 0, 0);     // MOV regL,data
            }
            else
            {
                nregm = tyuns(tym) ? BYTEREGS : cast(regm_t) mAX;
                if (outretregs & nregm)
                    nreg = reg;                             // already allocated
                else
                    nreg = allocreg(cdb, nregm, tym);
                loadea(cdb, e, cs, opmv, nreg, 0, 0, 0);    // MOV nregL,data
                if (reg != nreg)
                {
                    genmovreg(cdb, reg, nreg);   // MOV reg,nreg
                    cssave(e, mask(nreg), false);
                }
            }
        }
        else if (forregs & XMMREGS)
        {
            // Can't load from registers directly to XMM regs
            //e.Vsym.Sflags &= ~GTregcand;

            opcode_t opmv = xmmload(tym, xmmIsAligned(e));
            if (e.Eoper == OPvar)
            {
                Symbol *s = e.Vsym;
                if (s.Sfl == FLreg && !(mask(s.Sreglsw) & XMMREGS))
                {   //opmv = LODD;          // MOVD/MOVQ
                    /* getlvalue() will unwind this and unregister s; could use a better solution */
                }
            }
            loadea(cdb, e, cs, opmv, reg, 0, 0, 0, RM.load); // MOVSS/MOVSD reg,data
            checkSetVex(cdb.last(),tym);
        }
        else if (sz <= REGSIZE)
        {
            // LDR reg,[sp,#offset]
            // https://www.scs.stanford.edu/~zyedidia/arm64/ldr_imm_gen.html
            opcode_t opmv = PSOP.ldr | (29 << 5);
            loadea(cdb, e, cs, opmv, reg, 0, 0, 0, RM.load);
        }
        else if (sz <= 2 * REGSIZE)
        {
            reg = findregmsw(forregs);
            loadea(cdb, e, cs, 0x8B, reg, REGSIZE, forregs, 0); // MOV reg,data+2
            reg = findreglsw(forregs);
            loadea(cdb, e, cs, 0x8B, reg, 0, forregs, 0);       // MOV reg,data
        }
        else if (sz >= 8)
        {
            if ((outretregs & (mSTACK | mPSW)) == mSTACK)
            {
                // Note that we allocreg(DOUBLEREGS) needlessly
                cgstate.stackchanged = 1;
                int i = sz - REGSIZE;
                do
                {
                    loadea(cdb,e,cs,0xFF,6,i,0,0); // PUSH EA+i
                    cdb.genadjesp(REGSIZE);
                    cgstate.stackpush += REGSIZE;
                    i -= REGSIZE;
                }
                while (i >= 0);
                return;
            }
            else
            {
                assert(0);
            }
        }
        else
            assert(0);
        // Flags may already be set
        outretregs &= flags | ~mPSW;
        fixresult(cdb, e, forregs, outretregs);
        return;
    }
}
}
