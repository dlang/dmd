/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2011-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/ti_pvoid.c, backend/ti_pvoid.c)
 */


#include <stdlib.h>

#include "tinfo.h"


// void*

TypeInfo_Pvoid ti_pvoid;

const char* TypeInfo_Pvoid::toString()
{
    return "void*";
}

hash_t TypeInfo_Pvoid::getHash(void *p)
{   void* s = *(void **)p;
    return (hash_t)s;
}

int TypeInfo_Pvoid::equals(void *p1, void *p2)
{
    void* s1 = *(void**)p1;
    void* s2 = *(void**)p2;

    return s1 == s2;
}

int TypeInfo_Pvoid::compare(void *p1, void *p2)
{
    void* s1 = *(void**)p1;
    void* s2 = *(void**)p2;

    return (s1 < s2) ? -1 : ((s1 == s2) ? 0 : 1);
}

size_t TypeInfo_Pvoid::tsize()
{
    return sizeof(void*);
}

void TypeInfo_Pvoid::swap(void *p1, void *p2)
{
}

