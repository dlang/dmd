/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1993-1998 by Symantec
 *              Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/glocal.c, backend/glocal.c)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/glocal.c
 */

#if !SPP

#include        <stdio.h>
#include        <stdlib.h>
#include        <time.h>

#include        "cc.h"
#include        "global.h"
#include        "el.h"
#include        "go.h"
#include        "type.h"
#include        "oper.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

enum
{
    LFvolatile     = 1,       // contains volatile refs or defs
    LFambigref     = 2,       // references ambiguous data
    LFambigdef     = 4,       // defines ambiguous data
    LFsymref       = 8,       // reference to symbol s
    LFsymdef       = 0x10,    // definition of symbol s
    LFunambigref   = 0x20,    // references unambiguous data other than s
    LFunambigdef   = 0x40,    // defines unambiguous data other than s
    LFinp          = 0x80,    // input from I/O port
    LFoutp         = 0x100,   // output to I/O port
    LFfloat        = 0x200,   // sets float flags and/or depends on
                              // floating point settings
};

struct loc_t
{
    elem *e;
    int flags;  // LFxxxxx
};

struct Loctab
{
    loc_t *data;
    uint allocdim;
    uint dim;
};

STATIC void local_exp(Loctab& lt, elem *e, int goal);
STATIC int  local_chkrem(elem *e,elem *eu);
STATIC void local_ins(Loctab& lt, elem *e);
STATIC void local_rem(Loctab& lt, uint u);
STATIC int  local_getflags(elem *e,symbol *s);
STATIC void local_remove(Loctab& lt, int flags);
STATIC void local_ambigref(Loctab& lt);
STATIC void local_ambigdef(Loctab& lt);
STATIC void local_symref(Loctab& lt, symbol *s);
STATIC void local_symdef(Loctab& lt, symbol *s);
STATIC bool local_preserveAssignmentTo(tym_t ty);

///////////////////////////////
// This optimization attempts to replace sequences like:
//      x = func();
//      y = 3;
//      z = x + 5;
// with:
//      y = 3;
//      z = (x = func()) + 5;
// In other words, we attempt to localize expressions by moving them
// as near as we can to where they are used. This should minimize
// temporary generation and register usage.

void localize()
{
    cmes("localize()\n");

    static Loctab loctab;       // cache the array so it usually won't need reallocating

    Loctab* lt = &loctab;

    // Table should not get any larger than the symbol table
    if (lt->allocdim < globsym.symmax)
    {
        lt->allocdim = globsym.symmax;
        lt->data = (loc_t *) realloc(lt->data, lt->allocdim * sizeof(loc_t));
        assert(lt->data);
    }

    for (block *b = startblock; b; b = b->Bnext)       // for each block
    {
        lt->dim = 0;                     // start over for each block
        if (b->Belem &&
            /* Overly broad way to account for the case:
             * try
             * { i++;
             *   foo(); // throws exception
             *   i++;   // shouldn't combine previous i++ with this one
             * }
             */
            !b->Btry)
        {
            local_exp(*lt,b->Belem,0);
        }
    }
}

//////////////////////////////////////
// Input:
//      goal    !=0 if we want the result of the expression
//

STATIC void local_exp(Loctab& lt, elem *e, int goal)
{   symbol *s;
    elem *e1;
    int op1;

Loop:
    elem_debug(e);
    int op = e->Eoper;
    switch (op)
    {   case OPcomma:
            local_exp(lt,e->E1,0);
            e = e->E2;
            goto Loop;

        case OPandand:
        case OPoror:
            local_exp(lt,e->E1,1);
            lt.dim = 0;         // we can do better than this, fix later
            break;

        case OPcolon:
        case OPcolon2:
            lt.dim = 0;         // we can do better than this, fix later
            break;

        case OPinfo:
            if (e->E1->Eoper == OPmark)
            {   lt.dim = 0;
                e = e->E2;
                goto Loop;
            }
            goto case_bin;

        case OPdtor:
        case OPctor:
        case OPdctor:
            lt.dim = 0;         // don't move expressions across ctor/dtor
            break;              // boundaries, it would goof up EH cleanup

        case OPddtor:
            lt.dim = 0;         // don't move expressions across ctor/dtor
                                // boundaries, it would goof up EH cleanup
            local_exp(lt,e->E1,0);
            lt.dim = 0;
            break;

        case OPeq:
        case OPstreq:
            e1 = e->E1;
            local_exp(lt,e->E2,1);
            if (e1->Eoper == OPvar)
            {   s = e1->EV.sp.Vsym;
                if (s->Sflags & SFLunambig)
                {   local_symdef(lt, s);
                    if (!goal)
                        local_ins(lt, e);
                }
                else
                    local_ambigdef(lt);
            }
            else
            {
                assert(!OTleaf(e1->Eoper));
                local_exp(lt,e1->E1,1);
                if (OTbinary(e1->Eoper))
                    local_exp(lt,e1->E2,1);
                local_ambigdef(lt);
            }
            break;

        case OPpostinc:
        case OPpostdec:
        case OPaddass:
        case OPminass:
        case OPmulass:
        case OPdivass:
        case OPmodass:
        case OPashrass:
        case OPshrass:
        case OPshlass:
        case OPandass:
        case OPxorass:
        case OPorass:
        case OPcmpxchg:
            if (ERTOL(e))
            {   local_exp(lt,e->E2,1);
        case OPnegass:
                e1 = e->E1;
                op1 = e1->Eoper;
                if (op1 != OPvar)
                {
                    local_exp(lt,e1->E1,1);
                    if (OTbinary(op1))
                        local_exp(lt,e1->E2,1);
                }
                else if (lt.dim && (op == OPaddass || op == OPxorass))
                {
                    s = e1->EV.sp.Vsym;
                    for (uint u = 0; u < lt.dim; u++)
                    {   elem *em;

                        em = lt.data[u].e;
                        if (em->Eoper == op &&
                            em->E1->EV.sp.Vsym == s &&
                            tysize(em->Ety) == tysize(e1->Ety) &&
                            !tyfloating(em->Ety) &&
                            em->E1->EV.sp.Voffset == e1->EV.sp.Voffset &&
                            !el_sideeffect(em->E2)
                           )
                        {   // Change (x += a),(x += b) to
                            // (x + a),(x += a + b)
                            go.changes++;
                            e->E2 = el_bin(opeqtoop(op),e->E2->Ety,em->E2,e->E2);
                            em->Eoper = opeqtoop(op);
                            em->E2 = el_copytree(em->E2);
                            local_rem(lt, u);
#ifdef DEBUG
                            if (debugc)
                            {   dbg_printf("Combined equation ");
                                WReqn(e);
                                dbg_printf(";\n");
                                e = doptelem(e,GOALvalue);
                            }
#endif

                            break;
                        }
                    }
                }
            }
            else
            {
                e1 = e->E1;
                op1 = e1->Eoper;
                if (op1 != OPvar)
                {
                    local_exp(lt,e1->E1,1);
                    if (OTbinary(op1))
                        local_exp(lt,e1->E2,1);
                }
                if (lt.dim)
                {   if (op1 == OPvar &&
                        ((s = e1->EV.sp.Vsym)->Sflags & SFLunambig))
                        local_symref(lt, s);
                    else
                        local_ambigref(lt);
                }
                local_exp(lt,e->E2,1);
            }
            if (op1 == OPvar &&
                ((s = e1->EV.sp.Vsym)->Sflags & SFLunambig))
            {   local_symref(lt, s);
                local_symdef(lt, s);
                if (op == OPaddass || op == OPxorass)
                    local_ins(lt, e);
            }
            else if (lt.dim)
            {
                local_remove(lt, LFambigdef | LFambigref);
            }
            break;
        case OPstrlen:
        case OPind:
            local_exp(lt,e->E1,1);
            local_ambigref(lt);
            break;

        case OPstrcmp:
        case OPmemcmp:
        case OPbt:
            local_exp(lt,e->E1,1);
            local_exp(lt,e->E2,1);
            local_ambigref(lt);
            break;

        case OPstrcpy:
        case OPmemcpy:
        case OPstrcat:
        case OPcall:
        case OPcallns:
            local_exp(lt,e->E2,1);
        case OPstrctor:
        case OPucall:
        case OPucallns:
            local_exp(lt,e->E1,1);
            goto Lrd;

        case OPbtc:
        case OPbtr:
        case OPbts:
            local_exp(lt,e->E1,1);
            local_exp(lt,e->E2,1);
            goto Lrd;
        case OPasm:
        Lrd:
            local_remove(lt, LFfloat | LFambigref | LFambigdef);
            break;

        case OPmemset:
            local_exp(lt,e->E2,1);
            if (e->E1->Eoper == OPvar)
            {
                /* Don't want to rearrange (p = get(); p memset 0;)
                 * as elemxxx() will rearrange it back.
                 */
                s = e->E1->EV.sp.Vsym;
                if (s->Sflags & SFLunambig)
                    local_symref(lt, s);
                else
                    local_ambigref(lt);     // ambiguous reference
            }
            else
                local_exp(lt,e->E1,1);
            local_ambigdef(lt);
            break;

        case OPvar:
            s = e->EV.sp.Vsym;
            if (lt.dim)
            {
                // If potential candidate for replacement
                if (s->Sflags & SFLunambig)
                {
                    for (uint u = 0; u < lt.dim; u++)
                    {   elem *em;

                        em = lt.data[u].e;
                        if (em->E1->EV.sp.Vsym == s &&
                            (em->Eoper == OPeq || em->Eoper == OPstreq))
                        {
                            if (tysize(em->Ety) == tysize(e->Ety) &&
                                em->E1->EV.sp.Voffset == e->EV.sp.Voffset &&
                                ((tyfloating(em->Ety) != 0) == (tyfloating(e->Ety) != 0) ||
                                 /** Hack to fix https://issues.dlang.org/show_bug.cgi?id=10226
                                  * Recognize assignments of float vectors to void16, as used by
                                  * core.simd intrinsics. The backend type for void16 is Tschar16!
                                  */
                                 (tyvector(em->Ety) != 0) == (tyvector(e->Ety) != 0) && tybasic(e->Ety) == TYschar16) &&
                                /* Changing the Ety to a OPvecfill node means we're potentially generating
                                 * wrong code.
                                 * Ref: https://issues.dlang.org/show_bug.cgi?id=18034
                                 */
                                (em->E2->Eoper != OPvecfill || tybasic(e->Ety) == tybasic(em->Ety)) &&
                                !local_preserveAssignmentTo(em->E1->Ety))
                            {
#ifdef DEBUG
                                if (debugc)
                                {   dbg_printf("Moved equation ");
                                    WReqn(em);
                                    dbg_printf(";\n");
                                }
#endif
                                go.changes++;
                                em->Ety = e->Ety;
                                el_copy(e,em);
                                em->E1 = em->E2 = NULL;
                                em->Eoper = OPconst;
                            }
                            local_rem(lt, u);
                            break;
                        }
                    }
                    local_symref(lt, s);
                }
                else
                    local_ambigref(lt);     // ambiguous reference
            }
            break;

        case OPremquo:
            if (e->E1->Eoper != OPvar)
                goto case_bin;
            s = e->E1->EV.sp.Vsym;
            if (lt.dim)
            {
                if (s->Sflags & SFLunambig)
                    local_symref(lt, s);
                else
                    local_ambigref(lt);     // ambiguous reference
            }
            goal = 1;
            e = e->E2;
            goto Loop;

        default:
            if (OTcommut(e->Eoper))
            {   // Since commutative operators may get their leaves
                // swapped, we eliminate any that may be affected by that.

                for (uint u = 0; u < lt.dim;)
                {
                    int f1,f2,f;
                    elem *eu;

                    f = lt.data[u].flags;
                    eu = lt.data[u].e;
                    s = eu->E1->EV.sp.Vsym;
                    f1 = local_getflags(e->E1,s);
                    f2 = local_getflags(e->E2,s);
                    if (f1 & f2 & LFsymref ||   // if both reference or
                        (f1 | f2) & LFsymdef || // either define
                        f & LFambigref && (f1 | f2) & LFambigdef ||
                        f & LFambigdef && (f1 | f2) & (LFambigref | LFambigdef)
                       )
                        local_rem(lt, u);
                    else if (f & LFunambigdef && local_chkrem(e,eu->E2))
                        local_rem(lt, u);
                    else
                        u++;
                }
            }
            if (EUNA(e))
            {   goal = 1;
                e = e->E1;
                goto Loop;
            }
        case_bin:
            if (EBIN(e))
            {   local_exp(lt,e->E1,1);
                goal = 1;
                e = e->E2;
                goto Loop;
            }
            break;
    }   // end of switch (e->Eoper)
}

///////////////////////////////////
// Examine expression tree eu to see if it defines any variables
// that e refs or defs.
// Note that e is a binary operator.
// Returns:
//      !=0 if it does

STATIC int local_chkrem(elem *e,elem *eu)
{
    int result = 0;

    while (1)
    {   elem_debug(eu);
        int op = eu->Eoper;
        if (OTassign(op) && eu->E1->Eoper == OPvar)
        {
            Symbol *s = eu->E1->EV.sp.Vsym;
            int f1 = local_getflags(e->E1,s);
            int f2 = local_getflags(e->E2,s);
            if ((f1 | f2) & (LFsymref | LFsymdef))      // if either reference or define
            {   result = 1;
                break;
            }
        }
        if (OTbinary(op))
        {   if (local_chkrem(e,eu->E2))
            {   result = 1;
                break;
            }
        }
        else if (!OTunary(op))
            break;                      // leaf node
        eu = eu->E1;
    }
    return result;
}

//////////////////////////////////////
// Add entry e to lt.data[]

STATIC void local_ins(Loctab& lt, elem *e)
{
    elem_debug(e);
    if (e->E1->Eoper == OPvar)
    {   symbol *s;

        s = e->E1->EV.sp.Vsym;
        symbol_debug(s);
        if (s->Sflags & SFLunambig)     // if can only be referenced directly
        {   int flags;

            flags = local_getflags(e->E2,NULL);
#if TX86
            if (!(flags & (LFvolatile | LFinp | LFoutp)) &&
#else
            if (!(flags & LFvolatile) &&
#endif
                !(e->E1->Ety & mTYvolatile))
            {
                // Add e to the candidate array
                //dbg_printf("local_ins('%s'), loctop = %d, locmax = %d\n",s->Sident,lt.dim,lt.allocdim);
                assert(lt.dim < lt.allocdim);
                lt.data[lt.dim].e = e;
                lt.data[lt.dim].flags = flags;
                lt.dim++;
            }
        }
    }
}

//////////////////////////////////////
// Remove entry i from lt.data[], and then compress the table.
//

STATIC void local_rem(Loctab& lt, uint u)
{
    //dbg_printf("local_rem(%u)\n",u);
    assert(u < lt.dim);
    if (u + 1 != lt.dim)
    {   assert(u < lt.dim);
        lt.data[u] = lt.data[lt.dim - 1];
    }
    --lt.dim;
}

//////////////////////////////////////
// Analyze and gather LFxxxx flags about expression e and symbol s.

STATIC int local_getflags(elem *e,symbol *s)
{   int flags;

    elem_debug(e);
    if (s)
        symbol_debug(s);
    flags = 0;
    while (1)
    {
        if (e->Ety & mTYvolatile)
            flags |= LFvolatile;
        switch (e->Eoper)
        {
            case OPeq:
            case OPstreq:
                if (e->E1->Eoper == OPvar)
                {   symbol *s1;

                    s1 = e->E1->EV.sp.Vsym;
                    if (s1->Sflags & SFLunambig)
                        flags |= (s1 == s) ? LFsymdef : LFunambigdef;
                    else
                        flags |= LFambigdef;
                }
                else
                    flags |= LFambigdef;
                goto L1;

            case OPpostinc:
            case OPpostdec:
            case OPaddass:
            case OPminass:
            case OPmulass:
            case OPdivass:
            case OPmodass:
            case OPashrass:
            case OPshrass:
            case OPshlass:
            case OPandass:
            case OPxorass:
            case OPorass:
            case OPcmpxchg:
                if (e->E1->Eoper == OPvar)
                {   symbol *s1;

                    s1 = e->E1->EV.sp.Vsym;
                    if (s1->Sflags & SFLunambig)
                        flags |= (s1 == s) ? LFsymdef | LFsymref
                                           : LFunambigdef | LFunambigref;
                    else
                        flags |= LFambigdef | LFambigref;
                }
                else
                    flags |= LFambigdef | LFambigref;
            L1:
                flags |= local_getflags(e->E2,s);
                e = e->E1;
                break;

            case OPucall:
            case OPucallns:
            case OPcall:
            case OPcallns:
            case OPstrcat:
            case OPstrcpy:
            case OPmemcpy:
            case OPbtc:
            case OPbtr:
            case OPbts:
            case OPstrctor:
                flags |= LFambigref | LFambigdef;
                break;

            case OPmemset:
                flags |= LFambigdef;
                break;

            case OPvar:
                if (e->EV.sp.Vsym == s)
                    flags |= LFsymref;
                else if (!(e->EV.sp.Vsym->Sflags & SFLunambig))
                    flags |= LFambigref;
                break;

            case OPind:
            case OPstrlen:
            case OPstrcmp:
            case OPmemcmp:
            case OPbt:
                flags |= LFambigref;
                break;

#if TX86
            case OPinp:
                flags |= LFinp;
                break;

            case OPoutp:
                flags |= LFoutp;
                break;
#endif
        }
        if (EUNA(e))
        {
            if (tyfloating(e->Ety))
                flags |= LFfloat;
            e = e->E1;
        }
        else if (EBIN(e))
        {
            if (tyfloating(e->Ety))
                flags |= LFfloat;
            flags |= local_getflags(e->E2,s);
            e = e->E1;
        }
        else
            break;
    }
    return flags;
}

//////////////////////////////////////
// Remove all entries with flags set.
//

STATIC void local_remove(Loctab& lt, int flags)
{
    for (uint u = 0; u < lt.dim;)
    {
        if (lt.data[u].flags & flags)
            local_rem(lt, u);
        else
            ++u;
    }
}

//////////////////////////////////////
// Ambiguous reference. Remove all with ambiguous defs
//

STATIC void local_ambigref(Loctab& lt)
{
    for (uint u = 0; u < lt.dim;)
    {
        if (lt.data[u].flags & LFambigdef)
            local_rem(lt, u);
        else
            ++u;
    }
}

//////////////////////////////////////
// Ambiguous definition. Remove all with ambiguous refs.
//

STATIC void local_ambigdef(Loctab& lt)
{
    for (uint u = 0; u < lt.dim;)
    {
        if (lt.data[u].flags & (LFambigref | LFambigdef))
            local_rem(lt, u);
        else
            ++u;
    }
}

//////////////////////////////////////
// Reference to symbol.
// Remove any that define that symbol.

STATIC void local_symref(Loctab& lt, symbol *s)
{
    symbol_debug(s);
    for (uint u = 0; u < lt.dim;)
    {
        if (local_getflags(lt.data[u].e,s) & LFsymdef)
            local_rem(lt, u);
        else
            ++u;
    }
}

//////////////////////////////////////
// Definition of symbol.
// Remove any that reference that symbol.

STATIC void local_symdef(Loctab& lt, symbol *s)
{
    symbol_debug(s);
    for (uint u = 0; u < lt.dim;)
    {
        if (local_getflags(lt.data[u].e,s) & (LFsymref | LFsymdef))
            local_rem(lt, u);
        else
            ++u;
    }
}

/***************************************************
 * See if we should preserve assignment to Symbol of type ty.
 * Returns:
 *      true if preserve assignment
 * References:
 *      https://issues.dlang.org/show_bug.cgi?id=13474
 */
STATIC bool local_preserveAssignmentTo(tym_t ty)
{
    /* Need to preserve assignment if generating code using
     * the x87, as that is the only way to get the x87 to
     * convert to float/double precision.
     */
    if (config.inline8087 && !config.fpxmmregs)
    {
        switch (tybasic(ty))
        {
            case TYfloat:
            case TYifloat:
            case TYcfloat:
            case TYdouble:
            case TYidouble:
            case TYdouble_alias:
            case TYcdouble:
                return true;

            default:
                break;
        }
    }
    return false;
}

#endif
