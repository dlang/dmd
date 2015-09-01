// Compiler implementation of the D programming language
// Copyright (c) 2000-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt
// https://github.com/D-Programming-Language/dmd/blob/master/src/root/rmem.h

#ifndef ROOT_MEM_H
#define ROOT_MEM_H

#include <stddef.h>     // for size_t

#if __APPLE__ && __i386__
    /* size_t is 'unsigned long', which makes it mangle differently
     * than D's 'uint'
     */
    typedef unsigned d_size_t;
#else
    typedef size_t d_size_t;
#endif

struct Mem
{
    Mem() { }

    char *xstrdup(const char *s);
    void *xmalloc(d_size_t size);
    void *xcalloc(d_size_t size, d_size_t n);
    void *xrealloc(void *p, d_size_t size);
    void xfree(void *p);
    void *xmallocdup(void *o, d_size_t size);
    void error();
};

extern Mem mem;

#endif /* ROOT_MEM_H */
