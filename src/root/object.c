/* Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/object.c
 */

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
    size_t lhs = (size_t)this;
    size_t rhs = (size_t)obj;
    if (lhs < rhs)
        return -1;
    else if (lhs > rhs)
        return 1;
    return 0;
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
