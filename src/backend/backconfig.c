// Copyright (C) 2000-2013 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

// Configure the back end (optimizer and code generator)

#include        <stdio.h>
#include        <ctype.h>
#include        <string.h>
#include        <stdlib.h>
#include        <time.h>

#include        "cc.h"
#include        "global.h"
#include        "oper.h"
#include        "code.h"
#include        "type.h"
#include        "dt.h"
#include        "cgcv.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

#if MARS
extern void ph_init();
#endif

/**************************************
 * Initialize configuration variables.
 */

void out_config_init(
        int model,      // 32: 32 bit code
                        // 64: 64 bit code
                        // Windows: set bit 0 to generate MS-COFF instead of OMF
        bool exe,       // true: exe file
                        // false: dll or shared library (generate PIC code)
        bool trace,     // add profiling code
        bool nofloat,   // do not pull in floating point code
        bool verbose,   // verbose compile
        bool optimize,  // optimize code
        int symdebug,   // add symbolic debug information
                        // 1: D
                        // 2: fake it with C symbolic debug info
        bool alwaysframe,       // always create standard function frame
        bool stackstomp         // add stack stomping code
        )
{
#if MARS
    //printf("out_config_init()\n");

    if (!config.target_cpu)
    {   config.target_cpu = TARGET_PentiumPro;
        config.target_scheduler = config.target_cpu;
    }
    config.fulltypes = CVNONE;
    config.fpxmmregs = FALSE;
    config.inline8087 = 1;
    config.memmodel = 0;
    config.flags |= CFGuchar;   // make sure TYchar is unsigned
    tytab[TYchar] |= TYFLuns;
    bool mscoff = model & 1;
    model &= 32 | 64;
#if TARGET_WINDOS
    if (model == 64)
    {   config.exe = EX_WIN64;
        config.fpxmmregs = TRUE;

        // Not sure we really need these two lines, try removing them later
        config.flags |= CFGnoebp;
        config.flags |= CFGalwaysframe;
        config.flags |= CFGromable; // put switch tables in code segment
        config.objfmt = OBJ_MSCOFF;
    }
    else
    {   config.exe = EX_NT;
        config.flags2 |= CFG2seh;       // Win32 eh
        config.objfmt = mscoff ? OBJ_MSCOFF : OBJ_OMF;
    }

    if (exe)
        config.wflags |= WFexe;         // EXE file only optimizations
    config.flags4 |= CFG4underscore;
#endif
#if TARGET_LINUX
    if (model == 64)
    {   config.exe = EX_LINUX64;
        config.fpxmmregs = TRUE;
    }
    else
    {
        config.exe = EX_LINUX;
        if (!exe)
            config.flags |= CFGromable; // put switch tables in code segment
    }
    config.flags |= CFGnoebp;
    config.flags |= CFGalwaysframe;
    if (!exe)
        config.flags3 |= CFG3pic;
    config.objfmt = OBJ_ELF;
#endif
#if TARGET_OSX
    config.fpxmmregs = TRUE;
    if (model == 64)
    {   config.exe = EX_OSX64;
        config.fpxmmregs = TRUE;
    }
    else
        config.exe = EX_OSX;
    config.flags |= CFGnoebp;
    config.flags |= CFGalwaysframe;
    if (!exe)
        config.flags3 |= CFG3pic;
    config.flags |= CFGromable; // put switch tables in code segment
    config.objfmt = OBJ_MACH;
#endif
#if TARGET_FREEBSD
    if (model == 64)
    {   config.exe = EX_FREEBSD64;
        config.fpxmmregs = TRUE;
    }
    else
    {
        config.exe = EX_FREEBSD;
        if (!exe)
            config.flags |= CFGromable; // put switch tables in code segment
    }
    config.flags |= CFGnoebp;
    config.flags |= CFGalwaysframe;
    if (!exe)
        config.flags3 |= CFG3pic;
    config.objfmt = OBJ_ELF;
#endif
#if TARGET_OPENBSD
    if (model == 64)
    {   config.exe = EX_OPENBSD64;
        config.fpxmmregs = TRUE;
    }
    else
    {
        config.exe = EX_OPENBSD;
        if (!exe)
            config.flags |= CFGromable; // put switch tables in code segment
    }
    config.flags |= CFGnoebp;
    config.flags |= CFGalwaysframe;
    if (!exe)
        config.flags3 |= CFG3pic;
    config.objfmt = OBJ_ELF;
#endif
#if TARGET_SOLARIS
    if (model == 64)
    {   config.exe = EX_SOLARIS64;
        config.fpxmmregs = TRUE;
    }
    else
    {
        config.exe = EX_SOLARIS;
        if (!exe)
            config.flags |= CFGromable; // put switch tables in code segment
    }
    config.flags |= CFGnoebp;
    config.flags |= CFGalwaysframe;
    if (!exe)
        config.flags3 |= CFG3pic;
    config.objfmt = OBJ_ELF;
#endif
    config.flags2 |= CFG2nodeflib;      // no default library
    config.flags3 |= CFG3eseqds;
#if 0
    if (env->getEEcontext()->EEcompile != 2)
        config.flags4 |= CFG4allcomdat;
    if (env->nochecks())
        config.flags4 |= CFG4nochecks;  // no runtime checking
#elif TARGET_OSX
#else
    config.flags4 |= CFG4allcomdat;
#endif
    if (trace)
        config.flags |= CFGtrace;       // turn on profiler
    if (nofloat)
        config.flags3 |= CFG3wkfloat;

    configv.verbose = verbose;

    if (optimize)
        go_flag((char *)"-o");

    if (symdebug)
    {
#if SYMDEB_DWARF
        configv.addlinenumbers = 1;
        config.fulltypes = (symdebug == 1) ? CVDWARF_D : CVDWARF_C;
#endif
#if SYMDEB_CODEVIEW
        if (config.objfmt == OBJ_MSCOFF)
        {
            configv.addlinenumbers = 1;
            config.fulltypes = CV8;
            if(symdebug > 1)
                config.flags2 |= CFG2gms;
        }
        else
        {
            configv.addlinenumbers = 1;
            config.fulltypes = CV4;
        }
#endif
        if (!optimize)
            config.flags |= CFGalwaysframe;
    }
    else
    {
        configv.addlinenumbers = 0;
        config.fulltypes = CVNONE;
        //config.flags &= ~CFGalwaysframe;
    }

    if (alwaysframe)
        config.flags |= CFGalwaysframe;
    if (stackstomp)
        config.flags2 |= CFG2stomp;

    ph_init();
    block_init();

    cod3_setdefault();
    if (model == 64)
    {
        util_set64();
        type_init();
        cod3_set64();
    }
    else
    {
        util_set32();
        type_init();
        cod3_set32();
    }

    rtlsym_init(); // uses fregsaved, so must be after it's set inside cod3_set*
#endif
}

#ifdef DEBUG

/****************************
 * Transmit internal compiler debugging flags.
 */
void out_config_debug(
        bool b,
        bool c,
        bool f,
        bool r,
        bool w,
        bool x,
        bool y
    )
{
    debugb = b;
    debugc = c;
    debugf = f;
    debugr = r;
    debugw = w;
    debugx = x;
    debugy = y;
}

#endif

/*************************************
 */

void util_set16()
{
    // The default is 16 bits
}

/*******************************
 * Redo tables from 8086/286 to 386/486.
 */

void util_set32()
{
    _tyrelax[TYenum] = TYlong;
    _tyrelax[TYint]  = TYlong;
    _tyrelax[TYuint] = TYlong;

    tyequiv[TYint] = TYlong;
    tyequiv[TYuint] = TYulong;

    for (int i = 0; i < 1; ++i)
    {   tysize[TYenum + i] = LONGSIZE;
        tysize[TYint  + i] = LONGSIZE;
        tysize[TYuint + i] = LONGSIZE;
        tysize[TYnullptr + i] = LONGSIZE;
        tysize[TYnptr + i] = LONGSIZE;
        tysize[TYnref + i] = LONGSIZE;
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_SOLARIS
        tysize[TYldouble + i] = 12;
        tysize[TYildouble + i] = 12;
        tysize[TYcldouble + i] = 24;
#elif TARGET_OSX
        tysize[TYldouble + i] = 16;
        tysize[TYildouble + i] = 16;
        tysize[TYcldouble + i] = 32;
#elif TARGET_WINDOS
        tysize[TYldouble + i] = 10;
        tysize[TYildouble + i] = 10;
        tysize[TYcldouble + i] = 20;
#else
        assert(0);
#endif
#if TARGET_SEGMENTED
        tysize[TYsptr + i] = LONGSIZE;
        tysize[TYcptr + i] = LONGSIZE;
        tysize[TYfptr + i] = 6;     // NOTE: There are codgen test that check
        tysize[TYvptr + i] = 6;     // tysize[x] == tysize[TYfptr] so don't set
        tysize[TYfref + i] = 6;     // tysize[TYfptr] to tysize[TYnptr]
#endif
    }

    for (int i = 0; i < 1; ++i)
    {   tyalignsize[TYenum + i] = LONGSIZE;
        tyalignsize[TYint  + i] = LONGSIZE;
        tyalignsize[TYuint + i] = LONGSIZE;
        tyalignsize[TYnullptr + i] = LONGSIZE;
        tyalignsize[TYnref + i] = LONGSIZE;
        tyalignsize[TYnptr + i] = LONGSIZE;
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_SOLARIS
        tyalignsize[TYldouble + i] = 4;
        tyalignsize[TYildouble + i] = 4;
        tyalignsize[TYcldouble + i] = 4;
#elif TARGET_OSX
        tyalignsize[TYldouble + i] = 16;
        tyalignsize[TYildouble + i] = 16;
        tyalignsize[TYcldouble + i] = 16;
#elif TARGET_WINDOS
        tyalignsize[TYldouble + i] = 2;
        tyalignsize[TYildouble + i] = 2;
        tyalignsize[TYcldouble + i] = 2;
#else
        assert(0);
#endif
#if TARGET_SEGMENTED
        tyalignsize[TYsptr + i] = LONGSIZE;
        tyalignsize[TYcptr + i] = LONGSIZE;
#endif
    }
}

/*******************************
 * Redo tables from 8086/286 to I64.
 */

void util_set64()
{
    _tyrelax[TYenum] = TYlong;
    _tyrelax[TYint]  = TYlong;
    _tyrelax[TYuint] = TYlong;

    tyequiv[TYint] = TYlong;
    tyequiv[TYuint] = TYulong;

    for (int i = 0; i < 1; ++i)
    {   tysize[TYenum + i] = LONGSIZE;
        tysize[TYint  + i] = LONGSIZE;
        tysize[TYuint + i] = LONGSIZE;
        tysize[TYnullptr + i] = 8;
        tysize[TYnptr + i] = 8;
        tysize[TYnref + i] = 8;
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_SOLARIS || TARGET_OSX
        tysize[TYldouble + i] = 16;
        tysize[TYildouble + i] = 16;
        tysize[TYcldouble + i] = 32;
#elif TARGET_WINDOS
        tysize[TYldouble + i] = 10;
        tysize[TYildouble + i] = 10;
        tysize[TYcldouble + i] = 20;
#else
        assert(0);
#endif
#if TARGET_SEGMENTED
        tysize[TYsptr + i] = 8;
        tysize[TYcptr + i] = 8;
        tysize[TYfptr + i] = 10;    // NOTE: There are codgen test that check
        tysize[TYvptr + i] = 10;    // tysize[x] == tysize[TYfptr] so don't set
        tysize[TYfref + i] = 10;    // tysize[TYfptr] to tysize[TYnptr]
#endif
    }

    for (int i = 0; i < 1; ++i)
    {   tyalignsize[TYenum + i] = LONGSIZE;
        tyalignsize[TYint  + i] = LONGSIZE;
        tyalignsize[TYuint + i] = LONGSIZE;
        tyalignsize[TYnullptr + i] = 8;
        tyalignsize[TYnptr + i] = 8;
        tyalignsize[TYnref + i] = 8;
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_SOLARIS
        tyalignsize[TYldouble + i] = 16;
        tyalignsize[TYildouble + i] = 16;
        tyalignsize[TYcldouble + i] = 16;
#elif TARGET_OSX
        tyalignsize[TYldouble + i] = 16;
        tyalignsize[TYildouble + i] = 16;
        tyalignsize[TYcldouble + i] = 16;
#elif TARGET_WINDOS
        tyalignsize[TYldouble + i] = 2;
        tyalignsize[TYildouble + i] = 2;
        tyalignsize[TYcldouble + i] = 2;
#else
        assert(0);
#endif
#if TARGET_SEGMENTED
        tyalignsize[TYsptr + i] = 8;
        tyalignsize[TYcptr + i] = 8;
        tyalignsize[TYfptr + i] = 8;
        tyalignsize[TYvptr + i] = 8;
        tyalignsize[TYfref + i] = 8;
#endif
        tytab[TYjfunc + i] &= ~TYFLpascal;  // set so caller cleans the stack (as in C)
    }

    TYptrdiff = TYllong;
    TYsize = TYullong;
    TYsize_t = TYullong;
}
