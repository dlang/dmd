
/* Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/stringtable.c
 */

#include <stdio.h>
#include <stdint.h>                     // uint{8|16|32}_t
#include <string.h>                     // memcpy()
#include <stdlib.h>

#include "root.h"
#include "rmem.h"                       // mem
#include "stringtable.h"

// TODO: Merge with root.String
hash_t calcHash(const char *str, size_t len)
{
    hash_t hash = 0;

    union
    {
        uint8_t  scratchB[4];
        uint16_t scratchS[2];
        uint32_t scratchI;
    };
    
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
                scratchB[0] = str[0];
                scratchB[1] = str[1];
                hash += scratchS[0];
                return hash;

            case 3:
                hash *= 37;
                scratchB[0] = str[0];
                scratchB[1] = str[1];
                hash += (scratchS[0] << 8) +
                        ((const uint8_t *)str)[2];
                return hash;

            default:
                hash *= 37;
                scratchB[0] = str[0];
                scratchB[1] = str[1];
                scratchB[2] = str[2];
                scratchB[3] = str[3];
                hash += scratchI;
                str += 4;
                len -= 4;
                break;
        }
    }
}

static int hashCmp(hash_t lhs, hash_t rhs)
{
    if (lhs == rhs)
        return 0;
    else if (lhs < rhs)
        return -1;
    return 1;
}

void StringValue::ctor(const char *p, size_t length)
{
    this->length = length;
    this->lstring[length] = 0;
    memcpy(this->lstring, p, length * sizeof(char));
}

void StringTable::_init(size_t size)
{
    table = (void **)mem.calloc(size, sizeof(void *));
    tabledim = size;
    count = 0;
}

StringTable::~StringTable()
{
    // Zero out dangling pointers to help garbage collector.
    // Should zero out StringEntry's too.
    for (size_t i = 0; i < count; i++)
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

    static StringEntry *alloc(const char *s, size_t len);
};

StringEntry *StringEntry::alloc(const char *s, size_t len)
{
    StringEntry *se;

    se = (StringEntry *) mem.calloc(1,sizeof(StringEntry) + len + 1);
    se->value.ctor(s, len);
    se->hash = calcHash(s,len);
    return se;
}

void **StringTable::search(const char *s, size_t len)
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
        cmp = hashCmp((*se)->hash, hash);
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

StringValue *StringTable::lookup(const char *s, size_t len)
{   StringEntry *se;

    se = *(StringEntry **)search(s,len);
    if (se)
        return &se->value;
    else
        return NULL;
}

StringValue *StringTable::update(const char *s, size_t len)
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

StringValue *StringTable::insert(const char *s, size_t len)
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
