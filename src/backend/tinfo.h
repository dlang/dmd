// Compiler implementation of the D programming language
// Copyright (c) 2000-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt
// https://github.com/D-Programming-Language/dmd/blob/master/src/backend/tinfo.h


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
