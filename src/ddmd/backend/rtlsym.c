/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1996-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/rtlsym.c
 */

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <time.h>
#include        "cc.h"
#include        "type.h"
#include        "oper.h"
#include        "global.h"
#include        "code.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

Symbol *rtlsym[RTLSYM_MAX];

#if MARS
// This varies depending on C ABI
#define FREGSAVED       fregsaved
#else
#define FREGSAVED       (mBP | mBX | mSI | mDI)
#endif

// Helper function for rtlsym_init()

static Symbol *symbolz(const char *name, type *t, int fl, SYMFLGS flags, regm_t regsaved)
{
    Symbol *s = symbol_calloc(name);
    s->Stype = t;
    s->Ssymnum = -1;
    s->Sclass = SCextern;
    s->Sfl = fl;
    s->Sregsaved = regsaved;
    s->Sflags = flags;
    return s;
}

/******************************************
 * Initialize rtl symbols.
 */

void rtlsym_init()
{
    static int inited;

    if (!inited)
    {   inited++;

        //printf("rtlsym_init(%s)\n", regm_str(FREGSAVED));

#if MARS
        type *t = type_fake(TYnfunc);
        t->Tmangle = mTYman_c;
        t->Tcount++;

        // Variadic function
        type *tv = type_fake(TYnfunc);
        tv->Tmangle = mTYman_c;
        tv->Tcount++;
#endif

        // Only used by dmd1 for RTLSYM_THROW
        type *tw = NULL;

#undef SYMBOL_Z
#define SYMBOL_Z(e, fl, regsaved, n, flags, t) \
        rtlsym[RTLSYM_##e] = symbolz(n, t, fl, flags, regsaved);

        RTLSYMS
    }
}

/*******************************
 * Reset the symbols for the case when we are generating multiple
 * .OBJ files from one compile.
 */
#if MARS

void rtlsym_reset()
{
    clib_inited = 0;            // reset CLIB symbols, too
    for (size_t i = 0; i < RTLSYM_MAX; i++)
    {
        rtlsym[i]->Sxtrnnum = 0;
        rtlsym[i]->Stypidx = 0;
    }
}

#endif

/*******************************
 */

void rtlsym_term()
{
}

#endif
