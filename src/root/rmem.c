
/* Copyright (c) 2000 Digital Mars      */
/* All Rights Reserved                  */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if linux || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun&&__SVR4
#include "../root/rmem.h"
#else
#include "rmem.h"
#endif

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

/* =================================================== */

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


