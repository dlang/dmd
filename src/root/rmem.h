
// Copyright (c) 2000-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef ROOT_MEM_H
#define ROOT_MEM_H

#include <stddef.h>     // for size_t

typedef void (*FINALIZERPROC)(void* pObj, void* pClientData);

struct GC;                      // thread specific allocator

struct Mem
{
    GC *gc;                     // pointer to our thread specific allocator
    Mem() { gc = NULL; }

    void init();

    // Derive from Mem to get these storage allocators instead of global new/delete
    void * operator new(size_t m_size);
    void * operator new(size_t m_size, Mem *mem);
    void * operator new(size_t m_size, GC *gc);
    void operator delete(void *p);

    void * operator new[](size_t m_size);
    void operator delete[](void *p);

    char *strdup(const char *s);
    void *malloc(size_t size);
    void *malloc_uncollectable(size_t size);
    void *calloc(size_t size, size_t n);
    void *realloc(void *p, size_t size);
    void free(void *p);
    void free_uncollectable(void *p);
    void *mallocdup(void *o, size_t size);
    void error();
    void check(void *p);        // validate pointer
    void fullcollect();         // do full garbage collection
    void fullcollectNoStack();  // do full garbage collection, no scan stack
    void mark(void *pointer);
    void addroots(char* pStart, char* pEnd);
    void removeroots(char* pStart);
    void setFinalizer(void* pObj, FINALIZERPROC pFn, void* pClientData);
    void setStackBottom(void *bottom);
    GC *getThreadGC();          // get apartment allocator for this thread
};

extern Mem mem;

#endif /* ROOT_MEM_H */
