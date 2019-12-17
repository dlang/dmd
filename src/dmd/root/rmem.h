
/* Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/root/rmem.h
 */

#pragma once

#include "dsystem.h"    // for size_t

#if __APPLE__ && __i386__
    /* size_t is 'unsigned long', which makes it mangle differently
     * than D's 'uint'
     */
    typedef unsigned d_size_t;
#elif MARS && DMD_VERSION >= 2079 && DMD_VERSION <= 2081 && \
        __APPLE__ && __SIZEOF_SIZE_T__ == 8
    /* DMD versions between 2.079 and 2.081 mapped D ulong to uint64_t on OS X.
     */
    typedef uint64_t d_size_t;
#else
    typedef size_t d_size_t;
#endif

struct Mem
{
    Mem() { }

    static char *xstrdup(const char *s);
    static void xfree(void *p);
    static void *xmalloc(d_size_t size);
    static void *xcalloc(d_size_t size, d_size_t n);
    static void *xrealloc(void *p, d_size_t size);
    static void error();

#if 1 // version (GC)
    static bool _isGCEnabled;

    static bool isGCEnabled();
    static void disableGC();
    static void addRange(const void *p, d_size_t size);
    static void removeRange(const void *p);
#endif
};

extern Mem mem;
