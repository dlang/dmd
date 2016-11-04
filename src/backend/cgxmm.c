// Copyright (C) 2011-2012 by Digital Mars
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
#include        <string.h>
#include        <time.h>
#include        <stdlib.h>

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

unsigned xmmoperator(tym_t tym, unsigned oper);

/*******************************************
 * Is operator a store operator?
 */

bool isXMMstore(unsigned op)
{
    switch (op)
    {
    case STOSS: case STOAPS: case STOUPS:
    case STOSD: case STOAPD: case STOUPD:
    case STOD: case STOQ: case STODQA: case STODQU:
    case STOHPD: case STOHPS: case STOLPD: case STOLPS: return true;
    default: return false;
    }
}

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
        union { targ_size_t s; targ_long l[2]; } u;
        u.l[1] = 0;
        u.s = value;
        targ_long *p = &u.l[0];
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
        c = gen2(c,LODD,modregxrmx(3,xreg-XMM0,reg));     // MOVD xreg,reg
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
    regm_t retregs = *pretregs & XMMREGS;
    if (!retregs)
        retregs = XMMREGS;
    code *c = codelem(e1,&retregs,FALSE); // eval left leaf
    unsigned reg = findreg(retregs);
    regm_t rretregs = XMMREGS & ~retregs;
    code *cr = scodelem(e2, &rretregs, retregs, TRUE);  // eval right leaf

    unsigned op = xmmoperator(e1->Ety, e->Eoper);
    unsigned rreg = findreg(rretregs);

    // float + ifloat is not actually addition
    if ((e->Eoper == OPadd || e->Eoper == OPmin) &&
        ((tyreal(e1->Ety) && tyimaginary(e2->Ety)) ||
         (tyreal(e2->Ety) && tyimaginary(e1->Ety))))
    {
        retregs |= rretregs;
        c = cat(c, cr);
        if (e->Eoper == OPmin)
        {
            unsigned nretregs = XMMREGS & ~retregs;
            unsigned sreg; // hold sign bit
            unsigned sz = tysize(e1->Ety);
            c = cat(c,allocreg(&nretregs,&sreg,e2->Ety));
            targ_size_t signbit = 0x80000000;
            if (sz == 8)
                signbit = 0x8000000000000000LL;
            c = cat(c, movxmmconst(sreg, sz, signbit, 0));
            c = cat(c, getregs(nretregs));
            unsigned xop = (sz == 8) ? XORPD : XORPS;       // XORPD/S rreg,sreg
            c = cat(c, gen2(CNIL,xop,modregxrmx(3,rreg-XMM0,sreg-XMM0)));
        }
        if (retregs != *pretregs)
            c = cat(c, fixresult(e,retregs,pretregs));
        return c;
    }

    /* We should take advantage of mem addressing modes for OP XMM,MEM
     * but we do not at the moment.
     */
    code *cg;
    if (OTrel(e->Eoper))
    {
        retregs = mPSW;
        cg = NULL;
        code *cc = gen2(CNIL,op,modregxrmx(3,rreg-XMM0,reg-XMM0));
        return cat4(c,cr,cg,cc);
    }
    else
        cg = getregs(retregs);

    code *co = gen2(CNIL,op,modregxrmx(3,reg-XMM0,rreg-XMM0));
    if (retregs != *pretregs)
        co = cat(co,fixresult(e,retregs,pretregs));

    return cat4(c,cr,cg,co);
}


/************************
 * Generate code for an assignment using XMM registers.
 */

code *xmmeq(elem *e, unsigned op, elem *e1, elem *e2,regm_t *pretregs)
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

    //printf("xmmeq(e1 = %p, e2 = %p, *pretregs = %s)\n", e1, e2, regm_str(*pretregs));
    int e2oper = e2->Eoper;
    tym_t tyml = tybasic(e1->Ety);              /* type of lvalue               */
    regm_t retregs = *pretregs;

    if (!(retregs & XMMREGS))
        retregs = XMMREGS;              // pick any XMM reg

    cs.Iop = (op == OPeq) ? xmmstore(tyml) : op;
    regvar = FALSE;
    varregm = 0;
    if (config.flags4 & CFG4optimized)
    {
        // Be careful of cases like (x = x+x+x). We cannot evaluate in
        // x if x is in a register.
        if (isregvar(e1,&varregm,&varreg) &&    // if lvalue is register variable
            doinreg(e1->EV.sp.Vsym,e2) &&       // and we can compute directly into it
            varregm & XMMREGS
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

    c = getregs_imm(regvar ? varregm : 0);

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
 * Generate code for conversion using SSE2 instructions.
 *
 *      OPs32_d
 *      OPs64_d (64-bit only)
 *      OPu32_d (64-bit only)
 *      OPd_f
 *      OPf_d
 *      OPd_s32
 *      OPd_s64 (64-bit only)
 *
 */

code *xmmcnvt(elem *e,regm_t *pretregs)
{
    code *c;
    unsigned op=0, regs;
    tym_t ty;
    unsigned char rex = 0;
    bool zx = false; // zero extend uint

    /* There are no ops for integer <-> float/real conversions
     * but there are instructions for them. In order to use these
     * try to fuse chained conversions. Be careful not to loose
     * precision for real to long.
     */
    elem *e1 = e->E1;
    switch (e->Eoper)
    {
    case OPd_f:
        if (e1->Eoper == OPs32_d)
            ;
        else if (I64 && e1->Eoper == OPs64_d)
            rex = REX_W;
        else if (I64 && e1->Eoper == OPu32_d)
        {   rex = REX_W;
            zx = true;
        }
        else
        {   regs = XMMREGS;
            op = CVTSD2SS;
            ty = TYfloat;
            break;
        }
        // directly use si2ss
        regs = ALLREGS;
        e1 = e1->E1;
        op = CVTSI2SS;
        ty = TYfloat;
        break;

    case OPs32_d:              goto Litod;
    case OPs64_d: rex = REX_W; goto Litod;
    case OPu32_d: rex = REX_W; zx = true; goto Litod;
    Litod:
        regs = ALLREGS;
        op = CVTSI2SD;
        ty = TYdouble;
        break;

    case OPd_s32: ty = TYint;  goto Ldtoi;
    case OPd_u32: ty = TYlong; if (I64) rex = REX_W; goto Ldtoi;
    case OPd_s64: ty = TYlong; rex = REX_W; goto Ldtoi;
    Ldtoi:
        regs = XMMREGS;
        switch (e1->Eoper)
        {
        case OPf_d:
            e1 = e1->E1;
            op = CVTTSS2SI;
            break;
        case OPld_d:
            if (e->Eoper == OPd_s64)
                return cnvt87(e,pretregs); // precision
            /* FALL-THROUGH */
        default:
            op = CVTTSD2SI;
            break;
        }
        break;

    case OPf_d:
        regs = XMMREGS;
        op = CVTSS2SD;
        ty = TYdouble;
        break;
    }
    assert(op);

    c = codelem(e1, &regs, FALSE);
    unsigned reg = findreg(regs);
    if (reg >= XMM0)
        reg -= XMM0;
    else if (zx)
    {   assert(I64);
        c = cat(c,getregs(regs));
        c = genregs(c,0x89,reg,reg); // MOV reg,reg to zero upper 32-bit
        code_orflag(c,CFvolatile);
    }

    unsigned retregs = *pretregs;
    if (tyxmmreg(ty)) // target is XMM
    {   if (!(*pretregs & XMMREGS))
            retregs = XMMREGS;
    }
    else              // source is XMM
    {   assert(regs & XMMREGS);
        if (!(retregs & ALLREGS))
            retregs = ALLREGS;
    }

    unsigned rreg;
    c = cat(c,allocreg(&retregs,&rreg,ty));
    if (rreg >= XMM0)
        rreg -= XMM0;

    c = gen2(c, op, modregxrmx(3,rreg,reg));
    assert(I64 || !rex);
    if (rex)
        code_orrex(c, rex);

    if (*pretregs != retregs)
        c = cat(c,fixresult(e,retregs,pretregs));
    return c;
}

/********************************
 * Generate code for op=
 */

code *xmmopass(elem *e,regm_t *pretregs)
{   elem *e1 = e->E1;
    elem *e2 = e->E2;
    tym_t ty1 = tybasic(e1->Ety);
    unsigned sz1 = _tysize[ty1];
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

    unsigned op = xmmoperator(e1->Ety, e->Eoper);
    code *co = gen2(CNIL,op,modregxrmx(3,reg-XMM0,rreg-XMM0));

    if (!regvar)
    {
        cs.Iop = xmmstore(ty1);           // reverse operand order of MOVS[SD]
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
    int sz = _tysize[tyml];

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
    unsigned op = (sz == 8) ? XORPD : XORPS;       // XORPD/S reg,rreg
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
        case TYuint:
        case TYint:
        case TYlong:
        case TYulong:
        case TYfloat:
        case TYcfloat:
        case TYifloat:  op = LODSS; break;       // MOVSS
        case TYllong:
        case TYullong:
        case TYdouble:
        case TYcdouble:
        case TYidouble: op = LODSD; break;       // MOVSD

        case TYfloat4:  op = LODAPS; break;      // MOVAPS
        case TYdouble2: op = LODAPD; break;      // MOVAPD
        case TYschar16:
        case TYuchar16:
        case TYshort8:
        case TYushort8:
        case TYlong4:
        case TYulong4:
        case TYllong2:
        case TYullong2: op = LODDQA; break;      // MOVDQA

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
        case TYuint:
        case TYint:
        case TYlong:
        case TYulong:
        case TYfloat:
        case TYifloat:  op = STOSS; break;       // MOVSS
        case TYdouble:
        case TYidouble:
        case TYllong:
        case TYullong:
        case TYcdouble:
        case TYcfloat:  op = STOSD; break;       // MOVSD

        case TYfloat4:  op = STOAPS; break;      // MOVAPS
        case TYdouble2: op = STOAPD; break;      // MOVAPD
        case TYschar16:
        case TYuchar16:
        case TYshort8:
        case TYushort8:
        case TYlong4:
        case TYulong4:
        case TYllong2:
        case TYullong2: op = STODQA; break;      // MOVDQA

        default:
            printf("tym = x%x\n", tym);
            assert(0);
    }
    return op;
}

/************************************
 * Get correct XMM operator based on type and operator.
 */

unsigned xmmoperator(tym_t tym, unsigned oper)
{
    tym = tybasic(tym);
    unsigned op;
    switch (oper)
    {
        case OPadd:
        case OPaddass:
            switch (tym)
            {
                case TYfloat:
                case TYifloat:  op = ADDSS;  break;
                case TYdouble:
                case TYidouble: op = ADDSD;  break;

                // SIMD vector types
                case TYfloat4:  op = ADDPS;  break;
                case TYdouble2: op = ADDPD;  break;
                case TYschar16:
                case TYuchar16: op = PADDB;  break;
                case TYshort8:
                case TYushort8: op = PADDW;  break;
                case TYlong4:
                case TYulong4:  op = PADDD;  break;
                case TYllong2:
                case TYullong2: op = PADDQ;  break;

                default:        assert(0);
            }
            break;

        case OPmin:
        case OPminass:
            switch (tym)
            {
                case TYfloat:
                case TYifloat:  op = SUBSS;  break;
                case TYdouble:
                case TYidouble: op = SUBSD;  break;

                // SIMD vector types
                case TYfloat4:  op = SUBPS;  break;
                case TYdouble2: op = SUBPD;  break;
                case TYschar16:
                case TYuchar16: op = PSUBB;  break;
                case TYshort8:
                case TYushort8: op = PSUBW;  break;
                case TYlong4:
                case TYulong4:  op = PSUBD;  break;
                case TYllong2:
                case TYullong2: op = PSUBQ;  break;

                default:        assert(0);
            }
            break;

        case OPmul:
        case OPmulass:
            switch (tym)
            {
                case TYfloat:
                case TYifloat:  op = MULSS;  break;
                case TYdouble:
                case TYidouble: op = MULSD;  break;

                // SIMD vector types
                case TYfloat4:  op = MULPS;  break;
                case TYdouble2: op = MULPD;  break;
                case TYshort8:
                case TYushort8: op = PMULLW; break;

                default:        assert(0);
            }
            break;

        case OPdiv:
        case OPdivass:
            switch (tym)
            {
                case TYfloat:
                case TYifloat:  op = DIVSS;  break;
                case TYdouble:
                case TYidouble: op = DIVSD;  break;

                // SIMD vector types
                case TYfloat4:  op = DIVPS;  break;
                case TYdouble2: op = DIVPD;  break;

                default:        assert(0);
            }
            break;

        case OPor:
        case OPorass:
            switch (tym)
            {
                // SIMD vector types
                case TYschar16:
                case TYuchar16:
                case TYshort8:
                case TYushort8:
                case TYlong4:
                case TYulong4:
                case TYllong2:
                case TYullong2: op = POR; break;

                default:        assert(0);
            }
            break;

        case OPand:
        case OPandass:
            switch (tym)
            {
                // SIMD vector types
                case TYschar16:
                case TYuchar16:
                case TYshort8:
                case TYushort8:
                case TYlong4:
                case TYulong4:
                case TYllong2:
                case TYullong2: op = PAND; break;

                default:        assert(0);
            }
            break;

        case OPxor:
        case OPxorass:
            switch (tym)
            {
                // SIMD vector types
                case TYschar16:
                case TYuchar16:
                case TYshort8:
                case TYushort8:
                case TYlong4:
                case TYulong4:
                case TYllong2:
                case TYullong2: op = PXOR; break;

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
            switch (tym)
            {
                case TYfloat:
                case TYifloat:  op = UCOMISS;  break;
                case TYdouble:
                case TYidouble: op = UCOMISD;  break;

                default:        assert(0);
            }
            break;

        default:
            assert(0);
    }
    return op;
}

code *cdvector(elem *e, regm_t *pretregs)
{
    /* e should look like one of:
     *    vector
     *      |
     *    param
     *    /   \
     *  param op2
     *  /   \
     * op   op1
     */

    if (!config.fpxmmregs)
    {   printf("SIMD operations not supported on this platform\n");
        exit(1);
    }

    unsigned n = el_nparams(e->E1);
    elem **params = (elem **)malloc(n * sizeof(elem *));
    assert(params);
    elem **tmp = params;
    el_paramArray(&tmp, e->E1);

#if 0
    printf("cdvector()\n");
    for (int i = 0; i < n; i++)
    {
        printf("[%d]: ", i);
        elem_print(params[i]);
    }
#endif

    if (*pretregs == 0)
    {   /* Evaluate for side effects only
         */
        code *c = CNIL;
        for (int i = 0; i < n; i++)
        {
            c = cat(c, codelem(params[i], pretregs, FALSE));
            *pretregs = 0;      // in case they got set
        }
        return c;
    }

    assert(n >= 2 && n <= 4);

    elem *eop = params[0];
    elem *op1 = params[1];
    elem *op2 = NULL;
    tym_t ty2 = 0;
    if (n >= 3)
    {   op2 = params[2];
        ty2 = tybasic(op2->Ety);
    }

    unsigned op = el_tolong(eop);
#ifdef DEBUG
    assert(!isXMMstore(op));
#endif
    tym_t ty1 = tybasic(op1->Ety);
    unsigned sz1 = _tysize[ty1];
//    assert(sz1 == 16);       // float or double

    regm_t retregs;
    code *c;
    code *cr, *cg, *co;
    if (n == 3 && ty2 == TYuchar && op2->Eoper == OPconst)
    {   // Handle: op xmm,imm8

        retregs = *pretregs & XMMREGS;
        if (!retregs)
            retregs = XMMREGS;
        c = codelem(op1,&retregs,FALSE); // eval left leaf
        unsigned reg = findreg(retregs);
        int r;
        switch (op)
        {
            case PSLLD:  r = 6; op = 0x660F72;  break;
            case PSLLQ:  r = 6; op = 0x660F73;  break;
            case PSLLW:  r = 6; op = 0x660F71;  break;
            case PSRAD:  r = 4; op = 0x660F72;  break;
            case PSRAW:  r = 4; op = 0x660F71;  break;
            case PSRLD:  r = 2; op = 0x660F72;  break;
            case PSRLQ:  r = 2; op = 0x660F73;  break;
            case PSRLW:  r = 2; op = 0x660F71;  break;
            case PSRLDQ: r = 3; op = 0x660F73;  break;
            case PSLLDQ: r = 7; op = 0x660F73;  break;

            default:
                printf("op = x%x\n", op);
                assert(0);
                break;
        }
        cr = CNIL;
        cg = getregs(retregs);
        co = genc2(CNIL,op,modregrmx(3,r,reg-XMM0), el_tolong(op2));
    }
    else if (n == 2)
    {   /* Handle: op xmm,mem
         * where xmm is written only, not read
         */
        code cs;

        if ((op1->Eoper == OPind && !op1->Ecount) || op1->Eoper == OPvar)
        {
            c = getlvalue(&cs, op1, RMload);     // get addressing mode
        }
        else
        {
            regm_t rretregs = XMMREGS;
            c = codelem(op1, &rretregs, FALSE);
            unsigned rreg = findreg(rretregs) - XMM0;
            cs.Irm = modregrm(3,0,rreg & 7);
            cs.Iflags = 0;
            cs.Irex = 0;
            if (rreg & 8)
                cs.Irex |= REX_B;
        }

        retregs = *pretregs & XMMREGS;
        if (!retregs)
            retregs = XMMREGS;
        unsigned reg;
        cr = CNIL;
        cg = allocreg(&retregs, &reg, e->Ety);
        code_newreg(&cs, reg - XMM0);
        cs.Iop = op;
        co = gen(CNIL,&cs);
    }
    else if (n == 3 || n == 4)
    {   /* Handle:
         *      op xmm,mem        // n = 3
         *      op xmm,mem,imm8   // n = 4
         * Both xmm and mem are operands, evaluate xmm first.
         */

        code cs;

        retregs = *pretregs & XMMREGS;
        if (!retregs)
            retregs = XMMREGS;
        c = codelem(op1,&retregs,FALSE); // eval left leaf
        unsigned reg = findreg(retregs);

        if ((op2->Eoper == OPind && !op2->Ecount) || op2->Eoper == OPvar)
        {
            cr = getlvalue(&cs, op2, RMload | retregs);     // get addressing mode
        }
        else
        {
            unsigned rretregs = XMMREGS & ~retregs;
            cr = scodelem(op2, &rretregs, retregs, TRUE);
            unsigned rreg = findreg(rretregs) - XMM0;
            cs.Irm = modregrm(3,0,rreg & 7);
            cs.Iflags = 0;
            cs.Irex = 0;
            if (rreg & 8)
                cs.Irex |= REX_B;
        }

        cg = getregs(retregs);
        if (n == 4)
        {
            switch (op)
            {
                case CMPPD:   case CMPSS:   case CMPSD:   case CMPPS:
                case PSHUFD:  case PSHUFHW: case PSHUFLW:
                case BLENDPD: case BLENDPS: case DPPD:    case DPPS:
                case MPSADBW: case PBLENDW:
                case ROUNDPD: case ROUNDPS: case ROUNDSD: case ROUNDSS:
                case SHUFPD:  case SHUFPS:
                    break;
                default:
                    printf("op = x%x\n", op);
                    assert(0);
                    break;
            }
            elem *imm8 = params[3];
            cs.IFL2 = FLconst;
            cs.IEV2.Vsize_t = el_tolong(imm8);
        }
        code_newreg(&cs, reg - XMM0);
        cs.Iop = op;
        co = gen(CNIL,&cs);
    }
    else
        assert(0);
    co = cat(co,fixresult(e,retregs,pretregs));
    free(params);
    freenode(e);
    return cat4(c,cr,cg,co);
}

/***************
 * Generate code for vector "store" operations.
 * The tree e must look like:
 *  (op1 OPvecsto (op OPparam op2))
 * where op is the store instruction STOxxxx.
 */
code *cdvecsto(elem *e, regm_t *pretregs)
{
    //printf("cdvecsto()\n");
    //elem_print(e);
    elem *op1 = e->E1;
    elem *op2 = e->E2->E2;
    elem *eop = e->E2->E1;
    unsigned op = el_tolong(eop);
#ifdef DEBUG
    assert(isXMMstore(op));
#endif
    return xmmeq(e, op, op1, op2, pretregs);
}

#endif // !SPP
