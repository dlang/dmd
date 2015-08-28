// Copyright (C) 1993-1998 by Symantec
// Copyright (C) 2000-2015 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
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

typedef struct loc_t
{
    elem *e;
    int flags;
#       define LFvolatile       1       // contains volatile refs or defs
#       define LFambigref       2       // references ambiguous data
#       define LFambigdef       4       // defines ambiguous data
#       define LFsymref         8       // reference to symbol s
#       define LFsymdef         0x10    // definition of symbol s
#       define LFunambigref     0x20    // references unambiguous data other than s
#       define LFunambigdef     0x40    // defines unambiguous data other than s
#if TX86
#       define LFinp            0x80    // input from I/O port
#       define LFoutp           0x100   // output to I/O port
#endif
#       define LFfloat          0x200   // sets float flags and/or depends on
                                        // floating point settings
} loc_t;

static loc_t *loctab;
static unsigned locmax;
static unsigned loctop;

STATIC void local_exp(elem *e,int goal);
STATIC int  local_chkrem(elem *e,elem *eu);
STATIC void local_ins(elem *e);
STATIC void local_rem(unsigned u);
STATIC int  local_getflags(elem *e,symbol *s);
STATIC void local_remove(int flags);
STATIC void local_ambigref(void);
STATIC void local_ambigdef(void);
STATIC void local_symref(symbol *s);
STATIC void local_symdef(symbol *s);

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
{   block *b;

    cmes("localize()\n");

    // Table should not get any larger than the symbol table
    locmax = globsym.symmax;
    loctab = (loc_t *) malloc(locmax * sizeof(*loctab));

    for (b = startblock; b; b = b->Bnext)       /* for each block        */
    {
        loctop = 0;                     // start over for each block
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
            local_exp(b->Belem,0);
        }
    }
    free(loctab);
    locmax = 0;
}

//////////////////////////////////////
// Input:
//      goal    !=0 if we want the result of the expression
//

STATIC void local_exp(elem *e,int goal)
{   symbol *s;
    unsigned u;
    elem *e1;
    int op1;

Loop:
    elem_debug(e);
    int op = e->Eoper;
    switch (op)
    {   case OPcomma:
            local_exp(e->E1,0);
            e = e->E2;
            goto Loop;

        case OPandand:
        case OPoror:
            local_exp(e->E1,1);
            loctop = 0;         // we can do better than this, fix later
            break;

        case OPcolon:
        case OPcolon2:
            loctop = 0;         // we can do better than this, fix later
            break;

        case OPinfo:
            if (e->E1->Eoper == OPmark)
            {   loctop = 0;
                e = e->E2;
                goto Loop;
            }
            goto case_bin;

        case OPdtor:
        case OPctor:
        case OPdctor:
            loctop = 0;         // don't move expressions across ctor/dtor
            break;              // boundaries, it would goof up EH cleanup

        case OPddtor:
            loctop = 0;         // don't move expressions across ctor/dtor
                                // boundaries, it would goof up EH cleanup
            local_exp(e->E1,0);
            loctop = 0;
            break;

        case OPeq:
        case OPstreq:
            e1 = e->E1;
            local_exp(e->E2,1);
            if (e1->Eoper == OPvar)
            {   s = e1->EV.sp.Vsym;
                if (s->Sflags & SFLunambig)
                {   local_symdef(s);
                    if (!goal)
                        local_ins(e);
                }
                else
                    local_ambigdef();
            }
            else
            {
                assert(!OTleaf(e1->Eoper));
                local_exp(e1->E1,1);
                if (OTbinary(e1->Eoper))
                    local_exp(e1->E2,1);
                local_ambigdef();
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
            if (ERTOL(e))
            {   local_exp(e->E2,1);
        case OPnegass:
                e1 = e->E1;
                op1 = e1->Eoper;
                if (op1 != OPvar)
                {
                    local_exp(e1->E1,1);
                    if (OTbinary(op1))
                        local_exp(e1->E2,1);
                }
                else if (loctop && (op == OPaddass || op == OPxorass))
                {   unsigned u;

                    s = e1->EV.sp.Vsym;
                    for (u = 0; u < loctop; u++)
                    {   elem *em;

                        em = loctab[u].e;
                        if (em->Eoper == op &&
                            em->E1->EV.sp.Vsym == s &&
                            tysize(em->Ety) == tysize(e1->Ety) &&
                            !tyfloating(em->Ety) &&
                            em->E1->EV.sp.Voffset == e1->EV.sp.Voffset &&
                            !el_sideeffect(em->E2)
                           )
                        {   // Change (x += a),(x += b) to
                            // (x + a),(x += a + b)
                            changes++;
                            e->E2 = el_bin(opeqtoop(op),e->E2->Ety,em->E2,e->E2);
                            em->Eoper = opeqtoop(op);
                            em->E2 = el_copytree(em->E2);
                            local_rem(u);
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
                    local_exp(e1->E1,1);
                    if (OTbinary(op1))
                        local_exp(e1->E2,1);
                }
                if (loctop)
                {   if (op1 == OPvar &&
                        ((s = e1->EV.sp.Vsym)->Sflags & SFLunambig))
                        local_symref(s);
                    else
                        local_ambigref();
                }
                local_exp(e->E2,1);
            }
            if (op1 == OPvar &&
                ((s = e1->EV.sp.Vsym)->Sflags & SFLunambig))
            {   local_symref(s);
                local_symdef(s);
                if (op == OPaddass || op == OPxorass)
                    local_ins(e);
            }
            else if (loctop)
            {
                local_remove(LFambigdef | LFambigref);
            }
            break;
        case OPstrlen:
        case OPind:
            local_exp(e->E1,1);
            local_ambigref();
            break;

        case OPstrcmp:
        case OPmemcmp:
        case OPbt:
            local_exp(e->E1,1);
            local_exp(e->E2,1);
            local_ambigref();
            break;

        case OPstrcpy:
        case OPmemcpy:
        case OPstrcat:
        case OPcall:
        case OPcallns:
            local_exp(e->E2,1);
        case OPstrctor:
        case OPucall:
        case OPucallns:
            local_exp(e->E1,1);
            goto Lrd;

        case OPbtc:
        case OPbtr:
        case OPbts:
            local_exp(e->E1,1);
            local_exp(e->E2,1);
            goto Lrd;
        case OPasm:
        Lrd:
            local_remove(LFfloat | LFambigref | LFambigdef);
            break;

        case OPmemset:
            local_exp(e->E2,1);
            if (e->E1->Eoper == OPvar)
            {
                /* Don't want to rearrange (p = get(); p memset 0;)
                 * as elemxxx() will rearrange it back.
                 */
                s = e->E1->EV.sp.Vsym;
                if (s->Sflags & SFLunambig)
                    local_symref(s);
                else
                    local_ambigref();           // ambiguous reference
            }
            else
                local_exp(e->E1,1);
            local_ambigdef();
            break;

        case OPvar:
            s = e->EV.sp.Vsym;
            if (loctop)
            {   unsigned u;

                // If potential candidate for replacement
                if (s->Sflags & SFLunambig)
                {
                    for (u = 0; u < loctop; u++)
                    {   elem *em;

                        em = loctab[u].e;
                        if (em->E1->EV.sp.Vsym == s &&
                            (em->Eoper == OPeq || em->Eoper == OPstreq))
                        {
                            if (tysize(em->Ety) == tysize(e->Ety) &&
                                em->E1->EV.sp.Voffset == e->EV.sp.Voffset &&
                                (tyfloating(em->Ety) != 0) == (tyfloating(e->Ety) != 0))
                            {
#ifdef DEBUG
                                if (debugc)
                                {   dbg_printf("Moved equation ");
                                    WReqn(em);
                                    dbg_printf(";\n");
                                }
#endif
                                changes++;
                                em->Ety = e->Ety;
                                el_copy(e,em);
                                em->E1 = em->E2 = NULL;
                                em->Eoper = OPconst;
                            }
                            local_rem(u);
                            break;
                        }
                    }
                    local_symref(s);
                }
                else
                    local_ambigref();           // ambiguous reference
            }
            break;

        case OPremquo:
            if (e->E1->Eoper != OPvar)
                goto case_bin;
            s = e->E1->EV.sp.Vsym;
            if (loctop)
            {
                if (s->Sflags & SFLunambig)
                    local_symref(s);
                else
                    local_ambigref();           // ambiguous reference
            }
            goal = 1;
            e = e->E2;
            goto Loop;

        default:
            if (OTcommut(e->Eoper))
            {   // Since commutative operators may get their leaves
                // swapped, we eliminate any that may be affected by that.

                for (u = 0; u < loctop;)
                {
                    int f1,f2,f;
                    elem *eu;

                    f = loctab[u].flags;
                    eu = loctab[u].e;
                    s = eu->E1->EV.sp.Vsym;
                    f1 = local_getflags(e->E1,s);
                    f2 = local_getflags(e->E2,s);
                    if (f1 & f2 & LFsymref ||   // if both reference or
                        (f1 | f2) & LFsymdef || // either define
                        f & LFambigref && (f1 | f2) & LFambigdef ||
                        f & LFambigdef && (f1 | f2) & (LFambigref | LFambigdef)
                       )
                        local_rem(u);
                    else if (f & LFunambigdef && local_chkrem(e,eu->E2))
                        local_rem(u);
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
            {   local_exp(e->E1,1);
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
{   int f1,f2;
    int op;
    symbol *s;
    int result = 0;

    while (1)
    {   elem_debug(eu);
        op = eu->Eoper;
        if (OTassign(op) && eu->E1->Eoper == OPvar)
        {   s = eu->E1->EV.sp.Vsym;
            f1 = local_getflags(e->E1,s);
            f2 = local_getflags(e->E2,s);
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
// Add entry e to loctab[]

STATIC void local_ins(elem *e)
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
                //dbg_printf("local_ins('%s'), loctop = %d, locmax = %d\n",s->Sident,loctop,locmax);
                assert(loctop < locmax);
                loctab[loctop].e = e;
                loctab[loctop].flags = flags;
                loctop++;
            }
        }
    }
}

//////////////////////////////////////
// Remove entry i from loctab[], and then compress the table.
//

STATIC void local_rem(unsigned u)
{
    //dbg_printf("local_rem(%u)\n",u);
    assert(u < loctop);
    if (u + 1 != loctop)
    {   assert(u < loctop);
        loctab[u] = loctab[loctop - 1];
    }
    loctop--;
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

STATIC void local_remove(int flags)
{   unsigned u;

    for (u = 0; u < loctop;)
    {
        if (loctab[u].flags & flags)
            local_rem(u);
        else
            u++;
    }
}

//////////////////////////////////////
// Ambiguous reference. Remove all with ambiguous defs
//

STATIC void local_ambigref()
{   unsigned u;

    for (u = 0; u < loctop;)
    {
        if (loctab[u].flags & LFambigdef)
            local_rem(u);
        else
            u++;
    }
}

//////////////////////////////////////
// Ambigous definition. Remove all with ambiguous refs.
//

STATIC void local_ambigdef()
{   unsigned u;

    for (u = 0; u < loctop;)
    {
        if (loctab[u].flags & (LFambigref | LFambigdef))
            local_rem(u);
        else
            u++;
    }
}

//////////////////////////////////////
// Reference to symbol.
// Remove any that define that symbol.

STATIC void local_symref(symbol *s)
{   unsigned u;

    symbol_debug(s);
    for (u = 0; u < loctop;)
    {
        if (local_getflags(loctab[u].e,s) & LFsymdef)
            local_rem(u);
        else
            u++;
    }
}

//////////////////////////////////////
// Definition of symbol.
// Remove any that reference that symbol.

STATIC void local_symdef(symbol *s)
{   unsigned u;

    symbol_debug(s);
    for (u = 0; u < loctop;)
    {
        if (local_getflags(loctab[u].e,s) & (LFsymref | LFsymdef))
            local_rem(u);
        else
            u++;
    }
}

#endif
