/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2016-2021 by The D Language Foundation, All Rights Reserved
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
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.dlist;
import dmd.backend.dvec;

extern (C++):

nothrow:
@safe:

int REGSIZE();

alias SLICESIZE = REGSIZE;  // slices are all register-sized
enum MAXSLICES = 2;         // max # of pieces we can slice an aggregate into

/* This 'slices' a two register wide aggregate into two separate register-sized variables,
 * enabling much better enregistering.
 * SROA (Scalar Replacement Of Aggregates) is the common term for this.
 */

struct SymInfo
{
    bool canSlice;
    bool accessSlice;   // if Symbol was accessed as a slice
    tym_t[MAXSLICES] ty; // type of each slice
    SYMIDX si0;          // index of first slice, the rest follow sequentially
}

/********************************
 * Gather information about slice-able variables by scanning e.
 * Params:
 *      symtab = symbol table
 *      e = expression to scan
 *      sia = where to put gathered information
 */
@trusted
extern (D) private void sliceStructs_Gather(ref const symtab_t symtab, SymInfo[] sia, const(elem)* e)
{
    while (1)
    {
        switch (e.Eoper)
        {
            case OPvar:
            {
                const si = e.EV.Vsym.Ssymnum;
                if (si != SYMIDX.max && sia[si].canSlice)
                {
                    assert(si < symtab.length);
                    const n = nthSlice(e);
                    const sz = getSize(e);
                    if (sz == 2 * SLICESIZE && !tyfv(e.Ety) &&
                        tybasic(e.Ety) != TYldouble && tybasic(e.Ety) != TYildouble)
                    {
                        // Rewritten as OPpair later
                    }
                    else if (n != NOTSLICE)
                    {
                        if (!sia[si].accessSlice)
                        {
                            /* [1] default as pointer type
                             */
                            foreach (ref ty; sia[si].ty)
                                ty = TYnptr;

                            const s = e.EV.Vsym;
                            const t = s.Stype;
                            if (tybasic(t.Tty) == TYstruct)
                            {
                                if (const targ1 = t.Ttag.Sstruct.Sarg1type)
                                    if (const targ2 = t.Ttag.Sstruct.Sarg2type)
                                    {
                                        sia[si].ty[0] = targ1.Tty;
                                        sia[si].ty[1] = targ2.Tty;
                                    }
                            }
                        }
                        sia[si].accessSlice = true;
                        if (sz == SLICESIZE)
                            sia[si].ty[n] = tybasic(e.Ety);
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
                        sliceStructs_Gather(symtab, sia, e.EV.E2);

                    // Assignment to a whole var will disallow SROA
                    if (e.EV.E1.Eoper == OPvar)
                    {
                        const e1 = e.EV.E1;
                        const si = e1.EV.Vsym.Ssymnum;
                        if (si != SYMIDX.max && sia[si].canSlice)
                        {
                            assert(si < symtab.length);
                            if (nthSlice(e1) == NOTSLICE)
                            {
                                sia[si].canSlice = false;
                            }
                            // Disable SROA on OSX32 (because XMM registers?)
                            // https://issues.dlang.org/show_bug.cgi?id=15206
                            // https://github.com/dlang/dmd/pull/8034
                            else if (!(config.exe & EX_OSX))
                            {
                                sliceStructs_Gather(symtab, sia, e.EV.E1);
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
                    sliceStructs_Gather(symtab, sia, e.EV.E2);
                    e = e.EV.E1;
                    break;
                }
                return;
        }
    }
}

/***********************************
 * Rewrite expression tree e based on info in sia[].
 * Params:
 *      symtab = symbol table
 *      sia = slicing info
 *      e = expression tree to rewrite in place
 */
@trusted
extern (D) private void sliceStructs_Replace(ref symtab_t symtab, const SymInfo[] sia, elem *e)
{
    while (1)
    {
        switch (e.Eoper)
        {
            case OPvar:
            {
                Symbol *s = e.EV.Vsym;
                const si = s.Ssymnum;
                //printf("e: %d %d\n", si, sia[si].canSlice);
                //elem_print(e);
                if (si != SYMIDX.max && sia[si].canSlice)
                {
                    const n = nthSlice(e);
                    if (getSize(e) == 2 * SLICESIZE)
                    {
                        // Rewrite e as (si0 OPpair si0+1)
                        elem *e1 = el_calloc();
                        el_copy(e1, e);
                        e1.Ety = sia[si].ty[0];

                        elem *e2 = el_calloc();
                        el_copy(e2, e);
                        Symbol *s1 = symtab[sia[si].si0 + 1]; // +1 for second slice
                        e2.Ety = sia[si].ty[1];
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
                    else if (n == 0)  // the first slice of the symbol is the same as the original
                    {
                    }
                    else // the nth slice
                    {
                        e.EV.Vsym = symtab[sia[si].si0 + n];
                        e.EV.Voffset -= n * SLICESIZE;
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
                    sliceStructs_Replace(symtab, sia, e.EV.E2);
                    e = e.EV.E1;
                    break;
                }
                return;
        }
    }
}

@trusted
void sliceStructs(ref symtab_t symtab, block* startblock)
{
    if (debugc) printf("sliceStructs() %s\n", funcsym_p.Sident.ptr);
    const sia_length = symtab.length;
    /* 3 is because it is used for two arrays, sia[] and sia2[].
     * sia2[] can grow to twice the size of sia[], as symbols can get split into two.
     */
    debug
        enum tmp_length = 3;
    else
        enum tmp_length = 6;
    SymInfo[tmp_length] tmp = void;
    SymInfo* sip;
    if (sia_length <= tmp.length / 3)
        sip = tmp.ptr;
    else
    {
        sip = cast(SymInfo *)malloc(3 * sia_length * SymInfo.sizeof);
        assert(sip);
    }
    SymInfo[] sia = sip[0 .. sia_length];
    SymInfo[] sia2 = sip[sia_length .. sia_length * 3];

    if (0) foreach (si; 0 .. symtab.length)
    {
        Symbol *s = symtab[si];
        printf("[%d]: %p %d %s\n", cast(int)si, s, cast(int)type_size(s.Stype), s.Sident.ptr);
    }

    bool anySlice = false;
    foreach (si; 0 .. symtab.length)
    {
        Symbol *s = symtab[si];
        //printf("slice1: %s\n", s.Sident.ptr);

        if (!(s.Sflags & SFLunambig))   // if somebody took the address of s
        {
            sia[si].canSlice = false;
            continue;
        }

        const sz = type_size(s.Stype);
        if (sz != 2 * SLICESIZE ||
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
                    isXMMreg(s.Spreg) && s.Spreg2 == NOREG)
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

    foreach (b; BlockRange(startblock))
    {
        if (b.BC == BCasm)
            goto Ldone;
        if (b.Belem)
            sliceStructs_Gather(symtab, sia, b.Belem);
    }

    {   // scope needed because of goto skipping declarations
        bool any = false;
        int n = 0;              // the number of symbols added
        foreach (si; 0 .. sia_length)
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
                Symbol *sold = symtab[si + n];

                const idlen = 2 + strlen(sold.Sident.ptr) + 2;
                char *id = cast(char *)malloc(idlen + 1);
                assert(id);
                sprintf(id, "__%s_%d", sold.Sident.ptr, SLICESIZE);
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
                sold.Stype = type_fake(sia[si].ty[0]);
                sold.Stype.Tcount++;
                snew.Stype = type_fake(sia[si].ty[1]);
                snew.Stype.Tcount++;

                // insert snew into symtab[si + n + 1]
                symbol_insert(symtab, snew, si + n + 1);

                sia2[si + n].canSlice = true;
                sia2[si + n].si0 = si + n;
                sia2[si + n].ty[] = sia[si].ty[];
                ++n;
                any = true;
            }
        }
        if (!any)
            goto Ldone;
    }

    foreach (si; 0 .. symtab.length)
    {
        Symbol *s = symtab[si];
        assert(s.Ssymnum == si);
    }

    foreach (b; BlockRange(startblock))
    {
        if (b.Belem)
            sliceStructs_Replace(symtab, sia2, b.Belem);
    }

Ldone:
    if (sip != tmp.ptr)
        free(sip);
}


/*************************************
 * Determine if `e` is a slice.
 * Params:
 *      e = elem that may be a slice
 * Returns:
 *      slice number if it is, NOTSLICE if not
 */
enum NOTSLICE = -1;
int nthSlice(const(elem)* e)
{
    const sz = tysize(e.Ety); // not getSize(e) because type_fake(TYstruct) doesn't work
    if (sz == -1)
        return NOTSLICE;
    const sliceSize = SLICESIZE;

    /* See if e fits in a slice
     */
    const lwr = e.EV.Voffset;
    const upr = lwr + sz;
    if (0 <= lwr && upr <= sliceSize)
        return 0;
    if (sliceSize < lwr && upr <= sliceSize * 2)
        return 1;

    return NOTSLICE;
}

/******************************************
 * Get size of an elem e.
 */
private int getSize(const(elem)* e)
{
    int sz = tysize(e.Ety);
    if (sz == -1 && e.ET && (tybasic(e.Ety) == TYstruct || tybasic(e.Ety) == TYarray))
        sz = cast(int)type_size(e.ET);
    return sz;
}

}
