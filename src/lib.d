// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.lib;

import ddmd.globals;

extern (C++) Library LibOMF_factory();
extern (C++) Library LibElf_factory();
extern (C++) Library LibMSCoff_factory();
extern (C++) Library LibMach_factory();

extern (C++) class Library
{
public:
    final static Library factory()
    {
        static if (TARGET_WINDOS)
        {
            return global.params.is64bit ? LibMSCoff_factory() : LibOMF_factory();
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

    abstract void addObject(const(char)* module_name, void* buf, size_t buflen);

    abstract void addLibrary(void* buf, size_t buflen);

    abstract void write();
}
