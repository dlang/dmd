
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

struct StringEntry
{
    hash_t hash;
    StringValue *value;

    StringEntry(hash_t hash, const char* s, size_t length)
        : hash(hash)
        , value(StringValue::alloc(s, length))
    {
    }

    bool equals(hash_t hash, const char* s, size_t length)
    {
        return this->hash == hash && this->value->length == length &&
            ::memcmp(this->value->lstring, s, length) == 0;
    }

};

StringValue *StringValue::alloc(const char *p, size_t length)
{
    StringValue *sv = (StringValue *)mem.malloc(sizeof(StringValue) + length + 1);
    sv->ptrvalue = NULL;
    sv->length = length;
    ::memcpy(sv->lstring, p, length);
    sv->lstring[length] = 0;
    return sv;
}

static size_t nextpow2(size_t val)
{
    size_t res = 1;
    while (res < val)
        res <<= 1;
    return res;
}

static const double loadFactor = 0.8;

void StringTable::_init(size_t size)
{
    size = nextpow2((size_t)(size / loadFactor));
    if (size < 32) size = 32;
    table = (StringEntry *)mem.calloc(size, sizeof(table[0]));
    tabledim = size;
    count = 0;
}

StringTable::~StringTable()
{
    for (size_t i = 0; i < tabledim; i++)
        if (table[i].value)
            mem.free(table[i].value);

    // Zero out dangling pointers to help garbage collector.
    memset(table, 0, tabledim * sizeof(table[0]));
    mem.free(table);
    table = NULL;
}

size_t StringTable::findSlot(hash_t hash, const char *s, size_t length)
{
    // quadratic probing using triangular numbers
    // http://stackoverflow.com/questions/2348187/moving-from-linear-probing-to-quadratic-probing-hash-collisons/2349774#2349774
    for (size_t i = hash & (tabledim - 1), j = 1; ;++j)
    {
        if (!table[i].value || (table[i].equals(hash, s, length)))
            return i;
        i = (i + j) & (tabledim - 1);
    }
}

StringValue *StringTable::lookup(const char *s, size_t length)
{
    const hash_t hash = calcHash(s, length);
    const size_t i = findSlot(hash, s, length);
    // printf("lookup %.*s %p\n", (int)length, s, table[i].value ?: NULL);
    return table[i].value;
}

StringValue *StringTable::update(const char *s, size_t length)
{
    const hash_t hash = calcHash(s, length);
    size_t i = findSlot(hash, s, length);
    if (!table[i].value)
    {
        if (++count > tabledim * loadFactor)
        {
            grow();
            i = findSlot(hash, s, length);
        }
        table[i] = StringEntry(hash, s, length);
    }
    // printf("update %.*s %p\n", (int)length, s, table[i].value ?: NULL);
    return table[i].value;
}

StringValue *StringTable::insert(const char *s, size_t length)
{
    const hash_t hash = calcHash(s, length);
    size_t i = findSlot(hash, s, length);
    if (!table[i].value)
    {
        if (++count > tabledim * loadFactor)
        {
            grow();
            i = findSlot(hash, s, length);
        }
        table[i] = StringEntry(hash, s, length);
    }
    // printf("insert %.*s %p\n", (int)length, s, table[i].value ?: NULL);
    return table[i].value;
}

void StringTable::grow()
{
    const size_t odim = tabledim;
    StringEntry *otab = table;
    tabledim *= 2;
    table = (StringEntry *)mem.calloc(tabledim, sizeof(table[0]));

    for (size_t i = 0; i < odim; ++i)
    {
        StringEntry &se = otab[i];
        if (!se.value) continue;
        table[findSlot(se.hash, se.value->toDchars(), se.value->len())] = se;
    }

    memset(otab, 0, odim * sizeof(otab[0]));
    mem.free(otab);
}
