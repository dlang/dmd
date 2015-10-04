// Copyright (C) 1986-1997 by Symantec
// Copyright (C) 2000-2013 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */


/****************************************************************
 * Handle basic blocks.
 */

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <time.h>
#include        <stdlib.h>

#include        "cc.h"
#include        "oper.h"
#include        "el.h"
#include        "type.h"
#include        "global.h"
#include        "go.h"
#include        "code.h"
#if SCPP
#include        "parser.h"
#include        "iasm.h"
#endif

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

STATIC void bropt(void);
STATIC void brrear(void);
STATIC void search(block *b);
STATIC void elimblks(void);
STATIC int  mergeblks(void);
STATIC void blident(void);
STATIC void blreturn(void);
STATIC void brmin(void);
STATIC void bltailmerge(void);
STATIC void block_check();
STATIC void brtailrecursion();
STATIC elem * assignparams(elem **pe,int *psi,elem **pe2);
STATIC void emptyloops();
int el_anyframeptr(elem *e);

unsigned numblks;       // number of basic blocks in current function
block *startblock;      /* beginning block of function                  */
                        /* (can have no predecessors)                   */

block **dfo = NULL;     /* array of depth first order                   */
unsigned dfotop;        /* # of items in dfo[]                          */

block *curblock;        /* current block being read in                  */
block *block_last;      // last block read in

static block * block_freelist;

////////////////////////////
// Storage allocator.

static block blkzero;

__inline block *block_calloc_i()
{   block *b;

    if (block_freelist)
    {   b = block_freelist;
        block_freelist = b->Bnext;
        *b = blkzero;
    }
    else
        b = (block *) mem_fcalloc(sizeof(block));
    return b;
}

block *block_calloc()
{
    return block_calloc_i();
}

//////////////////////////////////
//

goal_t bc_goal[BCMAX];

void block_init()
{
    for (size_t i = 0; i < BCMAX; i++)
        bc_goal[i] = GOALvalue;

    bc_goal[BCgoto] = GOALnone;
    bc_goal[BCret ] = GOALnone;
    bc_goal[BCexit] = GOALnone;

    bc_goal[BCiftrue] = GOALflags;
}

//////////////////////////////////
//

void block_term()
{
#if TERMCODE
    block *b;

    while (block_freelist)
    {   b = block_freelist->Bnext;
        mem_ffree(block_freelist);
        block_freelist = b;
    }

#endif
}

/**************************
 * Finish up this block and start the next one.
 */

#if MARS
void block_next(Blockx *bctx,enum BC bc,block *bn)
{
    bctx->curblock->BC = bc;
    block_last = bctx->curblock;
    if (!bn)
        bn = block_calloc_i();
    bctx->curblock->Bnext = bn;                 // next block
    bctx->curblock = bctx->curblock->Bnext;     // new current block
#if NTEXCEPTIONS
    bctx->curblock->Btry = bctx->tryblock;
#endif
    bctx->curblock->Bflags |= bctx->flags;
}
#else
void block_next(enum BC bc,block *bn)
{
    curblock->BC = bc;
    curblock->Bsymend = globsym.top;
    block_last = curblock;
    if (!bn)
        bn = block_calloc_i();
    curblock->Bnext = bn;                       // next block
    curblock = curblock->Bnext;         // new current block
    curblock->Bsymstart = globsym.top;
    curblock->Btry = pstate.STbtry;
}

void block_next()
{
    block_next((enum BC)curblock->BC,NULL);
}
#endif

/**************************
 * Finish up this block and start the next one.
 */

#if MARS

block *block_goto(Blockx *bx,enum BC bc,block *bn)
{   block *b;

    b = bx->curblock;
    block_next(bx,bc,bn);
    list_append(&b->Bsucc,bx->curblock);
    return bx->curblock;
}

#endif

/****************************
 * Goto a block named gotolbl.
 * Start a new block that is labelled by newlbl.
 */

#if SCPP

void block_goto()
{
    block_goto(block_calloc());
}

void block_goto(block *bn)
{
    block_goto(bn,bn);
}

void block_goto(block *bgoto,block *bnew)
{
    enum BC bc;

    assert(bgoto);
    list_append(&(curblock->Bsucc),bgoto);
    if (curblock->Bcode)        // If there is already code in the block
                                // then this is an ASM block
            bc = BCasm;
    else
            bc = BCgoto;        // fall thru to next block
    block_next(bc,bnew);
}

#endif

/**********************************
 * Replace block numbers with block pointers.
 * Also compute numblks and maxblks.
 */

void block_ptr()
{   block *b;

/*    dbg_printf("block_ptr()\n");*/

    numblks = 0;
    for (b = startblock; b; b = b->Bnext)       /* for each block        */
    {
#if SCPP
        b->Bblknum = numblks;
#endif
        numblks++;
    }
    maxblks = 3 * numblks;              /* allow for increase in # of blocks */
}

/*******************************
 * Build predecessor list (Bpred) for each block.
 */

void block_pred()
{   block *b;

    //dbg_printf("block_pred()\n");
    for (b = startblock; b; b = b->Bnext)       /* for each block        */
        list_free(&b->Bpred,FPNULL);

    for (b = startblock; b; b = b->Bnext)       /* for each block        */
    {   list_t bp;

        //printf("b = %p, BC = ",b); WRBC(b->BC); printf("\n");
        for (bp = b->Bsucc; bp; bp = list_next(bp))
        {                               /* for each successor to b      */
                //printf("\tbs = %p\n",list_block(bp));
                assert(list_block(bp));
                list_prepend(&(list_block(bp)->Bpred),b);
        }
    }
    assert(startblock->Bpred == NULL);  /* startblock has no preds      */
}

/********************************************
 * Clear visit.
 */

void block_clearvisit()
{   block *b;

    for (b = startblock; b; b = b->Bnext)       // for each block
        b->Bflags &= ~BFLvisited;               // mark as unvisited
}

/********************************************
 * Visit block and each of its predecessors.
 */

void block_visit(block *b)
{   list_t l;

    b->Bflags |= BFLvisited;
    for (l = b->Bsucc; l; l = list_next(l))      // for each successor
    {   block *bs = list_block(l);
        assert(bs);
        if ((bs->Bflags & BFLvisited) == 0)     // if not visited
            block_visit(bs);
    }
}

/*****************************
 * Compute number of parents (Bcount) of each basic block.
 */

void block_compbcount()
{
    block_clearvisit();
    block_visit(startblock);                    // visit all reachable blocks
    elimblks();                                 // eliminate unvisited blocks
}

/*******************************
 * Free list of blocks.
 */

void blocklist_free(block **pb)
{       block *b,*bn;

        for (b = *pb; b; b = bn)
        {       bn = b->Bnext;
                block_free(b);
        }
        *pb = NULL;
}

/********************************
 * Free optimizer gathered data.
 */

void block_optimizer_free(block *b)
{
    vec_free(b->Bdom);
    vec_free(b->Binrd);
    vec_free(b->Boutrd);
    vec_free(b->Binlv);
    vec_free(b->Boutlv);
    vec_free(b->Bin);
    vec_free(b->Bout);
    vec_free(b->Bgen);
    vec_free(b->Bkill);
    vec_free(b->Bout2);
    vec_free(b->Bgen2);
    vec_free(b->Bkill2);

    memset(&b->_BLU,0,sizeof(b->_BLU));
}

/****************************
 * Free a block.
 */

void block_free(block *b)
{
    assert(b);
    if (b->Belem)
        el_free(b->Belem);
    list_free(&b->Bsucc,FPNULL);
    list_free(&b->Bpred,FPNULL);
    if (OPTIMIZER)
        block_optimizer_free(b);
    switch (b->BC)
    {   case BCswitch:
        case BCifthen:
        case BCjmptab:
#if MARS
            free(b->BS.Bswitch);
#else
            MEM_PH_FREE(b->BS.Bswitch);
#endif
            break;
#if SCPP
        case BCcatch:
            type_free(b->Bcatchtype);
            break;
#endif
        case BCasm:
            code_free(b->Bcode);
            break;
    }
    b->Bnext = block_freelist;
    block_freelist = b;
}

/****************************
 * Hydrate/dehydrate a list of blocks.
 */

#if HYDRATE
void blocklist_hydrate(block **pb)
{   block *b;

    while (isdehydrated(*pb))
    {
        /*dbg_printf("blocklist_hydrate(*pb = %p) =",*pb);*/
        b = (block *)ph_hydrate(pb);
        /*dbg_printf(" %p\n",b);*/
        el_hydrate(&b->Belem);
        list_hydrate(&b->Bsucc,FPNULL);
        list_hydrate(&b->Bpred,FPNULL);
        (void) ph_hydrate(&b->Btry);
#if SCPP
        (void) ph_hydrate(&b->Bendscope);
        symbol_hydrate(&b->Binitvar);
#endif
        switch (b->BC)
        {
#if SCPP
            case BCtry:
                symbol_hydrate(&b->catchvar);
                break;
            case BCcatch:
                type_hydrate(&b->Bcatchtype);
                break;
#endif
            case BCswitch:
                (void) ph_hydrate(&b->BS.Bswitch);
                break;

            case BC_finally:
                //(void) ph_hydrate(&b->B_ret);
                break;

            case BCasm:
                code_hydrate(&b->Bcode);
                break;
        }
#if TX86
        filename_translate(&b->Bsrcpos);
        srcpos_hydrate(&b->Bsrcpos);
#endif
        pb = &b->Bnext;
    }
}
#endif

#if DEHYDRATE
void blocklist_dehydrate(block **pb)
{   block *b;

    while ((b = *pb) != NULL && !isdehydrated(b))
    {
#if DEBUG_XSYMGEN
        if (xsym_gen && ph_in_head(b))
            return;
#endif
        /*dbg_printf("blocklist_dehydrate(*pb = %p) =",b);*/
        ph_dehydrate(pb);
        /*dbg_printf(" %p\n",*pb);*/
        el_dehydrate(&b->Belem);
        list_dehydrate(&b->Bsucc,FPNULL);
        list_dehydrate(&b->Bpred,FPNULL);
        ph_dehydrate(&b->Btry);
#if SCPP
        ph_dehydrate(&b->Bendscope);
        symbol_dehydrate(&b->Binitvar);
#endif
        switch (b->BC)
        {
#if SCPP
            case BCtry:
                symbol_dehydrate(&b->catchvar);
                break;
            case BCcatch:
                type_dehydrate(&b->Bcatchtype);
                break;
#endif
            case BCswitch:
                ph_dehydrate(&b->BS.Bswitch);
                break;

            case BC_finally:
                //ph_dehydrate(&b->B_ret);
                break;

            case BCasm:
                code_dehydrate(&b->Bcode);
                break;
        }
#if TX86
        srcpos_dehydrate(&b->Bsrcpos);
#endif
        pb = &b->Bnext;
    }
}
#endif

/****************************
 * Append elem to the elems comprising the current block.
 * Read in an expression and put it in curblock->Belem.
 * If there is one already there, create a tree like:
 *              ,
 *             / \
 *           old  e
 */

void block_appendexp(block *b,elem *e)
{   elem *ec;
    elem **pe;

    assert(MARS || PARSER);
    if (e)
    {
        assert(b);
        elem_debug(e);
        pe = &b->Belem;
        ec = *pe;
        if (ec != NULL)
        {
            type *t = e->ET;

            if (t)
                type_debug(t);
            elem_debug(e);
#if MARS
            tym_t ty = e->Ety;

            elem_debug(e);
            /* Build tree such that (a,b) => (a,(b,e))  */
            while (ec->Eoper == OPcomma)
            {
                ec->Ety = ty;
                ec->ET = t;
                pe = &(ec->E2);
                ec = *pe;
            }
            e = el_bin(OPcomma,ty,ec,e);
            e->ET = t;
#else
            /* Build tree such that (a,b) => (a,(b,e))  */
            while (ec->Eoper == OPcomma)
            {
                el_settype(ec,t);
                pe = &(ec->E2);
                ec = *pe;
            }
            e = el_bint(OPcomma,t,ec,e);
#endif
        }
        *pe = e;
    }
}

/************************
 * Mark curblock as initializing symbol s.
 */

#if SCPP

#undef block_initvar

void block_initvar(symbol *s)
{
#ifdef DEBUG
    assert(curblock);
#endif
    symbol_debug(s);
    curblock->Binitvar = s;
}

#endif

/*******************
 * Mark end of function.
 * flag:
 *      0       do a "return"
 *      1       do a "return 0"
 */

void block_endfunc(int flag)
{
#if SCPP
    curblock->Bsymend = globsym.top;
    curblock->Bendscope = curblock;
#endif
    if (flag)
    {   elem *e;

        e = el_longt(tsint, 0);
        block_appendexp(curblock, e);
        curblock->BC = BCretexp;        // put a return at the end
    }
    else
        curblock->BC = BCret;           // put a return at the end
    curblock = NULL;                    // undefined from now on
    block_last = NULL;
}

/******************************
 * Perform branch optimization on basic blocks.
 */

void blockopt(int iter)
{   block *b;
    int count;

    if (OPTIMIZER)
    {
        int iterationLimit = 200;
        if (iterationLimit < numblks)
            iterationLimit = numblks;
        count = 0;
        do
        {
            //printf("changes = %d, count = %d, dfotop = %d\n",go.changes,count,dfotop);
#if MARS
            util_progress();
#else
            if (controlc_saw)
                util_exit(EXIT_BREAK);
#endif
            go.changes = 0;
            bropt();                    // branch optimization
            brrear();                   // branch rearrangement
            blident();                  // combine identical blocks
            blreturn();                 // split out return blocks
            bltailmerge();              // do tail merging
            brtailrecursion();          // do tail recursion
            brcombine();                // convert graph to expressions
            if (iter >= 2)
                brmin();                // minimize branching
            do
            {
                compdfo();              /* compute depth first order (DFO) */
                elimblks();             /* remove blocks not in DFO      */
                assert(count < iterationLimit);
                count++;
            } while (mergeblks());      /* merge together blocks         */
        } while (go.changes);
#ifdef DEBUG
        if (debugw)
            for (b = startblock; b; b = b->Bnext)
                WRblock(b);
#endif
    }
    else
    {
        /* canonicalize the trees        */
        for (b = startblock; b; b = b->Bnext)
        {
#ifdef DEBUG
            if (debugb)
                WRblock(b);
#endif
            if (b->Belem)
            {   b->Belem = doptelem(b->Belem,bc_goal[b->BC] | GOALstruct);
                if (b->Belem)
                    b->Belem = el_convert(b->Belem);
            }
#ifdef DEBUG
            if (debugb)
            {   dbg_printf("after optelem():\n");
                WRblock(b);
            }
#endif
        }
        if (localgot)
        {   // Initialize with:
            //  localgot = OPgot;
            elem *e = el_long(TYnptr, 0);
            e->Eoper = OPgot;
            e = el_bin(OPeq, TYnptr, el_var(localgot), e);
            startblock->Belem = el_combine(e, startblock->Belem);
        }

        bropt();                        /* branch optimization           */
        brrear();                       /* branch rearrangement          */
        comsubs();                      /* eliminate common subexpressions */
#ifdef DEBUG
        if (debugb)
                for (b = startblock; b; b = b->Bnext)
                        WRblock(b);
#endif
    }
}

/***********************************
 * Try to remove control structure.
 * That is, try to resolve if-else, goto and return statements
 * into &&, || and ?: combinations.
 */

void brcombine()
{   block *b;
    block *b2,*b3;
    int op;
    int anychanges;

    cmes("brcombine()\n");
    //for (b = startblock; b; b = b->Bnext)
        //WRblock(b);

    if (funcsym_p->Sfunc->Fflags3 & (Fcppeh | Fnteh))
    {   // Don't mess up extra EH info by eliminating blocks
        return;
    }

    do
    {
        anychanges = 0;
        for (b = startblock; b; b = b->Bnext)   /* for each block       */
        {   unsigned char bc;

            /* Look for [e1 IFFALSE L3,L2] L2: [e2 GOTO L3] L3: [e3]    */
            /* Replace with [(e1 && e2),e3]                             */
            bc = b->BC;
            if (bc == BCiftrue)
            {   unsigned char bc2;

                b2 = list_block(b->Bsucc);
                b3 = list_block(list_next(b->Bsucc));

                if (list_next(b2->Bpred))       // if more than one predecessor
                    continue;
                if (b2 == b3)
                    continue;
                if (b2 == startblock)
                    continue;
                if (!PARSER && b2->Belem && EOP(b2->Belem))
                    continue;

                bc2 = b2->BC;
                if (bc2 == BCgoto &&
                    b3 == list_block(b2->Bsucc))
                {
                    b->BC = BCgoto;
                    if (b2->Belem)
                    {
                        op = OPandand;
                        b->Belem = PARSER ? el_bint(op,tsint,b->Belem,b2->Belem)
                                          : el_bin(op,TYint,b->Belem,b2->Belem);
                        b2->Belem = NULL;
                    }
                    list_subtract(&(b->Bsucc),b2);
                    list_subtract(&(b2->Bpred),b);
                    cmes("brcombine(): if !e1 then e2 => e1 || e2\n");
                    anychanges++;
                }
                else if (list_next(b3->Bpred) || b3 == startblock)
                    continue;
                else if ((bc2 == BCretexp && b3->BC == BCretexp)
                         //|| (bc2 == BCret && b3->BC == BCret)
                        )
                {   elem *e;

                    if (PARSER)
                    {
                        type *t = (bc2 == BCretexp) ? b2->Belem->ET : tsvoid;
                        e = el_bint(OPcolon2,t,b2->Belem,b3->Belem);
                        b->Belem = el_bint(OPcond,t,b->Belem,e);
                    }
                    else
                    {
                        if (EOP(b3->Belem))
                            continue;
                        tym_t ty = (bc2 == BCretexp) ? b2->Belem->Ety : TYvoid;
                        e = el_bin(OPcolon2,ty,b2->Belem,b3->Belem);
                        b->Belem = el_bin(OPcond,ty,b->Belem,e);
                    }
                    b->BC = bc2;
                    b->Belem->ET = b2->Belem->ET;
                    b2->Belem = NULL;
                    b3->Belem = NULL;
                    list_free(&b->Bsucc,FPNULL);
                    list_subtract(&(b2->Bpred),b);
                    list_subtract(&(b3->Bpred),b);
                    cmes("brcombine(): if e1 return e2 else return e3 => ret e1?e2:e3\n");
                    anychanges++;
                }
                else if (bc2 == BCgoto &&
                         b3->BC == BCgoto &&
                         list_block(b2->Bsucc) == list_block(b3->Bsucc))
                {   elem *e;
                    block *bsucc;

                    bsucc = list_block(b2->Bsucc);
                    if (b2->Belem)
                    {
                        if (PARSER)
                        {
                            if (b3->Belem)
                            {
                                e = el_bint(OPcolon2,b2->Belem->ET,
                                        b2->Belem,b3->Belem);
                                e = el_bint(OPcond,e->ET,b->Belem,e);
                            }
                            else
                            {
                                op = OPandand;
                                e = el_bint(op,tsint,b->Belem,b2->Belem);
                            }
                        }
                        else
                        {
                            if (b3->Belem)
                            {
                                if (EOP(b3->Belem))
                                    continue;
                                e = el_bin(OPcolon2,b2->Belem->Ety,
                                        b2->Belem,b3->Belem);
                                e = el_bin(OPcond,e->Ety,b->Belem,e);
                                e->ET = b2->Belem->ET;
                            }
                            else
                            {
                                op = OPandand;
                                e = el_bin(op,TYint,b->Belem,b2->Belem);
                            }
                        }
                        b2->Belem = NULL;
                        b->Belem = e;
                    }
                    else if (b3->Belem)
                    {
                        op = OPoror;
                        b->Belem = PARSER ? el_bint(op,tsint,b->Belem,b3->Belem)
                                          : el_bin(op,TYint,b->Belem,b3->Belem);
                    }
                    b->BC = BCgoto;
                    b3->Belem = NULL;
                    list_free(&b->Bsucc,FPNULL);

                    list_append(&b->Bsucc,bsucc);
                    list_append(&bsucc->Bpred,b);

                    list_free(&(b2->Bpred),FPNULL);
                    list_free(&(b2->Bsucc),FPNULL);
                    list_free(&(b3->Bpred),FPNULL);
                    list_free(&(b3->Bsucc),FPNULL);
                    b2->BC = BCret;
                    b3->BC = BCret;
                    list_subtract(&(bsucc->Bpred),b2);
                    list_subtract(&(bsucc->Bpred),b3);
                    cmes("brcombine(): if e1 goto e2 else goto e3 => ret e1?e2:e3\n");
                    anychanges++;
                }
            }
            else if (bc == BCgoto && PARSER)
            {
                b2 = list_block(b->Bsucc);
                if (!list_next(b2->Bpred) && b2->BC != BCasm    // if b is only parent
                    && b2 != startblock
#if SCPP
                    && b2->BC != BCtry
#endif
                    && b2->BC != BC_try
                    && b->Btry == b2->Btry
                   )
                {   list_t bl;

                    if (b2->Belem)
                    {
                        if (PARSER)
                        {
                            block_appendexp(b,b2->Belem);
                        }
                        else if (b->Belem)
                            b->Belem = el_bin(OPcomma,b2->Belem->Ety,b->Belem,b2->Belem);
                        else
                            b->Belem = b2->Belem;
                        b2->Belem = NULL;
                    }
                    list_subtract(&b->Bsucc,b2);
                    list_subtract(&b2->Bpred,b);

                    /* change predecessor of successors of b2 from b2 to b */
                    for (bl = b2->Bsucc; bl; bl = list_next(bl))
                    {   list_t bp;

                        for (bp = list_block(bl)->Bpred; bp; bp = list_next(bp))
                        {
                            if (list_block(bp) == b2)
                                list_ptr(bp) = (void *)b;
                        }
                    }

                    b->BC = b2->BC;
                    b->BS = b2->BS;
                    b->Bsucc = b2->Bsucc;
                    b2->Bsucc = NULL;
                    b2->BC = BCret;             /* a harmless one       */
                    cmes3("brcombine(): %p goto %p eliminated\n",b,b2);
                    anychanges++;
                }
            }
        }
        if (anychanges)
        {   go.changes++;
            continue;
        }
    } while (0);
}

/***********************
 * Branch optimization.
 */

STATIC void bropt()
{       block *b,*db;
        elem *n,**pn;

        cmes("bropt()\n");
        assert(!PARSER);
        for (b = startblock; b; b = b->Bnext)   /* for each block       */
        {
                pn = &(b->Belem);
                if (OPTIMIZER && *pn)
                    while ((*pn)->Eoper == OPcomma)
                        pn = &((*pn)->E2);

                n = *pn;
                if (b->BC == BCiftrue)
                {
                        assert(n);
                        /* Replace IF (!e) GOTO ... with        */
                        /* IF OPnot (e) GOTO ...                */
                        if (n->Eoper == OPnot)
                        {
                            tym_t tym;

                            tym = n->E1->Ety;
                            *pn = el_selecte1(n);
                            (*pn)->Ety = tym;
                            for (n = b->Belem; n->Eoper == OPcomma; n = n->E2)
                                n->Ety = tym;
                            b->Bsucc = list_reverse(b->Bsucc);
                            cmes("CHANGE: if (!e)\n");
                            go.changes++;
                        }

                        /* Take care of IF (constant)                   */
                        if (iftrue(n))          /* if elem is TRUE      */
                        {
                            // select first succ
                            db = list_block(list_next(b->Bsucc));
                            goto L1;
                        }
                        else if (iffalse(n))
                        {
                            // select second succ
                            db = list_block(b->Bsucc);

                            L1: list_subtract(&(b->Bsucc),db);
                                list_subtract(&(db->Bpred),b);
                                b->BC = BCgoto;
                                /* delete elem if it has no side effects */
                                b->Belem = doptelem(b->Belem,GOALnone | GOALagain);
                                cmes("CHANGE: if (const)\n");
                                go.changes++;
                        }

                        /* Look for both destinations being the same    */
                        else if (list_block(b->Bsucc) ==
                                 list_block(list_next(b->Bsucc)))
                        {       b->BC = BCgoto;
                                db = list_block(b->Bsucc);
                                list_subtract(&(b->Bsucc),db);
                                list_subtract(&(db->Bpred),b);
                                cmes("CHANGE: if (e) goto L1; else goto L1;\n");
                                go.changes++;
                        }
                }
                else if (b->BC == BCswitch)
                {       /* see we can evaluate this switch now  */
                        unsigned i,ncases;
                        targ_llong *p,value;
                        list_t bl;

                        while (n->Eoper == OPcomma)
                                n = n->E2;
                        if (n->Eoper != OPconst)
                                continue;
                        assert(tyintegral(n->Ety));
                        value = el_tolong(n);
                        p = b->BS.Bswitch;      /* ptr to switch data   */
                        assert(p);
                        ncases = *p++;          /* # of cases           */
                        i = 1;                  /* first case           */
                        while (1)
                        {
                                if (i > ncases)
                                {   i = 0;      /* select default       */
                                    break;
                                }
                                if (*p++ == value)
                                    break;      /* found it             */
                                i++;            /* next case            */
                        }
                        /* the ith entry in Bsucc is the one we want    */
                        db = list_block(list_nth(b->Bsucc,i));
                        /* delete predecessors of successors (!)        */
                        for (bl = b->Bsucc; bl; bl = list_next(bl))
                            if (i--)            // if not ith successor
                            {   void *p;
                                p = list_subtract(
                                    &(list_block(bl)->Bpred),b);
                                assert(p == b);
                            }

                        /* dump old successor list and create a new one */
                        list_free(&b->Bsucc,FPNULL);
                        list_append(&b->Bsucc,db);
                        b->BC = BCgoto;
                        b->Belem = doptelem(b->Belem,GOALnone | GOALagain);
                        cmes("CHANGE: switch (const)\n");
                        go.changes++;
                }
        }
}

/*********************************
 * Do branch rearrangement.
 */

STATIC void brrear()
{       block *b;

        cmes("brrear()\n");
        for (b = startblock; b; b = b->Bnext)   /* for each block       */
        {       list_t bl;

                for (bl = b->Bsucc; bl; bl = list_next(bl))
                {       /* For each transfer of control block pointer   */
                        block *bt;
                        int iter = 0;

                        bt = list_block(bl);

                        /* If it is a transfer to a block that consists */
                        /* of nothing but an unconditional transfer,    */
                        /*      Replace transfer address with that      */
                        /*      transfer address.                       */
                        /* Note: There are certain kinds of infinite    */
                        /* loops which we avoid by putting a lid on     */
                        /* the number of iterations.                    */

                        while (bt->BC == BCgoto && !bt->Belem &&
#if SCPP || NTEXCEPTIONS
                                b->Btry == bt->Btry &&
#endif
#if NTEXCEPTIONS
                                bt->Btry == list_block(bt->Bsucc)->Btry &&
#endif
                                (OPTIMIZER || !(bt->Bsrcpos.Slinnum && configv.addlinenumbers)) &&
                               ++iter < 10)
                        {
                                list_ptr(bl) = list_ptr(bt->Bsucc);
                                if (bt->Bsrcpos.Slinnum && !b->Bsrcpos.Slinnum)
                                    b->Bsrcpos = bt->Bsrcpos;
                                b->Bflags |= bt->Bflags;
                                list_append(&(list_block(bl)->Bpred),b);
                                list_subtract(&(bt->Bpred),b);
                                cmes("goto->goto\n");
                                bt = list_block(bl);
                        }

                        // Bsucc after the first are the targets of
                        // jumps, calls and loops, and as such to do this right
                        // we need to traverse the Bcode list and fix up
                        // the IEV2.Vblock pointers.
                        if (b->BC == BCasm)
                            break;
                }
#if 0
                /* Replace cases of                     */
                /*      IF (e) GOTO L1 ELSE L2          */
                /*      L1:                             */
                /* with                                 */
                /*      IF OPnot (e) GOTO L2 ELSE L1    */
                /*      L1:                             */

                if (b->BC == BCiftrue || b->BC == BCiffalse)
                {       block *bif,*belse;

                        bif = list_block(b->Bsucc);
                        belse = list_block(list_next(b->Bsucc));

                        if (bif == b->Bnext)
                        {       b->BC ^= BCiffalse ^ BCiftrue;  /* toggle */
                                list_ptr(b->Bsucc) = belse;
                                list_ptr(list_next(b->Bsucc)) = bif;
                                b->Bflags |= bif->Bflags & BFLvisited;
                                cmes("if (e) L1 else L2\n");
                        }
                }
#endif
        } /* for */
}

/*************************
 * Compute depth first order (DFO).
 * Equivalent to Aho & Ullman Fig. 13.8.
 * Blocks not in dfo[] are unreachable.
 */

void compdfo()
{
  int i;

  cmes("compdfo()\n");
  assert(OPTIMIZER);
  block_clearvisit();
#ifdef DEBUG
  if (maxblks == 0 || maxblks < numblks)
        dbg_printf("maxblks = %d, numblks = %d\n",maxblks,numblks);
#endif
  assert(maxblks && maxblks >= numblks);
  debug_assert(!PARSER);
  if (!dfo)
#if TX86
        dfo = (block **) util_calloc(sizeof(block *),maxblks);
#else
        dfo = (block **) MEM_PARF_CALLOC(sizeof(block *) * maxblks);
#endif
  dfotop = numblks;                     /* assign numbers backwards     */
  search(startblock);
  assert(dfotop <= numblks);
  /* Ripple data to the bottom of the array     */
  if (dfotop)                           /* if not at bottom             */
  {     for (i = 0; i < numblks - dfotop; i++)
        {       dfo[i] = dfo[i + dfotop];
                dfo[i]->Bdfoidx = i;
        }
  }
  dfotop = numblks - dfotop;
#if 0
  for (i = 0; i < dfotop; i++)
        dbg_printf("dfo[%d] = 0x%x\n",i,dfo[i]);
#endif
}

/******************************
 * Add block to dfo[], then its successors.
 */

STATIC void search(block *b)
{ list_t l;

  assert(b);
  b->Bflags |= BFLvisited;              // executed at least once
  for (l = b->Bsucc; l; l = list_next(l))               // for each successor
  {     block *bs = list_block(l);

        assert(bs);
        if ((bs->Bflags & BFLvisited) == 0) // if not visited
            search(bs);                 // search it
  }
  dfo[--dfotop] = b;                    // add to dfo[]
  b->Bdfoidx = dfotop;                  // link back
}

/*************************
 * Remove blocks not marked as visited (they aren't in dfo[]).
 * A block is not in dfo[] if not visited.
 */

STATIC void elimblks()
{   block **pb,*b;
    list_t s;
    block *bf;

#ifdef DEBUG
    if (OPTIMIZER)
    {   int n;

        n = 0;
        for (b = startblock; b; b = b->Bnext)
              n++;
        //dbg_printf("1 n = %d, numblks = %d, dfotop = %d\n",n,numblks,dfotop);
        assert(numblks == n);
    }
#endif

    cmes("elimblks()\n");
    bf = NULL;
    for (pb = &startblock; (b = *pb) != NULL;)
    {
        if (((b->Bflags & BFLvisited) == 0)  /* if block is not visited */
            && ((b->Bflags & BFLlabel) == 0)    /* need label offset    */
            )
        {
                /* for each marked successor S to b                     */
                /*      remove b from S.Bpred.                          */
                /* Presumably all predecessors to b are unmarked also.  */
                for (s = b->Bsucc; s; s = list_next(s))
                {   assert(list_block(s));
                    if (list_block(s)->Bflags & BFLvisited) /* if it is marked */
                        list_subtract(&(list_block(s)->Bpred),b);
                }
                if (b->Balign && b->Bnext && b->Balign > b->Bnext->Balign)
                    b->Bnext->Balign = b->Balign;
                *pb = b->Bnext;         /* remove from linked list      */

                b->Bnext = bf;
                bf = b;                 /* prepend to deferred list to free */
                cmes2("CHANGE: block %p deleted\n",b);
                go.changes++;
        }
        else
                pb = &((*pb)->Bnext);
    }

    // Do deferred free's of the blocks
    for ( ; bf; bf = b)
    {   b = bf->Bnext;
        block_free(bf);
        numblks--;
    }

    cmes("elimblks done\n");
    assert(!OPTIMIZER || numblks == dfotop);
}

/**********************************
 * Merge together blocks where the first block is a goto to the next
 * block and the next block has only the first block as a predecessor.
 * Example:
 *      e1; GOTO L2;
 *      L2: return e2;
 * becomes:
 *      L2: return (e1 , e2);
 * Returns:
 *      # of merged blocks
 */

STATIC int mergeblks()
{       int merge = 0,i;

        assert(OPTIMIZER);
        cmes("mergeblks()\n");
        for (i = 0; i < dfotop; i++)
        {       block *b;

                b = dfo[i];
                if (b->BC == BCgoto)
                {   block *bL2 = list_block(b->Bsucc);

                    if (b == bL2)
                    {
                Lcontinue:
                        continue;
                    }
                    assert(bL2->Bpred);
                    if (!list_next(bL2->Bpred) && bL2 != startblock)
                    {   list_t bl;
                        elem *e;

                        if (b == bL2 || bL2->BC == BCasm)
                            continue;

                        if (
#if SCPP
                            bL2->BC == BCtry ||
#endif
                            bL2->BC == BC_try ||
                            b->Btry != bL2->Btry)
                            continue;
#if SCPP
                        // If any predecessors of b are BCasm, don't merge.
                        for (bl = b->Bpred; bl; bl = list_next(bl))
                        {
                            if (list_block(bl)->BC == BCasm)
                                goto Lcontinue;
                        }
#endif

                        /* JOIN the elems               */
                        e = el_combine(b->Belem,bL2->Belem);
                        if (b->Belem && bL2->Belem)
                            e = doptelem(e,bc_goal[bL2->BC] | GOALagain);
                        bL2->Belem = e;
                        b->Belem = NULL;

                        /* Remove b from predecessors of bL2    */
                        list_free(&(bL2->Bpred),FPNULL);
                        bL2->Bpred = b->Bpred;
                        b->Bpred = NULL;
                        /* Remove bL2 from successors of b      */
                        list_free(&b->Bsucc,FPNULL);

                        /* fix up successor list of predecessors        */
                        for (bl = bL2->Bpred; bl; bl = list_next(bl))
                        {   list_t bs;

                            for (bs=list_block(bl)->Bsucc; bs; bs=list_next(bs))
                                if (list_block(bs) == b)
                                    list_ptr(bs) = (void *)bL2;
                        }

                        merge++;
                        cmes3("block %p merged with %p\n",b,bL2);

                        if (b == startblock)
                        {   /* bL2 is the new startblock */
                            block **pb;

                            cmes("bL2 is new startblock\n");
                            /* Remove bL2 from list of blocks   */
                            for (pb = &startblock; 1; pb = &(*pb)->Bnext)
                            {   assert(*pb);
                                if (*pb == bL2)
                                {   *pb = bL2->Bnext;
                                    break;
                                }
                            }

                            /* And relink bL2 at the start              */
                            bL2->Bnext = startblock->Bnext;
                            startblock = bL2;   /* new start            */

                            block_free(b);
                            numblks--;
                            break;              /* dfo[] is now invalid */
                        }
                    }
                }
        }
        return merge;
}

/*******************************
 * Combine together blocks that are identical.
 */

STATIC void blident()
{   block *bn;
    block *bnext;

    cmes("blident()\n");
    assert(startblock);

#if SCPP
    // Determine if any asm blocks
    int anyasm = 0;
    for (bn = startblock; bn; bn = bn->Bnext)
    {   if (bn->BC == BCasm)
        {   anyasm = 1;
            break;
        }
    }
#endif

    for (bn = startblock; bn; bn = bnext)
    {   block *b;

        bnext = bn->Bnext;
        if (bn->Bflags & BFLnomerg)
            continue;

        for (b = bnext; b; b = b->Bnext)
        {
            /* Blocks are identical if:                 */
            /*  BC match                                */
            /*  not optimized for time or it's a return */
            /*      (otherwise looprotate() is undone)  */
            /*  successors match                        */
            /*  elems match                             */
            if (b->BC == bn->BC &&
                //(!OPTIMIZER || !(go.mfoptim & MFtime) || !b->Bsucc) &&
                (!OPTIMIZER || !(b->Bflags & BFLnomerg) || !b->Bsucc) &&
                list_equal(b->Bsucc,bn->Bsucc) &&
#if SCPP || NTEXCEPTIONS
                b->Btry == bn->Btry &&
#endif
                el_match(b->Belem,bn->Belem)
               )
            {   /* Eliminate block bn           */
                list_t bl;

                switch (b->BC)
                {
                    case BCswitch:
                        if (memcmp(b->BS.Bswitch,bn->BS.Bswitch,list_nitems(bn->Bsucc) * sizeof(*bn->BS.Bswitch)))
                            continue;
                        break;

#if SCPP
                    case BCtry:
                    case BCcatch:
#endif
#if MARS
                    case BCjcatch:
#endif
                    case BC_try:
                    case BC_finally:
                    case BCasm:
                    Lcontinue:
                        continue;
                }
                assert(!b->Bcode);

                for (bl = bn->Bpred; bl; bl = list_next(bl))
                {   block *bp;

                    bp = list_block(bl);
                    if (bp->BC == BCasm)
                        // Can't do this because of jmp's and loop's
                        goto Lcontinue;
                }

#if 0 && SCPP
                // Predecessors must all be at the same btry level.
                if (bn->Bpred)
                {   block *bp;

                    bp = list_block(bn->Bpred);
                    btry = bp->Btry;
                    if (bp->BC == BCtry)
                        btry = bp;
                }
                else
                    btry = NULL;

                for (bl = b->Bpred; bl; bl = list_next(bl))
                {   block *bp;

                    bp = list_block(bl);
                    if (bp->BC != BCtry)
                        bp = bp->Btry;
                    if (btry != bp)
                        goto Lcontinue;
                }
#endif

                // if bn is startblock, eliminate b instead of bn
                if (bn == startblock)
                {
                    goto Lcontinue;     // can't handle predecessors to startblock
                    bn = b;
                    b = startblock;             /* swap b and bn        */
                }

#if SCPP
                // Don't do it if any predecessors are ASM blocks, since
                // we'd have to walk the code list to fix up any jmps.
                if (anyasm)
                {
                    for (bl = bn->Bpred; bl; bl = list_next(bl))
                    {   list_t bls;
                        block *bp;

                        bp = list_block(bl);
                        if (bp->BC == BCasm)
                            goto Lcontinue;
                        for (bls=bp->Bsucc; bls; bls=list_next(bls))
                            if (list_block(bls) == bn &&
                                list_block(bls)->BC == BCasm)
                                goto Lcontinue;
                    }
                }
#endif

                /* Change successors to predecessors of bn to point to  */
                /* b instead of bn                                      */
                for (bl = bn->Bpred; bl; bl = list_next(bl))
                {   list_t bls;
                    block *bp;

                    bp = list_block(bl);
                    for (bls=bp->Bsucc; bls; bls=list_next(bls))
                        if (list_block(bls) == bn)
                        {   list_ptr(bls) = (void *)b;
                            list_prepend(&b->Bpred,bp);
                        }
                }

                /* Entirely remove predecessor list from bn.            */
                /* elimblks() will delete bn entirely.                  */
                list_free(&(bn->Bpred),FPNULL);

#ifdef DEBUG
                assert(bn->BC != BCcatch);
                if (debugc)
                    dbg_printf("block B%d (%p) removed, it was same as B%d (%p)\n",
                        bn->Bdfoidx,bn,b->Bdfoidx,b);
#endif
                go.changes++;
                break;
            }
        }
    }
}

/**********************************
 * Split out return blocks so the returns can be combined into a
 * single block by blident().
 */

STATIC void blreturn()
{
    if (!(go.mfoptim & MFtime))            /* if optimized for space       */
    {
        int retcount;                   /* number of return counts      */
        block *b;

        retcount = 0;

        /* Find last return block       */
        for (b = startblock; b; b = b->Bnext)
        {   if (b->BC == BCret)
                retcount++;
            if (b->BC == BCasm)
                return;                 // mucks up blident()
        }

        if (retcount < 2)               /* quit if nothing to combine   */
            return;

        /* Split return blocks  */
        for (b = startblock; b; b = b->Bnext)
        {   if (b->BC != BCret)
                continue;
#if SCPP || NTEXCEPTIONS
            // If no other blocks with the same Btry, don't split
#if SCPP
            if (config.flags3 & CFG3eh)
#endif
            {
                for (block *b2 = startblock; b2; b2 = b2->Bnext)
                {
                    if (b2->BC == BCret && b != b2 && b->Btry == b2->Btry)
                        goto L1;
                }
                continue;
            }
        L1: ;
#endif
            if (b->Belem)
            {   /* Split b into a goto and a b  */
                block *bn;

#ifdef DEBUG
                if (debugc)
                    dbg_printf("blreturn: splitting block B%d\n",b->Bdfoidx);
#endif
                numblks++;
                bn = block_calloc();
                bn->BC = BCret;
                bn->Bnext = b->Bnext;
#if SCPP || NTEXCEPTIONS
                bn->Btry = b->Btry;
#endif
                b->BC = BCgoto;
                b->Bnext = bn;
                list_append(&b->Bsucc,bn);
                list_append(&bn->Bpred,b);

                b = bn;
            }
        }

        blident();                      /* combine return blocks        */
    }
}

/*****************************************
 * Convert expression into a list.
 * Construct the list in reverse, that is, so that the right-most
 * expression occurs first in the list.
 */

STATIC list_t bl_enlist(elem *e)
{   list_t el = NULL;

    if (e)
    {
        elem_debug(e);
        if (e->Eoper == OPcomma)
        {   list_t el2;
            list_t pl;

            el2 = bl_enlist(e->E1);
            el = bl_enlist(e->E2);
            e->E1 = e->E2 = NULL;
            el_free(e);

            /* Append el2 list to el    */
            assert(el);
            for (pl = el; list_next(pl); pl = list_next(pl))
                ;
            list_next(pl) = el2;
        }
        else
            list_prepend(&el,e);
    }
    return el;
}

/*****************************************
 * Take a list of expressions and convert it back into an expression tree.
 */

STATIC elem * bl_delist(list_t el)
{   elem *e;
    list_t elstart = el;

    for (e = NULL; el; el = list_next(el))
        e = el_combine(list_elem(el),e);
    list_free(&elstart,FPNULL);
    return e;
}

/*****************************************
 * Do tail merging.
 */

STATIC void bltailmerge()
{
    cmes("bltailmerge()\n");
    assert(!PARSER && OPTIMIZER);
    if (!(go.mfoptim & MFtime))            /* if optimized for space       */
    {
        block *b;
        block *bn;
        list_t bl;
        elem *e;
        elem *en;

        /* Split each block into a reversed linked list of elems        */
        for (b = startblock; b; b = b->Bnext)
            b->Blist = bl_enlist(b->Belem);

        /* Search for two blocks that have the same successor list.
           If the first expressions both lists are the same, split
           off a new block with that expression in it.
         */
        for (b = startblock; b; b = b->Bnext)
        {
            if (!b->Blist)
                continue;
            e = list_elem(b->Blist);
            elem_debug(e);
            for (bn = b->Bnext; bn; bn = bn->Bnext)
            {
                if (b->BC == bn->BC &&
                    list_equal(b->Bsucc,bn->Bsucc) &&
                    bn->Blist &&
                    el_match(e,(en = list_elem(bn->Blist)))
#if SCPP || NTEXCEPTIONS
                    && b->Btry == bn->Btry
#endif
                   )
                {
                    switch (b->BC)
                    {
                        case BCswitch:
                            if (memcmp(b->BS.Bswitch,bn->BS.Bswitch,list_nitems(bn->Bsucc) * sizeof(*bn->BS.Bswitch)))
                                continue;
                            break;

#if SCPP
                        case BCtry:
                        case BCcatch:
#endif
#if MARS
                        case BCjcatch:
#endif
                        case BC_try:
                        case BC_finally:
                        case BCasm:
                            continue;
                    }

                    /* We've got a match        */
                    block *bnew;

                    /*  Create a new block, bnew, which will be the
                        merged block. Physically locate it just after bn.
                     */
#ifdef DEBUG
                    if (debugc)
                        dbg_printf("tail merging: %p and %p\n", b, bn);
#endif
                    numblks++;
                    bnew = block_calloc();
                    bnew->Bnext = bn->Bnext;
                    bnew->BC = b->BC;
#if SCPP || NTEXCEPTIONS
                    bnew->Btry = b->Btry;
#endif
                    if (bnew->BC == BCswitch)
                    {
                        bnew->BS.Bswitch = b->BS.Bswitch;
                        b->BS.Bswitch = NULL;
                        bn->BS.Bswitch = NULL;
                    }
                    bn->Bnext = bnew;

                    /* The successor list to bnew is the same as b's was */
                    bnew->Bsucc = b->Bsucc;
                    b->Bsucc = NULL;
                    list_free(&bn->Bsucc,FPNULL);

                    /* Update the predecessor list of the successor list
                        of bnew, from b to bnew, and removing bn
                     */
                    for (bl = bnew->Bsucc; bl; bl = list_next(bl))
                    {
                        list_subtract(&list_block(bl)->Bpred,b);
                        list_subtract(&list_block(bl)->Bpred,bn);
                        list_append(&list_block(bl)->Bpred,bnew);
                    }

                    /* The predecessors to bnew are b and bn    */
                    list_append(&bnew->Bpred,b);
                    list_append(&bnew->Bpred,bn);

                    /* The successors to b and bn are bnew      */
                    b->BC = BCgoto;
                    bn->BC = BCgoto;
                    list_append(&b->Bsucc,bnew);
                    list_append(&bn->Bsucc,bnew);

                    go.changes++;

                    /* Find all the expressions we can merge    */
                    do
                    {
                        list_append(&bnew->Blist,e);
                        el_free(en);
                        list_pop(&b->Blist);
                        list_pop(&bn->Blist);
                        if (!b->Blist)
                            goto nextb;
                        e = list_elem(b->Blist);
                        if (!bn->Blist)
                            break;
                        en = list_elem(bn->Blist);
                    } while (el_match(e,en));
                }
            }
    nextb:  ;
        }

        /* Recombine elem lists into expression trees   */
        for (b = startblock; b; b = b->Bnext)
            b->Belem = bl_delist(b->Blist);
    }
}

/**********************************
 * Rearrange blocks to minimize jmp's.
 */

STATIC void brmin()
{   block *b;
    block *bnext;
    list_t bl,blp;

#if SCPP
    // Dunno how this may mess up generating EH tables.
    if (config.flags3 & CFG3eh)         // if EH turned on
        return;
#endif

    cmes("brmin()\n");
    debug_assert(startblock);
    for (b = startblock->Bnext; b; b = b->Bnext)
    {
        bnext = b->Bnext;
        if (!bnext)
            break;
        for (bl = b->Bsucc; bl; bl = list_next(bl))
        {   block *bs;

            bs = list_block(bl);
            if (bs == bnext)
                goto L1;
        }

        // b is a block which does not have bnext as a successor.
        // Look for a successor of b for which everyone must jmp to.

        for (bl = b->Bsucc; bl; bl = list_next(bl))
        {   block *bs;
            block *bn;

            bs = list_block(bl);
            for (blp = bs->Bpred; blp; blp = list_next(blp))
            {   block *bsp;

                bsp = list_block(blp);
                if (bsp->Bnext == bs)
                    goto L2;
            }

            // Move bs so it is the Bnext of b
            for (bn = bnext; 1; bn = bn->Bnext)
            {
                if (!bn)
                    goto L2;
                if (bn->Bnext == bs)
                    break;
            }
#if 1
            bn->Bnext = NULL;
            b->Bnext = bs;
            for (bn = bs; bn->Bnext; bn = bn->Bnext)
                ;
            bn->Bnext = bnext;
#else
            bn->Bnext = bs->Bnext;
            bs->Bnext = bnext;
            b->Bnext = bs;
#endif
            cmes3("Moving block %p to appear after %p\n",bs,b);
            go.changes++;
            break;

        L2: ;
        }


    L1: ;
    }
}

/********************************
 * Check integrity of blocks.
 */

#if 0

STATIC void block_check()
{   block *b;
    list_t bl;

    for (b = startblock; b; b = b->Bnext)
    {   int nsucc;
        int npred;

        nsucc = list_nitems(b->Bsucc);
        npred = list_nitems(b->Bpred);
        switch (b->BC)
        {
            case BCgoto:
                assert(nsucc == 1);
                break;
            case BCiftrue:
                assert(nsucc == 2);
                break;
        }

        for (bl = b->Bsucc; bl; bl = list_next(bl))
        {   block *bs = list_block(bl);
            list_t bls;

            for (bls = bs->Bpred; 1; bls = list_next(bls))
            {
                assert(bls);
                if (list_block(bls) == b)
                    break;
            }
        }
    }
}

#endif

/***************************************
 * Do tail recursion.
 */

STATIC void brtailrecursion()
{   block *b;
    block *bs;
    elem **pe;

#if SCPP
//    if (tyvariadic(funcsym_p->Stype))
        return;
    return;             // haven't dealt with struct params, and ctors/dtors
#endif
    if (funcsym_p->Sfunc->Fflags3 & Fnotailrecursion)
        return;
    if (localgot)
    {   /* On OSX, tail recursion will result in two OPgot's:
            int status5;
            struct MyStruct5 { }
            void rec5(int i, MyStruct5 s)
            {
                if( i > 0 )
                {   status5++;
                    rec5(i-1, s);
                }
            }
        */

        return;
    }
    for (b = startblock; b; b = b->Bnext)
    {
        if (b->BC == BC_try)
            return;
        pe = &b->Belem;
        block *bn = NULL;
        if (*pe &&
            (b->BC == BCret ||
             b->BC == BCretexp ||
             (b->BC == BCgoto && (bn = list_block(b->Bsucc))->Belem == NULL &&
              bn->BC == BCret)
            )
           )
        {   elem *e;

            if (el_anyframeptr(*pe))
                return;
            while ((*pe)->Eoper == OPcomma)
                pe = &(*pe)->E2;
            e = *pe;
            if (OTcall(e->Eoper) &&
                e->E1->Eoper == OPvar &&
                e->E1->EV.sp.Vsym == funcsym_p)
            {
//printf("before:\n");
//elem_print(*pe);
                if (OTunary(e->Eoper))
                {   *pe = el_long(TYint,0);
                }
                else
                {   int si = 0;
                    elem *e2 = NULL;
                    *pe = assignparams(&e->E2,&si,&e2);
                    *pe = el_combine(*pe,e2);
                }
                el_free(e);
//printf("after:\n");
//elem_print(*pe);

                if (b->BC == BCgoto)
                {   list_subtract(&b->Bsucc,bn);
                    list_subtract(&bn->Bpred,b);
                }
                b->BC = BCgoto;
                list_append(&b->Bsucc,startblock);
                list_append(&startblock->Bpred,b);

                // Create a new startblock, bs, because startblock cannot
                // have predecessors.
                numblks++;
                bs = block_calloc();
                bs->BC = BCgoto;
                bs->Bnext = startblock;
                list_append(&bs->Bsucc,startblock);
                list_append(&startblock->Bpred,bs);
                startblock = bs;

                cmes("tail recursion\n");
                go.changes++;
                return;
            }
        }
    }
}

/*****************************************
 * Convert parameter expression to assignment statements.
 */

STATIC elem * assignparams(elem **pe,int *psi,elem **pe2)
{
    elem *e = *pe;

    if (e->Eoper == OPparam)
    {   elem *ea = NULL;
        elem *eb = NULL;
        elem *e2 = assignparams(&e->E2,psi,&eb);
        elem *e1 = assignparams(&e->E1,psi,&ea);
        e->E1 = NULL;
        e->E2 = NULL;
        e = el_combine(e1,e2);
        *pe2 = el_combine(eb,ea);
    }
    else
    {   int si = *psi;
        Symbol *sp;
        Symbol *s;
        int op;
        elem *es;
        type *t;

        assert(si < globsym.top);
        sp = globsym.tab[si];
        s = symbol_genauto(sp->Stype);
        s->Sfl = FLauto;
        op = OPeq;
        if (e->Eoper == OPstrpar)
        {
            op = OPstreq;
            t = e->ET;
            elem *ex = e;
            e = e->E1;
            ex->E1 = NULL;
            el_free(ex);
        }
        es = el_var(s);
        es->Ety = e->Ety;
        e = el_bin(op,TYvoid,es,e);
        if (op == OPstreq)
            e->ET = t;
        *pe2 = el_bin(op,TYvoid,el_var(sp),el_copytree(es));
        (*pe2)->E1->Ety = es->Ety;
        if (op == OPstreq)
            (*pe2)->ET = t;
        *psi = ++si;
        *pe = NULL;
    }
    return e;
}

/****************************************************
 * Eliminate empty loops.
 */

STATIC void emptyloops()
{
    block *b;

    cmes("emptyloops()\n");
    for (b = startblock; b; b = b->Bnext)
    {
        if (b->BC == BCiftrue &&
            list_block(b->Bsucc) == b &&
            list_nitems(b->Bpred) == 2)
        {   block *bpred;
            elem *einit;
            elem *erel;
            elem *einc;

            // Find predecessor to b
            bpred = list_block(b->Bpred);
            if (bpred == b)
                bpred = list_block(list_next(b->Bpred));
            if (!bpred->Belem)
                continue;

            // Find einit
            for (einit = bpred->Belem; einit->Eoper == OPcomma; einit = einit->E2)
                ;
            if (einit->Eoper != OPeq ||
                einit->E2->Eoper != OPconst ||
                einit->E1->Eoper != OPvar)
                continue;

#if 1
            // Look for ((i += 1) < limit)
            erel = b->Belem;
            if (erel->Eoper != OPlt ||
                erel->E2->Eoper != OPconst ||
                erel->E1->Eoper != OPaddass)
                continue;

            einc = erel->E1;
            if (einc->E2->Eoper != OPconst ||
                einc->E1->Eoper != OPvar ||
                !el_match(einc->E1,einit->E1))
                continue;

            if (!tyintegral(einit->E1->Ety) ||
                el_tolong(einc->E2) != 1 ||
                el_tolong(einit->E2) >= el_tolong(erel->E2)
               )
                continue;

             {
                erel->Eoper = OPeq;
                erel->Ety = erel->E1->Ety;
                erel->E1 = el_selecte1(erel->E1);
                b->BC = BCgoto;
                list_subtract(&b->Bsucc,b);
                list_subtract(&b->Bpred,b);
#ifdef DEBUG
                if (debugc)
                {   WReqn(erel);
                    dbg_printf(" eliminated loop\n");
                }
#endif
                go.changes++;
             }
#else
            // Find einc and erel
            if (b->Belem->Eoper != OPcomma)
                continue;
            einc = b->Belem->E1;
            erel = b->Belem->E2;
            if (einc->Eoper != OPaddass ||
                einc->E1->Eoper != OPvar ||
                einc->E2->Eoper != OPconst ||
                erel->Eoper != OPlt ||
                erel->E1->Eoper != OPvar ||
                erel->E2->Eoper != OPconst ||
                !el_match(einit->E1,einc->E1) ||
                !el_match(einit->E1,erel->E1)
               )
                continue;

            if (!tyintegral(einit->E1->Ety) ||
                el_tolong(einc->E2) != 1 ||
                el_tolong(einit->E2) >= el_tolong(erel->E2)
               )
                continue;

             {
                erel->Eoper = OPeq;
                erel->Ety = erel->E1->Ety;
                b->BC = BCgoto;
                list_subtract(&b->Bsucc,b);
                list_subtract(&b->Bpred,b);
#ifdef DEBUG
                if (debugc)
                {   WReqn(erel);
                    dbg_printf(" eliminated loop\n");
                }
#endif
                go.changes++;
             }
#endif
        }
    }
}

/******************************************
 * Determine if function has any side effects.
 * This means, determine if all the function does is return a value;
 * no extraneous definitions or effects or exceptions.
 * A function with no side effects can be CSE'd. It does not reference
 * statics or indirect references.
 */

STATIC int funcsideeffect_walk(elem *e);

void funcsideeffects()
{
#if MARS
    block *b;

    //printf("funcsideeffects('%s')\n",funcsym_p->Sident);
    for (b = startblock; b; b = b->Bnext)
    {
        if (b->Belem && funcsideeffect_walk(b->Belem))
            goto Lside;
    }

Lnoside:
    funcsym_p->Sfunc->Fflags3 |= Fnosideeff;
    //printf("  function '%s' has no side effects\n",funcsym_p->Sident);
    //return;

Lside:
    //printf("  function '%s' has side effects\n",funcsym_p->Sident);
    ;
#endif
}

#if MARS

STATIC int funcsideeffect_walk(elem *e)
{   int op;
    Symbol *s;

    assert(e);
    elem_debug(e);
    if (typemask(e) & mTYvolatile)
        goto Lside;
    op = e->Eoper;
    switch (op)
    {
        case OPcall:
        case OPucall:
            if (e->E1->Eoper == OPvar &&
                tyfunc((s = e->E1->EV.sp.Vsym)->Stype->Tty) &&
                ((s->Sfunc && s->Sfunc->Fflags3 & Fnosideeff) || s == funcsym_p)
               )
                break;
            goto Lside;

        // Note: we should allow assignments to local variables as
        // not being a 'side effect'.

        default:
            assert(op < OPMAX);
            return OTsideff(op) ||
                (OTunary(op) && funcsideeffect_walk(e->E1)) ||
                (OTbinary(op) && (funcsideeffect_walk(e->E1) ||
                                  funcsideeffect_walk(e->E2)));
    }
    return 0;

  Lside:
    return 1;
}

#endif

/*******************************
 * Determine if there are any OPframeptr's in the tree.
 */

int el_anyframeptr(elem *e)
{
    while (1)
    {
        if (OTunary(e->Eoper))
            e = e->E1;
        else if (OTbinary(e->Eoper))
        {   if (el_anyframeptr(e->E2))
                return 1;
            e = e->E1;
        }
        else if (e->Eoper == OPframeptr)
            return 1;
        else
            break;
    }
    return 0;
}


#endif //!SPP
