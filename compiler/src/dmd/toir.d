/**
 * Convert to Intermediate Representation (IR) for the back-end.
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/toir.d, _toir.d)
 * Documentation:  https://dlang.org/phobos/dmd_toir.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/toir.d
 */

module dmd.toir;

import core.checkedint;
import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stdlib;

import dmd.root.array;
import dmd.common.outbuffer;
import dmd.root.rmem;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.oper;
import dmd.backend.rtlsym;
import dmd.backend.symtab : SYMIDX;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.aggregate;
import dmd.arraytypes;
import dmd.astenums;
import dmd.attrib;
import dmd.dclass;
import dmd.declaration;
import dmd.dmdparams;
import dmd.dmodule;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.toctype;
import dmd.e2ir;
import dmd.errorsink;
import dmd.func;
import dmd.globals : Param;
import dmd.glue;
import dmd.identifier;
import dmd.id;
import dmd.location;
import dmd.mtype;
import dmd.semantic3 : checkClosure;
import dmd.typesem;
import dmd.target;
import dmd.tocvdebug;
import dmd.tocsym;

/****************************************
 * Our label symbol
 */

struct Label
{
    block* lblock;      // The block to which the label is defined.
}

/***********************************************************
 * Collect state variables needed by the intermediate representation (IR)
 */
struct IRState
{
    Module m;                       // module
    private FuncDeclaration symbol; // function that code is being generate for
    Symbol* shidden;                // hidden parameter to function
    Symbol* sthis;                  // 'this' parameter to function (member and nested)
    Symbol* sclosure;               // pointer to closure instance
    BlockState* blx;
    Dsymbols* deferToObj;           // array of Dsymbol's to run toObjFile(bool multiobj) on later
    elem* ehidden;                  // transmit hidden pointer to CallExp::toElem()
    Symbol* startaddress;
    Array!(elem*)* varsInScope;     // variables that are in scope that will need destruction later
    Label*[void*]* labels;          // table of labels used/declared in function
    const Param* params;            // command line parameters
    const Target* target;           // target
    ErrorSink eSink;                // sink for error messages
    bool mayThrow;                  // the expression being evaluated may throw
    bool Cfile;                     // use C semantics

    this(Module m, FuncDeclaration fd, Array!(elem*)* varsInScope, Dsymbols* deferToObj, Label*[void*]* labels,
        const Param* params, const Target* target, ErrorSink eSink)
    {
        this.m = m;
        this.symbol = fd;
        this.varsInScope = varsInScope;
        this.deferToObj = deferToObj;
        this.labels = labels;
        this.params = params;
        this.target = target;
        this.eSink = eSink;
        mayThrow = params.useExceptions
            && ClassDeclaration.throwable
            && !(fd && fd.hasNoEH);
        this.Cfile = m.filetype == FileType.c;
    }

    FuncDeclaration getFunc() @safe
    {
        return symbol;
    }

    /**********************
     * Returns:
     *    true if do array bounds checking for the current function
     */
    bool arrayBoundsCheck()
    {
        if (m.filetype == FileType.c)
            return false;
        final switch (params.useArrayBounds)
        {
        case CHECKENABLE.off:
            return false;
        case CHECKENABLE.on:
            return true;
        case CHECKENABLE.safeonly:
            {
                if (FuncDeclaration fd = getFunc())
                {
                    Type t = fd.type;
                    if (t.ty == Tfunction && (cast(TypeFunction)t).trust == TRUST.safe)
                        return true;
                }
                return false;
            }
        case CHECKENABLE._default:
            assert(0);
        }
    }

    /****************************
     * Returns:
     *  true if in a nothrow section of code
     */
    bool isNothrow() @safe
    {
        return !mayThrow;
    }
}

/*********************************************
 * Produce elem which increments the usage count for a particular line.
 * Sets corresponding bit in bitmap `m.covb[linnum]`.
 * Used to implement -cov switch (coverage analysis).
 * Params:
 *      irs = context
 *      loc = line and file of what line to show usage for
 * Returns:
 *      elem that increments the line count
 * References:
 * https://dlang.org/dmd-windows.html#switch-cov
 */
extern (D) elem* incUsageElem(ref IRState irs, Loc loc)
{
    uint linnum = loc.linnum;

    Module m = cast(Module)irs.blx._module;
    //printf("m.cov %p linnum %d filename %s srcfile %s numlines %d\n", m.cov, linnum, loc.filename, m.srcfile.toChars(), m.numlines);
    if (!m.cov || !linnum ||
        strcmp(loc.filename, m.srcfile.toChars()))
        return null;

    //printf("cov = %p, covb = %p, linnum = %u\n", m.cov, m.covb.ptr, p, linnum);

    linnum--;           // from 1-based to 0-based

    /* Set bit in covb[] indicating this is a valid code line number
     */
    if (m.covb.length)    // covb can be null if it has already been written out to its .obj file
    {
        assert(linnum < m.numlines);
        size_t i = linnum / (m.covb[0].sizeof * 8);
        m.covb[i] |= 1 << (linnum & (m.covb[0].sizeof * 8 - 1));
    }

    /* Generate: *(m.cov + linnum * 4) += 1
     */
    elem* e;
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
 * 'fdp' is the parent of 'fd' if the frame pointer is being used to call 'fd'.
 * 'origSc' is the original scope we inlined from.
 * This routine is critical for implementing nested functions.
 */
elem* getEthis(Loc loc, ref IRState irs, Dsymbol fd, Dsymbol fdp = null, Dsymbol origSc = null)
{
    elem* ethis;
    FuncDeclaration thisfd = irs.getFunc();
    Dsymbol ctxt0 = fdp ? fdp : fd;                     // follow either of these two
    Dsymbol ctxt1 = origSc ? origSc.toParent2() : null; // contexts from template arguments
    if (!fdp) fdp = fd.toParent2();
    Dsymbol fdparent = fdp;

    /* These two are compiler generated functions for the in and out contracts,
     * and are called from an overriding function, not just the one they're
     * nested inside, so this hack sets fdparent so it'll pass
     */
    if (fdparent != thisfd && (fd.ident == Id.require || fd.ident == Id.ensure))
    {
        FuncDeclaration fdthis = thisfd;
        for (size_t i = 0; ; )
        {
            if (i == fdthis.foverrides.length)
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
                 * See also: SymbolExp.toElem() in e2ir.c (https://issues.dlang.org/show_bug.cgi?id=9383 fix)
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
                    /* https://issues.dlang.org/show_bug.cgi?id=7517: If fdp is declared in interface, offset the
                     * 'this' pointer to get correct interface type reference.
                     */
                    Symbol* stmp = symbol_genauto(TYnptr);
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

                thisfd.csym.Sfunc.Fflags &= ~Finline; // inliner breaks with this because the offsets are off
                                                      // see runnable/ice10086b.d
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
            irs.eSink.error(loc, "`%s` is a nested function and cannot be accessed from `%s`", fd.toChars(), irs.getFunc().toPrettyChars());
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
            //printf("\ts = '%s'\n", s.toChars());
            thisfd = s.isFuncDeclaration();

            if (thisfd)
            {
                /* Enclosing function is a function.
                 */
                // Error should have been caught by front end
                assert(thisfd.isNested() || thisfd.vthis);

                // pick one context
                ethis = fixEthis2(ethis, thisfd, thisfd.followInstantiationContext(ctxt0, ctxt1));
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
                    irs.eSink.error(loc, "cannot get frame pointer to `%s`", fd.toPrettyChars());
                    return el_long(TYnptr, 0);      // error recovery
                }
                ClassDeclaration cd = ad.isClassDeclaration();
                ClassDeclaration cdx = fd.isClassDeclaration();
                if (cd && cdx && cdx.isBaseOf(cd, null))
                    break;
                StructDeclaration sd = ad.isStructDeclaration();
                if (fd == sd)
                    break;
                if (!ad.isNested() || !(ad.vthis || ad.vthis2))
                    goto Lnoframe;

                bool i = ad.followInstantiationContext(ctxt0, ctxt1);
                const voffset = i ? ad.vthis2.offset : ad.vthis.offset;
                ethis = el_bin(OPadd, TYnptr, ethis, el_long(TYsize_t, voffset));
                ethis = el_una(OPind, TYnptr, ethis);
            }
            if (fdparent == s.toParentP(ctxt0, ctxt1))
                break;

            /* Remember that frames for functions that have no
             * nested references are skipped in the linked list
             * of frames.
             */
            FuncDeclaration fdp2 = s.toParentP(ctxt0, ctxt1).isFuncDeclaration();
            if (fdp2 && fdp2.hasNestedFrameRefs())
                ethis = el_una(OPind, TYnptr, ethis);

            s = s.toParentP(ctxt0, ctxt1);
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

/************************
 * Select one context pointer from a dual-context array
 * Returns:
 *      *(ethis + offset);
 */
elem* fixEthis2(elem* ethis, FuncDeclaration fd, bool ctxt2 = false)
{
    if (fd && fd.hasDualContext())
    {
        if (ctxt2)
            ethis = el_bin(OPadd, TYnptr, ethis, el_long(TYsize_t, tysize(TYnptr)));
        ethis = el_una(OPind, TYnptr, ethis);
    }
    return ethis;
}

/*************************
 * Initialize the hidden aggregate member, vthis, with
 * the context pointer.
 * Returns:
 *      *(ey + (ethis2 ? ad.vthis2 : ad.vthis).offset) = this;
 */
elem* setEthis(Loc loc, ref IRState irs, elem* ey, AggregateDeclaration ad, bool setthis2 = false)
{
    elem* ethis;
    FuncDeclaration thisfd = irs.getFunc();
    int offset = 0;
    Dsymbol adp = setthis2 ? ad.toParent2(): ad.toParentLocal();     // class/func we're nested in

    //printf("[%s] setEthis(ad = %s, adp = %s, thisfd = %s)\n", loc.toChars(), ad.toChars(), adp.toChars(), thisfd.toChars());

    if (adp == thisfd)
    {
        ethis = getEthis(loc, irs, ad);
    }
    else if (thisfd.vthis && !thisfd.hasDualContext() &&
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

    assert(!setthis2 || ad.vthis2);
    const voffset = setthis2 ? ad.vthis2.offset : ad.vthis.offset;
    ey = el_bin(OPadd, TYnptr, ey, el_long(TYsize_t, voffset));
    ey = el_una(OPind, TYnptr, ey);
    ey = el_bin(OPeq, TYnptr, ey, ethis);
    return ey;
}

enum NotIntrinsic = -1;
enum OPtoPrec = OPMAX + 1; // front end only

/*******************************************
 * Convert intrinsic function to operator.
 * Returns:
 *      the operator as backend OPER,
 *      NotIntrinsic if not an intrinsic function,
 *      OPtoPrec if frontend-only intrinsic
 */
int intrinsic_op(FuncDeclaration fd)
{
    int op = NotIntrinsic;
    fd = fd.toAliasFunc();
    if (fd.isDeprecated())
        return op;
    //printf("intrinsic_op(%s)\n", name);

    const Identifier id3 = fd.ident;

    // Look for [core|std].module.function as id3.id2.id1 ...
    auto m = fd.getModule();
    if (!m || !m.md)
        return op;

    const md = m.md;
    const Identifier id2 = md.id;

    if (md.packages.length == 0)
        return op;

    // get type of first argument
    auto tf = fd.type ? fd.type.isTypeFunction() : null;
    auto param1 = tf && tf.parameterList.length > 0 ? tf.parameterList[0] : null;
    auto argtype1 = param1 ? param1.type : null;

    const Identifier id1 = md.packages[0];
    // ... except std.math package and core.stdc.stdarg.va_start.
    if (md.packages.length == 2)
    {
        // Matches any module in std.math.*
        if (md.packages[1] == Id.math && id1 == Id.std)
        {
            goto Lstdmath;
        }
        goto Lva_start;
    }

    if (id1 == Id.std && id2 == Id.math)
    {
    Lstdmath:
        if (argtype1 is Type.tfloat80 || id3 == Id._sqrt)
            goto Lmath;
        if (id3 == Id.fabs &&
            (argtype1 is Type.tfloat32 || argtype1 is Type.tfloat64))
        {
            op = OPabs;
        }
    }
    else if (id1 == Id.core)
    {
        if (id2 == Id.math)
        {
        Lmath:
            if (argtype1 is Type.tfloat80 || argtype1 is Type.tfloat32 || argtype1 is Type.tfloat64)
            {
                     if (id3 == Id.cos)    op = OPcos;
                else if (id3 == Id.sin)    op = OPsin;
                else if (id3 == Id.fabs)   op = OPabs;
                else if (id3 == Id.rint)   op = OPrint;
                else if (id3 == Id._sqrt)  op = OPsqrt;
                else if (id3 == Id.yl2x)   op = OPyl2x;
                else if (id3 == Id.ldexp)  op = OPscale;
                else if (id3 == Id.rndtol) op = OPrndtol;
                else if (id3 == Id.yl2xp1) op = OPyl2xp1;
                else if (id3 == Id.toPrec) op = OPtoPrec;
            }
        }
        else if (id2 == Id.simd)
        {
                 if (id3 == Id.__prefetch) op = OPprefetch;
            else if (id3 == Id.__simd_sto) op = OPvector;
            else if (id3 == Id.__simd)     op = OPvector;
            else if (id3 == Id.__simd_ib)  op = OPvector;
        }
        else if (id2 == Id.bitop)
        {
                 if (id3 == Id.volatileLoad)  op = OPind;
            else if (id3 == Id.volatileStore) op = OPeq;

            else if (id3 == Id.bsf) op = OPbsf;
            else if (id3 == Id.bsr) op = OPbsr;
            else if (id3 == Id.btc) op = OPbtc;
            else if (id3 == Id.btr) op = OPbtr;
            else if (id3 == Id.bts) op = OPbts;

            else if (id3 == Id.inp)  op = OPinp;
            else if (id3 == Id.inpl) op = OPinp;
            else if (id3 == Id.inpw) op = OPinp;

            else if (id3 == Id.outp)  op = OPoutp;
            else if (id3 == Id.outpl) op = OPoutp;
            else if (id3 == Id.outpw) op = OPoutp;

            else if (id3 == Id.bswap)   op = OPbswap;
            else if (id3 == Id._popcnt) op = OPpopcnt;
        }
        else if (id2 == Id.volatile)
        {
                 if (id3 == Id.volatileLoad)  op = OPind;
            else if (id3 == Id.volatileStore) op = OPeq;
        }
    }

    if (target.isX86)
    // No 64-bit bsf bsr in 32bit mode
    {
        if ((op == OPbsf || op == OPbsr) && argtype1 is Type.tuns64)
            return NotIntrinsic;
    }
    return op;

Lva_start:
    if (target.isX86_64 &&
        fd.toParent().isTemplateInstance() &&
        id3 == Id.va_start &&
        id2 == Id.stdarg &&
        md.packages[1] == Id.stdc &&
        id1 == Id.core)
    {
        return OPva_start;
    }
    return op;
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
elem* resolveLengthVar(VarDeclaration lengthVar, elem **pe, Type t1)
{
    //printf("resolveLengthVar()\n");
    elem* einit = null;

    if (lengthVar && !(lengthVar.storage_class & STC.const_))
    {
        elem* elength;
        Symbol* slength;

        if (t1.ty == Tsarray)
        {
            TypeSArray tsa = cast(TypeSArray)t1;
            const length = tsa.dim.toInteger();

            elength = el_long(TYsize_t, length);
            goto L3;
        }
        else if (t1.ty == Tarray)
        {
            elength = *pe;
            *pe = el_same(elength);
            elength = el_una(target.isX86_64 ? OP128_64 : OP64_32, TYsize_t, elength);

        L3:
            slength = toSymbol(lengthVar);
            if (slength.Sclass == SC.auto_ && slength.Ssymnum == SYMIDX.max)
                symbol_add(slength);

            einit = el_bin(OPeq, TYsize_t, el_var(slength), elength);
        }
    }
    return einit;
}

/*************************************
 * for a nested function 'fd' return the type of the closure
 * of an outer function or aggregate. If the function is a member function
 * the 'this' type is expected to be stored in 'sthis.Sthis'.
 * It is always returned if it is not a void pointer.
 * buildClosure() must have been called on the outer function before.
 *
 * Params:
 *      sthis = the symbol of the current 'this' derived from fd.vthis
 *      fd = the nested function
 */
TYPE* getParentClosureType(Symbol* sthis, FuncDeclaration fd)
{
    if (sthis)
    {
        // only replace void*
        if (sthis.Stype.Tty != TYnptr || sthis.Stype.Tnext.Tty != TYvoid)
            return sthis.Stype;
    }
    for (Dsymbol sym = fd.toParent2(); sym; sym = sym.toParent2())
    {
        if (auto fn = sym.isFuncDeclaration())
            if (fn.csym && fn.csym.Sscope)
                return fn.csym.Sscope.Stype;
        if (sym.isAggregateDeclaration())
            break;
    }
    return sthis ? sthis.Stype : Type_toCtype(Type.tvoidptr);
}

/**************************************
 * Go through the variables in function fd that are
 * to be allocated in a closure, and set the .offset fields
 * for those variables to their positions relative to the start
 * of the closure instance.
 * Also turns off nrvo for closure variables.
 * Params:
 *      fd = function
 * Returns:
 *      overall alignment of the closure
 */
uint setClosureVarOffset(FuncDeclaration fd)
{
    // Nothing to do
    if (!fd.needsClosure())
        return 0;

    uint offset = target.ptrsize;      // leave room for previous sthis
    uint aggAlignment = offset;        // overall alignment for the closure

    foreach (v; fd.closureVars)
    {
        /* Align and allocate space for v in the closure
         * just like AggregateDeclaration.addField() does.
         */
        uint memsize;
        uint memalignsize;
        structalign_t xalign;
        if (v.storage_class & STC.lazy_)
        {
            /* Lazy variables are really delegates,
             * so give same answers that TypeDelegate would
             */
            memsize = target.ptrsize * 2;
            memalignsize = memsize;
            xalign.setDefault();
        }
        else if (v.storage_class & (STC.out_ | STC.ref_))
        {
            // reference parameters are just pointers
            memsize = target.ptrsize;
            memalignsize = memsize;
            xalign.setDefault();
        }
        else
        {
            memsize = cast(uint)v.type.size();
            memalignsize = v.type.alignsize();
            xalign = v.alignment;
        }
        offset = alignmember(xalign, memalignsize, offset);
        v.offset = offset;
        //printf("closure var %s, offset = %d\n", v.toChars(), v.offset);

        offset += memsize;

        uint actualAlignment = xalign.isDefault() ? memalignsize : xalign.get();
        if (aggAlignment < actualAlignment)
            aggAlignment = actualAlignment;     // take the largest

        /* Can't do nrvo if the variable is put in a closure, since
         * what the shidden points to may no longer exist.
         */
        assert(!fd.isNRVO() || fd.nrvo_var != v);
    }
    return aggAlignment;
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
void buildClosure(FuncDeclaration fd, ref IRState irs)
{
    //printf("buildClosure(fd = %s)\n", fd.toChars());
    const oldValue = fd.requiresClosure;
    if (fd.needsClosure())
    {
        /* nrvo is incompatible with closure
         */
        if (oldValue != fd.requiresClosure && (fd.nrvo_var || !irs.params.useGC))
        {
            /* https://issues.dlang.org/show_bug.cgi?id=23112
             * This can shift due to templates being expanded that access alias symbols.
             */
            fd.checkClosure();   // give decent diagnostic
        }

        auto aggAlignment = setClosureVarOffset(fd);

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
        const char* name1 = "CLOSURE.";
        const char* name2 = fd.toPrettyChars();
        size_t namesize = strlen(name1)+strlen(name2)+1;
        char* closname = cast(char *)Mem.check(calloc(namesize, char.sizeof));
        strcat(strcat(closname, name1), name2);

        /* Build type for closure */
        type* Closstru = type_struct_class(closname, target.ptrsize, 0, null, null, false, false, true, false);
        free(closname);
        auto chaintype = getParentClosureType(irs.sthis, fd);
        symbol_struct_addField(*Closstru.Ttag, "__chain", chaintype, 0);

        Symbol* sclosure;
        sclosure = symbol_name("__closptr", SC.auto_, type_pointer(Closstru));
        sclosure.Sflags |= SFLtrue | SFLfree;
        symbol_add(sclosure);
        irs.sclosure = sclosure;

        assert(fd.closureVars.length);
        assert(fd.closureVars[0].offset >= target.ptrsize);
        foreach (v; fd.closureVars)
        {
            //printf("closure var %s\n", v.toChars());
            v.inClosure = true;

            // Hack for the case fail_compilation/fail10666.d,
            // until proper https://issues.dlang.org/show_bug.cgi?id=5730 fix will come.
            bool isScopeDtorParam = v.edtor && (v.storage_class & STC.parameter);
            if (v.needsScopeDtor() || isScopeDtorParam)
            {
                /* Because the value needs to survive the end of the scope!
                 */
                irs.eSink.error(v.loc, "variable `%s` has scoped destruction, cannot build closure", v.toPrettyChars());
            }
            if (v.isargptr)
            {
                /* See https://issues.dlang.org/show_bug.cgi?id=2479
                 * This is actually a bug, but better to produce a nice
                 * message at compile time rather than memory corruption at runtime
                 */
                irs.eSink.error(v.loc, "variable `%s` cannot reference variadic arguments from closure", v.toPrettyChars());
            }

            /* Set Sscope to closure */
            Symbol* vsym = toSymbol(v);
            assert(vsym.Sscope == null);
            vsym.Sscope = sclosure;

            /* Add variable as closure type member */
            symbol_struct_addField(*Closstru.Ttag, &vsym.Sident[0], vsym.Stype, v.offset);
            //printf("closure field %s: memalignsize: %i, offset: %i\n", &vsym.Sident[0], memalignsize, v.offset);
        }

        // Calculate the size of the closure
        VarDeclaration  vlast = fd.closureVars[fd.closureVars.length - 1];
        typeof(size(vlast.type)) lastsize;
        if (vlast.storage_class & STC.lazy_)
            lastsize = target.ptrsize * 2;
        else if (vlast.isReference)
            lastsize = target.ptrsize;
        else
            lastsize = vlast.type.size();
        bool overflow;
        auto structsize = addu(vlast.offset, lastsize, overflow);
        assert(!overflow && structsize <= uint.max);
        //printf("structsize = %d\n", cast(uint)structsize);

        Closstru.Ttag.Sstruct.Sstructsize = cast(uint)structsize;
        fd.csym.Sscope = sclosure;

        if (driverParams.symdebug)
            toDebugClosure(Closstru.Ttag);

        // Add extra size so we can align it
        enum GC_ALIGN = 16;     // gc aligns on 16 bytes
        if (aggAlignment > GC_ALIGN)
            structsize += aggAlignment - GC_ALIGN;

        // Allocate memory for the closure
        elem* e = el_long(TYsize_t, structsize);
        e = el_bin(OPcall, TYnptr, el_var(getRtlsym(RTLSYM.ALLOCMEMORY)), e);
        toTraceGC(irs, e, fd.loc);

        // Align it
        if (aggAlignment > GC_ALIGN)
        {
            // e + (aggAlignment - 1) & ~(aggAlignment - 1)
            e = el_bin(OPadd, TYsize_t, e, el_long(TYsize_t, aggAlignment - 1));
            e = el_bin(OPand, TYsize_t, e, el_long(TYsize_t, ~(aggAlignment - 1L)));
        }

        // Assign block of memory to sclosure
        //    sclosure = allocmemory(sz);
        e = el_bin(OPeq, TYvoid, el_var(sclosure), e);

        // Set the first element to sthis
        //    *(sclosure + 0) = sthis;
        elem* ethis;
        if (irs.sthis)
            ethis = el_var(irs.sthis);
        else
            ethis = el_long(TYnptr, 0);
        elem* ex = el_una(OPind, TYnptr, el_var(sclosure));
        ex = el_bin(OPeq, TYnptr, ex, ethis);
        e = el_combine(e, ex);

        // Copy function parameters into closure
        foreach (v; fd.closureVars)
        {
            if (!v.isParameter())
                continue;
            tym_t tym = totym(v.type);
            const x64ref = ISX64REF(v);
            if (x64ref && config.exe == EX_WIN64)
            {
                if (v.storage_class & STC.lazy_)
                    tym = TYdelegate;
            }
            else if (v.isReference())
                tym = TYnptr;   // reference parameters are just pointers
            else if (v.storage_class & STC.lazy_)
                tym = TYdelegate;
            ex = el_bin(OPadd, TYnptr, el_var(sclosure), el_long(TYsize_t, v.offset));
            ex = el_una(OPind, tym, ex);
            elem* ev = el_var(toSymbol(v));
            if (x64ref)
            {
                ev.Ety = TYnref;
                ev = el_una(OPind, tym, ev);
                if (tybasic(ev.Ety) == TYstruct || tybasic(ev.Ety) == TYarray)
                    ev.ET = Type_toCtype(v.type);
            }
            if (tybasic(ex.Ety) == TYstruct || tybasic(ex.Ety) == TYarray)
            {
                .type* t = Type_toCtype(v.type);
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

/**************************************
 * Go through the variables in function fd that are
 * to be allocated in an aligned section, and set the .offset fields
 * for those variables to their positions relative to the start
 * of the aligned section instance.
 * Params:
 *      fd = function
 * Returns:
 *      overall alignment of the align section
 * Reference:
 *      setClosureVarOffset
 */
private
uint setAlignSectionVarOffset(FuncDeclaration fd)
{
    // Nothing to do
    if (!fd.alignSectionVars)
        return 0;

    uint offset = 0;
    uint aggAlignment = offset;        // overall alignment for the closure

    // first go through and find overall alignment for the entire section
    foreach (v; (*fd.alignSectionVars)[])
    {
        if (v.inClosure)
            continue;

        /* Align and allocate space for v in the align closure
         * just like AggregateDeclaration.addField() does.
         */
        const memsize = cast(uint)v.type.size();
        const memalignsize = v.type.alignsize();
        const xalign = v.alignment;

        offset = alignmember(xalign, memalignsize, offset);
        v.offset = offset;
        //printf("align closure var %s, offset = %d\n", v.toChars(), offset);

        offset += memsize;

        uint actualAlignment = xalign.isDefault() ? memalignsize : xalign.get();
        //printf("actualAlignment = x%x, x%x\n", actualAlignment, xalign.get());
        if (aggAlignment < actualAlignment)
            aggAlignment = actualAlignment;     // take the largest
    }

    return aggAlignment;
}

/*************************************
 * Aligned sections are implemented by taking the local variables that
 * need alignment that is larger than the stack alignment.
 * They are allocated into a separate chunk of memory on the stack
 * called an align section, which is aligned on function entry.
 *
 * buildAlignSection() inserts code just after the function prolog
 * is complete. It allocates memory for the align closure by making
 * a local stack variable to contain that memory, allocates
 * a local variable (salignSection) to point to it.
 * In VarExp::toElem and SymOffExp::toElem, when referring to a
 * variable that is in an align closure, take the offset from salignSection rather
 * than from the frame pointer.
 * A variable cannot be in both a closure and an align section. They go in the closure
 * and then that closure is aligned.
 *
 * getEthis() and NewExp::toElem need to use sclosure, if set, rather
 * than the current frame pointer??
 *
 * Run after buildClosure, as buildClosure gets first dibs on inAlignSection variables
 * Params:
 *      fd = function in which all this occurs
 *      irs = state of the intermediate code generation
 * Reference:
 *      buildClosure() is very similar.
 *
 *      https://github.com/dlang/dmd/pull/9143 was an incomplete attempt to solve this problem
 *      that was merged. It should probably be removed.
 */
void buildAlignSection(FuncDeclaration fd, ref IRState irs)
{
    enum log = false;
    if (log) printf("buildAlignSection(fd = %s)\n", fd.toChars());
    if (!fd.alignSectionVars)
        return;
    auto alignSectionVars = (*fd.alignSectionVars)[];

    /* If they're all in a closure, don't need to build an align section
     */
    foreach (v; alignSectionVars)
    {
        if (!v.inClosure)
            goto L1;
    }
    return;
  L1:

    auto stackAlign = target.stackAlign();
    auto aggAlignment = setAlignSectionVarOffset(fd);

    /* Generate type name for align closure struct */
    const char* name1 = "ALIGNSECTION.";
    const char* name2 = fd.toPrettyChars();
    size_t namesize = strlen(name1)+strlen(name2)+1;
    char* closname = cast(char *)Mem.check(calloc(namesize, char.sizeof));
    strcat(strcat(closname, name1), name2);

    /* Build type for aligned section */
    type* Closstru = type_struct_class(closname, stackAlign, 0, null, null, false, false, true, false);
    free(closname);

    Symbol* sclosure;
    type* t = type_pointer(Closstru);
    type_setcv(&t, t.Tty | mTYvolatile);        // so optimizer doesn't delete it
    sclosure = symbol_name("__alignsecptr", SC.auto_, t);
    sclosure.Sflags |= SFLtrue | SFLfree;
    symbol_add(sclosure);
    fd.salignSection = sclosure;

    foreach (v; alignSectionVars)
    {
        if (v.inClosure)
            continue;

        if (log) printf("align section var %s\n", v.toChars());
        v.inAlignSection = true;

        Symbol* vsym = toSymbol(v);
        assert(vsym.Sscope == null);
        vsym.Sscope = sclosure;

        /* Add variable as align section type member */
        symbol_struct_addField(*Closstru.Ttag, &vsym.Sident[0], vsym.Stype, v.offset);
        if (log) printf("align section field %s: offset: %i\n", &vsym.Sident[0], v.offset);
    }

    // Calculate the size of the align section
    VarDeclaration  vlast = alignSectionVars[$ - 1];
    typeof(size(vlast.type)) lastsize;
    lastsize = vlast.type.size();
    bool overflow;
    auto structsize = addu(vlast.offset, lastsize, overflow);
    assert(!overflow && structsize <= uint.max);
    if (log) printf("structsize = %d\n", cast(uint)structsize);

    // Add extra size so we can align it
    if (log) printf("aggAlignment: x%x, stackAlign: x%x\n", aggAlignment, stackAlign);
    assert(aggAlignment > stackAlign);
    structsize += aggAlignment - stackAlign;

    Closstru.Ttag.Sstruct.Sstructsize = cast(uint)structsize;
    fd.csym.Sscope = sclosure;

    if (driverParams.symdebug)
        toDebugClosure(Closstru.Ttag);

    // Create Symbol that is an instance of the align closure
    Symbol* salignSectionInstance = symbol_name("__alignsec", SC.auto_, Closstru);
    salignSectionInstance.Sflags |= SFLtrue | SFLfree;
    symbol_add(salignSectionInstance);

    elem* e = el_ptr(salignSectionInstance);

    /* Align it
     * e + (aggAlignment - 1) & ~(aggAlignment - 1)
     */
    e = el_bin(OPadd, TYsize_t, e, el_long(TYsize_t, aggAlignment - 1));
    e = el_bin(OPand, TYsize_t, e, el_long(TYsize_t, ~(aggAlignment - 1L)));

    // Assign pointer to align section instance to sclosure
    //    salignSection = allocmemory(sz);
    e = el_bin(OPeq, TYvoid, el_var(sclosure), e);

    block_appendexp(irs.blx.curblock, e);
}

/*************************************
 * build a debug info struct for variables captured by nested functions,
 * but not in a closure.
 * must be called after generating the function to fill stack offsets
 * Params:
 *      fd = function
 */
void buildCapture(FuncDeclaration fd)
{
    if (!driverParams.symdebug)
        return;
    if (target.objectFormat() != Target.ObjectFormat.coff)  // toDebugClosure only implemented for CodeView,
        return;                 //  but optlink crashes for negative field offsets

    if (fd.closureVars.length && !fd.needsClosure)
    {
        /* Generate type name for struct with captured variables */
        const char* name1 = "CAPTURE.";
        const char* name2 = fd.toPrettyChars();
        size_t namesize = strlen(name1)+strlen(name2)+1;
        char* capturename = cast(char *)Mem.check(calloc(namesize, char.sizeof));
        strcat(strcat(capturename, name1), name2);

        /* Build type for struct */
        type* capturestru = type_struct_class(capturename, target.ptrsize, 0, null, null, false, false, true, false);
        free(capturename);

        foreach (v; fd.closureVars)
        {
            Symbol* vsym = toSymbol(v);

            /* Add variable as capture type member */
            auto soffset = vsym.Soffset;
            if (fd.vthis)
                soffset -= toSymbol(fd.vthis).Soffset; // see toElem.ToElemVisitor.visit(SymbolExp)
            symbol_struct_addField(*capturestru.Ttag, &vsym.Sident[0], vsym.Stype, cast(uint)soffset);
            //printf("capture field %s: offset: %i\n", &vsym.Sident[0], v.offset);
        }

        // generate pseudo symbol to put into functions' Sscope
        Symbol* scapture = symbol_name("__captureptr", SC.alias_, type_pointer(capturestru));
        scapture.Sflags |= SFLtrue | SFLfree;
        //symbol_add(scapture);
        fd.csym.Sscope = scapture;

        toDebugClosure(capturestru.Ttag);
    }
}


/***************************
 * Determine return style of function - whether in registers or
 * through a hidden pointer to the caller's stack.
 * Params:
 *   tf = function type to check
 *   needsThis = true if the function type is for a non-static member function
 * Returns:
 *   RET.stack if return value from function is on the stack, RET.regs otherwise
 */
RET retStyle(TypeFunction tf, bool needsThis)
{
    //printf("TypeFunction.retStyle() %s\n", toChars());
    return target.isReturnOnStack(tf, needsThis) ? RET.stack : RET.regs;
}
