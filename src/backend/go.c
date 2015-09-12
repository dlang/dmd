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

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <time.h>

#include        "cc.h"
#include        "global.h"
#include        "oper.h"
#include        "el.h"
#include        "go.h"
#include        "type.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/****************************
 * Terminate use of globals.
 */

void go_term()
{
    vec_free(go.defkill);
    vec_free(go.starkill);
    vec_free(go.vptrkill);
    util_free(go.expnod);
    util_free(go.expblk);
    util_free(go.defnod);
}

#if DEBUG
                        // to print progress message and current trees set to
                        // DEBUG_TREES to 1 and uncomment next 2 lines
#define DEBUG_TREES 0
#if DEBUG_TREES
void dbg_optprint(char *);
#else
                        // to print progress message, undo comment
#define dbg_optprint(c) // dbg_printf(c)
#endif
#else
#define dbg_optprint(c)
#endif

/**************************************
 * Parse optimizer command line flag.
 * Input:
 *      cp      flag string
 * Returns:
 *      0       not recognized
 *      !=0     recognized
 */

int go_flag(char *cp)
{   unsigned i;
    unsigned flag;

    enum GL     // indices of various flags in flagtab[]
    {
        GLO,GLall,GLcnp,GLcp,GLcse,GLda,GLdc,GLdv,GLli,GLliv,GLlocal,GLloop,
        GLnone,GLo,GLreg,GLspace,GLspeed,GLtime,GLtree,GLvbe,GLMAX
    };
    static const char *flagtab[] =
    {   "O","all","cnp","cp","cse","da","dc","dv","li","liv","local","loop",
        "none","o","reg","space","speed","time","tree","vbe"
    };
    static mftype flagmftab[] =
    {   0,MFall,MFcnp,MFcp,MFcse,MFda,MFdc,MFdv,MFli,MFliv,MFlocal,MFloop,
        0,0,MFreg,0,MFtime,MFtime,MFtree,MFvbe
    };

    i = GLMAX;
    assert(i == arraysize(flagtab));
    assert(i == arraysize(flagmftab));

    //printf("go_flag('%s')\n", cp);
    flag = binary(cp + 1,flagtab,GLMAX);
    if (mfoptim == 0 && flag != -1)
        mfoptim = MFall & ~MFvbe;

    if (*cp == '-')                     /* a regular -whatever flag     */
    {                                   /* cp -> flag string            */
        switch (flag)
        {
            case GLall:
            case GLcnp:
            case GLcp:
            case GLdc:
            case GLda:
            case GLdv:
            case GLcse:
            case GLli:
            case GLliv:
            case GLlocal:
            case GLloop:
            case GLreg:
            case GLspeed:
            case GLtime:
            case GLtree:
            case GLvbe:
                mfoptim &= ~flagmftab[flag];    /* clear bits   */
                break;
            case GLo:
            case GLO:
            case GLnone:
                mfoptim |= MFall & ~MFvbe;      // inverse of -all
                break;
            case GLspace:
                mfoptim |= MFtime;      /* inverse of -time     */
                break;
            case -1:                    /* not in flagtab[]     */
                goto badflag;
            default:
                assert(0);
        }
    }
    else if (*cp == '+')                /* a regular +whatever flag     */
    {                           /* cp -> flag string            */
        switch (flag)
        {
            case GLall:
            case GLcnp:
            case GLcp:
            case GLdc:
            case GLda:
            case GLdv:
            case GLcse:
            case GLli:
            case GLliv:
            case GLlocal:
            case GLloop:
            case GLreg:
            case GLspeed:
            case GLtime:
            case GLtree:
            case GLvbe:
                mfoptim |= flagmftab[flag];     /* set bits     */
                break;
            case GLnone:
                mfoptim &= ~MFall;      /* inverse of +all      */
                break;
            case GLspace:
                mfoptim &= ~MFtime;     /* inverse of +time     */
                break;
            case -1:                    /* not in flagtab[]     */
                goto badflag;
            default:
                assert(0);
        }
    }
    if (mfoptim)
    {
        mfoptim |= MFtree | MFdc;       // always do at least this much
        config.flags4 |= (mfoptim & MFtime) ? CFG4speed : CFG4space;
    }
    else
    {
        config.flags4 &= ~CFG4optimized;
    }
    return 1;                   // recognized

badflag:
    return 0;
}

#if DEBUG_TREES
void dbg_optprint(char *title)
{
    block *b;
    for (b = startblock; b; b = b->Bnext)
        if (b->Belem)
        {
            dbg_printf("%s\n",title);
            elem_print(b->Belem);
        }
}
#endif

/****************************
 * Optimize function.
 */

void optfunc()
{
#if !HTOD
    block *b;
    int iter;           // iteration count
    clock_t starttime;

    cmes ("optfunc()\n");
    dbg_optprint("optfunc\n");
#ifdef DEBUG
    if (debugb)
    {
        dbg_printf("................Before optimization.........\n");
        WRfunc();
    }
#endif
    iter = 0;

    if (localgot)
    {   // Initialize with:
        //      localgot = OPgot;
        elem *e = el_long(TYnptr, 0);
        e->Eoper = OPgot;
        e = el_bin(OPeq, TYnptr, el_var(localgot), e);
        startblock->Belem = el_combine(e, startblock->Belem);
    }

    // Each pass through the loop can reduce only one level of comma expression.
    // The infinite loop check needs to take this into account.
    // Add 100 just to give optimizer more rope to try to converge.
    int iterationLimit = 0;
    for (b = startblock; b; b = b->Bnext)
    {
        if (!b->Belem)
            continue;
        int d = el_countCommas(b->Belem) + 100;
        if (d > iterationLimit)
            iterationLimit = d;
    }

    // Some functions can take enormous amounts of time to optimize.
    // We try to put a lid on it.
    starttime = clock();
    do
    {
        //printf("iter = %d\n", iter);
        if (++iter > 200)
        {   assert(iter < iterationLimit);      // infinite loop check
            break;
        }
#if MARS
        util_progress();
#else
        file_progress();
#endif

        //printf("optelem\n");
        /* canonicalize the trees        */
        for (b = startblock; b; b = b->Bnext)
            if (b->Belem)
            {
#if DEBUG
                if(debuge)
                {
                    dbg_printf("before\n");
                    elem_print(b->Belem);
                    //el_check(b->Belem);
                }
#endif
                b->Belem = doptelem(b->Belem,bc_goal[b->BC] | GOALagain);
#if DEBUG
                if(0 && debugf)
                {
                    dbg_printf("after\n");
                    elem_print(b->Belem);
                }
#endif
            }
        //printf("blockopt\n");
        if (mfoptim & MFdc)
            blockopt(0);                // do block optimization
        out_regcand(&globsym);          // recompute register candidates
        changes = 0;                    /* no changes yet                */
        if (mfoptim & MFcnp)
            constprop();                /* make relationals unsigned     */
        if (mfoptim & (MFli | MFliv))
            loopopt();                  /* remove loop invariants and    */
                                        /* induction vars                */
                                        /* do loop rotation              */
        else
            for (b = startblock; b; b = b->Bnext)
                b->Bweight = 1;
        dbg_optprint("boolopt\n");

        if (mfoptim & MFcnp)
            boolopt();                  // optimize boolean values
        if (changes && mfoptim & MFloop && (clock() - starttime) < 30 * CLOCKS_PER_SEC)
            continue;

        if (mfoptim & MFcnp)
            constprop();                /* constant propagation          */
        if (mfoptim & MFcp)
            copyprop();                 /* do copy propagation           */

        /* Floating point constants and string literals need to be
         * replaced with loads from variables in read-only data.
         * This can result in localgot getting needed.
         */
        symbol *localgotsave = localgot;
        for (b = startblock; b; b = b->Bnext)
        {
            if (b->Belem)
            {
                b->Belem = doptelem(b->Belem,bc_goal[b->BC] | GOALstruct);
                if (b->Belem)
                    b->Belem = el_convert(b->Belem);
            }
        }
        if (localgot != localgotsave)
        {   /* Looks like we did need localgot, initialize with:
             *  localgot = OPgot;
             */
            elem *e = el_long(TYnptr, 0);
            e->Eoper = OPgot;
            e = el_bin(OPeq, TYnptr, el_var(localgot), e);
            startblock->Belem = el_combine(e, startblock->Belem);
        }

        /* localize() is after localgot, otherwise we wind up with
         * more than one OPgot in a function, which mucks up OSX
         * code generation which assumes at most one (localgotoffset).
         */
        if (mfoptim & MFlocal)
            localize();                 // improve expression locality
        if (mfoptim & MFda)
            rmdeadass();                /* remove dead assignments       */

        cmes2 ("changes = %d\n", changes);
        if (!(changes && mfoptim & MFloop && (clock() - starttime) < 30 * CLOCKS_PER_SEC))
            break;
    } while (1);
    cmes2("%d iterations\n",iter);
    if (mfoptim & MFdc)
        blockopt(1);                    // do block optimization

    for (b = startblock; b; b = b->Bnext)
    {
        if (b->Belem)
            postoptelem(b->Belem);
    }
    if (mfoptim & MFvbe)
        verybusyexp();              /* very busy expressions         */
    if (mfoptim & MFcse)
        builddags();                /* common subexpressions         */
    if (mfoptim & MFdv)
        deadvar();                  /* eliminate dead variables      */

#ifdef DEBUG
    if (debugb)
    {
        dbg_printf(".............After optimization...........\n");
        WRfunc();
    }
#endif

    // Prepare for code generator
    for (b = startblock; b; b = b->Bnext)
    {
        block_optimizer_free(b);
    }
#endif
}

#endif // !SPP
