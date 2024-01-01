/**
 * Configures and initializes the backend.
 *
 * Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
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
import dmd.backend.backconfig;

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
        case Target.OS.Windows: exfmt = target.isX86_64 ? EX_WIN64 : EX_WIN32;       break;
        case Target.OS.linux:   exfmt = target.isX86_64 ? EX_LINUX64 : EX_LINUX;     break;
        case Target.OS.OSX:     exfmt = target.isX86_64 ? EX_OSX64 : EX_OSX;         break;
        case Target.OS.FreeBSD: exfmt = target.isX86_64 ? EX_FREEBSD64 : EX_FREEBSD; break;
        case Target.OS.OpenBSD: exfmt = target.isX86_64 ? EX_OPENBSD64 : EX_OPENBSD; break;
        case Target.OS.Solaris: exfmt = target.isX86_64 ? EX_SOLARIS64 : EX_SOLARIS; break;
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
        (target.isX86_64 ? 64 : 32) | (target.objectFormat() == Target.ObjectFormat.coff ? 1 : 0),
        exe,
        false, //params.trace,
        driverParams.nofloat,
        driverParams.vasm,
        params.v.verbose,
        driverParams.optimize,
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
        driverParams.symImport != SymImport.none
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
