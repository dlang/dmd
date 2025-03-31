/**
 * Function inliner.
 *
 * This is meant to replace the previous inliner, which inlined the front end AST.
 * This inlines based on the intermediate code, after it is optimized,
 * which is simpler and presumably can inline more functions.
 * It does not yet have full functionality,
 * - it does not inline expressions with string literals in them, as these get turned into
 *   local symbols which cannot be referenced from another object file
 * - exception handling code for Win32 is not inlined
 * - it does not give warnings for failed attempts at inlining pragma(inline, true) functions
 * - it can only inline functions that have already been compiled
 * - it cannot inline statements
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2022-2025 by The D Language Foundation, All Rights Reserved
 *              Some parts based on an inliner from the Digital Mars C compiler.
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/inliner.d, backend/inliner.d)
 */

// C++ specific routines

module dmd.backend.inliner;

import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.string;
import core.stdc.stdlib;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.oper;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.barray;
import dmd.backend.dlist;

nothrow:
@safe:

private enum log = false;
private enum log2 = false;

/**********************************
 * Determine if function can be inline'd.
 * Used to decide to save a function's intermediate code for later inlining.
 * Params:
 *      sfunc = function to check
 * Returns:
 *      true if sfunc can be inline'd.
 */

@trusted
bool canInlineFunction(Symbol* sfunc)
{
    auto f = sfunc.Sfunc;

    bool no(int line)
    {
        f.Fflags &= ~Finline;   // don't check it again
        if (log) debug printf("returns: no %d\n", line);
        return false;
    }

    if (log) debug printf("canInlineFunction(%s)\n", sfunc.Sident.ptr);

    if (config.flags & CFGnoinlines ||
        !(f.Fflags & Finline))
    {
        if (log) debug printf("returns: no %d\n", __LINE__);
        return false;
    }

    auto t = sfunc.Stype;
    assert(f && tyfunc(t.Tty));

    if (/* Cannot inline varargs or unprototyped functions      */
        (t.Tflags & (TFfixed | TFprototype)) != (TFfixed | TFprototype) ||
        (t.Tty & mTYimport)           // do not inline imported functions
       )
        return no(__LINE__);

    if (config.ehmethod == EHmethod.EH_WIN32 && !(f.Fflags3 & Feh_none))
        return no(__LINE__);       // not working properly, so don't inline it

    foreach (s; f.Flocsym[])
    {
        assert(s);
        if (s.Sclass == SC.bprel)
            return no(__LINE__);
    }

    auto b = f.Fstartblock;
    if (!b)
        return no(__LINE__);

    while (1)
    {
        switch (b.bc)
        {
            case BC.goto_:
                if (b.Bnext != b.nthSucc(0))
                    return no(__LINE__);
                b = b.Bnext;
                continue;

            case BC.ret:
                if (tybasic(t.Tnext.Tty) != TYvoid
                    && !(f.Fflags & (Fctor | Fdtor | Finvariant))
                   )
                {   // Message about no return value
                    // should already have been generated
                    return no(__LINE__);
                }
                if (!b.Belem)
                    return no(__LINE__);
                break;

            case BC.retexp:
                break;

            default:
                return no(__LINE__);
        }
        break;
    }

    /* Do slowest check last */
    for (b = f.Fstartblock; b; b = b.Bnext)
    {
        if (!canInlineExpression(b.Belem))
            return no(__LINE__);
    }

    if (log) debug printf("returns: yes %d\n", __LINE__);
    return true;
}

/**************************
 * Examine all of the function calls in sfunc, and inline-expand
 * any that can be.
 * Params:
 *      sfunc = function to scan
 */

@trusted
void scanForInlines(Symbol* sfunc)
{
    if (log) debug printf("scanForInlines(%s)\n",prettyident(sfunc));
    //symbol_debug(sfunc);
    func_t* f = sfunc.Sfunc;
    assert(f && tyfunc(sfunc.Stype.Tty));
    // BUG: flag not set right in dmd
    if (1 || f.Fflags3 & Fdoinline)  // if any inline functions called
    {
        f.Fflags |= Finlinenest;
        foreach (b; BlockRange(bo.startblock))
            if (b.Belem)
            {
                //elem_print(b.Belem);
                b.Belem = scanExpressionForInlines(b.Belem);
            }
        if (eecontext.EEelem)
        {
            const marksi = globsym.length;
            eecontext.EEelem = scanExpressionForInlines(eecontext.EEelem);
            eecontext_convs(marksi);
        }
        f.Fflags &= ~Finlinenest;
    }
}

/************************************************* private *********************************/

private:

/****************************************
 * Can this expression be inlined?
 * Params:
 *      e = expression
 * Returns:
 *      true if it can be inlined
 */
@trusted
bool canInlineExpression(elem* e)
{
    if (!e)
        return true;
    while (1)
    {
        if (OTleaf(e.Eoper))
        {
            if (e.Eoper == OPvar || e.Eoper == OPrelconst)
            {
                /* Statics cannot be accessed from a different object file,
                 * so the reference will fail.
                 */
                if (e.Vsym.Sclass == SC.locstat || e.Vsym.Sclass == SC.static_)
                {
                    if (log) printf("not inlining due to %s\n", e.Vsym.Sident.ptr);
                    return false;
                }
            }
            else if (e.Eoper == OPasm)
                return false;
            return true;
        }
        else if (OTunary(e.Eoper))
        {
            e = e.E1;
            continue;
        }
        else
        {
            if (!canInlineExpression(e.E1))
                return false;
            e = e.E2;
            continue;
        }
    }
}


/*********************************************
 * Walk the elems, looking for function calls we can inline.
 * Params:
 *      e = expression tree to walk
 * Returns:
 *      replacement tree
 */
@trusted
elem* scanExpressionForInlines(elem* e)
{
    //printf("scanExpressionForInlines(%p)\n",e);
    const op = e.Eoper;
    if (OTbinary(op))
    {
        e.E1 = scanExpressionForInlines(e.E1);
        e.E2 = scanExpressionForInlines(e.E2);
        if (op == OPcall)
            e = tryInliningCall(e);
    }
    else if (OTunary(op))
    {
        assert(op != OPstrctor);  // never happens in MARS
        e.E1 = scanExpressionForInlines(e.E1);
        if (op == OPucall)
        {
            e = tryInliningCall(e);
        }
    }
    else /* leaf */
    {
    }
    return e;
}

/**********************************
 * Inline-expand a function call if it can be.
 * Params:
 *      e = OPcall or OPucall elem
 * Returns:
 *      replacement tree.
 */

@trusted
private elem* tryInliningCall(elem* e)
{
    //elem_debug(e);
    assert(e && (e.Eoper == OPcall || e.Eoper == OPucall));

    if (e.E1.Eoper != OPvar)
        return e;

    // This is an explicit function call (not through a pointer)
    Symbol* sfunc = e.E1.Vsym;
    if (log) printf("tryInliningCall: %s, class = %d\n", prettyident(sfunc),sfunc.Sclass);

    // sfunc may not be a function due to user's clever casting
    if (!tyfunc(sfunc.Stype.Tty))
        return e;

    /* If forward referencing an inline function, we'll have to
     * write out the function when it eventually is defined
     */
    if (!sfunc.Sfunc) // this can happen for rtlsym functions
    {
    }
    else if (sfunc.Sfunc.Fstartblock == null)
        {   } //nwc_mustwrite(sfunc);
    else
    {   func_t* f = sfunc.Sfunc;

        /* Check to see if we inline expand the function, or queue  */
        /* it to be output.                                         */
        if ((f.Fflags & (Finline | Finlinenest)) == Finline)
            e = inlineCall(e,sfunc);
        else
            {   } //queue_func(sfunc);
    }

    return e;
}

/**********************************
 * Inline expand a function call.
 * Params:
 *      e = the OPcall or OPucall that calls sfunc, this gets free'd
 *      sfunc = function being called that gets inlined
 * Returns:
 *      the expression replacing the function call
 */
@trusted
private elem* inlineCall(elem* e,Symbol* sfunc)
{
    if (debugc)
        printf("inline %s\n", prettyident(sfunc));
    if (log) printf("inlineCall(e = %p, func %p = '%s')\n", e, sfunc, prettyident(sfunc));
    if (log2) { printf("before:\n"); elem_print(e); }
    //symbol_debug(sfunc);
    assert(e.Eoper == OPcall || e.Eoper == OPucall);
    func_t* f = sfunc.Sfunc;

    // Declare all of sfunc's local symbols as symbols in globsym
    const sistart = globsym.length;                      // where func's local symbols start
    foreach (s; f.Flocsym[])
    {
        assert(s);
        //if (!s)
        //    continue;
        //symbol_debug(s);
        auto sc = s.Sclass;
        switch (sc)
        {
            case SC.parameter:
            case SC.fastpar:
            case SC.shadowreg:
                sc = SC.auto_;
                goto L1;
            case SC.regpar:
                sc = SC.register;
                goto L1;
            case SC.register:
            case SC.auto_:
            case SC.pseudo:
            L1:
            {
                //printf("  new symbol %s\n", s.Sident.ptr);
                Symbol* snew = symbol_copy(*s);
                snew.Sclass = sc;
                snew.Sfl = FL.auto_;
                snew.Sflags |= SFLfree;
                snew.Srange = null;
                s.Sflags |= SFLreplace;
                if (sc == SC.pseudo)
                {
                    snew.Sfl = FL.pseudo;
                    snew.Sreglsw = s.Sreglsw;
                }
                s.Ssymnum = symbol_add(snew);
                break;
            }
            case SC.global:
            case SC.static_:
                break;
            default:
                //fprintf(stderr, "Sclass = %d\n", sc);
                symbol_print(*s);
                assert(0);
        }
    }

    static if (0)
        foreach (i, s; globsym[])
        {
            if (i == sistart)
                printf("---\n");
            printf("[%d] %s %s\n", cast(int)i, s.Sident.ptr, tym_str(s.Stype.Tty));
        }

    /* Create duplicate of function elems
     */
    elem* ec;
    for (block* b = f.Fstartblock; b; b = b.Bnext)
    {
        ec = el_combine(ec, el_copytree(b.Belem));
    }

    /* Walk the copied tree, replacing references to the old
     * variables with references to the new
     */
    if (ec)
    {
        adjustExpression(ec);
        if (config.flags3 & CFG3eh &&
            (eecontext.EEin ||
             f.Fflags3 & Fmark ||      // if mark/release around function expansion
             f.Fflags & Fctor))
        {
            elem* em = el_calloc();
            em.Eoper = OPmark;
            //el_settype(em,tstypes[TYvoid]);
            ec = el_bin(OPinfo,ec.Ety,em,ec);
        }
    }

    /* Initialize the parameter variables with the argument list
     */
    if (e.Eoper == OPcall)
    {
        elem* eargs = initializeParamsWithArgs(e.E2, sistart, globsym.length);
        ec = el_combine(eargs,ec);
    }

    if (ec)
    {
        ec.Esrcpos = e.Esrcpos;         // save line information
        f.Fflags |= Finlinenest;        // prevent recursive inlining
        ec = scanExpressionForInlines(ec); // look for more cases
        f.Fflags &= ~Finlinenest;
    }
    else
        ec = el_long(TYint,0);
    el_free(e);                         // dump function call
    if (log2) { printf("after:\n"); elem_print(ec); }
    return ec;
}

/****************************
 * Evaluate the argument list, putting in initialization statements to the
 * local parameters. If there are more arguments than parameters,
 * evaluate the remaining arguments for side effects only.
 * Params:
 *      eargs = argument tree
 *      sistart = starting index in globsym[] of the inlined function's parameters
 * Returns:
 *      expression representing the argument list
 */
@trusted
private elem* initializeParamsWithArgs(elem* eargs, SYMIDX sistart, SYMIDX siend)
{
    /* Create args[] and fill it with the arguments
     */
    const nargs = el_nparams(eargs);
    assert(nargs < size_t.max / (2 * (elem*).sizeof));   // conservative overflow check
    elem*[] args = (cast(elem**)malloc(nargs * (elem*).sizeof))[0 .. nargs];
    elem** tmp = args.ptr;
    el_paramArray(&tmp, eargs);

    elem* ecopy;

    auto si = sistart;
    for (size_t n = args.length; n; --n)
    {
        elem* e = args[n - 1];

        if (e.Eoper == OPstrpar)
            e = e.E1;

        /* Look for and return next parameter Symbol
         */
        Symbol* nextSymbol(ref SYMIDX si)
        {
            while (1)
            {
                if (si == siend)
                    return null;

                Symbol* s = globsym[si];
                ++si;
                // SCregpar was turned into SCregister, SCparameter to SCauto
                if (s.Sclass == SC.register || s.Sclass == SC.auto_)
                    return s;
            }
        }

        Symbol* s = nextSymbol(si);
        if (!s)
        {
            ecopy = el_combine(el_copytree(e), ecopy); // for ... arguments
            continue;
        }

        //printf("Param[%d] %s %s\n", cast(int)cast(int)si, s.Sident.ptr, tym_str(s.Stype.Tty));
        //elem_print(e);
        if (e.Eoper == OPstrctor)
        {
            ecopy = el_combine(el_copytree(e.E1), ecopy);     // skip the OPstrctor
            e = ecopy;
            //while (e.Eoper == OPcomma)
            //    e = e.E2;
            debug
            {
                if (e.Eoper != OPcall && e.Eoper != OPcond)
                    elem_print(e);
            }
            assert(e.Eoper == OPcall || e.Eoper == OPcond || e.Eoper == OPinfo);
            //exp2_setstrthis(e,s,0,ecopy.ET);
            continue;
        }

        /* s is the parameter, e is the argument, s = e
         */
        const szs = type_size(s.Stype);
        const sze = getSize(e);

        if (szs * 2 == sze && szs == REGSIZE())     // s got SROA'd into 2 slices
        {
            if (log) printf("detected slice with %s\n", s.Sident.ptr);
            auto s2 = nextSymbol(si);
            if (!s2)
            {
                for (size_t m = args.length; m; --m)
                {
                    elem* ex = args[m - 1];
                    printf("arg[%d]\n", cast(int) m);
                    elem_print(ex);
                }

                printf("function: %s\n", funcsym_p.Sident.ptr);
                printf("szs: %d sze: %d\n", cast(int)szs, cast(int)sze);
                printf("detected slice with %s\n", s.Sident.ptr);
                symbol_print(*s); elem_print(e); assert(0);
            }
            assert(szs == type_size(s2.Stype));
            const ty = s.Stype.Tty;

            elem* ex;
            e = el_copytree(e);         // copy argument
            if (e.Eoper != OPvar)
            {
                elem* ec = exp2_copytotemp(e);
                e = ec.E2;
                ex = ec.E1;
                ec.E1 = null;
                ec.E2 = null;
                el_free(ec);
                e.Vsym.Sfl = FL.auto_;
            }
            assert(e.Eoper == OPvar);
            elem* e2 = el_copytree(e);
            e.Voffset += 0;
            e2.Voffset += szs;
            e.Ety = ty;
            e2.Ety = ty;
            elem* elo = el_bin(OPeq, ty, el_var(s), e);
            elem* ehi = el_bin(OPeq, ty, el_var(s2), e2);
            if (tybasic(ty) == TYstruct || tybasic(ty) == TYarray)
            {
                elo.Eoper = OPstreq;
                ehi.Eoper = OPstreq;
                elo.ET = s.Stype;
                ehi.ET = s.Stype;
            }
            ex = el_combine(ex, elo);
            ex = el_combine(ex, ehi);

            ecopy = el_combine(ex, ecopy);
            continue;
        }

        if (sze * 2 == szs && szs == 2 * REGSIZE() && n >= 2)
        {
            /* This happens when elparam() splits an OPpair into
             * two OPparams. Try to reverse this here
             */
            elem* e2 = args[--n - 1];
            assert(getSize(e2) == sze);
            e = el_bin(OPpair, s.Stype.Tty, e, e2);
        }

        // s = e;
        elem* evar = el_var(s);
        elem* ex = el_copytree(e);
        auto ty = tybasic(ex.Ety);
        if (szs == 3)
        {
            ty = TYstruct;
        }
        else if (szs < sze && sze == 4)
        {
            // e got promoted to int
            ex = el_una(OP32_16, TYshort, ex);
            ty = TYshort;
            if (szs == 1)
            {
                ex = el_una(OP16_8, TYschar, ex);
                ty = TYschar;
            }
        }
        evar.Ety = ty;
        auto eeq = el_bin(OPeq,ty,evar,ex);
        // If struct copy
        if (tybasic(eeq.Ety) == TYstruct || tybasic(eeq.Ety) == TYarray)
        {
            eeq.Eoper = OPstreq;
            eeq.ET = s.Stype;
        }
        //el_settype(evar,ecopy.ET);

        ecopy = el_combine(eeq, ecopy);
        continue;
    }
    free(args.ptr);
    return ecopy;
}

/*********************************
 * Replace references to old symbols with references to copied symbols.
 */
@trusted
private void adjustExpression(elem* e)
{
    while (1)
    {
        assert(e);
        //elem_debug(e);
        //dbg_printf("adjustExpression(%p) ",e);WROP(e.Eoper);dbg_printf("\n");
        // the debugger falls over on debugging inlines
        if (configv.addlinenumbers)
            e.Esrcpos.Slinnum = 0;             // suppress debug info for inlines
        if (!OTleaf(e.Eoper))
        {
            if (OTbinary(e.Eoper))
                adjustExpression(e.E2);
            else
                assert(!e.E2);
            e = e.E1;
        }
        else
        {
            if (e.Eoper == OPvar || e.Eoper == OPrelconst)
            {
                Symbol* s = e.Vsym;

                if (s.Sflags & SFLreplace)
                {
                    e.Vsym = globsym[s.Ssymnum];
                    //printf("  replacing %p %s\n", e, s.Sident.ptr);
                }
            }
            break;
        }
    }
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
