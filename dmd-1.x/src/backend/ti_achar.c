
// Copyright (c) 2006-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gpl.txt.
// See the included readme.txt for details.


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

