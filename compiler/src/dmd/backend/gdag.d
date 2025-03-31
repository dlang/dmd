/**
 * Directed acyclic graphs and global optimizer common subexpressions
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1986-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/gdag.d, backend/gdag.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/gdag.d
 */

module dmd.backend.gdag;

import core.stdc.stdio;
import core.stdc.time;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.oper;
import dmd.backend.global;
import dmd.backend.goh;
import dmd.backend.el;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.dlist;
import dmd.backend.dvec;


nothrow:
@safe:

enum Aetype { cse, arraybounds }

private __gshared Aetype aetype;

@trusted
bool Eunambig(elem* e) { return OTassign(e.Eoper) && e.E1.Eoper == OPvar; }

/*************************************
 * Determine if floating point should be cse'd.
 * Returns:
 *      true if should be cse'd
 */

@trusted
private bool cse_float(elem* e)
{
    // Don't CSE floating stuff if generating
    // inline 8087 code, the code generator
    // can't handle it yet
    return !(tyfloating(e.Ety) && config.inline8087 &&
             e.Eoper != OPvar && e.Eoper != OPconst) ||
           (tyxmmreg(e.Ety) && config.fpxmmregs);
}

/************************************
 * Build DAGs (basically find all the common subexpressions).
 * Must be done after all other optimizations, because most
 * of them depend on the trees being trees, not DAGs.
 * The general strategy is:
 *      Compute available expressions (AEs)
 *      For each block
 *              stick together nodes that match, keeping AEs up to date
 *      For each block
 *              unstick unprofitable common subexpressions
 *              (this is generally target-dependent)
 */
@trusted
void builddags(ref GlobalOptimizer go)
{
    vec_t aevec;

    debug if (debugc) printf("builddags()\n");
    assert(bo.dfo);
    flowae(go);                       /* compute available expressions */
    if (go.exptop <= 1)             /* if no AEs                     */
        return;
    aetype = Aetype.cse;

    debug
        foreach (i, e; go.expnod[])
        {
            //printf("go.expnod[%d] = %p\n",i,e);
            if (e)
                elem_debug(e);
        }

    static if (0)
    {
        printf("defkill  "); vec_println(go.defkill,go.exptop);
        printf("starkill "); vec_println(go.starkill,go.exptop);
        printf("vptrkill "); vec_println(go.vptrkill,go.exptop);
    }

    static if (0)
    {
        /* This is the 'correct' algorithm for CSEs. We can't use it    */
        /* till we fix the code generator.                              */
        foreach (i, b; dfo[])
        {
            if (b.Belem)
            {
                static if (0)
                {
                    printf("dfo[%d] = %p\n",i,b);
                    printf("b.Bin   "); vec_println(b.Bin,go.exptop);
                    printf("b.Bout  "); vec_println(b.Bout,go.exptop);
                    aewalk(go, &(b.Belem),b.Bin);
                    printf("b.Bin   "); vec_println(b.Bin,go.exptop);
                    printf("b.Bout  "); vec_println(b.Bout,go.exptop);
                }
                else
                {
                    aewalk(go, &(b.Belem),b.Bin);
                }
                /* Bin and Bout would be equal at this point  */
                /* except that we deleted some elems from     */
                /* go.expnod[] and so it's a subset of Bout   */
                /* assert(veceq(b.Bin,b.Bout));               */
            }
        }
    }
    else
    {
        /* Do CSEs across extended basic blocks only. This is because   */
        /* the code generator can only track register contents          */
        /* properly across extended basic blocks.                       */
        aevec = vec_calloc(go.exptop);
        foreach (i, b; bo.dfo[])
        {
            /* if not first block and (there are more than one      */
            /* predecessor or the only predecessor is not the       */
            /* previous block), then zero out the available         */
            /* expressions.                                         */
            if ((i != 0 &&
                 (list_block(b.Bpred) != bo.dfo[i - 1] ||
                  list_next(b.Bpred) != null))
                || b.bc == BC.asm_
                || b.bc == BC._finally
                || b.bc == BC._lpad
                || b.bc == BC.catch_
                || b.bc == BC.jcatch
               )
                vec_clear(aevec);
            if (b.Belem)           /* if there is an expression    */
                aewalk(go, &(b.Belem),aevec);
        }
        vec_free(aevec);
    }

    // Need 2 passes to converge on solution
    foreach (j; 0 .. 2)
        foreach (b; bo.dfo[])
        {
            if (b.Belem)
            {
                //printf("b = 0x%x\n",b);
                removecses(&(b.Belem));
            }
        }
}


/****************************
 * Walk tree, rewriting* pn into a DAG as we go.
 * Params:
 *      go = GlobalOptimizer
 *      pn = pointer to expression tree to convert to DAG
 *      ae = vector of available expressions
 */
@trusted
private void aewalk(ref GlobalOptimizer go, elem** pn, vec_t ae)
{
    elem* n = *pn;
    assert(n && ae);
    //printf("visiting  %d: (",n.Eexp); WReqn(*pn); printf(")\n");
    //chkvecdim(go.exptop);
    const op = n.Eoper;
    if (n.Eexp)                            // if an AE
    {   // Try to find an equivalent AE, and point to it instead
        assert(go.expnod[n.Eexp] == n);
        if (aetype == Aetype.cse)
        {
            for (uint i = 0; (i = cast(uint) vec_index(i, ae)) < go.exptop; ++i)
            {   elem* e = go.expnod[i];

                // Attempt to replace n with e
                if (e == null)              // if elem no longer exists
                    vec_clearbit(i,ae);     // it's not available
                else if (n != e &&
                    el_match(n,e) &&
                    e.Ecount < 0xFF-1 &&   // must fit in unsigned char
                    cse_float(n)
                    )
                {
                    *pn = e;                // replace n with e
                    //printf("cse: %p (",n); WReqn(*pn); printf(")\n");
                    e.Ecount++;
                    debug assert(e.Ecount != 0);

                    void aeclear(elem* n)
                    {
                        while (1)
                        {
                            const i = n.Eexp;
                            assert(i);
                            if (n.Ecount)
                                break;

                            go.expnod[i] = null;
                            vec_clearbit(i,ae);
                            if (OTunary(n.Eoper))
                            {
                                n = n.E1;
                                continue;
                            }
                            else if (OTbinary(n.Eoper))
                            {
                                aeclear(n.E1);
                                n = n.E2;
                                continue;
                            }
                            break;
                        }
                    }

                    aeclear(n);
                    el_free(n);
                    return;
                }
            }
        }
    }

    elem* t;
    switch (op)
    {
        case OPcolon:
        case OPcolon2:
        {
            // ae = ae & ael & aer
            // AEs gened by ael and aer are mutually exclusive
            vec_t aer = vec_clone(ae);
            aewalk(go, &(n.E1),ae);
            aewalk(go, &(n.E2),aer);
            vec_andass(ae,aer);
            vec_free(aer);
            break;
        }

        case OPandand:
        case OPoror:
        {
            aewalk(go, &(n.E1),ae);
            /* ae &= aer    */
            vec_t aer = vec_clone(ae);
            aewalk(go, &(n.E2),aer);
            if (el_returns(n.E2))
                vec_andass(ae,aer);
            vec_free(aer);
            break;
        }

        case OPnegass:
            t = n.E1;
            if (t.Eoper == OPind)
                aewalk(go, &(t.E1),ae);
            break;

        case OPctor:
        case OPdtor:
        case OPdctor:
            break;

        case OPasm:
        case OPddtor:
            vec_clear(ae);          // kill everything
            return;

        default:
            if (OTbinary(op))
            {
                if (ERTOL(n))
                {
                    // Don't CSE constants that will turn into
                    // an INC or DEC anyway
                    if (n.E2.Eoper == OPconst &&
                        n.E2.Vint == 1 &&
                        (op == OPaddass || op == OPminass ||
                         op == OPpostinc || op == OPpostdec)
                       )
                    {   }
                    else
                        aewalk(go, &(n.E2),ae);
                }
                if (OTassign(op))
                {
                    t = n.E1;
                    if (t.Eoper == OPind)
                        aewalk(go, &(t.E1),ae);
                }
                else
                    aewalk(go, &(n.E1),ae);
                if (!ERTOL(n))
                    aewalk(go, &(n.E2),ae);
            }
            else if (OTunary(op))
            {
                assert(op != OPnegass);
                aewalk(go, &(n.E1),ae);
            }
    }

    if (OTdef(op))
    {
        assert(n.Eexp == 0);   // should not be an AE
        /* remove all AEs that could be affected by this def    */
        if (Eunambig(n))        // if unambiguous definition
        {
            assert(t.Eoper == OPvar);
            Symbol* s = t.Vsym;
            if (Symbol_isAffected(*s))
                vec_subass(ae,go.starkill);
            for (uint i = 0; (i = cast(uint) vec_index(i, ae)) < go.exptop; ++i) // for each ae elem
            {
                elem* e = go.expnod[i];

                if (!e) continue;
                if (OTunary(e.Eoper))
                {
                    if (vec_testbit(e.E1.Eexp,ae))
                        continue;
                }
                else if (OTbinary(e.Eoper))
                {
                    if (vec_testbit(e.E1.Eexp,ae) &&
                        vec_testbit(e.E2.Eexp,ae))
                        continue;
                }
                else if (e.Eoper == OPvar)
                {
                    if (e.Vsym != s)
                        continue;
                }
                else
                    continue;
                vec_clearbit(i,ae);
            }
        }
        else                    /* else ambiguous definition    */
        {
            vec_subass(ae,go.defkill);
            if (OTcalldef(op))
                vec_subass(ae,go.vptrkill);
        }

        // GEN the lvalue of an assignment operator
        if (OTassign(op) && !OTpost(op) && t.Eexp)
            vec_setbit(t.Eexp,ae);
    }
    if (n.Eexp)            // if an AE
    {
        if (op == OPvp_fp || op == OPcvp_fp)
            /* Invalidate all other OPvp_fps     */
            vec_subass(ae,go.vptrkill);

        /*printf("available: ("); WReqn(n); printf(")\n");
        elem_print(n);*/
        vec_setbit(n.Eexp,ae);     /* mark this elem as available  */
    }
}


/**************************
 * Remove a CSE.
 * Input:
 *      pe      pointer to pointer to CSE
 * Output:
 *      *pe     new elem to replace the old
 * Returns:
 *      *pe
 */
@trusted
private elem* delcse(elem** pe)
{
    elem* e;

    e = el_calloc();
    el_copy(e,*pe);

    debug if (debugc)
    {
        printf("deleting unprofitable CSE %p (", *pe);
        WReqn(e);
        printf(")\n");
    }

    assert(e.Ecount != 0);
    if (!OTleaf(e.Eoper))
    {
        if (e.E1.Ecount == 0xFF-1)
        {
            elem* ereplace;
            ereplace = el_calloc();
            el_copy(ereplace,e.E1);
            e.E1 = ereplace;
            ereplace.Ecount = 0;
        }
        else
        {
            e.E1.Ecount++;
            debug assert(e.E1.Ecount != 0);
        }
        if (OTbinary(e.Eoper))
        {
            if (e.E2.Ecount == 0xFF-1)
            {
                elem* ereplace;
                ereplace = el_calloc();
                el_copy(ereplace,e.E2);
                e.E2 = ereplace;
                ereplace.Ecount = 0;
            }
            else
            {
                e.E2.Ecount++;
                debug assert(e.E2.Ecount != 0);
            }
        }
    }
    --(*pe).Ecount;
    debug assert((*pe).Ecount != 0xFF);
    (*pe).Nflags |= NFLdelcse;     // not generating node
    e.Ecount = 0;
    *pe = e;
    return* pe;
}


/******************************
 * 'Unstick' CSEs that would be unprofitable to do. These are usually
 * things like addressing modes, and are usually target-dependent.
 */

@trusted
private void removecses(elem** pe)
{
L1:
    elem* e = *pe;
    //printf("  removecses(%p) ", e); WReqn(e); printf("\n");
    assert(e);
    elem_debug(e);
    if (e.Nflags & NFLdelcse && e.Ecount)
    {
        delcse(pe);
        goto L1;
    }
    const op = e.Eoper;
    if (OTunary(op))
    {
        if (op == OPind)
        {
            bool scaledIndex = I32 || I64;      // if scaled index addressing mode support
            elem* e1 = e.E1;
            if (e1.Eoper == OPadd &&
                e1.Ecount
               )
            {
                if (scaledIndex)
                {
                    e1 = delcse(&e.E1);
                    if (e1.E1.Ecount) // == 1)
                        delcse(&e1.E1);
                    if (e1.E2.Ecount && e1.E2.Eoper != OPind)
                        delcse(&e1.E2);
                }
                /* *(v +. c)
                 * *(*pc +. c)
                 * The + and the const shouldn't be CSEs.
                 */
                else if (e1.E2.Eoper == OPconst &&
                    (e1.E1.Eoper == OPvar || (e1.E1.Eoper == OPind && e1.E1.Ety & (mTYconst | mTYimmutable)))
                   )
                {
                    e1 = delcse(&e.E1);
                }
            }

            /* *(((e <<. 3) + e) + e)
             */
            if (scaledIndex && e1.Eoper == OPadd &&
                e1.E1.Eoper == OPadd &&
                e1.E1.E1.Ecount &&
                e1.E1.E1.Eoper == OPshl &&
                e1.E1.E1.E2.Eoper == OPconst &&
                e1.E1.E1.E2.Vuns <= 3
               )
            {
                delcse(&e1.E1.E1);        // the <<. operator
            }

            /* *(((e << 3) +. e) + e)
            */
            if (scaledIndex && e1.Eoper == OPadd &&
                e1.E1.Eoper == OPadd &&
                e1.E1.Ecount &&
                e1.E1.E1.Eoper == OPshl &&
                e1.E1.E1.E2.Eoper == OPconst &&
                e1.E1.E1.E2.Vuns <= 3
               )
            {
                delcse(&e1.E1);              // the +. operator
            }

            /* *((e <<. 3) + e)
             */
            else if (scaledIndex && e1.Eoper == OPadd &&
                e1.E1.Ecount &&
                e1.E1.Eoper == OPshl &&
                e1.E1.E2.Eoper == OPconst &&
                e1.E1.E2.Vuns <= 3
               )
            {
                delcse(&e1.E1);              // the <<. operator
            }

            // Remove* e1 where it's a double
            if (e.Ecount && tyfloating(e.Ety))
                e = delcse(pe);
        }
        // This CSE is too easy to regenerate
        else if (op == OPu16_32 && I16 && e.Ecount)
            e = delcse(pe);

        else if (op == OPd_ld && e.E1.Ecount > 0)
            delcse(&e.E1);

        // OPremquo is only worthwhile if its result is used more than once
        else if (e.E1.Eoper == OPremquo &&
                 (op == OP64_32 || op == OP128_64 || op == OPmsw) &&
                 e.E1.Ecount == 0)
        {   // Convert back to OPdiv or OPmod
            elem* e1 = e.E1;
            e.Eoper = (op == OPmsw) ? OPmod : OPdiv;
            e.E1 = e1.E1;
            e.E2 = e1.E2;
            e1.E1 = null;
            e1.E2 = null;
            el_free(e1);

            removecses(&(e.E1));
            pe = &(e.E2);
            goto L1;
        }
    }
    else if (OTbinary(op))
    {
        if (e.Ecount > 0 && OTrel(op) && e.Ecount < 4
            /* Don't CSE floating stuff if generating   */
            /* inline 8087 code, the code generator     */
            /* can't handle it yet                      */
            && !(tyfloating(e.E1.Ety) && config.inline8087)
           )
                e = delcse(pe);
        if (ERTOL(e))
        {
            removecses(&(e.E2));
            pe = &(e.E1);
        }
        else
        {
            removecses(&(e.E1));
            pe = &(e.E2);
        }
        goto L1;
    }
    else /* leaf node */
    {
        return;
    }
    pe = &(e.E1);
    goto L1;
}

/*****************************************
 * Do optimizations based on if we know an expression is
 * 0 or !=0, even though we don't know anything else.
 */

@trusted
void boolopt(ref GlobalOptimizer go)
{
    vec_t aevec;
    vec_t aevecval;

    debug if (debugc) printf("boolopt()\n");
    if (!bo.dfo.length)
        compdfo(bo.dfo, bo.startblock);
    flowae(go);                       /* compute available expressions */
    if (go.exptop <= 1)             /* if no AEs                     */
        return;
    static if (0)
    {
        foreach (i; 0 .. go.exptop)
                printf("go.expnod[%d] = 0x%x\n",cast(int)i,go.expnod[i]);
        printf("defkill  "); vec_println(go.defkill,go.exptop);
        printf("starkill "); vec_println(go.starkill,go.exptop);
        printf("vptrkill "); vec_println(go.vptrkill,go.exptop);
    }

    /* Do CSEs across extended basic blocks only. This is because   */
    /* the code generator can only track register contents          */
    /* properly across extended basic blocks.                       */
    aevec = vec_calloc(go.exptop);
    aevecval = vec_calloc(go.exptop);

    // Mark each expression that we know starts off with a non-zero value
    foreach (const i; 0 .. go.exptop)
    {
        elem* e = go.expnod[i];
        if (e)
        {
            elem_debug(e);
            if (e.Eoper == OPvar && e.Vsym.Sflags & SFLtrue)
            {
                vec_setbit(i,aevec);
                vec_setbit(i,aevecval);
            }
        }
    }

    foreach (i, b; bo.dfo[])
    {
        /* if not first block and (there are more than one      */
        /* predecessor or the only predecessor is not the       */
        /* previous block), then zero out the available         */
        /* expressions.                                         */
        if ((i != 0 &&
             (list_block(b.Bpred) != bo.dfo[i - 1] ||
              list_next(b.Bpred) != null))
            || b.bc == BC.asm_
            || b.bc == BC._finally
            || b.bc == BC._lpad
            || b.bc == BC.catch_
            || b.bc == BC.jcatch
           )
            vec_clear(aevec);
        if (b.Belem)           /* if there is an expression    */
            abewalk(go, b.Belem, aevec, aevecval);
    }
    vec_free(aevec);
    vec_free(aevecval);
}

/****************************
 * Walk tree, replacing bool expressions that we know
 *      ae = vector of available boolean expressions
 *      aeval = parallel vector of values corresponding to whether bool
 *               value is 1 or 0
 *      n = elem tree to look at
 */

@trusted
private void abewalk(ref GlobalOptimizer go, elem* n, vec_t ae, vec_t aeval)
{
    elem* t;

    assert(n && ae);
    elem_debug(n);
    /*printf("visiting: ("); WReqn(*pn); printf("), Eexp = %d\n",n.Eexp);*/
    /*chkvecdim(go.exptop);*/
    const op = n.Eoper;
    switch (op)
    {
        case OPcond:
        {
            assert(n.E2.Eoper == OPcolon || n.E2.Eoper == OPcolon2);
            abewalk(go, n.E1, ae, aeval);
            abeboolres(go, n.E1, ae, aeval);
            vec_t aer = vec_clone(ae);
            vec_t aerval = vec_clone(aeval);
            if (!el_returns(n.E2.E1))
            {
                abeset(go, n.E1, aer, aerval, true);
                abewalk(go, n.E2.E1, aer, aerval);
                abeset(go, n.E1,ae, aeval, false);
                abewalk(go, n.E2.E2, ae, aeval);
            }
            else if (!el_returns(n.E2.E2))
            {
                abeset(go, n.E1,ae, aeval, true);
                abewalk(go, n.E2.E1, ae,aeval);
                abeset(go, n.E1,aer, aerval, false);
                abewalk(go, n.E2.E2, aer, aerval);
            }
            else
            {
                /* ae = ae & ael & aer
                 * AEs gened by ael and aer are mutually exclusive
                 */
                abeset(go, n.E1, aer, aerval, true);
                abewalk(go, n.E2.E1, aer, aerval);
                abeset(go, n.E1, ae, aeval, false);
                abewalk(go, n.E2.E2, ae, aeval);

                vec_xorass(aerval,aeval);
                vec_subass(aer,aerval);
                vec_andass(ae,aer);
            }
            vec_free(aer);
            vec_free(aerval);
            break;
        }

        case OPcolon:
        case OPcolon2:
            assert(0);

        case OPandand:
        case OPoror:
        {
            //printf("test1 %p: ", n); WReqn(n); printf("\n");
            abewalk(go, n.E1, ae, aeval);
            abeboolres(go, n.E1, ae, aeval);
            vec_t aer = vec_clone(ae);
            vec_t aerval = vec_clone(aeval);
            if (!el_returns(n.E2))
            {
                abeset(go, n.E1, aer, aerval, (op == OPandand));
                abewalk(go, n.E2, aer, aerval);
                abeset(go, n.E1, ae, aeval, (op != OPandand));
            }
            else
            {
                /* ae &= aer
                 */
                abeset(go, n.E1, aer, aerval, (op == OPandand));
                abewalk(go, n.E2, aer, aerval);

                vec_xorass(aerval,aeval);
                vec_subass(aer,aerval);
                vec_andass(ae,aer);
            }

            vec_free(aer);
            vec_free(aerval);
            break;
        }

        case OPbool:
        case OPnot:
            abewalk(go, n.E1, ae, aeval);
            abeboolres(go, n.E1, ae, aeval);
            break;

        case OPeqeq:
        case OPne:
        case OPlt:
        case OPle:
        case OPgt:
        case OPge:
        case OPunord:   case OPlg:      case OPleg:     case OPule:
        case OPul:      case OPuge:     case OPug:      case OPue:
        case OPngt:     case OPnge:     case OPnlt:     case OPnle:
        case OPord:     case OPnlg:     case OPnleg:    case OPnule:
        case OPnul:     case OPnuge:    case OPnug:     case OPnue:
            abewalk(go, n.E1, ae, aeval);
            abewalk(go, n.E2, ae, aeval);
            abeboolres(go, n, ae, aeval);
            break;

        case OPnegass:
            t = n.E1;
            if (t.Eoper == OPind)
                abewalk(go, t.E1, ae, aeval);
            break;

        case OPasm:
            vec_clear(ae);      // kill everything
            return;

        default:
            if (OTbinary(op))
            {   if (ERTOL(n))
                    abewalk(go, n.E2, ae, aeval);
                if (OTassign(op))
                {   t = n.E1;
                    if (t.Eoper == OPind)
                        abewalk(go, t.E1, ae, aeval);
                }
                else
                        abewalk(go, n.E1, ae, aeval);
                if (!ERTOL(n))
                    abewalk(go, n.E2,ae, aeval);
            }
            else if (OTunary(op))
                abewalk(go, n.E1, ae, aeval);
            break;
    }

    if (OTdef(op))
    {
        assert(n.Eexp == 0);           // should not be an AE
        /* remove all AEs that could be affected by this def    */
        if (Eunambig(n))        /* if unambiguous definition    */
        {
            Symbol* s;

            assert(t.Eoper == OPvar);
            s = t.Vsym;
            if (Symbol_isAffected(*s))
                vec_subass(ae,go.starkill);
            for (uint i = 0; (i = cast(uint) vec_index(i, ae)) < go.exptop; ++i) // for each ae elem
            {
                elem* e = go.expnod[i];

                if (!e) continue;
                if (el_appears(e,s))
                    vec_clearbit(i,ae);
            }
        }
        else                    /* else ambiguous definition    */
        {
            vec_subass(ae,go.defkill);
            if (OTcalldef(op))
                vec_subass(ae,go.vptrkill);
        }
        /* GEN the lvalue of an assignment operator     */
        uint i1, i2;
        if (op == OPeq && (i1 = t.Eexp) != 0 && (i2 = n.E2.Eexp) != 0)
        {
            if (vec_testbit(i2,ae))
            {
                vec_setbit(i1,ae);
                if (vec_testbit(i2,aeval))
                    vec_setbit(i1,aeval);
                else
                    vec_clearbit(i1,aeval);
            }
        }
    }
    else if (n.Eexp)           /* if an AE                     */
    {
        if (op == OPvp_fp || op == OPcvp_fp)
            /* Invalidate all other OPvp_fps */
            vec_subass(ae,go.vptrkill);

        /*printf("available: ("); WReqn(n); printf(")\n");
        elem_print(n);*/
//      vec_setbit(n.Eexp,ae); /* mark this elem as available  */
    }
}

/************************************
 * Elem e is to be evaluated for a boolean result.
 * See if we already know its value.
 */

@trusted
private void abeboolres(ref GlobalOptimizer go, elem* n,vec_t ae,vec_t aeval)
{
    //printf("abeboolres()[%d %p] ", n.Eexp, go.expnod[n.Eexp]); WReqn(n); printf("\n");
    elem_debug(n);
    if (n.Eexp && go.expnod[n.Eexp])
    {   /* Try to find an equivalent AE, and point to it instead */
        assert(go.expnod[n.Eexp] == n);
        uint i;
        for (i = 0; (i = cast(uint) vec_index(i, ae)) < go.exptop; ++i) // for each ae elem
        {   elem* e = go.expnod[i];

            // Attempt to replace n with the boolean result of e
            //printf("Looking at go.expnod[%d] = %p\n",i,e);
            assert(e);
            elem_debug(e);
            if (n != e && el_match(n,e))
            {
                debug if (debugc)
                {   printf("Elem %p: ",n);
                    WReqn(n);
                    printf(" is replaced by %d\n",vec_testbit(i,aeval) != 0);
                }

                abefree(go, n, ae);
                n.Vlong = vec_testbit(i,aeval) != 0;
                n.Eoper = OPconst;
                n.Ety = TYint;
                go.changes++;
                break;
            }
        }
    }
}

/****************************
 * Remove e from available expressions, and its children.
 */

@trusted
private void abefree(ref GlobalOptimizer go, elem* e,vec_t ae)
{
    //printf("abefree [%d %p]: ", e.Eexp, e); WReqn(e); printf("\n");
    assert(e.Eexp);
    vec_clearbit(e.Eexp,ae);
    go.expnod[e.Eexp] = null;
    if (!OTleaf(e.Eoper))
    {
        if (OTbinary(e.Eoper))
        {
            abefree(go, e.E2,ae);
            el_free(e.E2);
            e.E2 = null;
        }
        abefree(go, e.E1,ae);
        el_free(e.E1);
        e.E1 = null;
    }
}

/************************************
 * Elem e is to be evaluated for a boolean result.
 * Set its result according to flag.
 */

@trusted
private void abeset(ref GlobalOptimizer go, elem* e, vec_t ae, vec_t aeval, int flag)
{
    while (1)
    {
        uint i = e.Eexp;
        if (i && go.expnod[i])
        {
            //printf("abeset for go.expnod[%d] = %p: ",i,e); WReqn(e); printf("\n");
            vec_setbit(i,ae);
            if (flag)
                vec_setbit(i,aeval);
            else
                vec_clearbit(i,aeval);
        }
        switch (e.Eoper)
        {   case OPnot:
                flag ^= 1;
                e = e.E1;
                continue;

            case OPbool:
            case OPeq:
                e = e.E1;
                continue;

            default:
                break;
        }
        break;
    }
}
