// Compiler implementation of the D programming language
// Copyright (c) 2000-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt
// https://github.com/D-Programming-Language/dmd/blob/master/src/root/rmem.h

#ifndef ROOT_MEM_H
#define ROOT_MEM_H

#include <stddef.h>     // for size_t

struct Mem
{
    Mem() { }

    char *xstrdup(const char *s);
    void *xmalloc(size_t size);
    void *xcalloc(size_t size, size_t n);
    void *xrealloc(void *p, size_t size);
    void xfree(void *p);
    void *xmallocdup(void *o, size_t size);
    void error();
};

extern Mem mem;

#endif /* ROOT_MEM_H */
