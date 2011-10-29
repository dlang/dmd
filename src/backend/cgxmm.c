// Copyright (C) 2011-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * or /dm/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <time.h>
#include        "cc.h"
#include        "oper.h"
#include        "el.h"
#include        "code.h"
#include        "global.h"
#include        "type.h"
#if SCPP
#include        "exh.h"
#endif

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/***********************************************
 * Do simple orthogonal operators for XMM registers.
 */

code *orthxmm(elem *e, regm_t *pretregs)
{   elem *e1 = e->E1;
    elem *e2 = e->E2;
    tym_t ty1 = tybasic(e1->Ety);
    unsigned sz1 = tysize[ty1];
    assert(sz1 == 4 || sz1 == 8);       // float or double
    regm_t retregs = *pretregs & XMMREGS;
    code *c = codelem(e1,&retregs,FALSE); // eval left leaf
    unsigned reg = findreg(retregs);
    regm_t rretregs = XMMREGS & ~retregs;
    code *cr = scodelem(e2, &rretregs, retregs, TRUE);  // eval right leaf
    unsigned rreg = findreg(rretregs);
    code *cg = getregs(retregs);
    unsigned op;
    switch (e->Eoper)
    {
        case OPadd:
            op = 0xF20F58;                      // ADDSD
            if (sz1 == 4)                       // float
                op = 0xF30F58;                  // ADDSS
            break;

        case OPmin:
            op = 0xF20F5C;                      // SUBSD
            if (sz1 == 4)                       // float
                op = 0xF30F5C;                  // SUBSS
            break;

        case OPmul:
            op = 0xF20F59;                      // MULSD
            if (sz1 == 4)                       // float
                op = 0xF30F59;                  // MULSS
            break;

        case OPdiv:
            op = 0xF20F5E;                      // DIVSD
            if (sz1 == 4)                       // float
                op = 0xF30F5E;                  // DIVSS
            break;

        default:
            assert(0);
    }
    code *co = gen2(CNIL,op,modregrm(3,reg-XMM0,rreg-XMM0));
    co = cat(co,fixresult(e,retregs,pretregs));
    return cat4(c,cr,cg,co);
}


#endif // !SPP
