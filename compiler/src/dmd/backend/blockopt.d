/**
 * Manipulating basic blocks and their edges.
 *
 * Copyright:   Copyright (C) 1986-1997 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/blockopt.d, backend/blockopt.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_blockopt.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/blockopt.d
 */

module dmd.backend.blockopt;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.time;
import core.stdc.stdlib;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.oper;
import dmd.backend.dlist;
import dmd.backend.dvec;
import dmd.backend.el;
import dmd.backend.mem;
import dmd.backend.type;
import dmd.backend.global;
import dmd.backend.goh;
import dmd.backend.code;
import dmd.backend.ty;

import dmd.backend.barray;

static if (NTEXCEPTIONS)
    enum SCPP_OR_NTEXCEPTIONS = true;
else
    enum SCPP_OR_NTEXCEPTIONS = false;

nothrow:
@safe:

import dmd.backend.gflow : util_realloc;

struct BlockOpt
{
    block* startblock;      // beginning block of function
                            // (can have no predecessors)

    Barray!(block*) dfo;    // array of depth first order

    block* curblock;        // current block being read in
    block* block_last;      // last block read in

    block* block_freelist;

    block blkzero;          // storage allocator
}

__gshared BlockOpt bo;

@trusted
pragma(inline, true) block* block_calloc_i()
{
    block* b;

    if (bo.block_freelist)
    {
        b = bo.block_freelist;
        bo.block_freelist = b.Bnext;
        *b = bo.blkzero;
    }
    else
        b = cast(block*) mem_calloc(block.sizeof);
    return b;
}

block* block_calloc()
{
    return block_calloc_i();
}

/*********************************
 */

Goal bc_goal(BC bc)
{
    switch (bc)
    {
        case BC.goto_: return Goal.none;
        case BC.ret: return Goal.none;
        case BC.exit: return Goal.none;
        case BC.iftrue: return Goal.flags;
        default: return Goal.value;
    }
}

/*********************************
 */

@trusted
void block_term()
{
    while (bo.block_freelist)
    {
        block* b = bo.block_freelist.Bnext;
        mem_free(bo.block_freelist);
        bo.block_freelist = b;
    }
}

/**************************
 * Finish up this block and start the next one.
 */

@trusted
void block_next(BlockState* bctx, BC bc, block* bn)
{
    bctx.curblock.bc = bc;
    bo.block_last = bctx.curblock;
    if (!bn)
        bn = block_calloc_i();
    bctx.curblock.Bnext = bn;                // next block
    bctx.curblock = bctx.curblock.Bnext;     // new current block
    bctx.curblock.Btry = bctx.tryblock;
    bctx.curblock.Bflags |= bctx.flags;
}

/**************************
 * Finish up this block and start the next one.
 */

block* block_goto(BlockState* bx, BC bc, block* bn)
{
    block* b;

    b = bx.curblock;
    block_next(bx,bc,bn);
    b.appendSucc(bx.curblock);
    return bx.curblock;
}

/****************************
 * Goto a block named gotolbl.
 * Start a new block that is labelled by newlbl.
 */

version (COMPILE)
{

void block_goto()
{
    block_goto(block_calloc());
}

void block_goto(block* bn)
{
    block_goto(bn,bn);
}

void block_goto(block* bgoto,block* bnew)
{
    BC bc;

    assert(bgoto);
    curblock.appendSucc(bgoto);
    if (curblock.Bcode)         // If there is already code in the block
                                // then this is an ASM block
        bc = BC.asm_;
    else
        bc = BC.goto_;            // fall thru to next block
    block_next(bc,bnew);
}

}

/**********************************
 * Replace block numbers with block pointers.
 */

@trusted
void block_ptr()
{
    //printf("block_ptr()\n");

    uint numblks = 0;
    for (block* b = bo.startblock; b; b = b.Bnext)       /* for each block        */
    {
        b.Bblknum = numblks;
        numblks++;
    }
}

/*******************************
 * Build predecessor list (Bpred) for each block.
 */

@trusted
void block_pred()
{
    //printf("block_pred()\n");
    for (block* b = bo.startblock; b; b = b.Bnext)       // for each block
        list_free(&b.Bpred,FPNULL);

    for (block* b = bo.startblock; b; b = b.Bnext)       // for each block
    {
        //printf("b = %p, BC = %s\n", b, bc_str(b.bc));
        foreach (bp; ListRange(b.Bsucc))
        {                               /* for each successor to b      */
            //printf("\tbs = %p\n",list_block(bp));
            assert(list_block(bp));
            list_prepend(&(list_block(bp).Bpred),b);
        }
    }
    assert(bo.startblock.Bpred == null);  /* startblock has no preds      */
}

/********************************************
 * Clear visit.
 */

@trusted
void block_clearvisit()
{
    for (block* b = bo.startblock; b; b = b.Bnext)       // for each block
        b.Bflags = cast(BFL)(b.Bflags & ~cast(uint)BFL.visited); // mark as unvisited
}

/********************************************
 * Visit block and each of its predecessors.
 */

void block_visit(block* b)
{
    b.Bflags |= BFL.visited;
    foreach (l; ListRange(b.Bsucc))
    {
        block* bs = list_block(l);
        assert(bs);
        if ((bs.Bflags & BFL.visited) == 0)     // if not visited
            block_visit(bs);
    }
}

/*****************************
 * Compute number of parents (Bcount) of each basic block.
 */
@trusted
void block_compbcount(ref GlobalOptimizer go)
{
    block_clearvisit();
    block_visit(bo.startblock);                    // visit all reachable blocks
    elimblks(go);                               // eliminate unvisited blocks
}

/*******************************
 * Free list of blocks.
 */

void blocklist_free(block** pb)
{
    block* bn;
    for (block* b = *pb; b; b = bn)
    {
        bn = b.Bnext;
        block_free(b);
    }
    *pb = null;
}

/********************************
 * Free optimizer gathered data.
 */

@trusted
void block_optimizer_free(block* b)
{
    static void vfree(ref vec_t v) { vec_free(v); v = null; }
    vfree(b.Bdom);
    vfree(b.Binrd);
    vfree(b.Boutrd);
    vfree(b.Binlv);
    vfree(b.Boutlv);
    vfree(b.Bin);
    vfree(b.Bout);
    vfree(b.Bgen);
    vfree(b.Bkill);
    vfree(b.Bout2);
    vfree(b.Bgen2);
    vfree(b.Bkill2);

    // memset(&b->_BLU,0,sizeof(b->_BLU));
}

/****************************
 * Free a block.
 */

@trusted
void block_free(block* b)
{
    assert(b);
    if (b.Belem)
        el_free(b.Belem);
    list_free(&b.Bsucc,FPNULL);
    list_free(&b.Bpred,FPNULL);
    if (OPTIMIZER)
        block_optimizer_free(b);
    switch (b.bc)
    {
        case BC.switch_:
        case BC.ifthen:
        case BC.jmptab:
            free(b.Bswitch.ptr);
            break;

        case BC.jcatch:
            if (b.actionTable)
            {
                b.actionTable.dtor();
                free(b.actionTable);
            }
            break;

        case BC.asm_:
            code_free(b.Bcode);
            break;

        default:
            break;
    }
    b.Bnext = bo.block_freelist;
    bo.block_freelist = b;
}

/****************************
 * Append elem to the elems comprising the current block.
 * Read in an expression and put it in curblock.Belem.
 * If there is one already there, create a tree like:
 *              ,
 *             / \
 *           old  e
 */

@trusted
void block_appendexp(block* b,elem* e)
{
    if (e)
    {
        assert(b);
        elem_debug(e);
        elem** pe = &b.Belem;
        elem* ec = *pe;
        if (ec != null)
        {
            type* t = e.ET;

            if (t)
                type_debug(t);
            elem_debug(e);
            tym_t ty = e.Ety;

            elem_debug(e);
            /* Build tree such that (a,b) => (a,(b,e))  */
            while (ec.Eoper == OPcomma)
            {
                ec.Ety = ty;
                ec.ET = t;
                pe = &(ec.E2);
                ec = *pe;
            }
            e = el_bin(OPcomma,ty,ec,e);
            e.ET = t;
        }
        *pe = e;
    }
}

/************************
 * Mark curblock as initializing Symbol s.
 */

version (COMPILE)
{

//#undef block_initvar

void block_initvar(Symbol* s)
{
    symbol_debug(s);
    curblock.Binitvar = s;
}

}

/******************************
 * Perform branch optimization on basic blocks.
 */

@trusted
void blockopt(ref GlobalOptimizer go, int iter)
{
    if (OPTIMIZER)
    {
        blassertsplit(go);              // only need this once

        int iterationLimit = 200;
        if (iterationLimit < bo.dfo.length)
            iterationLimit = cast(int)bo.dfo.length;
        int count = 0;
        do
        {
            //printf("changes = %d, count = %d, dfo.length = %d\n",go.changes,count,dfo.length);
            go.changes = 0;
            bropt(go);                  // branch optimization
            brrear();                   // branch rearrangement
            blident(go);                // combine identical blocks
            blreturn(go);               // split out return blocks
            bltailmerge(go);            // do tail merging
            brtailrecursion(go);        // do tail recursion
            brcombine(go);              // convert graph to expressions
            blexit(go);
            if (iter >= 2)
                brmin(go);              // minimize branching

            // Switched to one block per Statement, do not undo it
            enum merge = false;

            do
            {
                compdfo(bo.dfo, bo.startblock); // compute depth first order (DFO)
                elimblks(go);           /* remove blocks not in DFO      */
                assert(count < iterationLimit);
                count++;
            } while (merge && mergeblks());      // merge together blocks
        } while (go.changes);

        debug if (debugw)
        {
            WRfunc("After blockopt()", funcsym_p, bo.startblock);
        }
    }
    else
    {
        debug
        {
            numberBlocks(bo.startblock);
        }

        /* canonicalize the trees        */
        for (block* b = bo.startblock; b; b = b.Bnext)
        {
            debug if (debugb)
            {
                printf("before doptelem():\n");
                WRblock(b);
            }

            if (b.Belem)
            {
                b.Belem = doptelem(b.Belem, bc_goal(b.bc) | Goal.struct_);
                if (b.Belem)
                    b.Belem = el_convert(go, b.Belem);
            }

            debug if (debugb)
            {
                printf("after optelem():\n");
                WRblock(b);
            }
        }
        if (localgot)
        {   // Initialize with:
            //  localgot = OPgot;
            elem* e = el_long(TYnptr, 0);
            e.Eoper = OPgot;
            e = el_bin(OPeq, TYnptr, el_var(localgot), e);
            bo.startblock.Belem = el_combine(e, bo.startblock.Belem);
        }

        bropt(go);                      /* branch optimization           */
        brrear();                       /* branch rearrangement          */
        comsubs(go);                    /* eliminate common subexpressions */

        debug if (debugb)
        {
            WRfunc("After blockopt()", funcsym_p, bo.startblock);
        }
    }
}

/***********************************
 * Try to remove control structure.
 * That is, try to resolve if-else, goto and return statements
 * into &&, || and ?: combinations.
 */

@trusted
void brcombine(ref GlobalOptimizer go)
{
    debug if (debugc) printf("brcombine()\n");
    //WRfunc("brcombine()", funcsym_p, startblock);

    if (funcsym_p.Sfunc.Fflags3 & (Fcppeh | Fnteh))
    {   // Don't mess up extra EH info by eliminating blocks
        return;
    }

    do
    {
        int anychanges = 0;
        for (block* b = bo.startblock; b; b = b.Bnext)   // for each block
        {
            /* Look for [e1 IFFALSE L3,L2] L2: [e2 GOTO L3] L3: [e3]    */
            /* Replace with [(e1 && e2),e3]                             */
            const bc = b.bc;
            if (bc == BC.iftrue)
            {
                block* b2 = b.nthSucc(0);
                block* b3 = b.nthSucc(1);

                if (list_next(b2.Bpred))       // if more than one predecessor
                    continue;
                if (b2 == b3)
                    continue;
                if (b2 == bo.startblock)
                    continue;
                if (b2.Belem && !OTleaf(b2.Belem.Eoper))
                    continue;

                const bc2 = b2.bc;
                if (bc2 == BC.goto_ &&
                    b3 == b2.nthSucc(0))
                {
                    b.bc = BC.goto_;
                    if (b2.Belem)
                    {
                        int op = OPandand;
                        b.Belem = el_bin(op,TYint,b.Belem,b2.Belem);
                        b2.Belem = null;
                    }
                    list_subtract(&(b.Bsucc),b2);
                    list_subtract(&(b2.Bpred),b);
                    debug if (debugc) printf("brcombine(): if !e1 then e2 => e1 || e2\n");
                    anychanges++;
                }
                else if (list_next(b3.Bpred) || b3 == bo.startblock)
                    continue;
                if ((bc2 == BC.retexp && b3.bc == BC.retexp)
                         //|| (bc2 == BC.ret && b3.bc == BC.ret)
                        )
                {
                    if (!OTleaf(b3.Belem.Eoper))
                        continue;
                    tym_t ty = (bc2 == BC.retexp) ? b2.Belem.Ety : cast(tym_t) TYvoid;
                    elem* e = el_bin(OPcolon2,ty,b2.Belem,b3.Belem);
                    b.Belem = el_bin(OPcond,ty,b.Belem,e);
                    b.bc = bc2;
                    b.Belem.ET = b2.Belem.ET;
                    b2.Belem = null;
                    b3.Belem = null;
                    list_free(&b.Bsucc,FPNULL);
                    list_subtract(&(b2.Bpred),b);
                    list_subtract(&(b3.Bpred),b);
                    debug if (debugc) printf("brcombine(): if e1 return e2 else return e3 => ret e1?e2:e3\n");
                    anychanges++;
                }
                else if (bc2 == BC.goto_ &&
                         b3.bc == BC.goto_ &&
                         b2.nthSucc(0) == b3.nthSucc(0))
                {
                    block* bsucc = b2.nthSucc(0);
                    if (b2.Belem)
                    {
                        elem* e;
                        if (b3.Belem)
                        {
                            if (!OTleaf(b3.Belem.Eoper))
                                continue;
                            e = el_bin(OPcolon2,b2.Belem.Ety,
                                    b2.Belem,b3.Belem);
                            e = el_bin(OPcond,e.Ety,b.Belem,e);
                            e.ET = b2.Belem.ET;
                        }
                        else
                        {
                            int op = OPandand;
                            e = el_bin(op,TYint,b.Belem,b2.Belem);
                        }
                        b2.Belem = null;
                        b.Belem = e;
                    }
                    else if (b3.Belem)
                    {
                        int op = OPoror;
                        b.Belem = el_bin(op,TYint,b.Belem,b3.Belem);
                    }
                    b.bc = BC.goto_;
                    b3.Belem = null;
                    list_free(&b.Bsucc,FPNULL);

                    b.appendSucc(bsucc);
                    list_append(&bsucc.Bpred,b);

                    list_free(&(b2.Bpred),FPNULL);
                    list_free(&(b2.Bsucc),FPNULL);
                    list_free(&(b3.Bpred),FPNULL);
                    list_free(&(b3.Bsucc),FPNULL);
                    b2.bc = BC.ret;
                    b3.bc = BC.ret;
                    list_subtract(&(bsucc.Bpred),b2);
                    list_subtract(&(bsucc.Bpred),b3);
                    debug if (debugc) printf("brcombine(): if e1 goto e2 else goto e3 => ret e1?e2:e3\n");
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

@trusted
private void bropt(ref GlobalOptimizer go)
{
    debug if (debugc) printf("bropt()\n");
    for (block* b = bo.startblock; b; b = b.Bnext)   // for each block
    {
        elem** pn = &(b.Belem);
        if (OPTIMIZER && *pn)
            pn = el_scancommas(pn);

        elem* n = *pn;

        /* look for conditional that never returns */
        if (n && tybasic(n.Ety) == TYnoreturn && b.bc != BC.exit)
        {
            b.bc = BC.exit;
            // Exit block has no successors, so remove them
            foreach (bp; ListRange(b.Bsucc))
            {
                list_subtract(&(list_block(bp).Bpred),b);
            }
            list_free(&b.Bsucc, FPNULL);
            debug if (debugc) printf("CHANGE: noreturn becomes BC.exit\n");
            go.changes++;
            continue;
        }

        if (b.bc == BC.iftrue)
        {
            assert(n);
            /* Replace IF (!e) GOTO ... with        */
            /* IF OPnot (e) GOTO ...                */
            if (n.Eoper == OPnot)
            {
                tym_t tym;

                tym = n.E1.Ety;
                *pn = el_selecte1(n);
                (*pn).Ety = tym;
                for (n = b.Belem; n.Eoper == OPcomma; n = n.E2)
                    n.Ety = tym;
                b.Bsucc = list_reverse(b.Bsucc);
                debug if (debugc) printf("CHANGE: if (!e)\n");
                go.changes++;
            }

            /* Take care of IF (constant)                   */
            block* db;
            if (iftrue(n))          /* if elem is true      */
            {
                // select first succ
                db = b.nthSucc(1);
                goto L1;
            }
            else if (iffalse(n))
            {
                // select second succ
                db = b.nthSucc(0);

              L1:
                list_subtract(&(b.Bsucc),db);
                list_subtract(&(db.Bpred),b);
                b.bc = BC.goto_;
                /* delete elem if it has no side effects */
                b.Belem = doptelem(b.Belem, Goal.none | Goal.again);
                debug if (debugc) printf("CHANGE: if (const)\n");
                go.changes++;
            }

            /* Look for both destinations being the same    */
            else if (b.nthSucc(0) ==
                     b.nthSucc(1))
            {
                b.bc = BC.goto_;
                db = b.nthSucc(0);
                list_subtract(&(b.Bsucc),db);
                list_subtract(&(db.Bpred),b);
                debug if (debugc) printf("CHANGE: if (e) goto L1; else goto L1;\n");
                go.changes++;
            }
        }
        else if (b.bc == BC.switch_)
        {   /* see we can evaluate this switch now  */
            n = *el_scancommas(&n);
            if (n.Eoper != OPconst)
                continue;
            assert(tyintegral(n.Ety));
            targ_llong value = el_tolong(n);

            int i = 0;          // 0 means the default case
            foreach (j, val; b.Bswitch)
            {
                if (val == value)
                {
                    i = cast(int)j + 1;
                    break;
                }
            }
            block* db = b.nthSucc(i);

            /* delete predecessors of successors (!)        */
            foreach (bl; ListRange(b.Bsucc))
            {
                if (i--)            // but not the db successor
                {
                    void* p = list_subtract(&(list_block(bl).Bpred),b);
                    assert(p == b);
                }
            }

            /* dump old successor list and create a new one */
            list_free(&b.Bsucc,FPNULL);
            b.appendSucc(db);
            b.bc = BC.goto_;
            b.Belem = doptelem(b.Belem, Goal.none | Goal.again);
            debug if (debugc) printf("CHANGE: switch (const)\n");
            go.changes++;
        }
    }
}

/*********************************
 * Do branch rearrangement.
 */

@trusted
private void brrear()
{
    debug if (debugc) printf("brrear()\n");
    for (block* b = bo.startblock; b; b = b.Bnext)   // for each block
    {
        foreach (bl; ListRange(b.Bsucc))
        {   /* For each transfer of control block pointer   */
            int iter = 0;

            block* bt = list_block(bl);

            /* If it is a transfer to a block that consists */
            /* of nothing but an unconditional transfer,    */
            /*      Replace transfer address with that      */
            /*      transfer address.                       */
            /* Note: There are certain kinds of infinite    */
            /* loops which we avoid by putting a lid on     */
            /* the number of iterations.                    */

            static if (NTEXCEPTIONS)
                enum additionalAnd = "b.Btry == bt.Btry &&
                                  bt.Btry == bt.nthSucc(0).Btry";
            else
                enum additionalAnd = "true";

            while (bt.bc == BC.goto_ && !bt.Belem &&
                   mixin(additionalAnd) &&
                   (OPTIMIZER || !(bt.Bsrcpos.Slinnum && configv.addlinenumbers)) &&
                   ++iter < 10)
            {
                bl.ptr = list_ptr(bt.Bsucc);
                if (bt.Bsrcpos.Slinnum && !b.Bsrcpos.Slinnum)
                    b.Bsrcpos = bt.Bsrcpos;
                b.Bflags |= bt.Bflags;
                list_append(&(list_block(bl).Bpred),b);
                list_subtract(&(bt.Bpred),b);
                debug if (debugc) printf("goto.goto\n");
                bt = list_block(bl);
            }

            // Bsucc after the first are the targets of
            // jumps, calls and loops, and as such to do this right
            // we need to traverse the Bcode list and fix up
            // the IEV2.Vblock pointers.
            if (b.bc == BC.asm_)
                break;
        }

        static if(0)
        {
            /* Replace cases of                     */
            /*      IF (e) GOTO L1 ELSE L2          */
            /*      L1:                             */
            /* with                                 */
            /*      IF OPnot (e) GOTO L2 ELSE L1    */
            /*      L1:                             */

            if (b.bc == BC.iftrue || b.bc == BC.iffalse)
            {
                block* bif = b.nthSucc(0);
                block* belse = b.nthSucc(1);

                if (bif == b.Bnext)
                {
                    b.bc ^= BC.iffalse ^ BC.iftrue;  /* toggle */
                    b.setNthSucc(0, belse);
                    b.setNthSucc(1, bif);
                    b.Bflags |= bif.Bflags & BFL.visited;
                    debug if (debugc) printf("if (e) L1 else L2\n");
                }
            }
        }
    } /* for */
}

/*************************
 * Compute depth first order (DFO).
 * Equivalent to Aho & Ullman Fig. 13.8.
 * Blocks not in dfo[] are unreachable.
 * Params:
 *      dfo = array to fill in in DFO
 *      startblock = list of blocks
 */
void compdfo(ref Barray!(block*) dfo, block* startblock)
{
    debug if (debugc) printf("compdfo()\n");
    debug assert(OPTIMIZER);
    block_clearvisit();
    dfo.setLength(0);

    /******************************
     * Add b's successors to dfo[], then b
     */
    void walkDFO(block* b)
    {
        assert(b);
        b.Bflags |= BFL.visited;             // executed at least once

        foreach (bl; ListRange(b.Bsucc))   // for each successor
        {
            block* bs = list_block(bl);
            assert(bs);
            if ((bs.Bflags & BFL.visited) == 0) // if not visited
                walkDFO(bs);
        }

        dfo.push(b);
    }


    dfo.setLength(0);
    walkDFO(startblock);

    // Reverse the array
    if (dfo.length)
    {
        size_t i = 0;
        size_t k = dfo.length - 1;
        while (i < k)
        {
            auto b = dfo[k];
            dfo[k] = dfo[i];
            dfo[i] = b;
            ++i;
            --k;
        }

        foreach (j, b; dfo[])
            b.Bdfoidx = cast(uint)j;
    }

    static if (0) debug
    {
        foreach (i, b; dfo[])
            printf("dfo[%d] = %p\n", cast(int)i, b);
    }
}


/*************************
 * Remove blocks not marked as visited (they are not in dfo[]).
 * A block is not in dfo[] if not visited.
 */

@trusted
private void elimblks(ref GlobalOptimizer go)
{
    debug if (debugc) printf("elimblks()\n");
    block* bf = null;
    block* b;
    for (block** pb = &bo.startblock; (b = *pb) != null;)
    {
        if (((b.Bflags & BFL.visited) == 0)   // if block is not visited
            && ((b.Bflags & BFL.label) == 0)  // need label offset
            )
        {
            /* for each marked successor S to b                     */
            /*      remove b from S.Bpred.                          */
            /* Presumably all predecessors to b are unmarked also.  */
            foreach (s; ListRange(b.Bsucc))
            {
                assert(list_block(s));
                if (list_block(s).Bflags & BFL.visited) /* if it is marked */
                    list_subtract(&(list_block(s).Bpred),b);
            }
            if (b.Balign && b.Bnext && b.Balign > b.Bnext.Balign)
                b.Bnext.Balign = b.Balign;
            *pb = b.Bnext;         // remove from linked list

            b.Bnext = bf;
            bf = b;                // prepend to deferred list to free
            debug if (debugc) printf("CHANGE: block %p deleted\n",b);
            go.changes++;
        }
        else
            pb = &((*pb).Bnext);
    }

    // Do deferred free's of the blocks
    for ( ; bf; bf = b)
    {
        b = bf.Bnext;
        block_free(bf);
    }

    debug if (debugc) printf("elimblks done\n");
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

@trusted
private int mergeblks()
{
    int merge = 0;

    assert(OPTIMIZER);
    debug if (debugc) printf("mergeblks()\n");
    foreach (b; bo.dfo[])
    {
        if (b.bc == BC.goto_)
        {   block* bL2 = list_block(b.Bsucc);

            if (b == bL2)
            {
                continue;
            }
            assert(bL2.Bpred);
            if (!list_next(bL2.Bpred) && bL2 != bo.startblock)
            {
                if (b == bL2 || bL2.bc == BC.asm_)
                    continue;

                if (bL2.bc == BC.try_ ||
                    bL2.bc == BC._try ||
                    b.Btry != bL2.Btry)
                    continue;

                /* JOIN the elems               */
                elem* e = el_combine(b.Belem,bL2.Belem);
                if (b.Belem && bL2.Belem)
                    e = doptelem(e,bc_goal(bL2.bc) | Goal.again);
                bL2.Belem = e;
                b.Belem = null;

                /* Remove b from predecessors of bL2    */
                list_free(&(bL2.Bpred),FPNULL);
                bL2.Bpred = b.Bpred;
                b.Bpred = null;
                /* Remove bL2 from successors of b      */
                list_free(&b.Bsucc,FPNULL);

                /* fix up successor list of predecessors        */
                foreach (bl; ListRange(bL2.Bpred))
                {
                    foreach (bs; ListRange(list_block(bl).Bsucc))
                        if (list_block(bs) == b)
                            bs.ptr = cast(void*)bL2;
                }

                merge++;
                debug if (debugc) printf("block %p merged with %p\n",b,bL2);

                if (b == bo.startblock)
                {   /* bL2 is the new startblock */
                    debug if (debugc) printf("bL2 is new startblock\n");
                    /* Remove bL2 from list of blocks   */
                    for (block** pb = &bo.startblock; 1; pb = &(*pb).Bnext)
                    {
                        assert(*pb);
                        if (*pb == bL2)
                        {
                            *pb = bL2.Bnext;
                            break;
                        }
                    }

                    /* And relink bL2 at the start              */
                    bL2.Bnext = bo.startblock.Bnext;
                    bo.startblock = bL2;   // new start

                    block_free(b);
                    break;              // dfo[] is now invalid
                }
            }
        }
    }
    return merge;
}

/*******************************
 * Combine together blocks that are identical.
 */

@trusted
private void blident(ref GlobalOptimizer go)
{
    debug if (debugc) printf("blident()\n");
    assert(bo.startblock);

    block* bnext;
    for (block* bn = bo.startblock; bn; bn = bnext)
    {
        bnext = bn.Bnext;
        if (bn.Bflags & BFL.nomerg)
            continue;

        for (block* b = bnext; b; b = b.Bnext)
        {
            /* Blocks are identical if:                 */
            /*  BC match                                */
            /*  not optimized for time or it's a return */
            /*      (otherwise looprotate() is undone)  */
            /*  successors match                        */
            /*  elems match                             */
            static if (SCPP_OR_NTEXCEPTIONS)
                bool additionalAnd = b.Btry == bn.Btry;
            else
                enum additionalAnd = true;
            if (b.bc == bn.bc &&
                //(!OPTIMIZER || !(go.mfoptim & MFtime) || !b.Bsucc) &&
                (!OPTIMIZER || !(b.Bflags & BFL.nomerg) || !b.Bsucc) &&
                list_equal(b.Bsucc,bn.Bsucc) &&
                additionalAnd &&
                el_match(b.Belem,bn.Belem)
               )
            {   /* Eliminate block bn           */
                switch (b.bc)
                {
                    case BC.switch_:
                        if (b.Bswitch[] != bn.Bswitch[])
                            continue;
                        break;

                    case BC.try_:
                    case BC.catch_:
                    case BC.jcatch:
                    case BC._try:
                    case BC._finally:
                    case BC._lpad:
                    case BC.asm_:
                    Lcontinue:
                        continue;

                    default:
                        break;
                }
                assert(!b.Bcode);

                foreach (bl; ListRange(bn.Bpred))
                {
                    block* bp = list_block(bl);
                    if (bp.bc == BC.asm_)
                        // Can't do this because of jmp's and loop's
                        goto Lcontinue;
                }

                static if(0) // && SCPP
                {
                    // Predecessors must all be at the same btry level.
                    if (bn.Bpred)
                    {
                        block* bp = list_block(bn.Bpred);
                        btry = bp.Btry;
                        if (bp.bc == BC.try_)
                            btry = bp;
                    }
                    else
                        btry = null;

                    foreach (bl; ListRange(b.Bpred))
                    {
                        block* bp = list_block(bl);
                        if (bp.bc != BC.try_)
                            bp = bp.Btry;
                        if (btry != bp)
                            goto Lcontinue;
                    }
                }

                // if bn is startblock, eliminate b instead of bn
                if (bn == bo.startblock)
                {
                    goto Lcontinue;     // can't handle predecessors to startblock
                    // unreachable code
                    //bn = b;
                    //b = startblock;             /* swap b and bn        */
                }

                /* Change successors to predecessors of bn to point to  */
                /* b instead of bn                                      */
                foreach (bl; ListRange(bn.Bpred))
                {
                    block* bp = list_block(bl);
                    foreach (bls; ListRange(bp.Bsucc))
                        if (list_block(bls) == bn)
                        {   bls.ptr = cast(void*)b;
                            list_prepend(&b.Bpred,bp);
                        }
                }

                /* Entirely remove predecessor list from bn.            */
                /* elimblks() will delete bn entirely.                  */
                list_free(&(bn.Bpred),FPNULL);

                debug
                {
                    assert(bn.bc != BC.catch_);
                    if (debugc)
                        printf("block B%d (%p) removed, it was same as B%d (%p)\n",
                            bn.Bdfoidx,bn,b.Bdfoidx,b);
                }

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

@trusted
private void blreturn(ref GlobalOptimizer go)
{
    if (!(go.mfoptim & MFtime))            /* if optimized for space       */
    {
        int retcount = 0;               // number of return counts

        /* Find last return block       */
        for (block* b = bo.startblock; b; b = b.Bnext)
        {
            if (b.bc == BC.ret)
                retcount++;
            if (b.bc == BC.asm_)
                return;                 // mucks up blident()
        }

        if (retcount < 2)               /* quit if nothing to combine   */
            return;

        /* Split return blocks  */
        for (block* b = bo.startblock; b; b = b.Bnext)
        {
            if (b.bc != BC.ret)
                continue;
            static if (SCPP_OR_NTEXCEPTIONS)
            {
                // If no other blocks with the same Btry, don't split
                enum ifCondition = true;
                if (ifCondition)
                {
                    for (block* b2 = bo.startblock; b2; b2 = b2.Bnext)
                    {
                        if (b2.bc == BC.ret && b != b2 && b.Btry == b2.Btry)
                            goto L1;
                    }
                    continue;
                }
            L1:
            }
            if (b.Belem)
            {   /* Split b into a goto and a b  */
                debug if (debugc)
                    printf("blreturn: splitting block B%d\n",b.Bdfoidx);

                block* bn = block_calloc();
                bn.bc = BC.ret;
                bn.Bnext = b.Bnext;
                static if(SCPP_OR_NTEXCEPTIONS)
                {
                    bn.Btry = b.Btry;
                }
                b.bc = BC.goto_;
                b.Bnext = bn;
                list_append(&b.Bsucc,bn);
                list_append(&bn.Bpred,b);

                b = bn;
            }
        }

        blident(go);                    /* combine return blocks        */
    }
}

/*****************************************
 * Convert comma-expressions into an array of expressions.
 */

@trusted
extern (D)
private void bl_enlist2(ref Barray!(elem*) elems, elem* e)
{
    if (e)
    {
        elem_debug(e);
        if (e.Eoper == OPcomma)
        {
            bl_enlist2(elems, e.E1);
            bl_enlist2(elems, e.E2);
            e.E1 = e.E2 = null;
            el_free(e);
        }
        else
            elems.push(e);
    }
}

@trusted
private list_t bl_enlist(elem* e)
{
    list_t el = null;

    if (e)
    {
        elem_debug(e);
        if (e.Eoper == OPcomma)
        {
            list_t el2 = bl_enlist(e.E1);
            el = bl_enlist(e.E2);
            e.E1 = e.E2 = null;
            el_free(e);

            /* Append el2 list to el    */
            assert(el);
            list_t pl;
            for (pl = el; list_next(pl); pl = list_next(pl))
                {}
            pl.next = el2;
        }
        else
            list_prepend(&el,e);
    }
    return el;
}

/*****************************************
 * Take a list of expressions and convert it back into an expression tree.
 */

extern (D)
private elem* bl_delist2(elem*[] elems)
{
    elem* result = null;
    foreach (e; elems)
    {
        result = el_combine(result, e);
    }
    return result;
}

@trusted
private elem* bl_delist(list_t el)
{
    elem* e = null;
    foreach (els; ListRange(el))
        e = el_combine(list_elem(els),e);
    list_free(&el,FPNULL);
    return e;
}

/*****************************************
 * Do tail merging.
 */

@trusted
private void bltailmerge(ref GlobalOptimizer go)
{
    debug if (debugc) printf("bltailmerge()\n");
    assert(OPTIMIZER);
    if (!(go.mfoptim & MFtime))            /* if optimized for space       */
    {
        /* Split each block into a reversed linked list of elems        */
        for (block* b = bo.startblock; b; b = b.Bnext)
            b.Blist = bl_enlist(b.Belem);

        /* Search for two blocks that have the same successor list.
           If the first expressions both lists are the same, split
           off a new block with that expression in it.
         */
        static if (SCPP_OR_NTEXCEPTIONS)
            enum additionalAnd = "b.Btry == bn.Btry";
        else
            enum additionalAnd = "true";
        for (block* b = bo.startblock; b; b = b.Bnext)
        {
            if (!b.Blist)
                continue;
            elem* e = list_elem(b.Blist);
            elem_debug(e);
            for (block* bn = b.Bnext; bn; bn = bn.Bnext)
            {
                elem* en;
                if (b.bc == bn.bc &&
                    list_equal(b.Bsucc,bn.Bsucc) &&
                    bn.Blist &&
                    el_match(e,(en = list_elem(bn.Blist))) &&
                    mixin(additionalAnd)
                   )
                {
                    switch (b.bc)
                    {
                        case BC.switch_:
                            if (b.Bswitch[] != bn.Bswitch[])
                                continue;
                            break;

                        case BC.try_:
                        case BC.catch_:
                        case BC.jcatch:
                        case BC._try:
                        case BC._finally:
                        case BC._lpad:
                        case BC.asm_:
                            continue;

                        default:
                            break;
                    }

                    /* We've got a match        */

                    /*  Create a new block, bnew, which will be the
                        merged block. Physically locate it just after bn.
                     */
                    debug if (debugc)
                        printf("tail merging: %p and %p\n", b, bn);

                    block* bnew = block_calloc();
                    bnew.Bnext = bn.Bnext;
                    bnew.bc = b.bc;
                    static if (SCPP_OR_NTEXCEPTIONS)
                    {
                        bnew.Btry = b.Btry;
                    }
                    if (bnew.bc == BC.switch_)
                    {
                        bnew.Bswitch = b.Bswitch;
                        b.Bswitch = null;
                        bn.Bswitch = null;
                    }
                    bn.Bnext = bnew;

                    /* The successor list to bnew is the same as b's was */
                    bnew.Bsucc = b.Bsucc;
                    b.Bsucc = null;
                    list_free(&bn.Bsucc,FPNULL);

                    /* Update the predecessor list of the successor list
                        of bnew, from b to bnew, and removing bn
                     */
                    foreach (bl; ListRange(bnew.Bsucc))
                    {
                        list_subtract(&list_block(bl).Bpred,b);
                        list_subtract(&list_block(bl).Bpred,bn);
                        list_append(&list_block(bl).Bpred,bnew);
                    }

                    /* The predecessors to bnew are b and bn    */
                    list_append(&bnew.Bpred,b);
                    list_append(&bnew.Bpred,bn);

                    /* The successors to b and bn are bnew      */
                    b.bc = BC.goto_;
                    bn.bc = BC.goto_;
                    list_append(&b.Bsucc,bnew);
                    list_append(&bn.Bsucc,bnew);

                    go.changes++;

                    /* Find all the expressions we can merge    */
                    do
                    {
                        list_append(&bnew.Blist,e);
                        el_free(en);
                        list_pop(&b.Blist);
                        list_pop(&bn.Blist);
                        if (!b.Blist)
                            goto nextb;
                        e = list_elem(b.Blist);
                        if (!bn.Blist)
                            break;
                        en = list_elem(bn.Blist);
                    } while (el_match(e,en));
                }
            }
    nextb:
        }

        /* Recombine elem lists into expression trees   */
        for (block* b = bo.startblock; b; b = b.Bnext)
            b.Belem = bl_delist(b.Blist);
    }
}

/**********************************
 * Rearrange blocks to minimize jmp's.
 */

@trusted
private void brmin(ref GlobalOptimizer go)
{
    debug if (debugc) printf("brmin()\n");
    debug assert(bo.startblock);
    for (block* b = bo.startblock.Bnext; b; b = b.Bnext)
    {
        block* bnext = b.Bnext;
        if (!bnext)
            break;
        foreach (bl; ListRange(b.Bsucc))
        {
            block* bs = list_block(bl);
            if (bs == bnext)
                goto L1;
        }

        // b is a block which does not have bnext as a successor.
        // Look for a successor of b for which everyone must jmp to.

        foreach (bl; ListRange(b.Bsucc))
        {
            block* bs = list_block(bl);
            block* bn;
            foreach (blp; ListRange(bs.Bpred))
            {
                block* bsp = list_block(blp);
                if (bsp.Bnext == bs)
                    goto L2;
            }

            // Move bs so it is the Bnext of b
            for (bn = bnext; 1; bn = bn.Bnext)
            {
                if (!bn)
                    goto L2;
                if (bn.Bnext == bs)
                    break;
            }
            bn.Bnext = null;
            b.Bnext = bs;
            for (bn = bs; bn.Bnext; bn = bn.Bnext)
                {}
            bn.Bnext = bnext;
            debug if (debugc) printf("Moving block %p to appear after %p\n",bs,b);
            go.changes++;
            break;

        L2:
        }


    L1:
    }
}

/********************************
 * Check integrity of blocks.
 */

static if(0)
{

@trusted
private void block_check()
{
    for (block* b = startblock; b; b = b.Bnext)
    {
        int nsucc = list_nitems(b.Bsucc);
        int npred = list_nitems(b.Bpred);
        switch (b.bc)
        {
            case BC.goto_:
                assert(nsucc == 1);
                break;

            case BC.iftrue:
                assert(nsucc == 2);
                break;
        }

        foreach (bl; ListRange(b.Bsucc))
        {
            block* bs = list_block(bl);

            foreach (bls; ListRange(bs.Bpred))
            {
                assert(bls);
                if (list_block(bls) == b)
                    break;
            }
        }
    }
}

}

/***************************************
 * Do tail recursion.
 */

@trusted
private void brtailrecursion(ref GlobalOptimizer go)
{
    if (funcsym_p.Sfunc.Fflags3 & Fnotailrecursion)
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

    for (block* b = bo.startblock; b; b = b.Bnext)
    {
        if (b.bc == BC._try)
            return;
        elem** pe = &b.Belem;
        block* bn = null;
        if (*pe &&
            (b.bc == BC.ret ||
             b.bc == BC.retexp ||
             (b.bc == BC.goto_ && (bn = list_block(b.Bsucc)).Belem == null &&
              bn.bc == BC.ret)
            )
           )
        {
            if (el_anyframeptr(*pe))    // if any OPframeptr's
                return;

            pe = el_scancommas(pe);

            elem* e = *pe;

            static bool isCandidate(elem* e)
            {
                e = *el_scancommas(&e);
                if (e.Eoper == OPcond)
                    return isCandidate(e.E2.E1) || isCandidate(e.E2.E2);

                return OTcall(e.Eoper) &&
                       e.E1.Eoper == OPvar &&
                       e.E1.Vsym == funcsym_p;
            }

            if (e.Eoper == OPcond &&
                (isCandidate(e.E2.E1) || isCandidate(e.E2.E2)))
            {
                /* Split OPcond into a BC.iftrue block and two return blocks
                 */
                block* b1 = block_calloc();
                block* b2 = block_calloc();

                b1.Belem = e.E2.E1;
                e.E2.E1 = null;

                b2.Belem = e.E2.E2;
                e.E2.E2 = null;

                *pe = e.E1;
                e.E1 = null;
                el_free(e);

                if (b.bc == BC.goto_)
                {
                    list_subtract(&b.Bsucc, bn);
                    list_subtract(&bn.Bpred, b);
                    list_append(&b1.Bsucc, bn);
                    list_append(&bn.Bpred, b1);
                    list_append(&b2.Bsucc, bn);
                    list_append(&bn.Bpred, b2);
                }

                list_append(&b.Bsucc, b1);
                list_append(&b1.Bpred, b);
                list_append(&b.Bsucc, b2);
                list_append(&b2.Bpred, b);

                b1.bc = b.bc;
                b2.bc = b.bc;
                b.bc = BC.iftrue;

                b2.Bnext = b.Bnext;
                b1.Bnext = b2;
                b.Bnext = b1;
                continue;
            }

            if (OTcall(e.Eoper) &&
                e.E1.Eoper == OPvar &&
                e.E1.Vsym == funcsym_p)
            {
                //printf("before:\n");
                //elem_print(*pe);
                if (OTunary(e.Eoper))
                {
                    *pe = el_long(TYint,0);
                }
                else
                {
                    int si = 0;
                    elem* e2 = null;
                    *pe = assignparams(&e.E2,&si,&e2);
                    *pe = el_combine(*pe,e2);
                }
                el_free(e);
                //printf("after:\n");
                //elem_print(*pe);

                if (b.bc == BC.goto_)
                {
                    list_subtract(&b.Bsucc,bn);
                    list_subtract(&bn.Bpred,b);
                }
                b.bc = BC.goto_;
                list_append(&b.Bsucc,bo.startblock);
                list_append(&bo.startblock.Bpred,b);

                // Create a new startblock, bs, because startblock cannot
                // have predecessors.
                block* bs = block_calloc();
                bs.bc = BC.goto_;
                bs.Bnext = bo.startblock;
                list_append(&bs.Bsucc,bo.startblock);
                list_append(&bo.startblock.Bpred,bs);
                bo.startblock = bs;

                debug if (debugc) printf("tail recursion\n");
                go.changes++;
            }
        }
    }
}

/*****************************************
 * Convert parameter expression to assignment statements.
 */

@trusted
private elem* assignparams(elem** pe,int* psi,elem** pe2)
{
    elem* e = *pe;

        if (e.Eoper == OPparam)
    {
        elem* ea = null;
        elem* eb = null;
        elem* e2 = assignparams(&e.E2,psi,&eb);
        elem* e1 = assignparams(&e.E1,psi,&ea);
        e.E1 = null;
        e.E2 = null;
        e = el_combine(e1,e2);
        *pe2 = el_combine(eb,ea);
    }
    else
    {
        int si = *psi;
        type* t;

        assert(si < globsym.length);
        Symbol* sp = globsym[si];
        Symbol* s = symbol_genauto(sp.Stype);
        s.Sfl = FL.auto_;
        int op = OPeq;
        if (e.Eoper == OPstrpar)
        {
            op = OPstreq;
            t = e.ET;
            elem* ex = e;
            e = e.E1;
            ex.E1 = null;
            el_free(ex);
        }
        elem* es = el_var(s);
        es.Ety = e.Ety;
        e = el_bin(op,TYvoid,es,e);
        if (op == OPstreq)
            e.ET = t;
        *pe2 = el_bin(op,TYvoid,el_var(sp),el_copytree(es));
        (*pe2).E1.Ety = es.Ety;
        if (op == OPstreq)
            (*pe2).ET = t;
        *psi = ++si;
        *pe = null;
    }
    return e;
}

/****************************************************
 * Eliminate empty loops.
 */

@trusted
private void emptyloops(ref GlobalOptimizer go)
{
    debug if (debugc) printf("emptyloops()\n");
    for (block* b = bo.startblock; b; b = b.Bnext)
    {
        if (b.bc == BC.iftrue &&
            list_block(b.Bsucc) == b &&
            list_nitems(b.Bpred) == 2)
        {
            // Find predecessor to b
            block* bpred = list_block(b.Bpred);
            if (bpred == b)
                bpred = list_block(list_next(b.Bpred));
            if (!bpred.Belem)
                continue;

            // Find einit
            elem* einit = *el_scancommas(&(bpred.Belem));
            if (einit.Eoper != OPeq ||
                einit.E2.Eoper != OPconst ||
                einit.E1.Eoper != OPvar)
                continue;

            // Look for ((i += 1) < limit)
            elem* erel = b.Belem;
            if (erel.Eoper != OPlt ||
                erel.E2.Eoper != OPconst ||
                erel.E1.Eoper != OPaddass)
                continue;

            elem* einc = erel.E1;
            if (einc.E2.Eoper != OPconst ||
                einc.E1.Eoper != OPvar ||
                !el_match(einc.E1,einit.E1))
                continue;

            if (!tyintegral(einit.E1.Ety) ||
                el_tolong(einc.E2) != 1 ||
                el_tolong(einit.E2) >= el_tolong(erel.E2)
               )
                continue;

             {
                erel.Eoper = OPeq;
                erel.Ety = erel.E1.Ety;
                erel.E1 = el_selecte1(erel.E1);
                b.bc = BC.goto_;
                list_subtract(&b.Bsucc,b);
                list_subtract(&b.Bpred,b);

                debug if (debugc)
                {
                    WReqn(erel);
                    printf(" eliminated loop\n");
                }

                go.changes++;
             }
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

@trusted
private void funcsideeffects()
{
    //printf("funcsideeffects('%s')\n",funcsym_p.Sident);
    for (block* b = bo.startblock; b; b = b.Bnext)
    {
        if (b.Belem && funcsideeffect_walk(b.Belem))
        {
            //printf("  function '%s' has side effects\n",funcsym_p.Sident);
            return;
        }
    }
    funcsym_p.Sfunc.Fflags3 |= Fnosideeff;
    //printf("  function '%s' has no side effects\n",funcsym_p.Sident);
}

@trusted
private int funcsideeffect_walk(elem* e)
{
    assert(e);
    elem_debug(e);
    if (typemask(e) & (mTYvolatile | mTYshared))
        return 1;
    int op = e.Eoper;
    switch (op)
    {
        case OPcall:
        case OPucall:
            Symbol* s;
            if (e.E1.Eoper == OPvar &&
                tyfunc((s = e.E1.Vsym).Stype.Tty) &&
                ((s.Sfunc && s.Sfunc.Fflags3 & Fnosideeff) || s == funcsym_p)
               )
                break;
            goto Lside;

        // Note: we should allow assignments to local variables as
        // not being a 'side effect'.

        default:
            assert(op < OPMAX);
            return OTsideff(op) ||
                (OTunary(op) && funcsideeffect_walk(e.E1)) ||
                (OTbinary(op) && (funcsideeffect_walk(e.E1) ||
                                  funcsideeffect_walk(e.E2)));
    }
    return 0;

  Lside:
    return 1;
}

/*******************************
 * Determine if there are any OPframeptr's in the tree.
 */

@trusted
private int el_anyframeptr(elem* e)
{
    while (1)
    {
        if (OTunary(e.Eoper))
            e = e.E1;
        else if (OTbinary(e.Eoper))
        {
            if (el_anyframeptr(e.E2))
                return 1;
            e = e.E1;
        }
        else if (e.Eoper == OPframeptr)
            return 1;
        else
            break;
    }
    return 0;
}


/**************************************
 * Split off asserts into their very own BC.exit
 * blocks after the end of the function.
 * This is because assert calls are never in a hot branch.
 */

@trusted
private void blassertsplit(ref GlobalOptimizer go)
{
    debug if (debugc) printf("blassertsplit()\n");
    Barray!(elem*) elems;
    for (block* b = bo.startblock; b; b = b.Bnext)
    {
        /* Not sure of effect of jumping out of a try block
         */
        if (b.Btry)
            continue;

        if (b.bc == BC.exit)
            continue;

        elems.reset();
        bl_enlist2(elems, b.Belem);
        auto earray = elems[];
    L1:
        int dctor = 0;

        int accumDctor(elem* e)
        {
            while (1)
            {
                if (OTunary(e.Eoper))
                {
                    e = e.E1;
                    continue;
                }
                else if (OTbinary(e.Eoper))
                {
                    accumDctor(e.E1);
                    e = e.E2;
                    continue;
                }
                else if (e.Eoper == OPdctor)
                    ++dctor;
                else if (e.Eoper == OPddtor)
                    --dctor;
                break;
            }
            return dctor;
        }

        foreach (i, e; earray)
        {
            if (!(dctor == 0 &&   // don't split block between a dctor..ddtor pair
                e.Eoper == OPoror && e.E2.Eoper == OPcall && e.E2.E1.Eoper == OPvar))
            {
                accumDctor(e);
                continue;
            }
            Symbol* f = e.E2.E1.Vsym;
            if (!(f.Sflags & SFLexit))
            {
                accumDctor(e);
                continue;
            }

            if (accumDctor(e.E1))
            {
                accumDctor(e.E2);
                continue;
            }

            // Create exit block
            block* bexit = block_calloc();
            bexit.bc = BC.exit;
            bexit.Belem = e.E2;

            /* Append bexit to block list
             */
            for (block* bx = b; 1; )
            {
                block* bxn = bx.Bnext;
                if (!bxn)
                {
                    bx.Bnext = bexit;
                    break;
                }
                bx = bxn;
            }

            earray[i] = e.E1;
            e.E1 = null;
            e.E2 = null;
            el_free(e);

            /* Split b into two blocks, [b,b2]
             */
            block* b2 = block_calloc();
            b2.Bnext = b.Bnext;
            b.Bnext = b2;
            b2.bc = b.bc;
            b2.BS = b.BS;

            b.Belem = bl_delist2(earray[0 .. i + 1]);

            /* Transfer successors of b to b2.
             * Fix up predecessors of successors to b2 to point to b2 instead of b
             */
            b2.Bsucc = b.Bsucc;
            b.Bsucc = null;
            foreach (b2sl; ListRange(b2.Bsucc))
            {
                block* b2s = list_block(b2sl);
                foreach (b2spl; ListRange(b2s.Bpred))
                {
                    if (list_block(b2spl) == b)
                        b2spl.ptr = cast(void*)b2;
                }
            }

            b.bc = BC.iftrue;
            assert(b.Belem);
            list_append(&b.Bsucc, b2);
            list_append(&b2.Bpred, b);
            list_append(&b.Bsucc, bexit);
            list_append(&bexit.Bpred, b);

            b = b2;
            earray = earray[i + 1 .. earray.length];  // rest of expressions go into b2
            debug if (debugc)
            {
                printf(" split off assert\n");
            }
            go.changes++;
            goto L1;
        }
        b.Belem = bl_delist2(earray);
        if (b.bc == BC.retexp && !b.Belem)
            b.Belem = el_long(TYint, 1);

    }
    elems.dtor();
}

/*************************************************
 * Detect exit blocks and move them to the end.
 */
@trusted
private void blexit(ref GlobalOptimizer go)
{
    debug if (debugc)
        printf("blexit()\n");

    Barray!(block*) bexits;
    for (block* b = bo.startblock; b; b = b.Bnext)
    {
        /* Not sure of effect of jumping out of a try block
         */
        if (b.Btry)
            continue;

        if (b.bc == BC.exit)
        {
            /* If b is not already at the end, put it at the end
             * because we don't care about speed for BC.exit blocks
             */
            if (b != bo.startblock && b.Bnext && b.Bnext.bc != BC.exit)
                bexits.push(b);
            continue;
        }

        if (!b.Belem || el_returns(b.Belem))
            continue;

        b.bc = BC.exit;

        foreach (bsl; ListRange(b.Bsucc))
        {
            block* bs = list_block(bsl);
            list_subtract(&bs.Bpred, b);
        }
        list_free(&b.Bsucc, FPNULL);

        if (b != bo.startblock && b.Bnext)
            bexits.push(b);

        debug if (debugc)
            printf(" to exit block\n");
        go.changes++;
    }

    /* Move all the newly detected Bexit blocks in bexits[] to the end
     */

    /* First remove them from the list of blocks
     */
    size_t i = 0;
    block** pb = &bo.startblock.Bnext;
    while (1)
    {
        if (i == bexits.length)
            break;

        if (*pb == bexits[i])
        {
            *pb = (*pb).Bnext;
            ++i;
        }
        else
            pb = &(*pb).Bnext;
    }

    /* Advance pb to point to the last Bnext
     */
    while (*pb)
        pb = &(*pb).Bnext;

    /* Append the bexits[] to the end
     */
    foreach (b; bexits[])
    {
        *pb = b;
        pb = &b.Bnext;
    }
    *pb = null;

    bexits.dtor();
}
