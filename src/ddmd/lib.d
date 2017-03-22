/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _lib.d)
 */

module ddmd.lib;

import core.stdc.stdio;
import core.stdc.stdarg;

import ddmd.globals;
import ddmd.errors;
import ddmd.utils;

import ddmd.root.outbuffer;
import ddmd.root.file;
import ddmd.root.filename;

static if (TARGET_WINDOS)
{
    import ddmd.libomf;
    import ddmd.libmscoff;
}
else static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
{
    import ddmd.libelf;
}
else static if (TARGET_OSX)
{
    import ddmd.libmach;
}
else
{
    static assert(0, "unsupported system");
}

enum LOG = false;

class Library
{
    static Library factory()
    {
        static if (TARGET_WINDOS)
        {
            return (global.params.mscoff || global.params.is64bit) ? LibMSCoff_factory() : LibOMF_factory();
        }
        else static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
        {
            return LibElf_factory();
        }
        else static if (TARGET_OSX)
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
    final void setFilename(const(char)* dir, const(char)* filename)
    {
        static if (LOG)
        {
            printf("LibElf::setFilename(dir = '%s', filename = '%s')\n", dir ? dir : "", filename ? filename : "");
        }
        const(char)* arg = filename;
        if (!arg || !*arg)
        {
            // Generate lib file name from first obj name
            const(char)* n = (*global.params.objfiles)[0];
            n = FileName.name(n);
            arg = FileName.forceExt(n, global.lib_ext);
        }
        if (!FileName.absolute(arg))
            arg = FileName.combine(dir, arg);

        loc.filename = FileName.defaultExt(arg, global.lib_ext);
        loc.linnum = 0;
        loc.charnum = 0;
    }

    final void write()
    {
        if (global.params.verbose)
            fprintf(global.stdmsg, "library   %s\n", loc.filename);

        OutBuffer libbuf;
        WriteLibToBuffer(&libbuf);

        // Transfer image to file
        File* libfile = File.create(loc.filename);
        libfile.setbuffer(libbuf.data, libbuf.offset);
        libbuf.extractData();
        ensurePathToNameExists(Loc(), libfile.name.toChars());
        writeFile(Loc(), libfile);
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

extern (C++) void addObjectToLibrary(Library lib, const(char)* module_name, const(ubyte)* buf, cpp_size_t buflen)
{
    lib.addObject(module_name, buf[0 .. buflen]);
}
