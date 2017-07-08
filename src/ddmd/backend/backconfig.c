/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/backconfig.c
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
        bool stackstomp,        // add stack stomping code
        unsigned char avx,      // use AVX instruction set (0, 1, 2)
        bool betterC            // implement "Better C"
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
        config.avx = avx;
        config.ehmethod = EH_DM;

        // Not sure we really need these two lines, try removing them later
        config.flags |= CFGnoebp;
        config.flags |= CFGalwaysframe;
        config.flags |= CFGromable; // put switch tables in code segment
        config.objfmt = OBJ_MSCOFF;
    }
    else
    {
        config.exe = EX_WIN32;
        config.ehmethod = EH_WIN32;
        config.objfmt = mscoff ? OBJ_MSCOFF : OBJ_OMF;
    }

    if (exe)
        config.wflags |= WFexe;         // EXE file only optimizations
    config.flags4 |= CFG4underscore;
#endif
#if TARGET_LINUX
    if (model == 64)
    {   config.exe = EX_LINUX64;
        config.ehmethod = EH_DWARF;
        config.fpxmmregs = TRUE;
        config.avx = avx;
    }
    else
    {
        config.exe = EX_LINUX;
        config.ehmethod = EH_DWARF;
        if (!exe)
            config.flags |= CFGromable; // put switch tables in code segment
    }
    config.flags |= CFGnoebp;
    if (!exe)
    {
        config.flags3 |= CFG3pic;
        config.flags |= CFGalwaysframe; // PIC needs a frame for TLS fixups
    }
    config.objfmt = OBJ_ELF;
#endif
#if TARGET_OSX
    config.fpxmmregs = TRUE;
    config.avx = avx;
    if (model == 64)
    {   config.exe = EX_OSX64;
        config.fpxmmregs = TRUE;
        config.ehmethod = EH_DWARF;
    }
    else
    {
        config.exe = EX_OSX;
        config.ehmethod = EH_DWARF;
    }
    config.flags |= CFGnoebp;
    if (!exe)
    {
        config.flags3 |= CFG3pic;
        config.flags |= CFGalwaysframe; // PIC needs a frame for TLS fixups
    }
    config.flags |= CFGromable; // put switch tables in code segment
    config.objfmt = OBJ_MACH;
#endif
#if TARGET_FREEBSD
    if (model == 64)
    {   config.exe = EX_FREEBSD64;
        config.ehmethod = EH_DWARF;
        config.fpxmmregs = TRUE;
        config.avx = avx;
    }
    else
    {
        config.exe = EX_FREEBSD;
        config.ehmethod = EH_DWARF;
        if (!exe)
            config.flags |= CFGromable; // put switch tables in code segment
    }
    config.flags |= CFGnoebp;
    if (!exe)
    {
        config.flags3 |= CFG3pic;
        config.flags |= CFGalwaysframe; // PIC needs a frame for TLS fixups
    }
    config.objfmt = OBJ_ELF;
#endif
#if TARGET_OPENBSD
    if (model == 64)
    {   config.exe = EX_OPENBSD64;
        config.fpxmmregs = TRUE;
        config.avx = avx;
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
    config.ehmethod = EH_DM;
#endif
#if TARGET_SOLARIS
    if (model == 64)
    {   config.exe = EX_SOLARIS64;
        config.fpxmmregs = TRUE;
        config.avx = avx;
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
    config.ehmethod = EH_DM;
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

    config.betterC = betterC;

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
    _tysize[TYldouble] = 10;
    _tysize[TYildouble] = 10;
    _tysize[TYcldouble] = 20;

    _tyalignsize[TYldouble] = 2;
    _tyalignsize[TYildouble] = 2;
    _tyalignsize[TYcldouble] = 2;
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

    _tysize[TYenum] = LONGSIZE;
    _tysize[TYint ] = LONGSIZE;
    _tysize[TYuint] = LONGSIZE;
    _tysize[TYnullptr] = LONGSIZE;
    _tysize[TYnptr] = LONGSIZE;
    _tysize[TYnref] = LONGSIZE;
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    _tysize[TYldouble] = 12;
    _tysize[TYildouble] = 12;
    _tysize[TYcldouble] = 24;
#elif TARGET_OSX
    _tysize[TYldouble] = 16;
    _tysize[TYildouble] = 16;
    _tysize[TYcldouble] = 32;
#elif TARGET_WINDOS
    _tysize[TYldouble] = 10;
    _tysize[TYildouble] = 10;
    _tysize[TYcldouble] = 20;
#else
    assert(0);
#endif
    _tysize[TYsptr] = LONGSIZE;
    _tysize[TYcptr] = LONGSIZE;
    _tysize[TYfptr] = 6;     // NOTE: There are codgen test that check
    _tysize[TYvptr] = 6;     // _tysize[x] == _tysize[TYfptr] so don't set
    _tysize[TYfref] = 6;     // _tysize[TYfptr] to _tysize[TYnptr]

    _tyalignsize[TYenum] = LONGSIZE;
    _tyalignsize[TYint ] = LONGSIZE;
    _tyalignsize[TYuint] = LONGSIZE;
    _tyalignsize[TYnullptr] = LONGSIZE;
    _tyalignsize[TYnref] = LONGSIZE;
    _tyalignsize[TYnptr] = LONGSIZE;
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    _tyalignsize[TYldouble] = 4;
    _tyalignsize[TYildouble] = 4;
    _tyalignsize[TYcldouble] = 4;
#elif TARGET_OSX
    _tyalignsize[TYldouble] = 16;
    _tyalignsize[TYildouble] = 16;
    _tyalignsize[TYcldouble] = 16;
#elif TARGET_WINDOS
    _tyalignsize[TYldouble] = 2;
    _tyalignsize[TYildouble] = 2;
    _tyalignsize[TYcldouble] = 2;
#else
    assert(0);
#endif
    _tyalignsize[TYsptr] = LONGSIZE;
    _tyalignsize[TYcptr] = LONGSIZE;
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

    _tysize[TYenum] = LONGSIZE;
    _tysize[TYint ] = LONGSIZE;
    _tysize[TYuint] = LONGSIZE;
    _tysize[TYnullptr] = 8;
    _tysize[TYnptr] = 8;
    _tysize[TYnref] = 8;
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS || TARGET_OSX
    _tysize[TYldouble] = 16;
    _tysize[TYildouble] = 16;
    _tysize[TYcldouble] = 32;
#elif TARGET_WINDOS
    _tysize[TYldouble] = 10;
    _tysize[TYildouble] = 10;
    _tysize[TYcldouble] = 20;
#else
    assert(0);
#endif
    _tysize[TYsptr] = 8;
    _tysize[TYcptr] = 8;
    _tysize[TYfptr] = 10;    // NOTE: There are codgen test that check
    _tysize[TYvptr] = 10;    // _tysize[x] == _tysize[TYfptr] so don't set
    _tysize[TYfref] = 10;    // _tysize[TYfptr] to _tysize[TYnptr]

    _tyalignsize[TYenum] = LONGSIZE;
    _tyalignsize[TYint ] = LONGSIZE;
    _tyalignsize[TYuint] = LONGSIZE;
    _tyalignsize[TYnullptr] = 8;
    _tyalignsize[TYnptr] = 8;
    _tyalignsize[TYnref] = 8;
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    _tyalignsize[TYldouble] = 16;
    _tyalignsize[TYildouble] = 16;
    _tyalignsize[TYcldouble] = 16;
#elif TARGET_OSX
    _tyalignsize[TYldouble] = 16;
    _tyalignsize[TYildouble] = 16;
    _tyalignsize[TYcldouble] = 16;
#elif TARGET_WINDOS
    _tyalignsize[TYldouble] = 2;
    _tyalignsize[TYildouble] = 2;
    _tyalignsize[TYcldouble] = 2;
#else
    assert(0);
#endif
    _tyalignsize[TYsptr] = 8;
    _tyalignsize[TYcptr] = 8;
    _tyalignsize[TYfptr] = 8;
    _tyalignsize[TYvptr] = 8;
    _tyalignsize[TYfref] = 8;
    tytab[TYjfunc] &= ~TYFLpascal;  // set so caller cleans the stack (as in C)

    TYptrdiff = TYllong;
    TYsize = TYullong;
    TYsize_t = TYullong;
    TYdelegate = TYcent;
    TYdarray = TYucent;
}

// cc.d
unsigned Srcpos::sizeCheck() { return sizeof(Srcpos); }
unsigned Pstate::sizeCheck() { return sizeof(Pstate); }
unsigned Cstate::sizeCheck() { return sizeof(Cstate); }
unsigned Blockx::sizeCheck() { return sizeof(Blockx); }
unsigned block::sizeCheck()  { return sizeof(block);  }
unsigned func_t::sizeCheck() { return sizeof(func_t); }
unsigned baseclass_t::sizeCheck() { return sizeof(baseclass_t); }
unsigned template_t::sizeCheck() { return sizeof(template_t); }
unsigned struct_t::sizeCheck() { return sizeof(struct_t); }
unsigned Symbol::sizeCheck() { return sizeof(Symbol); }
unsigned param_t::sizeCheck() { return sizeof(param_t); }
unsigned Declar::sizeCheck() { return sizeof(Declar); }
unsigned dt_t::sizeCheck() { return sizeof(dt_t); }

// cdef.d
unsigned Config::sizeCheck() { return sizeof(Config); }
unsigned Configv::sizeCheck() { return sizeof(Configv); }
unsigned eve::sizeCheck() { return sizeof(eve); }

// el.d

// type.d
unsigned TYPE::sizeCheck() { return sizeof(type); }
