// Copyright (C) 2011-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * or /dm/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <time.h>
#include        "cc.h"
#include        "oper.h"
#include        "el.h"
#include        "code.h"
#include        "global.h"
#include        "type.h"
#if SCPP
#include        "exh.h"
#endif

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/*******************************************
 * Move constant value into xmm register xreg.
 */

code *movxmmconst(unsigned xreg, unsigned sz, targ_size_t value, regm_t flags)
{
    /* Generate:
     *    MOV reg,value
     *    MOV floatreg,reg
     *    MOV xreg,floatreg
     * Not so efficient. We should at least do a PXOR for 0.
     */
    assert(mask[xreg] & XMMREGS);
    unsigned r;
    code *c = regwithvalue(CNIL,ALLREGS,value,&r,(sz == 8) ? 64 : 0);
    c = genfltreg(c,0x89,r,0);            // MOV floatreg,r
    if (sz == 8)
        code_orrex(c, REX_W);
    assert(sz == 4 || sz == 8);             // float or double
    unsigned op = (sz == 4) ? 0xF30F10 : 0xF20F10;
    c = genfltreg(c,op,xreg - XMM0,0);     // MOVSS/MOVSD xreg,floatreg
}

/***********************************************
 * Do simple orthogonal operators for XMM registers.
 */

code *orthxmm(elem *e, regm_t *pretregs)
{   elem *e1 = e->E1;
    elem *e2 = e->E2;
    tym_t ty1 = tybasic(e1->Ety);
    unsigned sz1 = tysize[ty1];
    assert(sz1 == 4 || sz1 == 8);       // float or double
    regm_t retregs = *pretregs & XMMREGS;
    code *c = codelem(e1,&retregs,FALSE); // eval left leaf
    unsigned reg = findreg(retregs);
    regm_t rretregs = XMMREGS & ~retregs;
    code *cr = scodelem(e2, &rretregs, retregs, TRUE);  // eval right leaf
    unsigned rreg = findreg(rretregs);
    code *cg = getregs(retregs);
    unsigned op;
    switch (e->Eoper)
    {
        case OPadd:
            op = 0xF20F58;                      // ADDSD
            if (sz1 == 4)                       // float
                op = 0xF30F58;                  // ADDSS
            break;

        case OPmin:
            op = 0xF20F5C;                      // SUBSD
            if (sz1 == 4)                       // float
                op = 0xF30F5C;                  // SUBSS
            break;

        case OPmul:
            op = 0xF20F59;                      // MULSD
            if (sz1 == 4)                       // float
                op = 0xF30F59;                  // MULSS
            break;

        case OPdiv:
            op = 0xF20F5E;                      // DIVSD
            if (sz1 == 4)                       // float
                op = 0xF30F5E;                  // DIVSS
            break;

        default:
            assert(0);
    }
    code *co = gen2(CNIL,op,modregxrmx(3,reg-XMM0,rreg-XMM0));
    co = cat(co,fixresult(e,retregs,pretregs));
    return cat4(c,cr,cg,co);
}


/************************
 * Generate code for an assignment using XMM registers.
 */

code *xmmeq(elem *e,regm_t *pretregs)
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

    //printf("xmmeq(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    elem *e1 = e->E1;
    elem *e2 = e->E2;
    int e2oper = e2->Eoper;
    tym_t tyml = tybasic(e1->Ety);              /* type of lvalue               */
    regm_t retregs = *pretregs;

    unsigned sz = tysize[tyml];           // # of bytes to transfer
    assert(sz == 4 || sz == 8);         // float or double size

    if (!(retregs & XMMREGS))
        retregs = XMMREGS;              // pick any XMM reg

    cs.Iop = 0xF20F11;                  // MOVSD xmm_m64,xmm
    if (sz == 4)
        cs.Iop = 0xF30F11;              // MOVSS xmm_m32,xmm
    regvar = FALSE;
    varregm = 0;
    if (config.flags4 & CFG4optimized)
    {
        // Be careful of cases like (x = x+x+x). We cannot evaluate in
        // x if x is in a register.
        if (isregvar(e1,&varregm,&varreg) &&    // if lvalue is register variable
            doinreg(e1->EV.sp.Vsym,e2)          // and we can compute directly into it
           )
        {   regvar = TRUE;
            retregs = varregm;
            reg = varreg;       /* evaluate directly in target register */
        }
    }
    if (*pretregs & mPSW && !EOP(e1))     // if evaluating e1 couldn't change flags
    {   // Be careful that this lines up with jmpopcode()
        retregs |= mPSW;
        *pretregs &= ~mPSW;
    }
    cr = scodelem(e2,&retregs,0,TRUE);    // get rvalue

    // Look for special case of (*p++ = ...), where p is a register variable
    if (e1->Eoper == OPind &&
        ((e11 = e1->E1)->Eoper == OPpostinc || e11->Eoper == OPpostdec) &&
        e11->E1->Eoper == OPvar &&
        e11->E1->EV.sp.Vsym->Sfl == FLreg
       )
    {
        postinc = e11->E2->EV.Vint;
        if (e11->Eoper == OPpostdec)
            postinc = -postinc;
        cl = getlvalue(&cs,e11,RMstore | retregs);
        freenode(e11->E2);
    }
    else
    {   postinc = 0;
        cl = getlvalue(&cs,e1,RMstore | retregs);       // get lvalue (cl == CNIL if regvar)
    }

    c = getregs_imm(varregm);

    reg = findreg(retregs & XMMREGS);
    cs.Irm |= modregrm(0,(reg - XMM0) & 7,0);
    if ((reg - XMM0) & 8)
        cs.Irex |= REX_R;

    // Do not generate mov from register onto itself
    if (!(regvar && reg == XMM0 + ((cs.Irm & 7) | (cs.Irex & REX_B ? 8 : 0))))
        c = gen(c,&cs);         // MOV EA+offset,reg

    if (e1->Ecount ||                     // if lvalue is a CSE or
        regvar)                           // rvalue can't be a CSE
    {
        c = cat(c,getregs_imm(retregs));        // necessary if both lvalue and
                                        //  rvalue are CSEs (since a reg
                                        //  can hold only one e at a time)
        cssave(e1,retregs,EOP(e1));     // if lvalue is a CSE
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

/********************************
 * Generate code for += -= *= /=
 */

code *xmmopass(elem *e,regm_t *pretregs)
{   elem *e1 = e->E1;
    elem *e2 = e->E2;
    tym_t ty1 = tybasic(e1->Ety);
    unsigned sz1 = tysize[ty1];
    assert(sz1 == 4 || sz1 == 8);       // float or double
    regm_t rretregs = XMMREGS & ~*pretregs;
    if (!rretregs)
        rretregs = XMMREGS;

    code *cr = codelem(e2,&rretregs,FALSE); // eval right leaf
    unsigned rreg = findreg(rretregs);

    code cs;
    code *cl,*cg;

    regm_t retregs;
    unsigned reg;
    bool regvar = FALSE;
    if (config.flags4 & CFG4optimized)
    {
        // Be careful of cases like (x = x+x+x). We cannot evaluate in
        // x if x is in a register.
        unsigned varreg;
        regm_t varregm;
        if (isregvar(e1,&varregm,&varreg) &&    // if lvalue is register variable
            doinreg(e1->EV.sp.Vsym,e2)          // and we can compute directly into it
           )
        {   regvar = TRUE;
            retregs = varregm;
            reg = varreg;                       // evaluate directly in target register
            cl = NULL;
            cg = getregs(retregs);              // destroy these regs
        }
    }

    if (!regvar)
    {
        cl = getlvalue(&cs,e1,rretregs);        // get EA
        retregs = *pretregs & XMMREGS & ~rretregs;
        if (!retregs)
            retregs = XMMREGS & ~rretregs;
        cg = allocreg(&retregs,&reg,ty1);
        cs.Iop = 0xF20F10;                  // MOVSD xmm,xmm_m64
        if (sz1 == 4)
            cs.Iop = 0xF30F10;              // MOVSS xmm,xmm_m32
        code_newreg(&cs,reg - XMM0);
        cg = gen(cg,&cs);
    }

    unsigned op;
    switch (e->Eoper)
    {
        case OPaddass:
            op = 0xF20F58;                      // ADDSD
            if (sz1 == 4)                       // float
                op = 0xF30F58;                  // ADDSS
            break;

        case OPminass:
            op = 0xF20F5C;                      // SUBSD
            if (sz1 == 4)                       // float
                op = 0xF30F5C;                  // SUBSS
            break;

        case OPmulass:
            op = 0xF20F59;                      // MULSD
            if (sz1 == 4)                       // float
                op = 0xF30F59;                  // MULSS
            break;

        case OPdivass:
            op = 0xF20F5E;                      // DIVSD
            if (sz1 == 4)                       // float
                op = 0xF30F5E;                  // DIVSS
            break;

        default:
            assert(0);
    }
    code *co = gen2(CNIL,op,modregxrmx(3,reg-XMM0,rreg-XMM0));

    if (!regvar)
    {
        cs.Iop ^= 1;                            // reverse operand order of MOVS[SD]
        gen(co,&cs);
    }

    if (e1->Ecount ||                     // if lvalue is a CSE or
        regvar)                           // rvalue can't be a CSE
    {
        cl = cat(cl,getregs_imm(retregs));        // necessary if both lvalue and
                                        //  rvalue are CSEs (since a reg
                                        //  can hold only one e at a time)
        cssave(e1,retregs,EOP(e1));     // if lvalue is a CSE
    }

    co = cat(co,fixresult(e,retregs,pretregs));
    freenode(e1);
    return cat4(cr,cl,cg,co);
}

/******************
 * Negate operator
 */

code *xmmneg(elem *e,regm_t *pretregs)
{
    //printf("xmmneg()\n");
    //elem_print(e);
    assert(*pretregs);
    tym_t tyml = tybasic(e->E1->Ety);
    int sz = tysize[tyml];

    regm_t retregs = *pretregs & XMMREGS;
    if (!retregs)
        retregs = XMMREGS;

    /* Generate:
     *    MOV reg,e1
     *    MOV rreg,signbit
     *    XOR reg,rreg
     */
    code *cl = codelem(e->E1,&retregs,FALSE);
    cl = cat(cl,getregs(retregs));
    unsigned reg = findreg(retregs);
    regm_t rretregs = XMMREGS & ~retregs;
    unsigned rreg;
    cl = cat(cl,allocreg(&rretregs,&rreg,tyml));
    targ_size_t signbit = 0x80000000;
    if (sz == 8)
        signbit = 0x8000000000000000LL;
    code *c = movxmmconst(rreg, sz, signbit, 0);

    code *cg = getregs(retregs);
    unsigned op = (sz == 8) ? 0x660F57 : 0x0F57 ;       // XORPD/S reg,rreg
    code *co = gen2(CNIL,op,modregxrmx(3,reg-XMM0,rreg-XMM0));
    co = cat(co,fixresult(e,retregs,pretregs));
    return cat4(cl,c,cg,co);
}


#endif // !SPP
