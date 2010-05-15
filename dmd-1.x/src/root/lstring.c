// lstring.c

// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdlib.h>

#include "dchar.h"
#include "rmem.h"
#include "lstring.h"

#ifdef _MSC_VER // prevent compiler internal crash
Lstring Lstring::zero;
#else
Lstring Lstring::zero = LSTRING_EMPTY();
#endif

Lstring *Lstring::ctor(const dchar *p, unsigned length)
{
    Lstring *s;

    s = alloc(length);
    memcpy(s->string, p, length * sizeof(dchar));
    return s;
}

Lstring *Lstring::alloc(unsigned length)
{
    Lstring *s;

    s = (Lstring *)mem.malloc(size(length));
    s->length = length;
    s->string[length] = 0;
    return s;
}

Lstring *Lstring::append(const Lstring *s)
{
    Lstring *t;

    if (!s->length)
        return this;
    t = alloc(length + s->length);
    memcpy(t->string, string, length * sizeof(dchar));
    memcpy(t->string + length, s->string, s->length * sizeof(dchar));
    return t;
}

Lstring *Lstring::substring(int start, int end)
{
    Lstring *t;

    if (start == end)
        return &zero;
    t = alloc(end - start);
    memcpy(t->string, string + start, (end - start) * sizeof(dchar));
    return t;
}
