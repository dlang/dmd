// Copyright (C) 1996-1998 by Symantec
// Copyright (C) 2000-2010 by Digital Mars
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

static Symbol rtlsym2[RTLSYM_MAX];

/******************************************
 * Initialize rtl symbols.
 */

void rtlsym_init()
{
    static int inited;

    if (!inited)
    {   inited++;

        //printf("rtlsym_init(%s)\n", regm_str(FREGSAVED));

        for (int i = 0; i < RTLSYM_MAX; i++)
        {
            rtlsym[i] = &rtlsym2[i];
#ifdef DEBUG
            rtlsym[i]->id = IDsymbol;
#endif
            rtlsym[i]->Stype = tsclib;
            rtlsym[i]->Ssymnum = -1;
            rtlsym[i]->Sclass = SCextern;
            rtlsym[i]->Sfl = FLfunc;
#if ELFOBJ || MACHOBJ
            rtlsym[i]->obj_si = (unsigned)-1;
            rtlsym[i]->dwarf_off = (unsigned)-1;
#endif
            rtlsym[i]->Sregsaved = FREGSAVED;
        }

#if MARS
        type *t = type_fake(TYnfunc);
        t->Tmangle = mTYman_c;
        t->Tcount++;

        // Variadic function
        type *tv = type_fake(TYnfunc);
        tv->Tmangle = mTYman_c;
        tv->Tcount++;
#endif

        // Only used by dmd1 for RTLSYM_THROWC
        type *tw = NULL;

#undef SYMBOL_Z
#define SYMBOL_Z(e, fl, saved, n, flags, ty)                                \
        if (ty) rtlsym[RTLSYM_##e]->Stype = (ty);                           \
        if ((fl) != FLfunc) rtlsym[RTLSYM_##e]->Sfl = (fl);                 \
        if (flags) rtlsym[RTLSYM_##e]->Sflags = (flags);                    \
        if ((saved) != FREGSAVED) rtlsym[RTLSYM_##e]->Sregsaved = (saved);  \
        strcpy(rtlsym[RTLSYM_##e]->Sident, (n));                            \

        RTLSYMS
    }
}

/*******************************
 * Reset the symbols for the case when we are generating multiple
 * .OBJ files from one compile.
 */

#if MARS

void rtlsym_reset()
{   int i;

    clib_inited = 0;
    for (i = 0; i < RTLSYM_MAX; i++)
    {   rtlsym[i]->Sxtrnnum = 0;
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
