/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _lib.d)
 */

module ddmd.lib;

import ddmd.globals;

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

    abstract void setFilename(const(char)* dir, const(char)* filename);

    abstract void addObject(const(char)* module_name, const ubyte[] buf);

    abstract void addLibrary(const ubyte[] buf);

    abstract void write();
}

extern (C++) void addObjectToLibrary(Library lib, const(char)* module_name, const(ubyte)* buf, size_t buflen)
{
    lib.addObject(module_name, buf[0 .. buflen]);
}
