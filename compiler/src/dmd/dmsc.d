/**
 * Configures and initializes the backend.
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/dmsc.d, _dmsc.d)
 * Documentation:  https://dlang.org/phobos/dmd_dmsc.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/dmsc.d
 */

module dmd.dmsc;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stddef;

import dmd.globals;
import dmd.dclass;
import dmd.dmdparams;
import dmd.dmodule;
import dmd.errors : errorBackend;
import dmd.mtype;
import dmd.target;

import dmd.root.filename;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.global;
import dmd.backend.ty;
import dmd.backend.type;
import dmd.backend.backconfig;
import dmd.backend.var : go;

/**************************************
 * Initialize backend config variables.
 * Params:
 *      params = command line parameters
 *      driverParams = more command line parameters
 *      target = target machine info
 */

void backend_init(const ref Param params, const ref DMDparams driverParams, const ref Target target)
{
    //printf("backend_init()\n");
    exefmt_t exfmt;
    bool is64 = target.isX86_64 || target.isAArch64;
    switch (target.os)
    {
        case Target.OS.Windows: exfmt = is64 ? EX_WIN64     : EX_WIN32;   break;
        case Target.OS.linux:   exfmt = is64 ? EX_LINUX64   : EX_LINUX;   break;
        case Target.OS.OSX:     exfmt = is64 ? EX_OSX64     : EX_OSX;     break;
        case Target.OS.FreeBSD: exfmt = is64 ? EX_FREEBSD64 : EX_FREEBSD; break;
        case Target.OS.OpenBSD: exfmt = is64 ? EX_OPENBSD64 : EX_OPENBSD; break;
        case Target.OS.Solaris: exfmt = is64 ? EX_SOLARIS64 : EX_SOLARIS; break;
        case Target.OS.DragonFlyBSD: assert(is64); exfmt = EX_DRAGONFLYBSD64; break;
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
        target.isAArch64,
        is64 ? 64 : 32,
        exe,
        false, //params.trace,
        driverParams.nofloat,
        driverParams.vasm,
        params.v.verbose,
        driverParams.optimize || params.useInline,
        driverParams.symdebug,
        driverParams.alwaysframe,
        driverParams.stackstomp,
        driverParams.ibt,
        target.cpu >= CPU.avx2 ? 2 : target.cpu >= CPU.avx ? 1 : 0,
        driverParams.pic,
        params.useModuleInfo && Module.moduleinfo,
        params.useTypeInfo && Type.dtypeinfo,
        params.useExceptions && ClassDeclaration.throwable,
        driverParams.dwarf,
        global.versionString(),
        exfmt,
        params.addMain,
        driverParams.symImport != SymImport.none,
        go,
        // FIXME: casting to @nogc because errors.d is not marked @nogc yet
        cast(ErrorCallbackBackend) &errorBackend,
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

/**************************************
 */

void backend_term() @safe
{
}
