/**
 * xmm specific code generation
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2011-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/x86/cgxmm.d, backend/cgxmm.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_x86_cgxmm.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/x86/cgxmm.d
 */

module dmd.backend.x86.cgxmm;

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
import dmd.backend.x86.xmm;


nothrow:
@safe:

/*******************************************
 * Is operator a store operator?
 */

bool isXMMstore(opcode_t op)
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
 * Params:
 *      cdb = generated code appends to this
 *      xreg = XMM register to load
 *      sz = number of bytes to load
 *      pev = pointer to const value
 *      flags = if set flags based on value
 */

@trusted
void movxmmconst(ref CodeBuilder cdb, reg_t xreg, tym_t ty, Vconst* pev, regm_t flags)
{
    //printf("movxmmconst() %s ty: %s value: %lld\n", regm_str(mask(xreg)), tym_str(ty), pev.Vllong);

    const sz = tysize(ty);
    assert(mask(xreg) & XMMREGS);
    if (sz == 16 || sz == 32)
    {
        if (sz == 16 &&
                 pev.Vllong2[0] == 0 && pev.Vllong2[1] == 0)
            cdb.gen2(PXOR,modregxrmx(3,xreg-XMM0,xreg-XMM0));       // PXOR xreg,xreg
        else if (sz == 32 &&
                 pev.Vllong4[0] == 0 && pev.Vllong4[1] == 0 &&
                 pev.Vllong4[2] == 0 && pev.Vllong4[3] == 0)
            cdb.gen2(PXOR,modregxrmx(3,xreg-XMM0,xreg-XMM0));       // PXOR xreg,xreg
        else if (sz == 16 &&
                 pev.Vllong2[0] == ~0 && pev.Vllong2[1] == ~0)
            cdb.gen2(PCMPEQD,modregxrmx(3,xreg-XMM0,xreg-XMM0));    // PCMPEQD xreg,xreg
        else if (sz == 32 &&
                 pev.Vllong4[0] == ~0 && pev.Vllong4[1] == ~0 &&
                 pev.Vllong4[2] == ~0 && pev.Vllong4[3] == ~0)
            cdb.gen2(PCMPEQQ,modregxrmx(3,xreg-XMM0,xreg-XMM0));    // PCMPEQQ xreg,xreg
        else
            assert(0);
        tym_t tyx = sz == 16 ? TYllong2 : TYllong4;
        checkSetVex(cdb.last(), tyx);
        return;
    }

    /* Generate:
     *    MOV reg,value
     *    MOV xreg,reg
     */
    assert(sz == 4 || sz == 8);
    targ_size_t value = pev.Vint;
    if (sz == 8)
        value = cast(targ_size_t)pev.Vullong;

    if (value == 0)
    {
        if (ty == TYfloat || ty == TYifloat)
        {
            cdb.gen2(XORPS,modregxrmx(3,xreg-XMM0,xreg-XMM0));       // XORPS xreg,xreg
            return;
        }
        else if (ty == TYdouble || ty == TYidouble)
        {
            cdb.gen2(XORPD,modregxrmx(3,xreg-XMM0,xreg-XMM0));       // XORPD xreg,xreg
            return;
        }
    }


    if (I32 && sz == 8)
    {
        regm_t rm = ALLREGS;
        const r = allocreg(cdb,rm,TYint);         // allocate scratch register
        static union U { targ_size_t s; targ_long[2] l; }
        U u;
        u.l[1] = 0;
        u.s = value;
        targ_long* p = &u.l[0];
        movregconst(cdb,r,p[0],0);
        cdb.genfltreg(STO,r,0);                     // MOV floatreg,r
        movregconst(cdb,r,p[1],0);
        cdb.genfltreg(STO,r,4);                     // MOV floatreg+4,r

        const op = xmmload(TYdouble, true);
        cdb.genxmmreg(op,xreg,0,TYdouble);          // MOVSD XMMreg,floatreg
    }
    else
    {
        const reg = regwithvalue(cdb,ALLREGS,value,(sz == 8) ? 64 : 0);
        cdb.gen2(LODD,modregxrmx(3,xreg-XMM0,reg));     // MOVD xreg,reg
        if (sz == 8)
            code_orrex(cdb.last(), REX_W);
        checkSetVex(cdb.last(), TYulong);
    }
}

/***********************************************
 * Do simple orthogonal operators for XMM registers.
 */
@trusted
void orthxmm(ref CodeBuilder cdb, elem* e, ref regm_t pretregs)
{
    //printf("orthxmm(e = %p, pretregs = %s)\n", e, regm_str(pretregs));
    elem* e1 = e.E1;
    elem* e2 = e.E2;

    // float + ifloat is not actually addition
    if ((e.Eoper == OPadd || e.Eoper == OPmin) &&
        ((tyreal(e1.Ety) && tyimaginary(e2.Ety)) ||
         (tyreal(e2.Ety) && tyimaginary(e1.Ety))))
    {
        regm_t retregs = pretregs & XMMREGS;
        if (!retregs)
            retregs = XMMREGS;

        regm_t rretregs;
        reg_t rreg;
        if (tyreal(e1.Ety))
        {
            const reg = findreg(retregs);
            rreg = findreg(retregs & ~mask(reg));
            retregs = mask(reg);
            rretregs = mask(rreg);
        }
        else
        {
            // Pick the second register, not the first
            rreg = findreg(retregs);
            rretregs = mask(rreg);
            const reg = findreg(retregs & ~rretregs);
            retregs = mask(reg);
        }
        assert(retregs && rretregs);

        codelem(cgstate,cdb,e1,retregs,false); // eval left leaf
        scodelem(cgstate,cdb, e2, rretregs, retregs, true);  // eval right leaf

        retregs |= rretregs;
        if (e.Eoper == OPmin)
        {
            regm_t nretregs = XMMREGS & ~retregs;
            const sreg = allocreg(cdb,nretregs,e2.Ety); // hold sign bit
            const uint sz = tysize(e1.Ety);
            Vconst signbit;
            signbit.Vint = 0x80000000;
            if (sz == 8)
                signbit.Vllong = 0x8000_0000_0000_0000;
            movxmmconst(cdb,sreg, e1.Ety, &signbit, 0);
            getregs(cdb,nretregs);
            const opcode_t xop = (sz == 8) ? XORPD : XORPS;       // XORPD/S rreg,sreg
            cdb.gen2(xop,modregxrmx(3,rreg-XMM0,sreg-XMM0));
        }
        if (retregs != pretregs)
            fixresult(cdb,e,retregs,pretregs);
        return;
    }

    regm_t retregs = pretregs & XMMREGS;
    if (!retregs)
        retregs = XMMREGS;
    const constflag = OTrel(e.Eoper);
    codelem(cgstate,cdb,e1,retregs,constflag); // eval left leaf
    const reg = findreg(retregs);
    regm_t rretregs = XMMREGS & ~retregs;
    scodelem(cgstate,cdb, e2, rretregs, retregs, true);  // eval right leaf

    const rreg = findreg(rretregs);
    const op = xmmoperator(e1.Ety, e.Eoper);

    /* We should take advantage of mem addressing modes for OP XMM,MEM
     * but we do not at the moment.
     */
    if (OTrel(e.Eoper) && !tyvector(tybasic(e.Ety)))
    {
        cdb.gen2(op,modregxrmx(3,rreg-XMM0,reg-XMM0));
        checkSetVex(cdb.last(), e1.Ety);
        return;
    }

    getregs(cdb,retregs);
    cdb.gen2(op,modregxrmx(3,reg-XMM0,rreg-XMM0));
    if (op == CMPPS || op == CMPPD)
    {
        // https://www.felixcloutier.com/x86/cmpps
        ubyte imm8;
        switch (e.Eoper)
        {
            case OPeqeq: imm8 = 0; break;
            case OPlt:   imm8 = 1; break;
            case OPle:   imm8 = 2; break;
            case OPne:   imm8 = 4; break;
            default:
                elem_print(e);
                assert(0);  // not doing the unordered compares
        }
        code* c = cdb.last();
        c.IFL2 = FL.const_;
        c.IEV2.Vsize_t = imm8;
    }
    checkSetVex(cdb.last(), e1.Ety);
    if (retregs != pretregs)
        fixresult(cdb,e,retregs,pretregs);
}


/************************
 * Generate code for an assignment using XMM registers.
 * Params:
 *      opcode = store opcode to use, CMP means generate one
 */
@trusted
void xmmeq(ref CodeBuilder cdb, elem* e, opcode_t op, elem* e1, elem* e2,ref regm_t pretregs)
{
    tym_t tymll;
    int i;
    code cs;
    elem* e11;
    bool regvar;                  /* true means evaluate into register variable */
    targ_int postinc;

    //printf("xmmeq(e1 = %p, e2 = %p, pretregs = %s)\n", e1, e2, regm_str(pretregs));
    tym_t tyml = tybasic(e1.Ety);              /* type of lvalue               */
    regm_t retregs = pretregs;

    if (!(retregs & XMMREGS))
        retregs = XMMREGS;              // pick any XMM reg

    bool aligned = xmmIsAligned(e1);
    // If default, select store opcode
    cs.Iop = (op == CMP) ? xmmstore(tyml, aligned) : op;
    regvar = false;
    regm_t varregm = 0;
    if (config.flags4 & CFG4optimized)
    {
        // Be careful of cases like (x = x+x+x). We cannot evaluate in
        // x if x is in a register.
        reg_t varreg;
        if (isregvar(e1, varregm, varreg) &&    // if lvalue is register variable
            doinreg(e1.Vsym,e2) &&           // and we can compute directly into it
            varregm & XMMREGS
           )
        {   regvar = true;
            retregs = varregm;    // evaluate directly in target register
        }
        else
            varregm = 0;
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
        e11.E1.Vsym.Sfl == FL.reg
       )
    {
        postinc = e11.E2.Vint;
        if (e11.Eoper == OPpostdec)
            postinc = -postinc;
        getlvalue(cdb,cs,e11,retregs,RM.store);
        freenode(e11.E2);
    }
    else
    {   postinc = 0;
        getlvalue(cdb,cs,e1,retregs,RM.store);       // get lvalue (cl == CNIL if regvar)
    }

    getregs_imm(cdb,regvar ? varregm : 0);

    const reg = findreg(retregs & XMMREGS);
    cs.Irm |= modregrm(0,(reg - XMM0) & 7,0);
    if ((reg - XMM0) & 8)
        cs.Irex |= REX_R;

    // Do not generate mov from register onto itself
    if (!(regvar && reg == XMM0 + ((cs.Irm & 7) | (cs.Irex & REX_B ? 8 : 0))))
    {
        cdb.gen(&cs);         // MOV EA+offset,reg
        checkSetVex(cdb.last(), tyml);
    }

    if (e1.Ecount ||                     // if lvalue is a CSE or
        regvar)                           // rvalue can't be a CSE
    {
        getregs_imm(cdb,retregs);        // necessary if both lvalue and
                                        //  rvalue are CSEs (since a reg
                                        //  can hold only one e at a time)
        cssave(e1,retregs,!OTleaf(e1.Eoper));     // if lvalue is a CSE
    }

    fixresult(cdb,e,retregs,pretregs);
    if (postinc)
    {
        const increg = findreg(idxregm(&cs));  // the register to increment
        if (pretregs & mPSW)
        {   // Use LEA to avoid touching the flags
            uint rm = cs.Irm & 7;
            if (cs.Irex & REX_B)
                rm |= 8;
            cdb.genc1(LEA,buildModregrm(2,increg,rm),FL.const_,postinc);
            if (tysize(e11.E1.Ety) == 8)
                code_orrex(cdb.last(), REX_W);
        }
        else if (I64)
        {
            cdb.genc2(0x81,modregrmx(3,0,increg),postinc);
            if (tysize(e11.E1.Ety) == 8)
                code_orrex(cdb.last(), REX_W);
        }
        else
        {
            if (postinc == 1)
                cdb.gen1(0x40 + increg);       // INC increg
            else if (postinc == -cast(targ_int)1)
                cdb.gen1(0x48 + increg);       // DEC increg
            else
            {
                cdb.genc2(0x81,modregrm(3,0,increg),postinc);
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
@trusted
void xmmcnvt(ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("xmmconvt: %p, %s\n", e, regm_str(pretregs));
    opcode_t op = NoOpcode;
    regm_t regs;
    tym_t ty;
    ubyte rex = 0;
    bool zx = false; // zero extend uint

    /* There are no ops for integer <. float/real conversions
     * but there are instructions for them. In order to use these
     * try to fuse chained conversions. Be careful not to loose
     * precision for real to long.
     */
    elem* e1 = e.E1;
    switch (e.Eoper)
    {
    case OPd_f:
        if (e1.Eoper == OPs32_d)
        { }
        else if (I64 && e1.Eoper == OPs64_d)
            rex = REX_W;
        else if (I64 && e1.Eoper == OPu32_d)
        {   rex = REX_W;
            zx = true;
        }
        else
        {   regs = XMMREGS;
            op = CVTSD2SS;
            ty = TYfloat;
            break;
        }
        if (e1.Ecount)
        {
            regs = XMMREGS;
            op = CVTSD2SS;
            ty = TYfloat;
            break;
        }
        // directly use si2ss
        regs = ALLREGS;
        e1 = e1.E1;  // fused operation
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

    case OPd_s16:
    case OPd_s32: ty = TYint;  goto Ldtoi;
    case OPd_u32: ty = TYlong; if (I64) rex = REX_W; goto Ldtoi;
    case OPd_s64: ty = TYlong; rex = REX_W; goto Ldtoi;
    Ldtoi:
        regs = XMMREGS;
        switch (e1.Eoper)
        {
        case OPf_d:
            if (e1.Ecount)
            {
                op = CVTTSD2SI;
                break;
            }
            e1 = e1.E1;      // fused operation
            op = CVTTSS2SI;
            break;
        case OPld_d:
            if (e.Eoper == OPd_s64)
            {
                cnvt87(cdb,e,pretregs); // precision
                return;
            }
            goto default;

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

    default:
        assert(0);
    }
    assert(op != NoOpcode);

    codelem(cgstate,cdb,e1, regs, false);
    reg_t reg = findreg(regs);
    if (isXMMreg(reg))
        reg -= XMM0;
    else if (zx)
    {   assert(I64);
        getregs(cdb,regs);
        genregs(cdb,0x8B,reg,reg); // MOV reg,reg to zero upper 32-bit
                                   // Don't use x89 because that will get optimized away
        code_orflag(cdb.last(),CFvolatile);
    }

    regm_t retregs = pretregs;
    if (tyxmmreg(ty)) // target is XMM
    {   if (!(pretregs & XMMREGS))
            retregs = XMMREGS;
    }
    else              // source is XMM
    {   assert(regs & XMMREGS);
        if (!(retregs & ALLREGS))
            retregs = ALLREGS;
    }

    reg_t rreg = allocreg(cdb,retregs,ty);
    if (isXMMreg(rreg))
        rreg -= XMM0;

    cdb.gen2(op, modregxrmx(3,rreg,reg));
    assert(I64 || !rex);
    if (rex)
        code_orrex(cdb.last(), rex);

    if (pretregs != retregs)
        fixresult(cdb,e,retregs,pretregs);
}

/********************************
 * Generate code for op=
 */
@trusted
void xmmopass(ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{   elem* e1 = e.E1;
    elem* e2 = e.E2;
    tym_t ty1 = tybasic(e1.Ety);
    const sz1 = _tysize[ty1];
    regm_t rretregs = XMMREGS & ~pretregs;
    if (!rretregs)
        rretregs = XMMREGS;

    codelem(cgstate,cdb,e2,rretregs,false); // eval right leaf
    reg_t rreg = findreg(rretregs);

    code cs;
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
            doinreg(e1.Vsym,e2)          // and we can compute directly into it
           )
        {   regvar = true;
            retregs = varregm;
            reg = varreg;                       // evaluate directly in target register
            getregs(cdb,retregs);       // destroy these regs
        }
    }

    if (!regvar)
    {
        getlvalue(cdb,cs,e1,rretregs,RM.rw);         // get EA
        retregs = pretregs & XMMREGS & ~rretregs;
        if (!retregs)
            retregs = XMMREGS & ~rretregs;
        reg = allocreg(cdb,retregs,ty1);
        cs.Iop = xmmload(ty1, true);            // MOVSD xmm,xmm_m64
        code_newreg(&cs,reg - XMM0);
        cdb.gen(&cs);
        checkSetVex(cdb.last(), ty1);
    }

    const op = xmmoperator(e1.Ety, e.Eoper);
    cdb.gen2(op,modregxrmx(3,reg-XMM0,rreg-XMM0));
    checkSetVex(cdb.last(), e1.Ety);

    if (!regvar)
    {
        cs.Iop = xmmstore(ty1,true);      // reverse operand order of MOVS[SD]
        cdb.gen(&cs);
        checkSetVex(cdb.last(), ty1);
    }

    if (e1.Ecount ||                     // if lvalue is a CSE or
        regvar)                           // rvalue can't be a CSE
    {
        getregs_imm(cdb,retregs);        // necessary if both lvalue and
                                        //  rvalue are CSEs (since a reg
                                        //  can hold only one e at a time)
        cssave(e1,retregs,!OTleaf(e1.Eoper));     // if lvalue is a CSE
    }

    fixresult(cdb,e,retregs,pretregs);
    freenode(e1);
}

/********************************
 * Generate code for post increment and post decrement.
 */

@trusted
void xmmpost(ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    elem* e1 = e.E1;
    elem* e2 = e.E2;
    tym_t ty1 = tybasic(e1.Ety);

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
            doinreg(e1.Vsym,e2)          // and we can compute directly into it
           )
        {
            regvar = true;
            retregs = varregm;
            reg = varreg;                       // evaluate directly in target register
            getregs(cdb,retregs);       // destroy these regs
        }
    }

    code cs;
    if (!regvar)
    {
        getlvalue(cdb,cs,e1,0,RM.rw);                // get EA
        retregs = XMMREGS & ~pretregs;
        if (!retregs)
            retregs = XMMREGS;
        reg = allocreg(cdb,retregs,ty1);
        cs.Iop = xmmload(ty1, true);            // MOVSD xmm,xmm_m64
        code_newreg(&cs,reg - XMM0);
        cdb.gen(&cs);
        checkSetVex(cdb.last(), ty1);
    }

    // Result register
    regm_t resultregs = XMMREGS & pretregs & ~retregs;
    if (!resultregs)
        resultregs = XMMREGS & ~retregs;
    const resultreg = allocreg(cdb,resultregs, ty1);

    cdb.gen2(xmmload(ty1,true),modregxrmx(3,resultreg-XMM0,reg-XMM0));   // MOVSS/D resultreg,reg
    checkSetVex(cdb.last(), ty1);

    regm_t rretregs = XMMREGS & ~(pretregs | retregs | resultregs);
    if (!rretregs)
        rretregs = XMMREGS & ~(retregs | resultregs);
    codelem(cgstate,cdb,e2,rretregs,false); // eval right leaf
    const rreg = findreg(rretregs);

    const op = xmmoperator(e1.Ety, e.Eoper);
    cdb.gen2(op,modregxrmx(3,reg-XMM0,rreg-XMM0));  // ADD reg,rreg
    checkSetVex(cdb.last(), e1.Ety);

    if (!regvar)
    {
        cs.Iop = xmmstore(ty1,true);      // reverse operand order of MOVS[SD]
        cdb.gen(&cs);
        checkSetVex(cdb.last(), ty1);
    }

    if (e1.Ecount ||                     // if lvalue is a CSE or
        regvar)                           // rvalue can't be a CSE
    {
        getregs_imm(cdb,retregs); // necessary if both lvalue and
                                        //  rvalue are CSEs (since a reg
                                        //  can hold only one e at a time)
        cssave(e1,retregs,!OTleaf(e1.Eoper));     // if lvalue is a CSE
    }

    fixresult(cdb,e,resultregs,pretregs);
    freenode(e1);
}

/******************
 * Negate operator
 */

@trusted
void xmmneg(ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("xmmneg()\n");
    //elem_print(e);
    assert(pretregs);
    tym_t tyml = tybasic(e.E1.Ety);
    int sz = _tysize[tyml];

    regm_t retregs = pretregs & XMMREGS;
    if (!retregs)
        retregs = XMMREGS;

    /* Generate:
     *    MOV reg,e1
     *    MOV rreg,signbit
     *    XOR reg,rreg
     */
    codelem(cgstate,cdb,e.E1,retregs,false);
    getregs(cdb,retregs);
    const reg = findreg(retregs);
    regm_t rretregs = XMMREGS & ~retregs;
    const rreg = allocreg(cdb,rretregs,tyml);

    Vconst signbit;
    signbit.Vint = 0x80000000;
    if (sz == 8)
        signbit.Vllong = 0x8000_0000_0000_0000;

    movxmmconst(cdb,rreg, tyml, &signbit, 0);

    getregs(cdb,retregs);
    const op = (sz == 8) ? XORPD : XORPS;       // XORPD/S reg,rreg
    cdb.gen2(op,modregxrmx(3,reg-XMM0,rreg-XMM0));
    fixresult(cdb,e,retregs,pretregs);
}

/******************
 * Absolute value operator OPabs
 */

@trusted
void xmmabs(ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("xmmabs()\n");
    //elem_print(e);
    assert(pretregs);
    tym_t tyml = tybasic(e.E1.Ety);
    int sz = _tysize[tyml];

    regm_t retregs = pretregs & XMMREGS;
    if (!retregs)
        retregs = XMMREGS;

    /* Generate:
     *    MOV reg,e1
     *    MOV rreg,mask
     *    AND reg,rreg
     */
    codelem(cgstate,cdb,e.E1,retregs,false);
    getregs(cdb,retregs);
    const reg = findreg(retregs);
    regm_t rretregs = XMMREGS & ~retregs;
    const rreg = allocreg(cdb,rretregs,tyml);

    Vconst mask;
    mask.Vint = 0x7FFF_FFFF;
    if (sz == 8)
        mask.Vllong = 0x7FFF_FFFF_FFFF_FFFFL;
    movxmmconst(cdb, rreg, tyml, &mask, 0);

    getregs(cdb,retregs);
    const op = (sz == 8) ? ANDPD : ANDPS;       // ANDPD/S reg,rreg
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

@trusted
opcode_t xmmload(tym_t tym, bool aligned = true)
{
    opcode_t op;
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

@trusted
opcode_t xmmstore(tym_t tym, bool aligned = true)
{
    opcode_t op;
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
            printf("tym = 0x%x\n", tym);
            assert(0);
    }
    return op;
}


/************************************
 * Get correct XMM operator based on type and operator.
 */

@trusted
private opcode_t xmmoperator(tym_t tym, OPER oper)
{
    tym = tybasic(tym);
    opcode_t op;
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

        case OPgt:
            switch (tym)
            {
                case TYschar32:
                case TYuchar32:
                case TYschar16:
                case TYuchar16: op = PCMPGTB;  break;
                case TYshort16:
                case TYushort16:
                case TYshort8:
                case TYushort8: op = PCMPGTW;  break;
                case TYlong8:
                case TYulong8:
                case TYlong4:
                case TYulong4:  op = PCMPGTD;  break;
                case TYllong4:
                case TYullong4:
                case TYllong2:
                case TYullong2: op = PCMPGTQ;  break;
                default:
                    goto Lfloatcmp;
            }
            break;

        case OPeqeq:
            switch (tym)
            {
                case TYschar32:
                case TYuchar32:
                case TYschar16:
                case TYuchar16: op = PCMPEQB;  break;
                case TYshort16:
                case TYushort16:
                case TYshort8:
                case TYushort8: op = PCMPEQW;  break;
                case TYlong8:
                case TYulong8:
                case TYlong4:
                case TYulong4:  op = PCMPEQD;  break;
                case TYllong4:
                case TYullong4:
                case TYllong2:
                case TYullong2: op = PCMPEQQ;  break;
                default:
                    goto Lfloatcmp;
            }
            break;

        case OPlt:
        case OPle:
        case OPge:
        case OPne:
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
        Lfloatcmp:
            switch (tym)
            {
                case TYfloat:
                case TYifloat:  op = UCOMISS;  break;
                case TYdouble:
                case TYidouble: op = UCOMISD;  break;

                case TYfloat4:
                case TYfloat8:
                case TYfloat16: op = CMPPS;    break;

                case TYdouble2:
                case TYdouble4:
                case TYdouble8: op = CMPPD;    break;
                default:        assert(0);
            }
            break;

        default:
            assert(0);
    }
    return op;
}

@trusted
void cdvector(ref CGstate cg, ref CodeBuilder cdb, elem* e, ref regm_t pretregs)
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

    const n = el_nparams(e.E1);
    assert(n < size_t.max / (2 * (elem*).sizeof));   // conservative overflow check
    elem** params = cast(elem**)malloc(n * (elem*).sizeof);
    assert(params);
    elem** tmp = params;
    el_paramArray(&tmp, e.E1);

static if (0)
{
    printf("cdvector()\n");
    for (int i = 0; i < n; i++)
    {
        printf("[%d]: ", i);
        elem_print(params[i]);
    }
}

    if (pretregs == 0)
    {   /* Evaluate for side effects only
         */
        foreach (i; 0 .. n)
        {
            codelem(cgstate,cdb,params[i], pretregs, false);
            pretregs = 0;      // in case they got set
        }
        return;
    }

    assert(n >= 2 && n <= 4);

    elem* eop = params[0];
    elem* op1 = params[1];
    elem* op2 = null;
    tym_t ty2 = 0;
    if (n >= 3)
    {   op2 = params[2];
        ty2 = tybasic(op2.Ety);
    }

    auto op = cast(opcode_t)el_tolong(eop);
    debug assert(!isXMMstore(op));
    tym_t ty1 = tybasic(op1.Ety);

    regm_t retregs;
    if (n == 3 && ty2 == TYuchar && op2.Eoper == OPconst)
    {   // Handle: op xmm,imm8

        retregs = pretregs & XMMREGS;
        if (!retregs)
            retregs = XMMREGS;
        codelem(cgstate,cdb,op1,retregs,false); // eval left leaf
        const reg = findreg(retregs);
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
        }
        getregs(cdb,retregs);
        cdb.genc2(op,modregrmx(3,r,reg-XMM0), cast(uint)el_tolong(op2));
    }
    else if (n == 2)
    {   /* Handle: op xmm,mem
         * where xmm is written only, not read
         */
        code cs;

        if ((op1.Eoper == OPind && !op1.Ecount) || op1.Eoper == OPvar)
        {
            getlvalue(cdb,cs, op1, 0, RM.load);     // get addressing mode
        }
        else
        {
            regm_t rretregs = XMMREGS;
            codelem(cgstate,cdb,op1, rretregs, false);
            const rreg = findreg(rretregs) - XMM0;
            cs.Irm = modregrm(3,0,rreg & 7);
            cs.Iflags = 0;
            cs.Irex = 0;
            if (rreg & 8)
                cs.Irex |= REX_B;
        }

        retregs = pretregs & XMMREGS;
        if (!retregs)
            retregs = XMMREGS;
        const reg = allocreg(cdb,retregs, e.Ety);
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

        retregs = pretregs & XMMREGS;
        if (!retregs)
            retregs = XMMREGS;
        codelem(cgstate,cdb,op1,retregs,false); // eval left leaf
        const reg = findreg(retregs);

        /* MOVHLPS and LODLPS have the same opcode. They are distinguished
         * by MOVHLPS has a second operand of size 128, LODLPS has 64
         *  https://www.felixcloutier.com/x86/movlps
         *  https://www.felixcloutier.com/x86/movhlps
         * MOVHLPS must be an XMM operand, LODLPS must be a memory operand
         */
        const isMOVHLPS = op == MOVHLPS && tysize(ty2) == 16;

        if (((op2.Eoper == OPind && !op2.Ecount) || op2.Eoper == OPvar) && !isMOVHLPS)
        {
            getlvalue(cdb,cs, op2, retregs, RM.load);     // get addressing mode
        }
        else
        {
            // load op2 into XMM register
            regm_t rretregs = XMMREGS & ~retregs;
            scodelem(cgstate,cdb, op2, rretregs, retregs, true);
            const rreg = findreg(rretregs) - XMM0;
            cs.Irm = modregrm(3,0,rreg & 7);
            cs.Iflags = 0;
            cs.Irex = 0;
            if (rreg & 8)
                cs.Irex |= REX_B;
        }

        getregs(cdb,retregs);

        switch (op)
        {
            case CMPPD:   case CMPSS:   case CMPSD:   case CMPPS:
            case PSHUFD:  case PSHUFHW: case PSHUFLW:
            case BLENDPD: case BLENDPS: case DPPD:    case DPPS:
            case MPSADBW: case PBLENDW:
            case ROUNDPD: case ROUNDPS: case ROUNDSD: case ROUNDSS:
            case SHUFPD:  case SHUFPS:
                if (n == 3)
                {
                    if (cgstate.pass == BackendPass.final_)
                        error(e.Esrcpos, "missing 4th parameter to `__simd()`");
                    cs.IFL2 = FL.const_;
                    cs.IEV2.Vsize_t = 0;
                }
                break;
            default:
                break;
        }

        if (n == 4)
        {
            elem* imm8 = params[3];
            cs.IFL2 = FL.const_;
            if (imm8.Eoper != OPconst)
            {
                error(imm8.Esrcpos, "last parameter to `__simd()` must be a constant");
                cs.IEV2.Vsize_t = 0;
            }
            else
                cs.IEV2.Vsize_t = cast(targ_size_t)el_tolong(imm8);
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
@trusted
void cdvecsto(ref CGstate cg, ref CodeBuilder cdb, elem* e, ref regm_t pretregs)
{
    //printf("cdvecsto()\n");
    //elem_print(e);
    elem* op1 = e.E1;
    elem* op2 = e.E2.E2;
    elem* eop = e.E2.E1;
    const op = cast(opcode_t)el_tolong(eop);
    debug assert(isXMMstore(op));
    xmmeq(cdb, e, op, op1, op2, pretregs);
}

/***************
 * Generate code for OPvecfill (broadcast).
 * OPvecfill takes the single value in e1 and
 * fills the vector type with it.
 */
@trusted
void cdvecfill(ref CGstate cg, ref CodeBuilder cdb, elem* e, ref regm_t pretregs)
{
    //printf("cdvecfill(e = %p, pretregs = %s)\n",e,regm_str(pretregs));

    regm_t retregs = pretregs & XMMREGS;
    if (!retregs)
        retregs = XMMREGS;

    code* c;
    code cs;

    elem* e1 = e.E1;
static if (0)
{
    if ((e1.Eoper == OPind && !e1.Ecount) || e1.Eoper == OPvar)
    {
        cr = getlvalue(cs, e1, retregs, RM.load);     // get addressing mode
    }
    else
    {
        regm_t rretregs = XMMREGS & ~retregs;
        cr = scodelem(cgstate,op2, rretregs, retregs, true);
        const rreg = findreg(rretregs) - XMM0;
        cs.Irm = modregrm(3,0,rreg & 7);
        cs.Iflags = 0;
        cs.Irex = 0;
        if (rreg & 8)
            cs.Irex |= REX_B;
    }
}

    /* e.Ety only gives us the size of the result vector, not its type.
     * We must combine it with the vector element type, e1.Ety, to
     * form the resulting vector type, ty.
     * The reason is someone may have painted the result of the OPvecfill to
     * a different vector type.
     */
    const sz = tysize(e.Ety);
    const ty1 = tybasic(e1.Ety);
    assert(sz == 16 || sz == 32);
    const bool x16 = (sz == 16);

    tym_t ty;
    switch (ty1)
    {
        case TYfloat:   ty = x16 ? TYfloat4  : TYfloat8;   break;
        case TYdouble:  ty = x16 ? TYdouble2 : TYdouble4;  break;
        case TYschar:   ty = x16 ? TYschar16 : TYschar32;  break;
        case TYuchar:   ty = x16 ? TYuchar16 : TYuchar32;  break;
        case TYshort:   ty = x16 ? TYshort8  : TYshort16;  break;
        case TYushort:  ty = x16 ? TYushort8 : TYushort16; break;
        case TYint:
        case TYlong:    ty = x16 ? TYlong4   : TYlong8;    break;
        case TYuint:
        case TYulong:   ty = x16 ? TYulong4  : TYulong8;   break;
        case TYllong:   ty = x16 ? TYllong2  : TYllong4;   break;
        case TYullong:  ty = x16 ? TYullong2 : TYullong4;  break;

        default:
            assert(0);
    }

    switch (ty)
    {
        case TYfloat4:
        case TYfloat8:
            if (config.avx && e1.Eoper == OPind && !e1.Ecount)
            {
                // VBROADCASTSS X/YMM,MEM
                getlvalue(cdb,cs, e1, 0, RM.rw);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                const reg = allocreg(cdb,retregs,ty);
                cs.Iop = VBROADCASTSS;
                cs.Irex &= ~REX_W;
                code_newreg(&cs,reg - XMM0);
                checkSetVex(&cs,ty);
                cdb.gen(&cs);
            }
            else
            {
                codelem(cgstate,cdb,e1,retregs,false); // eval left leaf
                const reg = cast(reg_t)(findreg(retregs) - XMM0);
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
            if (config.avx && tysize(ty) == 32 && e1.Eoper == OPind && !e1.Ecount)
            {
                // VBROADCASTSD YMM,MEM
                getlvalue(cdb,cs, e1, 0, RM.rw);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                const reg = allocreg(cdb,retregs,ty);
                cs.Iop = VBROADCASTSD;
                cs.Irex &= ~REX_W;
                code_newreg(&cs,reg - XMM0);
                checkSetVex(&cs,ty);
                cdb.gen(&cs);
            }
            else
            {
                codelem(cgstate,cdb,e1,retregs,false); // eval left leaf
                const reg = cast(reg_t)(findreg(retregs) - XMM0);
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
            if (config.avx >= 2 && e1.Eoper == OPind && !e1.Ecount)
            {
                // VPBROADCASTB X/YMM,MEM
                getlvalue(cdb,cs, e1, 0, RM.rw);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                reg_t reg = allocreg(cdb,retregs,ty);
                cs.Iop = VPBROADCASTB;
                cs.Irex &= ~REX_W;
                code_newreg(&cs,reg - XMM0);
                checkSetVex(&cs,ty);
                cdb.gen(&cs);
            }
            else
            {
                regm_t regm = ALLREGS;
                codelem(cgstate,cdb,e1,regm,true); // eval left leaf
                const r = findreg(regm);

                reg_t reg = allocreg(cdb,retregs, e.Ety);
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
                        regm = XMMREGS & ~retregs;
                        // VPXOR XMM1,XMM1,XMM1
                        reg_t zeroreg = allocreg(cdb,regm, ty);
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
            if (config.avx >= 2 && e1.Eoper == OPind && !e1.Ecount)
            {
                // VPBROADCASTW X/YMM,MEM
                getlvalue(cdb,cs, e1, 0, RM.rw);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                reg_t reg = allocreg(cdb,retregs,ty);
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
                codelem(cgstate,cdb,e1,regm,true); // eval left leaf
                reg_t r = findreg(regm);

                reg_t reg = allocreg(cdb,retregs, e.Ety);
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
            if (config.avx && e1.Eoper == OPind && !e1.Ecount)
            {
                // VPBROADCASTD/VBROADCASTSS X/YMM,MEM
                getlvalue(cdb,cs, e1, 0, RM.rw);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                reg_t reg = allocreg(cdb,retregs,ty);
                cs.Iop = config.avx >= 2 ? VPBROADCASTD : VBROADCASTSS;
                cs.Irex &= ~REX_W;
                code_newreg(&cs,reg - XMM0);
                checkSetVex(&cs,ty);
                cdb.gen(&cs);
            }
            else
            {
                codelem(cgstate,cdb,e1,retregs,true); // eval left leaf
                const reg = cast(reg_t)(findreg(retregs) - XMM0);
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
            if (e1.Eoper == OPind && !e1.Ecount)
            {
                // VPBROADCASTQ/VBROADCASTSD/(V)PUNPCKLQDQ X/YMM,MEM
                getlvalue(cdb,cs, e1, 0, RM.rw);         // get addressing mode
                assert((cs.Irm & 0xC0) != 0xC0);   // AVX1 doesn't have register source operands
                reg_t reg = allocreg(cdb,retregs,ty);
                cs.Iop = config.avx >= 2 ? VPBROADCASTQ : tysize(ty) == 32 ? VBROADCASTSD : PUNPCKLQDQ;
                cs.Irex &= ~REX_W;
                code_newreg(&cs,reg - XMM0);
                checkSetVex(&cs,ty);
                cdb.gen(&cs);
            }
            else
            {
                codelem(cgstate,cdb,e1,retregs,true); // eval left leaf
                const reg = cast(reg_t)(findreg(retregs) - XMM0);
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

@trusted
bool xmmIsAligned(elem* e)
{
    if (tyvector(e.Ety) && e.Eoper == OPvar)
    {
        Symbol* s = e.Vsym;
        const alignsz = tyalignsize(e.Ety);
        if (Symbol_Salignsize(*s) < alignsz ||
            e.Voffset & (alignsz - 1) ||
            alignsz > STACKALIGN
           )
            return false;       // definitely not aligned
    }
    return true;        // assume aligned
}

/**************************************
 * VEX prefixes can be 2 or 3 bytes.
 * If it must be 3 bytes, set the CFvex3 flag.
 */

void checkSetVex3(code* c)
{
    // See Intel Vol. 2A 2.3.5.6
    if (c.Ivex.w || !c.Ivex.x || !c.Ivex.b || c.Ivex.mmmm > 0x1 ||
        !I64 && (c.Ivex.r || !(c.Ivex.vvvv & 8))
       )
    {
        c.Iflags |= CFvex3;
    }
}

/*************************************
 * Determine if operation should be rewritten as a VEX
 * operation; and do so.
 * Params:
 *      c = code
 *      ty = type of operand
 */

@trusted
void checkSetVex(code* c, tym_t ty)
{
    //printf("checkSetVex() %d %x\n", tysize(ty), c.Iop);
    if (config.avx || tysize(ty) == 32)
    {
        uint vreg = (c.Irm >> 3) & 7;
        if (c.Irex & REX_R)
            vreg |= 8;

        // TODO: This is too simplistic, depending on the instruction, vex.vvvv
        // encodes NDS, NDD, DDS, or no operand (NOO). The code below assumes
        // NDS (non-destructive source), except for the incomplete list of 2
        // operand instructions (NOO) handled by the switch.
        switch (c.Iop)
        {
            case LODSS:
            case LODSD:
            case STOSS:
            case STOSD:
                if ((c.Irm & 0xC0) == 0xC0)
                    break;
                goto case LODAPS;

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

            case NOP:
                return;         // ignore

            default:
                break;
        }

        opcode_t op = 0xC4000000 | (c.Iop & 0xFF);
        switch (c.Iop & 0xFFFFFF00)
        {
            static uint MM_PP(uint mm, uint pp) { return (mm << 16) | (pp << 8); }
            case 0x00000F00: op |= MM_PP(1,0); break;
            case 0x00660F00: op |= MM_PP(1,1); break;
            case 0x00F30F00: op |= MM_PP(1,2); break;
            case 0x00F20F00: op |= MM_PP(1,3); break;
            case 0x660F3800: op |= MM_PP(2,1); break;
            case 0x660F3A00: op |= MM_PP(3,1); break;
            default:
                printf("Iop = %x\n", c.Iop);
                assert(0);
        }
        c.Iop = op;
        c.Ivex.pfx = 0xC4;
        c.Ivex.r = !(c.Irex & REX_R);
        c.Ivex.x = !(c.Irex & REX_X);
        c.Ivex.b = !(c.Irex & REX_B);
        c.Ivex.w = (c.Irex & REX_W) != 0;
        c.Ivex.l = tysize(ty) == 32;

        c.Ivex.vvvv = cast(ushort)~vreg;

        c.Iflags |= CFvex;
        checkSetVex3(c);
    }
}

/**************************************
 * Load complex operand into XMM registers or flags or both.
 */
@trusted
void cloadxmm(ref CodeBuilder cdb, elem* e, ref regm_t pretregs)
{
    //printf("e = %p, pretregs = %s)\n", e, regm_str(pretregs));
    //elem_print(e);
    assert(pretregs & (XMMREGS | mPSW));
    if (pretregs == (mXMM0 | mXMM1) &&
        e.Eoper != OPconst)
    {
        code cs = void;
        tym_t tym = tybasic(e.Ety);
        tym_t ty = tym == TYcdouble ? TYdouble : TYfloat;
        opcode_t opmv = xmmload(tym, xmmIsAligned(e));

        regm_t retregs0 = mXMM0;
        reg_t reg0 = allocreg(cdb, retregs0, ty);
        loadea(cdb, e, cs, opmv, reg0, 0, 0, 0, RM.load);  // MOVSS/MOVSD XMM0,data
        checkSetVex(cdb.last(), ty);

        regm_t retregs1 = mXMM1;
        reg_t reg1 = allocreg(cdb, retregs1, ty);
        loadea(cdb, e, cs, opmv, reg1, tysize(ty), 0, mXMM0, RM.load); // MOVSS/MOVSD XMM1,data+offset
        checkSetVex(cdb.last(), ty);

        return;
    }

    // See test/complex.d for cases winding up here
    cload87(cdb, e, pretregs);
}

/***********************************
 * Determine if we can load a constant into an XMM register
 * with instructions.
 * Params:
 *      e = constant
 * Returns:
 *      true if it can be done
 */
@trusted
bool loadxmmconst(elem* e)
{
    //printf("loadxmmconst() "); elem_print_const(e); printf("\n");
    const sz = tysize(e.Ety);
    ubyte* p = cast(ubyte*)&e.EV;
    assert(sz >= 1);

    if (config.avx < 2 && sz >= 32)
        return false;

    // true only if all ones or all zeros
    const b = p[0];
    if (b != 0 && b != 0xFF)
        return false;
    foreach (i; 1 .. sz)
    {
        if (p[i] != b)
            return false;
    }
    return true;
}
