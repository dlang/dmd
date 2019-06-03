/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/lib.d, _lib.d)
 * Documentation:  https://dlang.org/phobos/dmd_lib.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/lib.d
 */

module dmd.lib;

import core.stdc.stdio;
import core.stdc.stdarg;

import dmd.globals;
import dmd.errors;
import dmd.utils;

import dmd.root.outbuffer;
import dmd.root.file;
import dmd.root.filename;

static if (TARGET.Windows)
{
    import dmd.libomf;
    import dmd.libmscoff;
}
else static if (TARGET.Linux || TARGET.FreeBSD || TARGET.OpenBSD || TARGET.Solaris || TARGET.DragonFlyBSD)
{
    import dmd.libelf;
}
else static if (TARGET.OSX)
{
    import dmd.libmach;
}
else
{
    static assert(0, "unsupported system");
}

private enum LOG = false;

class Library
{
    static Library factory()
    {
        static if (TARGET.Windows)
        {
            return (global.params.mscoff || global.params.is64bit) ? LibMSCoff_factory() : LibOMF_factory();
        }
        else static if (TARGET.Linux || TARGET.FreeBSD || TARGET.OpenBSD || TARGET.Solaris || TARGET.DragonFlyBSD)
        {
            return LibElf_factory();
        }
        else static if (TARGET.OSX)
        {
            return LibMach_factory();
        }
        else
        {
            assert(0); // unsupported system
        }
    }

    abstract void addObject(const(char)* module_name, const ubyte[] buf);

    protected abstract void WriteLibToBuffer(OutBuffer* libbuf);


    /***********************************
     * Set the library file name based on the output directory
     * and the filename.
     * Add default library file name extension.
     * Params:
     *  dir = path to file
     *  filename = name of file relative to `dir`
     */
    final void setFilename(const(char)[] dir, const(char)[] filename)
    {
        static if (LOG)
        {
            printf("LibElf::setFilename(dir = '%.*s', filename = '%.*s')\n",
                   cast(int)dir.length, dir.ptr, cast(int)filename.length, filename.ptr);
        }
        const(char)[] arg = filename;
        if (!arg.length)
        {
            // Generate lib file name from first obj name
            const(char)[] n = global.params.objfiles[0].toDString;
            n = FileName.name(n);
            arg = FileName.forceExt(n, global.lib_ext);
        }
        if (!FileName.absolute(arg))
            arg = FileName.combine(dir, arg);

        loc = Loc(FileName.defaultExt(arg, global.lib_ext).ptr, 0, 0);
    }

    final void write()
    {
        if (global.params.verbose)
            message("library   %s", loc.filename);

        OutBuffer libbuf;
        WriteLibToBuffer(&libbuf);

        writeFile(Loc.initial, loc.filename.toDString, libbuf.peekSlice());
    }

    final void error(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        .verror(loc, format, ap);
        va_end(ap);
    }

  protected:
    Loc loc;                  // the filename of the library
}

version (D_LP64)
    alias cpp_size_t = size_t;
else version (OSX)
{
    import core.stdc.config : cpp_ulong;
    alias cpp_size_t = cpp_ulong;
}
else
    alias cpp_size_t = size_t;
