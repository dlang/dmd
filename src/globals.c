
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/mars.c
 */

#include "globals.h"

#include "filename.h"

Global global;

void Global::init()
{
    inifilename = NULL;
    mars_ext = "d";
    hdr_ext  = "di";
    doc_ext  = "html";
    ddoc_ext = "ddoc";
    json_ext = "json";
    map_ext  = "map";

#if TARGET_WINDOS
    obj_ext  = "obj";
#elif TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    obj_ext  = "o";
#else
#error "fix this"
#endif

#if TARGET_WINDOS
    lib_ext  = "lib";
#elif TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    lib_ext  = "a";
#else
#error "fix this"
#endif

#if TARGET_WINDOS
    dll_ext  = "dll";
#elif TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    dll_ext  = "so";
#elif TARGET_OSX
    dll_ext = "dylib";
#else
#error "fix this"
#endif

#if TARGET_WINDOS
    run_noext = false;
#elif TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    // Allow 'script' D source files to have no extension.
    run_noext = true;
#else
#error "fix this"
#endif

    copyright = "Copyright (c) 1999-2014 by Digital Mars";
    written = "written by Walter Bright";
    version = "v"
#include "verstr.h"
    ;

    compiler.vendor = "Digital Mars D";
    stdmsg = stdout;

    main_d = "__main.d";

    memset(&params, 0, sizeof(Param));

    errorLimit = 20;
}

unsigned Global::startGagging()
{
    ++gag;
    return gaggedErrors;
}

bool Global::endGagging(unsigned oldGagged)
{
    bool anyErrs = (gaggedErrors != oldGagged);
    --gag;
    // Restore the original state of gagged errors; set total errors
    // to be original errors + new ungagged errors.
    errors -= (gaggedErrors - oldGagged);
    gaggedErrors = oldGagged;
    return anyErrs;
}

void Global::increaseErrorCount()
{
    if (gag)
        ++gaggedErrors;
    ++errors;
}


char *Loc::toChars()
{
    OutBuffer buf;

    if (filename)
    {
        buf.printf("%s", filename);
    }

    if (linnum)
    {
        buf.printf("(%d", linnum);
        if (global.params.showColumns && charnum)
            buf.printf(",%d", charnum);
        buf.writeByte(')');
    }
    return buf.extractString();
}

Loc::Loc(const char *filename, unsigned linnum, unsigned charnum)
{
    this->linnum = linnum;
    this->charnum = charnum;
    this->filename = filename;
}

bool Loc::equals(const Loc& loc)
{
    return (!global.params.showColumns || charnum == loc.charnum) &&
        linnum == loc.linnum && FileName::equals(filename, loc.filename);
}
