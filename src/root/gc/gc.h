// Copyright (c) 2000-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef GC_H
#define GC_H

struct Gcx;             // private data

typedef void (*GC_FINALIZER)(void *p, void *dummy);

struct GCStats
{
    unsigned poolsize;          // total size of pool
    unsigned usedsize;          // bytes allocated
    unsigned freeblocks;        // number of blocks marked FREE
    unsigned freelistsize;      // total of memory on free lists
    unsigned pageblocks;        // number of blocks marked PAGE
};

struct GC
{
    // For passing to debug code
    static unsigned line;
    static char *file;
//    #define GC_LOG() ((GC::line = __LINE__), (GC::file = __FILE__))
    #define GC_LOG() ((void)0)

    Gcx *gcx;           // implementation

    ~GC();

    void init();

    char *strdup(const char *s);
    void *malloc(size_t size);
    void *malloc_atomic(size_t size);
    void *calloc(size_t size, size_t n);
    void *realloc(void *p, size_t size);
    void free(void *p);
    void *mallocdup(void *o, size_t size);
    void check(void *p);
    void error();

    void setStackBottom(void *p);

    void addRoot(void *p);      // add p to list of roots
    void removeRoot(void *p);   // remove p from list of roots

    void addRange(void *pbot, void *ptop);      // add range to scan for roots
    void removeRange(void *pbot);               // remove range

    void fullcollect(); // do full garbage collection
    void fullcollectNoStack();  // do full garbage collection; no scan stack
    void gencollect();  // do generational garbage collection
    void minimize();    // minimize physical memory usage

    void setFinalizer(void *p, GC_FINALIZER pFn);

    void getStats(GCStats *stats);
};

#endif

