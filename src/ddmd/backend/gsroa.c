/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 2016-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/gslice.c
 */


#if (SCPP || MARS) && !HTOD

#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <time.h>

#include        "cc.h"
#include        "el.h"
#include        "go.h"
#include        "oper.h"
#include        "global.h"
#include        "type.h"
#include        "code.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/* This 'slices' a two register wide aggregate into two separate register-sized variables,
 * enabling much better enregistering.
 * SROA (Scalar Replacement Of Aggregates) is the common term for this.
 */

struct SymInfo
{
    bool canSlice;
    bool accessSlice;   // if Symbol was accessed as a slice
    bool usePair;       // will use OPpair
    tym_t ty0;          // type of first slice
    tym_t ty1;          // type of second slice
    SYMIDX si0;
};

static void sliceStructs_Gather(SymInfo *sia, elem *e)
{
    while (1)
    {
        switch (e->Eoper)
        {
            case OPvar:
            {
                SYMIDX si = e->EV.sp.Vsym->Ssymnum;
                if (si >= 0 && sia[si].canSlice)
                {
                    assert(si < globsym.top);
                    unsigned sz = tysize(e->Ety);
                    if (sz == 2 * REGSIZE && !tyfv(e->Ety))
                    {
                        // Rewrite as OPpair later
                        sia[si].usePair = true;

                        /* OPpair cannot handle XMM registers, cdpair() and fixresult()
                         */
                        if (tyfloating(sia[si].ty0) || tyfloating(sia[si].ty1))
                            sia[si].canSlice = false;
                    }
                    else if (sz == REGSIZE &&
                        (e->Eoffset == 0 || e->Eoffset == REGSIZE))
                    {
                        if (!sia[si].accessSlice)
                        {
                            sia[si].ty0 = TYnptr;
                            sia[si].ty1 = TYnptr;
                        }
                        sia[si].accessSlice = true;
                        if (e->Eoffset == 0)
                            sia[si].ty0 = tybasic(e->Ety);
                        else
                            sia[si].ty1 = tybasic(e->Ety);
                        // Cannot slice float fields if the symbol is also accessed using OPpair (see above)
                        if (sia[si].usePair && (tyfloating(sia[si].ty0) || tyfloating(sia[si].ty1)))
                            sia[si].canSlice = false;
                    }
                    else
                    {
                        sia[si].canSlice = false;
                    }
                }
                return;
            }

            default:
                if (OTassign(e->Eoper))
                {
                    if (OTbinary(e->Eoper))
                        sliceStructs_Gather(sia, e->E2);

                    // Assignment to a whole var will disallow SROA
                    if (e->E1->Eoper == OPvar)
                    {
                        elem *e1 = e->E1;
                        SYMIDX si = e1->EV.sp.Vsym->Ssymnum;
                        if (si >= 0 && sia[si].canSlice)
                        {
                            assert(si < globsym.top);
                            if (tysize(e1->Ety) != REGSIZE ||
                                (e1->Eoffset != 0 && e1->Eoffset != REGSIZE))
                            {
                                sia[si].canSlice = false;
                            }
                        }
                        return;
                    }
                    e = e->E1;
                    break;
                }
                if (OTunary(e->Eoper))
                {
                    e = e->E1;
                    break;
                }
                if (OTbinary(e->Eoper))
                {
                    sliceStructs_Gather(sia, e->E2);
                    e = e->E1;
                    break;
                }
                return;
        }
    }
}

static void sliceStructs_Replace(SymInfo *sia, elem *e)
{
    while (1)
    {
        switch (e->Eoper)
        {
            case OPvar:
            {
                Symbol *s = e->EV.sp.Vsym;
                SYMIDX si = s->Ssymnum;
                //printf("e: %d %d\n", si, sia[si].canSlice);
                //elem_print(e);
                if (si >= 0 && sia[si].canSlice)
                {
                    if (tysize(e->Ety) == 2 * REGSIZE)
                    {
                        // Rewrite e as (si0 OPpair si0+1)
                        elem *e1 = el_calloc();
                        el_copy(e1, e);
                        e1->Ety = sia[si].ty0;

                        elem *e2 = el_calloc();
                        el_copy(e2, e);
                        Symbol *s1 = globsym.tab[sia[si].si0 + 1]; // +1 for second slice
                        e2->Ety = sia[si].ty1;
                        e2->EV.sp.Vsym = s1;
                        e2->Eoffset = 0;

                        e->Eoper = OPpair;
                        e->E1 = e1;
                        e->E2 = e2;
                    }
                    else if (e->Eoffset == 0)  // the first slice of the symbol is the same as the original
                    {
                    }
                    else
                    {
                        Symbol *s1 = globsym.tab[sia[si].si0 + 1]; // +1 for second slice
                        e->EV.sp.Vsym = s1;
                        e->Eoffset = 0;
                        //printf("replaced with:\n");
                        //elem_print(e);
                    }
                }
                return;
            }

            default:
                if (OTunary(e->Eoper))
                {
                    e = e->E1;
                    break;
                }
                if (OTbinary(e->Eoper))
                {
                    sliceStructs_Replace(sia, e->E2);
                    e = e->E1;
                    break;
                }
                return;
        }
    }
}

void sliceStructs()
{
    if (debugc) printf("sliceStructs()\n");
    size_t sia_length = globsym.top;
    /* 3 is because it is used for two arrays, sia[] and sia2[].
     * sia2[] can grow to twice the size of sia[], as symbols can get split into two.
     */
    SymInfo *sia = (SymInfo *)malloc(3 * sia_length * sizeof(SymInfo));
    assert(sia);
    SymInfo *sia2 = sia + sia_length;

    bool anySlice = false;
    for (int si = 0; si < globsym.top; si++)
    {
        Symbol *s = globsym.tab[si];
        //printf("slice1: %s\n", s->Sident);

        if ((s->Sflags & (GTregcand | SFLunambig)) != (GTregcand | SFLunambig))
        {
            sia[si].canSlice = false;
            continue;
        }

        targ_size_t sz = type_size(s->Stype);
        if (sz != 2 * REGSIZE ||
            tyfv(s->Stype->Tty) || tybasic(s->Stype->Tty) == TYhptr)    // because there is no TYseg
        {
            sia[si].canSlice = false;
            continue;
        }

        switch (s->Sclass)
        {
            case SCfastpar:
            case SCregister:
            case SCauto:
            case SCshadowreg:
            case SCparameter:
                anySlice = true;
                sia[si].canSlice = true;
                sia[si].accessSlice = false;
                sia[si].usePair = false;
                break;

            case SCstack:
            case SCpseudo:
            case SCstatic:
            case SCbprel:
                sia[si].canSlice = false;
                break;

            default:
                symbol_print(s);
                assert(0);
        }
    }

    if (!anySlice)
        goto Ldone;

    for (block *b = startblock; b; b = b->Bnext)
    {
        if (b->BC == BCasm)
            goto Ldone;
        if (b->Belem)
            sliceStructs_Gather(sia, b->Belem);
    }

    {   // scope needed because of goto skipping declarations
        bool any = false;
        int n = 0;              // the number of symbols added
        for (int si = 0; si < sia_length; si++)
        {
            sia2[si + n].canSlice = false;
            if (sia[si].canSlice)
            {
                if (!sia[si].accessSlice)
                {
                    // If never did access it as a slice, don't slice
                    sia[si].canSlice = false;
                    continue;
                }

                /* Split slice-able symbol sold into two symbols,
                 * (sold,snew) in adjacent slots in the symbol table.
                 */
                Symbol *sold = globsym.tab[si + n];

                size_t idlen = 2 + strlen(sold->Sident) + 2;
                char *id = (char *)malloc(idlen + 1);
                assert(id);
                sprintf(id, "__%s_%d", sold->Sident, REGSIZE);
                if (debugc) printf("creating slice symbol %s\n", id);
                Symbol *snew = symbol_calloc(id, idlen);
                free(id);
                snew->Sclass = sold->Sclass;
                snew->Sfl = sold->Sfl;
                snew->Sflags = sold->Sflags;
                if (snew->Sclass == SCfastpar || snew->Sclass == SCshadowreg)
                {
                    snew->Spreg = sold->Spreg2;
                    snew->Spreg2 = NOREG;
                    sold->Spreg2 = NOREG;
                }
                type_free(sold->Stype);
                sold->Stype = type_fake(sia[si].ty0);
                sold->Stype->Tcount++;
                snew->Stype = type_fake(sia[si].ty1);
                snew->Stype->Tcount++;

                SYMIDX sinew = symbol_add(snew);
                for (int i = sinew; i > si + n + 1; --i)
                {
                    globsym.tab[i] = globsym.tab[i - 1];
                    globsym.tab[i]->Ssymnum += 1;
                }
                globsym.tab[si + n + 1] = snew;
                snew->Ssymnum = si + n + 1;

                sia2[si + n].canSlice = true;
                sia2[si + n].si0 = si + n;
                sia2[si + n].ty0 = sia[si].ty0;
                sia2[si + n].ty1 = sia[si].ty1;
                ++n;
                any = true;
            }
        }
        if (!any)
            goto Ldone;
    }

    for (int si = 0; si < globsym.top; si++)
    {
        Symbol *s = globsym.tab[si];
        assert(s->Ssymnum == si);
    }

    for (block *b = startblock; b; b = b->Bnext)
    {
        if (b->Belem)
            sliceStructs_Replace(sia2, b->Belem);
    }

Ldone:
    free(sia);
}

#endif
