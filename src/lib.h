
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_LIB_H
#define DMD_LIB_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

Library *LibMSCoff_factory();
Library *LibOMF_factory();
Library *LibElf_factory();
Library *LibMach_factory();

class Library
{
  public:
    static Library *factory()
    {
#if TARGET_WINDOS
        return global.params.is64bit ? LibMSCoff_factory() : LibOMF_factory();
#elif TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        return LibElf_factory();
#elif TARGET_OSX
        return LibMach_factory();
#else
        assert(0); // unsupported system
#endif
    }

    virtual void setFilename(const char *dir, const char *filename) = 0;
    virtual void addObject(const char *module_name, void *buf, size_t buflen) = 0;
    virtual void addLibrary(void *buf, size_t buflen) = 0;
    virtual void write() = 0;
};

#endif /* DMD_LIB_H */

