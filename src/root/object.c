
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>

#include "object.h"
#include "outbuffer.h"

/****************************** Object ********************************/

bool RootObject::equals(RootObject *o)
{
    return o == this;
}

int RootObject::compare(RootObject *obj)
{
    return this - obj;
}

void RootObject::print()
{
    printf("%s %p\n", toChars(), this);
}

char *RootObject::toChars()
{
    return (char *)"Object";
}

int RootObject::dyncast()
{
    return 0;
}

void RootObject::toBuffer(OutBuffer *b)
{
    b->writestring("Object");
}
