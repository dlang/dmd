/**
 * Register allocator
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/x86/cgreg.d, backend/cgreg.d)
 */

module dmd.backend.x86.cgreg;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.codebuilder;
import dmd.backend.oper;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.barray;
import dmd.backend.dlist;
import dmd.backend.dvec;


nothrow:
@safe:

private __gshared
{
    int nretblocks;

    vec_t[REGMAX] regrange;

    Barray!int weights;
}

@trusted
ref int WEIGHTS(int bi, int si) { return weights[bi * globsym.length + si]; }

/******************************************
 */

@trusted
void cgreg_init()
{
    if (!(config.flags4 & CFG4optimized))
        return;

    // Use calloc() instead because sometimes the alloc is too large
    //printf("1weights: dfo.length = %d, globsym.length = %d\n", dfo.length, globsym.length);
    weights.setLength(bo.dfo.length * globsym.length);
    weights[] = 0;

    nretblocks = 0;
    foreach (bi, b; bo.dfo[])
    {
        if (b.bc == BC.ret || b.bc == BC.retexp)
            nretblocks++;
        if (b.Belem)
        {
            //printf("b.Bweight = x%x\n",b.Bweight);
            el_weights(cast(int)bi,b.Belem,b.Bweight);
        }
    }
    memset(regrange.ptr, 0, regrange.sizeof);

    // Make adjustments to symbols we might stick in registers
    foreach (s; globsym[])
    {
        //printf("considering candidate '%s' for register\n", s.Sident.ptr);

        if (s.Srange)
            s.Srange = vec_realloc(s.Srange,bo.dfo.length);

        // Determine symbols that are not candidates
        uint sz;
        if (!(s.Sflags & GTregcand) ||
            !s.Srange ||
            (sz = cast(uint)type_size(s.Stype)) == 0 ||
            (tysize(s.ty()) == -1) ||
            (I16 && sz > REGSIZE) ||
            (tyfloating(s.ty()) && !(config.fpxmmregs && tyxmmreg(s.ty())))
           )
        {
            debug if (debugr)
            {
                printf("not considering variable '%s' for register\n",s.Sident.ptr);
                if (!(s.Sflags & GTregcand))
                    printf("\tnot GTregcand\n");
                if (!s.Srange)
                    printf("\tno Srange\n");
                if (sz == 0)
                    printf("\tsz == 0\n");
                if (tysize(s.ty()) == -1)
                    printf("\ttysize\n");
            }

            s.Sflags &= ~GTregcand;
            continue;
        }

        switch (s.Sclass)
        {
            case SC.parameter:
                // Do not put parameters in registers if they are not used
                // more than twice (otherwise we have a net loss).
                if (s.Sweight <= 2 && !tyxmmreg(s.ty()))
                {
                    debug if (debugr)
                        printf("parameter '%s' weight %d is not enough\n",s.Sident.ptr,s.Sweight);
                    s.Sflags &= ~GTregcand;
                    continue;
                }
                break;

            default:
                break;
        }

        if (sz == 1)
            s.Sflags |= GTbyte;

        if (!s.Slvreg)
            s.Slvreg = vec_calloc(bo.dfo.length);

        //printf("dfo.length = %d, numbits = %d\n",dfo.length,vec_numbits(s.Srange));
        assert(vec_numbits(s.Srange) == bo.dfo.length);
    }
}

/******************************************
 */

@trusted
void cgreg_term()
{
    if (config.flags4 & CFG4optimized)
    {
        foreach (s; globsym[])
        {
            vec_free(s.Srange);
            vec_free(s.Slvreg);
            s.Srange = null;
            s.Slvreg = null;
        }

        foreach (ref r; regrange[])
        {
            if (r)
            {
                vec_free(r);
                r = null;
            }
        }

        // weights.dtor();   // save allocation for next time
    }
}

/*********************************
 */

@trusted
void cgreg_reset()
{
    foreach (ref r; regrange[])
        if (!r)
            r = vec_calloc(bo.dfo.length);
        else
            vec_clear(r);
}

/*******************************
 * Registers used in block bi.
 */

@trusted
void cgreg_used(uint bi,regm_t used)
{
    for (size_t j = 0; used; j++)
    {   if (used & 1)           // if register j is used
            vec_setbit(bi,regrange[j]);
        used >>= 1;
    }
}

/*************************
 * Run through a tree calculating symbol weights.
 */

@trusted
private void el_weights(int bi,elem* e,uint weight)
{
    while (1)
    {   elem_debug(e);

        int op = e.Eoper;
        if (!OTleaf(op))
        {
            // This prevents variable references within common subexpressions
            // from adding to the variable's usage count.
            if (e.Ecount)
            {
                if (e.Ecomsub)
                    weight = 0;
                else
                    e.Ecomsub = 1;
            }

            if (OTbinary(op))
            {   el_weights(bi,e.E2,weight);
                if ((OTopeq(op) || OTpost(op)) && e.E1.Eoper == OPvar)
                {
                    if (weight >= 10)
                        weight += 10;
                    else
                        weight++;
                }
            }
            e = e.E1;
        }
        else
        {
            switch (op)
            {
                case OPvar:
                    Symbol* s = e.Vsym;
                    if (s.Ssymnum != SYMIDX.max && s.Sflags & GTregcand)
                    {
                        s.Sweight += weight;
                        //printf("adding %d weight to '%s' (block %d, Ssymnum %d), giving Sweight %d\n",weight,s.Sident.ptr,bi,s.Ssymnum,s.Sweight);
                        if (weights)
                            WEIGHTS(bi,cast(int)s.Ssymnum) += weight;
                    }
                    break;

                default:
                    break;
            }
            return;
        }
    }
}

/*****************************************
 * Determine 'benefit' of assigning symbol s to register reg.
 * Benefit is roughly the number of clocks saved.
 * A negative value means that s cannot or should not be assigned to reg.
 */

@trusted
private int cgreg_benefit(Symbol* s, reg_t reg, Symbol* retsym)
{
    int benefit;
    int benefit2;
    block* b;
    int bi;
    int gotoepilog;
    int retsym_cnt;

    //printf("cgreg_benefit(s = '%s', reg = %d)\n", s.Sident.ptr, reg);

    vec_sub(s.Slvreg,s.Srange,regrange[reg]);
    int si = cast(int)s.Ssymnum;

    reg_t dst_integer_reg;
    reg_t dst_float_reg;
    cgreg_dst_regs(&dst_integer_reg, &dst_float_reg);

Lagain:
    //printf("again\n");
    benefit = 0;
    retsym_cnt = 0;

static if (1) // causes assert failure in std.range(4488) from std.parallelism's unit tests
{
      // (it works now - but keep an eye on it for the moment)
    // If s is passed in a register to the function, favor that register
    if ((s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg) && s.Spreg == reg)
        ++benefit;
}

    // Make sure we have enough uses to justify
    // using a register we must save
    if (fregsaved & (1UL << reg) & cgstate.mfuncreg)
        benefit -= 1 + nretblocks;

    for (bi = 0; (bi = cast(uint) vec_index(bi, s.Srange)) < bo.dfo.length; ++bi)
    {   int inoutp;
        int inout_;

        b = bo.dfo[bi];
        switch (b.bc)
        {
            case BC.jcatch:
            case BC.catch_:
            case BC._except:
            case BC._finally:
            case BC._lpad:
            case BC._ret:
                s.Sflags &= ~GTregcand;
                goto Lcant;             // can't assign to register

            default:
                break;
        }
        if (vec_testbit(bi,s.Slvreg))
        {   benefit += WEIGHTS(bi,si);
            //printf("WEIGHTS(%d,%d) = %d, benefit = %d\n",bi,si,WEIGHTS(bi,si),benefit);
            inout_ = 1;

            if (s == retsym && (reg == dst_integer_reg || reg == dst_float_reg) && b.bc == BC.retexp)
            {   benefit += 1;
                retsym_cnt++;
                //printf("retsym, benefit = %d\n",benefit);
                if (s.Sfl == FL.reg && !vec_disjoint(s.Srange,regrange[reg]))
                    goto Lcant;                         // don't spill if already in register
            }
        }
        else
            inout_ = -1;

        // Look at predecessors to see if we need to load in/out of register
        gotoepilog = 0;
    L2:
        inoutp = 0;
        benefit2 = 0;
        foreach (bl; ListRange(b.Bpred))
        {
            block* bp = list_block(bl);
            int bpi = bp.Bdfoidx;
            if (!vec_testbit(bpi,s.Srange))
                continue;
            if (gotoepilog && bp.bc == BC.goto_)
            {
                if (vec_testbit(bpi,s.Slvreg))
                {
                    if (inout_ == -1)
                        benefit2 -= bp.Bweight;        // need to mov into mem
                }
                else
                {
                    if (inout_ == 1)
                        benefit2 -= bp.Bweight;        // need to mov into reg
                }
            }
            else if (vec_testbit(bpi,s.Slvreg))
            {
                switch (inoutp)
                {
                    case 0:
                        inoutp = 1;
                        if (inout_ != 1)
                        {   if (gotoepilog)
                            {   vec_clearbit(bpi,s.Slvreg);
                                goto Lagain;
                            }
                            benefit2 -= b.Bweight;     // need to mov into mem
                        }
                        break;
                    case 1:
                        break;
                    case -1:
                        if (gotoepilog == 0)
                        {   gotoepilog = 1;
                            goto L2;
                        }
                        vec_clearbit(bpi,s.Slvreg);
                        goto Lagain;

                    default:
                        assert(0);
                }
            }
            else
            {
                switch (inoutp)
                {
                    case 0:
                        inoutp = -1;
                        if (inout_ != -1)
                        {   if (gotoepilog)
                            {   vec_clearbit(bi,s.Slvreg);
                                goto Lagain;
                            }
                            benefit2 -= b.Bweight;     // need to mov into reg
                        }
                        break;
                    case 1:
                        if (gotoepilog == 0)
                        {   gotoepilog = 1;
                            goto L2;
                        }
                        if (inout_ == 1)
                        {   vec_clearbit(bi,s.Slvreg);
                            goto Lagain;
                        }
                        goto Lcant;
                    case -1:
                        break;

                    default:
                        assert(0);
                }
            }
        }
        //printf("benefit2 = %d\n", benefit2);
        benefit += benefit2;
    }

    //printf("2weights: dfo.length = %d, globsym.length = %d\n", dfo.length, globsym.length);
    debug if (benefit > s.Sweight + retsym_cnt + 1)
        printf("s = '%s', benefit = %d, Sweight = %d, retsym_cnt = x%x\n",s.Sident.ptr,benefit,s.Sweight, retsym_cnt);

    /* This can happen upon overflow of s.Sweight, but only in extreme cases such as
     * issues.dlang.org/show_bug.cgi?id=17098
     * It essentially means "a whole lotta uses in nested loops", where
     * it should go into a register anyway. So just saturate it at int.max
     */
    //assert(benefit <= s.Sweight + retsym_cnt + 1);
    if (benefit > s.Sweight + retsym_cnt + 1)
        benefit = int.max;      // saturate instead of overflow error
    return benefit;

Lcant:
    return -1;                  // can't assign to reg
}

/*********************************************
 * Determine if block gets symbol loaded by predecessor epilog (1),
 * or by prolog (0).
 */

int cgreg_gotoepilog(block* b,Symbol* s)
{
    int bi = b.Bdfoidx;

    int inout_;
    if (vec_testbit(bi,s.Slvreg))
        inout_ = 1;
    else
        inout_ = -1;

    // Look at predecessors to see if we need to load in/out of register
    int gotoepilog = 0;
    int inoutp = 0;
    foreach (bl; ListRange(b.Bpred))
    {
        block* bp = list_block(bl);
        int bpi = bp.Bdfoidx;
        if (!vec_testbit(bpi,s.Srange))
            continue;
        if (vec_testbit(bpi,s.Slvreg))
        {
            switch (inoutp)
            {
                case 0:
                    inoutp = 1;
                    if (inout_ != 1)
                    {   if (gotoepilog)
                            goto Lcant;
                    }
                    break;
                case 1:
                    break;
                case -1:
                    if (gotoepilog == 0)
                    {   gotoepilog = 1;
                        goto Lret;
                    }
                    goto Lcant;

                default:
                    assert(0);
            }
        }
        else
        {
            switch (inoutp)
            {
                case 0:
                    inoutp = -1;
                    if (inout_ != -1)
                    {   if (gotoepilog)
                            goto Lcant;
                    }
                    break;
                case 1:
                    if (gotoepilog == 0)
                    {   gotoepilog = 1;
                        goto Lret;
                    }
                    goto Lcant;
                case -1:
                    break;

                default:
                    assert(0);
            }
        }
    }
Lret:
    return gotoepilog;

Lcant:
    assert(0);
//    return -1;                  // can't assign to reg
}

/**********************************
 * Determine block prolog code for `s` - it's either
 * assignments to register, or storing register back in memory.
 * Params:
 *      b = block to generate prolog code for
 *      s = symbol in the block that may need prolog code
 *      cdbstore = append store code to this
 *      cdbload = append load code to this
 */
void cgreg_spillreg_prolog(block* b,Symbol* s,ref CodeBuilder cdbstore,ref CodeBuilder cdbload)
{
    const int bi = b.Bdfoidx;

    //printf("cgreg_spillreg_prolog(block %d, s = '%s')\n",bi,s.Sident.ptr);

    // Load register from s
    void load()
    {
        debug if (debugr)
        {
            printf("B%d: prolog moving '%s' into %s:%s\n",
                    bi, s.Sident.ptr, regstring[s.Sregmsw],
                    type_size(s.Stype) > REGSIZE ? regstring[s.Sreglsw] : "");
        }
        gen_spill_reg(cdbload, s, true);
    }

    // Store register to s
    void store()
    {
        debug if (debugr)
        {
            printf("B%d: prolog moving %s into '%s'\n",bi,regstring[s.Sreglsw],s.Sident.ptr);
        }
        gen_spill_reg(cdbstore, s, false);
    }

    const live = vec_testbit(bi,s.Slvreg) != 0;   // if s is in a register in block b

    // If it's startblock, and it's a spilled parameter, we
    // need to load it
    if (live && s.Sflags & SFLspill && bi == 0 &&
        (s.Sclass == SC.parameter || s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg))
    {
        return load();
    }

    if (cgreg_gotoepilog(b,s))
        return;

    // Look at predecessors to see if we need to load in/out of register
    foreach (bl; ListRange(b.Bpred))
    {
        const bpi = list_block(bl).Bdfoidx;

        if (!vec_testbit(bpi,s.Srange))
            continue;
        if (vec_testbit(bpi,s.Slvreg))
        {
            if (!live)
            {
                return store();
            }
        }
        else
        {
            if (live)
            {
                return load();
            }
        }
    }
}

/**********************************
 * Determine block epilog code - it's either
 * assignments to register, or storing register back in memory.
 * Params:
 *      b = block to generate prolog code for
 *      s = symbol in the block that may need epilog code
 *      cdbstore = append store code to this
 *      cdbload = append load code to this
 */
void cgreg_spillreg_epilog(block* b,Symbol* s,ref CodeBuilder cdbstore, ref CodeBuilder cdbload)
{
    const bi = b.Bdfoidx;
    //printf("cgreg_spillreg_epilog(block %d, s = '%s')\n",bi,s.Sident.ptr);
    //assert(b.bc == BC.goto_);
    if (!cgreg_gotoepilog(b.nthSucc(0), s))
        return;

    const live = vec_testbit(bi,s.Slvreg) != 0;

    // Look at successors to see if we need to load in/out of register
    foreach (bl; ListRange(b.Bsucc))
    {
        const bpi = list_block(bl).Bdfoidx;
        if (!vec_testbit(bpi,s.Srange))
            continue;
        if (vec_testbit(bpi,s.Slvreg))
        {
            if (!live)
            {
                debug if (debugr)
                    printf("B%d: epilog moving '%s' into %s\n",bi,s.Sident.ptr,regstring[s.Sreglsw]);
                gen_spill_reg(cdbload, s, true);
                return;
            }
        }
        else
        {
            if (live)
            {
                debug if (debugr)
                    printf("B%d: epilog moving %s into '%s'\n",bi,regstring[s.Sreglsw],s.Sident.ptr);
                gen_spill_reg(cdbstore, s, false);
                return;
            }
        }
    }
}

/***************************
 * Map symbol s into registers [NOREG,reglsw] or [regmsw, reglsw].
 */

@trusted
private void cgreg_map(Symbol* s, reg_t regmsw, reg_t reglsw)
{
    //assert(I64 || reglsw < 8);

    if (vec_disjoint(s.Srange,regrange[reglsw]) &&
        (regmsw == NOREG || vec_disjoint(s.Srange,regrange[regmsw]))
       )
    {
        s.Sfl = FL.reg;
        vec_copy(s.Slvreg,s.Srange);
    }
    else
    {
        s.Sflags |= SFLspill;

        // Already computed by cgreg_benefit()
        //vec_sub(s.Slvreg,s.Srange,regrange[reglsw]);

        if (s.Sfl == FL.reg)            // if reassigned
        {
            switch (s.Sclass)
            {
                case SC.auto_:
                case SC.register:
                    s.Sfl = FL.auto_;
                    break;
                case SC.fastpar:
                    s.Sfl = FL.fast;
                    break;
                case SC.bprel:
                    s.Sfl = FL.bprel;
                    break;
                case SC.shadowreg:
                case SC.parameter:
                    s.Sfl = FL.para;
                    break;
                case SC.pseudo:
                    s.Sfl = FL.pseudo;
                    break;
                case SC.stack:
                    s.Sfl = FL.stack;
                    break;
                default:
                    symbol_print(*s);
                    assert(0);
            }
        }
    }
    s.Sreglsw = cast(ubyte)reglsw;
    s.Sregm = (1UL << reglsw);
    cgstate.mfuncreg &= ~(1UL << reglsw);
    if (regmsw != NOREG)
        vec_subass(s.Slvreg,regrange[regmsw]);
    vec_orass(regrange[reglsw],s.Slvreg);

    if (regmsw == NOREG)
    {
        debug
        {
            if (debugr)
            {
                printf("symbol '%s' %s in register %s\n    ",
                    s.Sident.ptr,
                    (s.Sflags & SFLspill) ? "spilled".ptr : "put".ptr,
                    regstring[reglsw]);
                vec_println(s.Slvreg);
            }
        }
    }
    else
    {
        assert(regmsw < 8);
        s.Sregmsw = cast(ubyte)regmsw;
        s.Sregm |= 1UL << regmsw;
        cgstate.mfuncreg &= ~(1UL << regmsw);
        vec_orass(regrange[regmsw],s.Slvreg);

        debug
        {
            if (debugr)
                printf("symbol '%s' %s in register pair %s\n",
                    s.Sident.ptr,
                    (s.Sflags & SFLspill) ? "spilled".ptr : "put".ptr,
                    regm_str(s.Sregm));
        }
    }
}

/********************************************
 * The register variables in this mask can not be in registers.
 * "Unregister" them.
 */

@trusted
void cgreg_unregister(regm_t conflict)
{
    if (cgstate.pass == BackendPass.final_)
        cgstate.pass = BackendPass.reg;                         // have to codegen at least one more time
    foreach (s; globsym[])
    {
        if (s.Sfl == FL.reg && s.Sregm & conflict)
        {
            s.Sflags |= GTunregister;
        }
    }
}

/******************************************
 * Do register assignments.
 * Returns:
 *      !=0     redo code generation
 *      0       no more register assignments
 */

struct Reg              // data for trial register assignment
{
    Symbol* sym;
    int benefit;
    reg_t reglsw;
    reg_t regmsw;
}

@trusted
int cgreg_assign(Symbol* retsym)
{
    int flag = false;                   // assume no changes

    /* First do any 'unregistering' which might have happened in the last
     * code gen pass.
     */
    foreach (s; globsym[])
    {
        if (s.Sflags & GTunregister)
        {
            debug if (debugr)
            {
                printf("symbol '%s' %s register %s\n    ",
                    s.Sident.ptr,
                    (s.Sflags & SFLspill) ? "unspilled".ptr : "unregistered".ptr,
                    regstring[s.Sreglsw]);
                vec_println(s.Slvreg);
            }

            flag = true;
            s.Sflags &= ~(GTregcand | GTunregister | SFLspill);
            if (s.Sfl == FL.reg)
            {
                switch (s.Sclass)
                {
                    case SC.auto_:
                    case SC.register:
                        s.Sfl = FL.auto_;
                        break;
                    case SC.fastpar:
                        s.Sfl = FL.fast;
                        break;
                    case SC.bprel:
                        s.Sfl = FL.bprel;
                        break;
                    case SC.shadowreg:
                    case SC.parameter:
                        s.Sfl = FL.para;
                        break;
                    case SC.pseudo:
                        s.Sfl = FL.pseudo;
                        break;
                    case SC.stack:
                        s.Sfl = FL.stack;
                        break;
                    default:
                        debug symbol_print(*s);
                        assert(0);
                }
            }
        }
    }

    vec_t v = vec_calloc(bo.dfo.length);

    reg_t dst_integer_reg;
    reg_t dst_float_reg;
    cgreg_dst_regs(&dst_integer_reg, &dst_float_reg);
    regm_t dst_integer_mask = 1UL << dst_integer_reg;
    regm_t dst_float_mask = 1UL << dst_float_reg;

    /* Find all the parameters passed as named registers
     */
    regm_t regparams = 0;
    foreach (s; globsym[])
    {
        if (s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg)
            regparams |= s.Spregm();
    }

    /* Disallow parameters being put in registers that are used by the 64 bit
     * prolog generated by prolog_getvarargs()
     */
    regm_t variadicPrologRegs = (I64 && variadic(funcsym_p.Stype))
        ? (mAX | mR11) |   // these are used by the prolog code
          ((mDI | mSI | mDX | mCX | mR8 | mR9 | XMMREGS) & ~regparams) // unnamed register arguments
        : 0;

    if (cgstate.AArch64)
    {
        variadicPrologRegs = variadic(funcsym_p.Stype)
            ? (mask(11)) |   // these are used by the prolog code
              ((0xFF_0000_00FF) & ~regparams) // unnamed register arguments R0..R7 and Q32..Q39
            : 0;
    }

    // Find symbol t, which is the most 'deserving' symbol that should be
    // placed into a register.
    Reg t;
    t.sym = null;
    t.benefit = 0;
    foreach (s; globsym[])
    {
        Reg u;
        u.sym = s;
        if (!(s.Sflags & GTregcand) ||
            s.Sflags & SFLspill ||
            // Keep trying to reassign retsym into destination register
            (s.Sfl == FL.reg && !(s == retsym && s.Sregm != dst_integer_mask && s.Sregm != dst_float_mask))
           )
        {
            debug if (debugr)
            {
                if (s.Sfl == FL.reg)
                {
                    printf("symbol '%s' is in reg %s\n",s.Sident.ptr,regm_str(s.Sregm));
                }
                else if (s.Sflags & SFLspill)
                {
                    printf("symbol '%s' spilled in reg %s\n",s.Sident.ptr,regm_str(s.Sregm));
                }
                else if (!(s.Sflags & GTregcand))
                {
                    printf("symbol '%s' is not a reg candidate\n",s.Sident.ptr);
                }
                else
                    printf("symbol '%s' is not a candidate\n",s.Sident.ptr);
            }

            continue;
        }

        tym_t ty = s.ty();

        debug
        {
            if (debugr)
            {   printf("symbol '%3s', ty x%x weight x%x %s\n   ",
                s.Sident.ptr,ty,s.Sweight,
                regm_str(s.Spregm()));
                vec_println(s.Srange);
            }
        }

        // Select sequence of registers to try to map s onto
        const(reg_t)* pseq;                     // sequence to try for LSW
        const(reg_t)* pseqmsw = null;           // sequence to try for MSW, null if none
        cgreg_set_priorities(ty, &pseq, &pseqmsw);

        u.benefit = 0;
        for (int i = 0; pseq[i] != NOREG; i++)
        {
            reg_t reg = pseq[i];

            // Symbols used as return values should only be mapped into return value registers
            if (s == retsym && !(reg == dst_integer_reg || reg == dst_float_reg))
                continue;

            // If BP isn't available, can't assign to it
            if (reg == BP && !(cgstate.allregs & mBP))
                continue;

static if (0 && TARGET_LINUX)
{
            // Need EBX for static pointer
            if (reg == BX && !(cgstate.allregs & mBX))
                continue;
}
            /* Don't enregister any parameters to variadicPrologRegs
             */
            if (variadicPrologRegs & (1UL << reg))
            {
                if (s.Sclass == SC.parameter || s.Sclass == SC.fastpar)
                    continue;
                /* Win64 doesn't use the Posix variadic scheme, so we can skip SCshadowreg
                 */
            }

            /* Don't assign register parameter to another register parameter
             */
            if ((s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg) &&
                (1UL << reg) & regparams &&
                reg != s.Spreg)
                continue;

            if (s.Sflags & GTbyte &&
                !((1UL << reg) & BYTEREGS))
                    continue;

            int benefit = cgreg_benefit(s,reg,retsym);

            debug if (debugr)
            {   printf(" %s",regstring[reg]);
                vec_print(regrange[reg]);
                printf(" %d\n",benefit);
            }

            if (benefit > u.benefit)
            {   // successful assigning of lsw
                reg_t regmsw = NOREG;

                // Now assign MSW
                if (pseqmsw)
                {
                    for (uint regj = 0; 1; regj++)
                    {
                        regmsw = pseqmsw[regj];
                        if (regmsw == NOREG)
                            goto Ltried;                // tried and failed to assign MSW
                        if (regmsw == reg)              // can't assign msw and lsw to same reg
                            continue;
                        if ((s.Sclass == SC.fastpar || s.Sclass == SC.shadowreg) &&
                            (1UL << regmsw) & regparams &&
                            regmsw != s.Spreg2)
                            continue;

                        debug if (debugr)
                        {   printf(".%s",regstring[regmsw]);
                            vec_println(regrange[regmsw]);
                        }

                        if (vec_disjoint(s.Slvreg,regrange[regmsw]))
                            break;
                    }
                }
                vec_copy(v,s.Slvreg);
                u.benefit = benefit;
                u.reglsw = reg;
                u.regmsw = regmsw;
            }
Ltried:
        }

        if (u.benefit > t.benefit)
        {   t = u;
            vec_copy(t.sym.Slvreg,v);
        }
    }

    if (t.sym && t.benefit > 0)
    {
        cgreg_map(t.sym,t.regmsw,t.reglsw);
        flag = true;
    }

    /* See if any scratch registers have become available that we can use.
     * Scratch registers are cheaper, as they don't need save/restore.
     * All floating point registers are scratch registers, so no need
     * to do this for them.
     */
    if ((I32 || I64) &&                       // not worth the bother for 16 bit code
        !flag &&                              // if haven't already assigned registers in this pass
        (cgstate.mfuncreg & ~fregsaved) & ALLREGS &&  // if unused non-floating scratch registers
        !(funcsym_p.Sflags & SFLexit))       // don't need save/restore if function never returns
    {
        foreach (s; globsym[])
        {
            if (s.Sfl == FL.reg &&                // if assigned to register
                (1UL << s.Sreglsw) & fregsaved &&   // and that register is not scratch
                type_size(s.Stype) <= REGSIZE && // don't bother with register pairs
                !tyfloating(s.ty()))             // don't assign floating regs to non-floating regs
            {
                s.Sreglsw = findreg((cgstate.mfuncreg & ~fregsaved) & ALLREGS);
                s.Sregm = 1UL << s.Sreglsw;
                flag = true;

                debug if (debugr)
                    printf("re-assigned '%s' to %s\n",s.Sident.ptr,regstring[s.Sreglsw]);

                break;
            }
        }
    }
    vec_free(v);

    return flag;
}
