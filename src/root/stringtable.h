
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#ifndef STRINGTABLE_H
#define STRINGTABLE_H

#if __SC__
#pragma once
#endif

#include "root.h"

struct StringEntry;

// StringValue is a variable-length structure as indicated by the last array
// member with unspecified size.  It has neither proper c'tors nor a factory
// method because the only thing which should be creating these is StringTable.
struct StringValue
{
    void *ptrvalue;
private:
    size_t length;

#ifndef IN_GCC
    // Disable warning about nonstandard extension
    #pragma warning (disable : 4200)
#endif
    char lstring[];

public:
    size_t len() const { return length; }
    const char *toDchars() const { return lstring; }

private:
    friend struct StringEntry;
    StringValue();  // not constructible
    // This is more like a placement new c'tor
    void ctor(const char *p, size_t length);
};

struct StringTable
{
private:
    void **table;
    size_t count;
    size_t tabledim;

public:
    void _init(size_t size = 37);
    void reset(size_t size = 0);
    ~StringTable();

    StringValue *lookup(const char *s, size_t len);
    StringValue *insert(const char *s, size_t len);
    StringValue *update(const char *s, size_t len);
    int apply(int (*fp)(StringValue *));

private:
    void **search(const char *s, size_t len);
};

#endif
