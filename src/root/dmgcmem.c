

// Copyright (c) 2000-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#if linux || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
#include <unistd.h>
#include <pthread.h>
#endif

#include "rmem.h"
#include "gc/gc.h"
//#include "printf.h"

/* This implementation of the storage allocator uses the Digital Mars gc.
 */

Mem mem;

//static int nuncollectable;

extern "C"
{
    void gc_init();
    GC *gc_get();
}

void Mem::init()
{
    gc_init();
}

char *Mem::strdup(const char *s)
{
    return gc_get()->strdup(s);
}

void *Mem::malloc(size_t size)
{
    if (gc)                     // if cached allocator
    {
//      PRINTF("Using cached gc for size %d, file = '%s', line = %d\n", size, GC::file, GC::line);
//      GC::file = NULL;
//      GC::line = 0;
        return ((GC *)gc)->malloc(size);
    }
    if (this == &mem)           // don't cache global mem
    {
//      PRINTF("Using global gc for size %d, file = '%s', line = %d\n", size, GC::file, GC::line);
//      GC::file = NULL;
//      GC::line = 0;
        return gc_get()->malloc(size);
    }
//    PRINTF("Generating cached gc for size %d, file = '%s', line = %d\n", size, GC::file, GC::line);
    gc = gc_get();
    return gc->malloc(size);
}

void *Mem::malloc_uncollectable(size_t size)
{   void *p;

    p = ::malloc(size);
    if (!p)
        error();
    addroots((char *)p, (char *)p + size);

#if 0
    ++nuncollectable;
    WPRINTF(L"malloc_uncollectable(%u) = %x, n=%d\n", size, p, nuncollectable);
#endif

    return p;
}

void *Mem::calloc(size_t size, size_t n)
{
    return gc_get()->calloc(size, n);
}

void *Mem::realloc(void *p, size_t size)
{
    return gc_get()->realloc(p, size);
}

void Mem::free(void *p)
{
    gc_get()->free(p);
}

void Mem::free_uncollectable(void *p)
{
    if (p)
    {   removeroots((char *)p);
        ::free(p);

#if 0
        --nuncollectable;
        WPRINTF(L"free_uncollectable(%x) n=%d\n", p, nuncollectable);
#endif

#if 0
        gc_get()->fullcollect();

        GCStats stats;

        getStats(&stats);
        WPRINTF(L"poolsize = %x, usedsize = %x, freelistsize = %x\n",
                stats.poolsize, stats.usedsize, stats.freelistsize);
#endif
    }
}

void *Mem::mallocdup(void *o, size_t size)
{
    return gc_get()->mallocdup(o, size);
}

void Mem::check(void *p)
{
    if (gc)
        gc->check(p);
    else
        gc_get()->check(p);
}

void Mem::error()
{
#if linux || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
    assert(0);
#endif
    printf("Error: out of memory\n");
    exit(EXIT_FAILURE);
}

void Mem::fullcollect()
{
    gc_get()->fullcollect();

#if 0
    {
        GCStats stats;

        gc_get()->getStats(&stats);
        WPRINTF(L"Thread %x ", Thread::getId());
        WPRINTF(L"poolsize=x%x, usedsize=x%x, freelistsize=x%x, freeblocks=%d, pageblocks=%d\n",
            stats.poolsize, stats.usedsize, stats.freelistsize, stats.freeblocks, stats.pageblocks);
    }
#endif
}


void Mem::fullcollectNoStack()
{
    gc_get()->fullcollectNoStack();

#if 0
    {
        GCStats stats;

        gc_get()->getStats(&stats);
        WPRINTF(L"Thread %x ", Thread::getId());
        WPRINTF(L"poolsize=x%x, usedsize=x%x, freelistsize=x%x, freeblocks=%d, pageblocks=%d\n",
            stats.poolsize, stats.usedsize, stats.freelistsize, stats.freeblocks, stats.pageblocks);
    }
#endif
}


void Mem::mark(void *pointer)
{
    (void) pointer;                     // for VC /W4 compatibility
}


void Mem::addroots(char* pStart, char* pEnd)
{
    gc_get()->addRange(pStart, pEnd);
}


void Mem::removeroots(char* pStart)
{
    gc_get()->removeRange(pStart);
}


void Mem::setFinalizer(void* pObj, FINALIZERPROC pFn, void* pClientData)
{
    (void)pClientData;
    gc_get()->setFinalizer(pObj, pFn);
}


void Mem::setStackBottom(void *stackbottom)
{
    gc_get()->setStackBottom(stackbottom);
}


GC *Mem::getThreadGC()
{
    return gc_get();
}


/* =================================================== */

#if 1
void * operator new(size_t m_size)
{
    //PRINTF("Call to global operator new(%d), file = '%s', line = %d\n", m_size, GC::file ? GC::file : "(null)", GC::line);
    GC::file = NULL;
    GC::line = 0;
    return mem.malloc(m_size);
}

void operator delete(void *p)
{
    //WPRINTF(L"Call to global operator delete\n");
    mem.free(p);
}

void* operator new[](size_t size)
{
    return operator new(size);
}

void operator delete[](void *pv)
{
    operator delete(pv);
}
#endif

void * Mem::operator new(size_t m_size)
{   void *p;

    p = gc_get()->malloc(m_size);
    //printf("Mem::operator new(%d) = %p\n", m_size, p);
    if (!p)
        mem.error();
    return p;
}

void * Mem::operator new(size_t m_size, Mem *mem)
{   void *p;

    p = mem->malloc(m_size);
    //printf("Mem::operator new(%d) = %p\n", m_size, p);
    if (!p)
        ::mem.error();
    return p;
}

void * Mem::operator new(size_t m_size, GC *gc)
{   void *p;

//    if (!gc)
//      WPRINTF(L"gc is NULL\n");
    p = gc->malloc(m_size);
    //printf("Mem::operator new(%d) = %p\n", m_size, p);
    if (!p)
        ::mem.error();
    return p;
}

void Mem::operator delete(void *p)
{
//    printf("Mem::operator delete(%p)\n", p);
    gc_get()->free(p);
}

/* ============================================================ */

/* The following section of code exists to find the right
 * garbage collector for this thread. There is one independent instance
 * of the collector per thread.
 */

/* ===================== linux ================================ */

#if linux || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun

#include <pthread.h>

#define LOG     0               // log thread creation / destruction

extern "C"
{

// Key identifying the thread-specific data
static pthread_key_t gc_key;

/* "Once" variable ensuring that the key for gc_alloc will be allocated
 * exactly once.
 */
static pthread_once_t gc_alloc_key_once = PTHREAD_ONCE_INIT;

/* Forward functions */
static void gc_alloc_key();
static void gc_alloc_destroy_gc(void * accu);


void gc_init()
{
#if LOG
    WPRINTF(L"Thread %lx: gc_init()\n", pthread_self());
#endif
    pthread_once(&gc_alloc_key_once, gc_alloc_key);
#if LOG
    WPRINTF(L"Thread %lx: gc_init() return\n", pthread_self());
#endif
}

GC *gc_get()
{
    GC *gc;

    // Get the thread-specific data associated with the key
    gc = (GC *) pthread_getspecific(gc_key);

    // It's initially NULL, meaning that we must allocate the buffer first.
    if (gc == NULL)
    {
        GC_LOG();
        gc = new GC();
        gc->init();

        // Store the buffer pointer in the thread-specific data.
        pthread_setspecific(gc_key, (void *) gc);
#if LOG
        WPRINTF(L"Thread %lx: allocating gc at %x\n", pthread_self(), gc);
#endif
    }
    return gc;
}

// Function to allocate the key for gc_alloc thread-specific data.

static void gc_alloc_key()
{
    pthread_key_create(&gc_key, gc_alloc_destroy_gc);
#if LOG
    WPRINTF(L"Thread %lx: allocated gc key %d\n", pthread_self(), gc_key);
#endif
}

// Function to free the buffer when the thread exits.
// Called only when the thread-specific data is not NULL.

static void gc_alloc_destroy_gc(void *gc)
{
#if LOG
    WPRINTF(L"Thread %x: freeing gc at %x\n", pthread_self(), gc);
#endif
    delete (GC *)gc;
}

}

#endif

/* ===================== win32 ================================ */

#if !defined(linux) && defined(_WIN32)

#if 1           // single threaded version

extern "C"
{

static GC *gc;

void gc_init()
{
    if (!gc)
    {   gc = (GC *)::malloc(sizeof(GC));
        gc->init();
    }
}

GC *gc_get()
{
    return gc;
}

}

#else           // multi threaded version

#include "mutex.h"
#include "thread.h"

/* This is the win32 version. It suffers from the bug that
 * when the thread exits the data structure is not cleared,
 * but the memory pool it points to is free'd.
 * Thus, if a new thread comes along with the same thread id,
 * the data will look initialized, but will point to garbage.
 *
 * What needs to happen is when a thread exits, the associated
 * GC_context data struct is cleared.
 */

struct GC_context
{
    ThreadId threadid;  // identifier of current thread
    GC *gc;
};

Mutex gc_mutex;

static GC_context array[64];

// Array of pointers to GC_context objects, one per threadid
GC_context *gccontext = array;
unsigned gccontext_allocdim = 64;
unsigned gccontext_dim;

ThreadId gc_cache_ti;
GC_context *gc_cache_cc;

extern "C" void gc_init()
{
}


extern "C" GC *gc_get()
{
    /* This works by creating an array of GC_context's, one
     * for each thread. We match up by thread id.
     */

    ThreadId ti;
    GC_context *cc;

    //PRINTF("gc_get()\n");

    ti = Thread::getId();
    gc_mutex.acquire();

    // Used cached version if we can
    if (ti == gc_cache_ti)
    {
        cc = gc_cache_cc;
        //exception(L"getGC_context(): cache x%x", ti);
    }
    else
    {
        // This does a linear search through gccontext[].
        // A hash table might be faster if there are more
        // than a dozen threads.
        GC_context *ccp;
        GC_context *ccptop = &gccontext[gccontext_dim];
        for (ccp = gccontext; ccp < ccptop; ccp++)
        {
            cc = ccp;
            if (cc->threadid == ti)
            {
                WPRINTF(L"getGC_context(): existing x%x", ti);
                goto Lret;
            }
        }

        // Do not allocate with garbage collector, as this must reside
        // global to all threads.

        assert(gccontext_dim < gccontext_allocdim);
        cc = ccp;
        memset(cc, 0, sizeof(*cc));
        cc->threadid = ti;
        cc->gc = new GC();
        cc->gc->init();

        gccontext_dim++;
        WPRINTF(L"getGC_context(): new x%x\n", ti);

    Lret:
        // Cache for next time
        gc_cache_ti = ti;
        gc_cache_cc = cc;
    }

    gc_mutex.release();
    return cc->gc;
}

#endif


#endif
