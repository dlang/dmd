/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2016-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/gsroa.c, backend/gsroa.d)
 */

module dmd.backend.gsroa;

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
import dmd.backend.el;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.dlist;
import dmd.backend.dvec;

extern (C++):

int REGSIZE();

/* This 'slices' a two register wide aggregate into two separate register-sized variables,
 * enabling much better enregistering.
 * SROA (Scalar Replacement Of Aggregates) is the common term for this.
 */

struct SymInfo
{
    bool canSlice;
    bool accessSlice;   // if Symbol was accessed as a slice
    tym_t ty0;          // type of first slice
    tym_t ty1;          // type of second slice
    SYMIDX si0;
}

private void sliceStructs_Gather(SymInfo *sia, elem *e)
{
    while (1)
    {
        switch (e.Eoper)
        {
            case OPvar:
            {
                SYMIDX si = e.EV.Vsym.Ssymnum;
                if (si >= 0 && sia[si].canSlice)
                {
                    assert(si < globsym.top);
                    uint sz = tysize(e.Ety);
                    if (sz == 2 * REGSIZE && !tyfv(e.Ety))
                    {
                        // Rewritten as OPpair later
                    }
                    else if (sz == REGSIZE &&
                        (e.EV.Voffset == 0 || e.EV.Voffset == REGSIZE))
                    {
                        if (!sia[si].accessSlice)
                        {
                            /* [1] default as pointer type
                             */
                            sia[si].ty0 = TYnptr;
                            sia[si].ty1 = TYnptr;
                        }
                        sia[si].accessSlice = true;
                        if (e.EV.Voffset == 0)
                            sia[si].ty0 = tybasic(e.Ety);
                        else
                            sia[si].ty1 = tybasic(e.Ety);
                    }
                    else
                    {
                        sia[si].canSlice = false;
                    }
                }
                return;
            }

            default:
                if (OTassign(e.Eoper))
                {
                    if (OTbinary(e.Eoper))
                        sliceStructs_Gather(sia, e.EV.E2);

                    // Assignment to a whole var will disallow SROA
                    if (e.EV.E1.Eoper == OPvar)
                    {
                        elem *e1 = e.EV.E1;
                        SYMIDX si = e1.EV.Vsym.Ssymnum;
                        if (si >= 0 && sia[si].canSlice)
                        {
                            assert(si < globsym.top);
                            if (tysize(e1.Ety) != REGSIZE ||
                                (e1.EV.Voffset != 0 && e1.EV.Voffset != REGSIZE))
                            {
                                sia[si].canSlice = false;
                            }
                            // Disable SROA on OSX32 (because XMM registers?)
                            else if (!(config.exe & EX_OSX))
                            {
                                sliceStructs_Gather(sia, e.EV.E1);
                            }
                        }
                        return;
                    }
                    e = e.EV.E1;
                    break;
                }
                if (OTunary(e.Eoper))
                {
                    e = e.EV.E1;
                    break;
                }
                if (OTbinary(e.Eoper))
                {
                    sliceStructs_Gather(sia, e.EV.E2);
                    e = e.EV.E1;
                    break;
                }
                return;
        }
    }
}

private void sliceStructs_Replace(SymInfo *sia, elem *e)
{
    while (1)
    {
        switch (e.Eoper)
        {
            case OPvar:
            {
                Symbol *s = e.EV.Vsym;
                SYMIDX si = s.Ssymnum;
                //printf("e: %d %d\n", si, sia[si].canSlice);
                //elem_print(e);
                if (si >= 0 && sia[si].canSlice)
                {
                    if (tysize(e.Ety) == 2 * REGSIZE)
                    {
                        // Rewrite e as (si0 OPpair si0+1)
                        elem *e1 = el_calloc();
                        el_copy(e1, e);
                        e1.Ety = sia[si].ty0;

                        elem *e2 = el_calloc();
                        el_copy(e2, e);
                        Symbol *s1 = globsym.tab[sia[si].si0 + 1]; // +1 for second slice
                        e2.Ety = sia[si].ty1;
                        e2.EV.Vsym = s1;
                        e2.EV.Voffset = 0;

                        e.Eoper = OPpair;
                        e.EV.E1 = e1;
                        e.EV.E2 = e2;

                        if (tycomplex(e.Ety))
                        {
                            /* Ensure complex OPpair operands are floating point types
                             * because [1] may have defaulted them to a pointer type.
                             * https://issues.dlang.org/show_bug.cgi?id=18936
                             */
                            tym_t tyop;
                            switch (tybasic(e.Ety))
                            {
                                case TYcfloat:   tyop = TYfloat;   break;
                                case TYcdouble:  tyop = TYdouble;  break;
                                case TYcldouble: tyop = TYldouble; break;
                                default:
                                    assert(0);
                            }
                            if (!tyfloating(e1.Ety))
                                e1.Ety = tyop;
                            if (!tyfloating(e2.Ety))
                                e2.Ety = tyop;
                        }
                    }
                    else if (e.EV.Voffset == 0)  // the first slice of the symbol is the same as the original
                    {
                    }
                    else
                    {
                        Symbol *s1 = globsym.tab[sia[si].si0 + 1]; // +1 for second slice
                        e.EV.Vsym = s1;
                        e.EV.Voffset = 0;
                        //printf("replaced with:\n");
                        //elem_print(e);
                    }
                }
                return;
            }

            default:
                if (OTunary(e.Eoper))
                {
                    e = e.EV.E1;
                    break;
                }
                if (OTbinary(e.Eoper))
                {
                    sliceStructs_Replace(sia, e.EV.E2);
                    e = e.EV.E1;
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
    SymInfo *sia = cast(SymInfo *)malloc(3 * sia_length * SymInfo.sizeof);
    assert(sia);
    SymInfo *sia2 = sia + sia_length;

    bool anySlice = false;
    for (int si = 0; si < globsym.top; si++)
    {
        Symbol *s = globsym.tab[si];
        //printf("slice1: %s\n", s.Sident);

        if ((s.Sflags & (GTregcand | SFLunambig)) != (GTregcand | SFLunambig))
        {
            sia[si].canSlice = false;
            continue;
        }

        targ_size_t sz = type_size(s.Stype);
        if (sz != 2 * REGSIZE ||
            tyfv(s.Stype.Tty) || tybasic(s.Stype.Tty) == TYhptr)    // because there is no TYseg
        {
            sia[si].canSlice = false;
            continue;
        }

        switch (s.Sclass)
        {
            case SCfastpar:
            case SCregister:
            case SCauto:
            case SCshadowreg:
            case SCparameter:
                anySlice = true;
                sia[si].canSlice = true;
                sia[si].accessSlice = false;
                // We can't slice whole XMM registers
                if (tyxmmreg(s.Stype.Tty) &&
                    s.Spreg >= XMM0 && s.Spreg <= XMM15 && s.Spreg2 == NOREG)
                {
                    sia[si].canSlice = false;
                }
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

    for (block *b = startblock; b; b = b.Bnext)
    {
        if (b.BC == BCasm)
            goto Ldone;
        if (b.Belem)
            sliceStructs_Gather(sia, b.Belem);
    }

    {   // scope needed because of goto skipping declarations
        bool any = false;
        int n = 0;              // the number of symbols added
        for (int si = 0; si < sia_length; si++)
        {
            sia2[si + n].canSlice = false;
            if (sia[si].canSlice)
            {
                // If never did access it as a slice, don't slice
                if (!sia[si].accessSlice)
                {
                    sia[si].canSlice = false;
                    continue;
                }

                /* Split slice-able symbol sold into two symbols,
                 * (sold,snew) in adjacent slots in the symbol table.
                 */
                Symbol *sold = globsym.tab[si + n];

                size_t idlen = 2 + strlen(sold.Sident.ptr) + 2;
                char *id = cast(char *)malloc(idlen + 1);
                assert(id);
                sprintf(id, "__%s_%d", sold.Sident.ptr, REGSIZE);
                if (debugc) printf("creating slice symbol %s\n", id);
                Symbol *snew = symbol_calloc(id, cast(uint)idlen);
                free(id);
                snew.Sclass = sold.Sclass;
                snew.Sfl = sold.Sfl;
                snew.Sflags = sold.Sflags;
                if (snew.Sclass == SCfastpar || snew.Sclass == SCshadowreg)
                {
                    snew.Spreg = sold.Spreg2;
                    snew.Spreg2 = NOREG;
                    sold.Spreg2 = NOREG;
                }
                type_free(sold.Stype);
                sold.Stype = type_fake(sia[si].ty0);
                sold.Stype.Tcount++;
                snew.Stype = type_fake(sia[si].ty1);
                snew.Stype.Tcount++;

                SYMIDX sinew = symbol_add(snew);
                for (int i = sinew; i > si + n + 1; --i)
                {
                    globsym.tab[i] = globsym.tab[i - 1];
                    globsym.tab[i].Ssymnum += 1;
                }
                globsym.tab[si + n + 1] = snew;
                snew.Ssymnum = si + n + 1;

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
        assert(s.Ssymnum == si);
    }

    for (block *b = startblock; b; b = b.Bnext)
    {
        if (b.Belem)
            sliceStructs_Replace(sia2, b.Belem);
    }

Ldone:
    free(sia);
}

}
