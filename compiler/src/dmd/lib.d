/**
 * A module defining an abstract library.
 * Implementations for various formats are in separate `libXXX.d` modules.
 *
 * Copyright:   Copyright (C) 1999-2023 by The D Language Foundation, All Rights Reserved
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
import dmd.location;
import dmd.errorsink;
import dmd.target : Target;
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
    const(char)[] lib_ext;      // library file extension
    ErrorSink eSink;            // where the error messages go

    static Library factory(Target.ObjectFormat of, const char[] lib_ext, ErrorSink eSink)
    {
        Library lib;
        final switch (of)
        {
            case Target.ObjectFormat.elf:   lib = LibElf_factory();     break;
            case Target.ObjectFormat.macho: lib = LibMach_factory();    break;
            case Target.ObjectFormat.coff:  lib = LibMSCoff_factory();  break;
            case Target.ObjectFormat.omf:   lib = LibOMF_factory();     break;
        }
        lib.lib_ext = lib_ext;
        lib.eSink = eSink;
        return lib;
    }

    abstract void addObject(const(char)[] module_name, const ubyte[] buf);

    abstract void writeLibToBuffer(ref OutBuffer libbuf);


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
            arg = FileName.forceExt(n, lib_ext);
        }
        if (!FileName.absolute(arg))
            arg = FileName.combine(dir, arg);

        loc = Loc(FileName.defaultExt(arg, lib_ext).ptr, 0, 0);
    }

    final const(char)* getFilename() const
    {
        return loc.filename;
    }

  public:
    Loc loc;                  // the filename of the library
}
