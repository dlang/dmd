/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/elem.d, backend/elem.d)
 */

/* Routines to handle elems.                    */

module dmd.backend.elem;

version (SCPP)
{
    version = COMPILE;
    version = SCPP_HTOD;
}
version (HTOD)
{
    version = COMPILE;
    version = SCPP_HTOD;
}
version (MARS)
{
    version = COMPILE;
    enum HYDRATE = false;
    enum DEHYDRATE = false;
}

version (COMPILE)
{

import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.cgcv;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.dlist;
import dmd.backend.dt;
import dmd.backend.dvec;
import dmd.backend.el;
import dmd.backend.evalu8 : el_toldoubled;
import dmd.backend.global;
import dmd.backend.goh;
import dmd.backend.mem;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.rtlsym;
import dmd.backend.ty;
import dmd.backend.type;

version (SCPP_HTOD)
{
    import msgs2;
    import parser;
    import precomp;
}

version (CRuntime_Microsoft)
{
    import dmd.root.longdouble;
}

/+
version (CRuntime_Microsoft) extern (C++)
{
    alias real_t = real;
    private struct longdouble_soft { real_t r; }
    size_t ld_sprint(char* str, int fmt, longdouble_soft x);
}
+/

extern (C++):

nothrow:
@safe:

alias MEM_PH_MALLOC = mem_malloc;
alias MEM_PH_CALLOC = mem_calloc;
alias MEM_PH_FREE = mem_free;
alias MEM_PH_FREEFP = mem_freefp;
alias MEM_PH_STRDUP = mem_strdup;
alias MEM_PH_REALLOC = mem_realloc;
alias MEM_PARF_MALLOC = mem_malloc;
alias MEM_PARF_CALLOC = mem_calloc;
alias MEM_PARF_REALLOC = mem_realloc;
alias MEM_PARF_FREE = mem_free;
alias MEM_PARF_STRDUP = mem_strdup;

int REGSIZE();

version (STATS)
{
private __gshared
{
    int elfreed = 0;                 /* number of freed elems        */
    int eprm_cnt;                    /* max # of allocs at any point */
}
}

/*******************************
 * Do our own storage allocation of elems.
 */

private __gshared
{
    elem *nextfree = null;           /* pointer to next free elem    */

    int elcount = 0;                 /* number of allocated elems    */
    int elem_size = elem.sizeof;

    debug
    int elmax;                       /* max # of allocs at any point */
}

/////////////////////////////
// Table to gather redundant strings in.

struct STAB
{
    Symbol *sym;        // symbol that refers to the string
    char[] str;         // the string
}

private __gshared
{
    STAB[16] stable;
    int stable_si;
}

/************************
 * Initialize el package.
 */

@trusted
void el_init()
{
    if (!configv.addlinenumbers)
        elem_size = elem.sizeof - Srcpos.sizeof;
}

/*******************************
 * Initialize for another run through.
 */

@trusted
void el_reset()
{
    stable_si = 0;
    for (int i = 0; i < stable.length; i++)
        mem_free(stable[i].str.ptr);
    memset(stable.ptr,0,stable.sizeof);
}

/************************
 * Terminate el package.
 */

@trusted
void el_term()
{
    static if (TERMCODE)
    {
        for (int i = 0; i < stable.length; i++)
            mem_free(stable[i].str.ptr);

        debug printf("Max # of elems = %d\n",elmax);

        if (elcount != 0)
            printf("unfreed elems = %d\n",elcount);
        while (nextfree)
        {
            elem *e;
            e = nextfree.EV.E1;
            mem_ffree(nextfree);
            nextfree = e;
        }
    }
    else
    {
        assert(elcount == 0);
    }
}

/***********************
 * Allocate an element.
 */

@trusted
elem *el_calloc()
{
    elem *e;

    elcount++;
    if (nextfree)
    {
        e = nextfree;
        nextfree = e.EV.E1;
    }
    else
        e = cast(elem *) mem_fmalloc(elem.sizeof);

    version (STATS)
        eprm_cnt++;

    //MEMCLEAR(e, (*e).sizeof);
    memset(e, 0, (*e).sizeof);

    debug
    {
        e.id = elem.IDelem;
        if (elcount > elmax)
            elmax = elcount;
    }
    /*printf("el_calloc() = %p\n",e);*/
    return e;
}


/***************
 * Free element
 */
@trusted
void el_free(elem *e)
{
L1:
    if (!e) return;
    elem_debug(e);
    //printf("el_free(%p)\n",e);
    //elem_print(e);
    version (SCPP_HTOD)
    {
        tym_t ty;
        if (PARSER)
        {
            ty = e.ET ? e.ET.Tty : 0;
            type_free(e.ET);
        }
        else if (e.Ecount--)
            return;                         // usage count
    }
    else
    {
        if (e.Ecount--)
            return;                         // usage count
    }
    elcount--;
    const op = e.Eoper;
    switch (op)
    {
        case OPconst:
            break;

        case OPvar:
            break;

        case OPrelconst:
            version (SCPP_HTOD)
            if (0 && PARSER && tybasic(ty) == TYmemptr)
                el_free(e.EV.ethis);
            break;

        case OPstring:
        case OPasm:
            mem_free(e.EV.Vstring);
            break;

        default:
            debug assert(op < OPMAX);
            if (!OTleaf(op))
            {
                if (OTbinary(op))
                    el_free(e.EV.E2);
                elem* en = e.EV.E1;
                debug memset(e,0xFF,elem_size);
                e.EV.E1 = nextfree;
                nextfree = e;

                version (STATS)
                    elfreed++;

                e = en;
                goto L1;
            }
            break;
    }
    debug memset(e,0xFF,elem_size);
    e.EV.E1 = nextfree;
    nextfree = e;

    version (STATS)
        elfreed++;
}

version (STATS)
{
    /* count number of elems available on free list */
    void el_count_free()
    {
        elem *e;
        int count;

        for(e=nextfree;e;e=e.EV.E1)
            count++;
        printf("Requests for elems %d\n",elcount);
        printf("Requests to free elems %d\n",elfreed);
        printf("Number of elems %d\n",eprm_cnt);
        printf("Number of elems currently on free list %d\n",count);
    }
}

/*********************
 * Combine e1 and e2 with a comma-expression.
 * Be careful about either or both being null.
 */

elem * el_combine(elem *e1,elem *e2)
{
    if (e1)
    {
        if (e2)
        {
            version (SCPP_HTOD)
            {
                e1 = (PARSER) ? el_bint(OPcomma,e2.ET,e1,e2)
                        : el_bin(OPcomma,e2.Ety,e1,e2);
            }
            else
            {
                e1 = el_bin(OPcomma,e2.Ety,e1,e2);
            }
        }
    }
    else
        e1 = e2;
    return e1;
}

/*********************
 * Combine e1 and e2 as parameters to a function.
 * Be careful about either or both being null.
 */

elem * el_param(elem *e1,elem *e2)
{
    //printf("el_param(%p, %p)\n", e1, e2);
    if (e1)
    {
        if (e2)
        {
            version (SCPP_HTOD)
            {
                e1 = (PARSER) ? el_bint(OPparam,tstypes[TYvoid],e1,e2)
                        : el_bin(OPparam,TYvoid,e1,e2);
            }
            else
            {
                e1 = el_bin(OPparam,TYvoid,e1,e2);
            }
        }
    }
    else
        e1 = e2;
    return e1;
}

/*********************************
 * Create parameter list, terminated by a null.
 */

@trusted
elem *el_params(elem *e1, ...)
{
    elem *e;
    va_list ap;

    e = null;
    va_start(ap, e1);
    for (; e1; e1 = va_arg!(elem *)(ap))
    {
        e = el_param(e, e1);
    }
    va_end(ap);
    return e;
}

/*****************************************
 * Do an array of parameters as a balanced
 * binary tree.
 */

@trusted
elem *el_params(void **args, int length)
{
    if (length == 0)
        return null;
    if (length == 1)
        return cast(elem *)args[0];
    int mid = length >> 1;
    return el_param(el_params(args, mid),
                    el_params(args + mid, length - mid));
}

/*****************************************
 * Do an array of parameters as a balanced
 * binary tree.
 */

@trusted
elem *el_combines(void **args, int length)
{
    if (length == 0)
        return null;
    if (length == 1)
        return cast(elem *)args[0];
    int mid = length >> 1;
    return el_combine(el_combines(args, mid),
                    el_combines(args + mid, length - mid));
}

/**************************************
 * Return number of op nodes
 */

@trusted
size_t el_opN(const elem *e, OPER op)
{
    if (e.Eoper == op)
        return el_opN(e.EV.E1, op) + el_opN(e.EV.E2, op);
    else
        return 1;
}

/******************************************
 * Fill an array with the ops.
 */

@trusted
void el_opArray(elem ***parray, elem *e, OPER op)
{
    if (e.Eoper == op)
    {
        el_opArray(parray, e.EV.E1, op);
        el_opArray(parray, e.EV.E2, op);
    }
    else
    {
        **parray = e;
        ++(*parray);
    }
}

@trusted
void el_opFree(elem *e, OPER op)
{
    if (e.Eoper == op)
    {
        el_opFree(e.EV.E1, op);
        el_opFree(e.EV.E2, op);
        e.EV.E1 = null;
        e.EV.E2 = null;
        el_free(e);
    }
}

/*****************************************
 * Do an array of parameters as a tree
 */

@trusted
extern (C) elem *el_opCombine(elem **args, size_t length, OPER op, tym_t ty)
{
    if (length == 0)
        return null;
    if (length == 1)
        return args[0];
    return el_bin(op, ty, el_opCombine(args, length - 1, op, ty), args[length - 1]);
}

/***************************************
 * Return a list of the parameters.
 */

int el_nparams(const elem *e)
{
    return cast(int)el_opN(e, OPparam);
}

/******************************************
 * Fill an array with the parameters.
 */

@trusted
void el_paramArray(elem ***parray, elem *e)
{
    if (e.Eoper == OPparam)
    {
        el_paramArray(parray, e.EV.E1);
        el_paramArray(parray, e.EV.E2);
        freenode(e);
    }
    else
    {
        **parray = e;
        ++(*parray);
    }
}

/*************************************
 * Create a quad word out of two dwords.
 */

elem *el_pair(tym_t tym, elem *lo, elem *hi)
{
    static if (0)
    {
        lo = el_una(OPu32_64, TYullong, lo);
        hi = el_una(OPu32_64, TYullong, hi);
        hi = el_bin(OPshl, TYullong, hi, el_long(TYint, 32));
        return el_bin(OPor, tym, lo, hi);
    }
    else
    {
        return el_bin(OPpair, tym, lo, hi);
    }
}


/*************************
 * Copy an element (not the tree!).
 */

@trusted
void el_copy(elem *to, const elem *from)
{
    assert(to && from);
    elem_debug(from);
    elem_debug(to);
    memcpy(to,from,elem_size);
    elem_debug(to);
}

/***********************************
 * Allocate a temporary, and return temporary elem.
 */

@trusted
elem * el_alloctmp(tym_t ty)
{
    version (MARS)
    { }
    else
        assert(!PARSER);

    Symbol *s;
    s = symbol_generate(SCauto,type_fake(ty));
    symbol_add(s);
    s.Sfl = FLauto;
    s.Sflags = SFLfree | SFLunambig | GTregcand;
    return el_var(s);
}

/********************************
 * Select the e1 child of e.
 */

@trusted
elem * el_selecte1(elem *e)
{
    elem *e1;
    assert(!PARSER);
    elem_debug(e);
    assert(!OTleaf(e.Eoper));
    e1 = e.EV.E1;
    elem_debug(e1);
    if (e.EV.E2) elem_debug(e.EV.E2);
    e.EV.E1 = null;                               // so e1 won't be freed
    if (configv.addlinenumbers)
    {
        if (e.Esrcpos.Slinnum)
            e1.Esrcpos = e.Esrcpos;
    }
    e1.Ety = e.Ety;
    //if (tyaggregate(e1.Ety))
    //    e1.Enumbytes = e.Enumbytes;
    version (MARS)
    {
        if (!e1.Ejty)
            e1.Ejty = e.Ejty;
    }
    el_free(e);
    return e1;
}

/********************************
 * Select the e2 child of e.
 */

@trusted
elem * el_selecte2(elem *e)
{
    elem *e2;
    //printf("el_selecte2(%p)\n",e);
    elem_debug(e);
    assert(OTbinary(e.Eoper));
    if (e.EV.E1)
        elem_debug(e.EV.E1);
    e2 = e.EV.E2;
    elem_debug(e2);
    e.EV.E2 = null;                       // so e2 won't be freed
    if (configv.addlinenumbers)
    {
        if (e.Esrcpos.Slinnum)
            e2.Esrcpos = e.Esrcpos;
    }
    if (PARSER)
        el_settype(e2,e.ET);
    else
    {
        e2.Ety = e.Ety;
        //if (tyaggregate(e.Ety))
        //    e2.Enumbytes = e.Enumbytes;
    }
    el_free(e);
    return e2;
}

/*************************
 * Create and return a duplicate of e, including its leaves.
 * No CSEs.
 */

@trusted
elem * el_copytree(elem *e)
{
    elem *d;
    if (!e)
        return e;
    elem_debug(e);
    d = el_calloc();
    el_copy(d,e);
    assert(!e.Ecount);
    version (SCPP_HTOD)
    {
        if (PARSER)
        {
            type_debug(d.ET);
            d.ET.Tcount++;
        }
    }
    if (!OTleaf(e.Eoper))
    {
        d.EV.E1 = el_copytree(e.EV.E1);
        if (OTbinary(e.Eoper))
            d.EV.E2 = el_copytree(e.EV.E2);
    }
    else
    {
        switch (e.Eoper)
        {
            case OPstring:
static if (0)
{
                if (OPTIMIZER)
                {
                    /* Convert the string to a static symbol and
                       then just refer to it, because two OPstrings can't
                       refer to the same string.
                     */

                    el_convstring(e);   // convert string to symbol
                    d.Eoper = OPrelconst;
                    d.EV.Vsym = e.EV.Vsym;
                    break;
                }
}
static if (0)
{
            case OPrelconst:
                e.EV.sm.ethis = null;
                break;
}
            case OPasm:
                d.EV.Vstring = cast(char *) mem_malloc(d.EV.Vstrlen);
                memcpy(d.EV.Vstring,e.EV.Vstring,e.EV.Vstrlen);
                break;

            default:
                break;
        }
    }
    return d;
}

/*******************************
 * Replace (e) with ((stmp = e),stmp)
 */

version (MARS)
{
@trusted
elem *exp2_copytotemp(elem *e)
{
    //printf("exp2_copytotemp()\n");
    elem_debug(e);
    tym_t ty = tybasic(e.Ety);
    type *t;
    version (MARS)
    {
        if ((ty == TYstruct || ty == TYarray) && e.ET)
            t = e.ET;
        else
            t = type_fake(ty);
    }
    else
        t = type_fake(ty);

    Symbol *stmp = symbol_genauto(t);
    elem *eeq = el_bin(OPeq,e.Ety,el_var(stmp),e);
    elem *er = el_bin(OPcomma,e.Ety,eeq,el_var(stmp));
    if (ty == TYstruct || ty == TYarray)
    {
        eeq.Eoper = OPstreq;
        eeq.ET = e.ET;
        eeq.EV.E1.ET = e.ET;
        er.ET = e.ET;
        er.EV.E2.ET = e.ET;
    }
    return er;
}
}

/*************************
 * Similar to el_copytree(e). But if e has any side effects, it's replaced
 * with (tmp = e) and tmp is returned.
 */

@trusted
elem * el_same(elem **pe)
{
    elem *e = *pe;
    if (e && el_sideeffect(e))
    {
        *pe = exp2_copytotemp(e);       /* convert to ((tmp=e),tmp)     */
        e = (*pe).EV.E2;                  /* point at tmp                 */
    }
    return el_copytree(e);
}

/*************************
 * Thin wrapper of exp2_copytotemp. Different from el_same,
 * always makes a temporary.
 */
@trusted
elem *el_copytotmp(elem **pe)
{
    //printf("copytotemp()\n");
    elem *e = *pe;
    if (e)
    {
        *pe = exp2_copytotemp(e);
        e = (*pe).EV.E2;
    }
    return el_copytree(e);
}

/**************************
 * Replace symbol s1 with s2 in tree.
 */

version (SCPP_HTOD)
{

void el_replace_sym(elem *e,const Symbol *s1,Symbol *s2)
{
    symbol_debug(s1);
    symbol_debug(s2);
    while (1)
    {
        elem_debug(e);
        if (!OTleaf(e.Eoper))
        {
            if (OTbinary(e.Eoper))
                el_replace_sym(e.EV.E2,s1,s2);
            e = e.EV.E1;
        }
        else
        {
            switch (e.Eoper)
            {
                case OPvar:
                case OPrelconst:
                    if (e.EV.Vsym == s1)
                        e.EV.Vsym = s2;
                    break;

                default:
                    break;
            }
            break;
        }
    }
}

}

/*************************************
 * Does symbol s appear in tree e?
 * Returns:
 *      1       yes
 *      0       no
 */

@trusted
int el_appears(const(elem)* e, const Symbol *s)
{
    symbol_debug(s);
    while (1)
    {
        elem_debug(e);
        if (!OTleaf(e.Eoper))
        {
            if (OTbinary(e.Eoper) && el_appears(e.EV.E2,s))
                return 1;
            e = e.EV.E1;
        }
        else
        {
            switch (e.Eoper)
            {
                case OPvar:
                case OPrelconst:
                    if (e.EV.Vsym == s)
                        return 1;
                    break;

                default:
                    break;
            }
            break;
        }
    }
    return 0;
}

version (MARS)
{

/*****************************************
 * Look for symbol that is a base of addressing mode e.
 * Returns:
 *      s       symbol used as base
 *      null    couldn't find a base symbol
 */

static if (0)
{
Symbol *el_basesym(elem *e)
{
    Symbol *s;
    s = null;
    while (1)
    {
        elem_debug(e);
        switch (e.Eoper)
        {
            case OPvar:
                s = e.EV.Vsym;
                break;

            case OPcomma:
                e = e.EV.E2;
                continue;

            case OPind:
                s = el_basesym(e.EV.E1);
                break;

            case OPadd:
                s = el_basesym(e.EV.E1);
                if (!s)
                    s = el_basesym(e.EV.E2);
                break;
        }
        break;
    }
    return s;
}
}

/****************************************
 * Does any definition of lvalue ed appear in e?
 * Returns:
 *      true if there is one
 */

@trusted
bool el_anydef(const elem *ed, const(elem)* e)
{
    const edop = ed.Eoper;
    const s = (edop == OPvar) ? ed.EV.Vsym : null;
    while (1)
    {
        const op = e.Eoper;
        if (!OTleaf(op))
        {
            auto e1 = e.EV.E1;
            if (OTdef(op))
            {
                if (e1.Eoper == OPvar && e1.EV.Vsym == s)
                    return true;

                // This doesn't cover all the cases
                if (e1.Eoper == edop && el_match(e1,ed))
                    return true;
            }
            if (OTbinary(op) && el_anydef(ed,e.EV.E2))
                return true;
            e = e1;
        }
        else
            break;
    }
    return false;
}

}

/************************
 * Make a binary operator node.
 */

@trusted
elem* el_bint(OPER op,type *t,elem *e1,elem *e2)
{
    elem *e;
    /* e2 is null when OPpostinc is built       */
    assert(op < OPMAX && OTbinary(op) && e1);
    assert(PARSER);
    e = el_calloc();
    if (t)
    {
        e.ET = t;
        type_debug(t);
        e.ET.Tcount++;
    }
    e.Eoper = cast(ubyte)op;
    elem_debug(e1);
    if (e2)
        elem_debug(e2);
    e.EV.E1 = e1;
    e.EV.E2 = e2;
    return e;
}

@trusted
elem* el_bin(OPER op,tym_t ty,elem *e1,elem *e2)
{
static if (0)
{
    if (!(op < OPMAX && OTbinary(op) && e1 && e2))
        *cast(char *)0=0;
}
    assert(op < OPMAX && OTbinary(op) && e1 && e2);
    version (MARS) { } else assert(!PARSER);
    elem_debug(e1);
    elem_debug(e2);
    elem* e = el_calloc();
    e.Ety = ty;
    e.Eoper = cast(ubyte)op;
    e.EV.E1 = e1;
    e.EV.E2 = e2;
    if (op == OPcomma && tyaggregate(ty))
        e.ET = e2.ET;
    return e;
}

/************************
 * Make a unary operator node.
 */

@trusted
elem* el_unat(OPER op,type *t,elem *e1)
{
    debug if (!(op < OPMAX && OTunary(op) && e1))
        printf("op = x%x, e1 = %p\n",op,e1);

    assert(op < OPMAX && OTunary(op) && e1);
    assert(PARSER);
    elem_debug(e1);
    elem* e = el_calloc();
    e.Eoper = cast(ubyte)op;
    e.EV.E1 = e1;
    if (t)
    {
        type_debug(t);
        t.Tcount++;
        e.ET = t;
    }
    return e;
}

@trusted
elem* el_una(OPER op,tym_t ty,elem *e1)
{
    debug if (!(op < OPMAX && OTunary(op) && e1))
        printf("op = x%x, e1 = %p\n",op,e1);

    assert(op < OPMAX && OTunary(op) && e1);
    version (MARS) { } else assert(!PARSER);
    elem_debug(e1);
    elem* e = el_calloc();
    e.Ety = ty;
    e.Eoper = cast(ubyte)op;
    e.EV.E1 = e1;
    return e;
}

/*******************
 * Make a constant node out of integral type.
 */

@trusted
extern (C) elem * el_longt(type *t,targ_llong val)
{
    assert(PARSER);
    elem* e = el_calloc();
    e.Eoper = OPconst;
    e.ET = t;
    if (e.ET)
    {
        type_debug(t);
        e.ET.Tcount++;
    }
    e.EV.Vllong = val;
    return e;
}

extern (C) // necessary because D <=> C++ mangling of "long long" is not consistent across memory models
{
elem * el_long(tym_t t,targ_llong val)
{
    version (MARS)
    { }
    else
        assert(!PARSER);

    elem* e = el_calloc();
    e.Eoper = OPconst;
    e.Ety = t;
    switch (tybasic(t))
    {
        case TYfloat:
        case TYifloat:
            e.EV.Vfloat = val;
            break;

        case TYdouble:
        case TYidouble:
            e.EV.Vdouble = val;
            break;

        case TYldouble:
        case TYildouble:
            e.EV.Vldouble = val;
            break;

        case TYcfloat:
        case TYcdouble:
        case TYcldouble:
            assert(0);

        default:
            e.EV.Vllong = val;
            break;
    }
    return e;
}
}

/*******************************
 * If elem is a const that can be converted to an OPconst,
 * do the conversion.
 */

version (SCPP_HTOD)
{
void el_toconst(elem *e)
{
    elem_debug(e);
    assert(PARSER);
    if (e.Eoper == OPvar && e.EV.Vsym.Sflags & SFLvalue)
    {
        elem *es = e.EV.Vsym.Svalue;
        type_debug(e.ET);
        symbol_debug(e.EV.Vsym);
        elem_debug(es);
        e.Eoper = es.Eoper;
        assert(e.Eoper == OPconst);
        e.EV = es.EV;
    }
}
}

/*******************************
 * Set new type for elem.
 */

elem * el_settype(elem *e,type *t)
{
    version (MARS)
        assert(0);
    else
    {
        assert(PARSER);
        elem_debug(e);
        type_debug(t);
        type_settype(&e.ET,t);
        return e;
    }
}

/*******************************
 * Walk tree, replacing symbol s1 with s2.
 */

version (SCPP_HTOD)
{

void el_replacesym(elem *e,const Symbol *s1,Symbol *s2)
{
    assert(PARSER);
    while (e)
    {
        elem_debug(e);
        if (!OTleaf(e.Eoper))
        {
            el_replacesym(e.EV.E2,s1,s2);
            e = e.EV.E1;
        }
        else
        {
            if ((e.Eoper == OPvar || e.Eoper == OPrelconst) &&
                e.EV.Vsym == s1)
                e.EV.Vsym = s2;
            break;
        }
    }
}

}

/*******************************
 * Create elem that is the size of a type.
 */

elem * el_typesize(type *t)
{
version (MARS)
{
    assert(0);
}
else
{
    assert(PARSER);
    type_debug(t);
    if (CPP && tybasic(t.Tty) == TYstruct && t.Tflags & TFsizeunknown)
    {
        elem *e;
        symbol_debug(t.Ttag);
        e = el_calloc();
        e.Eoper = OPsizeof;
        e.EV.Vsym = t.Ttag;
        e.ET = tssize;
        e.ET.Tcount++;
        type_debug(tssize);
        elem_debug(e);
        return e;
    }
    else if (tybasic(t.Tty) == TYarray && type_isvla(t))
    {
        type *troot = type_arrayroot(t);
        elem *en;

        en = el_nelems(t);
        return el_bint(OPmul, en.ET, en, el_typesize(troot));
    }
    else
        return el_longt(tssize,type_size(t));
}
}

/*****************************
 * Return an elem that evaluates to the number of elems in a type
 * (if it is an array). Returns null if t is not an array.
 */

version (SCPP_HTOD)
{
elem * el_nelems(type *t)
{
    elem *enelems;
    assert(PARSER);
    type_debug(t);
    if (tybasic(t.Tty) == TYarray)
    {
        type *ts = tssize;
        enelems = el_longt(ts, 1);
        do
        {
            if (t.Tflags & TFsizeunknown ||
                (t.Tflags & TFvla && !t.Tel))
            {
                synerr(EM_unknown_size,"array".ptr);        // size of array is unknown
                t.Tflags &= ~TFsizeunknown;
            }
            else if (t.Tflags & TFvla)
            {
                enelems = el_bint(OPmul, ts, enelems, el_copytree(t.Tel));
            }
            else if (enelems.Eoper == OPconst)
            {
                enelems.EV.Vllong *= t.Tdim;
                type_chksize(cast(uint)enelems.EV.Vllong);
            }
            else
                enelems = el_bint(OPmul, enelems.ET, enelems, el_longt(ts, t.Tdim));
            t = t.Tnext;
        } while (tybasic(t.Tty) == TYarray);
    }
    else
        enelems = null;
    return enelems;
}
}

/************************************
 * Returns: true if function has any side effects.
 */

version (MARS)
{

@trusted
bool el_funcsideeff(const elem *e)
{
    const(Symbol)* s;
    if (e.Eoper == OPvar &&
        tyfunc((s = e.EV.Vsym).Stype.Tty) &&
        ((s.Sfunc && s.Sfunc.Fflags3 & Fnosideeff) || s == funcsym_p)
       )
        return false;
    return true;                   // assume it does have side effects
}

}

/****************************
 * Returns: true if elem has any side effects.
 */

@trusted
bool el_sideeffect(const elem *e)
{
    assert(e);
    const op = e.Eoper;
    assert(op < OPMAX);
    elem_debug(e);
    return  typemask(e) & (mTYvolatile | mTYshared) ||
            OTsideff(op) ||
            (OTunary(op) && el_sideeffect(e.EV.E1)) ||
            (OTbinary(op) && (el_sideeffect(e.EV.E1) ||
                                  el_sideeffect(e.EV.E2)));
}

/******************************
 * Input:
 *      ea      lvalue (might be an OPbit)
 * Returns:
 *      0       eb has no dependency on ea
 *      1       eb might have a dependency on ea
 *      2       eb definitely depends on ea
 */

@trusted
int el_depends(const(elem)* ea, const elem *eb)
{
 L1:
    elem_debug(ea);
    elem_debug(eb);
    switch (ea.Eoper)
    {
        case OPbit:
            ea = ea.EV.E1;
            goto L1;

        case OPvar:
        case OPind:
            break;

        default:
            assert(0);
    }
    switch (eb.Eoper)
    {
        case OPconst:
        case OPrelconst:
        case OPstring:

    version (SCPP_HTOD)
        case OPsizeof:

            goto Lnodep;

        case OPvar:
            if (ea.Eoper == OPvar && ea.EV.Vsym != eb.EV.Vsym)
                goto Lnodep;
            break;

        default:
            break;      // this could use improvement
    }
    return 1;

Lnodep:
    return 0;
}


/**************************
 * Make a pointer to an elem out of a symbol at offset.
 */

version (SCPP_HTOD)
{

elem * el_ptr_offset(Symbol *s,targ_size_t offset)
{
    auto e = el_ptr(s);      /* e is an elem which is a pointer to s */
    auto e1 = e.EV.E1;
    if (e1.Eoper == OPvar)
    { }
    // The following case happens if symbol s is in thread local storage
    else if (e1.Eoper == OPind &&
             e1.EV.E1.Eoper == OPadd &&
             e1.EV.E1.EV.E1.Eoper == OPrelconst)
        e1 = e1.EV.E1.EV.E1;
    else
        assert(0);
    assert(e1.EV.Vsym == s);
    e1.EV.Voffset = offset;
    return e;
}

}

/*************************
 * Returns:
 *      true   elem evaluates right-to-left
 *      false  elem evaluates left-to-right
 */

@trusted
bool ERTOL(const elem *e)
{
    elem_debug(e);
    assert(!PARSER);
    return OTrtol(e.Eoper) &&
        (!OTopeq(e.Eoper) || config.inline8087 || !tyfloating(e.Ety));
}

/********************************
 * Determine if expression may return.
 * Does not detect all cases, errs on the side of saying it returns.
 * Params:
 *      e = tree
 * Returns:
 *      false if expression never returns.
 */

@trusted
bool el_returns(const(elem)* e)
{
    while (1)
    {
        elem_debug(e);
        switch (e.Eoper)
        {
            case OPcall:
            case OPucall:
                e = e.EV.E1;
                if (e.Eoper == OPvar && e.EV.Vsym.Sflags & SFLexit)
                    return false;
                break;

            case OPhalt:
                return false;

            case OPandand:
            case OPoror:
                e = e.EV.E1;
                continue;

            case OPcolon:
            case OPcolon2:
                return el_returns(e.EV.E1) || el_returns(e.EV.E2);

            default:
                if (OTbinary(e.Eoper))
                {
                    if (!el_returns(e.EV.E2))
                        return false;
                    e = e.EV.E1;
                    continue;
                }
                if (OTunary(e.Eoper))
                {
                    e = e.EV.E1;
                    continue;
                }
                break;
        }
        break;
    }
    return true;
}

/********************************
 * Scan down commas and return the controlling elem.
 */

@trusted
elem *el_scancommas(elem *e)
{
    while (e.Eoper == OPcomma)
        e = e.EV.E2;
    return e;
}

/***************************
 * Count number of commas in the expression.
 */

@trusted
int el_countCommas(const(elem)* e)
{
    int ncommas = 0;
    while (1)
    {
        if (OTbinary(e.Eoper))
        {
            ncommas += (e.Eoper == OPcomma) + el_countCommas(e.EV.E2);
        }
        else if (OTunary(e.Eoper))
        {
        }
        else
            break;
        e = e.EV.E1;
    }
    return ncommas;
}

/************************************
 * Convert floating point constant to a read-only symbol.
 * Needed iff floating point code can't load immediate constants.
 */

version (HTOD) { } else
{
@trusted
elem *el_convfloat(elem *e)
{
    ubyte[32] buffer = void;

    assert(config.inline8087);

    // Do not convert if the constants can be loaded with the special FPU instructions
    if (tycomplex(e.Ety))
    {
        if (loadconst(e, 0) && loadconst(e, 1))
            return e;
    }
    else if (loadconst(e, 0))
        return e;

    go.changes++;
    tym_t ty = e.Ety;
    int sz = tysize(ty);
    assert(sz <= buffer.length);
    void *p;
    switch (tybasic(ty))
    {
        case TYfloat:
        case TYifloat:
            p = &e.EV.Vfloat;
            assert(sz == (e.EV.Vfloat).sizeof);
            break;

        case TYdouble:
        case TYidouble:
        case TYdouble_alias:
            p = &e.EV.Vdouble;
            assert(sz == (e.EV.Vdouble).sizeof);
            break;

        case TYldouble:
        case TYildouble:
            /* The size, alignment, and padding of long doubles may be different
             * from host to target
             */
            p = buffer.ptr;
            memset(buffer.ptr, 0, sz);                      // ensure padding is 0
            memcpy(buffer.ptr, &e.EV.Vldouble, 10);
            break;

        case TYcfloat:
            p = &e.EV.Vcfloat;
            assert(sz == (e.EV.Vcfloat).sizeof);
            break;

        case TYcdouble:
            p = &e.EV.Vcdouble;
            assert(sz == (e.EV.Vcdouble).sizeof);
            break;

        case TYcldouble:
            p = buffer.ptr;
            memset(buffer.ptr, 0, sz);
            memcpy(buffer.ptr, &e.EV.Vcldouble.re, 10);
            memcpy(buffer.ptr + tysize(TYldouble), &e.EV.Vcldouble.im, 10);
            break;

        default:
            assert(0);
    }

    static if (0)
    {
        printf("%gL+%gLi\n", cast(double)e.EV.Vcldouble.re, cast(double)e.EV.Vcldouble.im);
        printf("el_convfloat() %g %g sz=%d\n", e.EV.Vcdouble.re, e.EV.Vcdouble.im, sz);
        printf("el_convfloat(): sz = %d\n", sz);
        ushort *p = cast(ushort *)&e.EV.Vcldouble;
        for (int i = 0; i < sz/2; i++) printf("%04x ", p[i]);
        printf("\n");
    }

    Symbol *s  = out_readonly_sym(ty, p, sz);
    el_free(e);
    e = el_var(s);
    e.Ety = ty;
    if (e.Eoper == OPvar)
        e.Ety |= mTYconst;
    //printf("s: %s %d:x%x\n", s.Sident, s.Sseg, s.Soffset);
    return e;
}
}

/************************************
 * Convert vector constant to a read-only symbol.
 * Needed iff vector code can't load immediate constants.
 */

@trusted
elem *el_convxmm(elem *e)
{
    ubyte[eve.sizeof] buffer = void;

    // Do not convert if the constants can be loaded with the special XMM instructions
static if (0)
{
    if (loadconst(e))
        return e;
}

    go.changes++;
    tym_t ty = e.Ety;
    int sz = tysize(ty);
    assert(sz <= buffer.length);
    void *p = &e.EV;

    static if (0)
    {
        printf("el_convxmm(): sz = %d\n", sz);
        for (size i = 0; i < sz; i++) printf("%02x ", (cast(ubyte *)p)[i]);
        printf("\n");
    }

    Symbol *s  = out_readonly_sym(ty, p, sz);
    el_free(e);
    e = el_var(s);
    e.Ety = ty;
    if (e.Eoper == OPvar)
        e.Ety |= mTYconst;
    //printf("s: %s %d:x%x\n", s.Sident, s.Sseg, s.Soffset);
    return e;
}

/********************************
 * Convert reference to a string to reference to a symbol
 * stored in the static data segment.
 */

@trusted
elem *el_convstring(elem *e)
{
    //printf("el_convstring()\n");
    int i;
    Symbol *s;
    char *p;

    assert(!PARSER);
    elem_debug(e);
    assert(e.Eoper == OPstring);
    p = e.EV.Vstring;
    e.EV.Vstring = null;
    size_t len = e.EV.Vstrlen;

    // Handle strings that go into the code segment
    if (tybasic(e.Ety) == TYcptr ||
        (tyfv(e.Ety) && config.flags3 & CFG3strcod))
    {
        assert(config.objfmt == OBJ_OMF);         // option not done yet for others
        s = symbol_generate(SCstatic, type_fake(mTYcs | e.Ety));
        s.Sfl = FLcsdata;
        s.Soffset = Offset(cseg);
        s.Sseg = cseg;
        symbol_keep(s);
        if (!eecontext.EEcompile || eecontext.EEin)
        {
            objmod.bytes(cseg,Offset(cseg),cast(uint)len,p);
            Offset(cseg) += len;
        }
        mem_free(p);
        goto L1;
    }

    if (eecontext.EEin)                 // if compiling debugger expression
    {
        s = out_readonly_sym(e.Ety, p, cast(int)len);
        mem_free(p);
        goto L1;
    }

    // See if e is already in the string table
    for (i = 0; i < stable.length; i++)
    {
        if (stable[i].str.length == len &&
            memcmp(stable[i].str.ptr,p,len) == 0)
        {
            // Replace e with that symbol
            MEM_PH_FREE(p);
            s = stable[i].sym;
            goto L1;
        }
    }

    // Replace string with a symbol that refers to that string
    // in the DATA segment

    if (eecontext.EEcompile)
    {
        s = symboldata(Offset(DATA),e.Ety);
        s.Sseg = DATA;
    }
    else
        s = out_readonly_sym(e.Ety,p,cast(int)len);

    // Remember the string for possible reuse later
    //printf("Adding %d, '%s'\n",stable_si,p);
    mem_free(stable[stable_si].str.ptr);
    stable[stable_si].str = p[0 .. cast(size_t)len];
    stable[stable_si].sym = s;
    stable_si = (stable_si + 1) & (stable.length - 1);

L1:
    // Refer e to the symbol generated
    elem *ex = el_ptr(s);
    ex.Ety = e.Ety;
    if (e.EV.Voffset)
    {
        if (ex.Eoper == OPrelconst)
             ex.EV.Voffset += e.EV.Voffset;
        else
             ex = el_bin(OPadd, ex.Ety, ex, el_long(TYint, e.EV.Voffset));
    }
    el_free(e);
    return ex;
}

/********************************************
 * If e is a long double constant, and it is perfectly representable as a
 * double constant, convert it to a double constant.
 * Note that this must NOT be done in contexts where there are no further
 * operations, since then it could change the type (eg, in the function call
 * printf("%La", 2.0L); the 2.0 must stay as a long double).
 */
static if (1)
{
@trusted
void shrinkLongDoubleConstantIfPossible(elem *e)
{
    if (e.Eoper == OPconst && e.Ety == TYldouble)
    {
        /* Check to see if it can be converted into a double (this happens
         * when the low bits are all zero, and the exponent is in the
         * double range).
         * Use 'volatile' to prevent optimizer from folding away the conversions,
         * and thereby missing the truncation in the conversion to double.
         */
        auto v = e.EV.Vldouble;
        double vDouble;

        version (CRuntime_Microsoft)
        {
            static if (is(typeof(v) == real))
                *(&vDouble) = v;
            else
                *(&vDouble) = cast(double)v;
        }
        else
            *(&vDouble) = v;

        if (v == vDouble)       // This will fail if compiler does NaN incorrectly!
        {
            // Yes, we can do it!
            e.EV.Vdouble = vDouble;
            e.Ety = TYdouble;
        }
    }
}
}


/*************************
 * Run through a tree converting it to CODGEN.
 */

version (HTOD) { } else
{
@trusted
elem *el_convert(elem *e)
{
    //printf("el_convert(%p)\n", e);
    elem_debug(e);
    const op = e.Eoper;
    switch (op)
    {
        case OPvar:
            break;

        case OPconst:
            if (tyvector(e.Ety))
                e = el_convxmm(e);
            else if (tyfloating(e.Ety) && config.inline8087)
                e = el_convfloat(e);
            break;

        case OPstring:
            go.changes++;
            e = el_convstring(e);
            break;

        case OPnullptr:
            e = el_long(e.Ety, 0);
            break;

        case OPmul:
            /* special floating-point case: allow x*2 to be x+x
             * in this case, we preserve the constant 2.
             */
            if (tyreal(e.Ety) &&       // don't bother with imaginary or complex
                e.EV.E2.Eoper == OPconst && el_toldoubled(e.EV.E2) == 2.0L)
            {
                e.EV.E1 = el_convert(e.EV.E1);
                /* Don't call el_convert(e.EV.E2), we want it to stay as a constant
                 * which will be detected by code gen.
                 */
                break;
            }
            goto case OPdiv;

        case OPdiv:
        case OPadd:
        case OPmin:
            // For a*b,a+b,a-b,a/b, if a long double constant is involved, convert it to a double constant.
            if (tyreal(e.Ety))
                 shrinkLongDoubleConstantIfPossible(e.EV.E1);
            if (tyreal(e.Ety))
                shrinkLongDoubleConstantIfPossible(e.EV.E2);
            goto default;

        default:
            if (OTbinary(op))
            {
                e.EV.E1 = el_convert(e.EV.E1);
                e.EV.E2 = el_convert(e.EV.E2);
            }
            else if (OTunary(op))
            {
                e.EV.E1 = el_convert(e.EV.E1);
            }
            break;
    }
    return e;
}
}


/************************
 * Make a constant elem.
 *      ty      = type of elem
 *      *pconst = union of constant data
 */

@trusted
elem * el_const(tym_t ty, eve *pconst)
{
    elem *e;

    version (MARS) { }
    else assert(!PARSER);

    e = el_calloc();
    e.Eoper = OPconst;
    e.Ety = ty;
    memcpy(&e.EV,pconst,(e.EV).sizeof);
    return e;
}


/**************************
 * Insert constructor information into tree.
 * A corresponding el_ddtor() must be called later.
 * Params:
 *      e =     code to construct the object
 *      decl =  VarDeclaration of variable being constructed
 */

static if (0)
{
elem *el_dctor(elem *e,void *decl)
{
    elem *ector = el_calloc();
    ector.Eoper = OPdctor;
    ector.Ety = TYvoid;
    ector.EV.ed.Edecl = decl;
    if (e)
        e = el_bin(OPinfo,e.Ety,ector,e);
    else
        /* Remember that a "constructor" may execute no code, hence
         * the need for OPinfo if there is code to execute.
         */
        e = ector;
    return e;
}
}

/**************************
 * Insert destructor information into tree.
 *      e       code to destruct the object
 *      decl    VarDeclaration of variable being destructed
 *              (must match decl for corresponding OPctor)
 */

static if (0)
{
elem *el_ddtor(elem *e,void *decl)
{
    /* A destructor always executes code, or we wouldn't need
     * eh for it.
     * An OPddtor must match 1:1 with an OPdctor
     */
    elem *edtor = el_calloc();
    edtor.Eoper = OPddtor;
    edtor.Ety = TYvoid;
    edtor.EV.ed.Edecl = decl;
    edtor.EV.ed.Eleft = e;
    return edtor;
}
}

/*********************************************
 * Create constructor/destructor pair of elems.
 * Caution: The pattern generated here must match that detected in e2ir.c's visit(CallExp).
 * Params:
 *      ec = code to construct (may be null)
 *      ed = code to destruct
 *      pedtor = set to destructor node
 * Returns:
 *      constructor node
 */

@trusted
elem *el_ctor_dtor(elem *ec, elem *ed, elem **pedtor)
{
    elem *er;
    if (config.ehmethod == EHmethod.EH_DWARF)
    {
        /* Construct (note that OPinfo is evaluated RTOL):
         *  er = (OPdctor OPinfo (__flag = 0, ec))
         *  edtor = __flag = 1, (OPddtor ((__exception_object = _EAX), ed, (!__flag && _Unsafe_Resume(__exception_object))))
         */

        /* Declare __flag, __EAX, __exception_object variables.
         * Use volatile to prevent optimizer from messing them up, since optimizer doesn't know about
         * landing pads (the landing pad will be on the OPddtor's EV.ed.Eleft)
         */
        Symbol *sflag = symbol_name("__flag", SCauto, type_fake(mTYvolatile | TYbool));
        Symbol *sreg = symbol_name("__EAX", SCpseudo, type_fake(mTYvolatile | TYnptr));
        sreg.Sreglsw = 0;          // EAX, RAX, whatevs
        Symbol *seo = symbol_name("__exception_object", SCauto, tspvoid);

        symbol_add(sflag);
        symbol_add(sreg);
        symbol_add(seo);

        elem *ector = el_calloc();
        ector.Eoper = OPdctor;
        ector.Ety = TYvoid;
//      ector.EV.ed.Edecl = decl;

        eve c = void;
        memset(&c, 0, c.sizeof);
        elem *e_flag_0 = el_bin(OPeq, TYvoid, el_var(sflag), el_const(TYbool, &c));  // __flag = 0
        er = el_bin(OPinfo, ec ? ec.Ety : TYvoid, ector, el_combine(e_flag_0, ec));

        /* A destructor always executes code, or we wouldn't need
         * eh for it.
         * An OPddtor must match 1:1 with an OPdctor
         */
        elem *edtor = el_calloc();
        edtor.Eoper = OPddtor;
        edtor.Ety = TYvoid;
//      edtor.EV.Edecl = decl;
//      edtor.EV.E1 = e;

        c.Vint = 1;
        elem *e_flag_1 = el_bin(OPeq, TYvoid, el_var(sflag), el_const(TYbool, &c)); // __flag = 1
        elem *e_eax = el_bin(OPeq, TYvoid, el_var(seo), el_var(sreg));              // __exception_object = __EAX
        elem *eu = el_bin(OPcall, TYvoid, el_var(getRtlsym(RTLSYM_UNWIND_RESUME)), el_var(seo));
        eu = el_bin(OPandand, TYvoid, el_una(OPnot, TYbool, el_var(sflag)), eu);

        edtor.EV.E1 = el_combine(el_combine(e_eax, ed), eu);

        *pedtor = el_combine(e_flag_1, edtor);
    }
    else
    {
        /* Construct (note that OPinfo is evaluated RTOL):
         *  er = (OPdctor OPinfo ec)
         *  edtor = (OPddtor ed)
         */
        elem *ector = el_calloc();
        ector.Eoper = OPdctor;
        ector.Ety = TYvoid;
//      ector.EV.ed.Edecl = decl;
        if (ec)
            er = el_bin(OPinfo,ec.Ety,ector,ec);
        else
            /* Remember that a "constructor" may execute no code, hence
             * the need for OPinfo if there is code to execute.
             */
            er = ector;

        /* A destructor always executes code, or we wouldn't need
         * eh for it.
         * An OPddtor must match 1:1 with an OPdctor
         */
        elem *edtor = el_calloc();
        edtor.Eoper = OPddtor;
        edtor.Ety = TYvoid;
//      edtor.EV.Edecl = decl;
        edtor.EV.E1 = ed;
        *pedtor = edtor;
    }

    return er;
}

/**************************
 * Insert constructor information into tree.
 *      ector   pointer to object being constructed
 *      e       code to construct the object
 *      sdtor   function to destruct the object
 */

version (SCPP_HTOD)
{
elem *el_ctor(elem *ector,elem *e,Symbol *sdtor)
{
    //printf("el_ctor(ector = %p, e = %p, sdtor = %p)\n", ector, e, sdtor);
    //printf("stdor = '%s'\n", cpp_prettyident(sdtor));
    //printf("e:\n"); elem_print(e);
    if (ector)
    {
        if (sdtor)
        {
            if (sdtor.Sfunc.Fbody)
            {
                n2_instantiate_memfunc(sdtor);
            }
            // Causes symbols to be written out prematurely when
            // writing precompiled headers.
            // Moved to outelem().
            //nwc_mustwrite(sdtor);
        }
        if (!sdtor || ector.Eoper == OPcall ||
            (ector.Eoper == OPrelconst && !(sytab[ector.EV.Vsym.Sclass] & SCSS))
            // Not ambient memory model
            || (tyfarfunc(sdtor.ty()) ? !LARGECODE : LARGECODE)
           )
        {
            el_free(ector);
        }
        else
        {
            ector = el_unat(OPctor,ector.ET,ector);
            ector.EV.Edtor = sdtor;
            symbol_debug(sdtor);
            if (e)
                e = el_bint(OPinfo,e.ET,ector,e);
            else
                e = ector;
        }
    }
    return e;
}
}

/**************************
 * Insert destructor information into tree.
 *      edtor   pointer to object being destructed
 *      e       code to do the destruction
 */

elem *el_dtor(elem *edtor,elem *e)
{
    if (edtor)
    {
        edtor = el_unat(OPdtor,edtor.ET,edtor);
        if (e)
            e = el_bint(OPcomma,e.ET,edtor,e);
        else
            e = edtor;
    }
    return e;
}

/**********************************
 * Create an elem of the constant 0, of the type t.
 */

@trusted
elem *el_zero(type *t)
{
    assert(PARSER);

    elem* e = el_calloc();
    e.Eoper = OPconst;
    e.ET = t;
    if (t)
    {
        type_debug(t);
        e.ET.Tcount++;
    }
    return(e);
}

/*******************
 * Find and return pointer to parent of e starting at *pe.
 * Return null if can't find it.
 */

@trusted
elem ** el_parent(elem *e,elem **pe)
{
    assert(e && pe && *pe);
    elem_debug(e);
    elem_debug(*pe);
    if (e == *pe)
        return pe;
    else if (OTunary((*pe).Eoper))
        return el_parent(e,&((*pe).EV.E1));
    else if (OTbinary((*pe).Eoper))
    {
        elem **pe2;
        return ((pe2 = el_parent(e,&((*pe).EV.E1))) != null)
                ? pe2
                : el_parent(e,&((*pe).EV.E2));
    }
    else
        return null;
}

/*******************************
 * Returns: true if trees match.
 */

@trusted
private bool el_matchx(const(elem)* n1, const(elem)* n2, int gmatch2)
{
    if (n1 == n2)
        return true;
    if (!n1 || !n2)
        return false;
    elem_debug(n1);
    elem_debug(n2);

L1:
    const op = n1.Eoper;
    if (op != n2.Eoper)
        return false;

    auto tym = typemask(n1);
    auto tym2 = typemask(n2);
    if (tym != tym2)
    {
        if ((tym & ~mTYbasic) != (tym2 & ~mTYbasic))
        {
            if (!(gmatch2 & 2))
                return false;
        }
        tym = tybasic(tym);
        tym2 = tybasic(tym2);
        if (tyequiv[tym] != tyequiv[tym2] &&
            !((gmatch2 & 8) && touns(tym) == touns(tym2))
           )
            return false;
        gmatch2 &= ~8;
    }

  if (OTunary(op))
  {
    L2:
        if (PARSER)
        {
            n1 = n1.EV.E1;
            n2 = n2.EV.E1;
            assert(n1 && n2);
            goto L1;
        }
        else if (OPTIMIZER)
        {
            if (op == OPstrpar || op == OPstrctor)
            {   if (/*n1.Enumbytes != n2.Enumbytes ||*/ n1.ET != n2.ET)
                    return false;
            }
            n1 = n1.EV.E1;
            n2 = n2.EV.E1;
            assert(n1 && n2);
            goto L1;
        }
        else
        {
            if (n1.EV.E1 == n2.EV.E1)
                goto ismatch;
            n1 = n1.EV.E1;
            n2 = n2.EV.E1;
            assert(n1 && n2);
            goto L1;
        }
  }
  else if (OTbinary(op))
  {
        if (!PARSER)
        {
            if (op == OPstreq)
            {
                if (/*n1.Enumbytes != n2.Enumbytes ||*/ n1.ET != n2.ET)
                    return false;
            }
        }
        if (el_matchx(n1.EV.E2, n2.EV.E2, gmatch2))
        {
            goto L2;    // check left tree
        }
        return false;
  }
  else /* leaf elem */
  {
        switch (op)
        {
            case OPconst:
                if (gmatch2 & 1)
                    break;
            Lagain:
                switch (tybasic(tym))
                {
                    case TYshort:
                    case TYwchar_t:
                    case TYushort:
                    case TYchar16:
                    case_short:
                        if (n1.EV.Vshort != n2.EV.Vshort)
                            return false;
                        break;

                    case TYlong:
                    case TYulong:
                    case TYdchar:
                    case_long:
                        if (n1.EV.Vlong != n2.EV.Vlong)
                            return false;
                        break;

                    case TYllong:
                    case TYullong:
                    case_llong:
                        if (n1.EV.Vllong != n2.EV.Vllong)
                            return false;
                        break;

                    case TYcent:
                    case TYucent:
                        if (n1.EV.Vcent.lsw != n2.EV.Vcent.lsw ||
                            n1.EV.Vcent.msw != n2.EV.Vcent.msw)
                                return false;
                        break;

                    case TYenum:
                        if (PARSER)
                        {   tym = n1.ET.Tnext.Tty;
                            goto Lagain;
                        }
                        goto case TYuint;

                    case TYint:
                    case TYuint:
                        if (_tysize[TYint] == SHORTSIZE)
                            goto case_short;
                        else
                            goto case_long;

                    case TYnullptr:
                    case TYnptr:
                    case TYnref:
                    case TYsptr:
                    case TYcptr:
                    case TYimmutPtr:
                    case TYsharePtr:
                    case TYrestrictPtr:
                    case TYfgPtr:
                        if (_tysize[TYnptr] == SHORTSIZE)
                            goto case_short;
                        else if (_tysize[TYnptr] == LONGSIZE)
                            goto case_long;
                        else
                        {   assert(_tysize[TYnptr] == LLONGSIZE);
                            goto case_llong;
                        }

                    case TYbool:
                    case TYchar:
                    case TYuchar:
                    case TYschar:
                        if (n1.EV.Vschar != n2.EV.Vschar)
                            return false;
                        break;

                    case TYfptr:
                    case TYhptr:
                    case TYvptr:

                        /* Far pointers on the 386 are longer than
                           any integral type...
                         */
                        if (memcmp(&n1.EV, &n2.EV, tysize(tym)))
                            return false;
                        break;

                        /* Compare bit patterns w/o worrying about
                           exceptions, unordered comparisons, etc.
                         */
                    case TYfloat:
                    case TYifloat:
                        if (memcmp(&n1.EV,&n2.EV,(n1.EV.Vfloat).sizeof))
                            return false;
                        break;

                    case TYdouble:
                    case TYdouble_alias:
                    case TYidouble:
                        if (memcmp(&n1.EV,&n2.EV,(n1.EV.Vdouble).sizeof))
                            return false;
                        break;

                    case TYldouble:
                    case TYildouble:
                        static if ((n1.EV.Vldouble).sizeof > 10)
                        {
                            /* sizeof is 12, but actual size is 10 */
                            if (memcmp(&n1.EV,&n2.EV,10))
                                return false;
                        }
                        else
                        {
                            if (memcmp(&n1.EV,&n2.EV,(n1.EV.Vldouble).sizeof))
                                return false;
                        }
                        break;

                    case TYcfloat:
                        if (memcmp(&n1.EV,&n2.EV,(n1.EV.Vcfloat).sizeof))
                            return false;
                        break;

                    case TYcdouble:
                        if (memcmp(&n1.EV,&n2.EV,(n1.EV.Vcdouble).sizeof))
                            return false;
                        break;

                    case TYfloat4:
                    case TYdouble2:
                    case TYschar16:
                    case TYuchar16:
                    case TYshort8:
                    case TYushort8:
                    case TYlong4:
                    case TYulong4:
                    case TYllong2:
                    case TYullong2:
                        if (n1.EV.Vcent.msw != n2.EV.Vcent.msw || n1.EV.Vcent.lsw != n2.EV.Vcent.lsw)
                            return false;
                        break;

                    case TYcldouble:
                        static if ((n1.EV.Vldouble).sizeof > 10)
                        {
                            /* sizeof is 12, but actual size of each part is 10 */
                            if (memcmp(&n1.EV,&n2.EV,10) ||
                                memcmp(&n1.EV.Vldouble + 1, &n2.EV.Vldouble + 1, 10))
                                return false;
                        }
                        else
                        {
                            if (memcmp(&n1.EV,&n2.EV,(n1.EV.Vcldouble).sizeof))
                                return false;
                        }
                        break;

                    case TYvoid:
                        break;                  // voids always match

                    version (SCPP_HTOD)
                    {
                    case TYident:
                        assert(errcnt);
                        return false;
                    }

                    default:
                        elem_print(n1);
                        assert(0);
                }
                break;
            case OPrelconst:
            case OPvar:
version (SCPP_HTOD)
            case OPsizeof:

                symbol_debug(n1.EV.Vsym);
                symbol_debug(n2.EV.Vsym);
                if (n1.EV.Voffset != n2.EV.Voffset)
                    return false;
version (SCPP_HTOD)
{
                if (gmatch2 & 4)
                {
                    static if (0)
                    {
                        printf("------- symbols ---------\n");
                        symbol_print(n1.EV.Vsym);
                        symbol_print(n2.EV.Vsym);
                        printf("\n");
                    }
                    if (/*strcmp(n1.EV.Vsym.Sident, n2.EV.Vsym.Sident) &&*/
                        n1.EV.Vsym != n2.EV.Vsym &&
                        (!n1.EV.Vsym.Ssequence || n1.EV.Vsym.Ssequence != n2.EV.Vsym.Ssequence))
                        return false;
                }
                else if (n1.EV.Vsym != n2.EV.Vsym)
                    return false;
}
else
{
                if (n1.EV.Vsym != n2.EV.Vsym)
                    return false;
}
                break;

            case OPasm:
            case OPstring:
            {
                const n = n2.EV.Vstrlen;
                if (n1.EV.Vstrlen != n ||
                    n1.EV.Voffset != n2.EV.Voffset ||
                    memcmp(n1.EV.Vstring, n2.EV.Vstring, n))
                        return false;   /* check bytes in the string    */
                break;
            }

            case OPstrthis:
            case OPframeptr:
            case OPhalt:
            case OPgot:
                break;

version (SCPP_HTOD)
{
            case OPmark:
                break;
}
            default:
                WROP(op);
                assert(0);
        }
ismatch:
        return true;
    }
    assert(0);
}

/*******************************
 * Returns: true if trees match.
 */
bool el_match(const elem* n1, const elem* n2)
{
    return el_matchx(n1, n2, 0);
}

/*********************************
 * Kludge on el_match(). Same, but ignore differences in OPconst.
 */

bool el_match2(const elem* n1, const elem* n2)
{
    return el_matchx(n1,n2,1);
}

/*********************************
 * Kludge on el_match(). Same, but ignore differences in type modifiers.
 */

bool el_match3(const elem* n1, const elem* n2)
{
    return el_matchx(n1,n2,2);
}

/*********************************
 * Kludge on el_match(). Same, but ignore differences in spelling of var's.
 */

bool el_match4(const elem* n1, const elem* n2)
{
    return el_matchx(n1,n2,2|4);
}

/*********************************
 * Kludge on el_match(). Same, but regard signed/unsigned as equivalent.
 */

bool el_match5(const elem* n1, const elem* n2)
{
    return el_matchx(n1,n2,8);
}


/******************************
 * Extract long value from constant parser elem.
 */

@trusted
targ_llong el_tolongt(elem *e)
{
    const parsersave = PARSER;
    PARSER = 1;
    const result = el_tolong(e);
    PARSER = parsersave;
    return result;
}

/******************************
 * Extract long value from constant elem.
 */

@trusted
targ_llong el_tolong(elem *e)
{
    elem_debug(e);
    version (SCPP_HTOD)
    {
        if (e.Eoper == OPsizeof)
        {
            e.Eoper = OPconst;
            e.EV.Vllong = type_size(e.EV.Vsym.Stype);
        }
    }
    if (e.Eoper != OPconst)
        elem_print(e);
    assert(e.Eoper == OPconst);
    auto ty = tybasic(typemask(e));
L1:
    targ_llong result;
    switch (ty)
    {
        case TYchar:
            if (config.flags & CFGuchar)
                goto Uchar;
            goto case TYschar;

        case TYschar:
            result = e.EV.Vschar;
            break;

        case TYuchar:
        case TYbool:
        Uchar:
            result = e.EV.Vuchar;
            break;

        case TYshort:
        Ishort:
            result = e.EV.Vshort;
            break;

        case TYushort:
        case TYwchar_t:
        case TYchar16:
        Ushort:
            result = e.EV.Vushort;
            break;
version (SCPP_HTOD)
{
        case TYenum:
            assert(PARSER);
            ty = e.ET.Tnext.Tty;
            goto L1;
}

        case TYsptr:
        case TYcptr:
        case TYnptr:
        case TYnullptr:
        case TYnref:
        case TYimmutPtr:
        case TYsharePtr:
        case TYrestrictPtr:
        case TYfgPtr:
            if (_tysize[TYnptr] == SHORTSIZE)
                goto Ushort;
            if (_tysize[TYnptr] == LONGSIZE)
                goto Ulong;
            if (_tysize[TYnptr] == LLONGSIZE)
                goto Ullong;
            assert(0);

        case TYuint:
            if (_tysize[TYint] == SHORTSIZE)
                goto Ushort;
            goto Ulong;

        case TYulong:
        case TYdchar:
        case TYfptr:
        case TYhptr:
        case TYvptr:
        case TYvoid:                    /* some odd cases               */
        Ulong:
            result = e.EV.Vulong;
            break;

        case TYint:
            if (_tysize[TYint] == SHORTSIZE)
                goto Ishort;
            goto Ilong;

        case TYlong:
        Ilong:
            result = e.EV.Vlong;
            break;

        case TYllong:
        case TYullong:
        Ullong:
            result = e.EV.Vullong;
            break;

        case TYdouble_alias:
        case TYldouble:
        case TYdouble:
        case TYfloat:
        case TYildouble:
        case TYidouble:
        case TYifloat:
        case TYcldouble:
        case TYcdouble:
        case TYcfloat:
            result = cast(targ_llong)el_toldoubled(e);
            break;

version (SCPP_HTOD)
{
        case TYmemptr:
            ty = tybasic(tym_conv(e.ET));
            goto L1;
}

        case TYcent:
        case TYucent:
            goto Ullong; // should do better than this when actually doing arithmetic on cents

        default:
            version (SCPP_HTOD)
            {
                // Can happen as result of syntax errors
                assert(errcnt);
            }
            else
            {
                elem_print(e);
                assert(0);
            }
    }
    return result;
}

/***********************************
 * Determine if constant e is all ones or all zeros.
 * Params:
 *    e = elem to test
 *    bit = 0:  all zeros
 *          1:  1
 *         -1:  all ones
 * Returns:
  *   true if it is
 */

bool el_allbits(const elem* e,int bit)
{
    elem_debug(e);
    assert(e.Eoper == OPconst);
    targ_llong value = e.EV.Vullong;
    switch (tysize(e.Ety))
    {
        case 1: value = cast(byte) value;
                break;

        case 2: value = cast(short) value;
                break;

        case 4: value = cast(int) value;
                break;

        case 8: break;

        default:
                assert(0);
    }
    if (bit == -1)
        value++;
    else if (bit == 1)
        value--;
    return value == 0;
}

/********************************************
 * Determine if constant e is a 32 bit or less value, or is a 32 bit value sign extended to 64 bits.
 */

bool el_signx32(const elem* e)
{
    elem_debug(e);
    assert(e.Eoper == OPconst);
    if (tysize(e.Ety) == 8)
    {
        if (e.EV.Vullong != cast(int)e.EV.Vullong)
            return false;
    }
    return true;
}

/******************************
 * Extract long double value from constant elem.
 * Silently ignore types which are not floating point values.
 */

version (CRuntime_Microsoft)
{
longdouble_soft el_toldouble(elem *e)
{
    longdouble_soft result;
    elem_debug(e);
    assert(e.Eoper == OPconst);
    switch (tybasic(typemask(e)))
    {
        case TYfloat:
        case TYifloat:
            result = longdouble_soft(e.EV.Vfloat);
            break;

        case TYdouble:
        case TYidouble:
        case TYdouble_alias:
            result = longdouble_soft(e.EV.Vdouble);
            break;

        case TYldouble:
        case TYildouble:
            static if (is(typeof(e.EV.Vldouble) == real))
                result = longdouble_soft(e.EV.Vldouble);
            else
                result = longdouble_soft(cast(real)e.EV.Vldouble);
            break;

        default:
            result = longdouble_soft(0);
            break;
    }
    return result;
}
}
else
{
targ_ldouble el_toldouble(elem *e)
{
    targ_ldouble result;
    elem_debug(e);
    assert(e.Eoper == OPconst);
    switch (tybasic(typemask(e)))
    {
        case TYfloat:
        case TYifloat:
            result = e.EV.Vfloat;
            break;

        case TYdouble:
        case TYidouble:
        case TYdouble_alias:
            result = e.EV.Vdouble;
            break;

        case TYldouble:
        case TYildouble:
            result = e.EV.Vldouble;
            break;

        default:
            result = 0;
            break;
    }
    return result;
}
}

/********************************
 * Is elem type-dependent or value-dependent?
 * Returns: true if so
 */

@trusted
bool el_isdependent(elem* e)
{
    if (type_isdependent(e.ET))
        return true;
    while (1)
    {
        if (e.PEFflags & PEFdependent)
            return true;
        if (OTunary(e.Eoper))
            e = e.EV.E1;
        else if (OTbinary(e.Eoper))
        {
            if (el_isdependent(e.EV.E2))
                return true;
            e = e.EV.E1;
        }
        else
            break;
    }
    return false;
}

/****************************************
 * Returns: alignment size of elem e
 */

@trusted
uint el_alignsize(elem *e)
{
    const tym = tybasic(e.Ety);
    uint alignsize = tyalignsize(tym);
    if (alignsize == cast(uint)-1 ||
        (e.Ety & (mTYxmmgpr | mTYgprxmm)))
    {
        assert(e.ET);
        alignsize = type_alignsize(e.ET);
    }
    return alignsize;
}

/*******************************
 * Check for errors in a tree.
 */

debug
{

@trusted
void el_check(const(elem)* e)
{
    elem_debug(e);
    while (1)
    {
        if (OTunary(e.Eoper))
            e = e.EV.E1;
        else if (OTbinary(e.Eoper))
        {
            el_check(e.EV.E2);
            e = e.EV.E1;
        }
        else
            break;
    }
}

}

/*******************************
 * Write out expression elem.
 */

@trusted
void elem_print(const elem* e, int nestlevel = 0)
{
    foreach (i; 0 .. nestlevel)
        printf(" ");
    printf("el:%p ",e);
    if (!e)
    {
        printf("\n");
        return;
    }
    elem_debug(e);
    if (configv.addlinenumbers)
    {
        version (MARS)
        {
            if (e.Esrcpos.Sfilename)
                printf("%s(%u) ", e.Esrcpos.Sfilename, e.Esrcpos.Slinnum);
        }
        else
            e.Esrcpos.print("elem_print");
    }
    if (!PARSER)
    {
        printf("cnt=%d ",e.Ecount);
        if (!OPTIMIZER)
            printf("cs=%d ",e.Ecomsub);
    }
    WROP(e.Eoper);
    printf(" ");
    version (SCPP_HTOD)
        enum scpp = true;
    else
        enum scpp = false;
    if (scpp && PARSER)
    {
        if (e.ET)
        {
            type_debug(e.ET);
            if (tybasic(e.ET.Tty) == TYstruct)
                printf("%d ", cast(int)type_size(e.ET));
            WRTYxx(e.ET.Tty);
        }
    }
    else
    {
        if ((e.Eoper == OPstrpar || e.Eoper == OPstrctor || e.Eoper == OPstreq) ||
            e.Ety == TYstruct || e.Ety == TYarray)
            if (e.ET)
                printf("%d ", cast(int)type_size(e.ET));
        WRTYxx(e.Ety);
    }
    if (OTunary(e.Eoper))
    {
        if (e.EV.E2)
            printf("%p %p\n",e.EV.E1,e.EV.E2);
        else
            printf("%p\n",e.EV.E1);
        elem_print(e.EV.E1, nestlevel + 1);
    }
    else if (OTbinary(e.Eoper))
    {
        if (!PARSER && e.Eoper == OPstreq && e.ET)
                printf("bytes=%d ", cast(int)type_size(e.ET));
        printf("%p %p\n",e.EV.E1,e.EV.E2);
        elem_print(e.EV.E1, nestlevel + 1);
        elem_print(e.EV.E2, nestlevel + 1);
    }
    else
    {
        switch (e.Eoper)
        {
            case OPrelconst:
                printf(" %lld+&",cast(ulong)e.EV.Voffset);
                printf(" %s",e.EV.Vsym.Sident.ptr);
                break;

            case OPvar:
                if (e.EV.Voffset)
                    printf(" %lld+",cast(ulong)e.EV.Voffset);
                printf(" %s",e.EV.Vsym.Sident.ptr);
                break;

            case OPasm:
            case OPstring:
                printf(" '%s',%lld\n",e.EV.Vstring,cast(ulong)e.EV.Voffset);
                break;

            case OPconst:
                elem_print_const(e);
                break;

            default:
                break;
        }
        printf("\n");
    }
}

@trusted
void elem_print_const(const elem* e)
{
    assert(e.Eoper == OPconst);
    tym_t tym = tybasic(typemask(e));
case_tym:
    switch (tym)
    {   case TYbool:
        case TYchar:
        case TYschar:
        case TYuchar:
            printf("%d ",e.EV.Vuchar);
            break;

        case TYsptr:
        case TYcptr:
        case TYnullptr:
        case TYnptr:
        case TYnref:
        case TYimmutPtr:
        case TYsharePtr:
        case TYrestrictPtr:
        case TYfgPtr:
            if (_tysize[TYnptr] == LONGSIZE)
                goto L1;
            if (_tysize[TYnptr] == SHORTSIZE)
                goto L3;
            if (_tysize[TYnptr] == LLONGSIZE)
                goto L2;
            assert(0);

        case TYenum:
            if (PARSER)
            {   tym = e.ET.Tnext.Tty;
                goto case_tym;
            }
            goto case TYint;

        case TYint:
        case TYuint:
        case TYvoid:        /* in case (void)(1)    */
            if (tysize(TYint) == LONGSIZE)
                goto L1;
            goto case TYshort;

        case TYshort:
        case TYwchar_t:
        case TYushort:
        case TYchar16:
        L3:
            printf("%d ",e.EV.Vint);
            break;

        case TYlong:
        case TYulong:
        case TYdchar:
        case TYfptr:
        case TYvptr:
        case TYhptr:
        L1:
            printf("%dL ",e.EV.Vlong);
            break;

        case TYllong:
        L2:
            printf("%lldLL ",cast(ulong)e.EV.Vllong);
            break;

        case TYullong:
            printf("%lluLL ",cast(ulong)e.EV.Vullong);
            break;

        case TYcent:
        case TYucent:
            printf("%lluLL+%lluLL ", cast(ulong)e.EV.Vcent.msw, cast(ulong)e.EV.Vcent.lsw);
            break;

        case TYfloat:
            printf("%gf ",cast(double)e.EV.Vfloat);
            break;

        case TYdouble:
        case TYdouble_alias:
            printf("%g ",cast(double)e.EV.Vdouble);
            break;

        case TYldouble:
        {
            version (CRuntime_Microsoft)
            {
                char[3 + 3 * (targ_ldouble).sizeof + 1] buffer = void;
                static if (is(typeof(e.EV.Vldouble) == real))
                    ld_sprint(buffer.ptr, 'g', longdouble_soft(e.EV.Vldouble));
                else
                    ld_sprint(buffer.ptr, 'g', longdouble_soft(cast(real)e.EV.Vldouble));
                printf("%s ", buffer.ptr);
            }
            else
                printf("%Lg ", e.EV.Vldouble);
            break;
        }

        case TYifloat:
            printf("%gfi ", cast(double)e.EV.Vfloat);
            break;

        case TYidouble:
            printf("%gi ", cast(double)e.EV.Vdouble);
            break;

        case TYildouble:
            printf("%gLi ", cast(double)e.EV.Vldouble);
            break;

        case TYcfloat:
            printf("%gf+%gfi ", cast(double)e.EV.Vcfloat.re, cast(double)e.EV.Vcfloat.im);
            break;

        case TYcdouble:
            printf("%g+%gi ", cast(double)e.EV.Vcdouble.re, cast(double)e.EV.Vcdouble.im);
            break;

        case TYcldouble:
            printf("%gL+%gLi ", cast(double)e.EV.Vcldouble.re, cast(double)e.EV.Vcldouble.im);
            break;

        case TYfloat4:
        case TYdouble2:
        case TYschar16:
        case TYuchar16:
        case TYshort8:
        case TYushort8:
        case TYlong4:
        case TYulong4:
        case TYllong2:
        case TYullong2:
            printf("%llxLL+%llxLL ", cast(long)e.EV.Vcent.msw, cast(long)e.EV.Vcent.lsw);
            break;

version (MARS) { } else
{
        case TYident:
            printf("'%s' ", e.ET.Tident);
            break;
}

        default:
            printf("Invalid type ");
            WRTYxx(typemask(e));
            /*assert(0);*/
    }
}

/**********************************
 * Hydrate an elem.
 */

static if (HYDRATE)
{
void el_hydrate(elem **pe)
{
    if (!isdehydrated(*pe))
        return;

    assert(PARSER);
    elem* e = cast(elem *) ph_hydrate(cast(void**)pe);
    elem_debug(e);

    debug if (!(e.Eoper < OPMAX))
        printf("e = x%lx, e.Eoper = %d\n",e,e.Eoper);

    debug assert(e.Eoper < OPMAX);
    type_hydrate(&e.ET);
    if (configv.addlinenumbers)
    {
        filename_translate(&e.Esrcpos);
        srcpos_hydrate(&e.Esrcpos);
    }
    if (!OTleaf(e.Eoper))
    {
        el_hydrate(&e.EV.E1);
        if (OTbinary(e.Eoper))
            el_hydrate(&e.EV.E2);
        else if (e.Eoper == OPctor)
        {
            version (SCPP_HTOD)
            {
                symbol_hydrate(&e.EV.Edtor);
                symbol_debug(e.EV.Edtor);
            }
        }
    }
    else
    {
        switch (e.Eoper)
        {
            case OPstring:
            case OPasm:
                ph_hydrate(cast(void**)&e.EV.Vstring);
                break;

            case OPrelconst:
                //if (tybasic(e.ET.Tty) == TYmemptr)
                    //el_hydrate(&e.EV.sm.ethis);
            case OPvar:
                symbol_hydrate(&e.EV.Vsym);
                symbol_debug(e.EV.Vsym);
                break;

            default:
                break;
        }
    }
}
}

/**********************************
 * Dehydrate an elem.
 */

static if (DEHYDRATE)
{
void el_dehydrate(elem **pe)
{
    elem* e = *pe;
    if (e == null || isdehydrated(e))
        return;

    assert(PARSER);
    elem_debug(e);

    debug if (!(e.Eoper < OPMAX))
        printf("e = x%lx, e.Eoper = %d\n",e,e.Eoper);

    debug_assert(e.Eoper < OPMAX);
    ph_dehydrate(pe);

    version (DEBUG_XSYMGEN)
    {
        if (xsym_gen && ph_in_head(e))
            return;
    }

    type_dehydrate(&e.ET);
    if (configv.addlinenumbers)
        srcpos_dehydrate(&e.Esrcpos);
    if (!OTleaf(e.Eoper))
    {
        el_dehydrate(&e.EV.E1);
        if (OTbinary(e.Eoper))
            el_dehydrate(&e.EV.E2);
        else
        {
            version (SCPP_HTOD)
            {
                if (e.Eoper == OPctor)
                    symbol_dehydrate(&e.EV.eop.Edtor);
            }
        }
    }
    else
    {
        switch (e.Eoper)
        {
            case OPstring:
            case OPasm:
                ph_dehydrate(&e.EV.Vstring);
                break;

            case OPrelconst:
                //if (tybasic(e.ET.Tty) == TYmemptr)
                    //el_dehydrate(&e.EV.sm.ethis);
            case OPvar:
                symbol_dehydrate(&e.EV.Vsym);
                break;

            default:
                break;
        }
    }
}
}

}
