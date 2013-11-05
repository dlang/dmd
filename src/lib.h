
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

class Library
{
  public:
    static Library *factory();

    virtual void setFilename(const char *dir, const char *filename) = 0;
    virtual void addObject(const char *module_name, void *buf, size_t buflen) = 0;
    virtual void addLibrary(void *buf, size_t buflen) = 0;
    virtual void write() = 0;
};

Library *LibMSCoff_factory();

#endif /* DMD_LIB_H */

