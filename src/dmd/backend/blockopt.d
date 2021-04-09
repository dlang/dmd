/**
 * Manipulating basic blocks and their edges.
 *
 * Copyright:   Copyright (C) 1986-1997 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/blockopt.d, backend/blockopt.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_blockopt.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/blockopt.d
 */

module dmd.backend.blockopt;

/****************************************************************
 * Handle basic blocks.
 */

version (SPP) {} else
{

version (SCPP)
    version = COMPILE;
else version (HTOD)
    version = COMPILE;

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

version (COMPILE)
{
    import parser;
    import iasm;
    import precomp;
}


version (SCPP)
    enum SCPP_OR_NTEXCEPTIONS = true;
else static if (NTEXCEPTIONS)
    enum SCPP_OR_NTEXCEPTIONS = true;
else
    enum SCPP_OR_NTEXCEPTIONS = false;

extern(C++):

nothrow:
@safe:

extern (C) void *mem_fcalloc(size_t numbytes); // tk/mem.c
extern (C) void mem_free(void*); // tk/mem.c

alias MEM_PH_FREE = mem_free;

version (HTOD)
    void *util_realloc(void* p, size_t n, size_t size);
else
    import dmd.backend.gflow : util_realloc;

__gshared
{
    block *startblock;      // beginning block of function
                            // (can have no predecessors)

    Barray!(block*) dfo;    // array of depth first order

    block *curblock;        // current block being read in
    block *block_last;      // last block read in

    block *block_freelist;

    block blkzero;          // storage allocator
}

@trusted
pragma(inline, true) block *block_calloc_i()
{
    block *b;

    if (block_freelist)
    {
        b = block_freelist;
        block_freelist = b.Bnext;
        *b = blkzero;
    }
    else
        b = cast(block *) mem_calloc(block.sizeof);
    return b;
}

block *block_calloc()
{
    return block_calloc_i();
}

/*********************************
 */

__gshared goal_t[BCMAX] bc_goal;

@trusted
void block_init()
{
    for (size_t i = 0; i < BCMAX; i++)
        bc_goal[i] = GOALvalue;

    bc_goal[BCgoto] = GOALnone;
    bc_goal[BCret ] = GOALnone;
    bc_goal[BCexit] = GOALnone;

    bc_goal[BCiftrue] = GOALflags;
}

/*********************************
 */

@trusted
void block_term()
{
    while (block_freelist)
    {
        block *b = block_freelist.Bnext;
        mem_free(block_freelist);
        block_freelist = b;
    }
}

/**************************
 * Finish up this block and start the next one.
 */

version (MARS)
{
@trusted
void block_next(Blockx *bctx,int bc,block *bn)
{
    bctx.curblock.BC = cast(ubyte) bc;
    block_last = bctx.curblock;
    if (!bn)
        bn = block_calloc_i();
    bctx.curblock.Bnext = bn;                // next block
    bctx.curblock = bctx.curblock.Bnext;     // new current block
    bctx.curblock.Btry = bctx.tryblock;
    bctx.curblock.Bflags |= bctx.flags;
}
}
else
{
@trusted
void block_next(int bc,block *bn)
{
    curblock.BC = cast(ubyte) bc;
    curblock.Bsymend = globsym.length;
    block_last = curblock;
    if (!bn)
        bn = block_calloc_i();
    curblock.Bnext = bn;                     // next block
    curblock = curblock.Bnext;               // new current block
    curblock.Bsymstart = globsym.length;
    curblock.Btry = pstate.STbtry;
}

void block_next()
{
    block_next(cast(BC)curblock.BC,null);
}
}

/**************************
 * Finish up this block and start the next one.
 */

version (MARS)
{
block *block_goto(Blockx *bx,int bc,block *bn)
{
    block *b;

    b = bx.curblock;
    block_next(bx,bc,bn);
    b.appendSucc(bx.curblock);
    return bx.curblock;
}
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

void block_goto(block *bn)
{
    block_goto(bn,bn);
}

void block_goto(block *bgoto,block *bnew)
{
    BC bc;

    assert(bgoto);
    curblock.appendSucc(bgoto);
    if (curblock.Bcode)         // If there is already code in the block
                                // then this is an ASM block
        bc = BCasm;
    else
        bc = BCgoto;            // fall thru to next block
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
    for (block *b = startblock; b; b = b.Bnext)       /* for each block        */
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
    for (block *b = startblock; b; b = b.Bnext)       // for each block
        list_free(&b.Bpred,FPNULL);

    for (block *b = startblock; b; b = b.Bnext)       // for each block
    {
        //printf("b = %p, BC = ",b); WRBC(b.BC); printf("\n");
        foreach (bp; ListRange(b.Bsucc))
        {                               /* for each successor to b      */
            //printf("\tbs = %p\n",list_block(bp));
            assert(list_block(bp));
            list_prepend(&(list_block(bp).Bpred),b);
        }
    }
    assert(startblock.Bpred == null);  /* startblock has no preds      */
}

/********************************************
 * Clear visit.
 */

@trusted
void block_clearvisit()
{
    for (block *b = startblock; b; b = b.Bnext)       // for each block
        b.Bflags &= ~BFLvisited;               // mark as unvisited
}

/********************************************
 * Visit block and each of its predecessors.
 */

void block_visit(block *b)
{
    b.Bflags |= BFLvisited;
    foreach (l; ListRange(b.Bsucc))
    {
        block *bs = list_block(l);
        assert(bs);
        if ((bs.Bflags & BFLvisited) == 0)     // if not visited
            block_visit(bs);
    }
}

/*****************************
 * Compute number of parents (Bcount) of each basic block.
 */
@trusted
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
{
    block *bn;
    for (block *b = *pb; b; b = bn)
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
void block_optimizer_free(block *b)
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
void block_free(block *b)
{
    assert(b);
    if (b.Belem)
        el_free(b.Belem);
    list_free(&b.Bsucc,FPNULL);
    list_free(&b.Bpred,FPNULL);
    if (OPTIMIZER)
        block_optimizer_free(b);
    switch (b.BC)
    {
        case BCswitch:
        case BCifthen:
        case BCjmptab:
            version (MARS)
            {
                free(b.Bswitch);
            }
            else
            {
                MEM_PH_FREE(b.Bswitch);
            }
            break;

        version (SCPP)
        {
            case BCcatch:
                type_free(b.Bcatchtype);
                break;
        }

        version (MARS)
        {
            case BCjcatch:
                free(b.actionTable);
                break;
        }

        case BCasm:
            version (HTOD) {} else
            {
                code_free(b.Bcode);
            }
            break;

        default:
            break;
    }
    b.Bnext = block_freelist;
    block_freelist = b;
}

/****************************
 * Hydrate/dehydrate a list of blocks.
 */

version (COMPILE)
{
static if (HYDRATE)
{
@trusted
void blocklist_hydrate(block **pb)
{
    while (isdehydrated(*pb))
    {
        /*printf("blocklist_hydrate(*pb = %p) =",*pb);*/
        block *b = cast(block *)ph_hydrate(cast(void**)pb);
        /*printf(" %p\n",b);*/
        el_hydrate(&b.Belem);
        list_hydrate(&b.Bsucc,FPNULL);
        list_hydrate(&b.Bpred,FPNULL);
        cast(void) ph_hydrate(cast(void**)&b.Btry);
        cast(void) ph_hydrate(cast(void**)&b.Bendscope);
        symbol_hydrate(&b.Binitvar);
        switch (b.BC)
        {
            case BCtry:
                symbol_hydrate(&b.catchvar);
                break;

            case BCcatch:
                type_hydrate(&b.Bcatchtype);
                break;

            case BCswitch:
                ph_hydrate(cast(void**)&b.Bswitch);
                break;

            case BC_finally:
                //(void) ph_hydrate(&b.B_ret);
                break;

            case BC_lpad:
                symbol_hydrate(&b.flag);
                break;

            case BCasm:
                version (HTOD) {} else
                {
                    code_hydrate(&b.Bcode);
                }
                break;

            default:
                break;
        }
        filename_translate(&b.Bsrcpos);
        srcpos_hydrate(&b.Bsrcpos);
        pb = &b.Bnext;
    }
}
}

static if (DEHYDRATE)
{
@trusted
void blocklist_dehydrate(block **pb)
{
    block *b;

    while ((b = *pb) != null && !isdehydrated(b))
    {
        version (DEBUG_XSYMGEN)
        {
            if (xsym_gen && ph_in_head(b))
                return;
        }

        /*printf("blocklist_dehydrate(*pb = %p) =",b);*/
        ph_dehydrate(pb);
        /*printf(" %p\n",*pb);*/
        el_dehydrate(&b.Belem);
        list_dehydrate(&b.Bsucc,FPNULL);
        list_dehydrate(&b.Bpred,FPNULL);
        ph_dehydrate(&b.Btry);
        ph_dehydrate(&b.Bendscope);
        symbol_dehydrate(&b.Binitvar);
        switch (b.BC)
        {
            case BCtry:
                symbol_dehydrate(&b.catchvar);
                break;

            case BCcatch:
                type_dehydrate(&b.Bcatchtype);
                break;

            case BCswitch:
                ph_dehydrate(&b.Bswitch);
                break;

            case BC_finally:
                //ph_dehydrate(&b.B_ret);
                break;

            case BC_lpad:
                symbol_dehydrate(&b.flag);
                break;

            case BCasm:
                code_dehydrate(&b.Bcode);
                break;

            default:
                break;
        }
        srcpos_dehydrate(&b.Bsrcpos);
        pb = &b.Bnext;
    }
}
}
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
void block_appendexp(block *b,elem *e)
{
    version (MARS) {}
    else assert(PARSER);

    if (e)
    {
        assert(b);
        elem_debug(e);
        elem **pe = &b.Belem;
        elem *ec = *pe;
        if (ec != null)
        {
            type *t = e.ET;

            if (t)
                type_debug(t);
            elem_debug(e);
            version (MARS)
            {
                tym_t ty = e.Ety;

                elem_debug(e);
                /* Build tree such that (a,b) => (a,(b,e))  */
                while (ec.Eoper == OPcomma)
                {
                    ec.Ety = ty;
                    ec.ET = t;
                    pe = &(ec.EV.E2);
                    ec = *pe;
                }
                e = el_bin(OPcomma,ty,ec,e);
                e.ET = t;
            }
            else
            {
                /* Build tree such that (a,b) => (a,(b,e))  */
                while (ec.Eoper == OPcomma)
                {
                    el_settype(ec,t);
                    pe = &(ec.EV.E2);
                    ec = *pe;
                }
                e = el_bint(OPcomma,t,ec,e);
            }
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

void block_initvar(Symbol *s)
{
    symbol_debug(s);
    curblock.Binitvar = s;
}

}

/*******************
 * Mark end of function.
 * flag:
 *      0       do a "return"
 *      1       do a "return 0"
 */

@trusted
void block_endfunc(int flag)
{
    curblock.Bsymend = globsym.length;
    curblock.Bendscope = curblock;
    if (flag)
    {
        elem *e = el_longt(tstypes[TYint], 0);
        block_appendexp(curblock, e);
        curblock.BC = BCretexp;        // put a return at the end
    }
    else
        curblock.BC = BCret;           // put a return at the end
    curblock = null;                    // undefined from now on
    block_last = null;
}

/******************************
 * Perform branch optimization on basic blocks.
 */

@trusted
void blockopt(int iter)
{
    if (OPTIMIZER)
    {
        blassertsplit();                // only need this once

        int iterationLimit = 200;
        if (iterationLimit < dfo.length)
            iterationLimit = cast(int)dfo.length;
        int count = 0;
        do
        {
            //printf("changes = %d, count = %d, dfo.length = %d\n",go.changes,count,dfo.length);
            go.changes = 0;
            bropt();                    // branch optimization
            brrear();                   // branch rearrangement
            blident();                  // combine identical blocks
            blreturn();                 // split out return blocks
            bltailmerge();              // do tail merging
            brtailrecursion();          // do tail recursion
            brcombine();                // convert graph to expressions
            blexit();
            if (iter >= 2)
                brmin();                // minimize branching
            version (MARS)
                // Switched to one block per Statement, do not undo it
                enum merge = false;
            else
                enum merge = true;

            do
            {
                compdfo();              /* compute depth first order (DFO) */
                elimblks();             /* remove blocks not in DFO      */
                assert(count < iterationLimit);
                count++;
            } while (merge && mergeblks());      // merge together blocks
        } while (go.changes);

        debug if (debugw)
        {
            numberBlocks(startblock);
            for (block *b = startblock; b; b = b.Bnext)
                WRblock(b);
        }
    }
    else
    {
        debug
        {
            numberBlocks(startblock);
        }

        /* canonicalize the trees        */
        for (block *b = startblock; b; b = b.Bnext)
        {
            debug if (debugb)
                WRblock(b);

            if (b.Belem)
            {
                b.Belem = doptelem(b.Belem,bc_goal[b.BC] | GOALstruct);
                if (b.Belem)
                    b.Belem = el_convert(b.Belem);
            }

            debug if (debugb)
            {   printf("after optelem():\n");
                WRblock(b);
            }
        }
        if (localgot)
        {   // Initialize with:
            //  localgot = OPgot;
            elem *e = el_long(TYnptr, 0);
            e.Eoper = OPgot;
            e = el_bin(OPeq, TYnptr, el_var(localgot), e);
            startblock.Belem = el_combine(e, startblock.Belem);
        }

        bropt();                        /* branch optimization           */
        brrear();                       /* branch rearrangement          */
        comsubs();                      /* eliminate common subexpressions */

        debug if (debugb)
        {
            printf("...................After blockopt().............\n");
            numberBlocks(startblock);
            for (block *b = startblock; b; b = b.Bnext)
                WRblock(b);
        }
    }
}

/***********************************
 * Try to remove control structure.
 * That is, try to resolve if-else, goto and return statements
 * into &&, || and ?: combinations.
 */

@trusted
void brcombine()
{
    debug if (debugc) printf("brcombine()\n");
    //numberBlocks(startblock);
    //for (block *b = startblock; b; b = b.Bnext)
        //WRblock(b);

    if (funcsym_p.Sfunc.Fflags3 & (Fcppeh | Fnteh))
    {   // Don't mess up extra EH info by eliminating blocks
        return;
    }

    do
    {
        int anychanges = 0;
        for (block *b = startblock; b; b = b.Bnext)   // for each block
        {
            /* Look for [e1 IFFALSE L3,L2] L2: [e2 GOTO L3] L3: [e3]    */
            /* Replace with [(e1 && e2),e3]                             */
            ubyte bc = b.BC;
            if (bc == BCiftrue)
            {
                block *b2 = b.nthSucc(0);
                block *b3 = b.nthSucc(1);

                if (list_next(b2.Bpred))       // if more than one predecessor
                    continue;
                if (b2 == b3)
                    continue;
                if (b2 == startblock)
                    continue;
                if (!PARSER && b2.Belem && !OTleaf(b2.Belem.Eoper))
                    continue;

                ubyte bc2 = b2.BC;
                if (bc2 == BCgoto &&
                    b3 == b2.nthSucc(0))
                {
                    b.BC = BCgoto;
                    if (b2.Belem)
                    {
                        int op = OPandand;
                        b.Belem = PARSER ? el_bint(op,tstypes[TYint],b.Belem,b2.Belem)
                                          : el_bin(op,TYint,b.Belem,b2.Belem);
                        b2.Belem = null;
                    }
                    list_subtract(&(b.Bsucc),b2);
                    list_subtract(&(b2.Bpred),b);
                    debug if (debugc) printf("brcombine(): if !e1 then e2 => e1 || e2\n");
                    anychanges++;
                }
                else if (list_next(b3.Bpred) || b3 == startblock)
                    continue;
                else if ((bc2 == BCretexp && b3.BC == BCretexp)
                         //|| (bc2 == BCret && b3.BC == BCret)
                        )
                {
                    if (PARSER)
                    {
                        type *t = (bc2 == BCretexp) ? b2.Belem.ET : tstypes[TYvoid];
                        elem *e = el_bint(OPcolon2,t,b2.Belem,b3.Belem);
                        b.Belem = el_bint(OPcond,t,b.Belem,e);
                    }
                    else
                    {
                        if (!OTleaf(b3.Belem.Eoper))
                            continue;
                        tym_t ty = (bc2 == BCretexp) ? b2.Belem.Ety : cast(tym_t) TYvoid;
                        elem *e = el_bin(OPcolon2,ty,b2.Belem,b3.Belem);
                        b.Belem = el_bin(OPcond,ty,b.Belem,e);
                    }
                    b.BC = bc2;
                    b.Belem.ET = b2.Belem.ET;
                    b2.Belem = null;
                    b3.Belem = null;
                    list_free(&b.Bsucc,FPNULL);
                    list_subtract(&(b2.Bpred),b);
                    list_subtract(&(b3.Bpred),b);
                    debug if (debugc) printf("brcombine(): if e1 return e2 else return e3 => ret e1?e2:e3\n");
                    anychanges++;
                }
                else if (bc2 == BCgoto &&
                         b3.BC == BCgoto &&
                         b2.nthSucc(0) == b3.nthSucc(0))
                {
                    block *bsucc = b2.nthSucc(0);
                    if (b2.Belem)
                    {
                        elem *e;
                        if (PARSER)
                        {
                            if (b3.Belem)
                            {
                                e = el_bint(OPcolon2,b2.Belem.ET,
                                        b2.Belem,b3.Belem);
                                e = el_bint(OPcond,e.ET,b.Belem,e);
                            }
                            else
                            {
                                int op = OPandand;
                                e = el_bint(op,tstypes[TYint],b.Belem,b2.Belem);
                            }
                        }
                        else
                        {
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
                        }
                        b2.Belem = null;
                        b.Belem = e;
                    }
                    else if (b3.Belem)
                    {
                        int op = OPoror;
                        b.Belem = PARSER ? el_bint(op,tstypes[TYint],b.Belem,b3.Belem)
                                         : el_bin(op,TYint,b.Belem,b3.Belem);
                    }
                    b.BC = BCgoto;
                    b3.Belem = null;
                    list_free(&b.Bsucc,FPNULL);

                    b.appendSucc(bsucc);
                    list_append(&bsucc.Bpred,b);

                    list_free(&(b2.Bpred),FPNULL);
                    list_free(&(b2.Bsucc),FPNULL);
                    list_free(&(b3.Bpred),FPNULL);
                    list_free(&(b3.Bsucc),FPNULL);
                    b2.BC = BCret;
                    b3.BC = BCret;
                    list_subtract(&(bsucc.Bpred),b2);
                    list_subtract(&(bsucc.Bpred),b3);
                    debug if (debugc) printf("brcombine(): if e1 goto e2 else goto e3 => ret e1?e2:e3\n");
                    anychanges++;
                }
            }
            else if (bc == BCgoto && PARSER)
            {
                block *b2 = b.nthSucc(0);
                if (!list_next(b2.Bpred) && b2.BC != BCasm    // if b is only parent
                    && b2 != startblock
                    && b2.BC != BCtry
                    && b2.BC != BC_try
                    && b.Btry == b2.Btry
                   )
                {
                    if (b2.Belem)
                    {
                        if (PARSER)
                        {
                            block_appendexp(b,b2.Belem);
                        }
                        else if (b.Belem)
                            b.Belem = el_bin(OPcomma,b2.Belem.Ety,b.Belem,b2.Belem);
                        else
                            b.Belem = b2.Belem;
                        b2.Belem = null;
                    }
                    list_subtract(&b.Bsucc,b2);
                    list_subtract(&b2.Bpred,b);

                    /* change predecessor of successors of b2 from b2 to b */
                    foreach (bl; ListRange(b2.Bsucc))
                    {
                        list_t bp;
                        for (bp = list_block(bl).Bpred; bp; bp = list_next(bp))
                        {
                            if (list_block(bp) == b2)
                                bp.ptr = cast(void *)b;
                        }
                    }

                    b.BC = b2.BC;
                    b.BS = b2.BS;
                    b.Bsucc = b2.Bsucc;
                    b2.Bsucc = null;
                    b2.BC = BCret;             /* a harmless one       */
                    debug if (debugc) printf("brcombine(): %p goto %p eliminated\n",b,b2);
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
private void bropt()
{
    debug if (debugc) printf("bropt()\n");
    assert(!PARSER);
    for (block *b = startblock; b; b = b.Bnext)   // for each block
    {
        elem **pn = &(b.Belem);
        if (OPTIMIZER && *pn)
            while ((*pn).Eoper == OPcomma)
                pn = &((*pn).EV.E2);

        elem *n = *pn;

        /* look for conditional that never returns */
        if (n && tybasic(n.Ety) == TYnoreturn && b.BC != BCexit)
        {
            b.BC = BCexit;
            // Exit block has no successors, so remove them
            foreach (bp; ListRange(b.Bsucc))
            {
                list_subtract(&(list_block(bp).Bpred),b);
            }
            list_free(&b.Bsucc, FPNULL);
            debug if (debugc) printf("CHANGE: noreturn becomes BCexit\n");
            go.changes++;
            continue;
        }

        if (b.BC == BCiftrue)
        {
            assert(n);
            /* Replace IF (!e) GOTO ... with        */
            /* IF OPnot (e) GOTO ...                */
            if (n.Eoper == OPnot)
            {
                tym_t tym;

                tym = n.EV.E1.Ety;
                *pn = el_selecte1(n);
                (*pn).Ety = tym;
                for (n = b.Belem; n.Eoper == OPcomma; n = n.EV.E2)
                    n.Ety = tym;
                b.Bsucc = list_reverse(b.Bsucc);
                debug if (debugc) printf("CHANGE: if (!e)\n");
                go.changes++;
            }

            /* Take care of IF (constant)                   */
            block *db;
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
                b.BC = BCgoto;
                /* delete elem if it has no side effects */
                b.Belem = doptelem(b.Belem,GOALnone | GOALagain);
                debug if (debugc) printf("CHANGE: if (const)\n");
                go.changes++;
            }

            /* Look for both destinations being the same    */
            else if (b.nthSucc(0) ==
                     b.nthSucc(1))
            {
                b.BC = BCgoto;
                db = b.nthSucc(0);
                list_subtract(&(b.Bsucc),db);
                list_subtract(&(db.Bpred),b);
                debug if (debugc) printf("CHANGE: if (e) goto L1; else goto L1;\n");
                go.changes++;
            }
        }
        else if (b.BC == BCswitch)
        {   /* see we can evaluate this switch now  */
            while (n.Eoper == OPcomma)
                n = n.EV.E2;
            if (n.Eoper != OPconst)
                continue;
            assert(tyintegral(n.Ety));
            targ_llong value = el_tolong(n);
            targ_llong* pv = b.Bswitch;      // ptr to switch data
            assert(pv);
            uint ncases = cast(uint) *pv++;  // # of cases
            uint i = 1;                      // first case
            while (1)
            {
                if (i > ncases)
                {
                    i = 0;      // select default
                    break;
                }
                if (*pv++ == value)
                    break;      // found it
                i++;            // next case
            }
            /* the ith entry in Bsucc is the one we want    */
            block *db = b.nthSucc(i);
            /* delete predecessors of successors (!)        */
            foreach (bl; ListRange(b.Bsucc))
                if (i--)            // if not ith successor
                {
                    void *p = list_subtract(&(list_block(bl).Bpred),b);
                    assert(p == b);
                }

            /* dump old successor list and create a new one */
            list_free(&b.Bsucc,FPNULL);
            b.appendSucc(db);
            b.BC = BCgoto;
            b.Belem = doptelem(b.Belem,GOALnone | GOALagain);
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
    for (block *b = startblock; b; b = b.Bnext)   // for each block
    {
        foreach (bl; ListRange(b.Bsucc))
        {   /* For each transfer of control block pointer   */
            int iter = 0;

            block *bt = list_block(bl);

            /* If it is a transfer to a block that consists */
            /* of nothing but an unconditional transfer,    */
            /*      Replace transfer address with that      */
            /*      transfer address.                       */
            /* Note: There are certain kinds of infinite    */
            /* loops which we avoid by putting a lid on     */
            /* the number of iterations.                    */

            version (SCPP)
            {
                static if (NTEXCEPTIONS)
                    enum additionalAnd = "b.Btry == bt.Btry &&
                                      bt.Btry == bt.nthSucc(0).Btry";
                else
                    enum additionalAnd = "b.Btry == bt.Btry";
            }
            else static if (NTEXCEPTIONS)
                enum additionalAnd = "b.Btry == bt.Btry &&
                                  bt.Btry == bt.nthSucc(0).Btry";
            else
                enum additionalAnd = "true";

            while (bt.BC == BCgoto && !bt.Belem &&
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
            if (b.BC == BCasm)
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

            if (b.BC == BCiftrue || b.BC == BCiffalse)
            {
                block *bif = b.nthSucc(0);
                block *belse = b.nthSucc(1);

                if (bif == b.Bnext)
                {
                    b.BC ^= BCiffalse ^ BCiftrue;  /* toggle */
                    b.setNthSucc(0, belse);
                    b.setNthSucc(1, bif);
                    b.Bflags |= bif.Bflags & BFLvisited;
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

@trusted
void compdfo()
{
    compdfo(dfo, startblock);
}

@trusted
void compdfo(ref Barray!(block*) dfo, block* startblock)
{
    debug if (debugc) printf("compdfo()\n");
    assert(OPTIMIZER);
    block_clearvisit();
    debug assert(!PARSER);
    dfo.setLength(0);

    /******************************
     * Add b's successors to dfo[], then b
     */
    void walkDFO(block *b)
    {
        assert(b);
        b.Bflags |= BFLvisited;             // executed at least once

        foreach (bl; ListRange(b.Bsucc))   // for each successor
        {
            block *bs = list_block(bl);
            assert(bs);
            if ((bs.Bflags & BFLvisited) == 0) // if not visited
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

    static if(0)
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
private void elimblks()
{
    debug if (debugc) printf("elimblks()\n");
    block *bf = null;
    block *b;
    for (block **pb = &startblock; (b = *pb) != null;)
    {
        if (((b.Bflags & BFLvisited) == 0)   // if block is not visited
            && ((b.Bflags & BFLlabel) == 0)  // need label offset
            )
        {
            /* for each marked successor S to b                     */
            /*      remove b from S.Bpred.                          */
            /* Presumably all predecessors to b are unmarked also.  */
            foreach (s; ListRange(b.Bsucc))
            {
                assert(list_block(s));
                if (list_block(s).Bflags & BFLvisited) /* if it is marked */
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
    foreach (b; dfo[])
    {
        if (b.BC == BCgoto)
        {   block *bL2 = list_block(b.Bsucc);

            if (b == bL2)
            {
        Lcontinue:
                continue;
            }
            assert(bL2.Bpred);
            if (!list_next(bL2.Bpred) && bL2 != startblock)
            {
                if (b == bL2 || bL2.BC == BCasm)
                    continue;

                if (bL2.BC == BCtry ||
                    bL2.BC == BC_try ||
                    b.Btry != bL2.Btry)
                    continue;
                version (SCPP)
                {
                    // If any predecessors of b are BCasm, don't merge.
                    foreach (bl; ListRange(b.Bpred))
                    {
                        if (list_block(bl).BC == BCasm)
                            goto Lcontinue;
                    }
                }

                /* JOIN the elems               */
                elem *e = el_combine(b.Belem,bL2.Belem);
                if (b.Belem && bL2.Belem)
                    e = doptelem(e,bc_goal[bL2.BC] | GOALagain);
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
                            bs.ptr = cast(void *)bL2;
                }

                merge++;
                debug if (debugc) printf("block %p merged with %p\n",b,bL2);

                if (b == startblock)
                {   /* bL2 is the new startblock */
                    debug if (debugc) printf("bL2 is new startblock\n");
                    /* Remove bL2 from list of blocks   */
                    for (block **pb = &startblock; 1; pb = &(*pb).Bnext)
                    {
                        assert(*pb);
                        if (*pb == bL2)
                        {
                            *pb = bL2.Bnext;
                            break;
                        }
                    }

                    /* And relink bL2 at the start              */
                    bL2.Bnext = startblock.Bnext;
                    startblock = bL2;   // new start

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
private void blident()
{
    debug if (debugc) printf("blident()\n");
    assert(startblock);

    version (SCPP)
    {
        // Determine if any asm blocks
        int anyasm = 0;
        for (block *bn = startblock; bn; bn = bn.Bnext)
        {
            if (bn.BC == BCasm)
            {   anyasm = 1;
                break;
            }
        }
    }

    block *bnext;
    for (block *bn = startblock; bn; bn = bnext)
    {
        bnext = bn.Bnext;
        if (bn.Bflags & BFLnomerg)
            continue;

        for (block *b = bnext; b; b = b.Bnext)
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
            if (b.BC == bn.BC &&
                //(!OPTIMIZER || !(go.mfoptim & MFtime) || !b.Bsucc) &&
                (!OPTIMIZER || !(b.Bflags & BFLnomerg) || !b.Bsucc) &&
                list_equal(b.Bsucc,bn.Bsucc) &&
                additionalAnd &&
                el_match(b.Belem,bn.Belem)
               )
            {   /* Eliminate block bn           */
                switch (b.BC)
                {
                    case BCswitch:
                        if (memcmp(b.Bswitch,bn.Bswitch,list_nitems(bn.Bsucc) * (*bn.Bswitch).sizeof))
                            continue;
                        break;

                    case BCtry:
                    case BCcatch:
                    case BCjcatch:
                    case BC_try:
                    case BC_finally:
                    case BC_lpad:
                    case BCasm:
                    Lcontinue:
                        continue;

                    default:
                        break;
                }
                assert(!b.Bcode);

                foreach (bl; ListRange(bn.Bpred))
                {
                    block *bp = list_block(bl);
                    if (bp.BC == BCasm)
                        // Can't do this because of jmp's and loop's
                        goto Lcontinue;
                }

                static if(0) // && SCPP
                {
                    // Predecessors must all be at the same btry level.
                    if (bn.Bpred)
                    {
                        block *bp = list_block(bn.Bpred);
                        btry = bp.Btry;
                        if (bp.BC == BCtry)
                            btry = bp;
                    }
                    else
                        btry = null;

                    foreach (bl; ListRange(b.Bpred))
                    {
                        block *bp = list_block(bl);
                        if (bp.BC != BCtry)
                            bp = bp.Btry;
                        if (btry != bp)
                            goto Lcontinue;
                    }
                }

                // if bn is startblock, eliminate b instead of bn
                if (bn == startblock)
                {
                    goto Lcontinue;     // can't handle predecessors to startblock
                    // unreachable code
                    //bn = b;
                    //b = startblock;             /* swap b and bn        */
                }

                version (SCPP)
                {
                    // Don't do it if any predecessors are ASM blocks, since
                    // we'd have to walk the code list to fix up any jmps.
                    if (anyasm)
                    {
                        foreach (bl; ListRange(bn.Bpred))
                        {
                            block *bp = list_block(bl);
                            if (bp.BC == BCasm)
                                goto Lcontinue;
                            foreach (bls; ListRange(bp.Bsucc))
                                if (list_block(bls) == bn &&
                                    list_block(bls).BC == BCasm)
                                    goto Lcontinue;
                        }
                    }
                }

                /* Change successors to predecessors of bn to point to  */
                /* b instead of bn                                      */
                foreach (bl; ListRange(bn.Bpred))
                {
                    block *bp = list_block(bl);
                    foreach (bls; ListRange(bp.Bsucc))
                        if (list_block(bls) == bn)
                        {   bls.ptr = cast(void *)b;
                            list_prepend(&b.Bpred,bp);
                        }
                }

                /* Entirely remove predecessor list from bn.            */
                /* elimblks() will delete bn entirely.                  */
                list_free(&(bn.Bpred),FPNULL);

                debug
                {
                    assert(bn.BC != BCcatch);
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
private void blreturn()
{
    if (!(go.mfoptim & MFtime))            /* if optimized for space       */
    {
        int retcount = 0;               // number of return counts

        /* Find last return block       */
        for (block *b = startblock; b; b = b.Bnext)
        {
            if (b.BC == BCret)
                retcount++;
            if (b.BC == BCasm)
                return;                 // mucks up blident()
        }

        if (retcount < 2)               /* quit if nothing to combine   */
            return;

        /* Split return blocks  */
        for (block *b = startblock; b; b = b.Bnext)
        {
            if (b.BC != BCret)
                continue;
            static if (SCPP_OR_NTEXCEPTIONS)
            {
                // If no other blocks with the same Btry, don't split
                version (SCPP)
                {
                    auto ifCondition = config.flags3 & CFG3eh;
                }
                else
                {
                    enum ifCondition = true;
                }
                if (ifCondition)
                {
                    for (block *b2 = startblock; b2; b2 = b2.Bnext)
                    {
                        if (b2.BC == BCret && b != b2 && b.Btry == b2.Btry)
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

                block *bn = block_calloc();
                bn.BC = BCret;
                bn.Bnext = b.Bnext;
                static if(SCPP_OR_NTEXCEPTIONS)
                {
                    bn.Btry = b.Btry;
                }
                b.BC = BCgoto;
                b.Bnext = bn;
                list_append(&b.Bsucc,bn);
                list_append(&bn.Bpred,b);

                b = bn;
            }
        }

        blident();                      /* combine return blocks        */
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
            bl_enlist2(elems, e.EV.E1);
            bl_enlist2(elems, e.EV.E2);
            e.EV.E1 = e.EV.E2 = null;
            el_free(e);
        }
        else
            elems.push(e);
    }
}

@trusted
private list_t bl_enlist(elem *e)
{
    list_t el = null;

    if (e)
    {
        elem_debug(e);
        if (e.Eoper == OPcomma)
        {
            list_t el2 = bl_enlist(e.EV.E1);
            el = bl_enlist(e.EV.E2);
            e.EV.E1 = e.EV.E2 = null;
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
private elem * bl_delist(list_t el)
{
    elem *e = null;
    foreach (els; ListRange(el))
        e = el_combine(list_elem(els),e);
    list_free(&el,FPNULL);
    return e;
}

/*****************************************
 * Do tail merging.
 */

@trusted
private void bltailmerge()
{
    debug if (debugc) printf("bltailmerge()\n");
    assert(!PARSER && OPTIMIZER);
    if (!(go.mfoptim & MFtime))            /* if optimized for space       */
    {
        /* Split each block into a reversed linked list of elems        */
        for (block *b = startblock; b; b = b.Bnext)
            b.Blist = bl_enlist(b.Belem);

        /* Search for two blocks that have the same successor list.
           If the first expressions both lists are the same, split
           off a new block with that expression in it.
         */
        static if (SCPP_OR_NTEXCEPTIONS)
            enum additionalAnd = "b.Btry == bn.Btry";
        else
            enum additionalAnd = "true";
        for (block *b = startblock; b; b = b.Bnext)
        {
            if (!b.Blist)
                continue;
            elem *e = list_elem(b.Blist);
            elem_debug(e);
            for (block *bn = b.Bnext; bn; bn = bn.Bnext)
            {
                elem *en;
                if (b.BC == bn.BC &&
                    list_equal(b.Bsucc,bn.Bsucc) &&
                    bn.Blist &&
                    el_match(e,(en = list_elem(bn.Blist))) &&
                    mixin(additionalAnd)
                   )
                {
                    switch (b.BC)
                    {
                        case BCswitch:
                            if (memcmp(b.Bswitch,bn.Bswitch,list_nitems(bn.Bsucc) * (*bn.Bswitch).sizeof))
                                continue;
                            break;

                        case BCtry:
                        case BCcatch:
                        case BCjcatch:
                        case BC_try:
                        case BC_finally:
                        case BC_lpad:
                        case BCasm:
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

                    block *bnew = block_calloc();
                    bnew.Bnext = bn.Bnext;
                    bnew.BC = b.BC;
                    static if (SCPP_OR_NTEXCEPTIONS)
                    {
                        bnew.Btry = b.Btry;
                    }
                    if (bnew.BC == BCswitch)
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
                    b.BC = BCgoto;
                    bn.BC = BCgoto;
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
        for (block *b = startblock; b; b = b.Bnext)
            b.Belem = bl_delist(b.Blist);
    }
}

/**********************************
 * Rearrange blocks to minimize jmp's.
 */

@trusted
private void brmin()
{
    version (SCPP)
    {
        // Dunno how this may mess up generating EH tables.
        if (config.flags3 & CFG3eh)         // if EH turned on
            return;
    }

    debug if (debugc) printf("brmin()\n");
    debug assert(startblock);
    for (block *b = startblock.Bnext; b; b = b.Bnext)
    {
        block *bnext = b.Bnext;
        if (!bnext)
            break;
        foreach (bl; ListRange(b.Bsucc))
        {
            block *bs = list_block(bl);
            if (bs == bnext)
                goto L1;
        }

        // b is a block which does not have bnext as a successor.
        // Look for a successor of b for which everyone must jmp to.

        foreach (bl; ListRange(b.Bsucc))
        {
            block *bs = list_block(bl);
            block *bn;
            foreach (blp; ListRange(bs.Bpred))
            {
                block *bsp = list_block(blp);
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
    for (block *b = startblock; b; b = b.Bnext)
    {
        int nsucc = list_nitems(b.Bsucc);
        int npred = list_nitems(b.Bpred);
        switch (b.BC)
        {
            case BCgoto:
                assert(nsucc == 1);
                break;

            case BCiftrue:
                assert(nsucc == 2);
                break;
        }

        foreach (bl; ListRange(b.Bsucc))
        {
            block *bs = list_block(bl);

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
private void brtailrecursion()
{
    version (SCPP)
    {
    //    if (tyvariadic(funcsym_p.Stype))
            return;
        return;             // haven't dealt with struct params, and ctors/dtors
    }
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

    for (block *b = startblock; b; b = b.Bnext)
    {
        if (b.BC == BC_try)
            return;
        elem **pe = &b.Belem;
        block *bn = null;
        if (*pe &&
            (b.BC == BCret ||
             b.BC == BCretexp ||
             (b.BC == BCgoto && (bn = list_block(b.Bsucc)).Belem == null &&
              bn.BC == BCret)
            )
           )
        {
            if (el_anyframeptr(*pe))    // if any OPframeptr's
                return;

            static elem** skipCommas(elem** pe)
            {
                while ((*pe).Eoper == OPcomma)
                    pe = &(*pe).EV.E2;
                return pe;
            }

            pe = skipCommas(pe);

            elem *e = *pe;

            static bool isCandidate(elem* e)
            {
                e = *skipCommas(&e);
                if (e.Eoper == OPcond)
                    return isCandidate(e.EV.E2.EV.E1) || isCandidate(e.EV.E2.EV.E2);

                return OTcall(e.Eoper) &&
                       e.EV.E1.Eoper == OPvar &&
                       e.EV.E1.EV.Vsym == funcsym_p;
            }

            if (e.Eoper == OPcond &&
                (isCandidate(e.EV.E2.EV.E1) || isCandidate(e.EV.E2.EV.E2)))
            {
                /* Split OPcond into a BCiftrue block and two return blocks
                 */
                block* b1 = block_calloc();
                block* b2 = block_calloc();

                b1.Belem = e.EV.E2.EV.E1;
                e.EV.E2.EV.E1 = null;

                b2.Belem = e.EV.E2.EV.E2;
                e.EV.E2.EV.E2 = null;

                *pe = e.EV.E1;
                e.EV.E1 = null;
                el_free(e);

                if (b.BC == BCgoto)
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

                b1.BC = b.BC;
                b2.BC = b.BC;
                b.BC = BCiftrue;

                b2.Bnext = b.Bnext;
                b1.Bnext = b2;
                b.Bnext = b1;
                continue;
            }

            if (OTcall(e.Eoper) &&
                e.EV.E1.Eoper == OPvar &&
                e.EV.E1.EV.Vsym == funcsym_p)
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
                    elem *e2 = null;
                    *pe = assignparams(&e.EV.E2,&si,&e2);
                    *pe = el_combine(*pe,e2);
                }
                el_free(e);
                //printf("after:\n");
                //elem_print(*pe);

                if (b.BC == BCgoto)
                {
                    list_subtract(&b.Bsucc,bn);
                    list_subtract(&bn.Bpred,b);
                }
                b.BC = BCgoto;
                list_append(&b.Bsucc,startblock);
                list_append(&startblock.Bpred,b);

                // Create a new startblock, bs, because startblock cannot
                // have predecessors.
                block *bs = block_calloc();
                bs.BC = BCgoto;
                bs.Bnext = startblock;
                list_append(&bs.Bsucc,startblock);
                list_append(&startblock.Bpred,bs);
                startblock = bs;

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
private elem * assignparams(elem **pe,int *psi,elem **pe2)
{
    elem *e = *pe;

        if (e.Eoper == OPparam)
    {
        elem *ea = null;
        elem *eb = null;
        elem *e2 = assignparams(&e.EV.E2,psi,&eb);
        elem *e1 = assignparams(&e.EV.E1,psi,&ea);
        e.EV.E1 = null;
        e.EV.E2 = null;
        e = el_combine(e1,e2);
        *pe2 = el_combine(eb,ea);
    }
    else
    {
        int si = *psi;
        type *t;

        assert(si < globsym.length);
        Symbol *sp = globsym[si];
        Symbol *s = symbol_genauto(sp.Stype);
        s.Sfl = FLauto;
        int op = OPeq;
        if (e.Eoper == OPstrpar)
        {
            op = OPstreq;
            t = e.ET;
            elem *ex = e;
            e = e.EV.E1;
            ex.EV.E1 = null;
            el_free(ex);
        }
        elem *es = el_var(s);
        es.Ety = e.Ety;
        e = el_bin(op,TYvoid,es,e);
        if (op == OPstreq)
            e.ET = t;
        *pe2 = el_bin(op,TYvoid,el_var(sp),el_copytree(es));
        (*pe2).EV.E1.Ety = es.Ety;
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
private void emptyloops()
{
    debug if (debugc) printf("emptyloops()\n");
    for (block *b = startblock; b; b = b.Bnext)
    {
        if (b.BC == BCiftrue &&
            list_block(b.Bsucc) == b &&
            list_nitems(b.Bpred) == 2)
        {
            // Find predecessor to b
            block *bpred = list_block(b.Bpred);
            if (bpred == b)
                bpred = list_block(list_next(b.Bpred));
            if (!bpred.Belem)
                continue;

            // Find einit
            elem *einit;
            for (einit = bpred.Belem; einit.Eoper == OPcomma; einit = einit.EV.E2)
            { }
            if (einit.Eoper != OPeq ||
                einit.EV.E2.Eoper != OPconst ||
                einit.EV.E1.Eoper != OPvar)
                continue;

            // Look for ((i += 1) < limit)
            elem *erel = b.Belem;
            if (erel.Eoper != OPlt ||
                erel.EV.E2.Eoper != OPconst ||
                erel.EV.E1.Eoper != OPaddass)
                continue;

            elem *einc = erel.EV.E1;
            if (einc.EV.E2.Eoper != OPconst ||
                einc.EV.E1.Eoper != OPvar ||
                !el_match(einc.EV.E1,einit.EV.E1))
                continue;

            if (!tyintegral(einit.EV.E1.Ety) ||
                el_tolong(einc.EV.E2) != 1 ||
                el_tolong(einit.EV.E2) >= el_tolong(erel.EV.E2)
               )
                continue;

             {
                erel.Eoper = OPeq;
                erel.Ety = erel.EV.E1.Ety;
                erel.EV.E1 = el_selecte1(erel.EV.E1);
                b.BC = BCgoto;
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
void funcsideeffects()
{
    version (MARS)
    {
        //printf("funcsideeffects('%s')\n",funcsym_p.Sident);
        for (block *b = startblock; b; b = b.Bnext)
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
}

version (MARS)
{

@trusted
private int funcsideeffect_walk(elem *e)
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
            Symbol *s;
            if (e.EV.E1.Eoper == OPvar &&
                tyfunc((s = e.EV.E1.EV.Vsym).Stype.Tty) &&
                ((s.Sfunc && s.Sfunc.Fflags3 & Fnosideeff) || s == funcsym_p)
               )
                break;
            goto Lside;

        // Note: we should allow assignments to local variables as
        // not being a 'side effect'.

        default:
            assert(op < OPMAX);
            return OTsideff(op) ||
                (OTunary(op) && funcsideeffect_walk(e.EV.E1)) ||
                (OTbinary(op) && (funcsideeffect_walk(e.EV.E1) ||
                                  funcsideeffect_walk(e.EV.E2)));
    }
    return 0;

  Lside:
    return 1;
}

}

/*******************************
 * Determine if there are any OPframeptr's in the tree.
 */

@trusted
private int el_anyframeptr(elem *e)
{
    while (1)
    {
        if (OTunary(e.Eoper))
            e = e.EV.E1;
        else if (OTbinary(e.Eoper))
        {
            if (el_anyframeptr(e.EV.E2))
                return 1;
            e = e.EV.E1;
        }
        else if (e.Eoper == OPframeptr)
            return 1;
        else
            break;
    }
    return 0;
}


/**************************************
 * Split off asserts into their very own BCexit
 * blocks after the end of the function.
 * This is because assert calls are never in a hot branch.
 */

@trusted
private void blassertsplit()
{
    debug if (debugc) printf("blassertsplit()\n");
    Barray!(elem*) elems;
    for (block *b = startblock; b; b = b.Bnext)
    {
        /* Not sure of effect of jumping out of a try block
         */
        if (b.Btry)
            continue;

        if (b.BC == BCexit)
            continue;

        elems.reset();
        bl_enlist2(elems, b.Belem);
        auto earray = elems[];
    L1:
        int dctor = 0;

        int accumDctor(elem *e)
        {
            while (1)
            {
                if (OTunary(e.Eoper))
                {
                    e = e.EV.E1;
                    continue;
                }
                else if (OTbinary(e.Eoper))
                {
                    accumDctor(e.EV.E1);
                    e = e.EV.E2;
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
                e.Eoper == OPoror && e.EV.E2.Eoper == OPcall && e.EV.E2.EV.E1.Eoper == OPvar))
            {
                accumDctor(e);
                continue;
            }
            Symbol *f = e.EV.E2.EV.E1.EV.Vsym;
            if (!(f.Sflags & SFLexit))
            {
                accumDctor(e);
                continue;
            }

            if (accumDctor(e.EV.E1))
            {
                accumDctor(e.EV.E2);
                continue;
            }

            // Create exit block
            block *bexit = block_calloc();
            bexit.BC = BCexit;
            bexit.Belem = e.EV.E2;

            /* Append bexit to block list
             */
            for (block *bx = b; 1; )
            {
                block* bxn = bx.Bnext;
                if (!bxn)
                {
                    bx.Bnext = bexit;
                    break;
                }
                bx = bxn;
            }

            earray[i] = e.EV.E1;
            e.EV.E1 = null;
            e.EV.E2 = null;
            el_free(e);

            /* Split b into two blocks, [b,b2]
             */
            block *b2 = block_calloc();
            b2.Bnext = b.Bnext;
            b.Bnext = b2;
            b2.BC = b.BC;
            b2.BS = b.BS;

            b.Belem = bl_delist2(earray[0 .. i + 1]);

            /* Transfer successors of b to b2.
             * Fix up predecessors of successors to b2 to point to b2 instead of b
             */
            b2.Bsucc = b.Bsucc;
            b.Bsucc = null;
            foreach (b2sl; ListRange(b2.Bsucc))
            {
                block *b2s = list_block(b2sl);
                foreach (b2spl; ListRange(b2s.Bpred))
                {
                    if (list_block(b2spl) == b)
                        b2spl.ptr = cast(void *)b2;
                }
            }

            b.BC = BCiftrue;
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
        if (b.BC == BCretexp && !b.Belem)
            b.Belem = el_long(TYint, 1);

    }
    elems.dtor();
}

/*************************************************
 * Detect exit blocks and move them to the end.
 */
@trusted
private void blexit()
{
    debug if (debugc) printf("blexit()\n");

    Barray!(block*) bexits;
    for (block *b = startblock; b; b = b.Bnext)
    {
        /* Not sure of effect of jumping out of a try block
         */
        if (b.Btry)
            continue;

        if (b.BC == BCexit)
            continue;

        if (!b.Belem || el_returns(b.Belem))
            continue;

        b.BC = BCexit;

        foreach (bsl; ListRange(b.Bsucc))
        {
            block *bs = list_block(bsl);
            list_subtract(&bs.Bpred, b);
        }
        list_free(&b.Bsucc, FPNULL);

        if (b != startblock && b.Bnext)
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
    block** pb = &startblock.Bnext;
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

} //!SPP
