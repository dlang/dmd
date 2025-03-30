/**
 * Code generation 2
 *
 * Includes:
 * - math operators (+ - * / %) and functions (abs, cos, sqrt)
 * - 'string' functions (strlen, memcpy, memset)
 * - pointers (address of / dereference)
 * - struct assign, constructor, destructor
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/x86/cod2.d, backend/cod2.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_x86_cod2.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/x86/cod2.d
 */

module dmd.backend.x86.cod2;

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
import dmd.backend.type;
import dmd.backend.arm.cod2;
import dmd.backend.x86.xmm;


nothrow:
@safe:

import dmd.backend.cg : segfl, stackfl;

import dmd.backend.divcoeff : choose_multiplier, udiv_coefficients;

/*******************************
 * Swap two registers.
 */

private void swap(ref reg_t a, ref reg_t b)
{
    const tmp = a;
    a = b;
    b = tmp;
}


/*******************************************
 * Returns: true if cannot use this EA in anything other than a MOV instruction.
 */

@trusted
bool movOnly(const elem* e)
{
    if (config.exe & EX_OSX64 && config.flags3 & CFG3pic && e.Eoper == OPvar)
    {
        const s = e.Vsym;
        // Fixups for these can only be done with a MOV
        if (s.Sclass == SC.global || s.Sclass == SC.extern_ ||
            s.Sclass == SC.comdat || s.Sclass == SC.comdef)
            return true;
    }
    return false;
}

/********************************
 * Determine index registers used by addressing mode.
 * Index is rm of modregrm field.
 * Returns:
 *      mask of index registers
 */

regm_t idxregm(const code* c)
{
    const rm = c.Irm;
    regm_t idxm;
    if ((rm & 0xC0) != 0xC0)            /* if register is not the destination */
    {
        if (I16)
        {
            static immutable ubyte[8] idxrm  = [mBX|mSI,mBX|mDI,mSI,mDI,mSI,mDI,0,mBX];
            idxm = idxrm[rm & 7];
        }
        else
        {
            if ((rm & 7) == 4)          /* if sib byte                  */
            {
                const sib = c.Isib;
                reg_t idxreg = (sib >> 3) & 7;
                // scaled index reg
                idxm = mask(idxreg | ((c.Irex & REX_X) ? 8 : 0));

                if ((sib & 7) == 5 && (rm & 0xC0) == 0)
                { }
                else
                    idxm |= mask((sib & 7) | ((c.Irex & REX_B) ? 8 : 0));
            }
            else
                idxm = mask((rm & 7) | ((c.Irex & REX_B) ? 8 : 0));
        }
    }
    return idxm;
}


/***************************
 * Gen code for call to floating point routine.
 */

@trusted
void opdouble(ref CodeBuilder cdb, elem* e,ref regm_t pretregs,uint clib)
{
    if (config.inline8087)
    {
        orth87(cdb,e,pretregs);
        return;
    }

    regm_t retregs1,retregs2;
    if (tybasic(e.E1.Ety) == TYfloat)
    {
        clib += CLIB.fadd - CLIB.dadd;    /* convert to float operation   */
        retregs1 = FLOATREGS;
        retregs2 = FLOATREGS2;
    }
    else
    {
        if (I32)
        {   retregs1 = DOUBLEREGS_32;
            retregs2 = DOUBLEREGS2_32;
        }
        else
        {   retregs1 = mSTACK;
            retregs2 = DOUBLEREGS_16;
        }
    }

    codelem(cgstate,cdb,e.E1, retregs1,false);
    if (retregs1 & mSTACK)
        cgstate.stackclean++;
    scodelem(cgstate,cdb,e.E2, retregs2, retregs1 & ~mSTACK, false);
    if (retregs1 & mSTACK)
        cgstate.stackclean--;
    callclib(cdb, e, clib, pretregs, 0);
}

/*****************************
 * Handle operators which are more or less orthogonal
 * ( + - & | ^ )
 */

@trusted
void cdorth(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdorth(e = %p, pretregs = %s)\n",e,regm_str(pretregs));
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdorth(cg, cdb, e, pretregs);

    elem* e1 = e.E1;
    elem* e2 = e.E2;
    if (pretregs == 0)                   // if don't want result
    {
        codelem(cgstate,cdb,e1,pretregs,false); // eval left leaf
        pretregs = 0;                          // in case they got set
        codelem(cgstate,cdb,e2,pretregs,false);
        return;
    }

    const ty = tybasic(e.Ety);
    const ty1 = tybasic(e1.Ety);

    if (tyfloating(ty1))
    {
        if (tyvector(ty1) ||
            config.fpxmmregs && tyxmmreg(ty1) &&
            !(pretregs & mST0) &&
            !(pretregs & mST01) &&
            !(ty == TYldouble || ty == TYildouble)  // watch out for shrinkLongDoubleConstantIfPossible()
           )
        {
            orthxmm(cdb,e,pretregs);
            return;
        }
        if (config.inline8087)
        {
            orth87(cdb,e,pretregs);
            return;
        }
        if (config.exe & EX_windos)
        {
            opdouble(cdb,e,pretregs,(e.Eoper == OPadd) ? CLIB.dadd
                                                       : CLIB.dsub);
            return;
        }
        else
        {
            assert(0);
        }
    }
    if (tyxmmreg(ty1))
    {
        orthxmm(cdb,e,pretregs);
        return;
    }

    opcode_t op1, op2;
    uint mode;
    __gshared int nest;

    const ty2 = tybasic(e2.Ety);
    const e2oper = e2.Eoper;
    const sz = _tysize[ty];
    const isbyte = (sz == 1);
    code_flags_t word = (!I16 && sz == SHORTSIZE) ? CFopsize : 0;
    bool test = false;                // assume we destroyed lvalue

    switch (e.Eoper)
    {
        case OPadd:     mode = 0;
                        op1 = 0x03; op2 = 0x13; break;  /* ADD, ADC     */
        case OPmin:     mode = 5;
                        op1 = 0x2B; op2 = 0x1B; break;  /* SUB, SBB     */
        case OPor:      mode = 1;
                        op1 = 0x0B; op2 = 0x0B; break;  /* OR , OR      */
        case OPxor:     mode = 6;
                        op1 = 0x33; op2 = 0x33; break;  /* XOR, XOR     */
        case OPand:     mode = 4;
                        op1 = 0x23; op2 = 0x23;         /* AND, AND     */
                        if (tyreg(ty1) &&
                            pretregs == mPSW)          /* if flags only */
                        {
                            test = true;
                            op1 = 0x85;                 /* TEST         */
                            mode = 0;
                        }
                        break;

        default:
            assert(0);
    }
    op1 ^= isbyte;                                  /* if byte operation    */

    // Compute numwords, the number of words to operate on.
    int numwords = 1;
    if (!I16)
    {
        /* Cannot operate on longs and then do a 'paint' to a far       */
        /* pointer, because far pointers are 48 bits and longs are 32.  */
        /* Therefore, numwords can never be 2.                          */
        assert(!(tyfv(ty1) && tyfv(ty2)));
        if (sz == 2 * REGSIZE)
        {
            numwords++;
        }
    }
    else
    {
        /* If ty is a TYfptr, but both operands are long, treat the     */
        /* operation as a long.                                         */
        if ((tylong(ty1) || ty1 == TYhptr) &&
            (tylong(ty2) || ty2 == TYhptr))
            numwords++;
    }

    // Special cases where only flags are set
    if (test && _tysize[ty1] <= REGSIZE &&
        (e1.Eoper == OPvar || (e1.Eoper == OPind && !e1.Ecount))
        && !movOnly(e1)
       )
    {
        // Handle the case of (var & const)
        if (e2.Eoper == OPconst && el_signx32(e2))
        {
            code cs = void;
            cs.Iflags = 0;
            cs.Irex = 0;
            getlvalue(cdb,cs,e1,0);
            targ_size_t value = e2.Vpointer;
            if (sz == 2)
                value &= 0xFFFF;
            else if (sz == 4)
                value &= 0xFFFFFFFF;
            reg_t reg;
            if (reghasvalue(isbyte ? BYTEREGS : ALLREGS,value,reg))
            {
                code_newreg(&cs, reg);
                if (I64 && isbyte && reg >= 4)
                    cs.Irex |= REX;
            }
            else
            {
                if (sz == 8 && !I64)
                {
                    assert(value == cast(int)value);    // sign extend imm32
                }
                op1 = 0xF7;
                cs.IEV2.Vint = cast(targ_int)value;
                cs.IFL2 = FL.const_;
            }
            cs.Iop = op1 ^ isbyte;
            cs.Iflags |= word | CFpsw;
            freenode(e1);
            freenode(e2);
            cdb.gen(&cs);
            return;
        }

        // Handle (exp & reg)
        reg_t reg;
        regm_t retregs;
        if (isregvar(e2,retregs,reg))
        {
            code cs = void;
            cs.Iflags = 0;
            cs.Irex = 0;
            getlvalue(cdb,cs,e1,0);
            code_newreg(&cs, reg);
            if (I64 && isbyte && reg >= 4)
                cs.Irex |= REX;
            cs.Iop = op1 ^ isbyte;
            cs.Iflags |= word | CFpsw;
            freenode(e1);
            freenode(e2);
            cdb.gen(&cs);
            return;
        }
    }

    code cs = void;
    cs.Iflags = 0;
    cs.Irex = 0;

    // Look for possible uses of LEA
    if (e.Eoper == OPadd &&
        !(pretregs & mPSW) &&                // flags aren't set by LEA
        !nest &&                              // could cause infinite recursion if e.Ecount
        (sz == REGSIZE || (I64 && sz == 4)))  // far pointers aren't handled
    {
        const rex = (sz == 8) ? REX_W : 0;

        // Handle the case of (e + &var)
        int e1oper = e1.Eoper;
        if ((e2oper == OPrelconst && (config.target_cpu >= TARGET_Pentium || (!e2.Ecount && stackfl[el_fl(e2)])))
                || // LEA costs too much for simple EAs on older CPUs
            (e2oper == OPconst && (e1.Eoper == OPcall || e1.Eoper == OPcallns) && !(pretregs & mAX)) ||
            (!I16 && (isscaledindex(e1) || isscaledindex(e2))) ||
            (!I16 && e1oper == OPvar && e1.Vsym.Sfl == FL.reg && (e2oper == OPconst || (e2oper == OPvar && e2.Vsym.Sfl == FL.reg))) ||
            (e2oper == OPconst && e1oper == OPeq && e1.E1.Eoper == OPvar) ||
            (!I16 && (e2oper == OPrelconst || e2oper == OPconst) && !e1.Ecount &&
             (e1oper == OPmul || e1oper == OPshl) &&
             e1.E2.Eoper == OPconst &&
             ssindex(e1oper,e1.E2.Vuns)
            ) ||
            (!I16 && e1.Ecount)
           )
        {
            const inc = e.Ecount != 0;
            nest += inc;
            code csx = void;
            getlvalue(cdb,csx,e,0);
            nest -= inc;
            const regx = allocreg(cdb,pretregs,ty);
            csx.Iop = LEA;
            code_newreg(&csx, regx);
            cdb.gen(&csx);          // LEA regx,EA
            if (rex)
                code_orrex(cdb.last(), rex);
            return;
        }

        // Handle the case of ((e + c) + e2)
        if (!I16 &&
            e1oper == OPadd &&
            (e1.E2.Eoper == OPconst && el_signx32(e1.E2) ||
             e2oper == OPconst && el_signx32(e2)) &&
            !e1.Ecount
           )
        {
            elem* ebase;
            elem* edisp;
            if (e2oper == OPconst && el_signx32(e2))
            {   edisp = e2;
                ebase = e1.E2;
            }
            else
            {   edisp = e1.E2;
                ebase = e2;
            }

            auto e11 = e1.E1;
            regm_t retregs = pretregs & ALLREGS;
            if (!retregs)
                retregs = ALLREGS;
            int ss = 0;
            int ss2 = 0;

            // Handle the case of (((e *  c1) + c2) + e2)
            // Handle the case of (((e << c1) + c2) + e2)
            if ((e11.Eoper == OPmul || e11.Eoper == OPshl) &&
                e11.E2.Eoper == OPconst &&
                !e11.Ecount
               )
            {
                const co1 = cast(targ_size_t)el_tolong(e11.E2);
                if (e11.Eoper == OPshl)
                {
                    if (co1 > 3)
                        goto L13;
                    ss = cast(int)co1;
                }
                else
                {
                    ss2 = 1;
                    switch (co1)
                    {
                        case  6:        ss = 1;                 break;
                        case 12:        ss = 1; ss2 = 2;        break;
                        case 24:        ss = 1; ss2 = 3;        break;
                        case 10:        ss = 2;                 break;
                        case 20:        ss = 2; ss2 = 2;        break;
                        case 40:        ss = 2; ss2 = 3;        break;
                        case 18:        ss = 3;                 break;
                        case 36:        ss = 3; ss2 = 2;        break;
                        case 72:        ss = 3; ss2 = 3;        break;
                        default:
                            ss2 = 0;
                            goto L13;
                    }
                }
                freenode(e11.E2);
                freenode(e11);
                e11 = e11.E1;
              L13:
                { }
            }

            reg_t reg11;
            regm_t regm;
            if (e11.Eoper == OPvar && isregvar(e11,regm,reg11))
            {
                if (tysize(e11.Ety) <= REGSIZE)
                    retregs = mask(reg11); // only want the LSW
                else
                    retregs = regm;
                freenode(e11);
            }
            else
                codelem(cgstate,cdb,e11,retregs,false);

            regm_t rretregs = ALLREGS & ~retregs & ~mBP;
            scodelem(cgstate,cdb,ebase,rretregs,retregs,true);
            reg_t reg;
            {
                regm_t sregs = pretregs & ~rretregs;
                if (!sregs)
                    sregs = ALLREGS & ~rretregs;
                reg = allocreg(cdb,sregs,ty);
            }

            assert((retregs & (retregs - 1)) == 0); // must be only one register
            assert((rretregs & (rretregs - 1)) == 0); // must be only one register

            auto  reg1 = findreg(retregs);
            const reg2 = findreg(rretregs);

            if (ss2)
            {
                assert(reg != reg2);
                if ((reg1 & 7) == BP)
                {   static immutable uint[4] imm32 = [1+1,2+1,4+1,8+1];

                    // IMUL reg,imm32
                    cdb.genc2(0x69,modregxrmx(3,reg,reg1),imm32[ss]);
                }
                else
                {   // LEA reg,[reg1*ss][reg1]
                    cdb.gen2sib(LEA,modregxrm(0,reg,4),modregrm(ss,reg1 & 7,reg1 & 7));
                    if (reg1 & 8)
                        code_orrex(cdb.last(), REX_X | REX_B);
                }
                if (rex)
                    code_orrex(cdb.last(), rex);
                reg1 = reg;
                ss = ss2;                               // use *2 for scale
            }

            cs.Iop = LEA;                      // LEA reg,c[reg1*ss][reg2]
            cs.Irm = modregrm(2,reg & 7,4);
            cs.Isib = modregrm(ss,reg1 & 7,reg2 & 7);
            assert(reg2 != BP);
            cs.Iflags = CFoff;
            cs.Irex = cast(ubyte)rex;
            if (reg & 8)
                cs.Irex |= REX_R;
            if (reg1 & 8)
                cs.Irex |= REX_X;
            if (reg2 & 8)
                cs.Irex |= REX_B;
            cs.IFL1 = FL.const_;
            cs.IEV1.Vsize_t = edisp.Vuns;

            freenode(edisp);
            freenode(e1);
            cdb.gen(&cs);
            fixresult(cdb,e,mask(reg),pretregs);
            return;
        }
    }

    regm_t posregs = (isbyte) ? BYTEREGS : (mES | cgstate.allregs);
    regm_t retregs = pretregs & posregs;
    if (retregs == 0)                   /* if no return regs speced     */
                                        /* (like if wanted flags only)  */
        retregs = ALLREGS & posregs;    // give us some

    if (ty1 == TYhptr || ty2 == TYhptr)
    {     /* Generate code for add/subtract of huge pointers.
           No attempt is made to generate very good code.
         */
        retregs = (retregs & mLSW) | mDX;
        regm_t rretregs;
        if (ty1 == TYhptr)
        {   // hptr +- long
            rretregs = mLSW & ~(retregs | cgstate.regcon.mvar);
            if (!rretregs)
                rretregs = mLSW;
            rretregs |= mCX;
            codelem(cgstate,cdb,e1,rretregs,0);
            retregs &= ~rretregs;
            if (!(retregs & mLSW))
                retregs |= mLSW & ~rretregs;

            scodelem(cgstate,cdb,e2,retregs,rretregs,true);
        }
        else
        {   // long + hptr
            codelem(cgstate,cdb,e1,retregs,0);
            rretregs = (mLSW | mCX) & ~retregs;
            if (!(rretregs & mLSW))
                rretregs |= mLSW;
            scodelem(cgstate,cdb,e2,rretregs,retregs,true);
        }
        getregs(cdb,rretregs | retregs);
        const mreg = DX;
        const lreg = findreglsw(retregs);
        if (e.Eoper == OPmin)
        {   // negate retregs
            cdb.gen2(0xF7,modregrm(3,3,mreg));     // NEG mreg
            cdb.gen2(0xF7,modregrm(3,3,lreg));     // NEG lreg
            code_orflag(cdb.last(),CFpsw);
            cdb.genc2(0x81,modregrm(3,3,mreg),0);  // SBB mreg,0
        }
        const lrreg = findreglsw(rretregs);
        genregs(cdb,0x03,lreg,lrreg);              // ADD lreg,lrreg
        code_orflag(cdb.last(),CFpsw);
        genmovreg(cdb,lrreg,CX);      // MOV lrreg,CX
        cdb.genc2(0x81,modregrm(3,2,mreg),0);      // ADC mreg,0
        genshift(cdb);                             // MOV CX,offset __AHSHIFT
        cdb.gen2(0xD3,modregrm(3,4,mreg));         // SHL mreg,CL
        genregs(cdb,0x03,mreg,lrreg);              // ADD mreg,MSREG(h)
        fixresult(cdb,e,retregs,pretregs);
        return;
    }

    regm_t rretregs;
    reg_t reg;
    if (_tysize[ty1] > REGSIZE && numwords == 1)
    {     /* The only possibilities are (TYfptr + tyword) or (TYfptr - tyword) */

        debug
        if (_tysize[ty2] != REGSIZE)
        {
            printf("e = %p, e.Eoper = %s e1.Ety = %s e2.Ety = %s\n", e, oper_str(e.Eoper), tym_str(ty1), tym_str(ty2));
            elem_print(e);
        }

        assert(_tysize[ty2] == REGSIZE);

        /* Watch out for the case here where you are going to OP reg,EA */
        /* and both the reg and EA use ES! Prevent this by forcing      */
        /* reg into the regular registers.                              */
        if ((e2oper == OPind ||
            (e2oper == OPvar && el_fl(e2) == FL.fardata)) &&
            !e2.Ecount)
        {
            retregs = ALLREGS;
        }

        codelem(cgstate,cdb,e1,retregs,test != 0);
        reg = findreglsw(retregs);      /* reg is the register with the offset*/
    }
    else
    {
        regm_t regm;
        reg_t regx;

        /* if (tyword + TYfptr) */
        if (_tysize[ty1] == REGSIZE && _tysize[ty2] > REGSIZE)
        {   retregs = ~pretregs & ALLREGS;

            /* if retregs doesn't have any regs in it that aren't reg vars */
            if ((retregs & ~cgstate.regcon.mvar) == 0)
                retregs |= mAX;
        }
        else if (numwords == 2 && retregs & mES)
            retregs = (retregs | mMSW) & ALLREGS;

        // Determine if we should swap operands, because
        //      mov     EAX,x
        //      add     EAX,reg
        // is faster than:
        //      mov     EAX,reg
        //      add     EAX,x
        else if (e2oper == OPvar &&
                 e1.Eoper == OPvar &&
                 e.Eoper != OPmin &&
                 isregvar(e1,regm,regx) &&
                 regm != retregs &&
                 _tysize[ty1] == _tysize[ty2])
        {
            elem* es = e1;
            e1 = e2;
            e2 = es;
        }
        codelem(cgstate,cdb,e1,retregs,test != 0);         // eval left leaf
        reg = findreg(retregs);
    }
    reg_t rreg;
    int rval;
    targ_size_t i;
    switch (e2oper)
    {
        case OPind:                                 /* if addressing mode   */
            if (!e2.Ecount)                         /* if not CSE           */
                    goto L1;                        /* try OP reg,EA        */
            goto default;

        default:                                    /* operator node        */
        L2:
            rretregs = ALLREGS & ~retregs;
            /* Be careful not to do arithmetic on ES        */
            if (_tysize[ty1] == REGSIZE && _tysize[ty2] > REGSIZE && pretregs != mPSW)
                rretregs = pretregs & (mES | ALLREGS | mBP) & ~retregs;
            else if (isbyte)
                rretregs &= BYTEREGS;

            scodelem(cgstate,cdb,e2,rretregs,retregs,true);       // get rvalue
            rreg = (_tysize[ty2] > REGSIZE) ? findreglsw(rretregs) : findreg(rretregs);
            if (!test)
                getregs(cdb,retregs);          // we will trash these regs
            if (numwords == 1)                              /* ADD reg,rreg */
            {
                /* reverse operands to avoid moving around the segment value */
                if (_tysize[ty2] > REGSIZE)
                {
                    getregs(cdb,rretregs);
                    genregs(cdb,op1,rreg,reg);
                    retregs = rretregs;     // reverse operands
                }
                else
                {
                    genregs(cdb,op1,reg,rreg);
                    if (!I16 && pretregs & mPSW)
                        cdb.last().Iflags |= word;
                }
                if (I64 && sz == 8)
                    code_orrex(cdb.last(), REX_W);
                if (I64 && isbyte && (reg >= 4 || rreg >= 4))
                    code_orrex(cdb.last(), REX);
            }
            else /* numwords == 2 */                /* ADD lsreg,lsrreg     */
            {
                reg = findreglsw(retregs);
                rreg = findreglsw(rretregs);
                genregs(cdb,op1,reg,rreg);
                if (e.Eoper == OPadd || e.Eoper == OPmin)
                    code_orflag(cdb.last(),CFpsw);
                reg = findregmsw(retregs);
                rreg = findregmsw(rretregs);
                if (!(e2oper == OPu16_32 && // if second operand is 0
                      (op2 == 0x0B || op2 == 0x33)) // and OR or XOR
                   )
                    genregs(cdb,op2,reg,rreg);        // ADC msreg,msrreg
            }
            break;

        case OPrelconst:
            if (I64 && (config.flags3 & CFG3pic || config.exe == EX_WIN64))
                goto default;
            if (sz != REGSIZE)
                goto L2;
            if (segfl[el_fl(e2)] != 3)              /* if not in data segment */
                goto L2;
            if (evalinregister(e2))
                goto L2;
            cs.IEV2.Voffset = e2.Voffset;
            cs.IEV2.Vsym = e2.Vsym;
            cs.Iflags |= CFoff;
            i = 0;                          /* no INC or DEC opcode         */
            rval = 0;
            goto L3;

        case OPconst:
            if (tyfv(ty2))
                goto L2;
            if (numwords == 1)
            {
                if (!el_signx32(e2))
                    goto L2;
                i = e2.Vpointer;
                if (word)
                {
                    if (!(pretregs & mPSW) &&
                        config.flags4 & CFG4speed &&
                        (e.Eoper == OPor || e.Eoper == OPxor || test ||
                         (e1.Eoper != OPvar && e1.Eoper != OPind)))
                    {   word = 0;
                        i &= 0xFFFF;
                    }
                }
                rval = reghasvalue(isbyte ? BYTEREGS : ALLREGS,i,rreg);
                cs.IEV2.Vsize_t = i;
            L3:
                if (!test)
                    getregs(cdb,retregs);          // we will trash these regs
                op1 ^= isbyte;
                cs.Iflags |= word;
                if (rval)
                {   cs.Iop = op1 ^ 2;
                    mode = rreg;
                }
                else
                    cs.Iop = 0x81;
                cs.Irm = modregrm(3,mode&7,reg&7);
                if (mode & 8)
                    cs.Irex |= REX_R;
                if (reg & 8)
                    cs.Irex |= REX_B;
                if (I64 && sz == 8)
                    cs.Irex |= REX_W;
                if (I64 && isbyte && (reg >= 4 || (rval && rreg >= 4)))
                    cs.Irex |= REX;
                cs.IFL2 = (e2.Eoper == OPconst) ? FL.const_ : el_fl(e2);
                /* Modify instruction for special cases */
                switch (e.Eoper)
                {
                    case OPadd:
                    {
                        int iop;

                        if (i == 1)
                            iop = 0;                    /* INC reg      */
                        else if (i == -1)
                            iop = 8;                    /* DEC reg      */
                        else
                            break;
                        cs.Iop = (0x40 | iop | reg) ^ isbyte;
                        if ((isbyte && pretregs & mPSW) || I64)
                        {
                            cs.Irm = cast(ubyte)(modregrm(3,0,reg & 7) | iop);
                            cs.Iop = 0xFF;
                        }
                        break;
                    }

                    case OPand:
                        if (test)
                            cs.Iop = rval ? op1 : 0xF7; // TEST
                        break;

                    default:
                        break;
                }
                if (pretregs & mPSW)
                    cs.Iflags |= CFpsw;
                cs.Iop ^= isbyte;
                cdb.gen(&cs);
                cs.Iflags &= ~CFpsw;
            }
            else if (numwords == 2)
            {
                getregs(cdb,retregs);
                reg = findregmsw(retregs);
                const lsreg = findreglsw(retregs);
                cs.Iop = 0x81;
                cs.Irm = modregrm(3,mode,lsreg);
                cs.IFL2 = FL.const_;
                const msw = cast(targ_int)MSREG(e2.Vllong);
                cs.IEV2.Vint = e2.Vlong;
                switch (e.Eoper)
                {
                    case OPadd:
                    case OPmin:
                        cs.Iflags |= CFpsw;
                        break;

                    default:
                        break;
                }
                cdb.gen(&cs);
                cs.Iflags &= ~CFpsw;

                cs.Irm = cast(ubyte)((cs.Irm & modregrm(3,7,0)) | reg);
                cs.IEV2.Vint = msw;
                if (e.Eoper == OPadd)
                    cs.Irm |= modregrm(0,2,0);      /* ADC          */
                cdb.gen(&cs);
            }
            else
                assert(0);
            freenode(e2);
            break;

        case OPvar:
            if (movOnly(e2))
                goto L2;
        L1:
            if (tyfv(ty2))
                goto L2;
            if (!test)
                getregs(cdb,retregs);          // we will trash these regs
            loadea(cdb,e2,cs,op1,
                   ((numwords == 2) ? findreglsw(retregs) : reg),
                   0,retregs,retregs);
            if (!I16 && word)
            {   if (pretregs & mPSW)
                    code_orflag(cdb.last(),word);
                else
                    cdb.last().Iflags &= ~cast(int)word;
            }
            else if (numwords == 2)
            {
                if (e.Eoper == OPadd || e.Eoper == OPmin)
                    code_orflag(cdb.last(),CFpsw);
                reg = findregmsw(retregs);
                if (!OTleaf(e2.Eoper))
                {   getlvalue_msw(cs);
                    cs.Iop = op2;
                    NEWREG(cs.Irm,reg);
                    cdb.gen(&cs);                 // ADC reg,data+2
                }
                else
                    loadea(cdb,e2,cs,op2,reg,REGSIZE,retregs,0);
            }
            else if (I64 && sz == 8)
                code_orrex(cdb.last(), REX_W);
            freenode(e2);
            break;
    }

    if (sz <= REGSIZE && pretregs & mPSW)
    {
        /* If the expression is (_tls_array + ...), then the flags are not set
         * since the linker may rewrite these instructions into something else.
         */
        if (I64 && e.Eoper == OPadd && e1.Eoper == OPvar)
        {
            const s = e1.Vsym;
            if (s.Sident[0] == '_' && memcmp(s.Sident.ptr + 1,"tls_array".ptr,10) == 0)
            {
                goto L7;                        // don't assume flags are set
            }
        }
        code_orflag(cdb.last(),CFpsw);
        pretregs &= ~mPSW;                    // flags already set
    L7: { }
    }
    fixresult(cdb,e,retregs,pretregs);
}


/*****************************
 * Handle multiply.
 */

@trusted
void cdmul(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdmul(cg, cdb, e, pretregs);

    //printf("cdmul()\n");
    elem* e1 = e.E1;
    elem* e2 = e.E2;
    if (pretregs == 0)                         // if don't want result
    {
        codelem(cgstate,cdb,e1,pretregs,false);      // eval left leaf
        pretregs = 0;                          // in case they got set
        codelem(cgstate,cdb,e2,pretregs,false);
        return;
    }

    //printf("cdmul(e = %p, pretregs = %s)\n", e, regm_str(pretregs));
    const tyml = tybasic(e1.Ety);
    const ty = tybasic(e.Ety);
    const oper = e.Eoper;

    if (tyfloating(tyml))
    {
        if (tyvector(tyml) ||
            config.fpxmmregs && oper != OPmod && tyxmmreg(tyml) &&
            !(pretregs & mST0) &&
            !(ty == TYldouble || ty == TYildouble) &&  // watch out for shrinkLongDoubleConstantIfPossible()
            !tycomplex(ty) && // SIMD code is not set up to deal with complex mul/div
            !(ty == TYllong)  //   or passing to function through integer register
           )
        {
            orthxmm(cdb,e,pretregs);
            return;
        }
        if (config.exe & EX_posix)
            orth87(cdb,e,pretregs);
        else
            opdouble(cdb,e,pretregs,(oper == OPmul) ? CLIB.dmul : CLIB.ddiv);

        return;
    }

    if (tyxmmreg(tyml))
    {
        orthxmm(cdb,e,pretregs);
        return;
    }

    const uns = tyuns(tyml) || tyuns(e2.Ety);  // 1 if signed operation, 0 if unsigned
    const isbyte = tybyte(e.Ety) != 0;
    const sz = _tysize[tyml];
    const ubyte rex = (I64 && sz == 8) ? REX_W : 0;
    const uint grex = rex << 16;
    const OPER opunslng = I16 ? OPu16_32 : OPu32_64;

    code cs = void;
    cs.Iflags = 0;
    cs.Irex = 0;

    switch (e2.Eoper)
    {
        case OPu16_32:
        case OPs16_32:
        case OPu32_64:
        case OPs32_64:
        {
            if (sz != 2 * REGSIZE || e1.Eoper != e2.Eoper ||
                e1.Ecount || e2.Ecount)
                goto default;
            const ubyte opx = (e2.Eoper == opunslng) ? 4 : 5;
            regm_t retregsx = mAX;
            codelem(cgstate,cdb,e1.E1,retregsx,false);    // eval left leaf
            if (e2.E1.Eoper == OPvar ||
                (e2.E1.Eoper == OPind && !e2.E1.Ecount)
               )
            {
                loadea(cdb,e2.E1,cs,0xF7,opx,0,mAX,mAX | mDX);
            }
            else
            {
                regm_t rretregsx = ALLREGS & ~mAX;
                scodelem(cgstate,cdb,e2.E1,rretregsx,retregsx,true); // get rvalue
                getregs(cdb,mAX | mDX);
                const rregx = findreg(rretregsx);
                cdb.gen2(0xF7,grex | modregrmx(3,opx,rregx)); // OP AX,rregx
            }
            freenode(e.E1);
            freenode(e2);
            fixresult(cdb,e,mAX | mDX,pretregs);
            return;
        }

        case OPconst:
            const e2factor = cast(targ_size_t)el_tolong(e2);

            // Multiply by a constant
            if (I32 && sz == REGSIZE * 2)
            {
                /*  if (msw)
                      IMUL    EDX,EDX,lsw
                      IMUL    reg,EAX,msw
                      ADD     reg,EDX
                    else
                      IMUL    reg,EDX,lsw
                    MOV       EDX,lsw
                    MUL       EDX
                    ADD       EDX,reg
                 */
                regm_t retregs = mAX | mDX;
                codelem(cgstate,cdb,e1,retregs,false);    // eval left leaf
                reg_t reg = allocScratchReg(cdb, cgstate.allregs & ~(mAX | mDX));
                getregs(cdb,mDX | mAX);

                const lsw = cast(targ_int)(e2factor & ((1L << (REGSIZE * 8)) - 1));
                const msw = cast(targ_int)(e2factor >> (REGSIZE * 8));

                if (msw)
                {
                    genmulimm(cdb,DX,DX,lsw);           // IMUL EDX,EDX,lsw
                    genmulimm(cdb,reg,AX,msw);          // IMUL reg,EAX,msw
                    cdb.gen2(0x03,modregrm(3,reg,DX));  // ADD  reg,EAX
                }
                else
                    genmulimm(cdb,reg,DX,lsw);          // IMUL reg,EDX,lsw

                movregconst(cdb,DX,lsw,0);              // MOV EDX,lsw
                getregs(cdb,mDX);
                cdb.gen2(0xF7,modregrm(3,4,DX));        // MUL EDX
                cdb.gen2(0x03,modregrm(3,DX,reg));      // ADD EDX,reg

                const resregx = mDX | mAX;
                freenode(e2);
                fixresult(cdb,e,resregx,pretregs);
                return;
            }


            const int pow2 = ispow2(e2factor);

            if (sz > REGSIZE || !el_signx32(e2))
                goto default;

            if (config.target_cpu >= TARGET_80286)
            {
                if (I32 || I64)
                {
                    // See if we can use an LEA instruction
                    int ss;
                    int ss2 = 0;
                    int shift;

                    switch (e2factor)
                    {
                        case 12:    ss = 1; ss2 = 2; goto L4;
                        case 24:    ss = 1; ss2 = 3; goto L4;

                        case 6:
                        case 3:     ss = 1; goto L4;

                        case 20:    ss = 2; ss2 = 2; goto L4;
                        case 40:    ss = 2; ss2 = 3; goto L4;

                        case 10:
                        case 5:     ss = 2; goto L4;

                        case 36:    ss = 3; ss2 = 2; goto L4;
                        case 72:    ss = 3; ss2 = 3; goto L4;

                        case 18:
                        case 9:     ss = 3; goto L4;

                        L4:
                        {
                            regm_t resreg = pretregs & ALLREGS & ~(mBP | mR13);
                            if (!resreg)
                                resreg = isbyte ? BYTEREGS : ALLREGS & ~(mBP | mR13);

                            codelem(cgstate,cdb,e.E1,resreg,false);
                            getregs(cdb,resreg);
                            reg_t reg = findreg(resreg);

                            cdb.gen2sib(LEA,grex | modregxrm(0,reg,4),
                                        modregxrmx(ss,reg,reg));        // LEA reg,[ss*reg][reg]
                            assert((reg & 7) != BP);
                            if (ss2)
                            {
                                cdb.gen2sib(LEA,grex | modregxrm(0,reg,4),
                                               modregxrm(ss2,reg,5));
                                cdb.last().IFL1 = FL.const_;
                                cdb.last().IEV1.Vint = 0;               // LEA reg,0[ss2*reg]
                            }
                            else if (!(e2factor & 1))                   // if even factor
                            {
                                genregs(cdb,0x03,reg,reg);              // ADD reg,reg
                                code_orrex(cdb.last(),rex);
                            }
                            freenode(e2);
                            fixresult(cdb,e,resreg,pretregs);
                            return;
                        }
                        case 37:
                        case 74:    shift = 2;
                                    goto L5;
                        case 13:
                        case 26:    shift = 0;
                                    goto L5;
                        L5:
                        {
                            regm_t retregs = isbyte ? BYTEREGS : ALLREGS;
                            regm_t resreg = pretregs & (ALLREGS | mBP);
                            if (!resreg)
                                resreg = retregs;

                            // Don't use EBP
                            resreg &= ~(mBP | mR13);
                            if (!resreg)
                                resreg = retregs;
                            const reg = allocreg(cdb,resreg,TYint);

                            regm_t sregm = (ALLREGS & ~mR13) & ~resreg;
                            codelem(cgstate,cdb,e.E1,sregm,false);
                            uint sreg = findreg(sregm);
                            getregs(cdb,resreg | sregm);
                            assert((sreg & 7) != BP);
                            assert((reg & 7) != BP);
                            cdb.gen2sib(LEA,grex | modregxrm(0,reg,4),
                                                  modregxrmx(2,sreg,sreg));       // LEA reg,[sreg*4][sreg]
                            if (shift)
                                cdb.genc2(0xC1,grex | modregrmx(3,4,sreg),shift); // SHL sreg,shift
                            cdb.gen2sib(LEA,grex | modregxrm(0,reg,4),
                                                  modregxrmx(3,sreg,reg));        // LEA reg,[sreg*8][reg]
                            if (!(e2factor & 1))                                  // if even factor
                            {
                                genregs(cdb,0x03,reg,reg);                        // ADD reg,reg
                                code_orrex(cdb.last(),rex);
                            }
                            freenode(e2);
                            fixresult(cdb,e,resreg,pretregs);
                            return;
                        }

                        default:
                            break;
                    }
                }

                regm_t retregs = isbyte ? BYTEREGS : ALLREGS;
                regm_t resreg = pretregs & (ALLREGS | mBP);
                if (!resreg)
                    resreg = retregs;

                scodelem(cgstate,cdb,e.E1,retregs,0,true);     // eval left leaf
                const regx = findreg(retregs);
                const rreg = allocreg(cdb,resreg,e.Ety);

                // IMUL regx,imm16
                cdb.genc2(0x69,grex | modregxrmx(3,rreg,regx),e2factor);
                freenode(e2);
                fixresult(cdb,e,resreg,pretregs);
                return;
            }
            goto default;

        case OPind:
            if (!e2.Ecount)                        // if not CSE
                    goto case OPvar;                        // try OP reg,EA
            goto default;

        default:                                    // OPconst and operators
            //printf("test2 %p, retregs = %s rretregs = %s resreg = %s\n", e, regm_str(retregs), regm_str(rretregs), regm_str(resreg));
            if (sz <= REGSIZE)
            {
                regm_t retregs = mAX;
                codelem(cgstate,cdb,e1,retregs,false);           // eval left leaf
                regm_t rretregs = isbyte ? BYTEREGS & ~mAX
                                         : ALLREGS & ~(mAX|mDX);
                scodelem(cgstate,cdb,e2,rretregs,retregs,true);  // get rvalue
                getregs(cdb,mAX | mDX);     // trash these regs
                reg_t rreg = findreg(rretregs);
                cdb.gen2(0xF7 ^ isbyte,grex | modregrmx(3,5 - uns,rreg)); // OP AX,rreg
                if (I64 && isbyte && rreg >= 4)
                    code_orrex(cdb.last(), REX);
                fixresult(cdb,e,mAX,pretregs);
                return;
            }
            else if (sz == 2 * REGSIZE)
            {
                regm_t retregs = mDX | mAX;
                codelem(cgstate,cdb,e1,retregs,false);           // eval left leaf
                if (config.target_cpu >= TARGET_PentiumPro)
                {
                    regm_t rretregs = cgstate.allregs & ~retregs;           // second arg
                    scodelem(cgstate,cdb,e2,rretregs,retregs,true); // get rvalue
                    reg_t rlo = findreglsw(rretregs);
                    reg_t rhi = findregmsw(rretregs);
                    /*  IMUL    rhi,EAX
                        IMUL    EDX,rlo
                        ADD     rhi,EDX
                        MUL     rlo
                        ADD     EDX,rhi
                     */
                    getregs(cdb,mAX|mDX|mask(rhi));
                    cdb.gen2(0x0FAF,modregrm(3,rhi,AX));
                    cdb.gen2(0x0FAF,modregrm(3,DX,rlo));
                    cdb.gen2(0x03,modregrm(3,rhi,DX));
                    cdb.gen2(0xF7,modregrm(3,4,rlo));
                    cdb.gen2(0x03,modregrm(3,DX,rhi));
                    fixresult(cdb,e,mDX|mAX,pretregs);
                    return;
                }
                else
                {
                    regm_t rretregs = mCX | mBX;           // second arg
                    scodelem(cgstate,cdb,e2,rretregs,retregs,true);  // get rvalue
                    callclib(cdb,e,CLIB.lmul,pretregs,0);
                    return;
                }
            }
            assert(0);

        case OPvar:
            if (!I16 && sz <= REGSIZE)
            {
                if (sz > 1)        // no byte version
                {
                    // Generate IMUL r32,r/m32
                    regm_t retregs = pretregs & (ALLREGS | mBP);
                    if (!retregs)
                        retregs = ALLREGS;
                    codelem(cgstate,cdb,e1,retregs,false);        // eval left leaf
                    regm_t resreg = retregs;
                    loadea(cdb,e2,cs,0x0FAF,findreg(resreg),0,retregs,retregs);
                    freenode(e2);
                    fixresult(cdb,e,resreg,pretregs);
                    return;
                }
            }
            else
            {
                if (sz == 2 * REGSIZE)
                {
                    if (e.E1.Eoper != opunslng ||
                        e1.Ecount)
                        goto default;            // have to handle it with codelem(cgstate,)

                    regm_t retregs = ALLREGS & ~(mAX | mDX);
                    codelem(cgstate,cdb,e1.E1,retregs,false);    // eval left leaf
                    const reg = findreg(retregs);
                    getregs(cdb,mAX);
                    genmovreg(cdb,AX,reg);            // MOV AX,reg
                    loadea(cdb,e2,cs,0xF7,4,REGSIZE,mAX | mDX | mskl(reg),mAX | mDX);  // MUL EA+2
                    getregs(cdb,retregs);
                    cdb.gen1(0x90 + reg);                          // XCHG AX,reg
                    getregs(cdb,mAX | mDX);
                    if ((cs.Irm & 0xC0) == 0xC0)            // if EA is a register
                        loadea(cdb,e2,cs,0xF7,4,0,mAX | mskl(reg),mAX | mDX); // MUL EA
                    else
                    {   getlvalue_lsw(cs);
                        cdb.gen(&cs);                       // MUL EA
                    }
                    cdb.gen2(0x03,modregrm(3,DX,reg));      // ADD DX,reg

                    freenode(e1);
                    fixresult(cdb,e,mAX | mDX,pretregs);
                    return;
                }
                assert(sz <= REGSIZE);
            }

            // loadea() handles CWD or CLR DX for divides
            regm_t retregs = sz <= REGSIZE ? mAX : mDX|mAX;
            codelem(cgstate,cdb,e.E1,retregs,false);     // eval left leaf
            loadea(cdb,e2,cs,0xF7 ^ isbyte,5 - uns,0,
                   mAX,
                   mAX | mDX);
            freenode(e2);
            fixresult(cdb,e,mAX,pretregs);
            return;
    }
    assert(0);
}


/*****************************
 * Handle divide, modulo and remquo.
 * Note that modulo isn't defined for doubles.
 */

@trusted
void cddiv(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cddiv(cg, cdb, e, pretregs);

    //printf("cddiv()\n");
    elem* e1 = e.E1;
    elem* e2 = e.E2;
    if (pretregs == 0)                         // if don't want result
    {
        codelem(cgstate,cdb,e1,pretregs,false);      // eval left leaf
        pretregs = 0;                          // in case they got set
        codelem(cgstate,cdb,e2,pretregs,false);
        return;
    }

    //printf("cddiv(e = %p, pretregs = %s)\n", e, regm_str(pretregs));
    const tyml = tybasic(e1.Ety);
    const ty = tybasic(e.Ety);
    const oper = e.Eoper;

    if (tyfloating(tyml))
    {
        if (tyvector(tyml) ||
            config.fpxmmregs && oper != OPmod && tyxmmreg(tyml) &&
            !(pretregs & mST0) &&
            !(ty == TYldouble || ty == TYildouble) &&  // watch out for shrinkLongDoubleConstantIfPossible()
            !tycomplex(ty) && // SIMD code is not set up to deal with complex mul/div
            !(ty == TYllong)  //   or passing to function through integer register
           )
        {
            orthxmm(cdb,e,pretregs);
            return;
        }
        if (config.exe & EX_posix)
            orth87(cdb,e,pretregs);
        else
            opdouble(cdb,e,pretregs,(oper == OPmul) ? CLIB.dmul : CLIB.ddiv);

        return;
    }

    if (tyxmmreg(tyml))
    {
        orthxmm(cdb,e,pretregs);
        return;
    }

    const uns = tyuns(tyml) || tyuns(e2.Ety);  // 1 if uint operation, 0 if not
    const isbyte = tybyte(e.Ety) != 0;
    const sz = _tysize[tyml];
    const ubyte rex = (I64 && sz == 8) ? REX_W : 0;
    const uint grex = rex << 16;

    code cs = void;
    cs.Iflags = 0;
    cs.IFL2 = FL.unde;
    cs.Irex = 0;

    switch (e2.Eoper)
    {
        case OPconst:
            auto d = cast(targ_size_t)el_tolong(e2);
            bool neg = false;
            const e2factor = d;
            if (!uns && cast(targ_llong)e2factor < 0)
            {   neg = true;
                d = -d;
            }

            // Signed divide by a constant
            if ((d & (d - 1)) &&
                ((I32 && sz == 4) || (I64 && (sz == 4 || sz == 8))) &&
                config.flags4 & CFG4speed && !uns)
            {
                /* R1 / 10
                 *
                 *  MOV     EAX,m
                 *  IMUL    R1
                 *  MOV     EAX,R1
                 *  SAR     EAX,31
                 *  SAR     EDX,shpost
                 *  SUB     EDX,EAX
                 *  IMUL    EAX,EDX,d
                 *  SUB     R1,EAX
                 *
                 * EDX = quotient
                 * R1 = remainder
                 */
                assert(sz == 4 || sz == 8);

                ulong m;
                int shpost;
                const int N = sz * 8;
                const bool mhighbit = choose_multiplier(N, d, N - 1, &m, &shpost);

                regm_t regm = cgstate.allregs & ~(mAX | mDX);
                codelem(cgstate,cdb,e1,regm,false);       // eval left leaf
                const reg_t reg = findreg(regm);
                getregs(cdb,regm | mDX | mAX);

                /* Algorithm 5.2
                 * if m>=2**(N-1)
                 *    q = SRA(n + MULSH(m-2**N,n), shpost) - XSIGN(n)
                 * else
                 *    q = SRA(MULSH(m,n), shpost) - XSIGN(n)
                 * if (neg)
                 *    q = -q
                 */
                const bool mgt = mhighbit || m >= (1UL << (N - 1));
                movregconst(cdb, AX, cast(targ_size_t)m, (sz == 8) ? 0x40 : 0);  // MOV EAX,m
                cdb.gen2(0xF7,grex | modregrmx(3,5,reg));               // IMUL R1
                if (mgt)
                    cdb.gen2(0x03,grex | modregrmx(3,DX,reg));          // ADD EDX,R1
                getregsNoSave(mAX);                                     // EAX no longer contains 'm'
                genmovreg(cdb, AX, reg);                   // MOV EAX,R1
                cdb.genc2(0xC1,grex | modregrm(3,7,AX),sz * 8 - 1);     // SAR EAX,31
                if (shpost)
                    cdb.genc2(0xC1,grex | modregrm(3,7,DX),shpost);     // SAR EDX,shpost
                reg_t r3;
                if (neg && oper == OPdiv)
                {
                    cdb.gen2(0x2B,grex | modregrm(3,AX,DX));            // SUB EAX,EDX
                    r3 = AX;
                }
                else
                {
                    cdb.gen2(0x2B,grex | modregrm(3,DX,AX));            // SUB EDX,EAX
                    r3 = DX;
                }

                // r3 is quotient
                regm_t resregx;
                switch (oper)
                {   case OPdiv:
                        resregx = mask(r3);
                        break;

                    case OPmod:
                        assert(reg != AX && r3 == DX);
                        if (sz == 4 || (sz == 8 && cast(targ_long)d == d))
                        {
                            cdb.genc2(0x69,grex | modregrm(3,AX,DX),d);      // IMUL EAX,EDX,d
                        }
                        else
                        {
                            movregconst(cdb,AX,d,(sz == 8) ? 0x40 : 0); // MOV EAX,d
                            cdb.gen2(0x0FAF,grex | modregrmx(3,AX,DX));     // IMUL EAX,EDX
                            getregsNoSave(mAX);                             // EAX no longer contains 'd'
                        }
                        cdb.gen2(0x2B,grex | modregxrm(3,reg,AX));          // SUB R1,EAX
                        resregx = regm;
                        break;

                    case OPremquo:
                        assert(reg != AX && r3 == DX);
                        if (sz == 4 || (sz == 8 && cast(targ_long)d == d))
                        {
                            cdb.genc2(0x69,grex | modregrm(3,AX,DX),d);     // IMUL EAX,EDX,d
                        }
                        else
                        {
                            movregconst(cdb,AX,d,(sz == 8) ? 0x40 : 0); // MOV EAX,d
                            cdb.gen2(0x0FAF,grex | modregrmx(3,AX,DX));     // IMUL EAX,EDX
                        }
                        cdb.gen2(0x2B,grex | modregxrm(3,reg,AX));          // SUB R1,EAX
                        genmovreg(cdb, AX, r3);                // MOV EAX,r3
                        if (neg)
                            cdb.gen2(0xF7,grex | modregrm(3,3,AX));         // NEG EAX
                        genmovreg(cdb, DX, reg);               // MOV EDX,R1
                        resregx = mDX | mAX;
                        break;

                    default:
                        assert(0);
                }
                freenode(e2);
                fixresult(cdb,e,resregx,pretregs);
                return;
            }

            // Unsigned divide by a constant
            if (e2factor > 2 && (e2factor & (e2factor - 1)) &&
                ((I32 && sz == 4) || (I64 && (sz == 4 || sz == 8))) &&
                config.flags4 & CFG4speed && uns)
            {
                assert(sz == 4 || sz == 8);

                reg_t r3;
                regm_t regm;
                reg_t reg;
                ulong m;
                int shpre;
                int shpost;
                if (udiv_coefficients(sz * 8, e2factor, &shpre, &m, &shpost))
                {
                    /* t1 = MULUH(m, n)
                     * q = SRL(t1 + SRL(n - t1, 1), shpost - 1)
                     *   MOV   EAX,reg
                     *   MOV   EDX,m
                     *   MUL   EDX
                     *   MOV   EAX,reg
                     *   SUB   EAX,EDX
                     *   SHR   EAX,1
                     *   LEA   R3,[EAX][EDX]
                     *   SHR   R3,shpost-1
                     */
                    assert(shpre == 0);

                    regm = cgstate.allregs & ~(mAX | mDX);
                    codelem(cgstate,cdb,e1,regm,false);       // eval left leaf
                    reg = findreg(regm);
                    getregs(cdb,mAX | mDX);
                    genmovreg(cdb,AX,reg);                   // MOV EAX,reg
                    movregconst(cdb, DX, cast(targ_size_t)m, (sz == 8) ? 0x40 : 0);  // MOV EDX,m
                    getregs(cdb,regm | mDX | mAX);
                    cdb.gen2(0xF7,grex | modregrmx(3,4,DX));              // MUL EDX
                    genmovreg(cdb,AX,reg);                   // MOV EAX,reg
                    cdb.gen2(0x2B,grex | modregrm(3,AX,DX));              // SUB EAX,EDX
                    cdb.genc2(0xC1,grex | modregrm(3,5,AX),1);            // SHR EAX,1
                    regm_t regm3 = cgstate.allregs;
                    if (oper == OPmod || oper == OPremquo)
                    {
                        regm3 &= ~regm;
                        if (oper == OPremquo || !el_signx32(e2))
                            regm3 &= ~mAX;
                    }
                    r3 = allocreg(cdb,regm3,TYint);
                    cdb.gen2sib(LEA,grex | modregxrm(0,r3,4),modregrm(0,AX,DX)); // LEA R3,[EAX][EDX]
                    if (shpost != 1)
                        cdb.genc2(0xC1,grex | modregrmx(3,5,r3),shpost-1);   // SHR R3,shpost-1
                }
                else
                {
                    /* q = SRL(MULUH(m, SRL(n, shpre)), shpost)
                     *   SHR   EAX,shpre
                     *   MOV   reg,m
                     *   MUL   reg
                     *   SHR   EDX,shpost
                     */
                    regm = mAX;
                    if (oper == OPmod || oper == OPremquo)
                        regm = cgstate.allregs & ~(mAX|mDX);
                    codelem(cgstate,cdb,e1,regm,false);       // eval left leaf
                    reg = findreg(regm);

                    if (reg != AX)
                    {
                        getregs(cdb,mAX);
                        genmovreg(cdb,AX,reg);                 // MOV EAX,reg
                    }
                    if (shpre)
                    {
                        getregs(cdb,mAX);
                        cdb.genc2(0xC1,grex | modregrm(3,5,AX),shpre);      // SHR EAX,shpre
                    }
                    getregs(cdb,mDX);
                    movregconst(cdb, DX, cast(targ_size_t)m, (sz == 8) ? 0x40 : 0);  // MOV EDX,m
                    getregs(cdb,mDX | mAX);
                    cdb.gen2(0xF7,grex | modregrmx(3,4,DX));                // MUL EDX
                    if (shpost)
                        cdb.genc2(0xC1,grex | modregrm(3,5,DX),shpost);     // SHR EDX,shpost
                    r3 = DX;
                }

                regm_t resreg;
                switch (oper)
                {   case OPdiv:
                        // r3 = quotient
                        resreg = mask(r3);
                        break;

                    case OPmod:
                        /* reg = original value
                         * r3  = quotient
                         */
                        assert(!(regm & mAX));
                        if (el_signx32(e2))
                        {
                            cdb.genc2(0x69,grex | modregrmx(3,AX,r3),e2factor); // IMUL EAX,r3,e2factor
                        }
                        else
                        {
                            assert(!(mask(r3) & mAX));
                            movregconst(cdb,AX,e2factor,(sz == 8) ? 0x40 : 0);  // MOV EAX,e2factor
                            getregs(cdb,mAX);
                            cdb.gen2(0x0FAF,grex | modregrmx(3,AX,r3));   // IMUL EAX,r3
                        }
                        getregs(cdb,regm);
                        cdb.gen2(0x2B,grex | modregxrm(3,reg,AX));        // SUB reg,EAX
                        resreg = regm;
                        break;

                    case OPremquo:
                        /* reg = original value
                         * r3  = quotient
                         */
                        assert(!(mask(r3) & (mAX|regm)));
                        assert(!(regm & mAX));
                        if (el_signx32(e2))
                        {
                            cdb.genc2(0x69,grex | modregrmx(3,AX,r3),e2factor); // IMUL EAX,r3,e2factor
                        }
                        else
                        {
                            movregconst(cdb,AX,e2factor,(sz == 8) ? 0x40 : 0); // MOV EAX,e2factor
                            getregs(cdb,mAX);
                            cdb.gen2(0x0FAF,grex | modregrmx(3,AX,r3));   // IMUL EAX,r3
                        }
                        getregs(cdb,regm);
                        cdb.gen2(0x2B,grex | modregxrm(3,reg,AX));        // SUB reg,EAX
                        genmovreg(cdb, AX, r3);              // MOV EAX,r3
                        genmovreg(cdb, DX, reg);             // MOV EDX,reg
                        resreg = mDX | mAX;
                        break;

                    default:
                        assert(0);
                }
                freenode(e2);
                fixresult(cdb,e,resreg,pretregs);
                return;
            }

            const int pow2 = ispow2(e2factor);

            // Register pair signed divide by power of 2
            if (sz == REGSIZE * 2 &&
                (oper == OPdiv) && !uns &&
                pow2 != -1 &&
                I32 // not set up for I64 cent yet
               )
            {
                regm_t retregs = mDX | mAX;
                if (pow2 == 63 && !(retregs & BYTEREGS & mLSW))
                    retregs = (retregs & mMSW) | (BYTEREGS & mLSW);  // because of SETZ

                codelem(cgstate,cdb,e.E1,retregs,false);  // eval left leaf
                const rhi = findregmsw(retregs);
                const rlo = findreglsw(retregs);
                freenode(e2);
                getregs(cdb,retregs);

                if (pow2 < 32)
                {
                    reg_t r1 = allocScratchReg(cdb, cgstate.allregs & ~retregs);

                    genmovreg(cdb,r1,rhi);                                        // MOV  r1,rhi
                    if (pow2 == 1)
                        cdb.genc2(0xC1,grex | modregrmx(3,5,r1),REGSIZE * 8 - 1); // SHR  r1,31
                    else
                    {
                        cdb.genc2(0xC1,grex | modregrmx(3,7,r1),REGSIZE * 8 - 1); // SAR  r1,31
                        cdb.genc2(0x81,grex | modregrmx(3,4,r1),(1 << pow2) - 1); // AND  r1,mask
                    }
                    cdb.gen2(0x03,grex | modregxrmx(3,rlo,r1));                   // ADD  rlo,r1
                    cdb.genc2(0x81,grex | modregxrmx(3,2,rhi),0);                 // ADC  rhi,0
                    cdb.genc2(0x0FAC,grex | modregrm(3,rhi,rlo),pow2);            // SHRD rlo,rhi,pow2
                    cdb.genc2(0xC1,grex | modregrmx(3,7,rhi),pow2);               // SAR  rhi,pow2
                }
                else if (pow2 == 32)
                {
                    reg_t r1 = allocScratchReg(cdb, cgstate.allregs & ~retregs);

                    genmovreg(cdb,r1,rhi);                                        // MOV r1,rhi
                    cdb.genc2(0xC1,grex | modregrmx(3,7,r1),REGSIZE * 8 - 1);     // SAR r1,31
                    cdb.gen2(0x03,grex | modregxrmx(3,rlo,r1));                   // ADD rlo,r1
                    cdb.genc2(0x81,grex | modregxrmx(3,2,rhi),0);                 // ADC rhi,0
                    cdb.genmovreg(rlo,rhi);                                       // MOV rlo,rhi
                    cdb.genc2(0xC1,grex | modregrmx(3,7,rhi),REGSIZE * 8 - 1);    // SAR rhi,31
                }
                else if (pow2 < 63)
                {
                    reg_t r1 = allocScratchReg(cdb, cgstate.allregs & ~retregs);
                    reg_t r2 = allocScratchReg(cdb, cgstate.allregs & ~(retregs | mask(r1)));

                    genmovreg(cdb,r1,rhi);                                        // MOV r1,rhi
                    cdb.genc2(0xC1,grex | modregrmx(3,7,r1),REGSIZE * 8 - 1);     // SAR r1,31
                    cdb.genmovreg(r2,r1);                                         // MOV r2,r1

                    if (pow2 == 33)
                    {
                        cdb.gen2(0xF7,modregrmx(3,3,r1));                         // NEG r1
                        cdb.gen2(0x03,grex | modregxrmx(3,rlo,r2));               // ADD rlo,r2
                        cdb.gen2(0x13,grex | modregxrmx(3,rhi,r1));               // ADC rhi,r1
                    }
                    else
                    {
                        cdb.genc2(0x81,grex | modregrmx(3,4,r2),(1 << (pow2-32)) - 1); // AND r2,mask
                        cdb.gen2(0x03,grex | modregxrmx(3,rlo,r1));                    // ADD rlo,r1
                        cdb.gen2(0x13,grex | modregxrmx(3,rhi,r2));                    // ADC rhi,r2
                    }

                    cdb.genmovreg(rlo,rhi);                                       // MOV rlo,rhi
                    cdb.genc2(0xC1,grex | modregrmx(3,7,rlo),pow2 - 32);          // SAR rlo,pow2-32
                    cdb.genc2(0xC1,grex | modregrmx(3,7,rhi),REGSIZE * 8 - 1);    // SAR rhi,31
                }
                else
                {
                    // This may be better done by cgelem.d
                    assert(pow2 == 63);
                    cdb.genc2(0x81,grex | modregrmx(3,4,rhi),0x8000_0000); // ADD rhi,0x8000_000
                    cdb.genregs(0x09,rlo,rhi);                             // OR  rlo,rhi
                    cdb.gen2(0x0F94,modregrmx(3,0,rlo));                   // SETZ rlo
                    cdb.genregs(MOVZXb,rlo,rlo);                           // MOVZX rlo,rloL
                    movregconst(cdb,rhi,0,0);                              // MOV rhi,0
                }

                fixresult(cdb,e,retregs,pretregs);
                return;
            }

            // Register pair signed modulo by power of 2
            if (sz == REGSIZE * 2 &&
                (oper == OPmod) && !uns &&
                pow2 != -1 &&
                I32 // not set up for I64 cent yet
               )
            {
                regm_t retregs = mDX | mAX;
                codelem(cgstate,cdb,e.E1,retregs,false);  // eval left leaf
                const rhi = findregmsw(retregs);
                const rlo = findreglsw(retregs);
                freenode(e2);
                getregs(cdb,retregs);

                regm_t scratchm = cgstate.allregs & ~retregs;
                if (pow2 == 63)
                    scratchm &= BYTEREGS;               // because of SETZ
                reg_t r1 = allocScratchReg(cdb, scratchm);

                if (pow2 < 32)
                {
                    cdb.genmovreg(r1,rhi);                                    // MOV r1,rhi
                    cdb.genc2(0xC1,grex | modregrmx(3,7,r1),REGSIZE * 8 - 1); // SAR r1,31
                    cdb.gen2(0x33,grex | modregxrmx(3,rlo,r1));               // XOR rlo,r1
                    cdb.gen2(0x2B,grex | modregxrmx(3,rlo,r1));               // SUB rlo,r1
                    cdb.genc2(0x81,grex | modregrmx(3,4,rlo),(1<<pow2)-1);    // AND rlo,(1<<pow2)-1
                    cdb.gen2(0x33,grex | modregxrmx(3,rlo,r1));               // XOR rlo,r1
                    cdb.gen2(0x2B,grex | modregxrmx(3,rlo,r1));               // SUB rlo,r1
                    cdb.gen2(0x1B,grex | modregxrmx(3,rhi,rhi));              // SBB rhi,rhi
                }
                else if (pow2 == 32)
                {
                    cdb.genmovreg(r1,rhi);                                      // MOV r1,rhi
                    cdb.genc2(0xC1,grex | modregrmx(3,7,r1),REGSIZE * 8 - 1);   // SAR r1,31
                    cdb.gen2(0x03,grex | modregxrmx(3,rlo,r1));                 // ADD rlo,r1
                    cdb.gen2(0x2B,grex | modregxrmx(3,rlo,r1));                 // SUB rlo,r1
                    cdb.gen2(0x1B,grex | modregxrmx(3,rhi,rhi));                // SBB rhi,rhi
                }
                else if (pow2 < 63)
                {
                    reg_t r2 = allocScratchReg(cdb, cgstate.allregs & ~(retregs | mask(r1)));

                    cdb.genmovreg(r1,rhi);                                      // MOV  r1,rhi
                    cdb.genc2(0xC1,grex | modregrmx(3,7,r1),REGSIZE * 8 - 1);   // SAR  r1,31
                    cdb.genmovreg(r2,r1);                                       // MOV  r2,r1
                    cdb.genc2(0x0FAC,grex | modregrm(3,r2,r1),64-pow2);         // SHRD r1,r2,64-pow2
                    cdb.genc2(0xC1,grex | modregrmx(3,5,r2),64-pow2);           // SHR  r2,64-pow2
                    cdb.gen2(0x03,grex | modregxrmx(3,rlo,r1));                 // ADD  rlo,r1
                    cdb.gen2(0x13,grex | modregxrmx(3,rhi,r2));                 // ADC  rhi,r2
                    cdb.genc2(0x81,grex | modregrmx(3,4,rhi),(1<<(pow2-32))-1); // AND  rhi,(1<<(pow2-32))-1
                    cdb.gen2(0x2B,grex | modregxrmx(3,rlo,r1));                 // SUB  rlo,r1
                    cdb.gen2(0x1B,grex | modregxrmx(3,rhi,r2));                 // SBB  rhi,r2
                }
                else
                {
                    // This may be better done by cgelem.d
                    assert(pow2 == 63);

                    cdb.genc1(LEA,grex | modregxrmx(2,r1,rhi), FL.const_, 0x8000_0000); // LEA r1,0x8000_0000[rhi]
                    cdb.gen2(0x0B,grex | modregxrmx(3,r1,rlo));               // OR   r1,rlo
                    cdb.gen2(0x0F94,modregrmx(3,0,r1));                       // SETZ r1
                    cdb.genc2(0xC1,grex | modregrmx(3,4,r1),REGSIZE * 8 - 1); // SHL  r1,31
                    cdb.gen2(0x2B,grex | modregxrmx(3,rhi,r1));               // SUB  rhi,r1
                }

                fixresult(cdb,e,retregs,pretregs);
                return;
            }

            if (sz > REGSIZE || !el_signx32(e2))
                goto default;

            // Special code for signed divide or modulo by power of 2
            if ((sz == REGSIZE || (I64 && sz == 4)) &&
                (oper == OPdiv || oper == OPmod) && !uns &&
                pow2 != -1 &&
                !(config.target_cpu < TARGET_80286 && pow2 != 1 && oper == OPdiv)
               )
            {
                if (pow2 == 1 && oper == OPdiv && config.target_cpu > TARGET_80386)
                {
                    /* MOV r,reg
                       SHR r,31
                       ADD reg,r
                       SAR reg,1
                     */
                    regm_t retregs = cgstate.allregs;
                    codelem(cgstate,cdb,e.E1,retregs,false);  // eval left leaf
                    const reg = findreg(retregs);
                    freenode(e2);
                    getregs(cdb,retregs);

                    reg_t r = allocScratchReg(cdb, cgstate.allregs & ~retregs);
                    genmovreg(cdb,r,reg);                        // MOV r,reg
                    cdb.genc2(0xC1,grex | modregxrmx(3,5,r),(sz * 8 - 1)); // SHR r,31
                    cdb.gen2(0x03,grex | modregxrmx(3,reg,r));   // ADD reg,r
                    cdb.gen2(0xD1,grex | modregrmx(3,7,reg));    // SAR reg,1
                    regm_t resreg = retregs;
                    fixresult(cdb,e,resreg,pretregs);
                    return;
                }

                regm_t resreg;
                switch (oper)
                {
                    case OPdiv:
                        resreg = mAX;
                        break;

                    case OPmod:
                        resreg = mDX;
                        break;

                    case OPremquo:
                        resreg = mDX | mAX;
                        break;

                    default:
                        assert(0);
                }

                regm_t retregs = mAX;
                codelem(cgstate,cdb,e.E1,retregs,false);  // eval left leaf
                freenode(e2);
                getregs(cdb,mAX | mDX);             // modify these regs
                cdb.gen1(0x99);                             // CWD
                code_orrex(cdb.last(), rex);
                if (pow2 == 1)
                {
                    if (oper == OPdiv)
                    {
                        cdb.gen2(0x2B,grex | modregrm(3,AX,DX));  // SUB AX,DX
                        cdb.gen2(0xD1,grex | modregrm(3,7,AX));   // SAR AX,1
                    }
                    else // OPmod
                    {
                        cdb.gen2(0x33,grex | modregrm(3,AX,DX));   // XOR AX,DX
                        cdb.genc2(0x81,grex | modregrm(3,4,AX),1); // AND AX,1
                        cdb.gen2(0x03,grex | modregrm(3,DX,AX));   // ADD DX,AX
                    }
                }
                else
                {   targ_ulong m;

                    m = (1 << pow2) - 1;
                    if (oper == OPdiv)
                    {
                        cdb.genc2(0x81,grex | modregrm(3,4,DX),m);  // AND DX,m
                        cdb.gen2(0x03,grex | modregrm(3,AX,DX));    // ADD AX,DX
                        // Be careful not to generate this for 8088
                        assert(config.target_cpu >= TARGET_80286);
                        cdb.genc2(0xC1,grex | modregrm(3,7,AX),pow2); // SAR AX,pow2
                    }
                    else // OPmod
                    {
                        cdb.gen2(0x33,grex | modregrm(3,AX,DX));    // XOR AX,DX
                        cdb.gen2(0x2B,grex | modregrm(3,AX,DX));    // SUB AX,DX
                        cdb.genc2(0x81,grex | modregrm(3,4,AX),m);  // AND AX,mask
                        cdb.gen2(0x33,grex | modregrm(3,AX,DX));    // XOR AX,DX
                        cdb.gen2(0x2B,grex | modregrm(3,AX,DX));    // SUB AX,DX
                        resreg = mAX;
                    }
                }
                fixresult(cdb,e,resreg,pretregs);
                return;
            }
            goto default;

        case OPind:
            if (!e2.Ecount)                        // if not CSE
                    goto case OPvar;                        // try OP reg,EA
            goto default;

        default:                                    // OPconst and operators
            //printf("test2 %p, retregs = %s rretregs = %s resreg = %s\n", e, regm_str(retregs), regm_str(rretregs), regm_str(resreg));
            regm_t retregs = sz <= REGSIZE ? mAX : mDX | mAX;
            codelem(cgstate,cdb,e1,retregs,false);           // eval left leaf
            regm_t rretregs;
            if (sz <= REGSIZE)                  // dedicated regs for div
            {
                // pick some other regs
                rretregs = isbyte ? BYTEREGS & ~mAX
                                : ALLREGS & ~(mAX|mDX);
            }
            else
            {
                assert(sz <= 2 * REGSIZE);
                rretregs = mCX | mBX;           // second arg
            }
            scodelem(cgstate,cdb,e2,rretregs,retregs,true);  // get rvalue
            if (sz <= REGSIZE)
            {
                getregs(cdb,mAX | mDX);     // trash these regs
                if (uns)                        // unsigned divide
                {
                    movregconst(cdb,DX,0,(sz == 8) ? 64 : 0);  // MOV DX,0
                    getregs(cdb,mDX);
                }
                else
                {
                    cdb.gen1(0x99);                 // CWD
                    code_orrex(cdb.last(),rex);
                }
                reg_t rreg = findreg(rretregs);
                cdb.gen2(0xF7 ^ isbyte,grex | modregrmx(3,7 - uns,rreg)); // OP AX,rreg
                if (I64 && isbyte && rreg >= 4)
                    code_orrex(cdb.last(), REX);
                regm_t resreg;
                switch (oper)
                {
                    case OPdiv:
                        resreg = mAX;
                        break;

                    case OPmod:
                        resreg = mDX;
                        break;

                    case OPremquo:
                        resreg = mDX | mAX;
                        break;

                    default:
                        assert(0);
                }
                fixresult(cdb,e,resreg,pretregs);
            }
            else if (sz == 2 * REGSIZE)
            {
                uint lib;
                switch (oper)
                {
                    case OPdiv:
                    case OPremquo:
                        lib = uns ? CLIB.uldiv : CLIB.ldiv;
                        break;

                    case OPmod:
                        lib = uns ? CLIB.ulmod : CLIB.lmod;
                        break;

                    default:
                        assert(0);
                }

                regm_t keepregs = I32 ? mSI | mDI : 0;
                callclib(cdb,e,lib,pretregs,keepregs);
            }
            else
                    assert(0);
            return;

        case OPvar:
            if (I16 || sz == 2 * REGSIZE)
                goto default;            // have to handle it with codelem(cgstate,)

            // loadea() handles CWD or CLR DX for divides
            regm_t retregs = mAX;
            codelem(cgstate,cdb,e.E1,retregs,false);     // eval left leaf
            loadea(cdb,e2,cs,0xF7 ^ isbyte,7 - uns,0,
                   mAX | mDX,
                   mAX | mDX);
            freenode(e2);
            regm_t resreg;
            switch (oper)
            {
                case OPdiv:
                    resreg = mAX;
                    break;

                case OPmod:
                    resreg = mDX;
                    break;

                case OPremquo:
                    resreg = mDX | mAX;
                    break;

                default:
                    assert(0);
            }
            fixresult(cdb,e,resreg,pretregs);
            return;
    }
    assert(0);
}


/***************************
 * Handle OPnot and OPbool.
 * Generate:
 *      c:      [evaluate e1]
 *      cfalse: [save reg code]
 *              clr     reg
 *              jmp     cnop
 *      ctrue:  [save reg code]
 *              clr     reg
 *              inc     reg
 *      cnop:   nop
 */

@trusted
void cdnot(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdnot(cg, cdb, e, pretregs);

    //printf("cdnot()\n");
    reg_t reg;
    regm_t forflags;
    regm_t retregs;
    elem* e1 = e.E1;

    if (pretregs == 0)
        goto L1;
    if (pretregs == mPSW)
    {   //assert(e.Eoper != OPnot && e.Eoper != OPbool);*/ /* should've been optimized
    L1:
        codelem(cgstate,cdb,e1,pretregs,false);      // evaluate e1 for cc
        return;
    }

    OPER op = e.Eoper;
    uint sz = tysize(e1.Ety);
    uint rex = (I64 && sz == 8) ? REX_W : 0;
    uint grex = rex << 16;

    if (!tyfloating(e1.Ety))
    {
    if (sz <= REGSIZE && e1.Eoper == OPvar)
    {   code cs;

        getlvalue(cdb,cs,e1,0);
        freenode(e1);
        if (!I16 && sz == 2)
            cs.Iflags |= CFopsize;

        retregs = pretregs & (ALLREGS | mBP);
        if (config.target_cpu >= TARGET_80486 &&
            tysize(e.Ety) == 1)
        {
            if (reghasvalue((sz == 1) ? BYTEREGS : ALLREGS,0,reg))
            {
                cs.Iop = 0x39;
                if (I64 && (sz == 1) && reg >= 4)
                    cs.Irex |= REX;
            }
            else
            {   cs.Iop = 0x81;
                reg = 7;
                cs.IFL2 = FL.const_;
                cs.IEV2.Vint = 0;
            }
            cs.Iop ^= (sz == 1);
            code_newreg(&cs,reg);
            cdb.gen(&cs);                             // CMP e1,0

            retregs &= BYTEREGS;
            if (!retregs)
                retregs = BYTEREGS;
            reg = allocreg(cdb,retregs,TYint);

            const opcode_t iop = (op == OPbool)
                ? 0x0F95    // SETNZ rm8
                : 0x0F94;   // SETZ rm8
            cdb.gen2(iop, modregrmx(3,0,reg));
            if (reg >= 4)
                code_orrex(cdb.last(), REX);
            if (op == OPbool)
                pretregs &= ~mPSW;
            goto L4;
        }

        if (reghasvalue((sz == 1) ? BYTEREGS : ALLREGS,1,reg))
            cs.Iop = 0x39;
        else
        {   cs.Iop = 0x81;
            reg = 7;
            cs.IFL2 = FL.const_;
            cs.IEV2.Vint = 1;
        }
        if (I64 && (sz == 1) && reg >= 4)
            cs.Irex |= REX;
        cs.Iop ^= (sz == 1);
        code_newreg(&cs,reg);
        cdb.gen(&cs);                         // CMP e1,1

        reg = allocreg(cdb,retregs,TYint);
        op ^= (OPbool ^ OPnot);                 // switch operators
        goto L2;
    }
    else if (config.target_cpu >= TARGET_80486 &&
        tysize(e.Ety) == 1)
    {
        int jop = jmpopcode(e.E1);
        retregs = mPSW;
        codelem(cgstate,cdb,e.E1,retregs,false);
        retregs = pretregs & BYTEREGS;
        if (!retregs)
            retregs = BYTEREGS;
        reg = allocreg(cdb,retregs,TYint);

        int iop = 0x0F90 | (jop & 0x0F);        // SETcc rm8
        if (op == OPnot)
            iop ^= 1;
        cdb.gen2(iop,grex | modregrmx(3,0,reg));
        if (reg >= 4)
            code_orrex(cdb.last(), REX);
        if (op == OPbool)
            pretregs &= ~mPSW;
        goto L4;
    }
    else if (sz <= REGSIZE &&
        // NEG bytereg is too expensive
        (sz != 1 || config.target_cpu < TARGET_PentiumPro))
    {
        retregs = pretregs & (ALLREGS | mBP);
        if (sz == 1 && !(retregs &= BYTEREGS))
            retregs = BYTEREGS;
        codelem(cgstate,cdb,e.E1,retregs,false);
        reg = findreg(retregs);
        getregs(cdb,retregs);
        cdb.gen2(sz == 1 ? 0xF6 : 0xF7,grex | modregrmx(3,3,reg));   // NEG reg
        code_orflag(cdb.last(),CFpsw);
        if (!I16 && sz == SHORTSIZE)
            code_orflag(cdb.last(),CFopsize);
    L2:
        genregs(cdb,0x19,reg,reg);                  // SBB reg,reg
        code_orrex(cdb.last(), rex);
        // At this point, reg==0 if e1==0, reg==-1 if e1!=0
        if (op == OPnot)
        {
            if (I64)
                cdb.gen2(0xFF,grex | modregrmx(3,0,reg));    // INC reg
            else
                cdb.gen1(0x40 + reg);                        // INC reg
        }
        else
            cdb.gen2(0xF7,grex | modregrmx(3,3,reg));    // NEG reg
        if (pretregs & mPSW)
        {   code_orflag(cdb.last(),CFpsw);
            pretregs &= ~mPSW;         // flags are always set anyway
        }
    L4:
        fixresult(cdb,e,retregs,pretregs);
        return;
    }
    }
    code* cnop = gennop(null);
    code* ctrue = gennop(null);
    logexp(cdb,e.E1,(op == OPnot) ? false : true,FL.code,ctrue);
    forflags = pretregs & mPSW;
    if (I64 && sz == 8)
        forflags |= 64;
    assert(tysize(e.Ety) <= REGSIZE);              // result better be int
    CodeBuilder cdbfalse;
    cdbfalse.ctor();
    reg = allocreg(cdbfalse,pretregs,e.Ety);        // allocate reg for result
    code* cfalse = cdbfalse.finish();
    CodeBuilder cdbtrue;
    cdbtrue.ctor();
    cdbtrue.append(ctrue);
    for (code* c1 = cfalse; c1; c1 = code_next(c1))
        cdbtrue.gen(c1);                                      // duplicate reg save code
    CodeBuilder cdbfalse2;
    cdbfalse2.ctor();
    movregconst(cdbfalse2,reg,0,forflags);                    // mov 0 into reg
    cgstate.regcon.immed.mval &= ~mask(reg);                          // mark reg as unavail
    movregconst(cdbtrue,reg,1,forflags);                      // mov 1 into reg
    cgstate.regcon.immed.mval &= ~mask(reg);                          // mark reg as unavail
    genjmp(cdbfalse2,JMP,FL.code,cast(block*) cnop);          // skip over ctrue
    cdb.append(cfalse);
    cdb.append(cdbfalse2);
    cdb.append(cdbtrue);
    cdb.append(cnop);
}


/************************
 * Complement operator
 */

@trusted
void cdcom(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdcom() pretregs: %s\n", regm_str(pretregs));
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdcom(cg, cdb, e, pretregs);

    if (pretregs == 0)
    {
        codelem(cgstate,cdb,e.E1,pretregs,false);
        return;
    }
    tym_t tym = tybasic(e.Ety);
    int sz = _tysize[tym];
    uint rex = (I64 && sz == 8) ? REX_W : 0;
    regm_t possregs = (sz == 1) ? BYTEREGS : cgstate.allregs;
    regm_t retregs = pretregs & possregs;
    if (retregs == 0)
        retregs = possregs;
    codelem(cgstate,cdb,e.E1,retregs,false);
    getregs(cdb,retregs);                // retregs will be destroyed

    if (0 && sz == 4 * REGSIZE)
    {
        cdb.gen2(0xF7,modregrm(3,2,AX));   // NOT AX
        cdb.gen2(0xF7,modregrm(3,2,BX));   // NOT BX
        cdb.gen2(0xF7,modregrm(3,2,CX));   // NOT CX
        cdb.gen2(0xF7,modregrm(3,2,DX));   // NOT DX
    }
    else
    {
        const reg = (sz <= REGSIZE) ? findreg(retregs) : findregmsw(retregs);
        const op = (sz == 1) ? 0xF6 : 0xF7;
        genregs(cdb,op,2,reg);     // NOT reg
        code_orrex(cdb.last(), rex);
        if (I64 && sz == 1 && reg >= 4)
            code_orrex(cdb.last(), REX);
        if (sz == 2 * REGSIZE)
        {
            const reg2 = findreglsw(retregs);
            genregs(cdb,op,2,reg2);  // NOT reg+1
        }
    }
    fixresult(cdb,e,retregs,pretregs);
}

/************************
 * Bswap operator
 */

@trusted
void cdbswap(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdbswap(cg, cdb, e, pretregs);

    if (pretregs == 0)
    {
        codelem(cgstate,cdb,e.E1,pretregs,false);
        return;
    }

    const tym = tybasic(e.Ety);
    const sz = _tysize[tym];
    const posregs = (sz == 2) ? mAX|mBX|mCX|mDX : cgstate.allregs;
    regm_t retregs = pretregs & posregs;
    if (retregs == 0)
        retregs = posregs;
    codelem(cgstate,cdb,e.E1,retregs,false);
    getregs(cdb,retregs);        // retregs will be destroyed
    if (sz == 2 * REGSIZE)
    {
        assert(sz != 16);                       // no cent support yet
        const msreg = findregmsw(retregs);
        cdb.gen1(0x0FC8 + (msreg & 7));         // BSWAP msreg
        const lsreg = findreglsw(retregs);
        cdb.gen1(0x0FC8 + (lsreg & 7));         // BSWAP lsreg
        cdb.gen2(0x87,modregrm(3,msreg,lsreg)); // XCHG msreg,lsreg
    }
    else
    {
        const reg = findreg(retregs);
        if (sz == 2)
        {
            genregs(cdb,0x86,reg+4,reg);    // XCHG regL,regH
        }
        else
        {
            assert(sz == 4 || sz == 8);
            cdb.gen1(0x0FC8 + (reg & 7));      // BSWAP reg
            ubyte rex = 0;
            if (sz == 8)
                rex |= REX_W;
            if (reg & 8)
                rex |= REX_B;
            if (rex)
                code_orrex(cdb.last(), rex);
        }
    }
    fixresult(cdb,e,retregs,pretregs);
}

/*************************
 * ?: operator
 */

@trusted
void cdcond(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdcond(cg, cdb, e, pretregs);

    /* vars to save state of 8087 */
    NDP[global87.stack.length] _8087old;
    NDP[global87.stack.length] _8087save;

    //printf("cdcond(e = %p, pretregs = %s)\n",e,regm_str(pretregs));
    elem* e1 = e.E1;
    elem* e2 = e.E2;
    elem* e21 = e2.E1;
    elem* e22 = e2.E2;
    regm_t psw = pretregs & mPSW;               /* save PSW bit                 */
    const op1 = e1.Eoper;
    uint sz1 = tysize(e1.Ety);
    uint jop = jmpopcode(e1);

    uint jop1 = jmpopcode(e21);
    uint jop2 = jmpopcode(e22);

    docommas(cdb,e1);
    cgstate.stackclean++;

    if (!OTrel(op1) && e1 == e21 &&
        sz1 <= REGSIZE && !tyfloating(e1.Ety))
    {   // Recognize (e ? e : f)

        code* cnop1 = gennop(null);
        regm_t retregs = pretregs | mPSW;
        codelem(cgstate,cdb,e1,retregs,false);

        cse_flush(cdb,1);                // flush CSEs to memory
        genjmp(cdb,jop,FL.code,cast(block*)cnop1);
        freenode(e21);

        const regconsave = cgstate.regcon;
        const stackpushsave = cgstate.stackpush;

        retregs |= psw;
        if (retregs & (mBP | ALLREGS))
            cgstate.regimmed_set(findreg(retregs),0);
        codelem(cgstate,cdb,e22,retregs,false);

        andregcon(regconsave);
        assert(stackpushsave == cgstate.stackpush);

        pretregs = retregs;
        freenode(e2);
        cdb.append(cnop1);
        cgstate.stackclean--;
        return;
    }

    uint sz2;
    if (OTrel(op1) && sz1 <= REGSIZE && tysize(e2.Ety) <= REGSIZE &&
        !e1.Ecount &&
        (jop == JC || jop == JNC) &&
        (sz2 = tysize(e2.Ety)) <= REGSIZE &&
        e21.Eoper == OPconst &&
        e22.Eoper == OPconst
       )
    {
        uint sz = tysize(e.Ety);
        uint rex = (I64 && sz == 8) ? REX_W : 0;
        uint grex = rex << 16;

        regm_t retregs;
        targ_size_t v1,v2;

        if (sz2 != 1 || I64)
        {
            retregs = pretregs & (ALLREGS | mBP);
            if (!retregs)
                retregs = ALLREGS;
        }
        else
        {
            retregs = pretregs & BYTEREGS;
            if (!retregs)
                retregs = BYTEREGS;
        }

        cg.cmp_flag = 1 | rex;
        v1 = cast(targ_size_t)e21.Vllong;
        v2 = cast(targ_size_t)e22.Vllong;
        if (jop == JNC)
        {   v1 = v2;
            v2 = cast(targ_size_t)e21.Vllong;
        }

        opcode_t opcode = 0x81;
        switch (sz2)
        {   case 1:     opcode--;
                        v1 = cast(byte) v1;
                        v2 = cast(byte) v2;
                        break;

            case 2:     v1 = cast(short) v1;
                        v2 = cast(short) v2;
                        break;

            case 4:     v1 = cast(int) v1;
                        v2 = cast(int) v2;
                        break;
            default:
                        break;
        }

        if (I64 && v1 != cast(targ_ullong)cast(targ_ulong)v1)
        {
            // only zero-extension from 32-bits is available for 'or'
        }
        else if (I64 && cast(targ_llong)v2 != cast(targ_llong)cast(targ_long)v2)
        {
            // only sign-extension from 32-bits is available for 'and'
        }
        else
        {
            codelem(cgstate,cdb,e1,retregs,false);
            const reg = findreg(retregs);

            if (v1 == 0 && v2 == ~cast(targ_size_t)0)
            {
                cdb.gen2(0xF6 + (opcode & 1),grex | modregrmx(3,2,reg));  // NOT reg
                if (I64 && sz2 == REGSIZE)
                    code_orrex(cdb.last(), REX_W);
                if (I64 && sz2 == 1 && reg >= 4)
                    code_orrex(cdb.last(), REX);
            }
            else
            {
                v1 -= v2;
                cdb.genc2(opcode,grex | modregrmx(3,4,reg),v1);   // AND reg,v1-v2
                if (I64 && sz2 == 1 && reg >= 4)
                    code_orrex(cdb.last(), REX);
                if (v2 == 1 && !I64)
                    cdb.gen1(0x40 + reg);                     // INC reg
                else if (v2 == -1L && !I64)
                    cdb.gen1(0x48 + reg);                     // DEC reg
                else
                {   cdb.genc2(opcode,grex | modregrmx(3,0,reg),v2);   // ADD reg,v2
                    if (I64 && sz2 == 1 && reg >= 4)
                        code_orrex(cdb.last(), REX);
                }
            }

            freenode(e21);
            freenode(e22);
            freenode(e2);

            fixresult(cdb,e,retregs,pretregs);
            cgstate.stackclean--;
            return;
        }
    }

    if (op1 != OPcond && op1 != OPandand && op1 != OPoror &&
        op1 != OPnot && op1 != OPbool &&
        e21.Eoper == OPconst &&
        sz1 <= REGSIZE &&
        pretregs & (mBP | ALLREGS) &&
        tysize(e21.Ety) <= REGSIZE && !tyfloating(e21.Ety))
    {   // Recognize (e ? c : f)

        code* cnop1 = gennop(null);
        regm_t retregs = mPSW;
        jop = jmpopcode(e1);            // get jmp condition
        codelem(cgstate,cdb,e1,retregs,false);

        // Set the register with e21 without affecting the flags
        retregs = pretregs & (ALLREGS | mBP);
        if (retregs & ~cgstate.regcon.mvar)
            retregs &= ~cgstate.regcon.mvar;    // don't disturb register variables
        // NOTE: see my email (sign extension bug? possible fix, some questions
        const reg = regwithvalue(cdb,retregs,cast(targ_size_t)e21.Vllong,
                                 tysize(e21.Ety) == 8 ? 64|8 : 8);
        retregs = mask(reg);

        cse_flush(cdb,1);                // flush CSE's to memory
        genjmp(cdb,jop,FL.code,cast(block*)cnop1);
        freenode(e21);

        const regconsave = cgstate.regcon;
        const stackpushsave = cgstate.stackpush;

        codelem(cgstate,cdb,e22,retregs,false);

        andregcon(regconsave);
        assert(stackpushsave == cgstate.stackpush);

        freenode(e2);
        cdb.append(cnop1);
        fixresult(cdb,e,retregs,pretregs);
        cgstate.stackclean--;
        return;
    }

    code* cnop1 = gennop(null);
    code* cnop2 = gennop(null);         // dummy target addresses
    logexp(cdb,e1,false,FL.code,cnop1);  // evaluate condition
    const regconold = cgstate.regcon;
    const stackusedold = global87.stackused;
    const stackpushold = cgstate.stackpush;
    memcpy(_8087old.ptr,global87.stack.ptr,global87.stack.sizeof);
    regm_t retregs = pretregs;
    CodeBuilder cdb1;
    cdb1.ctor();
    if (psw && jop1 != JNE)
    {
        retregs &= ~mPSW;
        if (!retregs)
            retregs = ALLREGS;
        codelem(cgstate,cdb1,e21,retregs,false);
        fixresult(cdb1,e21,retregs,pretregs);
    }
    else
        codelem(cgstate,cdb1,e21,retregs,false);

    if (CPP && e2.Eoper == OPcolon2)
    {
        code cs;

        // This is necessary so that any cleanup code on one branch
        // is redone on the other branch.
        cs.Iop = PSOP.mark2;
        cs.Iflags = 0;
        cs.Irex = 0;
        cdb.gen(&cs);
        cdb.append(cdb1);
        cs.Iop = PSOP.release2;
        cdb.gen(&cs);
    }
    else
        cdb.append(cdb1);

    const regconsave = cgstate.regcon;
    cgstate.regcon = cast()regconold;

    const stackpushsave = cgstate.stackpush;
    cgstate.stackpush = stackpushold;

    const stackusedsave = global87.stackused;
    global87.stackused = stackusedold;

    memcpy(_8087save.ptr,global87.stack.ptr,global87.stack.sizeof);
    memcpy(global87.stack.ptr,_8087old.ptr,global87.stack.sizeof);

    retregs |= psw;                     // PSW bit may have been trashed
    pretregs |= psw;
    CodeBuilder cdb2;
    cdb2.ctor();
    if (psw && jop2 != JNE)
    {
        retregs &= ~mPSW;
        if (!retregs)
            retregs = ALLREGS;
        codelem(cgstate,cdb2,e22,retregs,false);
        fixresult(cdb2,e22,retregs,pretregs);
    }
    else
        codelem(cgstate,cdb2,e22,retregs,false);   // use same regs as E1
    pretregs = retregs | psw;
    andregcon(regconold);
    andregcon(regconsave);
    assert(global87.stackused == stackusedsave);
    assert(cgstate.stackpush == stackpushsave);
    memcpy(global87.stack.ptr,_8087save.ptr,global87.stack.sizeof);
    freenode(e2);
    genjmp(cdb,JMP,FL.code,cast(block*) cnop2);
    cdb.append(cnop1);
    cdb.append(cdb2);
    cdb.append(cnop2);
    if (pretregs & mST0)
        note87(e,0,0);

    cgstate.stackclean--;
}

/*********************
 * Comma operator OPcomma
 */

@trusted
void cdcomma(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    regm_t retregs = 0;
    codelem(cgstate,cdb,e.E1,retregs,false);   // ignore value from left leaf
    codelem(cgstate,cdb,e.E2,pretregs,false);   // do right leaf
}


/*********************************
 * Do && and || operators.
 * Generate:
 *              (evaluate e1 and e2, if true goto cnop1)
 *      cnop3:  NOP
 *      cg:     [save reg code]         ;if we must preserve reg
 *              CLR     reg             ;false result (set Z also)
 *              JMP     cnop2
 *
 *      cnop1:  NOP                     ;if e1 evaluates to true
 *              [save reg code]         ;preserve reg
 *
 *              MOV     reg,1           ;true result
 *                  or
 *              CLR     reg             ;if return result in flags
 *              INC     reg
 *
 *      cnop2:  NOP                     ;mark end of code
 */

@trusted
void cdloglog(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdloglog(cg, cdb, e, pretregs);

    /* We can trip the assert with the following:
     *    if ( (b<=a) ? (c<b || a<=c) : c>=a )
     * We'll generate ugly code for it, but it's too obscure a case
     * to expend much effort on it.
     * assert(pretregs != mPSW);
     */

    //printf("cdloglog() pretregs: %s\n", regm_str(pretregs));
    cgstate.stackclean++;
    code* cnop1 = gennop(null);
    CodeBuilder cdb1;
    cdb1.ctor();
    cdb1.append(cnop1);
    code* cnop3 = gennop(null);
    elem* e2 = e.E2;
    (e.Eoper == OPoror)
        ? logexp(cdb,e.E1,1,FL.code,cnop1)
        : logexp(cdb,e.E1,0,FL.code,cnop3);
    con_t regconsave = cgstate.regcon;
    uint stackpushsave = cgstate.stackpush;
    if (pretregs == 0)                 // if don't want result
    {
        int noreturn = !el_returns(e2);
        codelem(cgstate,cdb,e2,pretregs,false);
        if (noreturn)
        {
            regconsave.used |= cgstate.regcon.used;
            cgstate.regcon = regconsave;
        }
        else
            andregcon(regconsave);
        assert(cgstate.stackpush == stackpushsave);
        cdb.append(cnop3);
        cdb.append(cdb1);        // eval code, throw away result
        cgstate.stackclean--;
        return;
    }

    if (tybasic(e2.Ety) == TYnoreturn)
    {
        regm_t retregs2 = 0;
        codelem(cgstate,cdb, e2, retregs2, false);
        regconsave.used |= cgstate.regcon.used;
        cgstate.regcon = regconsave;
        assert(cgstate.stackpush == stackpushsave);

        regm_t retregs = pretregs & (ALLREGS | mBP);
        if (!retregs)
            retregs = ALLREGS;                                   // if mPSW only

        const reg = allocreg(cdb1,retregs,TYint);                     // allocate reg for result
        movregconst(cdb1,reg,e.Eoper == OPoror,pretregs & mPSW);
        cgstate.regcon.immed.mval &= ~mask(reg);                        // mark reg as unavail
        pretregs = retregs;

        cdb.append(cnop3);
        cdb.append(cdb1);        // eval code, throw away result
        cgstate.stackclean--;
        return;
    }

    code* cnop2 = gennop(null);
    uint sz = tysize(e.Ety);
    if (tybasic(e2.Ety) == TYbool &&
      sz == tysize(e2.Ety) &&
      !(pretregs & mPSW) &&
      e2.Eoper == OPcall)
    {
        codelem(cgstate,cdb,e2,pretregs,false);

        andregcon(regconsave);

        // stack depth should not change when evaluating E2
        assert(cgstate.stackpush == stackpushsave);

        assert(sz <= 4);                                        // result better be int
        regm_t retregs = pretregs & cgstate.allregs;
        const reg = allocreg(cdb1,retregs,TYint);                     // allocate reg for result
        movregconst(cdb1,reg,e.Eoper == OPoror,0);             // reg = 1
        cgstate.regcon.immed.mval &= ~mask(reg);                        // mark reg as unavail
        pretregs = retregs;
        if (e.Eoper == OPoror)
        {
            cdb.append(cnop3);
            genjmp(cdb,JMP,FL.code,cast(block*) cnop2);    // JMP cnop2
            cdb.append(cdb1);
            cdb.append(cnop2);
        }
        else
        {
            genjmp(cdb,JMP,FL.code,cast(block*) cnop2);    // JMP cnop2
            cdb.append(cnop3);
            cdb.append(cdb1);
            cdb.append(cnop2);
        }
        cgstate.stackclean--;
        return;
    }

    logexp(cdb,e2,1,FL.code,cnop1);
    andregcon(regconsave);

    // stack depth should not change when evaluating E2
    assert(cgstate.stackpush == stackpushsave);

    assert(sz <= 4);                                         // result better be int
    regm_t retregs = pretregs & (ALLREGS | mBP);
    if (!retregs)
        retregs = ALLREGS;                                   // if mPSW only
    CodeBuilder cdbcg;
    cdbcg.ctor();
    const reg = allocreg(cdbcg,retregs,TYint);               // allocate reg for result
    code* cd = cdbcg.finish();
    for (code* c1 = cd; c1; c1 = code_next(c1))              // for each instruction
        cdb1.gen(c1);                                        // duplicate it
    CodeBuilder cdbcg2;
    cdbcg2.ctor();
    movregconst(cdbcg2,reg,0,pretregs & mPSW);              // MOV reg,0
    cgstate.regcon.immed.mval &= ~mask(reg);                 // mark reg as unavail
    genjmp(cdbcg2, JMP,FL.code,cast(block*) cnop2);          // JMP cnop2
    movregconst(cdb1,reg,1,pretregs & mPSW);                // reg = 1
    cgstate.regcon.immed.mval &= ~mask(reg);                 // mark reg as unavail
    pretregs = retregs;
    cdb.append(cnop3);
    cdb.append(cd);
    cdb.append(cdbcg2);
    cdb.append(cdb1);
    cdb.append(cnop2);
    cgstate.stackclean--;
}


/*********************
 * Generate code for shift left or shift right (OPshl,OPshr,OPashr,OProl,OPror).
 */

@trusted
void cdshift(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdshift(cg, cdb, e, pretregs);

    //printf("cdshift()\n");
    reg_t resreg;
    uint shiftcnt;
    regm_t retregs,rretregs;

    elem* e1 = e.E1;
    if (pretregs == 0)                   // if don't want result
    {
        codelem(cgstate,cdb,e1,pretregs,false); // eval left leaf
        pretregs = 0;                  // in case they got set
        codelem(cgstate,cdb,e.E2,pretregs,false);
        return;
    }

    tym_t tyml = tybasic(e1.Ety);
    int sz = _tysize[tyml];
    assert(!tyfloating(tyml));
    OPER oper = e.Eoper;
    uint grex = ((I64 && sz == 8) ? REX_W : 0) << 16;

    uint s1,s2;
    switch (oper)
    {
        case OPshl:
            s1 = 4;                     // SHL
            s2 = 2;                     // RCL
            break;
        case OPshr:
            s1 = 5;                     // SHR
            s2 = 3;                     // RCR
            break;
        case OPashr:
            s1 = 7;                     // SAR
            s2 = 3;                     // RCR
            break;
        case OProl:
            s1 = 0;                     // ROL
            break;
        case OPror:
            s1 = 1;                     // ROR
            break;
        default:
            assert(0);
    }

    reg_t sreg = NOREG;                   // guard against using value without assigning to sreg
    elem* e2 = e.E2;
    regm_t forccs = pretregs & mPSW;            // if return result in CCs
    regm_t forregs = pretregs & (ALLREGS | mBP); // mask of possible return regs
    bool e2isconst = false;                    // assume for the moment
    uint isbyte = (sz == 1);
    switch (e2.Eoper)
    {
        case OPconst:
            e2isconst = true;               // e2 is a constant
            shiftcnt = e2.Vint;         // get shift count
            if ((!I16 && sz <= REGSIZE) ||
                shiftcnt <= 4 ||            // if sequence of shifts
                (sz == 2 &&
                    (shiftcnt == 8 || config.target_cpu >= TARGET_80286)) ||
                (sz == 2 * REGSIZE && shiftcnt == 8 * REGSIZE)
               )
            {
                retregs = (forregs) ? forregs
                                    : ALLREGS;
                if (isbyte)
                {   retregs &= BYTEREGS;
                    if (!retregs)
                        retregs = BYTEREGS;
                }
                else if (sz > REGSIZE && sz <= 2 * REGSIZE &&
                         !(retregs & mMSW))
                    retregs |= mMSW & ALLREGS;
                if (s1 == 7)    // if arithmetic right shift
                {
                    if (shiftcnt == 8)
                        retregs = mAX;
                    else if (sz == 2 * REGSIZE && shiftcnt == 8 * REGSIZE)
                        retregs = mDX|mAX;
                }

                if (sz == 2 * REGSIZE && shiftcnt == 8 * REGSIZE &&
                    oper == OPshl &&
                    !e1.Ecount &&
                    (e1.Eoper == OPs16_32 || e1.Eoper == OPu16_32 ||
                     e1.Eoper == OPs32_64 || e1.Eoper == OPu32_64)
                   )
                {   // Handle (shtlng)s << 16
                    regm_t r = retregs & mMSW;
                    codelem(cgstate,cdb,e1.E1,r,false);      // eval left leaf
                    resreg = regwithvalue(cdb,retregs & mLSW,0,0);
                    getregs(cdb,r);
                    retregs = r | mask(resreg);
                    if (forccs)
                    {   sreg = findreg(r);
                        gentstreg(cdb,sreg);
                        pretregs &= ~mPSW;             // already set
                    }
                    freenode(e1);
                    freenode(e2);
                    break;
                }

                // See if we should use LEA reg,xxx instead of shift
                if (!I16 && shiftcnt >= 1 && shiftcnt <= 3 &&
                    (sz == REGSIZE || (I64 && sz == 4)) &&
                    oper == OPshl &&
                    e1.Eoper == OPvar &&
                    !(pretregs & mPSW) &&
                    config.flags4 & CFG4speed
                   )
                {
                    reg_t reg;
                    regm_t regm;

                    if (isregvar(e1,regm,reg) && !(regm & retregs))
                    {   code cs;
                        resreg = allocreg(cdb,retregs,e.Ety);
                        buildEA(&cs,-1,reg,1 << shiftcnt,0);
                        cs.Iop = LEA;
                        code_newreg(&cs,resreg);
                        cs.Iflags = 0;
                        if (I64 && sz == 8)
                            cs.Irex |= REX_W;
                        cdb.gen(&cs);             // LEA resreg,[reg * ss]
                        freenode(e1);
                        freenode(e2);
                        break;
                    }
                }

                codelem(cgstate,cdb,e1,retregs,false); // eval left leaf
                //assert((retregs & cgstate.regcon.mvar) == 0);
                getregs(cdb,retregs);          // modify these regs

                {
                    if (sz == 2 * REGSIZE)
                    {   resreg = findregmsw(retregs);
                        sreg = findreglsw(retregs);
                    }
                    else
                    {   resreg = findreg(retregs);
                        sreg = NOREG;              // an invalid value
                    }
                    if (config.target_cpu >= TARGET_80286 &&
                        sz <= REGSIZE)
                    {
                        // SHL resreg,shiftcnt
                        assert(!(sz == 1 && (mask(resreg) & ~BYTEREGS)));
                        cdb.genc2(0xC1 ^ isbyte,grex | modregxrmx(3,s1,resreg),shiftcnt);
                        if (shiftcnt == 1)
                            cdb.last().Iop += 0x10;     // short form of shift
                        if (I64 && sz == 1 && resreg >= 4)
                            cdb.last().Irex |= REX;
                        // See if we need operand size prefix
                        if (!I16 && oper != OPshl && sz == 2)
                            cdb.last().Iflags |= CFopsize;
                        if (forccs)
                            cdb.last().Iflags |= CFpsw;         // need flags result
                    }
                    else if (shiftcnt == 8)
                    {   if (!(retregs & BYTEREGS) || resreg >= 4)
                        {
                            goto L1;
                        }

                        if (cgstate.pass != BackendPass.final_ && (!forregs || forregs & (mSI | mDI)))
                        {
                            // e1 might get into SI or DI in a later pass,
                            // so don't put CX into a register
                            getregs(cdb,mCX);
                        }

                        assert(sz == 2);
                        switch (oper)
                        {
                            case OPshl:
                                // MOV regH,regL        XOR regL,regL
                                assert(resreg < 4 && !grex);
                                genregs(cdb,0x8A,resreg+4,resreg);
                                genregs(cdb,0x32,resreg,resreg);
                                break;

                            case OPshr:
                            case OPashr:
                                // MOV regL,regH
                                genregs(cdb,0x8A,resreg,resreg+4);
                                if (oper == OPashr)
                                    cdb.gen1(0x98);           // CBW
                                else
                                    genregs(cdb,0x32,resreg+4,resreg+4); // CLR regH
                                break;

                            case OPror:
                            case OProl:
                                // XCHG regL,regH
                                genregs(cdb,0x86,resreg+4,resreg);
                                break;

                            default:
                                assert(0);
                        }
                        if (forccs)
                            gentstreg(cdb,resreg);
                    }
                    else if (shiftcnt == REGSIZE * 8)   // it's an lword
                    {
                        if (oper == OPshl)
                            swap(resreg, sreg);
                        genmovreg(cdb,sreg,resreg);  // MOV sreg,resreg
                        if (oper == OPashr)
                            cdb.gen1(0x99);                       // CWD
                        else
                            movregconst(cdb,resreg,0,0);  // MOV resreg,0
                        if (forccs)
                        {
                            gentstreg(cdb,sreg);
                            pretregs &= mBP | ALLREGS | mES;
                        }
                    }
                    else
                    {
                        if (oper == OPshl && sz == 2 * REGSIZE)
                            swap(resreg, sreg);
                        while (shiftcnt--)
                        {
                            cdb.gen2(0xD1 ^ isbyte,modregrm(3,s1,resreg));
                            if (sz == 2 * REGSIZE)
                            {
                                code_orflag(cdb.last(),CFpsw);
                                cdb.gen2(0xD1,modregrm(3,s2,sreg));
                            }
                        }
                        if (forccs)
                            code_orflag(cdb.last(),CFpsw);
                    }
                    if (sz <= REGSIZE)
                        pretregs &= mBP | ALLREGS;     // flags already set
                }
                freenode(e2);
                break;
            }
            goto default;

        default:
            retregs = forregs & ~mCX;               // CX will be shift count
            if (sz <= REGSIZE)
            {
                if (forregs & ~cgstate.regcon.mvar && !(retregs & ~cgstate.regcon.mvar))
                    retregs = ALLREGS & ~mCX;       // need something
                else if (!retregs)
                    retregs = ALLREGS & ~mCX;       // need something
                if (sz == 1)
                {   retregs &= mAX|mBX|mDX;
                    if (!retregs)
                        retregs = mAX|mBX|mDX;
                }
            }
            else
            {
                if (!(retregs & mMSW))
                    retregs = ALLREGS & ~mCX;
            }
            codelem(cgstate,cdb,e.E1,retregs,false);     // eval left leaf

            if (sz <= REGSIZE)
                resreg = findreg(retregs);
            else
            {
                resreg = findregmsw(retregs);
                sreg = findreglsw(retregs);
            }
        L1:
            rretregs = mCX;                 // CX is shift count
            if (sz <= REGSIZE)
            {
                scodelem(cgstate,cdb,e2,rretregs,retregs,false); // get rvalue
                getregs(cdb,retregs);      // trash these regs
                cdb.gen2(0xD3 ^ isbyte,grex | modregrmx(3,s1,resreg)); // Sxx resreg,CX

                if (!I16 && sz == 2 && (oper == OProl || oper == OPror))
                    cdb.last().Iflags |= CFopsize;

                // Note that a shift by CL does not set the flags if
                // CL == 0. If e2 is a constant, we know it isn't 0
                // (it would have been optimized out).
                if (e2isconst)
                    pretregs &= mBP | ALLREGS; // flags already set with result
            }
            else if (sz == 2 * REGSIZE &&
                     config.target_cpu >= TARGET_80386)
            {
                reg_t hreg = resreg;
                reg_t lreg = sreg;
                uint rex = I64 ? (REX_W << 16) : 0;
                if (e2isconst)
                {
                    getregs(cdb,retregs);
                    if (shiftcnt & (REGSIZE * 8))
                    {
                        if (oper == OPshr)
                        {   //      SHR hreg,shiftcnt
                            //      MOV lreg,hreg
                            //      XOR hreg,hreg
                            cdb.genc2(0xC1,rex | modregrm(3,s1,hreg),shiftcnt - (REGSIZE * 8));
                            genmovreg(cdb,lreg,hreg);
                            movregconst(cdb,hreg,0,0);
                        }
                        else if (oper == OPashr)
                        {   //      MOV     lreg,hreg
                            //      SAR     hreg,31
                            //      SHRD    lreg,hreg,shiftcnt
                            genmovreg(cdb,lreg,hreg);
                            cdb.genc2(0xC1,rex | modregrm(3,s1,hreg),(REGSIZE * 8) - 1);
                            cdb.genc2(0x0FAC,rex | modregrm(3,hreg,lreg),shiftcnt - (REGSIZE * 8));
                        }
                        else
                        {   //      SHL lreg,shiftcnt
                            //      MOV hreg,lreg
                            //      XOR lreg,lreg
                            cdb.genc2(0xC1,rex | modregrm(3,s1,lreg),shiftcnt - (REGSIZE * 8));
                            genmovreg(cdb,hreg,lreg);
                            movregconst(cdb,lreg,0,0);
                        }
                    }
                    else
                    {
                        if (oper == OPshr || oper == OPashr)
                        {   //      SHRD    lreg,hreg,shiftcnt
                            //      SHR/SAR hreg,shiftcnt
                            cdb.genc2(0x0FAC,rex | modregrm(3,hreg,lreg),shiftcnt);
                            cdb.genc2(0xC1,rex | modregrm(3,s1,hreg),shiftcnt);
                        }
                        else
                        {   //      SHLD hreg,lreg,shiftcnt
                            //      SHL  lreg,shiftcnt
                            cdb.genc2(0x0FA4,rex | modregrm(3,lreg,hreg),shiftcnt);
                            cdb.genc2(0xC1,rex | modregrm(3,s1,lreg),shiftcnt);
                        }
                    }
                    freenode(e2);
                }
                else if (config.target_cpu >= TARGET_80486 && REGSIZE == 2)
                {
                    scodelem(cgstate,cdb,e2,rretregs,retregs,false); // get rvalue in CX
                    getregs(cdb,retregs);          // modify these regs
                    if (oper == OPshl)
                    {
                        /*
                            SHLD    hreg,lreg,CL
                            SHL     lreg,CL
                         */

                        cdb.gen2(0x0FA5,modregrm(3,lreg,hreg));
                        cdb.gen2(0xD3,modregrm(3,4,lreg));
                    }
                    else
                    {
                        /*
                            SHRD    lreg,hreg,CL
                            SAR             hreg,CL

                            -- or --

                            SHRD    lreg,hreg,CL
                            SHR             hreg,CL
                         */
                        cdb.gen2(0x0FAD,modregrm(3,hreg,lreg));
                        cdb.gen2(0xD3,modregrm(3,s1,hreg));
                    }
                }
                else
                {   code* cl1,cl2;

                    scodelem(cgstate,cdb,e2,rretregs,retregs,false); // get rvalue in CX
                    getregs(cdb,retregs | mCX);     // modify these regs
                                                            // TEST CL,0x20
                    cdb.genc2(0xF6,modregrm(3,0,CX),REGSIZE * 8);
                    cl1 = gennop(null);
                    CodeBuilder cdb1;
                    cdb1.ctor();
                    cdb1.append(cl1);
                    if (oper == OPshl)
                    {
                        /*  TEST    CL,20H
                            JNE     L1
                            SHLD    hreg,lreg,CL
                            SHL     lreg,CL
                            JMP     L2
                        L1: AND     CL,20H-1
                            SHL     lreg,CL
                            MOV     hreg,lreg
                            XOR     lreg,lreg
                        L2: NOP
                         */

                        if (REGSIZE == 2)
                            cdb1.genc2(0x80,modregrm(3,4,CX),REGSIZE * 8 - 1);
                        cdb1.gen2(0xD3,modregrm(3,4,lreg));
                        genmovreg(cdb1,hreg,lreg);
                        genregs(cdb1,0x31,lreg,lreg);

                        genjmp(cdb,JNE,FL.code,cast(block*)cl1);
                        cdb.gen2(0x0FA5,modregrm(3,lreg,hreg));
                        cdb.gen2(0xD3,modregrm(3,4,lreg));
                    }
                    else
                    {   if (oper == OPashr)
                        {
                            /*  TEST        CL,20H
                                JNE         L1
                                SHRD        lreg,hreg,CL
                                SAR         hreg,CL
                                JMP         L2
                            L1: AND         CL,15
                                MOV         lreg,hreg
                                SAR         hreg,31
                                SHRD        lreg,hreg,CL
                            L2: NOP
                             */

                            if (REGSIZE == 2)
                                cdb1.genc2(0x80,modregrm(3,4,CX),REGSIZE * 8 - 1);
                            genmovreg(cdb1,lreg,hreg);
                            cdb1.genc2(0xC1,modregrm(3,s1,hreg),31);
                            cdb1.gen2(0x0FAD,modregrm(3,hreg,lreg));
                        }
                        else
                        {
                            /*  TEST        CL,20H
                                JNE         L1
                                SHRD        lreg,hreg,CL
                                SHR         hreg,CL
                                JMP         L2
                            L1: AND         CL,15
                                SHR         hreg,CL
                                MOV         lreg,hreg
                                XOR         hreg,hreg
                            L2: NOP
                             */

                            if (REGSIZE == 2)
                                cdb1.genc2(0x80,modregrm(3,4,CX),REGSIZE * 8 - 1);
                            cdb1.gen2(0xD3,modregrm(3,5,hreg));
                            genmovreg(cdb1,lreg,hreg);
                            genregs(cdb1,0x31,hreg,hreg);
                        }
                        genjmp(cdb,JNE,FL.code,cast(block*)cl1);
                        cdb.gen2(0x0FAD,modregrm(3,hreg,lreg));
                        cdb.gen2(0xD3,modregrm(3,s1,hreg));
                    }
                    cl2 = gennop(null);
                    genjmp(cdb,JMPS,FL.code,cast(block*)cl2);
                    cdb.append(cdb1);
                    cdb.append(cl2);
                }
                break;
            }
            else if (sz == 2 * REGSIZE)
            {
                scodelem(cgstate,cdb,e2,rretregs,retregs,false);
                getregs(cdb,retregs | mCX);
                if (oper == OPshl)
                    swap(resreg, sreg);
                if (!e2isconst)                   // if not sure shift count != 0
                    cdb.genc2(0xE3,0,6);          // JCXZ .+6
                cdb.gen2(0xD1,modregrm(3,s1,resreg));
                code_orflag(cdb.last(),CFtarg2);
                cdb.gen2(0xD1,modregrm(3,s2,sreg));
                cdb.genc2(0xE2,0,cast(targ_uns)-6);          // LOOP .-6
                cgstate.regimmed_set(CX,0);         // note that now CX == 0
            }
            else
                assert(0);
            break;
    }
    fixresult(cdb,e,retregs,pretregs);
}


/***************************
 * Perform a 'star' reference (indirection).
 */

@trusted
void cdind(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdind(cg, cdb, e, pretregs);

    regm_t retregs;
    reg_t reg;
    uint nreg;

    //printf("cdind(e = %p, pretregs = %s)\n",e,regm_str(pretregs));
    tym_t tym = tybasic(e.Ety);
    if (tyfloating(tym))
    {
        if (config.inline8087)
        {
            if (pretregs & mST0)
            {
                cdind87(cdb, e, pretregs);
                return;
            }
            if (I64 && tym == TYcfloat && pretregs & (ALLREGS | mBP))
            { }
            else if (tycomplex(tym))
            {
                cload87(cdb, e, pretregs);
                return;
            }

            if (pretregs & mPSW)
            {
                cdind87(cdb, e, pretregs);
                return;
            }
        }
    }

    elem* e1 = e.E1;
    assert(e1);
    switch (tym)
    {
        case TYstruct:
        case TYarray:
            // This case should never happen, why is it here?
            tym = TYnptr;               // don't confuse allocreg()
            if (pretregs & (mES | mCX) || e.Ety & mTYfar)
                    tym = TYfptr;
            break;

        default:
            break;
    }
    uint sz = _tysize[tym];
    uint isbyte = tybyte(tym) != 0;

    code cs;

     getlvalue(cdb,cs,e,0,RM.load);          // get addressing mode
    //printf("Irex = %02x, Irm = x%02x, Isib = x%02x\n", cs.Irex, cs.Irm, cs.Isib);
    //fprintf(stderr,"cd2 :\n"); WRcodlst(c);
    if (pretregs == 0)
    {
        if (e.Ety & mTYvolatile)               // do the load anyway
            pretregs = regmask(e.Ety, 0);     // load into registers
        else
            return;
    }

    regm_t idxregs = idxregm(&cs);               // mask of index regs used

    if (pretregs == mPSW)
    {
        if (!I16 && tym == TYfloat)
        {
            retregs = ALLREGS & ~idxregs;
            reg = allocreg(cdb,retregs,TYfloat);
            cs.Iop = 0x8B;
            code_newreg(&cs,reg);
            cdb.gen(&cs);                       // MOV reg,lsw
            cdb.gen2(0xD1,modregrmx(3,4,reg));  // SHL reg,1
            code_orflag(cdb.last(), CFpsw);
        }
        else if (sz <= REGSIZE)
        {
            cs.Iop = 0x81 ^ isbyte;
            cs.Irm |= modregrm(0,7,0);
            cs.IFL2 = FL.const_;
            cs.IEV2.Vsize_t = 0;
            cdb.gen(&cs);             // CMP [idx],0
        }
        else if (!I16 && sz == REGSIZE + 2)      // if far pointer
        {
            retregs = ALLREGS & ~idxregs;
            reg = allocreg(cdb,retregs,TYint);
            cs.Iop = MOVZXw;
            cs.Irm |= modregrm(0,reg,0);
            getlvalue_msw(cs);
            cdb.gen(&cs);             // MOVZX reg,msw
            goto L4;
        }
        else if (sz <= 2 * REGSIZE)
        {
            retregs = ALLREGS & ~idxregs;
            reg = allocreg(cdb,retregs,TYint);
            cs.Iop = 0x8B;
            code_newreg(&cs,reg);
            getlvalue_msw(cs);
            cdb.gen(&cs);             // MOV reg,msw
            if (I32)
            {   if (tym == TYdouble || tym == TYdouble_alias)
                    cdb.gen2(0xD1,modregrm(3,4,reg)); // SHL reg,1
            }
            else if (tym == TYfloat)
                cdb.gen2(0xD1,modregrm(3,4,reg));    // SHL reg,1
        L4:
            cs.Iop = 0x0B;
            getlvalue_lsw(cs);
            cs.Iflags |= CFpsw;
            cdb.gen(&cs);                    // OR reg,lsw
        }
        else if (!I32 && sz == 8)
        {
            pretregs |= DOUBLEREGS_16;     // fake it for now
            goto L1;
        }
        else
        {
            debug printf("%s\n", tym_str(tym));
            assert(0);
        }
    }
    else                                // else return result in reg
    {
    L1:
        retregs = pretregs;
        if (sz == 8 &&
            (retregs & (mPSW | mSTACK | ALLREGS | mBP)) == mSTACK)
        {   int i;

            // Optimizer should not CSE these, as the result is worse code!
            assert(!e.Ecount);

            cs.Iop = 0xFF;
            cs.Irm |= modregrm(0,6,0);
            cs.IEV1.Voffset += 8 - REGSIZE;
            cgstate.stackchanged = 1;
            i = 8 - REGSIZE;
            do
            {
                cdb.gen(&cs);                         // PUSH EA+i
                cdb.genadjesp(REGSIZE);
                cs.IEV1.Voffset -= REGSIZE;
                cgstate.stackpush += REGSIZE;
                i -= REGSIZE;
            }
            while (i >= 0);
            goto L3;
        }
        if (I16 && sz == 8)
            retregs = DOUBLEREGS_16;

        // Watch out for loading an lptr from an lptr! We must have
        // the offset loaded into a different register.
        /*if (retregs & mES && (cs.Iflags & CFSEG) == CFes)
                retregs = ALLREGS;*/

        {
            assert(!isbyte || retregs & BYTEREGS);
            reg = allocreg(cdb,retregs,tym); // alloc registers
        }
        if (retregs & XMMREGS)
        {
            assert(sz == 4 || sz == 8 || sz == 16 || sz == 32); // float, double or vector
            cs.Iop = xmmload(tym);
            cs.Irex &= ~REX_W;
            code_newreg(&cs,reg - XMM0);
            checkSetVex(&cs,tym);
            cdb.gen(&cs);     // MOV reg,[idx]
        }
        else if (sz <= REGSIZE)
        {
            cs.Iop = 0x8B;                                  // MOV
            if (sz <= 2 && !I16 &&
                config.target_cpu >= TARGET_PentiumPro && config.flags4 & CFG4speed)
            {
                cs.Iop = tyuns(tym) ? MOVZXw : MOVSXw;      // MOVZX/MOVSX
                cs.Iflags &= ~CFopsize;
            }
            cs.Iop ^= isbyte;
        L2:
            code_newreg(&cs,reg);
            cdb.gen(&cs);     // MOV reg,[idx]
            if (isbyte && reg >= 4)
                code_orrex(cdb.last(), REX);
        }
        else if ((tym == TYfptr || tym == TYhptr) && retregs & mES)
        {
            cs.Iop = 0xC4;          // LES reg,[idx]
            goto L2;
        }
        else if (sz <= 2 * REGSIZE)
        {   uint lsreg;

            cs.Iop = 0x8B;
            // Be careful not to interfere with index registers
            if (!I16)
            {
                // Can't handle if both result registers are used in
                // the addressing mode.
                if ((retregs & idxregs) == retregs)
                {
                    retregs = mMSW & cgstate.allregs & ~idxregs;
                    if (!retregs)
                        retregs |= mCX;
                    retregs |= mLSW & ~idxregs;

                    // We can run out of registers, so if that's possible,
                    // give us* one* of the idxregs
                    if ((retregs & ~cgstate.regcon.mvar & mLSW) == 0)
                    {
                        regm_t x = idxregs & mLSW;
                        if (x)
                            retregs |= mask(findreg(x));        // give us one idxreg
                    }
                    else if ((retregs & ~cgstate.regcon.mvar & mMSW) == 0)
                    {
                        regm_t x = idxregs & mMSW;
                        if (x)
                            retregs |= mask(findreg(x));        // give us one idxreg
                    }

                    reg = allocreg(cdb,retregs,tym);     // alloc registers
                    assert((retregs & idxregs) != retregs);
                }

                lsreg = findreglsw(retregs);
                if (mask(reg) & idxregs)                // reg is in addr mode
                {
                    code_newreg(&cs,lsreg);
                    cdb.gen(&cs);                 // MOV lsreg,lsw
                    if (sz == REGSIZE + 2)
                        cs.Iflags |= CFopsize;
                    lsreg = reg;
                    getlvalue_msw(cs);                 // MOV reg,msw
                }
                else
                {
                    code_newreg(&cs,reg);
                    getlvalue_msw(cs);
                    cdb.gen(&cs);                 // MOV reg,msw
                    if (sz == REGSIZE + 2)
                        cdb.last().Iflags |= CFopsize;
                    getlvalue_lsw(cs);                 // MOV lsreg,lsw
                }
                NEWREG(cs.Irm,lsreg);
                cdb.gen(&cs);
            }
            else
            {
                // Index registers are always the lsw!
                cs.Irm |= modregrm(0,reg,0);
                getlvalue_msw(cs);
                cdb.gen(&cs);     // MOV reg,msw
                lsreg = findreglsw(retregs);
                NEWREG(cs.Irm,lsreg);
                getlvalue_lsw(cs);     // MOV lsreg,lsw
                cdb.gen(&cs);
            }
        }
        else if (I16 && sz == 8)
        {
            assert(reg == AX);
            cs.Iop = 0x8B;
            cs.IEV1.Voffset += 6;
            cdb.gen(&cs);             // MOV AX,EA+6
            cs.Irm |= modregrm(0,CX,0);
            cs.IEV1.Voffset -= 4;
            cdb.gen(&cs);                    // MOV CX,EA+2
            NEWREG(cs.Irm,DX);
            cs.IEV1.Voffset -= 2;
            cdb.gen(&cs);                    // MOV DX,EA
            cs.IEV1.Voffset += 4;
            NEWREG(cs.Irm,BX);
            cdb.gen(&cs);                    // MOV BX,EA+4
        }
        else
            assert(0);
    L3:
        fixresult(cdb,e,retregs,pretregs);
    }
    //fprintf(stderr,"cdafter :\n"); WRcodlst(c);
}



/********************************
 * Generate code to load ES with the right segment value,
 * do nothing if e is a far pointer.
 */

@trusted
private code* cod2_setES(tym_t ty)
{
    if (config.exe & EX_flat)
        return null;

    int push;

    CodeBuilder cdb;
    cdb.ctor();
    switch (tybasic(ty))
    {
        case TYnptr:
            if (!(config.flags3 & CFG3eseqds))
            {   push = 0x1E;            // PUSH DS
                goto L1;
            }
            break;
        case TYcptr:
            push = 0x0E;                // PUSH CS
            goto L1;
        case TYsptr:
            if ((config.wflags & WFssneds) || !(config.flags3 & CFG3eseqds))
            {   push = 0x16;            // PUSH SS
            L1:
                // Must load ES
                getregs(cdb,mES);
                cdb.gen1(push);
                cdb.gen1(0x07);         // POP ES
            }
            break;

        default:
            break;
    }
    return cdb.finish();
}

/********************************
 * Generate code for intrinsic strlen().
 */

@trusted
void cdstrlen(ref CGstate cg, ref CodeBuilder cdb, elem* e, ref regm_t pretregs)
{
    /* Generate strlen in CX:
        LES     DI,e1
        CLR     AX                      ;scan for 0
        MOV     CX,-1                   ;largest possible string
        REPNE   SCASB
        NOT     CX
        DEC     CX
     */

    regm_t retregs = mDI;
    tym_t ty1 = e.E1.Ety;
    if (!tyreg(ty1))
        retregs |= mES;
    codelem(cgstate,cdb,e.E1,retregs,false);

    // Make sure ES contains proper segment value
    cdb.append(cod2_setES(ty1));

    ubyte rex = I64 ? REX_W : 0;

    getregs_imm(cdb,mAX | mCX);
    movregconst(cdb,AX,0,1);               // MOV AL,0
    movregconst(cdb,CX,-cast(targ_size_t)1,I64 ? 64 : 0);  // MOV CX,-1
    getregs(cdb,mDI|mCX);
    cdb.gen1(0xF2);                                     // REPNE
    cdb.gen1(0xAE);                                     // SCASB
    genregs(cdb,0xF7,2,CX);                // NOT CX
    code_orrex(cdb.last(), rex);
    if (I64)
        cdb.gen2(0xFF,(rex << 16) | modregrm(3,1,CX));  // DEC reg
    else
        cdb.gen1(0x48 + CX);                            // DEC CX

    if (pretregs & mPSW)
    {
        cdb.last().Iflags |= CFpsw;
        pretregs &= ~mPSW;
    }
    fixresult(cdb,e,mCX,pretregs);
}


/*********************************
 * Generate code for strcmp(s1,s2) intrinsic.
 */

@trusted
void cdstrcmp(ref CGstate cg, ref CodeBuilder cdb, elem* e, ref regm_t pretregs)
{
    char need_DS;
    int segreg;

    /*
        MOV     SI,s1                   ;get destination pointer (s1)
        MOV     CX,s1+2
        LES     DI,s2                   ;get source pointer (s2)
        PUSH    DS
        MOV     DS,CX
        CLR     AX                      ;scan for 0
        MOV     CX,-1                   ;largest possible string
        REPNE   SCASB
        NOT     CX                      ;CX = string length of s2
        SUB     DI,CX                   ;point DI back to beginning
        REPE    CMPSB                   ;compare string
        POP     DS
        JE      L1                      ;strings are equal
        SBB     AX,AX
        SBB     AX,-1
    L1:
    */

    regm_t retregs1 = mSI;
    tym_t ty1 = e.E1.Ety;
    if (!tyreg(ty1))
        retregs1 |= mCX;
    codelem(cgstate,cdb,e.E1,retregs1,false);

    regm_t retregs = mDI;
    tym_t ty2 = e.E2.Ety;
    if (!tyreg(ty2))
        retregs |= mES;
    scodelem(cgstate,cdb,e.E2,retregs,retregs1,false);

    // Make sure ES contains proper segment value
    cdb.append(cod2_setES(ty2));
    getregs_imm(cdb,mAX | mCX);

    ubyte rex = I64 ? REX_W : 0;

    // Load DS with right value
    switch (tybasic(ty1))
    {
        case TYnptr:
        case TYimmutPtr:
            need_DS = false;
            break;

        case TYsptr:
            if (config.wflags & WFssneds)       // if sptr can't use DS segment
                segreg = SEG_SS;
            else
                segreg = SEG_DS;
            goto L1;
        case TYcptr:
            segreg = SEG_CS;
        L1:
            cdb.gen1(0x1E);                         // PUSH DS
            cdb.gen1(0x06 + (segreg << 3));         // PUSH segreg
            cdb.gen1(0x1F);                         // POP  DS
            need_DS = true;
            break;
        case TYfptr:
        case TYvptr:
        case TYhptr:
            cdb.gen1(0x1E);                         // PUSH DS
            cdb.gen2(0x8E,modregrm(3,SEG_DS,CX));   // MOV DS,CX
            need_DS = true;
            break;
        default:
            assert(0);
    }

    movregconst(cdb,AX,0,0);                // MOV AX,0
    movregconst(cdb,CX,-cast(targ_size_t)1,I64 ? 64 : 0);   // MOV CX,-1
    getregs(cdb,mSI|mDI|mCX);
    cdb.gen1(0xF2);                              // REPNE
    cdb.gen1(0xAE);                              // SCASB
    genregs(cdb,0xF7,2,CX);         // NOT CX
    code_orrex(cdb.last(),rex);
    genregs(cdb,0x2B,DI,CX);        // SUB DI,CX
    code_orrex(cdb.last(),rex);
    cdb.gen1(0xF3);                              // REPE
    cdb.gen1(0xA6);                              // CMPSB
    if (need_DS)
        cdb.gen1(0x1F);                          // POP DS
    code* c4 = gennop(null);
    if (pretregs != mPSW)                       // if not flags only
    {
        genjmp(cdb,JE,FL.code,cast(block*) c4);      // JE L1
        getregs(cdb,mAX);
        genregs(cdb,0x1B,AX,AX);                 // SBB AX,AX
        code_orrex(cdb.last(),rex);
        cdb.genc2(0x81,(rex << 16) | modregrm(3,3,AX),cast(targ_uns)-1);   // SBB AX,-1
    }

    pretregs &= ~mPSW;
    cdb.append(c4);
    fixresult(cdb,e,mAX,pretregs);
}

/*********************************
 * Generate code for memcmp(s1,s2,n) intrinsic.
 */

@trusted
void cdmemcmp(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    char need_DS;
    int segreg;

    /*
        MOV     SI,s1                   ;get destination pointer (s1)
        MOV     DX,s1+2
        LES     DI,s2                   ;get source pointer (s2)
        MOV     CX,n                    ;get number of bytes to compare
        PUSH    DS
        MOV     DS,DX
        XOR     AX,AX
        REPE    CMPSB                   ;compare string
        POP     DS
        JE      L1                      ;strings are equal
        SBB     AX,AX
        SBB     AX,-1
    L1:
    */

    elem* e1 = e.E1;
    assert(e1.Eoper == OPparam);

    // Get s1 into DX:SI
    regm_t retregs1 = mSI;
    tym_t ty1 = e1.E1.Ety;
    if (!tyreg(ty1))
        retregs1 |= mDX;
    codelem(cgstate,cdb,e1.E1,retregs1,false);

    // Get s2 into ES:DI
    regm_t retregs = mDI;
    tym_t ty2 = e1.E2.Ety;
    if (!tyreg(ty2))
        retregs |= mES;
    scodelem(cgstate,cdb,e1.E2,retregs,retregs1,false);
    freenode(e1);

    // Get nbytes into CX
    regm_t retregs3 = mCX;
    scodelem(cgstate,cdb,e.E2,retregs3,retregs | retregs1,false);

    // Make sure ES contains proper segment value
    cdb.append(cod2_setES(ty2));

    // Load DS with right value
    switch (tybasic(ty1))
    {
        case TYnptr:
        case TYimmutPtr:
            need_DS = false;
            break;

        case TYsptr:
            if (config.wflags & WFssneds)       // if sptr can't use DS segment
                segreg = SEG_SS;
            else
                segreg = SEG_DS;
            goto L1;
        case TYcptr:
            segreg = SEG_CS;
        L1:
            cdb.gen1(0x1E);                     // PUSH DS
            cdb.gen1(0x06 + (segreg << 3));     // PUSH segreg
            cdb.gen1(0x1F);                     // POP  DS
            need_DS = true;
            break;
        case TYfptr:
        case TYvptr:
        case TYhptr:
            cdb.gen1(0x1E);                        // PUSH DS
            cdb.gen2(0x8E,modregrm(3,SEG_DS,DX));  // MOV DS,DX
            need_DS = true;
            break;
        default:
            assert(0);
    }

    static if (1)
    {
        getregs(cdb,mAX);
        cdb.gen2(0x33,modregrm(3,AX,AX));           // XOR AX,AX
        code_orflag(cdb.last(), CFpsw);             // keep flags
    }
    else
    {
        if (pretregs != mPSW)                      // if not flags only
        {
            regwithvalue(cdb,mAX,0,0);         // put 0 in AX
        }
    }

    getregs(cdb,mCX | mSI | mDI);
    cdb.gen1(0xF3);                             // REPE
    cdb.gen1(0xA6);                             // CMPSB
    if (need_DS)
        cdb.gen1(0x1F);                         // POP DS
    if (pretregs != mPSW)                      // if not flags only
    {
        code* c4 = gennop(null);
        genjmp(cdb,JE,FL.code,cast(block*) c4);  // JE L1
        getregs(cdb,mAX);
        genregs(cdb,0x1B,AX,AX);             // SBB AX,AX
        cdb.genc2(0x81,modregrm(3,3,AX),cast(targ_uns)-1);    // SBB AX,-1
        cdb.append(c4);
    }

    pretregs &= ~mPSW;
    fixresult(cdb,e,mAX,pretregs);
}

/*********************************
 * Generate code for strcpy(s1,s2) intrinsic.
 */

@trusted
void cdstrcpy(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    char need_DS;
    int segreg;

    /*
        LES     DI,s2                   ;ES:DI = s2
        CLR     AX                      ;scan for 0
        MOV     CX,-1                   ;largest possible string
        REPNE   SCASB                   ;find end of s2
        NOT     CX                      ;CX = strlen(s2) + 1 (for EOS)
        SUB     DI,CX
        MOV     SI,DI
        PUSH    DS
        PUSH    ES
        LES     DI,s1
        POP     DS
        MOV     AX,DI                   ;return value is s1
        REP     MOVSB
        POP     DS
    */

    cgstate.stackchanged = 1;
    regm_t retregs = mDI;
    tym_t ty2 = tybasic(e.E2.Ety);
    if (!tyreg(ty2))
        retregs |= mES;
    ubyte rex = I64 ? REX_W : 0;
    codelem(cgstate,cdb,e.E2,retregs,false);

    // Make sure ES contains proper segment value
    cdb.append(cod2_setES(ty2));
    getregs_imm(cdb,mAX | mCX);
    movregconst(cdb,AX,0,1);       // MOV AL,0
    movregconst(cdb,CX,-1,I64?64:0);  // MOV CX,-1
    getregs(cdb,mAX|mCX|mSI|mDI);
    cdb.gen1(0xF2);                             // REPNE
    cdb.gen1(0xAE);                             // SCASB
    genregs(cdb,0xF7,2,CX);                     // NOT CX
    code_orrex(cdb.last(),rex);
    genregs(cdb,0x2B,DI,CX);                    // SUB DI,CX
    code_orrex(cdb.last(),rex);
    genmovreg(cdb,SI,DI);          // MOV SI,DI

    // Load DS with right value
    switch (ty2)
    {
        case TYnptr:
        case TYimmutPtr:
            need_DS = false;
            break;

        case TYsptr:
            if (config.wflags & WFssneds)       // if sptr can't use DS segment
                segreg = SEG_SS;
            else
                segreg = SEG_DS;
            goto L1;
        case TYcptr:
            segreg = SEG_CS;
        L1:
            cdb.gen1(0x1E);                     // PUSH DS
            cdb.gen1(0x06 + (segreg << 3));     // PUSH segreg
            cdb.genadjesp(REGSIZE * 2);
            need_DS = true;
            break;
        case TYfptr:
        case TYvptr:
        case TYhptr:
            segreg = SEG_ES;
            goto L1;

        default:
            assert(0);
    }

    retregs = mDI;
    tym_t ty1 = tybasic(e.E1.Ety);
    if (!tyreg(ty1))
        retregs |= mES;
    scodelem(cgstate,cdb,e.E1,retregs,mCX|mSI,false);
    getregs(cdb,mAX|mCX|mSI|mDI);

    // Make sure ES contains proper segment value
    if (ty2 != TYnptr || ty1 != ty2)
        cdb.append(cod2_setES(ty1));
    else
    {}                              // ES is already same as DS

    if (need_DS)
        cdb.gen1(0x1F);                     // POP DS
    if (pretregs)
        genmovreg(cdb,AX,DI);               // MOV AX,DI
    cdb.gen1(0xF3);                         // REP
    cdb.gen1(0xA4);                              // MOVSB

    if (need_DS)
    {   cdb.gen1(0x1F);                          // POP DS
        cdb.genadjesp(-(REGSIZE * 2));
    }
    fixresult(cdb,e,mAX | mES,pretregs);
}

/*********************************
 * Generate code for memcpy(s1,s2,n) intrinsic.
 *  OPmemcpy
 *   /   \
 * s1   OPparam
 *       /   \
 *      s2    n
 */

@trusted
void cdmemcpy(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    char need_DS;
    int segreg;

    /*
        MOV     SI,s2
        MOV     DX,s2+2
        MOV     CX,n
        LES     DI,s1
        PUSH    DS
        MOV     DS,DX
        MOV     AX,DI                   ;return value is s1
        REP     MOVSB
        POP     DS
    */

    elem* e2 = e.E2;
    assert(e2.Eoper == OPparam);

    // Get s2 into DX:SI
    regm_t retregs2 = mSI;
    tym_t ty2 = e2.E1.Ety;
    if (!tyreg(ty2))
        retregs2 |= mDX;
    codelem(cgstate,cdb,e2.E1,retregs2,false);

    // Need to check if nbytes is 0 (OPconst of 0 would have been removed by elmemcpy())
    const zeroCheck = e2.E2.Eoper != OPconst;

    // Get nbytes into CX
    regm_t retregs3 = mCX;
    scodelem(cgstate,cdb,e2.E2,retregs3,retregs2,false);
    freenode(e2);

    // Get s1 into ES:DI
    regm_t retregs1 = mDI;
    tym_t ty1 = e.E1.Ety;
    if (!tyreg(ty1))
        retregs1 |= mES;
    scodelem(cgstate,cdb,e.E1,retregs1,retregs2 | retregs3,false);

    ubyte rex = I64 ? REX_W : 0;

    // Make sure ES contains proper segment value
    cdb.append(cod2_setES(ty1));

    // Load DS with right value
    switch (tybasic(ty2))
    {
        case TYnptr:
        case TYimmutPtr:
            need_DS = false;
            break;

        case TYsptr:
            if (config.wflags & WFssneds)       // if sptr can't use DS segment
                segreg = SEG_SS;
            else
                segreg = SEG_DS;
            goto L1;

        case TYcptr:
            segreg = SEG_CS;
        L1:
            cdb.gen1(0x1E);                        // PUSH DS
            cdb.gen1(0x06 + (segreg << 3));        // PUSH segreg
            cdb.gen1(0x1F);                        // POP  DS
            need_DS = true;
            break;

        case TYfptr:
        case TYvptr:
        case TYhptr:
            cdb.gen1(0x1E);                        // PUSH DS
            cdb.gen2(0x8E,modregrm(3,SEG_DS,DX));  // MOV DS,DX
            need_DS = true;
            break;

        default:
            assert(0);
    }

    if (pretregs)                              // if need return value
    {   getregs(cdb,mAX);
        genmovreg(cdb,AX,DI);
    }

    if (0 && I32 && config.flags4 & CFG4speed)
    {
        /* This is only faster if the memory is dword aligned, if not
         * it is significantly slower than just a rep movsb.
         */
        /*      mov     EDX,ECX
         *      shr     ECX,2
         *      jz      L1
         *      repe    movsd
         * L1:  nop
         *      and     EDX,3
         *      jz      L2
         *      mov     ECX,EDX
         *      repe    movsb
         * L2:  nop
         */
        getregs(cdb,mSI | mDI | mCX | mDX);
        genmovreg(cdb,DX,CX);                  // MOV EDX,ECX
        cdb.genc2(0xC1,modregrm(3,5,CX),2);                 // SHR ECX,2
        code* cx = gennop(null);
        genjmp(cdb, JE, FL.code, cast(block*)cx);  // JZ L1
        cdb.gen1(0xF3);                                     // REPE
        cdb.gen1(0xA5);                                     // MOVSW
        cdb.append(cx);
        cdb.genc2(0x81, modregrm(3,4,DX),3);                // AND EDX,3

        code* cnop = gennop(null);
        genjmp(cdb, JE, FL.code, cast(block*)cnop);  // JZ L2
        genmovreg(cdb,CX,DX);                    // MOV ECX,EDX
        cdb.gen1(0xF3);                          // REPE
        cdb.gen1(0xA4);                          // MOVSB
        cdb.append(cnop);
    }
    else
    {
        getregs(cdb,mSI | mDI | mCX);
        code* cnop;
        if (zeroCheck)
        {
            cnop = gennop(null);
            gentstreg(cdb,CX);                           // TEST ECX,ECX
            if (I64)
                code_orrex(cdb.last, REX_W);
            genjmp(cdb, JE, FL.code, cast(block*)cnop);  // JZ cnop
        }

        if (I16 && config.flags4 & CFG4speed)          // if speed optimization
        {
            // Note this doesn't work if CX is 0
            cdb.gen2(0xD1,(rex << 16) | modregrm(3,5,CX));        // SHR CX,1
            cdb.gen1(0xF3);                              // REPE
            cdb.gen1(0xA5);                              // MOVSW
            cdb.gen2(0x11,(rex << 16) | modregrm(3,CX,CX));            // ADC CX,CX
        }
        cdb.gen1(0xF3);                             // REPE
        cdb.gen1(0xA4);                             // MOVSB
        if (zeroCheck)
            cdb.append(cnop);
        if (need_DS)
            cdb.gen1(0x1F);                         // POP DS
    }
    fixresult(cdb,e,mES|mAX,pretregs);
}


/*********************************
 * Generate code for memset(s,value,numbytes) intrinsic.
 *      (s OPmemset (numbytes OPparam value))
 */

@trusted
void cdmemset(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    regm_t retregs1;
    regm_t retregs3;
    reg_t reg;
    reg_t vreg;
    tym_t ty1;
    int segreg;
    targ_uns numbytes;
    uint m;

    //printf("cdmemset(pretregs = %s)\n", regm_str(pretregs));
    elem* e2 = e.E2;
    assert(e2.Eoper == OPparam);

    elem* evalue = e2.E2;
    elem* enumbytes = e2.E1;

    const sz = tysize(evalue.Ety);
    if (sz > 1)
    {
        cdmemsetn(cg, cdb, e, pretregs);
        return;
    }

    const grex = I64 ? (REX_W << 16) : 0;

    bool valueIsConst = false;
    targ_size_t value;
    if (evalue.Eoper == OPconst)
    {
        value = el_tolong(evalue) & 0xFF;
        value |= value << 8;
        if (I32 || I64)
        {
            value |= value << 16;
            static if (value.sizeof == 8)
            if (I64)
                value |= value << 32;
        }
        valueIsConst = true;
    }
    else if (evalue.Eoper == OPstrpar)  // happens if evalue is a struct of 0 size
    {
        value = 0;
        valueIsConst = true;
    }
    else
        value = 0xDEADBEEF;     // stop annoying false positives that value is not inited

    if (enumbytes.Eoper == OPconst)
    {
        numbytes = cast(uint)cast(targ_size_t)el_tolong(enumbytes);
    }

    // Get nbytes into CX
    regm_t retregs2 = 0;
    if (enumbytes.Eoper != OPconst)
    {
        retregs2 = mCX;
        codelem(cgstate,cdb,enumbytes,retregs2,false);
    }

    // Get value into AX
    retregs3 = mAX;
    if (valueIsConst)
    {
        regwithvalue(cdb, mAX, value, I64?64:0);
        getregs(cdb, mAX);
        cgstate.regimmed_set(AX, value);
        freenode(evalue);
    }
    else
    {
        scodelem(cgstate,cdb,evalue,retregs3,retregs2,false);

        getregs(cdb,mAX);
        if (I16)
        {
            cdb.gen2(0x8A,modregrm(3,AH,AL)); // MOV AH,AL
        }
        else if (I32)
        {
            genregs(cdb,MOVZXb,AX,AX);                    // MOVZX EAX,AL
            cdb.genc2(0x69,modregrm(3,AX,AX),0x01010101); // IMUL EAX,EAX,0x01010101
        }
        else
        {
            genregs(cdb,MOVZXb,AX,AX);                    // MOVZX EAX,AL
            regm_t regm = cgstate.allregs & ~(mAX | retregs2);
            const r = regwithvalue(cdb,regm,cast(targ_size_t)0x01010101_01010101,64); // MOV reg,0x01010101_01010101
            cdb.gen2(0x0FAF,grex | modregrmx(3,AX,r));        // IMUL RAX,reg
        }
    }
    freenode(e2);

    // Get s into ES:DI
    retregs1 = mDI;
    ty1 = e.E1.Ety;
    if (!tyreg(ty1))
        retregs1 |= mES;
    scodelem(cgstate,cdb,e.E1,retregs1,retregs2 | retregs3,false);
    reg = DI; //findreg(retregs1);

    // Make sure ES contains proper segment value
    cdb.append(cod2_setES(ty1));

    if (pretregs)                              // if need return value
    {
        getregs(cdb,mBX);
        genmovreg(cdb,BX,DI);                   // MOV EBX,EDI
    }

    if (enumbytes.Eoper == OPconst)
    {
        getregs(cdb,mDI);
        if (const numwords = numbytes / REGSIZE)
        {
            regwithvalue(cdb,mCX,numwords, I64 ? 64 : 0);
            getregs(cdb,mCX);
            cdb.gen1(0xF3);                     // REP
            cdb.gen1(STOS);                     // STOSW/D/Q
            if (I64)
                code_orrex(cdb.last(), REX_W);
            cgstate.regimmed_set(CX, 0);                // CX is now 0
        }

        auto remainder = numbytes & (REGSIZE - 1);
        if (I64 && remainder >= 4)
        {
            cdb.gen1(STOS);                     // STOSD
            remainder -= 4;
        }
        for (; remainder; --remainder)
            cdb.gen1(STOSB);                    // STOSB
        fixresult(cdb,e,mES|mBX,pretregs);
        return;
    }

    getregs(cdb,mDI | mCX);
    if (I16)
    {
        if (config.flags4 & CFG4speed)      // if speed optimization
        {
            cdb.gen2(0xD1,modregrm(3,5,CX));  // SHR CX,1
            cdb.gen1(0xF3);                   // REP
            cdb.gen1(STOS);                   // STOSW
            cdb.gen2(0x11,modregrm(3,CX,CX)); // ADC CX,CX
        }
        cdb.gen1(0xF3);                       // REP
        cdb.gen1(STOSB);                      // STOSB
        cgstate.regimmed_set(CX, 0);                  // CX is now 0
        fixresult(cdb,e,mES|mBX,pretregs);
        return;
    }

    /*  MOV   sreg,ECX
        SHR   ECX,n
        REP
        STOSD/Q

        ADC   ECX,ECX
        REP
        STOSD

        MOV   ECX,sreg
        AND   ECX,3
        REP
        STOSB
     */
    regm_t regs = cgstate.allregs & (pretregs ? ~(mAX|mBX|mCX|mDI) : ~(mAX|mCX|mDI));
    const sreg = allocreg(cdb,regs,TYint);
    genregs(cdb,0x89,CX,sreg);                        // MOV sreg,ECX (32 bits only)

    const n = I64 ? 3 : 2;
    cdb.genc2(0xC1, grex | modregrm(3,5,CX), n);      // SHR ECX,n

    cdb.gen1(0xF3);                                   // REP
    cdb.gen1(STOS);                                   // STOSD/Q
    if (I64)
        code_orrex(cdb.last(), REX_W);

    if (I64)
    {
        cdb.gen2(0x11,modregrm(3,CX,CX));             // ADC ECX,ECX
        cdb.gen1(0xF3);                               // REP
        cdb.gen1(STOS);                               // STOSD
    }

    genregs(cdb,0x89,sreg,CX);                        // MOV ECX,sreg (32 bits only)
    cdb.genc2(0x81, modregrm(3,4,CX), 3);             // AND ECX,3
    cdb.gen1(0xF3);                                   // REP
    cdb.gen1(STOSB);                                  // STOSB

    cgstate.regimmed_set(CX, 0);                    // CX is now 0
    fixresult(cdb,e,mES|mBX,pretregs);
}

/***********************************************
 * Do memset for values larger than a byte.
 * Has many similarities to cod4.cdeq().
 * Doesn't work for 16 bit code.
 */
@trusted
private void cdmemsetn(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdmemsetn(pretregs = %s)\n", regm_str(pretregs));
    elem* e2 = e.E2;
    assert(e2.Eoper == OPparam);

    elem* evalue = e2.E2;
    elem* enelems = e2.E1;

    tym_t tymv = tybasic(evalue.Ety);
    const sz = tysize(evalue.Ety);
    assert(cast(int)sz > 1);

    if (tyxmmreg(tymv) && config.fpxmmregs)
        assert(0);      // fix later
    if (tyfloating(tymv) && config.inline8087)
        assert(0);      // fix later

    const grex = I64 ? (REX_W << 16) : 0;

    // get the count of elems into CX
    regm_t mregcx = mCX;
    codelem(cgstate,cdb,enelems,mregcx,false);

    // Get value into AX
    regm_t retregs3 = cgstate.allregs & ~mregcx;
    if (sz == 2 * REGSIZE)
        retregs3 &= ~(mBP | IDXREGS);  // BP cannot be used for register pair,
                                       // IDXREGS could deplete index regs - see sdtor.d test14815()
    scodelem(cgstate,cdb,evalue,retregs3,mregcx,false);

    /* Necessary because if evalue calls a function, and that function never returns,
     * it doesn't affect registers. Which means those registers can be used for enregistering
     * variables, and next pass fails because it can't use those registers, and so cannot
     * allocate registers for retregs3. See ice11596.d
     */
    useregs(retregs3);

    reg_t valreg = findreg(retregs3);
    reg_t valreghi;
    if (sz == 2 * REGSIZE)
    {
        valreg = findreglsw(retregs3);
        valreghi = findregmsw(retregs3);
    }

    freenode(e2);

    // Get s into ES:DI
    regm_t mregidx = IDXREGS & ~(mregcx | retregs3);
    assert(mregidx);
    tym_t ty1 = tybasic(e.E1.Ety);
    if (!tyreg(ty1))
        mregidx |= mES;
    scodelem(cgstate,cdb,e.E1,mregidx,mregcx | retregs3,false);
    reg_t idxreg = findreg(mregidx);

    // Make sure ES contains proper segment value
    cdb.append(cod2_setES(ty1));

    regm_t mregbx = 0;
    if (pretregs)                              // if need return value
    {
        mregbx = pretregs & ~(mregidx | mregcx | retregs3);
        if (!mregbx)
            mregbx = cgstate.allregs & ~(mregidx | mregcx | retregs3);
        const regbx = allocreg(cdb, mregbx, TYnptr);
        getregs(cdb, mregbx);
        genmovreg(cdb,regbx,idxreg);            // MOV BX,DI
    }

    getregs(cdb,mask(idxreg) | mCX);            // modify DI and CX

    /* Generate:
     *  JCXZ L1
     * L2:
     *  MOV [idxreg],AX
     *  ADD idxreg,sz
     *  LOOP L2
     * L1:
     *  NOP
     */
    code* c1 = gennop(null);
    genjmp(cdb, JCXZ, FL.code, cast(block*)c1);
    code cs;
    buildEA(&cs,idxreg,-1,1,0);
    cs.Iop = 0x89;
    if (!I16 && sz == 2)
        cs.Iflags |= CFopsize;
    if (I64 && sz == 8)
        cs.Irex |= REX_W;
    code_newreg(&cs, valreg);
    cdb.gen(&cs);                                       // MOV [idxreg],AX
    code* c2 = cdb.last();
    if (sz == REGSIZE * 2)
    {
        cs.IEV1.Vuns = REGSIZE;
        code_newreg(&cs, valreghi);
        cdb.gen(&cs);                                   // MOV REGSIZE[idxreg],DX
    }
    cdb.genc2(0x81, grex | modregrmx(3,0,idxreg), sz);  // ADD idxreg,sz
    genjmp(cdb, LOOP, FL.code, cast(block*)c2);         // LOOP L2
    cdb.append(c1);

    cgstate.regimmed_set(CX, 0);                  // CX is now 0

    fixresult(cdb,e,mregbx,pretregs);
}

/**********************
 * Do structure assignments.
 * This should be fixed so that (s1 = s2) is rewritten to (&s1 = &s2).
 * Mebbe call cdstreq() for double assignments???
 */

@trusted
void cdstreq(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    char need_DS = false;
    elem* e1 = e.E1;
    elem* e2 = e.E2;
    int segreg;
    uint numbytes = cast(uint)type_size(e.ET);          // # of bytes in structure/union
    ubyte rex = I64 ? REX_W : 0;

    //printf("cdstreq(e = %p, pretregs = %s)\n", e, regm_str(pretregs));

    // First, load pointer to rvalue into SI
    regm_t srcregs = mSI;                      // source is DS:SI
    docommas(cdb,e2);
    if (e2.Eoper == OPind)             // if (.. = *p)
    {   elem* e21 = e2.E1;

        segreg = SEG_DS;
        switch (tybasic(e21.Ety))
        {
            case TYsptr:
                if (config.wflags & WFssneds)   // if sptr can't use DS segment
                    segreg = SEG_SS;
                break;
            case TYcptr:
                if (!(config.exe & EX_flat))
                    segreg = SEG_CS;
                break;
            case TYfptr:
            case TYvptr:
            case TYhptr:
                srcregs |= mCX;         // get segment also
                need_DS = true;
                break;

            default:
                break;
        }
        codelem(cgstate,cdb,e21,srcregs,false);
        freenode(e2);
        if (segreg != SEG_DS)           // if not DS
        {
            getregs(cdb,mCX);
            cdb.gen2(0x8C,modregrm(3,segreg,CX)); // MOV CX,segreg
            need_DS = true;
        }
    }
    else if (e2.Eoper == OPvar)
    {
        if (e2.Vsym.ty() & mTYfar) // if e2 is in a far segment
        {   srcregs |= mCX;             // get segment also
            need_DS = true;
            cdrelconst(cgstate,cdb,e2,srcregs);
        }
        else
        {
            segreg = segfl[el_fl(e2)];
            if ((config.wflags & WFssneds) && segreg == SEG_SS || // if source is on stack
                segreg == SEG_CS)               // if source is in CS
            {
                need_DS = true;         // we need to reload DS
                // Load CX with segment
                srcregs |= mCX;
                getregs(cdb,mCX);
                cdb.gen2(0x8C,                // MOV CX,[SS|CS]
                    modregrm(3,segreg,CX));
            }
            cdrelconst(cgstate,cdb,e2,srcregs);
        }
        freenode(e2);
    }
    else
    {
        if (!(config.exe & EX_flat))
        {   need_DS = true;
            srcregs |= mCX;
        }
        codelem(cgstate,cdb,e2,srcregs,false);
    }

    // now get pointer to lvalue (destination) in ES:DI
    regm_t dstregs = (config.exe & EX_flat) ? mDI : mES|mDI;
    if (e1.Eoper == OPind)               // if (*p = ..)
    {
        if (tyreg(e1.E1.Ety))
            dstregs = mDI;
        cdb.append(cod2_setES(e1.E1.Ety));
        scodelem(cgstate,cdb,e1.E1,dstregs,srcregs,false);
    }
    else
        cdrelconst(cgstate,cdb,e1,dstregs);
    freenode(e1);

    getregs(cdb,(srcregs | dstregs) & (mLSW | mDI));
    if (need_DS)
    {     assert(!(config.exe & EX_flat));
        cdb.gen1(0x1E);                     // PUSH DS
        cdb.gen2(0x8E,modregrm(3,SEG_DS,CX));    // MOV DS,CX
    }
    if (numbytes <= REGSIZE * (6 + (REGSIZE == 4)))
    {
        while (numbytes >= REGSIZE)
        {
            cdb.gen1(0xA5);         // MOVSW
            code_orrex(cdb.last(), rex);
            numbytes -= REGSIZE;
        }
        //if (numbytes)
        //    printf("cdstreq numbytes %d\n",numbytes);
        if (I64 && numbytes >= 4)
        {
            cdb.gen1(0xA5);         // MOVSD
            numbytes -= 4;
        }
        while (numbytes--)
            cdb.gen1(0xA4);         // MOVSB
    }
    else
    {
static if (1)
{
        uint remainder = numbytes & (REGSIZE - 1);
        numbytes /= REGSIZE;            // number of words
        getregs_imm(cdb,mCX);
        movregconst(cdb,CX,numbytes,0);   // # of bytes/words
        cdb.gen1(0xF3);                 // REP
        if (REGSIZE == 8)
            cdb.gen1(REX | REX_W);
        cdb.gen1(0xA5);                 // REP MOVSD
        cgstate.regimmed_set(CX,0);             // note that CX == 0
        if (I64 && remainder >= 4)
        {
            cdb.gen1(0xA5);         // MOVSD
            remainder -= 4;
        }
        for (; remainder; remainder--)
        {
            cdb.gen1(0xA4);             // MOVSB
        }
}
else
{
        uint movs;
        if (numbytes & (REGSIZE - 1))   // if odd
            movs = 0xA4;                // MOVSB
        else
        {
            movs = 0xA5;                // MOVSW
            numbytes /= REGSIZE;        // # of words
        }
        getregs_imm(cdb,mCX);
        movregconst(cdb,CX,numbytes,0);   // # of bytes/words
        cdb.gen1(0xF3);                 // REP
        cdb.gen1(movs);
        cgstate.regimmed_set(CX,0);             // note that CX == 0
}
    }
    if (need_DS)
        cdb.gen1(0x1F);                 // POP  DS
    assert(!(pretregs & mPSW));
    if (pretregs)
    {   // ES:DI points past what we want

        cdb.genc2(0x81,(rex << 16) | modregrm(3,5,DI), type_size(e.ET));   // SUB DI,numbytes

        const tym = tybasic(e.Ety);
        if (tym == TYucent && I64)
        {
            /* https://issues.dlang.org/show_bug.cgi?id=22175
             * The trouble happens when the struct size does not fit exactly into
             * 2 registers. Then the type of e becomes a TYucent, not a TYstruct,
             * and we need to dereference DI to get the ucent
             */

            // dereference DI
            code cs;
            cs.Iop = 0x8B;
            regm_t retregs = pretregs;
            const reg = allocreg(cdb,retregs,tym);

            reg_t msreg = findregmsw(retregs);
            buildEA(&cs,DI,-1,1,REGSIZE);
            code_newreg(&cs,msreg);
            cs.Irex |= REX_W;
            cdb.gen(&cs);       // MOV msreg,REGSIZE[DI]        // msreg is never DI

            reg_t lsreg = findreglsw(retregs);
            buildEA(&cs,DI,-1,1,0);
            code_newreg(&cs,lsreg);
            cs.Irex |= REX_W;
            cdb.gen(&cs);       // MOV lsreg,[DI];
            fixresult(cdb,e,retregs,pretregs);
            return;
        }

        regm_t retregs = mDI;
        if (pretregs & mMSW && !(config.exe & EX_flat))
            retregs |= mES;
        fixresult(cdb,e,retregs,pretregs);
    }
}


/**********************
 * Get the address of.
 * Is also called by cdstreq() to set up pointer to a structure.
 */

@trusted
void cdrelconst(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    //printf("cdrelconst(e = %p, pretregs = %s)\n", e, regm_str(pretregs));

    /* The following should not happen, but cgelem.c is a little stupid.
     * Assertion can be tripped by func("string" == 0); and similar
     * things. Need to add goals to optelem() to fix this completely.
     */
    //assert((pretregs & mPSW) == 0);
    if (pretregs & mPSW)
    {
        pretregs &= ~mPSW;
        gentstreg(cdb,SP);            // SP is never 0
        if (I64)
            code_orrex(cdb.last(), REX_W);
    }
    if (!pretregs)
        return;

    assert(e);
    tym_t tym = tybasic(e.Ety);
    switch (tym)
    {
        case TYstruct:
        case TYarray:
        case TYldouble:
        case TYildouble:
        case TYcldouble:
            tym = TYnptr;               // don't confuse allocreg()
            if (I16 && pretregs & (mES | mCX) || e.Ety & mTYfar)
            {
                tym = TYfptr;
            }
            break;

        case TYifunc:
            tym = TYfptr;
            break;

        default:
            if (tyfunc(tym))
                tym =
                    tyfarfunc(tym) ? TYfptr :
                    TYnptr;
            break;
    }
    //assert(tym & typtr);              // don't fail on (int)&a

    SC sclass;
    reg_t mreg;            // segment of the address (TYfptrs only)

    reg_t lreg = allocreg(cdb,pretregs,tym); // offset of the address
    if (_tysize[tym] > REGSIZE)            // fptr could've been cast to long
    {
        if (pretregs & mES)
        {
            /* Do not allocate CX or SI here, as cdstreq() needs
             * them preserved. cdstreq() should use scodelem(cgstate,)
             */
            mreg = allocScratchReg(cdb, (mAX|mBX|mDX|mDI) & ~mask(lreg));
        }
        else
        {
            mreg = lreg;
            lreg = findreglsw(pretregs);
        }

        /* if (get segment of function that isn't necessarily in the
         * current segment (i.e. CS doesn't have the right value in it)
         */
        Symbol* s = e.Vsym;
        if (s.Sfl == FL.datseg)
        {   assert(0);
        }
        sclass = s.Sclass;
        const ety = tybasic(s.ty());
        if ((tyfarfunc(ety) || ety == TYifunc) &&
            (sclass == SC.extern_ || ClassInline(sclass) || config.wflags & WFthunk)
            || s.Sfl == FL.fardata
            || (s.ty() & mTYcs && s.Sseg != cseg && (LARGECODE || s.Sclass == SC.comdat))
           )
        {   // MOV mreg,seg of symbol
            cdb.gencs(0xB8 + mreg,0,FL.extern_,s);
            cdb.last().Iflags = CFseg;
        }
        else
        {
            const fl = (s.ty() & mTYcs) ? FL.csdata : s.Sfl;
            cdb.gen2(0x8C,            // MOV mreg,SEG REGISTER
                modregrm(3,segfl[fl],mreg));
        }
        if (pretregs & mES)
            cdb.gen2(0x8E,modregrm(3,0,mreg));        // MOV ES,mreg
    }
    getoffset(cg,cdb,e,lreg);
}

/*********************************
 * Load the offset portion of the address represented by e into
 * reg.
 */

@trusted
void getoffset(ref CGstate cg, ref CodeBuilder cdb,elem* e,reg_t reg)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod2.getoffset(cg, cdb, e, reg);

    //printf("getoffset(e = %p, reg = %s)\n", e, regm_str(mask(reg)));
    code cs = void;
    cs.Iflags = 0;
    ubyte rex = 0;
    cs.Irex = rex;
    assert(e.Eoper == OPvar || e.Eoper == OPrelconst);
    auto fl = el_fl(e);
    switch (fl)
    {
        case FL.datseg:
            cs.IEV2.Vpointer = e.Vpointer;
            goto L3;

        case FL.fardata:
            goto L4;

        case FL.tlsdata:
        if (config.exe & EX_posix)
        {
          Lposix:
            if (config.flags3 & CFG3pic)
            {
                if (I64)
                {
                    /* Generate:
                     *   LEA DI,s@TLSGD[RIP]
                     */
                    //assert(reg == DI);
                    code css = void;
                    css.Irex = REX | REX_W;
                    css.Iop = LEA;
                    css.Irm = modregrm(0,reg,5);
                    if (reg & 8)
                        css.Irex |= REX_R;
                    css.Iflags = CFopsize;
                    css.IFL1 = fl;
                    css.IEV1.Vsym = e.Vsym;
                    css.IEV1.Voffset = e.Voffset;
                    cdb.gen(&css);
                }
                else
                {
                    /* Generate:
                     *   LEA EAX,s@TLSGD[1*EBX+0]
                     */
                    assert(reg == AX);
                    load_localgot(cdb);
                    code css = void;
                    css.Iflags = 0;
                    css.Iop = LEA;             // LEA
                    css.Irex = 0;
                    css.Irm = modregrm(0,AX,4);
                    css.Isib = modregrm(0,BX,5);
                    css.IFL1 = fl;
                    css.IEV1.Vsym = e.Vsym;
                    css.IEV1.Voffset = e.Voffset;
                    cdb.gen(&css);
                }
                return;
            }
            /* Generate:
             *      MOV reg,GS:[00000000]
             *      ADD reg, offset s@TLS_LE
             * for locals, and for globals:
             *      MOV reg,GS:[00000000]
             *      ADD reg, s@TLS_IE
             * note different fixup
             */
            int stack = 0;
            if (reg == STACK)
            {   regm_t retregs = ALLREGS;

                const regx = allocreg(cdb,retregs,TYoffset);
                reg = findreg(retregs);
                stack = 1;
            }

            code css = void;
            css.Irex = rex;
            css.Iop = 0x8B;
            css.Irm = modregrm(0, 0, BPRM);
            code_newreg(&css, reg);
            css.Iflags = CFgs;
            css.IFL1 = FL.const_;
            css.IEV1.Vuns = 0;
            cdb.gen(&css);               // MOV reg,GS:[00000000]

            if (e.Vsym.Sclass == SC.static_ || e.Vsym.Sclass == SC.locstat)
            {   // ADD reg, offset s
                cs.Irex = rex;
                cs.Iop = 0x81;
                cs.Irm = modregrm(3,0,reg & 7);
                if (reg & 8)
                    cs.Irex |= REX_B;
                cs.Iflags = CFoff;
                cs.IFL2 = fl;
                cs.IEV2.Vsym = e.Vsym;
                cs.IEV2.Voffset = e.Voffset;
            }
            else
            {   // ADD reg, s
                cs.Irex = rex;
                cs.Iop = 0x03;
                cs.Irm = modregrm(0,0,BPRM);
                code_newreg(&cs, reg);
                cs.Iflags = CFoff;
                cs.IFL1 = fl;
                cs.IEV1.Vsym = e.Vsym;
                cs.IEV1.Voffset = e.Voffset;
            }
            cdb.gen(&cs);                // ADD reg, xxxx

            if (stack)
            {
                cdb.genpush(reg);        // PUSH reg
                cdb.genadjesp(REGSIZE);
                cgstate.stackchanged = 1;
            }
            break;
        }
        else if (config.exe & EX_windos)
        {
            if (I64)
            {
            Lwin64:
                assert(reg != STACK);
                cs.IEV2.Vsym = e.Vsym;
                cs.IEV2.Voffset = e.Voffset;
                cs.Iop = 0xB8 + (reg & 7);      // MOV Ereg,offset s
                if (reg & 8)
                    cs.Irex |= REX_B;
                cs.Iflags = CFoff;              // want offset only
                cs.IFL2 = fl;
                cdb.gen(&cs);
                break;
            }
            goto L4;
        }
        else
        {
            goto L4;
        }

        case FL.func:
            fl = FL.extern_;                  /* don't want PC relative addresses */
            goto L4;

        case FL.extern_:
            if (config.exe & EX_posix && e.Vsym.ty() & mTYthread)
                goto Lposix;
            if (config.exe & EX_WIN64 && e.Vsym.ty() & mTYthread)
                goto Lwin64;
            goto L4;

        case FL.data:
        case FL.udata:
        case FL.got:
        case FL.gotoff:
        case FL.csdata:
        L4:
            cs.IEV2.Vsym = e.Vsym;
            cs.IEV2.Voffset = e.Voffset;
        L3:
            if (reg == STACK)
            {   cgstate.stackchanged = 1;
                cs.Iop = 0x68;              /* PUSH immed16                 */
                cdb.genadjesp(REGSIZE);
            }
            else
            {   cs.Iop = 0xB8 + (reg & 7);  // MOV reg,immed16
                if (reg & 8)
                    cs.Irex |= REX_B;
                if (I64)
                {   cs.Irex |= REX_W;
                    if (config.flags3 & CFG3pic || config.exe == EX_WIN64)
                    {   // LEA reg,immed32[RIP]
                        cs.Iop = LEA;
                        cs.Irm = modregrm(0,reg & 7,5);
                        if (reg & 8)
                            cs.Irex = (cs.Irex & ~REX_B) | REX_R;
                        cs.IFL1 = fl;
                        cs.IEV1.Vsym = cs.IEV2.Vsym;
                        cs.IEV1.Voffset = cs.IEV2.Voffset;
                    }
                }
            }
            cs.Iflags = CFoff;              /* want offset only             */
            cs.IFL2 = fl;
            cdb.gen(&cs);
            break;

        case FL.reg:
            /* Allow this since the tree optimizer puts & in front of       */
            /* register doubles.                                            */
            goto L2;
        case FL.auto_:
        case FL.fast:
        case FL.bprel:
        case FL.fltreg:
            cgstate.reflocal = true;
            goto L2;
        case FL.para:
            cgstate.refparam = true;
        L2:
            if (reg == STACK)
            {   regm_t retregs = ALLREGS;

                const regx = allocreg(cdb,retregs,TYoffset);
                reg = findreg(retregs);
                loadea(cdb,e,cs,LEA,reg,0,0,0);    // LEA reg,EA
                if (I64)
                    code_orrex(cdb.last(), REX_W);
                cdb.genpush(reg);               // PUSH reg
                cdb.genadjesp(REGSIZE);
                cgstate.stackchanged = 1;
            }
            else
            {
                loadea(cdb,e,cs,LEA,reg,0,0,0);   // LEA reg,EA
                if (I64)
                    code_orrex(cdb.last(), REX_W);
            }
            break;

        default:
            debug
            {
                elem_print(e);
                printf("e.fl = %s\n", fl_str(el_fl(e)));
            }
            assert(0);
    }
}


/******************
 * OPneg, OPsqrt, OPsin, OPcos, OPrint
 */

@trusted
void cdneg(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdneg(cg, cdb, e, pretregs);

    //printf("cdneg()\n");
    //elem_print(e);
    if (pretregs == 0)
    {
        codelem(cgstate,cdb,e.E1,pretregs,false);
        return;
    }
    const tyml = tybasic(e.E1.Ety);
    const sz = _tysize[tyml];
    if (tyfloating(tyml))
    {
        if (tycomplex(tyml))
        {
            neg_complex87(cdb, e, pretregs);
            return;
        }
        if (tyxmmreg(tyml) && e.Eoper == OPneg && pretregs & XMMREGS)
        {
            xmmneg(cdb,e,pretregs);
            return;
        }
        if (config.inline8087 &&
            ((pretregs & (ALLREGS | mBP)) == 0 || e.Eoper == OPsqrt || I64))
            {
                neg87(cdb,e,pretregs);
                return;
            }
        regm_t retregs = (I16 && sz == 8) ? DOUBLEREGS_16 : ALLREGS;
        codelem(cgstate,cdb,e.E1,retregs,false);
        getregs(cdb,retregs);
        if (I32)
        {
            const reg = (sz == 8) ? findregmsw(retregs) : findreg(retregs);
            cdb.genc2(0x81,modregrm(3,6,reg),0x80000000); // XOR EDX,sign bit
        }
        else
        {
            const reg = (sz == 8) ? AX : findregmsw(retregs);
            cdb.genc2(0x81,modregrm(3,6,reg),0x8000);     // XOR AX,0x8000
        }
        fixresult(cdb,e,retregs,pretregs);
        return;
    }

    const uint isbyte = sz == 1;
    const possregs = (isbyte) ? BYTEREGS : cgstate.allregs;
    regm_t retregs = pretregs & possregs;
    if (retregs == 0)
        retregs = possregs;
    codelem(cgstate,cdb,e.E1,retregs,false);
    getregs(cdb,retregs);                // retregs will be destroyed
    if (sz <= REGSIZE)
    {
        const reg = findreg(retregs);
        uint rex = (I64 && sz == 8) ? REX_W : 0;
        if (I64 && sz == 1 && reg >= 4)
            rex |= REX;
        cdb.gen2(0xF7 ^ isbyte,(rex << 16) | modregrmx(3,3,reg));   // NEG reg
        if (!I16 && _tysize[tyml] == SHORTSIZE && pretregs & mPSW)
            cdb.last().Iflags |= CFopsize | CFpsw;
        pretregs &= mBP | ALLREGS;             // flags already set
    }
    else if (sz == 2 * REGSIZE)
    {
        const msreg = findregmsw(retregs);
        cdb.gen2(0xF7,modregrm(3,3,msreg));       // NEG msreg
        const lsreg = findreglsw(retregs);
        cdb.gen2(0xF7,modregrm(3,3,lsreg));       // NEG lsreg
        code_orflag(cdb.last(), CFpsw);           // need flag result of previous NEG
        cdb.genc2(0x81,modregrm(3,3,msreg),0);    // SBB msreg,0
    }
    else
        assert(0);
    fixresult(cdb,e,retregs,pretregs);
}


/******************
 * Absolute value operator, OPabs
 */


@trusted
void cdabs(ref CGstate cg, ref CodeBuilder cdb,elem* e, ref regm_t pretregs)
{
    //printf("cdabs(e = %p, pretregs = %s)\n", e, regm_str(pretregs));
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdabs(cg, cdb, e, pretregs);

    if (pretregs == 0)
    {
        codelem(cgstate,cdb,e.E1,pretregs,false);
        return;
    }
    const tyml = tybasic(e.E1.Ety);
    const sz = _tysize[tyml];
    const rex = (I64 && sz == 8) ? REX_W : 0;
    if (tyfloating(tyml))
    {
        if (tyxmmreg(tyml) && pretregs & XMMREGS)
        {
            xmmabs(cdb,e,pretregs);
            return;
        }
        if (config.inline8087 && ((pretregs & (ALLREGS | mBP)) == 0 || I64))
        {
            neg87(cdb,e,pretregs);
            return;
        }
        regm_t retregs = (!I32 && sz == 8) ? DOUBLEREGS_16 : ALLREGS;
        codelem(cgstate,cdb,e.E1,retregs,false);
        getregs(cdb,retregs);
        if (I32)
        {
            const reg = (sz == 8) ? findregmsw(retregs) : findreg(retregs);
            cdb.genc2(0x81,modregrm(3,4,reg),0x7FFFFFFF); // AND EDX,~sign bit
        }
        else
        {
            const reg = (sz == 8) ? AX : findregmsw(retregs);
            cdb.genc2(0x81,modregrm(3,4,reg),0x7FFF);     // AND AX,0x7FFF
        }
        fixresult(cdb,e,retregs,pretregs);
        return;
    }

    const uint isbyte = sz == 1;
    assert(isbyte == 0);
    regm_t possregs = (sz <= REGSIZE) ? cast(regm_t) mAX : cgstate.allregs;
    if (!I16 && sz == REGSIZE)
        possregs = cgstate.allregs;
    regm_t retregs = pretregs & possregs;
    if (retregs == 0)
        retregs = possregs;
    codelem(cgstate,cdb,e.E1,retregs,false);
    getregs(cdb,retregs);                // retregs will be destroyed
    if (sz <= REGSIZE)
    {
        /*      CWD
                XOR     AX,DX
                SUB     AX,DX
           or:
                MOV     r,reg
                SAR     r,63
                XOR     reg,r
                SUB     reg,r
         */
        reg_t reg;
        reg_t r;

        if (!I16 && sz == REGSIZE)
        {
            reg = findreg(retregs);
            r = allocScratchReg(cdb, cgstate.allregs & ~retregs);
            getregs(cdb,retregs);
            genmovreg(cdb,r,reg);                     // MOV r,reg
            cdb.genc2(0xC1,modregrmx(3,7,r),REGSIZE * 8 - 1);      // SAR r,31/63
            code_orrex(cdb.last(), rex);
        }
        else
        {
            reg = AX;
            r = DX;
            getregs(cdb,mDX);
            if (!I16 && sz == SHORTSIZE)
                cdb.gen1(0x98);                         // CWDE
            cdb.gen1(0x99);                             // CWD
            code_orrex(cdb.last(), rex);
        }
        cdb.gen2(0x33 ^ isbyte,(rex << 16) | modregxrmx(3,reg,r)); // XOR reg,r
        cdb.gen2(0x2B ^ isbyte,(rex << 16) | modregxrmx(3,reg,r)); // SUB reg,r
        if (!I16 && sz == SHORTSIZE && pretregs & mPSW)
            cdb.last().Iflags |= CFopsize | CFpsw;
        if (pretregs & mPSW)
            cdb.last().Iflags |= CFpsw;
        pretregs &= ~mPSW;                     // flags already set
    }
    else if (sz == 2 * REGSIZE)
    {
        /*      or      DX,DX
                jns     L2
                neg     DX
                neg     AX
                sbb     DX,0
            L2:
         */

        code* cnop = gennop(null);
        const msreg = findregmsw(retregs);
        const lsreg = findreglsw(retregs);
        genregs(cdb,0x09,msreg,msreg);            // OR msreg,msreg
        genjmp(cdb,JNS,FL.code,cast(block*)cnop);
        cdb.gen2(0xF7,modregrm(3,3,msreg));       // NEG msreg
        cdb.gen2(0xF7,modregrm(3,3,lsreg));       // NEG lsreg+1
        cdb.genc2(0x81,modregrm(3,3,msreg),0);    // SBB msreg,0
        cdb.append(cnop);
    }
    else
        assert(0);
    fixresult(cdb,e,retregs,pretregs);
}

/**************************
 * Post increment and post decrement.
 */

@trusted
void cdpost(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (cg.AArch64)
    {
        import dmd.backend.arm.cod2 : cdpost;
        return cdpost(cg, cdb, e, pretregs);
    }

    //printf("cdpost(pretregs = %s)\n", regm_str(pretregs));
    code cs = void;
    const op = e.Eoper;                      // OPxxxx
    if (pretregs == 0)                        // if nothing to return
    {
        cdaddass(cgstate,cdb,e,pretregs);
        return;
    }
    const tym_t tyml = tybasic(e.E1.Ety);
    const sz = _tysize[tyml];
    elem* e2 = e.E2;
    const rex = (I64 && sz == 8) ? REX_W : 0;

    if (tyfloating(tyml))
    {
        if (config.fpxmmregs && tyxmmreg(tyml) &&
            !tycomplex(tyml) // SIMD code is not set up to deal with complex
           )
        {
            xmmpost(cdb,e,pretregs);
            return;
        }

        if (config.inline8087)
        {
            post87(cdb,e,pretregs);
            return;
        }
if (config.exe & EX_windos)
{
        assert(sz <= 8);
        getlvalue(cdb,cs,e.E1,DOUBLEREGS);
        freenode(e.E1);
        regm_t idxregs = idxregm(&cs);  // mask of index regs used
        cs.Iop = 0x8B;                  /* MOV DOUBLEREGS,EA            */
        fltregs(cdb,&cs,tyml);
        cgstate.stackchanged = 1;
        int stackpushsave = cgstate.stackpush;
        regm_t retregs;
        if (sz == 8)
        {
            if (I32)
            {
                cdb.gen1(0x50 + DX);             // PUSH DOUBLEREGS
                cdb.gen1(0x50 + AX);
                cgstate.stackpush += DOUBLESIZE;
                retregs = DOUBLEREGS2_32;
            }
            else
            {
                cdb.gen1(0x50 + AX);
                cdb.gen1(0x50 + BX);
                cdb.gen1(0x50 + CX);
                cdb.gen1(0x50 + DX);             /* PUSH DOUBLEREGS      */
                cgstate.stackpush += DOUBLESIZE + DOUBLESIZE;

                cdb.gen1(0x50 + AX);
                cdb.gen1(0x50 + BX);
                cdb.gen1(0x50 + CX);
                cdb.gen1(0x50 + DX);             /* PUSH DOUBLEREGS      */
                retregs = DOUBLEREGS_16;
            }
        }
        else
        {
            cgstate.stackpush += FLOATSIZE;     /* so we know something is on   */
            if (!I32)
                cdb.gen1(0x50 + DX);
            cdb.gen1(0x50 + AX);
            retregs = FLOATREGS2;
        }
        cdb.genadjesp(cgstate.stackpush - stackpushsave);

        cgstate.stackclean++;
        scodelem(cgstate,cdb,e2,retregs,idxregs,false);
        cgstate.stackclean--;

        if (tyml == TYdouble || tyml == TYdouble_alias)
        {
            retregs = DOUBLEREGS;
            callclib(cdb,e,(op == OPpostinc) ? CLIB.dadd : CLIB.dsub,
                    retregs,idxregs);
        }
        else /* tyml == TYfloat */
        {
            retregs = FLOATREGS;
            callclib(cdb,e,(op == OPpostinc) ? CLIB.fadd : CLIB.fsub,
                    retregs,idxregs);
        }
        cs.Iop = 0x89;                  /* MOV EA,DOUBLEREGS            */
        fltregs(cdb,&cs,tyml);
        stackpushsave = cgstate.stackpush;
        if (tyml == TYdouble || tyml == TYdouble_alias)
        {   if (pretregs == mSTACK)
                retregs = mSTACK;       /* leave result on stack        */
            else
            {
                if (I32)
                {
                    cdb.gen1(0x58 + AX);
                    cdb.gen1(0x58 + DX);
                }
                else
                {
                    cdb.gen1(0x58 + DX);
                    cdb.gen1(0x58 + CX);
                    cdb.gen1(0x58 + BX);
                    cdb.gen1(0x58 + AX);
                }
                cgstate.stackpush -= DOUBLESIZE;
                retregs = DOUBLEREGS;
            }
        }
        else
        {
            cdb.gen1(0x58 + AX);
            if (!I32)
                cdb.gen1(0x58 + DX);
            cgstate.stackpush -= FLOATSIZE;
            retregs = FLOATREGS;
        }
        cdb.genadjesp(cgstate.stackpush - stackpushsave);
        fixresult(cdb,e,retregs,pretregs);
        return;
}
    }
    if (tyxmmreg(tyml))
    {
        xmmpost(cdb,e,pretregs);
        return;
    }

    assert(e2.Eoper == OPconst);
    uint isbyte = (sz == 1);
    regm_t possregs = isbyte ? BYTEREGS : cgstate.allregs;
    getlvalue(cdb,cs,e.E1,0);
    freenode(e.E1);
    regm_t idxregs = idxregm(&cs);       // mask of index regs used
    if (sz <= REGSIZE && pretregs == mPSW && (cs.Irm & 0xC0) == 0xC0 &&
        (!I16 || (idxregs & (mBX | mSI | mDI | mBP))))
    {
        // Generate:
        //      TEST    reg,reg
        //      LEA     reg,n[reg]      // don't affect flags
        reg_t reg = cs.Irm & 7;
        if (cs.Irex & REX_B)
            reg |= 8;
        cs.Iop = 0x85 ^ isbyte;
        code_newreg(&cs, reg);
        cs.Iflags |= CFpsw;
        cdb.gen(&cs);             // TEST reg,reg

        // If lvalue is a register variable, we must mark it as modified
        modEA(cdb,&cs);

        auto n = e2.Vint;
        if (op == OPpostdec)
            n = -n;
        int rm = reg;
        if (I16)
        {
            static immutable byte[8] regtorm = [ -1,-1,-1, 7,-1, 6, 4, 5 ]; // copied from cod1.c
            rm = regtorm[reg];
        }
        cdb.genc1(LEA,(rex << 16) | buildModregrm(2,reg,rm),FL.const_,n); // LEA reg,n[reg]
        return;
    }
    else if (sz <= REGSIZE || tyfv(tyml))
    {
        code cs2 = void;

        cs.Iop = 0x8B ^ isbyte;
        regm_t retregs = possregs & ~idxregs & pretregs;
        if (!tyfv(tyml))
        {
            if (retregs == 0)
                retregs = possregs & ~idxregs;
        }
        else /* tyfv(tyml) */
        {
            if ((retregs &= mLSW) == 0)
                retregs = mLSW & ~idxregs;
            /* Can't use LES if the EA uses ES as a seg override    */
            if (pretregs & mES && (cs.Iflags & CFSEG) != CFes)
            {   cs.Iop = 0xC4;                      /* LES          */
                getregs(cdb,mES);           // allocate ES
            }
        }
        const reg = allocreg(cdb,retregs,TYint);
        code_newreg(&cs, reg);
        if (sz == 1 && I64 && reg >= 4)
            cs.Irex |= REX;
        cdb.gen(&cs);                     // MOV reg,EA
        cs2 = cs;

        /* If lvalue is a register variable, we must mark it as modified */
        modEA(cdb,&cs);

        cs.Iop = 0x81 ^ isbyte;
        cs.Irm &= ~cast(int)modregrm(0,7,0);             // reg field = 0
        cs.Irex &= ~REX_R;
        if (op == OPpostdec)
            cs.Irm |= modregrm(0,5,0);  /* SUB                  */
        cs.IFL2 = FL.const_;
        targ_int n = e2.Vint;
        cs.IEV2.Vint = n;
        if (n == 1)                     /* can use INC or DEC           */
        {
            cs.Iop |= 0xFE;             /* xFE is dec byte, xFF is word */
            if (op == OPpostdec)
                NEWREG(cs.Irm,1);       // DEC EA
            else
                NEWREG(cs.Irm,0);       // INC EA
        }
        else if (n == -1)               // can use INC or DEC
        {
            cs.Iop |= 0xFE;             // xFE is dec byte, xFF is word
            if (op == OPpostinc)
                NEWREG(cs.Irm,1);       // DEC EA
            else
                NEWREG(cs.Irm,0);       // INC EA
        }

        // For scheduling purposes, we wish to replace:
        //      MOV     reg,EA
        //      OP      EA
        // with:
        //      MOV     reg,EA
        //      OP      reg
        //      MOV     EA,reg
        //      ~OP     reg
        if (sz <= REGSIZE && (cs.Irm & 0xC0) != 0xC0 &&
            config.target_cpu >= TARGET_Pentium &&
            config.flags4 & CFG4speed)
        {
            // Replace EA in cs with reg
            cs.Irm = (cs.Irm & ~cast(int)modregrm(3,0,7)) | modregrm(3,0,reg & 7);
            if (reg & 8)
            {   cs.Irex &= ~REX_R;
                cs.Irex |= REX_B;
            }
            else
                cs.Irex &= ~REX_B;
            if (I64 && sz == 1 && reg >= 4)
                cs.Irex |= REX;
            cdb.gen(&cs);                        // ADD/SUB reg,const

            // Reverse MOV direction
            cs2.Iop ^= 2;
            cdb.gen(&cs2);                       // MOV EA,reg

            // Toggle INC <. DEC, ADD <. SUB
            cs.Irm ^= (n == 1 || n == -1) ? modregrm(0,1,0) : modregrm(0,5,0);
            cdb.gen(&cs);

            if (pretregs & mPSW)
            {   pretregs &= ~mPSW;              // flags already set
                code_orflag(cdb.last(),CFpsw);
            }
        }
        else
            cdb.gen(&cs);                        // ADD/SUB EA,const

        freenode(e2);
        if (tyfv(tyml))
        {
            reg_t preg;

            getlvalue_msw(cs);
            if (pretregs & mES)
            {
                preg = ES;
                /* ES is already loaded if CFes is 0            */
                cs.Iop = ((cs.Iflags & CFSEG) == CFes) ? 0x8E : NOP;
                NEWREG(cs.Irm,0);       /* MOV ES,EA+2          */
            }
            else
            {
                regm_t retregsx = pretregs & mMSW;
                if (!retregsx)
                    retregsx = mMSW;
                preg = allocreg(cdb,retregsx,TYint);
                cs.Iop = 0x8B;
                if (I32)
                    cs.Iflags |= CFopsize;
                NEWREG(cs.Irm,preg);    /* MOV preg,EA+2        */
            }
            getregs(cdb,mask(preg));
            cdb.gen(&cs);
            retregs = mask(reg) | mask(preg);
        }
        fixresult(cdb,e,retregs,pretregs);
        return;
    }
    else if (tyml == TYhptr)
    {
        uint rvalue;
        regm_t mtmp;

        rvalue = e2.Vlong;
        freenode(e2);

        // If h--, convert to h++
        if (e.Eoper == OPpostdec)
            rvalue = -rvalue;

        regm_t retregs = mLSW & ~idxregs & pretregs;
        if (!retregs)
            retregs = mLSW & ~idxregs;
        const lreg = allocreg(cdb,retregs,TYint);

        // Can't use LES if the EA uses ES as a seg override
        if (pretregs & mES && (cs.Iflags & CFSEG) != CFes)
        {   cs.Iop = 0xC4;
            retregs |= mES;
            getregs(cdb,mES|mCX);       // allocate ES
            cs.Irm |= modregrm(0,lreg,0);
            cdb.gen(&cs);                       // LES lreg,EA
        }
        else
        {   cs.Iop = 0x8B;
            retregs |= mDX;
            getregs(cdb,mDX|mCX);
            cs.Irm |= modregrm(0,lreg,0);
            cdb.gen(&cs);                       // MOV lreg,EA
            NEWREG(cs.Irm,DX);
            getlvalue_msw(cs);
            cdb.gen(&cs);                       // MOV DX,EA+2
            getlvalue_lsw(cs);
        }

        // Allocate temporary register, rtmp
        mtmp = ALLREGS & ~mCX & ~idxregs & ~retregs;
        const rtmp = allocreg(cdb,mtmp,TYint);

        movregconst(cdb,rtmp,rvalue >> 16,0);   // MOV rtmp,e2+2
        getregs(cdb,mtmp);
        cs.Iop = 0x81;
        NEWREG(cs.Irm,0);
        cs.IFL2 = FL.const_;
        cs.IEV2.Vint = rvalue;
        cdb.gen(&cs);                           // ADD EA,e2
        code_orflag(cdb.last(),CFpsw);
        cdb.genc2(0x81,modregrm(3,2,rtmp),0);   // ADC rtmp,0
        genshift(cdb);                          // MOV CX,offset __AHSHIFT
        cdb.gen2(0xD3,modregrm(3,4,rtmp));      // SHL rtmp,CL
        cs.Iop = 0x01;
        NEWREG(cs.Irm,rtmp);                    // ADD EA+2,rtmp
        getlvalue_msw(cs);
        cdb.gen(&cs);
        fixresult(cdb,e,retregs,pretregs);
        return;
    }
    else if (sz == 2 * REGSIZE)
    {
        regm_t retregs = cgstate.allregs & ~idxregs & pretregs;
        if ((retregs & mLSW) == 0)
                retregs |= mLSW & ~idxregs;
        if ((retregs & mMSW) == 0)
                retregs |= ALLREGS & mMSW;
        assert(retregs & mMSW && retregs & mLSW);
        const reg = allocreg(cdb,retregs,tyml);
        uint sreg = findreglsw(retregs);
        cs.Iop = 0x8B;
        cs.Irm |= modregrm(0,sreg,0);
        cdb.gen(&cs);                   // MOV sreg,EA
        NEWREG(cs.Irm,reg);
        getlvalue_msw(cs);
        cdb.gen(&cs);                   // MOV reg,EA+2
        cs.Iop = 0x81;
        cs.Irm &= ~cast(int)modregrm(0,7,0);     /* reg field = 0 for ADD        */
        if (op == OPpostdec)
            cs.Irm |= modregrm(0,5,0);  /* SUB                          */
        getlvalue_lsw(cs);
        cs.IFL2 = FL.const_;
        cs.IEV2.Vlong = e2.Vlong;
        cdb.gen(&cs);                   // ADD/SUB EA,const
        code_orflag(cdb.last(),CFpsw);
        getlvalue_msw(cs);
        cs.IEV2.Vlong = 0;
        if (op == OPpostinc)
            cs.Irm ^= modregrm(0,2,0);  /* ADC                          */
        else
            cs.Irm ^= modregrm(0,6,0);  /* SBB                          */
        cs.IEV2.Vlong = cast(targ_long)(e2.Vullong >> (REGSIZE * 8));
        cdb.gen(&cs);                   // ADC/SBB EA,0
        freenode(e2);
        fixresult(cdb,e,retregs,pretregs);
        return;
    }
    else
    {
        assert(0);
    }
}


void cderr(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    debug
        elem_print(e);

    //printf("op = %d, %d\n", e.Eoper, OPstring);
    //printf("string = %p, len = %d\n", e.ss.Vstring, e.ss.Vstrlen);
    //printf("string = '%.*s'\n", cast(int)e.ss.Vstrlen, e.ss.Vstring);
    assert(0);
}

@trusted
void cdinfo(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    switch (e.E1.Eoper)
    {
        case OPdctor:
            codelem(cgstate,cdb,e.E2,pretregs,false);
            regm_t retregs = 0;
            codelem(cgstate,cdb,e.E1,retregs,false);
            break;
        default:
            assert(0);
    }
}

/*******************************************
 * D constructor.
 * OPdctor
 */

@trusted
void cddctor(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    /* Generate:
        PSOP.dctor
        MOV     sindex[BP],index
     */
    cgstate.usednteh |= EHcleanup;
    if (config.ehmethod == EHmethod.EH_WIN32)
    {   cgstate.usednteh |= NTEHcleanup | NTEH_try;
        nteh_usevars();
    }
    assert(pretregs == 0);
    code cs;
    cs.Iop = PSOP.dctor;         // mark start of EH range
    cs.Iflags = 0;
    cs.Irex = 0;
    cs.IFL1 = FL.ctor;
    cs.IEV1.Vtor = e;
    cdb.gen(&cs);
    nteh_gensindex(cdb,0);              // the actual index will be patched in later
                                        // by except_fillInEHTable()
}

/*******************************************
 * D destructor.
 * OPddtor
 */

@trusted
void cdddtor(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (config.ehmethod == EHmethod.EH_DWARF)
    {
        cgstate.usednteh |= EHcleanup;

        code cs;
        cs.Iop = PSOP.ddtor;     // mark end of EH range and where landing pad is
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.IFL1 = FL.dtor;
        cs.IEV1.Vtor = e;
        cdb.gen(&cs);

        // Mark all registers as destroyed
        getregsNoSave(cgstate.allregs);

        assert(pretregs == 0);
        codelem(cgstate,cdb,e.E1,pretregs,false);
        return;
    }
    else
    {
        /* Generate:
            PSOP.ddtor
            MOV     sindex[BP],index
            CALL    dtor
            JMP     L1
        Ldtor:
            ... e.E1 ...
            RET
        L1: NOP
        */
        cgstate.usednteh |= EHcleanup;
        if (config.ehmethod == EHmethod.EH_WIN32)
        {   cgstate.usednteh |= NTEHcleanup | NTEH_try;
            nteh_usevars();
        }

        code cs;
        cs.Iop = PSOP.ddtor;
        cs.Iflags = 0;
        cs.Irex = 0;
        cs.IFL1 = FL.dtor;
        cs.IEV1.Vtor = e;
        cdb.gen(&cs);

        nteh_gensindex(cdb,0);              // the actual index will be patched in later
                                            // by except_fillInEHTable()

        // Mark all registers as destroyed
        getregsNoSave(cgstate.allregs);

        assert(pretregs == 0);
        CodeBuilder cdbx;
        cdbx.ctor();
        codelem(cgstate,cdbx,e.E1,pretregs,false);
        cdbx.gen1(0xC3);                      // RET
        code* c = cdbx.finish();

        int nalign = 0;
        if (STACKALIGN >= 16)
        {
            nalign = STACKALIGN - REGSIZE;
            cod3_stackadj(cdb, nalign);
        }
        cgstate.calledafunc = 1;
        genjmp(cdb,0xE8,FL.code,cast(block*)c);   // CALL Ldtor
        if (nalign)
            cod3_stackadj(cdb, -nalign);

        code* cnop = gennop(null);

        genjmp(cdb,JMP,FL.code,cast(block*)cnop);
        cdb.append(cdbx);
        cdb.append(cnop);
        return;
    }
}


/*******************************************
 * C++ constructor.
 */
void cdctor(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
}

/******
 * OPdtor
 */
void cddtor(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
}

void cdmark(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
}

static if (!NTEXCEPTIONS)
{
void cdsetjmp(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    assert(0);
}
}

/*****************************************
 */

@trusted
void cdvoid(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    assert(pretregs == 0);
    codelem(cgstate,cdb,e.E1,pretregs,false);
}

/*****************************************
 */

@trusted
void cdhalt(ref CGstate cg, ref CodeBuilder cdb,elem* e,ref regm_t pretregs)
{
    if (cg.AArch64)
        return dmd.backend.arm.cod2.cdhalt(cg, cdb, e, pretregs);

    assert(pretregs == 0);
    cdb.gen1(config.target_cpu >= TARGET_80286 ? UD2 : INT3);
}
