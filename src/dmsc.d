/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _dmsc.d)
 */

module ddmd.dmsc;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stddef;

extern (C++):

import ddmd.globals;

import ddmd.root.filename;

import ddmd.backend.cc;
import ddmd.backend.cdef;
import ddmd.backend.global;
import ddmd.backend.ty;
import ddmd.backend.type;

/+
#include        "mars.h"

#include        "cc.h"
#include        "global.h"
#include        "oper.h"
#include        "code.h"
#include        "type.h"
#include        "dt.h"
#include        "cgcv.h"

extern Global global;
+/

__gshared Config config;

void out_config_init(
        int model,      // 32: 32 bit code
                        // 64: 64 bit code
                        // Windows: bit 0 set to generate MS-COFF instead of OMF
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

    bool exe;
    if (global.params.isWindows)
    {
        exe = false;
        if (params.dll)
        {
        }
        else if (params.run)
            exe = true;         // EXE file only optimizations
        else if (params.link && !global.params.deffile)
            exe = true;         // EXE file only optimizations
        else if (params.exefile)           // if writing out EXE file
        {   size_t len = strlen(params.exefile);
            if (len >= 4 && FileName.compare(params.exefile + len - 3, "exe") == 0)
                exe = true;
        }
    }
    else if (global.params.isLinux   ||
             global.params.isOSX     ||
             global.params.isFreeBSD ||
             global.params.isOpenBSD ||
             global.params.isSolaris)
    {
        exe = params.pic == 0;
    }

    out_config_init(
        (params.is64bit ? 64 : 32) | (params.mscoff ? 1 : 0),
        exe,
        false, //params.trace,
        params.nofloat,
        params.verbose,
        params.optimize,
        params.symdebug,
        params.alwaysframe,
        params.stackstomp
    );

    debug
    {
        out_config_debug(
            params.debugb,
            params.debugc,
            params.debugf,
            params.debugr,
            false,
            params.debugx,
            params.debugy
        );
    }
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
            WRTYxx(ty);
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
    s.Stype.Tmangle = mTYman_d; // writes symbol unmodified in Obj::mangle
    symbol_keep(s);             // keep around
    return s;
}

/**************************************
 */

void backend_term()
{
}
