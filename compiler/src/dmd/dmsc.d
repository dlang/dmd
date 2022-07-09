/**
 * Configures and initializes the backend.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/dmsc.d, _dmsc.d)
 * Documentation:  https://dlang.org/phobos/dmd_dmsc.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/dmsc.d
 */

module dmd.dmsc;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stddef;

extern (C++):

import dmd.globals;
import dmd.dclass;
import dmd.dmdparams;
import dmd.dmodule;
import dmd.mtype;
import dmd.target;

import dmd.root.filename;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.global;
import dmd.backend.ty;
import dmd.backend.type;

extern (C) void out_config_init(
        int model,      // 32: 32 bit code
                        // 64: 64 bit code
                        // Windows: bit 0 set to generate MS-COFF instead of OMF
        bool exe,       // true: exe file
                        // false: dll or shared library (generate PIC code)
        bool trace,     // add profiling code
        bool nofloat,   // do not pull in floating point code
        bool vasm,      // print generated assembler for each function
        bool verbose,   // verbose compile
        bool optimize,  // optimize code
        int symdebug,   // add symbolic debug information
                        // 1: D
                        // 2: fake it with C symbolic debug info
        bool alwaysframe,       // always create standard function frame
        bool stackstomp,        // add stack stomping code
        ubyte avx,              // use AVX instruction set (0, 1, 2)
        PIC pic,                // kind of position independent code
        bool useModuleInfo,     // implement ModuleInfo
        bool useTypeInfo,       // implement TypeInfo
        bool useExceptions,     // implement exception handling
        ubyte dwarf,            // DWARF version used
        string _version,        // Compiler version
        exefmt_t exefmt,        // Executable file format
        bool generatedMain      // a main entrypoint is generated
        );

void out_config_debug(
        bool debugb,
        bool debugc,
        bool debugf,
        bool debugr,
        bool debugw,
        bool debugx,
        bool debugy
    );

/**************************************
 * Initialize config variables.
 */

void backend_init()
{
    //printf("out_config_init()\n");
    Param *params = &global.params;
    exefmt_t exfmt;
    switch (target.os)
    {
        case Target.OS.Windows: exfmt = target.is64bit ? EX_WIN64 : EX_WIN32;       break;
        case Target.OS.linux:   exfmt = target.is64bit ? EX_LINUX64 : EX_LINUX;     break;
        case Target.OS.OSX:     exfmt = target.is64bit ? EX_OSX64 : EX_OSX;         break;
        case Target.OS.FreeBSD: exfmt = target.is64bit ? EX_FREEBSD64 : EX_FREEBSD; break;
        case Target.OS.OpenBSD: exfmt = target.is64bit ? EX_OPENBSD64 : EX_OPENBSD; break;
        case Target.OS.Solaris: exfmt = target.is64bit ? EX_SOLARIS64 : EX_SOLARIS; break;
        case Target.OS.DragonFlyBSD: exfmt = EX_DRAGONFLYBSD64; break;
        default: assert(0);
    }

    bool exe;
    if (driverParams.dll || driverParams.pic != PIC.fixed)
    {
    }
    else if (params.run)
        exe = true;         // EXE file only optimizations
    else if (driverParams.link && !params.deffile)
        exe = true;         // EXE file only optimizations
    else if (params.exefile.length &&
             params.exefile.length >= 4 &&
             FileName.equals(FileName.ext(params.exefile), "exe"))
        exe = true;         // if writing out EXE file

    out_config_init(
        (target.is64bit ? 64 : 32) | (target.objectFormat() == Target.ObjectFormat.coff ? 1 : 0),
        exe,
        false, //params.trace,
        driverParams.nofloat,
        driverParams.vasm,
        params.verbose,
        driverParams.optimize,
        driverParams.symdebug,
        driverParams.alwaysframe,
        driverParams.stackstomp,
        target.cpu >= CPU.avx2 ? 2 : target.cpu >= CPU.avx ? 1 : 0,
        driverParams.pic,
        params.useModuleInfo && Module.moduleinfo,
        params.useTypeInfo && Type.dtypeinfo,
        params.useExceptions && ClassDeclaration.throwable,
        driverParams.dwarf,
        global.versionString(),
        exfmt,
        params.addMain
    );

    out_config_debug(
        driverParams.debugb,
        driverParams.debugc,
        driverParams.debugf,
        driverParams.debugr,
        false,
        driverParams.debugx,
        driverParams.debugy
    );
}


/***********************************
 * Return aligned 'offset' if it is of size 'size'.
 */

targ_size_t _align(targ_size_t size, targ_size_t offset)
{
    switch (size)
    {
        case 1:
            break;
        case 2:
        case 4:
        case 8:
        case 16:
        case 32:
        case 64:
            offset = (offset + size - 1) & ~(size - 1);
            break;
        default:
            if (size >= 16)
                offset = (offset + 15) & ~15;
            else
                offset = (offset + _tysize[TYnptr] - 1) & ~(_tysize[TYnptr] - 1);
            break;
    }
    return offset;
}


/*******************************
 * Get size of ty
 */

targ_size_t size(tym_t ty)
{
    int sz = (tybasic(ty) == TYvoid) ? 1 : tysize(ty);
    debug
    {
        if (sz == -1)
            printf("ty: %s\n", tym_str(ty));
    }
    assert(sz!= -1);
    return sz;
}

/****************************
 * Generate symbol of type ty at DATA:offset
 */

Symbol *symboldata(targ_size_t offset,tym_t ty)
{
    Symbol *s = symbol_generate(SClocstat, type_fake(ty));
    s.Sfl = FLdata;
    s.Soffset = offset;
    s.Stype.Tmangle = mTYman_sys; // writes symbol unmodified in Obj::mangle
    symbol_keep(s);               // keep around
    return s;
}

/**************************************
 */

void backend_term()
{
}
