// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
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

code *modEA(code *c)
{
    if ((c->Irm & 0xC0) == 0xC0)        // addressing mode refers to a register
    {
        unsigned reg = c->Irm & 7;
        if (c->Irex & REX_B)
        {   reg |= 8;
            assert(I64);
        }
        return getregs(mask[reg]);
    }
    return CNIL;
}

#if TARGET_WINDOS
// This code is for CPUs that do not support the 8087

/****************************
 * Gen code for op= for doubles.
 */

STATIC code * opassdbl(elem *e,regm_t *pretregs,unsigned op)
{ code *c1,*c2,*c3,*c4,*c5,*c6,cs;
  unsigned clib;
  regm_t retregs2,retregs,idxregs;
  tym_t tym;
  elem *e1;

  static unsigned clibtab[OPdivass - OPpostinc + 1] =
  /* OPpostinc,OPpostdec,OPeq,OPaddass,OPminass,OPmulass,OPdivass       */
  {  CLIBdadd, CLIBdsub, (unsigned)-1,  CLIBdadd,CLIBdsub,CLIBdmul,CLIBddiv };

  if (config.inline8087)
        return opass87(e,pretregs);
  clib = clibtab[op - OPpostinc];
  e1 = e->E1;
  tym = tybasic(e1->Ety);
  c1 = getlvalue(&cs,e1,DOUBLEREGS | mBX | mCX);

  if (tym == TYfloat)
  {
        clib += CLIBfadd - CLIBdadd;    /* convert to float operation   */

        /* Load EA into FLOATREGS       */
        c1 = cat(c1,getregs(FLOATREGS));
        cs.Iop = 0x8B;
        cs.Irm |= modregrm(0,AX,0);
        c1 = gen(c1,&cs);

        if (!I32)
        {
            cs.Irm |= modregrm(0,DX,0);
            getlvalue_msw(&cs);
            c1 = gen(c1,&cs);
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
            /* Load EA into DOUBLEREGS  */
            c1 = cat(c1,getregs(DOUBLEREGS_32));
            cs.Iop = 0x8B;
            cs.Irm |= modregrm(0,AX,0);
            c1 = gen(c1,&cs);
            cs.Irm |= modregrm(0,DX,0);
            getlvalue_msw(&cs);
            c1 = gen(c1,&cs);
            getlvalue_lsw(&cs);

            retregs2 = DOUBLEREGS2_32;
            idxregs = DOUBLEREGS_32 | idxregm(&cs);
        }
        else
        {
            /* Push EA onto stack       */
            cs.Iop = 0xFF;
            cs.Irm |= modregrm(0,6,0);
            cs.IEVoffset1 += DOUBLESIZE - REGSIZE;
            c1 = gen(c1,&cs);
            getlvalue_lsw(&cs);
            gen(c1,&cs);
            getlvalue_lsw(&cs);
            gen(c1,&cs);
            getlvalue_lsw(&cs);
            gen(c1,&cs);
            stackpush += DOUBLESIZE;

            retregs2 = DOUBLEREGS_16;
            idxregs = idxregm(&cs);
        }
        retregs = DOUBLEREGS;
  }

  if ((cs.Iflags & CFSEG) == CFes)
        idxregs |= mES;
  cgstate.stackclean++;
  c3 = scodelem(e->E2,&retregs2,idxregs,FALSE);
  cgstate.stackclean--;
  c4 = callclib(e,clib,&retregs,0);
  if (e1->Ecount)
        cssave(e1,retregs,EOP(e1));             /* if lvalue is a CSE   */
  freenode(e1);
  cs.Iop = 0x89;                                /* MOV EA,DOUBLEREGS    */
  c5 = fltregs(&cs,tym);
  c6 = fixresult(e,retregs,pretregs);
  return cat6(c1,CNIL,c3,c4,c5,c6);
}

/****************************
 * Gen code for OPnegass for doubles.
 */

STATIC code * opnegassdbl(elem *e,regm_t *pretregs)
{   code *c1,*c2,*c3,*c,*cl,*cr,cs;
    unsigned clib;
    regm_t retregs2,retregs,idxregs;
    tym_t tym;
    elem *e1;
    int sz;

    if (config.inline8087)
        return cdnegass87(e,pretregs);
    e1 = e->E1;
    tym = tybasic(e1->Ety);
    sz = tysize[tym];

    cl = getlvalue(&cs,e1,*pretregs ? DOUBLEREGS | mBX | mCX : 0);
    cr = modEA(&cs);
    cs.Irm |= modregrm(0,6,0);
    cs.Iop = 0x80;
    cs.IEVoffset1 += sz - 1;
    cs.IFL2 = FLconst;
    cs.IEV2.Vuns = 0x80;
    c = gen(NULL,&cs);                  // XOR 7[EA],0x80
    if (tycomplex(tym))
    {
        cs.IEVoffset1 -= sz / 2;
        gen(c,&cs);                     // XOR 7[EA],0x80
    }
    c = cat3(cl,cr,c);

    if (*pretregs || e1->Ecount)
    {
        cs.IEVoffset1 -= sz - 1;

        if (tym == TYfloat)
        {
            // Load EA into FLOATREGS
            c1 = getregs(FLOATREGS);
            cs.Iop = 0x8B;
            NEWREG(cs.Irm, AX);
            c1 = gen(c1,&cs);

            if (!I32)
            {
                NEWREG(cs.Irm, DX);
                getlvalue_msw(&cs);
                c1 = gen(c1,&cs);
                getlvalue_lsw(&cs);

            }
            retregs = FLOATREGS;
        }
        else
        {
            if (I32)
            {
                // Load EA into DOUBLEREGS
                c1 = getregs(DOUBLEREGS_32);
                cs.Iop = 0x8B;
                cs.Irm &= ~modregrm(0,7,0);
                cs.Irm |= modregrm(0,AX,0);
                c1 = gen(c1,&cs);
                cs.Irm |= modregrm(0,DX,0);
                getlvalue_msw(&cs);
                c1 = gen(c1,&cs);
                getlvalue_lsw(&cs);
            }
            else
            {
#if 1
                cs.Iop = 0x8B;
                c1 = fltregs(&cs,TYdouble);     // MOV DOUBLEREGS, EA
#else
                // Push EA onto stack
                cs.Iop = 0xFF;
                cs.Irm |= modregrm(0,6,0);
                cs.IEVoffset1 += DOUBLESIZE - REGSIZE;
                c1 = gen(NULL,&cs);
                cs.IEVoffset1 -= REGSIZE;
                gen(c1,&cs);
                cs.IEVoffset1 -= REGSIZE;
                gen(c1,&cs);
                cs.IEVoffset1 -= REGSIZE;
                gen(c1,&cs);
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
        c1 = NULL;
    }

    freenode(e1);
    c3 = fixresult(e,retregs,pretregs);
    return cat3(c,c1,c3);
}
#endif



/************************
 * Generate code for an assignment.
 */

code *cdeq(elem *e,regm_t *pretregs)
{
  tym_t tymll;
  unsigned reg;
  int i;
  code *cl,*cr,*c,cs;
  elem *e11;
  bool regvar;                  /* TRUE means evaluate into register variable */
  regm_t varregm;
  unsigned varreg;
  targ_int postinc;

  //printf("cdeq(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
  elem *e1 = e->E1;
  elem *e2 = e->E2;
  int e2oper = e2->Eoper;
  tym_t tyml = tybasic(e1->Ety);              /* type of lvalue               */
  regm_t retregs = *pretregs;

    if (tyxmmreg(tyml) && config.fpxmmregs)
        return xmmeq(e, e->Eoper, e1, e2, pretregs);

    if (tyfloating(tyml) && config.inline8087)
    {
        if (tycomplex(tyml))
            return complex_eq87(e, pretregs);

        if (!(retregs == 0 &&
              (e2oper == OPconst || e2oper == OPvar || e2oper == OPind))
           )
            return eq87(e,pretregs);
        if (config.target_cpu >= TARGET_PentiumPro &&
            (e2oper == OPvar || e2oper == OPind)
           )
            return eq87(e,pretregs);
        if (tyml == TYldouble || tyml == TYildouble)
            return eq87(e,pretregs);
    }

  unsigned sz = tysize[tyml];           // # of bytes to transfer
  assert((int)sz > 0);

  if (retregs == 0)                     /* if no return value           */
  {     int fl;

        if ((e2oper == OPconst ||       /* if rvalue is a constant      */
             e2oper == OPrelconst &&
             !(I64 && (config.flags3 & CFG3pic || config.exe == EX_WIN64)) &&
             ((fl = el_fl(e2)) == FLdata ||
              fl==FLudata || fl == FLextern)
#if TARGET_SEGMENTED
              && !(e2->EV.sp.Vsym->ty() & mTYcs)
#endif
            ) &&
            !evalinregister(e2) &&
            !e1->Ecount)        /* and no CSE headaches */
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
                cl = getlvalue(&cs,e11,RMstore);
                freenode(e11->E2);
            }
            else
            {   postinc = 0;
                cl = getlvalue(&cs,e1,RMstore);

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
                        cl = regwithvalue(cl,rregm,e2->EV.Vpointer,&reg,64);
                        cs.Iop = 0x89;
                        cs.Irm |= modregrm(0,reg & 7,0);
                        if (reg & 8)
                            cs.Irex |= REX_R;
                        c = gen(cl,&cs);
                        freenode(e2);
                        goto Lp;
                    }
                    if ((sz == REGSIZE || (I64 && sz == 4)) && e2->EV.Vint)
                    {
                        // MOV reg,imm
                        // MOV EA,reg
                        regm_t rregm = allregs & ~idxregm(&cs);
                        unsigned reg;
                        cl = regwithvalue(cl,rregm,e2->EV.Vint,&reg,0);
                        cs.Iop = 0x89;
                        cs.Irm |= modregrm(0,reg & 7,0);
                        if (reg & 8)
                            cs.Irex |= REX_R;
                        c = gen(cl,&cs);
                        freenode(e2);
                        goto Lp;
                    }
                    if (sz == 2 * REGSIZE && e2->EV.Vllong == 0)
                    {   regm_t rregm;
                        unsigned reg;

                        // MOV reg,imm
                        // MOV EA,reg
                        // MOV EA+2,reg
                        rregm = getscratch() & ~idxregm(&cs);
                        if (rregm)
                        {   cl = regwithvalue(cl,rregm,e2->EV.Vint,&reg,0);
                            cs.Iop = 0x89;
                            cs.Irm |= modregrm(0,reg,0);
                            c = gen(cl,&cs);
                            getlvalue_msw(&cs);
                            c = gen(c,&cs);
                            freenode(e2);
                            goto Lp;
                        }
                    }
                }
            }

            /* If loading result into a register        */
            if ((cs.Irm & 0xC0) == 0xC0)
            {   cl = cat(cl,modEA(&cs));
                if (sz == 2 * REGSIZE && cs.IFL1 == FLreg)
                    cl = cat(cl,getregs(cs.IEVsym1->Sregm));
            }
            cs.Iop = (sz == 1) ? 0xC6 : 0xC7;

            if (e2oper == OPrelconst)
            {
                cs.IEVoffset2 = e2->EV.sp.Voffset;
                cs.IFL2 = fl;
                cs.IEVsym2 = e2->EV.sp.Vsym;
                cs.Iflags |= CFoff;
                cl = gen(cl,&cs);       /* MOV EA,&variable     */
                if (I64 && sz == 8)
                    code_orrex(cl, REX_W);
                if (sz > REGSIZE)
                {
                    cs.Iop = 0x8C;
                    getlvalue_msw(&cs);
                    cs.Irm |= modregrm(0,3,0);
                    cl = gen(cl,&cs);   /* MOV EA+2,DS  */
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
                        cl = movregconst(cl,reg,*p,64);
                    else
                        cl = movregconst(cl,reg,*p,1 ^ (cs.Iop & 1));
                    if (sz == 2 * REGSIZE)
                    {   getlvalue_msw(&cs);
                        if (REGSIZE == 2)
                            cl = movregconst(cl,cs.Irm & 7,((unsigned short *)p)[1],0);
                        else if (REGSIZE == 4)
                            cl = movregconst(cl,cs.Irm & 7,((unsigned *)p)[1],0);
                        else if (REGSIZE == 8)
                            cl = movregconst(cl,cs.Irm & 7,p[1],0);
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
                    cl = regwithvalue(cl,rregm,*p,&reg,64);
                    cs.Iop = 0x89;
                    cs.Irm |= modregrm(0,reg & 7,0);
                    if (reg & 8)
                        cs.Irex |= REX_R;
                    cl = gen(cl,&cs);
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
                            cl = regwithvalue(cl,rregm,*p,&reg,64);
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
                        cl = gen(cl,&cs);           /* MOV EA,const */

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
            c = cl;
            goto Lp;
        }
        retregs = allregs;              /* pick a reg, any reg          */
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
#if TARGET_SEGMENTED
           && (
             (e1->Eoper == OPind &&
                ((tymll = tybasic(e1->E1->Ety)) == TYfptr || tymll == TYhptr)) ||
             (e1->Eoper == OPvar && e1->EV.sp.Vsym->Sfl == FLfardata)
            )
#endif
          )
        // getlvalue() needs ES, so we can't return it
        retregs = allregs;              /* no conflicts with ES         */
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
            reg = varreg;       /* evaluate directly in target register */
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
  if (*pretregs & mPSW && !EOP(e1))     /* if evaluating e1 couldn't change flags */
  {     /* Be careful that this lines up with jmpopcode()       */
        retregs |= mPSW;
        *pretregs &= ~mPSW;
  }
  cr = scodelem(e2,&retregs,0,TRUE);    /* get rvalue                   */

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
        cl = getlvalue(&cs,e11,RMstore | retregs);
        freenode(e11->E2);
        if (I64 && sz < 8)
            cs.Irex &= ~REX_W;                  // incorrectly set by getlvalue()
    }
    else
    {   postinc = 0;
        cl = getlvalue(&cs,e1,RMstore | retregs);       // get lvalue (cl == CNIL if regvar)
    }

    c = getregs(varregm);

  assert(!(retregs & mES && (cs.Iflags & CFSEG) == CFes));
#if TARGET_SEGMENTED
  if ((tyml == TYfptr || tyml == TYhptr) && retregs & mES)
  {
        reg = findreglsw(retregs);
        cs.Irm |= modregrm(0,reg,0);
        c = gen(c,&cs);                 /* MOV EA,reg                   */
        getlvalue_msw(&cs);             // point to where segment goes
        cs.Iop = 0x8C;
        NEWREG(cs.Irm,0);
        gen(c,&cs);                     /* MOV EA+2,ES                  */
  }
  else
#endif
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
                c = gen(c,&cs);         // MOV EA+offset,reg
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
                cs.IEVoffset1 += sz - REGSIZE;  /* 0,2,6        */
            reg = findreg(retregs &
                    (sz > REGSIZE ? mMSW : ALLREGS));
            if (tyml == TYdouble || tyml == TYdouble_alias)
                reg = AX;
            cs.Irm |= modregrm(0,reg,0);
            /* Do not generate mov from register onto itself            */
            if (!regvar || reg != (cs.Irm & 7))
                for (; TRUE; sz -= REGSIZE)             /* 1,2,4        */
                {
                    c = gen(c,&cs);             /* MOV EA+offset,reg            */
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
  if (e1->Ecount ||                     /* if lvalue is a CSE or        */
      regvar)                           /* rvalue can't be a CSE        */
  {
        c = cat(c,getregs_imm(retregs));        // necessary if both lvalue and
                                        //  rvalue are CSEs (since a reg
                                        //  can hold only one e at a time)
        cssave(e1,retregs,EOP(e1));     /* if lvalue is a CSE           */
  }

    c = cat4(cr,cl,c,fixresult(e,retregs,pretregs));
Lp:
    if (postinc)
    {
        int reg = findreg(idxregm(&cs));
        if (*pretregs & mPSW)
        {   // Use LEA to avoid touching the flags
            unsigned rm = cs.Irm & 7;
            if (cs.Irex & REX_B)
                rm |= 8;
            c = genc1(c,0x8D,buildModregrm(2,reg,rm),FLconst,postinc);
            if (tysize(e11->E1->Ety) == 8)
                code_orrex(c, REX_W);
        }
        else if (I64)
        {
            c = genc2(c,0x81,modregrmx(3,0,reg),postinc);
            if (tysize(e11->E1->Ety) == 8)
                code_orrex(c, REX_W);
        }
        else
        {
            if (postinc == 1)
                c = gen1(c,0x40 + reg);         // INC reg
            else if (postinc == -(targ_int)1)
                c = gen1(c,0x48 + reg);         // DEC reg
            else
            {
                c = genc2(c,0x81,modregrm(3,0,reg),postinc);
            }
        }
    }
    freenode(e1);
    return c;
}


/************************
 * Generate code for += -= &= |= ^= negass
 */

code *cdaddass(elem *e,regm_t *pretregs)
{ regm_t retregs,forccs,forregs;
  tym_t tyml;
  unsigned reg,op,op1,op2,mode,wantres;
  int byte;
  code *cl,*cr,*c,*ce,cs;
  elem *e1;
  elem *e2;
  unsigned opsize;
  unsigned reverse;
  int sz;
  regm_t varregm;
  unsigned varreg;
  unsigned cflags;
  unsigned jop;

  //printf("cdaddass(e=%p, *pretregs = %s)\n",e,regm_str(*pretregs));
  op = e->Eoper;
  retregs = 0;
  reverse = 0;
  e1 = e->E1;
  tyml = tybasic(e1->Ety);              // type of lvalue
  sz = tysize[tyml];
  byte = (sz == 1);                     // 1 for byte operation, else 0

    // See if evaluate in XMM registers
    if (config.fpxmmregs && tyxmmreg(tyml) && op != OPnegass && !(*pretregs & mST0))
        return xmmopass(e,pretregs);

    if (tyfloating(tyml))
    {
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
      if (op == OPnegass)
            c = cdnegass87(e,pretregs);
        else
            c = opass87(e,pretregs);
#else
        if (op == OPnegass)
            c = opnegassdbl(e,pretregs);
        else
            c = opassdbl(e,pretregs,op);
#endif
        return c;
  }
  opsize = (I16 && tylong(tyml) && config.target_cpu >= TARGET_80386)
        ? CFopsize : 0;
  cflags = 0;
  forccs = *pretregs & mPSW;            // return result in flags
  forregs = *pretregs & ~mPSW;          // return result in regs
  /* TRUE if we want the result in a register   */
  wantres = forregs || (e1->Ecount && EOP(e1));

  switch (op)                   /* select instruction opcodes           */
  {     case OPpostinc: op = OPaddass;                  /* i++ => +=    */
        case OPaddass:  op1 = 0x01; op2 = 0x11;
                        cflags = CFpsw;
                        mode = 0; break;                /* ADD, ADC     */
        case OPpostdec: op = OPminass;                  /* i-- => -=    */
        case OPminass:  op1 = 0x29; op2 = 0x19;
                        cflags = CFpsw;
                        mode = 5; break;                /* SUB, SBC     */
        case OPandass:  op1 = op2 = 0x21;
                        mode = 4; break;                /* AND, AND     */
        case OPorass:   op1 = op2 = 0x09;
                        mode = 1; break;                /* OR , OR      */
        case OPxorass:  op1 = op2 = 0x31;
                        mode = 6; break;                /* XOR, XOR     */
        case OPnegass:  op1 = 0xF7;                     // NEG
                        break;
        default:
                assert(0);
  }
  op1 ^= byte;                  /* bit 0 is 0 for byte operation        */

  if (op == OPnegass)
  {
        cl = getlvalue(&cs,e1,0);
        cr = modEA(&cs);
        cs.Irm |= modregrm(0,3,0);
        cs.Iop = op1;
        switch (tysize[tyml])
        {   case CHARSIZE:
                c = gen(CNIL,&cs);
                break;

            case SHORTSIZE:
                c = gen(CNIL,&cs);
                if (!I16 && *pretregs & mPSW)
                    c->Iflags |= CFopsize | CFpsw;
                break;

            case LONGSIZE:
                if (!I16 || opsize)
                {   c = gen(CNIL,&cs);
                    c->Iflags |= opsize;
                    break;
                }
            neg_2reg:
                getlvalue_msw(&cs);
                c = gen(CNIL,&cs);              // NEG EA+2
                getlvalue_lsw(&cs);
                gen(c,&cs);                     // NEG EA
                code_orflag(c,CFpsw);
                cs.Iop = 0x81;
                getlvalue_msw(&cs);
                cs.IFL2 = FLconst;
                cs.IEV2.Vuns = 0;
                gen(c,&cs);                     // SBB EA+2,0
                break;

            case LLONGSIZE:
                if (I16)
                    assert(0);                      // not implemented yet
                if (I32)
                    goto neg_2reg;
                c = gen(CNIL,&cs);
                break;

            default:
                assert(0);
        }
        c = cat3(cl,cr,c);
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
#if TARGET_SEGMENTED
        && tyml != TYhptr
#endif
        )
      )
     )
  {
        cl = getlvalue(&cs,e1,0);
        cl = cat(cl,modEA(&cs));
        cs.IFL2 = FLconst;
        cs.IEV2.Vsize_t = e2->EV.Vint;
        if (sz <= REGSIZE || tyfv(tyml) || opsize)
        {
            targ_int i = cs.IEV2.Vint;

            /* Handle shortcuts. Watch out for if result has    */
            /* to be in flags.                                  */

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
                {   case OPminass:      /* convert to +=        */
                        cs.Irm ^= modregrm(0,5,0);
                        i = -i;
                        cs.IEV2.Vsize_t = i;
                        /* FALL-THROUGH */
                    case OPaddass:
                        if (i == 1)             /* INC EA       */
                                goto L1;
                        else if (i == -1)       /* DEC EA       */
                        {       cs.Irm |= modregrm(0,1,0);
                           L1:  cs.Iop = 0xFF;
                        }
                        break;
                }
                cs.Iop ^= byte;             /* for byte operations  */
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

                cr = allocreg(&sregm,&reg,tyml);        // allocate register

                cs2 = cs;
                cs2.Iflags &= ~CFpsw;
                cs2.Iop = 0x8B ^ byte;
                code_newreg(&cs2, reg);
                cr = gen(cr,&cs2);                      // MOV reg,EA

                cs.Irm = (cs.Irm & modregrm(0,7,0)) | modregrm(3,0,reg & 7);
                if (reg & 8)
                    cs.Irex |= REX_B;
                gen(cr,&cs);                            // OP reg

                cs2.Iop ^= 2;
                gen(cr,&cs2);                           // MOV EA,reg

                c = cat(cl,cr);
                retregs = sregm;
                wantres = 0;
                if (e1->Ecount)
                    cssave(e1,retregs,EOP(e1));
            }
            else
            {
                c = gen(cl,&cs);
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
                c = cl;
                cs.Iflags |= cflags;
                c = gen(c,&cs);
                cs.Iflags &= ~CFpsw;

                getlvalue_msw(&cs);             // point to msw
                msw = MSREG(e->E2->EV.Vllong);
                cs.IEV2.Vuns = msw;             /* msw of constant      */
                switch (op)
                {   case OPminass:
                        cs.Irm ^= modregrm(0,6,0);      /* SUB => SBB   */
                        break;
                    case OPaddass:
                        cs.Irm |= modregrm(0,2,0);      /* ADD => ADC   */
                        break;
                }
                c = gen(c,&cs);
        }
        else
            assert(0);
        freenode(e->E2);        /* don't need it anymore        */
  }
  else if (isregvar(e1,&varregm,&varreg) &&
           (e2->Eoper == OPvar || e2->Eoper == OPind) &&
          !evalinregister(e2) &&
           sz <= REGSIZE)               // deal with later
  {
        cr = getlvalue(&cs,e2,0);
        freenode(e2);
        cl = getregs(varregm);
        code_newreg(&cs, varreg);
        if (I64 && sz == 1 && varreg >= 4)
            cs.Irex |= REX;
        cs.Iop = op1 ^ 2;                       // toggle direction bit
        if (forccs)
            cs.Iflags |= CFpsw;
        reverse = 2;                            // remember we toggled it
        cl = gen(cl,&cs);
        c = cat(cr,cl);
        retregs = 0;            /* to trigger a bug if we attempt to use it */
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
        cl = getlvalue(&cs,e1,0);               // get lvalue
        cl = cat(cl,modEA(&cs));
        regm_t keepmsk = idxregm(&cs);
        retregs = mPSW;
        if (OTconv(e2->Eoper))
        {
            cr = scodelem(e2->E1,&retregs,keepmsk,TRUE);
            freenode(e2);
        }
        else
            cr = scodelem(e2,&retregs,keepmsk,TRUE);
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
        cr = gen(cr,&cs);
        c = cat(cl,cr);
        retregs = 0;            /* to trigger a bug if we attempt to use it */
  }
  else // evaluate e2 into register
  {
        retregs = (byte) ? BYTEREGS : ALLREGS;  // pick working reg
#if TARGET_SEGMENTED
        if (tyml == TYhptr)
            retregs &= ~mCX;                    // need CX for shift count
#endif
        cr = scodelem(e->E2,&retregs,0,TRUE);   // get rvalue
        cl = getlvalue(&cs,e1,retregs);         // get lvalue
        cl = cat(cl,modEA(&cs));
        cs.Iop = op1;
        if (sz <= REGSIZE || tyfv(tyml))
        {   reg = findreg(retregs);
            code_newreg(&cs, reg);              // OP1 EA,reg
            if (sz == 1 && reg >= 4 && I64)
                cs.Irex |= REX;
        }
#if TARGET_SEGMENTED
        else if (tyml == TYhptr)
        {   unsigned mreg,lreg;

            mreg = findregmsw(retregs);
            lreg = findreglsw(retregs);
            cl = cat(cl,getregs(retregs | mCX));

            // If h -= l, convert to h += -l
            if (e->Eoper == OPminass)
            {
                cl = gen2(cl,0xF7,modregrm(3,3,mreg));  // NEG mreg
                gen2(cl,0xF7,modregrm(3,3,lreg));       // NEG lreg
                code_orflag(cl,CFpsw);
                genc2(cl,0x81,modregrm(3,3,mreg),0);    // SBB mreg,0
            }
            cs.Iop = 0x01;
            cs.Irm |= modregrm(0,lreg,0);
            cl = gen(cl,&cs);                           // ADD EA,lreg
            code_orflag(cl,CFpsw);
            genc2(cl,0x81,modregrm(3,2,mreg),0);        // ADC mreg,0
            genshift(cl);                               // MOV CX,offset __AHSHIFT
            gen2(cl,0xD3,modregrm(3,4,mreg));           // SHL mreg,CL
            NEWREG(cs.Irm,mreg);                        // ADD EA+2,mreg
            getlvalue_msw(&cs);
        }
#endif
        else if (sz == 2 * REGSIZE)
        {
            cs.Irm |= modregrm(0,findreglsw(retregs),0);
            cl = gen(cl,&cs);                           /* OP1 EA,reg+1 */
            code_orflag(cl,cflags);
            cs.Iop = op2;
            NEWREG(cs.Irm,findregmsw(retregs)); /* OP2 EA+1,reg */
            getlvalue_msw(&cs);
        }
        else
                assert(0);
        cl = gen(cl,&cs);
        c = cat(cr,cl);
        retregs = 0;            /* to trigger a bug if we attempt to use it */
  }

  /* See if we need to reload result into a register.   */
  /* Need result in registers in case we have a 32 bit  */
  /* result and we want the flags as a result.          */
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
                ce = allocreg(&retregs,&reg,tyml);
            }
            // If lvalue is a register, just use that register
            else if ((cs.Irm & 0xC0) == 0xC0)
            {
                reg = cs.Irm & 7;
                if (cs.Irex & REX_B)
                    reg |= 8;
                retregs = mask[reg];
                ce = allocreg(&retregs,&reg,tyml);
            }
            else
            {
                ce = allocreg(&retregs,&reg,tyml);
                cs.Iop = 0x8B ^ byte ^ reverse;
                code_newreg(&cs, reg);
                if (I64 && byte && reg >= 4)
                    cs.Irex |= REX_W;
                ce = gen(ce,&cs);               // MOV reg,EA
            }
        }
#if TARGET_SEGMENTED
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
                ce = allocreg(&retregs,&reg,tyml);
                NEWREG(cs.Irm,findreglsw(retregs));
                if (retregs & mES)              /* if want ES loaded    */
                {   cs.Iop = 0xC4;
                    ce = gen(ce,&cs);           /* LES lreg,EA          */
                }
                else
                {   cs.Iop = 0x8B;
                    ce = gen(ce,&cs);           /* MOV lreg,EA          */
                    getlvalue_msw(&cs);
                    if (I32)
                        cs.Iflags |= CFopsize;
                    NEWREG(cs.Irm,reg);
                    gen(ce,&cs);                /* MOV mreg,EA+2        */
                }
        }
#endif
        else if (sz == 2 * REGSIZE)
        {       regm_t idx;
                code *cm,*cl;

                idx = idxregm(&cs);
                retregs = forregs;
                if (!retregs)
                        retregs = ALLREGS;
                ce = allocreg(&retregs,&reg,tyml);
                cs.Iop = 0x8B;
                NEWREG(cs.Irm,reg);
                cm = gen(NULL,&cs);             // MOV reg,EA+2
                NEWREG(cs.Irm,findreglsw(retregs));
                getlvalue_lsw(&cs);
                cl = gen(NULL,&cs);             // MOV reg+1,EA
                if (mask[reg] & idx)
                    ce = cat3(ce,cl,cm);
                else
                    ce = cat3(ce,cm,cl);
        }
        else
            assert(0);
        c = cat(c,ce);
        if (e1->Ecount)                 /* if we gen a CSE      */
                cssave(e1,retregs,EOP(e1));
  }
  freenode(e1);
  if (sz <= REGSIZE)
        *pretregs &= ~mPSW;            // flags are already set
  return cat(c,fixresult(e,retregs,pretregs));
}

/********************************
 * Generate code for *= /= %=
 */

code *cdmulass(elem *e,regm_t *pretregs)
{
    code *cr,*cl,*cg,*c,cs;
    regm_t retregs;
    unsigned resreg,reg,opr,lib,byte;

    //printf("cdmulass(e=%p, *pretregs = %s)\n",e,regm_str(*pretregs));
    elem *e1 = e->E1;
    elem *e2 = e->E2;
    unsigned op = e->Eoper;                     // OPxxxx

    tym_t tyml = tybasic(e1->Ety);              // type of lvalue
    char uns = tyuns(tyml) || tyuns(e2->Ety);
    unsigned sz = tysize[tyml];

    unsigned rex = (I64 && sz == 8) ? REX_W : 0;
    unsigned grex = rex << 16;          // 64 bit operands

    // See if evaluate in XMM registers
    if (config.fpxmmregs && tyxmmreg(tyml) && op != OPmodass && !(*pretregs & mST0))
        return xmmopass(e,pretregs);

    if (tyfloating(tyml))
    {
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        return opass87(e,pretregs);
#else
        return opassdbl(e,pretregs,op);
#endif
    }

  if (sz <= REGSIZE)                    /* if word or byte              */
  {     byte = (sz == 1);               /* 1 for byte operation         */
        resreg = AX;                    /* result register for * or /   */
        if (uns)                        /* if unsigned operation        */
                opr = 4;                /* MUL                          */
        else                            /* else signed                  */
                opr = 5;                /* IMUL                         */
        if (op != OPmulass)             /* if /= or %=                  */
        {       opr += 2;               /* MUL => DIV, IMUL => IDIV     */
                if (op == OPmodass)
                        resreg = DX;    /* remainder is in DX           */
        }
        if (op == OPmulass)             /* if multiply                  */
        {
            if (config.target_cpu >= TARGET_80286 &&
                e2->Eoper == OPconst && !byte)
            {
                targ_size_t e2factor = el_tolong(e2);
                if (I64 && sz == 8 && e2factor != (int)e2factor)
                    goto L1;
                freenode(e2);
                cr = CNIL;
                cl = getlvalue(&cs,e1,0);       /* get EA               */
                regm_t idxregs = idxregm(&cs);
                retregs = *pretregs & (ALLREGS | mBP) & ~idxregs;
                if (!retregs)
                    retregs = ALLREGS & ~idxregs;
                cg = allocreg(&retregs,&resreg,tyml);
                cs.Iop = 0x69;                  /* IMUL reg,EA,e2value  */
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
                cr = codelem(e2,&retregs,FALSE); /* load rvalue in reg  */
                cl = getlvalue(&cs,e1,retregs); /* get EA               */
                cg = getregs(retregs);          /* destroy these regs   */
                cs.Iop = 0x0FAF;                // IMUL resreg,EA
                resreg = findreg(retregs);
                opr = resreg;
            }
            else
            {
                retregs = mAX;
                cr = codelem(e2,&retregs,FALSE); // load rvalue in AX
                cl = getlvalue(&cs,e1,mAX);     // get EA
                cg = getregs(byte ? mAX : mAX | mDX); // destroy these regs
                cs.Iop = 0xF7 ^ byte;           // [I]MUL EA
            }
            code_newreg(&cs,opr);
            c = gen(CNIL,&cs);
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
                cr = NULL;
                c = NULL;
                cl = getlvalue(&cs,e1,mAX | mDX);
                cs.Iop = 0x8B;
                code_newreg(&cs, AX);
                cl = gen(cl,&cs);                       // MOV AX,EA
                freenode(e2);
                cg = getregs(mAX | mDX);                // trash these regs
                cg = gen1(cg,0x99);                     // CWD
                code_orrex(cg, rex);
                if (pow2 == 1)
                {
                    if (op == OPdivass)
                    {   gen2(cg,0x2B,grex | modregrm(3,AX,DX));        // SUB AX,DX
                        gen2(cg,0xD1,grex | modregrm(3,7,AX));         // SAR AX,1
                        resreg = AX;
                    }
                    else // OPmod
                    {   gen2(cg,0x33,grex | modregrm(3,AX,DX));        // XOR AX,DX
                        genc2(cg,0x81,grex | modregrm(3,4,AX),1);      // AND AX,1
                        gen2(cg,0x03,grex | modregrm(3,DX,AX));        // ADD DX,AX
                        resreg = DX;
                    }
                }
                else
                {
                    assert(pow2 < 32);
                    targ_ulong m = (1 << pow2) - 1;
                    if (op == OPdivass)
                    {   genc2(cg,0x81,grex | modregrm(3,4,DX),m);      // AND DX,m
                        gen2(cg,0x03,grex | modregrm(3,AX,DX));        // ADD AX,DX
                        // Be careful not to generate this for 8088
                        assert(config.target_cpu >= TARGET_80286);
                        genc2(cg,0xC1,grex | modregrm(3,7,AX),pow2);   // SAR AX,pow2
                        resreg = AX;
                    }
                    else // OPmodass
                    {   gen2(cg,0x33,grex | modregrm(3,AX,DX));        // XOR AX,DX
                        gen2(cg,0x2B,grex | modregrm(3,AX,DX));        // SUB AX,DX
                        genc2(cg,0x81,grex | modregrm(3,4,AX),m);      // AND AX,m
                        gen2(cg,0x33,grex | modregrm(3,AX,DX));        // XOR AX,DX
                        gen2(cg,0x2B,grex | modregrm(3,AX,DX));        // SUB AX,DX
                        resreg = AX;
                    }
                }
            }
            else
            {
                retregs = ALLREGS & ~(mAX|mDX);         // DX gets sign extension
                cr = codelem(e2,&retregs,FALSE);        // load rvalue in retregs
                reg = findreg(retregs);
                cl = getlvalue(&cs,e1,mAX | mDX | retregs);     // get EA
                cg = getregs(mAX | mDX);        // destroy these regs
                cs.Irm |= modregrm(0,AX,0);
                cs.Iop = 0x8B;
                c = gen(CNIL,&cs);              // MOV AX,EA
                if (uns)                        // if unsigned
                    movregconst(c,DX,0,0);      // CLR DX
                else                            // else signed
                {   gen1(c,0x99);               // CWD
                    code_orrex(c,rex);
                }
                c = cat(c,getregs(mDX | mAX));  // DX and AX will be destroyed
                genregs(c,0xF7,opr,reg);        // OPR reg
                code_orrex(c,rex);
            }
        }
        cs.Iop = 0x89 ^ byte;
        code_newreg(&cs,resreg);
        c = gen(c,&cs);                         // MOV EA,resreg
        if (e1->Ecount)                         // if we gen a CSE
                cssave(e1,mask[resreg],EOP(e1));
        freenode(e1);
        c = cat(c,fixresult(e,mask[resreg],pretregs));
        return cat4(cr,cl,cg,c);
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
        cr = codelem(e2,&retregs,FALSE);
        cl = getlvalue(&cs,e1,mDX|mAX | mCX|mBX);
        cl = cat(cl,getregs(mDX | mAX));
        cs.Iop = 0x8B;
        cl = gen(cl,&cs);               /* MOV AX,EA                    */
        getlvalue_msw(&cs);
        cs.Irm |= modregrm(0,DX,0);
        gen(cl,&cs);                    /* MOV DX,EA+2                  */
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
             c = getregs(mAX|mDX|mCX);
             c = gen2(c,0x0FAF,modregrm(3,CX,AX));
             gen2(c,0x0FAF,modregrm(3,DX,BX));
             gen2(c,0x03,modregrm(3,CX,DX));
             gen2(c,0xF7,modregrm(3,4,BX));
             gen2(c,0x03,modregrm(3,DX,CX));
        }
        else
        {   if (op == OPmodass)
                retregs = mBX | mCX;
            c = callclib(e,lib,&retregs,idxregm(&cs));
        }
        reg = findreglsw(retregs);
        cs.Iop = 0x89;
        NEWREG(cs.Irm,reg);
        gen(c,&cs);                     /* MOV EA,lsreg                 */
        reg = findregmsw(retregs);
        NEWREG(cs.Irm,reg);
        getlvalue_msw(&cs);
        gen(c,&cs);                     /* MOV EA+2,msreg               */
        if (e1->Ecount)                 // if we gen a CSE
                cssave(e1,retregs,EOP(e1));
        freenode(e1);
        cg = fixresult(e,retregs,pretregs);
        return cat4(cr,cl,c,cg);
  }
  else
  {     assert(0);
        /* NOTREACHED */
        return 0;
  }
}


/********************************
 * Generate code for <<= and >>=
 */

code *cdshass(elem *e,regm_t *pretregs)
{ elem *e1,*e2;
  code *cr,*cl,*cg,*c,cs,*ce;
  tym_t tym,tyml;
  regm_t retregs;
  unsigned shiftcnt,op1,op2,reg,v,oper,byte,conste2;
  unsigned loopcnt;
  unsigned sz;

  e1 = e->E1;
  e2 = e->E2;

  tyml = tybasic(e1->Ety);              /* type of lvalue               */
  sz = tysize[tyml];
  byte = tybyte(e->Ety) != 0;           /* 1 for byte operations        */
  tym = tybasic(e->Ety);                /* type of result               */
  oper = e->Eoper;
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
  {     case OPshlass:
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


  v = 0xD3;                             /* for SHIFT xx,CL cases        */
  loopcnt = 1;
  conste2 = FALSE;
  cr = CNIL;
  shiftcnt = 0;                         // avoid "use before initialized" warnings
  if (cnst(e2))
  {
        conste2 = TRUE;                 /* e2 is a constant             */
        shiftcnt = e2->EV.Vint;         /* byte ordering of host        */
        if (config.target_cpu >= TARGET_80286 &&
            sz <= REGSIZE &&
            shiftcnt != 1)
            v = 0xC1;                   // SHIFT xx,shiftcnt
        else if (shiftcnt <= 3)
        {   loopcnt = shiftcnt;
            v = 0xD1;                   // SHIFT xx,1
        }
  }
  if (v == 0xD3)                        /* if COUNT == CL               */
  {     retregs = mCX;
        cr = codelem(e2,&retregs,FALSE);
  }
  else
        freenode(e2);
  cl = getlvalue(&cs,e1,mCX);           /* get lvalue, preserve CX      */
  cl = cat(cl,modEA(&cs));              // check for modifying register

  if (*pretregs == 0 ||                 /* if don't return result       */
      (*pretregs == mPSW && conste2 && tysize[tym] <= REGSIZE) ||
      sz > REGSIZE
     )
  {     retregs = 0;            // value not returned in a register
        cs.Iop = v ^ byte;
        c = CNIL;
        while (loopcnt--)
        {
          NEWREG(cs.Irm,op1);           /* make sure op1 is first       */
          if (sz <= REGSIZE)
          {
              if (conste2)
              {   cs.IFL2 = FLconst;
                  cs.IEV2.Vint = shiftcnt;
              }
              c = gen(c,&cs);           /* SHIFT EA,[CL|1]              */
              if (*pretregs & mPSW && !loopcnt && conste2)
                code_orflag(c,CFpsw);
          }
          else /* TYlong */
          {   cs.Iop = 0xD1;            /* plain shift                  */
              ce = gennop(CNIL);                        /* ce: NOP      */
              if (v == 0xD3)
              {   c = getregs(mCX);
                  if (!conste2)
                  {   assert(loopcnt == 0);
                      c = genjmp(c,JCXZ,FLcode,(block *) ce);   /* JCXZ ce */
                  }
              }
              if (oper == OPshlass)
              {       cg = gen(CNIL,&cs);               // cg: SHIFT EA
                      code_orflag(cg,CFpsw);
                      c = cat(c,cg);
                      getlvalue_msw(&cs);
                      NEWREG(cs.Irm,op2);
                      gen(c,&cs);                       /* SHIFT EA     */
                      getlvalue_lsw(&cs);
              }
              else
              {       getlvalue_msw(&cs);
                      cg = gen(CNIL,&cs);
                      code_orflag(cg,CFpsw);
                      c = cat(c,cg);
                      NEWREG(cs.Irm,op2);
                      getlvalue_lsw(&cs);
                      gen(c,&cs);
              }
              if (v == 0xD3)                    /* if building a loop   */
              {   genjmp(c,LOOP,FLcode,(block *) cg); /* LOOP cg        */
                  regimmed_set(CX,0);           /* note that now CX == 0 */
              }
              c = cat(c,ce);
          }
        }

        /* If we want the result, we must load it from the EA   */
        /* into a register.                                             */

        if (sz == 2 * REGSIZE && *pretregs)
        {   retregs = *pretregs & (ALLREGS | mBP);
            if (retregs)
            {   ce = allocreg(&retregs,&reg,tym);
                cs.Iop = 0x8B;

                /* be careful not to trash any index regs       */
                /* do MSW first (which can't be an index reg)   */
                getlvalue_msw(&cs);
                NEWREG(cs.Irm,reg);
                cg = gen(CNIL,&cs);
                getlvalue_lsw(&cs);
                reg = findreglsw(retregs);
                NEWREG(cs.Irm,reg);
                gen(cg,&cs);
                if (*pretregs & mPSW)
                    cg = cat(cg,tstresult(retregs,tyml,TRUE));
            }
            else        /* flags only   */
            {   retregs = ALLREGS & ~idxregm(&cs);
                ce = allocreg(&retregs,&reg,TYint);
                cs.Iop = 0x8B;
                NEWREG(cs.Irm,reg);
                cg = gen(CNIL,&cs);     /* MOV reg,EA           */
                cs.Iop = 0x0B;          /* OR reg,EA+2          */
                cs.Iflags |= CFpsw;
                getlvalue_msw(&cs);
                gen(cg,&cs);
            }
            c = cat3(c,ce,cg);
        }
        cg = CNIL;
  }
  else                                  /* else must evaluate in register */
  {
        if (sz <= REGSIZE)
        {
            regm_t possregs = ALLREGS & ~mCX & ~idxregm(&cs);
            if (byte)
                    possregs &= BYTEREGS;
            retregs = *pretregs & possregs;
            if (retregs == 0)
                    retregs = possregs;
            cg = allocreg(&retregs,&reg,tym);
            cs.Iop = 0x8B ^ byte;
            code_newreg(&cs, reg);
            if (byte && I64 && (reg >= 4))
                cs.Irex |= REX;
            c = ce = gen(CNIL,&cs);                     /* MOV reg,EA   */
            if (!I16)
            {
                assert(!byte || (mask[reg] & BYTEREGS));
                ce = genc2(CNIL,v ^ byte,modregrmx(3,op1,reg),shiftcnt);
                if (byte && I64 && (reg >= 4))
                    ce->Irex |= REX;
                code_orrex(ce, rex);
                /* We can do a 32 bit shift on a 16 bit operand if      */
                /* it's a left shift and we're not concerned about      */
                /* the flags. Remember that flags are not set if        */
                /* a shift of 0 occurs.                         */
                if (tysize[tym] == SHORTSIZE &&
                    (oper == OPshrass || oper == OPashrass ||
                     (*pretregs & mPSW && conste2)))
                     ce->Iflags |= CFopsize;            /* 16 bit operand */
                cat(c,ce);
            }
            else
            {
                while (loopcnt--)
                {   /* Generate shift instructions.     */
                    genc2(ce,v ^ byte,modregrm(3,op1,reg),shiftcnt);
                }
            }
            if (*pretregs & mPSW && conste2)
            {   assert(shiftcnt);
                *pretregs &= ~mPSW;     // result is already in flags
                code_orflag(ce,CFpsw);
            }

            cs.Iop = 0x89 ^ byte;
            if (byte && I64 && (reg >= 4))
                cs.Irex |= REX;
            gen(ce,&cs);                                /* MOV EA,reg   */

            // If result is not in correct register
            cat(ce,fixresult(e,retregs,pretregs));
            retregs = *pretregs;
        }
        else
                assert(0);
  }
  if (e1->Ecount && !(retregs & regcon.mvar))   // if lvalue is a CSE
        cssave(e1,retregs,EOP(e1));
  freenode(e1);
  *pretregs = retregs;
  return cat4(cr,cl,cg,c);
}


/**********************************
 * Generate code for compares.
 * Handles lt,gt,le,ge,eqeq,ne for all data types.
 */

code *cdcmp(elem *e,regm_t *pretregs)
{ regm_t retregs,rretregs;
  unsigned reg,rreg,op,byte;
  tym_t tym;
  code *cl,*cr,*c,cs,*ce,*cg;
  elem *e1,*e2;
  bool eqorne;
  unsigned sz;
  int fl;
  int flag;

  //printf("cdcmp(e = %p, pretregs = %s)\n",e,regm_str(*pretregs));
  // Collect extra parameter. This is pretty ugly...
  flag = cdcmp_flag;
  cdcmp_flag = 0;

  e1 = e->E1;
  e2 = e->E2;
  if (*pretregs == 0)                   /* if don't want result         */
  {     cl = codelem(e1,pretregs,FALSE);
        *pretregs = 0;                  /* in case e1 changed it        */
        cr = codelem(e2,pretregs,FALSE);
        return cat(cl,cr);
  }

  unsigned jop = jmpopcode(e);          // must be computed before
                                        // leaves are free'd
  unsigned reverse = 0;

  cl = cr = CNIL;
  op = e->Eoper;
  assert(OTrel(op));
  eqorne = (op == OPeqeq) || (op == OPne);

  tym = tybasic(e1->Ety);
  sz = tysize[tym];
  byte = sz == 1;

    unsigned rex = (I64 && sz == 8) ? REX_W : 0;
    unsigned grex = rex << 16;          // 64 bit operands

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
  if (tyfloating(tym))                  /* if floating operation        */
  {
        retregs = mPSW;
        if (tyxmmreg(tym) && config.fpxmmregs)
            c = orthxmm(e,&retregs);
        else
            c = orth87(e,&retregs);
        goto L3;
  }
#else
  if (tyfloating(tym))                  /* if floating operation        */
  {
        if (config.inline8087)
        {   retregs = mPSW;
            c = orth87(e,&retregs);
        }
        else
        {   int clib;

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
                cl = codelem(e1,&retregs,FALSE);
                retregs = 0;
                c = callclib(e,clib,&retregs,0);
                freenode(e2);
            }
            else
            {   clib = CLIBdcmp;
                if (rel_exception(op))
                    clib += CLIBdcmpexc - CLIBdcmp;
                c = opdouble(e,&retregs,clib);
            }
        }
        goto L3;
  }
#endif

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
        cl = codelem(e1,&retregs,FALSE);
        retregs = mCX | mBX;
        cr = scodelem(e2,&retregs,mDX | mAX,FALSE);

        if (I16)
        {
            retregs = 0;
            c = callclib(e,CLIBlcmp,&retregs,0);    /* gross, but it works  */
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
             c = getregs(mDX);
             c = genregs(c,0x39,CX,DX);         // CMP EDX,ECX
             code *c1 = gennop(CNIL);
             genjmp(c,JNE,FLcode,(block *)c1);  // JNE C1
             movregconst(c,DX,0,0);             // XOR EDX,EDX
             genregs(c,0x39,BX,AX);             // CMP EAX,EBX
             genjmp(c,JE,FLcode,(block *)c1);   // JZ C1
             code *c3 = gen1(CNIL,0x40 + DX);   // INC EDX
             genjmp(c,JA,FLcode,(block *)c3);   // JA C3
             gen1(c,0x48 + DX);                 // DEC EDX
             genjmp(c,JMPS,FLcode,(block *)c1); // JMP C1
             c = cat4(c,c3,c1,getregs(mDX));
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

  c = CNIL;
  ce = CNIL;
  cs.Iflags = (!I16 && sz == SHORTSIZE) ? CFopsize : 0;
  cs.Irex = rex;
  if (sz > REGSIZE)
        ce = gennop(ce);

  switch (e2->Eoper)
  {
      default:
      L2:
        cl = scodelem(e1,&retregs,0,TRUE);      /* compute left leaf    */
      L1:
        rretregs = allregs & ~retregs;
        if (byte)
                rretregs &= BYTEREGS;
        cr = scodelem(e2,&rretregs,retregs,TRUE);       /* get right leaf */
        if (sz <= REGSIZE)                              /* CMP reg,rreg  */
        {   reg = findreg(retregs);             /* get reg that e1 is in */
            rreg = findreg(rretregs);
            c = genregs(CNIL,0x3B ^ byte ^ reverse,reg,rreg);
            code_orrex(c, rex);
            if (!I16 && sz == SHORTSIZE)
                c->Iflags |= CFopsize;          /* compare only 16 bits */
            if (I64 && byte && (reg >= 4 || rreg >= 4))
                c->Irex |= REX;                 // address byte registers
        }
        else
        {   assert(sz <= 2 * REGSIZE);

            /* Compare MSW, if they're equal then compare the LSW       */
            reg = findregmsw(retregs);
            rreg = findregmsw(rretregs);
            c = genregs(CNIL,0x3B ^ reverse,reg,rreg);  /* CMP reg,rreg */
            if (I32 && sz == 6)
                c->Iflags |= CFopsize;          /* seg is only 16 bits  */
            else if (I64)
                code_orrex(c, REX_W);
            genjmp(c,JNE,FLcode,(block *) ce);          /* JNE nop      */

            reg = findreglsw(retregs);
            rreg = findreglsw(rretregs);
            genregs(c,0x3B ^ reverse,reg,rreg);         /* CMP reg,rreg */
            if (I64)
                code_orrex(c, REX_W);
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
#if TARGET_SEGMENTED
            case FLfardata:
                break;
#endif
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
            c = genregs(NULL,0x85 ^ byte,reg,reg);      // TEST reg,reg
            c->Iflags |= (cs.Iflags & CFopsize) | CFpsw;
            code_orrex(c, rex);
            if (I64 && byte && reg >= 4)
                c->Irex |= REX;                 // address byte registers
            retregs = mPSW;
            break;
        }

        if (!tyuns(tym) && !tyuns(e2->Ety) &&
            !boolres(e2) && !(*pretregs & mPSW) &&
            (sz == REGSIZE || (I64 && sz == 4)) &&
            (!I16 || op == OPlt || op == OPge))
        {
            assert(*pretregs & (allregs));
            cl = codelem(e1,pretregs,FALSE);
            reg = findreg(*pretregs);
            c = getregs(mask[reg]);
            switch (op)
            {   case OPle:
                    c = genc2(c,0x81,grex | modregrmx(3,0,reg),(unsigned)-1);   // ADD reg,-1
                    code_orflag(c, CFpsw);
                    genc2(c,0x81,grex | modregrmx(3,2,reg),0);          // ADC reg,0
                    goto oplt;
                case OPgt:
                    c = gen2(c,0xF7,grex | modregrmx(3,3,reg));         // NEG reg
#if TARGET_WINDOS
                    // What does the Windows platform do?
                    //  lower INT_MIN by 1?   See test exe9.c
                    // BUG: fix later
                    code_orflag(c, CFpsw);
                    genc2(c,0x81,grex | modregrmx(3,3,reg),0);  // SBB reg,0
#endif
                    goto oplt;
                case OPlt:
                oplt:
                    if (!I16)
                        c = genc2(c,0xC1,grex | modregrmx(3,5,reg),sz * 8 - 1); // SHR reg,31
                    else
                    {   /* 8088-286 do not have a barrel shifter, so use this
                           faster sequence
                         */
                        c = genregs(c,0xD1,0,reg);              /* ROL reg,1    */
                        unsigned regi;
                        if (reghasvalue(allregs,1,&regi))
                            c = genregs(c,0x23,reg,regi);       /* AND reg,regi */
                        else
                            c = genc2(c,0x81,modregrm(3,4,reg),1); /* AND reg,1 */
                    }
                    break;
                case OPge:
                    c = genregs(c,0xD1,4,reg);          /* SHL reg,1    */
                    code_orrex(c,rex);
                    code_orflag(c, CFpsw);
                    genregs(c,0x19,reg,reg);            /* SBB reg,reg  */
                    code_orrex(c,rex);
                    if (I64)
                    {
                        c = gen2(c,0xFF,modregrmx(3,0,reg));    // INC reg
                        code_orrex(c, rex);
                    }
                    else
                        c = gen1(c,0x40 + reg);                 // INC reg
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
        {       cl = getlvalue(&cs,e1,RMload);
                freenode(e1);
                if (evalinregister(e2))
                {
                    retregs = idxregm(&cs);
                    if ((cs.Iflags & CFSEG) == CFes)
                            retregs |= mES;             /* take no chances */
                    rretregs = allregs & ~retregs;
                    if (byte)
                            rretregs &= BYTEREGS;
                    cr = scodelem(e2,&rretregs,retregs,TRUE);
                    cs.Iop = 0x39 ^ byte ^ reverse;
                    if (sz > REGSIZE)
                    {
                        rreg = findregmsw(rretregs);
                        cs.Irm |= modregrm(0,rreg,0);
                        getlvalue_msw(&cs);
                        c = gen(CNIL,&cs);              /* CMP EA+2,rreg */
                        if (I32 && sz == 6)
                            c->Iflags |= CFopsize;      /* seg is only 16 bits  */
                        if (I64 && byte && rreg >= 4)
                            c->Irex |= REX;
                        genjmp(c,JNE,FLcode,(block *) ce); /* JNE nop   */
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
#if !TARGET_SEGMENTED
                        if (sz == 6)
                            assert(0);
#endif
                        if (e2->Eoper == OPrelconst)
                        {   cs.Iflags = (cs.Iflags & ~(CFoff | CFseg)) | CFseg;
                            cs.IEVoffset2 = 0;
                        }
                        getlvalue_msw(&cs);
                        c = gen(CNIL,&cs);              /* CMP EA+2,const */
                        if (!I16 && sz == 6)
                            c->Iflags |= CFopsize;      /* seg is only 16 bits  */
                        genjmp(c,JNE,FLcode,(block *) ce); /* JNE nop   */
                        if (e2->Eoper == OPconst)
                            cs.IEV2.Vint = e2->EV.Vllong;
                        else if (e2->Eoper == OPrelconst)
                        {   /* Turn off CFseg, on CFoff */
                            cs.Iflags ^= CFseg | CFoff;
                            cs.IEVoffset2 = e2->EV.sp.Voffset;
                        }
                        else
                            assert(0);
                        getlvalue_lsw(&cs);
                    }
                    freenode(e2);
                }
                c = gen(c,&cs);
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
            cl = scodelem(e1,&retregs,0,FALSE);
            freenode(e2);
            break;
        }
        if (sz <= REGSIZE && !boolres(e2) && e1->Eoper == OPadd && *pretregs == mPSW)
        {
            retregs |= mPSW;
            cl = scodelem(e1,&retregs,0,FALSE);
            freenode(e2);
            break;
        }
        cl = scodelem(e1,&retregs,0,TRUE);      /* compute left leaf    */
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
        {                                       /* CMP reg,const        */
            reg = findreg(retregs & allregs);   // get reg that e1 is in
            rretregs = allregs & ~retregs;
            if (cs.IFL2 == FLconst && reghasvalue(rretregs,cs.IEV2.Vint,&rreg))
            {
                code *cc = genregs(CNIL,0x3B,reg,rreg);
                code_orrex(cc, rex);
                if (!I16)
                    cc->Iflags |= cs.Iflags & CFopsize;
                c = cat(c,cc);
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
            c = gen(CNIL,&cs);                  /* CMP reg,MSW          */
            if (I32 && sz == 6)
                c->Iflags |= CFopsize;          /* seg is only 16 bits  */
            genjmp(c,JNE,FLcode,(block *) ce);  /* JNE ce               */

            reg = findreglsw(retregs);
            cs.Irm = modregrm(3,7,reg);
            if (e2->Eoper == OPconst)
                cs.IEV2.Vint = e2->EV.Vlong;
            else if (e2->Eoper == OPrelconst)
            {   /* Turn off CFseg, on CFoff     */
                cs.Iflags ^= CFseg | CFoff;
                cs.IEVoffset2 = e2->EV.sp.Voffset;
            }
            else
                assert(0);
        }
        else
                assert(0);
        c = gen(c,&cs);                         /* CMP sucreg,LSW       */
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
            cl = getlvalue(&cs,e1,RMload);
            freenode(e1);
            cs.Iop = 0x39 ^ byte ^ reverse;
            code_newreg(&cs,reg);
            if (I64 && byte && reg >= 4)
                cs.Irex |= REX;                 // address byte registers
            c = gen(c,&cs);
            freenode(e2);
            break;
        }
      L5:
        cl = scodelem(e1,&retregs,0,TRUE);      /* compute left leaf    */
        if (sz <= REGSIZE)                      /* CMP reg,EA           */
        {
            reg = findreg(retregs & allregs);   // get reg that e1 is in
            unsigned opsize = cs.Iflags & CFopsize;
            c = cat(c,loadea(e2,&cs,0x3B ^ byte ^ reverse,reg,0,RMload | retregs,0));
            code_orflag(c,opsize);
        }
        else if (sz <= 2 * REGSIZE)
        {
            reg = findregmsw(retregs);   /* get reg that e1 is in */
            // CMP reg,EA
            c = loadea(e2,&cs,0x3B ^ reverse,reg,REGSIZE,RMload | retregs,0);
            if (I32 && sz == 6)
                c->Iflags |= CFopsize;          /* seg is only 16 bits  */
            genjmp(c,JNE,FLcode,(block *) ce);          /* JNE ce       */
            reg = findreglsw(retregs);
            if (e2->Eoper == OPind)
            {
                NEWREG(cs.Irm,reg);
                getlvalue_lsw(&cs);
                c = gen(c,&cs);
            }
            else
                c = cat(c,loadea(e2,&cs,0x3B ^ reverse,reg,0,RMload | retregs,0));
        }
        else
            assert(0);
        freenode(e2);
        break;
  }
  c = cat(c,ce);

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
            cg = allocreg(&resregs,&reg,TYint);
            cg = gen2(cg,0x0F90 + (jop & 0x0F),modregrmx(3,0,reg)); // SETcc reg
            if (I64 && reg >= 4)
                code_orrex(cg,REX);
            genregs(cg,0x0FB6,reg,reg);                 // MOVZX reg,reg
            if (I64 && sz == 8)
                code_orrex(cg,REX_W);
            if (I64 && reg >= 4)
                code_orrex(cg,REX);
            *pretregs &= ~mPSW;
            c = cat3(c,cg,fixresult(e,resregs,pretregs));
        }
        else
        {
            code *nop = CNIL;
            regm_t save = regcon.immed.mval;
            cg = allocreg(&retregs,&reg,TYint);
            regcon.immed.mval = save;
            if ((*pretregs & mPSW) == 0 &&
                (jop == JC || jop == JNC))
            {
                cg = cat(cg,getregs(retregs));
                cg = genregs(cg,0x19,reg,reg);              /* SBB reg,reg  */
                if (rex)
                    code_orrex(cg, rex);
                if (flag)
                    ;                                       // cdcond() will handle it
                else if (jop == JNC)
                {
                    if (I64)
                    {
                        cg = gen2(cg,0xFF,modregrmx(3,0,reg));      // INC reg
                        code_orrex(cg, rex);
                    }
                    else
                        gen1(cg,0x40 + reg);                 // INC reg
                }
                else
                {   gen2(cg,0xF7,modregrmx(3,3,reg));        /* NEG reg      */
                    code_orrex(cg, rex);
                }
            }
            else if (I64 && sz == 8)
            {
                assert(!flag);
                cg = movregconst(cg,reg,1,64|8);               // MOV reg,1
                nop = gennop(nop);
                cg = genjmp(cg,jop,FLcode,(block *) nop);   // Jtrue nop
                                                            // MOV reg,0
                movregconst(cg,reg,0,(*pretregs & mPSW) ? 64|8 : 64);
                regcon.immed.mval &= ~mask[reg];
            }
            else
            {
                assert(!flag);
                cg = movregconst(cg,reg,1,8);               // MOV reg,1
                nop = gennop(nop);
                cg = genjmp(cg,jop,FLcode,(block *) nop);   // Jtrue nop
                                                            // MOV reg,0
                movregconst(cg,reg,0,(*pretregs & mPSW) ? 8 : 0);
                regcon.immed.mval &= ~mask[reg];
            }
            *pretregs = retregs;
            c = cat3(c,cg,nop);
        }
  }
ret:
  return cat3(cl,cr,c);
}


/**********************************
 * Generate code for signed compare of longs.
 * Input:
 *      targ    block* or code*
 */

code *longcmp(elem *e,bool jcond,unsigned fltarg,code *targ)
{ regm_t retregs,rretregs;
  unsigned reg,rreg,op,jop;
  code *cl,*cr,*c,cs,*ce;
  code *cmsw,*clsw;
  elem *e1,*e2;
                                       /* <=  >   <   >= */
  static const unsigned char jopmsw[4] = {JL, JG, JL, JG };
  static const unsigned char joplsw[4] = {JBE, JA, JB, JAE };

  //printf("longcmp(e = %p)\n", e);
  cr = CNIL;
  e1 = e->E1;
  e2 = e->E2;
  op = e->Eoper;

  /* See if we should swap operands     */
  if (e1->Eoper == OPvar && e2->Eoper == OPvar && evalinregister(e2))
  {     e1 = e->E2;
        e2 = e->E1;
        op = swaprel(op);
  }

  cs.Iflags = 0;
  cs.Irex = 0;

  ce = gennop(CNIL);
  retregs = ALLREGS;

  switch (e2->Eoper)
  {
      default:
      L2:
        cl = scodelem(e1,&retregs,0,TRUE);      /* compute left leaf    */
        rretregs = ALLREGS & ~retregs;
        cr = scodelem(e2,&rretregs,retregs,TRUE);       /* get right leaf */
        /* Compare MSW, if they're equal then compare the LSW   */
        reg = findregmsw(retregs);
        rreg = findregmsw(rretregs);
        cmsw = genregs(CNIL,0x3B,reg,rreg);             /* CMP reg,rreg */

        reg = findreglsw(retregs);
        rreg = findreglsw(rretregs);
        clsw = genregs(CNIL,0x3B,reg,rreg);             /* CMP reg,rreg */
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
        {       cl = getlvalue(&cs,e1,0);
                freenode(e1);
                if (evalinregister(e2))
                {
                        retregs = idxregm(&cs);
                        if ((cs.Iflags & CFSEG) == CFes)
                                retregs |= mES;         /* take no chances */
                        rretregs = ALLREGS & ~retregs;
                        cr = scodelem(e2,&rretregs,retregs,TRUE);
                        rreg = findregmsw(rretregs);
                        cs.Iop = 0x39;
                        cs.Irm |= modregrm(0,rreg,0);
                        getlvalue_msw(&cs);
                        cmsw = gen(CNIL,&cs);   /* CMP EA+2,rreg        */
                        rreg = findreglsw(rretregs);
                        NEWREG(cs.Irm,rreg);
                }
                else
                {       cs.Irm |= modregrm(0,7,0);
                        getlvalue_msw(&cs);
                        cmsw = gen(CNIL,&cs);   /* CMP EA+2,const       */
                        cs.IEV2.Vint = e2->EV.Vlong;
                        freenode(e2);
                }
                getlvalue_lsw(&cs);
                clsw = gen(CNIL,&cs);           /* CMP EA,rreg/const    */
                break;
        }
        if (evalinregister(e2))
            goto L2;

        cl = scodelem(e1,&retregs,0,TRUE);      /* compute left leaf    */
        reg = findregmsw(retregs);              /* get reg that e1 is in */
        cs.Irm = modregrm(3,7,reg);

        cmsw = gen(CNIL,&cs);                   /* CMP reg,MSW          */
        reg = findreglsw(retregs);
        cs.Irm = modregrm(3,7,reg);
        cs.IEV2.Vint = e2->EV.Vlong;
        clsw = gen(CNIL,&cs);                   /* CMP sucreg,LSW       */
        freenode(e2);
        break;
      case OPvar:
        if (!e1->Ecount && e1->Eoper == OPs32_64)
        {   unsigned msreg;

            retregs = allregs;
            cl = scodelem(e1->E1,&retregs,0,TRUE);
            freenode(e1);
            reg = findreg(retregs);
            retregs = allregs & ~retregs;
            cr = allocreg(&retregs,&msreg,TYint);
            cr = genmovreg(cr,msreg,reg);                               // MOV msreg,reg
            cr = genc2(cr,0xC1,modregrm(3,7,msreg),REGSIZE * 8 - 1);    // SAR msreg,31
            cmsw = loadea(e2,&cs,0x3B,msreg,REGSIZE,mask[reg],0);
            clsw = loadea(e2,&cs,0x3B,reg,0,mask[reg],0);
            freenode(e2);
        }
        else
        {
            cl = scodelem(e1,&retregs,0,TRUE);  // compute left leaf
            reg = findregmsw(retregs);   // get reg that e1 is in
            cmsw = loadea(e2,&cs,0x3B,reg,REGSIZE,retregs,0);
            reg = findreglsw(retregs);
            clsw = loadea(e2,&cs,0x3B,reg,0,retregs,0);
            freenode(e2);
        }
        break;
  }

  jop = jopmsw[op - OPle];
  if (!(jcond & 1)) jop ^= (JL ^ JG);                   // toggle jump condition
  genjmp(cmsw,jop,fltarg,(block *) targ);               /* Jx targ      */
  genjmp(cmsw,jop ^ (JL ^ JG),FLcode,(block *) ce);     /* Jy nop       */

  jop = joplsw[op - OPle];
  if (!(jcond & 1)) jop ^= 1;                           // toggle jump condition
  genjmp(clsw,jop,fltarg,(block *) targ);               /* Jcond targ   */

  c = cse_flush(1);             // flush CSE's to memory
  freenode(e);
  return cat6(cl,cr,c,cmsw,clsw,ce);
}

/*****************************
 * Do conversions.
 * Depends on OPd_s32 and CLIBdbllng being in sequence.
 */

code *cdcnvt(elem *e, regm_t *pretregs)
{ regm_t retregs;
  code *c1,*c2;
  int i;
  static unsigned char clib[][2] =
  {     OPd_s32,        CLIBdbllng,
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
#if TARGET_SEGMENTED
        OPvp_fp,        CLIBvptrfptr,
        OPcvp_fp,       CLIBcvptrfptr,
#endif
  };

//printf("cdcnvt: *pretregs = %s\n", regm_str(*pretregs));
//elem_print(e);

  if (!*pretregs)
        return codelem(e->E1,pretregs,FALSE);
  if (config.inline8087)
  {     switch (e->Eoper)
        {
            case OPld_d:
            case OPd_ld:
                if (tycomplex(e->E1->Ety))
                {
            Lcomplex:
                    retregs = mST01 | (*pretregs & mPSW);
                    c1 = codelem(e->E1, &retregs, FALSE);
                    c2 = fixresult_complex87(e, retregs, pretregs);
                    return cat(c1, c2);
                }
                retregs = mST0 | (*pretregs & mPSW);
                c1 = codelem(e->E1, &retregs, FALSE);
                c2 = fixresult87(e, retregs, pretregs);
                return cat(c1, c2);

            case OPf_d:
            case OPd_f:
                if (tycomplex(e->E1->Ety))
                    goto Lcomplex;
                if (config.fpxmmregs && *pretregs & XMMREGS)
                    return xmmcnvt(e, pretregs);

                /* if won't do us much good to transfer back and        */
                /* forth between 8088 registers and 8087 registers      */
                if (OTcall(e->E1->Eoper) && !(*pretregs & allregs))
                {
                    retregs = regmask(e->E1->Ety, e->E1->E1->Ety);
                    if (retregs & (mXMM1 | mXMM0 |mST01 | mST0))       // if return in ST0
                    {
                        c1 = codelem(e->E1,pretregs,FALSE);
                        if (*pretregs & mST0)
                            note87(e, 0, 0);
                        return c1;
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
                    return xmmcnvt(e, pretregs);
                /* FALL-THROUGH */
            case OPs16_d:
            case OPu16_d:
            Lload87:
                return load87(e,0,pretregs,NULL,-1);
            case OPu32_d:
                if (I64 && config.fpxmmregs && *pretregs & XMMREGS)
                    return xmmcnvt(e,pretregs);
                else if (!I16)
                {
                    unsigned retregs = ALLREGS;
                    c1 = codelem(e->E1, &retregs, FALSE);
                    unsigned reg = findreg(retregs);
                    c1 = genfltreg(c1, 0x89, reg, 0);
                    regwithvalue(c1,ALLREGS,0,&reg,0);
                    genfltreg(c1, 0x89, reg, 4);

                    cat(c1, push87());
                    genfltreg(c1,0xDF,5,0);     // FILD m64int

                    retregs = mST0 /*| (*pretregs & mPSW)*/;
                    c2 = fixresult87(e, retregs, pretregs);
                    return cat(c1, c2);
                }
                break;
            case OPd_s64:
                if (!I64)
                    goto Lcnvt87;
                /* FALL-THROUGH */
            case OPd_s32:
                if (config.fpxmmregs)
                    return xmmcnvt(e,pretregs);
                /* FALL-THROUGH */
            case OPd_s16:
            case OPd_u16:
            Lcnvt87:
                return cnvt87(e,pretregs);
            case OPd_u32:               // use subroutine, not 8087
                if (I64 && config.fpxmmregs)
                    return xmmcnvt(e,pretregs);
                if (I32 || I64)
                    return cdd_u32(e,pretregs);
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
                retregs = mST0;
#else
                retregs = DOUBLEREGS;
#endif
                goto L1;

            case OPd_u64:
                if (I32 || I64)
                    return cdd_u64(e,pretregs);
                retregs = DOUBLEREGS;
                goto L1;
            case OPu64_d:
                if (*pretregs & mST0)
                {
                    retregs = I64 ? mAX : mAX|mDX;
                    c1 = codelem(e->E1,&retregs,FALSE);
                    c2 = callclib(e,CLIBu64_ldbl,pretregs,0);
                    return cat(c1,c2);
                }
                break;
            case OPld_u64:
                if (I32 || I64)
                    return cdd_u64(e,pretregs);
                retregs = mST0;
                c1 = codelem(e->E1,&retregs,FALSE);
                c2 = callclib(e,CLIBld_u64,pretregs,0);
                return cat(c1,c2);
        }
  }
  retregs = regmask(e->E1->Ety, TYnfunc);
L1:
  c1 = codelem(e->E1,&retregs,FALSE);
  for (i = 0; 1; i++)
  {     assert(i < arraysize(clib));
        if (clib[i][0] == e->Eoper)
        {   c2 = callclib(e,clib[i][1],pretregs,0);
            break;
        }
  }
  return cat(c1,c2);
}


/***************************
 * Convert short to long.
 * For OPs16_32, OPu16_32, OPnp_fp, OPu32_64, OPs32_64,
 * OPu64_128, OPs64_128
 */

code *cdshtlng(elem *e,regm_t *pretregs)
{ code *c,*ce,*c1,*c2,*c3,*c4;
  unsigned reg;
  regm_t retregs;

  //printf("cdshtlng(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
  int e1comsub = e->E1->Ecount;
  unsigned char op = e->Eoper;
  if ((*pretregs & (ALLREGS | mBP)) == 0)       // if don't need result in regs
    c = codelem(e->E1,pretregs,FALSE);  /* then conversion isn't necessary */

  else if (
#if TARGET_SEGMENTED
           op == OPnp_fp ||
#endif
           (I16 && op == OPu16_32) ||
           (I32 && op == OPu32_64)
          )
  {
        /* Result goes into a register pair.
         * Zero extend by putting a zero into most significant reg.
         */

        retregs = *pretregs & mLSW;
        assert(retregs);
        tym_t tym1 = tybasic(e->E1->Ety);
        c = codelem(e->E1,&retregs,FALSE);

        regm_t regm = *pretregs & (mMSW & ALLREGS);
        if (regm == 0)                  /* *pretregs could be mES       */
            regm = mMSW & ALLREGS;
        ce = allocreg(&regm,&reg,TYint);
        if (e1comsub)
            ce = cat(ce,getregs(retregs));
#if TARGET_SEGMENTED
        if (op == OPnp_fp)
        {   int segreg;

            /* BUG: what about pointers to functions?   */
            switch (tym1)
            {
                case TYnptr:    segreg = SEG_DS;        break;
                case TYcptr:    segreg = SEG_CS;        break;
                case TYsptr:    segreg = SEG_SS;        break;
                default:        assert(0);
            }
            ce = gen2(ce,0x8C,modregrm(3,segreg,reg));  /* MOV reg,segreg */
        }
        else
#endif
            ce = movregconst(ce,reg,0,0);               /* 0 extend     */

        c = cat3(c,ce,fixresult(e,retregs | regm,pretregs));
  }
  else if (I64 && op == OPu32_64)
  {
        elem *e1 = e->E1;
        retregs = *pretregs;
        if (e1->Eoper == OPvar || (e1->Eoper == OPind && !e1->Ecount))
        {   code cs;

            c1 = allocreg(&retregs,&reg,TYint);
            c2 = NULL;
            c3 = loadea(e1,&cs,0x8B,reg,0,retregs,retregs);        //  MOV Ereg,EA
            freenode(e1);
        }
        else
        {
            *pretregs &= ~mPSW;                 // flags are set by eval of e1
            c1 = codelem(e1,&retregs,FALSE);
            /* Determine if high 32 bits are already 0
             */
            if (e1->Eoper == OPu16_32 && !e1->Ecount)
            {
                c2 = NULL;
                c3 = NULL;
            }
            else
            {
                // Zero high 32 bits
                c2 = getregs(retregs);
                reg = findreg(retregs);
                c3 = genregs(NULL,0x89,reg,reg);    // MOV Ereg,Ereg
            }
        }
        c4 = fixresult(e,retregs,pretregs);
        c = cat4(c1,c2,c3,c4);
  }
  else if (I64 && op == OPs32_64 && OTrel(e->E1->Eoper) && !e->E1->Ecount)
  {
        /* Due to how e1 is calculated, the high 32 bits of the register
         * are already 0.
         */
        retregs = *pretregs;
        c1 = codelem(e->E1,&retregs,FALSE);
        c2 = fixresult(e,retregs,pretregs);
        c = cat(c1,c2);
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
        c1 = allocreg(&retregs,&reg,TYint);
        c2 = movregconst(NULL,reg,0,0);                         //  XOR reg,reg
        c3 = loadea(e11,&cs,0x8A,reg,0,retregs,retregs);        //  MOV regL,EA
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
        c1 = allocreg(&retregs,&reg,TYint);
        opcode = (op == OPu16_32) ? 0x0FB7 : 0x0FBF; /* MOVZX/MOVSX reg,EA */
        if (op == OPs32_64)
        {
            assert(I64);
            // MOVSXD reg,e1
            c2 = loadea(e1,&cs,0x63,reg,0,0,retregs);
            code_orrex(c2, REX_W);
        }
        else
            c2 = loadea(e1,&cs,opcode,reg,0,0,retregs);
        c3 = CNIL;
        freenode(e1);
    }
    else
    {
    L2:
        retregs = *pretregs;
        if (op == OPs32_64)
            retregs = mAX | (*pretregs & mPSW);
        *pretregs &= ~mPSW;             /* flags are already set        */
        c1 = codelem(e1,&retregs,FALSE);
        c2 = getregs(retregs);
        if (op == OPu16_32 && c1)
        {
            code *cx = code_last(c1);
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
            c2 = gen1(c2,0x98);         /* CWDE                         */
        else if (op == OPs32_64 && retregs == mAX)
        {   c2 = gen1(c2,0x98);         /* CDQE                         */
            code_orrex(c2, REX_W);
        }
        else
        {
            reg = findreg(retregs);
            if (config.flags4 & CFG4speed && op == OPu16_32)
            {   // AND reg,0xFFFF
                c3 = genc2(NULL,0x81,modregrmx(3,4,reg),0xFFFFu);
            }
            else
            {
                unsigned iop = (op == OPu16_32) ? 0x0FB7 : 0x0FBF; /* MOVZX/MOVSX reg,reg */
                c3 = genregs(CNIL,iop,reg,reg);
            }
            c2 = cat(c2,c3);
        }
     L1:
        c3 = e1comsub ? getregs(retregs) : CNIL;
    }
    c4 = fixresult(e,retregs,pretregs);
    c = cat4(c1,c2,c3,c4);
  }
  else if (*pretregs & mPSW || config.target_cpu < TARGET_80286)
  {
    // OPs16_32, OPs32_64
    // CWD doesn't affect flags, so we can depend on the integer
    // math to provide the flags.
    retregs = mAX | mPSW;               // want integer result in AX
    *pretregs &= ~mPSW;                 // flags are already set
    c1 = codelem(e->E1,&retregs,FALSE);
    c2 = getregs(mDX);                  // sign extend into DX
    c2 = gen1(c2,0x99);                 // CWD/CDQ
    c3 = e1comsub ? getregs(retregs) : CNIL;
    c4 = fixresult(e,mDX | retregs,pretregs);
    c = cat4(c1,c2,c3,c4);
  }
  else
  {
    // OPs16_32, OPs32_64
    unsigned msreg,lsreg;

    retregs = *pretregs & mLSW;
    assert(retregs);
    c1 = codelem(e->E1,&retregs,FALSE);
    retregs |= *pretregs & mMSW;
    c2 = allocreg(&retregs,&reg,e->Ety);
    msreg = findregmsw(retregs);
    lsreg = findreglsw(retregs);
    c3 = genmovreg(NULL,msreg,lsreg);                           // MOV msreg,lsreg
    assert(config.target_cpu >= TARGET_80286);                  // 8088 can't handle SAR reg,imm8
    c3 = genc2(c3,0xC1,modregrm(3,7,msreg),REGSIZE * 8 - 1);    // SAR msreg,31
    c4 = fixresult(e,retregs,pretregs);
    c = cat4(c1,c2,c3,c4);
  }
  return c;
}


/***************************
 * Convert byte to int.
 * For OPu8_16 and OPs8_16.
 */

code *cdbyteint(elem *e,regm_t *pretregs)
{   code *c,*c0,*c1,*c2,*c3,*c4;
    regm_t retregs;
    unsigned reg;
    char op;
    char size;
    elem *e1;


    if ((*pretregs & (ALLREGS | mBP)) == 0)     // if don't need result in regs
        return codelem(e->E1,pretregs,FALSE); /* then conversion isn't necessary */

    //printf("cdbyteint(e = %p, *pretregs = %s\n", e, regm_str(*pretregs));
    op = e->Eoper;
    e1 = e->E1;
    c0 = NULL;
    if (e1->Eoper == OPcomma)
        c0 = docommas(&e1);
    if (!I16)
    {
        if (e1->Eoper == OPvar || (e1->Eoper == OPind && !e1->Ecount))
        {   code cs;
            unsigned opcode;

            retregs = *pretregs;
            c1 = allocreg(&retregs,&reg,TYint);
            if (config.flags4 & CFG4speed &&
                op == OPu8_16 && mask[reg] & BYTEREGS &&
                config.target_cpu < TARGET_PentiumPro)
            {
                c2 = movregconst(NULL,reg,0,0);                 //  XOR reg,reg
                c3 = loadea(e1,&cs,0x8A,reg,0,retregs,retregs); //  MOV regL,EA
            }
            else
            {
                opcode = (op == OPu8_16) ? 0x0FB6 : 0x0FBE; // MOVZX/MOVSX reg,EA
                c2 = loadea(e1,&cs,opcode,reg,0,0,retregs);
                c3 = CNIL;
            }
            freenode(e1);
            goto L2;
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
        if (op == OPu8_16)              /* if unsigned conversion       */
        {
            retregs = *pretregs & BYTEREGS;
            if (retregs == 0)
                retregs = BYTEREGS;
        }
        else
        {
            /* CBW doesn't affect flags, so we can depend on the integer */
            /* math to provide the flags.                               */
            retregs = mAX | (*pretregs & mPSW); /* want integer result in AX */
        }
    }

    c3 = CNIL;
    c1 = codelem(e1,&retregs,FALSE);
    reg = findreg(retregs);
    if (!c1)
        goto L1;

    for (c = c1; c->next; c = c->next)
        ;                               /* find previous instruction    */

    /* If previous instruction is an AND bytereg,value  */
    if (c->Iop == 0x80 && c->Irm == modregrm(3,4,reg & 7) &&
        (op == OPu8_16 || (c->IEV2.Vuns & 0x80) == 0))
    {
        if (*pretregs & mPSW)
            c->Iflags |= CFpsw;
        c->Iop |= 1;                    /* convert to word operation    */
        c->IEV2.Vuns &= 0xFF;           /* dump any high order bits     */
        *pretregs &= ~mPSW;             /* flags already set            */
    }
    else
    {
     L1:
        if (!I16)
        {
            if (op == OPs8_16 && reg == AX && size == 2)
            {   c3 = gen1(c3,0x98);             /* CBW                  */
                c3->Iflags |= CFopsize;         /* don't do a CWDE      */
            }
            else
            {
                /* We could do better by not forcing the src and dst    */
                /* registers to be the same.                            */

                if (config.flags4 & CFG4speed && op == OPu8_16)
                {   // AND reg,0xFF
                    c3 = genc2(c3,0x81,modregrmx(3,4,reg),0xFF);
                }
                else
                {
                    unsigned iop = (op == OPu8_16) ? 0x0FB6 : 0x0FBE; // MOVZX/MOVSX reg,reg
                    c3 = genregs(c3,iop,reg,reg);
                    if (I64 && reg >= 4)
                        code_orrex(c3, REX);
                }
            }
        }
        else
        {
            if (op == OPu8_16)
                c3 = genregs(c3,0x30,reg+4,reg+4);      // XOR regH,regH
            else
            {
                c3 = gen1(c3,0x98);             /* CBW                  */
                *pretregs &= ~mPSW;             /* flags already set    */
            }
        }
    }
    c2 = getregs(retregs);
L2:
    c4 = fixresult(e,retregs,pretregs);
    return cat6(c0,c1,c2,c3,c4,NULL);
}


/***************************
 * Convert long to short (OP32_16).
 * Get offset of far pointer (OPoffset).
 * Convert int to byte (OP16_8).
 * Convert long long to long (OP64_32).
 * OP128_64
 */

code *cdlngsht(elem *e,regm_t *pretregs)
{ regm_t retregs;
  code *c;

#ifdef DEBUG
    switch (e->Eoper)
    {
        case OP32_16:
#if TARGET_SEGMENTED
        case OPoffset:
#endif
        case OP16_8:
        case OP64_32:
        case OP128_64:
            break;

        default:
            assert(0);
    }
#endif

  if (e->Eoper == OP16_8)
  {     retregs = *pretregs ? BYTEREGS : 0;
        c = codelem(e->E1,&retregs,FALSE);
  }
  else
  {     if (e->E1->Eoper == OPrelconst)
            c = offsetinreg(e->E1,&retregs);
        else
        {   retregs = *pretregs ? ALLREGS : 0;
            c = codelem(e->E1,&retregs,FALSE);
#if TARGET_SEGMENTED
            bool isOff = e->Eoper == OPoffset;
#else
            bool isOff = false;
#endif
            if (I16 ||
                I32 && (isOff || e->Eoper == OP64_32) ||
                I64 && (isOff || e->Eoper == OP128_64))
                retregs &= mLSW;                /* want LSW only        */
        }
  }

  /* We "destroy" a reg by assigning it the result of a new e, even     */
  /* though the values are the same. Weakness of our CSE strategy that  */
  /* a register can only hold the contents of one elem at a time.       */
  if (e->Ecount)
        c = cat(c,getregs(retregs));
  else
        useregs(retregs);

#ifdef DEBUG
  if (!(!*pretregs || retregs))
        WROP(e->Eoper),
        printf(" *pretregs = %s, retregs = %s, e = %p\n",regm_str(*pretregs),regm_str(retregs),e);
#endif
  assert(!*pretregs || retregs);
  return cat(c,fixresult(e,retregs,pretregs));  /* lsw only             */
}

/**********************************************
 * Get top 32 bits of 64 bit value (I32)
 * or top 16 bits of 32 bit value (I16)
 * or top 64 bits of 128 bit value (I64).
 * OPmsw
 */

code *cdmsw(elem *e,regm_t *pretregs)
{   regm_t retregs;
    code *c;

    //printf("cdmsw(e->Ecount = %d)\n", e->Ecount);
    assert(e->Eoper == OPmsw);

    retregs = *pretregs ? ALLREGS : 0;
    c = codelem(e->E1,&retregs,FALSE);
    retregs &= mMSW;                    // want MSW only

    // We "destroy" a reg by assigning it the result of a new e, even
    // though the values are the same. Weakness of our CSE strategy that
    // a register can only hold the contents of one elem at a time.
    if (e->Ecount)
        c = cat(c,getregs(retregs));
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
    return cat(c,fixresult(e,retregs,pretregs));        // msw only
}



/******************************
 * Handle operators OPinp and OPoutp.
 */

code *cdport(elem *e,regm_t *pretregs)
{   regm_t retregs;
    code *c1,*c2,*c3;
    unsigned char op,port;
    unsigned sz;
    elem *e1;

    //printf("cdport\n");
    op = 0xE4;                          /* root of all IN/OUT opcodes   */
    e1 = e->E1;

    // See if we can use immediate mode of IN/OUT opcodes
    if (e1->Eoper == OPconst && e1->EV.Vuns <= 255 &&
        (!evalinregister(e1) || regcon.mvar & mDX))
    {   port = e1->EV.Vuns;
        freenode(e1);
        c1 = CNIL;
    }
    else
    {   retregs = mDX;                  /* port number is always DX     */
        c1 = codelem(e1,&retregs,FALSE);
        op |= 0x08;                     /* DX version of opcode         */
        port = 0;                       // not logically needed, but
                                        // quiets "uninitialized var" complaints
    }

    if (e->Eoper == OPoutp)
    {
        sz = tysize(e->E2->Ety);
        retregs = mAX;                  /* byte/word to output is in AL/AX */
        c2 = scodelem(e->E2,&retregs,((op & 0x08) ? mDX : (regm_t) 0),TRUE);
        op |= 0x02;                     /* OUT opcode                   */
    }
    else // OPinp
    {   c2 = getregs(mAX);
        sz = tysize(e->Ety);
    }

    if (sz != 1)
        op |= 1;                        /* word operation               */
    c3 = genc2(CNIL,op,0,port);         /* IN/OUT AL/AX,DX/port         */
    if (op & 1 && sz != REGSIZE)        // if need size override
        c3->Iflags |= CFopsize;
    retregs = mAX;
    return cat4(c1,c2,c3,fixresult(e,retregs,pretregs));
}

/************************
 * Generate code for an asm elem.
 */

code *cdasm(elem *e,regm_t *pretregs)
{   code *c;

#if 1
    /* Assume only regs normally destroyed by a function are destroyed  */
    c = getregs((ALLREGS | mES) & ~fregsaved);
#else
    /* Assume all regs are destroyed    */
    c = getregs(ALLREGS | mES);
#endif
    c = genasm(c,e->EV.ss.Vstring,e->EV.ss.Vstrlen);
    return cat(c,fixresult(e,(I16 ? mDX | mAX : mAX),pretregs));
}

#if TARGET_SEGMENTED
/************************
 * Generate code for OPnp_f16p and OPf16p_np.
 */

code *cdfar16( elem *e, regm_t *pretregs)
{   code *c;
    code *c1;
    code *c3;
    code *cnop;
    code cs;
    unsigned reg;

    assert(I32);
    c = codelem(e->E1,pretregs,FALSE);
    reg = findreg(*pretregs);
    c = cat(c,getregs(*pretregs));      /* we will destroy the regs     */

    cs.Iop = 0xC1;
    cs.Irm = modregrm(3,0,reg);
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL2 = FLconst;
    cs.IEV2.Vuns = 16;

    c3 = gen(CNIL,&cs);                 /* ROL ereg,16                  */
    cs.Irm |= modregrm(0,1,0);
    c1 = gen(CNIL,&cs);                 /* ROR ereg,16                  */
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
        int jop;
        int byte;
        unsigned rx;
        regm_t retregs;

        retregs = BYTEREGS & ~*pretregs;
        c = cat(c,allocreg(&retregs,&rx,TYint));
        cnop = gennop(CNIL);
        jop = JCXZ;
        if (reg != CX)
        {
            c = gentstreg(c,reg);
            jop = JE;
        }
        c = genjmp(c,jop,FLcode,(block *)cnop);         /* Jop L1       */
        NEWREG(cs.Irm,4);
        gen(c1,&cs);                                    /* SHL reg,3    */
        genregs(c1,0x8C,2,rx);                          /* MOV rx,SS    */
        byte = (mask[reg] & BYTEREGS) == 0;
        genc2(c1,0x80 | byte,modregrm(3,4,rx),3);       /* AND rl,3     */
        genc2(c1,0x80,modregrm(3,1,rx),4);              /* OR  rl,4     */
        genregs(c1,0x0A | byte,reg,rx);                 /* OR  regl,rl  */
    }
    else /* OPf16p_np */
    {
        /*      ROR ereg,16
                SHR reg,3
                ROL ereg,16
         */

        cs.Irm |= modregrm(0,5,0);
        gen(c1,&cs);                                    /* SHR reg,3    */
        cnop = NULL;
    }
    return cat4(c,c1,c3,cnop);
}
#endif

/*************************
 * Generate code for OPbtst
 */

code *cdbtst(elem *e, regm_t *pretregs)
{
    elem *e1;
    elem *e2;
    code *c;
    code *c2;
    code cs;
    regm_t idxregs;
    regm_t retregs;
    unsigned reg;
    unsigned char word;
    tym_t ty1;
    int op;
    int mode;

    //printf("cdbtst(e = %p, *pretregs = %s\n", e, regm_str(*pretregs));

    op = 0xA3;                          // BT EA,value
    mode = 4;

    e1 = e->E1;
    e2 = e->E2;
    cs.Iflags = 0;

    if (*pretregs == 0)                   // if don't want result
    {   c = codelem(e1,pretregs,FALSE);   // eval left leaf
        *pretregs = 0;                    // in case they got set
        return cat(c,codelem(e2,pretregs,FALSE));
    }

    if ((e1->Eoper == OPind && !e1->Ecount) || e1->Eoper == OPvar)
    {
        c = getlvalue(&cs, e1, RMload);     // get addressing mode
        idxregs = idxregm(&cs);             // mask if index regs used
    }
    else
    {
        retregs = tysize[tybasic(e1->Ety)] == 1 ? BYTEREGS : allregs;
        c = codelem(e1, &retregs, FALSE);
        reg = findreg(retregs);
        cs.Irm = modregrm(3,0,reg & 7);
        cs.Iflags = 0;
        cs.Irex = 0;
        if (reg & 8)
            cs.Irex |= REX_B;
        idxregs = retregs;
    }

    ty1 = tybasic(e1->Ety);
    word = (!I16 && tysize[ty1] == SHORTSIZE) ? CFopsize : 0;

//    if (e2->Eoper == OPconst && e2->EV.Vuns < 0x100)  // should do this instead?
    if (e2->Eoper == OPconst)
    {
        cs.Iop = 0x0FBA;                         // BT rm,imm8
        cs.Irm |= modregrm(0,mode,0);
        cs.Iflags |= CFpsw | word;
        cs.IFL2 = FLconst;
        if (tysize[ty1] == SHORTSIZE)
        {
            cs.IEV2.Vint = e2->EV.Vint & 15;
        }
        else if (tysize[ty1] == 4)
        {
            cs.IEV2.Vint = e2->EV.Vint & 31;
        }
        else
        {
            cs.IEV2.Vint = e2->EV.Vint & 63;
            if (I64)
                cs.Irex |= REX_W;
        }
        c2 = gen(CNIL,&cs);
    }
    else
    {
        retregs = ALLREGS & ~idxregs;
        c2 = scodelem(e2,&retregs,idxregs,TRUE);
        reg = findreg(retregs);

        cs.Iop = 0x0F00 | op;                     // BT rm,reg
        code_newreg(&cs,reg);
        cs.Iflags |= CFpsw | word;
        if (I64 && tysize[ty1] == 8)
            cs.Irex |= REX_W;
        c2 = gen(c2,&cs);
    }

    if ((retregs = (*pretregs & (ALLREGS | mBP))) != 0) // if return result in register
    {
        code *nop = CNIL;
        regm_t save = regcon.immed.mval;
        code *cg = allocreg(&retregs,&reg,TYint);
        regcon.immed.mval = save;
        if ((*pretregs & mPSW) == 0)
        {
            cg = cat(cg,getregs(retregs));
            cg = genregs(cg,0x19,reg,reg);              // SBB reg,reg
            cg = gen2(cg,0xF7,modregrmx(3,3,reg));      // NEG reg
        }
        else
        {
            cg = movregconst(cg,reg,1,8);               // MOV reg,1
            nop = gennop(nop);
            cg = genjmp(cg,JC,FLcode,(block *) nop);    // Jtrue nop
                                                        // MOV reg,0
            movregconst(cg,reg,0,8);
            regcon.immed.mval &= ~mask[reg];
        }
        *pretregs = retregs;
        c2 = cat3(c2,cg,nop);
    }

    return cat(c,c2);
}

/*************************
 * Generate code for OPbt, OPbtc, OPbtr, OPbts
 */

code *cdbt(elem *e, regm_t *pretregs)
{
    elem *e1;
    elem *e2;
    code *c;
    code *c2;
    code cs;
    regm_t idxregs;
    regm_t retregs;
    unsigned reg;
    unsigned char word;
    tym_t ty1;
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

    e1 = e->E1;
    e2 = e->E2;
    cs.Iflags = 0;
    c = getlvalue(&cs, e, RMload);      // get addressing mode
    if (e->Eoper == OPbt && *pretregs == 0)
        return cat(c, codelem(e2,pretregs,FALSE));

    ty1 = tybasic(e1->Ety);
    word = (!I16 && tysize[ty1] == SHORTSIZE) ? CFopsize : 0;
    idxregs = idxregm(&cs);         // mask if index regs used

//    if (e2->Eoper == OPconst && e2->EV.Vuns < 0x100)  // should do this instead?
    if (e2->Eoper == OPconst)
    {
        cs.Iop = 0x0FBA;                         // BT rm,imm8
        cs.Irm |= modregrm(0,mode,0);
        cs.Iflags |= CFpsw | word;
        cs.IFL2 = FLconst;
        if (tysize[ty1] == SHORTSIZE)
        {
            cs.IEVoffset1 += (e2->EV.Vuns & ~15) >> 3;
            cs.IEV2.Vint = e2->EV.Vint & 15;
        }
        else if (tysize[ty1] == 4)
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
        c2 = gen(CNIL,&cs);
    }
    else
    {
        retregs = ALLREGS & ~idxregs;
        c2 = scodelem(e2,&retregs,idxregs,TRUE);
        reg = findreg(retregs);

        cs.Iop = 0x0F00 | op;                     // BT rm,reg
        code_newreg(&cs,reg);
        cs.Iflags |= CFpsw | word;
        c2 = gen(c2,&cs);
    }

    if ((retregs = (*pretregs & (ALLREGS | mBP))) != 0) // if return result in register
    {
        code *nop = CNIL;
        regm_t save = regcon.immed.mval;
        code *cg = allocreg(&retregs,&reg,TYint);
        regcon.immed.mval = save;
        if ((*pretregs & mPSW) == 0)
        {
            cg = cat(cg,getregs(retregs));
            cg = genregs(cg,0x19,reg,reg);              // SBB reg,reg
            cg = gen2(cg,0xF7,modregrmx(3,3,reg));      // NEG reg
        }
        else
        {
            cg = movregconst(cg,reg,1,8);               // MOV reg,1
            nop = gennop(nop);
            cg = genjmp(cg,JC,FLcode,(block *) nop);    // Jtrue nop
                                                        // MOV reg,0
            movregconst(cg,reg,0,8);
            regcon.immed.mval &= ~mask[reg];
        }
        *pretregs = retregs;
        c2 = cat3(c2,cg,nop);
    }

    return cat(c,c2);
}

/*************************************
 * Generate code for OPbsf and OPbsr.
 */

code *cdbscan(elem *e, regm_t *pretregs)
{
    regm_t retregs;
    unsigned reg;
    int sz;
    tym_t tyml;
    code *cl,*cg;
    code cs;

    //printf("cdbscan()\n");
    //elem_print(e);
    if (*pretregs == 0)
        return codelem(e->E1,pretregs,FALSE);
    tyml = tybasic(e->E1->Ety);
    sz = tysize[tyml];
    assert(sz == 2 || sz == 4 || sz == 8);

    if ((e->E1->Eoper == OPind && !e->E1->Ecount) || e->E1->Eoper == OPvar)
    {
        cl = getlvalue(&cs, e->E1, RMload);     // get addressing mode
    }
    else
    {
        retregs = allregs;
        cl = codelem(e->E1, &retregs, FALSE);
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
    cg = allocreg(&retregs, &reg, e->Ety);

    cs.Iop = (e->Eoper == OPbsf) ? 0x0FBC : 0x0FBD;        // BSF/BSR reg,EA
    code_newreg(&cs, reg);
    if (!I16 && sz == SHORTSIZE)
        cs.Iflags |= CFopsize;
    cg = gen(cg,&cs);
    if (sz == 8)
        code_orrex(cg, REX_W);

    return cat3(cl,cg,fixresult(e,retregs,pretregs));
}

/************************
 * OPpopcnt operator
 */

code *cdpopcnt(elem *e,regm_t *pretregs)
{
    code *cl,*cg;
    code cs;

    //printf("cdpopcnt()\n");
    //elem_print(e);
    assert(!I16);
    if (*pretregs == 0)
        return codelem(e->E1,pretregs,FALSE);

    tym_t tyml = tybasic(e->E1->Ety);

    int sz = tysize[tyml];
    assert(sz == 2 || sz == 4 || (sz == 8 && I64));     // no byte op

    if ((e->E1->Eoper == OPind && !e->E1->Ecount) || e->E1->Eoper == OPvar)
    {
        cl = getlvalue(&cs, e->E1, RMload);     // get addressing mode
    }
    else
    {
        regm_t retregs = allregs;
        cl = codelem(e->E1, &retregs, FALSE);
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
    cg = allocreg(&retregs, &reg, e->Ety);

    cs.Iop = POPCNT;            // POPCNT reg,EA
    code_newreg(&cs, reg);
    if (sz == SHORTSIZE)
        cs.Iflags |= CFopsize;
    if (*pretregs & mPSW)
        cs.Iflags |= CFpsw;
    cg = gen(cg,&cs);
    if (sz == 8)
        code_orrex(cg, REX_W);
    *pretregs &= mBP | ALLREGS;             // flags already set

    return cat3(cl,cg,fixresult(e,retregs,pretregs));
}


/*******************************************
 * Generate code for OPpair, OPrpair.
 */

code *cdpair(elem *e, regm_t *pretregs)
{
    regm_t retregs;
    regm_t regs1;
    regm_t regs2;
    code *cg;
    code *c1;
    code *c2;

    if (*pretregs == 0)                         // if don't want result
    {   c1 = codelem(e->E1,pretregs,FALSE);     // eval left leaf
        *pretregs = 0;                          // in case they got set
        return cat(c1,codelem(e->E2,pretregs,FALSE));
    }

    //printf("\ncdpair(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    //printf("Ecount = %d\n", e->Ecount);
    retregs = *pretregs & allregs;
    if  (!retregs)
        retregs = allregs;
    regs1 = retregs & (mLSW | mBP);
    regs2 = retregs & mMSW;
    if (e->Eoper == OPrpair)
    {
        regs1 = regs2;
        regs2 = retregs & (mLSW | mBP);
    }
    //printf("1: regs1 = %s, regs2 = %s\n", regm_str(regs1), regm_str(regs2));
    c1 = codelem(e->E1, &regs1, FALSE);
    c2 = scodelem(e->E2, &regs2, regs1, FALSE);

    cg = NULL;
    if (e->E1->Ecount)
        cg = getregs(regs1);
    if (e->E2->Ecount)
        cg = cat(cg, getregs(regs2));

    //printf("regs1 = %s, regs2 = %s\n", regm_str(regs1), regm_str(regs2));
    return cat4(c1,c2,cg,fixresult(e,regs1 | regs2,pretregs));
}

#endif // !SPP
