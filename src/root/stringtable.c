
// Copyright (c) 1999-2013 by Digital Mars
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

// TODO: Merge with root.String
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
                hash += *(const uint16_t *)str;
                return hash;

            case 3:
                hash *= 37;
                hash += (*(const uint16_t *)str << 8) +
                        ((const uint8_t *)str)[2];
                return hash;

            default:
                hash *= 37;
                hash += *(const uint32_t *)str;
                str += 4;
                len -= 4;
                break;
        }
    }
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

void StringTable::reset(size_t size)
{
    for (size_t i = 0; i < count; i++)
        table[i] = NULL;

    mem.free(table);
    table = NULL;
    _init(size);
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

/********************************
 * Walk the contents of the string table,
 * calling fp for each entry.
 * Params:
 *      fp = function to call. Returns !=0 to stop
 * Returns:
 *      last return value of fp call
 */

static int walk(StringEntry *se, int (*fp)(StringValue *))
{
    int result = 0;
    if (se)
    {
        StringValue *sv = &se->value;
        result = (*fp)(sv);
        if (result)
            return result;

        result = walk(se->left, fp);
        if (!result)
            result = walk(se->right, fp);
    }
    return result;
}

int StringTable::apply(int (*fp)(StringValue *))
{
    for (size_t i = 0; i < tabledim; ++i)
    {
        StringEntry *se = (StringEntry *)table[i];
        int result = walk(se, fp);
        if (result)
            return result;
    }
    return 0;
}

