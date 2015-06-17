
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

#define POOL_BITS 12
#define POOL_SIZE (1U << POOL_BITS)

// TODO: Merge with root.String
// MurmurHash2 was written by Austin Appleby, and is placed in the public
// domain. The author hereby disclaims copyright to this source code.
// https://sites.google.com/site/murmurhash/
static uint32_t calcHash(const char *key, size_t len)
{
    // 'm' and 'r' are mixing constants generated offline.
    // They're not really 'magic', they just happen to work well.

    const uint32_t m = 0x5bd1e995;
    const int r = 24;

    // Initialize the hash to a 'random' value

    uint32_t h = (uint32_t)len;

    // Mix 4 bytes at a time into the hash

    const uint8_t *data = (const uint8_t *)key;

    while(len >= 4)
    {
        uint32_t k = data[3] << 24 | data[2] << 16 | data[1] << 8 | data[0];

        k *= m;
        k ^= k >> r;
        k *= m;

        h *= m;
        h ^= k;

        data += 4;
        len -= 4;
    }

    // Handle the last few bytes of the input array

    switch(len & 3)
    {
    case 3: h ^= data[2] << 16;
    case 2: h ^= data[1] << 8;
    case 1: h ^= data[0];
        h *= m;
    }

    // Do a few final mixes of the hash to ensure the last few
    // bytes are well-incorporated.

    h ^= h >> 13;
    h *= m;
    h ^= h >> 15;

    return h;
}

struct StringEntry
{
    uint32_t hash;
    uint32_t vptr;
};

uint32_t StringTable::allocValue(const char *s, size_t length)
{
    const size_t nbytes = sizeof(StringValue) + length + 1;

    if (!npools || nfill + nbytes > POOL_SIZE)
    {
        pools = (uint8_t **)mem.xrealloc(pools, ++npools * sizeof(pools[0]));
        pools[npools - 1] = (uint8_t *)mem.xmalloc(nbytes > POOL_SIZE ? nbytes : POOL_SIZE);
        nfill = 0;
    }

    StringValue *sv = (StringValue *)&pools[npools - 1][nfill];
    sv->ptrvalue = NULL;
    sv->length = length;
    ::memcpy(sv->lstring(), s, length);
    sv->lstring()[length] = 0;

    const uint32_t vptr = (uint32_t)(npools << POOL_BITS | nfill);
    nfill += nbytes + (-nbytes & 7); // align to 8 bytes
    return vptr;
}

StringValue *StringTable::getValue(uint32_t vptr)
{
    if (!vptr) return NULL;

    const size_t idx = (vptr >> POOL_BITS) - 1;
    const size_t off = vptr & POOL_SIZE - 1;
    return (StringValue *)&pools[idx][off];
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
    table = (StringEntry *)mem.xcalloc(size, sizeof(table[0]));
    tabledim = size;
    pools = NULL;
    npools = nfill = 0;
    count = 0;
}

void StringTable::reset(size_t size)
{
    for (size_t i = 0; i < npools; ++i)
        mem.xfree(pools[i]);

    mem.xfree(table);
    mem.xfree(pools);
    table = NULL;
    pools = NULL;
    _init(size);
}

StringTable::~StringTable()
{
    for (size_t i = 0; i < npools; ++i)
        mem.xfree(pools[i]);

    mem.xfree(table);
    mem.xfree(pools);
    table = NULL;
    pools = NULL;
}

size_t StringTable::findSlot(hash_t hash, const char *s, size_t length)
{
    // quadratic probing using triangular numbers
    // http://stackoverflow.com/questions/2348187/moving-from-linear-probing-to-quadratic-probing-hash-collisons/2349774#2349774
    for (size_t i = hash & (tabledim - 1), j = 1; ;++j)
    {
        StringValue *sv;
        if (!table[i].vptr ||
            table[i].hash == hash &&
            (sv = getValue(table[i].vptr))->length == length &&
            ::memcmp(s, sv->lstring(), length) == 0)
            return i;
        i = (i + j) & (tabledim - 1);
    }
}

StringValue *StringTable::lookup(const char *s, size_t length)
{
    const hash_t hash = calcHash(s, length);
    const size_t i = findSlot(hash, s, length);
    // printf("lookup %.*s %p\n", (int)length, s, table[i].value ?: NULL);
    return getValue(table[i].vptr);
}

StringValue *StringTable::update(const char *s, size_t length)
{
    const hash_t hash = calcHash(s, length);
    size_t i = findSlot(hash, s, length);
    if (!table[i].vptr)
    {
        if (++count > tabledim * loadFactor)
        {
            grow();
            i = findSlot(hash, s, length);
        }
        table[i].hash = hash;
        table[i].vptr = allocValue(s, length);
    }
    // printf("update %.*s %p\n", (int)length, s, table[i].value ?: NULL);
    return getValue(table[i].vptr);
}

StringValue *StringTable::insert(const char *s, size_t length)
{
    const hash_t hash = calcHash(s, length);
    size_t i = findSlot(hash, s, length);
    if (table[i].vptr)
        return NULL; // already in table
    if (++count > tabledim * loadFactor)
    {
        grow();
        i = findSlot(hash, s, length);
    }
    table[i].hash = hash;
    table[i].vptr = allocValue(s, length);
    // printf("insert %.*s %p\n", (int)length, s, table[i].value ?: NULL);
    return getValue(table[i].vptr);
}

void StringTable::grow()
{
    const size_t odim = tabledim;
    StringEntry *otab = table;
    tabledim *= 2;
    table = (StringEntry *)mem.xcalloc(tabledim, sizeof(table[0]));

    for (size_t i = 0; i < odim; ++i)
    {
        StringEntry *se = &otab[i];
        if (!se->vptr) continue;
        StringValue *sv = getValue(se->vptr);
        table[findSlot(se->hash, sv->lstring(), sv->length)] = *se;
    }
    mem.xfree(otab);
}

/********************************
 * Walk the contents of the string table,
 * calling fp for each entry.
 * Params:
 *      fp = function to call. Returns !=0 to stop
 * Returns:
 *      last return value of fp call
 */
int StringTable::apply(int (*fp)(StringValue *))
{
    for (size_t i = 0; i < tabledim; ++i)
    {
        StringEntry *se = &table[i];
        if (!se->vptr) continue;
        StringValue *sv = getValue(se->vptr);
        int result = (*fp)(sv);
        if (result)
            return result;
    }
    return 0;
}

