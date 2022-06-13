/**
 * A leaking bump-the-pointer allocator
 *
 * This is only for dmd, not dmc.
 * It implements a heap allocator that never frees.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/ph2.d, backend/ph2.d)
 */

module dmd.backend.ph2;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.global;

extern (C++):

nothrow:

/**********************************************
 * Do our own storage allocator, a replacement
 * for malloc/free.
 */

struct Heap
{
    Heap *prev;         // previous heap
    ubyte *buf;         // buffer
    ubyte *p;           // high water mark
    uint nleft;         // number of bytes left
}

__gshared Heap *heap=null;

void ph_init()
{
    if (!heap) {
        heap = cast(Heap *)calloc(1,Heap.sizeof);
    }
    assert(heap);
}



void ph_term()
{
    //printf("ph_term()\n");
debug
{
    Heap *h;
    Heap *hprev;

    for (h = heap; h; h = hprev)
    {
        hprev = h.prev;
        free(h.buf);
        free(h);
    }
}
}

void ph_newheap(size_t nbytes)
{   uint newsize;
    Heap *h;

    h = cast(Heap *) malloc(Heap.sizeof);
    if (!h)
        err_nomem();

    newsize = (nbytes > 0xFF00) ? cast(uint)nbytes : 0xFF00;
    h.buf = cast(ubyte *) malloc(newsize);
    if (!h.buf)
    {
        free(h);
        err_nomem();
    }
    h.nleft = newsize;
    h.p = h.buf;
    h.prev = heap;
    heap = h;
}

void *ph_malloc(size_t nbytes)
{   ubyte *p;

    nbytes += uint.sizeof * 2;
    nbytes &= ~(uint.sizeof - 1);

    if (nbytes >= heap.nleft)
        ph_newheap(nbytes);
    p = heap.p;
    heap.p += nbytes;
    heap.nleft -= nbytes;
    *cast(uint *)p = cast(uint)(nbytes - uint.sizeof);
    p += uint.sizeof;
    return p;
}

void *ph_calloc(size_t nbytes)
{   void *p;

    p = ph_malloc(nbytes);
    return p ? memset(p,0,nbytes) : p;
}

void ph_free(void *p)
{
}

void *ph_realloc(void *p,size_t nbytes)
{
    //printf("ph_realloc(%p,%d)\n",p,cast(int)nbytes);
    if (!p)
        return ph_malloc(nbytes);
    if (!nbytes)
    {   ph_free(p);
        return null;
    }
    void *newp = ph_malloc(nbytes);
    if (newp)
    {   uint oldsize = (cast(uint *)p)[-1];
        memcpy(newp,p,oldsize);
        ph_free(p);
    }
    return newp;
}

void err_nomem()
{
    printf("Error: out of memory\n");
    err_exit();
}
