

// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include        <stdio.h>
#include        <time.h>
#include        <string.h>
#include        <stdlib.h>

#if __DMC__
#include        <new.h>
#else
#include        <new>
#endif

#include        "cc.h"
#include        "global.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/**********************************************
 * Do our own storage allocator, a replacement
 * for malloc/free.
 */

struct Heap
{
    Heap *prev;         // previous heap
    unsigned char *buf; // buffer
    unsigned char *p;   // high water mark
    unsigned nleft;     // number of bytes left
};

Heap *heap=NULL;

void ph_init()
{
    if (!heap) {
        heap = (Heap *)calloc(1,sizeof(Heap));
    }
    assert(heap);
}



void ph_term()
{
    //printf("ph_term()\n");
#if _WINDLL || DEBUG
    Heap *h;
    Heap *hprev;

    for (h = heap; h; h = hprev)
    {
        hprev = h->prev;
        free(h->buf);
        free(h);
    }
#endif
}

void ph_newheap(size_t nbytes)
{   unsigned newsize;
    Heap *h;

    h = (Heap *) malloc(sizeof(Heap));
    if (!h)
        err_nomem();

    newsize = (nbytes > 0xFF00) ? nbytes : 0xFF00;
    h->buf = (unsigned char *) malloc(newsize);
    if (!h->buf)
    {
        free(h);
        err_nomem();
    }
    h->nleft = newsize;
    h->p = h->buf;
    h->prev = heap;
    heap = h;
}

void *ph_malloc(size_t nbytes)
{   unsigned char *p;

#ifdef DEBUG
    util_progress();
#endif
    nbytes += sizeof(unsigned) * 2;
    nbytes &= ~(sizeof(unsigned) - 1);

    if (nbytes >= heap->nleft)
        ph_newheap(nbytes);
    p = heap->p;
    heap->p += nbytes;
    heap->nleft -= nbytes;
    *(unsigned *)p = nbytes - sizeof(unsigned);
    p += sizeof(unsigned);
    return p;
}

#if ASM86
__declspec(naked) void *ph_calloc(size_t nbytes)
{
    _asm
    {
        push    dword ptr 4[ESP]
        call    ph_malloc
        test    EAX,EAX
        je      L25
        push    dword ptr 4[ESP]
        push    0
        push    EAX
        call    memset
        add     ESP,0Ch
L25:    ret     4
    }
}
#else
void *ph_calloc(size_t nbytes)
{   void *p;

    p = ph_malloc(nbytes);
    return p ? memset(p,0,nbytes) : p;
}
#endif

void ph_free(void *p)
{
}

void * __cdecl ph_realloc(void *p,size_t nbytes)
{
    //dbg_printf("ph_realloc(%p,%d)\n",p,nbytes);
    if (!p)
        return ph_malloc(nbytes);
    if (!nbytes)
    {   ph_free(p);
        return NULL;
    }
    void *newp = ph_malloc(nbytes);
    if (newp)
    {   unsigned oldsize = ((unsigned *)p)[-1];
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

#if !MEM_DEBUG


/***********************
 * Replacement for the standard C++ library operator delete().
 */

#if 0
#undef delete
void __cdecl operator delete(void *p)
{
}
#endif

#if 0

/*****************************************
 * Using this for array allocations gives
 * us an easy way to get at the array dimension.
 * Overloading operator new[]() doesn't work because that
 * gives us the array allocated size, but we need the dimension.
 */

#ifdef DEBUG
#define ARRAY_PROLOG    'prol'
#define ARRAY_EPILOG    'epil'
#define ARRAY_FILL      'f'
static int array_max_dim;

/*********************************
 * Run "reasonableness" checks on array.
 */

void array_debug(void *a)
{   size_t *p = (size_t *)a;

    assert(p);
    assert(p[-2] == ARRAY_PROLOG);
    int length = p[-1];
    assert(length >= 0 && length <= array_max_dim);
    assert(p[length] == ARRAY_EPILOG);

    // Since array contents are aligned pointers or NULL...
    for (int i = 0; i < length; i++)
        assert((p[i] & 3) == 0);
}

#endif

#undef array_new
void *array_new(int sizelem, int dim)
{   size_t *p;
    size_t sz;

#ifdef DEBUG
    assert(sizelem == sizeof(void *));  // must be array of pointers
    if (!(dim >= 0 && dim < 10000))
        printf("dim = %d\n",dim);
    assert(dim >= 0 && dim < 10000);
    if (dim > array_max_dim)
        array_max_dim = dim;

    sz = sizeof(size_t) * (3 + dim);
    p = ph_calloc(sz);
    if (p)
    {   p[0] = ARRAY_PROLOG;            // leading sentinel
        p[1] = dim;
        p[2 + dim] = ARRAY_EPILOG;      // trailing sentinel
        p += 2;
        array_debug(p);
    }
#else

    sz = sizeof(size_t) * (1 + dim);
    p = ph_calloc(sz);
    if (p)
        *p++ = dim;
#endif
    return (void *)p;
}

#undef array_delete
void array_delete(void *a, int sizelem)
{
    size_t *p = (size_t *)a;
#ifdef DEBUG

    array_debug(p);
    assert(sizelem == sizeof(size_t));
    memset(p - 2,ARRAY_FILL,sizeof(size_t *) * (3 + p[-1]));
    ph_free(p - 2);
#else
    ((size_t *)p)--;
    ph_free(p);
#endif
}

size_t array_length(void *p)
{
    array_debug(p);
    return ((size_t *)p)[-1];
}

/********************************
 * Same as System.arraycopy()
 */

void array_copy(void *f,int fi,void *t,int ti,int length)
{
#ifdef DEBUG
    assert(length >= 0 && length <= array_max_dim);
    int f_length = array_length(f);
    int t_length = array_length(t);
    assert(fi >= 0 && fi + length <= f_length);
    assert(ti >= 0 && ti + length <= t_length);
#endif
    memcpy(&((void **)t)[ti],&((void **)f)[fi],length * sizeof(void *));
}

/************************************
 * Reallocate.
 */

#undef array_renew
void **array_renew(void *a,int newlength)
{   int sz = sizeof(void *);
    int hsz = sizeof(void *);

    if (!a)
        a = array_new(sz,newlength);
    else
    {
        int oldlength = array_length(a);
#ifdef DEBUG
        void *b = array_new(sizeof(void *),newlength);
        int len = (oldlength < newlength) ? oldlength : newlength;
        array_copy(a,0,b,0,len);
        array_delete(a,sizeof(void *));
        a = b;
#else
        if (oldlength < newlength)
        {
            (char *)a -= hsz;
            a = ph_realloc(a,hsz + newlength * sz);
            if (!a)
                goto Lret;
            (char *)a += hsz;
            memset(&((void **)a)[oldlength],0,(newlength - oldlength) * sz);
        }
        else if (oldlength > newlength)
        {
            ;
        }
        ((size_t *)a)[-1] = newlength;
#endif
    }
Lret:
    return a;
}

/******************************************
 * Sort an array.
 */

#if MACINTOSH
extern "C" int acompare(const void *e1,const void *e2)
#else
int __cdecl acompare(const void *e1,const void *e2)
#endif
{
    Object *o1 = *(Object **)e1;
    Object *o2 = *(Object **)e2;

    return o1->compare(o2);
}

void array_sort(void *a)
{
    qsort(a,array_length(a),sizeof(void *),acompare);
}

#endif
#endif
