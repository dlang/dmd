
// Copyright (c) 1999-2008 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "root.h"
#include "rmem.h"
#include "dchar.h"
#include "lstring.h"
#include "stringtable.h"

StringTable::StringTable(unsigned size)
{
    table = (void **)mem.calloc(size, sizeof(void *));
    tabledim = size;
    count = 0;
}

StringTable::~StringTable()
{
    unsigned i;

    // Zero out dangling pointers to help garbage collector.
    // Should zero out StringEntry's too.
    for (i = 0; i < count; i++)
        table[i] = NULL;

    mem.free(table);
    table = NULL;
}

struct StringEntry
{
    StringEntry *left;
    StringEntry *right;
    hash_t hash;

    StringValue value;

    static StringEntry *alloc(const dchar *s, unsigned len);
};

StringEntry *StringEntry::alloc(const dchar *s, unsigned len)
{
    StringEntry *se;

    se = (StringEntry *) mem.calloc(1,sizeof(StringEntry) - sizeof(Lstring) + Lstring::size(len));
    se->value.lstring.length = len;
    se->hash = Dchar::calcHash(s,len);
    memcpy(se->value.lstring.string, s, len * sizeof(dchar));
    return se;
}

void **StringTable::search(const dchar *s, unsigned len)
{
    hash_t hash;
    unsigned u;
    int cmp;
    StringEntry **se;

    //printf("StringTable::search(%p,%d)\n",s,len);
    hash = Dchar::calcHash(s,len);
    u = hash % tabledim;
    se = (StringEntry **)&table[u];
    //printf("\thash = %d, u = %d\n",hash,u);
    while (*se)
    {
        cmp = (*se)->hash - hash;
        if (cmp == 0)
        {
            cmp = (*se)->value.lstring.len() - len;
            if (cmp == 0)
            {
                cmp = Dchar::memcmp(s,(*se)->value.lstring.toDchars(),len);
                if (cmp == 0)
                    break;
            }
        }
        if (cmp < 0)
            se = &(*se)->left;
        else
            se = &(*se)->right;
    }
    //printf("\treturn %p, %p\n",se, (*se));
    return (void **)se;
}

StringValue *StringTable::lookup(const dchar *s, unsigned len)
{   StringEntry *se;

    se = *(StringEntry **)search(s,len);
    if (se)
        return &se->value;
    else
        return NULL;
}

StringValue *StringTable::update(const dchar *s, unsigned len)
{   StringEntry **pse;
    StringEntry *se;

    pse = (StringEntry **)search(s,len);
    se = *pse;
    if (!se)                    // not in table: so create new entry
    {
        se = StringEntry::alloc(s, len);
        *pse = se;
    }
    return &se->value;
}

StringValue *StringTable::insert(const dchar *s, unsigned len)
{   StringEntry **pse;
    StringEntry *se;

    pse = (StringEntry **)search(s,len);
    se = *pse;
    if (se)
        return NULL;            // error: already in table
    else
    {
        se = StringEntry::alloc(s, len);
        *pse = se;
    }
    return &se->value;
}




