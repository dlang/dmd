
/* Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/stringtable.h
 */

#ifndef STRINGTABLE_H
#define STRINGTABLE_H

#if __SC__
#pragma once
#endif

#include "root.h"
#include "rmem.h"   // for d_size_t

struct StringEntry;

// StringValue is a variable-length structure. It has neither proper c'tors nor a
// factory method because the only thing which should be creating these is StringTable.
struct StringValue
{
    void *ptrvalue;
    size_t length;
    char *lstring() { return (char *)(this + 1); }

    size_t len() const { return length; }
    const char *toDchars() const { return (const char *)(this + 1); }

    StringValue();  // not constructible
};

struct StringTable
{
private:
    StringEntry *table;
    size_t tabledim;

    uint8_t **pools;
    size_t npools;
    size_t nfill;

    size_t count;

public:
    void _init(d_size_t size = 0);
    void reset(d_size_t size = 0);
    ~StringTable();

    StringValue *lookup(const char *s, d_size_t len);
    StringValue *insert(const char *s, d_size_t len);
    StringValue *update(const char *s, d_size_t len);
    int apply(int (*fp)(StringValue *));

private:
    uint32_t allocValue(const char *p, d_size_t length);
    StringValue *getValue(uint32_t validx);
    size_t findSlot(hash_t hash, const char *s, d_size_t len);
    void grow();
};

#endif
