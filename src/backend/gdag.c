// Copyright (C) 1986-1998 by Symantec
// Copyright (C) 2000-2015 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */


#if (SCPP || MARS) && !HTOD

#include        <stdio.h>
#include        <time.h>

#include        "cc.h"
#include        "global.h"
#include        "el.h"
#include        "go.h"
#include        "ty.h"
#include        "oper.h"
#include        "vec.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

STATIC void aewalk(elem **pn , vec_t ae);
STATIC elem * delcse(elem **pe);
STATIC void removecses(elem **pe);
STATIC void boundscheck(elem *e, vec_t ae);

enum Aetype { AEcse, AEarraybounds };
static Aetype aetype;

/*************************************
 * Determine if floating point should be cse'd.
 */

inline int cse_float(elem *e)
{
#if TX86
    // Don't CSE floating stuff if generating
    // inline 8087 code, the code generator
    // can't handle it yet
    return !(tyfloating(e->Ety) && config.inline8087 &&
           e->Eoper != OPvar && e->Eoper != OPconst);
#else
    return 1;
#endif
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

void builddags()
{       unsigned i;
        vec_t aevec;

        cmes("builddags()\n");
        assert(dfo);
        flowae();                       /* compute available expressions */
        if (exptop <= 1)                /* if no AEs                    */
                return;
        aetype = AEcse;
#ifdef DEBUG
        for (i = 0; i < exptop; i++)
        {
            //dbg_printf("expnod[%d] = %p\n",i,expnod[i]);
            if (expnod[i])
                elem_debug(expnod[i]);
        }
#endif
#if 0
        dbg_printf("defkill  "); vec_println(defkill,exptop);
        dbg_printf("starkill "); vec_println(starkill,exptop);
        dbg_printf("vptrkill "); vec_println(vptrkill,exptop);
#endif

#if 0
        /* This is the 'correct' algorithm for CSEs. We can't use it    */
        /* till we fix the code generator.                              */
        for (i = 0; i < dfotop; i++)
        {       block *b;

                b = dfo[i];
                if (b->Belem)
                {
#if 0
                        dbg_printf("dfo[%d] = %p\n",i,b);
                        dbg_printf("b->Bin   "); vec_println(b->Bin,exptop);
                        dbg_printf("b->Bout  "); vec_println(b->Bout,exptop);
                        aewalk(&(b->Belem),b->Bin);
                        dbg_printf("b->Bin   "); vec_println(b->Bin,exptop);
                        dbg_printf("b->Bout  "); vec_println(b->Bout,exptop);
#else
                        aewalk(&(b->Belem),b->Bin);
#endif
                        /* Bin and Bout would be equal at this point    */
                        /* except that we deleted some elems from       */
                        /* expnod[] and so it's a subset of Bout        */
                        /* assert(veceq(b->Bin,b->Bout));               */
                }
        }
#else
        /* Do CSEs across extended basic blocks only. This is because   */
        /* the code generator can only track register contents          */
        /* properly across extended basic blocks.                       */
        aevec = vec_calloc(exptop);
        for (i = 0; i < dfotop; i++)
        {       block *b;

                b = dfo[i];
                /* if not first block and (there are more than one      */
                /* predecessor or the only predecessor is not the       */
                /* previous block), then zero out the available         */
                /* expressions.                                         */
                if ((i != 0 &&
                     (list_block(b->Bpred) != dfo[i - 1] ||
                      list_next(b->Bpred) != NULL))
                    || b->BC == BCasm
                    || b->BC == BC_finally
#if SCPP
                    || b->BC == BCcatch
#endif
#if MARS
                    || b->BC == BCjcatch
#endif
                   )
                        vec_clear(aevec);
                if (b->Belem)           /* if there is an expression    */
                        aewalk(&(b->Belem),aevec);

        }
        vec_free(aevec);
#endif
        // Need 2 passes to converge on solution
        for (int j = 0; j < 2; j++)
            for (i = 0; i < dfotop; i++)
            {   block *b;

                b = dfo[i];
                if (b->Belem)
                {
#if 0
                        dbg_printf("b = 0x%x\n",b);
#endif
                        removecses(&(b->Belem));
                }
            }
}

/**********************************
 */

STATIC void aeclear(elem *n,vec_t ae)
{   int i;

    i = n->Eexp;
    assert(i);
    if (n->Ecount == 0)
    {
        expnod[i] = 0;
        vec_clearbit(i,ae);
        if (EUNA(n))
            aeclear(n->E1,ae);
        else if (EBIN(n))
        {   aeclear(n->E1,ae);
            aeclear(n->E2,ae);
        }
    }
}

/****************************
 * Walk tree, building DAG as we go.
 *      ae = vector of available expressions
 */

STATIC void aewalk(elem **pn,vec_t ae)
{       vec_t aer;
        unsigned i,op;
        elem *n,*t;

        n = *pn;
        assert(n && ae);
        //printf("visiting  %d: (",n->Eexp); WReqn(*pn); dbg_printf(")\n");
        //chkvecdim(exptop);
        op = n->Eoper;
        if (n->Eexp)                            // if an AE
        {   // Try to find an equivalent AE, and point to it instead
            assert(expnod[n->Eexp] == n);
            if (aetype == AEcse)
            {
                foreach (i,exptop,ae)
                {   elem *e = expnod[i];

                    // Attempt to replace n with e
                    if (e == NULL)              // if elem no longer exists
                        vec_clearbit(i,ae);     // it's not available
                    else if (n != e &&
                        el_match(n,e) &&
                        e->Ecount < 0xFF-1 &&   // must fit in unsigned char
                        cse_float(n)
                        )
                    {
                        *pn = e;                // replace n with e
                        //dbg_printf("cse: %p (",n); WReqn(*pn); dbg_printf(")\n");
                        e->Ecount++;
#ifdef DEBUG
                        assert(e->Ecount != 0);
#endif
                        aeclear(n,ae);
                        el_free(n);
                        return;
                    }
                }
            }
        }
        switch (op)
        {   case OPcolon:
            case OPcolon2:
                // ae = ae & ael & aer
                // AEs gened by ael and aer are mutually exclusive
                aer = vec_clone(ae);
                aewalk(&(n->E1),ae);
                aewalk(&(n->E2),aer);
                vec_andass(ae,aer);
                vec_free(aer);
                break;
            case OPandand:
            case OPoror:
                aewalk(&(n->E1),ae);
                /* ae &= aer    */
                aer = vec_clone(ae);
                aewalk(&(n->E2),aer);
                if (!el_noreturn(n->E2))
                    vec_andass(ae,aer);
                vec_free(aer);
                break;
            case OPnegass:
                t = Elvalue(n);
                if (t->Eoper == OPind)
                    aewalk(&(t->E1),ae);
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
                {       if (ERTOL(n))
                        {
                            // Don't CSE constants that will turn into
                            // an INC or DEC anyway
                            if (n->E2->Eoper == OPconst &&
                                n->E2->EV.Vint == 1 &&
                                (op == OPaddass || op == OPminass ||
                                 op == OPpostinc || op == OPpostdec)
                               )
                                ;
                            else
                                aewalk(&(n->E2),ae);
                        }
                        if (OTassign(op))
                        {   t = Elvalue(n);
                            if (t->Eoper == OPind)
                                aewalk(&(t->E1),ae);
                        }
                        else
                            aewalk(&(n->E1),ae);
                        if (!ERTOL(n))
                            aewalk(&(n->E2),ae);
                }
                else if (OTunary(op))
                {   assert(op != OPnegass);
                    aewalk(&(n->E1),ae);
                }
        }

        if (OTdef(op))
        {
                assert(n->Eexp == 0);   // should not be an AE
                /* remove all AEs that could be affected by this def    */
                if (Eunambig(n))        // if unambiguous definition
                {       symbol *s;

                        assert(t->Eoper == OPvar);
                        s = t->EV.sp.Vsym;
                        if (!(s->Sflags & SFLunambig))
                                vec_subass(ae,starkill);
                        foreach (i,exptop,ae)   /* for each ae elem     */
                        {       elem *e = expnod[i];

                                if (!e) continue;
                                if (OTunary(e->Eoper))
                                {
                                        if (vec_testbit(e->E1->Eexp,ae))
                                                continue;
                                }
                                else if (OTbinary(e->Eoper))
                                {
                                        if (vec_testbit(e->E1->Eexp,ae) &&
                                            vec_testbit(e->E2->Eexp,ae))
                                                continue;
                                }
                                else if (e->Eoper == OPvar)
                                {       if (e->EV.sp.Vsym != s)
                                                continue;
                                }
                                else
                                        continue;
                                vec_clearbit(i,ae);
                        }
                }
                else                    /* else ambiguous definition    */
                {
                    vec_subass(ae,defkill);
                    if (OTcalldef(op))
                        vec_subass(ae,vptrkill);
                }

                // GEN the lvalue of an assignment operator
                if (OTassign(op) && !OTpost(op) && t->Eexp)
                    vec_setbit(t->Eexp,ae);
        }
        if (n->Eexp)            // if an AE
        {
#if TARGET_SEGMENTED
            if (op == OPvp_fp || op == OPcvp_fp)
                /* Invalidate all other OPvp_fps     */
                vec_subass(ae,vptrkill);
#endif

            /*dbg_printf("available: ("); WReqn(n); dbg_printf(")\n");
            elem_print(n);*/
            vec_setbit(n->Eexp,ae);     /* mark this elem as available  */
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

STATIC elem * delcse(elem **pe)
{       elem *e;

        e = el_calloc();
        el_copy(e,*pe);
#ifdef DEBUG
        if (debugc)
        {       dbg_printf("deleting unprofitable CSE %p (", *pe);
                WReqn(e);
                dbg_printf(")\n");
        }
#endif
        assert(e->Ecount != 0);
        if (EOP(e))
        {
                if (e->E1->Ecount == 0xFF-1)
                {       elem *ereplace;
                        ereplace = el_calloc();
                        el_copy(ereplace,e->E1);
                        e->E1 = ereplace;
                        ereplace->Ecount = 0;
                }
                else
                {
                    e->E1->Ecount++;
#ifdef DEBUG
                    assert(e->E1->Ecount != 0);
#endif
                }
                if (EBIN(e))
                {
                        if (e->E2->Ecount == 0xFF-1)
                        {       elem *ereplace;
                                ereplace = el_calloc();
                                el_copy(ereplace,e->E2);
                                e->E2 = ereplace;
                                ereplace->Ecount = 0;
                        }
                        else
                        {   e->E2->Ecount++;
#ifdef DEBUG
                            assert(e->E2->Ecount != 0);
#endif
                        }

                }
        }
        --(*pe)->Ecount;
#ifdef DEBUG
        assert((*pe)->Ecount != 0xFF);
#endif
        (*pe)->Nflags |= NFLdelcse;     // not generating node
        e->Ecount = 0;
#if FLOATS_IN_CODE
        if (FLT_CODESEG_CELEM(e))
            flt_record_const(e);
#endif
        *pe = e;
        return *pe;
}

/******************************
 * 'Unstick' CSEs that would be unprofitable to do. These are usually
 * things like addressing modes, and are usually target-dependent.
 */

STATIC void removecses(elem **pe)
{       unsigned op;
        elem *e;

L1:     e = *pe;
        //printf("  removecses(%p) ", e); WReqn(e); printf("\n");
        assert(e);
        elem_debug(e);
        if (e->Nflags & NFLdelcse && e->Ecount)
        {
            delcse(pe);
            goto L1;
        }
        op = e->Eoper;
        if (OTunary(op))
        {
            if (op == OPind)
            {
                elem *e1 = e->E1;
                if (e1->Eoper == OPadd &&
                    e1->Ecount // == 1
                   )
                {
                    if (I32)
                    {
                        e1 = delcse(&e->E1);
                        if (e1->E1->Ecount) // == 1)
                            delcse(&e1->E1);
                        if (e1->E2->Ecount && e1->E2->Eoper != OPind)
                            delcse(&e1->E2);
                    }
                    // Look for *(var + const). The + and the const
                    // shouldn't be CSEs.
                    else if (e1->E2->Eoper == OPconst &&
                        (e1->E1->Eoper == OPvar || (e1->E1->Eoper == OPind && e1->E1->Ety & (mTYconst | mTYimmutable)))
                       )
                    {
                        e1 = delcse(&e->E1);
                    }
                }

                if (I32 && e1->Eoper == OPadd &&
                    e1->E1->Eoper == OPadd &&
                    e1->E1->E1->Ecount &&
                    e1->E1->E1->Eoper == OPshl &&
                    e1->E1->E1->E2->Eoper == OPconst &&
                    e1->E1->E1->E2->EV.Vuns <= 3
                   )
                {
                    delcse(&e1->E1->E1);
                }

                if (I32 && e1->Eoper == OPadd &&
                    e1->E1->Eoper == OPadd &&
                    e1->E1->Ecount &&
                    e1->E1->E1->Eoper == OPshl &&
                    e1->E1->E1->E2->Eoper == OPconst &&
                    e1->E1->E1->E2->EV.Vuns <= 3
                   )
                {
                    delcse(&e1->E1);
                }

                else if (I32 && e1->Eoper == OPadd &&
                    e1->E1->Ecount &&
                    e1->E1->Eoper == OPshl &&
                    e1->E1->E2->Eoper == OPconst &&
                    e1->E1->E2->EV.Vuns <= 3
                   )
                {
                    delcse(&e1->E1);
                }

                // Remove *e1 where it's a double
                if (e->Ecount && tyfloating(e->Ety))
                    e = delcse(pe);
            }
            // This CSE is too easy to regenerate
            else if (op == OPu16_32 && !I32 && e->Ecount)
                e = delcse(pe);

            // OPremquo is only worthwhile if its result is used more than once
            else if (e->E1->Eoper == OPremquo &&
                     (op == OP64_32 || op == OP128_64 || op == OPmsw) &&
                     e->E1->Ecount == 0)
            {   // Convert back to OPdiv or OPmod
                elem *e1 = e->E1;
                e->Eoper = (op == OPmsw) ? OPmod : OPdiv;
                e->E1 = e1->E1;
                e->E2 = e1->E2;
                e1->E1 = NULL;
                e1->E2 = NULL;
                el_free(e1);

                removecses(&(e->E1));
                pe = &(e->E2);
                goto L1;
            }
        }
        else if (OTbinary(op))
        {
                if (e->Ecount > 0 && OTrel(op) && e->Ecount < 4
#if TX86
                    /* Don't CSE floating stuff if generating   */
                    /* inline 8087 code, the code generator     */
                    /* can't handle it yet                      */
                    && !(tyfloating(e->E1->Ety) && config.inline8087)
#endif
                   )
                        e = delcse(pe);
                if (ERTOL(e))
                {
                    removecses(&(e->E2));
                    pe = &(e->E1);
                }
                else
                {
                    removecses(&(e->E1));
                    pe = &(e->E2);
                }
                goto L1;
        }
        else /* leaf node */
        {
                return;
        }
        pe = &(e->E1);
        goto L1;
}

/*****************************************
 * Do optimizations based on if we know an expression is
 * 0 or !=0, even though we don't know anything else.
 */

STATIC void abewalk(elem *n,vec_t ae,vec_t aeval);
STATIC void abeboolres(elem *n,vec_t abe,vec_t abeval);
STATIC void abefree(elem *e,vec_t abe);
STATIC void abeset(elem *n,vec_t abe,vec_t abeval,int flag);

void boolopt()
{       unsigned i;
        vec_t aevec;
        vec_t aevecval;

        cmes("boolopt()\n");
        if (!dfo)
            compdfo();
        flowae();                       /* compute available expressions */
        if (exptop <= 1)                /* if no AEs                    */
                return;
#if 0
        for (i = 0; i < exptop; i++)
                dbg_printf("expnod[%d] = 0x%x\n",i,expnod[i]);
        dbg_printf("defkill  "); vec_println(defkill,exptop);
        dbg_printf("starkill "); vec_println(starkill,exptop);
        dbg_printf("vptrkill "); vec_println(vptrkill,exptop);
#endif

        /* Do CSEs across extended basic blocks only. This is because   */
        /* the code generator can only track register contents          */
        /* properly across extended basic blocks.                       */
        aevec = vec_calloc(exptop);
        aevecval = vec_calloc(exptop);

        // Mark each expression that we know starts off with a non-zero value
        for (i = 0; i < exptop; i++)
        {   elem *e = expnod[i];

            if (e)
            {   elem_debug(e);
                if (e->Eoper == OPvar && e->EV.sp.Vsym->Sflags & SFLtrue)
                {   vec_setbit(i,aevec);
                    vec_setbit(i,aevecval);
                }
            }
        }

        for (i = 0; i < dfotop; i++)
        {       block *b;

                b = dfo[i];
                /* if not first block and (there are more than one      */
                /* predecessor or the only predecessor is not the       */
                /* previous block), then zero out the available         */
                /* expressions.                                         */
                if ((i != 0 &&
                     (list_block(b->Bpred) != dfo[i - 1] ||
                      list_next(b->Bpred) != NULL))
                    || b->BC == BCasm
                    || b->BC == BC_finally
#if SCPP
                    || b->BC == BCcatch
#endif
#if MARS
                    || b->BC == BCjcatch
#endif
                   )
                        vec_clear(aevec);
                if (b->Belem)           /* if there is an expression    */
                        abewalk(b->Belem,aevec,aevecval);

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

STATIC void abewalk(elem *n,vec_t ae,vec_t aeval)
{
    unsigned i,op;
    unsigned i1,i2;
    elem *t;

    assert(n && ae);
    elem_debug(n);
    /*dbg_printf("visiting: ("); WReqn(*pn); dbg_printf("), Eexp = %d\n",n->Eexp);*/
    /*chkvecdim(exptop);*/
    op = n->Eoper;
    switch (op)
    {
        case OPcond:
        {
            assert(n->E2->Eoper == OPcolon || n->E2->Eoper == OPcolon2);
            abewalk(n->E1,ae,aeval);
            abeboolres(n->E1,ae,aeval);
            vec_t aer = vec_clone(ae);
            vec_t aerval = vec_clone(aeval);
            if (el_noreturn(n->E2->E1))
            {
                abeset(n->E1,aer,aerval,true);
                abewalk(n->E2->E1,aer,aerval);
                abeset(n->E1,ae,aeval,false);
                abewalk(n->E2->E2,ae,aeval);
            }
            else if (el_noreturn(n->E2->E2))
            {
                abeset(n->E1,ae,aeval,true);
                abewalk(n->E2->E1,ae,aeval);
                abeset(n->E1,aer,aerval,false);
                abewalk(n->E2->E2,aer,aerval);
            }
            else
            {
                /* ae = ae & ael & aer
                 * AEs gened by ael and aer are mutually exclusive
                 */
                abeset(n->E1,aer,aerval,true);
                abewalk(n->E2->E1,aer,aerval);
                abeset(n->E1,ae,aeval,false);
                abewalk(n->E2->E2,ae,aeval);

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
            abewalk(n->E1,ae,aeval);
            abeboolres(n->E1,ae,aeval);
            vec_t aer = vec_clone(ae);
            vec_t aerval = vec_clone(aeval);
            if (el_noreturn(n->E2))
            {
                abeset(n->E1,aer,aerval,(op == OPandand));
                abewalk(n->E2,aer,aerval);
                abeset(n->E1,ae,aeval,(op != OPandand));
            }
            else
            {
                /* ae &= aer
                 */
                abeset(n->E1,aer,aerval,(op == OPandand));
                abewalk(n->E2,aer,aerval);

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
            abewalk(n->E1,ae,aeval);
            abeboolres(n->E1,ae,aeval);
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
            abewalk(n->E1,ae,aeval);
            abewalk(n->E2,ae,aeval);
            abeboolres(n,ae,aeval);
            break;

        case OPnegass:
            t = Elvalue(n);
            if (t->Eoper == OPind)
                abewalk(t->E1,ae,aeval);
            break;

        case OPasm:
            vec_clear(ae);      // kill everything
            return;

        default:
            if (OTbinary(op))
            {   if (ERTOL(n))
                    abewalk(n->E2,ae,aeval);
                if (OTassign(op))
                {   t = Elvalue(n);
                    if (t->Eoper == OPind)
                        abewalk(t->E1,ae,aeval);
                }
                else
                        abewalk(n->E1,ae,aeval);
                if (!ERTOL(n))
                    abewalk(n->E2,ae,aeval);
            }
            else if (OTunary(op))
                abewalk(n->E1,ae,aeval);
            break;
    }

    if (OTdef(op))
    {   assert(n->Eexp == 0);           // should not be an AE
        /* remove all AEs that could be affected by this def    */
        if (Eunambig(n))        /* if unambiguous definition    */
        {       symbol *s;

                assert(t->Eoper == OPvar);
                s = t->EV.sp.Vsym;
                if (!(s->Sflags & SFLunambig))
                        vec_subass(ae,starkill);
                foreach (i,exptop,ae)   /* for each ae elem     */
                {       elem *e = expnod[i];

                        if (!e) continue;
                        if (el_appears(e,s))
                            vec_clearbit(i,ae);
                }
        }
        else                    /* else ambiguous definition    */
        {
            vec_subass(ae,defkill);
            if (OTcalldef(op))
                vec_subass(ae,vptrkill);
        }
        /* GEN the lvalue of an assignment operator     */
        if (op == OPeq && (i1 = t->Eexp) != 0 && (i2 = n->E2->Eexp) != 0)
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
    else if (n->Eexp)           /* if an AE                     */
    {
#if TARGET_SEGMENTED
        if (op == OPvp_fp || op == OPcvp_fp)
            /* Invalidate all other OPvp_fps */
            vec_subass(ae,vptrkill);
#endif

        /*dbg_printf("available: ("); WReqn(n); dbg_printf(")\n");
        elem_print(n);*/
//      vec_setbit(n->Eexp,ae); /* mark this elem as available  */
    }
}

/************************************
 * Elem e is to be evaluated for a boolean result.
 * See if we already know its value.
 */

STATIC void abeboolres(elem *n,vec_t ae,vec_t aeval)
{
    //printf("abeboolres()[%d %p] ", n->Eexp, expnod[n->Eexp]); WReqn(n); printf("\n");
    elem_debug(n);
    if (n->Eexp && expnod[n->Eexp])
    {   /* Try to find an equivalent AE, and point to it instead */
        assert(expnod[n->Eexp] == n);
        unsigned i;
        foreach (i,exptop,ae)
        {   elem *e = expnod[i];

            // Attempt to replace n with the boolean result of e
            //printf("Looking at expnod[%d] = %p\n",i,e);
            assert(e);
            elem_debug(e);
            if (n != e && el_match(n,e))
            {
#ifdef DEBUG
                if (debugc)
                {   dbg_printf("Elem %p: ",n);
                    WReqn(n);
                    dbg_printf(" is replaced by %d\n",vec_testbit(i,aeval) != 0);
                }
#endif
                abefree(n,ae);
                n->EV.Vlong = vec_testbit(i,aeval) != 0;
                n->Eoper = OPconst;
                n->Ety = TYint;
                changes++;
                break;
            }
        }
    }
}

/****************************
 * Remove e from available expressions, and its children.
 */

STATIC void abefree(elem *e,vec_t ae)
{
    //printf("abefree [%d %p]: ", e->Eexp, e); WReqn(e); dbg_printf("\n");
    assert(e->Eexp);
    vec_clearbit(e->Eexp,ae);
    expnod[e->Eexp] = NULL;
    if (EOP(e))
    {   if (EBIN(e))
        {   abefree(e->E2,ae);
            el_free(e->E2);
            e->E2 = NULL;
        }
        abefree(e->E1,ae);
        el_free(e->E1);
        e->E1 = NULL;
    }
}

/************************************
 * Elem e is to be evaluated for a boolean result.
 * Set its result according to flag.
 */

STATIC void abeset(elem *e,vec_t ae,vec_t aeval,int flag)
{
    while (1)
    {
        unsigned i = e->Eexp;
        if (i && expnod[i])
        {
            //printf("abeset for expnod[%d] = %p: ",i,e); WReqn(e); dbg_printf("\n");
            vec_setbit(i,ae);
            if (flag)
                vec_setbit(i,aeval);
            else
                vec_clearbit(i,aeval);
        }
        switch (e->Eoper)
        {   case OPnot:
                flag ^= 1;
            case OPbool:
            case OPeq:
                e = e->E1;
                continue;
        }
        break;
    }
}

#endif
