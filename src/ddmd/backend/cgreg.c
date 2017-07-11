/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/cgreg.c
 */


#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <time.h>
#include        "cc.h"
#include        "el.h"
#include        "oper.h"
#include        "code.h"
#include        "global.h"
#include        "type.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

STATIC void el_weights(int bi,elem *e,unsigned weight);

#ifndef __DMC__
#undef __cdecl
#define __cdecl
#endif

static int __cdecl weight_compare(const void *e1,const void *e2);

static int nretblocks;

static vec_t regrange[REGMAX];

static int *weights;
#define WEIGHTS(bi,si)  weights[bi * globsym.top + si]

/******************************************
 */

void cgreg_init()
{
    if (!(config.flags4 & CFG4optimized))
        return;

    // Use calloc() instead because sometimes the alloc is too large
    //printf("1weights: dfotop = %d, globsym.top = %d\n", dfotop, globsym.top);
    weights = (int *) calloc(1,dfotop * globsym.top * sizeof(weights[0]));
    assert(weights);

    nretblocks = 0;
    for (int bi = 0; bi < dfotop; bi++)
    {   block *b = dfo[bi];
        if (b->BC == BCret || b->BC == BCretexp)
            nretblocks++;
        if (b->Belem)
        {
            //printf("b->Bweight = x%x\n",b->Bweight);
            el_weights(bi,b->Belem,b->Bweight);
        }
    }
    memset(regrange,0,sizeof(regrange));

    // Make adjustments to symbols we might stick in registers
    for (size_t i = 0; i < globsym.top; i++)
    {   unsigned sz;
        symbol *s = globsym.tab[i];

        //printf("considering candidate '%s' for register\n",s->Sident);

        if (s->Srange)
            s->Srange = vec_realloc(s->Srange,dfotop);

        // Determine symbols that are not candidates
        if (!(s->Sflags & GTregcand) ||
            !s->Srange ||
            (sz = type_size(s->Stype)) == 0 ||
            (tysize(s->ty()) == -1) ||
            (I16 && sz > REGSIZE) ||
            (tyfloating(s->ty()) && !(config.fpxmmregs && tyxmmreg(s->ty())))
           )
        {
            #ifdef DEBUG
            if (debugr)
            {
                printf("not considering variable '%s' for register\n",s->Sident);
                if (!(s->Sflags & GTregcand))
                    printf("\tnot GTregcand\n");
                if (!s->Srange)
                    printf("\tno Srange\n");
                if (sz == 0)
                    printf("\tsz == 0\n");
                if (tysize(s->ty()) == -1)
                    printf("\ttysize\n");
            }
            #endif
            s->Sflags &= ~GTregcand;
            continue;
        }

        switch (s->Sclass)
        {   case SCparameter:
            case SCfastpar:
            case SCshadowreg:
                // Do not put parameters in registers if they are not used
                // more than twice (otherwise we have a net loss).
                if (s->Sweight <= 2 && !tyxmmreg(s->ty()))
                {
                    #ifdef DEBUG
                    if (debugr)
                        printf("parameter '%s' weight %d is not enough\n",s->Sident,s->Sweight);
                    #endif
                    s->Sflags &= ~GTregcand;
                    continue;
                }
                break;
        }

        if (sz == 1)
            s->Sflags |= GTbyte;

        if (!s->Slvreg)
            s->Slvreg = vec_calloc(dfotop);

        //printf("dfotop = %d, numbits = %d\n",dfotop,vec_numbits(s->Srange));
        assert(vec_numbits(s->Srange) == dfotop);
    }
}

/******************************************
 */

void cgreg_term()
{
    if (config.flags4 & CFG4optimized)
    {
        for (size_t i = 0; i < globsym.top; i++)
        {
            Symbol *s = globsym.tab[i];
            vec_free(s->Srange);
            vec_free(s->Slvreg);
            s->Srange = NULL;
            s->Slvreg = NULL;
        }

        for (size_t i = 0; i < arraysize(regrange); i++)
        {
            if (regrange[i])
            {   vec_free(regrange[i]);
                regrange[i] = NULL;
            }
        }

        free(weights);
        weights = NULL;
    }
}

/*********************************
 */

void cgreg_reset()
{
    for (size_t j = 0; j < arraysize(regrange); j++)
        if (!regrange[j])
            regrange[j] = vec_calloc(dfotop);
        else
            vec_clear(regrange[j]);
}

/*******************************
 * Registers used in block bi.
 */

void cgreg_used(unsigned bi,regm_t used)
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

STATIC void el_weights(int bi,elem *e,unsigned weight)
{
    while (1)
    {   elem_debug(e);

        int op = e->Eoper;
        if (!OTleaf(op))
        {
            // This prevents variable references within common subexpressions
            // from adding to the variable's usage count.
            if (e->Ecount)
            {
                if (e->Ecomsub)
                    weight = 0;
                else
                    e->Ecomsub = 1;
            }

            if (OTbinary(op))
            {   el_weights(bi,e->E2,weight);
                if ((OTopeq(op) || OTpost(op)) && e->E1->Eoper == OPvar)
                {
                    if (weight >= 10)
                        weight += 10;
                    else
                        weight++;
                }
            }
            e = e->E1;
        }
        else
        {
            switch (op)
            {
                case OPvar:
                    Symbol *s = e->EV.sp.Vsym;
                    if (s->Ssymnum != -1 && s->Sflags & GTregcand)
                    {
                        s->Sweight += weight;
                        //printf("adding %d weight to '%s' (block %d, Ssymnum %d), giving Sweight %d\n",weight,s->Sident,bi,s->Ssymnum,s->Sweight);
                        if (weights)
                            WEIGHTS(bi,s->Ssymnum) += weight;
                    }
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

int cgreg_benefit(Symbol *s,int reg, Symbol *retsym)
{
    int benefit;
    int benefit2;
    block *b;
    int bi;
    int gotoepilog;
    int retsym_cnt;

    //printf("cgreg_benefit(s = '%s', reg = %d)\n", s->Sident, reg);

    vec_sub(s->Slvreg,s->Srange,regrange[reg]);
    int si = s->Ssymnum;

    regm_t dst_integer_reg;
    regm_t dst_float_reg;
    cgreg_dst_regs(&dst_integer_reg, &dst_float_reg);

Lagain:
    //printf("again\n");
    benefit = 0;
    retsym_cnt = 0;

#if 1 // causes assert failure in std.range(4488) from std.parallelism's unit tests
      // (it works now - but keep an eye on it for the moment)
    // If s is passed in a register to the function, favor that register
    if ((s->Sclass == SCfastpar || s->Sclass == SCshadowreg) && s->Spreg == reg)
        ++benefit;
#endif

    // Make sure we have enough uses to justify
    // using a register we must save
    if (fregsaved & mask[reg] & mfuncreg)
        benefit -= 1 + nretblocks;

    foreach (bi,dfotop,s->Srange)
    {   int inoutp;
        int inout;

        b = dfo[bi];
        switch (b->BC)
        {
            case BCjcatch:
            case BCcatch:
            case BC_except:
            case BC_finally:
            case BC_lpad:
            case BC_ret:
                s->Sflags &= ~GTregcand;
                goto Lcant;             // can't assign to register
        }
        if (vec_testbit(bi,s->Slvreg))
        {   benefit += WEIGHTS(bi,si);
            //printf("WEIGHTS(%d,%d) = %d, benefit = %d\n",bi,si,WEIGHTS(bi,si),benefit);
            inout = 1;

            if (s == retsym && (reg == dst_integer_reg || reg == dst_float_reg) && b->BC == BCretexp)
            {   benefit += 1;
                retsym_cnt++;
                //printf("retsym, benefit = %d\n",benefit);
                if (s->Sfl == FLreg && !vec_disjoint(s->Srange,regrange[reg]))
                    goto Lcant;                         // don't spill if already in register
            }
        }
        else
            inout = -1;

        // Look at predecessors to see if we need to load in/out of register
        gotoepilog = 0;
    L2:
        inoutp = 0;
        benefit2 = 0;
        for (list_t bl = b->Bpred; bl; bl = list_next(bl))
        {
            block *bp = list_block(bl);
            int bpi = bp->Bdfoidx;
            if (!vec_testbit(bpi,s->Srange))
                continue;
            if (gotoepilog && bp->BC == BCgoto)
            {
                if (vec_testbit(bpi,s->Slvreg))
                {
                    if (inout == -1)
                        benefit2 -= bp->Bweight;        // need to mov into mem
                }
                else
                {
                    if (inout == 1)
                        benefit2 -= bp->Bweight;        // need to mov into reg
                }
            }
            else if (vec_testbit(bpi,s->Slvreg))
            {
                switch (inoutp)
                {
                    case 0:
                        inoutp = 1;
                        if (inout != 1)
                        {   if (gotoepilog)
                            {   vec_clearbit(bpi,s->Slvreg);
                                goto Lagain;
                            }
                            benefit2 -= b->Bweight;     // need to mov into mem
                        }
                        break;
                    case 1:
                        break;
                    case -1:
                        if (gotoepilog == 0)
                        {   gotoepilog = 1;
                            goto L2;
                        }
                        vec_clearbit(bpi,s->Slvreg);
                        goto Lagain;
                }
            }
            else
            {
                switch (inoutp)
                {
                    case 0:
                        inoutp = -1;
                        if (inout != -1)
                        {   if (gotoepilog)
                            {   vec_clearbit(bi,s->Slvreg);
                                goto Lagain;
                            }
                            benefit2 -= b->Bweight;     // need to mov into reg
                        }
                        break;
                    case 1:
                        if (gotoepilog == 0)
                        {   gotoepilog = 1;
                            goto L2;
                        }
                        if (inout == 1)
                        {   vec_clearbit(bi,s->Slvreg);
                            goto Lagain;
                        }
                        goto Lcant;
                    case -1:
                        break;
                }
            }
        }
        //printf("benefit2 = %d\n", benefit2);
        benefit += benefit2;
    }

#ifdef DEBUG
    //printf("2weights: dfotop = %d, globsym.top = %d\n", dfotop, globsym.top);
    if (benefit > s->Sweight + retsym_cnt + 1)
        printf("s = '%s', benefit = %d, Sweight = %d, retsym_cnt = x%x\n",s->Sident,benefit,s->Sweight, retsym_cnt);
#endif
    assert(benefit <= s->Sweight + retsym_cnt + 1);
    return benefit;

Lcant:
    return -1;                  // can't assign to reg
}

/*********************************************
 * Determine if block gets symbol loaded by predecessor epilog (1),
 * or by prolog (0).
 */

int cgreg_gotoepilog(block *b,Symbol *s)
{
    int bi = b->Bdfoidx;

    int inout;
    if (vec_testbit(bi,s->Slvreg))
        inout = 1;
    else
        inout = -1;

    // Look at predecessors to see if we need to load in/out of register
    int gotoepilog = 0;
    int inoutp = 0;
    for (list_t bl = b->Bpred; bl; bl = list_next(bl))
    {
        block *bp = list_block(bl);
        int bpi = bp->Bdfoidx;
        if (!vec_testbit(bpi,s->Srange))
            continue;
        if (vec_testbit(bpi,s->Slvreg))
        {
            switch (inoutp)
            {
                case 0:
                    inoutp = 1;
                    if (inout != 1)
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
            }
        }
        else
        {
            switch (inoutp)
            {
                case 0:
                    inoutp = -1;
                    if (inout != -1)
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
            }
        }
    }
Lret:
    return gotoepilog;

Lcant:
    assert(0);
    return -1;                  // can't assign to reg
}

/**********************************
 * Determine block prolog code - it's either
 * assignments to register, or storing register back in memory.
 */

void cgreg_spillreg_prolog(block *b,Symbol *s,code **pcstore,code **pcload)
{
    const int bi = b->Bdfoidx;

    //printf("cgreg_spillreg_prolog(block %d, s = '%s')\n",bi,s->Sident);

    bool load = false;
    int inoutp;
    if (vec_testbit(bi,s->Slvreg))
    {   inoutp = 1;
        // If it's startblock, and it's a spilled parameter, we
        // need to load it
        if (s->Sflags & SFLspill && bi == 0 &&
            (s->Sclass == SCparameter || s->Sclass == SCfastpar || s->Sclass == SCshadowreg))
        {
            load = true;
        }
    }
    else
        inoutp = -1;

    if (!load)
    {
        if (cgreg_gotoepilog(b,s))
            return;

        // Look at predecessors to see if we need to load in/out of register
        for (list_t bl = b->Bpred; 1; bl = list_next(bl))
        {
            if (!bl)
                return;

            block *bp = list_block(bl);
            const int bpi = bp->Bdfoidx;

            if (!vec_testbit(bpi,s->Srange))
                continue;
            if (vec_testbit(bpi,s->Slvreg))
            {
                if (inoutp != -1)
                    continue;
            }
            else
            {
                if (inoutp != 1)
                    continue;
            }
            break;
        }
    }

#ifdef DEBUG
    if (debugr)
    {
        int sz = type_size(s->Stype);
        if (inoutp == -1)
            printf("B%d: prolog moving %s into '%s'\n",bi,regstring[s->Sreglsw],s->Sident);
        else
            printf("B%d: prolog moving '%s' into %s:%s\n",
                    bi, s->Sident, regstring[s->Sregmsw], sz > REGSIZE ? regstring[s->Sreglsw] : "");
    }
#endif

    CodeBuilder cdbload(*pcload);
    CodeBuilder cdbstore(*pcstore);

    if (inoutp == -1)
        gen_spill_reg(cdbstore, s, false);
    else
        gen_spill_reg(cdbload, s, true);

    // Store old register values before loading in new ones
    *pcstore = cdbstore.finish();
    *pcload = cdbload.finish();
}

/**********************************
 * Determine block epilog code - it's either
 * assignments to register, or storing register back in memory.
 */

void cgreg_spillreg_epilog(block *b,Symbol *s,code **pcstore,code **pcload)
{
    int bi = b->Bdfoidx;
    //printf("cgreg_spillreg_epilog(block %d, s = '%s')\n",bi,s->Sident);
    //assert(b->BC == BCgoto);
    if (!cgreg_gotoepilog(b->nthSucc(0), s))
        return;

    CodeBuilder cdbload(*pcload);
    CodeBuilder cdbstore(*pcstore);

    int inoutp;
    if (vec_testbit(bi,s->Slvreg))
        inoutp = 1;
    else
        inoutp = -1;

    // Look at successors to see if we need to load in/out of register
    for (list_t bl = b->Bsucc; bl; bl = list_next(bl))
    {
        block *bp = list_block(bl);
        int bpi = bp->Bdfoidx;
        if (!vec_testbit(bpi,s->Srange))
            continue;
        if (vec_testbit(bpi,s->Slvreg))
        {
            if (inoutp != -1)
                continue;
        }
        else
        {
            if (inoutp != 1)
                continue;
        }

#ifdef DEBUG
        if (debugr)
        {
            if (inoutp == 1)
                printf("B%d: epilog moving %s into '%s'\n",bi,regstring[s->Sreglsw],s->Sident);
            else
                printf("B%d: epilog moving '%s' into %s\n",bi,s->Sident,regstring[s->Sreglsw]);
        }
#endif

        if (inoutp == 1)
            gen_spill_reg(cdbstore, s, false);
        else
            gen_spill_reg(cdbload, s, true);
        break;
    }

    // Store old register values before loading in new ones
    *pcstore = cdbstore.finish();
    *pcload = cdbload.finish();
}

/***************************
 * Map symbol s into registers [NOREG,reglsw] or [regmsw, reglsw].
 */

void cgreg_map(Symbol *s, unsigned regmsw, unsigned reglsw)
{
    //assert(I64 || reglsw < 8);

    if (vec_disjoint(s->Srange,regrange[reglsw]) &&
        (regmsw == NOREG || vec_disjoint(s->Srange,regrange[regmsw]))
       )
    {
        s->Sfl = FLreg;
        vec_copy(s->Slvreg,s->Srange);
    }
    else
    {
        s->Sflags |= SFLspill;

        // Already computed by cgreg_benefit()
        //vec_sub(s->Slvreg,s->Srange,regrange[reglsw]);

        if (s->Sfl == FLreg)            // if reassigned
        {
            switch (s->Sclass)
            {
                case SCauto:
                case SCregister:
                    s->Sfl = FLauto;
                    break;
                case SCfastpar:
                    s->Sfl = FLfast;
                    break;
                case SCbprel:
                    s->Sfl = FLbprel;
                    break;
                case SCshadowreg:
                case SCparameter:
                    s->Sfl = FLpara;
                    break;
                case SCpseudo:
                    s->Sfl = FLpseudo;
                    break;
                case SCstack:
                    s->Sfl = FLstack;
                    break;
                default:
                    symbol_print(s);
                    assert(0);
            }
        }
    }
    s->Sreglsw = reglsw;
    s->Sregm = mask[reglsw];
    mfuncreg &= ~mask[reglsw];
    if (regmsw != NOREG)
        vec_subass(s->Slvreg,regrange[regmsw]);
    vec_orass(regrange[reglsw],s->Slvreg);

    if (regmsw == NOREG)
    {
        #if DEBUG
            if (debugr)
            {
                printf("symbol '%s' %s in register %s\n    ",
                    s->Sident,
                    (s->Sflags & SFLspill) ? "spilled" : "put",
                    regstring[reglsw]);
                vec_println(s->Slvreg);
            }
        #endif
    }
    else
    {
        assert(regmsw < 8);
        s->Sregmsw = regmsw;
        s->Sregm |= mask[regmsw];
        mfuncreg &= ~mask[regmsw];
        vec_orass(regrange[regmsw],s->Slvreg);

        #if DEBUG
            if (debugr)
                printf("symbol '%s' %s in register pair %s\n",
                    s->Sident,
                    (s->Sflags & SFLspill) ? "spilled" : "put",
                    regm_str(s->Sregm));
        #endif
    }
}

/********************************************
 * The register variables in this mask can not be in registers.
 * "Unregister" them.
 */

void cgreg_unregister(regm_t conflict)
{
    if (pass == PASSfinal)
        pass = PASSreg;                         // have to codegen at least one more time
    for (int i = 0; i < globsym.top; i++)
    {   symbol *s = globsym.tab[i];
        if (s->Sfl == FLreg && s->Sregm & conflict)
        {
            s->Sflags |= GTunregister;
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
    Symbol *sym;
    int reglsw;
    int regmsw;
    int benefit;
};

int cgreg_assign(Symbol *retsym)
{
    int flag = FALSE;                   // assume no changes

    /* First do any 'unregistering' which might have happened in the last
     * code gen pass.
     */
    for (size_t si = 0; si < globsym.top; si++)
    {   symbol *s = globsym.tab[si];

        if (s->Sflags & GTunregister)
        {
        #if DEBUG
            if (debugr)
            {
                printf("symbol '%s' %s register %s\n    ",
                    s->Sident,
                    (s->Sflags & SFLspill) ? "unspilled" : "unregistered",
                    regstring[s->Sreglsw]);
                vec_println(s->Slvreg);
            }
        #endif
            flag = TRUE;
            s->Sflags &= ~(GTregcand | GTunregister | SFLspill);
            if (s->Sfl == FLreg)
            {
                switch (s->Sclass)
                {
                    case SCauto:
                    case SCregister:
                        s->Sfl = FLauto;
                        break;
                    case SCfastpar:
                        s->Sfl = FLfast;
                        break;
                    case SCbprel:
                        s->Sfl = FLbprel;
                        break;
                    case SCshadowreg:
                    case SCparameter:
                        s->Sfl = FLpara;
                        break;
                    case SCpseudo:
                        s->Sfl = FLpseudo;
                        break;
                    case SCstack:
                        s->Sfl = FLstack;
                        break;
                    default:
#ifdef DEBUG
                        symbol_print(s);
#endif
                        assert(0);
                }
            }
        }
    }

    vec_t v = vec_calloc(dfotop);

    unsigned dst_integer_reg;
    unsigned dst_float_reg;
    cgreg_dst_regs(&dst_integer_reg, &dst_float_reg);
    regm_t dst_integer_mask = mask[dst_integer_reg];
    regm_t dst_float_mask = mask[dst_float_reg];

    /* Find all the parameters passed as registers
     */
    regm_t regparams = 0;
    for (size_t si = 0; si < globsym.top; si++)
    {   symbol *s = globsym.tab[si];
        if (s->Sclass == SCfastpar || s->Sclass == SCshadowreg)
            regparams |= s->Spregm();
    }

    // Find symbol t, which is the most 'deserving' symbol that should be
    // placed into a register.
    Reg t;
    t.sym = NULL;
    t.benefit = 0;
    for (size_t si = 0; si < globsym.top; si++)
    {   symbol *s = globsym.tab[si];

        Reg u;
        u.sym = s;
        if (!(s->Sflags & GTregcand) ||
            s->Sflags & SFLspill ||
            // Keep trying to reassign retsym into destination register
            (s->Sfl == FLreg && !(s == retsym && s->Sregm != dst_integer_mask && s->Sregm != dst_float_mask))
           )
        {
            #ifdef DEBUG
            if (debugr)
            if (s->Sfl == FLreg)
            {
                printf("symbol '%s' is in reg %s\n",s->Sident,regm_str(s->Sregm));
            }
            else if (s->Sflags & SFLspill)
            {
                printf("symbol '%s' spilled in reg %s\n",s->Sident,regm_str(s->Sregm));
            }
            else if (!(s->Sflags & GTregcand))
            {
                printf("symbol '%s' is not a reg candidate\n",s->Sident);
            }
            else
                printf("symbol '%s' is not a candidate\n",s->Sident);
            #endif
            continue;
        }

        tym_t ty = s->ty();

        #ifdef DEBUG
            if (debugr)
            {   printf("symbol '%3s', ty x%x weight x%x\n   ",
                s->Sident,ty,s->Sweight);
                vec_println(s->Srange);
            }
        #endif

        // Select sequence of registers to try to map s onto
        unsigned char *pseq;                     // sequence to try for LSW
        unsigned char *pseqmsw = NULL;           // sequence to try for MSW, NULL if none
        cgreg_set_priorities(ty, &pseq, &pseqmsw);

        u.benefit = 0;
        for (int i = 0; pseq[i] != NOREG; i++)
        {
            unsigned reg = pseq[i];

            // Symbols used as return values should only be mapped into return value registers
            if (s == retsym && !(reg == dst_integer_reg || reg == dst_float_reg))
                continue;

            // If BP isn't available, can't assign to it
            if (reg == BP && !(allregs & mBP))
                continue;

#if 0 && TARGET_LINUX
            // Need EBX for static pointer
            if (reg == BX && !(allregs & mBX))
                continue;
#endif
            /* Don't assign register parameter to another register parameter
             */
            if ((s->Sclass == SCfastpar || s->Sclass == SCshadowreg) &&
                mask[reg] & regparams &&
                reg != s->Spreg)
                continue;

            if (s->Sflags & GTbyte &&
                !(mask[reg] & BYTEREGS))
                    continue;

            int benefit = cgreg_benefit(s,reg,retsym);

            #ifdef DEBUG
            if (debugr)
            {   printf(" %s",regstring[reg]);
                vec_print(regrange[reg]);
                printf(" %d\n",benefit);
            }
            #endif

            if (benefit > u.benefit)
            {   // successful assigning of lsw
                unsigned regmsw = NOREG;

                // Now assign MSW
                if (pseqmsw)
                {
                    for (unsigned regj = 0; 1; regj++)
                    {
                        regmsw = pseqmsw[regj];
                        if (regmsw == NOREG)
                            goto Ltried;                // tried and failed to assign MSW
                        if (regmsw == reg)              // can't assign msw and lsw to same reg
                            continue;
                        if ((s->Sclass == SCfastpar || s->Sclass == SCshadowreg) &&
                            mask[regmsw] & regparams &&
                            regmsw != s->Spreg2)
                            continue;
                        #ifdef DEBUG
                        if (debugr)
                        {   printf(".%s",regstring[regmsw]);
                            vec_println(regrange[regmsw]);
                        }
                        #endif
                        if (vec_disjoint(s->Slvreg,regrange[regmsw]))
                            break;
                    }
                }
                vec_copy(v,s->Slvreg);
                u.benefit = benefit;
                u.reglsw = reg;
                u.regmsw = regmsw;
            }
Ltried:     ;
        }

        if (u.benefit > t.benefit)
        {   t = u;
            vec_copy(t.sym->Slvreg,v);
        }
    }

    if (t.sym && t.benefit > 0)
    {
        cgreg_map(t.sym,t.regmsw,t.reglsw);
        flag = TRUE;
    }

    /* See if any scratch registers have become available that we can use.
     * Scratch registers are cheaper, as they don't need save/restore.
     * All floating point registers are scratch registers, so no need
     * to do this for them.
     */
    if ((I32 || I64) &&                       // not worth the bother for 16 bit code
        !flag &&                              // if haven't already assigned registers in this pass
        (mfuncreg & ~fregsaved) & ALLREGS &&  // if unused non-floating scratch registers
        !(funcsym_p->Sflags & SFLexit))       // don't need save/restore if function never returns
    {
        for (size_t si = 0; si < globsym.top; si++)
        {   symbol *s = globsym.tab[si];

            if (s->Sfl == FLreg &&                // if assigned to register
                mask[s->Sreglsw] & fregsaved &&   // and that register is not scratch
                type_size(s->Stype) <= REGSIZE && // don't bother with register pairs
                !tyfloating(s->ty()))             // don't assign floating regs to non-floating regs
            {
                s->Sreglsw = findreg((mfuncreg & ~fregsaved) & ALLREGS);
                s->Sregm = mask[s->Sreglsw];
                flag = TRUE;
#ifdef DEBUG
                if (debugr)
                    printf("re-assigned '%s' to %s\n",s->Sident,regstring[s->Sreglsw]);
#endif
                break;
            }
        }
    }
    vec_free(v);

    return flag;
}

//////////////////////////////////////
// Qsort() comparison routine for array of pointers to Symbol's.

static int __cdecl weight_compare(const void *e1,const void *e2)
{   Symbol **psp1;
    Symbol **psp2;

    psp1 = (Symbol **)e1;
    psp2 = (Symbol **)e2;

    return (*psp2)->Sweight - (*psp1)->Sweight;
}


#endif
