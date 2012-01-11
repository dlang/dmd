// Copyright (C) 2011-2012 by Digital Mars
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
#include        "xmm.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/*******************************************
 * Move constant value into xmm register xreg.
 */

code *movxmmconst(unsigned xreg, unsigned sz, targ_size_t value, regm_t flags)
{
    /* Generate:
     *    MOV reg,value
     *    MOV xreg,reg
     * Not so efficient. We should at least do a PXOR for 0.
     */
    assert(mask[xreg] & XMMREGS);
    assert(sz == 4 || sz == 8);
    code *c;
    if (I32 && sz == 8)
    {
        unsigned r;
        regm_t rm = ALLREGS;
        c = allocreg(&rm,&r,TYint);         // allocate scratch register
        targ_long *p = (targ_long *)&value;
        c = movregconst(c,r,p[0],0);
        c = genfltreg(c,0x89,r,0);            // MOV floatreg,r
        c = movregconst(c,r,p[1],0);
        c = genfltreg(c,0x89,r,4);            // MOV floatreg+4,r

        unsigned op = xmmload(TYdouble);
        c = genfltreg(c,op,xreg - XMM0,0);     // MOVSD XMMreg,floatreg
    }
    else
    {
        unsigned reg;
        c = regwithvalue(CNIL,ALLREGS,value,&reg,(sz == 8) ? 64 : 0);
        c = gen2(c,XMM_LODD,modregxrmx(3,xreg-XMM0,reg));     // MOVD xreg,reg
        if (sz == 8)
            code_orrex(c, REX_W);
    }
    return c;
}

/***********************************************
 * Do simple orthogonal operators for XMM registers.
 */

code *orthxmm(elem *e, regm_t *pretregs)
{   elem *e1 = e->E1;
    elem *e2 = e->E2;
    tym_t ty1 = tybasic(e1->Ety);
    unsigned sz1 = tysize[ty1];
    assert(sz1 == 4 || sz1 == 8 || sz1 == 16);       // float or double
    regm_t retregs = *pretregs & XMMREGS;
    if (!retregs)
        retregs = XMMREGS;
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
            switch (ty1)
            {
                case TYfloat:
                case TYifloat:  op = XMM_ADDSS;  break;  // ADDSS
                case TYdouble:
                case TYidouble: op = XMM_ADDSD;  break;  // ADDSD

                // SIMD vector types
                case TYfloat4:  op = XMM_ADDPS;  break;  // ADDPS
                case TYdouble2: op = XMM_ADDPD;  break;  // ADDPD
                case TYschar16:
                case TYuchar16: op = XMM_PADDB; break;   // PADDB
                case TYshort8:
                case TYushort8: op = XMM_PADDW; break;   // PADDW
                case TYlong4:
                case TYulong4:  op = XMM_PADDD; break;   // PADDD
                case TYllong2:
                case TYullong2: op = XMM_PADDQ; break;   // PADDQ

                default:        assert(0);
            }
            break;

        case OPmin:
            switch (ty1)
            {
                case TYfloat:
                case TYifloat:  op = XMM_SUBSS;  break;  // SUBSS
                case TYdouble:
                case TYidouble: op = XMM_SUBSD;  break;  // SUBSD

                // SIMD vector types
                case TYfloat4:  op = XMM_SUBPS;  break;  // SUBPS
                case TYdouble2: op = XMM_SUBPD;  break;  // SUBPD
                case TYschar16:
                case TYuchar16: op = XMM_PSUBB; break;   // PSUBB
                case TYshort8:
                case TYushort8: op = XMM_PSUBW; break;   // PSUBW
                case TYlong4:
                case TYulong4:  op = XMM_PSUBD; break;   // PSUBD
                case TYllong2:
                case TYullong2: op = XMM_PSUBQ; break;   // PSUBQ

                default:        assert(0);
            }
            break;

        case OPmul:
            switch (ty1)
            {
                case TYfloat:
                case TYifloat:  op = XMM_MULSS;  break;  // MULSS
                case TYdouble:
                case TYidouble: op = XMM_MULSD;  break;  // MULSD

                // SIMD vector types
                case TYfloat4:  op = XMM_MULPS;  break;  // MULPS
                case TYdouble2: op = XMM_MULPD;  break;  // MULPD
                case TYschar16:
                case TYuchar16: assert(0);     break;   // PMULB
                case TYshort8:
                case TYushort8: op = XMM_PMULLW; break;   // PMULLW
                case TYlong4:
                case TYulong4:  assert(0);     break;   // PMULD
                case TYllong2:
                case TYullong2: assert(0);     break;   // PMULQ

                default:        assert(0);
            }
            break;

        case OPdiv:
            switch (ty1)
            {
                case TYfloat:
                case TYifloat:  op = XMM_DIVSS;  break;  // DIVSS
                case TYdouble:
                case TYidouble: op = XMM_DIVSD;  break;  // DIVSD

                // SIMD vector types
                case TYfloat4:  op = XMM_DIVPS;  break;  // DIVPS
                case TYdouble2: op = XMM_DIVPD;  break;  // DIVPD
                case TYschar16:
                case TYuchar16: assert(0);     break;   // PDIVB
                case TYshort8:
                case TYushort8: assert(0);     break;   // PDIVW
                case TYlong4:
                case TYulong4:  assert(0);     break;   // PDIVD
                case TYllong2:
                case TYullong2: assert(0);     break;   // PDIVQ

                default:        assert(0);
            }
            break;

        case OPor:
            switch (ty1)
            {
                // SIMD vector types
                case TYschar16:
                case TYuchar16:
                case TYshort8:
                case TYushort8:
                case TYlong4:
                case TYulong4:
                case TYllong2:
                case TYullong2: op = XMM_POR; break;   // POR

                default:        assert(0);
            }
            break;

        case OPand:
            switch (ty1)
            {
                // SIMD vector types
                case TYschar16:
                case TYuchar16:
                case TYshort8:
                case TYushort8:
                case TYlong4:
                case TYulong4:
                case TYllong2:
                case TYullong2: op = XMM_PAND; break;   // PAND

                default:        assert(0);
            }
            break;

        case OPlt:
        case OPle:
        case OPgt:
        case OPge:
        case OPne:
        case OPeqeq:
        case OPunord:        /* !<>=         */
        case OPlg:           /* <>           */
        case OPleg:          /* <>=          */
        case OPule:          /* !>           */
        case OPul:           /* !>=          */
        case OPuge:          /* !<           */
        case OPug:           /* !<=          */
        case OPue:           /* !<>          */
        case OPngt:
        case OPnge:
        case OPnlt:
        case OPnle:
        case OPord:
        case OPnlg:
        case OPnleg:
        case OPnule:
        case OPnul:
        case OPnuge:
        case OPnug:
        case OPnue:
        {   retregs = mPSW;
            if (sz1 == 4)                       // float
                op = XMM_UCOMISS;
            else
            {   assert(sz1 == 8);
                op = XMM_UCOMISD;
            }
            code *cc = gen2(CNIL,op,modregxrmx(3,rreg-XMM0,reg-XMM0));
            return cat4(c,cr,cg,cc);
        }

        default:
#ifdef DEBUG
            elem_print(e);
#endif
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

    if (!(retregs & XMMREGS))
        retregs = XMMREGS;              // pick any XMM reg

    cs.Iop = xmmstore(tyml);
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
        cs.Iop = xmmload(ty1);                  // MOVSD xmm,xmm_m64
        code_newreg(&cs,reg - XMM0);
        cg = gen(cg,&cs);
    }

    unsigned op;
    switch (e->Eoper)
    {
        case OPaddass:
            op = XMM_ADDSD;                     // ADDSD
            if (sz1 == 4)                       // float
                op = XMM_ADDSS;                 // ADDSS
            break;

        case OPminass:
            op = XMM_SUBSD;                     // SUBSD
            if (sz1 == 4)                       // float
                op = XMM_SUBSS;                 // SUBSS
            break;

        case OPmulass:
            op = XMM_MULSD;                     // MULSD
            if (sz1 == 4)                       // float
                op = XMM_MULSS;                 // MULSS
            break;

        case OPdivass:
            op = XMM_DIVSD;                     // DIVSD
            if (sz1 == 4)                       // float
                op = XMM_DIVSS;                 // DIVSS
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
    unsigned op = (sz == 8) ? XMM_XORPD : XMM_XORPS;       // XORPD/S reg,rreg
    code *co = gen2(CNIL,op,modregxrmx(3,reg-XMM0,rreg-XMM0));
    co = cat(co,fixresult(e,retregs,pretregs));
    return cat4(cl,c,cg,co);
}

/*****************************
 * Get correct load operator based on type.
 * It is important to use the right one even if the number of bits moved is the same,
 * as there are performance consequences for using the wrong one.
 */

unsigned xmmload(tym_t tym)
{   unsigned op;
    switch (tybasic(tym))
    {
        case TYfloat:
        case TYifloat:  op = XMM_LODSS; break;       // MOVSS
        case TYdouble:
        case TYidouble: op = XMM_LODSD; break;       // MOVSD

        case TYfloat4:  op = XMM_LODAPS; break;      // MOVAPS
        case TYdouble2: op = XMM_LODAPD; break;      // MOVAPD
        case TYschar16:
        case TYuchar16:
        case TYshort8:
        case TYushort8:
        case TYlong4:
        case TYulong4:
        case TYllong2:
        case TYullong2: op = XMM_LODDQA; break;      // MOVDQA

        default:
            printf("tym = x%x\n", tym);
            assert(0);
    }
    return op;
}

/*****************************
 * Get correct store operator based on type.
 */

unsigned xmmstore(tym_t tym)
{   unsigned op;
    switch (tybasic(tym))
    {
        case TYfloat:
        case TYifloat:  op = XMM_STOSS; break;       // MOVSS
        case TYdouble:
        case TYidouble:
        case TYllong:
        case TYullong:
        case TYuint:
        case TYlong:
        case TYcfloat:  op = XMM_STOSD; break;       // MOVSD

        case TYfloat4:  op = XMM_STOAPS; break;      // MOVAPS
        case TYdouble2: op = XMM_STOAPD; break;      // MOVAPD
        case TYschar16:
        case TYuchar16:
        case TYshort8:
        case TYushort8:
        case TYlong4:
        case TYulong4:
        case TYllong2:
        case TYullong2: op = XMM_STODQA; break;      // MOVDQA

        default:
            printf("tym = x%x\n", tym);
            assert(0);
    }
    return op;
}

code *cdvector(elem *e, regm_t *pretregs)
{
    return NULL;
}

#endif // !SPP
