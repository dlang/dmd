/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/gloop.d, backend/gloop.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/gloop.d
 */


module dmd.backend.gloop;

version (SCPP)
    version = COMPILE;
version (MARS)
    version = COMPILE;

version (COMPILE)
{

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code_x86;
import dmd.backend.evalu8 : el_toldoubled;
import dmd.backend.oper;
import dmd.backend.global;
import dmd.backend.goh;
import dmd.backend.el;
import dmd.backend.outbuf;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.barray;
import dmd.backend.dlist;
import dmd.backend.dvec;
import dmd.backend.mem;

nothrow:
@safe:

@trusted
char symbol_isintab(const Symbol *s) { return sytab[s.Sclass] & SCSS; }

extern (C++):

bool findloopparameters(elem* erel, ref elem* rdeq, ref elem* rdinc);

alias Loops = Rarray!loop;


/*********************************
 * Loop data structure.
 */

struct loop
{
nothrow:
    vec_t Lloop;        // Vector of blocks in this loop
    vec_t Lexit;        // Vector of exit blocks of loop
    block *Lhead;       // Pointer to header of loop
    block *Ltail;       // Pointer to tail
    block *Lpreheader;  // Pointer to preheader (if any)
    Barray!(elem*) Llis; // loop invariant elems moved to Lpreheader, so
                        // redundant temporaries aren't created
    Rarray!Iv Livlist;        // basic induction variables
    Rarray!Iv Lopeqlist;      // list of other op= variables

    /*************************
     * Reset memory so this allocation can be re-used.
     */
    @trusted
    void reset()
    {
        vec_free(Lloop);
        vec_free(Lexit);

        foreach (ref iv; Livlist)
            iv.reset();
        foreach (ref iv; Lopeqlist)
            iv.reset();

        Llis.reset();
        Livlist.reset();
        Lopeqlist.reset();
    }

    /***********************
     * Write loop.
     */

    @trusted
    void print()
    {
        debug
        {
            loop *l = &this;
            printf("loop %p\n", l);
            printf("\thead: B%d, tail: B%d, prehead: B%d\n",l.Lhead.Bdfoidx,
                l.Ltail.Bdfoidx,(l.Lpreheader ) ? l.Lpreheader.Bdfoidx
                                                : cast(uint)-1);
            printf("\tLloop "); vec_println(l.Lloop);
            printf("\tLexit "); vec_println(l.Lexit);
        }
    }
}

struct famlist
{
nothrow:
    elem **FLpelem;         /* parent of elem in the family         */
    elem *c1;
    elem *c2;               // c1*(basic IV) + c2
    Symbol *FLtemp;         // symbol index of temporary (FLELIM if */
                            /* this entry has no temporary)         */
    tym_t FLty;             /* type of this induction variable      */
    tym_t FLivty;           /* type of the basic IV elem (which is  */
                            /* not necessarilly the type of the IV  */
                            /* elem!)                               */

    void reset()
    {
        el_free(c1);
        el_free(c2);
    }

    @trusted
    void print() const
    {
        debug
        {
            printf("famlist:\n");
            printf("*FLpelem:\n");
            elem_print(*FLpelem);
            printf("c1:");
            elem_print(c1);
            printf("c2:");
            elem_print(c2);
            printf("FLty = "); WRTYxx(FLty);
            printf("\nFLivty = "); WRTYxx(FLivty);
            printf("\n");
        }
    }
}

@system
enum FLELIM = cast(Symbol *)-1;

struct Iv
{
nothrow:
    Symbol *IVbasic;        // symbol of basic IV
    elem **IVincr;          // pointer to parent of IV increment elem
    Barray!famlist IVfamily;      // variables in this family

    @trusted
    void reset()
    {
        foreach (ref fl; IVfamily)
        {
            fl.reset();
        }
        IVfamily.reset();
    }

    @trusted
    void print() const
    {
        debug
        {
            printf("IV: '%s'\n",IVbasic.Sident.ptr);
            printf("*IVincr:\n");
            elem_print(*IVincr);
        }
    }
}


private __gshared bool addblk;                    /* if TRUE, then we added a block */

/* is elem loop invariant?      */
int isLI(const elem* n) { return n.Nflags & NFLli; }

/* make elem loop invariant     */
void makeLI(elem* n) { n.Nflags |= NFLli; }

/******************************
 *      Only variables that could only be unambiguously defined
 *      are candidates for loop invariant removal and induction
 *      variables.
 *      This means only variables that have the SFLunambig flag
 *      set for them.
 *      Doing this will still cover 90% (I hope) of the cases, and
 *      is a lot faster to compute.
 */

/*************
 * Free loops.
 */

private void freeloop(ref Loops loops)
{
    foreach (ref loop; loops)
        loop.reset();
    loops.reset();
}


/**********************************
 * Initialize block information.
 * Returns:
 *      !=0     contains BCasm block
 */

@trusted
int blockinit()
{
    bool hasasm = false;

    assert(dfo);
    uint i = 0;
    foreach (b; BlockRange(startblock))
    {
        debug                   /* check integrity of Bpred and Bsucc   */
          L1:
            foreach (blp; ListRange(b.Bpred))
            {
                foreach (bls; ListRange(list_block(blp).Bsucc))
                    if (list_block(bls) == b)
                        continue L1;
                assert(0);
            }

        ++i;
        if (b.BC == BCasm)
            hasasm = true;
                                        /* compute number of blocks     */
    }
    foreach (j, b; dfo[])
    {
        assert(b.Bdfoidx == j);
        b.Bdom = vec_realloc(b.Bdom, dfo.length); /* alloc Bdom vectors */
        vec_clear(b.Bdom);
    }
    return hasasm;
}

/****************************************
 * Compute dominators (Bdom) for each block.
 * See Aho & Ullman Fig. 13.5.
 * Note that flow graph is reducible if there is only one
 * pass through the loop.
 * Input:
 *      dfo[]
 * Output:
 *      fills in the Bdom vector for each block
 */

@trusted
void compdom()
{
    compdom(dfo[]);
}

@trusted
private extern (D) void compdom(block*[] dfo)
{
    assert(dfo.length);
    block* sb = dfo[0];                  // starting block

    vec_clear(sb.Bdom);
    vec_setbit(0,sb.Bdom);               // starting block only doms itself
    foreach (b; dfo)                     // for all except startblock
    {
        if (b != sb)
            vec_set(b.Bdom);             // dominate all blocks
    }

    vec_t t1 = vec_calloc(vec_numbits(sb.Bdom));       // allocate a temporary
    uint cntr = 0;                       // # of times thru loop
    bool chgs;
    do
    {
        chgs = false;
        foreach (i, b; dfo)              // for each block in dfo[]
        {
            if (i == 0)
                continue;                // except startblock
            if (b.Bpred)                 // if there are predecessors
            {
                vec_set(t1);
                foreach (bl; ListRange(b.Bpred))
                {
                    vec_andass(t1,list_block(bl).Bdom);
                }
            }
            else
                vec_clear(t1);      // no predecessors to dominate
            vec_setbit(i,t1);       // each block doms itself
            if (chgs)
                vec_copy(b.Bdom,t1);
            else if (!vec_equal(b.Bdom,t1))   // if any changes
            {
                vec_copy(b.Bdom,t1);
                chgs = true;
            }
        }
        cntr++;
        assert(cntr < 50);              // should have converged by now
    } while (chgs);
    vec_free(t1);

    debug if (debugc)
    {
        printf("Flow graph is%s reducible\n", cntr <= 2 ? "".ptr : " not".ptr);
    }
}

/***************************
 * Return !=0 if block A dominates block B.
 */

@trusted
bool dom(const block* A, const block* B)
{
    assert(A && B && dfo && dfo[A.Bdfoidx] == A);
    return vec_testbit(A.Bdfoidx,B.Bdom) != 0;
}

/**********************
 * Find all the loops.
 */

private extern (D) void findloops(block*[] dfo, ref Loops loops)
{
    freeloop(loops);

    //printf("findloops()\n");
    foreach (b; dfo)
        b.Bweight = 1;             // reset Bweights
    foreach_reverse (b; dfo)       // for each block (note reverse
                                   // dfo order, so most nested
                                   // loops are found first)
    {
        assert(b);
        foreach (bl; ListRange(b.Bsucc))
        {
            block *s = list_block(bl);      // each successor s to b
            assert(s);
            if (dom(s,b))                   // if s dominates b
                buildloop(loops, s, b);     // we found a loop
        }
    }

    debug if (debugc)
    {
        foreach (ref l; loops)
            l.print();
    }
}

/********************************
 */

private uint loop_weight(uint weight, int factor) pure
{
    // Be careful not to overflow
    if (weight < 0x1_0000)
        weight *= 10 * factor;
    else if (weight < 0x10_0000)
        weight *= 2 * factor;
    else
        weight += factor;
    assert(cast(int)weight > 0);
    return weight;
}

/*****************************
 * Construct natural loop.
 * Algorithm 13.1 from Aho & Ullman.
 * Note that head dom tail.
 */

@trusted
private void buildloop(ref Loops ploops,block *head,block *tail)
{
    loop *l;

    //printf("buildloop()\n");
    /* See if this is part of an existing loop. If so, merge the two.     */
    foreach (ref lp; ploops)
        if (lp.Lhead == head)           /* two loops with same header   */
        {
            vec_t v;

            // Calculate loop contents separately so we get the Bweights
            // done accurately.

            v = vec_calloc(dfo.length);
            vec_setbit(head.Bdfoidx,v);
            head.Bweight = loop_weight(head.Bweight, 1);
            insert(tail,v);

            vec_orass(lp.Lloop,v);      // merge into existing loop
            vec_free(v);

            vec_clear(lp.Lexit);        // recompute exit blocks
            l = &lp;
            goto L1;
        }

    /* Allocate loop entry        */
    l = ploops.push();

    l.Lloop = vec_calloc(dfo.length);    // allocate loop bit vector
    l.Lexit = vec_calloc(dfo.length);    // bit vector for exit blocks
    l.Lhead = head;
    l.Ltail = tail;
    l.Lpreheader = null;

    vec_setbit(head.Bdfoidx,l.Lloop);    /* add head to the loop         */
    head.Bweight = loop_weight(head.Bweight, 2);  // *20 usage for loop header

    insert(tail,l.Lloop);                /* insert tail in loop          */

L1:
    /* Find all the exit blocks (those blocks with
     * successors outside the loop).
     */

    // for each block in this loop
    for (uint i = 0; (i = cast(uint) vec_index(i, l.Lloop)) < dfo.length; ++i)
    {
        if (dfo[i].BC == BCret || dfo[i].BC == BCretexp || dfo[i].BC == BCexit)
            vec_setbit(i,l.Lexit); /* ret blocks are exit blocks */
        else
        {
            foreach (bl; ListRange(dfo[i].Bsucc))
                if (!vec_testbit(list_block(bl).Bdfoidx,l.Lloop))
                {
                    vec_setbit(i,l.Lexit);
                    break;
                }
        }
    }

    /*  Find preheader, if any, to the loop.
        The preheader is a block that has only the head as a successor.
        All other predecessors of head must be inside the loop.
     */
    l.Lpreheader = null;
    foreach (bl; ListRange(head.Bpred))
    {
        block *b = list_block(bl);

        if (!vec_testbit(b.Bdfoidx,l.Lloop))  /* if not in loop       */
        {
            if (l.Lpreheader)                 /* if already one       */
            {
                l.Lpreheader = null;          /* can only be one      */
                break;
            }
            else
            {
                if (list_next(b.Bsucc))       // if more than 1 successor
                    break;                    // b can't be a preheader
                l.Lpreheader = b;
            }
        }
    }
}

/********************************
 * Support routine for buildloop().
 * Add a block b and all its predecessors to loop lv.
 */

private void insert(block *b, vec_t lv)
{
    assert(b && lv);
    if (!vec_testbit(b.Bdfoidx,lv))     /* if block is not in loop      */
    {
        vec_setbit(b.Bdfoidx,lv);       /* add block to loop            */
        b.Bweight = loop_weight(b.Bweight,1);   // *10 usage count
        foreach (bl; ListRange(b.Bpred))
            insert(list_block(bl),lv);  /* insert all its predecessors  */
    }
}

/**************************************
 * Perform loop rotations.
 * Loop starts as:
 *
 *         prehead
 *          |
 *          v
 *      +->head---->
 *      |   |
 *      |   v
 *      |  body
 *      |   |
 *      |   v
 *      +--tail
 *
 * Two types are done:
 *      1) Header is moved to be past the tail.
 *
 *         prehead
 *          |
 *      +---+
 *      |
 *      |  body<-+
 *      |   |    |
 *      |   v    |
 *      |  tail  |
 *      |   |    |
 *      |   v    |
 *      +->head--+
 *          |
 *          v
 *
 *      2) Header is copied past the tail (done only if MFtime is set).
 *
 *         prehead
 *          |
 *          v
 *         head1-----+
 *          |        |
 *          v        |
 *         body<--+  |
 *          |     |  |
 *          v     |  |
 *         tail   |  |
 *          |     |  |
 *          v     |  |
 *         head2--+  |
 *          |        |
 *          +--------+
 *          v
 *
 * Input:
 *      Loop information (do not depend on the preheader information)
 * Output:
 *      Revised list of blocks, a new dfo and new loop information
 * Returns:
 *      true need to recompute loop data
 */

@trusted
private int looprotate(ref loop l)
{
    block *tail = l.Ltail;
    block *head = l.Lhead;

    //printf("looprotate(%p)\n",l);

    // Do not rotate loop if:
    if (head == tail ||                         // loop is only one block big
        !vec_testbit(head.Bdfoidx,l.Lexit))   // header is not an exit block
        goto Lret;

    if (//iter != 1 &&
        vec_testbit(tail.Bdfoidx,l.Lexit))    // tail is an exit block
        goto Lret;

    // Do not rotate if already rotated
    foreach (b; BlockRange(tail.Bnext))
        if (b == head)                  // if loop already rotated
            goto Lret;

    if (head.BC == BCtry)
         goto Lret;
    if (head.BC == BC_try)
         goto Lret;

    //if (debugc) { printf("looprotate: "); l.print(); }

    if ((go.mfoptim & MFtime) && head.BC != BCswitch && head.BC != BCasm)
    {   // Duplicate the header past the tail (but doing
        // switches would be too expensive in terms of code
        // generated).

        auto head2 = block_calloc(); // create new head block
        head2.Btry = head.Btry;
        head2.Bflags = head.Bflags;
        head.Bflags = BFLnomerg;       // move flags over to head2
        head2.Bflags |= BFLnomerg;
        head2.BC = head.BC;
        assert(head2.BC != BCswitch);
        if (head.Belem)                // copy expression tree
            head2.Belem = el_copytree(head.Belem);
        head2.Bnext = tail.Bnext;
        tail.Bnext = head2;

        // pred(head1) = pred(head) outside loop
        // pred(head2) = pred(head) inside loop
        list_t *pbln;
        auto pbl2 = &(head2.Bpred);
        for (list_t *pbl = &(head.Bpred); *pbl; pbl = pbln)
        {
            if (vec_testbit(list_block(*pbl).Bdfoidx, l.Lloop))
            {   // if this predecessor is inside the loop

                *pbl2 = *pbl;
                *pbl = list_next(*pbl);
                pbln = pbl;                     // don't skip this next one
                (*pbl2).next = null;
                auto bsucc = list_block(*pbl2).Bsucc;
                pbl2 = &((*pbl2).next);
                foreach (bl; ListRange(bsucc))
                    if (list_block(bl) == head)
                    {
                        bl.ptr = cast(void *)head2;
                        goto L2;
                    }
                assert(0);
        L2:
            }
            else
                pbln = &((*pbl).next);      // next predecessor in list
        } // for each pred(head)

        // succ(head2) = succ(head)
        foreach (bl; ListRange(head.Bsucc))
        {
            list_append(&(head2.Bsucc),list_block(bl));
            list_append(&(list_block(bl).Bpred),head2);
        }
        if (debugc) printf("1Rotated loop %p\n", &l);
        go.changes++;
        return true;
    }
    else if (startblock != head
            /* This screws up the OPctor/OPdtor sequence for:
             *   struct CString
             *   {   CString();
             *      ~CString();
             *      int GetLength();
             *   };
             *
             *   void f(void)
             *   {  for(;;)
             *      {   CString s ;
             *    if(s.GetLength()!=0)
             *       break ;
             *      }
             *   }
             */
            && !(config.flags3 & CFG3eh)
            )
    {   // optimize for space
        // Simply position the header past the tail
        foreach (b; BlockRange(startblock))
        {
            if (b.Bnext == head)
            {   // found parent b of head
                b.Bnext = head.Bnext;
                head.Bnext = tail.Bnext;
                tail.Bnext = head;
                if (debugc) printf("2Rotated loop %p\n", &l);
                go.changes++;
                return false;
            }
        }
        assert(0);
    }
Lret:
    return false;
}

private __gshared
{
    int gref;                // parameter for markinvar()
    block *gblock;           // parameter for markinvar()
    vec_t lv;                // parameter for markinvar()
    vec_t gin;               // parameter for markinvar()
    bool doflow;             // true if flow analysis has to be redone
}

/*********************************
 * Loop invariant and induction variable elimination.
 * Input:
 *      iter    which optimization iteration we are on
 */

@trusted
void loopopt()
{
    __gshared Loops startloop_cache;

    Loops startloop = startloop_cache;

    if (debugc) printf("loopopt()\n");
restart:
    file_progress();
    if (blockinit())                    // init block data
    {
        findloops(dfo[], startloop);    // Compute Bweights
        freeloop(startloop);            // free existing loops
        startloop_cache = startloop;
        return;                         // can't handle ASM blocks
    }
    compdom();                          // compute dominators
    findloops(dfo[], startloop);              // find the loops

  L3:
    while (1)
    {
        foreach (ref l; startloop)
        {
            if (looprotate(l))              // rotate the loop
            {
                compdfo();
                blockinit();
                compdom();
                findloops(dfo[], startloop);
                continue L3;
            }
        }
        break;
    }

    // Make sure there is a preheader for each loop.

    addblk = false;                     /* assume no blocks added        */
    foreach (ref l; startloop)
    {
        //if (debugc) l.print();

        if (!l.Lpreheader)             /* if no preheader               */
        {
            block *h;
            block *p;

            if (debugc) printf("Generating preheader for loop\n");
            addblk = true;              /* add one                       */
            p = block_calloc();         // the preheader
            h = l.Lhead;               /* loop header                   */

            /* Find parent of h */
            if (h == startblock)
                startblock = p;
            else
            {
                for (auto ph = startblock; 1; ph = ph.Bnext)
                {
                    assert(ph);         /* should have found it         */
                    if (ph.Bnext == h)
                    {
                        // Link p into block list between ph and h
                        ph.Bnext = p;
                        break;
                    }
                }
            }
            p.Bnext = h;

            l.Lpreheader = p;
            p.BC = BCgoto;
            assert(p.Bsucc == null);
            list_append(&(p.Bsucc),h); /* only successor is h          */
            p.Btry = h.Btry;

            if (debugc) printf("Adding preheader %p to loop %p\n",p,&l);

            // Move preds of h that aren't in the loop to preds of p
            for (list_t bl = h.Bpred; bl;)
            {
                block *b = list_block(bl);

                if (!vec_testbit (b.Bdfoidx, l.Lloop))
                {
                    list_append(&(p.Bpred), b);
                    list_subtract(&(h.Bpred), b);
                    bl = h.Bpred;      /* dunno what subtract did      */

                    /* Fix up successors of predecessors        */
                    foreach (bls; ListRange(b.Bsucc))
                        if (list_block(bls) == h)
                                bls.ptr = cast(void *)p;
                }
                else
                    bl = list_next(bl);
            }
            list_append(&(h.Bpred),p); /* p is a predecessor to h      */
        }
    } /* for */
    if (addblk)                         /* if any blocks were added      */
    {
        compdfo();                      /* compute depth-first order    */
        blockinit();
        compdom();
        findloops(dfo[], startloop);          // recompute block info
        addblk = false;
    }

    /* Do the loop optimizations.
     */

    doflow = true;                      /* do flow analysis             */

    if (go.mfoptim & MFtime)
    {
        if (debugc) printf("Starting loop unrolling\n");
    L2:
        while (1)
        {
            foreach (ref l; startloop)
            {
                if (loopunroll(l))
                {
                    compdfo();                      // compute depth-first order
                    blockinit();
                    compdom();
                    findloops(dfo[], startloop);    // recompute block info
                    doflow = true;
                    continue L2;
                }
            }
            break;
        }
    }

    /* Note that accessing the loops
     * starting from startloop will access them in least nested
     * one first, thus moving LIs out as far as possible
     */
    if (debugc) printf("Starting loop invariants\n");

    foreach_reverse (ref l; startloop)
    {
        //if (debugc) l.print();

        file_progress();
        assert(l.Lpreheader);
        if (doflow)
        {
            flowrd();               /* compute reaching definitions  */
            flowlv();               /* compute live variables        */
            flowae();               // compute available expressions
            doflow = false;         /* no need to redo it           */
            if (go.defnod.length == 0)     /* if no definition elems       */
                break;              /* no need to optimize          */
        }
        lv = l.Lloop;
        if (debugc) printf("...Loop %p start...\n",&l);

        /* Unmark all elems in this loop         */
        for (uint i = 0; (i = cast(uint) vec_index(i, lv)) < dfo.length; ++i)
            if (dfo[i].Belem)
                unmarkall(dfo[i].Belem);       /* unmark all elems     */

        /* Find & mark all LIs   */
        gin = vec_clone(l.Lpreheader.Bout);
        vec_t rd = vec_calloc(go.defnod.length);        /* allocate our running RD vector */
        for (uint i = 0; (i = cast(uint) vec_index(i, lv)) < dfo.length; ++i) // for each block in loop
        {
            block *b = dfo[i];

            if (debugc) printf("B%d\n",i);
            if (b.Belem)
            {
                vec_copy(rd, b.Binrd); // IN reaching defs
                static if (0)
                {
                    printf("i = %d\n",i);
                    {
                        for (int j = 0; j < go.defnod.length; j++)
                            elem_print(go.defnod[j].DNelem);
                    }
                    printf("rd    : "); vec_println(rd);
                }
                gblock = b;
                gref = 0;
                if (b != l.Lhead)
                    gref = 1;
                markinvar(b.Belem, rd);
                static if (0)
                {
                    printf("B%d\n", i);
                    {
                        foreach (j; 0 .. go.defnod.length)
                        {
                            printf("  [%2d] ", j);
                            WReqn(go.defnod[j].DNelem);
                            printf("\n");
                        }
                    }
                    printf("rd    : "); vec_println(rd);
                    printf("Boutrd: "); vec_println(b.Boutrd);
                }
                assert(vec_equal(rd, b.Boutrd));
            }
            else
                assert(vec_equal(b.Binrd, b.Boutrd));
        }
        vec_free(rd);
        vec_free(gin);

        /* Move loop invariants  */
        for (uint i = 0; (i = cast(uint) vec_index(i, lv)) < dfo.length; ++i)
        {
            uint domexit;               // true if this block dominates all
                                        // exit blocks of the loop

            for (uint j = 0; (j = cast(uint) vec_index(j, l.Lexit)) < dfo.length; ++j) // for each exit block
            {
                if (!vec_testbit (i, dfo[j].Bdom))
                {
                    domexit = 0;
                    goto L1;                // break if !(i dom j)
                }
            }
            // if i dom (all exit blocks)
            domexit = 1;
        L1:
            if (dfo[i].Belem)
            {   // If there is any hope of making an improvement
                if (domexit || l.Llis.length)
                {
                    //if (dfo[i] != l.Lhead)
                        //domexit |= 2;
                    movelis(dfo[i].Belem, dfo[i], l, domexit);
                }
            }
        }
        if (debugc) printf("...Loop %p done...\n",&l);

        if (go.mfoptim & MFliv)
        {
            loopiv(l);              /* induction variables          */
            if (addblk)             /* if we added a block          */
            {
                compdfo();
                goto restart;       /* play it safe and start over  */
            }
        }
    } /* for */
    freeloop(startloop);
    startloop_cache = startloop;
}

/*****************************
 * If elem is loop invariant, mark it.
 * Input:
 *      lv =    vector of all the blocks in this loop.
 *      rd =    vector of loop invariants for this elem. This must be
 *              continually updated.
 * Note that we do not iterate until no more LIs are found. The only
 * thing this would buy us is stuff that depends on LI assignments.
 */

@trusted
private void markinvar(elem *n,vec_t rd)
{
    vec_t tmp;
    uint i;
    Symbol *v;
    elem *n1;

    assert(n && rd);
    assert(vec_numbits(rd) == go.defnod.length);
    switch (n.Eoper)
    {
        case OPaddass:  case OPminass:  case OPmulass:  case OPandass:
        case OPorass:   case OPxorass:  case OPdivass:  case OPmodass:
        case OPshlass:  case OPshrass:  case OPashrass:
        case OPpostinc: case OPpostdec:
        case OPcall:
        case OPvecsto:
        case OPcmpxchg:
            markinvar(n.EV.E2,rd);
            goto case OPnegass;

        case OPnegass:
            n1 = n.EV.E1;
            if (n1.Eoper == OPind)
                    markinvar(n1.EV.E1,rd);
            else if (OTbinary(n1.Eoper))
            {   markinvar(n1.EV.E1,rd);
                markinvar(n1.EV.E2,rd);
            }
        L2:
            if (n.Eoper == OPcall ||
                gblock.Btry ||
                !(n1.Eoper == OPvar &&
                    symbol_isintab(n1.EV.Vsym)))
            {
                gref = 1;
            }

            updaterd(n,rd,null);
            break;

        case OPcallns:
            markinvar(n.EV.E2,rd);
            markinvar(n.EV.E1,rd);
            break;

        case OPstrcpy:
        case OPstrcat:
        case OPmemcpy:
        case OPmemset:
            markinvar(n.EV.E2,rd);
            markinvar(n.EV.E1,rd);
            updaterd(n,rd,null);
            break;

        case OPbtc:
        case OPbtr:
        case OPbts:
            markinvar(n.EV.E1,rd);
            markinvar(n.EV.E2,rd);
            updaterd(n,rd,null);
            break;

        case OPucall:
            markinvar(n.EV.E1,rd);
            goto case OPasm;

        case OPasm:
            gref = 1;
            updaterd(n,rd,null);
            break;

        case OPucallns:
        case OPstrpar:
        case OPstrctor:
        case OPvector:
        case OPvoid:
        case OPstrlen:
        case OPddtor:
        case OPinp:
        case OPprefetch:                // don't mark E2
            markinvar(n.EV.E1,rd);
            break;

        case OPcond:
        case OPparam:
        case OPstrcmp:
        case OPmemcmp:
        case OPbt:                      // OPbt is like OPind, assume not LI
        case OPoutp:
            markinvar(n.EV.E1,rd);
            markinvar(n.EV.E2,rd);
            break;

        case OPandand:
        case OPoror:
            markinvar(n.EV.E1,rd);
            tmp = vec_clone(rd);
            markinvar(n.EV.E2,tmp);
            if (el_returns(n.EV.E2))
                vec_orass(rd,tmp);              // rd |= tmp
            vec_free(tmp);
            break;

        case OPcolon:
        case OPcolon2:
            tmp = vec_clone(rd);
            switch (el_returns(n.EV.E1) * 2 | int(el_returns(n.EV.E2)))
            {
                case 3: // E1 and E2 return
                    markinvar(n.EV.E1,rd);
                    markinvar(n.EV.E2,tmp);
                    vec_orass(rd,tmp);              // rd |= tmp
                    break;
                case 2: // E1 returns
                    markinvar(n.EV.E1,rd);
                    markinvar(n.EV.E2,tmp);
                    break;
                case 1: // E2 returns
                    markinvar(n.EV.E1,tmp);
                    markinvar(n.EV.E2,rd);
                    break;
                case 0: // neither returns
                    markinvar(n.EV.E1,tmp);
                    vec_copy(tmp,rd);
                    markinvar(n.EV.E2,tmp);
                    break;
                default:
                    assert(0);
            }
            vec_free(tmp);
            break;

        case OPaddr:            // mark addresses of OPvars as LI
            markinvar(n.EV.E1,rd);
            if (n.EV.E1.Eoper == OPvar || isLI(n.EV.E1))
                makeLI(n);
            break;

        case OPmsw:
        case OPneg:     case OPbool:    case OPnot:     case OPcom:
        case OPs16_32:  case OPd_s32:   case OPs32_d:
        case OPd_s16:   case OPs16_d:   case OPd_f:     case OPf_d:
        case OP32_16:   case OPu8_16:
        case OPld_d:    case OPd_ld:
        case OPld_u64:
        case OPc_r:     case OPc_i:
        case OPu16_32:
        case OPu16_d:   case OPd_u16:
        case OPs8_16:   case OP16_8:
        case OPd_u32:   case OPu32_d:

        case OPs32_64:  case OPu32_64:
        case OP64_32:
        case OPd_s64:   case OPd_u64:
        case OPs64_d:
        case OPu64_d:
        case OP128_64:
        case OPs64_128:
        case OPu64_128:

        case OPabs:
        case OPtoprec:
        case OPrndtol:
        case OPrint:
        case OPsetjmp:
        case OPbsf:
        case OPbsr:
        case OPbswap:
        case OPpopcnt:
        case OPsqrt:
        case OPsin:
        case OPcos:
        case OPvp_fp: /* BUG for MacHandles */
        case OPnp_f16p: case OPf16p_np: case OPoffset: case OPnp_fp:
        case OPcvp_fp:
        case OPvecfill:
            markinvar(n.EV.E1,rd);
            if (isLI(n.EV.E1))        /* if child is LI               */
                makeLI(n);
            break;

        case OPeq:
        case OPstreq:
            markinvar(n.EV.E2,rd);
            n1 = n.EV.E1;
            markinvar(n1,rd);

            /* Determine if assignment is LI. Conditions are:       */
            /* 1) Rvalue is LI                                      */
            /* 2) Lvalue is a variable (simplifies things a lot)    */
            /* 3) Lvalue can only be affected by unambiguous defs   */
            /* 4) No rd's of lvalue that are within the loop (other */
            /*    than the current def)                             */
            if (isLI(n.EV.E2) && n1.Eoper == OPvar)          /* 1 & 2 */
            {
                v = n1.EV.Vsym;
                if (v.Sflags & SFLunambig)
                {
                    tmp = vec_calloc(go.defnod.length);
                    //filterrd(tmp,rd,v);
                    listrds(rd,n1,tmp,null);
                    for (i = 0; (i = cast(uint) vec_index(i, tmp)) < go.defnod.length; ++i)
                        if (go.defnod[i].DNelem != n &&
                            vec_testbit(go.defnod[i].DNblock.Bdfoidx,lv))
                                goto L3;
                    makeLI(n);      // then the def is LI
                L3: vec_free(tmp);
                }
            }
            goto L2;

        case OPadd:     case OPmin:     case OPmul:     case OPand:
        case OPor:      case OPxor:     case OPdiv:     case OPmod:
        case OPshl:     case OPshr:     case OPeqeq:    case OPne:
        case OPlt:      case OPle:      case OPgt:      case OPge:
        case OPashr:
        case OPror:     case OProl:
        case OPbtst:

        case OPunord:   case OPlg:      case OPleg:     case OPule:
        case OPul:      case OPuge:     case OPug:      case OPue:
        case OPngt:     case OPnge:     case OPnlt:     case OPnle:
        case OPord:     case OPnlg:     case OPnleg:    case OPnule:
        case OPnul:     case OPnuge:    case OPnug:     case OPnue:

        case OPcomma:
        case OPpair:
        case OPrpair:
        case OPremquo:
        case OPscale:
        case OPyl2x:
        case OPyl2xp1:
            markinvar(n.EV.E1,rd);
            markinvar(n.EV.E2,rd);
            if (isLI(n.EV.E2) && isLI(n.EV.E1))
                    makeLI(n);
            break;

        case OPind:                     /* must assume this is not LI   */
            markinvar(n.EV.E1,rd);
            if (isLI(n.EV.E1))
            {
                static if (0)
                {
                    // This doesn't work with C++, because exp2_ptrtocomtype() will
                    // transfer const to where it doesn't belong.
                    if (n.Ety & mTYconst)
                    {
                        makeLI(n);
                    }

                    // This was disabled because it was marking as LI
                    // the loop dimension for the [i] array if
                    // a[j][i] was in a loop. This meant the a[j] array bounds
                    // check for the a[j].length was skipped.
                    else if (n.Ejty)
                    {
                        tmp = vec_calloc(go.defnod.length);
                        filterrdind(tmp,rd,n);  // only the RDs pertaining to n

                        // if (no RDs within loop)
                        //      then it's loop invariant

                        for (i = 0; (i = cast(uint) vec_index(i, tmp)) < go.defnod.length; ++i)  // for each RD
                            if (vec_testbit(go.defnod[i].DNblock.Bdfoidx,lv))
                                goto L10;       // found a RD in the loop

                        // If gref has occurred, this can still be LI
                        // if n is an AE that was also an AE at the
                        // point of gref.
                        // We can catch a subset of these cases by looking
                        // at the AEs at the start of the loop.
                        if (gref)
                        {
                            int j;

                            //printf("\tn is: "); WReqn(n); printf("\n");
                            for (j = 0; (j = cast(uint) vec_index(j, gin)) < go.exptop; ++j)
                            {
                                elem *e = go.expnod[j];

                                //printf("\t\tgo.expnod[%d] = %p\n",j,e);
                                //printf("\t\tAE is: "); WReqn(e); printf("\n");
                                if (el_match2(n,e))
                                {
                                    makeLI(n);
                                    //printf("Ind LI: "); WReqn(n); printf("\n");
                                    break;
                                }
                            }
                        }
                        else
                            makeLI(n);
                  L10:
                        vec_free(tmp);
                        break;
                    }
                }
            }
            break;

        case OPvar:
            v = n.EV.Vsym;
            if (v.Sflags & SFLunambig)     // must be unambiguous to be LI
            {
                tmp = vec_calloc(go.defnod.length);
                //filterrd(tmp,rd,v);       // only the RDs pertaining to v
                listrds(rd,n,tmp,null);  // only the RDs pertaining to v

                // if (no RDs within loop)
                //  then it's loop invariant

                for (i = 0; (i = cast(uint) vec_index(i, tmp)) < go.defnod.length; ++i)  // for each RD
                    if (vec_testbit(go.defnod[i].DNblock.Bdfoidx,lv))
                        goto L1;    // found a RD in the loop
                makeLI(n);

            L1: vec_free(tmp);
            }
            break;

        case OPstring:
        case OPrelconst:
        case OPconst:                   /* constants are always LI      */
        case OPframeptr:
            makeLI(n);
            break;

        case OPinfo:
            markinvar(n.EV.E2,rd);
            break;

        case OPstrthis:
        case OPmark:
        case OPctor:
        case OPdtor:
        case OPdctor:
        case OPhalt:
        case OPgot:                     // shouldn't OPgot be makeLI ?
            break;

        default:
            WROP(n.Eoper);
            //printf("n.Eoper = %d, OPconst = %d\n", n.Eoper, OPconst);
            assert(0);
    }

    debug
    {
        if (debugc && isLI(n))
        {
            printf("  LI elem: ");
            WReqn(n);
            printf("\n");
        }
    }
}

/********************
 * Update rd vector.
 * Input:
 *      n       assignment elem or function call elem or OPasm elem
 *      rd      reaching def vector to update
 *              (clear bits for defs we kill, set bit for n (which is the
 *               def we are genning))
 *      vecdim  go.defnod.length
 */

extern (C) {
@trusted
void updaterd(elem *n,vec_t GEN,vec_t KILL)
{
    const op = n.Eoper;
    elem *t;

    assert(OTdef(op));
    assert(GEN);
    elem_debug(n);

    uint ni = n.Edef;
    assert(ni != -1);

    // If unambiguous def
    if (OTassign(op) && (t = n.EV.E1).Eoper == OPvar)
    {
        vec_t v = go.defnod[ni].DNunambig;
        assert(v);
        if (KILL)
            vec_orass(KILL, v);
        vec_subass(GEN, v);
    }
    else
    {
        static if (0)
        {
            if (OTassign(op) && t.Eoper != OPvar && t.Ejty)
            {
                // for all unambig defs in go.defnod[]
                foreach (uint i; 0 .. go.defnod.length)
                {
                    elem *tn = go.defnod[i].DNelem;
                    elem *tn1;

                    if (tn == n)
                        ni = i;

                    if (!OTassign(tn.Eoper))
                        continue;

                    // If def of same variable, kill that def
                    tn1 = tn.EV.E1;
                    if (tn1.Eoper != OPind || t.Ejty != tn1.Ejty)
                        continue;

                    if (KILL)
                        vec_setbit(i,KILL);
                    vec_clearbit(i,GEN);
                }
            }
        }
    }

    vec_setbit(ni,GEN);                 // set bit in GEN for this def
}
}

/***************************
 * Mark all elems as not being loop invariant.
 */

@trusted
private void unmarkall(elem *e)
{
    for (; 1; e = e.EV.E1)
    {
        assert(e);
        e.Nflags &= ~NFLli;            /* unmark this elem             */
        if (OTunary(e.Eoper))
            continue;
        else if (OTbinary(e.Eoper))
        {
            unmarkall(e.EV.E2);
            continue;
        }
        return;
    }
}


/********************************
 * Search for references to v in tree n before nstop is encountered.
 * Params:
 *      v = symbol to search for
 *      n = tree to search
 *      nstop = stop searching tree when reaching this elem
 * Returns:
 *    true if there are any refs of v in n before nstop is encountered
 */

@trusted
private bool refs(Symbol *v,elem *n,elem *nstop)
{
    symbol_debug(v);
    assert(symbol_isintab(v));
    assert(v.Ssymnum < globsym.length);
    bool stop = false;

    // Walk tree in evaluation order
    bool walk(elem* n)
    {
        elem_debug(n);
        assert(n);

        if (stop)
            return false;
        bool f = false;
        const op = n.Eoper;
        if (OTunary(op))
            f = walk(n.EV.E1);
        else if (OTbinary(op))
        {
            if (ERTOL(n))                   /* watch order of evaluation    */
            {
                /* Note that (OPvar = e) is not a ref of OPvar, whereas     */
                /* ((OPbit OPvar) = e) is a ref of OPvar, and (OPvar op= e) is */
                /* a ref of OPvar, etc.                                     */
                f = walk(n.EV.E2);
                if (!f)
                {
                    if (op == OPeq)
                    {
                        if (n.EV.E1.Eoper != OPvar)
                            f = walk(n.EV.E1.EV.E1);
                    }
                    else
                        f = walk(n.EV.E1);
                }
            }
            else
                f = walk(n.EV.E1) || walk(n.EV.E2);
        }

        if (n == nstop)
            stop = true;
        else if (n.Eoper == OPvar)           /* if variable reference        */
            return v == n.EV.Vsym;
        else if (op == OPasm)                /* everything is referenced     */
            return true;
        return f;
    }

    return walk(n);
}

/*************************
 * Move LIs to preheader.
 * Conditions to be satisfied for code motion are:
 *      1) All exit blocks are dominated (true before this is called).
 *                      -- OR --
 *      2) Variable assigned by a statement is not live on entering
 *         any successor outside the loop of any exit block of the
 *         loop.
 *
 *      3) Cannot move assignment to variable if there are any other
 *         assignments to that variable within the loop (true or
 *         assignment would not have been marked LI).
 *      4) Cannot move assignments to a variable if there is a use
 *         of that variable in this loop that is reached by any other
 *         def of it.
 *      5) Cannot move expressions that have side effects.
 *      6) Do not move assignments to variables that could be affected
 *         by ambiguous defs.
 *      7) It is not worth it to move expressions of the form:
 *              (var == const)
 * Input:
 *      n       the elem we're considering moving
 *      b       the block this elem is in
 *      l       the loop we're in
 *      domexit flags
 *      bit 0:  1       this branch is always executed
 *              0       this branch is only sometimes executed
 *      bit 1:  1       do not move LIs that could throw exceptions
 *                      or cannot be moved past possibly thrown exceptions
 * Returns:
 *      revised domexit
 */

@trusted
private void movelis(elem* n, block* b, ref loop l, ref uint pdomexit)
{
    vec_t tmp;
    elem *ne;
    elem *t;
    elem *n2;
    Symbol *v;
    tym_t ty;

Lnextlis:
    //if (isLI(n)) { printf("movelis(B%d, ", b.Bdfoidx); WReqn(n); printf(")\n"); }
    assert(n);
    elem_debug(n);
    const op = n.Eoper;
    switch (op)
    {
        case OPvar:
        case OPconst:
        case OPrelconst:
            goto Lret;

        case OPandand:
        case OPoror:
        case OPcond:
        {
            uint domexit;

            movelis(n.EV.E1,b,l,pdomexit);        // always executed
            domexit = pdomexit & ~1;   // sometimes executed
            movelis(n.EV.E2,b,l,domexit);
            pdomexit |= domexit & 2;
            goto Lret;
        }

        case OPeq:
            // Do loop invariant assignments
            if (isLI(n) && n.EV.E1.Eoper == OPvar)
            {
                v = n.EV.E1.EV.Vsym;          // variable index number

                if (!(v.Sflags & SFLunambig)) goto L3;         // case 6

                // If case 4 is not satisfied, return

                // Function parameters have an implied definition prior to the
                // first block of the function. Unfortunately, the rd vector
                // does not take this into account. Therefore, we assume the
                // worst and reject assignments to function parameters.
                if (v.Sclass == SCparameter || v.Sclass == SCregpar ||
                    v.Sclass == SCfastpar || v.Sclass == SCshadowreg)
                        goto L3;

                if (el_sideeffect(n.EV.E2)) goto L3;              // case 5

                // If case 1 or case 2 is not satisfied, return

                if (!(pdomexit & 1))                   // if not case 1
                {
                    uint i;
                    for (i = 0; (i = cast(uint) vec_index(i, l.Lexit)) < dfo.length; ++i)  // for each exit block
                    {
                        foreach (bl; ListRange(dfo[i].Bsucc))
                        {
                            block *s;           // successor to exit block

                            s = list_block(bl);
                            if (!vec_testbit(s.Bdfoidx,l.Lloop) &&
                                (!symbol_isintab(v) ||
                                 vec_testbit(v.Ssymnum,s.Binlv))) // if v is live on exit
                                    goto L3;
                        }
                    }
                }

                tmp = vec_calloc(go.defnod.length);
                uint i;
                for (i = 0; (i = cast(uint) vec_index(i, l.Lloop)) < dfo.length; ++i)  // for each block in loop
                {
                    if (dfo[i] == b)        // except this one
                        continue;

                    //<if there are any RDs of v in Binrd other than n>
                    //    <if there are any refs of v in that block>
                    //        return;

                    //filterrd(tmp,dfo[i].Binrd,v);
                    listrds(dfo[i].Binrd,n.EV.E1,tmp,null);
                    uint j;
                    for (j = 0; (j = cast(uint) vec_index(j, tmp)) < go.defnod.length; ++j)  // for each RD of v in Binrd
                    {
                        if (go.defnod[j].DNelem == n)
                            continue;
                        if (dfo[i].Belem &&
                            refs(v,dfo[i].Belem,cast(elem *)null)) //if refs of v
                        {
                            vec_free(tmp);
                            goto L3;
                        }
                        break;
                    }
                } // foreach

                // <if there are any RDs of v in b.Binrd other than n>
                //     <if there are any references to v before the
                //      assignment to v>
                //         <can't move this assignment>

                //filterrd(tmp,b.Binrd,v);
                listrds(b.Binrd,n.EV.E1,tmp,null);
                uint j;
                for (j = 0; (j = cast(uint) vec_index(j, tmp)) < go.defnod.length; ++j)  // for each RD of v in Binrd
                {
                    if (go.defnod[j].DNelem == n)
                        continue;
                    if (b.Belem && refs(v,b.Belem,n))
                    {
                        vec_free(tmp);
                        goto L3;            // can't move it
                    }
                    break;                  // avoid redundant looping
                }
                vec_free(tmp);

                // We have an LI assignment, n.
                // Check to see if the rvalue is already in the preheader.
                foreach (e; l.Llis)
                {
                    if (el_match(n.EV.E2, e.EV.E2))
                    {
                        el_free(n.EV.E2);
                        n.EV.E2 = el_calloc();
                        el_copy(n.EV.E2, e.EV.E1);
                        if (debugc) printf("LI assignment rvalue was replaced\n");
                        doflow = true;
                        go.changes++;
                        break;
                    }
                }

                // move assignment elem to preheader
                if (debugc) printf("Moved LI assignment ");

                debug
                    if (debugc)
                    {
                        WReqn(n);
                        printf(";\n");
                    }

                go.changes++;
                doflow = true;                  // redo flow analysis
                ne = el_calloc();
                el_copy(ne,n);                  // create assignment elem
                assert(l.Lpreheader);          // make sure there is one
                appendelem(ne,&(l.Lpreheader.Belem)); // append ne to preheader
                l.Llis.push(ne);

                el_copy(n,ne.EV.E1);      // replace n with just a reference to v
                goto Lret;
            } // if
            break;

        case OPcall:
        case OPucall:
            pdomexit |= 2;
            break;

        case OPpair:
        case OPrpair:                   // don't move these, as they do not do computation
            movelis(n.EV.E1,b,l,pdomexit);
            n = n.EV.E2;
            goto Lnextlis;

        default:
            break;
    }

L3:
    // Do leaves of non-LI expressions, leaves of = elems that didn't
    // meet the invariant assignment removal criteria, and don't do leaves
    if (OTleaf(op))
        goto Lret;
    if (!isLI(n) || op == OPeq || op == OPcomma || OTrel(op) || op == OPnot ||
      // These are usually addressing modes, so moving them is a net loss
      (I32 && op == OPshl && n.EV.E2.Eoper == OPconst && el_tolong(n.EV.E2) <= 3UL)
     )
    {
        if (OTassign(op))
        {
            elem *n1 = n.EV.E1;
            elem *n11;

            if (OTbinary(op))
                movelis(n.EV.E2,b,l,pdomexit);

            // Do lvalue only if it is an expression
            if (n1.Eoper == OPvar)
                goto Lret;
            n11 = n1.EV.E1;
            if (OTbinary(n1.Eoper))
            {
                movelis(n11,b,l,pdomexit);
                n = n1.EV.E2;
            }
            // If *(x + c), just make x the LI, not the (x + c).
            // The +c comes free with the addressing mode.
            else if (n1.Eoper == OPind &&
                    isLI(n11) &&
                    n11.Eoper == OPadd &&
                    n11.EV.E2.Eoper == OPconst
                    )
            {
                n = n11.EV.E1;
            }
            else
                n = n11;
            movelis(n,b,l,pdomexit);
            if (b.Btry || !(n1.Eoper == OPvar && symbol_isintab(n1.EV.Vsym)))
            {
                //printf("assign to global => domexit |= 2\n");
                pdomexit |= 2;
            }
        }
        else if (OTunary(op))
        {
            elem *e1 = n.EV.E1;

            // If *(x + c), just make x the LI, not the (x + c).
            // The +c comes free with the addressing mode.
            if (op == OPind &&
                isLI(e1) &&
                e1.Eoper == OPadd &&
                e1.EV.E2.Eoper == OPconst
               )
            {
                n = e1.EV.E1;
            }
            else
                n = e1;
        }
        else if (OTbinary(op))
        {
            movelis(n.EV.E1,b,l,pdomexit);
            n = n.EV.E2;
        }
        goto Lnextlis;
  }

  if (el_sideeffect(n))
        goto Lret;

    static if (0)
    {
        printf("*pdomexit = %u\n", pdomexit);
        if (pdomexit & 2)
        {
            // If any indirections, can't LI it

            // If this operand has already been indirected, we can let
            // it pass.
            Symbol *s;

            printf("looking at:\n");
            elem_print(n);
            s = el_basesym(n.EV.E1);
            if (s)
            {
                foreach (el; l.Llis)
                {
                    el = el.EV.E2;
                    elem_print(el);
                    if (el.Eoper == OPind && el_basesym(el.EV.E1) == s)
                    {
                        printf("  pass!\n");
                        goto Lpass;
                    }
                }
            }
            printf("  skip!\n");
            goto Lret;

        Lpass:
        }
    }

    // Move the LI expression to the preheader
    if (debugc) printf("Moved LI expression ");

    debug
        if (debugc)
        {
            WReqn(n);
            printf(";\n");
        }

    // See if it's already been moved
    ty = n.Ety;
    foreach (el; l.Llis)
    {
        tym_t ty2;

        //printf("existing LI: "); WReqn(el); printf("\n");
        ty2 = el.EV.E2.Ety;
        if (tysize(ty) == tysize(ty2))
        {
            el.EV.E2.Ety = ty;
            if (el_match(n,el.EV.E2))
            {
                el.EV.E2.Ety = ty2;
                if (!OTleaf(n.Eoper))
                {       el_free(n.EV.E1);
                        if (OTbinary(n.Eoper))
                                el_free(n.EV.E2);
                }
                el_copy(n,el.EV.E1);      // make copy of temp
                n.Ety = ty;

                debug
                    if (debugc)
                    {   printf("Already moved: LI expression replaced with ");
                        WReqn(n);
                        printf("\nPreheader %d expression %p ",
                        l.Lpreheader.Bdfoidx,l.Lpreheader.Belem);
                        WReqn(l.Lpreheader.Belem);
                        printf("\n");
                    }

                go.changes++;
                doflow = true;                  // redo flow analysis
                goto Lret;
            }
            el.EV.E2.Ety = ty2;
        }
    }

    if (!(pdomexit & 1))                       // if only sometimes executed
    {
        if (debugc) printf(" doesn't dominate exit\n");
        goto Lret;                              // don't move LI
    }

    if (tyaggregate(n.Ety))
        goto Lret;

    go.changes++;
    doflow = true;                              // redo flow analysis

    t = el_alloctmp(n.Ety);                     /* allocate temporary t */

    debug
    {
        if (debugc) printf("movelis() introduced new variable '%s' of type ",t.EV.Vsym.Sident.ptr);
        if (debugc) WRTYxx(t.Ety);
        if (debugc) printf("\n");
    }

    n2 = el_calloc();
    el_copy(n2,n);                              /* create copy n2 of n  */
    ne = el_bin(OPeq,t.Ety,t,n2);               /* create elem t=n2     */
    assert(l.Lpreheader);                       /* make sure there is one */
    appendelem(ne,&(l.Lpreheader.Belem));       /* append ne to preheader */

    debug
        if (debugc)
        {
            printf("Preheader %d expression %p\n\t",
            l.Lpreheader.Bdfoidx,l.Lpreheader.Belem);
            WReqn(l.Lpreheader.Belem);
            printf("\nLI expression replaced with "); WReqn(t);
            printf("\n");
        }

    el_copy(n,t);                                 /* replace this elem with t */

    // Remember LI expression in elem list
    l.Llis.push(ne);

Lret:

}

/***************************
 * Append elem to existing elem using an OPcomma elem.
 * Input:
 *      n       elem to append
 *      *pn     elem to append to
 */

@trusted
private void appendelem(elem *n,elem **pn)
{
    assert(n && pn);
    if (*pn)                                    /* if this elem exists  */
    {
        while ((*pn).Eoper == OPcomma)          /* while we see OPcomma elems */
        {
            (*pn).Ety = n.Ety;
            pn = &((*pn).EV.E2);                /* cruise down right side */
        }
        *pn = el_bin(OPcomma,n.Ety,*pn,n);
    }
    else
        *pn = n;                                /* else create a elem   */
}

/************** LOOP INDUCTION VARIABLES **********************/

/****************************
 * Create a new famlist entry.
 */

@trusted
private void newfamlist(famlist* fl, tym_t ty)
{
    eve c = void;
    memset(&c,0,c.sizeof);

    fl.FLty = ty;
    switch (tybasic(ty))
    {   case TYfloat:
            c.Vfloat = 1;
            break;

        case TYdouble:
        case TYdouble_alias:
            c.Vdouble = 1;
            break;

        case TYldouble:
            c.Vldouble = 1;
            break;

        case TYbool:
        case TYchar:
        case TYschar:
        case TYuchar:
            c.Vchar = 1;
            break;

        case TYshort:
        case TYushort:
        case TYchar16:
        case TYwchar_t:             // BUG: what about 4 byte wchar_t's?
            c.Vshort = 1;
            break;

        case TYsptr:
        case TYcptr:
        case TYfptr:
        case TYvptr:
        case TYnptr:
        case TYnullptr:
        case TYimmutPtr:
        case TYsharePtr:
        case TYrestrictPtr:
        case TYfgPtr:
            ty = TYint;
            if (I64)
                ty = TYllong;
            goto case TYuint;

        case TYint:
        case TYuint:
            c.Vint = 1;
            break;

        case TYhptr:
            ty = TYlong;
            goto case TYlong;

        case TYlong:
        case TYulong:
        case TYdchar:
        default:
            c.Vlong = 1;
            break;
    }
    fl.c1 = el_const(ty,&c);               /* c1 = 1               */
    c.Vldouble = 0;
    if (typtr(ty))
    {
        ty = TYint;
        if (tybasic(ty) == TYhptr)
            ty = TYlong;
        if (I64)
            ty = TYllong;
    }
    fl.c2 = el_const(ty,&c);               /* c2 = 0               */
}

/***************************
 * Remove induction variables from loop l.
 * Loop invariant removal should have been done just previously.
 */

@trusted
private void loopiv(ref loop l)
{
    if (debugc) printf("loopiv(%p)\n", &l);
    assert(l.Livlist.length == 0 && l.Lopeqlist.length == 0);
    elimspec(l);
    if (doflow)
    {
        flowrd();               /* compute reaching defs                */
        flowlv();               /* compute live variables               */
        flowae();               // compute available expressions
        doflow = false;
    }
    findbasivs(l);              /* find basic induction variables       */
    findopeqs(l);               // find op= variables
    findivfams(l);              /* find IV families                     */
    elimfrivivs(l);             /* eliminate less useful family IVs     */
    intronvars(l);              /* introduce new variables              */
    elimbasivs(l);              /* eliminate basic IVs                  */
    if (!addblk)                // adding a block changes the Binlv
        elimopeqs(l);           // eliminate op= variables

    foreach (ref iv; l.Livlist)
        iv.reset();
    l.Livlist.reset();          // reset for reuse

    foreach (ref iv; l.Lopeqlist)
        iv.reset();
    l.Lopeqlist.reset();        // reset for reuse

    /* Do copy propagation and dead assignment elimination        */
    /* upon return to optfunc()                                   */
}

/*************************************
 * Find basic IVs of loop l.
 * A basic IV x of loop l is a variable x which has
 * exactly one assignment within l of the form:
 * x += c or x -= c, where c is either a constant
 * or a LI.
 * Input:
 *      go.defnod[] loaded with all the definition elems of the loop
 */

@trusted
private void findbasivs(ref loop l)
{
    vec_t poss,notposs;
    elem *n;
    bool ambdone;

    ambdone = false;
    poss = vec_calloc(globsym.length);
    notposs = vec_calloc(globsym.length);  /* vector of all variables      */
                                        /* (initially all unmarked)     */

    /* for each def in go.defnod[] that is within loop l     */

    foreach (const i; 0 .. go.defnod.length)
    {
        if (!vec_testbit(go.defnod[i].DNblock.Bdfoidx,l.Lloop))
            continue;               /* def is not in the loop       */

        n = go.defnod[i].DNelem;
        elem_debug(n);
        if (OTassign(n.Eoper) && n.EV.E1.Eoper == OPvar)
        {
            Symbol *s;                  /* if unambiguous def           */

            s = n.EV.E1.EV.Vsym;
            if (symbol_isintab(s))
            {
                SYMIDX v;

                v = n.EV.E1.EV.Vsym.Ssymnum;
                if ((n.Eoper == OPaddass || n.Eoper == OPminass ||
                     n.Eoper == OPpostinc || n.Eoper == OPpostdec) &&
                        (n.EV.E2.Eoper == OPconst || /* if x += c or x -= c          */
                         n.EV.E2.Eoper == OPvar && isLI(n.EV.E2)))
                {
                    if (vec_testbit(v,poss))
                        /* We've already seen this def elem,    */
                        /* therefore there is more than one     */
                        /* def of v within the loop, therefore  */
                        /* v is not a basic IV.                 */
                        vec_setbit(v,notposs);
                    else
                        vec_setbit(v,poss);
                }
                else                    /* else mark as not possible    */
                    vec_setbit(v,notposs);
            }
        }
        else                            /* else ambiguous def           */
        {
            /* mark any vars that could be affected by              */
            /* this def as not possible                             */

            if (!ambdone)           /* avoid redundant loops        */
            {
                foreach (j; 0 .. globsym.length)
                {
                    if (!(globsym[j].Sflags & SFLunambig))
                        vec_setbit(j,notposs);
                }
                ambdone = true;
            }
        }
    }
    static if (0)
    {
        printf("poss    "); vec_println(poss);
        printf("notposs "); vec_println(notposs);
    }
    vec_subass(poss,notposs);             /* poss = poss - notposs        */

    /* create list of IVs */
    uint i;
    for (i = 0; (i = cast(uint) vec_index(i, poss)) < globsym.length; ++i)  // for each basic IV
    {
        Symbol *s;

        /* Skip if we don't want it to be a basic IV (see funcprev())   */
        s = globsym[i];
        assert(symbol_isintab(s));
        if (s.Sflags & SFLnotbasiciv)
            continue;

        // Do not use aggregates as basic IVs. This is because the other loop
        // code doesn't check offsets into symbols, (assuming everything
        // is at offset 0). We could perhaps amend this by allowing basic IVs
        // if the struct consists of only one data member.
        if (tyaggregate(s.ty()))
            continue;

        // Do not use complex types as basic IVs, as the code gen isn't up to it
        if (tycomplex(s.ty()))
                continue;

        auto biv = l.Livlist.push();
        biv.IVbasic = s;               // symbol of basic IV
        biv.IVincr = null;

        if (debugc) printf("Symbol '%s' (%d) is a basic IV, ", s.Sident.ptr, i);

        /* We have the sym idx of the basic IV. We need to find         */
        /* the parent of the increment elem for it.                     */

        /* First find the go.defnod[]      */
        foreach (j; 0 .. go.defnod.length)
        {
            /* If go.defnod is a def of i and it is in the loop        */
            if (go.defnod[j].DNelem.EV.E1 &&     /* OPasm are def nodes  */
                go.defnod[j].DNelem.EV.E1.EV.Vsym == s &&
                vec_testbit(go.defnod[j].DNblock.Bdfoidx,l.Lloop))
            {
                biv.IVincr = el_parent(go.defnod[j].DNelem,&(go.defnod[j].DNblock.Belem));
                assert(s == (*biv.IVincr).EV.E1.EV.Vsym);

                debug if (debugc)
                {
                    printf("Increment elem is: "); WReqn(*biv.IVincr);     printf("\n");
                }
                goto L1;
            }
        }
        assert(0);                      /* should have found it         */
        /* NOTREACHED */

    L1:
    }

    vec_free(poss);
    vec_free(notposs);
}

/*************************************
 * Find op= elems of loop l.
 * Analogous to findbasivs().
 * Used to eliminate useless loop code normally found in benchmark programs.
 * Input:
 *      go.defnod[] loaded with all the definition elems of the loop
 */

@trusted
private void findopeqs(ref loop l)
{
    vec_t poss,notposs;
    elem *n;
    bool ambdone;

    ambdone = false;
    poss = vec_calloc(globsym.length);
    notposs = vec_calloc(globsym.length);  // vector of all variables
                                        // (initially all unmarked)

    // for each def in go.defnod[] that is within loop l

    foreach (i; 0 .. go.defnod.length)
    {
        if (!vec_testbit(go.defnod[i].DNblock.Bdfoidx,l.Lloop))
            continue;               // def is not in the loop

        n = go.defnod[i].DNelem;
        elem_debug(n);
        if (OTopeq(n.Eoper) && n.EV.E1.Eoper == OPvar)
        {
            Symbol *s;                  // if unambiguous def

            s = n.EV.E1.EV.Vsym;
            if (symbol_isintab(s))
            {
                SYMIDX v;

                v = n.EV.E1.EV.Vsym.Ssymnum;
                {
                    if (vec_testbit(v,poss))
                        // We've already seen this def elem,
                        // therefore there is more than one
                        // def of v within the loop, therefore
                        // v is not a basic IV.
                        vec_setbit(v,notposs);
                    else
                        vec_setbit(v,poss);
                }
            }
        }
        else                            // else ambiguous def
        {
            // mark any vars that could be affected by
            // this def as not possible

            if (!ambdone)           // avoid redundant loops
            {
                foreach (j; 0 .. globsym.length)
                {
                    if (!(globsym[j].Sflags & SFLunambig))
                        vec_setbit(j,notposs);
                }
                ambdone = true;
            }
        }
    }

    // Don't use symbols already in Livlist
    foreach (ref iv; l.Livlist)
    {
        vec_setbit(iv.IVbasic.Ssymnum,notposs);
    }


    static if (0)
    {
        printf("poss    "); vec_println(poss);
        printf("notposs "); vec_println(notposs);
    }

    vec_subass(poss,notposs);           // poss = poss - notposs

    // create list of IVs
    uint i;
    for (i = 0; (i = cast(uint) vec_index(i, poss)) < globsym.length; ++i)  // for each opeq IV
    {
        Symbol *s;

        s = globsym[i];
        assert(symbol_isintab(s));

        // Do not use aggregates as basic IVs. This is because the other loop
        // code doesn't check offsets into symbols, (assuming everything
        // is at offset 0). We could perhaps amend this by allowing basic IVs
        // if the struct consists of only one data member.
        if (tyaggregate(s.ty()))
            continue;

        auto biv = l.Lopeqlist.push();
        biv.IVbasic = s;               // symbol of basic IV
        biv.IVincr = null;

        if (debugc) printf("Symbol '%s' (%d) is an opeq IV, ",s.Sident.ptr,i);

        // We have the sym idx of the basic IV. We need to find
        // the parent of the increment elem for it.

        // First find the go.defnod[]
        foreach (j; 0 .. go.defnod.length)
        {
            // If go.defnod is a def of i and it is in the loop
            if (go.defnod[j].DNelem.EV.E1 &&     // OPasm are def nodes
                go.defnod[j].DNelem.EV.E1.EV.Vsym == s &&
                vec_testbit(go.defnod[j].DNblock.Bdfoidx,l.Lloop))
            {
                biv.IVincr = el_parent(go.defnod[j].DNelem,&(go.defnod[j].DNblock.Belem));
                assert(s == (*biv.IVincr).EV.E1.EV.Vsym);

                debug if (debugc)
                {
                    printf("Opeq elem is: "); WReqn(*biv.IVincr);  printf("\n");
                }
                goto Lcont;
            }
        }
        assert(0);                      // should have found it
        // NOTREACHED

    Lcont:
    }

    vec_free(poss);
    vec_free(notposs);
}

/*****************************
 * Find families for each basic IV.
 * An IV family is a list of elems of the form
 * c1*X+c2, where X is a basic induction variable.
 * Note that we do not do divides, because of roundoff error problems.
 */

@trusted
private void findivfams(ref loop l)
{
    if (debugc) printf("findivfams(%p)\n", &l);
    foreach (ref biv; l.Livlist)
    {
        for (uint i = 0; (i = cast(uint) vec_index(i, l.Lloop)) < dfo.length; ++i)  // for each block in loop
            if (dfo[i].Belem)
                ivfamelems(&biv,&(dfo[i].Belem));
        /* Fold all the constant expressions in c1 and c2.      */
        foreach (ref fl; biv.IVfamily)
        {
            fl.c1 = doptelem(fl.c1,GOALvalue | GOALagain);
            fl.c2 = doptelem(fl.c2,GOALvalue | GOALagain);
        }
    }
}

/*************************
 * Tree walking support routine for findivfams().
 *      biv =   basic induction variable pointer
 *      pn      pointer to elem
 */

@trusted
private void ivfamelems(Iv *biv,elem **pn)
{
    tym_t ty,c2ty;
    elem *n1;
    elem *n2;

    assert(pn);
    elem* n = *pn;
    assert(biv && n);
    const op = n.Eoper;
    if (OTunary(op))
    {
       ivfamelems(biv,&n.EV.E1);
        n1 = n.EV.E1;
        n2 = null;
    }
    else if (OTbinary(op))
    {
        ivfamelems(biv,&n.EV.E1);
        ivfamelems(biv,&n.EV.E2); /* LTOR or RTOL order is unimportant */
        n1 = n.EV.E1;
        n2 = n.EV.E2;
    }
    else                                /* else leaf elem               */
        return;                         /* which can't be in the family */

    if (tycomplex(n.Ety))
        return;

    if (op == OPmul || op == OPadd || op == OPmin ||
        op == OPneg || op == OPshl)
    {   /* Note that we are wimping out and not considering             */
        /* LI variables as part of c1 and c2, but only constants.       */

        ty = n.Ety;

        /* Since trees are canonicalized, basic induction variables     */
        /* will only appear on the left.                                */

        /* Improvement:                                                 */
        /* We wish to pick up the cases (biv + li), (biv - li) and      */
        /* (li + biv). OPmul and LS with bivs are out, since if we      */
        /* try to eliminate the biv, and the loop test is a >, >=,      */
        /* <, <=, we have a problem since we don't know if the li       */
        /* is negative. (Would have to call swaprel() on it.)           */

        /* If we have (li + var), swap the leaves.                      */
        if (op == OPadd && isLI(n1) && n1.Eoper == OPvar && n2.Eoper == OPvar)
        {
            n.EV.E1 = n2;
            n2 = n.EV.E2 = n1;
            n1 = n.EV.E1;
        }

        // Get rid of case where we painted a far pointer to a long
        if (op == OPadd || op == OPmin)
        {
            int sz;

            sz = tysize(ty);
            if (sz == tysize(TYfptr) && !tyfv(ty) &&
                (sz != tysize(n1.Ety) || sz != tysize(n2.Ety)))
                return;
        }

        /* Look for function of basic IV (-biv or biv op const)         */
        if (n1.Eoper == OPvar && n1.EV.Vsym == biv.IVbasic)
        {
            if (op == OPneg)
            {
                if (debugc) printf("found (-biv), elem %p\n",n);
                auto fl = biv.IVfamily.push();
                newfamlist(fl, ty);
                fl.FLivty = n1.Ety;
                fl.FLpelem = pn;
                fl.c1 = el_una(op,ty,fl.c1); /* c1 = -1       */
            }
            else if (n2.Eoper == OPconst ||
                     isLI(n2) && (op == OPadd || op == OPmin))
            {
                debug
                    if (debugc)
                    {   printf("found (biv op const), elem (");
                            WReqn(n);
                            printf(");\n");
                            printf("Types: n1="); WRTYxx(n1.Ety);
                            printf(" ty="); WRTYxx(ty);
                            printf(" n2="); WRTYxx(n2.Ety);
                            printf("\n");
                    }

                auto fl = biv.IVfamily.push();
                newfamlist(fl, ty);
                fl.FLivty = n1.Ety;
                fl.FLpelem = pn;
                switch (op)
                {
                    case OPadd:           /* c2 = right           */
                        c2ty = n2.Ety;
                        if (typtr(fl.c2.Ety))
                                c2ty = fl.c2.Ety;
                        goto L1;

                    case OPmin:           /* c2 = -right          */
                        c2ty = fl.c2.Ety;
                        /* Check for subtracting two pointers */
                        if (typtr(c2ty) && typtr(n2.Ety))
                        {
                            if (tybasic(c2ty) == TYhptr)
                                c2ty = TYlong;
                            else
                                c2ty = I64 ? TYllong : TYint;
                        }
                  L1:
                        fl.c2 = el_bin(op,c2ty,fl.c2,el_copytree(n2));
                        break;

                    case OPmul:           /* c1 = right           */
                    case OPshl:           /* c1 = 1 << right      */
                        fl.c1 = el_bin(op,ty,fl.c1,el_copytree(n2));
                        break;

                    default:
                        assert(0);
                }
            }
        }

        /* Look for function of existing IV                             */

        foreach (ref fl; biv.IVfamily)
        {
            if (*fl.FLpelem != n1)          /* not it               */
                continue;

            /* Look for (fl op constant)     */
            if (op == OPneg)
            {
                if (debugc) printf("found (-fl), elem %p\n",n);
                /* c1 = -c1; c2 = -c2; */
                fl.c1 = el_una(OPneg,ty,fl.c1);
                fl.c2 = el_una(OPneg,ty,fl.c2);
                fl.FLty = ty;
                fl.FLpelem = pn;        /* replace with new IV  */
            }
            else if (n2.Eoper == OPconst ||
                     isLI(n2) && (op == OPadd || op == OPmin))
            {
                debug
                    if (debugc)
                    {
                        printf("found (fl op const), elem (");
                        WReqn(n);
                        assert(*pn == n);
                        printf(");\n");
                        elem_print(n);
                    }

                switch (op)
                {
                    case OPmul:
                    case OPshl:
                        fl.c1 = el_bin(op,ty,fl.c1,el_copytree(n2));
                        break;

                    case OPadd:
                    case OPmin:
                        break;

                    default:
                        assert(0);
                }
                fl.c2 = el_bin(op,ty,fl.c2,el_copytree(n2));
                fl.FLty = ty;
                fl.FLpelem = pn;        /* replace with new IV  */
            } /* else if */
        } /* for */
    } /* if */
}

/*********************************
 * Eliminate frivolous family ivs, that is,
 * if we can't eliminate the BIV, then eliminate family ivs that
 * differ from it only by a constant.
 */

@trusted
private void elimfrivivs(ref loop l)
{
    foreach (ref biv; l.Livlist)
    {
        int nrefs;

        if (debugc) printf("elimfrivivs()\n");
        /* Compute number of family ivs for biv */
        const nfams = biv.IVfamily.length;
        if (debugc) printf("nfams = %d\n", cast(int)nfams);

        /* Compute number of references to biv  */
        if (onlyref(biv.IVbasic,l,*biv.IVincr,&nrefs))
                nrefs--;
        if (debugc) printf("nrefs = %d\n",nrefs);
        assert(nrefs + 1 >= nfams);
        if (nrefs > nfams ||            // if we won't eliminate the biv
            (!I16 && nrefs == nfams))
        {   /* Eliminate any family ivs that only differ by a constant  */
            /* from biv                                                 */
            foreach (ref fl; biv.IVfamily)
            {
                elem *ec1 = fl.c1;
                targ_llong c;

                if (elemisone(ec1) ||
                    // Eliminate fl's that can be represented by
                    // an addressing mode
                    (!I16 && ec1.Eoper == OPconst && tyintegral(ec1.Ety) &&
                     ((c = el_tolong(ec1)) == 2 || c == 4 || c == 8)
                    )
                   )
                {
                    fl.FLtemp = FLELIM;

                    debug
                        if (debugc)
                        {
                            printf("Eliminating frivolous IV ");
                            WReqn(*fl.FLpelem);
                            printf("\n");
                        }
                }
            }
        }
    }
}


/******************************
 * Introduce new variables.
 */

@trusted
private void intronvars(ref loop l)
{
    elem *T;
    elem *ne;
    elem *t2;
    elem *C2;
    elem *cmul;
    tym_t ty,tyr;

    if (debugc) printf("intronvars(%p)\n", &l);
    foreach (ref biv; l.Livlist)
    {
        elem *bivinc = *biv.IVincr;   /* ptr to increment elem */

        foreach (ref fl; biv.IVfamily)
        {                               /* for each IV in family of biv  */
            if (fl.FLtemp == FLELIM)   /* if already eliminated         */
                continue;

            /* If induction variable can be written as a simple function */
            /* of a previous induction variable, skip it.                */
            if (funcprev(biv,fl))
                continue;

            ty = fl.FLty;
            T = el_alloctmp(ty);        /* allocate temporary T          */
            fl.FLtemp = T.EV.Vsym;

            debug
            {
                if (debugc) printf("intronvars() introduced new variable '%s' of type ",T.EV.Vsym.Sident.ptr);
                if (debugc) WRTYxx(ty);
                if (debugc) printf("\n");
            }

            /* append elem T=biv*C1+C2 to preheader */
            /* ne = biv*C1      */
            tyr = fl.FLivty;                   /* type of biv              */
            ne = el_var(biv.IVbasic);
            ne.Ety = tyr;
            if (!elemisone(fl.c1))             /* don't multiply ptrs by 1 */
                ne = el_bin(OPmul,tyr,ne,el_copytree(fl.c1));
            if (tyfv(tyr) && tysize(ty) == SHORTSIZE)
                ne = el_una(OP32_16,ty,ne);
            C2 = el_copytree(fl.c2);
            t2 = el_bin(OPadd,ty,ne,C2);        /* t2 = ne + C2         */
            ne = el_bin(OPeq,ty,el_copytree(T),t2);
            appendelem(ne, &(l.Lpreheader.Belem));

            /* prefix T+=C1*C to elem biv+=C                            */
            /* Must prefix in case the value of the expression (biv+=C) */
            /* is used by somebody up the tree.                         */
            cmul = el_bin(OPmul,fl.c1.Ety,el_copytree(fl.c1),
                                          el_copytree(bivinc.EV.E2));
            t2 = el_bin(bivinc.Eoper,ty,el_copytree(T),cmul);
            t2 = doptelem(t2,GOALvalue | GOALagain);
            *biv.IVincr = el_bin(OPcomma,bivinc.Ety,t2,bivinc);
            biv.IVincr = &((*biv.IVincr).EV.E2);

            debug
                if (debugc)
                {
                    printf("Replacing elem (");
                    WReqn(*fl.FLpelem);
                    printf(") with '%s'\n",T.EV.Vsym.Sident.ptr);
                    printf("The init elem is (");
                    WReqn(ne);
                    printf(");\nThe increment elem is (");
                    WReqn(t2);
                    printf(")\n");
                }

            el_free(*fl.FLpelem);
            *fl.FLpelem = T;           /* replace elem n with ref to T  */
            doflow = true;              /* redo flow analysis           */
            go.changes++;
        } /* for */
    } /* for */
}

/*******************************
 * Determine if induction variable can be rewritten as a simple
 * function of a previously generated temporary.
 * This can frequently
 * generate less code than that of an all-new temporary (especially
 * if it is the same as a previous temporary!).
 * Input:
 *      biv             Basic induction variable
 *      fl              Item in biv's family list we are looking at
 * Returns:
 *      false           Caller should create a new induction variable.
 *      true            *FLpelem is replaced with function of a previous
 *                      induction variable. FLtemp is set to FLELIM to
 *                      indicate this.
 */

@trusted
private bool funcprev(ref Iv biv, ref famlist fl)
{
    tym_t tymin;
    int sz;
    elem *e1;
    elem *e2;
    elem *flse1;

    debug if (debugc)
        printf("funcprev\n");

    foreach (ref fls; biv.IVfamily)
    {
        if (!fls.FLtemp)                // haven't generated a temporary yet
            continue;
        if (fls.FLtemp == FLELIM)      /* no iv we can use here        */
            continue;

        /* The multipliers must match   */
        if (!el_match(fls.c1,fl.c1))
            continue;

        /* If the c2's match also, we got it easy */
        if (el_match(fls.c2,fl.c2))
        {
            if (tysize(fl.FLty) > tysize(fls.FLtemp.ty()))
                continue;              /* can't increase size of var   */
            flse1 = el_var(fls.FLtemp);
            flse1.Ety = fl.FLty;
            goto L2;
        }

        /* The difference is only in the addition. Therefore, replace
           *fl.FLpelem with:
                case 1:         (fl.c2 + (fls.FLtemp - fls.c2))
                case 2:         (fls.FLtemp + (fl.c2 - fls.c2))
         */
        e1 = fl.c2;
        /* Subtracting relocatables usually generates slow code for     */
        /* linkers that can't handle arithmetic on relocatables.        */
        if (typtr(fls.c2.Ety))
        {
            if (fls.c2.Eoper == OPrelconst &&
                !(fl.c2.Eoper == OPrelconst &&
                  fl.c2.EV.Vsym == fls.c2.EV.Vsym)
               )
                continue;
        }
        flse1 = el_var(fls.FLtemp);
        e2 = flse1;                             /* assume case 1        */
        tymin = e2.Ety;
        if (typtr(fls.c2.Ety))
        {
            if (!typtr(tymin))
            {
                if (typtr(e1.Ety))
                {
                    e1 = e2;
                    e2 = fl.c2;            /* case 2               */
                }
                else                        /* can't subtract fptr  */
                    goto L1;
            }
            if (tybasic(fls.c2.Ety) == TYhptr)
                tymin = TYlong;
            else
                tymin = I64 ? TYllong : TYint;         /* type of (ptr - ptr) */
        }

        /* If e1 and fls.c2 are fptrs, and are not from the same       */
        /* segment, we cannot subtract them.                            */
        if (tyfv(e1.Ety) && tyfv(fls.c2.Ety))
        {
            if (e1.Eoper != OPrelconst || fls.c2.Eoper != OPrelconst)
                goto L1;                /* assume expressions have diff segs */
            if (e1.EV.Vsym.Sclass != fls.c2.EV.Vsym.Sclass)
            {
               L1:
                el_free(flse1);
                continue;
            }
        }

        /* Some more type checking...   */
        sz = tysize(fl.FLty);
        if (sz != tysize(e1.Ety) &&
            sz != tysize(tymin))
            goto L1;

        /* Do some type checking (can't add pointers and get a pointer!) */
        //if (typtr(fl.FLty) && typtr(e1.Ety) && typtr(tymin))
            //goto L1;
        /* Construct (e1 + (e2 - fls.c2))      */
        flse1 = el_bin(OPadd,fl.FLty,
                            e1,
                            el_bin(OPmin,tymin,
                                    e2,
                                    el_copytree(fls.c2)));
        if (sz < tysize(tymin) && sz == tysize(e1.Ety))
        {
            assert(I16);
            flse1.EV.E2 = el_una(OPoffset,fl.FLty,flse1.EV.E2);
        }

        flse1 = doptelem(flse1,GOALvalue | GOALagain);
        fl.c2 = null;
    L2:
        debug if (debugc)
        {
            printf("Replacing ");
            WReqn(*fl.FLpelem);
            printf(" with ");
            WReqn(flse1);
            printf("\n");
        }

        el_free(*fl.FLpelem);
        *fl.FLpelem = flse1;

        /* Fix the iv so when we do loops again, we won't create        */
        /* yet another iv, which is just what funcprev() is supposed    */
        /* to prevent.                                                  */
        fls.FLtemp.Sflags |= SFLnotbasiciv;

        fl.FLtemp = FLELIM;            /* mark iv as being gone        */
        go.changes++;
        doflow = true;
        return true;                    /* it was replaced              */
    }
    return false;                       /* need to create a new variable */
}

/***********************
 * Eliminate basic IVs.
 */

@trusted
private void elimbasivs(ref loop l)
{
    if (debugc) printf("elimbasivs(%p)\n", &l);
    foreach (ref biv; l.Livlist)
    {
        /* Can't eliminate this basic IV if we have a goal for the      */
        /* increment elem.                                              */
        // Be careful about Nflags being in a union...
        elem* einc = *biv.IVincr;
        if (!(einc.Nflags & NFLnogoal))
            continue;

        Symbol* X = biv.IVbasic;
        assert(symbol_isintab(X));
        tym_t ty = X.ty();
        int refcount;
        elem** pref = onlyref(X,l,einc,&refcount);

        /* if only ref of X is of the form (X) or (X relop e) or (e relop X) */
        if (pref != null && refcount <= 1)
        {
            if (!biv.IVfamily.length)
                continue;

            elem* ref_ = *pref;

            /* Replace (X) with (X != 0)                            */
            if (ref_.Eoper == OPvar)
                ref_ = *pref = el_bin(OPne,TYint,ref_,el_long(ref_.Ety,0L));

            const fi = simfl(biv.IVfamily, ty); // find simplest elem in family
            if (fi == biv.IVfamily.length)
                continue;
            famlist* fl = &biv.IVfamily[fi];

            // Don't do the replacement if we would replace a
            // signed comparison with an unsigned one
            tym_t flty = fl.FLty;
            if (tyuns(ref_.EV.E1.Ety) | tyuns(ref_.EV.E2.Ety))
                flty = touns(flty);

            if (ref_.Eoper >= OPle && ref_.Eoper <= OPge &&
                !(tyuns(ref_.EV.E1.Ety) | tyuns(ref_.EV.E2.Ety)) &&
                 tyuns(flty))
                    continue;

            /* if we have (e relop X), replace it with (X relop e)  */
            if (ref_.EV.E2.Eoper == OPvar && ref_.EV.E2.EV.Vsym == X)
            {
                elem* tmp = ref_.EV.E2;
                ref_.EV.E2 = ref_.EV.E1;
                ref_.EV.E1 = tmp;
                ref_.Eoper = cast(ubyte)swaprel(ref_.Eoper);
            }

            // If e*c1+c2 would result in a sign change or an overflow
            // then we can't do it
            if (fl.c1.Eoper == OPconst)
            {
                targ_llong c1 = el_tolong(fl.c1);
                const int sz = tysize(ty);
                if (sz == SHORTSIZE &&
                    ((ref_.EV.E2.Eoper == OPconst &&
                    c1 * el_tolong(ref_.EV.E2) & ~0x7FFFL) ||
                     c1 & ~0x7FFFL)
                   )
                    continue;

                if (sz == LONGSIZE &&
                    ((ref_.EV.E2.Eoper == OPconst &&
                    c1 * el_tolong(ref_.EV.E2) & ~0x7FFFFFFFL) ||
                     c1 & ~0x7FFFFFFFL)
                   )
                    continue;
                if (sz == LLONGSIZE &&
                    ((ref_.EV.E2.Eoper == OPconst &&
                    c1 * el_tolong(ref_.EV.E2) & ~0x7FFFFFFFFFFFFFFFL) ||
                     c1 & ~0x7FFFFFFFFFFFFFFFL)
                   )
                    continue;
            }

            /* If the incr is a decrement, and the relational is < or <=,
             * and its unsigned, then don't do it because it could drop below 0.
             * https://issues.dlang.org/show_bug.cgi?id=16189
             */
            if ((einc.Eoper == OPminass || einc.EV.E2.Eoper == OPconst && el_tolong(einc.EV.E2) < 0) &&
                (ref_.Eoper == OPlt || ref_.Eoper == OPle) &&
                (tyuns(ref_.EV.E1.Ety) | tyuns(ref_.EV.E2.Ety)))
                continue;

            /* If loop started out with a signed conditional that was
             * replaced with an unsigned one, don't do it if c2
             * is less than 0.
             */
            if (ref_.Nflags & NFLtouns && fl.c2.Eoper == OPconst)
            {
                targ_llong c2 = el_tolong(fl.c2);
                if (c2 < 0)
                    continue;
            }

            elem *refE2 = el_copytree(ref_.EV.E2);
            int refEoper = ref_.Eoper;

            /* if c1 < 0 and relop is < <= > >=
               then adjust relop as if both sides were multiplied
               by -1
             */
            if (!tyuns(ty) &&
                (tyintegral(ty) && el_tolong(fl.c1) < 0 ||
                 tyfloating(ty) && el_toldoubled(fl.c1) < 0.0))
                refEoper = swaprel(refEoper);

            /* Replace (X relop e) with (X relop (short)e)
               if T is 1 word but e is 2
             */
            if (tysize(flty) == SHORTSIZE &&
                tysize(refE2.Ety) == LONGSIZE)
                refE2 = el_una(OP32_16,flty,refE2);

            /* replace e with e*c1 + c2             */
            elem* C2 = el_copytree(fl.c2);
            elem* fofe = el_bin(OPadd,flty,
                            el_bin(OPmul,refE2.Ety,
                                    refE2,
                                    el_copytree(fl.c1)),
                            C2);
            fofe = doptelem(fofe,GOALvalue | GOALagain);    // fold any constants

            if (tyuns(flty) && refEoper == OPge &&
                fofe.Eoper == OPconst && el_allbits(fofe, 0) &&
                fl.c2.Eoper == OPconst && !el_allbits(fl.c2, 0))
            {
                /* Don't do it if replacement will result in
                 * an unsigned T>=0 which will be an infinite loop.
                 */
                el_free(fofe);
                continue;
            }

            if (debugc) printf("Eliminating basic IV '%s'\n",X.Sident.ptr);

            debug if (debugc)
            {
                printf("Comparison replaced: ");
                WReqn(ref_);
                printf(" with ");
            }

            el_free(ref_.EV.E2);
            ref_.EV.E2 = refE2;
            ref_.Eoper = cast(ubyte)refEoper;

            elimass(einc);          // dump the increment elem

            // replace X with T
            assert(ref_.EV.E1.EV.Voffset == 0);
            ref_.EV.E1.EV.Vsym = fl.FLtemp;
            ref_.EV.E1.Ety = flty;
            ref_.EV.E2 = fofe;

            /* If sizes of expression worked out wrong...
               Which can happen if we have (int)ptr==e
             */
            if (OTbinary(fofe.Eoper))         // if didn't optimize it away
            {
                const tym_t fofety = fofe.Ety;
                const int sz = tysize(fofety);
                tym_t ty1 = fofe.EV.E1.Ety;
                const tym_t ty2 = fofe.EV.E2.Ety;
                /* Sizes of + expression must all be the same       */
                if (sz != tysize(ty1) &&
                    sz != tysize(ty2)
                   )
                {
                    if (tyuns(fofety))      // if unsigned comparison
                        ty1 = touns(ty1);   /* to unsigned type     */
                    fofe.Ety = ty1;
                    ref_.EV.E1.Ety = ty1;
                }
            }

            /* Fix if leaves of compare are TYfptrs and the compare */
            /* operator is < <= > >=.                               */
            if (ref_.Eoper >= OPle && ref_.Eoper <= OPge && tyfv(ref_.EV.E1.Ety))
            {
                assert(tyfv(ref_.EV.E2.Ety));
                ref_.EV.E1 = el_una(OPoffset,TYuint,ref_.EV.E1);
                ref_.EV.E2 = el_una(OPoffset,TYuint,fofe);
            }

            debug if (debugc)
            {
                WReqn(ref_);
                printf("\n");
            }

            go.changes++;
            doflow = true;                  /* redo flow analysis   */

            /* if X is live on entry to any successor S outside loop */
            /*      prepend elem X=(T-c2)/c1 to S.Belem     */

            for (uint i = 0; (i = cast(uint) vec_index(i, l.Lexit)) < dfo.length; ++i)  // for each exit block
            {
                elem *ne;
                block *b;

                foreach (bl; ListRange(dfo[i].Bsucc))
                {   /* for each successor   */
                    b = list_block(bl);
                    if (vec_testbit(b.Bdfoidx,l.Lloop))
                        continue;       /* inside loop  */
                    if (!vec_testbit(X.Ssymnum,b.Binlv))
                        continue;       /* not live     */

                    C2 = el_copytree(fl.c2);
                    ne = el_bin(OPmin,ty,
                            el_var(fl.FLtemp),
                            C2);
                    if (tybasic(ne.EV.E1.Ety) == TYfptr &&
                        tybasic(ne.EV.E2.Ety) == TYfptr)
                    {
                        ne.Ety = I64 ? TYllong : TYint;
                        if (tylong(ty) && _tysize[TYint] == 2)
                            ne = el_una(OPs16_32,ty,ne);
                    }

                    ne = el_bin(OPeq,X.ty(),
                            el_var(X),
                            el_bin(OPdiv,ne.Ety,
                                ne,
                                el_copytree(fl.c1)));

                    debug if (debugc)
                    {
                        printf("Adding (");
                        WReqn(ne);
                        printf(") to exit block B%d\n",b.Bdfoidx);
                        //elem_print(ne);
                    }

                    /* We have to add a new block if there is */
                    /* more than one predecessor to b.      */
                    if (list_next(b.Bpred))
                    {
                        block *bn = block_calloc();
                        bn.Btry = b.Btry;
                        bn.BC = BCgoto;
                        bn.Bnext = dfo[i].Bnext;
                        dfo[i].Bnext = bn;
                        list_append(&(bn.Bsucc),b);
                        list_append(&(bn.Bpred),dfo[i]);
                        bl.ptr = cast(void *)bn;
                        foreach (bl2; ListRange(b.Bpred))
                            if (list_block(bl2) == dfo[i])
                            {
                                bl2.ptr = cast(void *)bn;
                                goto L2;
                            }
                        assert(0);
                    L2:
                        b = bn;
                        addblk = true;
                    }

                    if (b.Belem)
                        b.Belem =
                            el_bin(OPcomma,b.Belem.Ety,
                                ne,b.Belem);
                    else
                        b.Belem = ne;
                    go.changes++;
                    doflow = true;  /* redo flow analysis   */
                } /* for each successor */
            } /* foreach exit block */
            if (addblk)
                return;
        }
        else if (refcount == 0)                 /* if no uses of IV in loop  */
        {
            /* Eliminate the basic IV if it is not live on any successor */
            for (uint i = 0; (i = cast(uint) vec_index(i, l.Lexit)) < dfo.length; ++i)  // for each exit block
            {
                foreach (bl; ListRange(dfo[i].Bsucc))
                {   /* for each successor   */
                    block *b = list_block(bl);
                    if (vec_testbit(b.Bdfoidx,l.Lloop))
                        continue;       /* inside loop  */
                    if (vec_testbit(X.Ssymnum,b.Binlv))
                        goto L1;        /* live         */
                }
            }

            if (debugc) printf("No uses, eliminating basic IV '%s' (%p)\n",X.Sident.ptr,X);

            /* Remove the (s op= e2) by replacing it with (1 , e2)
             * and let later passes remove the (1 ,) nodes.
             * Don't remove those nodes here because other biv's may refer
             * to them.
             */
            {
                elem* ei = *biv.IVincr;
                ei.Eoper = OPcomma;
                ei.EV.E1.Eoper = OPconst;
                ei.EV.E1.Ety = TYint;
            }

            go.changes++;
            doflow = true;                  /* redo flow analysis   */
          L1:
        }
    } /* for */
}


/***********************
 * Eliminate opeq IVs that are not used outside the loop.
 */

@trusted
private void elimopeqs(ref loop l)
{
    elem **pref;
    Symbol *X;
    int refcount;

    if (debugc) printf("elimopeqs(%p)\n", &l);
    //foreach (ref biv; l.Lopeqlist) elem_print(*(biv.IVincr));

    foreach (ref biv; l.Lopeqlist)
    {
        // Can't eliminate this basic IV if we have a goal for the
        // increment elem.
        // Be careful about Nflags being in a union...
        if (!((*biv.IVincr).Nflags & NFLnogoal))
            continue;

        X = biv.IVbasic;
        assert(symbol_isintab(X));
        pref = onlyref(X,l,*biv.IVincr,&refcount);

        // if only ref of X is of the form (X) or (X relop e) or (e relop X)
        if (pref != null && refcount <= 1)
        { }
        else if (refcount == 0)                 // if no uses of IV in loop
        {   // Eliminate the basic IV if it is not live on any successor
            uint i;
            for (i = 0; (i = cast(uint) vec_index(i, l.Lexit)) < dfo.length; ++i)  // for each exit block
            {
                foreach (bl; ListRange(dfo[i].Bsucc))
                {   // for each successor
                    block *b = list_block(bl);
                    if (vec_testbit(b.Bdfoidx,l.Lloop))
                        continue;       // inside loop
                    if (vec_testbit(X.Ssymnum,b.Binlv))
                        goto L1;        // live
                }
            }

            if (debugc) printf("No uses, eliminating opeq IV '%s' (%p)\n",X.Sident.ptr,X);

            /* Remove the (s op= e2) by replacing it with (1 , e2)
             * and let later passes remove the (1 ,) nodes.
             * Don't remove those nodes here because other biv's may refer
             * to them, for nodes like (sum += i++)
             */
            {
                elem* einc = *(biv.IVincr);
                einc.Eoper = OPcomma;
                einc.EV.E1.Eoper = OPconst;
                einc.EV.E1.Ety = TYint;
            }

            go.changes++;
            doflow = true;                      // redo flow analysis
        L1:
        }
    }
}

/**************************
 * Find simplest elem in family.
 * Params:
 *      fams = array of famlist's
 *      tym  = type of basic IV
 * Returns: index into fams[] of simplest; fams.length if none found.
 */

@trusted
extern (D)
private size_t simfl(famlist[] fams, tym_t tym)
{
    size_t sofar = fams.length;

    foreach (i, ref fl; fams)
    {
        if (fl.FLtemp == FLELIM)       /* no variable, so skip it      */
            continue;
        /* If size of replacement is less than size of biv, we could    */
        /* be in trouble due to loss of precision.                      */
        if (size(fl.FLtemp.ty()) < size(tym))
            continue;

        // pick simplest
        sofar = sofar == fams.length ? i
                                     : (flcmp(fams[sofar], fams[i]) ? sofar : i);
    }
    return sofar;
}

/**************************
 * Return simpler of two family elems.
 * There is room for improvement, namely if
 *      f1.c1 = 2, f2.c1 = 27
 * then pick f1 because it is a shift.
 * Returns:
 *      true for f1 is simpler, false  for f2 is simpler
 */

@trusted
private bool flcmp(ref famlist f1, ref famlist f2)
{
    auto t1 = &(f1.c1.EV);
    auto t2 = &(f2.c1.EV);
    auto ty = (*f1.FLpelem).Ety;           // type of elem

    static if (0)
    {
        printf("f1: c1 = %d, c2 = %d\n",t1.Vshort,f1.c2.EV.Vshort);
        printf("f2: c1 = %d, c2 = %d\n",t2.Vshort,f2.c2.EV.Vshort);
        WRTYxx((*f1.FLpelem).Ety);
        WRTYxx((*f2.FLpelem).Ety);
    }

    /* Wimp out and just pick f1 if the types don't match               */
    if (tysize(ty) == tysize((*f2.FLpelem).Ety))
    {
        switch (tybasic(ty))
        {   case TYbool:
            case TYchar:
            case TYschar:
            case TYuchar:
                if (t2.Vuchar == 1 ||
                    t1.Vuchar != 1 && f2.c2.EV.Vuchar == 0)
                        goto Lf2;
                break;

            case TYshort:
            case TYushort:
            case TYchar16:
            case TYwchar_t:     // BUG: what about 4 byte wchar_t's?
            case_short:
                if (t2.Vshort == 1 ||
                    t1.Vshort != 1 && f2.c2.EV.Vshort == 0)
                        goto Lf2;
                break;

            case TYsptr:
            case TYcptr:
            case TYnptr:        // BUG: 64 bit pointers?
            case TYimmutPtr:
            case TYsharePtr:
            case TYrestrictPtr:
            case TYfgPtr:
            case TYnullptr:
            case TYint:
            case TYuint:
                if (_tysize[TYint] == SHORTSIZE)
                    goto case_short;
                else
                    goto case_long;

            case TYlong:
            case TYulong:
            case TYdchar:
            case TYfptr:
            case TYvptr:
            case TYhptr:
            case_long:
                if (t2.Vlong == 1 ||
                    t1.Vlong != 1 && f2.c2.EV.Vlong == 0)
                        goto Lf2;
                break;

            case TYfloat:
                if (t2.Vfloat == 1 ||
                    t1.Vfloat != 1 && f2.c2.EV.Vfloat == 0)
                        goto Lf2;
                break;

            case TYdouble:
            case TYdouble_alias:
                if (t2.Vdouble == 1.0 ||
                    t1.Vdouble != 1.0 && f2.c2.EV.Vdouble == 0)
                        goto Lf2;
                break;

            case TYldouble:
                if (t2.Vldouble == 1.0 ||
                    t1.Vldouble != 1.0 && f2.c2.EV.Vldouble == 0)
                        goto Lf2;
                break;

            case TYllong:
            case TYullong:
                if (t2.Vllong == 1 ||
                    t1.Vllong != 1 && f2.c2.EV.Vllong == 0)
                        goto Lf2;
                break;

            default:
                assert(0);
        }
    }
    //printf("picking f1\n");
    return true;

Lf2:
    //printf("picking f2\n");
    return false;
}

/************************************
 * Input:
 *      x       basic IV symbol
 *      incn    increment elem for basic IV X.
 * Output:
 *      *prefcount      # of references to X other than the increment elem
 * Returns:
 *      If ref of X in loop l is of the form (X relop e) or (e relop X)
 *              Return the relop elem
 *      Else
 *              Return null
 */

private __gshared
{
    int count;
    elem **nd;
    elem *sincn;
    Symbol *X;
}

@trusted
private elem ** onlyref(Symbol *x, ref loop l,elem *incn,int *prefcount)
{
    uint i;

    //printf("onlyref('%s')\n", x.Sident.ptr);
    X = x;                                /* save some parameter passing  */
    assert(symbol_isintab(x));
    sincn = incn;

    debug
      if (!(X.Ssymnum < globsym.length && incn))
          printf("X = %d, globsym.length = %d, l = %p, incn = %p\n",cast(int) X.Ssymnum,cast(int) globsym.length,&l,incn);

    assert(X.Ssymnum < globsym.length && incn);
    count = 0;
    nd = null;
    for (i = 0; (i = cast(uint) vec_index(i, l.Lloop)) < dfo.length; ++i)  // for each block in loop
    {
        block *b;

        b = dfo[i];
        if (b.Belem)
        {
            countrefs(&b.Belem,b.BC == BCiftrue);
        }
    }

    static if (0)
    {
        printf("count = %d, nd = (");
        if (nd) WReqn(*nd);
        printf(")\n");
    }

    *prefcount = count;
    return nd;
}


/******************************
 * Count elems of the form (X relop e) or (e relop X).
 * Do not count the node if it is the increment node (sincn).
 * Input:
 *      flag:   true if block wants to test the elem
 */

@trusted
private void countrefs(elem **pn,bool flag)
{
    elem *n = *pn;

    assert(n);
    if (n == sincn)                       /* if it is the increment elem  */
    {
        if (OTbinary(n.Eoper))
            countrefs(&n.EV.E2, false);
        return;                         // don't count lvalue
    }
    if (OTunary(n.Eoper))
        countrefs(&n.EV.E1,false);
    else if (OTbinary(n.Eoper))
    {
        if (OTrel(n.Eoper))
        {
            elem *e1 = n.EV.E1;

            assert(e1.Eoper != OPcomma);
            if (e1 == sincn &&
                (e1.Eoper == OPeq || OTopeq(e1.Eoper)))
                goto L1;

            /* Check both subtrees to see if n is the comparison node,
             * that is, if X is a leaf of the comparison.
             */
            if (e1.Eoper == OPvar && e1.EV.Vsym == X && !countrefs2(n.EV.E2) ||
                n.EV.E2.Eoper == OPvar && n.EV.E2.EV.Vsym == X && !countrefs2(e1))
                nd = pn;                /* found the relop node */
        }
    L1:
        countrefs(&n.EV.E1,false);
        countrefs(&n.EV.E2,(flag && n.Eoper == OPcomma));
    }
    else if ((n.Eoper == OPvar || n.Eoper == OPrelconst) && n.EV.Vsym == X)
    {
        if (flag)
            nd = pn;                    /* comparing it with 0          */
        count++;                        /* found another reference      */
    }
}

/*******************************
 * Count number of times symbol X appears in elem tree e.
 */

@trusted
private int countrefs2(elem *e)
{
    elem_debug(e);
    while (OTunary(e.Eoper))
        e = e.EV.E1;
    if (OTbinary(e.Eoper))
        return countrefs2(e.EV.E1) + countrefs2(e.EV.E2);
    return ((e.Eoper == OPvar || e.Eoper == OPrelconst) &&
            e.EV.Vsym == X);
}

/****************************
 * Eliminate some special cases.
 */

@trusted
private void elimspec(ref loop l)
{
    uint i;

    for (i = 0; (i = cast(uint) vec_index(i, l.Lloop)) < dfo.length; ++i)  // for each block in loop
    {
        block *b;

        b = dfo[i];
        if (b.Belem)
            elimspecwalk(&b.Belem);
    }
}


/******************************
 */

@trusted
private void elimspecwalk(elem **pn)
{
    elem *n;

    n = *pn;
    assert(n);
    if (OTunary(n.Eoper))
        elimspecwalk(&n.EV.E1);
    else if (OTbinary(n.Eoper))
    {
        elimspecwalk(&n.EV.E1);
        elimspecwalk(&n.EV.E2);
        if (OTrel(n.Eoper))
        {
            elem *e1 = n.EV.E1;

            /* Replace ((e1,e2) rel e3) with (e1,(e2 rel e3).
             * This will reduce the number of cases for elimbasivs().
             * Don't do equivalent with (e1 rel (e2,e3)) because
             * of potential side effects in e1.
             */
            if (e1.Eoper == OPcomma)
            {
                elem *e;

                debug if (debugc)
                {   printf("3rewriting ("); WReqn(n); printf(")\n"); }

                e = n.EV.E2;
                n.EV.E2 = e1;
                n.EV.E1 = n.EV.E2.EV.E1;
                n.EV.E2.EV.E1 = n.EV.E2.EV.E2;
                n.EV.E2.EV.E2 = e;
                n.EV.E2.Eoper = n.Eoper;
                n.EV.E2.Ety = n.Ety;
                n.Eoper = OPcomma;

                go.changes++;
                doflow = true;

                elimspecwalk(&n.EV.E1);
                elimspecwalk(&n.EV.E2);
            }

            /* Rewrite ((X op= e2) rel e3) into ((X op= e2),(X rel e3))
             * Rewrite ((X ++  e2) rel e3) into ((X +=  e2),(X-e2 rel e3))
             * so that the op= will not have a goal, so elimbasivs()
             * will work on it.
             */
            if ((OTopeq(e1.Eoper)
                 || OTpost(e1.Eoper)
                ) &&
                !el_sideeffect(e1.EV.E1))
            {
                elem *e;
                OPER op;

                debug if (debugc)
                {   printf("4rewriting ("); WReqn(n); printf(")\n"); }

                e = el_calloc();
                el_copy(e,n);
                e.EV.E1 = el_copytree(e1.EV.E1);
                e.EV.E1.Ety = n.EV.E1.Ety;
                n.EV.E2 = e;
                switch (e1.Eoper)
                {
                    case OPpostinc:
                        e1.Eoper = OPaddass;
                        op = OPmin;
                        goto L3;

                    case OPpostdec:
                        e1.Eoper = OPminass;
                        op = OPadd;
                    L3: e.EV.E1 = el_bin(op,e.EV.E1.Ety,e.EV.E1,el_copytree(e1.EV.E2));
                        break;

                    default:
                        break;
                }
                /* increment node is now guaranteed to have no goal */
                e1.Nflags |= NFLnogoal;
                n.Eoper = OPcomma;
                //go.changes++;
                doflow = true;

                elimspecwalk(&n.EV.E1);
                elimspecwalk(&n.EV.E2);
            }
        }
  }
}

/********
 * Walk e in execution order.
 * When eincrement is found, remove it.
 * Continue, replacing instances of `v` with `v+increment`
 * When second eincrement is found, stop.
 * Params:
 *      e = expression to walk
 *      defnum = index of eincrement
 *      v = increment variable
 *      increment = amount to increment v
 *      unrolls = number of times loop has been unrolled
 */

private void unrollWalker(elem* e, uint defnum, Symbol* v, targ_llong increment, int unrolls) nothrow
{
    int state = 0;

    /***********************************
     * Walk e in execution order, fixing it according to state.
     * state == 0..unrolls-1: when eincrement is found, remove it, advance to next state
     * state == 1..unrolls-1: replacing instances of v with v+(state*increment),
     * state == unrolls-1: leave eincrement alone, advance to next state
     * state == unrolls: done
     */

    void walker(elem *e)
    {
        assert(e);
        const op = e.Eoper;
        if (ERTOL(e))
        {
            if (e.Edef != defnum)
            {
                walker(e.EV.E2);
                walker(e.EV.E1);
            }
        }
        else if (OTbinary(op))
        {
            if (e.Edef != defnum)
            {
                walker(e.EV.E1);
                walker(e.EV.E2);
            }
        }
        else if (OTunary(op))
        {
            assert(e.Edef != defnum);
            walker(e.EV.E1);
        }
        else if (op == OPvar &&
                 state &&
                 e.EV.Vsym == v)
        {
            // overwrite e with (v+increment)
            elem *e1 = el_calloc();
            el_copy(e1,e);
            e.Eoper = OPadd;
            e.EV.E1 = e1;
            e.EV.E2 = el_long(e.Ety, increment * state);
        }
        if (OTdef(op) && e.Edef == defnum)
        {
            // found the increment elem; neuter all but the last one
            if (state + 1 < unrolls)
            {
                el_free(e.EV.E1);
                el_free(e.EV.E2);
                e.Eoper = OPconst;
                e.EV.Vllong = 0;
            }
            ++state;
        }
    }

    walker(e);
    assert(state == unrolls);
}


/*********************************
 * Unroll loop if possible.
 * Params:
 *      l = loop to unroll
 * Returns:
 *      true if loop was unrolled
 */
@trusted
bool loopunroll(ref loop l)
{
    const bool log = false;
    if (log) printf("loopunroll(%p)\n", &l);

    /* Do not repeatedly unroll the same loop,
     * or waste time attempting to
     */
    if (l.Lhead.Bflags & BFLnounroll)
        return false;
    l.Lhead.Bflags |= BFLnounroll;
    if (log) WRfunc();

    if (l.Lhead.Btry || l.Ltail.Btry)
        return false;

    /* For simplification, only unroll loops that consist only
     * of a head and tail, and the tail is the exit block.
     */
    int numblocks = 0;
    for (int i = 0; (i = cast(uint) vec_index(i, l.Lloop)) < dfo.length; ++i)  // for each block in loop
        ++numblocks;
    if (numblocks != 2)
    {
        if (log) printf("\tnot 2 blocks, but %d\n", numblocks);
        return false;
    }
    assert(l.Lhead != l.Ltail);

    /* tail must be the sole exit block
     */
    if (vec_testbit(l.Lhead.Bdfoidx, l.Lexit) ||
        !vec_testbit(l.Ltail.Bdfoidx, l.Lexit))
    {
        if (log) printf("\ttail not sole exit block\n");
        return false;
    }

    elem *ehead = l.Lhead.Belem;
    elem *etail = l.Ltail.Belem;

    if (log)
    {
        printf("Unroll candidate:\n");
        printf("  head B%d:\t", l.Lhead.Bdfoidx); WReqn(l.Lhead.Belem); printf("\n");
        printf("  tail B%d:\t", l.Ltail.Bdfoidx); WReqn(l.Ltail.Belem); printf("\n");
    }

    /* Tail must be of the form: (v < c) or (v <= c) where v is an unsigned integer
     */
    if ((etail.Eoper != OPlt && etail.Eoper != OPle) ||
        etail.EV.E1.Eoper != OPvar ||
        etail.EV.E2.Eoper != OPconst)
    {
        if (log) printf("\tnot (v < c)\n");
        return false;
    }

    elem *e1 = etail.EV.E1;
    elem *e2 = etail.EV.E2;

    if (!tyintegral(e1.Ety) ||
        tysize(e1.Ety) > targ_llong.sizeof ||
        !(tyuns(e1.Ety) || tyuns(e2.Ety)))
    {
        if (log) printf("\tnot (integral unsigned)\n");
        return false;
    }

    int cost = el_length(ehead);
    //printf("test4 cost: %d\n", cost);

    if (cost > 100)
    {
        if (log) printf("\tcost %d\n", cost);
        return false;
    }
    if (log) printf("cost %d\n", cost);

    Symbol* v = e1.EV.Vsym;

    // RD info is only reliable for registers and autos
    if (!(sytab[v.Sclass] & SCRD) || !(v.Sflags & SFLunambig))
    {
        if (log) printf("\tnot SCRD\n");
        return false;
    }

    /* Find the initial, increment elem, and final value of s
     */
    elem *einitial;
    elem *eincrement;
    if (!findloopparameters(etail, einitial, eincrement))
    {
        if (log) printf("\tnot findloopparameters()\n");
        return false;
    }

    targ_llong initial = el_tolong(einitial.EV.E2);
    targ_llong increment = el_tolong(eincrement.EV.E2);
    if (eincrement.Eoper == OPpostdec || eincrement.Eoper == OPminass)
        increment = -increment;
    targ_llong final_ = el_tolong(e2);

    if (log) printf("initial = %lld, increment = %lld, final = %lld\n",cast(long)initial,cast(long)increment,cast(long)final_);

    if (etail.Eoper == OPle)
        ++final_;

    if (initial < 0 ||
        final_ < initial ||
        increment <= 0 ||
        (final_ - initial) % increment)
    {
        if (log) printf("\tnot (evenly divisible)\n");
        return false;
    }

    /* If loop would only execute once anyway, just remove the test at the end
     */
    if (initial + increment == final_)
    {
        if (log) printf("\tjust once\n");
        etail.Eoper = OPcomma;
        e2.EV.Vllong = 0;
        e2.Ety = etail.Ety;
        return false;
    }

    /* number of times the loop is unrolled
     */
    targ_ullong numIterations = (final_ - initial) / increment;
    const int unrolls = (numIterations < 1000 / cost)
        ? cast(int)numIterations
        : 2;

    if (unrolls == 0 || (final_ - initial) % unrolls)
    {
        if (log) printf("\tnot (divisible by %d)\n", unrolls);
        return false;
    }

    if (log) printf("Unrolling starting\n");

    // Double the increment
    eincrement.EV.E2.EV.Vllong *= unrolls;
    //printf("  4head:\t"); WReqn(l.Lhead.Belem); printf("\n");

    elem* e = null;
    foreach (i; 0 .. unrolls)
        e = el_combine(e, el_copytree(ehead));

    /* Walk e in execution order.
     * When eincrement is found, remove it.
     * Continue, replacing instances of `v` with `v+increment`
     * When last eincrement is found, stop.
     */
    unrollWalker(e, eincrement.Edef, v, increment, unrolls);

    l.Lhead.Belem = e;

    /* If unrolled loop would only execute once anyway, just remove the test at the end
     */
    if (initial + unrolls * increment == final_)
    {
        if (log) printf("\tcompletely unrolled\n");
        etail.Eoper = OPcomma;
        e2.EV.Vllong = 0;
        e2.Ety = etail.Ety;
    }

    //WRfunc();
    return true;
}

/******************************
 * Count number of elems in a tree
 * Params:
 *  e = tree
 * Returns:
 *  number of elems in tree
 */
@trusted
private int el_length(elem *e)
{
    int n = 0;
    while (e)
    {
        n += 1;
        if (!OTleaf(e.Eoper))
        {
            if (e.Eoper == OPctor || e.Eoper == OPdtor)
                return 10_000;
            n += el_length(e.EV.E2);
            e = e.EV.E1;
        }
        else
            break;
    }
    return n;
}


}
