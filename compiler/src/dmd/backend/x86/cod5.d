/**
 * Code generation 5
 *
 * Handles finding out which blocks need a function prolog / epilog attached
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1995-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/x86/cod5.d, backend/cod5.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_x86_cod5.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/x86/cod5.d
 */
module dmd.backend.x86.cod5;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.time;
import dmd.backend.cc;
import dmd.backend.el;
import dmd.backend.oper;
import dmd.backend.code;
import dmd.backend.global;
import dmd.backend.type;

import dmd.backend.cdef;
import dmd.backend.dlist;
import dmd.backend.ty;

nothrow:
@safe:


/********************************************************
 * Determine which blocks get the function prolog and epilog
 * attached to them.
 */
void cod5_prol_epi(block* startblock)
{
static if(1)
{
    cod5_noprol(startblock);
}
else
{
    tym_t tym;
    tym_t tyf;
    block* b;
    block* bp;
    int nepis;

    tyf = funcsym_p.ty();
    tym = tybasic(tyf);

    if (!(config.flags4 & CFG4optimized) ||
        cgstate.anyiasm ||
        cgstate.Alloca.size ||
        cgstate.usednteh ||
        cgstate.calledFinally ||
        tyf & (mTYnaked | mTYloadds) ||
        tym == TYifunc ||
        tym == TYmfunc ||       // can't yet handle ECX passed as parameter
        tym == TYjfunc ||       // can't yet handle EAX passed as parameter
        config.flags & (CFGalwaysframe | CFGtrace) ||
//      config.fulltypes ||
        (config.wflags & WFwindows && tyfarfunc(tym)) ||
        need_prolog(startblock)
       )
    {   // First block gets the prolog, all return blocks
        // get the epilog.
        //printf("not even a candidate\n");
        cod5_noprol();
        return;
    }

    // Turn on BFL.outsideprolog for all blocks outside the ones needing the prolog.

    for (b = startblock; b; b = b.Bnext)
        b.Bflags &= ~BFL.outsideprolog;                 // start with them all off

    pe_add(startblock);

    // Look for only one block (bp) that will hold the prolog
    bp = null;
    nepis = 0;
    for (b = startblock; b; b = b.Bnext)
    {   int mark;

        if (b.Bflags & BFL.outsideprolog)
            continue;

        // If all predecessors are marked
        mark = 0;
        assert(b.Bpred);
        foreach (bl; ListRange(b.Bpred))
        {
            if (list_block(bl).Bflags & BFL.outsideprolog)
            {
                if (mark == 2)
                    goto L1;
                mark = 1;
            }
            else
            {
                if (mark == 1)
                    goto L1;
                mark = 2;
            }
        }
        if (mark == 1)
        {
            if (bp)             // if already have one
                goto L1;
            bp = b;
        }

        // See if b is an epilog
        mark = 0;
        foreach (bl; ListRange(b.Bsucc))
        {
            if (list_block(bl).Bflags & BFL.outsideprolog)
            {
                if (mark == 2)
                    goto L1;
                mark = 1;
            }
            else
            {
                if (mark == 1)
                    goto L1;
                mark = 2;
            }
        }
        if (mark == 1 || b.bc == BC.ret || b.bc == BC.retexp)
        {   b.Bflags |= BFL.epilog;
            nepis++;
            if (nepis > 1 && config.flags4 & CFG4space)
                goto L1;
        }
    }
    if (bp)
    {   bp.Bflags |= BFL.prolog;
        //printf("=============== prolog opt\n");
    }
}
}

/**********************************************
 * No prolog/epilog optimization.
 */
void cod5_noprol(block* startblock)
{
    block* b;

    //printf("no prolog optimization\n");
    startblock.Bflags |= BFL.prolog;
    for (b = startblock; b; b = b.Bnext)
    {
        b.Bflags = cast(BFL)(b.Bflags & ~cast(uint)BFL.outsideprolog);
        switch (b.bc)
        {   case BC.ret:
            case BC.retexp:
                b.Bflags |= BFL.epilog;
                break;
            default:
                b.Bflags = cast(BFL)(b.Bflags & ~cast(uint)BFL.epilog);
        }
    }
}

/*********************************************
 * Add block b, and its successors, to those blocks outside those requiring
 * the function prolog.
 */

private void pe_add(block* b)
{
    if (b.Bflags & BFL.outsideprolog ||
        need_prolog(b))
        return;

    b.Bflags |= BFL.outsideprolog;
    foreach (bl; ListRange(b.Bsucc))
        pe_add(list_block(bl));
}

/**********************************************
 * Determine if block needs the function prolog to be set up.
 */

@trusted
private int need_prolog(block* b)
{
    if (b.Bregcon.used & fregsaved)
        goto Lneed;

    // If block referenced a param in 16 bit code
    if (!I32 && b.Bflags & BFL.refparam)
        goto Lneed;

    // If block referenced a stack local
    if (b.Bflags & BFL.reflocal)
        goto Lneed;

    return 0;

Lneed:
    return 1;
}
