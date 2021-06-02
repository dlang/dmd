/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1993-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/glocal.d, backend/glocal.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/glocal.d
 */

module dmd.backend.glocal;

version (SCPP)
    version = COMPILE;
version (MARS)
    version = COMPILE;

version (COMPILE)
{

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.time;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code_x86;
import dmd.backend.oper;
import dmd.backend.global;
import dmd.backend.goh;
import dmd.backend.el;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.barray;
import dmd.backend.dlist;
import dmd.backend.dvec;

extern (C++):

nothrow:
@safe:

int REGSIZE();


enum
{
    LFvolatile     = 1,       // contains volatile or shared refs or defs
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
}

struct loc_t
{
    elem *e;
    int flags;  // LFxxxxx
}


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

@trusted
void localize()
{
    if (debugc) printf("localize()\n");

    __gshared Barray!(loc_t) loctab;       // cache the array so it usually won't need reallocating

    // Table should not get any larger than the symbol table
    loctab.setLength(globsym.symmax);

    foreach (b; BlockRange(startblock))       // for each block
    {
        loctab.setLength(0);                     // start over for each block
        if (b.Belem &&
            /* Overly broad way to account for the case:
             * try
             * { i++;
             *   foo(); // throws exception
             *   i++;   // shouldn't combine previous i++ with this one
             * }
             */
            !b.Btry)
        {
            local_exp(loctab,b.Belem,0);
        }
    }
}

//////////////////////////////////////
// Input:
//      goal    !=0 if we want the result of the expression
//

@trusted
private void local_exp(ref Barray!loc_t lt, elem *e, int goal)
{
    elem *e1;
    OPER op1;

Loop:
    elem_debug(e);
    const op = e.Eoper;
    switch (op)
    {
        case OPcomma:
            local_exp(lt,e.EV.E1,0);
            e = e.EV.E2;
            goto Loop;

        case OPandand:
        case OPoror:
            local_exp(lt,e.EV.E1,1);
            lt.setLength(0);         // we can do better than this, fix later
            break;

        case OPcolon:
        case OPcolon2:
            lt.setLength(0);         // we can do better than this, fix later
            break;

        case OPinfo:
            if (e.EV.E1.Eoper == OPmark)
            {   lt.setLength(0);
                e = e.EV.E2;
                goto Loop;
            }
            goto case_bin;

        case OPdtor:
        case OPctor:
        case OPdctor:
            lt.setLength(0);         // don't move expressions across ctor/dtor
            break;              // boundaries, it would goof up EH cleanup

        case OPddtor:
            lt.setLength(0);         // don't move expressions across ctor/dtor
                                // boundaries, it would goof up EH cleanup
            local_exp(lt,e.EV.E1,0);
            lt.setLength(0);
            break;

        case OPeq:
        case OPstreq:
        case OPvecsto:
            e1 = e.EV.E1;
            local_exp(lt,e.EV.E2,1);
            if (e1.Eoper == OPvar)
            {
                const s = e1.EV.Vsym;
                if (s.Sflags & SFLunambig)
                {   local_symdef(lt, s);
                    if (!goal)
                        local_ins(lt, e);
                }
                else
                    local_ambigdef(lt);
            }
            else
            {
                assert(!OTleaf(e1.Eoper));
                local_exp(lt,e1.EV.E1,1);
                if (OTbinary(e1.Eoper))
                    local_exp(lt,e1.EV.E2,1);
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
            {   local_exp(lt,e.EV.E2,1);
        case OPnegass:
                e1 = e.EV.E1;
                op1 = e1.Eoper;
                if (op1 != OPvar)
                {
                    local_exp(lt,e1.EV.E1,1);
                    if (OTbinary(op1))
                        local_exp(lt,e1.EV.E2,1);
                }
                else if (lt.length && (op == OPaddass || op == OPxorass))
                {
                    const s = e1.EV.Vsym;
                    for (uint u = 0; u < lt.length; u++)
                    {
                        auto em = lt[u].e;
                        if (em.Eoper == op &&
                            em.EV.E1.EV.Vsym == s &&
                            tysize(em.Ety) == tysize(e1.Ety) &&
                            !tyfloating(em.Ety) &&
                            em.EV.E1.EV.Voffset == e1.EV.Voffset &&
                            !el_sideeffect(em.EV.E2)
                           )
                        {   // Change (x += a),(x += b) to
                            // (x + a),(x += a + b)
                            go.changes++;
                            e.EV.E2 = el_bin(opeqtoop(op),e.EV.E2.Ety,em.EV.E2,e.EV.E2);
                            em.Eoper = cast(ubyte)opeqtoop(op);
                            em.EV.E2 = el_copytree(em.EV.E2);
                            local_rem(lt, u);

                            debug if (debugc)
                            {   printf("Combined equation ");
                                WReqn(e);
                                printf(";\n");
                                e = doptelem(e,GOALvalue);
                            }

                            break;
                        }
                    }
                }
            }
            else
            {
                e1 = e.EV.E1;
                op1 = e1.Eoper;
                if (op1 != OPvar)
                {
                    local_exp(lt,e1.EV.E1,1);
                    if (OTbinary(op1))
                        local_exp(lt,e1.EV.E2,1);
                }
                if (lt.length)
                {
                    Symbol* s;
                    if (op1 == OPvar &&
                        ((s = e1.EV.Vsym).Sflags & SFLunambig))
                        local_symref(lt, s);
                    else
                        local_ambigref(lt);
                }
                local_exp(lt,e.EV.E2,1);
            }

            Symbol* s;
            if (op1 == OPvar &&
                ((s = e1.EV.Vsym).Sflags & SFLunambig))
            {   local_symref(lt, s);
                local_symdef(lt, s);
                if (op == OPaddass || op == OPxorass)
                    local_ins(lt, e);
            }
            else if (lt.length)
            {
                local_remove(lt, LFambigdef | LFambigref);
            }
            break;

        case OPstrlen:
        case OPind:
            local_exp(lt,e.EV.E1,1);
            local_ambigref(lt);
            break;

        case OPstrcmp:
        case OPmemcmp:
        case OPbt:
            local_exp(lt,e.EV.E1,1);
            local_exp(lt,e.EV.E2,1);
            local_ambigref(lt);
            break;

        case OPstrcpy:
        case OPmemcpy:
        case OPstrcat:
        case OPcall:
        case OPcallns:
            local_exp(lt,e.EV.E2,1);
            local_exp(lt,e.EV.E1,1);
            goto Lrd;

        case OPstrctor:
        case OPucall:
        case OPucallns:
            local_exp(lt,e.EV.E1,1);
            goto Lrd;

        case OPbtc:
        case OPbtr:
        case OPbts:
            local_exp(lt,e.EV.E1,1);
            local_exp(lt,e.EV.E2,1);
            goto Lrd;

        case OPasm:
        Lrd:
            local_remove(lt, LFfloat | LFambigref | LFambigdef);
            break;

        case OPmemset:
            local_exp(lt,e.EV.E2,1);
            if (e.EV.E1.Eoper == OPvar)
            {
                /* Don't want to rearrange (p = get(); p memset 0;)
                 * as elemxxx() will rearrange it back.
                 */
                const s = e.EV.E1.EV.Vsym;
                if (s.Sflags & SFLunambig)
                    local_symref(lt, s);
                else
                    local_ambigref(lt);     // ambiguous reference
            }
            else
                local_exp(lt,e.EV.E1,1);
            local_ambigdef(lt);
            break;

        case OPvar:
            const s = e.EV.Vsym;
            if (lt.length)
            {
                // If potential candidate for replacement
                if (s.Sflags & SFLunambig)
                {
                    foreach (const u; 0 .. lt.length)
                    {
                        auto em = lt[u].e;
                        if (em.EV.E1.EV.Vsym == s &&
                            (em.Eoper == OPeq || em.Eoper == OPstreq))
                        {
                            if (tysize(em.Ety) == tysize(e.Ety) &&
                                em.EV.E1.EV.Voffset == e.EV.Voffset &&
                                ((tyfloating(em.Ety) != 0) == (tyfloating(e.Ety) != 0) ||
                                 /** Hack to fix https://issues.dlang.org/show_bug.cgi?id=10226
                                  * Recognize assignments of float vectors to void16, as used by
                                  * core.simd intrinsics. The backend type for void16 is Tschar16!
                                  */
                                 (tyvector(em.Ety) != 0) == (tyvector(e.Ety) != 0) && tybasic(e.Ety) == TYschar16) &&
                                /* Changing the Ety to a OPvecfill node means we're potentially generating
                                 * wrong code.
                                 * Ref: https://issues.dlang.org/show_bug.cgi?id=18034
                                 */
                                (em.EV.E2.Eoper != OPvecfill || tybasic(e.Ety) == tybasic(em.Ety)) &&
                                !local_preserveAssignmentTo(em.EV.E1.Ety))
                            {

                                debug if (debugc)
                                {   printf("Moved equation ");
                                    WReqn(em);
                                    printf(";\n");
                                }

                                go.changes++;
                                em.Ety = e.Ety;
                                el_copy(e,em);
                                em.EV.E1 = em.EV.E2 = null;
                                em.Eoper = OPconst;
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
            if (e.EV.E1.Eoper != OPvar)
                goto case_bin;
            const s = e.EV.E1.EV.Vsym;
            if (lt.length)
            {
                if (s.Sflags & SFLunambig)
                    local_symref(lt, s);
                else
                    local_ambigref(lt);     // ambiguous reference
            }
            goal = 1;
            e = e.EV.E2;
            goto Loop;

        default:
            if (OTcommut(e.Eoper))
            {   // Since commutative operators may get their leaves
                // swapped, we eliminate any that may be affected by that.

                for (uint u = 0; u < lt.length;)
                {
                    const f = lt[u].flags;
                    elem* eu = lt[u].e;
                    const s = eu.EV.E1.EV.Vsym;
                    const f1 = local_getflags(e.EV.E1,s);
                    const f2 = local_getflags(e.EV.E2,s);
                    if (f1 & f2 & LFsymref ||   // if both reference or
                        (f1 | f2) & LFsymdef || // either define
                        f & LFambigref && (f1 | f2) & LFambigdef ||
                        f & LFambigdef && (f1 | f2) & (LFambigref | LFambigdef)
                       )
                        local_rem(lt, u);
                    else if (f & LFunambigdef && local_chkrem(e,eu.EV.E2))
                        local_rem(lt, u);
                    else
                        u++;
                }
            }
            if (OTunary(e.Eoper))
            {   goal = 1;
                e = e.EV.E1;
                goto Loop;
            }
        case_bin:
            if (OTbinary(e.Eoper))
            {   local_exp(lt,e.EV.E1,1);
                goal = 1;
                e = e.EV.E2;
                goto Loop;
            }
            break;
    }   // end of switch (e.Eoper)
}

///////////////////////////////////
// Examine expression tree eu to see if it defines any variables
// that e refs or defs.
// Note that e is a binary operator.
// Returns:
//      true if it does

@trusted
private bool local_chkrem(const elem* e, const(elem)* eu)
{
    while (1)
    {
        elem_debug(eu);
        const op = eu.Eoper;
        if (OTassign(op) && eu.EV.E1.Eoper == OPvar)
        {
            const s = eu.EV.E1.EV.Vsym;
            const f1 = local_getflags(e.EV.E1,s);
            const f2 = local_getflags(e.EV.E2,s);
            if ((f1 | f2) & (LFsymref | LFsymdef))      // if either reference or define
                return true;
        }
        if (OTbinary(op))
        {
            if (local_chkrem(e,eu.EV.E2))
                return true;
        }
        else if (!OTunary(op))
            break;                      // leaf node
        eu = eu.EV.E1;
    }
    return false;
}

//////////////////////////////////////
// Add entry e to lt[]

@trusted
private void local_ins(ref Barray!loc_t lt, elem *e)
{
    elem_debug(e);
    if (e.EV.E1.Eoper == OPvar)
    {
        const s = e.EV.E1.EV.Vsym;
        symbol_debug(s);
        if (s.Sflags & SFLunambig)     // if can only be referenced directly
        {
            const flags = local_getflags(e.EV.E2,null);
            if (!(flags & (LFvolatile | LFinp | LFoutp)) &&
                !(e.EV.E1.Ety & (mTYvolatile | mTYshared)))
            {
                // Add e to the candidate array
                //printf("local_ins('%s'), loctop = %d\n",s.Sident.ptr,lt.length);
                lt.push(loc_t(e, flags));
            }
        }
    }
}

//////////////////////////////////////
// Remove entry i from lt[], and then compress the table.
//
@trusted
private void local_rem(ref Barray!loc_t lt, size_t u)
{
    //printf("local_rem(%u)\n",u);
    lt.remove(u);
}

//////////////////////////////////////
// Analyze and gather LFxxxx flags about expression e and symbol s.

@trusted
private int local_getflags(const(elem)* e, const Symbol* s)
{
    elem_debug(e);
    if (s)
        symbol_debug(s);
    int flags = 0;
    while (1)
    {
        if (e.Ety & (mTYvolatile | mTYshared))
            flags |= LFvolatile;
        switch (e.Eoper)
        {
            case OPeq:
            case OPstreq:
                if (e.EV.E1.Eoper == OPvar)
                {
                    const s1 = e.EV.E1.EV.Vsym;
                    if (s1.Sflags & SFLunambig)
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
                if (e.EV.E1.Eoper == OPvar)
                {
                    const s1 = e.EV.E1.EV.Vsym;
                    if (s1.Sflags & SFLunambig)
                        flags |= (s1 == s) ? LFsymdef | LFsymref
                                           : LFunambigdef | LFunambigref;
                    else
                        flags |= LFambigdef | LFambigref;
                }
                else
                    flags |= LFambigdef | LFambigref;
            L1:
                flags |= local_getflags(e.EV.E2,s);
                e = e.EV.E1;
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
                if (e.EV.Vsym == s)
                    flags |= LFsymref;
                else if (!(e.EV.Vsym.Sflags & SFLunambig))
                    flags |= LFambigref;
                break;

            case OPind:
            case OPstrlen:
            case OPstrcmp:
            case OPmemcmp:
            case OPbt:
                flags |= LFambigref;
                break;

            case OPinp:
                flags |= LFinp;
                break;

            case OPoutp:
                flags |= LFoutp;
                break;

            default:
                break;
        }
        if (OTunary(e.Eoper))
        {
            if (tyfloating(e.Ety))
                flags |= LFfloat;
            e = e.EV.E1;
        }
        else if (OTbinary(e.Eoper))
        {
            if (tyfloating(e.Ety))
                flags |= LFfloat;
            flags |= local_getflags(e.EV.E2,s);
            e = e.EV.E1;
        }
        else
            break;
    }
    return flags;
}

//////////////////////////////////////
// Remove all entries with flags set.
//

private void local_remove(ref Barray!loc_t lt, int flags)
{
    for (uint u = 0; u < lt.length;)
    {
        if (lt[u].flags & flags)
            local_rem(lt, u);
        else
            ++u;
    }
}

//////////////////////////////////////
// Ambiguous reference. Remove all with ambiguous defs
//

private void local_ambigref(ref Barray!loc_t lt)
{
    local_remove(lt, LFambigdef);
}

//////////////////////////////////////
// Ambiguous definition. Remove all with ambiguous refs.
//

private void local_ambigdef(ref Barray!loc_t lt)
{
    local_remove(lt, LFambigref | LFambigdef);
}

//////////////////////////////////////
// Reference to symbol.
// Remove any that define that symbol.

private void local_symref(ref Barray!loc_t lt, const Symbol* s)
{
    symbol_debug(s);
    for (uint u = 0; u < lt.length;)
    {
        if (local_getflags(lt[u].e,s) & LFsymdef)
            local_rem(lt, u);
        else
            ++u;
    }
}

//////////////////////////////////////
// Definition of symbol.
// Remove any that reference that symbol.

private void local_symdef(ref Barray!loc_t lt, const Symbol* s)
{
    symbol_debug(s);
    for (uint u = 0; u < lt.length;)
    {
        if (local_getflags(lt[u].e,s) & (LFsymref | LFsymdef))
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
@trusted
private bool local_preserveAssignmentTo(tym_t ty)
{
    /* Need to preserve assignment if generating code using
     * the x87, as that is the only way to get the x87 to
     * convert to float/double precision.
     */
    /* Don't do this for 64 bit compiles because returns are in
     * the XMM registers so it doesn't evaluate floats/doubles in the x87.
     * 32 bit returns are in ST0, so it evaluates in the x87.
     * https://issues.dlang.org/show_bug.cgi?id=21526
     */
    if (config.inline8087 && !I64)
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

}
