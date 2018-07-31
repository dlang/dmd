/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2006-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/ti_achar.c, backend/ti_achar.c)
 */


#include <string.h>
#include <stdlib.h>

#include "tinfo.h"


// char*

TypeInfo_Achar ti_achar;

const char* TypeInfo_Achar::toString()
{
    return "char*";
}

hash_t TypeInfo_Achar::getHash(void *p)
{   char* s;
    hash_t hash = 0;

    for (s = *(char**)p; *s; s++)
    {
        hash = hash * 11 + *s;
    }
    return hash;
}

int TypeInfo_Achar::equals(void *p1, void *p2)
{
    char* s1 = *(char**)p1;
    char* s2 = *(char**)p2;

    return strcmp(s1, s2) == 0;
}

int TypeInfo_Achar::compare(void *p1, void *p2)
{
    char* s1 = *(char**)p1;
    char* s2 = *(char**)p2;

    return strcmp(s1, s2);
}

size_t TypeInfo_Achar::tsize()
{
    return sizeof(char*);
}

void TypeInfo_Achar::swap(void *p1, void *p2)
{
}

