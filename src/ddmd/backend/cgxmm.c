/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 2011-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/cgxmm.c
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

static unsigned xmmoperator(tym_t tym, unsigned oper);

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

static void movxmmconst(CodeBuilder& cdb, unsigned xreg, unsigned sz, targ_size_t value, regm_t flags)
{
    /* Generate:
     *    MOV reg,value
     *    MOV xreg,reg
     * Not so efficient. We should at least do a PXOR for 0.
     */
    assert(mask[xreg] & XMMREGS);
    assert(sz == 4 || sz == 8);
    if (I32 && sz == 8)
    {
        unsigned r;
        regm_t rm = ALLREGS;
        allocreg(cdb,&rm,&r,TYint);         // allocate scratch register
        union { targ_size_t s; targ_long l[2]; } u;
        u.l[1] = 0;
        u.s = value;
        targ_long *p = &u.l[0];
        movregconst(cdb,r,p[0],0);
        cdb.genfltreg(STO,r,0);                     // MOV floatreg,r
        movregconst(cdb,r,p[1],0);
        cdb.genfltreg(STO,r,4);                     // MOV floatreg+4,r

        unsigned op = xmmload(TYdouble, true);
        cdb.genxmmreg(op,xreg,0,TYdouble);          // MOVSD XMMreg,floatreg
    }
    else
    {
        unsigned reg;
        regwithvalue(cdb,ALLREGS,value,&reg,(sz == 8) ? 64 : 0);
        cdb.gen2(LODD,modregxrmx(3,xreg-XMM0,reg));     // MOVD xreg,reg
        if (sz == 8)
            code_orrex(cdb.last(), REX_W);
        checkSetVex(cdb.last(), TYulong);
    }
}

/***********************************************
 * Do simple orthogonal operators for XMM registers.
 */

void orthxmm(CodeBuilder& cdb, elem *e, regm_t *pretregs)
{
    //printf("orthxmm(e = %p, *pretregs = %s)\n", e, regm_str(*pretregs));
    elem *e1 = e->E1;
    elem *e2 = e->E2;

    // float + ifloat is not actually addition
    if ((e->Eoper == OPadd || e->Eoper == OPmin) &&
        ((tyreal(e1->Ety) && tyimaginary(e2->Ety)) ||
         (tyreal(e2->Ety) && tyimaginary(e1->Ety))))
    {
        regm_t retregs = *pretregs & XMMREGS;
        if (!retregs)
            retregs = XMMREGS;

        unsigned reg;
        regm_t rretregs;
        unsigned rreg;
        if (tyreal(e1->Ety))
        {
            reg = findreg(retregs);
            rreg = findreg(retregs & ~mask[reg]);
            retregs = mask[reg];
            rretregs = mask[rreg];
        }
        else
        {
            // Pick the second register, not the first
            rreg = findreg(retregs);
            rretregs = mask[rreg];
            reg = findreg(retregs & ~rretregs);
            retregs = mask[reg];
        }
        assert(retregs && rretregs);

        codelem(cdb,e1,&retregs,FALSE); // eval left leaf
        scodelem(cdb, e2, &rretregs, retregs, TRUE);  // eval right leaf

        retregs |= rretregs;
        if (e->Eoper == OPmin)
        {
            unsigned nretregs = XMMREGS & ~retregs;
            unsigned sreg; // hold sign bit
            unsigned sz = tysize(e1->Ety);
            allocreg(cdb,&nretregs,&sreg,e2->Ety);
            targ_size_t signbit = 0x80000000;
            if (sz == 8)
                signbit = 0x8000000000000000LL;
            movxmmconst(cdb,sreg, sz, signbit, 0);
            getregs(cdb,nretregs);
            unsigned xop = (sz == 8) ? XORPD : XORPS;       // XORPD/S rreg,sreg
            cdb.gen2(xop,modregxrmx(3,rreg-XMM0,sreg-XMM0));
        }
        if (retregs != *pretregs)
            fixresult(cdb,e,retregs,pretregs);
        return;
    }

    regm_t retregs = *pretregs & XMMREGS;
    if (!retregs)
        retregs = XMMREGS;
    codelem(cdb,e1,&retregs,FALSE); // eval left leaf
    unsigned reg = findreg(retregs);
    regm_t rretregs = XMMREGS & ~retregs;
    scodelem(cdb, e2, &rretregs, retregs, TRUE);  // eval right leaf

    unsigned rreg = findreg(rretregs);
    unsigned op = xmmoperator(e1->Ety, e->Eoper);

    /* We should take advantage of mem addressing modes for OP XMM,MEM
     * but we do not at the moment.
     */
    if (OTrel(e->Eoper))
    {
        retregs = mPSW;
        cdb.gen2(op,modregxrmx(3,rreg-XMM0,reg-XMM0));
        checkSetVex(cdb.last(), e1->Ety);
        return;
    }
    else
        getregs(cdb,retregs);

    cdb.gen2(op,modregxrmx(3,reg-XMM0,rreg-XMM0));
    checkSetVex(cdb.last(), e1->Ety);
    if (retregs != *pretregs)
        fixresult(cdb,e,retregs,pretregs);
}


/************************
 * Generate code for an assignment using XMM registers.
 */

void xmmeq(CodeBuilder& cdb, elem *e, unsigned op, elem *e1, elem *e2,regm_t *pretregs)
{
    tym_t tymll;
    unsigned reg;
    int i;
    code cs;
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

    bool aligned = xmmIsAligned(e1);
    cs.Iop = (op == OPeq) ? xmmstore(tyml, aligned) : op;
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
    scodelem(cdb,e2,&retregs,0,TRUE);    // get rvalue

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
        getlvalue(cdb,&cs,e11,RMstore | retregs);
        freenode(e11->E2);
    }
    else
    {   postinc = 0;
        getlvalue(cdb,&cs,e1,RMstore | retregs);       // get lvalue (cl == CNIL if regvar)
    }

    getregs_imm(cdb,regvar ? varregm : 0);

    reg = findreg(retregs & XMMREGS);
    cs.Irm |= modregrm(0,(reg - XMM0) & 7,0);
    if ((reg - XMM0) & 8)
        cs.Irex |= REX_R;

    // Do not generate mov from register onto itself
    if (!(regvar && reg == XMM0 + ((cs.Irm & 7) | (cs.Irex & REX_B ? 8 : 0))))
    {
        cdb.gen(&cs);         // MOV EA+offset,reg
        if (op == OPeq)
            checkSetVex(cdb.last(), tyml);
    }

    if (e1->Ecount ||                     // if lvalue is a CSE or
        regvar)                           // rvalue can't be a CSE
    {
        getregs_imm(cdb,retregs);        // necessary if both lvalue and
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

void xmmcnvt(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
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
            {
                cnvt87(cdb,e,pretregs); // precision
                return;
            }
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

    codelem(cdb,e1, &regs, FALSE);
    unsigned reg = findreg(regs);
    if (reg >= XMM0)
        reg -= XMM0;
    else if (zx)
    {   assert(I64);
        getregs(cdb,regs);
        cdb.append(genregs(CNIL,STO,reg,reg)); // MOV reg,reg to zero upper 32-bit
        code_orflag(cdb.last(),CFvolatile);
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
    allocreg(cdb,&retregs,&rreg,ty);
    if (rreg >= XMM0)
        rreg -= XMM0;

    cdb.gen2(op, modregxrmx(3,rreg,reg));
    assert(I64 || !rex);
    if (rex)
        code_orrex(cdb.last(), rex);

    if (*pretregs != retregs)
        fixresult(cdb,e,retregs,pretregs);
}

/********************************
 * Generate code for op=
 */

void xmmopass(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{   elem *e1 = e->E1;
    elem *e2 = e->E2;
    tym_t ty1 = tybasic(e1->Ety);
    unsigned sz1 = _tysize[ty1];
    regm_t rretregs = XMMREGS & ~*pretregs;
    if (!rretregs)
        rretregs = XMMREGS;

    codelem(cdb,e2,&rretregs,FALSE); // eval right leaf
    unsigned rreg = findreg(rretregs);

    code cs;
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
            getregs(cdb,retregs);       // destroy these regs
        }
    }

    if (!regvar)
    {
        getlvalue(cdb,&cs,e1,rretregs);         // get EA
        retregs = *pretregs & XMMREGS & ~rretregs;
        if (!retregs)
            retregs = XMMREGS & ~rretregs;
        allocreg(cdb,&retregs,&reg,ty1);
        cs.Iop = xmmload(ty1, true);            // MOVSD xmm,xmm_m64
        code_newreg(&cs,reg - XMM0);
        cdb.gen(&cs);
        checkSetVex(cdb.last(), ty1);
    }

    unsigned op = xmmoperator(e1->Ety, e->Eoper);
    cdb.gen2(op,modregxrmx(3,reg-XMM0,rreg-XMM0));
    checkSetVex(cdb.last(), e1->Ety);

    if (!regvar)
    {
        cs.Iop = xmmstore(ty1,true);      // reverse operand order of MOVS[SD]
        cdb.gen(&cs);
        checkSetVex(cdb.last(), ty1);
    }

    if (e1->Ecount ||                     // if lvalue is a CSE or
        regvar)                           // rvalue can't be a CSE
    {
        getregs_imm(cdb,retregs);        // necessary if both lvalue and
                                        //  rvalue are CSEs (since a reg
                                        //  can hold only one e at a time)
        cssave(e1,retregs,EOP(e1));     // if lvalue is a CSE
    }

    fixresult(cdb,e,retregs,pretregs);
    freenode(e1);
}

/********************************
 * Generate code for post increment and post decrement.
 */

void xmmpost(CodeBuilder& cdb,elem *e,regm_t *pretregs)
{
    elem *e1 = e->E1;
    elem *e2 = e->E2;
    tym_t ty1 = tybasic(e1->Ety);

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
        {
            regvar = TRUE;
            retregs = varregm;
            reg = varreg;                       // evaluate directly in target register
            getregs(cdb,retregs);       // destroy these regs
        }
    }

    code cs;
    if (!regvar)
    {
        getlvalue(cdb,&cs,e1,0);                // get EA
        retregs = XMMREGS & ~*pretregs;
        if (!retregs)
            retregs = XMMREGS;
        allocreg(cdb,&retregs,&reg,ty1);
        cs.Iop = xmmload(ty1, true);            // MOVSD xmm,xmm_m64
        code_newreg(&cs,reg - XMM0);
        cdb.gen(&cs);
        checkSetVex(cdb.last(), ty1);
    }

    // Result register
    regm_t resultregs = XMMREGS & *pretregs & ~retregs;
    if (!resultregs)
        resultregs = XMMREGS & ~retregs;
    unsigned resultreg;
    allocreg(cdb,&resultregs, &resultreg, ty1);

    cdb.gen2(xmmload(ty1,true),modregxrmx(3,resultreg-XMM0,reg-XMM0));   // MOVSS/D resultreg,reg
    checkSetVex(cdb.last(), ty1);

    regm_t rretregs = XMMREGS & ~(*pretregs | retregs | resultregs);
    if (!rretregs)
        rretregs = XMMREGS & ~(retregs | resultregs);
    codelem(cdb,e2,&rretregs,FALSE); // eval right leaf
    unsigned rreg = findreg(rretregs);

    unsigned op = xmmoperator(e1->Ety, e->Eoper);
    cdb.gen2(op,modregxrmx(3,reg-XMM0,rreg-XMM0));  // ADD reg,rreg
    checkSetVex(cdb.last(), e1->Ety);

    if (!regvar)
    {
        cs.Iop = xmmstore(ty1,true);      // reverse operand order of MOVS[SD]
        cdb.gen(&cs);
        checkSetVex(cdb.last(), ty1);
    }

    if (e1->Ecount ||                     // if lvalue is a CSE or
        regvar)                           // rvalue can't be a CSE
    {
        getregs_imm(cdb,retregs); // necessary if both lvalue and
                                        //  rvalue are CSEs (since a reg
                                        //  can hold only one e at a time)
        cssave(e1,retregs,EOP(e1));     // if lvalue is a CSE
    }

    fixresult(cdb,e,resultregs,pretregs);
    freenode(e1);
}

/******************
 * Negate operator
 */

void xmmneg(CodeBuilder& cdb,elem *e,regm_t *pretregs)
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
    codelem(cdb,e->E1,&retregs,FALSE);
    getregs(cdb,retregs);
    unsigned reg = findreg(retregs);
    regm_t rretregs = XMMREGS & ~retregs;
    unsigned rreg;
    allocreg(cdb,&rretregs,&rreg,tyml);
    targ_size_t signbit = 0x80000000;
    if (sz == 8)
        signbit = 0x8000000000000000LL;
    movxmmconst(cdb,rreg, sz, signbit, 0);

    getregs(cdb,retregs);
    unsigned op = (sz == 8) ? XORPD : XORPS;       // XORPD/S reg,rreg
    cdb.gen2(op,modregxrmx(3,reg-XMM0,rreg-XMM0));
    fixresult(cdb,e,retregs,pretregs);
}

/*****************************
 * Get correct load operator based on type.
 * It is important to use the right one even if the number of bits moved is the same,
 * as there are performance consequences for using the wrong one.
 * Params:
 *      tym = type of data to load
 *      aligned = for vectors, true if aligned to 16 bytes
 */

unsigned xmmload(tym_t tym, bool aligned)
{   unsigned op;
    if (tysize(tym) == 32)
        aligned = false;
    switch (tybasic(tym))
    {
        case TYuint:
        case TYint:
        case TYlong:
        case TYulong:   op = LODD;  break;       // MOVD
        case TYfloat:
        case TYcfloat:
        case TYifloat:  op = LODSS; break;       // MOVSS
        case TYllong:
        case TYullong:  op = LODQ;  break;       // MOVQ
        case TYdouble:
        case TYcdouble:
        case TYidouble: op = LODSD; break;       // MOVSD

        case TYfloat8:
        case TYfloat4:  op = aligned ? LODAPS : LODUPS; break;      // MOVAPS / MOVUPS
        case TYdouble4:
        case TYdouble2: op = aligned ? LODAPD : LODUPD; break;      // MOVAPD / MOVUPD
        case TYschar16:
        case TYuchar16:
        case TYshort8:
        case TYushort8:
        case TYlong4:
        case TYulong4:
        case TYllong2:
        case TYullong2:
        case TYschar32:
        case TYuchar32:
        case TYshort16:
        case TYushort16:
        case TYlong8:
        case TYulong8:
        case TYllong4:
        case TYullong4: op = aligned ? LODDQA : LODDQU; break;      // MOVDQA / MOVDQU

        default:
            printf("tym = x%x\n", tym);
            assert(0);
    }
    return op;
}

/*****************************
 * Get correct store operator based on type.
 */

unsigned xmmstore(tym_t tym, bool aligned)
{   unsigned op;
    switch (tybasic(tym))
    {
        case TYuint:
        case TYint:
        case TYlong:
        case TYulong:   op = STOD;  break;       // MOVD
        case TYfloat:
        case TYifloat:  op = STOSS; break;       // MOVSS
        case TYllong:
        case TYullong:  op = STOQ;  break;       // MOVQ
        case TYdouble:
        case TYidouble:
        case TYcdouble:
        case TYcfloat:  op = STOSD; break;       // MOVSD

        case TYfloat8:
        case TYfloat4:  op = aligned ? STOAPS : STOUPS; break;      // MOVAPS / MOVUPS
        case TYdouble4:
        case TYdouble2: op = aligned ? STOAPD : STOUPD; break;      // MOVAPD / MOVUPD
        case TYschar16:
        case TYuchar16:
        case TYshort8:
        case TYushort8:
        case TYlong4:
        case TYulong4:
        case TYllong2:
        case TYullong2:
        case TYschar32:
        case TYuchar32:
        case TYshort16:
        case TYushort16:
        case TYlong8:
        case TYulong8:
        case TYllong4:
        case TYullong4: op = aligned ? STODQA : STODQU; break;      // MOVDQA / MOVDQU

        default:
            printf("tym = x%x\n", tym);
            assert(0);
    }
    return op;
}


/************************************
 * Get correct XMM operator based on type and operator.
 */

static unsigned xmmoperator(tym_t tym, unsigned oper)
{
    tym = tybasic(tym);
    unsigned op;
    switch (oper)
    {
        case OPadd:
        case OPaddass:
        case OPpostinc:
            switch (tym)
            {
                case TYfloat:
                case TYifloat:  op = ADDSS;  break;
                case TYdouble:
                case TYidouble: op = ADDSD;  break;

                // SIMD vector types
                case TYfloat8:
                case TYfloat4:  op = ADDPS;  break;
                case TYdouble4:
                case TYdouble2: op = ADDPD;  break;
                case TYschar32:
                case TYuchar32:
                case TYschar16:
                case TYuchar16: op = PADDB;  break;
                case TYshort16:
                case TYushort16:
                case TYshort8:
                case TYushort8: op = PADDW;  break;
                case TYlong8:
                case TYulong8:
                case TYlong4:
                case TYulong4:  op = PADDD;  break;
                case TYllong4:
                case TYullong4:
                case TYllong2:
                case TYullong2: op = PADDQ;  break;

                default:
                    printf("tym = x%x\n", tym);
                    assert(0);
            }
            break;

        case OPmin:
        case OPminass:
        case OPpostdec:
            switch (tym)
            {
                case TYfloat:
                case TYifloat:  op = SUBSS;  break;
                case TYdouble:
                case TYidouble: op = SUBSD;  break;

                // SIMD vector types
                case TYfloat8:
                case TYfloat4:  op = SUBPS;  break;
                case TYdouble4:
                case TYdouble2: op = SUBPD;  break;
                case TYschar32:
                case TYuchar32:
                case TYschar16:
                case TYuchar16: op = PSUBB;  break;
                case TYshort16:
                case TYushort16:
                case TYshort8:
                case TYushort8: op = PSUBW;  break;
                case TYlong8:
                case TYulong8:
                case TYlong4:
                case TYulong4:  op = PSUBD;  break;
                case TYllong4:
                case TYullong4:
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
                case TYfloat8:
                case TYfloat4:  op = MULPS;  break;
                case TYdouble4:
                case TYdouble2: op = MULPD;  break;
                case TYshort16:
                case TYushort16:
                case TYshort8:
                case TYushort8: op = PMULLW; break;
                case TYlong8:
                case TYulong8:
                case TYlong4:
                case TYulong4:  op = PMULLD; break;

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
                case TYfloat8:
                case TYfloat4:  op = DIVPS;  break;
                case TYdouble4:
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
                case TYullong2:
                case TYschar32:
                case TYuchar32:
                case TYshort16:
                case TYushort16:
                case TYlong8:
                case TYulong8:
                case TYllong4:
                case TYullong4: op = POR; break;

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
                case TYullong2:
                case TYschar32:
                case TYuchar32:
                case TYshort16:
                case TYushort16:
                case TYlong8:
                case TYulong8:
                case TYllong4:
                case TYullong4: op = PAND; break;

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
                case TYullong2:
                case TYschar32:
                case TYuchar32:
                case TYshort16:
                case TYushort16:
                case TYlong8:
                case TYulong8:
                case TYllong4:
                case TYullong4: op = PXOR; break;

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

void cdvector(CodeBuilder& cdb, elem *e, regm_t *pretregs)
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
        for (int i = 0; i < n; i++)
        {
            codelem(cdb,params[i], pretregs, FALSE);
            *pretregs = 0;      // in case they got set
        }
        return;
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
    if (n == 3 && ty2 == TYuchar && op2->Eoper == OPconst)
    {   // Handle: op xmm,imm8

        retregs = *pretregs & XMMREGS;
        if (!retregs)
            retregs = XMMREGS;
        codelem(cdb,op1,&retregs,FALSE); // eval left leaf
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
        getregs(cdb,retregs);
        cdb.genc2(op,modregrmx(3,r,reg-XMM0), el_tolong(op2));
    }
    else if (n == 2)
    {   /* Handle: op xmm,mem
         * where xmm is written only, not read
         */
        code cs;

        if ((op1->Eoper == OPind && !op1->Ecount) || op1->Eoper == OPvar)
        {
            getlvalue(cdb,&cs, op1, RMload);     // get addressing mode
        }
        else
        {
            regm_t rretregs = XMMREGS;
            codelem(cdb,op1, &rretregs, FALSE);
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
        allocreg(cdb,&retregs, &reg, e->Ety);
        code_newreg(&cs, reg - XMM0);
        cs.Iop = op;
        cdb.gen(&cs);
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
        codelem(cdb,op1,&retregs,FALSE); // eval left leaf
        unsigned reg = findreg(retregs);

        if ((op2->Eoper == OPind && !op2->Ecount) || op2->Eoper == OPvar)
        {
            getlvalue(cdb,&cs, op2, RMload | retregs);     // get addressing mode
        }
        else
        {
            unsigned rretregs = XMMREGS & ~retregs;
            scodelem(cdb, op2, &rretregs, retregs, TRUE);
            unsigned rreg = findreg(rretregs) - XMM0;
            cs.Irm = modregrm(3,0,rreg & 7);
            cs.Iflags = 0;
            cs.Irex = 0;
            if (rreg & 8)
                cs.Irex |= REX_B;
        }

        getregs(cdb,retregs);
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
        cdb.gen(&cs);
    }
    else
        assert(0);
    fixresult(cdb,e,retregs,pretregs);
    free(params);
    freenode(e);
}

/***************
 * Generate code for vector "store" operations.
 * The tree e must look like:
 *  (op1 OPvecsto (op OPparam op2))
 * where op is the store instruction STOxxxx.
 */
void cdvecsto(CodeBuilder& cdb, elem *e, regm_t *pretregs)
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
    xmmeq(cdb, e, op, op1, op2, pretregs);
}

/***************
 * Generate code for OPvecfill (broadcast).
 * OPvecfill takes the single value in e1 and
 * fills the vector type with it.
 */
void cdvecfill(CodeBuilder& cdb, elem *e, regm_t *pretregs)
{
    //printf("cdvecfill(e = %p, *pretregs = %s)\n",e,regm_str(*pretregs));

    regm_t retregs = *pretregs & XMMREGS;
    if (!retregs)
        retregs = XMMREGS;

    code *c;
    code cs;

    elem *e1 = e->E1;
#if 0
    if ((e1->Eoper == OPind && !e1->Ecount) || e1->Eoper == OPvar)
    {
        cr = getlvalue(&cs, e1, RMload | retregs);     // get addressing mode
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
#endif

    unsigned reg;
    unsigned rreg;
    unsigned varreg;
    regm_t varregm;
    tym_t ty = tybasic(e->Ety);
    switch (ty)
    {
        case TYfloat4:
        case TYfloat8:
            if (config.avx && e1->Eoper == OPind && !e1->Ecount)
            {
                // VBROADCASTSS X/YMM,MEM
                getlvalue(cdb,&cs, e1, 0);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                allocreg(cdb,&retregs,&reg,ty);
                cs.Iop = VBROADCASTSS;
                cs.Irex &= ~REX_W;
                code_newreg(&cs,reg - XMM0);
                checkSetVex(&cs,ty);
                cdb.gen(&cs);
            }
            else
            {
                codelem(cdb,e1,&retregs,FALSE); // eval left leaf
                reg = findreg(retregs) - XMM0;
                getregs(cdb,retregs);
                if (config.avx >= 2)
                {
                    // VBROADCASTSS X/YMM,XMM
                    cdb.gen2(VBROADCASTSS, modregxrmx(3,reg,reg));
                    checkSetVex(cdb.last(), ty);
                }
                else
                {
                    // (V)SHUFPS XMM,XMM,0
                    cdb.genc2(SHUFPS, modregxrmx(3,reg,reg), 0);
                    checkSetVex(cdb.last(), ty);
                    if (tysize(ty) == 32)
                    {
                        // VINSERTF128 YMM,YMM,XMM,1
                        cdb.genc2(VINSERTF128, modregxrmx(3,reg,reg), 1);
                        checkSetVex(cdb.last(), ty);
                    }
                }
            }
            break;

        case TYdouble2:
        case TYdouble4:
            if (config.avx && tysize(ty) == 32 && e1->Eoper == OPind && !e1->Ecount)
            {
                // VBROADCASTSD YMM,MEM
                getlvalue(cdb,&cs, e1, 0);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                allocreg(cdb,&retregs,&reg,ty);
                cs.Iop = VBROADCASTSD;
                cs.Irex &= ~REX_W;
                code_newreg(&cs,reg - XMM0);
                checkSetVex(&cs,ty);
                cdb.gen(&cs);
            }
            else
            {
                codelem(cdb,e1,&retregs,FALSE); // eval left leaf
                reg = findreg(retregs) - XMM0;
                getregs(cdb,retregs);
                if (config.avx >= 2 && tysize(ty) == 32)
                {
                    // VBROADCASTSD YMM,XMM
                    cdb.gen2(VBROADCASTSD, modregxrmx(3,reg,reg));
                    checkSetVex(cdb.last(), ty);
                }
                else
                {
                    // (V)UNPCKLPD XMM,XMM
                    cdb.gen2(UNPCKLPD, modregxrmx(3,reg,reg));
                    checkSetVex(cdb.last(), TYdouble2); // AVX-128
                    if (tysize(ty) == 32)
                    {
                        // VINSERTF128 YMM,YMM,XMM,1
                        cdb.genc2(VINSERTF128, modregxrmx(3,reg,reg), 1);
                        checkSetVex(cdb.last(), ty);
                    }
                }
            }
            break;

        case TYschar16:
        case TYuchar16:
        case TYschar32:
        case TYuchar32:
            if (config.avx >= 2 && e1->Eoper == OPind && !e1->Ecount)
            {
                // VPBROADCASTB X/YMM,MEM
                getlvalue(cdb,&cs, e1, 0);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                allocreg(cdb,&retregs,&reg,ty);
                cs.Iop = VPBROADCASTB;
                cs.Irex &= ~REX_W;
                code_newreg(&cs,reg - XMM0);
                checkSetVex(&cs,ty);
                cdb.gen(&cs);
            }
            else
            {
                regm_t regm = ALLREGS;
                codelem(cdb,e1,&regm,FALSE); // eval left leaf
                unsigned r = findreg(regm);

                allocreg(cdb,&retregs,&reg, e->Ety);
                reg -= XMM0;
                // (V)MOVD reg,r
                cdb.gen2(LODD,modregxrmx(3,reg,r));
                checkSetVex(cdb.last(), TYushort8);
                if (config.avx >= 2)
                {
                    // VPBROADCASTB X/YMM,XMM
                    cdb.gen2(VPBROADCASTB, modregxrmx(3,reg,reg));
                    checkSetVex(cdb.last(), ty);
                }
                else
                {
                    if (config.avx)
                    {
                        unsigned zeroreg;
                        regm = XMMREGS & ~retregs;
                        // VPXOR XMM1,XMM1,XMM1
                        allocreg(cdb,&regm,&zeroreg, ty);
                        zeroreg -= XMM0;
                        cdb.gen2(PXOR, modregxrmx(3,zeroreg,zeroreg));
                        checkSetVex(cdb.last(), TYuchar16); // AVX-128
                        // VPSHUFB XMM,XMM,XMM1
                        cdb.gen2(PSHUFB, modregxrmx(3,reg,zeroreg));
                        checkSetVex(cdb.last(), TYuchar16); // AVX-128
                    }
                    else
                    {
                        // PUNPCKLBW XMM,XMM
                        cdb.gen2(PUNPCKLBW, modregxrmx(3,reg,reg));
                        // PUNPCKLWD XMM,XMM
                        cdb.gen2(PUNPCKLWD, modregxrmx(3,reg,reg));
                        // PSHUFD XMM,XMM,0
                        cdb.genc2(PSHUFD, modregxrmx(3,reg,reg), 0);
                    }
                    if (tysize(ty) == 32)
                    {
                        // VINSERTF128 YMM,YMM,XMM,1
                        cdb.genc2(VINSERTF128, modregxrmx(3,reg,reg), 1);
                        checkSetVex(cdb.last(), ty);
                    }
                }
            }
            break;

        case TYshort8:
        case TYushort8:
        case TYshort16:
        case TYushort16:
            if (config.avx >= 2 && e1->Eoper == OPind && !e1->Ecount)
            {
                // VPBROADCASTW X/YMM,MEM
                getlvalue(cdb,&cs, e1, 0);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                allocreg(cdb,&retregs,&reg,ty);
                cs.Iop = VPBROADCASTW;
                cs.Irex &= ~REX_W;
                cs.Iflags &= ~CFopsize;
                code_newreg(&cs,reg - XMM0);
                checkSetVex(&cs,ty);
                cdb.gen(&cs);
            }
            else
            {
                regm_t regm = ALLREGS;
                codelem(cdb,e1,&regm,FALSE); // eval left leaf
                unsigned r = findreg(regm);

                allocreg(cdb,&retregs,&reg, e->Ety);
                reg -= XMM0;
                // (V)MOVD reg,r
                cdb.gen2(LODD,modregxrmx(3,reg,r));
                checkSetVex(cdb.last(), TYushort8);
                if (config.avx >= 2)
                {
                    // VPBROADCASTW X/YMM,XMM
                    cdb.gen2(VPBROADCASTW, modregxrmx(3,reg,reg));
                    checkSetVex(cdb.last(), ty);
                }
                else
                {
                    // (V)PUNPCKLWD XMM,XMM
                    cdb.gen2(PUNPCKLWD, modregxrmx(3,reg,reg));
                    checkSetVex(cdb.last(), TYushort8); // AVX-128
                    // (V)PSHUFD XMM,XMM,0
                    cdb.genc2(PSHUFD, modregxrmx(3,reg,reg), 0);
                    checkSetVex(cdb.last(), TYushort8); // AVX-128
                    if (tysize(ty) == 32)
                    {
                        // VINSERTF128 YMM,YMM,XMM,1
                        cdb.genc2(VINSERTF128, modregxrmx(3,reg,reg), 1);
                        checkSetVex(cdb.last(), ty);
                    }
                }
            }
            break;

        case TYlong8:
        case TYulong8:
        case TYlong4:
        case TYulong4:
            if (config.avx && e1->Eoper == OPind && !e1->Ecount)
            {
                // VPBROADCASTD/VBROADCASTSS X/YMM,MEM
                getlvalue(cdb,&cs, e1, 0);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                allocreg(cdb,&retregs,&reg,ty);
                cs.Iop = config.avx >= 2 ? VPBROADCASTD : VBROADCASTSS;
                cs.Irex &= ~REX_W;
                code_newreg(&cs,reg - XMM0);
                checkSetVex(&cs,ty);
                cdb.gen(&cs);
            }
            else
            {
                codelem(cdb,e1,&retregs,FALSE); // eval left leaf
                reg = findreg(retregs) - XMM0;
                getregs(cdb,retregs);
                if (config.avx >= 2)
                {
                    // VPBROADCASTD X/YMM,XMM
                    cdb.gen2(VPBROADCASTD, modregxrmx(3,reg,reg));
                    checkSetVex(cdb.last(), ty);
                }
                else
                {
                    // (V)PSHUFD XMM,XMM,0
                    cdb.genc2(PSHUFD, modregxrmx(3,reg,reg), 0);
                    checkSetVex(cdb.last(), TYulong4); // AVX-128
                    if (tysize(ty) == 32)
                    {
                        // VINSERTF128 YMM,YMM,XMM,1
                        cdb.genc2(VINSERTF128, modregxrmx(3,reg,reg), 1);
                        checkSetVex(cdb.last(), ty);
                    }
                }
            }
            break;

        case TYllong2:
        case TYullong2:
        case TYllong4:
        case TYullong4:
            if (e1->Eoper == OPind && !e1->Ecount)
            {
                // VPBROADCASTQ/VBROADCASTSD/(V)PUNPCKLQDQ X/YMM,MEM
                getlvalue(cdb,&cs, e1, 0);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                allocreg(cdb,&retregs,&reg,ty);
                cs.Iop = config.avx >= 2 ? VPBROADCASTQ : tysize(ty) == 32 ? VBROADCASTSD : PUNPCKLQDQ;
                cs.Irex &= ~REX_W;
                code_newreg(&cs,reg - XMM0);
                checkSetVex(&cs,ty);
                cdb.gen(&cs);
            }
            else
            {
                codelem(cdb,e1,&retregs,FALSE); // eval left leaf
                reg = findreg(retregs) - XMM0;
                getregs(cdb,retregs);
                if (config.avx >= 2)
                {
                    // VPBROADCASTQ X/YMM,XMM
                    cdb.gen2(VPBROADCASTQ, modregxrmx(3,reg,reg));
                    checkSetVex(cdb.last(), ty);
                }
                else
                {
                    // (V)PUNPCKLQDQ XMM,XMM
                    cdb.genc2(PUNPCKLQDQ, modregxrmx(3,reg,reg), 0);
                    checkSetVex(cdb.last(), TYullong2); // AVX-128
                    if (tysize(ty) == 32)
                    {
                        // VINSERTF128 YMM,YMM,XMM,1
                        cdb.genc2(VINSERTF128, modregxrmx(3,reg,reg), 1);
                        checkSetVex(cdb.last(), ty);
                    }
                }
            }
            break;

        default:
            assert(0);
    }

    fixresult(cdb,e,retregs,pretregs);
}

/*******************************************
 * Determine if lvalue e is a vector aligned on a 16/32 byte boundary.
 * Assume it to be aligned unless can prove it is not.
 * Params:
 *      e = lvalue
 * Returns:
 *      false if definitely not aligned
 */

bool xmmIsAligned(elem *e)
{
    if (tyvector(e->Ety) && e->Eoper == OPvar)
    {
        Symbol *s = e->EV.sp.Vsym;
        if (s->Salignsize() < 16 ||
            e->EV.sp.Voffset & (16 - 1) ||
            tysize(e->Ety) > STACKALIGN
           )
            return false;       // definitely not aligned
    }
    return true;        // assume aligned
}

/**************************************
 * VEX prefixes can be 2 or 3 bytes.
 * If it must be 3 bytes, set the CFvex3 flag.
 */

void checkSetVex3(code *c)
{
    // See Intel Vol. 2A 2.3.5.6
    if (c->Ivex.w || !c->Ivex.x || !c->Ivex.b || c->Ivex.mmmm > 0x1 ||
        !I64 && (c->Ivex.r || !(c->Ivex.vvvv & 8))
       )
    {
        c->Iflags |= CFvex3;
    }
}

/*************************************
 * Determine if operation should be rewritten as a VEX
 * operation; and do so.
 * Params:
 *      c = code
 *      ty = type of operand
 */

void checkSetVex(code *c, tym_t ty)
{
    if (config.avx || tysize(ty) == 32)
    {
        unsigned vreg = (c->Irm >> 3) & 7;
        if (c->Irex & REX_R)
            vreg |= 8;

        // TODO: This is too simplistic, depending on the instruction, vex.vvvv
        // encodes NDS, NDD, DDS, or no operand (NOO). The code below assumes
        // NDS (non-destructive source), except for the incomplete list of 2
        // operand instructions (NOO) handled by the switch.
        switch (c->Iop)
        {
            case LODSS:
            case LODSD:
            case STOSS:
            case STOSD:
                if ((c->Irm & 0xC0) == 0xC0)
                    break;
            case LODAPS:
            case LODUPS:
            case LODAPD:
            case LODUPD:
            case LODDQA:
            case LODDQU:
            case LODD:
            case LODQ:
            case STOAPS:
            case STOUPS:
            case STOAPD:
            case STOUPD:
            case STODQA:
            case STODQU:
            case STOD:
            case STOQ:
            case COMISS:
            case COMISD:
            case UCOMISS:
            case UCOMISD:
            case MOVDDUP:
            case MOVSHDUP:
            case MOVSLDUP:
            case VBROADCASTSS:
            case PSHUFD:
            case PSHUFHW:
            case PSHUFLW:
            case VPBROADCASTB:
            case VPBROADCASTW:
            case VPBROADCASTD:
            case VPBROADCASTQ:
                vreg = 0;       // for 2 operand vex instructions
                break;

            case VBROADCASTSD:
            case VBROADCASTF128:
            case VBROADCASTI128:
                assert(tysize(ty) == 32); // AVX-256 only instructions
                vreg = 0;       // for 2 operand vex instructions
                break;
        }

        unsigned op = 0xC4000000 | (c->Iop & 0xFF);
        switch (c->Iop & 0xFFFFFF00)
        {
            #define MM_PP(mm, pp) ((mm << 16) | (pp << 8))
            case 0x00000F00: op |= MM_PP(1,0); break;
            case 0x00660F00: op |= MM_PP(1,1); break;
            case 0x00F30F00: op |= MM_PP(1,2); break;
            case 0x00F20F00: op |= MM_PP(1,3); break;
            case 0x660F3800: op |= MM_PP(2,1); break;
            case 0x660F3A00: op |= MM_PP(3,1); break;
            default:
                printf("Iop = %x\n", c->Iop);
                assert(0);
            #undef MM_PP
        }
        c->Iop = op;
        c->Ivex.pfx = 0xC4;
        c->Ivex.r = !(c->Irex & REX_R);
        c->Ivex.x = !(c->Irex & REX_X);
        c->Ivex.b = !(c->Irex & REX_B);
        c->Ivex.w = (c->Irex & REX_W) != 0;
        c->Ivex.l = tysize(ty) == 32;

        c->Ivex.vvvv = ~vreg;

        c->Iflags |= CFvex;
        checkSetVex3(c);
    }
}

#endif // !SPP
