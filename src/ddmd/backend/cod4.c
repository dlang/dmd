/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/cod4.c
 */

#if !SPP

#include        <stdio.h>
#include        <time.h>

#include        "cc.h"
#include        "el.h"
#include        "oper.h"
#include        "code.h"
#include        "type.h"
#include        "global.h"
#include        "xmm.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

                        /*   AX,CX,DX,BX                */
const unsigned dblreg[4] = { BX,DX,(unsigned)-1,CX };


/*******************************
 * Return number of times symbol s appears in tree e.
 */

STATIC int intree(symbol *s,elem *e)
{
        if (EOP(e))
            return intree(s,e->E1) + (EBIN(e) ? intree(s,e->E2) : 0);
        return e->Eoper == OPvar && e->EV.sp.Vsym == s;
}

/***********************************
 * Determine if expression e can be evaluated directly into register
 * variable s.
 * Have to be careful about things like x=x+x+x, and x=a+x.
 * Returns:
 *      !=0     can
 *      0       can't
 */

int doinreg(symbol *s, elem *e)
{   int in = 0;
    int op;

 L1:
    op = e->Eoper;
    if (op == OPind ||
        OTcall(op)  ||
        OTleaf(op) ||
        (in = intree(s,e)) == 0 ||
        (OTunary(op) && !EOP(e->E1))
       )
        return 1;
    if (in == 1)
    {
        switch (op)
        {
            case OPadd:
            case OPmin:
            case OPand:
            case OPor:
            case OPxor:
            case OPshl:
            case OPmul:
                if (!intree(s,e->E2))
                {
                    e = e->E1;
                    goto L1;
                }
        }
    }
    return 0;
}

/****************************
 * Return code for saving common subexpressions if EA
 * turns out to be a register.
 * This is called just before modifying an EA.
 */

void modEA(CodeBuilder& cdb,code *c)
{
    if ((c->Irm & 0xC0) == 0xC0)        // addressing mode refers to a register
    {
        unsigned reg = c->Irm & 7;
        if (c->Irex & REX_B)
        {   reg |= 8;
            assert(I64);
        }
        getregs(cdb,mask[reg]);
    }
}

#if TARGET_WINDOS
// This code is for CPUs that do not support the 8087

/****************************
 * Gen code for op= for doubles.
 */

STATIC void opassdbl(CodeBuilder& cdb,elem *e,regm_t *pretregs,unsigned op)
{
    static unsigned clibtab[OPdivass - OPpostinc + 1] =
    /* OPpostinc,OPpostdec,OPeq,OPaddass,OPminass,OPmulass,OPdivass       */
    {  CLIBdadd, CLIBdsub, (unsigned)-1,  CLIBdadd,CLIBdsub,CLIBdmul,CLIBddiv };

    if (config.inline8087)
    {
        opass87(cdb,e,pretregs);
        return;
    }

    code cs;
    regm_t retregs2,retregs,idxregs;

    unsigned clib = clibtab[op - OPpostinc];
    elem *e1 = e->E1;
    tym_t tym = tybasic(e1->Ety);
    getlvalue(cdb,&cs,e1,DOUBLEREGS | mBX | mCX);

    if (tym == TYfloat)
    {
        clib += CLIBfadd - CLIBdadd;    /* convert to float operation   */

        // Load EA into FLOATREGS
        getregs(cdb,FLOATREGS);
        cs.Iop = 0x8B;
        cs.Irm |= modregrm(0,AX,0);
        cdb.gen(&cs);

        if (!I32)
        {
            cs.Irm |= modregrm(0,DX,0);
            getlvalue_msw(&cs);
            cdb.gen(&cs);
            getlvalue_lsw(&cs);

        }
        retregs2 = FLOATREGS2;
        idxregs = FLOATREGS | idxregm(&cs);
        retregs = FLOATREGS;
    }
    else
    {
        if (I32)
        {
            // Load EA into DOUBLEREGS
            getregs(cdb,DOUBLEREGS_32);
            cs.Iop = 0x8B;
            cs.Irm |= modregrm(0,AX,0);
            cdb.gen(&cs);
            cs.Irm |= modregrm(0,DX,0);
            getlvalue_msw(&cs);
            cdb.gen(&cs);
            getlvalue_lsw(&cs);

            retregs2 = DOUBLEREGS2_32;
            idxregs = DOUBLEREGS_32 | idxregm(&cs);
        }
        else
        {
            // Push EA onto stack
            cs.Iop = 0xFF;
            cs.Irm |= modregrm(0,6,0);
            cs.IEVoffset1 += DOUBLESIZE - REGSIZE;
            cdb.gen(&cs);
            getlvalue_lsw(&cs);
            cdb.gen(&cs);
            getlvalue_lsw(&cs);
            cdb.gen(&cs);
            getlvalue_lsw(&cs);
            cdb.gen(&cs);
            stackpush += DOUBLESIZE;

            retregs2 = DOUBLEREGS_16;
            idxregs = idxregm(&cs);
        }
        retregs = DOUBLEREGS;
    }

    if ((cs.Iflags & CFSEG) == CFes)
        idxregs |= mES;
    cgstate.stackclean++;
    scodelem(cdb,e->E2,&retregs2,idxregs,FALSE);
    cgstate.stackclean--;
    callclib(cdb,e,clib,&retregs,0);
    if (e1->Ecount)
        cssave(e1,retregs,EOP(e1));             // if lvalue is a CSE
    freenode(e1);
    cs.Iop = 0x89;                              // MOV EA,DOUBLEREGS
    fltregs(cdb,&cs,tym);
    fixresult(cdb,e,retregs,pretregs);
}

/****************************
 * Gen code for OPnegass for doubles.
 */

STATIC void opnegassdbl(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    if (config.inline8087)
    {
        cdnegass87(cdb,e,pretregs);
        return;
    }
    elem *e1 = e->E1;
    tym_t tym = tybasic(e1->Ety);
    int sz = _tysize[tym];
    code cs;

    getlvalue(cdb,&cs,e1,*pretregs ? DOUBLEREGS | mBX | mCX : 0);
    modEA(cdb,&cs);
    cs.Irm |= modregrm(0,6,0);
    cs.Iop = 0x80;
    cs.IEVoffset1 += sz - 1;
    cs.IFL2 = FLconst;
    cs.IEV2.Vuns = 0x80;
    cdb.gen(&cs);                       // XOR 7[EA],0x80
    if (tycomplex(tym))
    {
        cs.IEVoffset1 -= sz / 2;
        cdb.gen(&cs);                   // XOR 7[EA],0x80
    }

    regm_t retregs;
    if (*pretregs || e1->Ecount)
    {
        cs.IEVoffset1 -= sz - 1;

        if (tym == TYfloat)
        {
            // Load EA into FLOATREGS
            getregs(cdb,FLOATREGS);
            cs.Iop = 0x8B;
            NEWREG(cs.Irm, AX);
            cdb.gen(&cs);

            if (!I32)
            {
                NEWREG(cs.Irm, DX);
                getlvalue_msw(&cs);
                cdb.gen(&cs);
                getlvalue_lsw(&cs);

            }
            retregs = FLOATREGS;
        }
        else
        {
            if (I32)
            {
                // Load EA into DOUBLEREGS
                getregs(cdb,DOUBLEREGS_32);
                cs.Iop = 0x8B;
                cs.Irm &= ~modregrm(0,7,0);
                cs.Irm |= modregrm(0,AX,0);
                cdb.gen(&cs);
                cs.Irm |= modregrm(0,DX,0);
                getlvalue_msw(&cs);
                cdb.gen(&cs);
                getlvalue_lsw(&cs);
            }
            else
            {
#if 1
                cs.Iop = 0x8B;
                fltregs(cdb,&cs,TYdouble);     // MOV DOUBLEREGS, EA
#else
                // Push EA onto stack
                cs.Iop = 0xFF;
                cs.Irm |= modregrm(0,6,0);
                cs.IEVoffset1 += DOUBLESIZE - REGSIZE;
                cdb.gen(&cs);
                cs.IEVoffset1 -= REGSIZE;
                cdb.gen(&cs);
                cs.IEVoffset1 -= REGSIZE;
                cdb.gen(&cs);
                cs.IEVoffset1 -= REGSIZE;
                cdb.gen(&cs);
                stackpush += DOUBLESIZE;
#endif
            }
            retregs = DOUBLEREGS;
        }
        if (e1->Ecount)
            cssave(e1,retregs,EOP(e1));         /* if lvalue is a CSE   */
    }
    else
    {   retregs = 0;
        assert(e1->Ecount == 0);
    }

    freenode(e1);
    fixresult(cdb,e,retregs,pretregs);
}
#endif



/************************
 * Generate code for an assignment.
 */

void cdeq(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
  tym_t tymll;
  unsigned reg;
  int i;
  code cs;
  elem *e11;
  bool regvar;                  // TRUE means evaluate into register variable
  regm_t varregm;
  unsigned varreg;
  targ_int postinc;

  //printf("cdeq(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
  elem *e1 = e->E1;
  elem *e2 = e->E2;
  int e2oper = e2->Eoper;
  tym_t tyml = tybasic(e1->Ety);              // type of lvalue
  regm_t retregs = *pretregs;

    if (tyxmmreg(tyml) && config.fpxmmregs)
    {
        xmmeq(cdb, e, e->Eoper, e1, e2, pretregs);
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

    unsigned sz = _tysize[tyml];           // # of bytes to transfer
    assert((int)sz > 0);

    if (retregs == 0)                     // if no return value
    {
        int fl;

        /* If registers are tight, and we might need them for the lvalue,
         * prefer to not use them for the rvalue
         */
        bool plenty = true;
        if (e1->Eoper == OPind)
        {
            /* Will need 1 register for evaluation, +2 registers for
             * e1's addressing mode
             */
            regm_t m = allregs & ~regcon.mvar;  // mask of non-register variables
            m &= m - 1;         // clear least significant bit
            m &= m - 1;         // clear least significant bit
            plenty = m != 0;    // at least 3 registers
        }

        if ((e2oper == OPconst ||       // if rvalue is a constant
             e2oper == OPrelconst &&
             !(I64 && (config.flags3 & CFG3pic || config.exe == EX_WIN64)) &&
             ((fl = el_fl(e2)) == FLdata ||
              fl==FLudata || fl == FLextern)
              && !(e2->EV.sp.Vsym->ty() & mTYcs)
            ) &&
            !(evalinregister(e2) && plenty) &&
            !e1->Ecount)        // and no CSE headaches
        {
            // Look for special case of (*p++ = ...), where p is a register variable
            if (e1->Eoper == OPind &&
                ((e11 = e1->E1)->Eoper == OPpostinc || e11->Eoper == OPpostdec) &&
                e11->E1->Eoper == OPvar &&
                e11->E1->EV.sp.Vsym->Sfl == FLreg &&
                (!I16 || e11->E1->EV.sp.Vsym->Sregm & IDXREGS)
               )
            {
                Symbol *s = e11->E1->EV.sp.Vsym;
                if (s->Sclass == SCfastpar || s->Sclass == SCshadowreg)
                {
                    regcon.params &= ~s->Spregm();
                }
                postinc = e11->E2->EV.Vint;
                if (e11->Eoper == OPpostdec)
                    postinc = -postinc;
                getlvalue(cdb,&cs,e11,RMstore);
                freenode(e11->E2);
            }
            else
            {   postinc = 0;
                getlvalue(cdb,&cs,e1,RMstore);

                if (e2oper == OPconst &&
                    config.flags4 & CFG4speed &&
                    (config.target_cpu == TARGET_Pentium ||
                     config.target_cpu == TARGET_PentiumMMX) &&
                    (cs.Irm & 0xC0) == 0x80
                   )
                {
                    if (I64 && sz == 8 && e2->EV.Vpointer)
                    {
                        // MOV reg,imm64
                        // MOV EA,reg
                        regm_t rregm = allregs & ~idxregm(&cs);
                        unsigned reg;
                        regwithvalue(cdb,rregm,e2->EV.Vpointer,&reg,64);
                        cs.Iop = 0x89;
                        cs.Irm |= modregrm(0,reg & 7,0);
                        if (reg & 8)
                            cs.Irex |= REX_R;
                        cdb.gen(&cs);
                        freenode(e2);
                        goto Lp;
                    }
                    if ((sz == REGSIZE || (I64 && sz == 4)) && e2->EV.Vint)
                    {
                        // MOV reg,imm
                        // MOV EA,reg
                        regm_t rregm = allregs & ~idxregm(&cs);
                        unsigned reg;
                        regwithvalue(cdb,rregm,e2->EV.Vint,&reg,0);
                        cs.Iop = 0x89;
                        cs.Irm |= modregrm(0,reg & 7,0);
                        if (reg & 8)
                            cs.Irex |= REX_R;
                        cdb.gen(&cs);
                        freenode(e2);
                        goto Lp;
                    }
                    if (sz == 2 * REGSIZE && e2->EV.Vllong == 0)
                    {
                        unsigned reg;

                        // MOV reg,imm
                        // MOV EA,reg
                        // MOV EA+2,reg
                        regm_t rregm = getscratch() & ~idxregm(&cs);
                        if (rregm)
                        {
                            regwithvalue(cdb,rregm,e2->EV.Vint,&reg,0);
                            cs.Iop = 0x89;
                            cs.Irm |= modregrm(0,reg,0);
                            cdb.gen(&cs);
                            getlvalue_msw(&cs);
                            cdb.gen(&cs);
                            freenode(e2);
                            goto Lp;
                        }
                    }
                }
            }

            // If loading result into a register
            if ((cs.Irm & 0xC0) == 0xC0)
            {
                modEA(cdb,&cs);
                if (sz == 2 * REGSIZE && cs.IFL1 == FLreg)
                    getregs(cdb,cs.IEVsym1->Sregm);
            }
            cs.Iop = (sz == 1) ? 0xC6 : 0xC7;

            if (e2oper == OPrelconst)
            {
                cs.IEVoffset2 = e2->EV.sp.Voffset;
                cs.IFL2 = fl;
                cs.IEVsym2 = e2->EV.sp.Vsym;
                cs.Iflags |= CFoff;
                cdb.gen(&cs);       // MOV EA,&variable
                if (I64 && sz == 8)
                    code_orrex(cdb.last(), REX_W);
                if (sz > REGSIZE)
                {
                    cs.Iop = 0x8C;
                    getlvalue_msw(&cs);
                    cs.Irm |= modregrm(0,3,0);
                    cdb.gen(&cs);   // MOV EA+2,DS
                }
            }
            else
            {
                assert(e2oper == OPconst);
                cs.IFL2 = FLconst;
                targ_size_t *p = (targ_size_t *) &(e2->EV);
                cs.IEV2.Vsize_t = *p;
                // Look for loading a register variable
                if ((cs.Irm & 0xC0) == 0xC0)
                {   unsigned reg = cs.Irm & 7;

                    if (cs.Irex & REX_B)
                        reg |= 8;
                    if (I64 && sz == 8)
                        movregconst(cdb,reg,*p,64);
                    else
                        movregconst(cdb,reg,*p,1 ^ (cs.Iop & 1));
                    if (sz == 2 * REGSIZE)
                    {   getlvalue_msw(&cs);
                        if (REGSIZE == 2)
                            movregconst(cdb,cs.Irm & 7,((unsigned short *)p)[1],0);
                        else if (REGSIZE == 4)
                            movregconst(cdb,cs.Irm & 7,((unsigned *)p)[1],0);
                        else if (REGSIZE == 8)
                            movregconst(cdb,cs.Irm & 7,p[1],0);
                        else
                            assert(0);
                    }
                }
                else if (I64 && sz == 8 && *p >= 0x80000000)
                {   // Use 64 bit MOV, as the 32 bit one gets sign extended
                    // MOV reg,imm64
                    // MOV EA,reg
                    regm_t rregm = allregs & ~idxregm(&cs);
                    unsigned reg;
                    regwithvalue(cdb,rregm,*p,&reg,64);
                    cs.Iop = 0x89;
                    cs.Irm |= modregrm(0,reg & 7,0);
                    if (reg & 8)
                        cs.Irex |= REX_R;
                    cdb.gen(&cs);
                }
                else
                {
                    int i = sz;
                    do
                    {   int regsize = REGSIZE;
                        if (i >= 4 && I16 && I386)
                        {
                            regsize = 4;
                            cs.Iflags |= CFopsize;      // use opsize to do 32 bit operation
                        }
                        else if (I64 && sz == 16 && *p >= 0x80000000)
                        {
                            regm_t rregm = allregs & ~idxregm(&cs);
                            unsigned reg;
                            regwithvalue(cdb,rregm,*p,&reg,64);
                            cs.Iop = 0x89;
                            cs.Irm |= modregrm(0,reg & 7,0);
                            if (reg & 8)
                                cs.Irex |= REX_R;
                        }
                        else
                        {
                            regm_t retregs = (sz == 1) ? BYTEREGS : allregs;
                            unsigned reg;
                            if (reghasvalue(retregs,*p,&reg))
                            {
                                cs.Iop = (cs.Iop & 1) | 0x88;
                                cs.Irm |= modregrm(0,reg & 7,0); // MOV EA,reg
                                if (reg & 8)
                                    cs.Irex |= REX_R;
                                if (I64 && sz == 1 && reg >= 4)
                                    cs.Irex |= REX;
                            }
                            if (!I16 && i == 2)      // if 16 bit operand
                                cs.Iflags |= CFopsize;
                            if (I64 && sz == 8)
                                cs.Irex |= REX_W;
                        }
                        cdb.gen(&cs);           // MOV EA,const

                        p = (targ_size_t *)((char *) p + regsize);
                        cs.Iop = (cs.Iop & 1) | 0xC6;
                        cs.Irm &= ~modregrm(0,7,0);
                        cs.Irex &= ~REX_R;
                        cs.IEVoffset1 += regsize;
                        cs.IEV2.Vint = *p;
                        i -= regsize;
                    } while (i > 0);
                }
            }
            freenode(e2);
            goto Lp;
        }
        retregs = allregs;              // pick a reg, any reg
        if (sz == 2 * REGSIZE)
            retregs &= ~mBP;            // BP cannot be used for register pair
  }
  if (retregs == mPSW)
  {     retregs = allregs;
        if (sz == 2 * REGSIZE)
            retregs &= ~mBP;            // BP cannot be used for register pair
  }
  cs.Iop = 0x89;
  if (sz == 1)                  // must have byte regs
  {     cs.Iop = 0x88;
        retregs &= BYTEREGS;
        if (!retregs)
                retregs = BYTEREGS;
  }
  else if (retregs & mES
           && (
             (e1->Eoper == OPind &&
                ((tymll = tybasic(e1->E1->Ety)) == TYfptr || tymll == TYhptr)) ||
             (e1->Eoper == OPvar && e1->EV.sp.Vsym->Sfl == FLfardata)
            )
          )
        // getlvalue() needs ES, so we can't return it
        retregs = allregs;              // no conflicts with ES
  else if (tyml == TYdouble || tyml == TYdouble_alias || retregs & mST0)
        retregs = DOUBLEREGS;
  regvar = FALSE;
  varregm = 0;
  if (config.flags4 & CFG4optimized)
  {
        // Be careful of cases like (x = x+x+x). We cannot evaluate in
        // x if x is in a register.
        if (isregvar(e1,&varregm,&varreg) &&    // if lvalue is register variable
            doinreg(e1->EV.sp.Vsym,e2) &&       // and we can compute directly into it
            !(sz == 1 && e1->EV.sp.Voffset == 1)
           )
        {   regvar = TRUE;
            retregs = varregm;
            reg = varreg;       // evaluate directly in target register
            if (tysize(e1->Ety) == REGSIZE &&
                tysize(e1->EV.sp.Vsym->Stype->Tty) == 2 * REGSIZE)
            {
                if (e1->EV.sp.Voffset)
                    retregs &= mMSW;
                else
                    retregs &= mLSW;
                reg = findreg(retregs);
            }
        }
  }
  if (*pretregs & mPSW && !EOP(e1))     // if evaluating e1 couldn't change flags
  {     // Be careful that this lines up with jmpopcode()
        retregs |= mPSW;
        *pretregs &= ~mPSW;
  }
    scodelem(cdb,e2,&retregs,0,TRUE);    // get rvalue

    // Look for special case of (*p++ = ...), where p is a register variable
    if (e1->Eoper == OPind &&
        ((e11 = e1->E1)->Eoper == OPpostinc || e11->Eoper == OPpostdec) &&
        e11->E1->Eoper == OPvar &&
        e11->E1->EV.sp.Vsym->Sfl == FLreg &&
        (!I16 || e11->E1->EV.sp.Vsym->Sregm & IDXREGS)
       )
    {
        Symbol *s = e11->E1->EV.sp.Vsym;
        if (s->Sclass == SCfastpar || s->Sclass == SCshadowreg)
        {
            regcon.params &= ~s->Spregm();
        }

        postinc = e11->E2->EV.Vint;
        if (e11->Eoper == OPpostdec)
            postinc = -postinc;
        getlvalue(cdb,&cs,e11,RMstore | retregs);
        freenode(e11->E2);
        if (I64 && sz < 8)
            cs.Irex &= ~REX_W;                  // incorrectly set by getlvalue()
    }
    else
    {   postinc = 0;
        getlvalue(cdb,&cs,e1,RMstore | retregs);     // get lvalue (cl == CNIL if regvar)
    }

    getregs(cdb,varregm);

    assert(!(retregs & mES && (cs.Iflags & CFSEG) == CFes));
    if ((tyml == TYfptr || tyml == TYhptr) && retregs & mES)
    {
        reg = findreglsw(retregs);
        cs.Irm |= modregrm(0,reg,0);
        cdb.gen(&cs);                   // MOV EA,reg
        getlvalue_msw(&cs);             // point to where segment goes
        cs.Iop = 0x8C;
        NEWREG(cs.Irm,0);
        cdb.gen(&cs);                   // MOV EA+2,ES
    }
    else
    {
        if (!I16)
        {
            reg = findreg(retregs &
                    ((sz > REGSIZE) ? mBP | mLSW : mBP | ALLREGS));
            cs.Irm |= modregrm(0,reg & 7,0);
            if (reg & 8)
                cs.Irex |= REX_R;
            for (; TRUE; sz -= REGSIZE)
            {
                // Do not generate mov from register onto itself
                if (regvar && reg == ((cs.Irm & 7) | (cs.Irex & REX_B ? 8 : 0)))
                    break;
                if (sz == 2)            // if 16 bit operand
                    cs.Iflags |= CFopsize;
                else if (sz == 1 && reg >= 4)
                    cs.Irex |= REX;
                cdb.gen(&cs);           // MOV EA+offset,reg
                if (sz <= REGSIZE)
                    break;
                getlvalue_msw(&cs);
                reg = findregmsw(retregs);
                code_newreg(&cs, reg);
            }
        }
        else
        {
            if (sz > REGSIZE)
                cs.IEVoffset1 += sz - REGSIZE;  // 0,2,6
            reg = findreg(retregs &
                    (sz > REGSIZE ? mMSW : ALLREGS));
            if (tyml == TYdouble || tyml == TYdouble_alias)
                reg = AX;
            cs.Irm |= modregrm(0,reg,0);
            // Do not generate mov from register onto itself
            if (!regvar || reg != (cs.Irm & 7))
                for (; TRUE; sz -= REGSIZE)             // 1,2,4
                {
                    cdb.gen(&cs);             // MOV EA+offset,reg
                    if (sz <= REGSIZE)
                        break;
                    cs.IEVoffset1 -= REGSIZE;
                    if (tyml == TYdouble || tyml == TYdouble_alias)
                            reg = dblreg[reg];
                    else
                            reg = findreglsw(retregs);
                    NEWREG(cs.Irm,reg);
                }
        }
  }
  if (e1->Ecount ||                     // if lvalue is a CSE or
      regvar)                           // rvalue can't be a CSE
  {
        getregs_imm(cdb,retregs);       // necessary if both lvalue and
                                        //  rvalue are CSEs (since a reg
                                        //  can hold only one e at a time)
        cssave(e1,retregs,EOP(e1));     // if lvalue is a CSE
  }

    fixresult(cdb,e,retregs,pretregs);
Lp:
    if (postinc)
    {
        int reg = findreg(idxregm(&cs));
        if (*pretregs & mPSW)
        {   // Use LEA to avoid touching the flags
            unsigned rm = cs.Irm & 7;
            if (cs.Irex & REX_B)
                rm |= 8;
            cdb.genc1(0x8D,buildModregrm(2,reg,rm),FLconst,postinc);
            if (tysize(e11->E1->Ety) == 8)
                code_orrex(cdb.last(), REX_W);
        }
        else if (I64)
        {
            cdb.genc2(0x81,modregrmx(3,0,reg),postinc);
            if (tysize(e11->E1->Ety) == 8)
                code_orrex(cdb.last(), REX_W);
        }
        else
        {
            if (postinc == 1)
                cdb.gen1(0x40 + reg);         // INC reg
            else if (postinc == -(targ_int)1)
                cdb.gen1(0x48 + reg);         // DEC reg
            else
            {
                cdb.genc2(0x81,modregrm(3,0,reg),postinc);
            }
        }
    }
    freenode(e1);
}


/************************
 * Generate code for += -= &= |= ^= negass
 */

void cdaddass(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    //printf("cdaddass(e=%p, *pretregs = %s)\n",e,regm_str(*pretregs));
    unsigned op = e->Eoper;
    regm_t retregs = 0;
    unsigned reverse = 0;
    elem *e1 = e->E1;
    tym_t tyml = tybasic(e1->Ety);            // type of lvalue
    int sz = _tysize[tyml];
    int byte = (sz == 1);                     // 1 for byte operation, else 0

    // See if evaluate in XMM registers
    if (config.fpxmmregs && tyxmmreg(tyml) && op != OPnegass && !(*pretregs & mST0))
    {
        xmmopass(cdb,e,pretregs);
        return;
    }

    if (tyfloating(tyml))
    {
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        if (op == OPnegass)
            cdnegass87(cdb,e,pretregs);
        else
            opass87(cdb,e,pretregs);
#else
        if (op == OPnegass)
            opnegassdbl(cdb,e,pretregs);
        else
            opassdbl(cdb,e,pretregs,op);
#endif
        return;
    }
    unsigned opsize = (I16 && tylong(tyml) && config.target_cpu >= TARGET_80386)
        ? CFopsize : 0;
    unsigned cflags = 0;
    regm_t forccs = *pretregs & mPSW;            // return result in flags
    regm_t forregs = *pretregs & ~mPSW;          // return result in regs
    // TRUE if we want the result in a register
    unsigned wantres = forregs || (e1->Ecount && EOP(e1));

    unsigned reg,op1,op2,mode;
    code cs;
    elem *e2;
    regm_t varregm;
    unsigned varreg;
    unsigned jop;


  switch (op)                   // select instruction opcodes
  {     case OPpostinc: op = OPaddass;                  // i++ => +=
        case OPaddass:  op1 = 0x01; op2 = 0x11;
                        cflags = CFpsw;
                        mode = 0; break;                // ADD, ADC
        case OPpostdec: op = OPminass;                  // i-- => -=
        case OPminass:  op1 = 0x29; op2 = 0x19;
                        cflags = CFpsw;
                        mode = 5; break;                // SUB, SBC
        case OPandass:  op1 = op2 = 0x21;
                        mode = 4; break;                // AND, AND
        case OPorass:   op1 = op2 = 0x09;
                        mode = 1; break;                // OR , OR
        case OPxorass:  op1 = op2 = 0x31;
                        mode = 6; break;                // XOR, XOR
        case OPnegass:  op1 = 0xF7;                     // NEG
                        break;
        default:
                assert(0);
  }
  op1 ^= byte;                  // bit 0 is 0 for byte operation

  if (op == OPnegass)
  {
        getlvalue(cdb,&cs,e1,0);
        modEA(cdb,&cs);
        cs.Irm |= modregrm(0,3,0);
        cs.Iop = op1;
        switch (_tysize[tyml])
        {   case CHARSIZE:
                cdb.gen(&cs);
                break;

            case SHORTSIZE:
                cdb.gen(&cs);
                if (!I16 && *pretregs & mPSW)
                    cdb.last()->Iflags |= CFopsize | CFpsw;
                break;

            case LONGSIZE:
                if (!I16 || opsize)
                {   cdb.gen(&cs);
                    cdb.last()->Iflags |= opsize;
                    break;
                }
            neg_2reg:
                getlvalue_msw(&cs);
                cdb.gen(&cs);              // NEG EA+2
                getlvalue_lsw(&cs);
                cdb.gen(&cs);              // NEG EA
                code_orflag(cdb.last(),CFpsw);
                cs.Iop = 0x81;
                getlvalue_msw(&cs);
                cs.IFL2 = FLconst;
                cs.IEV2.Vuns = 0;
                cdb.gen(&cs);              // SBB EA+2,0
                break;

            case LLONGSIZE:
                if (I16)
                    assert(0);             // not implemented yet
                if (I32)
                    goto neg_2reg;
                cdb.gen(&cs);
                break;

            default:
                assert(0);
        }
        forccs = 0;             // flags already set by NEG
        *pretregs &= ~mPSW;
  }
  else if ((e2 = e->E2)->Eoper == OPconst &&    // if rvalue is a const
      el_signx32(e2) &&
       // Don't evaluate e2 in register if we can use an INC or DEC
      (((sz <= REGSIZE || tyfv(tyml)) &&
        (op == OPaddass || op == OPminass) &&
        (el_allbits(e2, 1) || el_allbits(e2, -1))
       ) ||
       (!evalinregister(e2)
        && tyml != TYhptr
        )
      )
     )
  {
        getlvalue(cdb,&cs,e1,0);
        modEA(cdb,&cs);
        cs.IFL2 = FLconst;
        cs.IEV2.Vsize_t = e2->EV.Vint;
        if (sz <= REGSIZE || tyfv(tyml) || opsize)
        {
            targ_int i = cs.IEV2.Vint;

            // Handle shortcuts. Watch out for if result has
            // to be in flags.

            if (reghasvalue(byte ? BYTEREGS : ALLREGS,i,&reg) && i != 1 && i != -1 &&
                !opsize)
            {
                cs.Iop = op1;
                cs.Irm |= modregrm(0,reg & 7,0);
                if (I64)
                {   if (byte && reg >= 4)
                        cs.Irex |= REX;
                    if (reg & 8)
                        cs.Irex |= REX_R;
                }
            }
            else
            {
                cs.Iop = 0x81;
                cs.Irm |= modregrm(0,mode,0);
                switch (op)
                {   case OPminass:      // convert to +=
                        cs.Irm ^= modregrm(0,5,0);
                        i = -i;
                        cs.IEV2.Vsize_t = i;
                        // FALL-THROUGH
                    case OPaddass:
                        if (i == 1)             // INC EA
                                goto L1;
                        else if (i == -1)       // DEC EA
                        {       cs.Irm |= modregrm(0,1,0);
                           L1:  cs.Iop = 0xFF;
                        }
                        break;
                }
                cs.Iop ^= byte;             // for byte operations
            }
            cs.Iflags |= opsize;
            if (forccs)
                cs.Iflags |= CFpsw;
            else if (!I16 && cs.Iflags & CFopsize)
            {
                switch (op)
                {   case OPorass:
                    case OPxorass:
                        cs.IEV2.Vsize_t &= 0xFFFF;
                        cs.Iflags &= ~CFopsize; // don't worry about MSW
                        break;
                    case OPandass:
                        cs.IEV2.Vsize_t |= ~0xFFFFLL;
                        cs.Iflags &= ~CFopsize; // don't worry about MSW
                        break;
                    case OPminass:
                    case OPaddass:
#if 1
                        if ((cs.Irm & 0xC0) == 0xC0)    // EA is register
                            cs.Iflags &= ~CFopsize;
#else
                        if ((cs.Irm & 0xC0) == 0xC0 &&  // EA is register and
                            e1->Eoper == OPind)         // not a register var
                            cs.Iflags &= ~CFopsize;
#endif
                        break;
                    default:
                        assert(0);
                        break;
                }
            }

            // For scheduling purposes, we wish to replace:
            //    OP    EA
            // with:
            //    MOV   reg,EA
            //    OP    reg
            //    MOV   EA,reg
            if (forregs && sz <= REGSIZE && (cs.Irm & 0xC0) != 0xC0 &&
                (config.target_cpu == TARGET_Pentium ||
                 config.target_cpu == TARGET_PentiumMMX) &&
                config.flags4 & CFG4speed)
            {   regm_t sregm;
                code cs2;

                // Determine which registers to use
                sregm = allregs & ~idxregm(&cs);
                if (byte)
                    sregm &= BYTEREGS;
                if (sregm & forregs)
                    sregm &= forregs;

                allocreg(cdb,&sregm,&reg,tyml);      // allocate register

                cs2 = cs;
                cs2.Iflags &= ~CFpsw;
                cs2.Iop = 0x8B ^ byte;
                code_newreg(&cs2, reg);
                cdb.gen(&cs2);                      // MOV reg,EA

                cs.Irm = (cs.Irm & modregrm(0,7,0)) | modregrm(3,0,reg & 7);
                if (reg & 8)
                    cs.Irex |= REX_B;
                cdb.gen(&cs);                       // OP reg

                cs2.Iop ^= 2;
                cdb.gen(&cs2);                      // MOV EA,reg

                retregs = sregm;
                wantres = 0;
                if (e1->Ecount)
                    cssave(e1,retregs,EOP(e1));
            }
            else
            {
                cdb.gen(&cs);
                cs.Iflags &= ~opsize;
                cs.Iflags &= ~CFpsw;
                if (I16 && opsize)                     // if DWORD operand
                    cs.IEVoffset1 += 2; // compensate for wantres code
            }
        }
        else if (sz == 2 * REGSIZE)
        {       targ_uns msw;

                cs.Iop = 0x81;
                cs.Irm |= modregrm(0,mode,0);
                cs.Iflags |= cflags;
                cdb.gen(&cs);
                cs.Iflags &= ~CFpsw;

                getlvalue_msw(&cs);             // point to msw
                msw = MSREG(e->E2->EV.Vllong);
                cs.IEV2.Vuns = msw;             // msw of constant
                switch (op)
                {   case OPminass:
                        cs.Irm ^= modregrm(0,6,0);      // SUB => SBB
                        break;
                    case OPaddass:
                        cs.Irm |= modregrm(0,2,0);      // ADD => ADC
                        break;
                }
                cdb.gen(&cs);
        }
        else
            assert(0);
        freenode(e->E2);        // don't need it anymore
  }
  else if (isregvar(e1,&varregm,&varreg) &&
           (e2->Eoper == OPvar || e2->Eoper == OPind) &&
          !evalinregister(e2) &&
           sz <= REGSIZE)               // deal with later
  {
        getlvalue(cdb,&cs,e2,0);
        freenode(e2);
        getregs(cdb,varregm);
        code_newreg(&cs, varreg);
        if (I64 && sz == 1 && varreg >= 4)
            cs.Irex |= REX;
        cs.Iop = op1 ^ 2;                       // toggle direction bit
        if (forccs)
            cs.Iflags |= CFpsw;
        reverse = 2;                            // remember we toggled it
        cdb.gen(&cs);
        retregs = 0;            // to trigger a bug if we attempt to use it
  }
  else if ((op == OPaddass || op == OPminass) &&
        sz <= REGSIZE &&
        !e2->Ecount &&
            ((jop = jmpopcode(e2)) == JC || jop == JNC ||
             (OTconv(e2->Eoper) && !e2->E1->Ecount && ((jop = jmpopcode(e2->E1)) == JC || jop == JNC)))
        )
  {
        /* e1 += (x < y)    ADC EA,0
         * e1 -= (x < y)    SBB EA,0
         * e1 += (x >= y)   SBB EA,-1
         * e1 -= (x >= y)   ADC EA,-1
         */
        getlvalue(cdb,&cs,e1,0);             // get lvalue
        modEA(cdb,&cs);
        regm_t keepmsk = idxregm(&cs);
        retregs = mPSW;
        if (OTconv(e2->Eoper))
        {
            scodelem(cdb,e2->E1,&retregs,keepmsk,TRUE);
            freenode(e2);
        }
        else
            scodelem(cdb,e2,&retregs,keepmsk,TRUE);
        cs.Iop = 0x81 ^ byte;                   // ADC EA,imm16/32
        unsigned reg = 2;                       // ADC
        if ((op == OPaddass) ^ (jop == JC))
            reg = 3;                            // SBB
        code_newreg(&cs,reg);
        cs.Iflags |= opsize;
        if (forccs)
            cs.Iflags |= CFpsw;
        cs.IFL2 = FLconst;
        cs.IEV2.Vsize_t = (jop == JC) ? 0 : ~(targ_size_t)0;
        cdb.gen(&cs);
        retregs = 0;            // to trigger a bug if we attempt to use it
  }
  else // evaluate e2 into register
  {
        retregs = (byte) ? BYTEREGS : ALLREGS;  // pick working reg
        if (tyml == TYhptr)
            retregs &= ~mCX;                    // need CX for shift count
        scodelem(cdb,e->E2,&retregs,0,TRUE);   // get rvalue
        getlvalue(cdb,&cs,e1,retregs);         // get lvalue
        modEA(cdb,&cs);
        cs.Iop = op1;
        if (sz <= REGSIZE || tyfv(tyml))
        {   reg = findreg(retregs);
            code_newreg(&cs, reg);              // OP1 EA,reg
            if (sz == 1 && reg >= 4 && I64)
                cs.Irex |= REX;
            if (forccs)
                cs.Iflags |= CFpsw;
        }
        else if (tyml == TYhptr)
        {
            unsigned mreg = findregmsw(retregs);
            unsigned lreg = findreglsw(retregs);
            getregs(cdb,retregs | mCX);

            // If h -= l, convert to h += -l
            if (e->Eoper == OPminass)
            {
                cdb.gen2(0xF7,modregrm(3,3,mreg));      // NEG mreg
                cdb.gen2(0xF7,modregrm(3,3,lreg));      // NEG lreg
                code_orflag(cdb.last(),CFpsw);
                cdb.genc2(0x81,modregrm(3,3,mreg),0);   // SBB mreg,0
            }
            cs.Iop = 0x01;
            cs.Irm |= modregrm(0,lreg,0);
            cdb.gen(&cs);                               // ADD EA,lreg
            code_orflag(cdb.last(),CFpsw);
            cdb.genc2(0x81,modregrm(3,2,mreg),0);       // ADC mreg,0
            genshift(cdb);                              // MOV CX,offset __AHSHIFT
            cdb.gen2(0xD3,modregrm(3,4,mreg));          // SHL mreg,CL
            NEWREG(cs.Irm,mreg);                        // ADD EA+2,mreg
            getlvalue_msw(&cs);
        }
        else if (sz == 2 * REGSIZE)
        {
            cs.Irm |= modregrm(0,findreglsw(retregs),0);
            cdb.gen(&cs);                               // OP1 EA,reg+1
            code_orflag(cdb.last(),cflags);
            cs.Iop = op2;
            NEWREG(cs.Irm,findregmsw(retregs)); // OP2 EA+1,reg
            getlvalue_msw(&cs);
        }
        else
            assert(0);
        cdb.gen(&cs);
        retregs = 0;            // to trigger a bug if we attempt to use it
  }

  // See if we need to reload result into a register.
  // Need result in registers in case we have a 32 bit
  // result and we want the flags as a result.
  if (wantres || (sz > REGSIZE && forccs))
  {
        if (sz <= REGSIZE)
        {   regm_t possregs;

            possregs = ALLREGS;
            if (byte)
                possregs = BYTEREGS;
            retregs = forregs & possregs;
            if (!retregs)
                retregs = possregs;

            // If reg field is destination
            if (cs.Iop & 2 && cs.Iop < 0x40 && (cs.Iop & 7) <= 5)
            {
                reg = (cs.Irm >> 3) & 7;
                if (cs.Irex & REX_R)
                    reg |= 8;
                retregs = mask[reg];
                allocreg(cdb,&retregs,&reg,tyml);
            }
            // If lvalue is a register, just use that register
            else if ((cs.Irm & 0xC0) == 0xC0)
            {
                reg = cs.Irm & 7;
                if (cs.Irex & REX_B)
                    reg |= 8;
                retregs = mask[reg];
                allocreg(cdb,&retregs,&reg,tyml);
            }
            else
            {
                allocreg(cdb,&retregs,&reg,tyml);
                cs.Iop = 0x8B ^ byte ^ reverse;
                code_newreg(&cs, reg);
                if (I64 && byte && reg >= 4)
                    cs.Irex |= REX_W;
                cdb.gen(&cs);               // MOV reg,EA
            }
        }
        else if (tyfv(tyml) || tyml == TYhptr)
        {       regm_t idxregs;

                if (tyml == TYhptr)
                    getlvalue_lsw(&cs);
                idxregs = idxregm(&cs);
                retregs = forregs & ~idxregs;
                if (!(retregs & IDXREGS))
                        retregs |= IDXREGS & ~idxregs;
                if (!(retregs & mMSW))
                        retregs |= mMSW & ALLREGS;
                allocreg(cdb,&retregs,&reg,tyml);
                NEWREG(cs.Irm,findreglsw(retregs));
                if (retregs & mES)              // if want ES loaded
                {   cs.Iop = 0xC4;
                    cdb.gen(&cs);               // LES lreg,EA
                }
                else
                {   cs.Iop = 0x8B;
                    cdb.gen(&cs);               // MOV lreg,EA
                    getlvalue_msw(&cs);
                    if (I32)
                        cs.Iflags |= CFopsize;
                    NEWREG(cs.Irm,reg);
                    cdb.gen(&cs);               // MOV mreg,EA+2
                }
        }
        else if (sz == 2 * REGSIZE)
        {
            regm_t idx = idxregm(&cs);
            retregs = forregs;
            if (!retregs)
                retregs = ALLREGS;
            allocreg(cdb,&retregs,&reg,tyml);
            cs.Iop = 0x8B;
            NEWREG(cs.Irm,reg);

            code csl = cs;
            NEWREG(csl.Irm,findreglsw(retregs));
            getlvalue_lsw(&csl);

            if (mask[reg] & idx)
            {
                cdb.gen(&csl);             // MOV reg+1,EA
                cdb.gen(&cs);              // MOV reg,EA+2
            }
            else
            {
                cdb.gen(&cs);              // MOV reg,EA+2
                cdb.gen(&csl);             // MOV reg+1,EA
            }
        }
        else
            assert(0);
        if (e1->Ecount)                 // if we gen a CSE
                cssave(e1,retregs,EOP(e1));
    }
    freenode(e1);
    if (sz <= REGSIZE)
        *pretregs &= ~mPSW;            // flags are already set
    fixresult(cdb,e,retregs,pretregs);
}

/********************************
 * Generate code for *= /= %=
 */

void cdmulass(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    code cs;
    regm_t retregs;
    unsigned resreg,reg,opr,lib,byte;

    //printf("cdmulass(e=%p, *pretregs = %s)\n",e,regm_str(*pretregs));
    elem *e1 = e->E1;
    elem *e2 = e->E2;
    unsigned op = e->Eoper;                     // OPxxxx

    tym_t tyml = tybasic(e1->Ety);              // type of lvalue
    char uns = tyuns(tyml) || tyuns(e2->Ety);
    unsigned sz = _tysize[tyml];

    unsigned rex = (I64 && sz == 8) ? REX_W : 0;
    unsigned grex = rex << 16;          // 64 bit operands

    // See if evaluate in XMM registers
    if (config.fpxmmregs && tyxmmreg(tyml) && op != OPmodass && !(*pretregs & mST0))
    {
        xmmopass(cdb,e,pretregs);
        return;
    }

    if (tyfloating(tyml))
    {
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        opass87(cdb,e,pretregs);
#else
        opassdbl(cdb,e,pretregs,op);
#endif
        return;
    }

    if (sz <= REGSIZE)                  // if word or byte
    {
        byte = (sz == 1);               // 1 for byte operation
        resreg = AX;                    // result register for * or /
        if (uns)                        // if unsigned operation
            opr = 4;                    // MUL
        else                            // else signed
            opr = 5;                    // IMUL
        if (op != OPmulass)             // if /= or %=
        {
            opr += 2;                   // MUL => DIV, IMUL => IDIV
            if (op == OPmodass)
                resreg = DX;            // remainder is in DX
        }
        if (op == OPmulass)             // if multiply
        {
            if (config.target_cpu >= TARGET_80286 &&
                e2->Eoper == OPconst && !byte)
            {
                targ_size_t e2factor = el_tolong(e2);
                if (I64 && sz == 8 && e2factor != (int)e2factor)
                    goto L1;
                freenode(e2);
                getlvalue(cdb,&cs,e1,0);     // get EA
                regm_t idxregs = idxregm(&cs);
                retregs = *pretregs & (ALLREGS | mBP) & ~idxregs;
                if (!retregs)
                    retregs = ALLREGS & ~idxregs;
                allocreg(cdb,&retregs,&resreg,tyml);
                cs.Iop = 0x69;                  // IMUL reg,EA,e2value
                cs.IFL2 = FLconst;
                cs.IEV2.Vint = e2factor;
                opr = resreg;
            }
            else if (!I16 && !byte)
            {
             L1:
                retregs = *pretregs & (ALLREGS | mBP);
                if (!retregs)
                    retregs = ALLREGS;
                codelem(cdb,e2,&retregs,FALSE); // load rvalue in reg
                getlvalue(cdb,&cs,e1,retregs);  // get EA
                getregs(cdb,retregs);           // destroy these regs
                cs.Iop = 0x0FAF;                        // IMUL resreg,EA
                resreg = findreg(retregs);
                opr = resreg;
            }
            else
            {
                retregs = mAX;
                codelem(cdb,e2,&retregs,FALSE);      // load rvalue in AX
                getlvalue(cdb,&cs,e1,mAX);           // get EA
                getregs(cdb,byte ? mAX : mAX | mDX); // destroy these regs
                cs.Iop = 0xF7 ^ byte;                        // [I]MUL EA
            }
            code_newreg(&cs,opr);
            cdb.gen(&cs);
        }
        else // /= or %=
        {   targ_size_t e2factor;
            int pow2;

            assert(!byte);                      // should never happen
            assert(I16 || sz != SHORTSIZE);
            if (config.flags4 & CFG4speed &&
                e2->Eoper == OPconst && !uns &&
                (sz == REGSIZE || (I64 && sz == 4)) &&
                (pow2 = ispow2(e2factor = el_tolong(e2))) != -1 &&
                e2factor == (int)e2factor &&
                !(config.target_cpu < TARGET_80286 && pow2 != 1 && op == OPdivass)
               )
            {
                // Signed divide or modulo by power of 2
                getlvalue(cdb,&cs,e1,mAX | mDX);
                cs.Iop = 0x8B;
                code_newreg(&cs, AX);
                cdb.gen(&cs);                       // MOV AX,EA
                freenode(e2);
                getregs(cdb,mAX | mDX);     // trash these regs
                cdb.gen1(0x99);                     // CWD
                code_orrex(cdb.last(), rex);
                if (pow2 == 1)
                {
                    if (op == OPdivass)
                    {   cdb.gen2(0x2B,grex | modregrm(3,AX,DX));       // SUB AX,DX
                        cdb.gen2(0xD1,grex | modregrm(3,7,AX));        // SAR AX,1
                        resreg = AX;
                    }
                    else // OPmod
                    {   cdb.gen2(0x33,grex | modregrm(3,AX,DX));       // XOR AX,DX
                        cdb.genc2(0x81,grex | modregrm(3,4,AX),1);     // AND AX,1
                        cdb.gen2(0x03,grex | modregrm(3,DX,AX));       // ADD DX,AX
                        resreg = DX;
                    }
                }
                else
                {
                    assert(pow2 < 32);
                    targ_ulong m = (1 << pow2) - 1;
                    if (op == OPdivass)
                    {   cdb.genc2(0x81,grex | modregrm(3,4,DX),m);     // AND DX,m
                        cdb.gen2(0x03,grex | modregrm(3,AX,DX));       // ADD AX,DX
                        // Be careful not to generate this for 8088
                        assert(config.target_cpu >= TARGET_80286);
                        cdb.genc2(0xC1,grex | modregrm(3,7,AX),pow2);  // SAR AX,pow2
                        resreg = AX;
                    }
                    else // OPmodass
                    {   cdb.gen2(0x33,grex | modregrm(3,AX,DX));       // XOR AX,DX
                        cdb.gen2(0x2B,grex | modregrm(3,AX,DX));       // SUB AX,DX
                        cdb.genc2(0x81,grex | modregrm(3,4,AX),m);     // AND AX,m
                        cdb.gen2(0x33,grex | modregrm(3,AX,DX));       // XOR AX,DX
                        cdb.gen2(0x2B,grex | modregrm(3,AX,DX));       // SUB AX,DX
                        resreg = AX;
                    }
                }
            }
            else
            {
                retregs = ALLREGS & ~(mAX|mDX);         // DX gets sign extension
                codelem(cdb,e2,&retregs,FALSE); // load rvalue in retregs
                reg = findreg(retregs);
                getlvalue(cdb,&cs,e1,mAX | mDX | retregs);     // get EA
                getregs(cdb,mAX | mDX);         // destroy these regs
                cs.Irm |= modregrm(0,AX,0);
                cs.Iop = 0x8B;
                cdb.gen(&cs);                   // MOV AX,EA
                if (uns)                        // if unsigned
                    movregconst(cdb,DX,0,0);      // CLR DX
                else                            // else signed
                {   cdb.gen1(0x99);             // CWD
                    code_orrex(cdb.last(),rex);
                }
                getregs(cdb,mDX | mAX); // DX and AX will be destroyed
                cdb.append(genregs(CNIL,0xF7,opr,reg));   // OPR reg
                code_orrex(cdb.last(),rex);
            }
        }
        cs.Iop = 0x89 ^ byte;
        code_newreg(&cs,resreg);
        cdb.gen(&cs);                           // MOV EA,resreg
        if (e1->Ecount)                         // if we gen a CSE
                cssave(e1,mask[resreg],EOP(e1));
        freenode(e1);
        fixresult(cdb,e,mask[resreg],pretregs);
        return;
  }
  else if (sz == 2 * REGSIZE)
  {
        lib = CLIBlmul;
        if (op == OPdivass || op == OPmodass)
        {       lib = (uns) ? CLIBuldiv : CLIBldiv;
                if (op == OPmodass)
                        lib++;
        }
        retregs = mCX | mBX;
        codelem(cdb,e2,&retregs,FALSE);
        getlvalue(cdb,&cs,e1,mDX|mAX | mCX|mBX);
        getregs(cdb,mDX | mAX);
        cs.Iop = 0x8B;
        cdb.gen(&cs);                   // MOV AX,EA
        getlvalue_msw(&cs);
        cs.Irm |= modregrm(0,DX,0);
        cdb.gen(&cs);                   // MOV DX,EA+2
        getlvalue_lsw(&cs);
        retregs = mDX | mAX;
        if (config.target_cpu >= TARGET_PentiumPro && op == OPmulass)
        {
            /*  IMUL    ECX,EAX
                IMUL    EDX,EBX
                ADD     ECX,EDX
                MUL     EBX
                ADD     EDX,ECX
             */
             getregs(cdb,mAX|mDX|mCX);
             cdb.gen2(0x0FAF,modregrm(3,CX,AX));
             cdb.gen2(0x0FAF,modregrm(3,DX,BX));
             cdb.gen2(0x03,modregrm(3,CX,DX));
             cdb.gen2(0xF7,modregrm(3,4,BX));
             cdb.gen2(0x03,modregrm(3,DX,CX));
        }
        else
        {   if (op == OPmodass)
                retregs = mBX | mCX;
            callclib(cdb,e,lib,&retregs,idxregm(&cs));
        }
        reg = findreglsw(retregs);
        cs.Iop = 0x89;
        NEWREG(cs.Irm,reg);
        cdb.gen(&cs);                   // MOV EA,lsreg
        reg = findregmsw(retregs);
        NEWREG(cs.Irm,reg);
        getlvalue_msw(&cs);
        cdb.gen(&cs);                   // MOV EA+2,msreg
        if (e1->Ecount)                 // if we gen a CSE
                cssave(e1,retregs,EOP(e1));
        freenode(e1);
        fixresult(cdb,e,retregs,pretregs);
        return;
  }
  else
  {     assert(0);
        // NOTREACHED
  }
}


/********************************
 * Generate code for <<= and >>=
 */

void cdshass(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    code cs;
    regm_t retregs;
    unsigned op1,op2,reg;

    elem *e1 = e->E1;
    elem *e2 = e->E2;

    tym_t tyml = tybasic(e1->Ety);              // type of lvalue
    unsigned sz = _tysize[tyml];
    unsigned byte = tybyte(e->Ety) != 0;        // 1 for byte operations
    tym_t tym = tybasic(e->Ety);                // type of result
    unsigned oper = e->Eoper;
    assert(tysize(e2->Ety) <= REGSIZE);

    unsigned rex = (I64 && sz == 8) ? REX_W : 0;

    // if our lvalue is a cse, make sure we evaluate for result in register
    if (e1->Ecount && !(*pretregs & (ALLREGS | mBP)) && !isregvar(e1,&retregs,&reg))
        *pretregs |= ALLREGS;

#if SCPP
    // Do this until the rest of the compiler does OPshr/OPashr correctly
    if (oper == OPshrass)
        oper = tyuns(tyml) ? OPshrass : OPashrass;
#endif

    // Select opcodes. op2 is used for msw for long shifts.

    switch (oper)
    {
        case OPshlass:
            op1 = 4;                    // SHL
            op2 = 2;                    // RCL
            break;
        case OPshrass:
            op1 = 5;                    // SHR
            op2 = 3;                    // RCR
            break;
        case OPashrass:
            op1 = 7;                    // SAR
            op2 = 3;                    // RCR
            break;
        default:
            assert(0);
    }


    unsigned v = 0xD3;                  // for SHIFT xx,CL cases
    unsigned loopcnt = 1;
    unsigned conste2 = FALSE;
    unsigned shiftcnt = 0;              // avoid "use before initialized" warnings
    if (cnst(e2))
    {
        conste2 = TRUE;                 // e2 is a constant
        shiftcnt = e2->EV.Vint;         // byte ordering of host
        if (config.target_cpu >= TARGET_80286 &&
            sz <= REGSIZE &&
            shiftcnt != 1)
            v = 0xC1;                   // SHIFT xx,shiftcnt
        else if (shiftcnt <= 3)
        {   loopcnt = shiftcnt;
            v = 0xD1;                   // SHIFT xx,1
        }
    }

    if (v == 0xD3)                        // if COUNT == CL
    {
        retregs = mCX;
        codelem(cdb,e2,&retregs,FALSE);
    }
    else
        freenode(e2);
    getlvalue(cdb,&cs,e1,mCX);          // get lvalue, preserve CX
    modEA(cdb,&cs);             // check for modifying register

    if (*pretregs == 0 ||               // if don't return result
        (*pretregs == mPSW && conste2 && _tysize[tym] <= REGSIZE) ||
        sz > REGSIZE
       )
    {
        retregs = 0;            // value not returned in a register
        cs.Iop = v ^ byte;
        while (loopcnt--)
        {
            NEWREG(cs.Irm,op1);           // make sure op1 is first
            if (sz <= REGSIZE)
            {
                if (conste2)
                {   cs.IFL2 = FLconst;
                    cs.IEV2.Vint = shiftcnt;
                }
                cdb.gen(&cs);             // SHIFT EA,[CL|1]
                if (*pretregs & mPSW && !loopcnt && conste2)
                  code_orflag(cdb.last(),CFpsw);
            }
            else // TYlong
            {   cs.Iop = 0xD1;            // plain shift
                code *ce = gennop(CNIL);                  // ce: NOP
                if (v == 0xD3)
                {
                    getregs(cdb,mCX);
                    if (!conste2)
                    {   assert(loopcnt == 0);
                        genjmp(cdb,JCXZ,FLcode,(block *) ce);   // JCXZ ce
                    }
                }
                code *cg;
                if (oper == OPshlass)
                {
                    cdb.gen(&cs);               // cg: SHIFT EA
                    cg = cdb.last();
                    code_orflag(cg,CFpsw);
                    getlvalue_msw(&cs);
                    NEWREG(cs.Irm,op2);
                    cdb.gen(&cs);               // SHIFT EA
                    getlvalue_lsw(&cs);
                }
                else
                {
                    getlvalue_msw(&cs);
                    cdb.gen(&cs);
                    cg = cdb.last();
                    code_orflag(cg,CFpsw);
                    NEWREG(cs.Irm,op2);
                    getlvalue_lsw(&cs);
                    cdb.gen(&cs);
                }
                if (v == 0xD3)                    // if building a loop
                {
                    genjmp(cdb,LOOP,FLcode,(block *) cg); // LOOP cg
                    regimmed_set(CX,0);           // note that now CX == 0
                }
                cdb.append(ce);
            }
        }

        // If we want the result, we must load it from the EA
        // into a register.

        if (sz == 2 * REGSIZE && *pretregs)
        {   retregs = *pretregs & (ALLREGS | mBP);
            if (retregs)
            {   retregs &= ~idxregm(&cs);
                allocreg(cdb,&retregs,&reg,tym);
                cs.Iop = 0x8B;

                // be careful not to trash any index regs
                // do MSW first (which can't be an index reg)
                getlvalue_msw(&cs);
                NEWREG(cs.Irm,reg);
                cdb.gen(&cs);
                getlvalue_lsw(&cs);
                reg = findreglsw(retregs);
                NEWREG(cs.Irm,reg);
                cdb.gen(&cs);
                if (*pretregs & mPSW)
                    tstresult(cdb,retregs,tyml,TRUE);
            }
            else        // flags only
            {   retregs = ALLREGS & ~idxregm(&cs);
                allocreg(cdb,&retregs,&reg,TYint);
                cs.Iop = 0x8B;
                NEWREG(cs.Irm,reg);
                cdb.gen(&cs);           // MOV reg,EA
                cs.Iop = 0x0B;          // OR reg,EA+2
                cs.Iflags |= CFpsw;
                getlvalue_msw(&cs);
                cdb.gen(&cs);
            }
        }
    }
    else                                // else must evaluate in register
    {
        if (sz <= REGSIZE)
        {
            regm_t possregs = ALLREGS & ~mCX & ~idxregm(&cs);
            if (byte)
                    possregs &= BYTEREGS;
            retregs = *pretregs & possregs;
            if (retregs == 0)
                    retregs = possregs;
            allocreg(cdb,&retregs,&reg,tym);
            cs.Iop = 0x8B ^ byte;
            code_newreg(&cs, reg);
            if (byte && I64 && (reg >= 4))
                cs.Irex |= REX;
            cdb.gen(&cs);                     // MOV reg,EA
            if (!I16)
            {
                assert(!byte || (mask[reg] & BYTEREGS));
                cdb.genc2(v ^ byte,modregrmx(3,op1,reg),shiftcnt);
                if (byte && I64 && (reg >= 4))
                    cdb.last()->Irex |= REX;
                code_orrex(cdb.last(), rex);
                // We can do a 32 bit shift on a 16 bit operand if
                // it's a left shift and we're not concerned about
                // the flags. Remember that flags are not set if
                // a shift of 0 occurs.
                if (_tysize[tym] == SHORTSIZE &&
                    (oper == OPshrass || oper == OPashrass ||
                     (*pretregs & mPSW && conste2)))
                     cdb.last()->Iflags |= CFopsize;            // 16 bit operand
            }
            else
            {
                while (loopcnt--)
                {   // Generate shift instructions.
                    cdb.genc2(v ^ byte,modregrm(3,op1,reg),shiftcnt);
                }
            }
            if (*pretregs & mPSW && conste2)
            {   assert(shiftcnt);
                *pretregs &= ~mPSW;     // result is already in flags
                code_orflag(cdb.last(),CFpsw);
            }

            cs.Iop = 0x89 ^ byte;
            if (byte && I64 && (reg >= 4))
                cs.Irex |= REX;
            cdb.gen(&cs);                                // MOV EA,reg

            // If result is not in correct register
            fixresult(cdb,e,retregs,pretregs);
            retregs = *pretregs;
        }
        else
            assert(0);
    }
    if (e1->Ecount && !(retregs & regcon.mvar))   // if lvalue is a CSE
        cssave(e1,retregs,EOP(e1));
    freenode(e1);
    *pretregs = retregs;
}


/**********************************
 * Generate code for compares.
 * Handles lt,gt,le,ge,eqeq,ne for all data types.
 */

void cdcmp(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{ regm_t retregs,rretregs;
  unsigned reg,rreg;
  int fl;

  //printf("cdcmp(e = %p, pretregs = %s)\n",e,regm_str(*pretregs));
  // Collect extra parameter. This is pretty ugly...
  int flag = cdcmp_flag;
  cdcmp_flag = 0;

    elem *e1 = e->E1;
    elem *e2 = e->E2;
    if (*pretregs == 0)                 // if don't want result
    {
        codelem(cdb,e1,pretregs,FALSE);
        *pretregs = 0;                  // in case e1 changed it
        codelem(cdb,e2,pretregs,FALSE);
        return;
    }

    unsigned jop = jmpopcode(e);        // must be computed before
                                        // leaves are free'd
    unsigned reverse = 0;

    unsigned op = e->Eoper;
    assert(OTrel(op));
    bool eqorne = (op == OPeqeq) || (op == OPne);

    tym_t tym = tybasic(e1->Ety);
    unsigned sz = _tysize[tym];
    unsigned byte = sz == 1;

    unsigned rex = (I64 && sz == 8) ? REX_W : 0;
    unsigned grex = rex << 16;          // 64 bit operands

    code cs;
    code *ce;
    if (tyfloating(tym))                  // if floating operation
    {
        if (config.fpxmmregs)
        {
            retregs = mPSW;
            if (tyxmmreg(tym))
                orthxmm(cdb,e,&retregs);
            else
                orth87(cdb,e,&retregs);
        }
        else if (config.inline8087)
        {   retregs = mPSW;
            orth87(cdb,e,&retregs);
        }
        else
        {
#if TARGET_WINDOS
            int clib;

            retregs = 0;                /* skip result for now          */
            if (iffalse(e2))            /* second operand is constant 0 */
            {   assert(!eqorne);        /* should be OPbool or OPnot    */
                if (tym == TYfloat)
                {   retregs = FLOATREGS;
                    clib = CLIBftst0;
                }
                else
                {   retregs = DOUBLEREGS;
                    clib = CLIBdtst0;
                }
                if (rel_exception(op))
                    clib += CLIBdtst0exc - CLIBdtst0;
                codelem(cdb,e1,&retregs,FALSE);
                retregs = 0;
                callclib(cdb,e,clib,&retregs,0);
                freenode(e2);
            }
            else
            {   clib = CLIBdcmp;
                if (rel_exception(op))
                    clib += CLIBdcmpexc - CLIBdcmp;
                opdouble(cdb,e,&retregs,clib);
            }
#else
            assert(0);
#endif
        }
        goto L3;
  }

  /* If it's a signed comparison of longs, we have to call a library    */
  /* routine, because we don't know the target of the signed branch     */
  /* (have to set up flags so that jmpopcode() will do it right)        */
  if (!eqorne &&
        (I16 && tym == TYlong  && tybasic(e2->Ety) == TYlong ||
         I32 && tym == TYllong && tybasic(e2->Ety) == TYllong)
     )
  {
        assert(jop != JC && jop != JNC);
        retregs = mDX | mAX;
        codelem(cdb,e1,&retregs,FALSE);
        retregs = mCX | mBX;
        scodelem(cdb,e2,&retregs,mDX | mAX,FALSE);

        if (I16)
        {
            retregs = 0;
            callclib(cdb,e,CLIBlcmp,&retregs,0);    // gross, but it works
        }
        else
        {
            /* Generate:
             *      CMP  EDX,ECX
             *      JNE  C1
             *      XOR  EDX,EDX
             *      CMP  EAX,EBX
             *      JZ   C1
             *      JA   C3
             *      DEC  EDX
             *      JMP  C1
             * C3:  INC  EDX
             * C1:
             */
             getregs(cdb,mDX);
             cdb.append(genregs(CNIL,0x39,CX,DX));             // CMP EDX,ECX
             code *c1 = gennop(CNIL);
             genjmp(cdb,JNE,FLcode,(block *)c1);  // JNE C1
             movregconst(cdb,DX,0,0);             // XOR EDX,EDX
             cdb.append(genregs(CNIL,0x39,BX,AX));             // CMP EAX,EBX
             genjmp(cdb,JE,FLcode,(block *)c1);   // JZ C1
             code *c3 = gen1(CNIL,0x40 + DX);                  // INC EDX
             genjmp(cdb,JA,FLcode,(block *)c3);   // JA C3
             cdb.gen1(0x48 + DX);                              // DEC EDX
             genjmp(cdb,JMPS,FLcode,(block *)c1); // JMP C1
             cdb.append(c3);
             cdb.append(c1);
             getregs(cdb,mDX);
             retregs = mPSW;
        }
        goto L3;
  }

  /* See if we should reverse the comparison, so a JA => JC, and JBE => JNC
   * (This is already reflected in the jop)
   */
  if ((jop == JC || jop == JNC) &&
      (op == OPgt || op == OPle) &&
      (tyuns(tym) || tyuns(e2->Ety))
     )
  {     // jmpopcode() sez comparison should be reversed
        assert(e2->Eoper != OPconst && e2->Eoper != OPrelconst);
        reverse ^= 2;
  }

  /* See if we should swap operands     */
  if (e1->Eoper == OPvar && e2->Eoper == OPvar && evalinregister(e2))
  {     e1 = e->E2;
        e2 = e->E1;
        reverse ^= 2;
  }

  retregs = allregs;
  if (byte)
        retregs = BYTEREGS;

  ce = CNIL;
  cs.Iflags = (!I16 && sz == SHORTSIZE) ? CFopsize : 0;
  cs.Irex = rex;
  if (sz > REGSIZE)
        ce = gennop(ce);

  switch (e2->Eoper)
  {
      default:
      L2:
        scodelem(cdb,e1,&retregs,0,TRUE);      // compute left leaf
      L1:
        rretregs = allregs & ~retregs;
        if (byte)
                rretregs &= BYTEREGS;
        scodelem(cdb,e2,&rretregs,retregs,TRUE);     // get right leaf
        if (sz <= REGSIZE)                              // CMP reg,rreg
        {   reg = findreg(retregs);             // get reg that e1 is in
            rreg = findreg(rretregs);
            cdb.append(genregs(CNIL,0x3B ^ byte ^ reverse,reg,rreg));
            code_orrex(cdb.last(), rex);
            if (!I16 && sz == SHORTSIZE)
                cdb.last()->Iflags |= CFopsize;          // compare only 16 bits
            if (I64 && byte && (reg >= 4 || rreg >= 4))
                cdb.last()->Irex |= REX;                 // address byte registers
        }
        else
        {   assert(sz <= 2 * REGSIZE);

            // Compare MSW, if they're equal then compare the LSW
            reg = findregmsw(retregs);
            rreg = findregmsw(rretregs);
            cdb.append(genregs(CNIL,0x3B ^ reverse,reg,rreg));  // CMP reg,rreg
            if (I32 && sz == 6)
                cdb.last()->Iflags |= CFopsize;         // seg is only 16 bits
            else if (I64)
                code_orrex(cdb.last(), REX_W);
            genjmp(cdb,JNE,FLcode,(block *) ce);   // JNE nop

            reg = findreglsw(retregs);
            rreg = findreglsw(rretregs);
            cdb.append(genregs(CNIL,0x3B ^ reverse,reg,rreg));  // CMP reg,rreg
            if (I64)
                code_orrex(cdb.last(), REX_W);
        }
        break;
      case OPrelconst:
        if (I64 && (config.flags3 & CFG3pic || config.exe == EX_WIN64))
            goto L2;
        fl = el_fl(e2);
        switch (fl)
        {   case FLfunc:
                fl = FLextern;          // so it won't be self-relative
                break;
            case FLdata:
            case FLudata:
            case FLextern:
                if (sz > REGSIZE)       // compare against DS, not DGROUP
                    goto L2;
                break;
            case FLfardata:
                break;
            default:
                goto L2;
        }
        cs.IFL2 = fl;
        cs.IEVsym2 = e2->EV.sp.Vsym;
        if (sz > REGSIZE)
        {   cs.Iflags |= CFseg;
            cs.IEVoffset2 = 0;
        }
        else
        {   cs.Iflags |= CFoff;
            cs.IEVoffset2 = e2->EV.sp.Voffset;
        }
        goto L4;

      case OPconst:
        // If compare against 0
        if (sz <= REGSIZE && *pretregs == mPSW && !boolres(e2) &&
            isregvar(e1,&retregs,&reg)
           )
        {   // Just do a TEST instruction
            cdb.append(genregs(NULL,0x85 ^ byte,reg,reg));      // TEST reg,reg
            cdb.last()->Iflags |= (cs.Iflags & CFopsize) | CFpsw;
            code_orrex(cdb.last(), rex);
            if (I64 && byte && reg >= 4)
                cdb.last()->Irex |= REX;                 // address byte registers
            retregs = mPSW;
            break;
        }

        if (!tyuns(tym) && !tyuns(e2->Ety) &&
            !boolres(e2) && !(*pretregs & mPSW) &&
            (sz == REGSIZE || (I64 && sz == 4)) &&
            (!I16 || op == OPlt || op == OPge))
        {
            assert(*pretregs & (allregs));
            codelem(cdb,e1,pretregs,FALSE);
            reg = findreg(*pretregs);
            getregs(cdb,mask[reg]);
            switch (op)
            {   case OPle:
                    cdb.genc2(0x81,grex | modregrmx(3,0,reg),(unsigned)-1);   // ADD reg,-1
                    code_orflag(cdb.last(), CFpsw);
                    cdb.genc2(0x81,grex | modregrmx(3,2,reg),0);          // ADC reg,0
                    goto oplt;
                case OPgt:
                    cdb.gen2(0xF7,grex | modregrmx(3,3,reg));         // NEG reg
#if TARGET_WINDOS
                    // What does the Windows platform do?
                    //  lower INT_MIN by 1?   See test exe9.c
                    // BUG: fix later
                    code_orflag(cdb.last(), CFpsw);
                    cdb.genc2(0x81,grex | modregrmx(3,3,reg),0);  // SBB reg,0
#endif
                    goto oplt;
                case OPlt:
                oplt:
                    if (!I16)
                        cdb.genc2(0xC1,grex | modregrmx(3,5,reg),sz * 8 - 1); // SHR reg,31
                    else
                    {   /* 8088-286 do not have a barrel shifter, so use this
                           faster sequence
                         */
                        cdb.append(genregs(CNIL,0xD1,0,reg));   // ROL reg,1
                        unsigned regi;
                        if (reghasvalue(allregs,1,&regi))
                            cdb.append(genregs(CNIL,0x23,reg,regi));  // AND reg,regi
                        else
                            cdb.genc2(0x81,modregrm(3,4,reg),1); // AND reg,1
                    }
                    break;
                case OPge:
                    cdb.append(genregs(CNIL,0xD1,4,reg));        // SHL reg,1
                    code_orrex(cdb.last(),rex);
                    code_orflag(cdb.last(), CFpsw);
                    cdb.append(genregs(CNIL,0x19,reg,reg));      // SBB reg,reg
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
            cs.IEV2.Vsize_t = e2->EV.Vcent.msw;
        else if (sz > REGSIZE)
            cs.IEV2.Vint = MSREG(e2->EV.Vllong);
        else
            cs.IEV2.Vsize_t = e2->EV.Vllong;

        // The cmp immediate relies on sign extension of the 32 bit immediate value
        if (I64 && sz >= REGSIZE && cs.IEV2.Vsize_t != (int)cs.IEV2.Vint)
            goto L2;
      L4:
        cs.Iop = 0x81 ^ byte;

        /* if ((e1 is data or a '*' reference) and it's not a
         * common subexpression
         */

        if ((e1->Eoper == OPvar && datafl[el_fl(e1)] ||
             e1->Eoper == OPind) &&
            !evalinregister(e1))
        {
                getlvalue(cdb,&cs,e1,RMload);
                freenode(e1);
                if (evalinregister(e2))
                {
                    retregs = idxregm(&cs);
                    if ((cs.Iflags & CFSEG) == CFes)
                            retregs |= mES;             // take no chances
                    rretregs = allregs & ~retregs;
                    if (byte)
                            rretregs &= BYTEREGS;
                    scodelem(cdb,e2,&rretregs,retregs,TRUE);
                    cs.Iop = 0x39 ^ byte ^ reverse;
                    if (sz > REGSIZE)
                    {
                        rreg = findregmsw(rretregs);
                        cs.Irm |= modregrm(0,rreg,0);
                        getlvalue_msw(&cs);
                        cdb.gen(&cs);              // CMP EA+2,rreg
                        if (I32 && sz == 6)
                            cdb.last()->Iflags |= CFopsize;      // seg is only 16 bits
                        if (I64 && byte && rreg >= 4)
                            cdb.last()->Irex |= REX;
                        genjmp(cdb,JNE,FLcode,(block *) ce); // JNE nop
                        rreg = findreglsw(rretregs);
                        NEWREG(cs.Irm,rreg);
                        getlvalue_lsw(&cs);
                    }
                    else
                    {
                        rreg = findreg(rretregs);
                        code_newreg(&cs, rreg);
                        if (I64 && byte && rreg >= 4)
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
                        if (e2->Eoper == OPrelconst)
                        {   cs.Iflags = (cs.Iflags & ~(CFoff | CFseg)) | CFseg;
                            cs.IEVoffset2 = 0;
                        }
                        getlvalue_msw(&cs);
                        cdb.gen(&cs);              // CMP EA+2,const
                        if (!I16 && sz == 6)
                            cdb.last()->Iflags |= CFopsize;      // seg is only 16 bits
                        genjmp(cdb,JNE,FLcode,(block *) ce); // JNE nop
                        if (e2->Eoper == OPconst)
                            cs.IEV2.Vint = e2->EV.Vllong;
                        else if (e2->Eoper == OPrelconst)
                        {   // Turn off CFseg, on CFoff
                            cs.Iflags ^= CFseg | CFoff;
                            cs.IEVoffset2 = e2->EV.sp.Voffset;
                        }
                        else
                            assert(0);
                        getlvalue_lsw(&cs);
                    }
                    freenode(e2);
                }
                cdb.gen(&cs);
                break;
        }

        if (evalinregister(e2) && !OTassign(e1->Eoper) &&
            !isregvar(e1,NULL,NULL))
        {   regm_t m;

            m = allregs & ~regcon.mvar;
            if (byte)
                m &= BYTEREGS;
            if (m & (m - 1))    // if more than one free register
                goto L2;
        }
        if ((e1->Eoper == OPstrcmp || (OTassign(e1->Eoper) && sz <= REGSIZE)) &&
            !boolres(e2) && !evalinregister(e1))
        {
            retregs = mPSW;
            scodelem(cdb,e1,&retregs,0,FALSE);
            freenode(e2);
            break;
        }
        if (sz <= REGSIZE && !boolres(e2) && e1->Eoper == OPadd && *pretregs == mPSW)
        {
            retregs |= mPSW;
            scodelem(cdb,e1,&retregs,0,FALSE);
            freenode(e2);
            break;
        }
        scodelem(cdb,e1,&retregs,0,TRUE);  // compute left leaf
        if (sz == 1)
        {
            reg = findreg(retregs & allregs);   // get reg that e1 is in
            cs.Irm = modregrm(3,7,reg & 7);
            if (reg & 8)
                cs.Irex |= REX_B;
            if (e1->Eoper == OPvar && e1->EV.sp.Voffset == 1 && e1->EV.sp.Vsym->Sfl == FLreg)
            {   assert(reg < 4);
                cs.Irm |= 4;                    // use upper register half
            }
            if (I64 && reg >= 4)
                cs.Irex |= REX;                 // address byte registers
        }
        else if (sz <= REGSIZE)
        {                                       // CMP reg,const
            reg = findreg(retregs & allregs);   // get reg that e1 is in
            rretregs = allregs & ~retregs;
            if (cs.IFL2 == FLconst && reghasvalue(rretregs,cs.IEV2.Vint,&rreg))
            {
                cdb.append(genregs(CNIL,0x3B,reg,rreg));
                code_orrex(cdb.last(), rex);
                if (!I16)
                    cdb.last()->Iflags |= cs.Iflags & CFopsize;
                freenode(e2);
                break;
            }
            cs.Irm = modregrm(3,7,reg & 7);
            if (reg & 8)
                cs.Irex |= REX_B;
        }
        else if (sz <= 2 * REGSIZE)
        {
            reg = findregmsw(retregs);          // get reg that e1 is in
            cs.Irm = modregrm(3,7,reg);
            cdb.gen(&cs);                       // CMP reg,MSW
            if (I32 && sz == 6)
                cdb.last()->Iflags |= CFopsize;  // seg is only 16 bits
            genjmp(cdb,JNE,FLcode,(block *) ce);  // JNE ce

            reg = findreglsw(retregs);
            cs.Irm = modregrm(3,7,reg);
            if (e2->Eoper == OPconst)
                cs.IEV2.Vint = e2->EV.Vlong;
            else if (e2->Eoper == OPrelconst)
            {   // Turn off CFseg, on CFoff
                cs.Iflags ^= CFseg | CFoff;
                cs.IEVoffset2 = e2->EV.sp.Voffset;
            }
            else
                assert(0);
        }
        else
                assert(0);
        cdb.gen(&cs);                         // CMP sucreg,LSW
        freenode(e2);
        break;

      case OPind:
        if (e2->Ecount)
            goto L2;
        goto L5;

      case OPvar:
#if TARGET_OSX
        if (movOnly(e2))
            goto L2;
#endif
        if ((e1->Eoper == OPvar &&
             isregvar(e2,&rretregs,&reg) &&
             sz <= REGSIZE
            ) ||
            (e1->Eoper == OPind &&
             isregvar(e2,&rretregs,&reg) &&
             !evalinregister(e1) &&
             sz <= REGSIZE
            )
           )
        {
            // CMP EA,e2
            getlvalue(cdb,&cs,e1,RMload);
            freenode(e1);
            cs.Iop = 0x39 ^ byte ^ reverse;
            code_newreg(&cs,reg);
            if (I64 && byte && reg >= 4)
                cs.Irex |= REX;                 // address byte registers
            cdb.gen(&cs);
            freenode(e2);
            break;
        }
      L5:
        scodelem(cdb,e1,&retregs,0,TRUE);      // compute left leaf
        if (sz <= REGSIZE)                      // CMP reg,EA
        {
            reg = findreg(retregs & allregs);   // get reg that e1 is in
            unsigned opsize = cs.Iflags & CFopsize;
            loadea(cdb,e2,&cs,0x3B ^ byte ^ reverse,reg,0,RMload | retregs,0);
            code_orflag(cdb.last(),opsize);
        }
        else if (sz <= 2 * REGSIZE)
        {
            reg = findregmsw(retregs);   // get reg that e1 is in
            // CMP reg,EA
            loadea(cdb,e2,&cs,0x3B ^ reverse,reg,REGSIZE,RMload | retregs,0);
            if (I32 && sz == 6)
                cdb.last()->Iflags |= CFopsize;        // seg is only 16 bits
            genjmp(cdb,JNE,FLcode,(block *) ce);  // JNE ce
            reg = findreglsw(retregs);
            if (e2->Eoper == OPind)
            {
                NEWREG(cs.Irm,reg);
                getlvalue_lsw(&cs);
                cdb.gen(&cs);
            }
            else
                loadea(cdb,e2,&cs,0x3B ^ reverse,reg,0,RMload | retregs,0);
        }
        else
            assert(0);
        freenode(e2);
        break;
    }
    cdb.append(ce);

L3:
  if ((retregs = (*pretregs & (ALLREGS | mBP))) != 0) // if return result in register
  {
        if (config.target_cpu >= TARGET_80386 && !flag && !(jop & 0xFF00))
        {
            regm_t resregs = retregs;
            if (!I64)
            {   resregs &= BYTEREGS;
                if (!resregs)
                    resregs = BYTEREGS;
            }
            allocreg(cdb,&resregs,&reg,TYint);
            cdb.gen2(0x0F90 + (jop & 0x0F),modregrmx(3,0,reg)); // SETcc reg
            if (I64 && reg >= 4)
                code_orrex(cdb.last(),REX);
            if (tysize(e->Ety) > 1)
            {
                cdb.append(genregs(CNIL,0x0FB6,reg,reg));       // MOVZX reg,reg
                if (I64 && sz == 8)
                    code_orrex(cdb.last(),REX_W);
                if (I64 && reg >= 4)
                    code_orrex(cdb.last(),REX);
            }
            *pretregs &= ~mPSW;
            fixresult(cdb,e,resregs,pretregs);
        }
        else
        {
            code *nop = CNIL;
            regm_t save = regcon.immed.mval;
            allocreg(cdb,&retregs,&reg,TYint);
            regcon.immed.mval = save;
            if ((*pretregs & mPSW) == 0 &&
                (jop == JC || jop == JNC))
            {
                getregs(cdb,retregs);
                cdb.append(genregs(CNIL,0x19,reg,reg));     // SBB reg,reg
                if (rex)
                    code_orrex(cdb.last(), rex);
                if (flag)
                    ;                                       // cdcond() will handle it
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
                {   cdb.gen2(0xF7,modregrmx(3,3,reg));      // NEG reg
                    code_orrex(cdb.last(), rex);
                }
            }
            else if (I64 && sz == 8)
            {
                assert(!flag);
                movregconst(cdb,reg,1,64|8);   // MOV reg,1
                nop = gennop(nop);
                genjmp(cdb,jop,FLcode,(block *) nop);  // Jtrue nop
                                                            // MOV reg,0
                movregconst(cdb,reg,0,(*pretregs & mPSW) ? 64|8 : 64);
                regcon.immed.mval &= ~mask[reg];
            }
            else
            {
                assert(!flag);
                movregconst(cdb,reg,1,8);      // MOV reg,1
                nop = gennop(nop);
                genjmp(cdb,jop,FLcode,(block *) nop);  // Jtrue nop
                                                            // MOV reg,0
                movregconst(cdb,reg,0,(*pretregs & mPSW) ? 8 : 0);
                regcon.immed.mval &= ~mask[reg];
            }
            *pretregs = retregs;
            cdb.append(nop);
        }
    }
ret:
    ;
}


/**********************************
 * Generate code for signed compare of longs.
 * Input:
 *      targ    block* or code*
 */

void longcmp(CodeBuilder& cdb,elem *e,bool jcond,unsigned fltarg,code *targ)
{
                                         // <=  >   <   >=
    static const unsigned char jopmsw[4] = {JL, JG, JL, JG };
    static const unsigned char joplsw[4] = {JBE, JA, JB, JAE };

    //printf("longcmp(e = %p)\n", e);
    elem *e1 = e->E1;
    elem *e2 = e->E2;
    unsigned op = e->Eoper;

    // See if we should swap operands
    if (e1->Eoper == OPvar && e2->Eoper == OPvar && evalinregister(e2))
    {
        e1 = e->E2;
        e2 = e->E1;
        op = swaprel(op);
    }

    code cs;
    cs.Iflags = 0;
    cs.Irex = 0;

    code *ce = gennop(CNIL);
    regm_t retregs = ALLREGS;
    regm_t rretregs;
    unsigned reg,rreg;

    unsigned jop = jopmsw[op - OPle];
    if (!(jcond & 1)) jop ^= (JL ^ JG);                   // toggle jump condition
    CodeBuilder cdbjmp;
    genjmp(cdbjmp,jop,fltarg,(block *) targ);             // Jx targ
    genjmp(cdbjmp,jop ^ (JL ^ JG),FLcode,(block *) ce);   // Jy nop

  switch (e2->Eoper)
  {
      default:
      L2:
        scodelem(cdb,e1,&retregs,0,TRUE);      // compute left leaf
        rretregs = ALLREGS & ~retregs;
        scodelem(cdb,e2,&rretregs,retregs,TRUE);     // get right leaf
        cse_flush(cdb,1);
        // Compare MSW, if they're equal then compare the LSW
        reg = findregmsw(retregs);
        rreg = findregmsw(rretregs);
        cdb.append(genregs(CNIL,0x3B,reg,rreg));        // CMP reg,rreg
        cdb.append(cdbjmp);

        reg = findreglsw(retregs);
        rreg = findreglsw(rretregs);
        cdb.append(genregs(CNIL,0x3B,reg,rreg));        // CMP reg,rreg
        break;
      case OPconst:
        cs.IEV2.Vint = MSREG(e2->EV.Vllong);            // MSW first
        cs.IFL2 = FLconst;
        cs.Iop = 0x81;

        /* if ((e1 is data or a '*' reference) and it's not a
         * common subexpression
         */

        if ((e1->Eoper == OPvar && datafl[el_fl(e1)] ||
             e1->Eoper == OPind) &&
            !evalinregister(e1))
        {
                getlvalue(cdb,&cs,e1,0);
                freenode(e1);
                if (evalinregister(e2))
                {
                        retregs = idxregm(&cs);
                        if ((cs.Iflags & CFSEG) == CFes)
                                retregs |= mES;         // take no chances
                        rretregs = ALLREGS & ~retregs;
                        scodelem(cdb,e2,&rretregs,retregs,TRUE);
                        cse_flush(cdb,1);
                        rreg = findregmsw(rretregs);
                        cs.Iop = 0x39;
                        cs.Irm |= modregrm(0,rreg,0);
                        getlvalue_msw(&cs);
                        cdb.gen(&cs);           // CMP EA+2,rreg
                        cdb.append(cdbjmp);
                        rreg = findreglsw(rretregs);
                        NEWREG(cs.Irm,rreg);
                }
                else
                {
                        cse_flush(cdb,1);
                        cs.Irm |= modregrm(0,7,0);
                        getlvalue_msw(&cs);
                        cdb.gen(&cs);           // CMP EA+2,const
                        cdb.append(cdbjmp);
                        cs.IEV2.Vint = e2->EV.Vlong;
                        freenode(e2);
                }
                getlvalue_lsw(&cs);
                cdb.gen(&cs);                   // CMP EA,rreg/const
                break;
        }
        if (evalinregister(e2))
            goto L2;

        scodelem(cdb,e1,&retregs,0,TRUE);    // compute left leaf
        cse_flush(cdb,1);
        reg = findregmsw(retregs);              // get reg that e1 is in
        cs.Irm = modregrm(3,7,reg);

        cdb.gen(&cs);                           // CMP reg,MSW
        cdb.append(cdbjmp);
        reg = findreglsw(retregs);
        cs.Irm = modregrm(3,7,reg);
        cs.IEV2.Vint = e2->EV.Vlong;
        cdb.gen(&cs);                           // CMP sucreg,LSW
        freenode(e2);
        break;
      case OPvar:
        if (!e1->Ecount && e1->Eoper == OPs32_64)
        {   unsigned msreg;

            retregs = allregs;
            scodelem(cdb,e1->E1,&retregs,0,TRUE);
            freenode(e1);
            reg = findreg(retregs);
            retregs = allregs & ~retregs;
            allocreg(cdb,&retregs,&msreg,TYint);
            cdb.append(genmovreg(CNIL,msreg,reg));                  // MOV msreg,reg
            cdb.genc2(0xC1,modregrm(3,7,msreg),REGSIZE * 8 - 1);    // SAR msreg,31
            cse_flush(cdb,1);
            loadea(cdb,e2,&cs,0x3B,msreg,REGSIZE,mask[reg],0);
            cdb.append(cdbjmp);
            loadea(cdb,e2,&cs,0x3B,reg,0,mask[reg],0);
            freenode(e2);
        }
        else
        {
            scodelem(cdb,e1,&retregs,0,TRUE);  // compute left leaf
            cse_flush(cdb,1);
            reg = findregmsw(retregs);   // get reg that e1 is in
            loadea(cdb,e2,&cs,0x3B,reg,REGSIZE,retregs,0);
            cdb.append(cdbjmp);
            reg = findreglsw(retregs);
            loadea(cdb,e2,&cs,0x3B,reg,0,retregs,0);
            freenode(e2);
        }
        break;
    }

    jop = joplsw[op - OPle];
    if (!(jcond & 1)) jop ^= 1;                           // toggle jump condition
    genjmp(cdb,jop,fltarg,(block *) targ);   // Jcond targ

    cdb.append(ce);
    freenode(e);
}

/*****************************
 * Do conversions.
 * Depends on OPd_s32 and CLIBdbllng being in sequence.
 */

void cdcnvt(CodeBuilder& cdb,elem *e, regm_t *pretregs)
{
    //printf("cdcnvt: *pretregs = %s\n", regm_str(*pretregs));
    //elem_print(e);

    static unsigned char clib[][2] =
    {
        OPd_s32,        CLIBdbllng,
        OPs32_d,        CLIBlngdbl,
        OPd_s16,        CLIBdblint,
        OPs16_d,        CLIBintdbl,
        OPd_u16,        CLIBdbluns,
        OPu16_d,        CLIBunsdbl,
        OPd_u32,        CLIBdblulng,
#if TARGET_WINDOS
        OPu32_d,        CLIBulngdbl,
#endif
        OPd_s64,        CLIBdblllng,
        OPs64_d,        CLIBllngdbl,
        OPd_u64,        CLIBdblullng,
        OPu64_d,        CLIBullngdbl,
        OPd_f,          CLIBdblflt,
        OPf_d,          CLIBfltdbl,
        OPvp_fp,        CLIBvptrfptr,
        OPcvp_fp,       CLIBcvptrfptr,
    };

    if (!*pretregs)
    {
        codelem(cdb,e->E1,pretregs,FALSE);
        return;
    }

    regm_t retregs;
    if (config.inline8087)
    {
        switch (e->Eoper)
        {
            case OPld_d:
            case OPd_ld:
            {
                if (tycomplex(e->E1->Ety))
                {
            Lcomplex:
                    regm_t retregs = mST01 | (*pretregs & mPSW);
                    codelem(cdb,e->E1, &retregs, FALSE);
                    fixresult_complex87(cdb, e, retregs, pretregs);
                    return;
                }
                regm_t retregs = mST0 | (*pretregs & mPSW);
                codelem(cdb,e->E1, &retregs, FALSE);
                fixresult87(cdb, e, retregs, pretregs);
                return;
            }
            case OPf_d:
            case OPd_f:
                if (tycomplex(e->E1->Ety))
                    goto Lcomplex;
                if (config.fpxmmregs && *pretregs & XMMREGS)
                {
                    xmmcnvt(cdb, e, pretregs);
                    return;
                }

                /* if won't do us much good to transfer back and        */
                /* forth between 8088 registers and 8087 registers      */
                if (OTcall(e->E1->Eoper) && !(*pretregs & allregs))
                {
                    retregs = regmask(e->E1->Ety, e->E1->E1->Ety);
                    if (retregs & (mXMM1 | mXMM0 |mST01 | mST0))       // if return in ST0
                    {
                        codelem(cdb,e->E1,pretregs,FALSE);
                        if (*pretregs & mST0)
                            note87(e, 0, 0);
                        return;
                    }
                    else
                        break;
                }
                goto Lload87;

            case OPs64_d:
                if (!I64)
                    goto Lload87;
                /* FALL-THROUGH */
            case OPs32_d:
                if (config.fpxmmregs && *pretregs & XMMREGS)
                {
                    xmmcnvt(cdb, e, pretregs);
                    return;
                }
                /* FALL-THROUGH */
            case OPs16_d:
            case OPu16_d:
            Lload87:
                load87(cdb,e,0,pretregs,NULL,-1);
                return;

            case OPu32_d:
                if (I64 && config.fpxmmregs && *pretregs & XMMREGS)
                {
                    xmmcnvt(cdb,e,pretregs);
                    return;
                }
                else if (!I16)
                {
                    regm_t retregs = ALLREGS;
                    codelem(cdb,e->E1, &retregs, FALSE);
                    unsigned reg = findreg(retregs);
                    cdb.genfltreg(0x89, reg, 0);
                    regwithvalue(cdb,ALLREGS,0,&reg,0);
                    cdb.genfltreg(0x89, reg, 4);

                    push87(cdb);
                    cdb.genfltreg(0xDF,5,0);     // FILD m64int

                    retregs = mST0 /*| (*pretregs & mPSW)*/;
                    fixresult87(cdb, e, retregs, pretregs);
                    return;
                }
                break;
            case OPd_s64:
                if (!I64)
                    goto Lcnvt87;
                /* FALL-THROUGH */
            case OPd_s32:
                if (config.fpxmmregs)
                {
                    xmmcnvt(cdb,e,pretregs);
                    return;
                }
                /* FALL-THROUGH */
            case OPd_s16:
            case OPd_u16:
            Lcnvt87:
                cnvt87(cdb,e,pretregs);
                return;
            case OPd_u32:               // use subroutine, not 8087
                if (I64 && config.fpxmmregs)
                {
                    xmmcnvt(cdb,e,pretregs);
                    return;
                }
                if (I32 || I64)
                {
                    cdd_u32(cdb,e,pretregs);
                    return;
                }
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
                retregs = mST0;
#else
                retregs = DOUBLEREGS;
#endif
                goto L1;

            case OPd_u64:
                if (I32 || I64)
                {
                    cdd_u64(cdb,e,pretregs);
                    return;
                }
                retregs = DOUBLEREGS;
                goto L1;
            case OPu64_d:
                if (*pretregs & mST0)
                {
                    regm_t retregs = I64 ? mAX : mAX|mDX;
                    codelem(cdb,e->E1,&retregs,FALSE);
                    callclib(cdb,e,CLIBu64_ldbl,pretregs,0);
                    return;
                }
                break;
            case OPld_u64:
            {
                if (I32 || I64)
                {
                    cdd_u64(cdb,e,pretregs);
                    return;
                }
                regm_t retregs = mST0;
                codelem(cdb,e->E1,&retregs,FALSE);
                callclib(cdb,e,CLIBld_u64,pretregs,0);
                return;
            }
        }
    }
    retregs = regmask(e->E1->Ety, TYnfunc);
L1:
    codelem(cdb,e->E1,&retregs,FALSE);
    for (int i = 0; 1; i++)
    {
        assert(i < arraysize(clib));
        if (clib[i][0] == e->Eoper)
        {   callclib(cdb,e,clib[i][1],pretregs,0);
            break;
        }
    }
}


/***************************
 * Convert short to long.
 * For OPs16_32, OPu16_32, OPnp_fp, OPu32_64, OPs32_64,
 * OPu64_128, OPs64_128
 */

void cdshtlng(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    unsigned reg;
    regm_t retregs;

    //printf("cdshtlng(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    int e1comsub = e->E1->Ecount;
    unsigned char op = e->Eoper;
    if ((*pretregs & (ALLREGS | mBP)) == 0)    // if don't need result in regs
    {
        codelem(cdb,e->E1,pretregs,FALSE);     // then conversion isn't necessary
        return;
    }

    else if (
             op == OPnp_fp ||
             (I16 && op == OPu16_32) ||
             (I32 && op == OPu32_64)
            )
    {
        /* Result goes into a register pair.
         * Zero extend by putting a zero into most significant reg.
         */

        regm_t retregs = *pretregs & mLSW;
        assert(retregs);
        tym_t tym1 = tybasic(e->E1->Ety);
        codelem(cdb,e->E1,&retregs,FALSE);

        regm_t regm = *pretregs & (mMSW & ALLREGS);
        if (regm == 0)                  // *pretregs could be mES
            regm = mMSW & ALLREGS;
        allocreg(cdb,&regm,&reg,TYint);
        if (e1comsub)
            getregs(cdb,retregs);
        if (op == OPnp_fp)
        {   int segreg;

            // BUG: what about pointers to functions?
            switch (tym1)
            {
                case TYnptr:    segreg = SEG_DS;        break;
                case TYcptr:    segreg = SEG_CS;        break;
                case TYsptr:    segreg = SEG_SS;        break;
                default:        assert(0);
            }
            cdb.gen2(0x8C,modregrm(3,segreg,reg));  // MOV reg,segreg
        }
        else
            movregconst(cdb,reg,0,0);  // 0 extend

        fixresult(cdb,e,retregs | regm,pretregs);
        return;
    }
    else if (I64 && op == OPu32_64)
    {
        elem *e1 = e->E1;
        retregs = *pretregs;
        if (e1->Eoper == OPvar || (e1->Eoper == OPind && !e1->Ecount))
        {   code cs;

            allocreg(cdb,&retregs,&reg,TYint);
            loadea(cdb,e1,&cs,0x8B,reg,0,retregs,retregs);  //  MOV Ereg,EA
            freenode(e1);
        }
        else
        {
            *pretregs &= ~mPSW;                 // flags are set by eval of e1
            codelem(cdb,e1,&retregs,FALSE);
            /* Determine if high 32 bits are already 0
             */
            if (e1->Eoper == OPu16_32 && !e1->Ecount)
            {
            }
            else
            {
                // Zero high 32 bits
                getregs(cdb,retregs);
                reg = findreg(retregs);
                cdb.append(genregs(NULL,0x89,reg,reg));  // MOV Ereg,Ereg
            }
        }
        fixresult(cdb,e,retregs,pretregs);
        return;
    }
    else if (I64 && op == OPs32_64 && OTrel(e->E1->Eoper) && !e->E1->Ecount)
    {
        /* Due to how e1 is calculated, the high 32 bits of the register
         * are already 0.
         */
        retregs = *pretregs;
        codelem(cdb,e->E1,&retregs,FALSE);
        fixresult(cdb,e,retregs,pretregs);
        return;
  }
  else if (!I16 && (op == OPs16_32 || op == OPu16_32) ||
            I64 && op == OPs32_64)
  {
    elem *e11;

    elem *e1 = e->E1;

    if (e1->Eoper == OPu8_16 && !e1->Ecount &&
        ((e11 = e1->E1)->Eoper == OPvar || (e11->Eoper == OPind && !e11->Ecount))
       )
    {   code cs;

        retregs = *pretregs & BYTEREGS;
        if (!retregs)
            retregs = BYTEREGS;
        allocreg(cdb,&retregs,&reg,TYint);
        movregconst(cdb,reg,0,0);                   //  XOR reg,reg
        loadea(cdb,e11,&cs,0x8A,reg,0,retregs,retregs);  //  MOV regL,EA
        freenode(e11);
        freenode(e1);
    }
    else if (e1->Eoper == OPvar ||
        (e1->Eoper == OPind && !e1->Ecount))
    {   code cs;
        unsigned opcode;

        if (I32 && op == OPu16_32 && config.flags4 & CFG4speed)
            goto L2;
        retregs = *pretregs;
        allocreg(cdb,&retregs,&reg,TYint);
        opcode = (op == OPu16_32) ? 0x0FB7 : 0x0FBF; // MOVZX/MOVSX reg,EA
        if (op == OPs32_64)
        {
            assert(I64);
            // MOVSXD reg,e1
            loadea(cdb,e1,&cs,0x63,reg,0,0,retregs);
            code_orrex(cdb.last(), REX_W);
        }
        else
            loadea(cdb,e1,&cs,opcode,reg,0,0,retregs);
        freenode(e1);
    }
    else
    {
    L2:
        retregs = *pretregs;
        if (op == OPs32_64)
            retregs = mAX | (*pretregs & mPSW);
        *pretregs &= ~mPSW;             // flags are already set
        CodeBuilder cdbx;
        codelem(cdbx,e1,&retregs,FALSE);
        code *cx = cdbx.finish();
        cdb.append(cdbx);
        getregs(cdb,retregs);
        if (op == OPu16_32 && cx)
        {
            cx = code_last(cx);
            if (cx->Iop == 0x81 && (cx->Irm & modregrm(3,7,0)) == modregrm(3,4,0) &&
                mask[cx->Irm & 7] == retregs)
            {
                // Convert AND of a word to AND of a dword, zeroing upper word
                if (cx->Irex & REX_B)
                    retregs = mask[8 | (cx->Irm & 7)];
                cx->Iflags &= ~CFopsize;
                cx->IEV2.Vint &= 0xFFFF;
                goto L1;
            }
        }
        if (op == OPs16_32 && retregs == mAX)
            cdb.gen1(0x98);         // CWDE
        else if (op == OPs32_64 && retregs == mAX)
        {   cdb.gen1(0x98);         // CDQE
            code_orrex(cdb.last(), REX_W);
        }
        else
        {
            reg = findreg(retregs);
            if (config.flags4 & CFG4speed && op == OPu16_32)
            {   // AND reg,0xFFFF
                cdb.genc2(0x81,modregrmx(3,4,reg),0xFFFFu);
            }
            else
            {
                unsigned iop = (op == OPu16_32) ? 0x0FB7 : 0x0FBF; // MOVZX/MOVSX reg,reg
                cdb.append(genregs(CNIL,iop,reg,reg));
            }
        }
     L1:
        if (e1comsub)
            getregs(cdb,retregs);
    }
    fixresult(cdb,e,retregs,pretregs);
    return;
  }
  else if (*pretregs & mPSW || config.target_cpu < TARGET_80286)
  {
    // OPs16_32, OPs32_64
    // CWD doesn't affect flags, so we can depend on the integer
    // math to provide the flags.
    retregs = mAX | mPSW;               // want integer result in AX
    *pretregs &= ~mPSW;                 // flags are already set
    codelem(cdb,e->E1,&retregs,FALSE);
    getregs(cdb,mDX);           // sign extend into DX
    cdb.gen1(0x99);                     // CWD/CDQ
    if (e1comsub)
        getregs(cdb,retregs);
    fixresult(cdb,e,mDX | retregs,pretregs);
    return;
  }
  else
  {
    // OPs16_32, OPs32_64
    unsigned msreg,lsreg;

    retregs = *pretregs & mLSW;
    assert(retregs);
    codelem(cdb,e->E1,&retregs,FALSE);
    retregs |= *pretregs & mMSW;
    allocreg(cdb,&retregs,&reg,e->Ety);
    msreg = findregmsw(retregs);
    lsreg = findreglsw(retregs);
    cdb.append(genmovreg(NULL,msreg,lsreg));                // MOV msreg,lsreg
    assert(config.target_cpu >= TARGET_80286);              // 8088 can't handle SAR reg,imm8
    cdb.genc2(0xC1,modregrm(3,7,msreg),REGSIZE * 8 - 1);    // SAR msreg,31
    fixresult(cdb,e,retregs,pretregs);
    return;
  }
}


/***************************
 * Convert byte to int.
 * For OPu8_16 and OPs8_16.
 */

void cdbyteint(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    regm_t retregs;
    char size;

    if ((*pretregs & (ALLREGS | mBP)) == 0)     // if don't need result in regs
    {
        codelem(cdb,e->E1,pretregs,FALSE);      // then conversion isn't necessary
        return;
    }

    //printf("cdbyteint(e = %p, *pretregs = %s\n", e, regm_str(*pretregs));
    char op = e->Eoper;
    elem *e1 = e->E1;
    if (e1->Eoper == OPcomma)
        docommas(cdb,&e1);
    if (!I16)
    {
        if (e1->Eoper == OPvar || (e1->Eoper == OPind && !e1->Ecount))
        {   code cs;

            regm_t retregs = *pretregs;
            unsigned reg;
            allocreg(cdb,&retregs,&reg,TYint);
            if (config.flags4 & CFG4speed &&
                op == OPu8_16 && mask[reg] & BYTEREGS &&
                config.target_cpu < TARGET_PentiumPro)
            {
                movregconst(cdb,reg,0,0);                 //  XOR reg,reg
                loadea(cdb,e1,&cs,0x8A,reg,0,retregs,retregs); //  MOV regL,EA
            }
            else
            {
                unsigned opcode = (op == OPu8_16) ? 0x0FB6 : 0x0FBE; // MOVZX/MOVSX reg,EA
                loadea(cdb,e1,&cs,opcode,reg,0,0,retregs);
            }
            freenode(e1);
            fixresult(cdb,e,retregs,pretregs);
            return;
        }
        size = tysize(e->Ety);
        retregs = *pretregs & BYTEREGS;
        if (retregs == 0)
            retregs = BYTEREGS;
        retregs |= *pretregs & mPSW;
        *pretregs &= ~mPSW;
    }
    else
    {
        if (op == OPu8_16)              // if unsigned conversion
        {
            retregs = *pretregs & BYTEREGS;
            if (retregs == 0)
                retregs = BYTEREGS;
        }
        else
        {
            // CBW doesn't affect flags, so we can depend on the integer
            // math to provide the flags.
            retregs = mAX | (*pretregs & mPSW); // want integer result in AX
        }
    }

    CodeBuilder cdb1;
    codelem(cdb1,e1,&retregs,FALSE);
    code *c1 = cdb1.finish();
    cdb.append(cdb1);
    unsigned reg = findreg(retregs);
    code *c;
    if (!c1)
        goto L1;

    // If previous instruction is an AND bytereg,value
    c = cdb.last();
    if (c->Iop == 0x80 && c->Irm == modregrm(3,4,reg & 7) &&
        (op == OPu8_16 || (c->IEV2.Vuns & 0x80) == 0))
    {
        if (*pretregs & mPSW)
            c->Iflags |= CFpsw;
        c->Iop |= 1;                    // convert to word operation
        c->IEV2.Vuns &= 0xFF;           // dump any high order bits
        *pretregs &= ~mPSW;             // flags already set
    }
    else
    {
     L1:
        if (!I16)
        {
            if (op == OPs8_16 && reg == AX && size == 2)
            {
                cdb.gen1(0x98);                  // CBW
                cdb.last()->Iflags |= CFopsize;  // don't do a CWDE
            }
            else
            {
                // We could do better by not forcing the src and dst
                // registers to be the same.

                if (config.flags4 & CFG4speed && op == OPu8_16)
                {   // AND reg,0xFF
                    cdb.genc2(0x81,modregrmx(3,4,reg),0xFF);
                }
                else
                {
                    unsigned iop = (op == OPu8_16) ? 0x0FB6 : 0x0FBE; // MOVZX/MOVSX reg,reg
                    cdb.append(genregs(CNIL,iop,reg,reg));
                    if (I64 && reg >= 4)
                        code_orrex(cdb.last(), REX);
                }
            }
        }
        else
        {
            if (op == OPu8_16)
                cdb.append(genregs(CNIL,0x30,reg+4,reg+4));  // XOR regH,regH
            else
            {
                cdb.gen1(0x98);                 // CBW
                *pretregs &= ~mPSW;             // flags already set
            }
        }
    }
    getregs(cdb,retregs);
    fixresult(cdb,e,retregs,pretregs);
}


/***************************
 * Convert long to short (OP32_16).
 * Get offset of far pointer (OPoffset).
 * Convert int to byte (OP16_8).
 * Convert long long to long (OP64_32).
 * OP128_64
 */

void cdlngsht(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
#ifdef DEBUG
    switch (e->Eoper)
    {
        case OP32_16:
        case OPoffset:
        case OP16_8:
        case OP64_32:
        case OP128_64:
            break;

        default:
            assert(0);
    }
#endif

    regm_t retregs;
    if (e->Eoper == OP16_8)
    {
        retregs = *pretregs ? BYTEREGS : 0;
        codelem(cdb,e->E1,&retregs,FALSE);
    }
    else
    {
        if (e->E1->Eoper == OPrelconst)
            offsetinreg(cdb,e->E1,&retregs);
        else
        {
            retregs = *pretregs ? ALLREGS : 0;
            codelem(cdb,e->E1,&retregs,FALSE);
            bool isOff = e->Eoper == OPoffset;
            if (I16 ||
                I32 && (isOff || e->Eoper == OP64_32) ||
                I64 && (isOff || e->Eoper == OP128_64))
                retregs &= mLSW;                // want LSW only
        }
    }

    /* We "destroy" a reg by assigning it the result of a new e, even
     * though the values are the same. Weakness of our CSE strategy that
     * a register can only hold the contents of one elem at a time.
     */
    if (e->Ecount)
        getregs(cdb,retregs);
    else
        useregs(retregs);

#ifdef DEBUG
    if (!(!*pretregs || retregs))
    {
        WROP(e->Eoper),
        printf(" *pretregs = %s, retregs = %s, e = %p\n",regm_str(*pretregs),regm_str(retregs),e);
    }
#endif
    assert(!*pretregs || retregs);
    fixresult(cdb,e,retregs,pretregs);  // lsw only
}

/**********************************************
 * Get top 32 bits of 64 bit value (I32)
 * or top 16 bits of 32 bit value (I16)
 * or top 64 bits of 128 bit value (I64).
 * OPmsw
 */

void cdmsw(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    assert(e->Eoper == OPmsw);

    regm_t retregs = *pretregs ? ALLREGS : 0;
    codelem(cdb,e->E1,&retregs,FALSE);
    retregs &= mMSW;                    // want MSW only

    /* We "destroy" a reg by assigning it the result of a new e, even
     * though the values are the same. Weakness of our CSE strategy that
     * a register can only hold the contents of one elem at a time.
     */
    if (e->Ecount)
        getregs(cdb,retregs);
    else
        useregs(retregs);

#ifdef DEBUG
    if (!(!*pretregs || retregs))
    {   WROP(e->Eoper);
        printf(" *pretregs = %s, retregs = %s\n",regm_str(*pretregs),regm_str(retregs));
        elem_print(e);
    }
#endif
    assert(!*pretregs || retregs);
    fixresult(cdb,e,retregs,pretregs);  // msw only
}



/******************************
 * Handle operators OPinp and OPoutp.
 */

void cdport(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    //printf("cdport\n");
    unsigned char op = 0xE4;            // root of all IN/OUT opcodes
    elem *e1 = e->E1;

    // See if we can use immediate mode of IN/OUT opcodes
    unsigned char port;
    if (e1->Eoper == OPconst && e1->EV.Vuns <= 255 &&
        (!evalinregister(e1) || regcon.mvar & mDX))
    {
        port = e1->EV.Vuns;
        freenode(e1);
    }
    else
    {
        regm_t retregs = mDX;           // port number is always DX
        codelem(cdb,e1,&retregs,FALSE);
        op |= 0x08;                     // DX version of opcode
        port = 0;                       // not logically needed, but
                                        // quiets "uninitialized var" complaints
    }

    unsigned sz;
    if (e->Eoper == OPoutp)
    {
        sz = tysize(e->E2->Ety);
        regm_t retregs = mAX;           // byte/word to output is in AL/AX
        scodelem(cdb,e->E2,&retregs,((op & 0x08) ? mDX : (regm_t) 0),TRUE);
        op |= 0x02;                     // OUT opcode
    }
    else // OPinp
    {
        getregs(cdb,mAX);
        sz = tysize(e->Ety);
    }

    if (sz != 1)
        op |= 1;                        // word operation
    cdb.genc2(op,0,port);               // IN/OUT AL/AX,DX/port
    if (op & 1 && sz != REGSIZE)        // if need size override
        cdb.last()->Iflags |= CFopsize;
    regm_t retregs = mAX;
    fixresult(cdb,e,retregs,pretregs);
}

/************************
 * Generate code for an asm elem.
 */

void cdasm(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    // Assume only regs normally destroyed by a function are destroyed
    getregs(cdb,(ALLREGS | mES) & ~fregsaved);
    cdb.append(genasm(CNIL,(unsigned char *)e->EV.ss.Vstring,e->EV.ss.Vstrlen));
    fixresult(cdb,e,(I16 ? mDX | mAX : mAX),pretregs);
}

/************************
 * Generate code for OPnp_f16p and OPf16p_np.
 */

void cdfar16(CodeBuilder& cdb, elem *e, regm_t *pretregs)
{
    code *cnop;
    code cs;

    assert(I32);
    codelem(cdb,e->E1,pretregs,FALSE);
    unsigned reg = findreg(*pretregs);
    getregs(cdb,*pretregs);      // we will destroy the regs

    cs.Iop = 0xC1;
    cs.Irm = modregrm(3,0,reg);
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL2 = FLconst;
    cs.IEV2.Vuns = 16;

    cdb.gen(&cs);                       // ROL ereg,16
    cs.Irm |= modregrm(0,1,0);
    cdb.gen(&cs);                       // ROR ereg,16
    cs.IEV2.Vuns = 3;
    cs.Iflags |= CFopsize;

    if (e->Eoper == OPnp_f16p)
    {
        /*      OR  ereg,ereg
                JE  L1
                ROR ereg,16
                SHL reg,3
                MOV rx,SS
                AND rx,3                ;mask off CPL bits
                OR  rl,4                ;run on LDT bit
                OR  regl,rl
                ROL ereg,16
            L1: NOP
         */
        unsigned rx;

        regm_t retregs = BYTEREGS & ~*pretregs;
        allocreg(cdb,&retregs,&rx,TYint);
        cnop = gennop(CNIL);
        int jop = JCXZ;
        if (reg != CX)
        {
            cdb.append(gentstreg(CNIL,reg));
            jop = JE;
        }
        genjmp(cdb,jop,FLcode,(block *)cnop);  // Jop L1
        NEWREG(cs.Irm,4);
        cdb.gen(&cs);                                   // SHL reg,3
        cdb.append(genregs(CNIL,0x8C,2,rx));            // MOV rx,SS
        int byte = (mask[reg] & BYTEREGS) == 0;
        cdb.genc2(0x80 | byte,modregrm(3,4,rx),3);      // AND rl,3
        cdb.genc2(0x80,modregrm(3,1,rx),4);             // OR  rl,4
        cdb.append(genregs(CNIL,0x0A | byte,reg,rx));   // OR  regl,rl
    }
    else // OPf16p_np
    {
        /*      ROR ereg,16
                SHR reg,3
                ROL ereg,16
         */

        cs.Irm |= modregrm(0,5,0);
        cdb.gen(&cs);                                   // SHR reg,3
        cnop = NULL;
    }
}

/*************************
 * Generate code for OPbtst
 */

void cdbtst(CodeBuilder& cdb, elem *e, regm_t *pretregs)
{
    regm_t retregs;
    unsigned reg;

    //printf("cdbtst(e = %p, *pretregs = %s\n", e, regm_str(*pretregs));

    int op = 0xA3;                        // BT EA,value
    int mode = 4;

    elem *e1 = e->E1;
    elem *e2 = e->E2;
    code cs;
    cs.Iflags = 0;

    if (*pretregs == 0)                   // if don't want result
    {
        codelem(cdb,e1,pretregs,FALSE);  // eval left leaf
        *pretregs = 0;                    // in case they got set
        codelem(cdb,e2,pretregs,FALSE);
        return;
    }

    regm_t idxregs;
    if ((e1->Eoper == OPind && !e1->Ecount) || e1->Eoper == OPvar)
    {
        getlvalue(cdb, &cs, e1, RMload);    // get addressing mode
        idxregs = idxregm(&cs);             // mask if index regs used
    }
    else
    {
        retregs = tysize(e1->Ety) == 1 ? BYTEREGS : allregs;
        codelem(cdb,e1, &retregs, FALSE);
        reg = findreg(retregs);
        cs.Irm = modregrm(3,0,reg & 7);
        cs.Iflags = 0;
        cs.Irex = 0;
        if (reg & 8)
            cs.Irex |= REX_B;
        idxregs = retregs;
    }

    tym_t ty1 = tybasic(e1->Ety);
    unsigned char word = (!I16 && _tysize[ty1] == SHORTSIZE) ? CFopsize : 0;

//    if (e2->Eoper == OPconst && e2->EV.Vuns < 0x100)  // should do this instead?
    if (e2->Eoper == OPconst)
    {
        cs.Iop = 0x0FBA;                         // BT rm,imm8
        cs.Irm |= modregrm(0,mode,0);
        cs.Iflags |= CFpsw | word;
        cs.IFL2 = FLconst;
        if (_tysize[ty1] == SHORTSIZE)
        {
            cs.IEV2.Vint = e2->EV.Vint & 15;
        }
        else if (_tysize[ty1] == 4)
        {
            cs.IEV2.Vint = e2->EV.Vint & 31;
        }
        else
        {
            cs.IEV2.Vint = e2->EV.Vint & 63;
            if (I64)
                cs.Irex |= REX_W;
        }
        cdb.gen(&cs);
    }
    else
    {
        retregs = ALLREGS & ~idxregs;
        scodelem(cdb,e2,&retregs,idxregs,TRUE);
        reg = findreg(retregs);

        cs.Iop = 0x0F00 | op;                     // BT rm,reg
        code_newreg(&cs,reg);
        cs.Iflags |= CFpsw | word;
        if (I64 && _tysize[ty1] == 8)
            cs.Irex |= REX_W;
        cdb.gen(&cs);
    }

    if ((retregs = (*pretregs & (ALLREGS | mBP))) != 0) // if return result in register
    {
        if (tysize(e->Ety) == 1)
        {
            assert(I64 || retregs & BYTEREGS);
            allocreg(cdb,&retregs,&reg,TYint);
            cdb.gen2(0x0F92,modregrmx(3,0,reg));        // SETC reg
            if (I64 && reg >= 4)
                code_orrex(cdb.last(), REX);
            *pretregs = retregs;
        }
        else
        {
            code *cnop = CNIL;
            regm_t save = regcon.immed.mval;
            allocreg(cdb,&retregs,&reg,TYint);
            regcon.immed.mval = save;
            if ((*pretregs & mPSW) == 0)
            {
                getregs(cdb,retregs);
                cdb.append(genregs(CNIL,0x19,reg,reg));     // SBB reg,reg
                cdb.gen2(0xF7,modregrmx(3,3,reg));          // NEG reg
            }
            else
            {
                movregconst(cdb,reg,1,8);      // MOV reg,1
                cnop = gennop(CNIL);
                genjmp(cdb,JC,FLcode,(block *) cnop);  // Jtrue nop
                                                            // MOV reg,0
                movregconst(cdb,reg,0,8);
                regcon.immed.mval &= ~mask[reg];
            }
            *pretregs = retregs;
            cdb.append(cnop);
        }
    }
}

/*************************
 * Generate code for OPbt, OPbtc, OPbtr, OPbts
 */

void cdbt(CodeBuilder& cdb,elem *e, regm_t *pretregs)
{
    //printf("cdbt(%p, %s)\n", e, regm_str(*pretregs));
    regm_t retregs;
    unsigned reg;
    int op;
    int mode;

    switch (e->Eoper)
    {
        case OPbt:      op = 0xA3; mode = 4; break;
        case OPbtc:     op = 0xBB; mode = 7; break;
        case OPbtr:     op = 0xB3; mode = 6; break;
        case OPbts:     op = 0xAB; mode = 5; break;

        default:
            assert(0);
    }

    elem *e1 = e->E1;
    elem *e2 = e->E2;
    code cs;
    cs.Iflags = 0;

    getlvalue(cdb, &cs, e, RMload);      // get addressing mode
    if (e->Eoper == OPbt && *pretregs == 0)
    {
        codelem(cdb,e2,pretregs,FALSE);
        return;
    }

    tym_t ty1 = tybasic(e1->Ety);
    unsigned char word = (!I16 && _tysize[ty1] == SHORTSIZE) ? CFopsize : 0;
    regm_t idxregs = idxregm(&cs);         // mask if index regs used

//    if (e2->Eoper == OPconst && e2->EV.Vuns < 0x100)  // should do this instead?
    if (e2->Eoper == OPconst)
    {
        cs.Iop = 0x0FBA;                         // BT rm,imm8
        cs.Irm |= modregrm(0,mode,0);
        cs.Iflags |= CFpsw | word;
        cs.IFL2 = FLconst;
        if (_tysize[ty1] == SHORTSIZE)
        {
            cs.IEVoffset1 += (e2->EV.Vuns & ~15) >> 3;
            cs.IEV2.Vint = e2->EV.Vint & 15;
        }
        else if (_tysize[ty1] == 4)
        {
            cs.IEVoffset1 += (e2->EV.Vuns & ~31) >> 3;
            cs.IEV2.Vint = e2->EV.Vint & 31;
        }
        else
        {
            cs.IEVoffset1 += (e2->EV.Vuns & ~63) >> 3;
            cs.IEV2.Vint = e2->EV.Vint & 63;
            if (I64)
                cs.Irex |= REX_W;
        }
        cdb.gen(&cs);
    }
    else
    {
        retregs = ALLREGS & ~idxregs;
        scodelem(cdb,e2,&retregs,idxregs,TRUE);
        reg = findreg(retregs);

        cs.Iop = 0x0F00 | op;                     // BT rm,reg
        code_newreg(&cs,reg);
        cs.Iflags |= CFpsw | word;
        cdb.gen(&cs);
    }

    if ((retregs = (*pretregs & (ALLREGS | mBP))) != 0) // if return result in register
    {
        if (_tysize[e->Ety] == 1)
        {
            assert(I64 || retregs & BYTEREGS);
            allocreg(cdb,&retregs,&reg,TYint);
            cdb.gen2(0x0F92,modregrmx(3,0,reg));        // SETC reg
            if (I64 && reg >= 4)
                code_orrex(cdb.last(), REX);
            *pretregs = retregs;
        }
        else
        {
            code *cnop = CNIL;
            regm_t save = regcon.immed.mval;
            allocreg(cdb,&retregs,&reg,TYint);
            regcon.immed.mval = save;
            if ((*pretregs & mPSW) == 0)
            {
                getregs(cdb,retregs);
                cdb.append(genregs(CNIL,0x19,reg,reg));     // SBB reg,reg
                cdb.gen2(0xF7,modregrmx(3,3,reg));          // NEG reg
            }
            else
            {
                movregconst(cdb,reg,1,8);      // MOV reg,1
                cnop = gennop(CNIL);
                genjmp(cdb,JC,FLcode,(block *) cnop);    // Jtrue nop
                                                            // MOV reg,0
                movregconst(cdb,reg,0,8);
                regcon.immed.mval &= ~mask[reg];
            }
            *pretregs = retregs;
            cdb.append(cnop);
        }
    }
}

/*************************************
 * Generate code for OPbsf and OPbsr.
 */

void cdbscan(CodeBuilder& cdb, elem *e, regm_t *pretregs)
{
    //printf("cdbscan()\n");
    //elem_print(e);
    if (!*pretregs)
    {
        codelem(cdb,e->E1,pretregs,FALSE);
        return;
    }

    tym_t tyml = tybasic(e->E1->Ety);
    int sz = _tysize[tyml];
    assert(sz == 2 || sz == 4 || sz == 8);
    regm_t retregs;
    unsigned reg;
    code cs;

    if ((e->E1->Eoper == OPind && !e->E1->Ecount) || e->E1->Eoper == OPvar)
    {
        getlvalue(cdb, &cs, e->E1, RMload);     // get addressing mode
    }
    else
    {
        retregs = allregs;
        codelem(cdb,e->E1, &retregs, FALSE);
        reg = findreg(retregs);
        cs.Irm = modregrm(3,0,reg & 7);
        cs.Iflags = 0;
        cs.Irex = 0;
        if (reg & 8)
            cs.Irex |= REX_B;
    }

    retregs = *pretregs & allregs;
    if  (!retregs)
        retregs = allregs;
    allocreg(cdb,&retregs, &reg, e->Ety);

    cs.Iop = (e->Eoper == OPbsf) ? 0x0FBC : 0x0FBD;        // BSF/BSR reg,EA
    code_newreg(&cs, reg);
    if (!I16 && sz == SHORTSIZE)
        cs.Iflags |= CFopsize;
    cdb.gen(&cs);
    if (sz == 8)
        code_orrex(cdb.last(), REX_W);

    fixresult(cdb,e,retregs,pretregs);
}

/************************
 * OPpopcnt operator
 */

void cdpopcnt(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    //printf("cdpopcnt()\n");
    //elem_print(e);
    assert(!I16);
    if (!*pretregs)
    {
        codelem(cdb,e->E1,pretregs,FALSE);
        return;
    }

    tym_t tyml = tybasic(e->E1->Ety);

    int sz = _tysize[tyml];
    assert(sz == 2 || sz == 4 || (sz == 8 && I64));     // no byte op

    code cs;
    if ((e->E1->Eoper == OPind && !e->E1->Ecount) || e->E1->Eoper == OPvar)
    {
        getlvalue(cdb, &cs, e->E1, RMload);     // get addressing mode
    }
    else
    {
        regm_t retregs = allregs;
        codelem(cdb,e->E1, &retregs, FALSE);
        reg_t reg = findreg(retregs);
        cs.Irm = modregrm(3,0,reg & 7);
        cs.Iflags = 0;
        cs.Irex = 0;
        if (reg & 8)
            cs.Irex |= REX_B;
    }

    regm_t retregs = *pretregs & allregs;
    if  (!retregs)
        retregs = allregs;
    unsigned reg;
    allocreg(cdb,&retregs, &reg, e->Ety);

    cs.Iop = POPCNT;            // POPCNT reg,EA
    code_newreg(&cs, reg);
    if (sz == SHORTSIZE)
        cs.Iflags |= CFopsize;
    if (*pretregs & mPSW)
        cs.Iflags |= CFpsw;
    cdb.gen(&cs);
    if (sz == 8)
        code_orrex(cdb.last(), REX_W);
    *pretregs &= mBP | ALLREGS;             // flags already set

    fixresult(cdb,e,retregs,pretregs);
}


/*******************************************
 * Generate code for OPpair, OPrpair.
 */

void cdpair(CodeBuilder& cdb, elem *e, regm_t *pretregs)
{
    if (*pretregs == 0)                         // if don't want result
    {
        codelem(cdb,e->E1,pretregs,FALSE);     // eval left leaf
        *pretregs = 0;                          // in case they got set
        codelem(cdb,e->E2,pretregs,FALSE);
        return;
    }

    //printf("\ncdpair(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    //printf("Ecount = %d\n", e->Ecount);

    regm_t retregs = *pretregs;
    if (retregs == mPSW && tycomplex(e->Ety) && config.inline8087)
    {
        if (config.fpxmmregs)
            retregs |= mXMM0 | mXMM1;
        else
            retregs |= mST01;
    }

    if (retregs & mST01)
    {
        loadPair87(cdb, e, pretregs);
        return;
    }

    regm_t regs1;
    regm_t regs2;
    if (retregs & XMMREGS)
    {
        retregs &= XMMREGS;
        unsigned reg = findreg(retregs);
        regs1 = mask[reg];
        regs2 = mask[findreg(retregs & ~regs1)];
    }
    else
    {
        retregs &= allregs;
        if  (!retregs)
            retregs = allregs;
        regs1 = retregs & mLSW;
        regs2 = retregs & mMSW;
    }
    if (e->Eoper == OPrpair)
    {
        // swap
        regs1 ^= regs2;
        regs2 ^= regs1;
        regs1 ^= regs2;
    }
    //printf("1: regs1 = %s, regs2 = %s\n", regm_str(regs1), regm_str(regs2));

    codelem(cdb,e->E1, &regs1, FALSE);
    scodelem(cdb,e->E2, &regs2, regs1, FALSE);
    //printf("2: regs1 = %s, regs2 = %s\n", regm_str(regs1), regm_str(regs2));

    if (e->E1->Ecount)
        getregs(cdb,regs1);
    if (e->E2->Ecount)
        getregs(cdb,regs2);

    fixresult(cdb,e,regs1 | regs2,pretregs);
}

/*************************
 * Generate code for OPcmpxchg
 */

void cdcmpxchg(CodeBuilder& cdb, elem *e, regm_t *pretregs)
{
    /* The form is:
     *     OPcmpxchg
     *    /     \
     * lvalue   OPparam
     *          /     \
     *        old     new
     */

    //printf("cdmulass(e=%p, *pretregs = %s)\n",e,regm_str(*pretregs));
    elem *e1 = e->E1;
    elem *e2 = e->E2;
    assert(e2->Eoper == OPparam);
    assert(!e2->Ecount);

    tym_t tyml = tybasic(e1->Ety);                   // type of lvalue
    unsigned sz = _tysize[tyml];

    if (I32 && sz == 8)
    {
        regm_t retregs = mDX|mAX;
        codelem(cdb,e2->E1,&retregs,FALSE);           // [DX,AX] = e2->E1

        retregs = mCX|mBX;
        scodelem(cdb,e2->E2,&retregs,mDX|mAX,FALSE);  // [CX,BX] = e2->E2

        code cs;
        getlvalue(cdb,&cs,e1,mCX|mBX|mAX|mDX);        // get EA

        getregs(cdb,mDX|mAX);                 // CMPXCHG destroys these regs

        if (e1->Ety & mTYvolatile)
            cdb.gen1(LOCK);                           // LOCK prefix
        cs.Iop = 0x0FC7;                              // CMPXCHG8B EA
        cs.Iflags |= CFpsw;
        code_newreg(&cs,1);
        cdb.gen(&cs);

        assert(!e1->Ecount);
        freenode(e1);
    }
    else
    {
        unsigned byte = (sz == 1);                  // 1 for byte operation
        unsigned char word = (!I16 && sz == SHORTSIZE) ? CFopsize : 0;
        unsigned rex = (I64 && sz == 8) ? REX_W : 0;

        regm_t retregs = mAX;
        codelem(cdb,e2->E1,&retregs,FALSE);        // AX = e2->E1

        retregs = (ALLREGS | mBP) & ~mAX;
        scodelem(cdb,e2->E2,&retregs,mAX,FALSE);   // load rvalue in reg

        code cs;
        getlvalue(cdb,&cs,e1,mAX | retregs); // get EA

        getregs(cdb,mAX);                  // CMPXCHG destroys AX

        if (e1->Ety & mTYvolatile)
            cdb.gen1(LOCK);                        // LOCK prefix
        cs.Iop = 0x0FB1 ^ byte;                    // CMPXCHG EA,reg
        cs.Iflags |= CFpsw | word;
        cs.Irex |= rex;
        unsigned reg = findreg(retregs);
        code_newreg(&cs,reg);
        cdb.gen(&cs);

        assert(!e1->Ecount);
        freenode(e1);
    }

    regm_t retregs;
    if ((retregs = (*pretregs & (ALLREGS | mBP))) != 0) // if return result in register
    {
        assert(tysize(e->Ety) == 1);
        assert(I64 || retregs & BYTEREGS);
        unsigned reg;
        allocreg(cdb,&retregs,&reg,TYint);
        unsigned ea = modregrmx(3,0,reg);
        if (I64 && reg >= 4)
            ea |= REX << 16;
        cdb.gen2(0x0F94,ea);        // SETZ reg
        *pretregs = retregs;
    }
}

/*************************
 * Generate code for OPprefetch
 */

void cdprefetch(CodeBuilder& cdb, elem *e, regm_t *pretregs)
{
    /* Generate the following based on e2:
     *    0: prefetch0
     *    1: prefetch1
     *    2: prefetch2
     *    3: prefetchnta
     *    4: prefetchw
     *    5: prefetchwt1
     */
    //printf("cdprefetch\n");
    elem *e1 = e->E1;

    assert(*pretregs == 0);
    assert(e->E2->Eoper == OPconst);
    unsigned op;
    unsigned reg;
    switch (e->E2->EV.Vuns)
    {
        case 0: op = PREFETCH; reg = 1; break;  // PREFETCH0
        case 1: op = PREFETCH; reg = 2; break;  // PREFETCH1
        case 2: op = PREFETCH; reg = 3; break;  // PREFETCH2
        case 3: op = PREFETCH; reg = 0; break;  // PREFETCHNTA
        case 4: op = 0x0F0D;   reg = 1; break;  // PREFETCHW
        case 5: op = 0x0F0D;   reg = 2; break;  // PREFETCHWT1
        default: assert(0);
    }

    freenode(e->E2);

    code cs;
    getlvalue(cdb,&cs,e1,0);
    cs.Iop = op;
    cs.Irm |= modregrm(0,reg,0);
    cs.Iflags |= CFvolatile;            // do not schedule
    cdb.gen(&cs);
}

#endif // !SPP
