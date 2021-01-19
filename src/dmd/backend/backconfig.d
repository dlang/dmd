/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2000-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/backconfig.d, backend/backconfig.d)
 */

// Configure the back end (optimizer and code generator)

module dmd.backend.backconfig;

import core.stdc.stdio;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.code;
import dmd.backend.global;
import dmd.backend.ty;
import dmd.backend.type;

extern (C++):

nothrow:

version (MARS)
{
    void ph_init();
}

/// Bit decoding of the TargetOS (copied from `dmd.globals : TargetOS`
enum TargetOS : ubyte
{
    /* These are mutually exclusive; one and only one is set.
     * Match spelling and casing of corresponding version identifiers
     */
    linux        = 1,
    Windows      = 2,
    OSX          = 4,
    OpenBSD      = 8,
    FreeBSD      = 0x10,
    Solaris      = 0x20,
    DragonFlyBSD = 0x40,

    // Combination masks
    all = linux | Windows | OSX | FreeBSD | Solaris | DragonFlyBSD,
    Posix = linux | OSX | FreeBSD | Solaris | DragonFlyBSD,
}

/**************************************
 * Initialize configuration variables.
 */

extern (C) void out_config_init(
        TargetOS target, // Target operating system, matches `dmd.globals : TargetOS`
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
        ubyte avx,              // use AVX instruction set (0, 1, 2)
        ubyte pic,              // position independence level (0, 1, 2)
        bool useModuleInfo,     // implement ModuleInfo
        bool useTypeInfo,       // implement TypeInfo
        bool useExceptions,     // implement exception handling
        string _version         // Compiler version
        )
{
version (MARS)
{
    //printf("out_config_init()\n");

    config._version = _version;
    if (!config.target_cpu)
    {   config.target_cpu = TARGET_PentiumPro;
        config.target_scheduler = config.target_cpu;
    }
    config.fulltypes = CVNONE;
    config.fpxmmregs = false;
    config.inline8087 = 1;
    config.memmodel = 0;
    config.flags |= CFGuchar;   // make sure TYchar is unsigned
    tytab[TYchar] |= TYFLuns;
    bool mscoff = model & 1;
    model &= 32 | 64;
    if (target == TargetOS.Windows)
    {
        if (model == 64)
        {
            config.exe = EX_WIN64;
            config.fpxmmregs = true;
            config.avx = avx;
            config.ehmethod = useExceptions ? EHmethod.EH_DM : EHmethod.EH_NONE;

            config.flags |= CFGnoebp;       // test suite fails without this
            //config.flags |= CFGalwaysframe;
            config.flags |= CFGromable; // put switch tables in code segment
            config.objfmt = OBJ_MSCOFF;
        }
        else
        {
            config.exe = EX_WIN32;
            config.ehmethod = useExceptions ? EHmethod.EH_WIN32 : EHmethod.EH_NONE;
            config.objfmt = mscoff ? OBJ_MSCOFF : OBJ_OMF;
        }

        if (exe)
            config.wflags |= WFexe;         // EXE file only optimizations
        config.flags4 |= CFG4underscore;
    }
    else if (target == TargetOS.linux)
    {
        config.fpxmmregs = true;
        config.avx = avx;
        if (model == 64)
        {
            config.exe = EX_LINUX64;
            config.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
        }
        else
        {
            config.exe = EX_LINUX;
            config.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
            if (!exe)
                config.flags |= CFGromable; // put switch tables in code segment
        }
        config.flags |= CFGnoebp;
        switch (pic)
        {
            case 0:         // PIC.fixed
                break;

            case 1:         // PIC.pic
                config.flags3 |= CFG3pic;
                break;

            case 2:         // PIC.pie
                config.flags3 |= CFG3pic | CFG3pie;
                break;

            default:
                assert(0);
        }
        if (symdebug)
            config.flags |= CFGalwaysframe;

        config.objfmt = OBJ_ELF;
    }
    else if (target == TargetOS.OSX)
    {
        config.fpxmmregs = true;
        config.avx = avx;
        if (model == 64)
        {
            config.exe = EX_OSX64;
            config.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
        }
        else
        {
            config.exe = EX_OSX;
            config.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
        }
        config.flags |= CFGnoebp;
        if (!exe)
        {
            config.flags3 |= CFG3pic;
            if (model == 64)
                config.flags |= CFGalwaysframe; // autotester fails without this
                                                // https://issues.dlang.org/show_bug.cgi?id=21042
        }
        if (symdebug)
            config.flags |= CFGalwaysframe;
        config.flags |= CFGromable; // put switch tables in code segment
        config.objfmt = OBJ_MACH;
    }
    else if (target == TargetOS.FreeBSD)
    {
        if (model == 64)
        {
            config.exe = EX_FREEBSD64;
            config.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
            config.fpxmmregs = true;
            config.avx = avx;
        }
        else
        {
            config.exe = EX_FREEBSD;
            config.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
            if (!exe)
                config.flags |= CFGromable; // put switch tables in code segment
        }
        config.flags |= CFGnoebp;
        if (!exe)
        {
            config.flags3 |= CFG3pic;
        }
        if (symdebug)
            config.flags |= CFGalwaysframe;
        config.objfmt = OBJ_ELF;
    }
    else if (target == TargetOS.OpenBSD)
    {
        if (model == 64)
        {
            config.exe = EX_OPENBSD64;
            config.fpxmmregs = true;
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
        config.ehmethod = useExceptions ? EHmethod.EH_DM : EHmethod.EH_NONE;
    }
    else if (target == TargetOS.DragonFlyBSD)
    {
        if (model == 64)
        {
            config.exe = EX_DRAGONFLYBSD64;
            config.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
            config.fpxmmregs = true;
            config.avx = avx;
        }
        else
        {
            assert(0);           // Only 64-bit supported on DragonFlyBSD
        }
        config.flags |= CFGnoebp;
        if (!exe)
        {
            config.flags3 |= CFG3pic;
            config.flags |= CFGalwaysframe; // PIC needs a frame for TLS fixups
        }
        config.objfmt = OBJ_ELF;
    }
    else if (target == TargetOS.Solaris)
    {
        if (model == 64)
        {
            config.exe = EX_SOLARIS64;
            config.fpxmmregs = true;
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
        config.ehmethod = useExceptions ? EHmethod.EH_DM : EHmethod.EH_NONE;
    }

    config.flags2 |= CFG2nodeflib;      // no default library
    config.flags3 |= CFG3eseqds;
static if (0)
{
    if (env.getEEcontext().EEcompile != 2)
        config.flags4 |= CFG4allcomdat;
    if (env.nochecks())
        config.flags4 |= CFG4nochecks;  // no runtime checking
}

    if (target != TargetOS.OSX)
        config.flags4 |= CFG4allcomdat;

    if (trace)
        config.flags |= CFGtrace;       // turn on profiler
    if (nofloat)
        config.flags3 |= CFG3wkfloat;

    configv.verbose = verbose;

    if (optimize)
        go_flag(cast(char*)"-o".ptr);

    if (symdebug)
    {
static if (SYMDEB_DWARF)
{
        configv.addlinenumbers = 1;
        config.fulltypes = (symdebug == 1) ? CVDWARF_D : CVDWARF_C;
}
static if (SYMDEB_CODEVIEW)
{
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
}
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

    config.useModuleInfo = useModuleInfo;
    config.useTypeInfo = useTypeInfo;
    config.useExceptions = useExceptions;

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
}
}

debug
{

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
static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_DRAGONFLYBSD || TARGET_SOLARIS)
{
    _tysize[TYldouble] = 12;
    _tysize[TYildouble] = 12;
    _tysize[TYcldouble] = 24;
}
else static if (TARGET_OSX)
{
    _tysize[TYldouble] = 16;
    _tysize[TYildouble] = 16;
    _tysize[TYcldouble] = 32;
}
else static if (TARGET_WINDOS)
{
    _tysize[TYldouble] = 10;
    _tysize[TYildouble] = 10;
    _tysize[TYcldouble] = 20;
}
else
{
    assert(0);
}
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
static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_DRAGONFLYBSD || TARGET_SOLARIS)
{
    _tyalignsize[TYldouble] = 4;
    _tyalignsize[TYildouble] = 4;
    _tyalignsize[TYcldouble] = 4;
}
else static if (TARGET_OSX)
{
    _tyalignsize[TYldouble] = 16;
    _tyalignsize[TYildouble] = 16;
    _tyalignsize[TYcldouble] = 16;
}
else static if (TARGET_WINDOS)
{
    _tyalignsize[TYldouble] = 2;
    _tyalignsize[TYildouble] = 2;
    _tyalignsize[TYcldouble] = 2;
}
else
{
    assert(0);
}
    _tyalignsize[TYsptr] = LONGSIZE;
    _tyalignsize[TYcptr] = LONGSIZE;
    _tyalignsize[TYfptr] = LONGSIZE;     // NOTE: There are codgen test that check
    _tyalignsize[TYvptr] = LONGSIZE;     // _tysize[x] == _tysize[TYfptr] so don't set
    _tyalignsize[TYfref] = LONGSIZE;     // _tysize[TYfptr] to _tysize[TYnptr]

    _tysize[TYimmutPtr] = _tysize[TYnptr];
    _tysize[TYsharePtr] = _tysize[TYnptr];
    _tysize[TYrestrictPtr] = _tysize[TYnptr];
    _tysize[TYfgPtr] = _tysize[TYnptr];
    _tyalignsize[TYimmutPtr] = _tyalignsize[TYnptr];
    _tyalignsize[TYsharePtr] = _tyalignsize[TYnptr];
    _tyalignsize[TYrestrictPtr] = _tyalignsize[TYnptr];
    _tyalignsize[TYfgPtr] = _tyalignsize[TYnptr];
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
static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_DRAGONFLYBSD || TARGET_SOLARIS || TARGET_OSX)
{
    _tysize[TYldouble] = 16;
    _tysize[TYildouble] = 16;
    _tysize[TYcldouble] = 32;
}
else static if (TARGET_WINDOS)
{
    _tysize[TYldouble] = 10;
    _tysize[TYildouble] = 10;
    _tysize[TYcldouble] = 20;
}
else
{
    assert(0);
}
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
static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_DRAGONFLYBSD || TARGET_SOLARIS)
{
    _tyalignsize[TYldouble] = 16;
    _tyalignsize[TYildouble] = 16;
    _tyalignsize[TYcldouble] = 16;
}
else static if (TARGET_OSX)
{
    _tyalignsize[TYldouble] = 16;
    _tyalignsize[TYildouble] = 16;
    _tyalignsize[TYcldouble] = 16;
}
else static if (TARGET_WINDOS)
{
    _tyalignsize[TYldouble] = 2;
    _tyalignsize[TYildouble] = 2;
    _tyalignsize[TYcldouble] = 2;
}
else
{
    assert(0);
}
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

    _tysize[TYimmutPtr] = _tysize[TYnptr];
    _tysize[TYsharePtr] = _tysize[TYnptr];
    _tysize[TYrestrictPtr] = _tysize[TYnptr];
    _tysize[TYfgPtr] = _tysize[TYnptr];
    _tyalignsize[TYimmutPtr] = _tyalignsize[TYnptr];
    _tyalignsize[TYsharePtr] = _tyalignsize[TYnptr];
    _tyalignsize[TYrestrictPtr] = _tyalignsize[TYnptr];
    _tyalignsize[TYfgPtr] = _tyalignsize[TYnptr];
}
