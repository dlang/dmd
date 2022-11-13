/**
 * Configure the back end (optimizer and code generator)
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2000-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/backconfig.d, backend/backconfig.d)
 */

module dmd.backend.backconfig;

import core.stdc.stdio;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.code;
import dmd.backend.global;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.dwarfdbginf;
extern (C++):

nothrow:
@safe:

version (MARS)
{
    void ph_init();
}

/**************************************
 * Initialize configuration for backend.
 * Params:
    model         = 32 for 32 bit code,
                    64 for 64 bit code,
                    set bit 0 to generate MS-COFF instead of OMF on Windows
    exe           = true for exe file,
                    false for dll or shared library (generate PIC code)
    trace         =  add profiling code
    nofloat       = do not pull in floating point code
    vasm          = print generated assembler for each function
    verbose       = verbose compile
    optimize      = optimize code
    symdebug      = add symbolic debug information,
                    1 for D,
                    2 for fake it with C symbolic debug info
    alwaysframe   = always create standard function frame
    stackstomp    = add stack stomping code
    avx           = use AVX instruction set (0, 1, 2)
    pic           = position independence level (0, 1, 2)
    useModuleInfo = implement ModuleInfo
    useTypeInfo   = implement TypeInfo
    useExceptions = implement exception handling
    dwarf         = DWARF version used
    _version      = Compiler version
    exefmt        = Executable file format
    generatedMain = a main entrypoint is generated
 */
public
@trusted
extern (C) void out_config_init(
        int model,
        bool exe,
        bool trace,
        bool nofloat,
        bool vasm,      // print generated assembler for each function
        bool verbose,
        bool optimize,
        int symdebug,
        bool alwaysframe,
        bool stackstomp,
        ubyte avx,
        ubyte pic,
        bool useModuleInfo,
        bool useTypeInfo,
        bool useExceptions,
        ubyte dwarf,
        string _version,
        exefmt_t exefmt,
        bool generatedMain      // a main entrypoint is generated
        )
{
version (MARS)
{
    //printf("out_config_init()\n");

    auto cfg = &config;

    cfg._version = _version;
    if (!cfg.target_cpu)
    {   cfg.target_cpu = TARGET_PentiumPro;
        cfg.target_scheduler = cfg.target_cpu;
    }
    cfg.fulltypes = CVNONE;
    cfg.fpxmmregs = false;
    cfg.inline8087 = 1;
    cfg.memmodel = 0;
    cfg.flags |= CFGuchar;   // make sure TYchar is unsigned
    cfg.exe = exefmt;
    tytab[TYchar] |= TYFLuns;
    bool mscoff = model & 1;
    model &= 32 | 64;
    if (generatedMain)
        cfg.flags2 |= CFG2genmain;

    if (dwarf < 3 || dwarf > 5)
    {
        if (dwarf)
        {
            import dmd.backend.errors;
            error(null, 0, 0, "DWARF version %u is not supported", dwarf);
        }

        // Default DWARF version
        cfg.dwarf = 3;
    }
    else
    {
        cfg.dwarf = dwarf;
    }

    if (cfg.exe & EX_windos)
    {
        if (model == 64)
        {
            cfg.fpxmmregs = true;
            cfg.avx = avx;
            cfg.ehmethod = useExceptions ? EHmethod.EH_DM : EHmethod.EH_NONE;

            cfg.flags |= CFGnoebp;       // test suite fails without this
            //cfg.flags |= CFGalwaysframe;
            cfg.flags |= CFGromable; // put switch tables in code segment
            cfg.objfmt = OBJ_MSCOFF;
        }
        else
        {
            cfg.ehmethod = useExceptions ? EHmethod.EH_WIN32 : EHmethod.EH_NONE;
            if (mscoff)
                cfg.flags |= CFGnoebp;       // test suite fails without this
            cfg.objfmt = mscoff ? OBJ_MSCOFF : OBJ_OMF;
            if (mscoff)
                cfg.flags |= CFGnoebp;    // test suite fails without this
        }

        if (exe)
            cfg.wflags |= WFexe;         // EXE file only optimizations
        cfg.flags4 |= CFG4underscore;
    }
    if (cfg.exe & (EX_LINUX | EX_LINUX64))
    {
        cfg.fpxmmregs = true;
        cfg.avx = avx;
        if (model == 64)
        {
            cfg.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
        }
        else
        {
            cfg.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
            if (!exe)
                cfg.flags |= CFGromable; // put switch tables in code segment
        }
        cfg.flags |= CFGnoebp;
        switch (pic)
        {
            case 0:         // PIC.fixed
                break;

            case 1:         // PIC.pic
                cfg.flags3 |= CFG3pic;
                break;

            case 2:         // PIC.pie
                cfg.flags3 |= CFG3pic | CFG3pie;
                break;

            default:
                assert(0);
        }
        if (symdebug)
            cfg.flags |= CFGalwaysframe;

        cfg.objfmt = OBJ_ELF;
    }
    if (cfg.exe & (EX_OSX | EX_OSX64))
    {
        cfg.fpxmmregs = true;
        cfg.avx = avx;
        cfg.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
        cfg.flags |= CFGnoebp;
        if (!exe)
        {
            cfg.flags3 |= CFG3pic;
            if (model == 64)
                cfg.flags |= CFGalwaysframe; // autotester fails without this
                                                // https://issues.dlang.org/show_bug.cgi?id=21042
        }
        if (symdebug)
            cfg.flags |= CFGalwaysframe;
        cfg.flags |= CFGromable; // put switch tables in code segment
        cfg.objfmt = OBJ_MACH;
    }
    if (cfg.exe & (EX_FREEBSD | EX_FREEBSD64))
    {
        if (model == 64)
        {
            cfg.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
            cfg.fpxmmregs = true;
            cfg.avx = avx;
        }
        else
        {
            cfg.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
            if (!exe)
                cfg.flags |= CFGromable; // put switch tables in code segment
        }
        cfg.flags |= CFGnoebp;
        if (!exe)
        {
            cfg.flags3 |= CFG3pic;
        }
        if (symdebug)
            cfg.flags |= CFGalwaysframe;
        cfg.objfmt = OBJ_ELF;
    }
    if (cfg.exe & (EX_OPENBSD | EX_OPENBSD64))
    {
        if (model == 64)
        {
            cfg.fpxmmregs = true;
            cfg.avx = avx;
        }
        else
        {
            if (!exe)
                cfg.flags |= CFGromable; // put switch tables in code segment
        }
        cfg.flags |= CFGnoebp;
        cfg.flags |= CFGalwaysframe;
        if (!exe)
            cfg.flags3 |= CFG3pic;
        cfg.objfmt = OBJ_ELF;
        cfg.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
    }
    if (cfg.exe == EX_DRAGONFLYBSD64)
    {
        if (model == 64)
        {
            cfg.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
            cfg.fpxmmregs = true;
            cfg.avx = avx;
        }
        else
        {
            assert(0);                      // Only 64-bit supported on DragonFlyBSD
        }
        cfg.flags |= CFGnoebp;
        if (!exe)
        {
            cfg.flags3 |= CFG3pic;
            cfg.flags |= CFGalwaysframe; // PIC needs a frame for TLS fixups
        }
        cfg.objfmt = OBJ_ELF;
    }
    if (cfg.exe & (EX_SOLARIS | EX_SOLARIS64))
    {
        if (model == 64)
        {
            cfg.fpxmmregs = true;
            cfg.avx = avx;
        }
        else
        {
            if (!exe)
                cfg.flags |= CFGromable; // put switch tables in code segment
        }
        cfg.flags |= CFGnoebp;
        cfg.flags |= CFGalwaysframe;
        if (!exe)
            cfg.flags3 |= CFG3pic;
        cfg.objfmt = OBJ_ELF;
        cfg.ehmethod = useExceptions ? EHmethod.EH_DWARF : EHmethod.EH_NONE;
    }

    cfg.flags2 |= CFG2nodeflib;      // no default library
    cfg.flags3 |= CFG3eseqds;
static if (0)
{
    if (env.getEEcontext().EEcompile != 2)
        cfg.flags4 |= CFG4allcomdat;
    if (env.nochecks())
        cfg.flags4 |= CFG4nochecks;  // no runtime checking
}
    if (cfg.exe & (EX_OSX | EX_OSX64))
    {
    }
    else
    {
        cfg.flags4 |= CFG4allcomdat;
    }
    if (trace)
        cfg.flags |= CFGtrace;       // turn on profiler
    if (nofloat)
        cfg.flags3 |= CFG3wkfloat;

    configv.vasm = vasm;
    configv.verbose = verbose;

    if (optimize)
        go_flag(cast(char*)"-o".ptr);

    if (symdebug)
    {
        if (cfg.exe & (EX_LINUX | EX_LINUX64 | EX_OPENBSD | EX_OPENBSD64 | EX_FREEBSD | EX_FREEBSD64 | EX_DRAGONFLYBSD64 |
                          EX_SOLARIS | EX_SOLARIS64 | EX_OSX | EX_OSX64))
        {
            configv.addlinenumbers = 1;
            cfg.fulltypes = (symdebug == 1) ? CVDWARF_D : CVDWARF_C;
        }
        if (cfg.exe & (EX_windos))
        {
            if (cfg.objfmt == OBJ_MSCOFF)
            {
                configv.addlinenumbers = 1;
                cfg.fulltypes = CV8;
                if(symdebug > 1)
                    cfg.flags2 |= CFG2gms;
            }
            else
            {
                configv.addlinenumbers = 1;
                cfg.fulltypes = CV4;
            }
        }
        if (!optimize)
            cfg.flags |= CFGalwaysframe;
    }
    else
    {
        configv.addlinenumbers = 0;
        cfg.fulltypes = CVNONE;
        //cfg.flags &= ~CFGalwaysframe;
    }

    if (alwaysframe)
        cfg.flags |= CFGalwaysframe;
    if (stackstomp)
        cfg.flags2 |= CFG2stomp;

    cfg.useModuleInfo = useModuleInfo;
    cfg.useTypeInfo = useTypeInfo;
    cfg.useExceptions = useExceptions;

    ph_init();
    block_init();

    cod3_setdefault();
    if (model == 64)
    {
        util_set64(cfg.exe);
        type_init();
        cod3_set64();
    }
    else
    {
        util_set32(cfg.exe);
        type_init();
        cod3_set32();
    }

    if (cfg.objfmt == OBJ_MACH)
        machDebugSectionsInit();
    else if (cfg.objfmt == OBJ_ELF)
        elfDebugSectionsInit();
    rtlsym_init(); // uses fregsaved, so must be after it's set inside cod3_set*
}
}

/****************************
 * Transmit internal compiler debugging flags.
 */
@trusted
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

/*************************************
 */

@trusted
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

@trusted
void util_set32(exefmt_t exe)
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
if (exe & (EX_LINUX | EX_LINUX64 | EX_FREEBSD | EX_FREEBSD64 | EX_OPENBSD | EX_OPENBSD64 | EX_DRAGONFLYBSD64 | EX_SOLARIS | EX_SOLARIS64))
{
    _tysize[TYldouble] = 12;
    _tysize[TYildouble] = 12;
    _tysize[TYcldouble] = 24;
}
if (exe & (EX_OSX | EX_OSX64))
{
    _tysize[TYldouble] = 16;
    _tysize[TYildouble] = 16;
    _tysize[TYcldouble] = 32;
}
if (exe & EX_windos)
{
    _tysize[TYldouble] = 10;
    _tysize[TYildouble] = 10;
    _tysize[TYcldouble] = 20;
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
if (exe & (EX_LINUX | EX_LINUX64 | EX_FREEBSD | EX_FREEBSD64 | EX_OPENBSD | EX_OPENBSD64 | EX_DRAGONFLYBSD64 | EX_SOLARIS | EX_SOLARIS64))
{
    _tyalignsize[TYldouble] = 4;
    _tyalignsize[TYildouble] = 4;
    _tyalignsize[TYcldouble] = 4;
}
else if (exe & (EX_OSX | EX_OSX64))
{
    _tyalignsize[TYldouble] = 16;
    _tyalignsize[TYildouble] = 16;
    _tyalignsize[TYcldouble] = 16;
}
if (exe & EX_windos)
{
    _tyalignsize[TYldouble] = 2;
    _tyalignsize[TYildouble] = 2;
    _tyalignsize[TYcldouble] = 2;
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

@trusted
void util_set64(exefmt_t exe)
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
    if (exe & (EX_LINUX | EX_LINUX64 | EX_FREEBSD | EX_FREEBSD64 | EX_OPENBSD |
                      EX_OPENBSD64 | EX_DRAGONFLYBSD64 | EX_SOLARIS | EX_SOLARIS64 | EX_OSX | EX_OSX64))
    {
        _tysize[TYldouble] = 16;
        _tysize[TYildouble] = 16;
        _tysize[TYcldouble] = 32;
    }
    if (exe & EX_windos)
    {
        _tysize[TYldouble] = 10;
        _tysize[TYildouble] = 10;
        _tysize[TYcldouble] = 20;
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
    if (exe & (EX_LINUX | EX_LINUX64 | EX_FREEBSD | EX_FREEBSD64 | EX_OPENBSD | EX_OPENBSD64 | EX_DRAGONFLYBSD64 | EX_SOLARIS | EX_SOLARIS64))
    {
        _tyalignsize[TYldouble] = 16;
        _tyalignsize[TYildouble] = 16;
        _tyalignsize[TYcldouble] = 16;
    }
    if (exe & (EX_OSX | EX_OSX64))
    {
        _tyalignsize[TYldouble] = 16;
        _tyalignsize[TYildouble] = 16;
        _tyalignsize[TYcldouble] = 16;
    }
    if (exe & EX_windos)
    {
        _tyalignsize[TYldouble] = 2;
        _tyalignsize[TYildouble] = 2;
        _tyalignsize[TYcldouble] = 2;
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
