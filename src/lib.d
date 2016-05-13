// Compiler implementation of the D programming language
// Copyright (c) 1999-2016 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.lib;

import ddmd.globals;

// Include all of these once these modules have been ported to all platforms.
version (Windows)
{
    import ddmd.libomf;
    import ddmd.libmscoff;
}
else version (OSX)
{
    import ddmd.libmach;
}
else version (Posix)
{
    import ddmd.libelf;
}
else
{
    static assert(0, "OS not supported.");
}

extern (C++) class Library
{
public:
    static Library factory()
    {
        // This should be turned into runtime logic based on TARGET_* once
        // these library generation modules are made cross-platform.
        version (Windows)
        {
            return (global.params.mscoff || global.params.is64bit) ? LibMSCoff_factory() : LibOMF_factory();
        }
        else version (OSX)
        {
            return LibMach_factory();
        }
        else version (Posix)
        {
            return LibElf_factory();
        }
        else
        {
            static assert(0, "OS not supported.");
        }
    }

    abstract void setFilename(const(char)* dir, const(char)* filename);

    abstract void addObject(const(char)* module_name, void* buf, size_t buflen);

    abstract void addLibrary(void* buf, size_t buflen);

    abstract void write();
}
