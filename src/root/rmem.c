
// Copyright (c) 2000-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "rmem.h"

/* This implementation of the storage allocator uses the standard C allocation package.
 */

Mem mem;

void Mem::init()
{
}

char *Mem::strdup(const char *s)
{
    char *p;

    if (s)
    {
        p = ::strdup(s);
        if (p)
            return p;
        error();
    }
    return NULL;
}

void *Mem::malloc(size_t size)
{   void *p;

    if (!size)
        p = NULL;
    else
    {
        p = ::malloc(size);
        if (!p)
            error();
    }
    return p;
}

void *Mem::calloc(size_t size, size_t n)
{   void *p;

    if (!size || !n)
        p = NULL;
    else
    {
        p = ::calloc(size, n);
        if (!p)
            error();
    }
    return p;
}

void *Mem::realloc(void *p, size_t size)
{
    if (!size)
    {   if (p)
        {   ::free(p);
            p = NULL;
        }
    }
    else if (!p)
    {
        p = ::malloc(size);
        if (!p)
            error();
    }
    else
    {
        void *psave = p;
        p = ::realloc(psave, size);
        if (!p)
        {   free(psave);
            error();
        }
    }
    return p;
}

void Mem::free(void *p)
{
    if (p)
        ::free(p);
}

void *Mem::mallocdup(void *o, size_t size)
{   void *p;

    if (!size)
        p = NULL;
    else
    {
        p = ::malloc(size);
        if (!p)
            error();
        else
            memcpy(p,o,size);
    }
    return p;
}

void Mem::error()
{
    printf("Error: out of memory\n");
    exit(EXIT_FAILURE);
}

void Mem::fullcollect()
{
}

void Mem::mark(void *pointer)
{
    (void) pointer;             // necessary for VC /W4
}

void Mem::setStackBottom(void *bottom)
{
}

void Mem::addroots(char* pStart, char* pEnd)
{
}


/* =================================================== */

#if 1

/* Allocate, but never release
 */

#define CHUNK_SIZE (4096 * 16)

static size_t heapleft = 0;
static void *heapp;

void * operator new(size_t m_size)
{
    // 16 byte alignment is better (and sometimes needed) for doubles
    m_size = (m_size + 15) & ~15;

    // The layout of the code is selected so the most common case is straight through
    if (m_size <= heapleft)
    {
     L1:
        heapleft -= m_size;
        void *p = heapp;
        heapp = (void *)((char *)heapp + m_size);
        return p;
    }

    if (m_size > CHUNK_SIZE)
    {
        void *p = malloc(m_size);
        if (p)
            return p;
        printf("Error: out of memory\n");
        exit(EXIT_FAILURE);
        return p;
    }

    heapleft = CHUNK_SIZE;
    heapp = malloc(CHUNK_SIZE);
    if (!heapp)
    {
        printf("Error: out of memory\n");
        exit(EXIT_FAILURE);
    }
    goto L1;
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
