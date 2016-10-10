/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/_tocsym.d, _toir.d)
 */

module ddmd.toir;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stdlib;

import ddmd.root.array;
import ddmd.root.outbuffer;
import ddmd.root.rmem;

import ddmd.backend.cdef;
import ddmd.backend.cc;
import ddmd.backend.dt;
import ddmd.backend.el;
import ddmd.backend.global;
import ddmd.backend.oper;
import ddmd.backend.rtlsym;
import ddmd.backend.ty;
import ddmd.backend.type;

import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.dmangle;
import ddmd.dmodule;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.func;
import ddmd.globals;
import ddmd.identifier;
import ddmd.id;
import ddmd.irstate;
import ddmd.mtype;
import ddmd.target;


extern (C++):

bool ISREF(Declaration var, Type tb);
bool ISWIN64REF(Declaration var);

type *Type_toCtype(Type t);
uint totym(Type tx);
Symbol *toSymbol(Dsymbol s);
void toTraceGC(IRState *irs, elem *e, Loc *loc);

/*********************************************
 * Produce elem which increments the usage count for a particular line.
 * Used to implement -cov switch (coverage analysis).
 */
elem *incUsageElem(IRState *irs, Loc loc)
{
    uint linnum = loc.linnum;

    Module m = cast(Module)irs.blx._module;
    if (!m.cov || !linnum ||
        loc.filename != m.srcfile.toChars())
        return null;

    //printf("cov = %p, covb = %p, linnum = %u\n", m.cov, m.covb, p, linnum);

    linnum--;           // from 1-based to 0-based

    /* Set bit in covb[] indicating this is a valid code line number
     */
    uint *p = m.covb;
    if (p)      // covb can be null if it has already been written out to its .obj file
    {
        assert(linnum < m.numlines);
        p += linnum / ((*p).sizeof * 8);
        *p |= 1 << (linnum & ((*p).sizeof * 8 - 1));
    }

    elem *e;
    e = el_ptr(m.cov);
    e = el_bin(OPadd, TYnptr, e, el_long(TYuint, linnum * 4));
    e = el_una(OPind, TYuint, e);
    e = el_bin(OPaddass, TYuint, e, el_long(TYuint, 1));
    return e;
}

/******************************************
 * Return elem that evaluates to the static frame pointer for function fd.
 * If fd is a member function, the returned expression will compute the value
 * of fd's 'this' variable.
 * This routine is critical for implementing nested functions.
 */
elem *getEthis(Loc loc, IRState *irs, Dsymbol fd)
{
    elem *ethis;
    FuncDeclaration thisfd = irs.getFunc();
    Dsymbol fdparent = fd.toParent2();
    Dsymbol fdp = fdparent;

    /* These two are compiler generated functions for the in and out contracts,
     * and are called from an overriding function, not just the one they're
     * nested inside, so this hack is so they'll pass
     */
    if (fdparent != thisfd && (fd.ident == Id.require || fd.ident == Id.ensure))
    {
        FuncDeclaration fdthis = thisfd;
        for (size_t i = 0; ; )
        {
            if (i == fdthis.foverrides.dim)
            {
                if (i == 0)
                    break;
                fdthis = fdthis.foverrides[0];
                i = 0;
                continue;
            }
            if (fdthis.foverrides[i] == fdp)
            {
                fdparent = thisfd;
                break;
            }
            i++;
        }
    }

    //printf("[%s] getEthis(thisfd = '%s', fd = '%s', fdparent = '%s')\n", loc.toChars(), thisfd.toPrettyChars(), fd.toPrettyChars(), fdparent.toPrettyChars());
    if (fdparent == thisfd)
    {
        /* Going down one nesting level, i.e. we're calling
         * a nested function from its enclosing function.
         */
        if (irs.sclosure && !(fd.ident == Id.require || fd.ident == Id.ensure))
        {
            ethis = el_var(irs.sclosure);
        }
        else if (irs.sthis)
        {
            // We have a 'this' pointer for the current function

            if (fdp != thisfd)
            {
                /* fdparent (== thisfd) is a derived member function,
                 * fdp is the overridden member function in base class, and
                 * fd is the nested function '__require' or '__ensure'.
                 * Even if there's a closure environment, we should give
                 * original stack data as the nested function frame.
                 * See also: SymbolExp.toElem() in e2ir.c (Bugzilla 9383 fix)
                 */
                /* Address of 'sthis' gives the 'this' for the nested
                 * function.
                 */
                //printf("L%d fd = %s, fdparent = %s, fd.toParent2() = %s\n",
                //    __LINE__, fd.toPrettyChars(), fdparent.toPrettyChars(), fdp.toPrettyChars());
                assert(fd.ident == Id.require || fd.ident == Id.ensure);
                assert(thisfd.hasNestedFrameRefs());

                ClassDeclaration cdp = fdp.isThis().isClassDeclaration();
                ClassDeclaration cd = thisfd.isThis().isClassDeclaration();
                assert(cdp && cd);

                int offset;
                cdp.isBaseOf(cd, &offset);
                assert(offset != ClassDeclaration.OFFSET_RUNTIME);
                //printf("%s to %s, offset = %d\n", cd.toChars(), cdp.toChars(), offset);
                if (offset)
                {
                    /* Bugzilla 7517: If fdp is declared in interface, offset the
                     * 'this' pointer to get correct interface type reference.
                     */
                    Symbol *stmp = symbol_genauto(TYnptr);
                    ethis = el_bin(OPadd, TYnptr, el_var(irs.sthis), el_long(TYsize_t, offset));
                    ethis = el_bin(OPeq, TYnptr, el_var(stmp), ethis);
                    ethis = el_combine(ethis, el_ptr(stmp));
                    //elem_print(ethis);
                }
                else
                    ethis = el_ptr(irs.sthis);
            }
            else if (thisfd.hasNestedFrameRefs())
            {
                /* Local variables are referenced, can't skip.
                 * Address of 'sthis' gives the 'this' for the nested
                 * function.
                 */
                ethis = el_ptr(irs.sthis);
            }
            else
            {
                /* If no variables in the current function's frame are
                 * referenced by nested functions, then we can 'skip'
                 * adding this frame into the linked list of stack
                 * frames.
                 */
                ethis = el_var(irs.sthis);
            }
        }
        else
        {
            /* No 'this' pointer for current function,
             */
            if (thisfd.hasNestedFrameRefs())
            {
                /* OPframeptr is an operator that gets the frame pointer
                 * for the current function, i.e. for the x86 it gets
                 * the value of EBP
                 */
                ethis = el_long(TYnptr, 0);
                ethis.Eoper = OPframeptr;
            }
            else
            {
                /* Use null if no references to the current function's frame
                 */
                ethis = el_long(TYnptr, 0);
            }
        }
    }
    else
    {
        if (!irs.sthis)                // if no frame pointer for this function
        {
            fd.error(loc, "is a nested function and cannot be accessed from %s", irs.getFunc().toPrettyChars());
            return el_long(TYnptr, 0); // error recovery
        }

        /* Go up a nesting level, i.e. we need to find the 'this'
         * of an enclosing function.
         * Our 'enclosing function' may also be an inner class.
         */
        ethis = el_var(irs.sthis);
        Dsymbol s = thisfd;
        while (fd != s)
        {
            FuncDeclaration fdp2 = s.toParent2().isFuncDeclaration();

            //printf("\ts = '%s'\n", s.toChars());
            thisfd = s.isFuncDeclaration();
            if (thisfd)
            {
                /* Enclosing function is a function.
                 */
                // Error should have been caught by front end
                assert(thisfd.isNested() || thisfd.vthis);
            }
            else
            {
                /* Enclosed by an aggregate. That means the current
                 * function must be a member function of that aggregate.
                 */
                AggregateDeclaration ad = s.isAggregateDeclaration();
                if (!ad)
                {
                  Lnoframe:
                    irs.getFunc().error(loc, "cannot get frame pointer to %s", fd.toPrettyChars());
                    return el_long(TYnptr, 0);      // error recovery
                }
                ClassDeclaration cd = ad.isClassDeclaration();
                ClassDeclaration cdx = fd.isClassDeclaration();
                if (cd && cdx && cdx.isBaseOf(cd, null))
                    break;
                StructDeclaration sd = ad.isStructDeclaration();
                if (fd == sd)
                    break;
                if (!ad.isNested() || !ad.vthis)
                    goto Lnoframe;

                ethis = el_bin(OPadd, TYnptr, ethis, el_long(TYsize_t, ad.vthis.offset));
                ethis = el_una(OPind, TYnptr, ethis);
            }
            if (fdparent == s.toParent2())
                break;

            /* Remember that frames for functions that have no
             * nested references are skipped in the linked list
             * of frames.
             */
            if (fdp2 && fdp2.hasNestedFrameRefs())
                ethis = el_una(OPind, TYnptr, ethis);

            s = s.toParent2();
            assert(s);
        }
    }
    version (none)
    {
        printf("ethis:\n");
        elem_print(ethis);
        printf("\n");
    }
    return ethis;
}

/*************************
 * Initialize the hidden aggregate member, vthis, with
 * the context pointer.
 * Returns:
 *      *(ey + ad.vthis.offset) = this;
 */
elem *setEthis(Loc loc, IRState *irs, elem *ey, AggregateDeclaration ad)
{
    elem *ethis;
    FuncDeclaration thisfd = irs.getFunc();
    int offset = 0;
    Dsymbol adp = ad.toParent2();     // class/func we're nested in

    //printf("[%s] setEthis(ad = %s, adp = %s, thisfd = %s)\n", loc.toChars(), ad.toChars(), adp.toChars(), thisfd.toChars());

    if (adp == thisfd)
    {
        ethis = getEthis(loc, irs, ad);
    }
    else if (thisfd.vthis &&
          (adp == thisfd.toParent2() ||
           (adp.isClassDeclaration() &&
            adp.isClassDeclaration().isBaseOf(thisfd.toParent2().isClassDeclaration(), &offset)
           )
          )
        )
    {
        /* Class we're new'ing is at the same level as thisfd
         */
        assert(offset == 0);    // BUG: should handle this case
        ethis = el_var(irs.sthis);
    }
    else
    {
        ethis = getEthis(loc, irs, adp);
        FuncDeclaration fdp = adp.isFuncDeclaration();
        if (fdp && fdp.hasNestedFrameRefs())
            ethis = el_una(OPaddr, TYnptr, ethis);
    }

    ey = el_bin(OPadd, TYnptr, ey, el_long(TYsize_t, ad.vthis.offset));
    ey = el_una(OPind, TYnptr, ey);
    ey = el_bin(OPeq, TYnptr, ey, ethis);
    return ey;
}

/*******************************************
 * Convert intrinsic function to operator.
 * Returns that operator, -1 if not an intrinsic function.
 */
int intrinsic_op(FuncDeclaration fd)
{
    fd = fd.toAliasFunc();
    const char *name = mangleExact(fd);
    //printf("intrinsic_op(%s)\n", name);
    __gshared immutable char*[11] std_namearray =
    [
        /* The names are mangled differently because of the pure and
         * nothrow attributes.
         */
        "4math3cosFNaNbNiNfeZe",
        "4math3sinFNaNbNiNfeZe",
        "4math4fabsFNaNbNiNfeZe",
        "4math4rintFNaNbNiNfeZe",
        "4math4sqrtFNaNbNiNfdZd",
        "4math4sqrtFNaNbNiNfeZe",
        "4math4sqrtFNaNbNiNffZf",
        "4math4yl2xFNaNbNiNfeeZe",
        "4math5ldexpFNaNbNiNfeiZe",
        "4math6rndtolFNaNbNiNfeZl",
        "4math6yl2xp1FNaNbNiNfeeZe",
    ];
    __gshared immutable char*[11] std_namearray64 =
    [
        /* The names are mangled differently because of the pure and
         * nothrow attributes.
         */
        "4math3cosFNaNbNiNfeZe",
        "4math3sinFNaNbNiNfeZe",
        "4math4fabsFNaNbNiNfeZe",
        "4math4rintFNaNbNiNfeZe",
        "4math4sqrtFNaNbNiNfdZd",
        "4math4sqrtFNaNbNiNfeZe",
        "4math4sqrtFNaNbNiNffZf",
        "4math4yl2xFNaNbNiNfeeZe",
        "4math5ldexpFNaNbNiNfeiZe",
        "4math6rndtolFNaNbNiNfeZl",
        "4math6yl2xp1FNaNbNiNfeeZe",
    ];
    __gshared immutable ubyte[11] std_ioptab =
    [
        OPcos,
        OPsin,
        OPabs,
        OPrint,
        OPsqrt,
        OPsqrt,
        OPsqrt,
        OPyl2x,
        OPscale,
        OPrndtol,
        OPyl2xp1,
    ];

    __gshared immutable char*[44] core_namearray =
    [
        "4math3cosFNaNbNiNfeZe",
        "4math3sinFNaNbNiNfeZe",
        "4math4fabsFNaNbNiNfeZe",
        "4math4rintFNaNbNiNfeZe",
        "4math4sqrtFNaNbNiNfdZd",
        "4math4sqrtFNaNbNiNfeZe",
        "4math4sqrtFNaNbNiNffZf",
        "4math4yl2xFNaNbNiNfeeZe",
        "4math5ldexpFNaNbNiNfeiZe",
        "4math6rndtolFNaNbNiNfeZl",
        "4math6yl2xp1FNaNbNiNfeeZe",

        "4simd10__prefetchFNaNbNiNfxPvhZv",
        "4simd10__simd_stoFNaNbNiNfE4core4simd3XMMNhG16vNhG16vZNhG16v",
        "4simd10__simd_stoFNaNbNiNfE4core4simd3XMMdNhG16vZNhG16v",
        "4simd10__simd_stoFNaNbNiNfE4core4simd3XMMfNhG16vZNhG16v",
        "4simd6__simdFNaNbNiNfE4core4simd3XMMNhG16vNhG16vZNhG16v",
        "4simd6__simdFNaNbNiNfE4core4simd3XMMNhG16vNhG16vhZNhG16v",
        "4simd6__simdFNaNbNiNfE4core4simd3XMMNhG16vZNhG16v",
        "4simd6__simdFNaNbNiNfE4core4simd3XMMdZNhG16v",
        "4simd6__simdFNaNbNiNfE4core4simd3XMMfZNhG16v",
        "4simd9__simd_ibFNaNbNiNfE4core4simd3XMMNhG16vhZNhG16v",

        "5bitop12volatileLoadFNbNiNfPhZh",
        "5bitop12volatileLoadFNbNiNfPkZk",
        "5bitop12volatileLoadFNbNiNfPmZm",
        "5bitop12volatileLoadFNbNiNfPtZt",

        "5bitop13volatileStoreFNbNiNfPhhZv",
        "5bitop13volatileStoreFNbNiNfPkkZv",
        "5bitop13volatileStoreFNbNiNfPmmZv",
        "5bitop13volatileStoreFNbNiNfPttZv",

        "5bitop3bsfFNaNbNiNfkZi",
        "5bitop3bsrFNaNbNiNfkZi",
        "5bitop3btcFNaNbNiPkkZi",
        "5bitop3btrFNaNbNiPkkZi",
        "5bitop3btsFNaNbNiPkkZi",
        "5bitop3inpFNbNikZh",
        "5bitop4inplFNbNikZk",
        "5bitop4inpwFNbNikZt",
        "5bitop4outpFNbNikhZh",
        "5bitop5bswapFNaNbNiNfkZk",
        "5bitop5outplFNbNikkZk",
        "5bitop5outpwFNbNiktZt",

        "5bitop7_popcntFNaNbNiNfkZi",
        "5bitop7_popcntFNaNbNiNfmxx", // don't find 64 bit version in 32 bit code
        "5bitop7_popcntFNaNbNiNftZt",
    ];
    __gshared immutable char*[44] core_namearray64 =
    [
        "4math3cosFNaNbNiNfeZe",
        "4math3sinFNaNbNiNfeZe",
        "4math4fabsFNaNbNiNfeZe",
        "4math4rintFNaNbNiNfeZe",
        "4math4sqrtFNaNbNiNfdZd",
        "4math4sqrtFNaNbNiNfeZe",
        "4math4sqrtFNaNbNiNffZf",
        "4math4yl2xFNaNbNiNfeeZe",
        "4math5ldexpFNaNbNiNfeiZe",
        "4math6rndtolFNaNbNiNfeZl",
        "4math6yl2xp1FNaNbNiNfeeZe",

        "4simd10__prefetchFNaNbNiNfxPvhZv",
        "4simd10__simd_stoFNaNbNiNfE4core4simd3XMMNhG16vNhG16vZNhG16v",
        "4simd10__simd_stoFNaNbNiNfE4core4simd3XMMdNhG16vZNhG16v",
        "4simd10__simd_stoFNaNbNiNfE4core4simd3XMMfNhG16vZNhG16v",
        "4simd6__simdFNaNbNiNfE4core4simd3XMMNhG16vNhG16vZNhG16v",
        "4simd6__simdFNaNbNiNfE4core4simd3XMMNhG16vNhG16vhZNhG16v",
        "4simd6__simdFNaNbNiNfE4core4simd3XMMNhG16vZNhG16v",
        "4simd6__simdFNaNbNiNfE4core4simd3XMMdZNhG16v",
        "4simd6__simdFNaNbNiNfE4core4simd3XMMfZNhG16v",
        "4simd9__simd_ibFNaNbNiNfE4core4simd3XMMNhG16vhZNhG16v",

        "5bitop12volatileLoadFNbNiNfPhZh",
        "5bitop12volatileLoadFNbNiNfPkZk",
        "5bitop12volatileLoadFNbNiNfPmZm",
        "5bitop12volatileLoadFNbNiNfPtZt",

        "5bitop13volatileStoreFNbNiNfPhhZv",
        "5bitop13volatileStoreFNbNiNfPkkZv",
        "5bitop13volatileStoreFNbNiNfPmmZv",
        "5bitop13volatileStoreFNbNiNfPttZv",

        "5bitop3bsfFNaNbNiNfmZi",
        "5bitop3bsrFNaNbNiNfmZi",
        "5bitop3btcFNaNbNiPmmZi",
        "5bitop3btrFNaNbNiPmmZi",
        "5bitop3btsFNaNbNiPmmZi",
        "5bitop3inpFNbNikZh",
        "5bitop4inplFNbNikZk",
        "5bitop4inpwFNbNikZt",
        "5bitop4outpFNbNikhZh",
        "5bitop5bswapFNaNbNiNfkZk",
        "5bitop5outplFNbNikkZk",
        "5bitop5outpwFNbNiktZt",

        "5bitop7_popcntFNaNbNiNfkZi",
        "5bitop7_popcntFNaNbNiNfmZi",
        "5bitop7_popcntFNaNbNiNftZt",
    ];
    __gshared immutable ubyte[44] core_ioptab =
    [
        OPcos,
        OPsin,
        OPabs,
        OPrint,
        OPsqrt,
        OPsqrt,
        OPsqrt,
        OPyl2x,
        OPscale,
        OPrndtol,
        OPyl2xp1,

        OPprefetch,
        OPvector,
        OPvector,
        OPvector,
        OPvector,
        OPvector,
        OPvector,
        OPvector,
        OPvector,
        OPvector,

        OPind,
        OPind,
        OPind,
        OPind,

        OPeq,
        OPeq,
        OPeq,
        OPeq,

        OPbsf,
        OPbsr,
        OPbtc,
        OPbtr,
        OPbts,
        OPinp,
        OPinp,
        OPinp,
        OPoutp,

        OPbswap,
        OPoutp,
        OPoutp,

        OPpopcnt,
        OPpopcnt,
        OPpopcnt,
    ];

    static assert(std_namearray.length == std_namearray64.length);
    static assert(std_namearray.length == std_ioptab.length);
    static assert(core_namearray.length == core_namearray64.length);
    static assert(core_namearray.length == core_ioptab.length);
    debug
    {
        for (size_t i = 0; i < std_namearray.length - 1; i++)
        {
            if (strcmp(std_namearray[i], std_namearray[i + 1]) >= 0)
            {
                printf("std_namearray[%ld] = '%s'\n", cast(long)i, std_namearray[i]);
                assert(0);
            }
        }
        for (size_t i = 0; i < std_namearray64.length - 1; i++)
        {
            if (strcmp(std_namearray64[i], std_namearray64[i + 1]) >= 0)
            {
                printf("std_namearray64[%ld] = '%s'\n", cast(long)i, std_namearray64[i]);
                assert(0);
            }
        }
        for (size_t i = 0; i < core_namearray.length - 1; i++)
        {
            //printf("test1 %s %s %d\n", core_namearray[i], core_namearray[i + 1], strcmp(core_namearray[i], core_namearray[i + 1]));
            if (strcmp(core_namearray[i], core_namearray[i + 1]) >= 0)
            {
                printf("core_namearray[%ld] = '%s'\n", cast(long)i, core_namearray[i]);
                assert(0);
            }
        }
        for (size_t i = 0; i < core_namearray64.length - 1; i++)
        {
            if (strcmp(core_namearray64[i], core_namearray64[i + 1]) >= 0)
            {
                printf("core_namearray64[%ld] = '%s'\n", cast(long)i, core_namearray64[i]);
                assert(0);
            }
        }
    }

    size_t length = strlen(name);

    if (length > 10 &&
        (name[7] == 'm' || name[7] == 'i') &&
        !memcmp(name, "_D3std".ptr, 6))
    {
        int i = binary(name + 6,
            cast(const(char)**)(global.params.is64bit ? std_namearray64.ptr : std_namearray.ptr),
            cast(int)std_namearray.length);
        return (i == -1) ? i : std_ioptab[i];
    }
    if (length > 12 &&
        (name[8] == 'm' || name[8] == 'b' || name[8] == 's') &&
        !memcmp(name, "_D4core".ptr, 7))
    {
        int i = binary(name + 7,
            cast(const(char)**)(global.params.is64bit ? core_namearray64.ptr : core_namearray.ptr),
            cast(int)core_namearray.length);
        if (i != -1)
            return core_ioptab[i];

        if (global.params.is64bit &&
            fd.toParent().isTemplateInstance() &&
            fd.ident == Id.va_start)
        {
            OutBuffer buf;
            mangleToBuffer(fd.getModule(), &buf);
            const s = buf.peekString();
            if (!strcmp(s, "4core4stdc6stdarg"))
            {
                return OPva_start;
            }
        }

        return -1;
    }

    return -1;
}

/**************************************
 * Given an expression e that is an array,
 * determine and set the 'length' variable.
 * Input:
 *      lengthVar       Symbol of 'length' variable
 *      &e      expression that is the array
 *      t1      Type of the array
 * Output:
 *      e       is rewritten to avoid side effects
 * Returns:
 *      expression that initializes 'length'
 */
elem *resolveLengthVar(VarDeclaration lengthVar, elem **pe, Type t1)
{
    //printf("resolveLengthVar()\n");
    elem *einit = null;

    if (lengthVar && !(lengthVar.storage_class & STCconst))
    {
        elem *elength;
        Symbol *slength;

        if (t1.ty == Tsarray)
        {
            TypeSArray tsa = cast(TypeSArray)t1;
            dinteger_t length = tsa.dim.toInteger();

            elength = el_long(TYsize_t, length);
            goto L3;
        }
        else if (t1.ty == Tarray)
        {
            elength = *pe;
            *pe = el_same(&elength);
            elength = el_una(global.params.is64bit ? OP128_64 : OP64_32, TYsize_t, elength);

        L3:
            slength = toSymbol(lengthVar);
            //symbol_add(slength);

            einit = el_bin(OPeq, TYsize_t, el_var(slength), elength);
        }
    }
    return einit;
}


void setClosureVarOffset(FuncDeclaration fd)
{
    if (fd.needsClosure())
    {
        uint offset = Target.ptrsize;      // leave room for previous sthis

        for (size_t i = 0; i < fd.closureVars.dim; i++)
        {
            VarDeclaration v = fd.closureVars[i];

            /* Align and allocate space for v in the closure
             * just like AggregateDeclaration.addField() does.
             */
            uint memsize;
            uint memalignsize;
            structalign_t xalign;
            if (v.storage_class & STClazy)
            {
                /* Lazy variables are really delegates,
                 * so give same answers that TypeDelegate would
                 */
                memsize = Target.ptrsize * 2;
                memalignsize = memsize;
                xalign = STRUCTALIGN_DEFAULT;
            }
            else if (v.storage_class & (STCout | STCref))
            {
                // reference parameters are just pointers
                memsize = Target.ptrsize;
                memalignsize = memsize;
                xalign = STRUCTALIGN_DEFAULT;
            }
            else
            {
                memsize = cast(uint)v.type.size();
                memalignsize = v.type.alignsize();
                xalign = v.alignment;
            }
            AggregateDeclaration.alignmember(xalign, memalignsize, &offset);
            v.offset = offset;
            //printf("closure var %s, offset = %d\n", v.toChars(), v.offset);

            offset += memsize;

            /* Can't do nrvo if the variable is put in a closure, since
             * what the shidden points to may no longer exist.
             */
            if (fd.nrvo_can && fd.nrvo_var == v)
            {
                fd.nrvo_can = 0;
            }
        }
    }
}

/*************************************
 * Closures are implemented by taking the local variables that
 * need to survive the scope of the function, and copying them
 * into a gc allocated chuck of memory. That chunk, called the
 * closure here, is inserted into the linked list of stack
 * frames instead of the usual stack frame.
 *
 * buildClosure() inserts code just after the function prolog
 * is complete. It allocates memory for the closure, allocates
 * a local variable (sclosure) to point to it, inserts into it
 * the link to the enclosing frame, and copies into it the parameters
 * that are referred to in nested functions.
 * In VarExp::toElem and SymOffExp::toElem, when referring to a
 * variable that is in a closure, takes the offset from sclosure rather
 * than from the frame pointer.
 *
 * getEthis() and NewExp::toElem need to use sclosure, if set, rather
 * than the current frame pointer.
 */
void buildClosure(FuncDeclaration fd, IRState *irs)
{
    //printf("buildClosure(fd = %s)\n", fd.toChars());
    if (fd.needsClosure())
    {
        setClosureVarOffset(fd);

        // Generate closure on the heap
        // BUG: doesn't capture variadic arguments passed to this function

        /* BUG: doesn't handle destructors for the local variables.
         * The way to do it is to make the closure variables the fields
         * of a class object:
         *    class Closure {
         *        vtbl[]
         *        monitor
         *        ptr to destructor
         *        sthis
         *        ... closure variables ...
         *        ~this() { call destructor }
         *    }
         */
        //printf("FuncDeclaration.buildClosure() %s\n", fd.toChars());

        /* Generate type name for closure struct */
        const char *name1 = "CLOSURE.";
        const char *name2 = fd.toPrettyChars();
        size_t namesize = strlen(name1)+strlen(name2)+1;
        char *closname = cast(char *) calloc(namesize, char.sizeof);
        strcat(strcat(closname, name1), name2);

        /* Build type for closure */
        type *Closstru = type_struct_class(closname, Target.ptrsize, 0, null, null, false, false, true);
        free(closname);
        symbol_struct_addField(Closstru.Ttag, "__chain", Type_toCtype(Type.tvoidptr), 0);

        Symbol *sclosure;
        sclosure = symbol_name("__closptr", SCauto, type_pointer(Closstru));
        sclosure.Sflags |= SFLtrue | SFLfree;
        symbol_add(sclosure);
        irs.sclosure = sclosure;

        assert(fd.closureVars.dim);
        assert(fd.closureVars[0].offset >= Target.ptrsize);
        for (size_t i = 0; i < fd.closureVars.dim; i++)
        {
            VarDeclaration v = fd.closureVars[i];
            //printf("closure var %s\n", v.toChars());

            // Hack for the case fail_compilation/fail10666.d,
            // until proper issue 5730 fix will come.
            bool isScopeDtorParam = v.edtor && (v.storage_class & STCparameter);
            if (v.needsScopeDtor() || isScopeDtorParam)
            {
                /* Because the value needs to survive the end of the scope!
                 */
                v.error("has scoped destruction, cannot build closure");
            }
            if (v.isargptr)
            {
                /* See Bugzilla 2479
                 * This is actually a bug, but better to produce a nice
                 * message at compile time rather than memory corruption at runtime
                 */
                v.error("cannot reference variadic arguments from closure");
            }

            /* Set Sscope to closure */
            Symbol *vsym = toSymbol(v);
            assert(vsym.Sscope == null);
            vsym.Sscope = sclosure;

            /* Add variable as closure type member */
            symbol_struct_addField(Closstru.Ttag, &vsym.Sident[0], vsym.Stype, v.offset);
            //printf("closure field %s: memalignsize: %i, offset: %i\n", &vsym.Sident[0], memalignsize, v.offset);
        }

        // Calculate the size of the closure
        VarDeclaration  vlast = fd.closureVars[fd.closureVars.dim - 1];
        uint structsize;
        if (vlast.storage_class & STClazy)
            structsize = vlast.offset + Target.ptrsize * 2;
        else if (vlast.isRef() || vlast.isOut())
            structsize = vlast.offset + Target.ptrsize;
        else
            structsize = cast(uint)(vlast.offset + vlast.type.size());
        //printf("structsize = %d\n", structsize);

        Closstru.Ttag.Sstruct.Sstructsize = structsize;

        // Allocate memory for the closure
        elem *e = el_long(TYsize_t, structsize);
        e = el_bin(OPcall, TYnptr, el_var(getRtlsym(RTLSYM_ALLOCMEMORY)), e);
        toTraceGC(irs, e, &fd.loc);

        // Assign block of memory to sclosure
        //    sclosure = allocmemory(sz);
        e = el_bin(OPeq, TYvoid, el_var(sclosure), e);

        // Set the first element to sthis
        //    *(sclosure + 0) = sthis;
        elem *ethis;
        if (irs.sthis)
            ethis = el_var(irs.sthis);
        else
            ethis = el_long(TYnptr, 0);
        elem *ex = el_una(OPind, TYnptr, el_var(sclosure));
        ex = el_bin(OPeq, TYnptr, ex, ethis);
        e = el_combine(e, ex);

        // Copy function parameters into closure
        for (size_t i = 0; i < fd.closureVars.dim; i++)
        {
            VarDeclaration v = fd.closureVars[i];

            if (!v.isParameter())
                continue;
            tym_t tym = totym(v.type);
            bool win64ref = ISWIN64REF(v);
            if (win64ref)
            {
                if (v.storage_class & STClazy)
                    tym = TYdelegate;
            }
            else if (ISREF(v, null))
                tym = TYnptr;   // reference parameters are just pointers
            else if (v.storage_class & STClazy)
                tym = TYdelegate;
            ex = el_bin(OPadd, TYnptr, el_var(sclosure), el_long(TYsize_t, v.offset));
            ex = el_una(OPind, tym, ex);
            elem *ev = el_var(toSymbol(v));
            if (win64ref)
            {
                ev.Ety = TYnptr;
                ev = el_una(OPind, tym, ev);
                if (tybasic(ev.Ety) == TYstruct || tybasic(ev.Ety) == TYarray)
                    ev.ET = Type_toCtype(v.type);
            }
            if (tybasic(ex.Ety) == TYstruct || tybasic(ex.Ety) == TYarray)
            {
                .type *t = Type_toCtype(v.type);
                ex.ET = t;
                ex = el_bin(OPstreq, tym, ex, ev);
                ex.ET = t;
            }
            else
                ex = el_bin(OPeq, tym, ex, ev);

            e = el_combine(e, ex);
        }

        block_appendexp(irs.blx.curblock, e);
    }
}


/***************************
 * Determine return style of function - whether in registers or
 * through a hidden pointer to the caller's stack.
 */
RET retStyle(TypeFunction tf)
{
    //printf("TypeFunction.retStyle() %s\n", toChars());
    if (tf.isref)
    {
        //printf("  ref RETregs\n");
        return RETregs;                 // returns a pointer
    }

    Type tn = tf.next.toBasetype();
    //printf("tn = %s\n", tn.toChars());
    d_uns64 sz = tn.size();
    Type tns = tn;

    if (global.params.isWindows && global.params.is64bit)
    {
        // http://msdn.microsoft.com/en-us/library/7572ztz4.aspx
        if (tns.ty == Tcomplex32)
            return RETstack;
        if (tns.isscalar())
            return RETregs;

        tns = tns.baseElemOf();
        if (tns.ty == Tstruct)
        {
            StructDeclaration sd = (cast(TypeStruct)tns).sym;
            if (sd.ident == Id.__c_long_double)
                return RETregs;
            if (!sd.isPOD() || sz > 8)
                return RETstack;
            if (sd.fields.dim == 0)
                return RETstack;
        }
        if (sz <= 16 && !(sz & (sz - 1)))
            return RETregs;
        return RETstack;
    }
    else if (global.params.isWindows && global.params.mscoff)
    {
        Type tb = tns.baseElemOf();
        if (tb.ty == Tstruct)
        {
            StructDeclaration sd = (cast(TypeStruct)tb).sym;
            if (sd.ident == Id.__c_long_double)
                return RETregs;
        }
    }

Lagain:
    if (tns.ty == Tsarray)
    {
        tns = tns.baseElemOf();
        if (tns.ty != Tstruct)
        {
L2:
            if (global.params.isLinux && tf.linkage != LINKd && !global.params.is64bit)
            {
                                                // 32 bit C/C++ structs always on stack
            }
            else
            {
                switch (sz)
                {
                    case 1:
                    case 2:
                    case 4:
                    case 8:
                        //printf("  sarray RETregs\n");
                        return RETregs; // return small structs in regs
                                            // (not 3 byte structs!)
                    default:
                        break;
                }
            }
            //printf("  sarray RETstack\n");
            return RETstack;
        }
    }

    if (tns.ty == Tstruct)
    {
        StructDeclaration sd = (cast(TypeStruct)tns).sym;
        if (global.params.isLinux && tf.linkage != LINKd && !global.params.is64bit)
        {
            if (sd.ident == Id.__c_long || sd.ident == Id.__c_ulong)
                return RETregs;

            //printf("  2 RETstack\n");
            return RETstack;            // 32 bit C/C++ structs always on stack
        }
        if (global.params.isWindows && tf.linkage == LINKcpp && !global.params.is64bit &&
                 sd.isPOD() && sd.ctor)
        {
            // win32 returns otherwise POD structs with ctors via memory
            // unless it's not really a struct
            if (sd.ident == Id.__c_long || sd.ident == Id.__c_ulong)
                return RETregs;
            return RETstack;
        }
        if (sd.arg1type && !sd.arg2type)
        {
            tns = sd.arg1type;
            if (tns.ty != Tstruct)
                goto L2;
            goto Lagain;
        }
        else if (global.params.is64bit && !sd.arg1type && !sd.arg2type)
            return RETstack;
        else if (sd.isPOD())
        {
            switch (sz)
            {
                case 1:
                case 2:
                case 4:
                case 8:
                    //printf("  3 RETregs\n");
                    return RETregs;     // return small structs in regs
                                        // (not 3 byte structs!)
                case 16:
                    if (!global.params.isWindows && global.params.is64bit)
                       return RETregs;
                    break;

                default:
                    break;
            }
        }
        //printf("  3 RETstack\n");
        return RETstack;
    }
    else if ((global.params.isLinux || global.params.isOSX || global.params.isFreeBSD || global.params.isSolaris) &&
             tf.linkage == LINKc &&
             tns.iscomplex())
    {
        if (tns.ty == Tcomplex32)
            return RETregs;     // in EDX:EAX, not ST1:ST0
        else
            return RETstack;
    }
    else
    {
        //assert(sz <= 16);
        //printf("  4 RETregs\n");
        return RETregs;
    }
}
