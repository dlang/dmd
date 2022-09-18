/**
 * A module defining an abstract library.
 * Implementations for various formats are in separate `libXXX.d` modules.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/lib.d, _lib.d)
 * Documentation:  https://dlang.org/phobos/dmd_lib.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/lib.d
 */

module dmd.lib;

import core.stdc.stdio;
import core.stdc.stdarg;

import dmd.globals;
import dmd.errors;
import dmd.target;
import dmd.utils;

import dmd.common.outbuffer;
import dmd.root.file;
import dmd.root.filename;
import dmd.root.string;

import dmd.libomf;
import dmd.libmscoff;
import dmd.libelf;
import dmd.libmach;

private enum LOG = false;

class Library
{
    static Library factory()
    {
        final switch (target.objectFormat())
        {
            case Target.ObjectFormat.elf:   return LibElf_factory();
            case Target.ObjectFormat.macho: return LibMach_factory();
            case Target.ObjectFormat.coff:  return LibMSCoff_factory();
            case Target.ObjectFormat.omf:   return LibOMF_factory();
        }
    }

    abstract void addObject(const(char)[] module_name, const ubyte[] buf);

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
            arg = FileName.forceExt(n, target.lib_ext);
        }
        if (!FileName.absolute(arg))
            arg = FileName.combine(dir, arg);

        loc = Loc(FileName.defaultExt(arg, target.lib_ext).ptr, 0, 0);
    }

    final const(char)* getFilename() const
    {
        return loc.filename;
    }

    final void write()
    {
        if (global.params.verbose)
            message("library   %s", loc.filename);

        auto filenameString = loc.filename.toDString;
        ensurePathToNameExists(Loc.initial, filenameString);
        auto tmpname = filenameString ~ ".tmp\0";
        scope(exit) destroy(tmpname);

        auto libbuf = OutBuffer(tmpname.ptr);
        WriteLibToBuffer(&libbuf);

        if (!libbuf.moveToFile(loc.filename))
        {
            .error(loc, "error writing file '%s'", loc.filename);
            fatal();
        }
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
