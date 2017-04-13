/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/tinfo.h
 */


#ifndef TYPEINFO_H
#define TYPEINFO_H

#include <stdlib.h>

typedef size_t hash_t;

struct TypeInfo
{
    virtual const char* toString() = 0;
    virtual hash_t getHash(void *p) = 0;
    virtual int equals(void *p1, void *p2) = 0;
    virtual int compare(void *p1, void *p2) = 0;
    virtual size_t tsize() = 0;
    virtual void swap(void *p1, void *p2) = 0;
};

struct TypeInfo_Achar : TypeInfo
{
    const char* toString();
    hash_t getHash(void *p);
    int equals(void *p1, void *p2);
    int compare(void *p1, void *p2);
    size_t tsize();
    void swap(void *p1, void *p2);
};

extern TypeInfo_Achar ti_achar;

struct TypeInfo_Pvoid : TypeInfo
{
    const char* toString();
    hash_t getHash(void *p);
    int equals(void *p1, void *p2);
    int compare(void *p1, void *p2);
    size_t tsize();
    void swap(void *p1, void *p2);
};

extern TypeInfo_Pvoid ti_pvoid;

#endif
