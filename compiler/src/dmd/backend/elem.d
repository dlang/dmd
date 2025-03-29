/**
 * Routines to handle elems.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/elem.d, backend/elem.d)
 */

module dmd.backend.elem;

import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.cgcv;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
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

version (CRuntime_Microsoft)
{
    import dmd.root.longdouble;
}

/+
version (CRuntime_Microsoft) extern (C++)
{
    alias real_t = real;
    private struct longdouble_soft { real_t r; }
    size_t ld_sprint(char* str, size_t size, int fmt, longdouble_soft x);
}
+/


nothrow:
@safe:

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
    elem* nextfree = null;           /* pointer to next free elem    */

    int elcount = 0;                 /* number of allocated elems    */
    int elem_size = elem.sizeof;

    debug
    int elmax;                       /* max # of allocs at any point */
}

/////////////////////////////
// Table to gather redundant strings in.

struct STAB
{
    Symbol* sym;        // symbol that refers to the string
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
            elem* e;
            e = nextfree.E1;
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
elem* el_calloc()
{
    elem* e;

    elcount++;
    if (nextfree)
    {
        e = nextfree;
        nextfree = e.E1;
    }
    else
        e = cast(elem*) mem_fmalloc(elem.sizeof);

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
void el_free(elem* e)
{
L1:
    if (!e) return;
    elem_debug(e);
    //printf("el_free(%p)\n",e);
    //elem_print(e);
    if (e.Ecount--)
        return;                         // usage count
    elcount--;
    const op = e.Eoper;
    switch (op)
    {
        case OPconst:
            break;

        case OPvar:
            break;

        case OPrelconst:
            break;

        case OPstring:
        case OPasm:
            mem_free(e.Vstring);
            break;

        default:
            debug assert(op < OPMAX);
            if (!OTleaf(op))
            {
                if (OTbinary(op))
                    el_free(e.E2);
                elem* en = e.E1;
                debug memset(e,0xFF,elem_size);
                e.E1 = nextfree;
                nextfree = e;

                version (STATS)
                    elfreed++;

                e = en;
                goto L1;
            }
            break;
    }
    debug memset(e,0xFF,elem_size);
    e.E1 = nextfree;
    nextfree = e;

    version (STATS)
        elfreed++;
}

version (STATS)
{
    /* count number of elems available on free list */
    void el_count_free()
    {
        elem* e;
        int count;

        for(e=nextfree;e;e=e.E1)
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

elem* el_combine(elem* e1,elem* e2)
{
    if (e1)
    {
        if (e2)
        {
            e1 = el_bin(OPcomma,e2.Ety,e1,e2);
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

elem* el_param(elem* e1,elem* e2)
{
    //printf("el_param(%p, %p)\n", e1, e2);
    if (e1)
    {
        if (e2)
        {
            e1 = el_bin(OPparam,TYvoid,e1,e2);
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
elem* el_params(elem* e1, ...)
{
    elem* e;
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
elem* el_params(void** args, int length)
{
    if (length == 0)
        return null;
    if (length == 1)
        return cast(elem*)args[0];
    int mid = length >> 1;
    return el_param(el_params(args, mid),
                    el_params(args + mid, length - mid));
}

/*****************************************
 * Do an array of parameters as a balanced
 * binary tree.
 */

@trusted
elem* el_combines(void** args, int length)
{
    if (length == 0)
        return null;
    if (length == 1)
        return cast(elem*)args[0];
    int mid = length >> 1;
    return el_combine(el_combines(args, mid),
                    el_combines(args + mid, length - mid));
}

/**************************************
 * Return number of op nodes
 */

@trusted
size_t el_opN(const elem* e, OPER op)
{
    if (e.Eoper == op)
        return el_opN(e.E1, op) + el_opN(e.E2, op);
    else
        return 1;
}

/******************************************
 * Fill an array with the ops.
 */

@trusted
void el_opArray(elem ***parray, elem* e, OPER op)
{
    if (e.Eoper == op)
    {
        el_opArray(parray, e.E1, op);
        el_opArray(parray, e.E2, op);
    }
    else
    {
        **parray = e;
        ++(*parray);
    }
}

@trusted
void el_opFree(elem* e, OPER op)
{
    if (e.Eoper == op)
    {
        el_opFree(e.E1, op);
        el_opFree(e.E2, op);
        e.E1 = null;
        e.E2 = null;
        el_free(e);
    }
}

/*****************************************
 * Do an array of parameters as a tree
 */

@trusted
elem* el_opCombine(elem** args, size_t length, OPER op, tym_t ty)
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

int el_nparams(const elem* e)
{
    return cast(int)el_opN(e, OPparam);
}

/******************************************
 * Fill an array with the parameters.
 */

@trusted
void el_paramArray(elem ***parray, elem* e)
{
    if (e.Eoper == OPparam)
    {
        el_paramArray(parray, e.E1);
        el_paramArray(parray, e.E2);
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

elem* el_pair(tym_t tym, elem* lo, elem* hi)
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
void el_copy(elem* to, const elem* from)
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
elem* el_alloctmp(tym_t ty)
{
    Symbol* s;
    s = symbol_generate(SC.auto_,type_fake(ty));
    symbol_add(s);
    s.Sfl = FL.auto_;
    s.Sflags = SFLfree | SFLunambig | GTregcand;
    return el_var(s);
}

/********************************
 * Select the e1 child of e.
 */

@trusted
elem* el_selecte1(elem* e)
{
    elem* e1;
    elem_debug(e);
    assert(!OTleaf(e.Eoper));
    e1 = e.E1;
    elem_debug(e1);
    if (e.E2) elem_debug(e.E2);
    e.E1 = null;                               // so e1 won't be freed
    if (configv.addlinenumbers)
    {
        if (e.Esrcpos.Slinnum)
            e1.Esrcpos = e.Esrcpos;
    }
    e1.Ety = e.Ety;
    //if (tyaggregate(e1.Ety))
    //    e1.Enumbytes = e.Enumbytes;
    if (!e1.Ejty)
        e1.Ejty = e.Ejty;
    el_free(e);
    return e1;
}

/********************************
 * Select the e2 child of e.
 */

@trusted
elem* el_selecte2(elem* e)
{
    elem* e2;
    //printf("el_selecte2(%p)\n",e);
    elem_debug(e);
    assert(OTbinary(e.Eoper));
    if (e.E1)
        elem_debug(e.E1);
    e2 = e.E2;
    elem_debug(e2);
    e.E2 = null;                       // so e2 won't be freed
    if (configv.addlinenumbers)
    {
        if (e.Esrcpos.Slinnum)
            e2.Esrcpos = e.Esrcpos;
    }
    e2.Ety = e.Ety;
    //if (tyaggregate(e.Ety))
    //    e2.Enumbytes = e.Enumbytes;
    el_free(e);
    return e2;
}

/*************************
 * Create and return a duplicate of e, including its leaves.
 * No CSEs.
 */

@trusted
elem* el_copytree(elem* e)
{
    elem* d;
    if (!e)
        return e;
    elem_debug(e);
    d = el_calloc();
    el_copy(d,e);
    d.Ecount = 0;
    if (!OTleaf(e.Eoper))
    {
        d.E1 = el_copytree(e.E1);
        if (OTbinary(e.Eoper))
            d.E2 = el_copytree(e.E2);
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
                    d.Vsym = e.Vsym;
                    break;
                }
}
static if (0)
{
            case OPrelconst:
                e.sm.ethis = null;
                break;
}
            case OPasm:
                d.Vstring = cast(char*) mem_malloc(d.Vstrlen);
                memcpy(d.Vstring,e.Vstring,e.Vstrlen);
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
@trusted
elem* exp2_copytotemp(elem* e)
{
    //printf("exp2_copytotemp()\n");
    elem_debug(e);
    tym_t ty = tybasic(e.Ety);
    type* t;
    if ((ty == TYstruct || ty == TYarray) && e.ET)
        t = e.ET;
    else
        t = type_fake(ty);

    Symbol* stmp = symbol_genauto(t);
    elem* eeq = el_bin(OPeq,e.Ety,el_var(stmp),e);
    elem* er = el_bin(OPcomma,e.Ety,eeq,el_var(stmp));
    if (ty == TYstruct || ty == TYarray)
    {
        eeq.Eoper = OPstreq;
        eeq.ET = e.ET;
        eeq.E1.ET = e.ET;
        er.ET = e.ET;
        er.E2.ET = e.ET;
    }
    return er;
}

/*************************
 * Similar to el_copytree(e). But if e has any side effects, it's replaced
 * with (tmp = e) and tmp is returned.
 */

@trusted
elem* el_same(ref elem* pe)
{
    elem* e = pe;
    if (e && el_sideeffect(e))
    {
        pe = exp2_copytotemp(e);       /* convert to ((tmp=e),tmp)     */
        e = pe.E2;                  /* point at tmp                 */
    }
    return el_copytree(e);
}

/*************************
 * Thin wrapper of exp2_copytotemp. Different from el_same,
 * always makes a temporary.
 */
@trusted
elem* el_copytotmp(ref elem* pe)
{
    //printf("copytotemp()\n");
    elem* e = pe;
    if (e)
    {
        pe = exp2_copytotemp(e);
        e = pe.E2;
    }
    return el_copytree(e);
}

/*************************************
 * Does symbol s appear in tree e?
 * Returns:
 *      1       yes
 *      0       no
 */

@trusted
int el_appears(const(elem)* e, const Symbol* s)
{
    symbol_debug(s);
    while (1)
    {
        elem_debug(e);
        if (!OTleaf(e.Eoper))
        {
            if (OTbinary(e.Eoper) && el_appears(e.E2,s))
                return 1;
            e = e.E1;
        }
        else
        {
            switch (e.Eoper)
            {
                case OPvar:
                case OPrelconst:
                    if (e.Vsym == s)
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

/*****************************************
 * Look for symbol that is a base of addressing mode e.
 * Returns:
 *      s       symbol used as base
 *      null    couldn't find a base symbol
 */

static if (0)
{
Symbol* el_basesym(elem* e)
{
    Symbol* s;
    s = null;
    while (1)
    {
        elem_debug(e);
        switch (e.Eoper)
        {
            case OPvar:
                s = e.Vsym;
                break;

            case OPcomma:
                e = e.E2;
                continue;

            case OPind:
                s = el_basesym(e.E1);
                break;

            case OPadd:
                s = el_basesym(e.E1);
                if (!s)
                    s = el_basesym(e.E2);
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
bool el_anydef(const elem* ed, const(elem)* e)
{
    const edop = ed.Eoper;
    const s = (edop == OPvar) ? ed.Vsym : null;
    while (1)
    {
        const op = e.Eoper;
        if (!OTleaf(op))
        {
            auto e1 = e.E1;
            if (OTdef(op))
            {
                if (e1.Eoper == OPvar && e1.Vsym == s)
                    return true;

                // This doesn't cover all the cases
                if (e1.Eoper == edop && el_match(e1,ed))
                    return true;
            }
            if (OTbinary(op) && el_anydef(ed,e.E2))
                return true;
            e = e1;
        }
        else
            break;
    }
    return false;
}

/************************
 * Make a binary operator node.
 */


@trusted
elem* el_bin(OPER op,tym_t ty,elem* e1,elem* e2)
{
static if (0)
{
    if (!(op < OPMAX && OTbinary(op) && e1 && e2))
        *cast(char*)0=0;
}
    assert(op < OPMAX && OTbinary(op) && e1 && e2);
    elem_debug(e1);
    elem_debug(e2);
    elem* e = el_calloc();
    e.Ety = ty;
    e.Eoper = cast(ubyte)op;
    e.E1 = e1;
    e.E2 = e2;
    if (op == OPcomma && tyaggregate(ty))
        e.ET = e2.ET;
    return e;
}

/************************
 * Make a unary operator node.
 */
@trusted
elem* el_una(OPER op,tym_t ty,elem* e1)
{
    debug if (!(op < OPMAX && OTunary(op) && e1))
        printf("op = x%x, e1 = %p\n",op,e1);

    assert(op < OPMAX && OTunary(op) && e1);
    elem_debug(e1);
    elem* e = el_calloc();
    e.Ety = ty;
    e.Eoper = cast(ubyte)op;
    e.E1 = e1;
    return e;
}


elem* el_long(tym_t t,targ_llong val)
{
    elem* e = el_calloc();
    e.Eoper = OPconst;
    e.Ety = t;
    switch (tybasic(t))
    {
        case TYfloat:
        case TYifloat:
            e.Vfloat = val;
            break;

        case TYdouble:
        case TYidouble:
            e.Vdouble = val;
            break;

        case TYldouble:
        case TYildouble:
            e.Vldouble = val;
            break;

        case TYcfloat:
        case TYcdouble:
        case TYcldouble:
            assert(0);

        default:
            e.Vllong = val;
            break;
    }
    return e;
}

/******************************
 * Create a const integer vector elem
 * Params:
 *      ty = type of the vector
 *      val = value to broadcast to the vector elements
 * Returns:
 *      created OPconst elem
 */
@trusted
elem* el_vectorConst(tym_t ty, ulong val)
{
    elem* e = el_calloc();
    e.Eoper = OPconst;
    e.Ety = ty;
    const sz = tysize(ty);

    if (val == 0 || !((val & 0xFF) + 1))
    {
        memset(&e.EV, cast(ubyte)val, sz);
        return e;
    }

    switch (tybasic(ty))
    {
        case TYschar16:
        case TYuchar16:
        case TYschar32:
        case TYuchar32:
            foreach (i; 0 .. sz)
            {
                e.Vuchar32[i] = cast(ubyte)val;
            }
            break;

        case TYshort8:
        case TYushort8:
        case TYshort16:
        case TYushort16:
            foreach (i; 0 .. sz / 2)
            {
                e.Vushort16[i] = cast(ushort)val;
            }
            break;

        case TYlong4:
        case TYulong4:
        case TYlong8:
        case TYulong8:
            foreach (i; 0 .. sz / 4)
            {
                e.Vulong8[i] = cast(uint)val;
            }
            break;

        case TYllong2:
        case TYullong2:
        case TYllong4:
        case TYullong4:
            foreach (i; 0 .. sz / 8)
            {
                e.Vullong4[i] = val;
            }
            break;

        default:
            assert(0);
    }
    return e;
}

/*******************************
 * Set new type for elem.
 */

elem* el_settype(elem* e,type* t)
{
    assert(0);
}

/*******************************
 * Create elem that is the size of a type.
 */

elem* el_typesize(type* t)
{
    assert(0);
}

/************************************
 * Returns: true if function has any side effects.
 */

@trusted
bool el_funcsideeff(const elem* e)
{
    const(Symbol)* s;
    if (e.Eoper == OPvar &&
        tyfunc((s = e.Vsym).Stype.Tty) &&
        ((s.Sfunc && s.Sfunc.Fflags3 & Fnosideeff) || s == funcsym_p)
       )
        return false;
    return true;                   // assume it does have side effects
}

/****************************
 * Returns: true if elem has any side effects.
 */

@trusted
bool el_sideeffect(const elem* e)
{
    assert(e);
    const op = e.Eoper;
    assert(op < OPMAX);
    elem_debug(e);
    return  typemask(e) & (mTYvolatile | mTYshared) ||
            OTsideff(op) ||
            (OTunary(op) && el_sideeffect(e.E1)) ||
            (OTbinary(op) && (el_sideeffect(e.E1) ||
                                  el_sideeffect(e.E2)));
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
int el_depends(const(elem)* ea, const elem* eb)
{
 L1:
    elem_debug(ea);
    elem_debug(eb);
    switch (ea.Eoper)
    {
        case OPbit:
            ea = ea.E1;
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
            goto Lnodep;

        case OPvar:
            if (ea.Eoper == OPvar && ea.Vsym != eb.Vsym)
                goto Lnodep;
            break;

        default:
            break;      // this could use improvement
    }
    return 1;

Lnodep:
    return 0;
}


/*************************
 * Returns:
 *      true   elem evaluates right-to-left
 *      false  elem evaluates left-to-right
 */

@trusted
bool ERTOL(const elem* e)
{
    elem_debug(e);
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
                e = e.E1;
                if (e.Eoper == OPvar && e.Vsym.Sflags & SFLexit)
                    return false;
                break;

            case OPhalt:
                return false;

            case OPandand:
            case OPoror:
                e = e.E1;
                continue;

            case OPcolon:
            case OPcolon2:
                return el_returns(e.E1) || el_returns(e.E2);

            default:
                if (OTbinary(e.Eoper))
                {
                    if (!el_returns(e.E2))
                        return false;
                    e = e.E1;
                    continue;
                }
                if (OTunary(e.Eoper))
                {
                    e = e.E1;
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
 * Extra layer of indirection so we can update
 * (*ret)
 */

@trusted
elem** el_scancommas(elem** pe)
{
    while ((*pe).Eoper == OPcomma)
        pe = &(*pe).E2;
    return pe;
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
            ncommas += (e.Eoper == OPcomma) + el_countCommas(e.E2);
        }
        else if (OTunary(e.Eoper))
        {
        }
        else
            break;
        e = e.E1;
    }
    return ncommas;
}

/************************************
 * Convert floating point constant to a read-only symbol.
 * Needed iff floating point code can't load immediate constants.
 */
@trusted
elem* el_convfloat(ref GlobalOptimizer go, elem* e)
{
    //printf("el_convfloat()\n"); elem_print(e);
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
    void* p;
    switch (tybasic(ty))
    {
        case TYfloat:
        case TYifloat:
            p = &e.Vfloat;
            assert(sz == (e.Vfloat).sizeof);
            break;

        case TYdouble:
        case TYidouble:
        case TYdouble_alias:
            p = &e.Vdouble;
            assert(sz == (e.Vdouble).sizeof);
            break;

        case TYldouble:
        case TYildouble:
            /* The size, alignment, and padding of long doubles may be different
             * from host to target
             */
            p = buffer.ptr;
            memset(buffer.ptr, 0, sz);                      // ensure padding is 0
            memcpy(buffer.ptr, &e.Vldouble, 10);
            break;

        case TYcfloat:
            p = &e.Vcfloat;
            assert(sz == (e.Vcfloat).sizeof);
            break;

        case TYcdouble:
            p = &e.Vcdouble;
            assert(sz == (e.Vcdouble).sizeof);
            break;

        case TYcldouble:
            p = buffer.ptr;
            memset(buffer.ptr, 0, sz);
            memcpy(buffer.ptr, &e.Vcldouble.re, 10);
            memcpy(buffer.ptr + tysize(TYldouble), &e.Vcldouble.im, 10);
            break;

        default:
            assert(0);
    }

    static if (0)
    {
        printf("%gL+%gLi\n", cast(double)e.Vcldouble.re, cast(double)e.Vcldouble.im);
        printf("el_convfloat() %g %g sz=%d\n", e.Vcdouble.re, e.Vcdouble.im, sz);
        printf("el_convfloat(): sz = %d\n", sz);
        ushort* p = cast(ushort*)&e.Vcldouble;
        for (int i = 0; i < sz/2; i++) printf("%04x ", p[i]);
        printf("\n");
    }

    Symbol* s  = out_readonly_sym(ty, p, sz);
    el_free(e);
    e = el_var(s);
    e.Ety = ty;
    if (e.Eoper == OPvar)
        e.Ety |= mTYconst;
    //printf("s: %s %d:x%x\n", s.Sident, s.Sseg, s.Soffset);
    return e;
}

/************************************
 * Convert vector constant to a read-only symbol.
 * Needed iff vector code can't load immediate constants.
 */

@trusted
elem* el_convxmm(ref GlobalOptimizer go, elem* e)
{
    ubyte[Vconst.sizeof] buffer = void;

    // Do not convert if the constants can be loaded with the special XMM instructions
    if (loadxmmconst(e))
        return e;

    go.changes++;
    tym_t ty = e.Ety;
    int sz = tysize(ty);
    assert(sz <= buffer.length);
    void* p = &e.EV;

    static if (0)
    {
        printf("el_convxmm(): sz = %d\n", sz);
        for (size i = 0; i < sz; i++) printf("%02x ", (cast(ubyte*)p)[i]);
        printf("\n");
    }

    Symbol* s  = out_readonly_sym(ty, p, sz);
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
elem* el_convstring(elem* e)
{
    //printf("el_convstring()\n");
    int i;
    Symbol* s;
    char* p;

    elem_debug(e);
    assert(e.Eoper == OPstring);
    p = e.Vstring;
    e.Vstring = null;
    size_t len = e.Vstrlen;

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
            mem_free(p);
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
    elem* ex = el_ptr(s);
    ex.Ety = e.Ety;
    if (e.Voffset)
    {
        if (ex.Eoper == OPrelconst)
             ex.Voffset += e.Voffset;
        else
             ex = el_bin(OPadd, ex.Ety, ex, el_long(TYint, e.Voffset));
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
void shrinkLongDoubleConstantIfPossible(elem* e)
{
    if (e.Eoper == OPconst && e.Ety == TYldouble)
    {
        /* Check to see if it can be converted into a double (this happens
         * when the low bits are all zero, and the exponent is in the
         * double range).
         * Use 'volatile' to prevent optimizer from folding away the conversions,
         * and thereby missing the truncation in the conversion to double.
         */
        auto v = e.Vldouble;
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
            e.Vdouble = vDouble;
            e.Ety = TYdouble;
        }
    }
}
}


/*************************
 * Run through a tree converting it to CODGEN.
 */
@trusted
elem* el_convert(ref GlobalOptimizer go, elem* e)
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
                e = el_convxmm(go, e);
            else if (tyfloating(e.Ety) && config.inline8087)
                e = el_convfloat(go, e);
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
                e.E2.Eoper == OPconst && el_toldoubled(e.E2) == 2.0L)
            {
                e.E1 = el_convert(go, e.E1);
                /* Don't call el_convert(e.E2), we want it to stay as a constant
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
                 shrinkLongDoubleConstantIfPossible(e.E1);
            if (tyreal(e.Ety))
                shrinkLongDoubleConstantIfPossible(e.E2);
            goto default;

        default:
            if (OTbinary(op))
            {
                e.E1 = el_convert(go, e.E1);
                e.E2 = el_convert(go, e.E2);
            }
            else if (OTunary(op))
            {
                e.E1 = el_convert(go, e.E1);
            }
            break;
    }
    return e;
}


/************************
 * Make a constant elem.
 *      ty      = type of elem
 *      *pconst = union of constant data
 */

@safe
elem* el_const(tym_t ty, ref Vconst pconst)
{
    elem* e = el_calloc();
    e.Eoper = OPconst;
    e.Ety = ty;
    e.EV = pconst;
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
elem* el_dctor(elem* e,void* decl)
{
    elem* ector = el_calloc();
    ector.Eoper = OPdctor;
    ector.Ety = TYvoid;
    ector.ed.Edecl = decl;
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
elem* el_ddtor(elem* e,void* decl)
{
    /* A destructor always executes code, or we wouldn't need
     * eh for it.
     * An OPddtor must match 1:1 with an OPdctor
     */
    elem* edtor = el_calloc();
    edtor.Eoper = OPddtor;
    edtor.Ety = TYvoid;
    edtor.ed.Edecl = decl;
    edtor.ed.Eleft = e;
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
elem* el_ctor_dtor(elem* ec, elem* ed, out elem* pedtor)
{
    elem* er;
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
        Symbol* sflag = symbol_name("__flag", SC.auto_, type_fake(mTYvolatile | TYbool));
        Symbol* sreg = symbol_name("__EAX", SC.pseudo, type_fake(mTYvolatile | TYnptr));
        sreg.Sreglsw = 0;          // EAX, RAX, whatevs
        Symbol* seo = symbol_name("__exception_object", SC.auto_, tspvoid);

        symbol_add(sflag);
        symbol_add(sreg);
        symbol_add(seo);

        elem* ector = el_calloc();
        ector.Eoper = OPdctor;
        ector.Ety = TYvoid;
//      ector.ed.Edecl = decl;

        Vconst c = void;
        memset(&c, 0, c.sizeof);
        elem* e_flag_0 = el_bin(OPeq, TYvoid, el_var(sflag), el_const(TYbool, c));  // __flag = 0
        er = el_bin(OPinfo, ec ? ec.Ety : TYvoid, ector, el_combine(e_flag_0, ec));

        /* A destructor always executes code, or we wouldn't need
         * eh for it.
         * An OPddtor must match 1:1 with an OPdctor
         */
        elem* edtor = el_calloc();
        edtor.Eoper = OPddtor;
        edtor.Ety = TYvoid;
//      edtor.Edecl = decl;
//      edtor.E1 = e;

        c.Vint = 1;
        elem* e_flag_1 = el_bin(OPeq, TYvoid, el_var(sflag), el_const(TYbool, c));  // __flag = 1
        elem* e_eax = el_bin(OPeq, TYvoid, el_var(seo), el_var(sreg));              // __exception_object = __EAX
        elem* eu = el_bin(OPcall, TYvoid, el_var(getRtlsym(RTLSYM.UNWIND_RESUME)), el_var(seo));
        eu = el_bin(OPandand, TYvoid, el_una(OPnot, TYbool, el_var(sflag)), eu);

        edtor.E1 = el_combine(el_combine(e_eax, ed), eu);

        pedtor = el_combine(e_flag_1, edtor);
    }
    else
    {
        /* Construct (note that OPinfo is evaluated RTOL):
         *  er = (OPdctor OPinfo ec)
         *  edtor = (OPddtor ed)
         */
        elem* ector = el_calloc();
        ector.Eoper = OPdctor;
        ector.Ety = TYvoid;
//      ector.ed.Edecl = decl;
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
        elem* edtor = el_calloc();
        edtor.Eoper = OPddtor;
        edtor.Ety = TYvoid;
//      edtor.Edecl = decl;
        edtor.E1 = ed;
        pedtor = edtor;
    }

    return er;
}

/*******************
 * Find and return pointer to parent of e starting at pe.
 * Return null if can't find it.
 */

@trusted
elem ** el_parent(elem* e, return ref elem* pe)
{
    assert(e && pe);
    elem_debug(e);
    elem_debug(pe);
    if (e == pe)
        return &pe; // not @safe
    else if (OTunary(pe.Eoper))
        return el_parent(e, pe.E1);
    else if (OTbinary(pe.Eoper))
    {
        elem** pe2 = el_parent(e, pe.E1);
        if (pe2)
            return pe2;
        return el_parent(e, pe.E2);
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
        if (OPTIMIZER)
        {
            if (op == OPstrpar || op == OPstrctor)
            {   if (/*n1.Enumbytes != n2.Enumbytes ||*/ n1.ET != n2.ET)
                    return false;
            }
            n1 = n1.E1;
            n2 = n2.E1;
            assert(n1 && n2);
            goto L1;
        }
        else
        {
            if (n1.E1 == n2.E1)
                goto ismatch;
            n1 = n1.E1;
            n2 = n2.E1;
            assert(n1 && n2);
            goto L1;
        }
  }
  else if (OTbinary(op))
  {
        if (op == OPstreq)
        {
            if (/*n1.Enumbytes != n2.Enumbytes ||*/ n1.ET != n2.ET)
                return false;
        }
        if (el_matchx(n1.E2, n2.E2, gmatch2))
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
                switch (tybasic(tym))
                {
                    case TYshort:
                    case TYwchar_t:
                    case TYushort:
                    case TYchar16:
                    case_short:
                        if (n1.Vshort != n2.Vshort)
                            return false;
                        break;

                    case TYlong:
                    case TYulong:
                    case TYdchar:
                    case_long:
                        if (n1.Vlong != n2.Vlong)
                            return false;
                        break;

                    case TYllong:
                    case TYullong:
                    case_llong:
                        if (n1.Vllong != n2.Vllong)
                            return false;
                        break;

                    case TYcent:
                    case TYucent:
                        if (n1.Vcent != n2.Vcent)
                                return false;
                        break;

                    case TYenum:
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
                        if (n1.Vschar != n2.Vschar)
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
                        if (memcmp(&n1.EV,&n2.EV,(n1.Vfloat).sizeof))
                            return false;
                        break;

                    case TYdouble:
                    case TYdouble_alias:
                    case TYidouble:
                        if (memcmp(&n1.EV,&n2.EV,(n1.Vdouble).sizeof))
                            return false;
                        break;

                    case TYldouble:
                    case TYildouble:
                        static if ((n1.Vldouble).sizeof > 10)
                        {
                            /* sizeof is 12, but actual size is 10 */
                            if (memcmp(&n1.EV,&n2.EV,10))
                                return false;
                        }
                        else
                        {
                            if (memcmp(&n1.EV,&n2.EV,(n1.Vldouble).sizeof))
                                return false;
                        }
                        break;

                    case TYcfloat:
                        if (memcmp(&n1.EV,&n2.EV,(n1.Vcfloat).sizeof))
                            return false;
                        break;

                    case TYcdouble:
                        if (memcmp(&n1.EV,&n2.EV,(n1.Vcdouble).sizeof))
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
                        if (n1.Vcent != n2.Vcent)
                            return false;
                        break;

                    case TYfloat8:
                    case TYdouble4:
                    case TYschar32:
                    case TYuchar32:
                    case TYshort16:
                    case TYushort16:
                    case TYlong8:
                    case TYulong8:
                    case TYllong4:
                    case TYullong4:
                        if (memcmp(&n1.EV,&n2.EV,32))   // 32 byte vector types (256 bit)
                            return false;
                        break;

                    case TYcldouble:
                        static if ((n1.Vldouble).sizeof > 10)
                        {
                            /* sizeof is 12, but actual size of each part is 10 */
                            if (memcmp(&n1.EV,&n2.EV,10) ||
                                memcmp(&n1.Vldouble + 1, &n2.Vldouble + 1, 10))
                                return false;
                        }
                        else
                        {
                            if (memcmp(&n1.EV,&n2.EV,(n1.Vcldouble).sizeof))
                                return false;
                        }
                        break;

                    case TYvoid:
                        break;                  // voids always match

                    default:
                        elem_print(n1);
                        assert(0);
                }
                break;
            case OPrelconst:
            case OPvar:
                symbol_debug(n1.Vsym);
                symbol_debug(n2.Vsym);
                if (n1.Voffset != n2.Voffset)
                    return false;
                if (n1.Vsym != n2.Vsym)
                    return false;
                break;

            case OPasm:
            case OPstring:
            {
                const n = n2.Vstrlen;
                if (n1.Vstrlen != n ||
                    n1.Voffset != n2.Voffset ||
                    memcmp(n1.Vstring, n2.Vstring, n))
                        return false;   /* check bytes in the string    */
                break;
            }

            case OPstrthis:
            case OPframeptr:
            case OPhalt:
            case OPgot:
                break;

            default:
                printf("op: %s\n", oper_str(op));
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
 * Extract long value from constant elem.
 */

@trusted
targ_llong el_tolong(elem* e)
{
    elem_debug(e);
    if (e.Eoper != OPconst)
        elem_print(e);
    assert(e.Eoper == OPconst);
    auto ty = tybasic(typemask(e));

    targ_llong result;
    switch (ty)
    {
        case TYchar:
            if (config.flags & CFGuchar)
                goto Uchar;
            goto case TYschar;

        case TYschar:
            result = e.Vschar;
            break;

        case TYuchar:
        case TYbool:
        Uchar:
            result = e.Vuchar;
            break;

        case TYshort:
        Ishort:
            result = e.Vshort;
            break;

        case TYushort:
        case TYwchar_t:
        case TYchar16:
        Ushort:
            result = e.Vushort;
            break;

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
            result = e.Vulong;
            break;

        case TYint:
            if (_tysize[TYint] == SHORTSIZE)
                goto Ishort;
            goto Ilong;

        case TYlong:
        Ilong:
            result = e.Vlong;
            break;

        case TYllong:
        case TYullong:
        Ullong:
            result = e.Vullong;
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

        case TYcent:
        case TYucent:
            goto Ullong; // should do better than this when actually doing arithmetic on cents

        default:
            elem_print(e);
            assert(0);
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
    targ_llong value = e.Vullong;
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
        if (e.Vullong != cast(int)e.Vullong)
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
longdouble_soft el_toldouble(elem* e)
{
    longdouble_soft result;
    elem_debug(e);
    assert(e.Eoper == OPconst);
    switch (tybasic(typemask(e)))
    {
        case TYfloat:
        case TYifloat:
            result = longdouble_soft(e.Vfloat);
            break;

        case TYdouble:
        case TYidouble:
        case TYdouble_alias:
            result = longdouble_soft(e.Vdouble);
            break;

        case TYldouble:
        case TYildouble:
            static if (is(typeof(e.Vldouble) == real))
                result = longdouble_soft(e.Vldouble);
            else
                result = longdouble_soft(cast(real)e.Vldouble);
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
targ_ldouble el_toldouble(elem* e)
{
    targ_ldouble result;
    elem_debug(e);
    assert(e.Eoper == OPconst);
    switch (tybasic(typemask(e)))
    {
        case TYfloat:
        case TYifloat:
            result = e.Vfloat;
            break;

        case TYdouble:
        case TYidouble:
        case TYdouble_alias:
            result = e.Vdouble;
            break;

        case TYldouble:
        case TYildouble:
            result = e.Vldouble;
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
            e = e.E1;
        else if (OTbinary(e.Eoper))
        {
            if (el_isdependent(e.E2))
                return true;
            e = e.E1;
        }
        else
            break;
    }
    return false;
}

/****************************************
 * Returns: alignment size of elem e
 */
uint el_alignsize(elem* e)
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
            e = e.E1;
        else if (OTbinary(e.Eoper))
        {
            el_check(e.E2);
            e = e.E1;
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
        if (e.Esrcpos.Sfilename)
            printf("%s(%u) ", e.Esrcpos.Sfilename, e.Esrcpos.Slinnum);
    }
    printf("cnt=%d ",e.Ecount);
    if (!OPTIMIZER)
        printf("cs=%d ",e.Ecomsub);
    printf("%s ", oper_str(e.Eoper));
    if ((e.Eoper == OPstrpar || e.Eoper == OPstrctor || e.Eoper == OPstreq) ||
        e.Ety == TYstruct || e.Ety == TYarray)
        if (e.ET)
            printf("%d ", cast(int)type_size(e.ET));
    printf("%s ", tym_str(e.Ety));
    if (OTunary(e.Eoper))
    {
        if (e.E2)
            printf("%p %p\n",e.E1,e.E2);
        else
            printf("%p\n",e.E1);
        elem_print(e.E1, nestlevel + 1);
    }
    else if (OTbinary(e.Eoper))
    {
        if (e.Eoper == OPstreq && e.ET)
            printf("bytes=%d ", cast(int)type_size(e.ET));
        printf("%p %p\n",e.E1,e.E2);
        elem_print(e.E1, nestlevel + 1);
        elem_print(e.E2, nestlevel + 1);
    }
    else
    {
        switch (e.Eoper)
        {
            case OPrelconst:
                printf(" %lld+&",cast(ulong)e.Voffset);
                printf(" %s",e.Vsym.Sident.ptr);
                break;

            case OPvar:
                if (e.Voffset)
                    printf(" %lld+",cast(ulong)e.Voffset);
                printf(" %s",e.Vsym.Sident.ptr);
                break;

            case OPasm:
            case OPstring:
                printf(" '%s',%lld",e.Vstring,cast(ulong)e.Voffset);
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
    switch (tym)
    {   case TYbool:
        case TYchar:
        case TYschar:
        case TYuchar:
            printf("%d ",e.Vuchar);
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
            printf("%d ",e.Vint);
            break;

        case TYlong:
        case TYulong:
        case TYdchar:
        case TYfptr:
        case TYvptr:
        case TYhptr:
        L1:
            printf("%dL ",e.Vlong);
            break;

        case TYllong:
        L2:
            printf("%lldLL ",cast(ulong)e.Vllong);
            break;

        case TYullong:
            printf("%lluLL ",cast(ulong)e.Vullong);
            break;

        case TYcent:
        case TYucent:
            printf("%lluLL+%lluLL ", cast(ulong)e.Vcent.hi, cast(ulong)e.Vcent.lo);
            break;

        case TYfloat:
            printf("%gf ",cast(double)e.Vfloat);
            break;

        case TYdouble:
        case TYdouble_alias:
            printf("%g ",cast(double)e.Vdouble);
            break;

        case TYldouble:
        {
            version (CRuntime_Microsoft)
            {
                const buffer_len = 3 + 3 * (targ_ldouble).sizeof + 1;
                char[buffer_len] buffer = void;
                static if (is(typeof(e.Vldouble) == real))
                    ld_sprint(buffer.ptr, buffer_len, 'g', longdouble_soft(e.Vldouble));
                else
                    ld_sprint(buffer.ptr, buffer_len, 'g', longdouble_soft(cast(real)e.Vldouble));
                printf("%s ", buffer.ptr);
            }
            else
                printf("%Lg ", e.Vldouble);
            break;
        }

        case TYifloat:
            printf("%gfi ", cast(double)e.Vfloat);
            break;

        case TYidouble:
            printf("%gi ", cast(double)e.Vdouble);
            break;

        case TYildouble:
            printf("%gLi ", cast(double)e.Vldouble);
            break;

        case TYcfloat:
            printf("%gf+%gfi ", cast(double)e.Vcfloat.re, cast(double)e.Vcfloat.im);
            break;

        case TYcdouble:
            printf("%g+%gi ", cast(double)e.Vcdouble.re, cast(double)e.Vcdouble.im);
            break;

        case TYcldouble:
            printf("%gL+%gLi ", cast(double)e.Vcldouble.re, cast(double)e.Vcldouble.im);
            break;

        // SIMD 16 byte vector types        // D type
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
            printf("%llxLL+%llxLL ", cast(long)e.Vcent.hi, cast(long)e.Vcent.lo);
            break;

        // SIMD 32 byte (256 bit) vector types
        case TYfloat8:            // float[8]
        case TYdouble4:           // double[4]
        case TYschar32:           // byte[32]
        case TYuchar32:           // ubyte[32]
        case TYshort16:           // short[16]
        case TYushort16:          // ushort[16]
        case TYlong8:             // int[8]
        case TYulong8:            // uint[8]
        case TYllong4:            // long[4]
        case TYullong4:           // ulong[4]
             printf("x%llx,x%llx,x%llx,x%llx ",
                e.Vullong4[3],e.Vullong4[2],e.Vullong4[1],e.Vullong4[0]);
                break;

        // SIMD 64 byte (512 bit) vector types
        case TYfloat16:           // float[16]
        case TYdouble8:           // double[8]
        case TYschar64:           // byte[64]
        case TYuchar64:           // ubyte[64]
        case TYshort32:           // short[32]
        case TYushort32:          // ushort[32]
        case TYlong16:            // int[16]
        case TYulong16:           // uint[16]
        case TYllong8:            // long[8]
        case TYullong8:           // ulong[8]
            printf("512 bit vector ");  // not supported yet with union Vconst
            break;

        default:
            printf("Invalid type ");
            printf("%s\n", tym_str(typemask(e)));
            /*assert(0);*/
    }
}
