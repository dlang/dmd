// Copyright (c) 1999-2008 by Digital Mars
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
#include "dchar.h"
#include "lstring.h"

struct StringValue
{
    union
    {   int intvalue;
        void *ptrvalue;
        dchar *string;
    };
    Lstring lstring;
};

struct StringTable : Object
{
    void **table;
    unsigned count;
    unsigned tabledim;

    StringTable(unsigned size = 37);
    ~StringTable();

    StringValue *lookup(const dchar *s, unsigned len);
    StringValue *insert(const dchar *s, unsigned len);
    StringValue *update(const dchar *s, unsigned len);

private:
    void **search(const dchar *s, unsigned len);
};

#endif
