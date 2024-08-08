/**
 * Code generation 4
 *
 * Includes:
 * - assignemt variations of operators (+= -= *= /= %= <<= >>=)
 * - integer comparison (< > <= >=)
 * - converting integers to a different size (e.g. short to int)
 * - bit instructions (bit scan, population count)
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Mostly code generation for assignment operators.
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/arm/cod4.d, backend/cod4.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_arm_cod4.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/arm/cod4.d
 */

module dmd.backend.arm.cod4;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.cg : datafl;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.codebuilder;
import dmd.backend.divcoeff : choose_multiplier, udiv_coefficients;
import dmd.backend.mem;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.oper;
import dmd.backend.ty;
import dmd.backend.evalu8 : el_toldoubled;
import dmd.backend.x86.xmm;
import dmd.backend.arm.cod1 : getlvalue, loadFromEA, storeToEA;
import dmd.backend.arm.cod3 : COND, conditionCode, gentstreg;
import dmd.backend.arm.instr;


nothrow:
@safe:

/************************
 * Generate code for an assignment, OPeq.
 */
@trusted
void cdeq(ref CGstate cg, ref CodeBuilder cdb,elem *e,ref regm_t pretregs)
{
    //printf("cdeq(e = %p, pretregs = %s)\n",e,regm_str(pretregs));
    //elem_print(e);

    reg_t reg;
    code cs;
    elem *e11;
    bool regvar;                  // true means evaluate into register variable
    regm_t varregm = 0;
    reg_t varreg;
    targ_int postinc;

    elem *e1 = e.E1;
    elem *e2 = e.E2;
    int e2oper = e2.Eoper;
    tym_t tyml = tybasic(e1.Ety);              // type of lvalue
    regm_t retregs = pretregs;

    if (tyxmmreg(tyml) && config.fpxmmregs)
    {
        xmmeq(cdb, e, CMP, e1, e2, pretregs);
        return;
    }

    if (tyfloating(tyml) && config.inline8087)
    {
        if (tycomplex(tyml))
        {
            complex_eq87(cdb, e, pretregs);
            return;
        }

        if (!(retregs == 0 &&
              (e2oper == OPconst || e2oper == OPvar || e2oper == OPind))
           )
        {
            eq87(cdb,e,pretregs);
            return;
        }
        if (config.target_cpu >= TARGET_PentiumPro &&
            (e2oper == OPvar || e2oper == OPind)
           )
        {
            eq87(cdb,e,pretregs);
            return;
        }
        if (tyml == TYldouble || tyml == TYildouble)
        {
            eq87(cdb,e,pretregs);
            return;
        }
    }

    uint sz = _tysize[tyml];           // # of bytes to transfer
    assert(cast(int)sz > 0);

    if (retregs == 0)                     // if no return value
    {
        /* If registers are tight, and we might need them for the lvalue,
         * prefer to not use them for the rvalue
         */
        bool plenty = true;
        if (e1.Eoper == OPind)
        {
            /* Will need 1 register for evaluation, +2 registers for
             * e1's addressing mode
             */
            regm_t m = cgstate.allregs & ~cgstate.regcon.mvar;  // mask of non-register variables
            m &= m - 1;         // clear least significant bit
            m &= m - 1;         // clear least significant bit
            plenty = m != 0;    // at least 3 registers
        }

        if (e2oper == OPconst &&       // if rvalue is a constant
            !(evalinregister(e2) && plenty) &&
            !e1.Ecount)        // and no CSE headaches
        {
            // Look for special case of (*p++ = ...), where p is a register variable
            if (e1.Eoper == OPind &&
                ((e11 = e1.E1).Eoper == OPpostinc || e11.Eoper == OPpostdec) &&
                e11.E1.Eoper == OPvar &&
                e11.E1.Vsym.Sfl == FLreg
               )
            {
                Symbol *s = e11.E1.Vsym;
                if (s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg)
                {
                    cgstate.regcon.params &= ~s.Spregm();
                }
                postinc = e11.E2.Vint;
                if (e11.Eoper == OPpostdec)
                    postinc = -postinc;
                getlvalue(cdb,cs,e1,0,RM.store);
                freenode(e11.E2);
            }
            else
            {
                postinc = 0;
                getlvalue(cdb,cs,e1,0,RM.store);
            }

            // If loading result into a register
            if (cs.reg != NOREG)
            {
                getregs(cdb, cs.reg);
                const p = cast(targ_size_t *) &(e2.EV);
                movregconst(cdb,cs.reg,*p,sz == 8);
                freenode(e2);
                goto Lp;
            }
        }
        retregs = cgstate.allregs;        // pick a reg, any reg
    }
    if (retregs == mPSW)
    {
        retregs = cgstate.allregs;
    }
    cs.Iop = 0;
    regvar = false;
    if (config.flags4 & CFG4optimized)
    {
        // Be careful of cases like (x = x+x+x). We cannot evaluate in
        // x if x is in a register.
        if (isregvar(e1,varregm,varreg) &&    // if lvalue is register variable
            doinreg(e1.Vsym,e2) &&       // and we can compute directly into it
            !(sz == 1 && e1.Voffset == 1)
           )
        {
            if (varregm & XMMREGS)
            {
                // Could be an integer vector in the XMMREGS
                xmmeq(cdb, e, CMP, e1, e2, pretregs);
                return;
            }
            regvar = true;
            retregs = varregm;
            reg = varreg;       // evaluate directly in target register
        }
    }
    if (pretregs & mPSW && OTleaf(e1.Eoper))     // if evaluating e1 couldn't change flags
    {   // Be careful that this lines up with jmpopcode()
        retregs |= mPSW;
        pretregs &= ~mPSW;
    }
    scodelem(cgstate,cdb,e2,retregs,0,true);    // get rvalue

    // Look for special case of (*p++ = ...), where p is a register variable
    if (e1.Eoper == OPind &&
        ((e11 = e1.E1).Eoper == OPpostinc || e11.Eoper == OPpostdec) &&
        e11.E1.Eoper == OPvar &&
        e11.E1.Vsym.Sfl == FLreg)
    {
        Symbol *s = e11.E1.Vsym;
        if (s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg)
        {
            cgstate.regcon.params &= ~s.Spregm();
        }

        postinc = e11.E2.Vint;
        if (e11.Eoper == OPpostdec)
            postinc = -postinc;
        getlvalue(cdb,cs,e1,retregs,RM.store);
        freenode(e11.E2);
    }
    else
    {
        postinc = 0;
        getlvalue(cdb,cs,e1,retregs,RM.store);     // get lvalue (cl == null if regvar)
    }

    getregs(cdb,varregm);

    reg = findreg(retregs & cg.allregs);
    storeToEA(cs,reg,sz);
    cdb.gen1(cs.Iop);

    if (e1.Ecount ||                    // if lvalue is a CSE or
        regvar)                         // rvalue can't be a CSE
    {
        getregs_imm(cdb,retregs);       // necessary if both lvalue and
                                        //  rvalue are CSEs (since a reg
                                        //  can hold only one e at a time)
        cssave(e1,retregs,!OTleaf(e1.Eoper));     // if lvalue is a CSE
    }

    fixresult(cdb,e,retregs,pretregs);
Lp:
    if (postinc)
    {
        reg_t ireg = cs.base;
        uint sh = 0;
        uint op = postinc > 0 ? 0 : 1; // ADD/SUB
        uint imm12 = postinc > 0 ? postinc : -postinc;
        if (postinc && (imm12 & 0xFFF) == 0)
        {
            imm12 >>= 12;
            sh = 1;
        }
        assert(imm12 < 0x1000);  // should use movregconst() if this assert trips
        uint ins = INSTR.addsub_imm(sz == 8,0,op,sh,postinc,ireg,ireg); // ADD/SUB ireg,ireg,imm12,shift
        cdb.gen1(ins);
    }
    freenode(e1);
}

/************************
 * Generate code for += -= &= |= ^= negass
 */

@trusted
void cdaddass(ref CGstate cg, ref CodeBuilder cdb,elem *e,ref regm_t pretregs)
{
    //printf("cdaddass(e=%p, pretregs = %s)\n",e,regm_str(pretregs));
    OPER op = e.Eoper;
    regm_t retregs = 0;
    elem *e1 = e.E1;
    tym_t tyml = tybasic(e1.Ety);            // type of lvalue
    int sz = _tysize[tyml];
    int isbyte = (sz == 1);                     // 1 for byte operation, else 0

    // See if evaluate in XMM registers
    if (config.fpxmmregs && tyxmmreg(tyml) && op != OPnegass)
    {
        xmmopass(cdb,e,pretregs);
        return;
    }

    if (tyfloating(tyml))
    {
        if (config.exe & EX_posix)
        {
            if (op == OPnegass)
                cdnegass87(cdb,e,pretregs);
            else
                opass87(cdb,e,pretregs);
        }
        else
            assert(0);
        return;
    }
    regm_t forccs = pretregs & mPSW;            // return result in flags
    regm_t forregs = pretregs & ~mPSW;          // return result in regs
    // true if we want the result in a register
    uint wantres = forregs || (e1.Ecount && !OTleaf(e1.Eoper));
    wantres = true; // dunno why the above is conditional

    reg_t reg;
    code cs;
    elem *e2;
    uint jop;


    switch (op)                   // select instruction opcodes
    {
        case OPpostinc: op = OPaddass;                  // i++ => +=
                        goto case OPaddass;

        case OPpostdec: op = OPminass;                  // i-- => -=
                        goto case OPminass;

        case OPaddass:
        case OPminass:
        case OPandass:
        case OPorass:
        case OPxorass:
        case OPnegass:  break;

        default:
                assert(0);
    }

    if (op == OPnegass)
    {
        getlvalue(cdb,cs,e1,0);
        if (cs.reg == NOREG)
        {
            regm_t keepmsk = mask(cs.base) | mask(cs.index);
            retregs = forregs & ~keepmsk;
            if (!retregs)
                retregs = cg.allregs & ~keepmsk;
            reg = allocreg(cdb,retregs,tyml);
        }
        else
        {
            retregs = mask(cs.reg);
            getregs(cdb,retregs);
            reg = cs.reg;
        }
        uint szw = sz == 8 ? 8 : 4;
        loadFromEA(cs, reg, szw, sz);
        cdb.gen(&cs);
        // negate reg
        uint sf = sz == 8;
        uint S = forccs != 0;
        uint ins = INSTR.neg_sub_addsub_shift(sf,S,0,reg,0,cs.reg);
        cdb.gen1(ins);
        storeToEA(cs, reg, sz);
        cdb.gen(&cs);

        retregs = mask(reg);
        forccs = 0;             // flags already set by NEGS
        pretregs &= ~mPSW;
    }
    else if (0 && (op == OPaddass || op == OPminass) &&
        !e2.Ecount &&
        ((jop = jmpopcode(e2)) == JC || jop == JNC ||
         (OTconv(e2.Eoper) && !e2.E1.Ecount && ((jop = jmpopcode(e2.E1)) == JC || jop == JNC)))
       )
    {
        /* e1 += (x < y)    ADC EA,0
         * e1 -= (x < y)    SBB EA,0
         * e1 += (x >= y)   SBB EA,-1
         * e1 -= (x >= y)   ADC EA,-1
         */
        getlvalue(cdb,cs,e1,0);             // get lvalue
        modEA(cdb,&cs);
        regm_t keepmsk = idxregm(&cs);
        retregs = mPSW;
        if (OTconv(e2.Eoper))
        {
            scodelem(cgstate,cdb,e2.E1,retregs,keepmsk,true);
            freenode(e2);
        }
        else
            scodelem(cgstate,cdb,e2,retregs,keepmsk,true);
        cs.Iop = 0x81 ^ isbyte;                   // ADC EA,imm16/32
        uint regop = 2;                     // ADC
        if ((op == OPaddass) ^ (jop == JC))
            regop = 3;                          // SBB
        code_newreg(&cs,regop);
        //cs.Iflags |= opsize;
        if (forccs)
            cs.Iflags |= CFpsw;
        cs.IFL2 = FLconst;
        cs.IEV2.Vsize_t = (jop == JC) ? 0 : ~cast(targ_size_t)0;
        cdb.gen(&cs);
        retregs = 0;            // to trigger a bug if we attempt to use it
    }
    else // evaluate e2 into register
    {
        retregs = cg.allregs;                        // pick working reg
        scodelem(cgstate,cdb,e.E2,retregs,0,true);   // get rvalue
        getlvalue(cdb,cs,e1,retregs);                // get lvalue
        reg_t reg1;
        if (cs.reg)
            reg1 = cs.reg;
        else
        {
            regm_t posregs = cg.allregs & ~(retregs | mask(cs.base) | mask(cs.index));
            reg1 = allocreg(cdb,posregs,tyml);
        }
        getregs(cdb,mask(reg1));
        loadFromEA(cs,reg1,sz == 8 ? 8 : 4, sz);

        reg_t reg2 = findreg(retregs);

        // OP reg1,reg2
        uint sf = sz == 8;
        uint imm3 = 0;                // shift amount
        uint S = forccs != 0;
        uint opt = 0;
        uint option = 0;
        reg_t Rm = reg2;
        reg_t Rn = reg1;
        reg_t Rd = reg1;
        uint ins;
        switch (op)                   // select instruction opcodes
        {
            case OPaddass:
                ins = INSTR.addsub_ext(sf,0,S,opt,Rm,option,imm3,Rn,Rd); // ADD/ADDS
                pretregs &= ~mPSW;                                       // flags are already set
                break;
            case OPminass:
                ins = INSTR.addsub_ext(sf,1,S,opt,Rm,option,imm3,Rn,Rd); // SUB/SUBS
                pretregs &= ~mPSW;                                       // flags are already set
                break;
            case OPandass:
                ins = INSTR.log_shift(sf,S?3:0,0,0,Rm,0,Rn,Rd);  // AND/ANDS
                pretregs &= ~mPSW;                               // flags are already set
                break;
            case OPorass:
                ins = INSTR.log_shift(sf,1,0,0,Rm,0,Rn,Rd);      // ORR
                break;
            case OPxorass:
                ins = INSTR.log_shift(sf,2,0,0,Rm,0,Rn,Rd);      // EOR
                break;
            default:
                assert(0);
        }
        cdb.gen1(ins);

        storeToEA(cs,reg1,sz);
        if (forccs)
            cs.Iflags |= CFpsw;
        cdb.gen(&cs);
        retregs = mask(reg1);
    }

    // See if we need to reload result into a register.
    // Need result in registers in case we have a 32 bit
    // result and we want the flags as a result.
    if (wantres)
    {
        if (e1.Ecount)                 // if we gen a CSE
            cssave(e1,retregs,!OTleaf(e1.Eoper));
    }
    freenode(e1);
    fixresult(cdb,e,retregs,pretregs);
}

/********************************
 * Generate code for *=
 */

@trusted
void cdmulass(ref CGstate cg, ref CodeBuilder cdb,elem *e,ref regm_t pretregs)
{
    code cs;

    //printf("cdmulass(e=%p, pretregs = %s)\n",e,regm_str(pretregs));
    elem *e1 = e.E1;
    elem *e2 = e.E2;
    OPER op = e.Eoper;                     // OPxxxx

    tym_t tyml = tybasic(e1.Ety);              // type of lvalue
    uint sz = _tysize[tyml];

    // See if evaluate in XMM registers
    if (config.fpxmmregs && tyxmmreg(tyml) && !(pretregs & mST0))
    {
        xmmopass(cdb,e,pretregs);
        return;
    }

    static if (0)
    if (tyfloating(tyml))
    {
        if (config.exe & EX_posix)
        {
            opass87(cdb,e,pretregs);
        }
        else
        {
            opassdbl(cdb,e,pretregs,op);
        }
        return;
    }

    assert(sz <= REGSIZE);
    regm_t regm2 = ~pretregs & cg.allregs;
    if (!regm2)
        regm2 = cg.allregs;
    codelem(cgstate,cdb,e2,regm2,false); // load rvalue in reg2
    reg_t reg2 = findreg(regm2);
    getlvalue(cdb,cs,e1,regm2);  // get EA
    regm_t earegm = mask(cs.base) | mask(cs.index);
    regm_t retregs;
    reg_t reg;
    if (cs.reg)
    {
        reg = cs.reg;
        retregs = mask(reg);
    }
    else
    {
        retregs = cg.allregs & ~earegm & ~regm2;
        reg = allocreg(cdb,retregs,tyml);
        loadFromEA(cs,reg,sz,sz == 8 ? 8 : 4);
    }
    getregs(cdb,retregs);           // destroy these regs
                                // MUL reg,reg,reg2
    // http://www.scs.stanford.edu/~zyedidia/arm64/mul_madd.html
    // MADD Rd,Rn,Rm,Rzr  Rd = Rn * Rm + Rzr
    reg_t Rd = reg;
    reg_t Rn = reg;
    reg_t Rm = reg2;
    cdb.gen1(INSTR.madd(sz == 8, Rm, 31, Rn, Rd));

    storeToEA(cs,reg,sz);
    cdb.gen(&cs);

    if (e1.Ecount)                 // if we gen a CSE
        cssave(e1,retregs,!OTleaf(e1.Eoper));
    freenode(e1);

    fixresult(cdb,e,retregs,pretregs);
}

/********************************
 * Generate code for /= %=
 */

@trusted
void cddivass(ref CGstate cg, ref CodeBuilder cdb,elem *e,ref regm_t pretregs)
{
    elem *e1 = e.E1;
    elem *e2 = e.E2;

    tym_t tyml = tybasic(e1.Ety);              // type of lvalue
    OPER op = e.Eoper;                     // OPxxxx

    // See if evaluate in XMM registers
    if (config.fpxmmregs && tyxmmreg(tyml) && op != OPmodass && !(pretregs & mST0))
    {
        xmmopass(cdb,e,pretregs);
        return;
    }

    static if (0)
    if (tyfloating(tyml))
    {
        if (config.exe & EX_posix)
        {
            opass87(cdb,e,pretregs);
        }
        else
        {
            opassdbl(cdb,e,pretregs,op);
        }
        return;
    }

    code cs;

    //printf("cddivass(e=%p, pretregs = %s)\n",e,regm_str(pretregs));
    bool uns = tyuns(tyml) || tyuns(e2.Ety);
    uint sz = _tysize[tyml];

    assert(sz <= REGSIZE);

    regm_t Rdivisorm = ~pretregs & cg.allregs;
    if (!Rdivisorm)
        Rdivisorm = cg.allregs;
    codelem(cgstate,cdb,e2,Rdivisorm,false); // load rvalue in Rdivisor
    reg_t Rdivisor = findreg(Rdivisorm);
    getlvalue(cdb,cs,e1,Rdivisorm);  // get EA
    regm_t earegm = mask(cs.base) | mask(cs.index);
    regm_t retregs;
    reg_t Rdividend;
    if (cs.reg)
    {
        Rdividend = cs.reg;
        retregs = mask(Rdividend);
    }
    else
    {
        retregs = cg.allregs & ~earegm & ~Rdivisorm;
        Rdividend = allocreg(cdb,retregs,tyml);
        loadFromEA(cs,Rdividend,sz,sz == 8 ? 8 : 4);
    }

    reg_t Rquo;
    if (e.Eoper == OPmodass)
    {
        retregs = cg.allregs & ~earegm & ~Rdivisorm & ~mask(Rdividend);
        Rquo = allocreg(cdb,retregs,tyml);
    }
    else
        Rquo = Rdividend;

    getregs(cdb,mask(Rquo));           // destroy these regs

    // DIV Rd, Rn, Rm
    uint ins = INSTR.sdiv_udiv(sz == 8,uns,Rdivisor,Rdividend,Rquo);
    cdb.gen1(ins);
    reg_t reg = Rquo;

    if (e.Eoper == OPmodass)
    {
        retregs = cg.allregs & ~earegm;
        reg_t Rmod = allocreg(cdb,retregs,tyml);
        getregs(cdb,mask(Rmod));
        uint ins2 = INSTR.msub(sz == 8,Rdivisor,Rdividend,Rquo,Rmod);
        cdb.gen1(ins2);
        reg = Rmod;
    }

    storeToEA(cs,reg,sz);
    cdb.gen(&cs);

    retregs = mask(reg);
    if (e1.Ecount)                 // if we gen a CSE
        cssave(e1,retregs,!OTleaf(e1.Eoper));
    freenode(e1);

    fixresult(cdb,e,retregs,pretregs);
}

/********************************
 * Generate code for OPshrass, OPashrass, OPshlass (>>=, >>>=, <<=)
 */

@trusted
void cdshass(ref CGstate cg, ref CodeBuilder cdb,elem *e,ref regm_t pretregs)
{
    if (cg.AArch64)
    {
        import dmd.backend.arm.cod4 : cdshass;
        return cdshass(cg, cdb, e, pretregs);
    }

    //printf("cdshass(e=%p, pretregs = %s)\n",e,regm_str(pretregs));
    elem *e1 = e.E1;
    elem *e2 = e.E2;

    tym_t tyml = tybasic(e1.Ety);              // type of lvalue

    code cs;

    uint sz = _tysize[tyml];
    assert(sz <= REGSIZE);

    regm_t Rshiftcntm = ~pretregs & cg.allregs;
    if (!Rshiftcntm)
        Rshiftcntm = cg.allregs;
    codelem(cgstate,cdb,e2,Rshiftcntm,false); // load rvalue in Rshiftcnt
    reg_t Rshiftcnt = findreg(Rshiftcntm);
    getlvalue(cdb,cs,e1,Rshiftcntm);  // get EA
    regm_t earegm = mask(cs.base) | mask(cs.index);
    regm_t retregs;
    reg_t Rshiftee;
    if (cs.reg)
    {
        Rshiftee = cs.reg;
        retregs = mask(Rshiftee);
    }
    else
    {
        retregs = cg.allregs & ~earegm & ~Rshiftcntm;
        Rshiftee = allocreg(cdb,retregs,tyml);
        loadFromEA(cs,Rshiftee,sz,sz == 8 ? 8 : 4);
    }

    reg_t Rresult;
    if (e.Eoper == OPmodass)
    {
        retregs = cg.allregs & ~earegm & ~Rshiftcntm & ~mask(Rshiftee);
        Rresult = allocreg(cdb,retregs,tyml);
    }
    else
        Rresult = Rshiftee;

    getregs(cdb,mask(Rresult));           // destroy these regs

    /* https://www.scs.stanford.edu/~zyedidia/arm64/encodingindex.html#dp_2src
     * https://www.scs.stanford.edu/~zyedidia/arm64/lsl_lslv.html
     * https://www.scs.stanford.edu/~zyedidia/arm64/lsr_lsrv.html
     * https://www.scs.stanford.edu/~zyedidia/arm64/asr_asrv.html
     * https://www.scs.stanford.edu/~zyedidia/arm64/ror_rorv.html
     */
    uint S = 0;
    uint opcode;
    switch (e.Eoper)
    {
        case OPshl:     opcode = 0x8;   break;
        case OPshr:     opcode = 0x9;   break;
        case OPashr:    opcode = 0xA;   break;
        //case OPror:     opcode = 0xB;   break;
        default:
            assert(0);
    }

    // DIV Rd, Rn, Rm

    uint ins = INSTR.dp_2src(sz == 8,S,Rshiftcnt,opcode,Rshiftee,Rresult);
    cdb.gen1(ins);
    reg_t reg = Rresult;

    storeToEA(cs,reg,sz);
    cdb.gen(&cs);

    retregs = mask(reg);
    if (e1.Ecount)                 // if we gen a CSE
        cssave(e1,retregs,!OTleaf(e1.Eoper));
    freenode(e1);

    fixresult(cdb,e,retregs,pretregs);
}

/**********************************
 * Generate code for compares.
 * Handles lt,gt,le,ge,eqeq,ne for all data types.
 */

@trusted
void cdcmp(ref CGstate cg, ref CodeBuilder cdb,elem *e,ref regm_t pretregs)
{
    //printf("cdcmp(e = %p, pretregs = %s)\n",e,regm_str(pretregs));
    //elem_print(e);

    regm_t retregs,rretregs;
    reg_t reg,rreg;

    // Collect extra parameter. This is pretty ugly...
    int flag = cg.cmp_flag;
    cg.cmp_flag = 0;

    elem *e1 = e.E1;
    elem *e2 = e.E2;
    if (pretregs == 0)                 // if don't want result
    {
        codelem(cgstate,cdb,e1,pretregs,false);
        pretregs = 0;                  // in case e1 changed it
        codelem(cgstate,cdb,e2,pretregs,false);
        return;
    }

    if (tyvector(tybasic(e1.Ety)))
        return orthxmm(cdb,e,pretregs);

    COND jop = conditionCode(e);        // must be computed before
                                        // leaves are free'd
    uint reverse = 0;

    OPER op = e.Eoper;
    assert(OTrel(op));
    //bool eqorne = (op == OPeqeq) || (op == OPne);

    tym_t tym = tybasic(e1.Ety);
    uint sz = _tysize[tym];
    uint isbyte = sz == 1;

    uint rex = (I64 && sz == 8) ? REX_W : 0;
    uint grex = rex << 16;          // 64 bit operands

    code cs;
    code *ce;
    if (tyfloating(tym))                  // if floating operation
    {
        if (config.fpxmmregs)
        {
            retregs = mPSW;
            if (tyxmmreg(tym))
                orthxmm(cdb,e,retregs);
            else
                assert(0);
        }
        else
        {
            assert(0);
        }
        goto L3;
    }

    /* See if we should reverse the comparison, so a JA => JC, and JBE => JNC
     * (This is already reflected in the jop)
     */
    if ((jop == COND.cs || jop == COND.cc) &&
        (op == OPgt || op == OPle) &&
        (tyuns(tym) || tyuns(e2.Ety))
       )
    {   // jmpopcode() sez comparison should be reversed
        assert(e2.Eoper != OPconst && e2.Eoper != OPrelconst);
        reverse ^= 1;
    }

    /* See if we should swap operands     */
    if (e1.Eoper == OPvar && e2.Eoper == OPvar && evalinregister(e2))
    {
        e1 = e.E2;
        e2 = e.E1;
        reverse ^= 1;
    }

    retregs = cgstate.allregs;

    ce = null;
    cs.Iflags = (sz == SHORTSIZE) ? CFopsize : 0;
    cs.Irex = cast(ubyte)rex;
    if (sz > REGSIZE)
        ce = gennop(ce);

    switch (e2.Eoper)
    {
        default:
            scodelem(cgstate,cdb,e1,retregs,0,true);        // compute left leaf
            rretregs = cgstate.allregs & ~retregs;
            scodelem(cgstate,cdb,e2,rretregs,retregs,true); // get right leaf
            if (sz <= REGSIZE)                              // CMP reg,rreg
            {
                reg = findreg(retregs);                     // get reg that e1 is in
                rreg = findreg(rretregs);
                uint ins;
                uint sf = sz == 8;
                if (reverse)
                    ins = INSTR.cmp_shift(sf, reg, 0, 0, rreg); // CMP rreg, reg
                else
                    ins = INSTR.cmp_shift(sf, rreg, 0, 0, reg); // CMP reg, rreg
                cdb.gen1(ins);
            }
            else
            {
                assert(sz == 2 * REGSIZE);

                // Compare MSW, if they're equal then compare the LSW
                reg = findregmsw(retregs);
                rreg = findregmsw(rretregs);
                uint ins = INSTR.cmp_shift(1, rreg, 0, 0, reg); // CMP reg, rreg
                cdb.gen1(ins);
                genjmp(cdb,JNE,FLcode,cast(block *) ce);      // JNE nop

                reg = findreglsw(retregs);
                rreg = findreglsw(rretregs);
                ins = INSTR.cmp_shift(1, rreg, 0, 0, reg);      // CMP reg, rreg
                cdb.gen1(ins);
            }
            break;

static if (0)
{
        case OPconst:
printf("OPconst:\n");
            // If compare against 0
            if (sz <= REGSIZE && pretregs == mPSW && !boolres(e2) &&
                isregvar(e1,retregs,reg)
               )
            {
                gentstreg(cdb, reg, sz == 8);           // CMP reg,#0
                retregs = mPSW;
                break;
            }

            if (!tyuns(tym) && !tyuns(e2.Ety) &&
                !boolres(e2) && !(pretregs & mPSW) &&
                (sz == REGSIZE || (I64 && sz == 4)) &&
                (!I16 || op == OPlt || op == OPge))
            {
                assert(pretregs & (cgstate.allregs));
                codelem(cgstate,cdb,e1,pretregs,false);
                reg = findreg(pretregs);
                getregs(cdb,mask(reg));
                switch (op)
                {
                    case OPle:
                        cdb.genc2(0x81,grex | modregrmx(3,0,reg),cast(uint)-1);   // ADD reg,-1
                        code_orflag(cdb.last(), CFpsw);
                        cdb.genc2(0x81,grex | modregrmx(3,2,reg),0);          // ADC reg,0
                        goto oplt;

                    case OPgt:
                        cdb.gen2(0xF7,grex | modregrmx(3,3,reg));         // NEG reg
                            /* Flips the sign bit unless the value is 0 or int.min.
                            Also sets the carry bit when the value is not 0. */
                        code_orflag(cdb.last(), CFpsw);
                        cdb.genc2(0x81,grex | modregrmx(3,3,reg),0);  // SBB reg,0
                            /* Subtracts the carry bit. This turns int.min into
                            int.max, flipping the sign bit.
                            For other negative and positive values, subtracting 1
                            doesn't affect the sign bit.
                            For 0, the carry bit is not set, so this does nothing
                            and the sign bit is not affected. */
                        goto oplt;

                    case OPlt:
                    oplt:
                        // Get the sign bit, i.e. 1 if the value is negative.
                        if (!I16)
                            cdb.genc2(0xC1,grex | modregrmx(3,5,reg),sz * 8 - 1); // SHR reg,31
                        else
                        {   /* 8088-286 do not have a barrel shifter, so use this
                               faster sequence
                             */
                            genregs(cdb,0xD1,0,reg);   // ROL reg,1
                            reg_t regi;
                            if (reghasvalue(cgstate.allregs,1,regi))
                                genregs(cdb,0x23,reg,regi);  // AND reg,regi
                            else
                                cdb.genc2(0x81,modregrm(3,4,reg),1); // AND reg,1
                        }
                        break;

                    case OPge:
                        genregs(cdb,0xD1,4,reg);        // SHL reg,1
                        code_orrex(cdb.last(),rex);
                        code_orflag(cdb.last(), CFpsw);
                        genregs(cdb,0x19,reg,reg);      // SBB reg,reg
                        code_orrex(cdb.last(),rex);
                        if (I64)
                        {
                            cdb.gen2(0xFF,modregrmx(3,0,reg));       // INC reg
                            code_orrex(cdb.last(), rex);
                        }
                        else
                            cdb.gen1(0x40 + reg);                    // INC reg
                        break;

                    default:
                        assert(0);
                }
                freenode(e2);
                goto ret;
            }

            cs.IFL2 = FLconst;
            if (sz == 16)
                cs.IEV2.Vsize_t = cast(targ_size_t)e2.Vcent.hi;
            else if (sz > REGSIZE)
                cs.IEV2.Vint = cast(int)MSREG(e2.Vllong);
            else
                cs.IEV2.Vsize_t = cast(targ_size_t)e2.Vllong;

            // The cmp immediate relies on sign extension of the 32 bit immediate value
            if (I64 && sz >= REGSIZE && cs.IEV2.Vsize_t != cast(int)cs.IEV2.Vint)
                goto default;
            cs.Iop = 0x81 ^ isbyte;

            /* if ((e1 is data or a '*' reference) and it's not a
             * common subexpression
             */

            if ((e1.Eoper == OPvar && datafl[el_fl(e1)] ||
                 e1.Eoper == OPind) &&
                !evalinregister(e1))
            {
                getlvalue(cdb,cs,e1,0,RM.load);
                freenode(e1);
                if (evalinregister(e2))
                {
                    retregs = idxregm(&cs);
                    rretregs = cgstate.allregs & ~retregs;
                    scodelem(cgstate,cdb,e2,rretregs,retregs,true);
                    cs.Iop = 0x39 ^ isbyte ^ reverse;
                    if (sz > REGSIZE)
                    {
                        rreg = findregmsw(rretregs);
                        cs.Irm |= modregrm(0,rreg,0);
                        getlvalue_msw(cs);
                        cdb.gen(&cs);              // CMP EA+2,rreg
                        if (I64 && isbyte && rreg >= 4)
                            cdb.last().Irex |= REX;
                        genjmp(cdb,JNE,FLcode,cast(block *) ce); // JNE nop
                        rreg = findreglsw(rretregs);
                        NEWREG(cs.Irm,rreg);
                        getlvalue_lsw(cs);
                    }
                    else
                    {
                        rreg = findreg(rretregs);
                        code_newreg(&cs, rreg);
                        if (I64 && isbyte && rreg >= 4)
                            cs.Irex |= REX;
                    }
                }
                else
                {
                    cs.Irm |= modregrm(0,7,0);
                    if (sz > REGSIZE)
                    {
                        if (sz == 6)
                            assert(0);
                        if (e2.Eoper == OPrelconst)
                        {   cs.Iflags = (cs.Iflags & ~(CFoff | CFseg)) | CFseg;
                            cs.IEV2.Voffset = 0;
                        }
                        getlvalue_msw(cs);
                        cdb.gen(&cs);              // CMP EA+2,const
                        genjmp(cdb,JNE,FLcode, cast(block *) ce); // JNE nop
                        if (e2.Eoper == OPconst)
                            cs.IEV2.Vint = cast(int)e2.Vllong;
                        else if (e2.Eoper == OPrelconst)
                        {   // Turn off CFseg, on CFoff
                            cs.Iflags ^= CFseg | CFoff;
                            cs.IEV2.Voffset = e2.Voffset;
                        }
                        else
                            assert(0);
                        getlvalue_lsw(cs);
                    }
                    freenode(e2);
                }
                cdb.gen(&cs);
                break;
            }

            regm_t regmx;
            reg_t regx;
            if (evalinregister(e2) && !OTassign(e1.Eoper) &&
                !isregvar(e1,regmx,regx))
            {
                regm_t m;

                m = cgstate.allregs & ~cgstate.regcon.mvar;
                if (isbyte)
                    m &= BYTEREGS;
                if (m & (m - 1))    // if more than one free register
                    goto default;
            }
            if ((e1.Eoper == OPstrcmp || (OTassign(e1.Eoper) && sz <= REGSIZE)) &&
                !boolres(e2) && !evalinregister(e1))
            {
                retregs = mPSW;
                scodelem(cgstate,cdb,e1,retregs,0,false);
                freenode(e2);
                break;
            }
            if (sz <= REGSIZE && !boolres(e2) && e1.Eoper == OPadd && pretregs == mPSW)
            {
                retregs |= mPSW;
                scodelem(cgstate,cdb,e1,retregs,0,false);
                freenode(e2);
                break;
            }
            scodelem(cgstate,cdb,e1,retregs,0,true);  // compute left leaf
            if (sz <= REGSIZE)
            {   // CMP reg,const
                reg = findreg(retregs & cgstate.allregs);   // get reg that e1 is in
                rretregs = cgstate.allregs & ~retregs;
                if (cs.IFL2 == FLconst && reghasvalue(rretregs,cs.IEV2.Vint,rreg))
                {
                    genregs(cdb,0x3B,reg,rreg);
                    code_orrex(cdb.last(), rex);
                    if (!I16)
                        cdb.last().Iflags |= cs.Iflags & CFopsize;
                    freenode(e2);
                    break;
                }
                cs.Irm = modregrm(3,7,reg & 7);
                if (reg & 8)
                    cs.Irex |= REX_B;
            }
            else
                assert(0);
            cdb.gen(&cs);                         // CMP sucreg,LSW
            freenode(e2);
            break;

        case OPind:
            if (e2.Ecount)
                goto default;
            goto L5;

        case OPvar:
            if (config.exe & (EX_OSX | EX_OSX64))
            {
                if (movOnly(e2))
                    goto default;
            }
            if ((e1.Eoper == OPvar &&
                 isregvar(e2,rretregs,reg) &&
                 sz <= REGSIZE
                ) ||
                (e1.Eoper == OPind &&
                 isregvar(e2,rretregs,reg) &&
                 !evalinregister(e1) &&
                 sz <= REGSIZE
                )
               )
            {
                // CMP EA,e2
                getlvalue(cdb,cs,e1,0,RM.load);
                freenode(e1);
                cs.Iop = 0x39 ^ isbyte ^ reverse;
                code_newreg(&cs,reg);
                if (I64 && isbyte && reg >= 4)
                    cs.Irex |= REX;                 // address byte registers
                cdb.gen(&cs);
                freenode(e2);
                break;
            }
          L5:
            scodelem(cgstate,cdb,e1,retregs,0,true);      // compute left leaf
            if (sz <= REGSIZE)                      // CMP reg,EA
            {
                reg = findreg(retregs & cgstate.allregs);   // get reg that e1 is in
                uint opsize = cs.Iflags & CFopsize;
                loadea(cdb,e2,cs,0x3B ^ isbyte ^ reverse,reg,0,retregs,0,RM.load);
                code_orflag(cdb.last(),opsize);
            }
            else if (sz <= 2 * REGSIZE)
            {
                reg = findregmsw(retregs);   // get reg that e1 is in
                // CMP reg,EA
                loadea(cdb,e2,cs,0x3B ^ reverse,reg,REGSIZE,retregs,0,RM.load);
                if (I32 && sz == 6)
                    cdb.last().Iflags |= CFopsize;        // seg is only 16 bits
                genjmp(cdb,JNE,FLcode, cast(block *) ce);  // JNE ce
                reg = findreglsw(retregs);
                if (e2.Eoper == OPind)
                {
                    NEWREG(cs.Irm,reg);
                    getlvalue_lsw(cs);
                    cdb.gen(&cs);
                }
                else
                    loadea(cdb,e2,cs,0x3B ^ reverse,reg,0,retregs,0,RM.load);
            }
            else
                assert(0);
            freenode(e2);
            break;
}
    }
    cdb.append(ce);

L3:
    if ((retregs = (pretregs & cg.allregs)) != 0) // if return result in register
    {
        if (1 && !flag && !(jop & 0xFF00))
        {
            regm_t resregs = retregs;
            reg = allocreg(cdb,resregs,TYint);
            uint ins = INSTR.csinc(sz == 8,0x1F,jop ^ 1,0x1F,reg); // CSET reg,invcond
            cdb.gen1(ins);
            pretregs &= ~mPSW;
            fixresult(cdb,e,resregs,pretregs);
        }
        else
        {
            code *nop = null;
            regm_t save = cgstate.regcon.immed.mval;
            reg = allocreg(cdb,retregs,TYint);
            cgstate.regcon.immed.mval = save;
            if ((pretregs & mPSW) == 0 &&
                (jop == COND.cs || jop == COND.cc))
            {
                getregs(cdb,retregs);
                genregs(cdb,0x19,reg,reg);     // SBB reg,reg
                if (rex || flag & REX_W)
                    code_orrex(cdb.last(), REX_W);
                if (flag)
                { }                                         // cdcond() will handle it
                else if (jop == JNC)
                {
                    if (I64)
                    {
                        cdb.gen2(0xFF,modregrmx(3,0,reg));  // INC reg
                        code_orrex(cdb.last(), rex);
                    }
                    else
                        cdb.gen1(0x40 + reg);               // INC reg
                }
                else
                {
                    cdb.gen2(0xF7,modregrmx(3,3,reg));      // NEG reg
                    code_orrex(cdb.last(), rex);
                }
            }
            else if (I64 && sz == 8)
            {
                assert(!flag);
                movregconst(cdb,reg,1,64|8);   // MOV reg,1
                nop = gennop(nop);
                genjmp(cdb,jop,FLcode,cast(block *) nop);  // Jtrue nop
                                                            // MOV reg,0
                movregconst(cdb,reg,0,(pretregs & mPSW) ? 64|8 : 64);
                cgstate.regcon.immed.mval &= ~mask(reg);
            }
            else
            {
                assert(!flag);
                movregconst(cdb,reg,1,8);      // MOV reg,1
                nop = gennop(nop);
                genjmp(cdb,jop,FLcode,cast(block *) nop);  // Jtrue nop
                                                            // MOV reg,0
                movregconst(cdb,reg,0,(pretregs & mPSW) ? 8 : 0);
                cgstate.regcon.immed.mval &= ~mask(reg);
            }
            pretregs = retregs;
            cdb.append(nop);
        }
    }
ret:
    { }
}

// longcmp
// cdcnvt
// cdshtlng
// cdbyteint
// cdlngsht
// cdmsw
// cdport
// cdasm
// cdfar16
// cdbtst
// cdbt
// cdbscan
// cdpopcnt
// cdpair
// cdcmpxchg
// cdprefetch
// opAssLoadReg
// opAssLoadPair
// opAssStoreReg
// opAssStorePair
