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
import dmd.backend.arm.cod3 : COND, genBranch, conditionCode;
import dmd.backend.arm.instr;

import dmd.backend.cg : segfl, stackfl;

nothrow:
@safe:

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
        codelem(cgstate,cdb,e,&retregs,0);
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
    codelem(cgstate,cdb, e, &retregs, true);         // evaluate elem
    if (no87)
        cse_flush(cdb,no87);              // flush CSE's to memory
    genBranch(cdb, cond, fltarg, cast(block *) targ); // generate jmp instruction
    cgstate.stackclean--;
}

/******************************
 * Routine to aid in setting things up for gen().
 * Look for common subexpression.
 * Can handle indirection operators, but not if they're common subs.
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
    if (e.Ecount &&                      /* if cse                       */
        e.Ecount != e.Ecomsub)           /* and cse was generated        */
    {
        assert(OTleaf(e.Eoper));                /* can't handle this            */
        regm_t rm = cgstate.regcon.cse.mval & ~cgstate.regcon.cse.mops & ~cgstate.regcon.mvar; // possible regs
        if (sz == REGSIZE * 2)          // value is in 2
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
                    // need to change cs.Iop to a MOV reg,i
                    assert(0);
                    // XXX reg,i
                    //cs.Irm = modregrm(3, reg & 7, i & 7);
                    //goto L2;
                }
                rm &= ~mask(i);
            }
        }
    }

    getlvalue(cdb, cs, e, keepmsk, rmx);
    if (offset == REGSIZE)
        getlvalue_msw(cs);
    else
        cs.IEV1.Voffset += offset;
    cs.Iop |= reg;                         // destination register
L2:
    getregs(cdb, desmsk);                  // save any regs we destroy

    // Eliminate MOV reg,reg
    static if (0)
    if ((cs.Iop & ~3) == 0x88 &&
        (cs.Irm & 0xC7) == modregrm(3,0,reg & 7))
    {
        uint r = cs.Irm & 7;
        if (cs.Irex & REX_B)
            r |= 8;
        if (r == reg)
            cs.Iop = NOP;
    }

    // Eliminate MOV xmmreg,xmmreg
    static if (0)
    if ((cs.Iop & ~(LODSD ^ STOSS)) == LODSD &&    // detect LODSD, LODSS, STOSD, STOSS
        (cs.Irm & 0xC7) == modregrm(3,0,reg & 7))
    {
        reg_t r = cs.Irm & 7;
        if (cs.Irex & REX_B)
            r |= 8;
        if (r == (reg - XMM0))
            cs.Iop = NOP;
    }

    cdb.gen(&cs);
}

// uint getaddrmode
// void setaddrmode
// getlvalue_msw
// getlvalue_lsw

/******************
 * Compute addressing mode.
 * Generate & return sequence of code (if any).
 * Return in cs the info on it.
 * Params:
 *      cdb = sink for any code generated
 *      pcs = set to addressing mode
 *      e   = the lvalue elem
 *      keepmsk = mask of registers we must not destroy or use
 *      rm = RM.store a store operation into the lvalue only
 *           RM.load a read operation from the lvalue only
 *           RM.rw load and store
 */

@trusted
void getlvalue(ref CodeBuilder cdb,ref code pcs,elem *e,regm_t keepmsk,RM rm = RM.rw)
{
    FL fl;
    uint f, opsave;
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
    }
    else
        fl = FLoper;
    pcs.IFL1 = cast(ubyte)fl;
    pcs.Iflags = CFoff;                  /* only want offsets            */
    pcs.Irex = 0;
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
static if (0)
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
            f = FLconst;

            /* Is address of `s` relative to RIP ?
             */
            static bool relativeToRIP(Symbol* s)
            {
                if (!I64)
                    return false;
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

            if (e1isadd &&
                ((e12.Eoper == OPrelconst &&
                  !relativeToRIP(e12.Vsym) &&
                  (f = el_fl(e12)) != FLfardata
                 ) ||
                 (e12.Eoper == OPconst && !I16 && !e1.Ecount && (!I64 || el_signx32(e12)))) &&
                e1.Ecount == e1.Ecomsub &&
                (!e1.Ecount || (~keepmsk & ALLREGS & mMSW) || (e1ty != TYfptr && e1ty != TYhptr)) &&
                tysize(e11.Ety) == REGSIZE
               )
            {
                uint t;            /* component of r/m field */
                int ss;
                int ssi;

                if (e12.Eoper == OPrelconst)
                    f = el_fl(e12);
                /*assert(datafl[f]);*/              /* what if addr of func? */
                if (!I16)
                {   /* Any register can be an index register        */
                    regm_t idxregs = cgstate.allregs & ~keepmsk;
                    assert(idxregs);

                    /* See if e1.E1 can be a scaled index  */
                    ss = isscaledindex(e11);
                    if (ss)
                    {
                        /* Load index register with result of e11.E1       */
                        cdisscaledindex(cdb, e11, &idxregs, keepmsk);
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
                        scodelem(cgstate,cdb, e11.E1, &idxregs, keepmsk, true);
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
                                if (rbase == BP || rbase == R13)
                                {
                                    static immutable uint[4] imm32 = [1+1,2+1,4+1,8+1];

                                    // IMUL r,BP,imm32
                                    cdb.genc2(0x69, modregxrmx(3, r, rbase), imm32[ss1]);
                                    goto L7;
                                }
                            }

                            cdb.gen2sib(LEA, modregxrm(t, r, 4), modregrm(ss1, reg & 7 ,rbase & 7));
                            if (reg & 8)
                                code_orrex(cdb.last(), REX_X);
                            if (rbase & 8)
                                code_orrex(cdb.last(), REX_B);
                            if (I64)
                                code_orrex(cdb.last(), REX_W);

                            if (ssflags & SSFLnobase1)
                            {
                                cdb.last().IFL1 = FLconst;
                                cdb.last().IEV1.Vuns = 0;
                            }
                        L7:
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
                        scodelem(cgstate,cdb, e11, &idxregs, keepmsk, true);
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
                }
                else
                {
                    regm_t idxregs = IDXREGS & ~keepmsk;   /* only these can be index regs */
                    assert(idxregs);
                    if (stackfl[f])                 /* if stack data type   */
                    {
                        idxregs &= mSI | mDI;       /* BX can't index off stack */
                        if (!idxregs) goto L1;      /* index regs aren't avail */
                        t = 6;                      /* [BP+SI+disp]         */
                    }
                    else
                        t = 0;                      /* [SI + disp]          */
                    scodelem(cgstate,cdb, e11, &idxregs, keepmsk, true); // load idx reg
                    pcs.Irm = cast(ubyte)(getaddrmode(idxregs) ^ t);
                }
                if (f == FLpara)
                    cgstate.refparam = true;
                else if (f == FLauto || f == FLbprel || f == FLfltreg || f == FLfast)
                    cgstate.reflocal = true;
                else if (f == FLcsdata || tybasic(e12.Ety) == TYcptr)
                    pcs.Iflags |= CFcs;
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
                    uint flagsave;

                    regm_t idxregs = IDXREGS & ~keepmsk;
                    reg = allocreg(cdb, idxregs, TYoffset);

                    /* If desired result is a far pointer, we'll have       */
                    /* to load another register with the segment of v       */
                    if (e1ty == TYfptr)
                    {
                        idxregs |= mMSW & ALLREGS & ~keepmsk;
                        allocreg(cdb, idxregs, TYfptr);
                        const msreg = findregmsw(idxregs);
                                                    /* MOV msreg,segreg     */
                        genregs(cdb, 0x8C, segfl[f], msreg);
                    }
                    opsave = pcs.Iop;
                    flagsave = pcs.Iflags;
                    ubyte rexsave = pcs.Irex;
                    pcs.Iop = LEA;
                    code_newreg(pcs, reg);
                    if (!I16)
                        pcs.Iflags &= ~CFopsize;
                    if (I64)
                        pcs.Irex |= REX_W;
                    cdb.gen(pcs);                 // LEA idxreg,EA
                    cssave(e1,idxregs,true);
                    if (!I16)
                    {
                        pcs.Iflags = flagsave;
                        pcs.Irex = rexsave;
                    }
                    if (stackfl[f] && (config.wflags & WFssneds))   // if pointer into stack
                        pcs.Iflags |= CFss;        // add SS: override
                    pcs.Iop = opsave;
                    pcs.IFL1 = FLoffset;
                    pcs.IEV1.Vuns = 0;
                    setaddrmode(pcs, idxregs);
                }
                freenode(e12);
                if (e1free)
                    freenode(e1);
                return Lptr();
            }

            L1:

            /* The rest of the cases could be a far pointer */

            regm_t idxregs;
            idxregs = (I16 ? IDXREGS : cgstate.allregs) & ~keepmsk; // only these can be index regs
            assert(idxregs);
            if (!I16 &&
                (sz == REGSIZE || (I64 && sz == 4)) &&
                rm == RM.store)
                idxregs |= cgstate.regcon.mvar;

            switch (e1ty)
            {
                case TYfptr:                        /* if far pointer       */
                case TYhptr:
                    idxregs = (mES | IDXREGS) & ~keepmsk;   // need segment too
                    assert(idxregs & mES);
                    pcs.Iflags |= CFes;            /* ES segment override  */
                    break;

                case TYsptr:                        /* if pointer to stack  */
                    if (config.wflags & WFssneds)   // if SS != DS
                        pcs.Iflags |= CFss;        /* then need SS: override */
                    break;

                case TYfgPtr:
                    if (I32)
                        pcs.Iflags |= CFgs;
                    else if (I64)
                        pcs.Iflags |= CFfs;
                    else
                        assert(0);
                    break;

                case TYcptr:                        /* if pointer to code   */
                    pcs.Iflags |= CFcs;            /* then need CS: override */
                    break;

                default:
                    break;
            }
            pcs.IFL1 = FLoffset;
            pcs.IEV1.Vuns = 0;

            /* see if we can replace *(e+c) with
             *      MOV     idxreg,e
             *      [MOV    ES,segment]
             *      EA =    [ES:]c[idxreg]
             */
            if (e1isadd && e12.Eoper == OPconst &&
                (!I64 || el_signx32(e12)) &&
                (tysize(e12.Ety) == REGSIZE || (I64 && tysize(e12.Ety) == 4)) &&
                (!e1.Ecount || !e1free)
               )
            {
                int ss;

                pcs.IEV1.Vuns = e12.Vuns;
                freenode(e12);
                if (e1free) freenode(e1);
                if (!I16 && e11.Eoper == OPadd && !e11.Ecount &&
                    tysize(e11.Ety) == REGSIZE)
                {
                    e12 = e11.E2;
                    e11 = e11.E1;
                    e1 = e1.E1;
                    e1free = true;
                    goto L4;
                }
                if (!I16 && (ss = isscaledindex(e11)) != 0)
                {   // (v * scale) + const
                    cdisscaledindex(cdb, e11, &idxregs, keepmsk);
                    reg = findreg(idxregs);
                    pcs.Irm = modregrm(0, 0, 4);
                    pcs.Isib = modregrm(ss, reg & 7, 5);
                    if (reg & 8)
                        pcs.Irex |= REX_X;
                }
                else
                {
                    scodelem(cgstate,cdb, e11, &idxregs, keepmsk, true); // load index reg
                    setaddrmode(pcs, idxregs);
                }
                return Lptr();
            }

            /* Look for *(v1 + v2)
             *      EA = [v1][v2]
             */

            if (!I16 && e1isadd && (!e1.Ecount || !e1free) &&
                (_tysize[e1ty] == REGSIZE || (I64 && _tysize[e1ty] == 4)))
            {
            L4:
                regm_t idxregs2;
                uint base, index;

                // Look for *(v1 + v2 << scale)
                int ss = isscaledindex(e12);
                if (ss)
                {
                    scodelem(cgstate,cdb, e11, &idxregs, keepmsk, true);
                    idxregs2 = cgstate.allregs & ~(idxregs | keepmsk);
                    cdisscaledindex(cdb, e12, &idxregs2, keepmsk | idxregs);
                }

                // Look for *(v1 << scale + v2)
                else if ((ss = isscaledindex(e11)) != 0)
                {
                    idxregs2 = idxregs;
                    cdisscaledindex(cdb, e11, &idxregs2, keepmsk);
                    idxregs = cgstate.allregs & ~(idxregs2 | keepmsk);
                    scodelem(cgstate,cdb, e12, &idxregs, keepmsk | idxregs2, true);
                }
                // Look for *(((v1 << scale) + c1) + v2)
                else if (e11.Eoper == OPadd && !e11.Ecount &&
                         e11.E2.Eoper == OPconst &&
                         (ss = isscaledindex(e11.E1)) != 0
                        )
                {
                    pcs.IEV1.Vuns = e11.E2.Vuns;
                    idxregs2 = idxregs;
                    cdisscaledindex(cdb, e11.E1, &idxregs2, keepmsk);
                    idxregs = cgstate.allregs & ~(idxregs2 | keepmsk);
                    scodelem(cgstate,cdb, e12, &idxregs, keepmsk | idxregs2, true);
                    freenode(e11.E2);
                    freenode(e11);
                }
                else
                {
                    scodelem(cgstate,cdb, e11, &idxregs, keepmsk, true);
                    idxregs2 = cgstate.allregs & ~(idxregs | keepmsk);
                    scodelem(cgstate,cdb, e12, &idxregs2, keepmsk | idxregs, true);
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
            scodelem(cgstate,cdb, e1, &idxregs, keepmsk, true);  // load index register
            setaddrmode(pcs, idxregs);

            return Lptr();
}
        case FLdatseg:
            assert(0);
        static if (0)
        {
            pcs.Irm = modregrm(0, 0, BPRM);
            pcs.IEVpointer1 = e.EVpointer;
            break;
        }

        case FLfltreg:
            cgstate.reflocal = true;
            pcs.Irm = modregrm(2, 0, BPRM);
            pcs.IEV1.Vint = 0;
            break;

        case FLreg:
            goto L2;

        case FLpara:
            if (s.Sclass == SC.shadowreg)
                goto case FLfast;
        Lpara:
            cgstate.refparam = true;
            pcs.Irm = modregrm(2, 0, BPRM);
            goto L2;

        case FLauto:
        case FLfast:
            if (regParamInPreg(s))
            {
                regm_t pregm = s.Spregm();
                /* See if the parameter is still hanging about in a register,
                 * and so can we load from that register instead.
                 */
                if (cgstate.regcon.params & pregm /*&& s.Spreg2 == NOREG && !(pregm & XMMREGS)*/)
                {
                    if (rm == RM.load && !cgstate.anyiasm)
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
                                    pcs.Irm = modregrm(3, 0, preg & 7);
                                    if (preg & 8)
                                        pcs.Irex |= REX_B;
                                    if (I64 && sz == 1 && preg >= 4)
                                        pcs.Irex |= REX;
                                    cgstate.regcon.used |= mask(preg);
                                    break;
                                }
                                else if (voffset == 1 && sz == 1 && preg < 4)
                                {
                                    pcs.Irm = modregrm(3, 0, 4 | preg); // use H register
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
            pcs.Iop |= cgstate.BP << 5;
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
            if (s.ty() & mTYcs && cast(bool) LARGECODE)
                goto Lfardata;
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
            pcs.Irm = modregrm(0, 0, BPRM);
        L2:
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
                pcs.Irm = modregrm(3, 0, s.Sreglsw & 7);
                if (s.Sreglsw & 8)
                    pcs.Irex |= REX_B;
                if (e.Voffset == REGSIZE && sz == REGSIZE)
                {
                    pcs.Irm = modregrm(3, 0, s.Sregmsw & 7);
                    if (s.Sregmsw & 8)
                        pcs.Irex |= REX_B;
                    else
                        pcs.Irex &= ~REX_B;
                }
                else if (e.Voffset == 1 && sz == 1)
                {
                    assert(s.Sregm & BYTEREGS);
                    assert(s.Sreglsw < 4);
                    pcs.Irm |= 4;                  // use 2nd byte of register
                }
                else
                {
                    assert(!e.Voffset);
                    if (I64 && sz == 1 && s.Sreglsw >= 4)
                        pcs.Irex |= REX;
                }
            }
            else if (s.ty() & mTYcs && !(fl == FLextern && LARGECODE))
            {
                pcs.Iflags |= CFcs | CFoff;
            }
            if (config.flags3 & CFG3pic &&
                (fl == FLtlsdata || s.ty() & mTYthread))
            {
                if (I32)
                {
                    if (config.flags3 & CFG3pie)
                    {
                        pcs.Iflags |= CFgs;
                    }
                }
                else if (I64)
                {
                    if (config.flags3 & CFG3pie &&
                        (s.Sclass == SC.global || s.Sclass == SC.static_ || s.Sclass == SC.locstat))
                    {
                        pcs.Iflags |= CFfs;
                        pcs.Irm = modregrm(0, 0, 4);
                        pcs.Isib = modregrm(0, 4, 5);  // don't use [RIP] addressing
                    }
                    else
                    {
                        //pcs.Iflags |= CFopsize; //I don't know what this was for
                        pcs.Irex = 0x48;
                    }
                }
            }
            pcs.IEV1.Vsym = s;
            pcs.IEV1.Voffset = e.Voffset;
            if (sz == 1)
            {   /* Don't use SI or DI for this variable     */
                s.Sflags |= GTbyte;
                if (I64 ? e.Voffset > 0 : e.Voffset > 1)
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

            if (rm != RM.store)                    // if not store only
                s.Sflags |= SFLread;               // assume we are doing a read
            break;

        case FLpseudo:
            {
                getregs(cdb, mask(s.Sreglsw));
                pcs.Irm = modregrm(3, 0, s.Sreglsw & 7);
                if (s.Sreglsw & 8)
                    pcs.Irex |= REX_B;
                if (e.Voffset == 1 && sz == 1)
                {   assert(s.Sregm & BYTEREGS);
                    assert(s.Sreglsw < 4);
                    pcs.Irm |= 4;                  // use 2nd byte of register
                }
                else
                {   assert(!e.Voffset);
                    if (I64 && sz == 1 && s.Sreglsw >= 4)
                        pcs.Irex |= REX;
                }
                break;
            }

        case FLfardata:
        case FLfunc:                                /* reading from code seg */
            if (config.exe & EX_flat)
                goto L3;
        Lfardata:
        {
            regm_t regm = ALLREGS & ~keepmsk;       // need scratch register
            reg = allocreg(cdb, regm, TYint);
            getregs(cdb,mES);
            // MOV mreg,seg of symbol
            cdb.gencs(0xB8 + reg, 0, FLextern, s);
            cdb.last().Iflags = CFseg;
            cdb.gen2(0x8E, modregrmx(3, 0, reg));     // MOV ES,reg
            pcs.Iflags |= CFes | CFoff;            /* ES segment override  */
            goto L3;
        }

        case FLstack:
            assert(!I16);
            pcs.Irm = modregrm(2, 0, 4);
            pcs.Isib = modregrm(0, 4, SP);
            pcs.IEV1.Vsym = s;
            pcs.IEV1.Voffset = e.Voffset;
            break;

        default:
            symbol_print(*s);
            assert(0);
    }
}

// fltregs
// tstresult

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
    regm_t forregs = outretregs & (mST01 | mST0 | mBP | ALLREGS | mES | mSTACK | XMMREGS);
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
            reg = findreg(retregs & (mBP | ALLREGS));
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
// funccall
// offsetinreg

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
        cdrelconst(cgstate,cdb,e,&outretregs);
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
            cloadxmm(cdb, e, &outretregs);
            return;
        }
    }
    int sz = _tysize[tym];
    cs.Iflags = 0;
    if (outretregs == mPSW)
    {
        Symbol *s;
        regm = cgstate.allregs;
        if (e.Eoper == OPconst)
        {       /* true:        OR SP,SP        (SP is never 0)         */
                /* false:       CMP SP,SP       (always equal)          */
                genregs(cdb, (boolres(e)) ? 0x09 : 0x39 , SP, SP);
                if (I64)
                    code_orrex(cdb.last(), REX_W);
        }
        else if (e.Eoper == OPvar &&
            (s = e.Vsym).Sfl == FLreg &&
            s.Sregm & XMMREGS &&
            (tym == TYfloat || tym == TYifloat || tym == TYdouble || tym ==TYidouble))
        {
            /* Evaluate using XMM register and XMM instruction.
             * This affects jmpopcode()
             */
            if (s.Sclass == SC.parameter)
                cgstate.refparam = true;
            tstresult(cdb,s.Sregm,e.Ety,true);
        }
        else if (sz <= REGSIZE)
        {
            if (!I16 && (tym == TYfloat || tym == TYifloat))
            {
                reg = allocreg(cdb, regm, TYoffset);   // get a register
                loadea(cdb, e, cs, 0x8B, reg, 0, 0, 0);    // MOV reg,data
                cdb.gen2(0xD1,modregrmx(3,4,reg));           // SHL reg,1
            }
            else if (I64 && (tym == TYdouble || tym ==TYidouble))
            {
                reg = allocreg(cdb, regm, TYoffset);   // get a register
                loadea(cdb, e, cs, 0x8B, reg, 0, 0, 0);    // MOV reg,data
                // remove sign bit, so that -0.0 == 0.0
                cdb.gen2(0xD1, modregrmx(3, 4, reg));           // SHL reg,1
                code_orrex(cdb.last(), REX_W);
            }
            else if (TARGET_OSX && e.Eoper == OPvar && movOnly(e))
            {
                reg = allocreg(cdb, regm, TYoffset);   // get a register
                loadea(cdb, e, cs, 0x8B, reg, 0, 0, 0);    // MOV reg,data
                fixresult(cdb, e, regm, outretregs);
            }
            else
            {   cs.IFL2 = FLconst;
                cs.IEV2.Vsize_t = 0;
                op = (sz == 1) ? 0x80 : 0x81;
                loadea(cdb, e, cs, op, 7, 0, 0, 0);        // CMP EA,0

                // Convert to TEST instruction if EA is a register
                // (to avoid register contention on Pentium)
                code *c = cdb.last();
                if ((c.Iop & ~1) == 0x38 &&
                    (c.Irm & modregrm(3, 0, 0)) == modregrm(3, 0, 0)
                   )
                {
                    c.Iop = (c.Iop & 1) | 0x84;
                    code_newreg(c, c.Irm & 7);
                    if (c.Irex & REX_B)
                        //c.Irex = (c.Irex & ~REX_B) | REX_R;
                        c.Irex |= REX_R;
                }
            }
        }
        else if (sz < 8)
        {
            reg = allocreg(cdb, regm, TYoffset);  // get a register
            if (I32)                                    // it's a 48 bit pointer
                loadea(cdb, e, cs, MOVZXw, reg, REGSIZE, 0, 0); // MOVZX reg,data+4
            else
            {
                loadea(cdb, e, cs, 0x8B, reg, REGSIZE, 0, 0); // MOV reg,data+2
                if (tym == TYfloat || tym == TYifloat)       // dump sign bit
                    cdb.gen2(0xD1, modregrm(3, 4, reg));        // SHL reg,1
            }
            loadea(cdb,e,cs,0x0B,reg,0,regm,0);     // OR reg,data
        }
        else if (sz == 8 || (I64 && sz == 2 * REGSIZE && !tyfloating(tym)))
        {
            reg = allocreg(cdb, regm, TYoffset);       // get a register
            int i = sz - REGSIZE;
            loadea(cdb, e, cs, 0x8B, reg, i, 0, 0);        // MOV reg,data+6
            if (tyfloating(tym))                             // TYdouble or TYdouble_alias
                cdb.gen2(0xD1, modregrm(3, 4, reg));            // SHL reg,1

            while ((i -= REGSIZE) >= 0)
            {
                loadea(cdb, e, cs, 0x0B, reg, i, regm, 0); // OR reg,data+i
                code *c = cdb.last();
                if (i == 0)
                    c.Iflags |= CFpsw;                      // need the flags on last OR
            }
        }
        else if (sz == tysize(TYldouble))               // TYldouble
            load87(cdb, e, 0, outretregs, null, -1);
        else
        {
            elem_print(e);
            assert(0);
        }
        return;
    }
    /* not for flags only */
    flags = outretregs & mPSW;             /* save original                */
    forregs = outretregs & (mBP | ALLREGS | mES | XMMREGS);
    if (outretregs & mSTACK)
        forregs |= DOUBLEREGS;
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
        else if (sz < 8)        // far pointers, longs for 16 bit targets
        {
            targ_int msw = I32 ? e.Vseg
                        : (e.Vulong >> 16);
            targ_int lsw = e.Voff;
            regm_t mswflags = 0;
            if (forregs & mES)
            {
                movregconst(cdb, reg, msw, 0); // MOV reg,segment
                genregs(cdb, 0x8E, 0, reg);    // MOV ES,reg
                msw = lsw;                               // MOV reg,offset
            }
            else
            {
                sreg = findreglsw(forregs);
                movregconst(cdb, sreg, lsw, 0);
                reg = findregmsw(forregs);
                /* Decide if we need to set flags when we load msw      */
                if (flags && (msw && msw|lsw || !(msw|lsw)))
                {   mswflags = mPSW;
                    flags = 0;
                }
            }
            movregconst(cdb, reg, msw, mswflags);
        }
        else if (sz == 8)
        {
            if (I32)
            {
                targ_long *p = cast(targ_long *)cast(void*)&e.Vdouble;
                if (isXMMreg(reg))
                {   /* This comes about because 0, 1, pi, etc., constants don't get stored
                     * in the data segment, because they are x87 opcodes.
                     * Not so efficient. We should at least do a PXOR for 0.
                     */
                    regm_t rm = ALLREGS;
                    const r = allocreg(cdb, rm, TYint);    // allocate scratch register
                    movregconst(cdb, r, p[0], 0);
                    cdb.genfltreg(0x89, r, 0);               // MOV floatreg,r
                    movregconst(cdb, r, p[1], 0);
                    cdb.genfltreg(0x89, r, 4);               // MOV floatreg+4,r

                    const opmv = xmmload(tym);
                    cdb.genxmmreg(opmv, reg, 0, tym);           // MOVSS/MOVSD XMMreg,floatreg
                }
                else
                {
                    movregconst(cdb, findreglsw(forregs) ,p[0], 0);
                    movregconst(cdb, findregmsw(forregs) ,p[1], 0);
                }
            }
            else
            {   targ_short *p = &e.Vshort;  // point to start of Vdouble

                assert(reg == AX);
                movregconst(cdb, AX, p[3], 0);   // MOV AX,p[3]
                movregconst(cdb, DX, p[0], 0);
                movregconst(cdb, CX, p[1], 0);
                movregconst(cdb, BX, p[2], 0);
            }
        }
        else if (I64 && sz == 16)
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
            regParamInPreg(e.Vsym) &&
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
            uint size = 2; // 32 bit
            uint VR = 0;
            uint opc = 1;
            opcode_t opmv = (size << 30) |
                            (7    << 27) |
                            (VR   << 26) |
                            (1    << 24) |
                            (opc  << 22) |
                            0;
            loadea(cdb, e, cs, opmv, reg, 0, 0, 0, RM.load);
        }
        else if (sz <= 2 * REGSIZE && forregs & mES)
        {
            loadea(cdb, e, cs, 0xC4, reg, 0, 0, mES);    // LES data
        }
        else if (sz <= 2 * REGSIZE)
        {
            if (I32 && sz == 8 &&
                (outretregs & (mSTACK | mPSW)) == mSTACK)
            {
                assert(0);
    /+
                /* Note that we allocreg(DOUBLEREGS) needlessly     */
                cgstate.stackchanged = 1;
                int i = DOUBLESIZE - REGSIZE;
                do
                {
                    loadea(cdb,e,cs,0xFF,6,i,0,0); // PUSH EA+i
                    cdb.genadjesp(REGSIZE);
                    cgstate.stackpush += REGSIZE;
                    i -= REGSIZE;
                }
                while (i >= 0);
                return;
    +/
            }

            reg = findregmsw(forregs);
            loadea(cdb, e, cs, 0x8B, reg, REGSIZE, forregs, 0); // MOV reg,data+2
            if (I32 && sz == REGSIZE + 2)
                cdb.last().Iflags |= CFopsize;                   // seg is 16 bits
            reg = findreglsw(forregs);
            loadea(cdb, e, cs, 0x8B, reg, 0, forregs, 0);       // MOV reg,data
        }
        else if (sz >= 8)
        {
            assert(!I32);
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
                assert(reg == AX);
                loadea(cdb, e, cs, 0x8B, AX, 6, 0,           0); // MOV AX,data+6
                loadea(cdb, e, cs, 0x8B, BX, 4, mAX,         0); // MOV BX,data+4
                loadea(cdb, e, cs, 0x8B, CX, 2, mAX|mBX,     0); // MOV CX,data+2
                loadea(cdb, e, cs, 0x8B, DX, 0, mAX|mCX|mCX, 0); // MOV DX,data
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
