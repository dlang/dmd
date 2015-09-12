// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
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
#include        <string.h>
#include        <time.h>

#include        "cc.h"
#include        "el.h"
#include        "go.h"
#include        "oper.h"
#include        "global.h"
#include        "type.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/*#define vec_copy(t,f) (dbg_printf("line %d\n",__LINE__),vec_copy((t),(f)))*/

extern mftype mfoptim;

struct Iv;

/*********************************
 * Loop data structure.
 */

struct loop
{   loop *Lnext;        // Next loop in list (startloop -> start of list)
    vec_t Lloop;        // Vector of blocks in this loop
    vec_t Lexit;        // Vector of exit blocks of loop
    block *Lhead;       // Pointer to header of loop
    block *Ltail;       // Pointer to tail
    block *Lpreheader;  // Pointer to preheader (if any)
    list_t Llis;        // loop invariant elems moved to Lpreheader, so
                        // redundant temporaries aren't created
    Iv *Livlist;        // basic induction variables
    Iv *Lopeqlist;      // list of other op= variables
    void print();
    static loop *mycalloc();

    static loop *freelist;
};

struct famlist
{       elem **FLpelem;         /* parent of elem in the family         */
        elem *c1,*c2;           /* c1*(basic IV) + c2                   */
#define FLELIM  ((symbol *)-1)
        symbol *FLtemp;         // symbol index of temporary (FLELIM if */
                                /* this entry has no temporary)         */
        tym_t FLty;             /* type of this induction variable      */
        tym_t FLivty;           /* type of the basic IV elem (which is  */
                                /* not necessarilly the type of the IV  */
                                /* elem!)                               */
        famlist *FLnext;        // next in list
        void print();

    static famlist *mycalloc();

    static famlist *freelist;
};

struct Iv
{
        symbol *IVbasic;        // symbol of basic IV
        elem **IVincr;          // pointer to parent of IV increment elem
        famlist *IVfamily;      // variables in this family
        Iv *IVnext;             // next iv in list
        void print();

    static Iv *mycalloc();

    static Iv *freelist;
};

STATIC void freeloop(loop **pl);
STATIC void buildloop(loop **pl, block *head, block *tail);
STATIC void insert(block *b , vec_t lv);
STATIC void movelis(elem *n,block *b,loop *l,int *pdomexit);
STATIC int looprotate(loop *l);
STATIC void markinvar(elem *n , vec_t rd);
STATIC bool refs(symbol *v , elem *n , elem *nstop);
STATIC void appendelem(elem *n , elem **pn);
STATIC void freeivlist(Iv *biv);
STATIC void unmarkall(elem *e);
void filterrd(vec_t f,vec_t rd,symbol *s);
STATIC void filterrdind(vec_t f,vec_t rd,elem *e);
STATIC famlist * simfl(famlist *fl , tym_t tym);
STATIC famlist * newfamlist(tym_t ty);
STATIC void loopiv(loop *l);
STATIC void findbasivs(loop *l);
STATIC void findopeqs(loop *l);
STATIC void findivfams(loop *l);
STATIC void ivfamelems(Iv *biv , elem **pn);
STATIC void elimfrivivs(loop *l);
STATIC void intronvars(loop *l);
STATIC bool funcprev(Iv *biv , famlist *fl);
STATIC void elimbasivs(loop *l);
STATIC void elimopeqs(loop *l);
STATIC famlist * flcmp(famlist *f1 , famlist *f2);
STATIC elem ** onlyref(symbol *x , loop *l , elem *incn , int *prefcount);
STATIC void countrefs(elem **pn , bool flag);
STATIC int countrefs2(elem *e);
STATIC void elimspec(loop *l);
STATIC void elimspecwalk(elem **pn);

static  bool addblk;                    /* if TRUE, then we added a block */

/* is elem loop invariant?      */
inline int isLI(elem *n) { return n->Nflags & NFLli; }

/* make elem loop invariant     */
inline void makeLI(elem *n) { n->Nflags |= NFLli; }

/******************************
 *      Only variables that could only be unambiguously defined
 *      are candidates for loop invariant removal and induction
 *      variables.
 *      This means only variables that have the SFLunambig flag
 *      set for them.
 *      Doing this will still cover 90% (I hope) of the cases, and
 *      is a lot faster to compute.
 */

/****************************
 */

void famlist::print()
{
#ifdef DEBUG
    dbg_printf("famlist:\n");
    dbg_printf("*FLpelem:\n");
    elem_print(*FLpelem);
    dbg_printf("c1:");
    elem_print(c1);
    dbg_printf("c2:");
    elem_print(c2);
    dbg_printf("FLty = "); WRTYxx(FLty);
    dbg_printf("\nFLivty = "); WRTYxx(FLivty);
    dbg_printf("\n");
#endif
}


/****************************
 */

void Iv::print()
{
#ifdef DEBUG
    dbg_printf("IV: '%s'\n",IVbasic->Sident);
    dbg_printf("*IVincr:\n");
    elem_print(*IVincr);
#endif
}

/***********************
 * Write loop.
 */

void loop::print()
{
#ifdef DEBUG
  loop *l = this;
  dbg_printf("loop %p, next = %p\n",l,(l) ? l->Lnext : (loop *) NULL);
  if (!l)
        return;
  dbg_printf("\thead: B%d, tail: B%d, prehead: B%d\n",l->Lhead->Bdfoidx,
        l->Ltail->Bdfoidx,(l->Lpreheader ) ? l->Lpreheader->Bdfoidx :
                                                        (unsigned)-1);
  dbg_printf("\tLloop "); vec_println(l->Lloop);
  dbg_printf("\tLexit "); vec_println(l->Lexit);
#endif
}

/***************************
 * Allocate loop.
 */

loop *loop::freelist = NULL;

loop *loop::mycalloc()
{   loop *l;

    if (freelist)
    {
        l = freelist;
        freelist = l->Lnext;
        memset(l,0,sizeof(loop));
    }
    else
        l = (loop *) mem_calloc(sizeof(loop));
    return l;
}

/*************
 * Free loops.
 */

STATIC void freeloop(loop **pl)
{ loop *ln;
  loop *l;

  for (l = *pl; l; l = ln)
  {     ln = l->Lnext;
        vec_free(l->Lloop);
        vec_free(l->Lexit);
        list_free(&l->Llis);
        l->Lnext = loop::freelist;
        loop::freelist = l;
  }
  *pl = NULL;
}

/**********************************
 * Initialize block information.
 * Returns:
 *      !=0     contains BCasm block
 */

int blockinit()
{ unsigned i;
  block *b;
  int hasasm = 0;

  assert(dfo);
  for (i = 0, b = startblock; b; i++, b = b->Bnext)
  {
#ifdef DEBUG                    /* check integrity of Bpred and Bsucc   */
        list_t blp;

        for (blp = b->Bpred; blp; blp = list_next(blp))
        {       list_t bls;

                for (bls = list_block(blp)->Bsucc; bls; bls = list_next(bls))
                        if (list_block(bls) == b)
                                goto L1;
                assert(0);
            L1: ;
        }
#endif
        if (b->BC == BCasm)
            hasasm = 1;
        ;                               /* compute number of blocks     */
  }
  assert(numblks == i && maxblks);
  assert(i <= maxblks);
  for (i = 0; i < dfotop; i++)
  {     assert(dfo[i]->Bdfoidx == i);
        if (!dfo[i]->Bdom)
                dfo[i]->Bdom = vec_calloc(maxblks); /* alloc Bdom vectors */
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

void compdom()
{ unsigned i;
  unsigned cntr;
  vec_t t1;
  list_t bl;
  bool chgs;
  block *sb;

  assert(dfo);
  sb = dfo[0];                          // starting block
  t1 = vec_calloc(vec_numbits(sb->Bdom));       // allocate a temporary
  vec_clear(sb->Bdom);
  vec_setbit(0,sb->Bdom);               // starting block only doms itself
  for (i = 1; i < dfotop; i++)          // for all except startblock
        vec_set(dfo[i]->Bdom);          // dominate all blocks
  cntr = 0;                             // # of times thru loop
  do
  {     chgs = FALSE;
        for (i = 1; i < dfotop; ++i)    // for each block in dfo[]
        {                               // except startblock
                bl = dfo[i]->Bpred;
                if (bl)                 // if there are predecessors
                {       vec_copy(t1,list_block(bl)->Bdom);
                        while ((bl = list_next(bl)) != NULL)
                            vec_andass(t1,list_block(bl)->Bdom);
                }
                else
                        vec_clear(t1);  // no predecessors to dominate
                vec_setbit(i,t1);       // each block doms itself
                if (chgs)
                        vec_copy(dfo[i]->Bdom,t1);
                else if (!vec_equal(dfo[i]->Bdom,t1))   // if any changes
                {       vec_copy(dfo[i]->Bdom,t1);
                        chgs = TRUE;
                }
        }
        cntr++;
        assert(cntr < 50);              // should have converged by now
  } while (chgs);
  vec_free(t1);
  if (cntr <= 2)
        cmes("Flow graph is reducible\n");
  else
        cmes("Flow graph is not reducible\n");
}

/***************************
 * Return !=0 if block A dominates block B.
 */

bool dom(block *A,block *B)
{
  assert(A && B && dfo && dfo[A->Bdfoidx] == A);
  return vec_testbit(A->Bdfoidx,B->Bdom) != 0;
}

/**********************
 * Find all the loops.
 */

STATIC void findloops(loop **ploops)
{ unsigned i;
  list_t bl;
  block *b,*s;

  freeloop(ploops);

  //printf("findloops()\n");
  for (i = 0; i < dfotop; i++)
        dfo[i]->Bweight = 1;            /* reset Bweights               */
  for (i = dfotop; i--;)                /* for each block (note reverse */
                                        /* dfo order, so most nested    */
                                        /* loops are found first)       */
  {     b = dfo[i];
        assert(b);
        for (bl = b->Bsucc; bl; bl = list_next(bl))
        {       s = list_block(bl);             /* each successor s to b */
                assert(s);
                if (dom(s,b))                   /* if s dominates b     */
                    buildloop(ploops,s,b);      // we found a loop
        }
  }

#ifdef DEBUG
  if (debugc)
  { loop *l;

    for (l = *ploops; l; l = l->Lnext)
    {
        l->print();
    }
  }
#endif
}

/********************************
 */

STATIC void loop_weight(block *b,int factor)
{
    // Be careful not to overflow
    if (b->Bweight < 0x10000)
        b->Bweight *= 10 * factor;
    else if (b->Bweight < 0x100000)
        b->Bweight *= 2 * factor;
    else
        b->Bweight += factor;
}

/*****************************
 * Construct natural loop.
 * Algorithm 13.1 from Aho & Ullman.
 * Note that head dom tail.
 */

STATIC void buildloop(loop **ploops,block *head,block *tail)
{ loop *l;
  unsigned i;
  list_t bl;

  //printf("buildloop()\n");
  /* See if this is part of an existing loop. If so, merge the two.     */
  for (l = *ploops; l; l = l->Lnext)
        if (l->Lhead == head)           /* two loops with same header   */
        {
            vec_t v;

            // Calculate loop contents separately so we get the Bweights
            // done accurately.

            v = vec_calloc(maxblks);
            vec_setbit(head->Bdfoidx,v);
            loop_weight(head,1);
            insert(tail,v);

            vec_orass(l->Lloop,v);      // merge into existing loop
            vec_free(v);

            vec_clear(l->Lexit);        // recompute exit blocks
            goto L1;
        }

  /* Allocate loop entry        */
  l = loop::mycalloc();
  l->Lnext = *ploops;
  *ploops = l;                          // put l at beginning of list

  l->Lloop = vec_calloc(maxblks);       /* allocate loop bit vector     */
  l->Lexit = vec_calloc(maxblks);       /* bit vector for exit blocks   */
  l->Lhead = head;
  l->Ltail = tail;

  vec_setbit(head->Bdfoidx,l->Lloop);   /* add head to the loop         */
  loop_weight(head,2);                  // *20 usage for loop header

  insert(tail,l->Lloop);                /* insert tail in loop          */

L1:
  /* Find all the exit blocks (those blocks with
   * successors outside the loop).
   */

  foreach (i,dfotop,l->Lloop)           /* for each block in this loop  */
  {     if (dfo[i]->BC == BCret || dfo[i]->BC == BCretexp || dfo[i]->BC == BCexit)
                vec_setbit(i,l->Lexit); /* ret blocks are exit blocks */
        else
        {       for (bl = dfo[i]->Bsucc; bl; bl = list_next(bl))
                        if (!vec_testbit(list_block(bl)->Bdfoidx,l->Lloop))
                        {       vec_setbit(i,l->Lexit);
                                break;
                        }
        }
  }

    /*  Find preheader, if any, to the loop.
        The preheader is a block that has only the head as a successor.
        All other predecessors of head must be inside the loop.
     */
    l->Lpreheader = NULL;
    for (bl = head->Bpred; bl; bl = list_next(bl))
    {   block *b = list_block(bl);

        if (!vec_testbit(b->Bdfoidx,l->Lloop))  /* if not in loop       */
        {   if (l->Lpreheader)                  /* if already one       */
            {   l->Lpreheader = NULL;           /* can only be one      */
                break;
            }
            else
            {   if (list_next(b->Bsucc))        // if more than 1 successor
                    break;                      // b can't be a preheader
                l->Lpreheader = b;
            }
        }
    }
}

/********************************
 * Support routine for buildloop().
 * Add a block b and all its predecessors to loop lv.
 */

STATIC void insert(block *b, vec_t lv)
{ list_t bl;

  assert(b && lv);
  if (!vec_testbit(b->Bdfoidx,lv))      /* if block is not in loop      */
  {     vec_setbit(b->Bdfoidx,lv);      /* add block to loop            */
        loop_weight(b,1);               // *10 usage count
        for (bl = b->Bpred; bl; bl = list_next(bl))
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
 *      TRUE need to recompute loop data
 */

STATIC int looprotate(loop *l)
{
       block *tail = l->Ltail;
       block *head = l->Lhead;
       block *b;

    //printf("looprotate(%p)\n",l);

    // Do not rotate loop if:
    if (head == tail ||                         // loop is only one block big
        !vec_testbit(head->Bdfoidx,l->Lexit))   // header is not an exit block
        goto Lret;

    if (//iter != 1 &&
        vec_testbit(tail->Bdfoidx,l->Lexit))    // tail is an exit block
        goto Lret;

    // Do not rotate if already rotated
    for (b = tail->Bnext; b; b = b->Bnext)
        if (b == head)                  // if loop already rotated
            goto Lret;

#if SCPP
    if (head->BC == BCtry)
         goto Lret;
#endif
    if (head->BC == BC_try)
         goto Lret;
#ifdef DEBUG
    //if (debugc) { dbg_printf("looprotate: "); l->print(); }
#endif

    if ((mfoptim & MFtime) && head->BC != BCswitch && head->BC != BCasm)
    {   // Duplicate the header past the tail (but doing
        // switches would be too expensive in terms of code
        // generated).
           block *head2;
           list_t bl, *pbl2, *pbl, *pbln;

        head2 = block_calloc(); // create new head block
        numblks++;                      // number of blocks in existence
        head2->Btry = head->Btry;
        head2->Bflags = head->Bflags;
        head->Bflags = BFLnomerg;       // move flags over to head2
        head2->Bflags |= BFLnomerg;
        head2->BC = head->BC;
        assert(head2->BC != BCswitch);
        if (head->Belem)                // copy expression tree
            head2->Belem = el_copytree(head->Belem);
        head2->Bnext = tail->Bnext;
        tail->Bnext = head2;

        // pred(head1) = pred(head) outside loop
        // pred(head2) = pred(head) inside loop
        pbl2 = &(head2->Bpred);
        for (pbl = &(head->Bpred); *pbl; pbl = pbln)
        {
            if (vec_testbit(list_block(*pbl)->Bdfoidx, l->Lloop))
            {   // if this predecessor is inside the loop

                *pbl2 = *pbl;
                *pbl = list_next(*pbl);
                pbln = pbl;                     // don't skip this next one
                list_next(*pbl2) = NULL;
                bl = list_block(*pbl2)->Bsucc;
                pbl2 = &(list_next(*pbl2));
                for (; bl; bl = list_next(bl))
                    if (list_block(bl) == head)
                    {
                        list_ptr(bl) = (void *)head2;
                        goto L2;
                    }
                assert(0);
        L2:     ;
            }
            else
                pbln = &(list_next(*pbl));      // next predecessor in list
        } // for each pred(head)

        // succ(head2) = succ(head)
        for (bl = head->Bsucc; bl; bl = list_next(bl))
        {
            list_append(&(head2->Bsucc),list_block(bl));
            list_append(&(list_block(bl)->Bpred),head2);
        }
        changes++;
        return TRUE;
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
        for (b = startblock; b; b = b->Bnext)
            if (b->Bnext == head)
                goto L1;                // found parent b of head
        assert(0);

    L1:
        b->Bnext = head->Bnext;
        head->Bnext = tail->Bnext;
        tail->Bnext = head;
        cmes2( "Rotated loop %p\n", l);
        changes++;
    }
Lret:
    return FALSE;
}

static int gref;                // parameter for markinvar()
static block *gblock;           // parameter for markinvar()
static vec_t lv;                // parameter for markinvar()
static vec_t gin;               // parameter for markinvar()
static bool doflow;             // TRUE if flow analysis has to be redone

/*********************************
 * Loop invariant and induction variable elimination.
 * Input:
 *      iter    which optimization iteration we are on
 */

void loopopt()
{
    list_t bl;
    loop *l;
    loop *ln;
    vec_t rd;
    loop *startloop;

    cmes("loopopt()\n");
    startloop = NULL;
restart:
    file_progress();
    if (blockinit())                    // init block data
    {
        findloops(&startloop);          // Compute Bweights
        freeloop(&startloop);           // free existing loops
        return;                         // can't handle ASM blocks
    }
    compdom();                          // compute dominators
    findloops(&startloop);              // find the loops

    for (l = startloop; l; l = ln)
    {
        ln = l->Lnext;
        if (looprotate(l))              // rotate the loop
        {
            compdfo();
            blockinit();
            compdom();
            findloops(&startloop);      // may trash l->Lnext
            if (ln)
            {   ln = startloop;         // start over
                file_progress();
            }
        }
    }
    // Make sure there is a preheader for each loop.

    addblk = FALSE;                     /* assume no blocks added        */
    for (l = startloop; l; l = l->Lnext)/* for each loop                 */
    {
#ifdef DEBUG
        //if (debugc) l->print();
#endif
        if (!l->Lpreheader)             /* if no preheader               */
        {   block *h, *p;

            cmes("Generating preheader for loop\n");
            addblk = TRUE;              /* add one                       */
            p = block_calloc();         // the preheader
            numblks++;
            assert (numblks <= maxblks);
            h = l->Lhead;               /* loop header                   */

            /* Find parent of h */
            if (h == startblock)
                startblock = p;
            else
            {   block *ph;

                for (ph = startblock; 1; ph = ph->Bnext)
                {   assert(ph);         /* should have found it         */
                    if (ph->Bnext == h)
                            break;
                }
                /* Link p into block list between ph and h      */
                ph->Bnext = p;
            }
            p->Bnext = h;

            l->Lpreheader = p;
            p->BC = BCgoto;
            assert(p->Bsucc == NULL);
            list_append(&(p->Bsucc),h); /* only successor is h          */
            p->Btry = h->Btry;

            cmes3("Adding preheader %p to loop %p\n",p,l);

            // Move preds of h that aren't in the loop to preds of p
            for (bl = h->Bpred; bl;)
            {   block *b = list_block(bl);

                if (!vec_testbit (b->Bdfoidx, l->Lloop))
                {   list_t bls;

                    list_append(&(p->Bpred), b);
                    list_subtract(&(h->Bpred), b);
                    bl = h->Bpred;      /* dunno what subtract did      */

                    /* Fix up successors of predecessors        */
                    for (bls = b->Bsucc; bls; bls = list_next(bls))
                        if (list_block(bls) == h)
                                list_ptr(bls) = (void *)p;
                }
                else
                    bl = list_next(bl);
            }
            list_append(&(h->Bpred),p); /* p is a predecessor to h      */
        }
    } /* for */
    if (addblk)                         /* if any blocks were added      */
    {
        compdfo();                      /* compute depth-first order    */
        blockinit();
        compdom();
        findloops(&startloop);          // recompute block info
        addblk = FALSE;
    }

    /* Do the loop optimizations. Note that accessing the loops */
    /* starting from startloop will access them in least nested */
    /* one first, thus moving LIs out as far as possible.       */

    doflow = TRUE;                      /* do flow analysis             */
    cmes("Starting loop invariants\n");

    for (l = startloop; l; l = l->Lnext)
    {   unsigned i,j;

#ifdef DEBUG
        //if (debugc) l->print();
#endif
        file_progress();
        assert(l->Lpreheader);
        if (doflow)
        {
                flowrd();               /* compute reaching definitions  */
                flowlv();               /* compute live variables        */
                flowae();               // compute available expressions
                doflow = FALSE;         /* no need to redo it           */
                if (deftop == 0)        /* if no definition elems       */
                        break;          /* no need to optimize          */
        }
        lv = l->Lloop;
        cmes2("...Loop %p start...\n",l);

        /* Unmark all elems in this loop         */
        foreach (i,dfotop,lv)
            if (dfo[i]->Belem)
                unmarkall(dfo[i]->Belem);       /* unmark all elems     */

        /* Find & mark all LIs   */
        gin = vec_clone(l->Lpreheader->Bout);
        rd = vec_calloc(deftop);        /* allocate our running RD vector */
        foreach (i,dfotop,lv)           /* for each block in loop       */
        {   block *b = dfo[i];

            cmes2("B%d\n",i);
            if (b->Belem)
            {
                vec_copy(rd, b->Binrd); // IN reaching defs
#if 0
                dbg_printf("i = %d\n",i);
                {   int j;
                    for (j = 0; j < deftop; j++)
                        elem_print(defnod[j].DNelem);
                }
                dbg_printf("rd    : "); vec_println(rd);
#endif
                gblock = b;
                gref = 0;
                if (b != l->Lhead)
                    gref = 1;
                markinvar(b->Belem, rd);
#if 0
                dbg_printf("i = %d\n",i);
                {   int j;
                    for (j = 0; j < deftop; j++)
                        elem_print(defnod[j].DNelem);
                }
                dbg_printf("rd    : "); vec_println(rd);
                dbg_printf("Boutrd: "); vec_println(b->Boutrd);
#endif
                assert(vec_equal(rd, b->Boutrd));
            }
            else
                assert(vec_equal(b->Binrd, b->Boutrd));
        }
        vec_free(rd);
        vec_free(gin);

        /* Move loop invariants  */
        foreach (i,dfotop,lv)
        {
            int domexit;                // TRUE if this block dominates all
                                        // exit blocks of the loop

            foreach (j,dfotop,l->Lexit) /* for each exit block  */
            {
                    if (!vec_testbit (i, dfo[j]->Bdom))
                    {   domexit = 0;
                        goto L1;                // break if !(i dom j)
                    }
            }
            // if i dom (all exit blocks)
            domexit = 1;
        L1:     ;
            if (dfo[i]->Belem)
            {   // If there is any hope of making an improvement
                if (domexit || l->Llis)
                {   //if (dfo[i] != l->Lhead)
                        //domexit |= 2;
                    movelis(dfo[i]->Belem, dfo[i], l, &domexit);
                }
            }
        }
        //list_free(&l->Llis,FPNULL);
        cmes2("...Loop %p done...\n",l);

        if (mfoptim & MFliv)
        {       loopiv(l);              /* induction variables          */
                if (addblk)             /* if we added a block          */
                {       compdfo();
                        goto restart;   /* play it safe and start over  */
                }
        }
    } /* for */
    freeloop(&startloop);
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

STATIC void markinvar(elem *n,vec_t rd)
{ vec_t tmp;
  unsigned i;
  symbol *v;
  elem *n1;

  assert(n && rd);
  assert(vec_numbits(rd) == deftop);
  switch (n->Eoper)
  {
        case OPaddass:  case OPminass:  case OPmulass:  case OPandass:
        case OPorass:   case OPxorass:  case OPdivass:  case OPmodass:
        case OPshlass:  case OPshrass:  case OPashrass:
        case OPpostinc: case OPpostdec:
        case OPcall:
        case OPvecsto:
        case OPcmpxchg:
                        markinvar(n->E2,rd);
        case OPnegass:
                        n1 = n->E1;
                        if (n1->Eoper == OPind)
                                markinvar(n1->E1,rd);
                        else if (OTbinary(n1->Eoper))
                        {   markinvar(n1->E1,rd);
                            markinvar(n1->E2,rd);
                        }
        L2:
                        if (n->Eoper == OPcall ||
                            gblock->Btry ||
                            !(n1->Eoper == OPvar &&
                                symbol_isintab(n1->EV.sp.Vsym)))
                        {
                            gref = 1;
                        }

                        updaterd(n,rd,NULL);
                        break;

        case OPcallns:
                markinvar(n->E2,rd);
                markinvar(n->E1,rd);
                break;

        case OPstrcpy:
        case OPstrcat:
        case OPmemcpy:
        case OPmemset:
                markinvar(n->E2,rd);
                markinvar(n->E1,rd);
                updaterd(n,rd,NULL);
                break;
        case OPbtc:
        case OPbtr:
        case OPbts:
                markinvar(n->E1,rd);
                markinvar(n->E2,rd);
                updaterd(n,rd,NULL);
                break;
        case OPucall:
                markinvar(n->E1,rd);
                /* FALL-THROUGH */
        case OPasm:
                gref = 1;
                updaterd(n,rd,NULL);
                break;

        case OPucallns:
        case OPstrpar:
        case OPstrctor:
        case OPvector:
        case OPvoid:
        case OPstrlen:
#if TX86
        case OPinp:
#endif
                markinvar(n->E1,rd);
                break;
        case OPcond:
        case OPparam:
        case OPstrcmp:
        case OPmemcmp:
        case OPbt:                      // OPbt is like OPind, assume not LI
#if TX86
        case OPoutp:
#endif
                markinvar(n->E1,rd);
                markinvar(n->E2,rd);
                break;
        case OPandand:
        case OPoror:
                markinvar(n->E1,rd);
                tmp = vec_clone(rd);
                markinvar(n->E2,tmp);
                vec_orass(rd,tmp);              /* rd |= tmp            */
                vec_free(tmp);
                break;
        case OPcolon:
        case OPcolon2:
                tmp = vec_clone(rd);
                markinvar(n->E1,rd);
                markinvar(n->E2,tmp);
                vec_orass(rd,tmp);              /* rd |= tmp            */
                vec_free(tmp);
                break;
        case OPaddr:            // mark addresses of OPvars as LI
                markinvar(n->E1,rd);
                if (n->E1->Eoper == OPvar || isLI(n->E1))
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
        case OPrndtol:
        case OPrint:
        case OPsetjmp:
        case OPbsf:
        case OPbsr:
        case OPbswap:
        case OPpopcnt:
#if TX86
        case OPsqrt:
        case OPsin:
        case OPcos:
#endif
#if TARGET_SEGMENTED
        case OPvp_fp: /* BUG for MacHandles */
        case OPnp_f16p: case OPf16p_np: case OPoffset: case OPnp_fp:
        case OPcvp_fp:
#endif
                markinvar(n->E1,rd);
                if (isLI(n->E1))        /* if child is LI               */
                        makeLI(n);
                break;
        case OPeq:
        case OPstreq:
                markinvar(n->E2,rd);
                n1 = n->E1;
                markinvar(n1,rd);

                /* Determine if assignment is LI. Conditions are:       */
                /* 1) Rvalue is LI                                      */
                /* 2) Lvalue is a variable (simplifies things a lot)    */
                /* 3) Lvalue can only be affected by unambiguous defs   */
                /* 4) No rd's of lvalue that are within the loop (other */
                /*    than the current def)                             */
                if (isLI(n->E2) && n1->Eoper == OPvar)          /* 1 & 2 */
                {   v = n1->EV.sp.Vsym;
                    if (v->Sflags & SFLunambig)
                    {
                        tmp = vec_calloc(deftop);
                        //filterrd(tmp,rd,v);
                        listrds(rd,n1,tmp);
                        foreach (i,deftop,tmp)
                            if (defnod[i].DNelem != n &&
                                vec_testbit(defnod[i].DNblock->Bdfoidx,lv))
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
#if TX86
        case OPscale:
        case OPyl2x:
        case OPyl2xp1:
#endif
                markinvar(n->E1,rd);
                markinvar(n->E2,rd);
                if (isLI(n->E2) && isLI(n->E1))
                        makeLI(n);
                break;

        case OPind:                     /* must assume this is not LI   */
                markinvar(n->E1,rd);
                if (isLI(n->E1))
                {
#if 0
                    // This doesn't work with C++, because exp2_ptrtocomtype() will
                    // transfer const to where it doesn't belong.
                    if (n->Ety & mTYconst)
                    {
                        makeLI(n);
                    }
#endif
#if 0
                    // This was disabled because it was marking as LI
                    // the loop dimension for the [i] array if
                    // a[j][i] was in a loop. This meant the a[j] array bounds
                    // check for the a[j].length was skipped.
                    else if (n->Ejty)
                    {
                        tmp = vec_calloc(deftop);
                        filterrdind(tmp,rd,n);  // only the RDs pertaining to n

                        // if (no RDs within loop)
                        //      then it's loop invariant

                        foreach (i,deftop,tmp)          // for each RD
                            if (vec_testbit(defnod[i].DNblock->Bdfoidx,lv))
                                goto L10;       // found a RD in the loop

                        // If gref has occurred, this can still be LI
                        // if n is an AE that was also an AE at the
                        // point of gref.
                        // We can catch a subset of these cases by looking
                        // at the AEs at the start of the loop.
                        if (gref)
                        {   int j;

                            //printf("\tn is: "); WReqn(n); printf("\n");
                            foreach (j,go.exptop,gin)
                            {   elem *e = go.expnod[j];

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
                L10:    vec_free(tmp);
                        break;
                    }
#endif
                }
                break;
        case OPvar:
                v = n->EV.sp.Vsym;
                if (v->Sflags & SFLunambig)     // must be unambiguous to be LI
                {
                    tmp = vec_calloc(deftop);
                    //filterrd(tmp,rd,v);       // only the RDs pertaining to v
                    listrds(rd,n,tmp);  // only the RDs pertaining to v

                    // if (no RDs within loop)
                    //  then it's loop invariant

                    foreach (i,deftop,tmp)              // for each RD
                        if (vec_testbit(defnod[i].DNblock->Bdfoidx,lv))
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
                markinvar(n->E2,rd);
                break;

        case OPstrthis:
        case OPmark:
        case OPctor:
        case OPdtor:
        case OPdctor:
        case OPddtor:
        case OPhalt:
        case OPgot:                     // shouldn't OPgot be makeLI ?
                break;

        default:
                WROP(n->Eoper);
                //printf("n->Eoper = %d, OPconst = %d\n", n->Eoper, OPconst);
                assert(0);
  }
#ifdef DEBUG
  if (debugc && isLI(n))
  {     dbg_printf("  LI elem: ");
        WReqn(n);
        dbg_printf("\n");
  }
#endif
}

/********************
 * Update rd vector.
 * Input:
 *      n       assignment elem or function call elem or OPasm elem
 *      rd      reaching def vector to update
 *              (clear bits for defs we kill, set bit for n (which is the
 *               def we are genning))
 *      vecdim  deftop
 */

void updaterd(elem *n,vec_t GEN,vec_t KILL)
{   unsigned op = n->Eoper;
    unsigned i;
    unsigned ni;
    elem *t;

    assert(OTdef(op));
    assert(GEN);
    elem_debug(n);

    // If unambiguous def
    if (OTassign(op) && (t = n->E1)->Eoper == OPvar)
    {   symbol *d = t->EV.sp.Vsym;
        targ_size_t toff = t->EV.sp.Voffset;
        targ_size_t tsize;
        targ_size_t ttop;

        tsize = (op == OPstreq) ? type_size(n->ET) : tysize(t->Ety);
        ttop = toff + tsize;

        //printf("updaterd: "); WReqn(n); printf(" toff=%d, tsize=%d\n", toff, tsize);

        ni = (unsigned)-1;

        /* for all unambig defs in defnod[] */
        for (i = 0; i < deftop; i++)
        {   elem *tn = defnod[i].DNelem;
            elem *tn1;
            targ_size_t tn1size;

            if (tn == n)
                ni = i;

            if (!OTassign(tn->Eoper))
                continue;

            // If def of same variable, kill that def
            tn1 = tn->E1;
            if (tn1->Eoper != OPvar || d != tn1->EV.sp.Vsym)
                continue;

            // If t completely overlaps tn1
            tn1size = (tn->Eoper == OPstreq)
                ? type_size(tn->ET) : tysize(tn1->Ety);
            if (toff <= tn1->EV.sp.Voffset &&
                tn1->EV.sp.Voffset + tn1size <= ttop)
            {
                if (KILL)
                    vec_setbit(i,KILL);
                vec_clearbit(i,GEN);
            }
        }
        assert(ni != -1);
    }
#if 0
    else if (OTassign(op) && t->Eoper != OPvar && t->Ejty)
    {
        ni = -1;

        // for all unambig defs in defnod[]
        for (i = 0; i < deftop; i++)
        {   elem *tn = defnod[i].DNelem;
            elem *tn1;

            if (tn == n)
                ni = i;

            if (!OTassign(tn->Eoper))
                continue;

            // If def of same variable, kill that def
            tn1 = tn->E1;
            if (tn1->Eoper != OPind || t->Ejty != tn1->Ejty)
                continue;

            if (KILL)
                vec_setbit(i,KILL);
            vec_clearbit(i,GEN);
        }
        assert(ni != -1);
    }
#endif
    else
    {
        /* Set bit in GEN for this def */
        for (i = 0; 1; i++)
        {   assert(i < deftop);         // should find n in defnod[]
            if (defnod[i].DNelem == n)
            {   ni = i;
                break;
            }
        }
    }

    vec_setbit(ni,GEN);                 // set bit in GEN for this def
}

/***************************
 * Mark all elems as not being loop invariant.
 */

STATIC void unmarkall(elem *e)
{
  for (; 1; e = e->E1)
  {
        assert(e);
        e->Nflags &= ~NFLli;            /* unmark this elem             */
        if (OTunary(e->Eoper))
                continue;
        else if (OTbinary(e->Eoper))
        {       unmarkall(e->E2);
                continue;
        }
        return;
  }
}


/********************************
 * Return TRUE if there are any refs of v in n before nstop is encountered.
 * Input:
 *      refstop = -1
 */

static int refstop;                     /* flag to stop refs()                  */

STATIC bool refs(symbol *v,elem *n,elem *nstop)
{ bool f;
  unsigned op;

  symbol_debug(v);
  elem_debug(n);
  assert(symbol_isintab(v));
  assert(v->Ssymnum < globsym.top);
  assert(n);

  op = n->Eoper;
  if (refstop == 0)
        return FALSE;
  f = FALSE;
  if (OTunary(op))
        f = refs(v,n->E1,nstop);
  else if (OTbinary(op))
  {     if (ERTOL(n))                   /* watch order of evaluation    */
        {
            /* Note that (OPvar = e) is not a ref of OPvar, whereas     */
            /* ((OPbit OPvar) = e) is a ref of OPvar, and (OPvar op= e) is */
            /* a ref of OPvar, etc.                                     */
            f = refs(v,n->E2,nstop);
            if (!f)
            {   if (op == OPeq)
                {       if (n->E1->Eoper != OPvar)
                                f = refs(v,n->E1->E1,nstop);
                }
                else
                        f = refs(v,n->E1,nstop);
            }
        }
        else
                f = refs(v,n->E1,nstop) || refs(v,n->E2,nstop);
  }

  if (n == nstop)
        refstop = 0;
  else if (n->Eoper == OPvar)           /* if variable reference        */
        return v == n->EV.sp.Vsym;
  else if (op == OPasm)                 /* everything is referenced     */
        return TRUE;
  return f;
}

/*************************
 * Move LIs to preheader.
 * Conditions to be satisfied for code motion are:
 *      1) All exit blocks are dominated (TRUE before this is called).
 *                      -- OR --
 *      2) Variable assigned by a statement is not live on entering
 *         any successor outside the loop of any exit block of the
 *         loop.
 *
 *      3) Cannot move assignment to variable if there are any other
 *         assignments to that variable within the loop (TRUE or
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

STATIC void movelis(elem *n,block *b,loop *l,int *pdomexit)
{ unsigned i,j,op;
  vec_t tmp;
  elem *ne,*t,*n2;
  list_t nl;
  symbol *v;
  tym_t ty;

Lnextlis:
  //if (isLI(n)) { printf("movelis("); WReqn(n); printf(")\n"); }
  assert(l && n);
  elem_debug(n);
  op = n->Eoper;
  switch (op)
  {
        case OPvar:
        case OPconst:
        case OPrelconst:
            goto Lret;

        case OPandand:
        case OPoror:
        case OPcond:
        {   int domexit;

            movelis(n->E1,b,l,pdomexit);        // always executed
            domexit = *pdomexit & ~1;   // sometimes executed
            movelis(n->E2,b,l,&domexit);
            *pdomexit |= domexit & 2;
            goto Lret;
        }

        case OPeq:
            // Do loop invariant assignments
            if (isLI(n) && n->E1->Eoper == OPvar)
            {   v = n->E1->EV.sp.Vsym;          // variable index number

                if (!(v->Sflags & SFLunambig)) goto L3;         // case 6

                // If case 4 is not satisfied, return

                // Function parameters have an implied definition prior to the
                // first block of the function. Unfortunately, the rd vector
                // does not take this into account. Therefore, we assume the
                // worst and reject assignments to function parameters.
                if (v->Sclass == SCparameter || v->Sclass == SCregpar ||
                    v->Sclass == SCfastpar || v->Sclass == SCshadowreg)
                        goto L3;

                if (el_sideeffect(n->E2)) goto L3;              // case 5

                // If case 1 or case 2 is not satisfied, return

                if (!(*pdomexit & 1))                   // if not case 1
                {
                    foreach (i,dfotop,l->Lexit)         // for each exit block
                    {   list_t bl;

                        for (bl = dfo[i]->Bsucc; bl; bl = list_next(bl))
                        {   block *s;           // successor to exit block

                            s = list_block(bl);
                            if (!vec_testbit(s->Bdfoidx,l->Lloop) &&
                                (!symbol_isintab(v) ||
                                 vec_testbit(v->Ssymnum,s->Binlv))) // if v is live on exit
                                    goto L3;
                        }
                    }
                }

                tmp = vec_calloc(deftop);
                foreach (i,dfotop,l->Lloop)     // for each block in loop
                {
                        if (dfo[i] == b)        // except this one
                                continue;

                        //<if there are any RDs of v in Binrd other than n>
                        //      <if there are any refs of v in that block>
                        //              return;

                        //filterrd(tmp,dfo[i]->Binrd,v);
                        listrds(dfo[i]->Binrd,n->E1,tmp);
                        foreach (j,deftop,tmp)  // for each RD of v in Binrd
                        {   if (defnod[j].DNelem == n)
                                        continue;
                                refstop = -1;
                                if (dfo[i]->Belem &&
                                    refs(v,dfo[i]->Belem,(elem *)NULL)) //if refs of v
                                {   vec_free(tmp);
                                        goto L3;
                                }
                                break;
                        }
                } // foreach

                // <if there are any RDs of v in b->Binrd other than n>
                //      <if there are any references to v before the
                //       assignment to v>
                //              <can't move this assignment>

                //filterrd(tmp,b->Binrd,v);
                listrds(b->Binrd,n->E1,tmp);
                foreach (j,deftop,tmp)          // for each RD of v in Binrd
                {   if (defnod[j].DNelem == n)
                            continue;
                        refstop = -1;
                        if (b->Belem && refs(v,b->Belem,n))
                        {   vec_free(tmp);
                            goto L3;            // can't move it
                        }
                        break;                  // avoid redundant looping
                }
                vec_free(tmp);

                // We have an LI assignment, n.
                // Check to see if the rvalue is already in the preheader.
                for (nl = l->Llis; nl; nl = list_next(nl))
                {
                    if (el_match(n->E2,list_elem(nl)->E2))
                    {
                        el_free(n->E2);
                        n->E2 = el_calloc();
                        el_copy(n->E2,list_elem(nl)->E1);
                        cmes("LI assignment rvalue was replaced\n");
                        doflow = TRUE;
                        changes++;
                        break;
                    }
                }

                // move assignment elem to preheader
                cmes("Moved LI assignment ");
        #ifdef DEBUG
                if (debugc)
                {   WReqn(n);
                        dbg_printf(";\n");
                }
        #endif
                changes++;
                doflow = TRUE;                  // redo flow analysis
                ne = el_calloc();
                el_copy(ne,n);                  // create assignment elem
                assert(l->Lpreheader);          // make sure there is one
                appendelem(ne,&(l->Lpreheader->Belem)); // append ne to preheader
                list_prepend(&l->Llis,ne);

                el_copy(n,ne->E1);      // replace n with just a reference to v
                goto Lret;
            } // if
            break;

        case OPcall:
        case OPucall:
            *pdomexit |= 2;
            break;
  }

L3:
  // Do leaves of non-LI expressions, leaves of = elems that didn't
  // meet the invariant assignment removal criteria, and don't do leaves
  if (OTleaf(op))
        goto Lret;
  if (!isLI(n) || op == OPeq || op == OPcomma || OTrel(op) || op == OPnot ||
      // These are usually addressing modes, so moving them is a net loss
      (I32 && op == OPshl && n->E2->Eoper == OPconst && el_tolong(n->E2) <= 3ull)
     )
  {
        if (OTassign(op))
        {       elem *n1 = n->E1;
                elem *n11;

                if (OTbinary(op))
                    movelis(n->E2,b,l,pdomexit);

                // Do lvalue only if it is an expression
                if (n1->Eoper == OPvar)
                    goto Lret;
                n11 = n1->E1;
                if (OTbinary(n1->Eoper))
                {
                    movelis(n11,b,l,pdomexit);
                    n = n1->E2;
                }
                // If *(x + c), just make x the LI, not the (x + c).
                // The +c comes free with the addressing mode.
                else if (n1->Eoper == OPind &&
                        isLI(n11) &&
                        n11->Eoper == OPadd &&
                        n11->E2->Eoper == OPconst
                        )
                {
                    n = n11->E1;
                }
                else
                    n = n11;
                movelis(n,b,l,pdomexit);
                if (b->Btry || !(n1->Eoper == OPvar && symbol_isintab(n1->EV.sp.Vsym)))
                {
                    //printf("assign to global => domexit |= 2\n");
                    *pdomexit |= 2;
                }
        }
        else if (OTunary(op))
        {   elem *e1 = n->E1;

            // If *(x + c), just make x the LI, not the (x + c).
            // The +c comes free with the addressing mode.
            if (op == OPind &&
                isLI(e1) &&
                e1->Eoper == OPadd &&
                e1->E2->Eoper == OPconst
               )
            {
                n = e1->E1;
            }
            else
                n = e1;
        }
        else if (OTbinary(op))
        {       movelis(n->E1,b,l,pdomexit);
                n = n->E2;
        }
        goto Lnextlis;
  }

  if (el_sideeffect(n))
        goto Lret;

#if 0
    printf("*pdomexit = %d\n",*pdomexit);
    if (*pdomexit & 2)
    {
        // If any indirections, can't LI it

        // If this operand has already been indirected, we can let
        // it pass.
        Symbol *s;

        printf("looking at:\n");
        elem_print(n);
        s = el_basesym(n->E1);
        if (s)
        {
            for (nl = l->Llis; nl; nl = list_next(nl))
            {   elem *el;
                tym_t ty2;

                el = list_elem(nl);
                el = el->E2;
                elem_print(el);
                if (el->Eoper == OPind && el_basesym(el->E1) == s)
                {
                    printf("  pass!\n");
                    goto Lpass;
                }
            }
        }
        printf("  skip!\n");
        goto Lret;

    Lpass:
        ;
    }
#endif

  // Move the LI expression to the preheader
  cmes("Moved LI expression ");
#ifdef DEBUG
  if (debugc)
  {     WReqn(n);
        dbg_printf(";\n");
  }
#endif

  // See if it's already been moved
  ty = n->Ety;
  for (nl = l->Llis; nl; nl = list_next(nl))
  {     elem *el;
        tym_t ty2;

        el = list_elem(nl);
        //printf("existing LI: "); WReqn(el); printf("\n");
        ty2 = el->E2->Ety;
        if (tysize(ty) == tysize(ty2))
        {   el->E2->Ety = ty;
            if (el_match(n,el->E2))
            {
                el->E2->Ety = ty2;
                if (!OTleaf(n->Eoper))
                {       el_free(n->E1);
                        if (OTbinary(n->Eoper))
                                el_free(n->E2);
                }
                el_copy(n,el->E1);      // make copy of temp
                n->Ety = ty;
#ifdef DEBUG
                if (debugc)
                {   dbg_printf("Already moved: LI expression replaced with ");
                    WReqn(n);
                    dbg_printf("\nPreheader %d expression %p ",
                    l->Lpreheader->Bdfoidx,l->Lpreheader->Belem);
                    WReqn(l->Lpreheader->Belem);
                    dbg_printf("\n");
                }
#endif
                changes++;
                doflow = TRUE;                  // redo flow analysis
                goto Lret;
            }
            el->E2->Ety = ty2;
        }
  }

  if (!(*pdomexit & 1))                         // if only sometimes executed
  {     cmes(" doesn't dominate exit\n");
        goto Lret;                              // don't move LI
  }

  if (tyaggregate(n->Ety))
        goto Lret;

  changes++;
  doflow = TRUE;                                // redo flow analysis

  t = el_alloctmp(n->Ety);                      /* allocate temporary t */
#if DEBUG
    cmes2("movelis() introduced new variable '%s' of type ",t->EV.sp.Vsym->Sident);
    if (debugc) WRTYxx(t->Ety);
    cmes("\n");
#endif
  n2 = el_calloc();
  el_copy(n2,n);                                /* create copy n2 of n  */
  ne = el_bin(OPeq,t->Ety,t,n2);                /* create elem t=n2     */
  assert(l->Lpreheader);                        /* make sure there is one */
  appendelem(ne,&(l->Lpreheader->Belem));       /* append ne to preheader */
#ifdef DEBUG
  if (debugc)
  {     dbg_printf("Preheader %d expression %p\n\t",
        l->Lpreheader->Bdfoidx,l->Lpreheader->Belem);
        WReqn(l->Lpreheader->Belem);
        dbg_printf("\nLI expression replaced with "); WReqn(t);
        dbg_printf("\n");
  }
#endif
  el_copy(n,t);                                 /* replace this elem with t */

  // Remember LI expression in elem list
  list_prepend(&l->Llis,ne);

Lret:
    ;
}

/***************************
 * Append elem to existing elem using an OPcomma elem.
 * Input:
 *      n       elem to append
 *      *pn     elem to append to
 */

STATIC void appendelem(elem *n,elem **pn)
{
  assert(n && pn);
  if (*pn)                                      /* if this elem exists  */
  {     while ((*pn)->Eoper == OPcomma)         /* while we see OPcomma elems */
        {   (*pn)->Ety = n->Ety;
            pn = &((*pn)->E2);                  /* cruise down right side */
        }
        *pn = el_bin(OPcomma,n->Ety,*pn,n);
  }
  else
        *pn = n;                                /* else create a elem   */
}

/************** LOOP INDUCTION VARIABLES **********************/

/***************************
 * Allocate famlist.
 */

famlist *famlist::freelist = NULL;

famlist *famlist::mycalloc()
{   famlist *fl;

    if (freelist)
    {
        fl = freelist;
        freelist = fl->FLnext;
        memset(fl,0,sizeof(famlist));
    }
    else
        fl = (famlist *) mem_calloc(sizeof(famlist));
    return fl;
}

/***************************
 * Allocate Iv.
 */

Iv *Iv::freelist = NULL;

Iv *Iv::mycalloc()
{   Iv *iv;

    if (freelist)
    {
        iv = freelist;
        freelist = iv->IVnext;
        memset(iv,0,sizeof(Iv));
    }
    else
        iv = (Iv *) mem_calloc(sizeof(Iv));
    return iv;
}

/*********************
 * Free iv list.
 */

STATIC void freeivlist(Iv *biv)
{ Iv *bivnext;

  while (biv)
  {     famlist *fl,*fln;

        for (fl = biv->IVfamily; fl; fl = fln)
        {       el_free(fl->c1);
                el_free(fl->c2);
                fln = fl->FLnext;

                fl->FLnext = famlist::freelist;
                famlist::freelist = fl;
        }
        bivnext = biv->IVnext;

        biv->IVnext = Iv::freelist;
        Iv::freelist = biv;

        biv = bivnext;
  }
}

/****************************
 * Create a new famlist entry.
 */

STATIC famlist * newfamlist(tym_t ty)
{       famlist *fl;
        union eve c;

        memset(&c,0,sizeof(c));
        fl = famlist::mycalloc();
        fl->FLty = ty;
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

#if TARGET_SEGMENTED
            case TYsptr:
            case TYcptr:
            case TYfptr:
            case TYvptr:
#endif
            case TYnptr:
            case TYnullptr:
                ty = TYint;
                if (I64)
                    ty = TYllong;
                /* FALL-THROUGH */
            case TYint:
            case TYuint:
                c.Vint = 1;
                break;
#if TARGET_SEGMENTED
            case TYhptr:
                ty = TYlong;
#endif
            case TYlong:
            case TYulong:
            case TYdchar:
            default:
                c.Vlong = 1;
                break;
        }
        fl->c1 = el_const(ty,&c);               /* c1 = 1               */
        c.Vldouble = 0;
        if (typtr(ty))
        {
            ty = TYint;
#if TARGET_SEGMENTED
            if (tybasic(ty) == TYhptr)
                ty = TYlong;
#endif
            if (I64)
                ty = TYllong;
        }
        fl->c2 = el_const(ty,&c);               /* c2 = 0               */
        return fl;
}

/***************************
 * Remove induction variables from loop l.
 * Loop invariant removal should have been done just previously.
 */

STATIC void loopiv(loop *l)
{
  cmes2("loopiv(%p)\n",l);
  assert(l->Livlist == NULL && l->Lopeqlist == NULL);
  elimspec(l);
  if (doflow)
  {     flowrd();               /* compute reaching defs                */
        flowlv();               /* compute live variables               */
        flowae();               // compute available expressions
        doflow = FALSE;
  }
  findbasivs(l);                /* find basic induction variables       */
  findopeqs(l);                 // find op= variables
  findivfams(l);                /* find IV families                     */
  elimfrivivs(l);               /* eliminate less useful family IVs     */
  intronvars(l);                /* introduce new variables              */
  elimbasivs(l);                /* eliminate basic IVs                  */
  if (!addblk)                  // adding a block changes the Binlv
      elimopeqs(l);             // eliminate op= variables

  freeivlist(l->Livlist);       // free up IV list
  l->Livlist = NULL;
  freeivlist(l->Lopeqlist);     // free up list
  l->Lopeqlist = NULL;

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
 *      defnod[] loaded with all the definition elems of the loop
 */

STATIC void findbasivs(loop *l)
{ vec_t poss,notposs;
  elem *n;
  unsigned i,j;
  bool ambdone;

  assert(l);
  ambdone = FALSE;
  poss = vec_calloc(globsym.top);
  notposs = vec_calloc(globsym.top);            /* vector of all variables      */
                                        /* (initially all unmarked)     */

  /* for each def in defnod[] that is within loop l     */

  for (i = 0; i < deftop; i++)
  {     if (!vec_testbit(defnod[i].DNblock->Bdfoidx,l->Lloop))
                continue;               /* def is not in the loop       */

        n = defnod[i].DNelem;
        elem_debug(n);
        if (OTassign(n->Eoper) && n->E1->Eoper == OPvar)
        {   symbol *s;                  /* if unambiguous def           */

            s = n->E1->EV.sp.Vsym;
            if (symbol_isintab(s))
            {
                SYMIDX v;

                v = n->E1->EV.sp.Vsym->Ssymnum;
                if ((n->Eoper == OPaddass || n->Eoper == OPminass ||
                     n->Eoper == OPpostinc || n->Eoper == OPpostdec) &&
                        (cnst(n->E2) || /* if x += c or x -= c          */
                         n->E2->Eoper == OPvar && isLI(n->E2)))
                {       if (vec_testbit(v,poss))
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
        {       /* mark any vars that could be affected by              */
                /* this def as not possible                             */

                if (!ambdone)           /* avoid redundant loops        */
                {       for (j = 0; j < globsym.top; j++)
                        {       if (!(globsym.tab[j]->Sflags & SFLunambig))
                                        vec_setbit(j,notposs);
                        }
                        ambdone = TRUE;
                }
        }
  }
#if 0
  dbg_printf("poss    "); vec_println(poss);
  dbg_printf("notposs "); vec_println(notposs);
#endif
  vec_subass(poss,notposs);             /* poss = poss - notposs        */

  /* create list of IVs */
  foreach (i,globsym.top,poss)          /* for each basic IV            */
  {     Iv *biv;
        symbol *s;

        /* Skip if we don't want it to be a basic IV (see funcprev())   */
        s = globsym.tab[i];
        assert(symbol_isintab(s));
        if (s->Sflags & SFLnotbasiciv)
                continue;

        // Do not use aggregates as basic IVs. This is because the other loop
        // code doesn't check offsets into symbols, (assuming everything
        // is at offset 0). We could perhaps amend this by allowing basic IVs
        // if the struct consists of only one data member.
        if (tyaggregate(s->ty()))
                continue;

        // Do not use complex types as basic IVs, as the code gen isn't up to it
        if (tycomplex(s->ty()))
                continue;

        biv = Iv::mycalloc();
        biv->IVnext = l->Livlist;
        l->Livlist = biv;               // link into list of IVs

        biv->IVbasic = s;               // symbol of basic IV

        cmes3("Symbol '%s' (%d) is a basic IV, ",s->Sident
                ? (char *)s->Sident : "",i);

        /* We have the sym idx of the basic IV. We need to find         */
        /* the parent of the increment elem for it.                     */

        /* First find the defnod[]      */
        for (j = 0; j < deftop; j++)
        {       /* If defnod is a def of i and it is in the loop        */
                if (defnod[j].DNelem->E1 &&     /* OPasm are def nodes  */
                    defnod[j].DNelem->E1->EV.sp.Vsym == s &&
                    vec_testbit(defnod[j].DNblock->Bdfoidx,l->Lloop))
                        goto L1;
        }
        assert(0);                      /* should have found it         */
        /* NOTREACHED */

    L1: biv->IVincr = el_parent(defnod[j].DNelem,&(defnod[j].DNblock->Belem));
        assert(s == (*biv->IVincr)->E1->EV.sp.Vsym);
#ifdef DEBUG
        if (debugc)
        {   dbg_printf("Increment elem is: "); WReqn(*biv->IVincr);     dbg_printf("\n"); }
#endif
  }

  vec_free(poss);
  vec_free(notposs);
}

/*************************************
 * Find op= elems of loop l.
 * Analogous to findbasivs().
 * Used to eliminate useless loop code normally found in benchmark programs.
 * Input:
 *      defnod[] loaded with all the definition elems of the loop
 */

STATIC void findopeqs(loop *l)
{   vec_t poss,notposs;
    elem *n;
    unsigned i,j;
    bool ambdone;

    assert(l);
    ambdone = FALSE;
    poss = vec_calloc(globsym.top);
    notposs = vec_calloc(globsym.top);  // vector of all variables
                                        // (initially all unmarked)

    // for each def in defnod[] that is within loop l

    for (i = 0; i < deftop; i++)
    {   if (!vec_testbit(defnod[i].DNblock->Bdfoidx,l->Lloop))
                continue;               // def is not in the loop

        n = defnod[i].DNelem;
        elem_debug(n);
        if (OTopeq(n->Eoper) && n->E1->Eoper == OPvar)
        {   symbol *s;                  // if unambiguous def

            s = n->E1->EV.sp.Vsym;
            if (symbol_isintab(s))
            {
                SYMIDX v;

                v = n->E1->EV.sp.Vsym->Ssymnum;
                {       if (vec_testbit(v,poss))
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
        {       // mark any vars that could be affected by
                // this def as not possible

                if (!ambdone)           // avoid redundant loops
                {       for (j = 0; j < globsym.top; j++)
                        {       if (!(globsym.tab[j]->Sflags & SFLunambig))
                                        vec_setbit(j,notposs);
                        }
                        ambdone = TRUE;
                }
        }
    }

    // Don't use symbols already in Livlist
    for (Iv *iv = l->Livlist; iv; iv = iv->IVnext)
    {   symbol *s;

        s = iv->IVbasic;
        vec_setbit(s->Ssymnum,notposs);
    }


#if 0
    dbg_printf("poss    "); vec_println(poss);
    dbg_printf("notposs "); vec_println(notposs);
#endif
    vec_subass(poss,notposs);           // poss = poss - notposs

    // create list of IVs
    foreach (i,globsym.top,poss)        // for each opeq IV
    {   Iv *biv;
        symbol *s;

        s = globsym.tab[i];
        assert(symbol_isintab(s));

        // Do not use aggregates as basic IVs. This is because the other loop
        // code doesn't check offsets into symbols, (assuming everything
        // is at offset 0). We could perhaps amend this by allowing basic IVs
        // if the struct consists of only one data member.
        if (tyaggregate(s->ty()))
                continue;

        biv = Iv::mycalloc();
        biv->IVnext = l->Lopeqlist;
        l->Lopeqlist = biv;             // link into list of IVs

        biv->IVbasic = s;               // symbol of basic IV

        cmes3("Symbol '%s' (%d) is an opeq IV, ",s->Sident
                ? (char *)s->Sident : "",i);

        // We have the sym idx of the basic IV. We need to find
        // the parent of the increment elem for it.

        // First find the defnod[]
        for (j = 0; j < deftop; j++)
        {       // If defnod is a def of i and it is in the loop
                if (defnod[j].DNelem->E1 &&     // OPasm are def nodes
                    defnod[j].DNelem->E1->EV.sp.Vsym == s &&
                    vec_testbit(defnod[j].DNblock->Bdfoidx,l->Lloop))
                        goto L1;
        }
        assert(0);                      // should have found it
        // NOTREACHED

    L1: biv->IVincr = el_parent(defnod[j].DNelem,&(defnod[j].DNblock->Belem));
        assert(s == (*biv->IVincr)->E1->EV.sp.Vsym);
#ifdef DEBUG
        if (debugc)
        {   dbg_printf("Opeq elem is: "); WReqn(*biv->IVincr);  dbg_printf("\n"); }
#endif
    Lcont:
        ;
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

STATIC void findivfams(loop *l)
{ Iv *biv;
  unsigned i;
  famlist *fl;

  cmes2("findivfams(%p)\n",l);
  for (biv = l->Livlist; biv; biv = biv->IVnext)
  {     foreach (i,dfotop,l->Lloop)     /* for each block in loop       */
            if (dfo[i]->Belem)
                ivfamelems(biv,&(dfo[i]->Belem));
        /* Fold all the constant expressions in c1 and c2.      */
        for (fl = biv->IVfamily; fl; fl = fl->FLnext)
        {       fl->c1 = doptelem(fl->c1,GOALvalue | GOALagain);
                fl->c2 = doptelem(fl->c2,GOALvalue | GOALagain);
        }
  }
}

/*************************
 * Tree walking support routine for findivfams().
 *      biv =   basic induction variable pointer
 *      pn      pointer to elem
 */

STATIC void ivfamelems(Iv *biv,elem **pn)
{ unsigned op;
  tym_t ty,c2ty;
  famlist *f;
  elem *n,*n1,*n2;

  assert(pn);
  n = *pn;
  assert(biv && n);
  op = n->Eoper;
  if (OTunary(op))
  {     ivfamelems(biv,&n->E1);
        n1 = n->E1;
        n2 = NULL;
  }
  else if (OTbinary(op))
  {     ivfamelems(biv,&n->E1);
        ivfamelems(biv,&n->E2); /* LTOR or RTOL order is unimportant */
        n1 = n->E1;
        n2 = n->E2;
  }
  else                                  /* else leaf elem               */
        return;                         /* which can't be in the family */

  if (tycomplex(n->Ety))
        return;

  if (op == OPmul || op == OPadd || op == OPmin ||
        op == OPneg || op == OPshl)
  {     /* Note that we are wimping out and not considering             */
        /* LI variables as part of c1 and c2, but only constants.       */

        ty = n->Ety;

        /* Since trees are canonicalized, basic induction variables     */
        /* will only appear on the left.                                */

        /* Improvement:                                                 */
        /* We wish to pick up the cases (biv + li), (biv - li) and      */
        /* (li + biv). OPmul and LS with bivs are out, since if we      */
        /* try to eliminate the biv, and the loop test is a >, >=,      */
        /* <, <=, we have a problem since we don't know if the li       */
        /* is negative. (Would have to call swaprel() on it.)           */

        /* If we have (li + var), swap the leaves.                      */
        if (op == OPadd && isLI(n1) && n1->Eoper == OPvar && n2->Eoper == OPvar)
        {       n->E1 = n2;
                n2 = n->E2 = n1;
                n1 = n->E1;
        }

#if TARGET_SEGMENTED
        // Get rid of case where we painted a far pointer to a long
        if (op == OPadd || op == OPmin)
        {   int sz;

            sz = tysize(ty);
            if (sz == tysize[TYfptr] && !tyfv(ty) &&
                (sz != tysize(n1->Ety) || sz != tysize(n2->Ety)))
                return;
        }
#endif

        /* Look for function of basic IV (-biv or biv op const)         */
        if (n1->Eoper == OPvar && n1->EV.sp.Vsym == biv->IVbasic)
        {       if (op == OPneg)
                {       famlist *fl;

                        cmes2("found (-biv), elem %p\n",n);
                        fl = newfamlist(ty);
                        fl->FLivty = n1->Ety;
                        fl->FLpelem = pn;
                        fl->FLnext = biv->IVfamily;
                        biv->IVfamily = fl;
                        fl->c1 = el_una(op,ty,fl->c1); /* c1 = -1       */
                }
                else if (n2->Eoper == OPconst ||
                         isLI(n2) && (op == OPadd || op == OPmin))
                {       famlist *fl;

#ifdef DEBUG
                        if (debugc)
                        {       dbg_printf("found (biv op const), elem (");
                                WReqn(n);
                                dbg_printf(");\n");
                                dbg_printf("Types: n1="); WRTYxx(n1->Ety);
                                dbg_printf(" ty="); WRTYxx(ty);
                                dbg_printf(" n2="); WRTYxx(n2->Ety);
                                dbg_printf("\n");
                        }
#endif
                        fl = newfamlist(ty);
                        fl->FLivty = n1->Ety;
                        fl->FLpelem = pn;
                        fl->FLnext = biv->IVfamily;
                        biv->IVfamily = fl;
                        switch (op)
                        { case OPadd:           /* c2 = right           */
                                c2ty = n2->Ety;
                                if (typtr(fl->c2->Ety))
                                        c2ty = fl->c2->Ety;
                                goto L1;
                          case OPmin:           /* c2 = -right          */
                                c2ty = fl->c2->Ety;
                                /* Check for subtracting two pointers */
                                if (typtr(c2ty) && typtr(n2->Ety))
                                {
#if TARGET_SEGMENTED
                                    if (tybasic(c2ty) == TYhptr)
                                        c2ty = TYlong;
                                    else
#endif
                                        c2ty = I64 ? TYllong : TYint;
                                }
                          L1:
                                fl->c2 = el_bin(op,c2ty,fl->c2,el_copytree(n2));
                                break;
                          case OPmul:           /* c1 = right           */
                          case OPshl:           /* c1 = 1 << right      */
                                fl->c1 = el_bin(op,ty,fl->c1,el_copytree(n2));
                                break;
                          default:
                                assert(0);
                        }
                }
        }

        /* Look for function of existing IV                             */

        for (f = biv->IVfamily; f; f = f->FLnext)
        {       if (*f->FLpelem != n1)          /* not it               */
                        continue;

                /* Look for (f op constant)     */
                if (op == OPneg)
                {
                        cmes2("found (-f), elem %p\n",n);
                        /* c1 = -c1; c2 = -c2; */
                        f->c1 = el_una(OPneg,ty,f->c1);
                        f->c2 = el_una(OPneg,ty,f->c2);
                        f->FLty = ty;
                        f->FLpelem = pn;        /* replace with new IV  */

                }
                else if (n2->Eoper == OPconst ||
                         isLI(n2) && (op == OPadd || op == OPmin))
                {
#ifdef DEBUG
                        if (debugc)
                        {       dbg_printf("found (f op const), elem (");
                                WReqn(n);
                                assert(*pn == n);
                                dbg_printf(");\n");
                                elem_print(n);
                        }
#endif
                        switch (op)
                        {   case OPmul:
                            case OPshl:
                                f->c1 = el_bin(op,ty,f->c1,el_copytree(n2));
                                break;
                            case OPadd:
                            case OPmin:
                                break;
                            default:
                                assert(0);
                        }
                        f->c2 = el_bin(op,ty,f->c2,el_copytree(n2));
                        f->FLty = ty;
                        f->FLpelem = pn;        /* replace with new IV  */
                } /* else if */
        } /* for */
  } /* if */
}

/*********************************
 * Eliminate frivolous family ivs, that is,
 * if we can't eliminate the BIV, then eliminate family ivs that
 * differ from it only by a constant.
 */

STATIC void elimfrivivs(loop *l)
{   Iv *biv;

    for (biv = l->Livlist; biv; biv = biv->IVnext)
    {   int nfams;
        famlist *fl;
        int nrefs;

        cmes("elimfrivivs()\n");
        /* Compute number of family ivs for biv */
        nfams = 0;
        for (fl = biv->IVfamily; fl; fl = fl->FLnext)
                nfams++;
        cmes2("nfams = %d\n",nfams);

        /* Compute number of references to biv  */
        if (onlyref(biv->IVbasic,l,*biv->IVincr,&nrefs))
                nrefs--;
        cmes2("nrefs = %d\n",nrefs);
        assert(nrefs + 1 >= nfams);
        if (nrefs > nfams ||            // if we won't eliminate the biv
            (!I16 && nrefs == nfams))
        {   /* Eliminate any family ivs that only differ by a constant  */
            /* from biv                                                 */
            for (fl = biv->IVfamily; fl; fl = fl->FLnext)
            {   elem *ec1 = fl->c1;
                targ_llong c;

                if (elemisone(ec1) ||
                    // Eliminate fl's that can be represented by
                    // an addressing mode
                    (!I16 && ec1->Eoper == OPconst && tyintegral(ec1->Ety) &&
                     ((c = el_tolong(ec1)) == 2 || c == 4 || c == 8)
                    )
                   )
                {       fl->FLtemp = FLELIM;
#ifdef DEBUG
                        if (debugc)
                        {       dbg_printf("Eliminating frivolous IV ");
                                WReqn(*fl->FLpelem);
                                dbg_printf("\n");
                        }
#endif
                }
            }
        }
    }
}


/******************************
 * Introduce new variables.
 */

STATIC void intronvars(loop *l)
{
    famlist *fl;
    Iv *biv;
    elem *T, *ne, *t2, *C2, *cmul;
    tym_t ty,tyr;

    cmes2("intronvars(%p)\n",l);
    for (biv = l->Livlist; biv; biv = biv->IVnext)      // for each basic IV
    {   elem *bivinc = *biv->IVincr;   /* ptr to increment elem */

        for (fl = biv->IVfamily; fl; fl = fl->FLnext)
        {                               /* for each IV in family of biv  */
            if (fl->FLtemp == FLELIM)   /* if already eliminated         */
                continue;

            /* If induction variable can be written as a simple function */
            /* of a previous induction variable, skip it.                */
            if (funcprev(biv,fl))
                continue;

            ty = fl->FLty;
            T = el_alloctmp(ty);        /* allocate temporary T          */
            fl->FLtemp = T->EV.sp.Vsym;
#if DEBUG
            cmes2("intronvars() introduced new variable '%s' of type ",T->EV.sp.Vsym->Sident);
            if (debugc) WRTYxx(ty);
            cmes("\n");
#endif

            /* append elem T=biv*C1+C2 to preheader */
            /* ne = biv*C1      */
            tyr = fl->FLivty;                   /* type of biv              */
            ne = el_var(biv->IVbasic);
            ne->Ety = tyr;
            if (!elemisone(fl->c1))             /* don't multiply ptrs by 1 */
                ne = el_bin(OPmul,tyr,ne,el_copytree(fl->c1));
            if (tyfv(tyr) && tysize(ty) == SHORTSIZE)
                ne = el_una(OP32_16,ty,ne);
            C2 = el_copytree(fl->c2);
            t2 = el_bin(OPadd,ty,ne,C2);        /* t2 = ne + C2         */
            ne = el_bin(OPeq,ty,el_copytree(T),t2);
            appendelem(ne, &(l->Lpreheader->Belem));

            /* prefix T+=C1*C to elem biv+=C                            */
            /* Must prefix in case the value of the expression (biv+=C) */
            /* is used by somebody up the tree.                         */
            cmul = el_bin(OPmul,fl->c1->Ety,el_copytree(fl->c1),
                                 el_copytree(bivinc->E2));
            t2 = el_bin(bivinc->Eoper,ty,el_copytree(T),cmul);
            t2 = doptelem(t2,GOALvalue | GOALagain);
            *biv->IVincr = el_bin(OPcomma,bivinc->Ety,t2,bivinc);
            biv->IVincr = &((*biv->IVincr)->E2);
#ifdef DEBUG
            if (debugc)
            {   dbg_printf("Replacing elem (");
                WReqn(*fl->FLpelem);
                dbg_printf(") with '%s'\n",T->EV.sp.Vsym->Sident);
                dbg_printf("The init elem is (");
                WReqn(ne);
                dbg_printf(");\nThe increment elem is (");
                WReqn(t2);
                dbg_printf(")\n");
            }
#endif
            el_free(*fl->FLpelem);
            *fl->FLpelem = T;           /* replace elem n with ref to T  */
            doflow = TRUE;              /* redo flow analysis           */
            changes++;
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
 *      FALSE           Caller should create a new induction variable.
 *      TRUE            *FLpelem is replaced with function of a previous
 *                      induction variable. FLtemp is set to FLELIM to
 *                      indicate this.
 */

STATIC bool funcprev(Iv *biv,famlist *fl)
{   tym_t tymin;
    int sz;
    famlist *fls;
    elem *e1,*e2,*flse1;

#ifdef DEBUG
    if (debugc)
        dbg_printf("funcprev\n");
#endif
    for (fls = biv->IVfamily; fls != fl; fls = fls->FLnext)
    {   assert(fls);                    /* fl must be in list           */
        if (fls->FLtemp == FLELIM)      /* no iv we can use here        */
                continue;

        /* The multipliers must match   */
        if (!el_match(fls->c1,fl->c1))
                continue;

        /* If the c2's match also, we got it easy */
        if (el_match(fls->c2,fl->c2))
        {
                if (tysize(fl->FLty) > tysize(fls->FLtemp->ty()))
                    continue;           /* can't increase size of var   */
                flse1 = el_var(fls->FLtemp);
                flse1->Ety = fl->FLty;
                goto L2;
        }

        /* The difference is only in the addition. Therefore, replace
           *fl->FLpelem with:
                case 1:         (fl->c2 + (fls->FLtemp - fls->c2))
                case 2:         (fls->FLtemp + (fl->c2 - fls->c2))
         */
        e1 = fl->c2;
        /* Subtracting relocatables usually generates slow code for     */
        /* linkers that can't handle arithmetic on relocatables.        */
        if (typtr(fls->c2->Ety))
        {   if (fls->c2->Eoper == OPrelconst &&
                !(fl->c2->Eoper == OPrelconst &&
                  fl->c2->EV.sp.Vsym == fls->c2->EV.sp.Vsym)
               )
                continue;
        }
        flse1 = el_var(fls->FLtemp);
        e2 = flse1;                             /* assume case 1        */
        tymin = e2->Ety;
        if (typtr(fls->c2->Ety))
        {       if (!typtr(tymin))
                {   if (typtr(e1->Ety))
                    {   e1 = e2;
                        e2 = fl->c2;            /* case 2               */
                    }
                    else                        /* can't subtract fptr  */
                        goto L1;
                }
#if TARGET_SEGMENTED
                if (tybasic(fls->c2->Ety) == TYhptr)
                    tymin = TYlong;
                else
#endif
                    tymin = I64 ? TYllong : TYint;         /* type of (ptr - ptr) */
        }

#if TARGET_SEGMENTED
        /* If e1 and fls->c2 are fptrs, and are not from the same       */
        /* segment, we cannot subtract them.                            */
        if (tyfv(e1->Ety) && tyfv(fls->c2->Ety))
        {   if (e1->Eoper != OPrelconst || fls->c2->Eoper != OPrelconst)
                goto L1;                /* assume expressions have diff segs */
            if (e1->EV.sp.Vsym->Sclass != fls->c2->EV.sp.Vsym->Sclass)
                { L1:
                    el_free(flse1);
                    continue;
                }
        }
#else
L1:
        el_free(flse1);
        continue;

#endif
        /* Some more type checking...   */
        sz = tysize(fl->FLty);
        if (sz != tysize(e1->Ety) &&
            sz != tysize(tymin))
            goto L1;

        /* Do some type checking (can't add pointers and get a pointer!) */
        //if (typtr(fl->FLty) && typtr(e1->Ety) && typtr(tymin))
            //goto L1;
        /* Construct (e1 + (e2 - fls->c2))      */
        flse1 = el_bin(OPadd,fl->FLty,
                            e1,
                            el_bin(OPmin,tymin,
                                    e2,
                                    el_copytree(fls->c2)));
        if (sz < tysize(tymin) && sz == tysize(e1->Ety))
        {
#if TARGET_SEGMENTED
            flse1->E2 = el_una(OPoffset,fl->FLty,flse1->E2);
#else
            assert(0);
#endif
        }

        flse1 = doptelem(flse1,GOALvalue | GOALagain);
        fl->c2 = NULL;
    L2:
#ifdef DEBUG
        if (debugc)
        {       dbg_printf("Replacing ");
                WReqn(*fl->FLpelem);
                dbg_printf(" with ");
                WReqn(flse1);
                dbg_printf("\n");
        }
#endif
        el_free(*fl->FLpelem);
        *fl->FLpelem = flse1;

        /* Fix the iv so when we do loops again, we won't create        */
        /* yet another iv, which is just what funcprev() is supposed    */
        /* to prevent.                                                  */
        fls->FLtemp->Sflags |= SFLnotbasiciv;

        fl->FLtemp = FLELIM;            /* mark iv as being gone        */
        changes++;
        doflow = TRUE;
        return TRUE;                    /* it was replaced              */
    }
    return FALSE;                       /* need to create a new variable */
}

/***********************
 * Eliminate basic IVs.
 */

STATIC void elimbasivs(loop *l)
{ famlist *fl;
  Iv *biv;
  unsigned i;
  tym_t ty;
  elem **pref,*fofe,*C2;
  symbol *X;
  int refcount;

  cmes2("elimbasivs(%p)\n",l);
  for (biv = l->Livlist; biv; biv = biv->IVnext)        // for each basic IV
  {

        /* Can't eliminate this basic IV if we have a goal for the      */
        /* increment elem.                                              */
        // Be careful about Nflags being in a union...
        if (!((*biv->IVincr)->Nflags & NFLnogoal))
                continue;

        X = biv->IVbasic;
        assert(symbol_isintab(X));
        ty = X->ty();
        pref = onlyref(X,l,*biv->IVincr,&refcount);

        /* if only ref of X is of the form (X) or (X relop e) or (e relop X) */
        if (pref != NULL && refcount <= 1)
        {       elem *ref;
                tym_t flty;

                fl = biv->IVfamily;
                if (!fl)                // if no elems in family of biv
                    continue;

                ref = *pref;

                /* Replace (X) with (X != 0)                            */
                if (ref->Eoper == OPvar)
                    ref = *pref = el_bin(OPne,TYint,ref,el_long(ref->Ety,0L));

                fl = simfl(fl,ty);      /* find simplest elem in family */
                if (!fl)
                    continue;

                // Don't do the replacement if we would replace a
                // signed comparison with an unsigned one
                flty = fl->FLty;
                if (tyuns(ref->E1->Ety) | tyuns(ref->E2->Ety))
                    flty = touns(flty);

                if (ref->Eoper >= OPle && ref->Eoper <= OPge &&
                    !(tyuns(ref->E1->Ety) | tyuns(ref->E2->Ety)) &&
                     tyuns(flty))
                        continue;

                /* if we have (e relop X), replace it with (X relop e)  */
                if (ref->E2->Eoper == OPvar && ref->E2->EV.sp.Vsym == X)
                {       elem *tmp;

                        tmp = ref->E2;
                        ref->E2 = ref->E1;
                        ref->E1 = tmp;
                        ref->Eoper = swaprel(ref->Eoper);
                }

                // If e*c1+c2 would result in a sign change or an overflow
                // then we can't do it
                if (fl->c1->Eoper == OPconst)
                {
                    targ_llong c1;
                    int sz;

                    c1 = el_tolong(fl->c1);
                    sz = tysize(ty);
                    if (sz == SHORTSIZE &&
                        ((ref->E2->Eoper == OPconst &&
                        c1 * el_tolong(ref->E2) & ~0x7FFFL) ||
                         c1 & ~0x7FFFL)
                       )
                        continue;

                    if (sz == LONGSIZE &&
                        ((ref->E2->Eoper == OPconst &&
                        c1 * el_tolong(ref->E2) & ~0x7FFFFFFFL) ||
                         c1 & ~0x7FFFFFFFL)
                       )
                        continue;
                    if (sz == LLONGSIZE &&
                        ((ref->E2->Eoper == OPconst &&
                        c1 * el_tolong(ref->E2) & ~0x7FFFFFFFFFFFFFFFLL) ||
                         c1 & ~0x7FFFFFFFFFFFFFFFLL)
                       )
                        continue;
                }

                /* If loop started out with a signed conditional that was
                 * replaced with an unsigned one, don't do it if c2
                 * is less than 0.
                 */
                if (ref->Nflags & NFLtouns && fl->c2->Eoper == OPconst)
                {
                    targ_llong c2 = el_tolong(fl->c2);
                    if (c2 < 0)
                        continue;
                }

                elem *refE2 = el_copytree(ref->E2);
                int refEoper = ref->Eoper;

                /* if c1 < 0 and relop is < <= > >=
                   then adjust relop as if both sides were multiplied
                   by -1
                 */
                if (!tyuns(ty) &&
                    (tyintegral(ty) && el_tolong(fl->c1) < 0 ||
                     tyfloating(ty) && el_toldouble(fl->c1) < 0.0))
                        refEoper = swaprel(refEoper);

                /* Replace (X relop e) with (X relop (short)e)
                   if T is 1 word but e is 2
                 */
                if (tysize(flty) == SHORTSIZE &&
                    tysize(refE2->Ety) == LONGSIZE)
                    refE2 = el_una(OP32_16,flty,refE2);

                /* replace e with e*c1 + c2             */
                C2 = el_copytree(fl->c2);
                fofe = el_bin(OPadd,flty,
                                el_bin(OPmul,refE2->Ety,
                                        refE2,
                                        el_copytree(fl->c1)),
                                C2);
                fofe = doptelem(fofe,GOALvalue | GOALagain);    // fold any constants

                if (tyuns(flty) && refEoper == OPge &&
                    fofe->Eoper == OPconst && el_allbits(fofe, 0) &&
                    fl->c2->Eoper == OPconst && !el_allbits(fl->c2, 0))
                {
                    /* Don't do it if replacement will result in
                     * an unsigned T>=0 which will be an infinite loop.
                     */
                    el_free(fofe);
                    continue;
                }

                cmes2("Eliminating basic IV '%s'\n",X->Sident);

#ifdef DEBUG
                if (debugc)
                {   dbg_printf("Comparison replaced: ");
                    WReqn(ref);
                    dbg_printf(" with ");
                }
#endif

                el_free(ref->E2);
                ref->E2 = refE2;
                ref->Eoper = refEoper;

                elimass(*biv->IVincr);          // dump the increment elem

                // replace X with T
                assert(ref->E1->EV.sp.Voffset == 0);
                ref->E1->EV.sp.Vsym = fl->FLtemp;
                ref->E1->Ety = flty;
                ref->E2 = fofe;

                /* If sizes of expression worked out wrong...
                   Which can happen if we have (int)ptr==e
                 */
                if (EBIN(fofe))         /* if didn't optimize it away   */
                {   int sz;
                    tym_t ty,ty1,ty2;

                    ty = fofe->Ety;
                    sz = tysize(ty);
                    ty1 = fofe->E1->Ety;
                    ty2 = fofe->E2->Ety;
                    /* Sizes of + expression must all be the same       */
                    if (sz != tysize(ty1) &&
                        sz != tysize(ty2)
                       )
                    {
                        if (tyuns(ty))          /* if unsigned comparison */
                            ty1 = touns(ty1);   /* to unsigned type     */
                        fofe->Ety = ty1;
                        ref->E1->Ety = ty1;
                    }
                }

#if TARGET_SEGMENTED
                /* Fix if leaves of compare are TYfptrs and the compare */
                /* operator is < <= > >=.                               */
                if (ref->Eoper >= OPle && ref->Eoper <= OPge && tyfv(ref->E1->Ety))
                {       assert(tyfv(ref->E2->Ety));
                        ref->E1 = el_una(OPoffset,TYuint,ref->E1);
                        ref->E2 = el_una(OPoffset,TYuint,fofe);
                }
#endif
#ifdef DEBUG
                if (debugc)
                {   WReqn(ref);
                    dbg_printf("\n");
                }
#endif

                changes++;
                doflow = TRUE;                  /* redo flow analysis   */

                /* if X is live on entry to any successor S outside loop */
                /*      prepend elem X=(T-c2)/c1 to S.Belem     */

                foreach (i,dfotop,l->Lexit)     /* for each exit block  */
                {       elem *ne;
                        block *b;
                        list_t bl;

                        for (bl = dfo[i]->Bsucc; bl; bl = list_next(bl))
                        {                       /* for each successor   */
                                b = list_block(bl);
                                if (vec_testbit(b->Bdfoidx,l->Lloop))
                                        continue;       /* inside loop  */
                                if (!vec_testbit(X->Ssymnum,b->Binlv))
                                        continue;       /* not live     */

                                C2 = el_copytree(fl->c2);
                                ne = el_bin(OPmin,ty,
                                        el_var(fl->FLtemp),
                                        C2);
#if TARGET_SEGMENTED
                                if (tybasic(ne->E1->Ety) == TYfptr &&
                                    tybasic(ne->E2->Ety) == TYfptr)
                                {   ne->Ety = I64 ? TYllong : TYint;
                                    if (tylong(ty) && intsize == 2)
                                        ne = el_una(OPs16_32,ty,ne);
                                }
#endif

                                ne = el_bin(OPeq,X->ty(),
                                        el_var(X),
                                        el_bin(OPdiv,ne->Ety,
                                            ne,
                                            el_copytree(fl->c1)));
#ifdef DEBUG
                                if (debugc)
                                {   dbg_printf("Adding (");
                                    WReqn(ne);
                                    dbg_printf(") to exit block B%d\n",b->Bdfoidx);
                                    //elem_print(ne);
                                }
#endif
                                /* We have to add a new block if there is */
                                /* more than one predecessor to b.      */
                                if (list_next(b->Bpred))
                                {   block *bn;
                                    list_t bl2;

                                    bn = block_calloc();
                                    bn->Btry = b->Btry;
                                    numblks++;
                                    assert(numblks <= maxblks);
                                    bn->BC = BCgoto;
                                    bn->Bnext = dfo[i]->Bnext;
                                    dfo[i]->Bnext = bn;
                                    list_append(&(bn->Bsucc),b);
                                    list_append(&(bn->Bpred),dfo[i]);
                                    list_ptr(bl) = (void *)bn;
                                    for (bl2 = b->Bpred; bl2;
                                         bl2 = list_next(bl2))
                                        if (list_block(bl2) == dfo[i])
                                        {       list_ptr(bl2) = (void *)bn;
                                                goto L2;
                                        }
                                    assert(0);
                                L2:
                                    b = bn;
                                    addblk = TRUE;
                                }

                                if (b->Belem)
                                    b->Belem =
                                        el_bin(OPcomma,b->Belem->Ety,
                                            ne,b->Belem);
                                else
                                    b->Belem = ne;
                                changes++;
                                doflow = TRUE;  /* redo flow analysis   */
                        } /* for each successor */
                } /* foreach exit block */
                if (addblk)
                        return;
        }
        else if (refcount == 0)                 /* if no uses of IV in loop  */
        {       /* Eliminate the basic IV if it is not live on any successor */
                foreach (i,dfotop,l->Lexit)     /* for each exit block       */
                {       block *b;
                        list_t bl;

                        for (bl = dfo[i]->Bsucc; bl; bl = list_next(bl))
                        {                       /* for each successor   */
                                b = list_block(bl);
                                if (vec_testbit(b->Bdfoidx,l->Lloop))
                                        continue;       /* inside loop  */
                                if (vec_testbit(X->Ssymnum,b->Binlv))
                                        goto L1;        /* live         */
                        }
                }

                cmes3("No uses, eliminating basic IV '%s' (%p)\n",(X->Sident)
                        ? (char *)X->Sident : "",X);

                /* Dump the increment elem                              */
                /* (Replace it with an OPconst that only serves as a    */
                /* placeholder in the tree)                             */
                *(biv->IVincr) = el_selecte2(*(biv->IVincr));

                changes++;
                doflow = TRUE;                  /* redo flow analysis   */
            L1: ;
        }
  } /* for */
}


/***********************
 * Eliminate opeq IVs that are not used outside the loop.
 */

STATIC void elimopeqs(loop *l)
{
    Iv *biv;
    unsigned i;
    elem **pref;
    symbol *X;
    int refcount;

    cmes2("elimopeqs(%p)\n",l);
    for (biv = l->Lopeqlist; biv; biv = biv->IVnext)    // for each opeq IV
    {

        // Can't eliminate this basic IV if we have a goal for the
        // increment elem.
        // Be careful about Nflags being in a union...
        if (!((*biv->IVincr)->Nflags & NFLnogoal))
            continue;

        X = biv->IVbasic;
        assert(symbol_isintab(X));
        pref = onlyref(X,l,*biv->IVincr,&refcount);

        // if only ref of X is of the form (X) or (X relop e) or (e relop X)
        if (pref != NULL && refcount <= 1)
            ;
        else if (refcount == 0)                 // if no uses of IV in loop
        {   // Eliminate the basic IV if it is not live on any successor
            foreach (i,dfotop,l->Lexit) // for each exit block
            {   block *b;
                list_t bl;

                for (bl = dfo[i]->Bsucc; bl; bl = list_next(bl))
                {   // for each successor
                    b = list_block(bl);
                    if (vec_testbit(b->Bdfoidx,l->Lloop))
                        continue;       // inside loop
                    if (vec_testbit(X->Ssymnum,b->Binlv))
                        goto L1;        // live
                }
            }

            cmes3("No uses, eliminating opeq IV '%s' (%p)\n",(X->Sident)
                    ? (char *)X->Sident : "",X);

            // Dump the increment elem
            // (Replace it with an OPconst that only serves as a
            // placeholder in the tree)
            *(biv->IVincr) = el_selecte2(*(biv->IVincr));

            changes++;
            doflow = TRUE;                      // redo flow analysis
        L1:     ;
        }
    }
}

/**************************
 * Find simplest elem in family.
 * Input:
 *      tym     type of basic IV
 * Return NULL if none found.
 */

STATIC famlist * simfl(famlist *fl,tym_t tym)
{ famlist *sofar;

  assert(fl);
  sofar = NULL;
  for (; fl; fl = fl->FLnext)
  {
        if (fl->FLtemp == FLELIM)       /* no variable, so skip it      */
            continue;
        /* If size of replacement is less than size of biv, we could    */
        /* be in trouble due to loss of precision.                      */
        if (size(fl->FLtemp->ty()) < size(tym))
            continue;
        sofar = flcmp(sofar,fl);        /* pick simplest                */
  }
  return sofar;
}

/**************************
 * Return simpler of two family elems.
 * There is room for improvement, namely if
 *      f1.c1 = 2, f2.c1 = 27
 * then pick f1 because it is a shift.
 */

STATIC famlist * flcmp(famlist *f1,famlist *f2)
{   tym_t ty;
    union eve *t1,*t2;

    assert(f2);
    if (!f1)
        goto Lf2;
    t1 = &(f1->c1->EV);
    t2 = &(f2->c1->EV);
    ty = (*f1->FLpelem)->Ety;           /* type of elem                 */
#if 0
    printf("f1: c1 = %d, c2 = %d\n",t1->Vshort,f1->c2->EV.Vshort);
    printf("f2: c1 = %d, c2 = %d\n",t2->Vshort,f2->c2->EV.Vshort);
    WRTYxx((*f1->FLpelem)->Ety);
    WRTYxx((*f2->FLpelem)->Ety);
#endif
    /* Wimp out and just pick f1 if the types don't match               */
    if (tysize(ty) == tysize((*f2->FLpelem)->Ety))
    {
        switch (tybasic(ty))
        {   case TYbool:
            case TYchar:
            case TYschar:
            case TYuchar:
                if (t2->Vuchar == 1 ||
                    t1->Vuchar != 1 && f2->c2->EV.Vuchar == 0)
                        goto Lf2;
                break;
            case TYshort:
            case TYushort:
            case TYchar16:
            case TYwchar_t:     // BUG: what about 4 byte wchar_t's?
            case_short:
                if (t2->Vshort == 1 ||
                    t1->Vshort != 1 && f2->c2->EV.Vshort == 0)
                        goto Lf2;
                break;

#if TARGET_SEGMENTED
            case TYsptr:
            case TYcptr:
#endif
            case TYnptr:        // BUG: 64 bit pointers?
            case TYnullptr:
            case TYint:
            case TYuint:
                if (intsize == SHORTSIZE)
                    goto case_short;
                else
                    goto case_long;
            case TYlong:
            case TYulong:
            case TYdchar:
#if TARGET_SEGMENTED
            case TYfptr:
            case TYvptr:
            case TYhptr:
#endif
            case_long:
                if (t2->Vlong == 1 ||
                    t1->Vlong != 1 && f2->c2->EV.Vlong == 0)
                        goto Lf2;
                break;
            case TYfloat:
                if (t2->Vfloat == 1 ||
                    t1->Vfloat != 1 && f2->c2->EV.Vfloat == 0)
                        goto Lf2;
                break;
            case TYdouble:
            case TYdouble_alias:
                if (t2->Vdouble == 1.0 ||
                    t1->Vdouble != 1.0 && f2->c2->EV.Vdouble == 0)
                        goto Lf2;
                break;
            case TYldouble:
                if (t2->Vldouble == 1.0 ||
                    t1->Vldouble != 1.0 && f2->c2->EV.Vldouble == 0)
                        goto Lf2;
                break;
            case TYllong:
            case TYullong:
                if (t2->Vllong == 1 ||
                    t1->Vllong != 1 && f2->c2->EV.Vllong == 0)
                        goto Lf2;
                break;
            default:
                assert(0);
        }
    }
    //printf("picking f1\n");
    return f1;

Lf2:
    //printf("picking f2\n");
    return f2;
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
 *              Return NULL
 */

static int count;
static elem **nd,*sincn;
static symbol *X;

STATIC elem ** onlyref(symbol *x,loop *l,elem *incn,int *prefcount)
{ unsigned i;

  //printf("onlyref('%s')\n", x->Sident);
  X = x;                                /* save some parameter passing  */
  assert(symbol_isintab(x));
  sincn = incn;
#ifdef DEBUG
  if (!(X->Ssymnum < globsym.top && l && incn))
        dbg_printf("X = %d, globsym.top = %d, l = %p, incn = %p\n",X->Ssymnum,globsym.top,l,incn);
#endif
  assert(X->Ssymnum < globsym.top && l && incn);
  count = 0;
  nd = NULL;
  foreach (i,dfotop,l->Lloop)           /* for each block in loop       */
  {     block *b;

        b = dfo[i];
        if (b->Belem)
        {
            countrefs(&b->Belem,b->BC == BCiftrue);
        }
  }
#if 0
  dbg_printf("count = %d, nd = (");
  if (nd) WReqn(*nd);
  dbg_printf(")\n");
#endif
  *prefcount = count;
  return nd;
}

/******************************
 * Count elems of the form (X relop e) or (e relop X).
 * Do not count the node if it is the increment node (sincn).
 * Input:
 *      flag:   TRUE if block wants to test the elem
 */

STATIC void countrefs(elem **pn,bool flag)
{ elem *n = *pn;

  assert(n);
  if (n == sincn)                       /* if it is the increment elem  */
  {
        if (OTbinary(n->Eoper))
            countrefs(&n->E2, FALSE);
        return;                         // don't count lvalue
  }
  if (OTunary(n->Eoper))
        countrefs(&n->E1,FALSE);
  else if (OTbinary(n->Eoper))
  {
        if (OTrel(n->Eoper))
        {       elem *e1 = n->E1;

                assert(e1->Eoper != OPcomma);
                if (e1 == sincn &&
                    (e1->Eoper == OPeq || OTopeq(e1->Eoper)))
                    goto L1;

                /* Check both subtrees to see if n is the comparison node,
                 * that is, if X is a leaf of the comparison.
                 */
                if (e1->Eoper == OPvar && e1->EV.sp.Vsym == X && !countrefs2(n->E2) ||
                    n->E2->Eoper == OPvar && n->E2->EV.sp.Vsym == X && !countrefs2(e1))
                        nd = pn;                /* found the relop node */
        }
    L1:
        countrefs(&n->E1,FALSE);
        countrefs(&n->E2,(flag && n->Eoper == OPcomma));
  }
  else if ((n->Eoper == OPvar || n->Eoper == OPrelconst) && n->EV.sp.Vsym == X)
  {     if (flag)
            nd = pn;                    /* comparing it with 0          */
        count++;                        /* found another reference      */
  }
}

/*******************************
 * Count number of times symbol X appears in elem tree e.
 */

STATIC int countrefs2(elem *e)
{
    elem_debug(e);
    while (OTunary(e->Eoper))
        e = e->E1;
    if (OTbinary(e->Eoper))
        return countrefs2(e->E1) + countrefs2(e->E2);
    return ((e->Eoper == OPvar || e->Eoper == OPrelconst) &&
            e->EV.sp.Vsym == X);
}

/****************************
 * Eliminate some special cases.
 */

STATIC void elimspec(loop *l)
{ unsigned i;

  foreach (i,dfotop,l->Lloop)           /* for each block in loop       */
  {     block *b;

        b = dfo[i];
        if (b->Belem)
            elimspecwalk(&b->Belem);
  }
}

/******************************
 */

STATIC void elimspecwalk(elem **pn)
{ elem *n;

  n = *pn;
  assert(n);
  if (OTunary(n->Eoper))
        elimspecwalk(&n->E1);
  else if (OTbinary(n->Eoper))
  {
        elimspecwalk(&n->E1);
        elimspecwalk(&n->E2);
        if (OTrel(n->Eoper))
        {       elem *e1 = n->E1;

                /* Replace ((e1,e2) rel e3) with (e1,(e2 rel e3).
                 * This will reduce the number of cases for elimbasivs().
                 * Don't do equivalent with (e1 rel (e2,e3)) because
                 * of potential side effects in e1.
                 */
                if (e1->Eoper == OPcomma)
                {       elem *e;

#ifdef DEBUG
                        if (debugc)
                        {   dbg_printf("3rewriting ("); WReqn(n); dbg_printf(")\n"); }
#endif
                        e = n->E2;
                        n->E2 = e1;
                        n->E1 = n->E2->E1;
                        n->E2->E1 = n->E2->E2;
                        n->E2->E2 = e;
                        n->E2->Eoper = n->Eoper;
                        n->E2->Ety = n->Ety;
                        n->Eoper = OPcomma;

                        changes++;
                        doflow = TRUE;

                        elimspecwalk(&n->E1);
                        elimspecwalk(&n->E2);
                }

                /* Rewrite ((X op= e2) rel e3) into ((X op= e2),(X rel e3))
                 * Rewrite ((X ++  e2) rel e3) into ((X +=  e2),(X-e2 rel e3))
                 * so that the op= will not have a goal, so elimbasivs()
                 * will work on it.
                 */
                if ((OTopeq(e1->Eoper)
                     || OTpost(e1->Eoper)
                    ) &&
                    !el_sideeffect(e1->E1))
                {       elem *e;
                        int op;
#ifdef DEBUG
                        if (debugc)
                        { dbg_printf("4rewriting ("); WReqn(n); dbg_printf(")\n"); }
#endif
                        e = el_calloc();
                        el_copy(e,n);
                        e->E1 = el_copytree(e1->E1);
                        e->E1->Ety = n->E1->Ety;
                        n->E2 = e;
                        switch (e1->Eoper)
                        {   case OPpostinc:
                                e1->Eoper = OPaddass;
                                op = OPmin;
                                goto L3;
                            case OPpostdec:
                                e1->Eoper = OPminass;
                                op = OPadd;
                            L3: e->E1 = el_bin(op,e->E1->Ety,e->E1,el_copytree(e1->E2));
                                break;

                        }
                        /* increment node is now guaranteed to have no goal */
                        e1->Nflags |= NFLnogoal;
                        n->Eoper = OPcomma;
                        //changes++;
                        doflow = TRUE;

                        elimspecwalk(&n->E1);
                        elimspecwalk(&n->E2);
                }
        }
  }
}

#endif
