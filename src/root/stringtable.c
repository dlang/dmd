
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#include <stdio.h>
#include <stdint.h>                     // uint{8|16|32}_t
#include <string.h>                     // memcpy()
#include <stdlib.h>

#include "root.h"
#include "rmem.h"                       // mem
#include "stringtable.h"

hash_t calcHash(const char *str, size_t len)
{
    hash_t hash = 0;

    while (1)
    {
        switch (len)
        {
            case 0:
                return hash;

            case 1:
                hash *= 37;
                hash += *(const uint8_t *)str;
                return hash;

            case 2:
                hash *= 37;
#if LITTLE_ENDIAN
                hash += *(const uint16_t *)str;
#else
                hash += str[0] * 256 + str[1];
#endif
                return hash;

            case 3:
                hash *= 37;
#if LITTLE_ENDIAN
                hash += (*(const uint16_t *)str << 8) +
                        ((const uint8_t *)str)[2];
#else
                hash += (str[0] * 256 + str[1]) * 256 + str[2];
#endif
                return hash;

            default:
                hash *= 37;
#if LITTLE_ENDIAN
                hash += *(const uint32_t *)str;
#else
                hash += ((str[0] * 256 + str[1]) * 256 + str[2]) * 256 + str[3];
#endif
                str += 4;
                len -= 4;
                break;
        }
    }
}

void StringValue::ctor(const char *p, unsigned length)
{
    this->length = length;
    this->lstring[length] = 0;
    memcpy(this->lstring, p, length * sizeof(char));
}

void StringTable::init(unsigned size)
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

    static StringEntry *alloc(const char *s, unsigned len);
};

StringEntry *StringEntry::alloc(const char *s, unsigned len)
{
    StringEntry *se;

    se = (StringEntry *) mem.calloc(1,sizeof(StringEntry) + len + 1);
    se->value.ctor(s, len);
    se->hash = calcHash(s,len);
    return se;
}

void **StringTable::search(const char *s, unsigned len)
{
    hash_t hash;
    unsigned u;
    int cmp;
    StringEntry **se;

    //printf("StringTable::search(%p,%d)\n",s,len);
    hash = calcHash(s,len);
    u = hash % tabledim;
    se = (StringEntry **)&table[u];
    //printf("\thash = %d, u = %d\n",hash,u);
    while (*se)
    {
        cmp = (*se)->hash - hash;
        if (cmp == 0)
        {
            cmp = (*se)->value.len() - len;
            if (cmp == 0)
            {
                cmp = ::memcmp(s,(*se)->value.toDchars(),len);
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

StringValue *StringTable::lookup(const char *s, unsigned len)
{   StringEntry *se;

    se = *(StringEntry **)search(s,len);
    if (se)
        return &se->value;
    else
        return NULL;
}

StringValue *StringTable::update(const char *s, unsigned len)
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

StringValue *StringTable::insert(const char *s, unsigned len)
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
