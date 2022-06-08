/**
 * Function inliner.
 *
 * This is meant to replace the previous inliner, which inlined the front end AST.
 * This inlines based on the intermediate code, after it is optimized,
 * which is simpler and presumably can inline more functions.
 * It does not yet have full functionality,
 * - it inlines one expression only, statements that can be turned into ||, && or ?:
 *   expressions are not done
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
 * Copyright:   Copyright (C) 2022 by The D Language Foundation, All Rights Reserved
 *              Some parts based on an inliner from the Digital Mars C compiler.
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/inliner.d, backend/inliner.d)
 */

// C++ specific routines

module dmd.backend.inliner;

version (MARS)
{

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

enum log = false;

/**********************************
 * Determine if function can be inline'd.
 * Params:
 *      sfunc = function to check
 * Returns:
 *      true if sfunc can be inline'd.
 */

bool canInlineFunction(Symbol *sfunc)
{
    if (log) printf("canInlineFunction(%s)\n",sfunc.Sident.ptr);
    auto f = sfunc.Sfunc;
    auto t = sfunc.Stype;
    assert(f && tyfunc(t.Tty));

    bool result = false;
    if (!(config.flags & CFGnoinlines) && /* if inlining is turned on   */
        f.Fflags & Finline &&
        /* Cannot inline varargs or unprototyped functions      */
        (t.Tflags & (TFfixed | TFprototype)) == (TFfixed | TFprototype) &&
        !(t.Tty & mTYimport)           // do not inline imported functions
       )
    {
        auto b = f.Fstartblock;
        if (!b)
            return false;
        if (config.ehmethod == EHmethod.EH_WIN32 && !(f.Fflags3 & Feh_none))
            return false;       // not working properly, so don't inline it
        switch (b.BC)
        {   case BCret:
                if (tybasic(t.Tnext.Tty) != TYvoid
                    && !(f.Fflags & (Fctor | Fdtor | Finvariant))
                   )
                {   // Message about no return value
                    // should already have been generated
                    break;
                }
                goto case BCretexp;

            case BCretexp:
                if (b.Belem)
                {
                    result = canInlineExpression(b.Belem);
                    if (log && !result) printf("not inlining function %s\n", sfunc.Sident.ptr);
                }
                break;

            default:
                break;
        }
    }
    if (!result)
        f.Fflags &= ~Finline;
    if (log) printf("returns: %d\n",result);
    return result;
}

/**************************
 * Examine all of the function calls in sfunc, and inline-expand
 * any that can be.
 * Params:
 *      sfunc = function to scan
 */

void scanForInlines(Symbol *sfunc)
{
    if (log) printf("scanForInlines(%s)\n",prettyident(sfunc));
    //symbol_debug(sfunc);
    func_t* f = sfunc.Sfunc;
    assert(f && tyfunc(sfunc.Stype.Tty));
    // BUG: flag not set right in dmd
    if (1 || f.Fflags3 & Fdoinline)  // if any inline functions called
    {
        f.Fflags |= Finlinenest;
        foreach (b; BlockRange(startblock))
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
bool canInlineExpression(elem* e)
{
    while (1)
    {
        if (OTleaf(e.Eoper))
        {
            if (e.Eoper == OPvar || e.Eoper == OPrelconst)
            {
                /* Statics cannot be accessed from a different object file,
                 * so the reference will fail.
                 */
                if (e.EV.Vsym.Sclass == SClocstat || e.EV.Vsym.Sclass == SCstatic)
                {
                    if (log) printf("not inlining due to %s\n", e.EV.Vsym.Sident.ptr);
                    return false;
                }
            }
            else if (e.Eoper == OPasm)
                return false;
            return true;
        }
        else if (OTunary(e.Eoper))
        {
            e = e.EV.E1;
            continue;
        }
        else
        {
            if (!canInlineExpression(e.EV.E1))
                return false;
            e = e.EV.E2;
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
elem* scanExpressionForInlines(elem *e)
{
    //printf("scanExpressionForInlines(%p)\n",e);
    const op = e.Eoper;
    if (OTbinary(op))
    {
        e.EV.E1 = scanExpressionForInlines(e.EV.E1);
        e.EV.E2 = scanExpressionForInlines(e.EV.E2);
        if (op == OPcall)
            e = tryInliningCall(e);
    }
    else if (OTunary(op))
    {
        if (op == OPstrctor) // never happens in MARS
        {
            elem* e1 = e.EV.E1;
            while (e1.Eoper == OPcomma)
            {
                e1.EV.E1 = scanExpressionForInlines(e1.EV.E1);
                e1 = e1.EV.E2;
            }
            if (e1.Eoper == OPcall && e1.EV.E1.Eoper == OPvar)
            {   // Never inline expand this function

                // But do expand templates
                Symbol* s = e1.EV.E1.EV.Vsym;
                if (tyfunc(s.ty()))
                {
                    // This function might be an inline template function that was
                    // never parsed. If so, parse it now.
                    if (s.Sfunc.Fbody)
                    {
                        //n2_instantiate_memfunc(s);
                    }
                }
            }
            else
                e1.EV.E1 = scanExpressionForInlines(e1.EV.E1);
            e1.EV.E2 = scanExpressionForInlines(e1.EV.E2);
        }
        else
        {
            e.EV.E1 = scanExpressionForInlines(e.EV.E1);
            if (op == OPucall)
            {
                e = tryInliningCall(e);
            }
        }
    }
    else /* leaf */
    {
        // If deferred allocation of variable, allocate it now.
        // The deferred allocations are done by cpp_initctor().
        if (0 && CPP &&
            (op == OPvar || op == OPrelconst))
        {
            Symbol* s = e.EV.Vsym;
            if (s.Sclass == SCauto &&
                s.Ssymnum == SYMIDX.max)
            {   //dbg_printf("Deferred allocation of %p\n",s);
                symbol_add(s);

                if (tybasic(s.Stype.Tty) == TYstruct &&
                    s.Stype.Ttag.Sstruct.Sdtor &&
                    !(s.Sflags & SFLnodtor))
                {
                    //enum DTORmostderived = 4;
                    //elem* eptr = el_ptr(s);
                    //elem* edtor = cpp_destructor(s.Stype,eptr,null,DTORmostderived);
                    //assert(edtor);
                    //edtor = scanExpressionForInlines(edtor);
                    //cpp_stidtors.push(edtor);
                }
            }
            if (tyfunc(s.ty()))
            {
                // This function might be an inline template function that was
                // never parsed. If so, parse it now.
                if (s.Sfunc.Fbody)
                {
                    //n2_instantiate_memfunc(s);
                }
            }
        }
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

private elem* tryInliningCall(elem *e)
{
    //elem_debug(e);
    assert(e && (e.Eoper == OPcall || e.Eoper == OPucall));

    if (e.EV.E1.Eoper != OPvar)
        return e;

    // This is an explicit function call (not through a pointer)
    Symbol* sfunc = e.EV.E1.EV.Vsym;
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
    {   func_t *f = sfunc.Sfunc;

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
 * Inline expand a function.
 * Params:
 *      e = the OPcall or OPucall that calls sfunc, this gets free'd
 *      sfunc = function being called that gets inlined
 * Returns:
 *      the expression replacing the function call
 */

private elem* inlineCall(elem *e,Symbol *sfunc)
{
    if (debugc)
        printf("inline %s\n", prettyident(sfunc));
    if (log) printf("inlineCall(e = %p, func %p = '%s')\n", e, sfunc, prettyident(sfunc));
    //printf("before:\n"); elem_print(e);
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
            case SCparameter:
            case SCfastpar:
            case SCshadowreg:
                sc = SCauto;
                goto L1;
            case SCregpar:
                sc = SCregister;
                goto L1;
            case SCregister:
            case SCauto:
            case SCpseudo:
            L1:
            {
                //printf("  new symbol %s\n", s.Sident.ptr);
                Symbol* snew = symbol_copy(s);
                snew.Sclass = sc;
                snew.Sfl = FLauto;
                snew.Sflags |= SFLfree;
                snew.Srange = null;
                s.Sflags |= SFLreplace;
                if (sc == SCpseudo)
                {
                    snew.Sfl = FLpseudo;
                    snew.Sreglsw = s.Sreglsw;
                }
                s.Ssymnum = symbol_add(snew);
                break;
            }
            case SCglobal:
            case SCstatic:
                break;
            default:
                //fprintf(stderr, "Sclass = %d\n", sc);
                symbol_print(s);
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
    assert(f.Fstartblock);
    elem* ec = el_copytree(f.Fstartblock.Belem);

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
        int n = 0;
        elem* eargs = initializeParamsWithArgs(e.EV.E2, n, sistart);
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
    //printf("after:\n"); elem_print(ec);
    return ec;
}

/****************************
 * Evaluate the argument list, putting in initialization statements to the
 * local parameters. If there are more arguments than parameters,
 * evaluate the remaining arguments for side effects only.
 * Params:
 *      pn = this is the nth argument (starts at 0), incremented once for each parameter
 *      sistart = starting index in globsym[] of the inlined function's parameters
 * Returns:
 *      expression representing the argument list
 */

private elem* initializeParamsWithArgs(elem *e, ref int pn, SYMIDX sistart)
{
    elem* ecopy;

    //elem_debug(e);
    if (e.Eoper == OPparam)
    {
        elem* e1 = initializeParamsWithArgs(e.EV.E2, pn, sistart);
        elem* e2 = initializeParamsWithArgs(e.EV.E1, pn, sistart);
        ecopy = el_combine(e1,e2);
    }
    else
    {
        if (e.Eoper == OPstrpar)
            e = e.EV.E1;

        auto n = pn;
        ++pn;
        // Find the nth parameter in the symbol table
        for (auto si = sistart; 1; si++)
        {
            if (si == globsym.length)              // for ... parameters
            {   ecopy = el_copytree(e);
                break;
            }
            Symbol* s = globsym[si];
            // SCregpar was turned into SCregister, SCparameter to SCauto
            if (s.Sclass == SCregister || s.Sclass == SCauto)
            {   if (n == 0)
                {
                    if (e.Eoper == OPstrctor)
                    {
                        ecopy = el_copytree(e.EV.E1);     // skip the OPstrctor
                        e = ecopy;
                        //while (e.Eoper == OPcomma)
                        //    e = e.EV.E2;
                        debug
                        {
                            if (e.Eoper != OPcall && e.Eoper != OPcond)
                                elem_print(e);
                        }
                        assert(e.Eoper == OPcall || e.Eoper == OPcond || e.Eoper == OPinfo);
                        //exp2_setstrthis(e,s,0,ecopy.ET);
                    }
                    else
                    {
                        /* s is the parameter, e is the argument, s = e
                         */
                        const szs = type_size(s.Stype);
                        const sze = getSize(e);

                        if (szs * 2 == sze && szs == REGSIZE())     // s got SROA'd into 2 slices
                        {
                            if (log) printf("detected slice with %s\n", s.Sident.ptr);
                            if (si + 1 >= globsym.length) { symbol_print(s); elem_print(e); }
                            assert(si + 1 < globsym.length);
                            auto s2 = globsym[si + 1];
                            assert(szs == type_size(s2.Stype));
                            --n;
                            ++pn;
                            const ty = s.Stype.Tty;

                            e = el_copytree(e);         // copy argument
                            if (e.Eoper != OPvar)
                            {
                                elem* ec = exp2_copytotemp(e);
                                e = ec.EV.E2;
                                ecopy = ec.EV.E1;
                                ec.EV.E1 = null;
                                ec.EV.E2 = null;
                                el_free(ec);
                                e.EV.Vsym.Sfl = FLauto;
                            }
                            assert(e.Eoper == OPvar);
                            elem* e2 = el_copytree(e);
                            e.EV.Voffset = 0;
                            e2.EV.Voffset = szs;
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
                            ecopy = el_combine(ecopy, elo);
                            ecopy = el_combine(ecopy, ehi);
                        }
                        else
                        {
                            // s = e;
                            elem* evar = el_var(s);
                            elem* ex = el_copytree(e);
                            auto ty = tybasic(ex.Ety);
                            if (szs < sze && sze == 4)
                            {
                                // e got promoted to int
                                ex = el_una(OP32_16, TYshort, ex);
                                ty = TYshort;
                                if (szs == 1)
                                {
                                    ex = el_una(OP16_8, TYchar, ex);
                                    ty = TYchar;
                                }
                            }
                            evar.Ety = ty;
                            ecopy = el_bin(OPeq,ty,evar,ex);
                            // If struct copy
                            if (tybasic(ecopy.Ety) == TYstruct || tybasic(ecopy.Ety) == TYarray)
                            {
                                ecopy.Eoper = OPstreq;
                                ecopy.ET = s.Stype;
                            }
                            //el_settype(evar,ecopy.ET);
                        }
                    }
                    break;
                }
                n--;
            }
        }
    }
    return ecopy;
}

/*********************************
 * Replace references to old symbols with references to copied symbols.
 */

private void adjustExpression(elem *e)
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
                adjustExpression(e.EV.E2);
            else
                assert(!e.EV.E2);
            e = e.EV.E1;
        }
        else
        {
            if (e.Eoper == OPvar || e.Eoper == OPrelconst)
            {
                Symbol *s = e.EV.Vsym;

                if (s.Sflags & SFLreplace)
                {
                    e.EV.Vsym = globsym[s.Ssymnum];
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

}
