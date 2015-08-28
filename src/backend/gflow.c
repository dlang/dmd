// Copyright (C) 1985-1998 by Symantec
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
#include        "type.h"
#include        "oper.h"
#include        "vec.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/* Since many routines are nearly identical, we can combine them with   */
/* this flag:                                                           */

#define AE      1
#define CP      2
#define VBE     3

static int flowxx;              /* one of the above values              */

static vec_t ambigsym = NULL;

STATIC void rdgenkill(void);
STATIC void numdefelems(elem *n);
STATIC void asgdefelems(block *b , elem *n);
STATIC void aecpgenkill(void);
STATIC int  numaeelems(elem *n);
STATIC void numcpelems(elem *n);
STATIC void asgexpelems(elem *n);
STATIC void defstarkill(void);
STATIC void rdelem(vec_t *pgen , vec_t *pkill , elem *n);
STATIC void aecpelem(vec_t *pgen , vec_t *pkill , elem *n);
STATIC void accumaecp(vec_t GEN , vec_t KILL , elem *n);
STATIC void accumaecpx(elem *n);
STATIC void lvgenkill(void);
STATIC void lvelem(vec_t *pgen , vec_t *pkill , elem *n);
STATIC void accumlv(vec_t GEN , vec_t KILL , elem *n);
STATIC void accumvbe(vec_t GEN , vec_t KILL , elem *n);
STATIC void accumrd(vec_t GEN , vec_t KILL , elem *n);
STATIC void flowaecp(void);

/***************** REACHING DEFINITIONS *********************/

/************************************
 * Compute reaching definitions (RDs).
 * That is, for each block B and each program variable X
 * find all elems that could be the last elem that defines
 * X along some path to B.
 * Binrd = the set of defs reaching the beginning of B.
 * Boutrd = the set of defs reaching the end of B.
 * Bkillrd = set of defs that are killed by some def in B.
 * Bgenrd = set of defs in B that reach the end of B.
 */

void flowrd()
{       vec_t tmp;
        unsigned i;
        bool anychng;

        rdgenkill();            /* Compute Bgen and Bkill for RDs       */
        if (deftop == 0)        /* if no definition elems               */
                return;         /* no analysis to be done               */

        /* The transfer equation is:                                    */
        /*      Bin = union of Bouts of all predecessors of B.          */
        /*      Bout = (Bin - Bkill) | Bgen                             */
        /* Using Ullman's algorithm:                                    */

        for (i = 0; i < dfotop; i++)
                vec_copy(dfo[i]->Boutrd,dfo[i]->Bgen);

        tmp = vec_calloc(deftop);
        do
        {       anychng = FALSE;
                for (i = 0; i < dfotop; i++)    /* for each block       */
                {       block *b;
                        list_t bp;

                        b = dfo[i];

                        /* Binrd = union of Boutrds of all predecessors of b */
                        vec_clear(b->Binrd);
                        if (b->BC != BCcatch /*&& b->BC != BCjcatch*/)
                        {
                            /* Set Binrd to 0 to account for:
                             * i = 0;
                             * try { i = 1; throw; } catch () { x = i; }
                             */
                            for (bp = b->Bpred; bp; bp = list_next(bp))
                                vec_orass(b->Binrd,list_block(bp)->Boutrd);
                        }
                        /* Bout = (Bin - Bkill) | Bgen */
                        vec_sub(tmp,b->Binrd,b->Bkill);
                        vec_orass(tmp,b->Bgen);
                        if (!anychng)
                                anychng = !vec_equal(tmp,b->Boutrd);
                        vec_copy(b->Boutrd,tmp);
                }
        } while (anychng);              /* while any changes to Boutrd  */
        vec_free(tmp);

#if 0
        dbg_printf("Reaching definitions\n");
        for (i = 0; i < dfotop; i++)
        {       block *b = dfo[i];

                assert(vec_numbits(b->Binrd) == deftop);
                dbg_printf("B%d Bin ",i); vec_println(b->Binrd);
                dbg_printf("  Bgen "); vec_println(b->Bgen);
                dbg_printf(" Bkill "); vec_println(b->Bkill);
                dbg_printf("  Bout "); vec_println(b->Boutrd);
        }
#endif
}

/***************************
 * Compute Bgen and Bkill for RDs.
 */

STATIC void rdgenkill()
{       unsigned i,deftopsave;

        util_free(defnod);              /* free existing junk           */

        defnod = NULL;

        /* Compute number of definition elems. */
        deftop = 0;
        for (i = 0; i < dfotop; i++)
                if (dfo[i]->Belem)
                {
                        numdefelems(dfo[i]->Belem);
                }
        if (deftop == 0)
                return;

        /* Allocate array of pointers to all definition elems   */
        /*      The elems are in dfo order.                     */
        /*      defnod[]s consist of a elem pointer and a pointer */
        /*      to the enclosing block.                         */
        defnod = (dn *) util_calloc(sizeof(dn),deftop);
        deftopsave = deftop;
        deftop = 0;
        for (i = 0; i < dfotop; i++)
                if (dfo[i]->Belem)
                        asgdefelems(dfo[i],dfo[i]->Belem);
        assert(deftop == deftopsave);

        for (i = 0; i < dfotop; i++)    /* for each block               */
        {       block *b = dfo[i];

                /* dump any existing vectors */
                vec_free(b->Bgen);
                vec_free(b->Bkill);
                vec_free(b->Binrd);
                vec_free(b->Boutrd);

                /* calculate and create new vectors */
                rdelem(&(b->Bgen),&(b->Bkill),b->Belem);
                if (b->BC == BCasm)
                {   vec_clear(b->Bkill);        // KILL nothing
                    vec_set(b->Bgen);           // GEN everything
                }
                b->Binrd = vec_calloc(deftop);
                b->Boutrd = vec_calloc(deftop);
        }
}

/**********************
 * Compute # of definition elems (deftop).
 */

STATIC void numdefelems(elem *n)
{
  while (1)
  {     assert(n);
        if (OTdef(n->Eoper))
                deftop++;
        if (OTbinary(n->Eoper))
        {
                numdefelems(n->E1);
                n = n->E2;
        }
        else if (OTunary(n->Eoper))
        {
                n = n->E1;
        }
        else
                break;
  }
}

/**************************
 * Load defnod[] array.
 * Loaded in order of execution of the elems. Not sure if this is
 * necessary.
 */

STATIC void asgdefelems(block *b,elem *n)
{       unsigned op;

        assert(b && n);
        op = n->Eoper;
        if (ERTOL(n))
        {       asgdefelems(b,n->E2);
                asgdefelems(b,n->E1);
        }
        else if (OTbinary(op))
        {       asgdefelems(b,n->E1);
                asgdefelems(b,n->E2);
        }
        else if (OTunary(op))
                asgdefelems(b,n->E1);
        if (OTdef(op))
        {       assert(defnod);
                defnod[deftop].DNblock = b;
                defnod[deftop].DNelem = n;
                deftop++;
        }
}

/*************************************
 * Allocate and compute rd GEN and KILL.
 */

STATIC void rdelem(vec_t *pgen,vec_t *pkill,                    /* where to put result          */
        elem *n )                               /* tree to evaluate for GEN and KILL */
{
        *pgen = vec_calloc(deftop);
        *pkill = vec_calloc(deftop);
        if (n)
                accumrd(*pgen,*pkill,n);
}

/**************************************
 * Accumulate GEN and KILL vectors for this elem.
 */

STATIC void accumrd(vec_t GEN,vec_t KILL,elem *n)
{       vec_t Gl,Kl,Gr,Kr;
        unsigned op;

        assert(GEN && KILL && n);
        op = n->Eoper;
        if (OTunary(op))
                accumrd(GEN,KILL,n->E1);
        else if (OTbinary(op))
        {
            if (op == OPcolon || op == OPcolon2)
            {
                rdelem(&Gl,&Kl,n->E1);
                rdelem(&Gr,&Kr,n->E2);

                /* GEN = (GEN - Kl) | Gl |      */
                /*      (GEN - Kr) | Gr         */
                /* KILL |= Kl & Kr              */

                vec_orass(Gl,Gr);
                vec_sub(Gr,GEN,Kl);
                vec_orass(Gl,Gr);
                vec_sub(Gr,GEN,Kr);
                vec_or(GEN,Gl,Gr);

                vec_andass(Kl,Kr);
                vec_orass(KILL,Kl);

                vec_free(Gl);
                vec_free(Kl);
                vec_free(Gr);
                vec_free(Kr);
            }
            else if (op == OPandand || op == OPoror)
            {
                accumrd(GEN,KILL,n->E1);
                rdelem(&Gr,&Kr,n->E2);
                vec_orass(GEN,Gr);      /* GEN |= Gr                    */

                vec_free(Gr);
                vec_free(Kr);
            }
            else if (OTrtol(op) && ERTOL(n))
            {   accumrd(GEN,KILL,n->E2);
                accumrd(GEN,KILL,n->E1);
            }
            else
            {   accumrd(GEN,KILL,n->E1);
                accumrd(GEN,KILL,n->E2);
            }
        }

        if (OTdef(op))                  /* if definition elem           */
                updaterd(n,GEN,KILL);
}

/******************** AVAILABLE EXPRESSIONS ***********************/

/************************************
 * Compute available expressions (AEs).
 * That is, expressions whose result is still current.
 * Bin = the set of AEs reaching the beginning of B.
 * Bout = the set of AEs reaching the end of B.
 */

void flowae()
{
  flowxx = AE;
  flowaecp();
}

/**************************** COPY PROPAGATION ************************/

/***************************************
 * Compute copy propagation info (CPs).
 * Very similar to AEs (the same code is used).
 * Using RDs for copy propagation is WRONG!
 * That is, set of copy statements still valid.
 * Bin = the set of CPs reaching the beginning of B.
 * Bout = the set of CPs reaching the end of B.
 */

void flowcp()
{
  flowxx = CP;
  flowaecp();
}

/*****************************************
 * Common flow analysis routines for Available Expressions and
 * Copy Propagation.
 * Input:
 *      flowxx
 */

STATIC void flowaecp()
{       vec_t tmp;
        unsigned i;
        bool anychng;

        aecpgenkill();          /* Compute Bgen and Bkill for AEs or CPs */
        if (exptop <= 1)        /* if no expressions                    */
                return;

        /* The transfer equation is:                    */
        /*      Bin = & Bout(all predecessors P of B)   */
        /*      Bout = (Bin - Bkill) | Bgen             */
        /* Using Ullman's algorithm:                    */

        vec_clear(startblock->Bin);
        vec_copy(startblock->Bout,startblock->Bgen); /* these never change */
        if (startblock->BC == BCiftrue)
            vec_copy(startblock->Bout2,startblock->Bgen2); // these never change

        /* For all blocks except startblock     */
        for (i = 1; i < dfotop; i++)
        {       block *b = dfo[i];

                vec_set(b->Bin);        /* Bin = all expressions        */

                /* Bout = (Bin - Bkill) | Bgen  */
                vec_sub(b->Bout,b->Bin,b->Bkill);
                vec_orass(b->Bout,b->Bgen);
                if (b->BC == BCiftrue)
                {   vec_sub(b->Bout2,b->Bin,b->Bkill2);
                    vec_orass(b->Bout2,b->Bgen2);
                }
        }

        tmp = vec_calloc(exptop);
        do
        {   anychng = FALSE;

            // For all blocks except startblock
            for (i = 1; i < dfotop; i++)
            {   block *b = dfo[i];
                list_t bl = b->Bpred;
                block *bp;

                // Bin = & of Bout of all predecessors
                // Bout = (Bin - Bkill) | Bgen

                assert(bl);     // it must have predecessors
                bp = list_block(bl);
                if (bp->BC == BCiftrue && list_block(bp->Bsucc) != b)
                    vec_copy(b->Bin,bp->Bout2);
                else
                    vec_copy(b->Bin,bp->Bout);
                while (TRUE)
                {   bl = list_next(bl);
                    if (!bl)
                        break;
                    bp = list_block(bl);
                    if (bp->BC == BCiftrue && list_block(bp->Bsucc) != b)
                        vec_andass(b->Bin,bp->Bout2);
                    else
                        vec_andass(b->Bin,bp->Bout);
                }

                if (anychng)
                {   vec_sub(b->Bout,b->Bin,b->Bkill);
                    vec_orass(b->Bout,b->Bgen);
                }
                else
                {   vec_sub(tmp,b->Bin,b->Bkill);
                    vec_orass(tmp,b->Bgen);
                    if (!vec_equal(tmp,b->Bout))
                    {   // Swap Bout and tmp instead of
                        // copying tmp over Bout
                        vec_t v;

                        v = tmp;
                        tmp = b->Bout;
                        b->Bout = v;
                        anychng = TRUE;
                    }
                }

                if (b->BC == BCiftrue)
                {   // Bout2 = (Bin - Bkill2) | Bgen2
                    if (anychng)
                    {   vec_sub(b->Bout2,b->Bin,b->Bkill2);
                        vec_orass(b->Bout2,b->Bgen2);
                    }
                    else
                    {   vec_sub(tmp,b->Bin,b->Bkill2);
                        vec_orass(tmp,b->Bgen2);
                        if (!vec_equal(tmp,b->Bout2))
                        {   // Swap Bout and tmp instead of
                            // copying tmp over Bout2
                            vec_t v;

                            v = tmp;
                            tmp = b->Bout2;
                            b->Bout2 = v;
                            anychng = TRUE;
                        }
                    }
                }
            }
        } while (anychng);
        vec_free(tmp);
}

/******************************
 * A variable to avoid parameter overhead to asgexpelems().
 */

static block *this_block;

/***********************************
 * Compute Bgen and Bkill for AEs, CPs, and VBEs.
 */

STATIC void aecpgenkill()
{       unsigned i;
        unsigned exptopsave;

        util_free(expnod);              /* dump any existing one        */

        expnod = NULL;

        /* Compute number of expressions */
        exptop = 1;                     /* start at 1                   */
        for (i = 0; i < dfotop; i++)
                if (dfo[i]->Belem)
                {       if (flowxx == CP)
                                numcpelems(dfo[i]->Belem);
                        else // AE || VBE
                                numaeelems(dfo[i]->Belem);
                }
        if (exptop <= 1)                /* if no expressions            */
                return;

        /* Allocate array of pointers to all expression elems.          */
        /* (The elems are in order. Also, these expressions must not    */
        /* have any side effects, and possibly should not be machine    */
        /* dependent primitive addressing modes.)                       */
        expnod = (elem **) util_calloc(sizeof(elem *),exptop);
        util_free(expblk);
        expblk = (flowxx == VBE)
                ? (block **) util_calloc(sizeof(block *),exptop) : NULL;

        exptopsave = exptop;
        exptop = 1;
        for (i = 0; i < dfotop; i++)
        {       this_block = dfo[i];    /* so asgexpelems knows about this */
                if (this_block->Belem)
                        asgexpelems(this_block->Belem);
        }
        assert(exptop == exptopsave);

        defstarkill();                  /* compute defkill and starkill */

#if 0
        assert(vec_numbits(defkill) == exptop);
        assert(vec_numbits(starkill) == exptop);
        assert(vec_numbits(vptrkill) == exptop);
        dbg_printf("defkill  "); vec_println(defkill);
        if (starkill)
            {   dbg_printf("starkill "); vec_println(starkill);}
        if (vptrkill)
            {   dbg_printf("vptrkill "); vec_println(vptrkill); }
#endif

        for (i = 0; i < dfotop; i++)    /* for each block               */
        {       block *b = dfo[i];
                elem *e;

                /* dump any existing vectors    */
                vec_free(b->Bin);
                vec_free(b->Bout);
                vec_free(b->Bgen);
                vec_free(b->Bkill);
                b->Bgen = vec_calloc(exptop);
                b->Bkill = vec_calloc(exptop);
                switch (b->BC)
                {
                    case BCiftrue:
                        vec_free(b->Bout2);
                        vec_free(b->Bgen2);
                        vec_free(b->Bkill2);
                        for (e = b->Belem; e->Eoper == OPcomma; e = e->E2)
                            accumaecp(b->Bgen,b->Bkill,e);
                        if (e->Eoper == OPandand || e->Eoper == OPoror)
                        {   vec_t Kr,Gr;

                            accumaecp(b->Bgen,b->Bkill,e->E1);
                            Kr = vec_calloc(exptop);
                            Gr = vec_calloc(exptop);
                            accumaecp(Gr,Kr,e->E2);

                            // We might or might not have executed E2
                            // KILL1 = KILL | Kr
                            // GEN1 = GEN & ((GEN - Kr) | Gr)

                            // We definitely executed E2
                            // KILL2 = (KILL - Gr) | Kr
                            // GEN2 = (GEN - Kr) | Gr

                            unsigned j,dim;
                            dim = vec_dim(Kr);
                            vec_t KILL = b->Bkill;
                            vec_t GEN = b->Bgen;

                            for (j = 0; j < dim; j++)
                            {   vec_base_t KILL1,KILL2,GEN1,GEN2;

                                KILL1 = KILL[j] | Kr[j];
                                GEN1  = GEN[j] & ((GEN[j] & ~Kr[j]) | Gr[j]);

                                KILL2 = (KILL[j] & ~Gr[j]) | Kr[j];
                                GEN2  = (GEN[j] & ~Kr[j]) | Gr[j];

                                KILL[j] = KILL1;
                                GEN[j] = GEN1;
                                Kr[j] = KILL2;
                                Gr[j] = GEN2;
                            }

                            if (e->Eoper == OPandand)
                            {   b->Bkill  = Kr;
                                b->Bgen   = Gr;
                                b->Bkill2 = KILL;
                                b->Bgen2  = GEN;
                            }
                            else
                            {   b->Bkill  = KILL;
                                b->Bgen   = GEN;
                                b->Bkill2 = Kr;
                                b->Bgen2  = Gr;
                            }
                        }
                        else
                        {
                            accumaecp(b->Bgen,b->Bkill,e);
                            b->Bgen2 = vec_clone(b->Bgen);
                            b->Bkill2 = vec_clone(b->Bkill);
                        }
                        b->Bout2 = vec_calloc(exptop);
                        break;

                    case BCasm:
                        vec_set(b->Bkill);              // KILL everything
                        vec_clear(b->Bgen);             // GEN nothing
                        break;

                    default:
                        // calculate GEN & KILL vectors
                        if (b->Belem)
                            accumaecp(b->Bgen,b->Bkill,b->Belem);
                        break;
                }
#if 0
                dbg_printf("block %d Bgen ",i); vec_println(b->Bgen);
                dbg_printf("       Bkill "); vec_println(b->Bkill);
#endif
                b->Bin = vec_calloc(exptop);
                b->Bout = vec_calloc(exptop);
        }
}

/*****************************
 * Accumulate number of expressions in exptop.
 * Set NFLaecp as a flag indicating an AE elem.
 * Returns:
 *      TRUE if this elem is a possible AE elem.
 */

STATIC int numaeelems(elem *n)
{ unsigned op;
  unsigned ae;

  assert(n);
  op = n->Eoper;
  if (OTunary(op))
  {     ae = numaeelems(n->E1);
        // Disallow starred references to avoid problems with VBE's
        // being hoisted before tests of an invalid pointer.
        if (flowxx == VBE && op == OPind)
            goto L1;
  }
  else if (OTbinary(op))
        ae = numaeelems(n->E1) & numaeelems(n->E2);
  else
        ae = TRUE;

  if (ae && OTae(op) && !(n->Ety & mTYvolatile) &&
      // Disallow struct AEs, because we can't handle CSEs that are structs
      tybasic(n->Ety) != TYstruct)
  {     n->Nflags |= NFLaecp;           /* remember for asgexpelems()   */
        exptop++;
  }
  else
  L1:
        n->Nflags &= ~NFLaecp;
  return n->Nflags & NFLaecp;
}


/****************************
 * Compute number of cp elems into exptop.
 * Mark cp elems by setting NFLaecp flag.
 */

STATIC void numcpelems(elem *n)
{ unsigned op;

  op = n->Eoper;
  if (OTunary(op))
        numcpelems(n->E1);
  else if (OTbinary(op))
  {     numcpelems(n->E1);
        numcpelems(n->E2);

        /* look for elem of the form OPvar=OPvar, where they aren't the */
        /* same variable.                                               */
        if ((op == OPeq || op == OPstreq) &&
            n->E1->Eoper == OPvar &&
            n->E2->Eoper == OPvar &&
            !((n->E1->Ety | n->E2->Ety) & mTYvolatile) &&
            n->E1->EV.sp.Vsym != n->E2->EV.sp.Vsym)
        {       exptop++;
                n->Nflags |= NFLaecp;
                return;
        }
  }
  n->Nflags &= ~NFLaecp;
}

/********************************
 * Assign ae (or cp) elems to expnod[] (in order of evaluation).
 */

STATIC void asgexpelems(elem *n)
{
  assert(n);
  if (OTunary(n->Eoper))
        asgexpelems(n->E1);
  else if (ERTOL(n))
  {     asgexpelems(n->E2);
        asgexpelems(n->E1);
  }
  else if (OTbinary(n->Eoper))
  {     asgexpelems(n->E1);
        asgexpelems(n->E2);
  }

  if (n->Nflags & NFLaecp)              /* if an ae, cp or vbe elem     */
  {     n->Eexp = exptop;               /* remember index into expnod[] */
        expnod[exptop] = n;
        if (expblk)
                expblk[exptop] = this_block;
        exptop++;
  }
  else
        n->Eexp = 0;
}

/********************************
 * Compute defkill, starkill and vptrkill vectors.
 *      starkill:       set of expressions killed when a variable is
 *                      changed that somebody could be pointing to.
 *                      (not needed for cp)
 *                      starkill is a subset of defkill.
 *      defkill:        set of expressions killed by an ambiguous
 *                      definition.
 *      vptrkill:       set of expressions killed by an access to a vptr.
 */

STATIC void defstarkill()
{       unsigned i,op;
        elem *n;

        vec_free(vptrkill);
        vec_free(defkill);
        vec_free(starkill);             /* dump any existing ones       */
        defkill = vec_calloc(exptop);
        if (flowxx != CP)
        {   starkill = vec_calloc(exptop);      /* and create new ones  */
            vptrkill = vec_calloc(exptop);      /* and create new ones  */
        }
        else /* CP */
        {   starkill = NULL;
            vptrkill = NULL;
        }

        if (flowxx == CP)
        {
            for (i = 1; i < exptop; i++)
            {   n = expnod[i];
                op = n->Eoper;
                assert(op == OPeq || op == OPstreq);
                assert(n->E1->Eoper==OPvar && n->E2->Eoper==OPvar);

                // Set bit in defkill if either the left or the
                // right variable is killed by an ambiguous def.

                Symbol *s1 = n->E1->EV.sp.Vsym;
                if (!(s1->Sflags & SFLunambig) ||
                    !(n->E2->EV.sp.Vsym->Sflags & SFLunambig))
                {
                    vec_setbit(i,defkill);
                }
            }
        }
        else
        {
            for (i = 1; i < exptop; i++)
            {   n = expnod[i];
                op = n->Eoper;
                switch (op)
                {
                    case OPvar:
                        if (!(n->EV.sp.Vsym->Sflags & SFLunambig))
                            vec_setbit(i,defkill);
                        break;

                    case OPind:         // if a 'starred' ref

#if 1
/* The following program fails for this:
import core.stdc.stdio;

class Foo
{
    string foo = "abc";
    size_t i = 0;

    void bar()
    {
        printf("%c\n", foo[i]);
        i++;
        printf("%c\n", foo[i]);
    }
}

void main()
{
    auto f = new Foo();
    f.bar();
}
*/
                        // For C/C++, casting to 'const' doesn't mean it
                        // actually is const,
                        // but immutable really doesn't change
                        if ((n->Ety & (mTYimmutable | mTYvolatile)) == mTYimmutable &&
                            n->E1->Eoper == OPvar &&
                            n->E1->EV.sp.Vsym->Sflags & SFLunambig
                           )
                            break;
#endif
                    case OPstrlen:
                    case OPstrcmp:
                    case OPmemcmp:
                    case OPbt:          // OPbt is like OPind
                        vec_setbit(i,defkill);
                        vec_setbit(i,starkill);
                        break;

#if TARGET_SEGMENTED
                    case OPvp_fp:
                    case OPcvp_fp:
                        vec_setbit(i,vptrkill);
                        goto Lunary;
#endif

                    default:
                        if (OTunary(op))
                        {
                        Lunary:
                            if (vec_testbit(n->E1->Eexp,defkill))
                                    vec_setbit(i,defkill);
                            if (vec_testbit(n->E1->Eexp,starkill))
                                    vec_setbit(i,starkill);
                        }
                        else if (OTbinary(op))
                        {
                            if (vec_testbit(n->E1->Eexp,defkill) ||
                                vec_testbit(n->E2->Eexp,defkill))
                                    vec_setbit(i,defkill);
                            if (vec_testbit(n->E1->Eexp,starkill) ||
                                vec_testbit(n->E2->Eexp,starkill))
                                    vec_setbit(i,starkill);
                        }
                        break;
                }
            }
        }
}

/********************************
 * Compute GEN and KILL vectors only for AEs.
 * defkill and starkill are assumed to be already set up correctly.
 * expnod[] is assumed to be set up correctly.
 */

void genkillae()
{       unsigned i;

        flowxx = AE;
        assert(exptop > 1);
        for (i = 0; i < dfotop; i++)
        {       block *b = dfo[i];

                assert(b);
                vec_clear(b->Bgen);
                vec_clear(b->Bkill);
                if (b->Belem)
                    accumaecp(b->Bgen,b->Bkill,b->Belem);
                else if (b->BC == BCasm)
                {   vec_set(b->Bkill);          // KILL everything
                    vec_clear(b->Bgen);         // GEN nothing
                }
        }
}

/************************************
 * Allocate and compute KILL and GEN vectors for a elem.
 */

STATIC void aecpelem(vec_t *pgen,vec_t *pkill, elem *n)
{       *pgen = vec_calloc(exptop);
        *pkill = vec_calloc(exptop);
        if (n)
        {       if (flowxx == VBE)
                        accumvbe(*pgen,*pkill,n);
                else
                        accumaecp(*pgen,*pkill,n);
        }
}

/*************************************
 * Accumulate GEN and KILL sets for AEs and CPs for this elem.
 */

static vec_t GEN;       // use static copies to save on parameter passing
static vec_t KILL;

STATIC void accumaecp(vec_t g,vec_t k,elem *n)
{   vec_t GENsave,KILLsave;

    assert(g && k);
    GENsave = GEN;
    KILLsave = KILL;
    GEN = g;
    KILL = k;
    accumaecpx(n);
    GEN = GENsave;
    KILL = KILLsave;
}

STATIC void accumaecpx(elem *n)
{   unsigned i,op;
    elem *t;

    assert(n);
    elem_debug(n);
    op = n->Eoper;

    switch (op)
    {
        case OPvar:
        case OPconst:
        case OPrelconst:
            if ((flowxx == AE) && n->Eexp)
            {   unsigned b;
#ifdef DEBUG
                assert(expnod[n->Eexp] == n);
#endif
                b = n->Eexp;
                vec_setclear(b,GEN,KILL);
            }
            return;
        case OPcolon:
        case OPcolon2:
        {   vec_t Gl,Kl,Gr,Kr;

            aecpelem(&Gl,&Kl,n->E1);
            aecpelem(&Gr,&Kr,n->E2);

            /* KILL |= Kl | Kr           */
            /* GEN =((GEN - Kl) | Gl) &  */
            /*     ((GEN - Kr) | Gr)     */

            vec_orass(KILL,Kl);
            vec_orass(KILL,Kr);

            vec_sub(Kl,GEN,Kl);
            vec_sub(Kr,GEN,Kr);
            vec_orass(Kl,Gl);
            vec_orass(Kr,Gr);
            vec_and(GEN,Kl,Kr);

            vec_free(Gl);
            vec_free(Gr);
            vec_free(Kl);
            vec_free(Kr);
            break;
        }
        case OPandand:
        case OPoror:
        {   vec_t Gr,Kr;

            accumaecpx(n->E1);
            aecpelem(&Gr,&Kr,n->E2);

            if (!el_noreturn(n->E2))
            {
                // KILL |= Kr
                // GEN &= (GEN - Kr) | Gr

                vec_orass(KILL,Kr);
                vec_sub(Kr,GEN,Kr);
                vec_orass(Kr,Gr);
                vec_andass(GEN,Kr);
            }

            vec_free(Gr);
            vec_free(Kr);
            break;
        }
        case OPddtor:
        case OPasm:
            assert(!n->Eexp);                   // no ASM available expressions
            vec_set(KILL);                      // KILL everything
            vec_clear(GEN);                     // GEN nothing
            return;

        case OPeq:
        case OPstreq:
            accumaecpx(n->E2);
        case OPnegass:
            accumaecpx(n->E1);
            t = Elvalue(n);
            break;

#if TARGET_SEGMENTED
        case OPvp_fp:
        case OPcvp_fp:                          // if vptr access
            if ((flowxx == AE) && n->Eexp)
                vec_orass(KILL,vptrkill);       // kill all other vptr accesses
            break;
#endif

        default:
            if (OTunary(op))
            {
        case OPind:                             // most common unary operator
                accumaecpx(n->E1);
#ifdef DEBUG
                assert(!OTassign(op));
#endif
            }
            else if (OTbinary(op))
            {
                if (OTrtol(op) && ERTOL(n))
                {   accumaecpx(n->E2);
                    accumaecpx(n->E1);
                }
                else
                {   accumaecpx(n->E1);
                    accumaecpx(n->E2);
                }
                if (OTassign(op))               // if assignment operator
                    t = Elvalue(n);
            }
            break;
    }


    /* Do copy propagation stuff first  */

    if (flowxx == CP)
    {
        if (!OTdef(op))                         /* if not def elem      */
                return;
        if (!Eunambig(n))                       /* if ambiguous def elem */
        {   vec_orass(KILL,defkill);
            vec_subass(GEN,defkill);
        }
        else                                    /* unambiguous def elem */
        {   symbol *s;

            assert(t->Eoper == OPvar);
            s = t->EV.sp.Vsym;                  // ptr to var being def'd
            for (i = 1; i < exptop; i++)        /* for each ae elem      */
            {   elem *e = expnod[i];

                /* If it could be changed by the definition,     */
                /* set bit in KILL.                              */

                if (e->E1->EV.sp.Vsym == s || e->E2->EV.sp.Vsym == s)
                    vec_setclear(i,KILL,GEN);
            }
        }

        /* GEN CP elems */
        if (n->Eexp)
        {   unsigned b = n->Eexp;

            vec_setclear(b,GEN,KILL);
        }

        return;
    }

    /* Else Available Expression stuff  */

    if (n->Eexp)
    {   unsigned b = n->Eexp;                   // add elem to GEN

        assert(expnod[b] == n);
        vec_setclear(b,GEN,KILL);
    }
    else if (OTdef(op))                         /* else if definition elem */
    {
        if (!Eunambig(n))                       /* if ambiguous def elem */
        {   vec_orass(KILL,defkill);
            vec_subass(GEN,defkill);
            if (OTcalldef(op))
            {   vec_orass(KILL,vptrkill);
                vec_subass(GEN,vptrkill);
            }
        }
        else                                    /* unambiguous def elem */
        {   symbol *s;

            assert(t->Eoper == OPvar);
            s = t->EV.sp.Vsym;                  /* idx of var being def'd */
            if (!(s->Sflags & SFLunambig))
            {   vec_orass(KILL,starkill);       /* kill all 'starred' refs */
                vec_subass(GEN,starkill);
            }
            for (i = 1; i < exptop; i++)        /* for each ae elem      */
            {   elem *e = expnod[i];
                int eop = e->Eoper;

                /* If it could be changed by the definition,     */
                /* set bit in KILL.                              */
                if (eop == OPvar)
                {   if (e->EV.sp.Vsym != s)
                        continue;
                }
                else if (OTunary(eop))
                {   if (!vec_testbit(e->E1->Eexp,KILL))
                        continue;
                }
                else if (OTbinary(eop))
                {   if (!vec_testbit(e->E1->Eexp,KILL) &&
                        !vec_testbit(e->E2->Eexp,KILL))
                        continue;
                }
                else
                        continue;

                vec_setclear(i,KILL,GEN);
            }
        }

        /* GEN the lvalue of an assignment operator      */
        if (OTassign(op) && !OTpost(op) && t->Eexp)
        {   unsigned b = t->Eexp;

            vec_setclear(b,GEN,KILL);
        }
    }
}

/************************* LIVE VARIABLES **********************/

/*********************************
 * Do live variable analysis (LVs).
 * A variable is 'live' at some point if there is a
 * subsequent use of it before a redefinition.
 * Binlv = the set of variables live at the beginning of B.
 * Boutlv = the set of variables live at the end of B.
 * Bgen = set of variables used before any definition in B.
 * Bkill = set of variables unambiguously defined before
 *       any use in B.
 * Note that Bgen & Bkill = 0.
 */

void flowlv()
{       vec_t tmp,livexit;
        unsigned i;
        bool anychng;
        unsigned cnt;

        lvgenkill();            /* compute Bgen and Bkill for LVs.      */
        //assert(globsym.top);  /* should be at least some symbols      */

        /* Create a vector of all the variables that are live on exit   */
        /* from the function.                                           */

        livexit = vec_calloc(globsym.top);
        for (i = 0; i < globsym.top; i++)
        {       if (globsym.tab[i]->Sflags & SFLlivexit)
                        vec_setbit(i,livexit);
        }

        /* The transfer equation is:                            */
        /*      Bin = (Bout - Bkill) | Bgen                     */
        /*      Bout = union of Bin of all successors to B.     */
        /* Using Ullman's algorithm:                            */

        for (i = 0; i < dfotop; i++)            /* for each block B     */
        {
                vec_copy(dfo[i]->Binlv,dfo[i]->Bgen);   /* Binlv = Bgen */
        }

        tmp = vec_calloc(globsym.top);
        cnt = 0;
        do
        {       anychng = FALSE;

                /* For each block B in reverse DFO order        */
                for (i = dfotop; i--;)
                {       block *b = dfo[i];
                        list_t bl = b->Bsucc;

                        /* Bout = union of Bins of all successors to B. */
                        if (bl)
                        {       vec_copy(b->Boutlv,list_block(bl)->Binlv);
                                while ((bl = list_next(bl)) != NULL)
                                {   vec_orass(b->Boutlv,list_block(bl)->Binlv);
                                }
                        }
                        else /* no successors, Boutlv = livexit */
                        {   //assert(b->BC==BCret||b->BC==BCretexp||b->BC==BCexit);
                            vec_copy(b->Boutlv,livexit);
                        }

                        /* Bin = (Bout - Bkill) | Bgen                  */
                        vec_sub(tmp,b->Boutlv,b->Bkill);
                        vec_orass(tmp,b->Bgen);
                        if (!anychng)
                                anychng = !vec_equal(tmp,b->Binlv);
                        vec_copy(b->Binlv,tmp);
                }
                cnt++;
                assert(cnt < 50);
        } while (anychng);
        vec_free(tmp);
        vec_free(livexit);
#if 0
        dbg_printf("Live variables\n");
        for (i = 0; i < dfotop; i++)
        {       dbg_printf("B%d IN\t",i);
                vec_println(dfo[i]->Binlv);
                dbg_printf("B%d GEN\t",i);
                vec_println(dfo[i]->Bgen);
                dbg_printf("  KILL\t");
                vec_println(dfo[i]->Bkill);
                dbg_printf("  OUT\t");
                vec_println(dfo[i]->Boutlv);
        }
#endif
}

/***********************************
 * Compute Bgen and Bkill for LVs.
 * Allocate Binlv and Boutlv vectors.
 */

STATIC void lvgenkill()
{       unsigned i;

        /* Compute ambigsym, a vector of all variables that could be    */
        /* referenced by a *e or a call.                                */

        assert(ambigsym == NULL);
        ambigsym = vec_calloc(globsym.top);
        for (i = 0; i < globsym.top; i++)
                if (!(globsym.tab[i]->Sflags & SFLunambig))
                        vec_setbit(i,ambigsym);

        for (i = 0; i < dfotop; i++)
        {       block *b = dfo[i];

                vec_free(b->Bgen);
                vec_free(b->Bkill);
                lvelem(&(b->Bgen),&(b->Bkill),b->Belem);
                if (b->BC == BCasm)
                {   vec_set(b->Bgen);
                    vec_clear(b->Bkill);
                }

                vec_free(b->Binlv);
                vec_free(b->Boutlv);
                b->Binlv = vec_calloc(globsym.top);
                b->Boutlv = vec_calloc(globsym.top);
        }

        vec_free(ambigsym);             /* dump any existing one        */
        ambigsym = NULL;
}

/*****************************
 * Allocate and compute KILL and GEN for live variables.
 */

STATIC void lvelem(vec_t *pgen,vec_t *pkill,elem *n)
{
        *pgen = vec_calloc(globsym.top);
        *pkill = vec_calloc(globsym.top);
        if (n && globsym.top)
                accumlv(*pgen,*pkill,n);
}

/**********************************************
 * Accumulate GEN and KILL sets for LVs for this elem.
 */

STATIC void accumlv(vec_t GEN,vec_t KILL,elem *n)
{   vec_t Gl,Kl,Gr,Kr;
    unsigned op;
    elem *t;

    assert(GEN && KILL && n);

    while (1)
    {   elem_debug(n);
        op = n->Eoper;
        switch (op)
        {
            case OPvar:
                if (symbol_isintab(n->EV.sp.Vsym))
                {   SYMIDX si = n->EV.sp.Vsym->Ssymnum;

                    assert((unsigned)si < globsym.top);
                    if (!vec_testbit(si,KILL))  // if not in KILL
                        vec_setbit(si,GEN);     // put in GEN
                }
                break;

            case OPcolon:
            case OPcolon2:
                lvelem(&Gl,&Kl,n->E1);
                lvelem(&Gr,&Kr,n->E2);

                /* GEN |= (Gl | Gr) - KILL      */
                /* KILL |= (Kl & Kr) - GEN      */

                vec_orass(Gl,Gr);
                vec_subass(Gl,KILL);
                vec_orass(GEN,Gl);
                vec_andass(Kl,Kr);
                vec_subass(Kl,GEN);
                vec_orass(KILL,Kl);

                vec_free(Gl);
                vec_free(Gr);
                vec_free(Kl);
                vec_free(Kr);
                break;

            case OPandand:
            case OPoror:
                accumlv(GEN,KILL,n->E1);
                lvelem(&Gr,&Kr,n->E2);

                /* GEN |= Gr - KILL     */
                /* KILL |= 0            */

                vec_subass(Gr,KILL);
                vec_orass(GEN,Gr);

                vec_free(Gr);
                vec_free(Kr);
                break;

            case OPasm:
                vec_set(GEN);           /* GEN everything not already KILLed */
                vec_subass(GEN,KILL);
                break;

            case OPcall:
            case OPcallns:
            case OPstrcpy:
            case OPmemcpy:
            case OPmemset:
#ifdef DEBUG
                assert(OTrtol(op));
#endif
                accumlv(GEN,KILL,n->E2);
                accumlv(GEN,KILL,n->E1);
                goto L1;

            case OPstrcat:
#ifdef DEBUG
                assert(!OTrtol(op));
#endif
                accumlv(GEN,KILL,n->E1);
                accumlv(GEN,KILL,n->E2);
            L1:
                vec_orass(GEN,ambigsym);
                vec_subass(GEN,KILL);
                break;

            case OPeq:
            case OPstreq:
                /* Avoid GENing the lvalue of an =      */
                accumlv(GEN,KILL,n->E2);
                t = Elvalue(n);
                if (t->Eoper != OPvar)
                        accumlv(GEN,KILL,t->E1);
                else /* unambiguous assignment */
                {
                    symbol *s = t->EV.sp.Vsym;
                    symbol_debug(s);

                    unsigned tsz = tysize(t->Ety);
                    if (op == OPstreq)
                        tsz = type_size(n->ET);

                    /* if not GENed already, KILL it */
                    if (symbol_isintab(s) &&
                        !vec_testbit(s->Ssymnum,GEN) &&
                        t->EV.sp.Voffset == 0 &&
                        tsz == type_size(s->Stype)
                       )
                    {   assert((unsigned)s->Ssymnum < globsym.top);
                        vec_setbit(s->Ssymnum,KILL);
                    }
                }
                break;

            case OPind:
            case OPucall:
            case OPucallns:
            case OPstrlen:
                accumlv(GEN,KILL,n->E1);

                /* If it was a *p elem, set bits in GEN for all symbols */
                /* it could have referenced, but only if bits in KILL   */
                /* are not already set.                                 */

                vec_orass(GEN,ambigsym);
                vec_subass(GEN,KILL);
                break;

            default:
                if (OTunary(op))
                {   n = n->E1;
                    continue;
                }
                else if (OTrtol(op) && ERTOL(n))
                {
                    accumlv(GEN,KILL,n->E2);

                    /* Note that lvalues of op=,i++,i-- elems */
                    /* are GENed.                               */
                    n = n->E1;
                    continue;
                }
                else if (OTbinary(op))
                {
                    accumlv(GEN,KILL,n->E1);
                    n = n->E2;
                    continue;
                }
                break;
        }
        break;
    }
}

/********************* VERY BUSY EXPRESSIONS ********************/

/**********************************************
 * Compute very busy expressions(VBEs).
 * That is,expressions that are evaluated along
 * separate paths.
 * Bin = the set of VBEs at the beginning of B.
 * Bout = the set of VBEs at the end of B.
 * Bgen = set of expressions X+Y such that X+Y is
 *      evaluated before any def of X or Y.
 * Bkill = set of expressions X+Y such that X or Y could
 *      be defined before X+Y is computed.
 * Note that gen and kill are mutually exclusive.
 */

void flowvbe()
{       vec_t tmp;
        unsigned i;
        bool anychng;

        flowxx = VBE;
        aecpgenkill();          /* compute Bgen and Bkill for VBEs      */
        if (exptop <= 1)        /* if no candidates for VBEs            */
                return;

        /*for (i = 0; i < exptop; i++)
                dbg_printf("expnod[%d] = 0x%x\n",i,expnod[i]);*/

        /* The transfer equation is:                    */
        /*      Bout = & Bin(all successors S of B)     */
        /*      Bin =(Bout - Bkill) | Bgen              */
        /* Using Ullman's algorithm:                    */

        /*dbg_printf("defkill = "); vec_println(defkill);
        dbg_printf("starkill = "); vec_println(starkill);*/

        for (i = 0; i < dfotop; i++)
        {       block *b = dfo[i];

                /*dbg_printf("block 0x%x\n",b);
                dbg_printf("Bgen = "); vec_println(b->Bgen);
                dbg_printf("Bkill = "); vec_println(b->Bkill);*/

                if (b->BC == BCret || b->BC == BCretexp || b->BC == BCexit)
                        vec_clear(b->Bout);
                else
                        vec_set(b->Bout);

                /* Bin = (Bout - Bkill) | Bgen  */
                vec_sub(b->Bin,b->Bout,b->Bkill);
                vec_orass(b->Bin,b->Bgen);
        }

        tmp = vec_calloc(exptop);
        do
        {       anychng = FALSE;

                /* for all blocks except return blocks in reverse dfo order */
                for (i = dfotop; i--;)
                {       block *b = dfo[i];
                        list_t bl;

                        if (b->BC == BCret || b->BC == BCretexp || b->BC == BCexit)
                                continue;

                        /* Bout = & of Bin of all successors */
                        bl = b->Bsucc;
                        assert(bl);     /* must have successors         */
                        vec_copy(b->Bout,list_block(bl)->Bin);
                        while (TRUE)
                        {   bl = list_next(bl);
                            if (!bl)
                                break;
                            vec_andass(b->Bout,list_block(bl)->Bin);
                        }

                        /* Bin = (Bout - Bkill) | Bgen  */
                        vec_sub(tmp,b->Bout,b->Bkill);
                        vec_orass(tmp,b->Bgen);
                        if (!anychng)
                                anychng = !vec_equal(tmp,b->Bin);
                        vec_copy(b->Bin,tmp);
                }
        } while (anychng);      /* while any changes occurred to any Bin */
        vec_free(tmp);
}

/*************************************
 * Accumulate GEN and KILL sets for VBEs for this elem.
 */

STATIC void accumvbe(vec_t GEN,vec_t KILL,elem *n)
{       unsigned op,i;
        elem *t;

        assert(GEN && KILL && n);
        op = n->Eoper;

        switch (op)
        {
            case OPcolon:
            case OPcolon2:
            {   vec_t Gl,Gr,Kl,Kr;

                aecpelem(&Gl,&Kl,n->E1);
                aecpelem(&Gr,&Kr,n->E2);

                /* GEN |=((Gr - Kl) | (Gl - Kr)) - KILL */
                vec_subass(Gr,Kl);
                vec_subass(Gl,Kr);
                vec_orass(Gr,Gl);
                vec_subass(Gr,KILL);
                vec_orass(GEN,Gr);

                /* KILL |=(Kl | Kr) - GEN       */
                vec_orass(Kl,Kr);
                vec_subass(Kl,GEN);
                vec_orass(KILL,Kl);

                vec_free(Gl);
                vec_free(Kl);
                vec_free(Gr);
                vec_free(Kr);
                break;
            }

            case OPandand:
            case OPoror:
                accumvbe(GEN,KILL,n->E1);
                /* WARNING: just so happens that it works this way.     */
                /* Be careful about (b+c)||(b+c) being VBEs, only the   */
                /* first should be GENed. Doing things this way instead */
                /* of (GEN |= Gr - KILL) and (KILL |= Kr - GEN) will    */
                /* ensure this.                                         */
                accumvbe(GEN,KILL,n->E2);
                break;

            case OPnegass:
                t = n->E1;
                if (t->Eoper != OPvar)
                {   accumvbe(GEN,KILL,t->E1);
                    if (OTbinary(t->Eoper))
                        accumvbe(GEN,KILL,t->E2);
                }
                break;

            case OPcall:
            case OPcallns:
                accumvbe(GEN,KILL,n->E2);
            case OPucall:
            case OPucallns:
                t = n->E1;
                // Do not VBE indirect function calls
                if (t->Eoper == OPind)
                    t = t->E1;
                accumvbe(GEN,KILL,t);
                break;

            case OPasm:                 // if the dreaded OPasm elem
                vec_set(KILL);          // KILL everything
                vec_subass(KILL,GEN);   // except for GENed stuff
                return;

            default:
                if (OTunary(op))
                {
                    t = n->E1;
                    accumvbe(GEN,KILL,t);
                }
                else if (ERTOL(n))
                {   accumvbe(GEN,KILL,n->E2);
                    t = n->E1;
                    // do not GEN the lvalue of an assignment op
                    if (OTassign(op))
                    {   t = Elvalue(n);
                        if (t->Eoper != OPvar)
                        {   accumvbe(GEN,KILL,t->E1);
                            if (OTbinary(t->Eoper))
                                accumvbe(GEN,KILL,t->E2);
                        }
                    }
                    else
                        accumvbe(GEN,KILL,t);
                }
                else if (OTbinary(op))
                {
                        /* do not GEN the lvalue of an assignment op    */
                        if (OTassign(op))
                        {   t = Elvalue(n);
                            if (t->Eoper != OPvar)
                            {   accumvbe(GEN,KILL,t->E1);
                                if (OTbinary(t->Eoper))
                                    accumvbe(GEN,KILL,t->E2);
                            }
                        }
                        else
                            accumvbe(GEN,KILL,n->E1);
                        accumvbe(GEN,KILL,n->E2);
                }
                break;
        }

        if (n->Eexp)                    /* if a vbe elem                */
        {       int ne = n->Eexp;

                assert(expnod[ne] == n);
                if (!vec_testbit(ne,KILL))      /* if not already KILLed */
                {
                        /* GEN this expression only if it hasn't        */
                        /* already been GENed in this block.            */
                        /* (Don't GEN common subexpressions.)           */
                        if (vec_testbit(ne,GEN))
                                vec_clearbit(ne,GEN);
                        else
                        {   vec_setbit(ne,GEN); /* GEN this expression  */
                            /* GEN all identical expressions            */
                            /* (operators only, as there is no point    */
                            /* to hoisting out variables and constants) */
                            if (!OTleaf(op))
                            {   for (i = 1; i < exptop; i++)
                                {       if (op == expnod[i]->Eoper &&
                                            i != ne &&
                                            el_match(n,expnod[i]))
                                            {   vec_setbit(i,GEN);
                                                assert(!vec_testbit(i,KILL));
                                            }
                                }
                            }
                        }
                }
#if TARGET_SEGMENTED
                if (op == OPvp_fp || op == OPcvp_fp)
                {
                    vec_orass(KILL,vptrkill);   /* KILL all vptr accesses */
                    vec_subass(KILL,GEN);       /* except for GENed stuff */
                }
#endif
        }
        else if (OTdef(op))             /* if definition elem           */
        {
                if (!Eunambig(n))       /* if ambiguous definition      */
                {       vec_orass(KILL,defkill);
                        if (OTcalldef(op))
                            vec_orass(KILL,vptrkill);
                }
                else                    /* unambiguous definition       */
                {   symbol *s;

                    assert(t->Eoper == OPvar);
                    s = t->EV.sp.Vsym;  // ptr to var being def'd
                    if (!(s->Sflags & SFLunambig))
                        vec_orass(KILL,starkill);/* kill all 'starred' refs */
                    for (i = 1; i < exptop; i++)        /* for each vbe elem */
                    {   elem *e = expnod[i];
                        unsigned eop = e->Eoper;

                        /* If it could be changed by the definition,     */
                        /* set bit in KILL.                              */
                        if (eop == OPvar)
                        {   if (e->EV.sp.Vsym != s)
                                continue;
                        }
                        else if (OTbinary(eop))
                        {   if (!vec_testbit(e->E1->Eexp,KILL) &&
                                !vec_testbit(e->E2->Eexp,KILL))
                                continue;
                        }
                        else if (OTunary(eop))
                        {   if (!vec_testbit(e->E1->Eexp,KILL))
                                continue;
                        }
                        else /* OPconst or OPrelconst or OPstring */
                                continue;

                        vec_setbit(i,KILL);     // KILL it
                    } /* for */
                } /* if */
                vec_subass(KILL,GEN);
        } /* if */
}

#endif
