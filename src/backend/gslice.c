
/*
 * Copyright (c) 2016 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/backend/gslice.c
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
 */

struct SymInfo
{
    bool canSlice;
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
                    if (tysize(e->Ety) != REGSIZE ||
                        (e->Eoffset != 0 && e->Eoffset != REGSIZE))
                    {
                        sia[si].canSlice = false;
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
                    if (e->Eoffset == 0)  // the first slice of the symbol is the same as the original
                    {
                        type_free(s->Stype);
                        s->Stype = type_fake(e->Ety);
                    }
                    else
                    {
                        Symbol *s1 = globsym.tab[sia[si].si0 + 1]; // +1 for second slice
                        type_free(s1->Stype);
                        s1->Stype = type_fake(e->Ety);
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
                sold->Stype = type_fake(TYnptr);
                sold->Stype->Tcount++;
                snew->Stype = type_fake(TYnptr);
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
