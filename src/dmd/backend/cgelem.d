/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Does strength reduction optimizations on the elem trees,
 * i.e. rewriting trees to less expensive trees.
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/cgelem.d, backend/cgelem.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_cgelem.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/cgelem.d
 *              Add coverage tests to https://github.com/dlang/dmd/blob/master/test/runnable/testcgelem.d
 */

module dmd.backend.cgelem;

version (SPP)
{
}
else
{

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.code;
import dmd.backend.cdef;
import dmd.backend.code_x86;
import dmd.backend.oper;
import dmd.backend.global;
import dmd.backend.goh;
import dmd.backend.el;
import dmd.backend.outbuf;
import dmd.backend.rtlsym;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.dlist;
import dmd.backend.dvec;

version (SCPP)
    import tk.mem;
else
{
    extern (C)
    {
        nothrow void *mem_calloc(size_t);
    }
}

extern (C++):

nothrow:
@safe:

elem * evalu8(elem *e, goal_t goal);


/* Masks so we can easily check size */
enum CHARMASK  = 0xFF;
enum SHORTMASK = 0xFFFF;
enum INTMASK   = SHORTMASK;
enum LONGMASK  = 0xFFFFFFFF;

/* Common constants often checked for */
enum LLONGMASK = 0xFFFFFFFFFFFFFFFFL;
enum ZEROLL    = 0L;

private __gshared
{
    bool again;
    bool topair;
    tym_t global_tyf;
}

private bool cnst(const elem* e) { return e.Eoper == OPconst; }
int REGSIZE();

version (MARS)
{
    import dmd.backend.errors;
}

/*****************************
 */

@trusted
private elem * cgel_lvalue(elem *e)
{
    //printf("cgel_lvalue()\n"); elem_print(e);
    elem *e1 = e.EV.E1;
    if (e1.Eoper == OPbit)
    {
        elem *e11 = e1.EV.E1;

        if (e11.Eoper == OPcomma)
        {
            // Replace (((e,v) bit x) op e2) with (e,((v bit x) op e2))
            e1.EV.E1 = e11.EV.E2;
            e11.EV.E2 = e;
            e11.Ety = e.Ety;
            e11.ET = e.ET;
            e = e11;
            goto L1;
        }
        else if (OTassign(e11.Eoper))
        {
            // Replace (((e op= v) bit x) op e2) with ((e op= v) , ((e bit x) op e2))
            e1.EV.E1 = el_copytree(e11.EV.E1);
            e = el_bin(OPcomma,e.Ety,e11,e);
            goto L1;
        }
    }
    else if (e1.Eoper == OPcomma)
    {
        // Replace ((e,v) op e2) with (e,(v op e2))
        const op = e.Eoper;
        e.Eoper = OPcomma;
        e1.Eoper = op;
        e1.Ety = e.Ety;
        e1.ET = e.ET;
        e.EV.E1 = e1.EV.E1;
        e1.EV.E1 = e1.EV.E2;
        e1.EV.E2 = e.EV.E2;
        e.EV.E2 = e1;
        goto L1;
    }
    else if (OTassign(e1.Eoper))
    {
        // Replace ((e op= v) op e2) with ((e op= v) , (e op e2))
        e.EV.E1 = el_copytree(e1.EV.E1);
        e = el_bin(OPcomma,e.Ety,e1,e);
    L1:
        e = optelem(e,GOALvalue);
    }
    return e;
}


/******************************
 * Scan down commas.
 */

@trusted
private elem * elscancommas(elem *e)
{
    while (e.Eoper == OPcomma
           || e.Eoper == OPinfo
          )
        e = e.EV.E2;
    return e;
}

/*************************
 * Returns:
 *    true if elem is the constant 1.
 */

int elemisone(elem *e)
{
    if (e.Eoper == OPconst)
    {
        switch (tybasic(e.Ety))
        {
            case TYchar:
            case TYuchar:
            case TYschar:
            case TYchar16:
            case TYshort:
            case TYushort:
            case TYint:
            case TYuint:
            case TYlong:
            case TYulong:
            case TYllong:
            case TYullong:
            case TYnullptr:
            case TYsptr:
            case TYcptr:
            case TYhptr:
            case TYfptr:
            case TYvptr:
            case TYnptr:
            case TYimmutPtr:
            case TYsharePtr:
            case TYrestrictPtr:
            case TYfgPtr:
            case TYbool:
            case TYwchar_t:
            case TYdchar:
                if (el_tolong(e) != 1)
                    goto nomatch;
                break;
            case TYldouble:
            case TYildouble:
                if (e.EV.Vldouble != 1)
                    goto nomatch;
                break;
            case TYdouble:
            case TYidouble:
            case TYdouble_alias:
                if (e.EV.Vdouble != 1)
                        goto nomatch;
                break;
            case TYfloat:
            case TYifloat:
                if (e.EV.Vfloat != 1)
                        goto nomatch;
                break;
            default:
                goto nomatch;
        }
        return true;
    }

nomatch:
    return false;
}

/*************************
 * Returns: true if elem is the constant -1.
 */

int elemisnegone(elem *e)
{
    if (e.Eoper == OPconst)
    {
        switch (tybasic(e.Ety))
        {
            case TYchar:
            case TYuchar:
            case TYschar:
            case TYchar16:
            case TYshort:
            case TYushort:
            case TYint:
            case TYuint:
            case TYlong:
            case TYulong:
            case TYllong:
            case TYullong:
            case TYnullptr:
            case TYnptr:
            case TYsptr:
            case TYcptr:
            case TYhptr:
            case TYfptr:
            case TYvptr:
            case TYimmutPtr:
            case TYsharePtr:
            case TYrestrictPtr:
            case TYfgPtr:
            case TYbool:
            case TYwchar_t:
            case TYdchar:
                if (el_tolong(e) != -1)
                    goto nomatch;
                break;
            case TYldouble:
            //case TYildouble:
                if (e.EV.Vldouble != -1)
                    goto nomatch;
                break;
            case TYdouble:
            //case TYidouble:
            case TYdouble_alias:
                if (e.EV.Vdouble != -1)
                        goto nomatch;
                break;
            case TYfloat:
            //case TYifloat:
                if (e.EV.Vfloat != -1)
                        goto nomatch;
                break;
            default:
                goto nomatch;
        }
        return true;
    }

nomatch:
    return false;
}

/**********************************
 * Swap relational operators (like if we swapped the leaves).
 */

OPER swaprel(OPER op)
{
    assert(op < OPMAX);
    if (OTrel(op))
        op = rel_swap(op);
    return op;
}

/**************************
 * Replace e1 by t=e1, replace e2 by t.
 */

private void fixside(elem **pe1,elem **pe2)
{
    const tym = (*pe1).Ety;
    elem *tmp = el_alloctmp(tym);
    *pe1 = el_bin(OPeq,tym,tmp,*pe1);
    elem *e2 = el_copytree(tmp);
    el_free(*pe2);
    *pe2 = e2;
}



/****************************
 * Compute the 'cost' of evaluating a elem. Could be done
 * as Sethi-Ullman numbers, but that ain't worth the bother.
 * We'll fake it.
 */

private int cost(const elem* n) { return opcost[n.Eoper]; }

/*******************************
 * For floating point expressions, the cost would be the number
 * of registers in the FPU stack needed.
 */

@trusted
private int fcost(const elem *e)
{
    int cost;

    //printf("fcost()\n");
    switch (e.Eoper)
    {
        case OPadd:
        case OPmin:
        case OPmul:
        case OPdiv:
        {
            const int cost1 = fcost(e.EV.E1);
            const int cost2 = fcost(e.EV.E2);
            cost = cost2 + 1;
            if (cost1 > cost)
                cost = cost1;
            break;
        }

        case OPcall:
        case OPucall:
            cost = 8;
            break;

        case OPneg:
        case OPabs:
        case OPtoprec:
            return fcost(e.EV.E1);

        case OPvar:
        case OPconst:
        case OPind:
        default:
            return 1;
    }
    if (cost > 8)
        cost = 8;
    return cost;
}

/*******************************
 * The lvalue of an op= is a conversion operator. Since the code
 * generator cannot handle this, we will have to fix it here. The
 * general strategy is:
 *      (conv) e1 op= e2        =>      e1 = (conv) e1 op e2
 * Since e1 can only be evaluated once, if it is an expression we
 * must use a temporary.
 */

@trusted
private elem *fixconvop(elem *e)
{
    static immutable ubyte[CNVOPMAX - CNVOPMIN + 1] invconvtab =
    [
        OPbool,         // OPb_8
        OPs32_d,        // OPd_s32
        OPd_s32,        // OPs32_d
        OPs16_d,        /* OPd_s16      */
        OPd_s16,        /* OPs16_d      */
        OPu16_d,        // OPd_u16
        OPd_u16,        // OPu16_d
        OPu32_d,        /* OPd_u32      */
        OPd_u32,        /* OPu32_d      */
        OPs64_d,        // OPd_s64
        OPd_s64,        // OPs64_d
        OPu64_d,        // OPd_u64
        OPd_u64,        // OPu64_d
        OPf_d,          // OPd_f
        OPd_f,          // OPf_d
        OP32_16,        // OPs16_32
        OP32_16,        // OPu16_32
        OPs16_32,       // OP32_16
        OP16_8,         // OPu8_16
        OP16_8,         // OPs8_16
        OPs8_16,        // OP16_8
        OP64_32,        // OPu32_64
        OP64_32,        // OPs32_64
        OPs32_64,       // OP64_32
        OP128_64,       // OPu64_128
        OP128_64,       // OPs64_128
        OPs64_128,      // OP128_64

        0,              /* OPvp_fp      */
        0,              /* OPcvp_fp     */
        OPnp_fp,        /* OPoffset     */
        OPoffset,       /* OPnp_fp      */
        OPf16p_np,      /* OPnp_f16p    */
        OPnp_f16p,      /* OPf16p_np    */

        OPd_ld,         // OPld_d
        OPld_d,         // OPd_ld
        OPu64_d,        // OPld_u64
    ];

    //printf("fixconvop before\n");
    //elem_print(e);
    assert(invconvtab.length == CNVOPMAX - CNVOPMIN + 1);
    assert(e);
    tym_t tyme = e.Ety;
    const cop = e.EV.E1.Eoper;             /* the conversion operator      */
    assert(cop <= CNVOPMAX);

    elem *econv = e.EV.E1;
    while (OTconv(econv.Eoper))
    {
        if (econv.EV.E1.Eoper != OPcomma)
        {
            econv = econv.EV.E1;
            continue;
        }
        /* conv(a,b) op= e2     or     conv(conv(a,b)) op= e2
         *   =>                 many:    =>
         * a, (conv(b) op= e2)         a, (conv(conv(b)) op= e2)
         */
        elem *ecomma = econv.EV.E1;
        econv.EV.E1 = ecomma.EV.E2;
        econv.EV.E1.Ety = ecomma.Ety;
        ecomma.EV.E2 = e;
        ecomma.Ety = e.Ety;
        //printf("fixconvop comma\n");
        //elem_print(ecomma);
        return optelem(ecomma, GOALvalue);
    }

    if (e.EV.E1.Eoper == OPd_f && OTconv(e.EV.E1.EV.E1.Eoper) && tyintegral(tyme))
    {
        elem *e1 = e.EV.E1;
        e.EV.E1 = e1.EV.E1;
        e.EV.E2 = el_una(OPf_d, e.EV.E1.Ety, e.EV.E2);
        e1.EV.E1 = null;
        el_free(e1);
        return fixconvop(e);
    }

    tym_t tycop = e.EV.E1.Ety;
    tym_t tym = e.EV.E1.EV.E1.Ety;
    e.EV.E1 = el_selecte1(e.EV.E1);     /* dump it for now              */
    elem *e1 = e.EV.E1;
    e1.Ety = tym;
    elem *e2 = e.EV.E2;
    assert(e1 && e2);
    /* select inverse conversion operator   */
    const icop = invconvtab[convidx(cop)];

    /* First, let's see if we can just throw it away.       */
    /* (unslng or shtlng) e op= e2  => e op= (lngsht) e2    */
    if (OTwid(e.Eoper) &&
            (cop == OPs16_32 || cop == OPu16_32 ||
             cop == OPu8_16 || cop == OPs8_16))
    {   if (e.Eoper != OPshlass && e.Eoper != OPshrass && e.Eoper != OPashrass)
            e.EV.E2 = el_una(icop,tym,e2);
        //printf("after1\n");
        //elem_print(e);
        return e;
    }

    /* Oh well, just split up the op and the =.                     */
    const op = opeqtoop(e.Eoper); // convert op= to op
    e.Eoper = OPeq;                  // just plain =
    elem *ed = el_copytree(e1);       // duplicate e1
                                      // make: e1 = (icop) ((cop) ed op e2)
    e.EV.E2 = el_una(icop,e1.Ety,
                             el_bin(op,tycop,el_una(cop,tycop,ed),
                                                  e2));

    //printf("after1\n");
    //elem_print(e);

    if (op == OPdiv &&
        tybasic(e2.Ety) == TYcdouble)
    {
        if (tycop == TYdouble)
        {
            e.EV.E2.EV.E1.Ety = tybasic(e2.Ety);
            e.EV.E2.EV.E1 = el_una(OPc_r, tycop, e.EV.E2.EV.E1);
        }
        else if (tycop == TYidouble)
        {
            e.EV.E2.EV.E1.Ety = tybasic(e2.Ety);
            e.EV.E2.EV.E1 = el_una(OPc_i, tycop, e.EV.E2.EV.E1);
        }
    }

    if (op == OPdiv &&
        tybasic(e2.Ety) == TYcfloat)
    {
        if (tycop == TYfloat)
        {
            e.EV.E2.EV.E1.Ety = tybasic(e2.Ety);
            e.EV.E2.EV.E1 = el_una(OPc_r, tycop, e.EV.E2.EV.E1);
        }
        else if (tycop == TYifloat)
        {
            e.EV.E2.EV.E1.Ety = tybasic(e2.Ety);
            e.EV.E2.EV.E1 = el_una(OPc_i, tycop, e.EV.E2.EV.E1);
        }
    }

    // Handle case of multiple conversion operators on lvalue
    // (such as (intdbl 8int char += double))
    elem *ex = e;
    elem **pe = &e;
    while (OTconv(ed.Eoper))
    {
        const uint copx = ed.Eoper;
        const uint icopx = invconvtab[convidx(copx)];
        tym_t tymx = ex.EV.E1.EV.E1.Ety;
        ex.EV.E1 = el_selecte1(ex.EV.E1);       // dump it for now
        e1 = ex.EV.E1;
        e1.Ety = tymx;
        ex.EV.E2 = el_una(icopx,e1.Ety,ex.EV.E2);
        ex.Ety = tymx;
        tym = tymx;

        if (ex.Ety != tyme)
        {   *pe = el_una(copx, ed.Ety, ex);
            pe = &(*pe).EV.E1;
        }

        ed = ed.EV.E1;
    }
    //printf("after2\n");
    //elem_print(e);

    e.Ety = tym;
    if (tym != tyme &&
        !(tyintegral(tym) && tyintegral(tyme) && tysize(tym) == tysize(tyme)))
        e = el_una(cop, tyme, e);

    if (ed.Eoper == OPbit)         // special handling
    {
        ed = ed.EV.E1;
        e1 = e1.EV.E1;            // go down one
    }

    /* If we have a *, must assign a temporary to the expression
     * underneath it (even if it's a var, as e2 may modify the var)
     */
    if (ed.Eoper == OPind)
    {
        elem *T = el_alloctmp(ed.EV.E1.Ety);    // make temporary
        ed.EV.E1 = el_bin(OPeq,T.Ety,T,ed.EV.E1); // ed: *(T=e)
        el_free(e1.EV.E1);
        e1.EV.E1 = el_copytree(T);
    }
    //printf("after3\n");
    //elem_print(e);
    return e;
}

private elem * elerr(elem *e, goal_t goal)
{
    debug elem_print(e);
    assert(0);
}

/* For ops with no optimizations */

private elem * elzot(elem *e, goal_t goal)
{
    return e;
}

/****************************
 */

private elem * elstring(elem *e, goal_t goal)
{
    return e;
}

/************************
 */

/************************
 * Convert far pointer to pointer.
 */

@trusted
private void eltonear(elem **pe)
{
    elem *e = *pe;
    const tym_t ty = e.EV.E1.Ety;
    e = el_selecte1(e);
    e.Ety = ty;
    *pe = optelem(e,GOALvalue);
}

/************************
 */

@trusted
private elem * elstrcpy(elem *e, goal_t goal)
{
    elem_debug(e);
    switch (e.EV.E2.Eoper)
    {
        case OPnp_fp:
            if (OPTIMIZER)
            {
                eltonear(&e.EV.E2);
                e = optelem(e,GOALvalue);
            }
            break;

        case OPstring:
            /* Replace strcpy(e1,"string") with memcpy(e1,"string",sizeof("string")) */
            // As streq
            e.Eoper = OPstreq;
            type *t = type_allocn(TYarray, tstypes[TYchar]);
            t.Tdim = strlen(e.EV.E2.EV.Vstring) + 1;
            e.ET = t;
            t.Tcount++;
            e.EV.E1 = el_una(OPind,TYstruct,e.EV.E1);
            e.EV.E2 = el_una(OPind,TYstruct,e.EV.E2);

            e = el_bin(OPcomma,e.Ety,e,el_copytree(e.EV.E1.EV.E1));
            if (el_sideeffect(e.EV.E2))
                fixside(&e.EV.E1.EV.E1.EV.E1,&e.EV.E2);
            e = optelem(e,GOALvalue);
            break;

        default:
            break;
    }
    return e;
}

/************************
 */

@trusted
private elem * elstrcmp(elem *e, goal_t goal)
{
    elem_debug(e);
    if (OPTIMIZER)
    {
        if (e.EV.E1.Eoper == OPnp_fp)
            eltonear(&e.EV.E1);
        switch (e.EV.E2.Eoper)
        {
            case OPnp_fp:
                eltonear(&e.EV.E2);
                break;

            case OPstring:
                // Replace strcmp(e1,"string") with memcmp(e1,"string",sizeof("string"))
                e.Eoper = OPparam;
                e = el_bin(OPmemcmp,e.Ety,e,el_long(TYint,strlen(e.EV.E2.EV.Vstring) + 1));
                e = optelem(e,GOALvalue);
                break;

            default:
                break;
        }
    }
    return e;
}

/****************************
 * For OPmemcmp
 * memcmp(a, b, nbytes) => ((a param b) OPmemcmp nbytes)
 */
@trusted

private elem * elmemcmp(elem *e, goal_t goal)
{
    elem_debug(e);
    if (!OPTIMIZER)
        return e;

    /* Hoist comma operators in `a` out of OPmemcmp
     */
    {
        elem* ec = e.EV.E1.EV.E1;
        if (ec.Eoper == OPcomma)
        {
            /* Rewrite: (((a,b) param c) OPmemcmp nbytes)
             * As: a,((b param c) OPmemcmp nbytes)
             */
            e.EV.E1.EV.E1 = ec.EV.E2;
            e.EV.E1.EV.E1.Ety = ec.Ety;
            e.EV.E1.EV.E1.ET = ec.ET;
            ec.EV.E2 = e;
            ec.Ety = e.Ety;
            return optelem(ec, goal);
        }
    }

    /* Hoist comma operators in `b` out of OPmemcmp
     */
    {
        elem* ec = e.EV.E1.EV.E2;
        if (ec.Eoper == OPcomma)
        {
            /* Have: ((a param (b,c)) OPmemcmp nbytes)
             */
            elem* a = e.EV.E1.EV.E1;
            elem* b = ec.EV.E1;
            if (a.canHappenAfter(b))
            {
                /* Rewrite: ((a param (b,c)) OPmemcmp nbytes)
                 * As: b,((a param c) OPmemcmp nbytes)
                 */
                e.EV.E1.EV.E2 = ec.EV.E2;
                e.EV.E1.EV.E2.Ety = ec.Ety;
                e.EV.E1.EV.E2.ET = ec.ET;
                ec.EV.E2 = e;
                ec.Ety = e.Ety;
                return optelem(ec, goal);
            }
        }
    }

    elem *ex = e.EV.E1;
    if (ex.EV.E1.Eoper == OPnp_fp)
        eltonear(&ex.EV.E1);
    if (ex.EV.E2.Eoper == OPnp_fp)
        eltonear(&ex.EV.E2);

    return e;
}

/****************************
 * For OPmemset
 */

@trusted
private elem * elmemset(elem *e, goal_t goal)
{
    elem_debug(e);
    if (OPTIMIZER)
    {
        elem *ex = e.EV.E1;
        if (ex.Eoper == OPnp_fp)
            eltonear(&ex);
        else
        {
            // lvalue OPmemset (nbytes param value)
            elem *enbytes = e.EV.E2.EV.E1;
            elem *evalue = e.EV.E2.EV.E2;

            version (MARS)
            if (enbytes.Eoper == OPconst && evalue.Eoper == OPconst)
            {
                int nbytes = cast(int)el_tolong(enbytes);
                targ_llong value = el_tolong(evalue);
                elem *e1 = e.EV.E1;

                if (e1.Eoper == OPcomma || OTassign(e1.Eoper))
                    return cgel_lvalue(e);    // replace (e,v)op=e2 with e,(v op= e2)

                tym_t tym;
                switch (nbytes)
                {
                    case CHARSIZE:      tym = TYchar;   goto L1;
                    case SHORTSIZE:     tym = TYshort;  goto L1;
                    case LONGSIZE:      tym = TYlong;   goto L1;
                    case LLONGSIZE:     if (_tysize[TYint] == 2)
                                            goto Ldefault;
                                        tym = TYllong;  goto L1;
                    L1:
                    {
                        tym_t ety = e.Ety;
                        memset(&value, value & 0xFF, value.sizeof);
                        evalue.EV.Vullong = value;
                        evalue.Ety = tym;
                        e.Eoper = OPeq;
                        e.Ety = (e.Ety & ~mTYbasic) | tym;
                        if (tybasic(e1.Ety) == TYstruct)
                            e1.Ety = tym;
                        else
                            e.EV.E1 = el_una(OPind, tym, e1);
                        elem *tmp = el_same(&e.EV.E1);
                        tmp = el_una(OPaddr, ety, tmp);
                        e.EV.E2.Ety = tym;
                        e.EV.E2 = el_selecte2(e.EV.E2);
                        e = el_combine(e, tmp);
                        e = optelem(e,GOALvalue);
                        break;
                    }

                    default:
                    Ldefault:
                        break;
                }
            }
        }
    }
    return e;
}


/****************************
 * For OPmemcpy
 *  OPmemcpy
 *   /   \
 * s1   OPparam
 *       /   \
 *      s2    n
 */

@trusted
private elem * elmemcpy(elem *e, goal_t goal)
{
    elem_debug(e);
    if (OPTIMIZER)
    {
        elem *ex = e.EV.E1;
        if (ex.Eoper == OPnp_fp)
            eltonear(&e.EV.E1);
        ex = e.EV.E2;
        if (ex.EV.E1.Eoper == OPnp_fp)
            eltonear(&ex.EV.E1);
        if (ex.EV.E2.Eoper == OPconst)
        {
            if (!boolres(ex.EV.E2))
            {   // Copying 0 bytes, so remove memcpy
                e.EV.E2 = e.EV.E1;
                e.EV.E1 = ex.EV.E1;
                ex.EV.E1 = null;
                e.Eoper = OPcomma;
                el_free(ex);
                return optelem(e, GOALvalue);
            }
            // Convert OPmemcpy to OPstreq
            e.Eoper = OPstreq;
            type *t = type_allocn(TYarray, tstypes[TYchar]);
            t.Tdim = cast(uint)el_tolong(ex.EV.E2);
            e.ET = t;
            t.Tcount++;
            e.EV.E1 = el_una(OPind,TYstruct,e.EV.E1);
            e.EV.E2 = el_una(OPind,TYstruct,ex.EV.E1);
            ex.EV.E1 = null;
            el_free(ex);
            ex = el_copytree(e.EV.E1.EV.E1);
            if (tysize(e.Ety) > tysize(ex.Ety))
                ex = el_una(OPnp_fp,e.Ety,ex);
            e = el_bin(OPcomma,e.Ety,e,ex);
            if (el_sideeffect(e.EV.E2))
                fixside(&e.EV.E1.EV.E1.EV.E1,&e.EV.E2);
            return optelem(e,GOALvalue);
        }

        /+ The following fails the autotester for Linux32 and FreeBSD32
         + for unknown reasons I cannot reproduce
        // Convert to memcpy(s1, s2, n)
        elem* ep = el_params(e.EV.E2.EV.E2, e.EV.E2.EV.E1, e.EV.E1, null);
        const ty = e.Ety;
        e.EV.E1 = null;
        e.EV.E2.EV.E1 = null;
        e.EV.E2.EV.E2 = null;
        el_free(e);
        e = el_bin(OPcall, ty, el_var(getRtlsym(RTLSYM_MEMCPY)), ep);
         +/
    }
    return e;
}


/***********************
 *        +             #       (combine offsets with addresses)
 *       / \    =>      |
 *      #   c          v,c
 *      |
 *      v
 */

@trusted
private elem * eladd(elem *e, goal_t goal)
{
    //printf("eladd(%p)\n",e);
    targ_size_t ptrmask = ~cast(targ_size_t)0;
    if (_tysize[TYnptr] <= 4)
        ptrmask = 0xFFFFFFFF;
L1:
    elem *e1 = e.EV.E1;
    elem *e2 = e.EV.E2;
    if (e2.Eoper == OPconst)
    {
        if (e1.Eoper == OPrelconst && e1.EV.Vsym.Sfl == FLgot)
            return e;
        if (e1.Eoper == OPrelconst ||          // if (&v) + c
            e1.Eoper == OPstring)
        {
            e1.EV.Voffset += e2.EV.Vpointer;
            e1.EV.Voffset &= ptrmask;
            e = el_selecte1(e);
            return e;
        }
    }
    else if (e1.Eoper == OPconst)
    {
        if (e2.Eoper == OPrelconst && e2.EV.Vsym.Sfl == FLgot)
            return e;
        if (e2.Eoper == OPrelconst ||          // if c + (&v)
            e2.Eoper == OPstring)
        {
            e2.EV.Voffset += e1.EV.Vpointer;
            e2.EV.Voffset &= ptrmask;
            e = el_selecte2(e);
            return e;
        }
    }

    if (!OPTIMIZER)
        return e;

    // Replace ((e + &v) + c) with (e + (&v+c))
    if (e2.Eoper == OPconst && e1.Eoper == OPadd &&
       (e1.EV.E2.Eoper == OPrelconst || e1.EV.E2.Eoper == OPstring))
    {
        e1.EV.E2.EV.Voffset += e2.EV.Vpointer;
        e1.EV.E2.EV.Voffset &= ptrmask;
        e = el_selecte1(e);
        goto L1;
    }
    // Replace ((e + c) + &v) with (e + (&v+c))
    else if ((e2.Eoper == OPrelconst || e2.Eoper == OPstring) &&
             e1.Eoper == OPadd && cnst(e1.EV.E2))
    {
        e2.EV.Voffset += e1.EV.E2.EV.Vpointer;
        e2.EV.Voffset &= ptrmask;
        e.EV.E1 = el_selecte1(e1);
        goto L1;                        /* try and find some more       */
    }
    // Replace (e1 + -e) with (e1 - e)
    else if (e2.Eoper == OPneg)
    {
        e.EV.E2 = el_selecte1(e2);
        e.Eoper = OPmin;
        again = 1;
        return e;
    }
    // Replace (-v + e) with (e + -v)
    else if (e1.Eoper == OPneg && OTleaf(e1.EV.E1.Eoper))
    {
        e.EV.E1 = e2;
        e.EV.E2 = e1;                     /* swap leaves                  */
        goto L1;
    }
    /* Replace ((e - e2) + e2) with (e)
     * The optimizer sometimes generates this case
     */
    else if (!tyfloating(e.Ety) &&       /* no floating bugs             */
        e1.Eoper == OPmin &&
        el_match(e1.EV.E2,e2) &&
        !el_sideeffect(e2))
    {
        tym_t tym = e.Ety;
        e = el_selecte1(el_selecte1(e));
        e.Ety = tym;                   /* retain original type         */
        return e;
    }
    // Replace ((e - #v+c1) + #v+c2) with ((e - c1) + c2)
    else if (e2.Eoper == OPrelconst &&
           e1.Eoper == OPmin &&
           e1.EV.E2.Eoper == OPrelconst &&
           e1.EV.E2.EV.Vsym == e2.EV.Vsym)
    {
        e2.Eoper = OPconst;
        e2.Ety = TYint;
        e1.Ety = e1.EV.E1.Ety;
        e1.EV.E2.Eoper = OPconst;
        e1.EV.E2.Ety = TYint;
        {
            /* Watch out for pointer types changing, requiring a conversion */
            tym_t ety = tybasic(e.Ety);
            tym_t e11ty = tybasic(e1.EV.E1.Ety);
            if (typtr(ety) && typtr(e11ty) &&
                _tysize[ety] != _tysize[e11ty])
            {
                e = el_una((_tysize[ety] > _tysize[e11ty]) ? OPnp_fp : OPoffset,
                            e.Ety,e);
                e.EV.E1.Ety = e1.Ety;
            }
        }
        again = 1;
        return e;
    }
    // Replace (e + e) with (e * 2)
    else if (el_match(e1,e2) && !el_sideeffect(e1) && !tyfloating(e1.Ety) &&
        !tyvector(e1.Ety))      // not all CPUs support XMM multiply
    {
        e.Eoper = OPmul;
        el_free(e2);
        e.EV.E2 = el_long(e1.Ety,2);
        again = 1;
        return e;
    }

    // Replace ((e11 + c) + e2) with ((e11 + e2) + c)
    if (e1.Eoper == OPadd && e1.EV.E2.Eoper == OPconst &&
        (e2.Eoper == OPvar || !OTleaf(e2.Eoper)) &&
        tysize(e1.Ety) == tysize(e2.Ety) &&
        tysize(e1.EV.E2.Ety) == tysize(e2.Ety))
    {
        e.EV.E2 = e1.EV.E2;
        e1.EV.E2 = e2;
        e1.Ety = e.Ety;
        return e;
    }

    // Replace (~e1 + 1) with (-e1)
    if (e1.Eoper == OPcom && e2.Eoper == OPconst && el_tolong(e2) == 1)
    {
        e = el_selecte1(e);
        e.Eoper = OPneg;
        e = optelem(e, goal);
        return e;
    }

    // Replace ((e11 - e12) + e2) with ((e11 + e2) - e12)
    // (this should increase the number of LEA possibilities)
    int sz = tysize(e.Ety);
    if (e1.Eoper == OPmin &&
        tysize(e1.Ety) == sz &&
        tysize(e2.Ety) == sz &&
        tysize(e1.EV.E1.Ety) == sz &&
        tysize(e1.EV.E2.Ety) == sz &&
        !tyfloating(e.Ety)
       )
    {
        e.Eoper = OPmin;
        e.EV.E2 = e1.EV.E2;
        e1.EV.E2 = e2;
        e1.Eoper = OPadd;
    }

    return e;
}


/************************
 * Multiply (for OPmul && OPmulass)
 *      e * (c**2) => e << c    ;replace multiply by power of 2 with shift
 */

@trusted
private elem * elmul(elem *e, goal_t goal)
{
    tym_t tym = e.Ety;

    if (OPTIMIZER)
    {
        // Replace -a*-b with a*b.
        // This is valid for all floating point types as well as integers.
        if (tyarithmetic(tym) && e.EV.E2.Eoper == OPneg && e.EV.E1.Eoper == OPneg)
        {
            e.EV.E1 = el_selecte1(e.EV.E1);
            e.EV.E2 = el_selecte1(e.EV.E2);
        }
    }

    elem *e2 = e.EV.E2;
    if (e2.Eoper == OPconst)           // try to replace multiplies with shifts
    {
        if (OPTIMIZER)
        {
            elem *e1 = e.EV.E1;
            uint op1 = e1.Eoper;

            if (tyintegral(tym) &&              // skip floating types
                OTbinary(op1) &&
                e1.EV.E2.Eoper == OPconst
               )
            {
                /* Attempt to replace ((e + c1) * c2) with (e * c2 + (c1 * c2))
                 * because the + can be frequently folded out (merged into an
                 * array offset, for example.
                 */
                if (op1 == OPadd)
                {
                    e.Eoper = OPadd;
                    e1.Eoper = OPmul;
                    e.EV.E2 = el_bin(OPmul,tym,e1.EV.E2,e2);
                    e1.EV.E2 = el_copytree(e2);
                    again = 1;
                    return e;
                }

                // ((e << c1) * c2) => e * ((1 << c1) * c2)
                if (op1 == OPshl)
                {
                    e2.EV.Vullong *= cast(targ_ullong)1 << el_tolong(e1.EV.E2);
                    e1.EV.E2.EV.Vullong = 0;
                    again = 1;
                    return e;
                }
            }

            if (elemisnegone(e2))
            {
                e.Eoper = (e.Eoper == OPmul) ? OPneg : OPnegass;
                e.EV.E2 = null;
                el_free(e2);
                return e;
            }
        }

        if (tyintegral(tym) && !tyvector(tym))
        {
            int i = ispow2(el_tolong(e2));      // check for power of 2
            if (i != -1)                        // if it is a power of 2
            {   e2.EV.Vint = i;
                e2.Ety = TYint;
                e.Eoper = (e.Eoper == OPmul)  /* convert to shift left */
                        ? OPshl : OPshlass;
                again = 1;
                return e;
            }
            else if (el_allbits(e2,-1))
                goto Lneg;
        }
        else if (elemisnegone(e2) && !tycomplex(e.EV.E1.Ety))
        {
            goto Lneg;
        }
    }
    return e;

Lneg:
    e.Eoper = (e.Eoper == OPmul)      /* convert to negate */
            ? OPneg : OPnegass;
    el_free(e.EV.E2);
    e.EV.E2 = null;
    again = 1;
    return e;
}

/************************
 * Subtract
 *        -               +
 *       / \    =>       / \            (propagate minuses)
 *      e   c           e   -c
 */

@trusted
private elem * elmin(elem *e, goal_t goal)
{
    elem *e2 = e.EV.E2;

    if (OPTIMIZER)
    {
        tym_t tym = e.Ety;
        elem *e1 = e.EV.E1;
        if (e2.Eoper == OPrelconst)
        {
            if (e1.Eoper == OPrelconst && e1.EV.Vsym == e2.EV.Vsym)
            {
                e.Eoper = OPconst;
                e.EV.Vllong = e1.EV.Voffset - e2.EV.Voffset;
                el_free(e1);
                el_free(e2);
                return e;
            }
        }

        // Convert subtraction of long pointers to subtraction of integers
        if (tyfv(e2.Ety) && tyfv(e1.Ety))
        {
            e.EV.E1 = el_una(OP32_16,tym,e1);
            e.EV.E2 = el_una(OP32_16,tym,e2);
            return optelem(e,GOALvalue);
        }

        // Replace (0 - e2) with (-e2)
        if (cnst(e1) && !boolres(e1) &&
            !(tycomplex(tym) && !tycomplex(e1.Ety) && !tycomplex(e2.Ety)) &&
            !tyvector(e1.Ety)
           )
        {
            e.EV.E1 = e2;
            e.EV.E2 = null;
            e.Eoper = OPneg;
            el_free(e1);
            return optelem(e,GOALvalue);
        }

        // Replace (e - e) with (0)
        if (el_match(e1,e2) && !el_sideeffect(e1))
        {
            el_free(e);
            e = el_calloc();
            e.Eoper = OPconst;
            e.Ety = tym;
            return e;
        }

        // Replace ((e1 + c) - e2) with ((e1 - e2) + c), but not
        // for floating or far or huge pointers!
        if (e1.Eoper == OPadd &&
            cnst(e1.EV.E2) &&
            (tyintegral(tym) ||
             tybasic(tym) == TYnptr ||
             tybasic(tym) == TYsptr ||
             tybasic(tym) == TYfgPtr ||
             tybasic(tym) == TYimmutPtr ||
             tybasic(tym) == TYrestrictPtr ||
             tybasic(tym) == TYsharePtr)
           )
        {
            e.Eoper = OPadd;
            e1.Eoper = OPmin;
            elem* c = e1.EV.E2;
            e1.EV.E2 = e2;
            e.EV.E2 = c;
            return optelem(e,GOALvalue);
        }

        // Replace (e1 + c1) - (e2 + c2) with (e1 - e2) + (c1 - c2), but not
        // for floating or far or huge pointers!
        if (e1.Eoper == OPadd && e2.Eoper == OPadd &&
            cnst(e1.EV.E2) && cnst(e2.EV.E2) &&
            (tyintegral(tym) ||
             tybasic(tym) == TYnptr ||
             tybasic(tym) == TYsptr ||
             tybasic(tym) == TYfgPtr ||
             tybasic(tym) == TYimmutPtr ||
             tybasic(tym) == TYrestrictPtr ||
             tybasic(tym) == TYsharePtr)
           )
        {
            e.Eoper = OPadd;
            e1.Eoper = OPmin;
            e2.Eoper = OPmin;
            elem *tmp = e1.EV.E2;
            e1.EV.E2 = e2.EV.E1;
            e2.EV.E1 = tmp;
            return optelem(e,GOALvalue);
        }

        // Replace (-e1 - 1) with (~e1)
        if (e1.Eoper == OPneg && e2.Eoper == OPconst && tyintegral(tym) && el_tolong(e2) == 1)
        {
            e = el_selecte1(e);
            e.Eoper = OPcom;
            e = optelem(e, goal);
            return e;
        }

        // Replace (-1 - e2) with (~e2)
        if (e1.Eoper == OPconst && tyintegral(tym) && !tyvector(tym) && el_tolong(e1) == -1)
        {
            el_free(e1);
            e.EV.E1 = e.EV.E2;
            e.EV.E2 = null;
            e.Eoper = OPcom;
            e = optelem(e, goal);
            return e;
        }

        /* Replace e1 - (v * c) with e1 + (v * -c)
         */
        if (e2.Eoper == OPmul &&
            e2.EV.E2.Eoper == OPconst)
        {
            e.Eoper = OPadd;
            e2.EV.E2 = el_una(OPneg, e2.EV.E2.Ety, e2.EV.E2);
            return optelem(e, goal);
        }
    }

    if (I16 && tybasic(e2.Ety) == TYhptr && tybasic(e.EV.E1.Ety) == TYhptr)
    {   // Convert to _aNahdiff(e1,e2)
        __gshared Symbol *hdiff;
        if (!hdiff)
        {
            Symbol *s = symbol_calloc(LARGECODE ? "_aFahdiff".ptr : "_aNahdiff".ptr);
            s.Stype = tsclib;
            s.Sclass = SCextern;
            s.Sfl = FLfunc;
            s.Ssymnum = 0;
            s.Sregsaved = mBX|mCX|mSI|mDI|mBP|mES;
            hdiff = s;
        }
        e.Eoper = OPcall;
        e.EV.E2 = el_bin(OPparam,TYint,e2,e.EV.E1);
        e.EV.E1 = el_var(hdiff);
        return e;
    }

    /* Disallow the optimization on doubles. The - operator is not
     * rearrangable by K+R, and can cause floating point problems if
     * converted to an add ((a + 1.0) - 1.0 shouldn't be folded).
     */
    if (cnst(e2) && !tyfloating(e2.Ety) &&
        !tyvector(e2.Ety)) // don't do vectors until we get constant folding for them
    {
        e.EV.E2 = el_una(OPneg,e2.Ety,e2);
        e.Eoper = OPadd;
        return optelem(e,GOALvalue);
    }
    return e;
}

/*****************************
 * OPand,OPor,OPxor
 * This should be expanded to include long type stuff.
 */

@trusted
private elem * elbitwise(elem *e, goal_t goal)
{
    //printf("elbitwise(e = %p, goal = x%x)\n", e, goal);

    elem *e2 = e.EV.E2;
    elem *e1 = e.EV.E1;
    const op = e1.Eoper;
    uint sz = tysize(e2.Ety);

    if (e2.Eoper == OPconst)
    {
        switch (sz)
        {
            case CHARSIZE:
                /* Replace (c & 0xFF) with (c)  */
                if (OPTIMIZER && e2.EV.Vuchar == CHARMASK)
                {
                L1:
                    switch (e.Eoper)
                    {   case OPand:     /* (c & 0xFF) => (c)    */
                            return el_selecte1(e);
                        case OPor:      /* (c | 0xFF) => (0xFF) */
                            return el_selecte2(e);
                        case OPxor:     /* (c ^ 0xFF) => (~c)   */
                            return el_una(OPcom,e.Ety,el_selecte1(e));
                        default:
                            assert(0);
                    }
                }
                break;

            case LONGSIZE:
            {
                if (!OPTIMIZER)
                    break;
                targ_ulong ul = e2.EV.Vulong;

                if (ul == 0xFFFFFFFF)           /* if e1 & 0xFFFFFFFF   */
                    goto L1;
                /* (x >> 16) & 0xFFFF => (cast(uint)x >> 16)       */
                if (ul == 0xFFFF && e.Eoper == OPand && (op == OPshr || op == OPashr) &&
                    e1.EV.E2.Eoper == OPconst && el_tolong(e1.EV.E2) == 16)
                {
                    elem *e11 = e1.EV.E1;
                    e11.Ety = touns(e11.Ety) | (e11.Ety & ~mTYbasic);
                    goto L1;
                }

                /* Replace (L & 0x0000XXXX) with (unslng)((lngsht) & 0xXXXX) */
                if (_tysize[TYint] < LONGSIZE &&
                    e.Eoper == OPand &&
                    ul <= SHORTMASK)
                {
                    tym_t tym = e.Ety;
                    e.EV.E1 = el_una(OP32_16,TYushort,e.EV.E1);
                    e.EV.E2 = el_una(OP32_16,TYushort,e.EV.E2);
                    e.Ety = TYushort;
                    e = el_una(OPu16_32,tym,e);
                    goto Lopt;
                }

                // Replace ((s8sht)L & 0xFF) with (u8sht)L
                if (ul == 0xFF && _tysize[TYint] == LONGSIZE && e.Eoper == OPand &&
                    (op == OPs8_16 || op == OPu8_16)
                   )
                {
                    e1.Eoper = OPu8_16;
                    e = el_selecte1(e);
                    goto Lopt;
                }
                break;
            }

            case SHORTSIZE:
            {
                targ_short i = e2.EV.Vshort;
                if (i == cast(targ_short)SHORTMASK) // e2 & 0xFFFF
                    goto L1;

                /* (x >> 8) & 0xFF => ((uint short)x >> 8)          */
                if (OPTIMIZER && i == 0xFF && e.Eoper == OPand &&
                    (op == OPshr || op == OPashr) && e1.EV.E2.Eoper == OPconst && e1.EV.E2.EV.Vint == 8)
                {
                    elem *e11 = e1.EV.E1;
                    e11.Ety = touns(e11.Ety) | (e11.Ety & ~mTYbasic);
                    goto L1;
                }

                // (s8_16(e) & 0xFF) => u8_16(e)
                if (OPTIMIZER && op == OPs8_16 && e.Eoper == OPand &&
                    i == 0xFF)
                {
                    e1.Eoper = OPu8_16;
                    e = el_selecte1(e);
                    goto Lopt;
                }

                if (
                    /* OK for uint if AND or high bits of i are 0   */
                    op == OPu8_16 && (e.Eoper == OPand || !(i & ~0xFF)) ||
                    /* OK for signed if i is 'sign-extended'    */
                    op == OPs8_16 && cast(targ_short)cast(targ_schar)i == i
                   )
                {
                    /* Convert ((u8int) e) & i) to (u8int)(e & (int8) i) */
                    /* or similar for s8int                              */
                    e = el_una(e1.Eoper,e.Ety,e);
                    e.EV.E1.Ety = e1.Ety = e1.EV.E1.Ety;
                    e.EV.E1.EV.E1 = el_selecte1(e1);
                    e.EV.E1.EV.E2 = el_una(OP16_8,e.EV.E1.Ety,e.EV.E1.EV.E2);
                    goto Lopt;
                }
                break;
            }

            case LLONGSIZE:
                if (OPTIMIZER)
                {
                    if (e2.EV.Vullong == LLONGMASK)
                        goto L1;
                }
                break;

            default:
                break;
        }
        if (OPTIMIZER && sz < 16)
        {
            targ_ullong ul = el_tolong(e2);

            if (e.Eoper == OPor && op == OPand && e1.EV.E2.Eoper == OPconst)
            {
                // ((x & c1) | c2) => (x | c2)
                targ_ullong c3;

                c3 = ul | e1.EV.E2.EV.Vullong;
                switch (sz)
                {
                    case CHARSIZE:
                        if ((c3 & CHARMASK) == CHARMASK)
                            goto L2;
                        break;

                    case SHORTSIZE:
                        if ((c3 & SHORTMASK) == SHORTMASK)
                            goto L2;
                        break;

                    case LONGSIZE:
                        if ((c3 & LONGMASK) == LONGMASK)
                        {
                        L2:
                            e1.EV.E2.EV.Vullong = c3;
                            e.EV.E1 = elbitwise(e1, GOALvalue);
                            goto Lopt;
                        }
                        break;

                    case LLONGSIZE:
                        if ((c3 & LLONGMASK) == LLONGMASK)
                            goto L2;
                        break;

                    default:
                        assert(0);
                }
            }

            if (op == OPs16_32 && (ul & 0xFFFFFFFFFFFF8000L) == 0 ||
                op == OPu16_32 && (ul & 0xFFFFFFFFFFFF0000L) == 0 ||
                op == OPs8_16  && (ul & 0xFFFFFFFFFFFFFF80L) == 0 ||
                op == OPu8_16  && (ul & 0xFFFFFFFFFFFFFF00L) == 0 ||
                op == OPs32_64 && (ul & 0xFFFFFFFF80000000L) == 0 ||
                op == OPu32_64 && (ul & 0xFFFFFFFF00000000L) == 0
               )
            {
                if (e.Eoper == OPand)
                {
                    if (op == OPs16_32 && (ul & 0x8000) == 0)
                        e1.Eoper = OPu16_32;
                    else if (op == OPs8_16  && (ul & 0x80) == 0)
                        e1.Eoper = OPu8_16;
                    else if (op == OPs32_64 && (ul & 0x80000000) == 0)
                        e1.Eoper = OPu32_64;
                }

                // ((shtlng)s & c) => ((shtlng)(s & c)
                e1.Ety = e.Ety;
                e.Ety = e2.Ety = e1.EV.E1.Ety;
                e.EV.E1 = e1.EV.E1;
                e1.EV.E1 = e;
                e = e1;
                goto Lopt;
            }

            // Replace (((a & b) ^ c) & d) with ((a ^ c) & e), where
            // e is (b&d).
            if (e.Eoper == OPand && op == OPxor && e1.EV.E1.Eoper == OPand &&
                e1.EV.E1.EV.E2.Eoper == OPconst)
            {
                e2.EV.Vullong &= e1.EV.E1.EV.E2.EV.Vullong;
                e1.EV.E1 = el_selecte1(e1.EV.E1);
                goto Lopt;
            }

            // Replace ((a >> b) & 1) with (a btst b)
            if ((I32 || I64) &&
                e.Eoper == OPand &&
                ul == 1 &&
                (e.EV.E1.Eoper == OPshr || e.EV.E1.Eoper == OPashr) &&
                sz <= REGSIZE &&
                tysize(e1.Ety) >= 2     // BT doesn't work on byte operands
               )
            {
                e.EV.E1.Eoper = OPbtst;
                e = el_selecte1(e);
                goto Lopt;
            }
        }
    }

    if (OPTIMIZER && goal & GOALflags && (I32 || I64) && e.Eoper == OPand &&
        (sz == 4 || sz == 8))
    {
        /* These should all compile to a BT instruction when -O, for -m32 and -m64
         * int bt32(uint *p, uint b) { return ((p[b >> 5] & (1 << (b & 0x1F)))) != 0; }
         * int bt64a(ulong *p, uint b) { return ((p[b >> 6] & (1L << (b & 63)))) != 0; }
         * int bt64b(ulong *p, size_t b) { return ((p[b >> 6] & (1L << (b & 63)))) != 0; }
         */

        static bool ELCONST(elem* e, long c) { return e.Eoper == OPconst && el_tolong(e) == c; }
        int pow2sz = ispow2(sz);

        if (e1.Eoper == OPind)
        {   // Swap e1 and e2 so that e1 is the mask and e2 is the memory location
            e2 = e1;
            e1 = e.EV.E2;
        }

        /* Replace:
         *  ((1 << (b & 31))   &   *(((b >>> 5) << 2) + p)
         * with:
         *  p bt b
         */
        elem *e12;              // the (b & 31), which may be preceded by (64_32)
        elem *e2111;            // the (b >>> 5), which may be preceded by (u32_64)
        if (e1.Eoper == OPshl &&
            ELCONST(e1.EV.E1,1) &&
            (((e12 = e1.EV.E2).Eoper == OP64_32 ? (e12 = e12.EV.E1) : e12).Eoper == OPand) &&
            ELCONST(e12.EV.E2,sz * 8 - 1) &&
            tysize(e12.Ety) <= sz &&

            e2.Eoper == OPind &&
            e2.EV.E1.Eoper == OPadd &&
            e2.EV.E1.EV.E1.Eoper == OPshl &&
            ELCONST(e2.EV.E1.EV.E1.EV.E2,pow2sz) &&
            (((e2111 = e2.EV.E1.EV.E1.EV.E1).Eoper == OPu32_64 ? (e2111 = e2111.EV.E1) : e2111).Eoper == OPshr) &&
            ELCONST(e2111.EV.E2,pow2sz + 3)
           )
        {
            elem **pb1 = &e12.EV.E1;
            elem **pb2 = &e2111.EV.E1;
            elem **pp  = &e2.EV.E1.EV.E2;

            if (el_match(*pb1, *pb2) &&
                !el_sideeffect(*pb1))
            {
                e.Eoper = OPbt;
                e.EV.E1 = *pp;            // p
                *pp = null;
                e.EV.E2 = *pb1;           // b
                *pb1 = null;
                *pb2 = null;
                el_free(e1);
                el_free(e2);
                return optelem(e,goal);
            }
        }

        /* Replace:
         *  (1 << a) & b
         * with:
         *  b btst a
         */
        if (e1.Eoper == OPshl &&
            ELCONST(e1.EV.E1,1) &&
            tysize(e.EV.E1.Ety) <= REGSIZE)
        {
            const int sz1 = tysize(e.EV.E1.Ety);
            e.Eoper = OPbtst;
            e.Ety = TYbool;
            e.EV.E1 = e2;
            e.EV.E2 = e1.EV.E2;
            //e.EV.E2.Ety = e.EV.E1.Ety; // leave type as int
            e1.EV.E2 = null;
            el_free(e1);

            if (sz1 >= 2)
                e = el_una(OPu8_16, TYushort, e);
            if (sz1 >= 4)
                e = el_una(OPu16_32, TYulong, e);
            if (sz1 >= 8)
                e = el_una(OPu32_64, TYullong, e);

            return optelem(e, goal);
        }
    }

    return e;

Lopt:
    debug
    {
        __gshared int nest;
        nest++;
        if (nest > 100)
        {   elem_print(e);
            assert(0);
        }
        e = optelem(e,GOALvalue);
        nest--;
        return e;
    }
    else
        return optelem(e,GOALvalue);
}

/***************************************
 * Fill in ops[maxops] with operands of repeated operator oper.
 * Returns:
 *      true    didn't fail
 *      false   more than maxops operands
 */

@trusted
bool fillinops(elem **ops, int *opsi, int maxops, int oper, elem *e)
{
    if (e.Eoper == oper)
    {
        if (!fillinops(ops, opsi, maxops, oper, e.EV.E1) ||
            !fillinops(ops, opsi, maxops, oper, e.EV.E2))
            return false;
    }
    else
    {
        if (*opsi >= maxops)
            return false;       // error, too many
        ops[*opsi] = e;
        *opsi += 1;
    }
    return true;
}


/*************************************
 * Replace shift|shift with rotate.
 */

@trusted
private elem *elor(elem *e, goal_t goal)
{
    //printf("elor()\n");
    /* ROL:     (a << shift) | (a >> (sizeof(a) * 8 - shift))
     * ROR:     (a >> shift) | (a << (sizeof(a) * 8 - shift))
     */
    elem *e1 = e.EV.E1;
    elem *e2 = e.EV.E2;
    uint sz = tysize(e.Ety);
    if (sz <= REGSIZE)
    {
        if (e1.Eoper == OPshl && e2.Eoper == OPshr &&
            tyuns(e2.EV.E1.Ety) && e2.EV.E2.Eoper == OPmin &&
            e2.EV.E2.EV.E1.Eoper == OPconst &&
            el_tolong(e2.EV.E2.EV.E1) == sz * 8 &&
            el_match5(e1.EV.E1, e2.EV.E1) &&
            el_match5(e1.EV.E2, e2.EV.E2.EV.E2) &&
            !el_sideeffect(e)
           )
        {
            e1.Eoper = OProl;
            return el_selecte1(e);
        }
        if (e1.Eoper == OPshr && e2.Eoper == OPshl &&
            tyuns(e1.EV.E1.Ety) && e2.EV.E2.Eoper == OPmin &&
            e2.EV.E2.EV.E1.Eoper == OPconst &&
            el_tolong(e2.EV.E2.EV.E1) == sz * 8 &&
            el_match5(e1.EV.E1, e2.EV.E1) &&
            el_match5(e1.EV.E2, e2.EV.E2.EV.E2) &&
            !el_sideeffect(e)
           )
        {
            e1.Eoper = OPror;
            return el_selecte1(e);
        }
        // rotate left by a constant
        if (e1.Eoper == OPshl && e2.Eoper == OPshr &&
            tyuns(e2.EV.E1.Ety) &&
            e1.EV.E2.Eoper == OPconst &&
            e2.EV.E2.Eoper == OPconst &&
            el_tolong(e2.EV.E2) == sz * 8 - el_tolong(e1.EV.E2) &&
            el_match5(e1.EV.E1, e2.EV.E1) &&
            !el_sideeffect(e)
           )
        {
            e1.Eoper = OProl;
            return el_selecte1(e);
        }
        // rotate right by a constant
        if (e1.Eoper == OPshr && e2.Eoper == OPshl &&
            tyuns(e2.EV.E1.Ety) &&
            e1.EV.E2.Eoper == OPconst &&
            e2.EV.E2.Eoper == OPconst &&
            el_tolong(e2.EV.E2) == sz * 8 - el_tolong(e1.EV.E2) &&
            el_match5(e1.EV.E1, e2.EV.E1) &&
            !el_sideeffect(e)
           )
        {
            e1.Eoper = OPror;
            return el_selecte1(e);
        }
    }

    /* Recognize the following function and replace it with OPbswap:
        ushort byteswap(ushort x) { return cast(ushort)(((x >> 8) & 0xFF) | ((x << 8) & 0xFF00)); }

         |  TYunsigned short
          &  TYshort
           32_16  TYshort
            >>  TYint
             u16_32  TYint
              var  TYunsigned short  x
             const  TYint 8L
           const  TYshort 255
          &  TYshort
           <<  TYshort
            var  TYshort  x
            const  TYshort 8
           const  TYshort 0xFF00
     */
    if (sz == 2 && OPTIMIZER)
    {
        if (e.Eoper == OPor &&
            e1.Eoper == OPand &&
            e2.Eoper == OPand)
        {
            elem* evar;
            elem* evar2;
            auto e11 = e1.EV.E1;
            auto e12 = e1.EV.E2;
            if (e11.Eoper == OP32_16 &&
                e12.Eoper == OPconst && el_tolong(e12) == 0xFF)
            {
                auto e111 = e11.EV.E1;
                if (e111.Eoper == OPshr || e111.Eoper == OPashr)
                {
                    auto e1111 = e111.EV.E1;
                    auto e1112 = e111.EV.E2;
                    if (e1112.Eoper == OPconst && el_tolong(e1112) == 8 &&
                        e1111.Eoper == OPu16_32)
                        evar = e1111.EV.E1;
                }
            }

            if (evar)
            {
                auto e22 = e2.EV.E2;
                if (e22.Eoper == OPconst && el_tolong(e22) == 0xFF00)
                {
                    auto e21 = e2.EV.E1;
                    if (e21.Eoper == OPshl)
                    {
                        auto e211 = e21.EV.E1;
                        auto e212 = e21.EV.E2;
                        if (e212.Eoper == OPconst && el_tolong(e212) == 8)
                        {
                            if (el_match5(evar, e211) && !el_sideeffect(e211))
                            {
                                evar2 = e211;
                                e21.EV.E1 = null;
                            }
                        }
                    }
                }
            }

            if (evar2)
            {
                el_free(e1);
                el_free(e2);
                e.Eoper = OPbswap;
                e.EV.E1 = evar2;
                e.EV.E2 = null;
                //printf("Matched byteswap(ushort)\n");
                return e;
            }
        }
    }

    /* BSWAP: (data[0]<< 24) | (data[1]<< 16) | (data[2]<< 8) | (data[3]<< 0)
     */
    if (sz == 4 && OPTIMIZER)
    {
        elem*[4] ops;
        int opsi = 0;
        if (fillinops(ops.ptr, &opsi, 4, OPor, e) && opsi == 4)
        {
            elem *ex = null;
            uint bmask = 0;
            for (int i = 0; i < 4; i++)
            {
                elem *eo = ops[i];
                elem *eo2;
                int shift;
                elem *eo111;
                if (eo.Eoper == OPu8_16 &&
                    eo.EV.E1.Eoper == OPind)
                {
                    eo111 = eo.EV.E1.EV.E1;
                    shift = 0;
                }
                else if (eo.Eoper == OPshl &&
                    eo.EV.E1.Eoper == OPu8_16 &&
                    (eo2 = eo.EV.E2).Eoper == OPconst &&
                    eo.EV.E1.EV.E1.Eoper == OPind)
                {
                    shift = cast(int)el_tolong(eo2);
                    switch (shift)
                    {
                        case 8:
                        case 16:
                        case 24:
                            break;

                        default:
                            goto L1;
                    }
                    eo111 = eo.EV.E1.EV.E1.EV.E1;
                }
                else
                    goto L1;

                uint off;
                elem *ed;
                if (eo111.Eoper == OPadd)
                {
                    ed = eo111.EV.E1;
                    if (eo111.EV.E2.Eoper != OPconst)
                        goto L1;
                    off = cast(uint)el_tolong(eo111.EV.E2);
                    if (off < 1 || off > 3)
                        goto L1;
                }
                else
                {
                    ed = eo111;
                    off = 0;
                }
                switch ((off << 5) | shift)
                {
                    // BSWAP
                    case (0 << 5) | 24: bmask |= 1; break;
                    case (1 << 5) | 16: bmask |= 2; break;
                    case (2 << 5) |  8: bmask |= 4; break;
                    case (3 << 5) |  0: bmask |= 8; break;

                    // No swap
                    case (0 << 5) |  0: bmask |= 0x10; break;
                    case (1 << 5) |  8: bmask |= 0x20; break;
                    case (2 << 5) | 16: bmask |= 0x40; break;
                    case (3 << 5) | 24: bmask |= 0x80; break;

                    default:
                        goto L1;
                }
                if (ex)
                {
                    if (!el_match(ex, ed))
                        goto L1;
                }
                else
                {   if (el_sideeffect(ed))
                        goto L1;
                    ex = ed;
                }
            }
            /* Got a match, build:
             *   BSWAP(*ex)
             */
            if (bmask == 0x0F)
                e = el_una(OPbswap, e.Ety, el_una(OPind, e.Ety, ex));
            else if (bmask == 0xF0)
                e = el_una(OPind, e.Ety, ex);
            else
                goto L1;
            return e;
        }
    }
  L1:

    return elbitwise(e, goal);
}

/*************************************
 */

@trusted
private elem *elxor(elem *e, goal_t goal)
{
    if (OPTIMIZER)
    {
        elem *e1 = e.EV.E1;
        elem *e2 = e.EV.E2;

        /* Recognize:
         *    (a & c) ^ (b & c)  =>  (a ^ b) & c
         */
        if (e1.Eoper == OPand && e2.Eoper == OPand &&
            el_match5(e1.EV.E2, e2.EV.E2) &&
            (e2.EV.E2.Eoper == OPconst || (!el_sideeffect(e2.EV.E1) && !el_sideeffect(e2.EV.E2))))
        {
            el_free(e1.EV.E2);
            e1.EV.E2 = e2.EV.E1;
            e1.Eoper = OPxor;
            e.Eoper = OPand;
            e.EV.E2 = e2.EV.E2;
            e2.EV.E1 = null;
            e2.EV.E2 = null;
            el_free(e2);
            return optelem(e, GOALvalue);
        }
    }
    return elbitwise(e, goal);
}

/**************************
 * Optimize nots.
 *      ! ! e => bool e
 *      ! bool e => ! e
 *      ! OTrel => !OTrel       (invert the condition)
 *      ! OTconv => !
 */

@trusted
private elem * elnot(elem *e, goal_t goal)
{
    elem *e1 = e.EV.E1;
    const op = e1.Eoper;
    switch (op)
    {
        case OPnot:                     // ! ! e => bool e
        case OPbool:                    // ! bool e => ! e
            e1.Eoper = cast(ubyte)(op ^ (OPbool ^ OPnot));
            /* That was a clever substitute for the following:  */
            /* e.Eoper = (op == OPnot) ? OPbool : OPnot;               */
            e = optelem(el_selecte1(e), goal);
            break;

        default:
            if (OTrel(op))                      /* ! OTrel => !OTrel            */
            {
                  /* Find the logical negation of the operator  */
                  auto op2 = rel_not(op);
                  if (!tyfloating(e1.EV.E1.Ety))
                  {   op2 = rel_integral(op2);
                      assert(OTrel(op2));
                  }
                  e1.Eoper = cast(ubyte)op2;
                  e = optelem(el_selecte1(e), goal);
            }
            else if (tybasic(e1.Ety) == TYbool && tysize(e.Ety) == 1)
            {
                // !e1 => (e1 ^ 1)
                e.Eoper = OPxor;
                e.EV.E2 = el_long(e1.Ety,1);
                e = optelem(e, goal);
            }
            else
            {
                static if (0)
                {
                    // Can't use this because what if OPd_s32?
                    // Note: !(long)(.1) != !(.1)
                    if (OTconv(op))             // don't use case because of differ target
                    {   // conversion operators
                        e1.Eoper = e.Eoper;
                        e = optelem(el_selecte1(e), goal);
                        break;
                    }
                }
            }
            break;

        case OPs32_d:
        case OPs16_d:
        case OPu16_d:
        case OPu32_d:
        case OPf_d:
        case OPd_ld:
        case OPs16_32:
        case OPu16_32:
        case OPu8_16:
        case OPs8_16:
        case OPu32_64:
        case OPs32_64:
        case OPvp_fp:
        case OPcvp_fp:
        case OPnp_fp:
            e1.Eoper = e.Eoper;
            e = optelem(el_selecte1(e), goal);
            break;
    }
    return e;
}

/*************************
 * Complement
 *      ~ ~ e => e
 */

@trusted
private elem * elcom(elem *e, goal_t goal)
{
    elem *e1 = e.EV.E1;
    if (e1.Eoper == OPcom)                       // ~ ~ e => e
        // Typing problem here
        e = el_selecte1(el_selecte1(e));
    return e;
}

/*************************
 * If it is a conditional of a constant
 * then we know which exp to evaluate.
 * BUG:
 *      doesn't detect ("string" ? et : ef)
 */

@trusted
private elem * elcond(elem *e, goal_t goal)
{
    //printf("elcond() goal = %d\n", goal);
    //elem_print(e);
    elem *e1 = e.EV.E1;
    switch (e1.Eoper)
    {
        case OPconst:
            if (boolres(e1))
            L1:
                e = el_selecte1(el_selecte2(e));
            else
                e = el_selecte2(el_selecte2(e));
            break;

        case OPrelconst:
        case OPstring:
            goto L1;

        case OPcomma:
            // ((a,b) ? c) => (a,(b ? c))
            e.Eoper = OPcomma;
            e.EV.E1 = e1.EV.E1;
            e1.EV.E1 = e1.EV.E2;
            e1.EV.E2 = e.EV.E2;
            e.EV.E2 = e1;
            e1.Eoper = OPcond;
            e1.Ety = e.Ety;
            return optelem(e,GOALvalue);

        case OPnot:
        {
            // (!a ? b : c) => (a ? c : b)
            elem *ex = e.EV.E2.EV.E1;
            e.EV.E2.EV.E1 = e.EV.E2.EV.E2;
            e.EV.E2.EV.E2 = ex;
            goto L2;
        }

        default:
            if (OTboolnop(e1.Eoper))
            {
        L2:
                e.EV.E1 = e1.EV.E1;
                e1.EV.E1 = null;
                el_free(e1);
                return elcond(e,goal);
            }
            if (!OPTIMIZER)
                break;

        {
            tym_t ty = e.Ety;
            elem *ec1 = e.EV.E2.EV.E1;
            elem *ec2 = e.EV.E2.EV.E2;

            if (tyintegral(ty) && ec1.Eoper == OPconst && ec2.Eoper == OPconst)
            {
                targ_llong i1 = el_tolong(ec1);
                targ_llong i2 = el_tolong(ec2);
                tym_t ty1 = tybasic(e1.Ety);

                if ((ty1 == TYbool && !OTlogical(e1.Eoper) || e1.Eoper == OPand && e1.EV.E2.Eoper == OPconst) &&
                    tysize(ty) == tysize(ec1.Ety))
                {
                    targ_llong b = ty1 == TYbool ? 1 : el_tolong(e1.EV.E2);

                    if (b == 1 && ispow2(i1 - i2) != -1)
                    {
                        // replace (e1 ? i1 : i2) with (i1 + (e1 ^ 1) * (i2 - i1))
                        // replace (e1 ? i2 : i1) with (i1 + e1 * (i2 - i1))
                        int sz = tysize(e1.Ety);
                        while (sz < tysize(ec1.Ety))
                        {
                            // Increase the size of e1 until it matches the size of ec1
                            switch (sz)
                            {
                                case 1:
                                    e1 = el_una(OPu8_16, TYushort, e1);
                                    sz = 2;
                                    break;
                                case 2:
                                    e1 = el_una(OPu16_32, TYulong, e1);
                                    sz = 4;
                                    break;
                                case 4:
                                    e1 = el_una(OPu32_64, TYullong, e1);
                                    sz = 8;
                                    break;
                                default:
                                    assert(0);
                            }
                        }
                        if (i1 < i2)
                        {
                            ec2.EV.Vllong = i2 - i1;
                            e1 = el_bin(OPxor,e1.Ety,e1,el_long(e1.Ety,1));
                        }
                        else
                        {
                            ec1.EV.Vllong = i2;
                            ec2.EV.Vllong = i1 - i2;
                        }
                        e.EV.E1 = ec1;
                        e.EV.E2.Eoper = OPmul;
                        e.EV.E2.Ety = ty;
                        e.EV.E2.EV.E1 = e1;
                        e.Eoper = OPadd;
                        return optelem(e,GOALvalue);
                    }

                    /* If b is an integer with only 1 bit set then
                     *   replace ((a & b) ? b : 0) with (a & b)
                     *   replace ((a & b) ? 0 : b) with ((a & b) ^ b)
                     */
                    if (e1.Eoper == OPand && e1.EV.E2.Eoper == OPconst && ispow2(b) != -1) // if only 1 bit is set
                    {
                        if (b == i1 && i2 == 0)
                        {   e = el_selecte1(e);
                            e.EV.E1.Ety = ty;
                            e.EV.E2.Ety = ty;
                            e.EV.E2.EV.Vllong = b;
                            return optelem(e,GOALvalue);
                        }
                        else if (i1 == 0 && b == i2)
                        {
                            e1.Ety = ty;
                            e1.EV.E1.Ety = ty;
                            e1.EV.E2.Ety = ty;
                            e1.EV.E2.EV.Vllong = b;
                            e.EV.E1 = el_bin(OPxor,ty,e1,el_long(ty,b));
                            e = el_selecte1(e);
                            return optelem(e,GOALvalue);
                        }
                    }
                }

                /* Replace ((a relop b) ? 1 : 0) with (a relop b)       */
                else if (OTrel(e1.Eoper) &&
                    tysize(ty) <= tysize(TYint))
                {
                    if (i1 == 1 && i2 == 0)
                        e = el_selecte1(e);
                    else if (i1 == 0 && i2 == 1)
                    {
                        e.EV.E1 = el_una(OPnot,ty,e1);
                        e = optelem(el_selecte1(e),GOALvalue);
                    }
                }

                // The next two optimizations attempt to replace with an
                // uint compare, which the code generator can generate
                // code for without using jumps.

                // Try to replace (!e1) with (e1 < 1)
                else if (e1.Eoper == OPnot && !OTrel(e1.EV.E1.Eoper) && e1.EV.E1.Eoper != OPand)
                {
                    e.EV.E1 = el_bin(OPlt,TYint,e1.EV.E1,el_long(touns(e1.EV.E1.Ety),1));
                    e1.EV.E1 = null;
                    el_free(e1);
                }
                // Try to replace (e1) with (e1 >= 1)
                else if (!OTrel(e1.Eoper) && e1.Eoper != OPand)
                {
                    if (tyfv(e1.Ety))
                    {
                        if (tysize(e.Ety) == tysize(TYint))
                        {
                            if (i1 == 1 && i2 == 0)
                            {   e.Eoper = OPbool;
                                el_free(e.EV.E2);
                                e.EV.E2 = null;
                            }
                            else if (i1 == 0 && i2 == 1)
                            {   e.Eoper = OPnot;
                                el_free(e.EV.E2);
                                e.EV.E2 = null;
                            }
                        }
                    }
                    else if(tyintegral(e1.Ety))
                        e.EV.E1 = el_bin(OPge,TYint,e1,el_long(touns(e1.Ety),1));
                }
            }

            // Try to detect absolute value expression
            // (a < 0) -a : a
            else if ((e1.Eoper == OPlt || e1.Eoper == OPle) &&
                e1.EV.E2.Eoper == OPconst &&
                !boolres(e1.EV.E2) &&
                !tyuns(e1.EV.E1.Ety) &&
                !tyuns(e1.EV.E2.Ety) &&
                ec1.Eoper == OPneg &&
                !el_sideeffect(ec2) &&
                el_match(e.EV.E1.EV.E1,ec2) &&
                el_match(ec1.EV.E1,ec2) &&
                tysize(ty) >= _tysize[TYint]
               )
            {   e.EV.E2.EV.E2 = null;
                el_free(e);
                e = el_una(OPabs,ty,ec2);
            }
            // (a >= 0) a : -a
            else if ((e1.Eoper == OPge || e1.Eoper == OPgt) &&
                e1.EV.E2.Eoper == OPconst &&
                !boolres(e1.EV.E2) &&
                !tyuns(e1.EV.E1.Ety) &&
                !tyuns(e1.EV.E2.Ety) &&
                ec2.Eoper == OPneg &&
                !el_sideeffect(ec1) &&
                el_match(e.EV.E1.EV.E1,ec1) &&
                el_match(ec2.EV.E1,ec1) &&
                tysize(ty) >= _tysize[TYint]
               )
            {   e.EV.E2.EV.E1 = null;
                el_free(e);
                e = el_una(OPabs,ty,ec1);
            }

            /* Replace:
             *    a ? noreturn : c
             * with:
             *    (a && noreturn), c
             * because that means fewer noreturn cases for the data flow analysis to deal with
             */
            else if (!el_returns(ec1))
            {
                e.Eoper = OPcomma;
                e.EV.E1 = e.EV.E2;
                e.EV.E2 = ec2;
                e.EV.E1.Eoper = OPandand;
                e.EV.E1.Ety = TYvoid;
                e.EV.E1.EV.E2 = ec1;
                e.EV.E1.EV.E1 = e1;
            }

            /* Replace:
             *    a ? b : noreturn
             * with:
             *    (a || noreturn), b
             */
            else if (!el_returns(ec2))
            {
                e.Eoper = OPcomma;
                e.EV.E1 = e.EV.E2;
                e.EV.E2 = ec1;
                e.EV.E1.Eoper = OPoror;
                e.EV.E1.Ety = TYvoid;
                e.EV.E1.EV.E2 = ec2;
                e.EV.E1.EV.E1 = e1;
            }

            /* Replace:
             *   *p op e ? p : false
             * with:
             *   bool
             */
            else if (goal == GOALflags &&
                ec2.Eoper == OPconst && !boolres(ec2) &&
                typtr(ec1.Ety) &&
                ec1.Eoper == OPvar &&
                OTbinary(e1.Eoper) &&
                !OTsideff(e1.Eoper) &&
                e1.EV.E1.Eoper == OPind &&
                el_match(findPointer(e1.EV.E1.EV.E1), ec1) &&
                !el_sideeffect(e))
            {
                /* NOTE: should optimize other cases of this
                 */
                el_free(e.EV.E2);
                e.EV.E2 = null;
                e.Eoper = OPbool;
                e.Ety = TYint;
            }
            break;
        }
    }
    return e;
}

/******************************
 * Given an elem that is the operand to OPind,
 * find the expression representing the pointer.
 * Params:
 *      e = operand to OPind
 * Returns:
 *      expression that represents the pointer
 */
@trusted
private elem* findPointer(elem* e)
{
    if (e.Eoper == OPvar)
        return e;
    if (OTleaf(e.Eoper) || !(e.Eoper == OPadd || e.Eoper == OPmin))
        return null;

    if (typtr(e.EV.E1.Ety))
        return findPointer(e.EV.E1);
    if (OTbinary(e.Eoper))
    {
        if (typtr(e.EV.E2.Ety))
            return findPointer(e.EV.E2);
    }
    return null;
}


/****************************
 * Comma operator.
 *        ,      e
 *       / \  =>                expression with no effect
 *      c   e
 *        ,               ,
 *       / \    =>       / \    operators with no effect
 *      +   e           ,   e
 *     / \             / \
 *    e   e           e   e
 */

@trusted
private elem * elcomma(elem *e, goal_t goal)
{
    int changes = -1;
L1:
    changes++;
L2:
    //printf("elcomma()\n");
    elem *e2 = e.EV.E2;
    elem **pe1 = &(e.EV.E1);
    elem *e1 = *pe1;
    int e1op = e1.Eoper;

  // c,e => e
    if (OTleaf(e1op) && !OTsideff(e1op) && !(e1.Ety & (mTYvolatile | mTYshared)))
    {
        e2.Ety = e.Ety;
        e = el_selecte2(e);
        goto Lret;
    }

    // ((a op b),e2) => ((a,b),e2)        if op has no side effects
    if (!el_sideeffect(e1) && e1op != OPcomma && e1op != OPandand &&
        e1op != OPoror && e1op != OPcond)
    {
        if (OTunary(e1op))
            *pe1 = el_selecte1(e1); /* get rid of e1                */
        else
        {
            e1.Eoper = OPcomma;
            e1.Ety = e1.EV.E2.Ety;
        }
        goto L1;
    }

    if (!OPTIMIZER)
        goto Lret;

    /* Replace (a,b),e2 with a,(b,e2)   */
    if (e1op == OPcomma)
    {
        e1.Ety = e.Ety;
        e.EV.E1 = e1.EV.E1;
        e1.EV.E1 = e1.EV.E2;
        e1.EV.E2 = e2;
        e.EV.E2 = elcomma(e1, GOALvalue);
        goto L2;
    }

    if ((OTopeq(e1op) || e1op == OPeq) &&
        (e1.EV.E1.Eoper == OPvar || e1.EV.E1.Eoper == OPind) &&
        !el_sideeffect(e1.EV.E1)
       )
    {
        if (el_match(e1.EV.E1,e2))
            // ((a = b),a) => (a = b)
            e = el_selecte1(e);
        else if (OTrel(e2.Eoper) &&
                 OTleaf(e2.EV.E2.Eoper) &&
                 el_match(e1.EV.E1,e2.EV.E1)
                )
        {   // ((a = b),(a < 0)) => ((a = b) < 0)
            e1.Ety = e2.EV.E1.Ety;
            e.EV.E1 = e2.EV.E1;
            e2.EV.E1 = e1;
            goto L1;
        }
        else if ((e2.Eoper == OPandand ||
                  e2.Eoper == OPoror   ||
                  e2.Eoper == OPcond) &&
                 el_match(e1.EV.E1,e2.EV.E1)
                )
        {
            /* ((a = b),(a || c)) => ((a = b) || c)     */
            e1.Ety = e2.EV.E1.Ety;
            e.EV.E1 = e2.EV.E1;
            e2.EV.E1 = e1;
            e = el_selecte2(e);
            changes++;
            goto Lret;
        }
        else if (e1op == OPeq)
        {
            /* Replace ((a = b),(c = a)) with a,(c = (a = b))   */
            for (; e2.Eoper == OPcomma; e2 = e2.EV.E1)
            { }
            if ((OTopeq(e2.Eoper) || e2.Eoper == OPeq) &&
                el_match(e1.EV.E1,e2.EV.E2) &&
                //!(e1.EV.E1.Eoper == OPvar && el_appears(e2.EV.E1,e1.EV.E1.EV.Vsym)) &&
                ERTOL(e2))
            {
                e.EV.E1 = e2.EV.E2;
                e1.Ety = e2.EV.E2.Ety;
                e2.EV.E2 = e1;
                goto L1;
            }
        }
        else
        {
          static if (1) // This optimization is undone in eleq().
          {
            // Replace ((a op= b),(a op= c)) with (0,a = (a op b) op c)
            for (; e2.Eoper == OPcomma; e2 = e2.EV.E1)
            { }
            if ((OTopeq(e2.Eoper)) &&
                el_match(e1.EV.E1,e2.EV.E1))
            {
                elem *ex;
                e.EV.E1 = el_long(TYint,0);
                e1.Eoper = cast(ubyte)opeqtoop(e1op);
                e2.EV.E2 = el_bin(opeqtoop(e2.Eoper),e2.Ety,e1,e2.EV.E2);
                e2.Eoper = OPeq;
                goto L1;
            }
          }
        }
    }
Lret:
    again = changes != 0;
    return e;
}

/********************************
 */

private elem * elremquo(elem *e, goal_t goal)
{
    static if (0) version (MARS)
    if (cnst(e.EV.E2) && !boolres(e.EV.E2))
        error(e.Esrcpos.Sfilename, e.Esrcpos.Slinnum, e.Esrcpos.Scharnum, "divide by zero\n");

    return e;
}

/********************************
 */

@trusted
private elem * elmod(elem *e, goal_t goal)
{
    tym_t tym = e.EV.E1.Ety;
    if (!tyfloating(tym))
        return eldiv(e, goal);
    return e;
}

/*****************************
 * Convert divides to >> if power of 2.
 * Can handle OPdiv, OPdivass, OPmod.
 */

@trusted
private elem * eldiv(elem *e, goal_t goal)
{
    //printf("eldiv()\n");
    elem *e2 = e.EV.E2;
    tym_t tym = e.EV.E1.Ety;
    int uns = tyuns(tym) | tyuns(e2.Ety);
    if (cnst(e2))
    {
        static if (0) version (MARS)
        if (!boolres(e2))
            error(e.Esrcpos.Sfilename, e.Esrcpos.Slinnum, e.Esrcpos.Scharnum, "divide by zero\n");

        if (uns)
        {
            e2.Ety = touns(e2.Ety);
            int i = ispow2(el_tolong(e2));
            if (i != -1)
            {
                OPER op;
                switch (e.Eoper)
                {   case OPdiv:
                        op = OPshr;
                        goto L1;

                    case OPdivass:
                        op = OPshrass;
                    L1:
                        e2.EV.Vint = i;
                        e2.Ety = TYint;
                        e.EV.E1.Ety = touns(tym);
                        break;

                    case OPmod:
                        op = OPand;
                        goto L3;
                    case OPmodass:
                        op = OPandass;
                    L3:
                        e2.EV.Vullong = el_tolong(e2) - 1;
                        break;

                    default:
                        assert(0);
                }
                e.Eoper = cast(ubyte)op;
                return optelem(e,GOALvalue);
            }
        }
    }

    if (OPTIMIZER)
    {
        const int SQRT_INT_MAX = 0xB504;
        const uint SQRT_UINT_MAX = 0x10000;
        elem *e1 = e.EV.E1;
        if (tyintegral(tym) && e.Eoper == OPdiv && e2.Eoper == OPconst &&
            e1.Eoper == OPdiv && e1.EV.E2.Eoper == OPconst)
        {
            /* Replace:
             *   (e / c1) / c2
             * With:
             *   e / (c1 * c2)
             */
            targ_llong c1 = el_tolong(e1.EV.E2);
            targ_llong c2 = el_tolong(e2);
            bool uns1 = tyuns(e1.EV.E1.Ety) || tyuns(e1.EV.E2.Ety);
            bool uns2 = tyuns(e1.Ety) || tyuns(e2.Ety);
            if (uns1 == uns2)   // identity doesn't hold for mixed sign case
            {
                // The transformation will fail if c1*c2 overflows. This substitutes
                // for a proper overflow check.
                if (uns1 ? (c1 < SQRT_UINT_MAX && c2 < SQRT_UINT_MAX)
                         : (-SQRT_INT_MAX < c1 && c1 < SQRT_INT_MAX && -SQRT_INT_MAX < c2 && c2 < SQRT_INT_MAX))
                {
                    e.EV.E1 = e1.EV.E1;
                    e1.EV.E1 = e1.EV.E2;
                    e1.EV.E2 = e2;
                    e.EV.E2 = e1;
                    e1.Eoper = OPmul;
                    return optelem(e, GOALvalue);
                }
            }
        }

        if (tyintegral(tym) && e.Eoper == OPdiv && e2.Eoper == OPconst &&
            e1.Eoper == OP64_32 &&
            e1.EV.E1.Eoper == OPremquo && e1.EV.E1.EV.E2.Eoper == OPconst)
        {
            /* Replace:
             *   (64_32 (e /% c1)) / c2
             * With:
             *   e / (c1 * c2)
             */
            elem *erq = e1.EV.E1;
            targ_llong c1 = el_tolong(erq.EV.E2);
            targ_llong c2 = el_tolong(e2);
            bool uns1 = tyuns(erq.EV.E1.Ety) || tyuns(erq.EV.E2.Ety);
            bool uns2 = tyuns(e1.Ety) || tyuns(e2.Ety);
            if (uns1 == uns2)   // identity doesn't hold for mixed sign case
            {
                // The transformation will fail if c1*c2 overflows. This substitutes
                // for a proper overflow check.
                if (uns1 ? (c1 < SQRT_UINT_MAX && c2 < SQRT_UINT_MAX)
                         : (-SQRT_INT_MAX < c1 && c1 < SQRT_INT_MAX && -SQRT_INT_MAX < c2 && c2 < SQRT_INT_MAX))
                {
                    e.EV.E1 = erq.EV.E1;
                    erq.EV.E1 = erq.EV.E2;
                    erq.EV.E2 = e2;
                    e.EV.E2 = erq;
                    erq.Eoper = OPmul;
                    erq.Ety = e1.Ety;
                    e1.EV.E1 = null;
                    el_free(e1);
                    return optelem(e, GOALvalue);
                }
            }
        }

        /* Convert if(e1/e2) to if(e1>=e2) iff uint division.
         */
        if (goal == GOALflags && uns && e.Eoper == OPdiv)
        {
            e.Eoper = OPge;
            e.Ety = TYbool;
            return e;
        }

        /* TODO: (i*c1)/c2 => i*(c1/c2) if (c1%c2)==0
         * TODO: i/(x?c1:c2) => i>>(x?log2(c1):log2(c2)) if c1 and c2 are powers of 2
         */

        if (tyintegral(tym) && (e.Eoper == OPdiv || e.Eoper == OPmod))
        {
            int sz = tysize(tym);

            // See if we can replace with OPremquo
            if (sz == REGSIZE
                // Currently don't allow this because OPmsw doesn't work for the case
                //|| (I64 && sz == 4)
                )
            {
                // Don't do it if there are special code sequences in the
                // code generator (see cdmul())
                int pow2;
                if (e2.Eoper == OPconst &&
                    !uns &&
                    (pow2 = ispow2(el_tolong(e2))) != -1 &&
                    !(config.target_cpu < TARGET_80286 && pow2 != 1 && e.Eoper == OPdiv)
                   )
                { }
                else
                {
                    assert(sz == 2 || sz == 4 || sz == 8);
                    OPER op = OPmsw;
                    if (e.Eoper == OPdiv)
                    {
                        op = (sz == 2) ? OP32_16 : (sz == 4) ? OP64_32 : OP128_64;
                    }
                    e.Eoper = OPremquo;
                    e = el_una(op, tym, e);
                    e.EV.E1.Ety = (sz == 2) ? TYlong : (sz == 4) ? TYllong : TYcent;
                    return e;
                }
            }
        }
    }

    return e;
}

/**************************
 * Convert (a op b) op c to a op (b op c).
 */

@trusted
private elem * swaplog(elem *e, goal_t goal)
{
    elem *e1 = e.EV.E1;
    e.EV.E1 = e1.EV.E2;
    e1.EV.E2 = e;
    return optelem(e1,goal);
}

@trusted
private elem * eloror(elem *e, goal_t goal)
{
    tym_t ty1,ty2;

    elem *e1 = e.EV.E1;
    if (OTboolnop(e1.Eoper))
    {
        e.EV.E1 = e1.EV.E1;
        e1.EV.E1 = null;
        el_free(e1);
        return eloror(e, goal);
    }

    elem *e2 = e.EV.E2;
    if (OTboolnop(e2.Eoper))
    {
        e.EV.E2 = e2.EV.E1;
        e2.EV.E1 = null;
        el_free(e2);
        return eloror(e, goal);
    }

    if (OPTIMIZER)
    {
        if (e1.Eoper == OPbool)
        {   ty1 = e1.EV.E1.Ety;
            e1 = e.EV.E1 = el_selecte1(e1);
            e1.Ety = ty1;
        }
        if (e1.Eoper == OPoror)
        {   /* convert (a||b)||c to a||(b||c). This will find more CSEs.    */
            return swaplog(e, goal);
        }
        e2 = elscancommas(e2);
        e1 = elscancommas(e1);
    }

    tym_t t = e.Ety;
    if (e2.Eoper == OPconst || e2.Eoper == OPrelconst || e2.Eoper == OPstring)
    {
        if (boolres(e2))                /* e1 || 1  => e1 , 1           */
        {
            if (e.EV.E2 == e2)
                goto L2;
        }
        else                            /* e1 || 0  =>  bool e1         */
        {
            if (e.EV.E2 == e2)
            {
                el_free(e.EV.E2);
                e.EV.E2 = null;
                e.Eoper = OPbool;
                goto L3;
            }
        }
    }

    if (e1.Eoper == OPconst || e1.Eoper == OPrelconst || e1.Eoper == OPstring)
    {
        if (boolres(e1))                /* (x,1) || e2  =>  (x,1),1     */
        {
            if (tybasic(e.EV.E2.Ety) == TYvoid)
            {
                assert(!goal);
                el_free(e);
                return null;
            }
            else
            {
            L2:
                e.Eoper = OPcomma;
                el_free(e.EV.E2);
                e.EV.E2 = el_long(t,1);
            }
        }
        else                            /* (x,0) || e2  =>  (x,0),(bool e2) */
        {
            e.Eoper = OPcomma;
            if (tybasic(e.EV.E2.Ety) != TYvoid)
                e.EV.E2 = el_una(OPbool,t,e.EV.E2);
        }
  }
  else if (OPTIMIZER &&
        e.EV.E2.Eoper == OPvar &&
        !OTlogical(e1.Eoper) &&
        tysize(ty2 = e2.Ety) == tysize(ty1 = e1.Ety) &&
        tysize(ty1) <= _tysize[TYint] &&
        !tyfloating(ty2) &&
        !tyfloating(ty1) &&
        !(ty2 & (mTYvolatile | mTYshared)))
    {   /* Convert (e1 || e2) => (e1 | e2)      */
        e.Eoper = OPor;
        e.Ety = ty1;
        e = el_una(OPbool,t,e);
    }
    else if (OPTIMIZER &&
             e1.Eoper == OPand && e2.Eoper == OPand &&
             tysize(e1.Ety) == tysize(e2.Ety) &&
             el_match(e1.EV.E1,e2.EV.E1) && !el_sideeffect(e1.EV.E1) &&
             !el_sideeffect(e2.EV.E2)
            )
    {   // Convert ((a & b) || (a & c)) => bool(a & (b | c))
        e.Eoper = OPbool;
        e.EV.E2 = null;
        e2.Eoper = OPor;
        el_free(e2.EV.E1);
        e2.EV.E1 = e1.EV.E2;
        e1.EV.E2 = e2;
    }
    else
        goto L1;
L3:
    e = optelem(e,GOALvalue);
L1:
    return e;
}

/**********************************************
 * Try to rewrite sequence of || and && with faster operations, such as BT.
 * Returns:
 *      false   nothing changed
 *      true    *pe is rewritten
 */

@trusted
private bool optim_loglog(elem **pe)
{
    if (I16)
        return false;
    elem *e = *pe;
    const op = e.Eoper;
    assert(op == OPandand || op == OPoror);
    size_t n = el_opN(e, op);
    if (n <= 3)
        return false;
    uint ty = e.Ety;
    elem **array = cast(elem **)malloc(n * (elem *).sizeof);
    assert(array);
    elem **p = array;
    el_opArray(&p, e, op);

    bool any = false;
    size_t first, last;
    targ_ullong emin, emax;
    int cmpop = op == OPandand ? OPne : OPeqeq;
    for (size_t i = 0; i < n; ++i)
    {
        elem *eq = array[i];
        if (eq.Eoper == cmpop &&
            eq.EV.E2.Eoper == OPconst &&
            tyintegral(eq.EV.E2.Ety) &&
            !el_sideeffect(eq.EV.E1))
        {
            targ_ullong m = el_tolong(eq.EV.E2);
            if (any)
            {
                if (el_match(array[first].EV.E1, eq.EV.E1))
                {
                    last = i;
                    if (m < emin)
                        emin = m;
                    if (m > emax)
                        emax = m;
                }
                else if (last - first > 2)
                    break;
                else
                {
                    first = last = i;
                    emin = emax = m;
                }
            }
            else
            {
                any = true;
                first = last = i;
                emin = emax = m;
            }
        }
        else if (any && last - first > 2)
            break;
        else
            any = false;
    }

    //printf("n = %d, count = %d, min = %d, max = %d\n", (int)n, last - first + 1, (int)emin, (int)emax);
    if (any && last - first > 2 && emax - emin < REGSIZE * 8)
    {
        /**
         * Transforms expressions of the form x==c1 || x==c2 || x==c3 || ... into a single
         * comparison by using a bitmapped representation of data, as follows. First, the
         * smallest constant of c1, c2, ... (call it min) is subtracted from all constants
         * and also from x (this step may be elided if all constants are small enough). Then,
         * the test is expressed as
         *   (1 << (x-min)) | ((1 << (c1-min)) | (1 << (c2-min)) | ...)
         * The test is guarded for overflow (x must be no larger than the largest of c1, c2, ...).
         * Since each constant is encoded as a displacement in a bitmap, hitting any bit yields
         * true for the expression.
         *
         * I.e. replace:
         *   e==c1 || e==c2 || e==c3 ...
         * with:
         *   (e - emin) <= (emax - emin) && (1 << (int)(e - emin)) & bits
         * where bits is:
         *   (1<<(c1-emin)) | (1<<(c2-emin)) | (1<<(c3-emin)) ...
         *
         * For the case of:
         *  x!=c1 && x!=c2 && x!=c3 && ...
         * using De Morgan's theorem, rewrite as:
         *   (e - emin) > (emax - emin) || ((1 << (int)(e - emin)) & ~bits)
         */

        // Delete all the || nodes that are no longer referenced
        el_opFree(e, op);

        if (emax < 32)                  // if everything fits in a 32 bit register
            emin = 0;                   // no need for bias

        // Compute bit mask
        targ_ullong bits = 0;
        for (size_t i = first; i <= last; ++i)
        {
            elem *eq = array[i];
            if (0 && eq.EV.E2.Eoper != OPconst)
            {
                printf("eq = %p, eq.EV.E2 = %p\n", eq, eq.EV.E2);
                printf("first = %d, i = %d, last = %d, Eoper = %d\n", cast(int)first, cast(int)i, cast(int)last, eq.EV.E2.Eoper);
                printf("any = %d, n = %d, count = %d, min = %d, max = %d\n", any, cast(int)n, cast(int)(last - first + 1), cast(int)emin, cast(int)emax);
            }
            assert(eq.EV.E2.Eoper == OPconst);
            bits |= cast(targ_ullong)1 << (el_tolong(eq.EV.E2) - emin);
        }
        //printf("n = %d, count = %d, min = %d, max = %d\n", cast(int)n, last - first + 1, cast(int)emin, cast(int)emax);
        //printf("bits = x%llx\n", bits);

        if (op == OPandand)
            bits = ~bits;

        uint tyc = array[first].EV.E1.Ety;

        elem *ex = el_bin(OPmin, tyc, array[first].EV.E1, el_long(tyc,emin));
        ex = el_bin(op == OPandand ? OPgt : OPle, TYbool, ex, el_long(touns(tyc), emax - emin));
        elem *ey = el_bin(OPmin, tyc, array[first + 1].EV.E1, el_long(tyc,emin));

        tym_t tybits = TYuint;
        if ((emax - emin) >= 32)
        {
            assert(I64);                // need 64 bit BT
            tybits = TYullong;
        }

        // Shift count must be an int
        switch (tysize(tyc))
        {
            case 1:
                ey = el_una(OPu8_16,TYint,ey);
                goto case 2;

            case 2:
                ey = el_una(OPu16_32,TYint,ey);
                break;

            case 4:
                break;

            case 8:
                ey = el_una(OP64_32,TYint,ey);
                break;

            default:
                assert(0);
        }
        ey = el_bin(OPbtst,TYbool,el_long(tybits,bits),ey);
        ex = el_bin(op == OPandand ? OPoror : OPandand, ty, ex, ey);

        /* Free unneeded nodes
         */
        array[first].EV.E1 = null;
        el_free(array[first]);
        array[first + 1].EV.E1 = null;
        el_free(array[first + 1]);
        for (size_t i = first + 2; i <= last; ++i)
            el_free(array[i]);

        array[first] = ex;

        for (size_t i = first + 1; i + (last - first) < n; ++i)
            array[i] = array[i + (last - first)];
        n -= last - first;
        (*pe) = el_opCombine(array, n, op, ty);

        free(array);
        return true;
    }

    free(array);
    return false;
}

@trusted
private elem * elandand(elem *e, goal_t goal)
{
    elem *e1 = e.EV.E1;
    if (OTboolnop(e1.Eoper))
    {
        e.EV.E1 = e1.EV.E1;
        e1.EV.E1 = null;
        el_free(e1);
        return elandand(e, goal);
    }
    elem *e2 = e.EV.E2;
    if (OTboolnop(e2.Eoper))
    {
        e.EV.E2 = e2.EV.E1;
        e2.EV.E1 = null;
        el_free(e2);
        return elandand(e, goal);
    }
    if (OPTIMIZER)
    {
        /* Recognize: (a >= c1 && a < c2)
         */
        if ((e1.Eoper == OPge || e1.Eoper == OPgt) &&
            (e2.Eoper == OPlt || e2.Eoper == OPle) &&
            e1.EV.E2.Eoper == OPconst && e2.EV.E2.Eoper == OPconst &&
            !el_sideeffect(e1.EV.E1) && el_match(e1.EV.E1, e2.EV.E1) &&
            tyintegral(e1.EV.E1.Ety) &&
            tybasic(e1.EV.E2.Ety) == tybasic(e2.EV.E2.Ety) &&
            tysize(e1.EV.E1.Ety) == _tysize[TYnptr])
        {
            /* Replace with: ((a - c1) < (c2 - c1))
             */
            targ_llong c1 = el_tolong(e1.EV.E2);
            if (e1.Eoper == OPgt)
                ++c1;
            targ_llong c2 = el_tolong(e2.EV.E2);
            if (0 <= c1 && c1 <= c2)
            {
                e1.Eoper = OPmin;
                e1.Ety = e1.EV.E1.Ety;
                e1.EV.E2.EV.Vllong = c1;
                e.EV.E2 = el_long(touns(e2.EV.E2.Ety), c2 - c1);
                e.Eoper = e2.Eoper;
                el_free(e2);
                return optelem(e, GOALvalue);
            }
        }

        // Look for (!(e >>> c) && ...)
        if (e1.Eoper == OPnot && e1.EV.E1.Eoper == OPshr &&
            e1.EV.E1.EV.E2.Eoper == OPconst)
        {
            // Replace (e >>> c) with (e & x)
            elem *e11 = e1.EV.E1;

            targ_ullong shift = el_tolong(e11.EV.E2);
            if (shift < _tysize[TYint] * 8)
            {
                targ_ullong m;
                m = ~0L << cast(int)shift;
                e11.Eoper = OPand;
                e11.EV.E2.EV.Vullong = m;
                e11.EV.E2.Ety = e11.Ety;
                return optelem(e,GOALvalue);
            }
        }

        if (e1.Eoper == OPbool)
        {
            tym_t t = e1.EV.E1.Ety;
            e1 = e.EV.E1 = el_selecte1(e1);
            e1.Ety = t;
        }
        if (e1.Eoper == OPandand)
        {   // convert (a&&b)&&c to a&&(b&&c). This will find more CSEs.
            return swaplog(e, goal);
        }
        e2 = elscancommas(e2);

        while (1)
        {
            e1 = elscancommas(e1);
            if (e1.Eoper == OPeq)
                e1 = e1.EV.E2;
            else
                break;
        }
    }

    if (e2.Eoper == OPconst || e2.Eoper == OPrelconst || e2.Eoper == OPstring)
    {
        if (boolres(e2))        // e1 && (x,1)  =>  e1 ? ((x,1),1) : 0
        {
            if (e2 == e.EV.E2)    // if no x, replace e with (bool e1)
            {
                el_free(e2);
                e.EV.E2 = null;
                e.Eoper = OPbool;
                goto L3;
            }
        }
        else                            // e1 && (x,0)  =>  e1 , (x,0)
        {
            if (e2 == e.EV.E2)
            {   e.Eoper = OPcomma;
                goto L3;
            }
        }
    }

  if (e1.Eoper == OPconst || e1.Eoper == OPrelconst || e1.Eoper == OPstring)
  {
        e.Eoper = OPcomma;
        if (boolres(e1))                // (x,1) && e2  =>  (x,1),bool e2
        {
            if (tybasic(e.EV.E2.Ety) != TYvoid)
                e.EV.E2 = el_una(OPbool,e.Ety,e.EV.E2);
        }
        else                            // (x,0) && e2  =>  (x,0),0
        {
            if (tybasic(e.EV.E2.Ety) == TYvoid)
            {
                assert(!goal);
                el_free(e);
                return null;
            }
            else
            {
                el_free(e.EV.E2);
                e.EV.E2 = el_long(e.Ety,0);
            }
        }
    }
    else
        goto L1;
L3:
    e = optelem(e,GOALvalue);
L1:
    return e;
}

/**************************
 * Reference to bit field
 *       bit
 *       / \    =>      ((e << c) >> b) & m
 *      e  w,b
 *
 * Note that this routine can handle long bit fields, though this may
 * not be supported later on.
 */

@trusted
private elem * elbit(elem *e, goal_t goal)
{

    tym_t tym1 = e.EV.E1.Ety;
    uint sz = tysize(tym1) * 8;
    elem *e2 = e.EV.E2;
    uint wb = e2.EV.Vuns;

    uint w = (wb >> 8) & 0xFF;               // width in bits of field
    targ_ullong m = (cast(targ_ullong)1 << w) - 1;   // mask w bits wide
    uint b = wb & 0xFF;                      // bits to right of field
    uint c = 0;
    assert(w + b <= sz);

    if (tyuns(tym1))                      // if uint bit field
    {
        // Should use a more general solution to this
        if (w == 8 && sz == 16 && b == 0)
        {
            e.EV.E1 = el_una(OP16_8,TYuchar,e.EV.E1);
            e.Eoper = OPu8_16;
            e.EV.E2 = null;
            el_free(e2);
            goto L1;
        }

        if (w + b == sz)                // if field is left-justified
            m = ~cast(targ_ullong)0;    // no need to mask
    }
    else                                // signed bit field
    {
        if (w == 8 && sz == 16 && b == 0)
        {
            e.EV.E1 = el_una(OP16_8,TYschar,e.EV.E1);
            e.Eoper = OPs8_16;
            e.EV.E2 = null;
            el_free(e2);
            goto L1;
        }
        m = ~cast(targ_ullong)0;
        c = sz - (w + b);
        b = sz - w;
    }

    e.Eoper = OPand;

    e2.EV.Vullong = m;                   // mask w bits wide
    e2.Ety = e.Ety;

    e.EV.E1 = el_bin(OPshr,tym1,
                el_bin(OPshl,tym1,e.EV.E1,el_long(TYint,c)),
                el_long(TYint,b));
L1:
    return optelem(e,GOALvalue);         // optimize result
}

/*****************
 * Indirection
 *      * & e => e
 */

@trusted
private elem * elind(elem *e, goal_t goal)
{
    tym_t tym = e.Ety;
    elem *e1 = e.EV.E1;
    switch (e1.Eoper)
    {
        case OPrelconst:
            e.EV.E1.ET = e.ET;
            e = el_selecte1(e);
            e.Eoper = OPvar;
            e.Ety = tym;               /* preserve original type       */
            break;

        case OPadd:
            if (OPTIMIZER)
            {   /* Try to convert far pointer to stack pointer  */
                elem *e12 = e1.EV.E2;

                if (e12.Eoper == OPrelconst &&
                    tybasic(e12.Ety) == TYfptr &&
                    /* If symbol is located on the stack        */
                    sytab[e12.EV.Vsym.Sclass] & SCSS)
                {   e1.Ety = (e1.Ety & (mTYconst | mTYvolatile | mTYimmutable | mTYshared | mTYLINK)) | TYsptr;
                    e12.Ety = (e12.Ety & (mTYconst | mTYvolatile | mTYimmutable | mTYshared | mTYLINK)) | TYsptr;
                }
            }
            break;

        case OPcomma:
            // Replace (*(ea,eb)) with (ea,*eb)
            e.EV.E1.ET = e.ET;
            type *t = e.ET;
            e = el_selecte1(e);
            e.Ety = tym;
            e.EV.E2 = el_una(OPind,tym,e.EV.E2);
            e.EV.E2.ET = t;
            again = 1;
            return e;

        default:
            break;
    }
    topair |= (config.fpxmmregs && tycomplex(tym));
    return e;
}

/*****************
 * Address of.
 *      & v => &v
 *      & * e => e
 *      & (v1 = v2) => ((v1 = v2), &v1)
 */

@trusted
private elem * eladdr(elem *e, goal_t goal)
{
    tym_t tym = e.Ety;
    elem *e1 = e.EV.E1;
    elem_debug(e1);
    switch (e1.Eoper)
    {
        case OPvar:
            e1.Eoper = OPrelconst;
            e1.EV.Vsym.Sflags &= ~(SFLunambig | GTregcand);
            e1.Ety = tym;
            e = optelem(el_selecte1(e),GOALvalue);
            break;

        case OPind:
        {
            tym_t tym2 = e1.EV.E1.Ety;

            // Watch out for conversions between near and far pointers
            int sz = tysize(tym) - tysize(tym2);
            if (sz != 0)
            {
                OPER op;
                if (sz > 0)                         // if &far * near
                    op = OPnp_fp;
                else                                // else &near * far
                    op = OPoffset;
                e.Ety = tym2;
                e = el_una(op,tym,e);
                goto L1;
            }

            e = el_selecte1(el_selecte1(e));
            e.Ety = tym;
            break;
        }

        case OPcomma:
            // Replace (&(ea,eb)) with (ea,&eb)
            e = el_selecte1(e);
            e.Ety = tym;
            e.EV.E2 = el_una(OPaddr,tym,e.EV.E2);
        L1:
            e = optelem(e,GOALvalue);
            break;

        case OPnegass:
            assert(0);

        default:
            if (OTassign(e1.Eoper))
            {
        case OPstreq:
                //  & (v1 = e) => ((v1 = e), &v1)
                if (e1.EV.E1.Eoper == OPvar)
                {
                    e.Eoper = OPcomma;
                    e.EV.E2 = el_una(OPaddr,tym,el_copytree(e1.EV.E1));
                    goto L1;
                }
                //  & (*p1 = e) => ((*(t = p1) = e), t)
                else if (e1.EV.E1.Eoper == OPind)
                {
                    const tym_t tym111 = e1.EV.E1.EV.E1.Ety;
                    elem *tmp = el_alloctmp(tym111);
                    e1.EV.E1.EV.E1 = el_bin(OPeq,tym111,tmp,e1.EV.E1.EV.E1);
                    e.Eoper = OPcomma;
                    e.EV.E2 = el_copytree(tmp);
                    goto L1;
                }
            }
            break;

        case OPcond:
        {   // Replace &(x ? y : z) with (x ? &y : &z)
            elem *ecolon = e1.EV.E2;
            ecolon.Ety = tym;
            ecolon.EV.E1 = el_una(OPaddr,tym,ecolon.EV.E1);
            ecolon.EV.E2 = el_una(OPaddr,tym,ecolon.EV.E2);
            e = el_selecte1(e);
            e = optelem(e,GOALvalue);
            break;
        }

        case OPinfo:
            // Replace &(e1 info e2) with (e1 info &e2)
            e = el_selecte1(e);
            e.EV.E2 = el_una(OPaddr,tym,e.EV.E2);
            e = optelem(e,GOALvalue);
            break;
    }
    return e;
}

/*******************************************
 */

@trusted
private elem * elneg(elem *e, goal_t goal)
{
    if (e.EV.E1.Eoper == OPneg)
    {
        e = el_selecte1(e);
        e = el_selecte1(e);
    }
    /* Convert -(e1 + c) to (-e1 - c)
     */
    else if (e.EV.E1.Eoper == OPadd && e.EV.E1.EV.E2.Eoper == OPconst)
    {
        e.Eoper = OPmin;
        e.EV.E2 = e.EV.E1.EV.E2;
        e.EV.E1.Eoper = OPneg;
        e.EV.E1.EV.E2 = null;
        e = optelem(e,goal);
    }
    else
        e = evalu8(e, goal);
    return e;
}

@trusted
private elem * elcall(elem *e, goal_t goal)
{
    if (e.EV.E1.Eoper == OPcomma || OTassign(e.EV.E1.Eoper))
        e = cgel_lvalue(e);
    return e;
}

/***************************
 * Walk tree, converting types to tym.
 */

@trusted
private void elstructwalk(elem *e,tym_t tym)
{
    tym_t ety;

    while ((ety = tybasic(e.Ety)) == TYstruct ||
           ety == TYarray)
    {   elem_debug(e);
        e.Ety = (e.Ety & ~mTYbasic) | tym;
        switch (e.Eoper)
        {
            case OPcomma:
            case OPcond:
            case OPinfo:
                break;

            case OPeq:
            case OPcolon:
            case OPcolon2:
                elstructwalk(e.EV.E1,tym);
                break;

            default:
                return;
        }
        e = e.EV.E2;
    }
}

/*******************************
 * See if we can replace struct operations with simpler ones.
 * For OPstreq and OPstrpar.
 */

@trusted
elem * elstruct(elem *e, goal_t goal)
{
    //printf("elstruct(%p)\n", e);
    //elem_print(e);
    if (e.Eoper == OPstreq && (e.EV.E1.Eoper == OPcomma || OTassign(e.EV.E1.Eoper)))
        return cgel_lvalue(e);

    if (e.Eoper == OPstreq && e.EV.E2.Eoper == OPcomma)
    {
        /* Replace (e1 streq (e21, e22)) with (e21, (e1 streq e22))
         */
        e.EV.E2.Eoper = e.Eoper;
        e.EV.E2.Ety = e.Ety;
        e.EV.E2.ET = e.ET;
        e.Eoper = OPcomma;
        elem *etmp = e.EV.E1;
        e.EV.E1 = e.EV.E2.EV.E1;
        e.EV.E2.EV.E1 = etmp;
        return optelem(e, goal);
    }

    if (!e.ET)
        return e;
    //printf("\tnumbytes = %d\n", (int)type_size(e.ET));

    type *t = e.ET;
    tym_t tym = ~0;
    tym_t ty = tybasic(t.Tty);

    uint sz = (e.Eoper == OPstrpar && type_zeroSize(t, global_tyf)) ? 0 : cast(uint)type_size(t);
    //printf("\tsz = %d\n", (int)sz);

    type *targ1 = null;
    type *targ2 = null;
    if (ty == TYstruct)
    {   // If a struct is a wrapper for another type, prefer that other type
        targ1 = t.Ttag.Sstruct.Sarg1type;
        targ2 = t.Ttag.Sstruct.Sarg2type;
    }

    if (ty == TYarray && sz && config.exe != EX_WIN64)
    {
        argtypes(t, targ1, targ2);
        if (!targ1)
            goto Ldefault;
        goto L1;
    }
    //if (targ1) { printf("targ1\n"); type_print(targ1); }
    //if (targ2) { printf("targ2\n"); type_print(targ2); }
    switch (cast(int)sz)
    {
        case 1:  tym = TYchar;   goto L1;
        case 2:  tym = TYshort;  goto L1;
        case 4:  tym = TYlong;   goto L1;
        case 8:  if (_tysize[TYint] == 2)
                     goto Ldefault;
                 tym = TYllong;  goto L1;

        case 3:  tym = TYlong;  goto L2;
        case 5:
        case 6:
        case 7:  tym = TYllong;
        L2:
            if (e.Eoper == OPstrpar && config.exe == EX_WIN64)
            {
                 goto L1;
            }
            if (I64 && config.exe != EX_WIN64)
            {
                goto L1;
            }
            tym = ~0;
            goto Ldefault;

        case 10:
        case 12:
            if (tysize(TYldouble) == sz && targ1 && !targ2 && tybasic(targ1.Tty) == TYldouble)
            {
                tym = TYldouble;
                goto L1;
            }
            goto case 9;

        case 9:
        case 11:
        case 13:
        case 14:
        case 15:
            if (I64 && config.exe != EX_WIN64)
            {
                goto L1;
            }
            goto Ldefault;

        case 16:
            if (I64 && (ty == TYstruct || (ty == TYarray && config.exe == EX_WIN64)))
            {
                tym = TYucent;
                goto L1;
            }
            if (config.exe == EX_WIN64)
                goto Ldefault;
            if (targ1 && !targ2)
                goto L1;
            goto Ldefault;

        L1:
            if (ty == TYstruct || ty == TYarray)
            {
                // This needs to match what TypeFunction::retStyle() does
                if (config.exe == EX_WIN64)
                {
                    //if (t.Ttag.Sstruct.Sflags & STRnotpod)
                        //goto Ldefault;
                }
                // If a struct is a wrapper for another type, prefer that other type
                else if (targ1 && !targ2)
                    tym = targ1.Tty;
                else if (I64 && !targ1 && !targ2)
                {
                    if (t.Ttag.Sstruct.Sflags & STRnotpod)
                    {
                        // In-memory only
                        goto Ldefault;
                    }
//                    if (type_size(t) == 16)
                        goto Ldefault;
                }
                else if (I64 && targ1 && targ2)
                {
                    if (tyfloating(tybasic(targ1.Tty)))
                        tym = TYcdouble;
                    else
                        tym = TYucent;
                    if ((0 == tyfloating(targ1.Tty)) ^ (0 == tyfloating(targ2.Tty)))
                    {
                        tym |= tyfloating(targ1.Tty) ? mTYxmmgpr : mTYgprxmm;
                    }
                }
                else if (I32 && targ1 && targ2)
                    tym = TYllong;
                assert(tym != TYstruct);
            }
            assert(tym != ~0);
            switch (e.Eoper)
            {
                case OPstreq:
                    if (sz != tysize(tym))
                    {
                        // we can't optimize OPstreq in this case,
                        // there will be memory corruption in the assignment
                        elem *e2 = e.EV.E2;
                        if (e2.Eoper != OPvar && e2.Eoper != OPind)
                        {
                            // the source may come in registers. ex: returned from a function.
                            assert(tyaggregate(e2.Ety));
                            e2 = optelem(e2, GOALvalue);
                            e2 = elstruct(e2, GOALvalue);
                            e2 = exp2_copytotemp(e2); // (tmp = e2, tmp)
                            e2.EV.E2.EV.Vsym.Sfl = FLauto;
                            e2.Ety = e2.EV.E2.Ety = e.Ety;
                            e2.ET = e2.EV.E2.ET = e.ET;
                            e.EV.E2 = e2;
                        }
                        break;
                    }
                    e.Eoper = OPeq;
                    e.Ety = (e.Ety & ~mTYbasic) | tym;
                    elstructwalk(e.EV.E1,tym);
                    elstructwalk(e.EV.E2,tym);
                    e = optelem(e,GOALvalue);
                    break;

                case OPstrpar:
                    e = el_selecte1(e);
                    goto default;

                default:                /* called by doptelem()         */
                    elstructwalk(e,tym);
                    break;
            }
            break;

        case 0:
            if (e.Eoper == OPstreq)
            {
                e.Eoper = OPcomma;
                e = optelem(e,GOALvalue);
                again = 1;
            }
            else
                goto Ldefault;
            break;

        default:
        Ldefault:
        {
            elem **pe2;
            if (e.Eoper == OPstreq)
                pe2 = &e.EV.E2;
            else if (e.Eoper == OPstrpar)
                pe2 = &e.EV.E1;
            else
                break;
            while ((*pe2).Eoper == OPcomma)
                pe2 = &(*pe2).EV.E2;
            elem *e2 = *pe2;

            if (e2.Eoper == OPvar)
                e2.EV.Vsym.Sflags &= ~GTregcand;

            // Convert (x streq (a?y:z)) to (x streq *(a ? &y : &z))
            if (e2.Eoper == OPcond)
            {
                tym_t ty2 = e2.Ety;

                /* We should do the analysis to see if we can use
                   something simpler than TYfptr.
                 */
                tym_t typ = (_tysize[TYint] == LONGSIZE) ? TYnptr : TYfptr;
                e2 = el_una(OPaddr,typ,e2);
                e2 = optelem(e2,GOALvalue);          /* distribute & to x and y leaves */
                *pe2 = el_una(OPind,ty2,e2);
                break;
            }
            break;
        }
    }
    return e;
}

/**************************
 * Assignment. Replace bit field assignment with
 * equivalent tree.
 *              =
 *            /  \
 *           /    r
 *        bit
 *       /   \
 *      l     w,b
 *
 * becomes:
 *          ,
 *         / \
 *        =   (r&m)
 *       / \
 *      l   |
 *         / \
 *  (r&m)<<b  &
 *           / \
 *          l  ~(m<<b)
 * Note:
 *      This depends on the expression (r&m)<<b before l. This is because
 *      of expressions like (l.a = l.b = n). It is an artifact of the way
 *      we do things that this works (cost() will rate the << as more
 *      expensive than the &, and so it will wind up on the left).
 */

@trusted
private elem * eleq(elem *e, goal_t goal)
{
    goal_t wantres = goal;
    elem *e1 = e.EV.E1;

    if (e1.Eoper == OPcomma || OTassign(e1.Eoper))
        return cgel_lvalue(e);

static if (0)  // Doesn't work too well, removed
{
    // Replace (*p++ = e2) with ((*p = e2),*p++)
    if (OPTIMIZER && e1.Eoper == OPind &&
      (e1.EV.E1.Eoper == OPpostinc || e1.EV.E1.Eoper == OPpostdec) &&
      !el_sideeffect(e1.EV.E1.EV.E1)
       )
    {
        e = el_bin(OPcomma,e.Ety,e,e1);
        e.EV.E1.EV.E1 = el_una(OPind,e1.Ety,el_copytree(e1.EV.E1.EV.E1));
        return optelem(e,GOALvalue);
    }
}

    if (OPTIMIZER)
    {
        elem *e2 = e.EV.E2;
        int op2 = e2.Eoper;

        // Replace (e1 = *p++) with (e1 = *p, p++, e1)
        elem *ei = e2;
        if (e1.Eoper == OPvar &&
            (op2 == OPind || (OTunary(op2) && (ei = e2.EV.E1).Eoper == OPind)) &&
            (ei.EV.E1.Eoper == OPpostinc || ei.EV.E1.Eoper == OPpostdec) &&
            !el_sideeffect(e1) &&
            !el_sideeffect(ei.EV.E1.EV.E1)
           )
        {
           e = el_bin(OPcomma,e.Ety,
                e,
                el_bin(OPcomma,e.Ety,ei.EV.E1,el_copytree(e1)));
           ei.EV.E1 = el_copytree(ei.EV.E1.EV.E1);            // copy p
           return optelem(e,GOALvalue);
        }

        /* Replace (e = e) with (e,e)   */
        if (el_match(e1,e2))
        {
            e.Eoper = OPcomma;
        L1:
            return optelem(e,GOALvalue);
        }

        // Replace (e1 = (e21 , e22)) with (e21 , (e1 = e22))
        if (op2 == OPcomma)
        {
            e2.Ety = e.Ety;
            e.EV.E2 = e2.EV.E2;
            e2.EV.E2 = e;
            e = e2;
            goto L1;
        }

        if (OTop(op2) && !el_sideeffect(e1)
            && op2 != OPdiv && op2 != OPmod
           )
        {
            tym_t ty;

            version (MARS)
                enum side = false; // don't allow side effects in e2.EV.E2 because of
                                   // D order-of-evaluation rules
            else
                enum side = true;  // ok in C and C++

            // Replace (e1 = e1 op e) with (e1 op= e)
            if (el_match(e1,e2.EV.E1) &&
                (side || !el_sideeffect(e2.EV.E2)))
            {
                ty = e2.EV.E2.Ety;
                e.EV.E2 = el_selecte2(e2);
            L2:
                e.EV.E2.Ety = ty;
                e.Eoper = cast(ubyte)optoopeq(op2);
                goto L1;
            }
            if (OTcommut(op2))
            {
                /* Replace (e1 = e op e1) with (e1 op= e)       */
                if (el_match(e1,e2.EV.E2))
                {   ty = e2.EV.E1.Ety;
                    e.EV.E2 = el_selecte1(e2);
                    goto L2;
                }
            }

static if (0)
{
// Note that this optimization is undone in elcomma(), this results in an
// infinite loop. This optimization is preferable if e1 winds up a register
// variable, the inverse in elcomma() is preferable if e1 winds up in memory.
            // Replace (e1 = (e1 op3 ea) op2 eb) with (e1 op3= ea),(e1 op2= eb)
            int op3 = e2.EV.E1.Eoper;
            if (OTop(op3) && el_match(e1,e2.EV.E1.EV.E1) && !el_depends(e1,e2.EV.E2))
            {
                e.Eoper = OPcomma;
                e.EV.E1 = e2.EV.E1;
                e.EV.E1.Eoper = optoopeq(op3);
                e2.EV.E1 = e1;
                e1.Ety = e.EV.E1.Ety;
                e2.Eoper = optoopeq(op2);
                e2.Ety = e.Ety;
                goto L1;
            }
}
        }

        if (op2 == OPneg && el_match(e1,e2.EV.E1) && !el_sideeffect(e1))
        {
            // Replace (i = -i) with (negass i)
            e.Eoper = OPnegass;
            e.EV.E2 = null;
            el_free(e2);
            return optelem(e, GOALvalue);
        }

        // Replace (x = (y ? z : x)) with ((y && (x = z)),x)
        if (op2 == OPcond && el_match(e1,e2.EV.E2.EV.E2))
        {
            elem *e22 = e2.EV.E2;         // e22 is the OPcond
            e.Eoper = OPcomma;
            e.EV.E2 = e1;
            e.EV.E1 = e2;
            e2.Eoper = OPandand;
            e2.Ety = TYint;
            e22.Eoper = OPeq;
            e22.Ety = e.Ety;
            e1 = e22.EV.E1;
            e22.EV.E1 = e22.EV.E2;
            e22.EV.E2 = e1;
            return optelem(e,GOALvalue);
        }

        // Replace (x = (y ? x : z)) with ((y || (x = z)),x)
        if (op2 == OPcond && el_match(e1,e2.EV.E2.EV.E1))
        {
            elem *e22 = e2.EV.E2;         // e22 is the OPcond
            e.Eoper = OPcomma;
            e.EV.E2 = e1;
            e.EV.E1 = e2;
            e2.Eoper = OPoror;
            e2.Ety = TYint;
            e22.Eoper = OPeq;
            e22.Ety = e.Ety;
            return optelem(e,GOALvalue);
        }

        // If floating point, replace (x = -y) with (x = y ^ signbit)
        if (op2 == OPneg && (tyreal(e2.Ety) || tyimaginary(e2.Ety)) &&
            (e2.EV.E1.Eoper == OPvar || e2.EV.E1.Eoper == OPind) &&
           /* Turned off for XMM registers because they don't play well with
            * int registers.
            */
           !config.fpxmmregs)
        {
            tym_t ty;

            elem *es = el_calloc();
            es.Eoper = OPconst;
            switch (tysize(e2.Ety))
            {
                case FLOATSIZE:
                    ty = TYlong;
                    es.EV.Vlong = 0x80000000;
                    break;

                case DOUBLESIZE:
                    if (I32)
                    {
                        ty = TYllong;
                        es.EV.Vllong = 0x8000000000000000L;
                        break;
                    }
                    goto default;

                default:
                    el_free(es);
                    goto L8;
            }
            es.Ety = ty;
            e1.Ety = ty;
            e2.Ety = ty;
            e2.EV.E1.Ety = ty;
            e2.EV.E2 = es;
            e2.Eoper = OPxor;
            return optelem(e,GOALvalue);

        L8:
        }

        // Replace (a=(r1 pair r2)) with (a1=r1), (a2=r2)
        if (tysize(e1.Ety) == 2 * REGSIZE &&
            e1.Eoper == OPvar &&
            (e2.Eoper == OPpair || e2.Eoper == OPrpair) &&
            goal == GOALnone &&
            !el_appears(e2, e1.EV.Vsym) &&
// this clause needs investigation because the code doesn't match the comment
            // Disable this rewrite if we're using x87 and `e1` is a FP-value
            // but `e2` is not, or vice versa
            // https://issues.dlang.org/show_bug.cgi?id=18197
            (config.fpxmmregs ||
             (tyfloating(e2.EV.E1.Ety) != 0) == (tyfloating(e2.Ety) != 0))
           )
        {
            // printf("** before:\n"); elem_print(e); printf("\n");
            tym_t ty = (REGSIZE == 8) ? TYllong : TYint;
            if (tyfloating(e1.Ety) && REGSIZE >= 4)
                ty = (REGSIZE == 8) ? TYdouble : TYfloat;
            ty |= e1.Ety & ~mTYbasic;
            e2.Ety = ty;
            e.Ety = ty;
            e1.Ety = ty;
            elem *eb = el_copytree(e1);
            eb.EV.Voffset += REGSIZE;

            if (e2.Eoper == OPpair)
            {
                e.EV.E2 = e2.EV.E1;
                eb = el_bin(OPeq,ty,eb,e2.EV.E2);
                e2.EV.E1 = e;
                e2.EV.E2 = eb;
            }
            else
            {
                e.EV.E2 = e2.EV.E2;
                eb = el_bin(OPeq,ty,eb,e2.EV.E1);
                e2.EV.E1 = eb;
                e2.EV.E2 = e;
            }

            e2.Eoper = OPcomma;
            // printf("** after:\n"); elem_print(e2); printf("\n");
            return optelem(e2,goal);
        }

        // Replace (a=b) with (a1=b1),(a2=b2)
        if (tysize(e1.Ety) == 2 * REGSIZE &&
            e1.Eoper == OPvar &&
            e2.Eoper == OPvar &&
            goal == GOALnone &&
            !tyfloating(e1.Ety) && !tyvector(e1.Ety)
           )
        {
            tym_t ty = (REGSIZE == 8) ? TYllong : TYint;
            ty |= e1.Ety & ~mTYbasic;
            e2.Ety = ty;
            e.Ety = ty;
            e1.Ety = ty;

            elem *eb = el_copytree(e);
            eb.EV.E1.EV.Voffset += REGSIZE;
            eb.EV.E2.EV.Voffset += REGSIZE;

            e = el_bin(OPcomma,ty,e,eb);
            return optelem(e,goal);
        }
    }

   if (e1.Eoper == OPcomma)
        return cgel_lvalue(e);
version (MARS)
{
    // No bit fields to deal with
    return e;
}
else
{
  if (e1.Eoper != OPbit)
        return e;
  if (e1.EV.E1.Eoper == OPcomma || OTassign(e1.EV.E1.Eoper))
        return cgel_lvalue(e);

    uint t = e.Ety;
    elem *l = e1.EV.E1;                           // lvalue
    elem *r = e.EV.E2;
    tym_t tyl = l.Ety;
    uint sz = tysize(tyl) * 8;
    uint w = (e1.EV.E2.EV.Vuns >> 8);        // width in bits of field
    targ_ullong m = (cast(targ_ullong)1 << w) - 1;  // mask w bits wide
    uint b = e1.EV.E2.EV.Vuns & 0xFF;        // bits to shift

    elem *l2;
    elem *r2;
    elem *eres =  el_bin(OPeq,t,
                l,
                el_bin(OPor,t,
                        el_bin(OPshl,t,
                                (r2 = el_bin(OPand,t,r,el_long(t,m))),
                                el_long(TYint,b)
                        ),
                        el_bin(OPand,t,
                                (l2 = el_copytree(l)),
                                el_long(t,~(m << b))
                        )
                )
          );
    eres.Esrcpos = e.Esrcpos;           // save line information
    if (OPTIMIZER && w + b == sz)
        r2.EV.E2.EV.Vllong = ~ZEROLL;    // no need to mask if left justified
    if (wantres)
    {
        uint c;
        elem **pe;
        elem *e2;

        r = el_copytree(r);
        if (tyuns(tyl))                 /* uint bit field           */
        {
            e2 = el_bin(OPand,t,r,el_long(t,m));
            pe = &e2.EV.E1;
        }
        else                            /* signed bit field             */
        {
            c = sz - w;                 /* e2 = (r << c) >> c           */
            e2 = el_bin(OPshr,t,el_bin(OPshl,tyl,r,el_long(TYint,c)),el_long(TYint,c));
            pe = &e2.EV.E1.EV.E1;
        }
        eres = el_bin(OPcomma,t,eres,e2);
        if (!OTleaf(r.Eoper))
            fixside(&(r2.EV.E1),pe);
    }

    if (!OTleaf(l.Eoper) && !OTleaf(l.EV.E1.Eoper))
        fixside(&(l2.EV.E1),&(l.EV.E1));
    e1.EV.E1 = e.EV.E2 = null;
    el_free(e);
    return optelem(eres,GOALvalue);
}
}

/**********************************
 */

private elem * elnegass(elem *e, goal_t goal)
{
    e = cgel_lvalue(e);
    return e;
}

/**************************
 * Add assignment. Replace bit field assignment with
 * equivalent tree.
 *             +=
 *            /  \
 *           /    r
 *        bit
 *       /   \
 *      l     w,b
 *
 * becomes:
 *                   =
 *                  / \
 *                 l   |
 *                    / \
 *                  <<   \
 *                 /  \   \
 *                &    b   &
 *               / \      / \
 *             op   m    l   ~(m<<b)
 *            /  \
 *           &    r
 *          / \
 *        >>   m
 *       /  \
 *      l    b
 */

@trusted
private elem * elopass(elem *e, goal_t goal)
{
    elem *e1 = e.EV.E1;
    if (OTconv(e1.Eoper))
    {   e = fixconvop(e);
        return optelem(e,GOALvalue);
    }
version (SCPP)   // have bit fields to worry about?
{
    goal_t wantres = goal;
    if (e1.Eoper == OPbit)
    {
        const op = opeqtoop(e.Eoper);

        // Make sure t is uint
        // so >> doesn't have to be masked
        tym_t t = touns(e.Ety);

        assert(tyintegral(t));
        elem *l = e1.EV.E1;                       // lvalue
        tym_t tyl = l.Ety;
        elem *r = e.EV.E2;
        uint w = (e1.EV.E2.EV.Vuns >> 8) & 0xFF; // width in bits of field
        targ_llong m = (cast(targ_llong)1 << w) - 1;    // mask w bits wide
        uint b = e1.EV.E2.EV.Vuns & 0xFF;        // bits to shift

        elem* l2,l3,op2,eres;

        if (tyuns(tyl))
        {
            eres = el_bin(OPeq,t,
                    l,
                    el_bin(OPor,t,
                            (op2=el_bin(OPshl,t,
                                    el_bin(OPand,t,
                                            el_bin(op,t,
                                                    el_bin(OPand,t,
                                                        el_bin(OPshr,t,
                                                            (l2=el_copytree(l)),
                                                            el_long(TYint,b)
                                                        ),
                                                        el_long(t,m)
                                                    ),
                                                    r
                                            ),
                                            el_long(t,m)
                                    ),
                                    el_long(TYint,b)
                            )),
                            el_bin(OPand,t,
                                    l3=el_copytree(l),
                                    el_long(t,~(m << b))
                            )
                    )
                );

            if (wantres)
            {
                eres = el_bin(OPcomma,t,eres,el_copytree(op2.EV.E1));
                fixside(&(op2.EV.E1),&(eres.EV.E2));
            }
        }
        else
        {   /* signed bit field
               rewrite to:      (l bit w,b) = ((l bit w,b) op r)
             */
            e.Eoper = OPeq;
            e.EV.E2 = el_bin(op,t,el_copytree(e1),r);
            if (l.Eoper == OPind)
                fixside(&e.EV.E2.EV.E1.EV.E1.EV.E1,&l.EV.E1);
            eres = e;
            goto ret;
        }

        if (!OTleaf(l.Eoper) && !OTleaf(l.EV.E1.Eoper))
        {
            fixside(&(l2.EV.E1),&(l.EV.E1));
            el_free(l3.EV.E1);
            l3.EV.E1 = el_copytree(l.EV.E1);
        }

        e1.EV.E1 = e.EV.E2 = null;
        el_free(e);
    ret:
        e = optelem(eres,GOALvalue);
        return e;
    }
}
    {
        if (e1.Eoper == OPcomma || OTassign(e1.Eoper))
            e = cgel_lvalue(e);    // replace (e,v)op=e2 with e,(v op= e2)
        else
        {
            switch (e.Eoper)
            {
                case OPmulass:
                    e = elmul(e,GOALvalue);
                    break;

                case OPdivass:
                    // Replace r/=c with r=r/c
                    if (tycomplex(e.EV.E2.Ety) && !tycomplex(e1.Ety))
                    {
                        elem *ed;
                        e.Eoper = OPeq;
                        if (e1.Eoper == OPind)
                        {   // ed: *(tmp=e1.EV.E1)
                            // e1: *tmp
                            elem *tmp = el_alloctmp(e1.EV.E1.Ety);
                            ed = el_bin(OPeq, tmp.Ety, tmp, e1.EV.E1);
                            e1.EV.E1 = el_copytree(tmp);
                            ed = el_una(OPind, e1.Ety, ed);
                        }
                        else
                            ed = el_copytree(e1);
                        // e: e1=ed/e2
                        e.EV.E2 = el_bin(OPdiv, e.EV.E2.Ety, ed, e.EV.E2);
                        if (tyreal(e1.Ety))
                            e.EV.E2 = el_una(OPc_r, e1.Ety, e.EV.E2);
                        else
                            e.EV.E2 = el_una(OPc_i, e1.Ety, e.EV.E2);
                        return optelem(e, GOALvalue);
                    }
                    // Replace x/=y with x=x/y
                    if (OPTIMIZER &&
                        tyintegral(e.EV.E1.Ety) &&
                        e.EV.E1.Eoper == OPvar &&
                        !el_sideeffect(e.EV.E1))
                    {
                        e.Eoper = OPeq;
                        e.EV.E2 = el_bin(OPdiv, e.EV.E2.Ety, el_copytree(e.EV.E1), e.EV.E2);
                        return optelem(e, GOALvalue);
                    }
                    e = eldiv(e, GOALvalue);
                    break;

                case OPmodass:
                    // Replace x%=y with x=x%y
                    if (OPTIMIZER &&
                        tyintegral(e.EV.E1.Ety) &&
                        e.EV.E1.Eoper == OPvar &&
                        !el_sideeffect(e.EV.E1))
                    {
                        e.Eoper = OPeq;
                        e.EV.E2 = el_bin(OPmod, e.EV.E2.Ety, el_copytree(e.EV.E1), e.EV.E2);
                        return optelem(e, GOALvalue);
                    }
                    break;

                default:
                    break;
            }
        }
    }
    return e;
}

/**************************
 * Add assignment. Replace bit field post assignment with
 * equivalent tree.
 *      (l bit w,b) ++ r
 * becomes:
 *      (((l bit w,b) += r) - r) & m
 */

@trusted
private elem * elpost(elem *e, goal_t goal)
{
    elem *e1 = e.EV.E1;
    if (e1.Eoper != OPbit)
    {
        if (e1.Eoper == OPcomma || OTassign(e1.Eoper))
            return cgel_lvalue(e);    // replace (e,v)op=e2 with e,(v op= e2)
        return e;
    }

    assert(e.EV.E2.Eoper == OPconst);
    targ_llong r = el_tolong(e.EV.E2);

    uint w = (e1.EV.E2.EV.Vuns >> 8) & 0xFF;  // width in bits of field
    targ_llong m = (cast(targ_llong)1 << w) - 1;     // mask w bits wide

    tym_t ty = e.Ety;
    if (e.Eoper != OPpostinc)
        r = -r;
    e.Eoper = (e.Eoper == OPpostinc) ? OPaddass : OPminass;
    e = el_bin(OPmin,ty,e,el_long(ty,r));
    if (tyuns(e1.EV.E1.Ety))             /* if uint bit field        */
        e = el_bin(OPand,ty,e,el_long(ty,m));
    return optelem(e,GOALvalue);
}

/***************************
 * Take care of compares.
 *      (e == 0) => (!e)
 *      (e != 0) => (bool e)
 */

@trusted
private elem * elcmp(elem *e, goal_t goal)
{
    elem *e2 = e.EV.E2;
    elem *e1 = e.EV.E1;

    //printf("elcmp(%p)\n",e); elem_print(e);

    if (OPTIMIZER)
    {
        auto op = e.Eoper;

        // Convert comparison of OPrelconsts of the same symbol to comparisons
        // of their offsets.
        if (e1.Eoper == OPrelconst && e2.Eoper == OPrelconst &&
            e1.EV.Vsym == e2.EV.Vsym)
        {
            e1.Eoper = OPconst;
            e1.Ety = TYptrdiff;
            e2.Eoper = OPconst;
            e2.Ety = TYptrdiff;
            return optelem(e,GOALvalue);
        }

        // Convert comparison of long pointers to comparison of integers
        if ((op == OPlt || op == OPle || op == OPgt || op == OPge) &&
            tyfv(e2.Ety) && tyfv(e1.Ety))
        {
            e.EV.E1 = el_una(OP32_16,e.Ety,e1);
            e.EV.E2 = el_una(OP32_16,e.Ety,e2);
            return optelem(e,GOALvalue);
        }

        // Convert ((e & 1) == 1) => (e & 1)
        if (op == OPeqeq && e2.Eoper == OPconst && e1.Eoper == OPand)
        {
            elem *e12 = e1.EV.E2;

            if (e12.Eoper == OPconst && el_tolong(e2) == 1 && el_tolong(e12) == 1)
            {
                tym_t ty = e.Ety;
                tym_t ty1 = e1.Ety;
                e = el_selecte1(e);
                e.Ety = ty1;
                int sz = tysize(ty);
                for (int sz1 = tysize(ty1); sz1 != sz; sz1 = tysize(e.Ety))
                {
                    switch (sz1)
                    {
                        case 1:
                            e = el_una(OPu8_16,TYshort,e);
                            break;
                        case 2:
                            if (sz > 2)
                                e = el_una(OPu16_32,TYlong,e);
                            else
                                e = el_una(OP16_8,TYuchar,e);
                            break;
                        case 4:
                            if (sz > 2)
                                e = el_una(OPu32_64,TYshort,e);
                            else
                                e = el_una(OP32_16,TYshort,e);
                            break;
                        case 8:
                            e = el_una(OP64_32,TYlong,e);
                            break;
                        default:
                            assert(0);
                    }
                }
                e.Ety = ty;
                return optelem(e,GOALvalue);
            }
        }
    }

    int uns = tyuns(e1.Ety) | tyuns(e2.Ety);
    if (cnst(e2))
    {
        tym_t tym;
        int sz = tysize(e2.Ety);

        if (e1.Eoper == OPu16_32 && e2.EV.Vulong <= cast(targ_ulong) SHORTMASK ||
            e1.Eoper == OPs16_32 &&
            e2.EV.Vlong == cast(targ_short) e2.EV.Vlong)
        {
            tym = (uns || e1.Eoper == OPu16_32) ? TYushort : TYshort;
            e.EV.E2 = el_una(OP32_16,tym,e2);
            goto L2;
        }

        /* Try to convert to byte/word comparison for ((x & c)==d)
           when mask c essentially casts x to a smaller type
         */
        if (OPTIMIZER &&
            e1.Eoper == OPand &&
            e1.EV.E2.Eoper == OPconst &&
            sz > CHARSIZE)
        {
            OPER op;
            assert(tyintegral(e2.Ety) || typtr(e2.Ety));
            /* ending up with byte ops in A regs */
            if (!(el_tolong(e2) & ~CHARMASK) &&
                !(el_tolong(e1.EV.E2) & ~CHARMASK)
               )
            {
                if (sz == LLONGSIZE)
                {
                    e1.EV.E1 = el_una(OP64_32,TYulong,e1.EV.E1);
                    e1.EV.E1 = el_una(OP32_16,TYushort,e1.EV.E1);
                }
                else if (sz == LONGSIZE)
                    e1.EV.E1 = el_una(OP32_16,TYushort,e1.EV.E1);
                tym = TYuchar;
                op = OP16_8;
                goto L4;
            }
            if (_tysize[TYint] == SHORTSIZE && /* not a win when regs are long */
                sz == LONGSIZE &&
                !(e2.EV.Vulong & ~SHORTMASK) &&
                !(e1.EV.E2.EV.Vulong & ~SHORTMASK)
               )
            {
                tym = TYushort;
                op = OP32_16;
            L4:
                e2.Ety = tym;
                e1.Ety = tym;
                e1.EV.E2.Ety = tym;
                e1.EV.E1 = el_una(op,tym,e1.EV.E1);
                e = optelem(e,GOALvalue);
                goto ret;
            }
        }

        if (e1.Eoper == OPf_d && tysize(e1.Ety) == 8 && cast(targ_float)e2.EV.Vdouble == e2.EV.Vdouble)
        {
            /* Remove unnecessary OPf_d operator
             */
            e.EV.E1 = e1.EV.E1;
            e1.EV.E1 = null;
            el_free(e1);
            e2.Ety = e.EV.E1.Ety;
            e2.EV.Vfloat = cast(targ_float)e2.EV.Vdouble;
            return optelem(e,GOALvalue);
        }

        if (e1.Eoper == OPd_ld && tysize(e1.Ety) == tysize(TYldouble) && cast(targ_double)e2.EV.Vldouble == e2.EV.Vldouble)
        {
            /* Remove unnecessary OPd_ld operator
             */
            e.EV.E1 = e1.EV.E1;
            e1.EV.E1 = null;
            el_free(e1);
            e2.Ety = e.EV.E1.Ety;
            e2.EV.Vdouble = cast(targ_double)e2.EV.Vldouble;
            return optelem(e,GOALvalue);
        }

        /* Convert (ulong > uint.max) to (msw(ulong) != 0)
         */
        if (OPTIMIZER && I32 && e.Eoper == OPgt && sz == LLONGSIZE && e2.EV.Vullong == 0xFFFFFFFF)
        {
            e.Eoper = OPne;
            e2.Ety = TYulong;
            e2.EV.Vulong = 0;
            e.EV.E1 = el_una(OPmsw,TYulong,e1);
            e = optelem(e,GOALvalue);
            goto ret;
        }

        if (e1.Eoper == OPu8_16 && e2.EV.Vuns < 256 ||
            e1.Eoper == OPs8_16 &&
            e2.EV.Vint == cast(targ_schar) e2.EV.Vint)
        {
            tym = (uns || e1.Eoper == OPu8_16) ? TYuchar : TYschar;
            e.EV.E2 = el_una(OP16_8,tym,e2);
        L2:
            tym |= e1.Ety & ~mTYbasic;
            e.EV.E1 = el_selecte1(e1);
            e.EV.E1.Ety = tym;
            e = optelem(e,GOALvalue);
        }
        else if (!boolres(e2))
        {
            targ_int i;
            switch (e.Eoper)
            {
                case OPle:              // (u <= 0) becomes (u == 0)
                    if (!uns)
                        break;
                    goto case OPeqeq;

                case OPeqeq:
                    e.Eoper = OPnot;
                    goto L5;

                case OPgt:              // (u > 0) becomes (u != 0)
                    if (!uns)
                        break;
                    goto case OPne;

                case OPne:
                    e.Eoper = OPbool;
                L5: el_free(e2);
                    e.EV.E2 = null;
                    e = optelem(e,GOALvalue);
                    break;

                case OPge:
                    i = 1;              // (u >= 0) becomes (u,1)
                    goto L3;

                case OPlt:              // (u < 0) becomes (u,0)
                    i = 0;
                L3:
                    if (uns)
                    {
                        e2.EV.Vint = i;
                        e2.Ety = TYint;
                        e.Eoper = OPcomma;
                        e = optelem(e,GOALvalue);
                    }
                    else
                    {
                        if (tyintegral(e1.Ety) && sz == 2 * REGSIZE)
                        {
                            // Only need to examine MSW
                            tym_t ty = sz == 4 ? TYint :
                                       sz == 8 ? TYint :
                                                 TYlong;        // for TYcent's
                            e.EV.E1 = el_una(OPmsw, ty, e1);
                            e2.Ety = ty;
                            return optelem(e, GOALvalue);
                        }
                    }
                    break;

                default:
                    break;
            }
        }
        else if (OPTIMIZER && uns && tysize(e2.Ety) == 2 &&
                 cast(ushort)e2.EV.Vuns == 0x8000 &&
                 (e.Eoper == OPlt || e.Eoper == OPge)
                )
        {
            // Convert to signed comparison against 0
            tym_t ty = tybasic(e2.Ety);
            switch (_tysize[ty])
            {
                case 1:     ty = TYschar;   break;
                case 2:     ty = TYshort;   break;
                default:    assert(0);
            }
            e.Eoper ^= (OPlt ^ OPge);      // switch between them
            e2.EV.Vuns = 0;
            e2.Ety = ty | (e2.Ety & ~mTYbasic);
            e1.Ety = ty | (e1.Ety & ~mTYbasic);
        }
        else if (OPTIMIZER && e1.Eoper == OPeq &&
                 e1.EV.E2.Eoper == OPconst)
        {    // Convert ((x = c1) rel c2) to ((x = c1),(c1 rel c2)
             elem *ec = el_copytree(e1.EV.E2);
             ec.Ety = e1.Ety;
             e.EV.E1 = ec;
             e = el_bin(OPcomma,e.Ety,e1,e);
             e = optelem(e,GOALvalue);
        }
    }
    else if ((
             (e1.Eoper == OPu8_16 ||
              e1.Eoper == OPs8_16)||
             (e1.Eoper == OPu16_32 ||
              e1.Eoper == OPs16_32)
             ) &&
             e1.Eoper == e2.Eoper)
    {
        if (uns)
        {
            e1.EV.E1.Ety = touns(e1.EV.E1.Ety);
            e2.EV.E1.Ety = touns(e2.EV.E1.Ety);
        }
        e1.Ety = e1.EV.E1.Ety;
        e2.Ety = e2.EV.E1.Ety;
        e.EV.E1 = el_selecte1(e1);
        e.EV.E2 = el_selecte1(e2);
        e = optelem(e,GOALvalue);
    }
ret:
    return e;
}

/*****************************
 * Boolean operator.
 *      OPbool
 */

@trusted
private elem * elbool(elem *e, goal_t goal)
{
    //printf("elbool()\n");
    elem* e1 = e.EV.E1;
    const op = e1.Eoper;

    if (OTlogical(op) ||
        // bool bool => bool
        (tybasic(e1.Ety) == TYbool && tysize(e.Ety) == 1)
       )
        return el_selecte1(e);

    switch (op)
    {
        case OPs32_d:
        case OPs16_d:
        case OPu16_d:
        case OPu32_d:
        case OPf_d:
        case OPd_ld:
        case OPs16_32:
        case OPu16_32:
        case OPu8_16:
        case OPs8_16:
        case OPu32_64:
        case OPs32_64:
        case OPvp_fp:
        case OPcvp_fp:
        case OPnp_fp:
            e1.Eoper = e.Eoper;
            return optelem(el_selecte1(e), goal);

        default:
            break;
    }

    if (OPTIMIZER)
    {
        int shift;

        // Replace bool(x,1) with (x,1),1
        e1 = elscancommas(e1);
        if (cnst(e1) || e1.Eoper == OPrelconst)
        {
            int i = boolres(e1) != 0;
            e.Eoper = OPcomma;
            e.EV.E2 = el_long(e.Ety,i);
            e = optelem(e,GOALvalue);
            return e;
        }

        // Replace bool(e & 1) with (uint char)(e & 1)
        else if (e.EV.E1.Eoper == OPand && e.EV.E1.EV.E2.Eoper == OPconst && el_tolong(e.EV.E1.EV.E2) == 1)
        {
        L1:
            uint sz = tysize(e.EV.E1.Ety);
            tym_t ty = e.Ety;
            switch (sz)
            {
                case 1:
                    e = el_selecte1(e);
                    break;

                case 2:
                    e.Eoper = OP16_8;
                    break;

                case 4:
                    e.Eoper = OP32_16;
                    e.Ety = TYushort;
                    e = el_una(OP16_8, ty, e);
                    break;

                case 8:
                    e.Eoper = OP64_32;
                    e.Ety = TYulong;
                    e = el_una(OP32_16, TYushort, e);
                    e = el_una(OP16_8, ty, e);
                    break;

                default:
                    assert(0);
            }
            e = optelem(e,GOALvalue);
        }

        // Replace bool(e % 2) with (uint char)(e & 1)
        else if (e.EV.E1.Eoper == OPmod && e.EV.E1.EV.E2.Eoper == OPconst && el_tolong(e.EV.E1.EV.E2) == 2
            && !tyfloating(e.EV.E1.Ety)) // dont optimize fmod()
        {
            uint sz = tysize(e.EV.E1.Ety);
            tym_t ty = e.Ety;
            e.EV.E1.Eoper = OPand;
            e.EV.E1.EV.E2.EV.Vullong = 1;
            switch (sz)
            {
                case 1:
                    e = el_selecte1(e);
                    break;

                case 2:
                    e.Eoper = OP16_8;
                    break;

                case 4:
                    e.Eoper = OP32_16;
                    e.Ety = TYushort;
                    e = el_una(OP16_8, ty, e);
                    break;

                case 8:
                    e.Eoper = OP64_32;
                    e.Ety = TYulong;
                    e = el_una(OP32_16, TYushort, e);
                    e = el_una(OP16_8, ty, e);
                    break;

                default:
                    assert(0);
            }
            e = optelem(e,GOALvalue);
        }

        // Replace bool((1<<c)&b) with -(b btst c)
        else if ((I32 || I64) &&
                 e.EV.E1.Eoper == OPand &&
                 e.EV.E1.EV.E1.Eoper == OPshl &&
                 e.EV.E1.EV.E1.EV.E1.Eoper == OPconst && el_tolong(e.EV.E1.EV.E1.EV.E1) == 1 &&
                 tysize(e.EV.E1.Ety) <= REGSIZE
                )
        {
            tym_t ty = e.Ety;
            elem *ex = e.EV.E1.EV.E1;
            ex.Eoper = OPbtst;
            e.EV.E1.EV.E1 = null;
            ex.EV.E1 = e.EV.E1.EV.E2;
            e.EV.E1.EV.E2 = null;
            ex.Ety = e.Ety;
            el_free(e);
            e = ex;
            return optelem(e,GOALvalue);
        }

        // Replace bool(a & c) when c is a power of 2 with ((a >> shift) & 1)
        else if (e.EV.E1.Eoper == OPand &&
                 e.EV.E1.EV.E2.Eoper == OPconst &&
                 (shift = ispow2(el_tolong(e.EV.E1.EV.E2))) != -1
                )
        {
            e.EV.E1.EV.E1 = el_bin(OPshr, e.EV.E1.EV.E1.Ety, e.EV.E1.EV.E1, el_long(TYint, shift));
            e.EV.E1.EV.E2.EV.Vullong = 1;
            goto L1;
        }
    }
    return e;
}


/*********************************
 * Conversions of pointers to far pointers.
 */

@trusted
private elem * elptrlptr(elem *e, goal_t goal)
{
    if (e.EV.E1.Eoper == OPrelconst || e.EV.E1.Eoper == OPstring)
    {
        e.EV.E1.Ety = e.Ety;
        e = el_selecte1(e);
    }
    return e;
}


/*********************************
 * Conversions of handle pointers to far pointers.
 */
@trusted
private elem * elvptrfptr(elem *e, goal_t goal)
{
    elem *e1 = e.EV.E1;
    if (e1.Eoper == OPadd || e1.Eoper == OPmin)
    {
        elem *e12 = e1.EV.E2;
        if (tybasic(e12.Ety) != TYvptr)
        {
            /* Rewrite (vtof(e11 + e12)) to (vtof(e11) + e12)   */
            const op = e.Eoper;
            e.Eoper = e1.Eoper;
            e.EV.E2 = e12;
            e1.Ety = e.Ety;
            e1.Eoper = cast(ubyte)op;
            e1.EV.E2 = null;
            e = optelem(e,GOALvalue);
        }
    }
    return e;
}


/************************
 * Optimize conversions of longs to ints.
 * Also used for (OPoffset) (TYfptr|TYvptr).
 * Also used for conversions of ints to bytes.
 */

@trusted
private elem * ellngsht(elem *e, goal_t goal)
{
    //printf("ellngsht()\n");
    tym_t ty = e.Ety;
    elem *e1 = e.EV.E1;
    switch (e1.Eoper)
    {
    case OPs16_32:
    case OPu16_32:
    case OPu8_16:
    case OPs8_16:
        // This fix is not quite right. For example, it fails
        // if e.Ety != e.EV.E1.EV.E1.Ety. The difference is when
        // one is uint and the other isn't.
        if (tysize(ty) != tysize(e.EV.E1.EV.E1.Ety))
            break;
        e = el_selecte1(el_selecte1(e));
        e.Ety = ty;
        return e;

    case OPvar:                 // simply paint type of variable
        // Do not paint type of ints into bytes, as this causes
        // many CSEs to be missed, resulting in bad code.
        // Loading a word anyway is just as fast as loading a byte.
        // for 68000 byte is swapped, load byte != load word
        if (e.Eoper == OP16_8)
        {
            // Mark symbol as being used sometimes as a byte to
            // 80X86 - preclude using SI or DI
            // 68000 - preclude using An
            e1.EV.Vsym.Sflags |= GTbyte;
        }
        else
            e1.Ety = ty;
        e = el_selecte1(e);
        break;

    case OPind:
        e = el_selecte1(e);
        break;

    case OPnp_fp:
        if (e.Eoper != OPoffset)
            goto case_default;
        // Replace (offset)(ptrlptr)e11 with e11
        e = el_selecte1(el_selecte1(e));
        e.Ety = ty;                    // retain original type
        break;

    case OPbtst:
        e = el_selecte1(e);
        break;

    default: // operator
    case_default:
        // Attempt to replace (lngsht)(a op b) with
        // ((lngsht)a op (lngsht)b).
        // op is now an integer op, which is cheaper.
        if (OTwid(e1.Eoper) && !OTassign(e1.Eoper))
        {
            tym_t ty1 = e1.EV.E1.Ety;
            switch (e.Eoper)
            {
                case OP16_8:
                    // Make sure e1.EV.E1 is of the type we're converting from
                    if (tysize(ty1) <= _tysize[TYint])
                    {
                        ty1 = (tyuns(ty1) ? TYuchar : TYschar) |
                                    (ty1 & ~mTYbasic);
                        e1.EV.E1 = el_una(e.Eoper,ty1,e1.EV.E1);
                    }
                    // Rvalue may be an int if it is a shift operator
                    if (OTbinary(e1.Eoper))
                    {   tym_t ty2 = e1.EV.E2.Ety;

                        if (tysize(ty2) <= _tysize[TYint])
                        {
                            ty2 = (tyuns(ty2) ? TYuchar : TYschar) |
                                        (ty2 & ~mTYbasic);
                            e1.EV.E2 = el_una(e.Eoper,ty2,e1.EV.E2);
                        }
                    }
                    break;

                case OPoffset:
                    if (_tysize[TYint] == LONGSIZE)
                    {
                        // Make sure e1.EV.E1 is of the type we're converting from
                        if (tysize(ty1) > LONGSIZE)
                        {
                            ty1 = (tyuns(ty1) ? TYuint : TYint) | (ty1 & ~mTYbasic);
                            e1.EV.E1 = el_una(e.Eoper,ty1,e1.EV.E1);
                        }
                        // Rvalue may be an int if it is a shift operator
                        if (OTbinary(e1.Eoper))
                        {   tym_t ty2 = e1.EV.E2.Ety;

                            if (tysize(ty2) > LONGSIZE)
                            {
                                ty2 = (tyuns(ty2) ? TYuint : TYint) |
                                            (ty2 & ~mTYbasic);
                                e1.EV.E2 = el_una(e.Eoper,ty2,e1.EV.E2);
                            }
                        }
                        break;
                    }
                    goto case OP32_16;

                case OP32_16:
                    // Make sure e1.EV.E1 is of the type we're converting from
                    if (tysize(ty1) == LONGSIZE)
                    {
                        ty1 = (tyuns(ty1) ? TYushort : TYshort) | (ty1 & ~mTYbasic);
                        e1.EV.E1 = el_una(e.Eoper,ty1,e1.EV.E1);
                    }
                    // Rvalue may be an int if it is a shift operator
                    if (OTbinary(e1.Eoper))
                    {   tym_t ty2 = e1.EV.E2.Ety;

                        if (tysize(ty2) == LONGSIZE)
                        {
                            ty2 = (tyuns(ty2) ? TYushort : TYshort) |
                                        (ty2 & ~mTYbasic);
                            e1.EV.E2 = el_una(e.Eoper,ty2,e1.EV.E2);
                        }
                    }
                    break;

                default:
                    assert(0);
            }
            e1.Ety = ty;
            e = el_selecte1(e);
            again = 1;
            return e;
        }
        break;
    }
    return e;
}


/************************
 * Optimize conversions of long longs to ints.
 * OP64_32, OP128_64
 */

@trusted
private elem * el64_32(elem *e, goal_t goal)
{
    tym_t ty = e.Ety;
    elem *e1 = e.EV.E1;
    switch (e1.Eoper)
    {
    case OPs32_64:
    case OPu32_64:
    case OPs64_128:
    case OPu64_128:
        if (tysize(ty) != tysize(e.EV.E1.EV.E1.Ety))
            break;
        e = el_selecte1(el_selecte1(e));
        e.Ety = ty;
        break;

    case OPpair:
        if (tysize(ty) != tysize(e.EV.E1.EV.E1.Ety))
            break;
        if (el_sideeffect(e1.EV.E2))
        {
            // Rewrite (OP64_32(a pair b)) as ((t=a),(b,t))
            elem *a = e1.EV.E1;
            elem *b = e1.EV.E2;
            elem *t = el_alloctmp(a.Ety);

            e.Eoper = OPcomma;
            e.EV.E1 = el_bin(OPeq,a.Ety,t,a);
            e.EV.E2 = e1;

            e1.Eoper = OPcomma;
            e1.EV.E1 = b;
            e1.EV.E2 = el_copytree(t);
            e1.Ety = e.Ety;
            break;
        }
        e = el_selecte1(el_selecte1(e));
        e.Ety = ty;
        break;

    case OPrpair:
        if (tysize(ty) != tysize(e.EV.E1.EV.E2.Ety))
            break;
        if (el_sideeffect(e1.EV.E1))
        {
            // Rewrite (OP64_32(a rpair b)) as (a,b)
            e = el_selecte1(e);
            e.Eoper = OPcomma;
            e.Ety = ty;
            break;
        }
        e = el_selecte2(el_selecte1(e));
        e.Ety = ty;
        break;

    case OPvar:                 // simply paint type of variable
    case OPind:
        e = el_selecte1(e);
        break;

    case OPshr:                 // OP64_32(x >> 32) => OPmsw(x)
        if (e1.EV.E2.Eoper == OPconst &&
            (e.Eoper == OP64_32 && el_tolong(e1.EV.E2) == 32 && !I64 ||
             e.Eoper == OP128_64 && el_tolong(e1.EV.E2) == 64 && I64)
           )
        {
            e.Eoper = OPmsw;
            e.EV.E1 = el_selecte1(e.EV.E1);
        }
        break;

    case OPmul:
        if (config.exe & (EX_OSX | EX_OSX64)) // https://issues.dlang.org/show_bug.cgi?id=21047
            break;
        else
            goto case;

    case OPadd:
    case OPmin:
    case OPor:
    case OPand:
    case OPxor:
        // OP64_32(a op b) => (OP64_32(a) op OP64_32(b))
        e1.EV.E1 = el_una(e.Eoper, ty, e1.EV.E1);
        e1.EV.E2 = el_una(e.Eoper, ty, e1.EV.E2);
        e = el_selecte1(e);
        break;

    default:
        break;
    }
    return e;
}


/*******************************
 * Convert complex to real.
 */

@trusted
private elem *elc_r(elem *e, goal_t goal)
{
    elem *e1 = e.EV.E1;

    if (e1.Eoper == OPvar || e1.Eoper == OPind)
    {
        e1.Ety = e.Ety;
        e = el_selecte1(e);
    }
    return e;
}

/*******************************
 * Convert complex to imaginary.
 */

@trusted
private elem *elc_i(elem *e, goal_t goal)
{
    elem *e1 = e.EV.E1;

    if (e1.Eoper == OPvar)
    {
        e1.Ety = e.Ety;
        e1.EV.Voffset += tysize(e.Ety);
        e = el_selecte1(e);
    }
    else if (e1.Eoper == OPind)
    {
        e1.Ety = e.Ety;
        e = el_selecte1(e);
        e.EV.E1 = el_bin(OPadd, e.EV.E1.Ety, e.EV.E1, el_long(TYint, tysize(e.Ety)));
        return optelem(e, GOALvalue);
    }

    return e;
}

/******************************
 * Handle OPu8_16 and OPs8_16.
 */

@trusted
private elem * elbyteint(elem *e, goal_t goal)
{
    if (OTlogical(e.EV.E1.Eoper) || e.EV.E1.Eoper == OPbtst)
    {
        e.EV.E1.Ety = e.Ety;
        e = el_selecte1(e);
        return e;
    }
    return evalu8(e, goal);
}

/******************************
 * OPs32_64
 * OPu32_64
 */
@trusted
private elem * el32_64(elem *e, goal_t goal)
{
    if (REGSIZE == 8 && e.EV.E1.Eoper == OPbtst)
    {
        e.EV.E1.Ety = e.Ety;
        e = el_selecte1(e);
        return e;
    }
    return evalu8(e, goal);
}

/****************************
 * Handle OPu64_d,
 *      OPd_ld OPu64_d,
 *      OPd_f OPu64_d
 */

@trusted
private elem *elu64_d(elem *e, goal_t goal)
{
    tym_t ty;
    elem** pu;
    if (e.Eoper == OPu64_d)
    {
        pu = &e.EV.E1;
        ty = TYdouble;
    }
    else if (e.Eoper == OPd_ld && e.EV.E1.Eoper == OPu64_d)
    {
        pu = &e.EV.E1.EV.E1;
        *pu = optelem(*pu, GOALvalue);
        ty = TYldouble;
    }
    else if (e.Eoper == OPd_f && e.EV.E1.Eoper == OPu64_d)
    {
        pu = &e.EV.E1.EV.E1;
        *pu = optelem(*pu, GOALvalue);
        ty = TYfloat;
    }

    if (!pu || (*pu).Eoper == OPconst)
        return evalu8(e, goal);

    elem* u = *pu;
    if (config.fpxmmregs && I64 && (ty == TYfloat || ty == TYdouble))
    {
        /* Rewrite for SIMD as:
         *    u >= 0 ? OPs64_d(u) : OPs64_d((u >> 1) | (u & 1)) * 2
         */
        u.Ety = TYllong;
        elem *u1 = el_copytree(u);
        if (!OTleaf(u.Eoper))
            fixside(&u, &u1);
        elem *u2 = el_copytree(u1);

        u = el_bin(OPge, TYint, u, el_long(TYllong, 0));

        u1 = el_una(OPs64_d, TYdouble, u1);
        if (ty == TYfloat)
            u1 = el_una(OPd_f, TYfloat, u1);

        elem* u3 = el_copytree(u2);
        u2 = el_bin(OPshr, TYullong, u2, el_long(TYullong, 1));
        u3 = el_bin(OPand, TYullong, u3, el_long(TYullong, 1));
        u2 = el_bin(OPor, TYllong, u2, u3);

        u2 = el_una(OPs64_d, TYdouble, u2);
        if (ty == TYfloat)
            u2 = el_una(OPd_f, TYfloat, u2);

        u2 = el_bin(OPmul, ty, u2, el_long(ty, 2));

        elem* r = el_bin(OPcond, e.Ety, u, el_bin(OPcolon, e.Ety, u1, u2));
        *pu = null;
        el_free(e);
        return optelem(r, GOALvalue);
    }
    if (config.inline8087)
    {
        /* Rewrite for x87 as:
         *  u < 0 ? OPs64_d(u) : OPs64_d(u) + 0x1p+64
         */
        u.Ety = TYllong;
        elem *u1 = el_copytree(u);
        if (!OTleaf(u.Eoper))
            fixside(&u, &u1);

        elem* eop1 = el_una(OPs64_d, TYdouble, u1);
        eop1 = el_una(OPd_ld, TYldouble, eop1);

        elem* eoff = el_calloc();
        eoff.Eoper = OPconst;
        eoff.Ety = TYldouble;
        eoff.EV.Vldouble = 0x1p+64;

        elem* u2 = el_copytree(u1);
        u2 = el_una(OPs64_d, TYdouble, u2);
        u2 = el_una(OPd_ld, TYldouble, u2);

        elem* eop2 = el_bin(OPadd, TYldouble, u2, eoff);

        elem* r = el_bin(OPcond, TYldouble,
                        el_bin(OPge, OPbool, u, el_long(TYllong, 0)),
                        el_bin(OPcolon, TYldouble, eop1, eop2));

        if (ty != TYldouble)
            r = el_una(OPtoprec, e.Ety, r);

        *pu = null;
        el_free(e);

        return optelem(r, GOALvalue);
    }

    return evalu8(e, goal);
}


/************************
 * Handle <<, OProl and OPror
 */

@trusted
private elem *elshl(elem *e, goal_t goal)
{
    tym_t ty = e.Ety;
    elem *e1 = e.EV.E1;
    elem *e2 = e.EV.E2;

    if (e1.Eoper == OPconst && !boolres(e1))             // if e1 is 0
    {
        e1.Ety = ty;
        e = el_selecte1(e);             // (0 << e2) => 0
    }
    else if (OPTIMIZER &&
        e2.Eoper == OPconst &&
        (e1.Eoper == OPshr || e1.Eoper == OPashr) &&
        e1.EV.E2.Eoper == OPconst &&
        el_tolong(e2) == el_tolong(e1.EV.E2))
    {   /* Rewrite:
         *  (x >> c) << c)
         * with:
         *  x & ~((1 << c) - 1);
         */
        targ_ullong c = el_tolong(e.EV.E2);
        e = el_selecte1(e);
        e = el_selecte1(e);
        e = el_bin(OPand, e.Ety, e, el_long(e.Ety, ~((1UL << c) - 1)));
        return optelem(e, goal);
    }
    return e;
}

/************************
 * Handle >>
 * OPshr, OPashr
 */

@trusted
private elem * elshr(elem *e, goal_t goal)
{
    tym_t ty = e.Ety;
    elem *e1 = e.EV.E1;
    elem *e2 = e.EV.E2;

    // (x >> 16) replaced with ((shtlng) x+2)
    if (OPTIMIZER &&
        e2.Eoper == OPconst && e2.EV.Vshort == SHORTSIZE * 8 &&
        tysize(ty) == LONGSIZE)
    {
        if (e1.Eoper == OPvar)
        {
            Symbol *s = e1.EV.Vsym;

            if (s.Sclass != SCfastpar && s.Sclass != SCshadowreg)
            {
                e1.EV.Voffset += SHORTSIZE; // address high word in long
                if (I32)
                    // Cannot independently address high word of register
                    s.Sflags &= ~GTregcand;
                goto L1;
            }
        }
        else if (e1.Eoper == OPind)
        {
            /* Replace (*p >> 16) with (shtlng)(*(&*p + 2))     */
            e.EV.E1 = el_una(OPind,TYshort,
                        el_bin(OPadd,e1.EV.E1.Ety,
                                el_una(OPaddr,e1.EV.E1.Ety,e1),
                                el_long(TYint,SHORTSIZE)));
        L1:
            e.Eoper = tyuns(e1.Ety) ? OPu16_32 : OPs16_32;
            el_free(e2);
            e.EV.E2 = null;
            e1.Ety = TYshort;
            e = optelem(e,GOALvalue);
        }
    }

    // (x >> 32) replaced with ((lngllng) x+4)
    if (e2.Eoper == OPconst && e2.EV.Vlong == LONGSIZE * 8 &&
        tysize(ty) == LLONGSIZE)
    {
        if (e1.Eoper == OPvar)
        {
            e1.EV.Voffset += LONGSIZE;      // address high dword in longlong
            if (I64)
                // Cannot independently address high word of register
                e1.EV.Vsym.Sflags &= ~GTregcand;
            goto L2;
        }
        else if (e1.Eoper == OPind)
        {
            // Replace (*p >> 32) with (lngllng)(*(&*p + 4))
            e.EV.E1 = el_una(OPind,TYlong,
                        el_bin(OPadd,e1.EV.E1.Ety,
                                el_una(OPaddr,e1.EV.E1.Ety,e1),
                                el_long(TYint,LONGSIZE)));
        L2:
            e.Eoper = tyuns(e1.Ety) ? OPu32_64 : OPs32_64;
            el_free(e2);
            e.EV.E2 = null;
            e1.Ety = TYlong;
            e = optelem(e,GOALvalue);
        }
    }
    return e;
}

/***********************************
 * Handle OPmsw.
 */

@trusted
elem *elmsw(elem *e, goal_t goal)
{
    tym_t ty = e.Ety;
    elem *e1 = e.EV.E1;

    if (OPTIMIZER &&
        tysize(e1.Ety) == LLONGSIZE &&
        tysize(ty) == LONGSIZE)
    {
        // Replace (int)(msw (long)x) with (int)*(&x+4)
        if (e1.Eoper == OPvar)
        {
            e1.EV.Voffset += LONGSIZE;      // address high dword in longlong
            if (I64)
                // Cannot independently address high word of register
                e1.EV.Vsym.Sflags &= ~GTregcand;
            e1.Ety = ty;
            e = optelem(e1,GOALvalue);
        }
        // Replace (int)(msw (long)*x) with (int)*(&*x+4)
        else if (e1.Eoper == OPind)
        {
            e1 = el_una(OPind,ty,
                el_bin(OPadd,e1.EV.E1.Ety,
                    el_una(OPaddr,e1.EV.E1.Ety,e1),
                    el_long(TYint,LONGSIZE)));
            e = optelem(e1,GOALvalue);
        }
        else
        {
            e = evalu8(e, goal);
        }
    }
    else if (OPTIMIZER && I64 &&
        tysize(e1.Ety) == CENTSIZE &&
        tysize(ty) == LLONGSIZE)
    {
        // Replace (long)(msw (cent)x) with (long)*(&x+8)
        if (e1.Eoper == OPvar)
        {
            e1.EV.Voffset += LLONGSIZE;      // address high dword in longlong
            e1.Ety = ty;
            e = optelem(e1,GOALvalue);
        }
        // Replace (long)(msw (cent)*x) with (long)*(&*x+8)
        else if (e1.Eoper == OPind)
        {
            e1 = el_una(OPind,ty,
                el_bin(OPadd,e1.EV.E1.Ety,
                    el_una(OPaddr,e1.EV.E1.Ety,e1),
                    el_long(TYint,LLONGSIZE)));
            e = optelem(e1,GOALvalue);
        }
        else
        {
            e = evalu8(e, goal);
        }
    }
    else
    {
        e = evalu8(e, goal);
    }

    return e;
}

/***********************************
 * Handle OPpair, OPrpair.
 */

@trusted
elem *elpair(elem *e, goal_t goal)
{
    //printf("elpair()\n");
    elem *e1 = e.EV.E1;
    if (e1.Eoper == OPconst)
    {
        e.EV.E1 = e.EV.E2;
        e.EV.E2 = e1;
        e.Eoper ^= OPpair ^ OPrpair;
    }
    return e;
}

/********************************
 * Handle OPddtor
 */

elem *elddtor(elem *e, goal_t goal)
{
    return e;
}

/********************************
 * Handle OPinfo, OPmark, OPctor, OPdtor
 */

private elem * elinfo(elem *e, goal_t goal)
{
    //printf("elinfo()\n");
    version (SCPP)
    static if (NTEXCEPTIONS)
    {
        if (funcsym_p.Sfunc.Fflags3 & Fnteh)
        {   // Eliminate cleanup info if using NT structured EH
            if (e.Eoper == OPinfo)
                e = el_selecte2(e);
            else
            {   el_free(e);
                e = el_long(TYint,0);
            }
        }
    }
    return e;
}

/********************************************
 */

private elem * elclassinit(elem *e, goal_t goal)
{
    return e;
}

/********************************************
 */

@trusted
private elem * elvalist(elem *e, goal_t goal)
{
    assert(e.Eoper == OPva_start);

    if (funcsym_p.ty() & mTYnaked)
    {   // do not generate prolog
        el_free(e);
        e = el_long(TYint, 0);
        return e;
    }

    if (I32)
    {
        // (OPva_start &va)
        // (OPeq (OPind E1) (OPptr lastNamed+T.sizeof))
        //elem_print(e);

        // Find last named parameter
        Symbol *lastNamed = null;
        Symbol *arguments_typeinfo = null;
        for (SYMIDX si = 0; si < globsym.length; si++)
        {
            Symbol *s = globsym[si];

            if (s.Sclass == SCparameter || s.Sclass == SCregpar)
                lastNamed = s;
            if (s.Sident[0] == '_' && strcmp(s.Sident.ptr, "_arguments_typeinfo") == 0)
                arguments_typeinfo = s;
        }

        if (!lastNamed)
            lastNamed = arguments_typeinfo;

        e.Eoper = OPeq;
        e.EV.E1 = el_una(OPind, TYnptr, e.EV.E1);
        if (lastNamed)
        {
            e.EV.E2 = el_ptr(lastNamed);
            e.EV.E2.EV.Voffset = (type_size(lastNamed.Stype) + 3) & ~3;
        }
        else
            e.EV.E2 = el_long(TYnptr, 0);
        // elem_print(e);

        return e;
    }

if (config.exe & EX_windos)
{
    assert(config.exe == EX_WIN64); // va_start is not an intrinsic on 32-bit

    // (OPva_start &va)
    // (OPeq (OPind E1) (OPptr &lastNamed+8))
    //elem_print(e);

    // Find last named parameter
    Symbol *lastNamed = null;
    for (SYMIDX si = 0; si < globsym.length; si++)
    {
        Symbol *s = globsym[si];

        if (s.Sclass == SCfastpar || s.Sclass == SCshadowreg)
            lastNamed = s;
    }

    e.Eoper = OPeq;
    e.EV.E1 = el_una(OPind, TYnptr, e.EV.E1);
    if (lastNamed)
    {
        e.EV.E2 = el_ptr(lastNamed);
        e.EV.E2.EV.Voffset = REGSIZE;
    }
    else
        e.EV.E2 = el_long(TYnptr, 0);
    //elem_print(e);

}

if (config.exe & EX_posix)
{
    assert(I64); // va_start is not an intrinsic on 32-bit
    // (OPva_start &va)
    // (OPeq (OPind E1) __va_argsave+offset)
    //elem_print(e);

    // Find __va_argsave
    Symbol *va_argsave = null;
    for (SYMIDX si = 0; si < globsym.length; si++)
    {
        Symbol *s = globsym[si];
        if (s.Sident[0] == '_' && strcmp(s.Sident.ptr, "__va_argsave") == 0)
        {
            va_argsave = s;
            break;
        }
    }

    e.Eoper = OPeq;
    e.EV.E1 = el_una(OPind, TYnptr, e.EV.E1);
    if (va_argsave)
    {
        e.EV.E2 = el_ptr(va_argsave);
        e.EV.E2.EV.Voffset = 6 * 8 + 8 * 16;
    }
    else
        e.EV.E2 = el_long(TYnptr, 0);
    //elem_print(e);
}

    return e;
}

/******************************************
 * OPparam
 */

@trusted
private void elparamx(elem *e)
{
    //printf("elparam()\n");
    if (e.EV.E1.Eoper == OPrpair)
    {
        e.EV.E1.Eoper = OPparam;
    }
    else if (e.EV.E1.Eoper == OPpair && !el_sideeffect(e.EV.E1))
    {
        e.EV.E1.Eoper = OPparam;
        elem *ex = e.EV.E1.EV.E2;
        e.EV.E1.EV.E2 = e.EV.E1.EV.E1;
        e.EV.E1.EV.E1 = ex;
    }
    else
    {
        static if (0)
        {
            // Unfortunately, these don't work because if the last parameter
            // is a pair, and it is a D function, the last parameter will get
            // passed in EAX.
            if (e.EV.E2.Eoper == OPrpair)
            {
                e.EV.E2.Eoper = OPparam;
            }
            else if (e.EV.E2.Eoper == OPpair)
            {
                e.EV.E2.Eoper = OPparam;
                elem *ex = e.EV.E2.EV.E2;
                e.EV.E2.EV.E2 = e.EV.E2.EV.E1;
                e.EV.E2.EV.E1 = ex;
            }
        }
    }
}

@trusted
private elem * elparam(elem *e, goal_t goal)
{
    if (!OPTIMIZER)
    {
        if (!I64)
            elparamx(e);
    }
    return e;
}

/********************************
 * Optimize an element. This routine is recursive!
 * Be careful not to do this if VBEs have been done (else the VBE
 * work will be undone), or if DAGs have been built (will crash if
 * there is more than one parent for an elem).
 * If (goal)
 *      we care about the result.
 */

@trusted
private elem * optelem(elem *e, goal_t goal)
{
beg:
    //__gshared uint count;
    //printf("count: %u\n", ++count);
    //{ printf("xoptelem: %p ",e); WROP(e.Eoper); printf(" goal x%x\n", goal); }
    assert(e);
    elem_debug(e);
    assert(e.Ecount == 0);             // no CSEs

    if (OPTIMIZER)
    {
        if (goal)
            e.Nflags &= ~NFLnogoal;
        else
            e.Nflags |= NFLnogoal;
    }

    auto op = e.Eoper;
    if (OTleaf(op))                     // if not an operator node
    {
        if (goal || OTsideff(op) || e.Ety & (mTYvolatile | mTYshared))
        {
            return e;
        }
        else
        {
            retnull:
                el_free(e);
                return null;
        }
    }
    else if (OTbinary(op))              // if binary operator
    {
        /* Determine goals for left and right subtrees  */
        goal_t leftgoal = GOALvalue;
        goal_t rightgoal = (goal || OTsideff(op)) ? GOALvalue : GOALnone;
        switch (op)
        {
            case OPcomma:
            {
                elem *e1 = e.EV.E1 = optelem(e.EV.E1,GOALnone);
//              if (e1 && !OTsideff(e1.Eoper))
//                  e1 = e.EV.E1 = optelem(e1, GOALnone);
                elem *e2 = e.EV.E2 = optelem(e.EV.E2,goal);
                if (!e1)
                {
                    if (!e2)
                        goto retnull;
                    if (!goal)
                        e.Ety = e.EV.E2.Ety;
                    e = el_selecte2(e);
                    return e;
                }
                if (!e2)
                {
                    e.Ety = e.EV.E1.Ety;
                    return el_selecte1(e);
                }
                if (!goal)
                    e.Ety = e2.Ety;
                return e;
            }

            case OPcond:
                if (!goal)
                {   // Transform x?y:z into x&&y or x||z
                    elem *e2 = e.EV.E2;
                    if (!el_sideeffect(e2.EV.E1))
                    {
                        e.Eoper = OPoror;
                        e.EV.E2 = el_selecte2(e2);
                        e.Ety = TYint;
                        goto beg;
                    }
                    else if (!el_sideeffect(e2.EV.E2))
                    {
                        e.Eoper = OPandand;
                        e.EV.E2 = el_selecte1(e2);
                        e.Ety = TYint;
                        goto beg;
                    }
                    assert(e2.Eoper == OPcolon || e2.Eoper == OPcolon2);
                    elem *e21 = e2.EV.E1 = optelem(e2.EV.E1, goal);
                    elem *e22 = e2.EV.E2 = optelem(e2.EV.E2, goal);
                    if (!e21)
                    {
                        if (!e22)
                        {
                            e = el_selecte1(e);
                            goto beg;
                        }
                        // Rewrite (e1 ? null : e22) as (e1 || e22)
                        e.Eoper = OPoror;
                        e.EV.E2 = el_selecte2(e2);
                        goto beg;
                    }
                    if (!e22)
                    {
                        // Rewrite (e1 ? e21 : null) as (e1 && e21)
                        e.Eoper = OPandand;
                        e.EV.E2 = el_selecte1(e2);
                        goto beg;
                    }
                    if (!rightgoal)
                        rightgoal = GOALvalue;
                }
                goto Llog;

            case OPoror:
                if (rightgoal)
                    rightgoal = GOALflags;
                if (OPTIMIZER && optim_loglog(&e))
                    goto beg;
                goto Llog;

            case OPandand:
                if (rightgoal)
                    rightgoal = GOALflags;
                if (OPTIMIZER && optim_loglog(&e))
                    goto beg;
                goto Llog;

            Llog:               // case (c log f()) with no goal
                if (goal || el_sideeffect(e.EV.E2))
                    leftgoal = GOALflags;
                break;

            default:
                leftgoal = rightgoal;
                break;

            case OPcolon:
            case OPcolon2:
                if (!goal && !el_sideeffect(e))
                    goto retnull;
                leftgoal = rightgoal;
                break;

            case OPmemcmp:
                if (!goal)
                {   // So OPmemcmp is removed cleanly
                    assert(e.EV.E1.Eoper == OPparam);
                    e.EV.E1.Eoper = OPcomma;
                }
                leftgoal = rightgoal;
                break;

            case OPcall:
            case OPcallns:
            {
                const tyf = tybasic(e.EV.E1.Ety);
                leftgoal = rightgoal;
                elem *e1 = e.EV.E1 = optelem(e.EV.E1, leftgoal);

                // Need argument to type_zeroSize()
                const tyf_save = global_tyf;
                global_tyf = tyf;
                elem *e2 = e.EV.E2 = optelem(e.EV.E2, rightgoal);
                global_tyf = tyf_save;

                if (!e1)
                {
                    if (!e2)
                        goto retnull;
                    return el_selecte2(e);
                }
                if (!e2)
                {
                    if (!leftgoal)
                        e.Ety = e1.Ety;
                    return el_selecte1(e);
                }
                return (*elxxx[op])(e, goal);
            }
        }

        elem *e1 = e.EV.E1;
        if (OTassign(op))
        {
            elem *ex = e1;
            while (OTconv(ex.Eoper))
                ex = ex.EV.E1;
            if (ex.Eoper == OPbit)
                ex.EV.E1 = optelem(ex.EV.E1, leftgoal);
            else if (e1.Eoper == OPu64_d)
                e1.EV.E1 = optelem(e1.EV.E1, leftgoal);
            else if ((e1.Eoper == OPd_ld || e1.Eoper == OPd_f) && e1.EV.E1.Eoper == OPu64_d)
                e1.EV.E1.EV.E1 = optelem(e1.EV.E1.EV.E1, leftgoal);
            else
                e1 = e.EV.E1 = optelem(e1,leftgoal);
        }
        else
            e1 = e.EV.E1 = optelem(e1,leftgoal);

        if ((op == OPandand || op == OPoror || op == OPcond) && e1) // short circuit evaluations
        {
            switch (op)
            {
                case OPandand:
                    if (iffalse(e1))
                    {
                        // Do not evaluate E2
                        el_free(e.EV.E2);
                        e.EV.E2 = null;
                        e.Eoper = OPbool;
                        goto beg;
                    }
                    break;

                case OPoror:
                    if (iftrue(e1))
                    {
                        // Do not evaluate E2
                        el_free(e.EV.E2);
                        e.EV.E2 = null;
                        e.Eoper = OPbool;
                        goto beg;
                    }
                    break;

                case OPcond:
                    if (iftrue(e1))
                    {
                        e.EV.E2 = el_selecte1(e.EV.E2);
                        e.EV.E2.Ety = e.Ety;
                        e.Eoper = OPcomma;
                        goto beg;
                    }
                    if (iffalse(e1))
                    {
                        e.EV.E2 = el_selecte2(e.EV.E2);
                        e.EV.E2.Ety = e.Ety;
                        e.Eoper = OPcomma;
                        goto beg;
                    }
                    break;

                default:
                    assert(0);
            }
        }

        elem *e2 = e.EV.E2 = optelem(e.EV.E2,rightgoal);
        if (!e1)
        {
            if (!e2)
                goto retnull;
            return el_selecte2(e);
        }
        if (!e2)
        {
            if (!leftgoal)
                e.Ety = e1.Ety;
            return el_selecte1(e);
        }

        if (op == OPparam && !goal)
            e.Eoper = OPcomma; // DMD bug 6733

        if (cnst(e1) && cnst(e2))
        {
            e = evalu8(e, GOALvalue);
            return e;
        }
        if (OPTIMIZER)
        {
            if (OTassoc(op))
            {
                /* Replace (a op1 (b op2 c)) with ((a op2 b) op1 c)
                   (this must come before the leaf swapping, or we could cause
                   infinite loops)
                 */
                if (e2.Eoper == op &&
                    e2.EV.E2.Eoper == OPconst &&
                    tysize(e2.EV.E1.Ety) == tysize(e2.EV.E2.Ety) &&
                    (!tyfloating(e1.Ety) || e1.Ety == e2.Ety)
                   )
                {
                  e.EV.E1 = e2;
                  e.EV.E2 = e2.EV.E2;
                  e2.EV.E2 = e2.EV.E1;
                  e2.EV.E1 = e1;
                  if (op == OPadd)  /* fix types                    */
                  {
                      e1 = e.EV.E1;
                      if (typtr(e1.EV.E2.Ety))
                          e1.Ety = e1.EV.E2.Ety;
                      else
                          /* suppose a and b are ints, and c is a pointer   */
                          /* then this will fix the type of op2 to be int   */
                          e1.Ety = e1.EV.E1.Ety;
                  }
                  goto beg;
                }

                // Replace ((a op c1) op c2) with (a op (c2 op c1))
                if (e1.Eoper == op &&
                    e2.Eoper == OPconst &&
                    e1.EV.E2.Eoper == OPconst &&
                    e1.EV.E1.Eoper != OPconst &&
                    tysize(e2.Ety) == tysize(e1.EV.E2.Ety))
                {
                    e.EV.E1 = e1.EV.E1;
                    e1.EV.E1 = e2;
                    e1.Ety = e2.Ety;
                    e.EV.E2 = e1;

                    if (tyfloating(e1.Ety))
                    {
                        e1 = evalu8(e1, GOALvalue);
                        if (!OTleaf(e1.Eoper))        // if failed to fold the constants
                        {   // Undo the changes so we don't infinite loop
                            e.EV.E2 = e1.EV.E1;
                            e1.EV.E1 = e.EV.E1;
                            e.EV.E1 = e1;
                        }
                        else
                        {   e.EV.E2 = e1;
                            goto beg;
                        }
                    }
                    else
                        goto beg;
                }
          }

          if (!OTrtol(op) && op != OPparam && op != OPcolon && op != OPcolon2 &&
              e1.Eoper == OPcomma)
          {     // Convert ((a,b) op c) to (a,(b op c))
                e1.EV.E2.Ety = e1.Ety;
                e1.EV.E2.ET = e1.ET;

                e1.Ety = e.Ety;
                e1.ET = e.ET;

                e.EV.E1 = e1.EV.E2;
                e1.EV.E2 = e;
                e = e1;
                goto beg;
          }
        }

        if (OTcommut(op))                // if commutative
        {
              /* see if we should swap the leaves       */
              version (MARS) { enum MARS = true; } else { enum MARS = false; }
              if (
                MARS ? (
                cost(e2) > cost(e1)
                /* Swap only if order of evaluation can be proved
                 * to not matter, as we must evaluate Left-to-Right
                 */
                && e1.canHappenAfter(e2)
                 )
                 : cost(e2) > cost(e1)
                 )
              {
                    e.EV.E1 = e2;
                    e2 = e.EV.E2 = e1;
                    e1 = e.EV.E1;         // reverse the leaves
                    op = e.Eoper = cast(ubyte)swaprel(op);
              }
              if (OTassoc(op))          // if commutative and associative
              {
                  if (!OTleaf(e1.Eoper) &&
                      op == e1.Eoper &&
                      e1.EV.E2.Eoper == OPconst &&
                      e.Ety == e1.Ety &&
                      tysize(e1.EV.E2.Ety) == tysize(e2.Ety)

                      // Reordering floating point can change the semantics
                      && (!MARS || !tyfloating(e1.Ety))
                     )
                  {
                        // look for ((e op c1) op c2),
                        // replace with (e op (c1 op c2))
                        if (e2.Eoper == OPconst)
                        {
                            e.EV.E1 = e1.EV.E1;
                            e.EV.E2 = e1;
                            e1.EV.E1 = e1.EV.E2;
                            e1.EV.E2 = e2;
                            e1.Ety = e2.Ety;

                            e1 = e.EV.E1;
                            e2 = e.EV.E2 = evalu8(e.EV.E2, GOALvalue);
                        }
                        else
                        {   // Replace ((e op c) op e2) with ((e op e2) op c)
                            e.EV.E2 = e1.EV.E2;
                            e1.EV.E2 = e2;
                            e2 = e.EV.E2;
                        }
                  }
              }
        }

        if (e2.Eoper == OPconst &&             // if right operand is a constant
            !(OTopeq(op) && OTconv(e1.Eoper))
           )
        {
            debug assert(!(OTeop0e(op) && (OTeop00(op))));
            if (OTeop0e(op))            /* if e1 op 0 => e1             */
            {
                if (!boolres(e2))       /* if e2 is 0                   */
                {
                    // Don't do it for ANSI floating point
                    if (tyfloating(e1.Ety) && !(config.flags4 & CFG4fastfloat))
                    { }
                    // Don't do it if we're assembling a complex value
                    else if ((tytab[e.EV.E1.Ety & 0xFF] ^
                         tytab[e.EV.E2.Ety & 0xFF]) == (TYFLreal | TYFLimaginary))
                    { }
                    else
                        return optelem(el_selecte1(e),goal);
                }
            }
            else if (OTeop00(op) && !boolres(e2) && !tyfloating(e.Ety))
            {
                if (OTassign(op))
                    op = e.Eoper = OPeq;
                else
                    op = e.Eoper = OPcomma;
            }

            if (OTeop1e(op))            /* if e1 op 1 => e1             */
            {
                if (elemisone(e2) && !tyimaginary(e2.Ety))
                    return optelem(el_selecte1(e),goal);
            }
        }

        if (OTpost(op) && !goal)
        {
            op = e.Eoper = (op == OPpostinc) ? OPaddass : OPminass;
        }
  }
  else /* unary operator */
  {
        elem* e1 = e.EV.E1;

        /* op(a,b) => a,(op b)
         */
        if (e1.Eoper == OPcomma && op != OPstrpar && op != OPddtor)
        {
            e.Eoper = e1.Eoper;
            e.EV.E1 = e1.EV.E1;
            e.EV.E2 = e1;
            e1.Eoper = op;
            e1.Ety = e.Ety;
            e1.ET = e.ET;
            e1.EV.E1 = e1.EV.E2;
            e1.EV.E2 = null;
            return optelem(e, goal);
        }

        assert(!e.EV.E2 || op == OPinfo || op == OPddtor);
        if (!goal && !OTsideff(op) && !(e.Ety & (mTYvolatile | mTYshared)))
        {
            tym_t tym = e1.Ety;

            e = el_selecte1(e);
            e.Ety = tym;
            return optelem(e,GOALnone);
        }

        if ((op == OPd_f || op == OPd_ld) && e1.Eoper == OPu64_d)
        {
            return elu64_d(e, goal);
        }

        e1 = e.EV.E1 = optelem(e1, (op == OPddtor)
                                     ? GOALnone
                                     : (op == OPbool || op == OPnot) ? GOALflags : GOALvalue);
        if (!e1)
            goto retnull;
        if (e1.Eoper == OPconst)
        {
            if (!(op == OPnp_fp && el_tolong(e1) != 0))
                return evalu8(e, GOALvalue);
        }
  }

//  if (debugb)
//  {   print("optelem: %p ",e); WROP(op); print("\n"); }

    static if (0)
    {
        {   print("xoptelem: %p ",e); WROP(e.Eoper); print("\n"); }
        elem_print(e);
        e = (*elxxx[op])(e, goal);
        printf("After:\n");
        elem_print(e);
        return e;
    }
    else
    {
        return (*elxxx[op])(e, goal);
    }
}


/********************************
 * Optimize and canonicalize an expression tree.
 * Fiddle with double operators so that the rvalue is a pointer
 * (this is needed by the 8086 code generator).
 *
 *         op                      op
 *        /  \                    /  \
 *      e1    e2                e1    ,
 *                                   / \
 *                                  =   &
 *                                 / \   \
 *                               fr   e2  fr
 *
 *      e1 op (*p)              e1 op p
 *      e1 op c                 e1 op &dc
 *      e1 op v                 e1 op &v
 */

@trusted
elem *doptelem(elem *e, goal_t goal)
{
    //printf("doptelem(e = %p, goal = x%x)\n", e, goal);
    assert(!PARSER);
    do
    {   again = false;
        topair = false;
        e = optelem(e,goal & (GOALflags | GOALvalue | GOALnone));
    } while (again && goal & GOALagain && e);

    /* If entire expression is a struct, and we can replace it with     */
    /* something simpler, do so.                                        */
    if (goal & GOALstruct && e && (tybasic(e.Ety) == TYstruct || tybasic(e.Ety) == TYarray))
        e = elstruct(e, goal);

    if (topair && e)
        e = elToPair(e);

    return e;
}

/****************************************
 * Do optimizations after bltailrecursion() and before common subexpressions.
 */

@trusted
void postoptelem(elem *e)
{
    Srcpos pos = {0};

    elem_debug(e);
    while (1)
    {
        if (OTunary(e.Eoper))
        {
            /* This is necessary as the optimizer tends to lose this information
             */
            version (MARS)
            if (e.Esrcpos.Slinnum > pos.Slinnum)
                pos = e.Esrcpos;

            if (e.Eoper == OPind)
            {
                version (MARS)
                if (e.EV.E1.Eoper == OPconst &&
                    /* Allow TYfgptr to reference GS:[0000] etc.
                     */
                    tybasic(e.EV.E1.Ety) == TYnptr)
                {
                    /* Disallow anything in the range [0..4096]
                     * Let volatile pointers dereference null
                     */
                    const targ_ullong v = el_tolong(e.EV.E1);
                    if (v < 4096 && !(e.Ety & mTYvolatile))
                    {
                        error(pos.Sfilename, pos.Slinnum, pos.Scharnum, "null dereference in function %s", funcsym_p.Sident.ptr);
                        e.EV.E1.EV.Vlong = 4096;     // suppress redundant messages
                    }
                }
            }
            e = e.EV.E1;
        }
        else if (OTbinary(e.Eoper))
        {
            /* This is necessary as the optimizer tends to lose this information
             */
            version (MARS)
            if (e.Esrcpos.Slinnum > pos.Slinnum)
                pos = e.Esrcpos;

            if (e.Eoper == OPparam)
            {
                if (!I64)
                    elparamx(e);
            }
            postoptelem(e.EV.E2);
            e = e.EV.E1;
        }
        else
            break;
    }
}

/***********************************
 * Rewrite rvalues of complex numbers to pairs of floating point numbers.
 */
@trusted
private elem *elToPair(elem *e)
{
    switch (e.Eoper)
    {
        case OPvar:
        {
            /* Rewrite complex number loads as a pair of loads
             * e => (e.0 pair e.offset)
             */
            tym_t ty0;
            tym_t ty = e.Ety;
            if (ty & (mTYxmmgpr | mTYgprxmm))
                break; // register allocation doesn't support it yet.
            switch (tybasic(ty))
            {
                case TYcfloat:      ty0 = TYfloat  | (ty & ~mTYbasic); goto L1;
                case TYcdouble:     ty0 = TYdouble | (ty & ~mTYbasic); goto L1;
                L1:
                    if (_tysize[tybasic(ty0)] < REGSIZE)
                        break;                          // func parameters, for example, can't handle this
                    e.Ety = ty0;
                    elem *e2 = el_copytree(e);
                    e2.EV.Voffset += _tysize[tybasic(ty0)];
                    return el_bin(OPpair, ty, e, e2);

                default:
                    break;
            }
            break;
        }

        case OPind:
        {
            e.EV.E1 = elToPair(e.EV.E1);
            /* Rewrite complex number loads as a pair of loads
             * *e1 => (*e1 pair *(e1 + offset))
             */
            tym_t ty0;
            tym_t ty = e.Ety;
            if (ty & (mTYxmmgpr | mTYgprxmm))
                break; // register allocation doesn't support it yet.
            switch (tybasic(ty))
            {
                case TYcfloat:      ty0 = TYfloat  | (ty & ~mTYbasic); goto L2;
                case TYcdouble:     ty0 = TYdouble | (ty & ~mTYbasic); goto L2;
                L2:
                    if (_tysize[tybasic(ty0)] < REGSIZE)
                        break;                          // func parameters, for example, can't handle this
                    e.Ety = ty0;
                    elem *e2 = el_copytree(e.EV.E1);
                    if (el_sideeffect(e2))
                        fixside(&e.EV.E1, &e2);
                    e2 = el_bin(OPadd,e2.Ety,e2,el_long(TYsize, _tysize[tybasic(ty0)]));
                    e2 = el_una(OPind, ty0, e2);
                    return el_bin(OPpair, ty, e, e2);

                default:
                    break;
            }
            break;
        }

        default:
            if (OTassign(e.Eoper))
            {
                // Skip over OPvar and OPind lvalues
                if (OTbinary(e.Eoper))
                    e.EV.E2 = elToPair(e.EV.E2);
                if (e.EV.E1.Eoper == OPvar)
                {
                }
                else if (e.EV.E1.Eoper == OPind)
                    e.EV.E1.EV.E1 = elToPair(e.EV.E1.EV.E1);
                else
                    e.EV.E1 = elToPair(e.EV.E1);
            }
            else if (OTunary(e.Eoper))
            {
                e.EV.E1 = elToPair(e.EV.E1);
            }
            else if (OTbinary(e.Eoper))
            {
                e.EV.E2 = elToPair(e.EV.E2);
                e.EV.E1 = elToPair(e.EV.E1);
            }
            break;
    }
    return e;
}

/******************************************
 * Determine if `b` can be moved before `a` without disturbing
 * order-of-evaluation semantics.
 */

@trusted
private bool canHappenAfter(elem* a, elem* b)
{
    return a.Eoper == OPconst ||
           a.Eoper == OPrelconst ||

           /* a is a variable that is not aliased
            * and is not assigned to in b
            */
           (a.Eoper == OPvar && a.EV.Vsym.Sflags & SFLunambig && !el_appears(b, a.EV.Vsym)) ||

           !(el_sideeffect(a) || el_sideeffect(b));
}


/***************************************************
 * Call table, index is OPER
 */

private extern (C++) alias elfp_t = elem *function(elem *, goal_t) nothrow;

private extern (D) immutable elfp_t[OPMAX] elxxx =
[
    OPunde:    &elerr,
    OPadd:     &eladd,
    OPmul:     &elmul,
    OPand:     &elbitwise,
    OPmin:     &elmin,
    OPnot:     &elnot,
    OPcom:     &elcom,
    OPcond:    &elcond,
    OPcomma:   &elcomma,
    OPremquo:  &elremquo,
    OPdiv:     &eldiv,
    OPmod:     &elmod,
    OPxor:     &elxor,
    OPstring:  &elstring,
    OPrelconst: &elzot,
    OPinp:     &elzot,
    OPoutp:    &elzot,
    OPasm:     &elzot,
    OPinfo:    &elinfo,
    OPdctor:   &elzot,
    OPddtor:   &elddtor,
    OPctor:    &elinfo,
    OPdtor:    &elinfo,
    OPmark:    &elinfo,
    OPvoid:    &elzot,
    OPhalt:    &elzot,
    OPnullptr: &elerr,
    OPpair:    &elpair,
    OPrpair:   &elpair,

    OPor:      &elor,
    OPoror:    &eloror,
    OPandand:  &elandand,
    OProl:     &elshl,
    OPror:     &elshl,
    OPshl:     &elshl,
    OPshr:     &elshr,
    OPashr:    &elshr,
    OPbit:     &elbit,
    OPind:     &elind,
    OPaddr:    &eladdr,
    OPneg:     &elneg,
    OPuadd:    &elzot,
    OPabs:     &evalu8,
    OPsqrt:    &evalu8,
    OPsin:     &evalu8,
    OPcos:     &evalu8,
    OPscale:   &elzot,
    OPyl2x:    &elzot,
    OPyl2xp1:  &elzot,
    OPcmpxchg:     &elzot,
    OPtoprec:  &elzot,
    OPrint:    &evalu8,
    OPrndtol:  &evalu8,
    OPstrlen:  &elzot,
    OPstrcpy:  &elstrcpy,
    OPmemcpy:  &elmemcpy,
    OPmemset:  &elmemset,
    OPstrcat:  &elzot,
    OPstrcmp:  &elstrcmp,
    OPmemcmp:  &elmemcmp,
    OPsetjmp:  &elzot,
    OPnegass:  &elnegass,
    OPpreinc:  &elzot,
    OPpredec:  &elzot,
    OPstreq:   &elstruct,
    OPpostinc: &elpost,
    OPpostdec: &elpost,
    OPeq:      &eleq,
    OPaddass:  &elopass,
    OPminass:  &elopass,
    OPmulass:  &elopass,
    OPdivass:  &elopass,
    OPmodass:  &elopass,
    OPshrass:  &elopass,
    OPashrass: &elopass,
    OPshlass:  &elopass,
    OPandass:  &elopass,
    OPxorass:  &elopass,
    OPorass:   &elopass,

    OPle:      &elcmp,
    OPgt:      &elcmp,
    OPlt:      &elcmp,
    OPge:      &elcmp,
    OPeqeq:    &elcmp,
    OPne:      &elcmp,

    OPunord:   &elcmp,
    OPlg:      &elcmp,
    OPleg:     &elcmp,
    OPule:     &elcmp,
    OPul:      &elcmp,
    OPuge:     &elcmp,
    OPug:      &elcmp,
    OPue:      &elcmp,
    OPngt:     &elcmp,
    OPnge:     &elcmp,
    OPnlt:     &elcmp,
    OPnle:     &elcmp,
    OPord:     &elcmp,
    OPnlg:     &elcmp,
    OPnleg:    &elcmp,
    OPnule:    &elcmp,
    OPnul:     &elcmp,
    OPnuge:    &elcmp,
    OPnug:     &elcmp,
    OPnue:     &elcmp,

    OPvp_fp:   &elvptrfptr,
    OPcvp_fp:  &elvptrfptr,
    OPoffset:  &ellngsht,
    OPnp_fp:   &elptrlptr,
    OPnp_f16p: &elzot,
    OPf16p_np: &elzot,

    OPs16_32:  &evalu8,
    OPu16_32:  &evalu8,
    OPd_s32:   &evalu8,
    OPb_8:     &evalu8,
    OPs32_d:   &evalu8,
    OPd_s16:   &evalu8,
    OPs16_d:   &evalu8,
    OPd_u16:   &evalu8,
    OPu16_d:   &evalu8,
    OPd_u32:   &evalu8,
    OPu32_d:   &evalu8,
    OP32_16:   &ellngsht,
    OPd_f:     &evalu8,
    OPf_d:     &evalu8,
    OPd_ld:    &evalu8,
    OPld_d:    &evalu8,
    OPc_r:     &elc_r,
    OPc_i:     &elc_i,
    OPu8_16:   &elbyteint,
    OPs8_16:   &elbyteint,
    OP16_8:    &ellngsht,
    OPu32_64:  &el32_64,
    OPs32_64:  &el32_64,
    OP64_32:   &el64_32,
    OPu64_128: &evalu8,
    OPs64_128: &evalu8,
    OP128_64:  &el64_32,
    OPmsw:     &elmsw,

    OPd_s64:   &evalu8,
    OPs64_d:   &evalu8,
    OPd_u64:   &evalu8,
    OPu64_d:   &elu64_d,
    OPld_u64:  &evalu8,
    OPparam:   &elparam,
    OPsizeof:  &elzot,
    OParrow:   &elzot,
    OParrowstar: &elzot,
    OPcolon:   &elzot,
    OPcolon2:  &elzot,
    OPbool:    &elbool,
    OPcall:    &elcall,
    OPucall:   &elcall,
    OPcallns:  &elcall,
    OPucallns: &elcall,
    OPstrpar:  &elstruct,
    OPstrctor: &elzot,
    OPstrthis: &elzot,
    OPconst:   &elerr,
    OPvar:     &elerr,
    OPreg:     &elerr,
    OPnew:     &elerr,
    OPanew:    &elerr,
    OPdelete:  &elerr,
    OPadelete: &elerr,
    OPbrack:   &elerr,
    OPframeptr: &elzot,
    OPgot:     &elzot,

    OPbsf:     &elzot,
    OPbsr:     &elzot,
    OPbtst:    &elzot,
    OPbt:      &elzot,
    OPbtc:     &elzot,
    OPbtr:     &elzot,
    OPbts:     &elzot,

    OPbswap:   &evalu8,
    OPpopcnt:  &evalu8,
    OPvector:  &elzot,
    OPvecsto:  &elzot,
    OPvecfill: &elzot,
    OPva_start: &elvalist,
    OPprefetch: &elzot,
];

}
