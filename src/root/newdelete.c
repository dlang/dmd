
/* Copyright (c) 2000-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/rmem.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__has_feature)
#if __has_feature(address_sanitizer)
#define USE_ASAN_NEW_DELETE
#endif
#endif

#if !defined(USE_ASAN_NEW_DELETE)

#if 1

void *allocmemory(size_t m_size);

void * operator new(size_t m_size)
{
    return allocmemory(m_size);
}

void operator delete(void *p)
{
}

#else

void * operator new(size_t m_size)
{
    void *p = malloc(m_size);
    if (p)
        return p;
    printf("Error: out of memory\n");
    exit(EXIT_FAILURE);
    return p;
}

void operator delete(void *p)
{
    free(p);
}

#endif

#endif
