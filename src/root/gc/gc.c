// Copyright (c) 2000-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


/************** Debugging ***************************/

#define THREADINVARIANT 0       // check thread integrity
#define INVARIANT       0       // check class invariants
#define LOGGING         0       // log allocations / frees
#define MEMSTOMP        0       // stomp on memory
#define SENTINEL        0       // add underrun/overrrun protection
#define PTRCHECK        0       // 0: fast pointer checking
                                // 1: more pointer checking
                                // 2: thorough but slow pointer checking

/*************** Configuration *********************/

#define USEROOT         0       // use root for printf
#define STACKGROWSDOWN  1       // 1: growing the stack means subtracting from the stack pointer
                                // (use 1 for Intel X86 CPUs)
                                // 0: growing the stack means adding to the stack pointer
#define ATOMIC          1       // mark some mallocs as "atomic"
#define LISTPREV        1       // use List prev pointers

/***************************************************/


#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <errno.h>

#include "gc.h"
#include "os.h"
#include "bits.h"

#if CHECK_OUT_OF_MEM
#include <setjmp.h>
extern jmp_buf g_setjmp_buf;
#endif

//#include "../root/perftimer.h"

#if USEROOT
#if defined linux

#include "../root/printf.h"

#elif defined _WIN32

#include "..\root\printf.h"

#endif
#else
#include <wchar.h>
#define WPRINTF wprintf
#define PRINTF printf
#endif

#ifdef linux
#include "gccbitops.h"
#endif

#ifdef _MSC_VER
#include "mscbitops.h"
#endif

#define PAGESIZE        4096
#define COMMITSIZE      (4096*16)
#define POOLSIZE        (4096*256*2)    // 2 megs

//#define printf 1 || printf

#undef assert
#define assert(e)       if (!(e)) _gc_assert(__LINE__)
void _gc_assert(unsigned line);

static int zero = 0;            // used to avoid complaints about assert(0) by MSVC

#if LOGGING

struct Log;

struct LogArray
{
    unsigned dim;
    unsigned allocdim;
    Log *data;

    LogArray();
    ~LogArray();

    void reserve(unsigned nentries);
    void push(Log foo);
    void remove(unsigned i);
    unsigned find(void *p);
    void copy(LogArray *from);
};

#endif

enum Bins
{
    B_16,
    B_32,
    B_64,
    B_128,
    B_256,
    B_512,
    B_1024,
    B_2048,
    B_PAGE,             // start of large alloc
    B_PAGEPLUS,         // continuation of large alloc
    B_FREE,             // free page
    B_UNCOMMITTED,      // memory not committed for this page
    B_MAX
};


struct List
{
    List *next;
    List *prev;
};

struct Range
{
    void *pbot;
    void *ptop;
};

struct Pool
{
    char *baseAddr;
    char *topAddr;
    GCBits mark;
    GCBits scan;
    GCBits finals;
    GCBits freebits;
#if ATOMIC
    GCBits atomic;
#endif

    unsigned npages;
    unsigned ncommitted;        // ncommitted <= npages
    unsigned char *pagetable;

    void init(unsigned npages);
    ~Pool();
    void invariant();

    unsigned allocPages(unsigned n);
    void freePages(unsigned pagenum, unsigned npages);
    int cmp(Pool *);
};

struct Gcx
{
#if THREADINVARIANT
    pthread_t self;
#   define thread_invariant(gcx) assert(gcx->self == pthread_self())
#else
#   define thread_invariant(gcx) ((void)0)
#endif

    unsigned nroots;
    unsigned rootdim;
    void **roots;

    unsigned nranges;
    unsigned rangedim;
    Range *ranges;

    unsigned noStack;   // !=0 means don't scan stack
    unsigned log;
    unsigned anychanges;
    char *stackBottom;

    char *minAddr;      // min(baseAddr)
    char *maxAddr;      // max(topAddr)

    unsigned npages;    // total number of pages in all the pools
    unsigned npools;
    Pool **pooltable;

    List *bucket[B_MAX];        // free list for each size

    GC_FINALIZER finalizer;     // finalizer function (one per GC)

    void init();
    ~Gcx();
    void invariant();

    void addRoot(void *p);
    void removeRoot(void *p);

    void addRange(void *pbot, void *ptop);      // add range to scan for roots
    void removeRange(void *pbot);               // remove range

    Pool *findPool(void *p);
    unsigned findSize(void *p);
    static Bins findBin(unsigned size);
    void *bigAlloc(unsigned size);
    Pool *newPool(unsigned npages);
    int allocPage(Bins bin);
    void mark(void *pbot, void *ptop);
    unsigned fullcollectshell();
    unsigned fullcollect(void *stackTop);
    void doFinalize(void *p);


    /***** Leak Detector ******/
#if LOGGING
    LogArray current;
    LogArray prev;

    void log_init();
    void log_malloc(void *p, unsigned size);
    void log_free(void *p);
    void log_collect();
    void log_parent(void *p, void *parent);
#else
    void log_init() { }
    void log_malloc(void *p, unsigned size) { (void)p; (void)size; }
    void log_free(void *p) { (void)p; }
    void log_collect() { }
    void log_parent(void *p, void *parent) { (void)p; (void)parent; }
#endif
};

void _gc_assert(unsigned line)
{
    (void)line;
#if USEROOT
    WPRINTF(L"GC assert fail: gc.c(%d)\n", line);
#else
    printf("GC assert fail: gc.c(%d)\n", line);
#endif
    *(char *)0 = 0;
    exit(0);
}

const unsigned binsize[B_MAX] = { 16,32,64,128,256,512,1024,2048,4096 };
const unsigned notbinsize[B_MAX] = { ~(16u-1),~(32u-1),~(64u-1),~(128u-1),~(256u-1),
                                ~(512u-1),~(1024u-1),~(2048u-1),~(4096u-1) };

unsigned binset[B_PAGE][PAGESIZE / (16 * 32)];

/********************************
 * Initialize binset[][].
 */

void binset_init()
{
    int bin;

    for (bin = 0; bin < B_PAGE; bin++)
    {
        unsigned bitstride = binsize[bin] / 16;

        for (unsigned bit = 0; bit < (PAGESIZE / 16); bit += bitstride)
        {
            unsigned u = bit / 32;
            unsigned m = bit % 32;
            binset[bin][u] |= 1 << m;
        }
    }
}

/* ============================ SENTINEL =============================== */


#if SENTINEL
#       define SENTINEL_PRE     0xF4F4F4F4      // 32 bits
#       define SENTINEL_POST    0xF5            // 8 bits
#       define SENTINEL_EXTRA   (2 * sizeof(unsigned) + 1)
#       define sentinel_size(p) (((unsigned *)(p))[-2])
#       define sentinel_pre(p)  (((unsigned *)(p))[-1])
#       define sentinel_post(p) (((unsigned char *)(p))[sentinel_size(p)])

void sentinel_init(void *p, unsigned size)
{
    sentinel_size(p) = size;
    sentinel_pre(p) = SENTINEL_PRE;
    sentinel_post(p) = SENTINEL_POST;
}

void sentinel_invariant(void *p, int line)
{
    //WPRINTF(L"pre = %x, line = %d\n", sentinel_pre(p), line);
    if (sentinel_pre(p) != SENTINEL_PRE)
        WPRINTF(L"p = %x, pre = %x, size = %x line = %d\n", p, sentinel_pre(p), sentinel_size(p), line);
    assert(sentinel_pre(p) == SENTINEL_PRE);
    assert(sentinel_post(p) == SENTINEL_POST);
}
#define sentinel_invariant(p) sentinel_invariant(p, __LINE__)

inline void *sentinel_add(void *p)
{
    //assert(((unsigned)p & 3) == 0);
    return (void *)((char *)p + 2 * sizeof(unsigned));
}

inline void *sentinel_sub(void *p)
{
    return (void *)((char *)p - 2 * sizeof(unsigned));
}

#else

#       define SENTINEL_EXTRA   0
#       define sentinel_init(p,size)    (void)(p)
#       define sentinel_invariant(p)    (void)(p)
#       define sentinel_add(p)          (void *)(p)
#       define sentinel_sub(p)          (void *)(p)

#endif

/* ============================ GC =============================== */

unsigned GC::line = 0;
char *GC::file = NULL;

GC::~GC()
{
#if defined linux
    //WPRINTF(L"Thread %x ", pthread_self());
    //WPRINTF(L"GC::~GC()\n");
#endif
    if (gcx)
    {
        Gcx *g = (Gcx *)gcx;
        delete g;
    }
}

void GC::init()
{
    //printf("GC::init()\n");
    if (!binset[0][0])
        binset_init();
    gcx = (Gcx *)::malloc(sizeof(Gcx));
    gcx->init();
}

void GC::setStackBottom(void *p)
{
    thread_invariant(gcx);
#if STACKGROWSDOWN
    p = (void *)((unsigned *)p + 4);
    if (p > gcx->stackBottom)
#else
    p = (void *)((unsigned *)p - 4);
    if (p < gcx->stackBottom)
#endif
    {
        //WPRINTF(L"setStackBottom(%x)\n", p);
        gcx->stackBottom = (char *)p;
    }
}

char *GC::strdup(const char *s)
{
    unsigned len;
    char *p = NULL;

    thread_invariant(gcx);
    if (s)
    {
        len = strlen(s) + 1;
        p = (char *)malloc(len);
#if CHECK_OUT_OF_MEM
        if (p)
#endif
            memcpy(p, s, len);
    }
    return p;
}

void *GC::calloc(size_t size, size_t n)
{
    unsigned len;
    void *p;

    thread_invariant(gcx);
    len = size * n;
    p = malloc(len);
    if (p)
    {   //printf("calloc: %x len %d\n", p, len);
        memset(p, 0, len);
    }
    return p;
}

void *GC::realloc(void *p, size_t size)
{
    thread_invariant(gcx);
    if (!size)
    {   if (p)
        {   free(p);
            p = NULL;
        }
    }
    else if (!p)
    {
        p = malloc(size);
    }
    else
    {   void *p2;
        unsigned psize;

//WPRINTF(L"GC::realloc(p = %x, size = %u)\n", p, size);
        sentinel_invariant(p);
#if SENTINEL
        psize = sentinel_size(p);
        if (psize != size)
#else
        psize = gcx->findSize(p);       // find allocated size
        if (psize < size ||             // if new size is bigger
            psize > size * 2)           // or less than half
#endif
        {
            p2 = malloc(size);
#if CHECK_OUT_OF_MEM
            if (!p2)
                return NULL;
#endif
            if (psize < size)
                size = psize;
            //WPRINTF(L"\tcopying %d bytes\n",size);
            memcpy(p2, p, size);
            //free(p);                  // causes 507 crash
            p = p2;
        }
    }
    return p;
}

void *GC::malloc_atomic(size_t size)
{
#if ATOMIC
    //WPRINTF(L"GC::malloc_atomic(size = %d)\n", size);
    void *p;

    p = malloc(size);
    if (p)
    {
        Pool *pool = gcx->findPool(p);
        pool->atomic.set(((char *)p - pool->baseAddr) / 16);
    }
    return p;
#else
    return malloc(size);
#endif
}

void *GC::malloc(size_t size)
{   void *p;
    Bins bin;

    //WPRINTF(L"GC::malloc(size = %d)\n", size);
    //PRINTF("GC::malloc(size = %d, file = '%s', line = %d)\n", size, GC::file, GC::line);
    //printf("gcx->self = %x, pthread_self() = %x\n", gcx->self, pthread_self());
    thread_invariant(gcx);
    if (size)
    {
        size += SENTINEL_EXTRA;

        // Compute size bin
        bin = gcx->findBin(size);

        if (bin < B_PAGE)
        {
            p = gcx->bucket[bin];
            if (p == NULL)
            {
                if (!gcx->allocPage(bin))       // try to find a new page
                {   unsigned freedpages;

                    freedpages = gcx->fullcollectshell();       // collect to find a new page
                    //if (freedpages < gcx->npools * 16)
                    if (freedpages < gcx->npages / 20 + 1)
                    {
                        gcx->newPool(1);
                    }
                }
                if (!gcx->bucket[bin] && !gcx->allocPage(bin))
                {   int result;

                    gcx->newPool(1);            // allocate new pool to find a new page
                    result = gcx->allocPage(bin);
#if CHECK_OUT_OF_MEM
                    if (!result)
                        //return NULL;
                        longjmp(g_setjmp_buf, 1);
#else
                    assert(result);
#endif
                }
                p = gcx->bucket[bin];
            }

            // Return next item from free list
            gcx->bucket[bin] = ((List *)p)->next;
            memset((char *)p + size, 0, binsize[bin] - size);
            #if MEMSTOMP
            memset(p, 0xF0, size);
            #endif
        }
        else
        {
            p = gcx->bigAlloc(size);
            if (!p)
#if CHECK_OUT_OF_MEM
                longjmp(g_setjmp_buf, 1);
#else
                return NULL;
#endif
        }
        size -= SENTINEL_EXTRA;
        p = sentinel_add(p);
        sentinel_init(p, size);
        //WPRINTF(L"\tmalloc => %x, %x\n", sentinel_sub(p), *(unsigned *)sentinel_sub(p));
        gcx->log_malloc(p, size);
        return p;
    }
    return NULL;
}

void GC::free(void *p)
{
    Pool *pool;
    unsigned pagenum;
    Bins bin;
    unsigned bit;

    thread_invariant(gcx);
    if (!p)
        return;

    // Find which page it is in
    pool = gcx->findPool(p);
    if (!pool)                          // if not one of ours
        return;                         // ignore
    sentinel_invariant(p);
    p = sentinel_sub(p);
    pagenum = ((char *)p - pool->baseAddr) / PAGESIZE;

    if (pool->finals.nbits && gcx->finalizer)
    {
        bit = (unsigned)((char *)p - pool->baseAddr) / 16;
        if (pool->finals.testClear(bit))
        {
            (*gcx->finalizer)(sentinel_add(p), NULL);
        }
    }

    bin = (Bins)pool->pagetable[pagenum];
    if (bin == B_PAGE)          // if large alloc
    {   int npages;
        unsigned n;

        // Free pages
        npages = 1;
        n = pagenum;
        while (++n < pool->ncommitted && pool->pagetable[n] == B_PAGEPLUS)
            npages++;
        #if MEMSTOMP
        memset(p, 0xF2, npages * PAGESIZE);
        #endif
        pool->freePages(pagenum, npages);
    }
    else
    {   // Add to free list
        List *list = (List *)p;

        #if MEMSTOMP
        memset(p, 0xF2, binsize[bin]);
        #endif

        list->next = gcx->bucket[bin];
        gcx->bucket[bin] = list;
    }
    gcx->log_free(sentinel_add(p));
}

void *GC::mallocdup(void *o, size_t size)
{
    void *p;

    thread_invariant(gcx);
    p = malloc(size);
#if CHECK_OUT_OF_MEM
    if (!p)
        return NULL;
#endif
    return memcpy(p, o, size);
}

/****************************************
 * Verify that pointer p:
 *      1) belongs to this memory pool
 *      2) points to the start of an allocated piece of memory
 *      3) is not on a free list
 */

void GC::check(void *p)
{
    if (p)
    {
        sentinel_invariant(p);
#if PTRCHECK >= 1
        Pool *pool;
        unsigned pagenum;
        Bins bin;
        unsigned size;

        p = sentinel_sub(p);
        pool = gcx->findPool(p);
        assert(pool);
        pagenum = ((char *)p - pool->baseAddr) / PAGESIZE;
        bin = (Bins)pool->pagetable[pagenum];
        assert(bin <= B_PAGE);
        size = binsize[bin];
        assert(((unsigned)p & (size - 1)) == 0);

#if PTRCHECK >= 2
        if (bin < B_PAGE)
        {
            // Check that p is not on a free list
            List *list;

            for (list = gcx->bucket[bin]; list; list = list->next)
            {
                assert((void *)list != p);
            }
        }
#endif
#endif
    }
}

void GC::error()
{   int i = 0;

    assert(i);
}

void GC::addRoot(void *p)
{
    thread_invariant(gcx);
    gcx->addRoot(p);
}

void GC::removeRoot(void *p)
{
    gcx->removeRoot(p);
}

void GC::addRange(void *pbot, void *ptop)
{
    thread_invariant(gcx);
    gcx->addRange(pbot, ptop);
}

void GC::removeRange(void *pbot)
{
    gcx->removeRange(pbot);
}

void GC::fullcollect()
{
    thread_invariant(gcx);

    gcx->fullcollectshell();

#if 0
    {
        GCStats stats;

        getStats(&stats);
        PRINTF("poolsize = %x, usedsize = %x, freelistsize = %x\n",
                stats.poolsize, stats.usedsize, stats.freelistsize);
    }
#endif
}

void GC::fullcollectNoStack()
{
    //WPRINTF(L"fullcollectNoStack()\n");
    gcx->noStack++;
    fullcollect();
    gcx->log_collect();
    gcx->noStack--;
}

void GC::gencollect()
{
    gcx->fullcollectshell();
}

void GC::minimize()
{
    // Not implemented, ignore
}


void GC::setFinalizer(void *p, GC_FINALIZER pFn)
{
    thread_invariant(gcx);

    gcx->finalizer = pFn;
    gcx->doFinalize(p);
}

/*****************************************
 * Retrieve statistics about garbage collection.
 * Useful for debugging and tuning.
 */

void GC::getStats(GCStats *stats)
{
    unsigned psize = 0;
    unsigned usize = 0;
    unsigned flsize = 0;

    unsigned n;
    unsigned bsize = 0;

//WPRINTF(L"getStats()\n");
    memset(stats, 0, sizeof(*stats));
    for (n = 0; n < gcx->npools; n++)
    {   Pool *pool = gcx->pooltable[n];

        psize += pool->ncommitted * PAGESIZE;
        for (unsigned j = 0; j < pool->ncommitted; j++)
        {
            Bins bin = (Bins)pool->pagetable[j];
            if (bin == B_FREE)
                stats->freeblocks++;
            else if (bin == B_PAGE)
                stats->pageblocks++;
            else if (bin < B_PAGE)
                bsize += PAGESIZE;
        }
    }

    for (n = 0; n < B_PAGE; n++)
    {
//WPRINTF(L"bin %d\n", n);
        for (List *list = gcx->bucket[n]; list; list = list->next)
        {
//WPRINTF(L"\tlist %x\n", list);
            flsize += binsize[n];
        }
    }

    usize = bsize - flsize;

    stats->poolsize = psize;
    stats->usedsize = bsize - flsize;
    stats->freelistsize = flsize;
}

/* ============================ Gcx =============================== */

void Gcx::init()
{   int dummy;

    memset(this, 0, sizeof(Gcx));
    stackBottom = (char *)&dummy;
    log_init();
#if THREADINVARIANT
    self = pthread_self();
#endif
    invariant();
}

Gcx::~Gcx()
{
    invariant();

    for (unsigned i = 0; i < npools; i++)
    {   Pool *pool = pooltable[i];

        delete pool;
    }
    if (pooltable)
        ::free(pooltable);

    if (roots)
        ::free(roots);

    if (ranges)
        ::free(ranges);
}

void Gcx::invariant()
{
#if INVARIANT
    unsigned i;

    thread_invariant(this);     // assure we're called on the right thread
    for (i = 0; i < npools; i++)
    {   Pool *pool = pooltable[i];

        pool->invariant();
        if (i == 0)
        {
            assert(minAddr == pool->baseAddr);
        }
        if (i + 1 < npools)
        {
            assert(pool->cmp(pooltable[i + 1]) < 0);
        }
        else if (i + 1 == npools)
        {
            assert(maxAddr == pool->topAddr);
        }
    }

    if (roots)
    {
        assert(rootdim != 0);
        assert(nroots <= rootdim);
    }

    if (ranges)
    {
        assert(rangedim != 0);
        assert(nranges <= rangedim);

        for (i = 0; i < nranges; i++)
        {
            assert(ranges[i].pbot);
            assert(ranges[i].ptop);
            assert(ranges[i].pbot <= ranges[i].ptop);
        }
    }

    for (i = 0; i < B_PAGE; i++)
    {
        for (List *list = bucket[i]; list; list = list->next)
        {
        }
    }
#endif
}

/***************************************
 */

void Gcx::addRoot(void *p)
{
    if (nroots == rootdim)
    {
        unsigned newdim = rootdim * 2 + 16;
        void **newroots;

        newroots = (void **)::malloc(newdim * sizeof(newroots[0]));
#if CHECK_OUT_OF_MEM
        if (!newroots)
            longjmp(g_setjmp_buf, 1);
#else
        assert(newroots);
#endif
        if (roots)
        {   memcpy(newroots, roots, nroots * sizeof(newroots[0]));
            ::free(roots);
        }
        roots = newroots;
        rootdim = newdim;
    }
    roots[nroots] = p;
    nroots++;
}

void Gcx::removeRoot(void *p)
{
    unsigned i;
    for (i = nroots; i--;)
    {
        if (roots[i] == p)
        {
            nroots--;
            memmove(roots + i, roots + i + 1, (nroots - i) * sizeof(roots[0]));
            return;
        }
    }
    assert(zero);
}


/***************************************
 */

void Gcx::addRange(void *pbot, void *ptop)
{
    //WPRINTF(L"Thread %x ", pthread_self());
    //WPRINTF(L"%x->Gcx::addRange(%x, %x), nranges = %d\n", this, pbot, ptop, nranges);
    if (nranges == rangedim)
    {
        unsigned newdim = rangedim * 2 + 16;
        Range *newranges;

        newranges = (Range *)::malloc(newdim * sizeof(newranges[0]));
#if CHECK_OUT_OF_MEM
        if (!newranges)
            longjmp(g_setjmp_buf, 1);
#else
        assert(newranges);
#endif
        if (ranges)
        {   memcpy(newranges, ranges, nranges * sizeof(newranges[0]));
            ::free(ranges);
        }
        ranges = newranges;
        rangedim = newdim;
    }
    ranges[nranges].pbot = pbot;
    ranges[nranges].ptop = ptop;
    nranges++;
}

void Gcx::removeRange(void *pbot)
{
    //WPRINTF(L"Thread %x ", pthread_self());
    //WPRINTF(L"%x->Gcx::removeRange(%x), nranges = %d\n", this, pbot, nranges);
    for (unsigned i = nranges; i--;)
    {
        if (ranges[i].pbot == pbot)
        {
            nranges--;
            memmove(ranges + i, ranges + i + 1, (nranges - i) * sizeof(ranges[0]));
            return;
        }
    }
    //WPRINTF(L"Wrong thread\n");

    // This is a fatal error, but ignore it at Sun's request.
    // The problem is that we can get a Close() call on a thread
    // other than the one the range was allocated on.
    //assert(zero);
}


/***********************************
 * Allocate a new pool with at least npages in it.
 * Sort it into pooltable[].
 * Return NULL if failed.
 */

Pool *Gcx::newPool(unsigned npages)
{
    Pool *pool;
    Pool **newpooltable;
    unsigned newnpools;
    unsigned i;

    //WPRINTF(L"************Gcx::newPool(npages = %d)****************\n", npages);

    // Round up to COMMITSIZE pages
    npages = (npages + (COMMITSIZE/PAGESIZE) - 1) & ~(COMMITSIZE/PAGESIZE - 1);

    // Minimum of POOLSIZE
    if (npages < POOLSIZE/PAGESIZE)
        npages = POOLSIZE/PAGESIZE;

    // Allocate successively larger pools up to 8 megs
    if (npools)
    {   unsigned n;

        n = npools;
        if (n > 8)
            n = 8;                      // cap pool size at 8 megs
        n *= (POOLSIZE / PAGESIZE);
        if (npages < n)
            npages = n;
    }

    pool = (Pool *)::malloc(sizeof(Pool));
    if (pool)
    {
        pool->init(npages);
        if (!pool->baseAddr)
            goto Lerr;

        newnpools = npools + 1;
        newpooltable = (Pool **)::realloc(pooltable, newnpools * sizeof(Pool *));
        if (!newpooltable)
            goto Lerr;

        // Sort pool into newpooltable[]
        for (i = 0; i < npools; i++)
        {
            if (pool->cmp(newpooltable[i]) < 0)
                 break;
        }
        memmove(newpooltable + i + 1, newpooltable + i, (npools - i) * sizeof(Pool *));
        newpooltable[i] = pool;

        pooltable = newpooltable;
        npools = newnpools;
        this->npages += npages;

        minAddr = pooltable[0]->baseAddr;
        maxAddr = pooltable[npools - 1]->topAddr;
    }
    return pool;

  Lerr:
    delete pool;
    return NULL;
}

/****************************************
 * Allocate a chunk of memory that is larger than a page.
 * Return NULL if out of memory.
 */

void *Gcx::bigAlloc(unsigned size)
{
    Pool *pool;
    unsigned npages;
    unsigned n;
    unsigned pn;
    unsigned freedpages;
    void *p;
    int state;

    npages = (size + PAGESIZE - 1) / PAGESIZE;

    for (state = 0; ; )
    {
        for (n = 0; n < npools; n++)
        {
            pool = pooltable[n];
            pn = pool->allocPages(npages);
            if (pn != ~0u)
                goto L1;
        }

        // Failed
        switch (state)
        {
            case 0:
                // Try collecting
                freedpages = fullcollectshell();
                if (freedpages >= npools * ((POOLSIZE / PAGESIZE) / 2))
                {   state = 1;
                    continue;
                }
                // Allocate new pool
                pool = newPool(npages);
                if (!pool)
                {   state = 2;
                    continue;
                }
                pn = pool->allocPages(npages);
                assert(pn != ~0u);
                goto L1;

            case 1:
                // Allocate new pool
                pool = newPool(npages);
                if (!pool)
                    goto Lnomemory;
                pn = pool->allocPages(npages);
                assert(pn != ~0u);
                goto L1;

            case 2:
                goto Lnomemory;
        }
    }

  L1:
    pool->pagetable[pn] = B_PAGE;
    if (npages > 1)
        memset(&pool->pagetable[pn + 1], B_PAGEPLUS, npages - 1);
    p = pool->baseAddr + pn * PAGESIZE;
    memset((char *)p + size, 0, npages * PAGESIZE - size);
    #if MEMSTOMP
    memset(p, 0xF1, size);
    #endif
    //printf("\tp = %x\n", p);
    return p;

  Lnomemory:
    //assert(zero);
    return NULL;
}

/*******************************
 * Allocate a page of bin's.
 * Returns:
 *      0       failed
 */

int Gcx::allocPage(Bins bin)
{
    Pool *pool;
    unsigned n;
    unsigned pn;
    char *p;
    char *ptop;

    //printf("Gcx::allocPage(bin = %d)\n", bin);
    for (n = 0; n < npools; n++)
    {
        pool = pooltable[n];
        pn = pool->allocPages(1);
        if (pn != ~0u)
            goto L1;
    }
    return 0;           // failed

  L1:
    pool->pagetable[pn] = (unsigned char)bin;

    // Convert page to free list
    unsigned size = binsize[bin];
    List **b = &bucket[bin];

    p = pool->baseAddr + pn * PAGESIZE;
    ptop = p + PAGESIZE;
    for (; p < ptop; p += size)
    {   List *list = (List *)p;

        list->next = *b;
        *b = list;
    }
    return 1;
}

/*******************************
 * Find Pool that pointer is in.
 * Return NULL if not in a Pool.
 * Assume pooltable[] is sorted.
 */

Pool *Gcx::findPool(void *p)
{
    if (p >= minAddr && p < maxAddr)
    {
        if (npools == 1)
        {
            return pooltable[0];
        }

        for (unsigned i = 0; i < npools; i++)
        {   Pool *pool;

            pool = pooltable[i];
            if (p < pool->topAddr)
            {   if (pool->baseAddr <= p)
                    return pool;
                break;
            }
        }
    }
    return NULL;
}

/*******************************
 * Find size of pointer p.
 * Returns 0 if not a gc'd pointer
 */

unsigned Gcx::findSize(void *p)
{
    Pool *pool;
    unsigned size = 0;

    pool = findPool(p);
    if (pool)
    {
        unsigned pagenum;
        Bins bin;

        pagenum = ((unsigned)((char *)p - pool->baseAddr)) / PAGESIZE;
        bin = (Bins)pool->pagetable[pagenum];
        size = binsize[bin];
        if (bin == B_PAGE)
        {   unsigned npages = pool->ncommitted;
            unsigned char *pt;
            unsigned i;

            pt = &pool->pagetable[0];
            for (i = pagenum + 1; i < npages; i++)
            {
                if (pt[i] != B_PAGEPLUS)
                    break;
            }
            size = (i - pagenum) * PAGESIZE;
        }
    }
    return size;
}


/*******************************
 * Compute bin for size.
 */

Bins Gcx::findBin(unsigned size)
{   Bins bin;

    if (size <= 256)
    {
        if (size <= 64)
        {
            if (size <= 16)
                bin = B_16;
            else if (size <= 32)
                bin = B_32;
            else
                bin = B_64;
        }
        else
        {
            if (size <= 128)
                bin = B_128;
            else
                bin = B_256;
        }
    }
    else
    {
        if (size <= 1024)
        {
            if (size <= 512)
                bin = B_512;
            else
                bin = B_1024;
        }
        else
        {
            if (size <= 2048)
                bin = B_2048;
            else
                bin = B_PAGE;
        }
    }
    return bin;
}

/************************************
 * Search a range of memory values and mark any pointers into the GC pool.
 */

void Gcx::mark(void *pbot, void *ptop)
{
    void **p1 = (void **)pbot;
    void **p2 = (void **)ptop;
    unsigned changes = 0;
    Pool *pool;

    //if (log) printf("Gcx::mark(%p .. %p)\n", pbot, ptop);
    if (npools == 1)
        pool = pooltable[0];

    for (; p1 < p2; p1++)
    {
        char *p = (char *)(*p1);

        //if (log) WPRINTF(L"\tmark %x\n", p);
        if (p >= minAddr && p < maxAddr /*&& ((int)p & 3) == 0*/)
        {
            if (npools != 1)
            {   pool = findPool(p);
                if (!pool)
                    continue;
            }

            unsigned offset = (unsigned)(p - pool->baseAddr);
            unsigned bit;
            unsigned pn = offset / PAGESIZE;
            Bins bin = (Bins)pool->pagetable[pn];

            //printf("\t\tfound pool %x, base=%x, pn = %d, bin = %d, bit = x%x\n", pool, pool->baseAddr, pn, bin, bit);

            // Adjust bit to be at start of allocated memory block
            if (bin <= B_PAGE)
            {
                bit = (offset & notbinsize[bin]) >> 4;
                //printf("\t\tbit = x%x\n", bit);
            }
            else if (bin == B_PAGEPLUS)
            {
                do
                {   --pn;
                } while ((Bins)pool->pagetable[pn] == B_PAGEPLUS);
                bit = pn * (PAGESIZE / 16);
            }
            else
            {
                // Don't mark bits in B_FREE or B_UNCOMMITTED pages
                continue;
            }

            //printf("\t\tmark(x%x) = %d\n", bit, pool->mark.test(bit));
            if (!pool->mark.testSet(bit))
            {
                //if (log) PRINTF("\t\tmarking %p\n", p);
                //pool->mark.set(bit);
#if ATOMIC
                if (!pool->atomic.test(bit))
#endif
                {
                    pool->scan.set(bit);
                    changes += 1;
                }
                log_parent(sentinel_add(pool->baseAddr + bit * 16), sentinel_add(pbot));
            }
        }
    }
    anychanges += changes;
}

/*********************************
 * Return number of full pages free'd.
 */

unsigned Gcx::fullcollectshell()
{
#if __GCC__
    asm("pushl %eax");
    asm("pushl %ebx");
    asm("pushl %ecx");
    asm("pushl %edx");
    asm("pushl %ebp");
    asm("pushl %esi");
    asm("pushl %edi");
    // This function must ensure that all register variables are on the stack
    // before &dummy
    unsigned dummy;
    dummy = fullcollect(&dummy - 7);
    asm("addl $28,%esp");
#elif _MSC_VER || __DMC__
    __asm push eax;
    __asm push ebx;
    __asm push ecx;
    __asm push edx;
    __asm push ebp;
    __asm push esi;
    __asm push edi;
    // This function must ensure that all register variables are on the stack
    // before &dummy
    unsigned dummy;
    dummy = fullcollect(&dummy - 7);
    __asm add esp,28;
#else
    // This function must ensure that all register variables are on the stack
    // before &dummy
    unsigned dummy;
    dummy = fullcollect(&dummy);
#endif
    return dummy;
}

unsigned Gcx::fullcollect(void *stackTop)
{
    unsigned n;
    Pool *pool;
    unsigned freedpages = 0;
    unsigned freed = 0;
    unsigned recoveredpages = 0;

int x1 = 0;
int x2 = 0;
int x3 = 0;

    //PRINTF("Gcx::fullcollect() npools = %d\n", npools);
//PerfTimer pf(L"fullcollect");
    invariant();
    anychanges = 0;
    for (n = 0; n < npools; n++)
    {
        pool = pooltable[n];
        pool->mark.zero();
        pool->scan.zero();
        pool->freebits.zero();
    }

    // Mark each free entry, so it doesn't get scanned
    for (n = 0; n < B_PAGE; n++)
    {
        List *list = bucket[n];
        List *prev = NULL;

        //WPRINTF(L"bin = %d\n", n);
        for (; list; list = list->next)
        {
            if (list->prev != prev)
                list->prev = prev;
            prev = list;
            pool = findPool(list);
            assert(pool);
            //WPRINTF(L" list = %x, bit = %d\n", list, (unsigned)((char *)list - pool->baseAddr) / 16);
            pool->freebits.set((unsigned)((char *)list - pool->baseAddr) / 16);
            assert(pool->freebits.test((unsigned)((char *)list - pool->baseAddr) / 16));
        }
    }

#if SENTINEL
    // Every memory item should either be on the free list or have the sentinel
    // set.
    for (n = 0; n < npools; n++)
    {   unsigned pn;
        unsigned ncommitted;

        pool = pooltable[n];
        ncommitted = pool->ncommitted;
        for (pn = 0; pn < ncommitted; pn++)
        {
            char *p;
            char *ptop;
            Bins bin = (Bins)pool->pagetable[pn];
            unsigned bit;

            p = pool->baseAddr + pn * PAGESIZE;
            ptop = p + PAGESIZE;

            //WPRINTF(L"pn = %d, bin = %d\n", pn, bin);
            if (bin < B_PAGE)
            {
                unsigned size = binsize[bin];
                unsigned bitstride = size / 16;
                bit = pn * (PAGESIZE/16);

                for (; p < ptop; p += size, bit += bitstride)
                {
                    if (pool->freebits.test(bit))
                        ;
                    else
                    {
                        //WPRINTF(L"p = %x, *p = %x\n", p, *(unsigned *)p);
                        sentinel_invariant(sentinel_add(p));
                    }
                }
            }
        }
    }
#endif

    for (n = 0; n < npools; n++)
    {
        pool = pooltable[n];
        pool->mark.copy(&pool->freebits);
    }

    if (!noStack)
    {
        // Scan stack
        //WPRINTF(L"scan stack bot = %x, top = %x\n", stackTop, stackBottom);
#if STACKGROWSDOWN
        mark(stackTop, stackBottom);
#else
        mark(stackBottom, stackTop);
#endif
    }

    // Scan roots[]
    //WPRINTF(L"scan roots[]\n");
    mark(roots, roots + nroots);

    // Scan ranges[]
    //WPRINTF(L"scan ranges[]\n");
    //log++;
    for (n = 0; n < nranges; n++)
    {
        //WPRINTF(L"\t%x .. %x\n", ranges[n].pbot, ranges[n].ptop);
        mark(ranges[n].pbot, ranges[n].ptop);
    }
    //log--;

    //WPRINTF(L"\tscan heap\n");
{
//PerfTimer pf(L"fullcollect: scanning    ");
    while (anychanges)
    {
        //WPRINTF(L"anychanges = %d\n", anychanges);
        anychanges = 0;
        for (n = 0; n < npools; n++)
        {
            unsigned *bbase;
            unsigned *b;
            unsigned *btop;

            pool = pooltable[n];

            bbase = pool->scan.base();
            btop = bbase + pool->scan.nwords;
            for (b = bbase; b < btop;)
            {   Bins bin;
                unsigned pn;
                unsigned u;
                unsigned bitm;
                char *o;
                char *ostart;

                bitm = *b;
                if (!bitm)
                {   b++;
                    continue;
                }
                //WPRINTF(L"bitm = x%08x, b = %x\n", bitm, b);
                pn = (b - bbase) / (PAGESIZE / (32 * 16));
                bin = (Bins)pool->pagetable[pn];
                o = pool->baseAddr + (b - bbase) * 32 * 16;
                *b = 0;

                if (bin < B_PAGE)
                {   int size = binsize[bin];
                    unsigned index;

                    do
                    {
                        index = _inline_bsf(bitm);
                        o += index * 16;
                        mark(o, o + size);
                        o += 16;

                        // Cannot combine these two, because 0x80000000<<32 is
                        // still 0x80000000
                        bitm >>= 1;
                    } while ((bitm >>= index) != 0);
                }
                else if (bin == B_PAGE)
                {
                    u = 1;
                    while (pn + u < pool->ncommitted &&
                           pool->pagetable[pn + u] == B_PAGEPLUS)
                        u++;
                    o = pool->baseAddr + pn * PAGESIZE;
                    mark(o, o + u * PAGESIZE);
                    b = bbase + (pn + u) * (PAGESIZE / (32 * 16));
                }
                else
                {
                    assert(0);
                }
            }
        }
    }
}

    // Free up everything not marked
{
//PerfTimer pf(L"fullcollect: freeing     ");
    //WPRINTF(L"\tfree'ing\n");
    for (n = 0; n < npools; n++)
    {   unsigned pn;
        unsigned ncommitted;
        unsigned *bbase;
        unsigned *fbase;
        int delta;

        pool = pooltable[n];
        bbase = pool->mark.base();
        delta = pool->freebits.base() - bbase;
        ncommitted = pool->ncommitted;
        for (pn = 0; pn < ncommitted; pn++, bbase += PAGESIZE / (32 * 16))
        {
            Bins bin = (Bins)pool->pagetable[pn];

            if (bin < B_PAGE)
            {   char *p;
                char *ptop;
                unsigned bit;
                unsigned bitstride;
                unsigned size = binsize[bin];

                p = pool->baseAddr + pn * PAGESIZE;
                ptop = p + PAGESIZE;
                bit = pn * (PAGESIZE/16);
                bitstride = size / 16;

#if 1
                // If free'd entire page
                fbase = bbase + delta;
#if INVARIANT
                assert(bbase == pool->mark.base() + pn * 8);
#endif
#if 1
                if ((bbase[0] ^ fbase[0]) == 0 &&
                    (bbase[1] ^ fbase[1]) == 0 &&
                    (bbase[2] ^ fbase[2]) == 0 &&
                    (bbase[3] ^ fbase[3]) == 0 &&
                    (bbase[4] ^ fbase[4]) == 0 &&
                    (bbase[5] ^ fbase[5]) == 0 &&
                    (bbase[6] ^ fbase[6]) == 0 &&
                    (bbase[7] ^ fbase[7]) == 0)
#else
                if ((bbase[0]) == 0 &&
                    (bbase[1]) == 0 &&
                    (bbase[2]) == 0 &&
                    (bbase[3]) == 0 &&
                    (bbase[4]) == 0 &&
                    (bbase[5]) == 0 &&
                    (bbase[6]) == 0 &&
                    (bbase[7]) == 0)
#endif
                {
x1++;
                    for (; p < ptop; p += size, bit += bitstride)
                    {
#if LISTPREV
                        if (pool->freebits.test(bit))
                        {   // Remove from free list
                            List *list = (List *)p;

                            //WPRINTF(L"bbase = %x, bbase[0] = %x, mark = %d\n", bbase, bbase[0], pool->mark.test(bit));
                            //WPRINTF(L"p = %x, bin = %d, size = %d, bit = %d\n", p, bin, size, bit);

                            if (bucket[bin] == list)
                                bucket[bin] = list->next;
                            if (list->next)
                                list->next->prev = list->prev;;
                            if (list->prev)
                                list->prev->next = list->next;
                            continue;
                        }
#endif
#if ATOMIC
                        pool->atomic.clear(bit);
#endif
                        if (finalizer && pool->finals.nbits &&
                            pool->finals.testClear(bit))
                        {
                            (*finalizer)((List *)sentinel_add(p), NULL);
                        }

                        List *list = (List *)p;
                        //printf("\tcollecting %x\n", list);
                        log_free(sentinel_add(list));

                        #if MEMSTOMP
                        memset(p, 0xF3, size);
                        #endif
                    }
                    pool->pagetable[pn] = B_FREE;
                    recoveredpages++;
                    //printf("freeing entire page %d\n", pn);
                    continue;
                }
#endif
                if (bbase[0] == binset[bin][0] &&
                    bbase[1] == binset[bin][1] &&
                    bbase[2] == binset[bin][2] &&
                    bbase[3] == binset[bin][3] &&
                    bbase[4] == binset[bin][4] &&
                    bbase[5] == binset[bin][5] &&
                    bbase[6] == binset[bin][6] &&
                    bbase[7] == binset[bin][7])
                {
x2++;
                    continue;
                }
x3++;
                for (; p < ptop; p += size, bit += bitstride)
                {
                    if (!pool->mark.test(bit))
                    {
                        sentinel_invariant(sentinel_add(p));

#if ATOMIC
                        pool->atomic.clear(bit);
#endif
                        pool->freebits.set(bit);
                        if (finalizer && pool->finals.nbits &&
                            pool->finals.testClear(bit))
                        {
                            (*finalizer)((List *)sentinel_add(p), NULL);
                        }

                        List *list = (List *)p;
                        //WPRINTF(L"\tcollecting %x, bin = %d\n", list, bin);
                        log_free(sentinel_add(list));

                        #if MEMSTOMP
                        memset(p, 0xF3, size);
                        #endif

#if LISTPREV
                        // Add to free list
                        list->next = bucket[bin];
                        list->prev = NULL;
                        if (list->next)
                            list->next->prev = list;
                        bucket[bin] = list;
#endif
                        freed += size;
                    }
                }
            }
            else if (bin == B_PAGE)
            {   unsigned bit = pn * (PAGESIZE / 16);

                if (!pool->mark.test(bit))
                {   char *p = pool->baseAddr + pn * PAGESIZE;

                    sentinel_invariant(sentinel_add(p));
#if ATOMIC
                    pool->atomic.clear(bit);
#endif
                    if (finalizer && pool->finals.nbits &&
                        pool->finals.testClear(bit))
                    {
                        (*finalizer)(sentinel_add(p), NULL);
                    }

                    //printf("\tcollecting big %x\n", p);
                    log_free(sentinel_add(p));
                    pool->pagetable[pn] = B_FREE;
                    freedpages++;
                    #if MEMSTOMP
                    memset(p, 0xF3, PAGESIZE);
                    #endif
                    while (pn + 1 < ncommitted && pool->pagetable[pn + 1] == B_PAGEPLUS)
                    {
                        pn++;
                        bbase += PAGESIZE / (32 * 16);
                        pool->pagetable[pn] = B_FREE;
                        freedpages++;

                        #if MEMSTOMP
                        p += PAGESIZE;
                        memset(p, 0xF3, PAGESIZE);
                        #endif
                    }
                }
            }
        }
    }
}

#if !LISTPREV
    // Zero buckets
    memset(bucket, 0, sizeof(bucket));

    // Free complete pages, rebuild free list
    //WPRINTF(L"\tfree complete pages\n");
PerfTimer pf(L"fullcollect: recoverpages");
    recoveredpages = 0;
    for (n = 0; n < npools; n++)
    {   unsigned pn;
        unsigned ncommitted;

        pool = pooltable[n];
        ncommitted = pool->ncommitted;
        for (pn = 0; pn < ncommitted; pn++)
        {
            Bins bin = (Bins)pool->pagetable[pn];
            unsigned bit;
            unsigned u;

            if (bin < B_PAGE)
            {
                unsigned size = binsize[bin];
                unsigned bitstride = size / 16;
                unsigned bitbase = pn * (PAGESIZE / 16);
                unsigned bittop = bitbase + (PAGESIZE / 16);
                char *p;

                bit = bitbase;
                for (bit = bitbase; bit < bittop; bit += bitstride)
                {   if (!pool->freebits.test(bit))
                        goto Lnotfree;
                }
                pool->pagetable[pn] = B_FREE;
                recoveredpages++;
                continue;

             Lnotfree:
                p = pool->baseAddr + pn * PAGESIZE;
                for (bit = bitbase; bit < bittop; bit += bitstride)
                {   if (pool->freebits.test(bit))
                    {   List *list;

                        u = (bit - bitbase) * 16;
                        list = (List *)(p + u);
                        if (list->next != bucket[bin])  // avoid unnecessary writes
                            list->next = bucket[bin];
                        bucket[bin] = list;
                    }
                }
            }
        }
    }
#endif

#undef printf
//    printf("recovered pages = %d\n", recoveredpages);
//    printf("\tfree'd %u bytes, %u pages from %u pools\n", freed, freedpages, npools);
#define printf 1 || printf

    //WPRINTF(L"\tfree'd %u bytes, %u pages from %u pools\n", freed, freedpages, npools);
    invariant();

#if 0
if (noStack)
{
    WPRINTF(L"\tdone, freedpages = %d, recoveredpages = %d, freed = %d, total = %d\n", freedpages, recoveredpages, freed / PAGESIZE, freedpages + recoveredpages + freed / PAGESIZE);
    WPRINTF(L"\tx1 = %d, x2 = %d, x3 = %d\n", x1, x2, x3);
    int psize = 0;
    for (n = 0; n < npools; n++)
    {
        pool = pooltable[n];
        psize += pool->topAddr - pool->baseAddr;
    }
    WPRINTF(L"total memory = x%x (npages=%d) in %d pools\n", psize, npages, npools);

    psize = 0;
    for (n = 0; n < npools; n++)
    {
        pool = pooltable[n];
        for (unsigned i = 0; i < pool->ncommitted; i++)
        {
            if (pool->pagetable[i] < B_FREE)
            {   psize++;
                if (psize <= 25)
                    WPRINTF(L"\tbin = %d\n", pool->pagetable[i]);
            }
        }
    }
    WPRINTF(L"total used pages = %d\n", psize);
}
#endif
    return freedpages + recoveredpages + freed / PAGESIZE;
}

/*********************************
 * Run finalizer on p when it is free'd.
 */

void Gcx::doFinalize(void *p)
{
    Pool *pool = findPool(p);
    assert(pool);

    // Only allocate finals[] if we actually need it
    if (!pool->finals.nbits)
        pool->finals.alloc(pool->mark.nbits);

    pool->finals.set(((char *)p - pool->baseAddr) / 16);
}

/* ============================ Pool  =============================== */

void Pool::init(unsigned npages)
{
    unsigned poolsize;

    //printf("Pool::Pool(%u)\n", npages);
    poolsize = npages * PAGESIZE;
    assert(poolsize >= POOLSIZE);
    baseAddr = (char *)os_mem_map(poolsize);

    if (!baseAddr)
    {
#if CHECK_OUT_OF_MEM
        longjmp(g_setjmp_buf, 1);
#endif
        WPRINTF(L"GC fail: poolsize = x%x, errno = %d\n", poolsize, errno);
#if USEROOT
        PRINTF("message = '%s'\n", sys_errlist[errno]);
#else
        printf("message = '%s'\n", sys_errlist[errno]);
#endif
        npages = 0;
        poolsize = 0;
    }
    //assert(baseAddr);
    topAddr = baseAddr + poolsize;

    mark.alloc(poolsize / 16);
    scan.alloc(poolsize / 16);
    freebits.alloc(poolsize / 16);
#if ATOMIC
    atomic.alloc(poolsize / 16);
#endif

    pagetable = (unsigned char *)::malloc(npages);
    memset(pagetable, B_UNCOMMITTED, npages);

    this->npages = npages;
    ncommitted = 0;

    invariant();
}

Pool::~Pool()
{
    invariant();
    if (baseAddr)
    {
        int result;

        if (ncommitted)
        {
            result = os_mem_decommit(baseAddr, 0, ncommitted * PAGESIZE);
            assert(result == 0);
        }

        if (npages)
        {
            result = os_mem_unmap(baseAddr, npages * PAGESIZE);
            assert(result == 0);
        }
    }
    if (pagetable)
        ::free(pagetable);
}

void Pool::invariant()
{
#if INVARIANT
    mark.invariant();
    scan.invariant();

    assert(baseAddr < topAddr);
    assert(baseAddr + npages * PAGESIZE == topAddr);
    assert(ncommitted <= npages);

    for (unsigned i = 0; i < npages; i++)
    {   Bins bin = (Bins)pagetable[i];

        assert(bin < B_MAX);
#if 0
        // Buggy GCC doesn't compile this right with -O
        if (i < ncommitted)
            assert(bin != B_UNCOMMITTED);
        else
            assert(bin == B_UNCOMMITTED);
#endif
    }
#endif
}

/***************************
 * Used for sorting pooltable[]
 */

int Pool::cmp(Pool *p2)
{
    return baseAddr - p2->baseAddr;
}

/**************************************
 * Allocate n pages from Pool.
 * Returns ~0u on failure.
 */

unsigned Pool::allocPages(unsigned n)
{
    unsigned i;
    unsigned n2;

    //printf("Pool::allocPages(n = %d)\n", n);
    n2 = n;
    for (i = 0; i < ncommitted; i++)
    {
        if (pagetable[i] == B_FREE)
        {
            if (--n2 == 0)
            {   //printf("\texisting pn = %d\n", i - n + 1);
                return i - n + 1;
            }
        }
        else
            n2 = n;
    }
    if (ncommitted + n < npages)
    {
        unsigned tocommit;

        tocommit = (n + (COMMITSIZE/PAGESIZE) - 1) & ~(COMMITSIZE/PAGESIZE - 1);
        if (ncommitted + tocommit > npages)
            tocommit = npages - ncommitted;
        //printf("\tlooking to commit %d more pages\n", tocommit);
        //fflush(stdout);
        if (os_mem_commit(baseAddr, ncommitted * PAGESIZE, tocommit * PAGESIZE) == 0)
        {
            memset(pagetable + ncommitted, B_FREE, tocommit);
            i = ncommitted;
            ncommitted += tocommit;

            while (i && pagetable[i - 1] == B_FREE)
                i--;

            return i;
        }
        //printf("\tfailed to commit %d pages\n", tocommit);
    }

    return ~0u;
}

/**********************************
 * Free npages pages starting with pagenum.
 */

void Pool::freePages(unsigned pagenum, unsigned npages)
{
    memset(&pagetable[pagenum], B_FREE, npages);
}

/* ======================= Leak Detector =========================== */

#if LOGGING

struct Log
{
    void *p;
    unsigned size;
    unsigned line;
    char *file;
    void *parent;

    void print();
};

void Log::print()
{
    WPRINTF(L"    p = %x, size = %d, parent = %x ", p, size, parent);
    if (file)
    {
        PRINTF("%s(%u)", file, line);
    }
    WPRINTF(L"\n");
}

LogArray::LogArray()
{
    data = NULL;
    dim = 0;
    allocdim = 0;
}

LogArray::~LogArray()
{
    if (data)
        ::free(data);
    data = NULL;
}

void LogArray::reserve(unsigned nentries)
{
    //WPRINTF(L"LogArray::reserve(%d)\n", nentries);
    assert(dim <= allocdim);
    if (allocdim - dim < nentries)
    {
        allocdim = (dim + nentries) * 2;
        assert(dim + nentries <= allocdim);
        if (!data)
        {
            data = (Log *)::malloc(allocdim * sizeof(*data));
        }
        else
        {   Log *newdata;

            newdata = (Log *)::malloc(allocdim * sizeof(*data));
            assert(newdata);
            memcpy(newdata, data, dim * sizeof(Log));
            ::free(data);
            data = newdata;
        }
        assert(!allocdim || data);
    }
}

void LogArray::push(Log log)
{
    reserve(1);
    data[dim++] = log;
}

void LogArray::remove(unsigned i)
{
    memmove(data + i, data + i + 1, (dim - i) * sizeof(data[0]));
    dim--;
}

unsigned LogArray::find(void *p)
{
    for (unsigned i = 0; i < dim; i++)
    {
        if (data[i].p == p)
            return i;
    }
    return ~0u;         // not found
}

void LogArray::copy(LogArray *from)
{
    if (from->dim > dim)
    {   reserve(from->dim - dim);
        assert(from->dim <= allocdim);
    }
    memcpy(data, from->data, from->dim * sizeof(data[0]));
    dim = from->dim;
}


/****************************/

void Gcx::log_init()
{
    //WPRINTF(L"+log_init()\n");
    current.reserve(1000);
    prev.reserve(1000);
    //WPRINTF(L"-log_init()\n");
}

void Gcx::log_parent(void *p, void *parent)
{
    //WPRINTF(L"+log_parent()\n");
    unsigned i;

    i = current.find(p);
    if (i == ~0u)
    {
        WPRINTF(L"parent'ing unallocated memory %x, parent = %x\n", p, parent);
        Pool *pool;
        pool = findPool(p);
        assert(pool);
        unsigned offset = (unsigned)((char *)p - pool->baseAddr);
        unsigned bit;
        unsigned pn = offset / PAGESIZE;
        Bins bin = (Bins)pool->pagetable[pn];
        bit = (offset & notbinsize[bin]);
        WPRINTF(L"\tbin = %d, offset = x%x, bit = x%x\n", bin, offset, bit);
    }
    else
    {
        current.data[i].parent = parent;
    }
    //WPRINTF(L"-log_parent()\n");
}

void Gcx::log_malloc(void *p, unsigned size)
{
    //WPRINTF(L"+log_malloc(p = %x, size = %d)\n", p, size);
    Log log;

    log.p = p;
    log.size = size;
    log.line = GC::line;
    log.file = GC::file;
    log.parent = NULL;

    GC::line = 0;
    GC::file = NULL;

    current.push(log);
    //WPRINTF(L"-log_malloc()\n");
}

void Gcx::log_free(void *p)
{
    //WPRINTF(L"+log_free(%x)\n", p);
    unsigned i;

    i = current.find(p);
    if (i == ~0u)
    {
        WPRINTF(L"free'ing unallocated memory %x\n", p);
    }
    else
        current.remove(i);
    //WPRINTF(L"-log_free()\n");
}

void Gcx::log_collect()
{
    //WPRINTF(L"+log_collect()\n");
    // Print everything in current that is not in prev

    WPRINTF(L"New pointers this cycle: --------------------------------\n");
    int used = 0;
    for (unsigned i = 0; i < current.dim; i++)
    {
        unsigned j;

        j = prev.find(current.data[i].p);
        if (j == ~0u)
            current.data[i].print();
        else
            used++;
    }

    WPRINTF(L"All roots this cycle: --------------------------------\n");
    for (unsigned i = 0; i < current.dim; i++)
    {
        void *p;
        unsigned j;

        p = current.data[i].p;
        if (!findPool(current.data[i].parent))
        {
            j = prev.find(current.data[i].p);
            if (j == ~0u)
                WPRINTF(L"N");
            else
                WPRINTF(L" ");;
            current.data[i].print();
        }
    }

    WPRINTF(L"Used = %d-------------------------------------------------\n", used);
    prev.copy(&current);

    WPRINTF(L"-log_collect()\n");
}

#endif
