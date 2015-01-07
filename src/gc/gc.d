/**
 * Contains the garbage collector implementation.
 *
 * Copyright: Copyright Digital Mars 2001 - 2013.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright, David Friedman, Sean Kelly
 */

/*          Copyright Digital Mars 2005 - 2013.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module gc.gc;

// D Programming Language Garbage Collector implementation

/************** Debugging ***************************/

//debug = PRINTF;               // turn on printf's
//debug = COLLECT_PRINTF;       // turn on printf's
//debug = PRINTF_TO_FILE;       // redirect printf's ouptut to file "gcx.log"
//debug = LOGGING;              // log allocations / frees
//debug = MEMSTOMP;             // stomp on memory
//debug = SENTINEL;             // add underrun/overrrun protection
//debug = PTRCHECK;             // more pointer checking
//debug = PTRCHECK2;            // thorough but slow pointer checking
//debug = INVARIANT;            // enable invariants
//debug = CACHE_HITRATE;        // enable hit rate measure

/*************** Configuration *********************/

version = STACKGROWSDOWN;       // growing the stack means subtracting from the stack pointer
                                // (use for Intel X86 CPUs)
                                // else growing the stack means adding to the stack pointer

/***************************************************/

import gc.bits;
import gc.stats;
import gc.os;
import gc.config;

import rt.util.container.treap;

import cstdlib = core.stdc.stdlib : calloc, free, malloc, realloc;
import core.stdc.string : memcpy, memset, memmove;
import core.bitop;
import core.sync.mutex;
import core.thread;
static import core.memory;
private alias BlkAttr = core.memory.GC.BlkAttr;
private alias BlkInfo = core.memory.GC.BlkInfo;

version (GNU) import gcc.builtins;

debug (PRINTF_TO_FILE) import core.stdc.stdio : fprintf, fopen, fflush, FILE;
else                   import core.stdc.stdio : printf; // needed to output profiling results

import core.time;
alias currTime = MonoTime.currTime;

debug(PRINTF_TO_FILE)
{
    private __gshared MonoTime gcStartTick;
    private __gshared FILE* gcx_fh;

    private int printf(ARGS...)(const char* fmt, ARGS args) nothrow
    {
        if (!gcx_fh)
            gcx_fh = fopen("gcx.log", "w");
        if (!gcx_fh)
            return 0;

        int len;
        if (MonoTime.ticksPerSecond == 0)
        {
            len = fprintf(gcx_fh, "before init: ");
        }
        else
        {
            if (gcStartTick == MonoTime.init)
                gcStartTick = MonoTime.currTime;
            immutable timeElapsed = MonoTime.currTime - gcStartTick;
            immutable secondsAsDouble = timeElapsed.total!"hnsecs" / cast(double)convert!("seconds", "hnsecs")(1);
            len = fprintf(gcx_fh, "%10.6lf: ", secondsAsDouble);
        }
        len += fprintf(gcx_fh, fmt, args);
        fflush(gcx_fh);
        return len;
    }
}

debug(PRINTF) void printFreeInfo(Pool* pool) nothrow
{
    uint nReallyFree;
    foreach(i; 0..pool.npages) {
        if(pool.pagetable[i] >= B_FREE) nReallyFree++;
    }

    printf("Pool %p:  %d really free, %d supposedly free\n", pool, nReallyFree, pool.freepages);
}

// Track total time spent preparing for GC,
// marking, sweeping and recovering pages.
__gshared Duration prepTime;
__gshared Duration markTime;
__gshared Duration sweepTime;
__gshared Duration recoverTime;
__gshared Duration maxPauseTime;
__gshared size_t numCollections;
__gshared size_t maxPoolMemory;

private
{
    enum USE_CACHE = true;

    // The maximum number of recursions of mark() before transitioning to
    // multiple heap traversals to avoid consuming O(D) stack space where
    // D is the depth of the heap graph.
    version(Win64)
        enum MAX_MARK_RECURSIONS = 32; // stack overflow in fibers
    else
        enum MAX_MARK_RECURSIONS = 64;
}

private
{
    extern (C)
    {
        // to allow compilation of this module without access to the rt package,
        //  make these functions available from rt.lifetime
        void rt_finalize2(void* p, bool det, bool resetMemory) nothrow;
        int rt_hasFinalizerInSegment(void* p, in void[] segment) nothrow;

        // Declared as an extern instead of importing core.exception
        // to avoid inlining - see issue 13725.
        void onInvalidMemoryOperationError() nothrow;
        void onOutOfMemoryError() nothrow;
    }

    enum
    {
        OPFAIL = ~cast(size_t)0
    }
}


alias GC gc_t;


/* ======================= Leak Detector =========================== */


debug (LOGGING)
{
    struct Log
    {
        void*  p;
        size_t size;
        size_t line;
        char*  file;
        void*  parent;

        void print() nothrow
        {
            printf("    p = %p, size = %zd, parent = %p ", p, size, parent);
            if (file)
            {
                printf("%s(%u)", file, line);
            }
            printf("\n");
        }
    }


    struct LogArray
    {
        size_t dim;
        size_t allocdim;
        Log *data;

        void Dtor() nothrow
        {
            if (data)
                cstdlib.free(data);
            data = null;
        }

        void reserve(size_t nentries) nothrow
        {
            assert(dim <= allocdim);
            if (allocdim - dim < nentries)
            {
                allocdim = (dim + nentries) * 2;
                assert(dim + nentries <= allocdim);
                if (!data)
                {
                    data = cast(Log*)cstdlib.malloc(allocdim * Log.sizeof);
                    if (!data && allocdim)
                        onOutOfMemoryError();
                }
                else
                {   Log *newdata;

                    newdata = cast(Log*)cstdlib.malloc(allocdim * Log.sizeof);
                    if (!newdata && allocdim)
                        onOutOfMemoryError();
                    memcpy(newdata, data, dim * Log.sizeof);
                    cstdlib.free(data);
                    data = newdata;
                }
            }
        }


        void push(Log log) nothrow
        {
            reserve(1);
            data[dim++] = log;
        }

        void remove(size_t i) nothrow
        {
            memmove(data + i, data + i + 1, (dim - i) * Log.sizeof);
            dim--;
        }


        size_t find(void *p) nothrow
        {
            for (size_t i = 0; i < dim; i++)
            {
                if (data[i].p == p)
                    return i;
            }
            return OPFAIL; // not found
        }


        void copy(LogArray *from) nothrow
        {
            reserve(from.dim - dim);
            assert(from.dim <= allocdim);
            memcpy(data, from.data, from.dim * Log.sizeof);
            dim = from.dim;
        }
    }
}


/* ============================ GC =============================== */


const uint GCVERSION = 1;       // increment every time we change interface
                                // to GC.

// This just makes Mutex final to de-virtualize member function calls.
final class GCMutex : Mutex
{
}

class GC
{
    // For passing to debug code (not thread safe)
    __gshared size_t line;
    __gshared char*  file;

    uint gcversion = GCVERSION;

    Gcx *gcx;                   // implementation

    // We can't allocate a Mutex on the GC heap because we are the GC.
    // Store it in the static data segment instead.
    __gshared GCMutex gcLock;    // global lock
    __gshared byte[__traits(classInstanceSize, GCMutex)] mutexStorage;

    __gshared Config config;

    void initialize()
    {
        config.initialize();

        mutexStorage[] = typeid(GCMutex).init[];
        gcLock = cast(GCMutex) mutexStorage.ptr;
        gcLock.__ctor();
        gcx = cast(Gcx*)cstdlib.calloc(1, Gcx.sizeof);
        if (!gcx)
            onOutOfMemoryError();
        gcx.initialize();

        if (config.initReserve)
            gcx.reserve(config.initReserve << 20);
        if (config.disable)
            gcx.disabled++;
    }


    void Dtor()
    {
        version (linux)
        {
            //debug(PRINTF) printf("Thread %x ", pthread_self());
            //debug(PRINTF) printf("GC.Dtor()\n");
        }

        if (gcx)
        {
            gcx.Dtor();
            cstdlib.free(gcx);
            gcx = null;
        }
    }


    /**
     *
     */
    void enable()
    {
        gcLock.lock();
        scope(exit) gcLock.unlock();
        assert(gcx.disabled > 0);
        gcx.disabled--;
    }


    /**
     *
     */
    void disable()
    {
        gcLock.lock();
        scope(exit) gcLock.unlock();
        gcx.disabled++;
    }


    /**
     *
     */
    uint getAttr(void* p) nothrow
    {
        if (!p)
        {
            return 0;
        }

        uint go() nothrow
        {
            Pool* pool = gcx.findPool(p);
            uint  oldb = 0;

            if (pool)
            {
                p = sentinel_sub(p);
                auto biti = cast(size_t)(p - pool.baseAddr) >> pool.shiftBy;

                oldb = gcx.getBits(pool, biti);
            }
            return oldb;
        }

        gcLock.lock();
        auto rc = go();
        gcLock.unlock();
        return rc;
    }


    /**
     *
     */
    uint setAttr(void* p, uint mask) nothrow
    {
        if (!p)
        {
            return 0;
        }

        uint go() nothrow
        {
            Pool* pool = gcx.findPool(p);
            uint  oldb = 0;

            if (pool)
            {
                p = sentinel_sub(p);
                auto biti = cast(size_t)(p - pool.baseAddr) >> pool.shiftBy;

                oldb = gcx.getBits(pool, biti);
                gcx.setBits(pool, biti, mask);
            }
            return oldb;
        }

        gcLock.lock();
        auto rc = go();
        gcLock.unlock();
        return rc;
    }


    /**
     *
     */
    uint clrAttr(void* p, uint mask) nothrow
    {
        if (!p)
        {
            return 0;
        }

        uint go() nothrow
        {
            Pool* pool = gcx.findPool(p);
            uint  oldb = 0;

            if (pool)
            {
                p = sentinel_sub(p);
                auto biti = cast(size_t)(p - pool.baseAddr) >> pool.shiftBy;

                oldb = gcx.getBits(pool, biti);
                gcx.clrBits(pool, biti, mask);
            }
            return oldb;
        }

        gcLock.lock();
        auto rc = go();
        gcLock.unlock();
        return rc;
    }


    /**
     *
     */
    void *malloc(size_t size, uint bits = 0, size_t *alloc_size = null, const TypeInfo ti = null) nothrow
    {
        if (!size)
        {
            if(alloc_size)
                *alloc_size = 0;
            return null;
        }

        void* p = void;
        size_t localAllocSize = void;
        if(alloc_size is null) alloc_size = &localAllocSize;

        // Since a finalizer could launch a new thread, we always need to lock
        // when collecting.  The safest way to do this is to simply always lock
        // when allocating.
        {
            gcLock.lock();
            p = mallocNoSync(size, bits, *alloc_size, ti);
            gcLock.unlock();
        }

        if (!(bits & BlkAttr.NO_SCAN))
        {
            memset(p + size, 0, *alloc_size - size);
        }

        return p;
    }


    //
    //
    //
    private void *mallocNoSync(size_t size, uint bits, ref size_t alloc_size, const TypeInfo ti = null) nothrow
    {
        assert(size != 0);

        Bins bin;

        //debug(PRINTF) printf("GC::malloc(size = %d, gcx = %p)\n", size, gcx);
        assert(gcx);
        //debug(PRINTF) printf("gcx.self = %x, pthread_self() = %x\n", gcx.self, pthread_self());

        if (gcx.running)
            onInvalidMemoryOperationError();

        size += SENTINEL_EXTRA;
        bin = gcx.findBin(size);
        Pool *pool;

        void *p;

        if (bin < B_PAGE)
        {
            bool tryAlloc() nothrow
            {
                if (!gcx.bucket[bin] && !gcx.allocPage(bin))
                    return false;
                p = gcx.bucket[bin];
                return true;
            }

            alloc_size = binsize[bin];

            if (!tryAlloc())
            {
                // disabled => allocate a new pool instead of collecting
                if (gcx.disabled && !gcx.newPool(1, false))
                {
                    // disabled but out of memory => try to free some memory
                    gcx.fullcollect();
                }
                else if (gcx.fullcollect() < gcx.npools * ((POOLSIZE / PAGESIZE) / 8))
                {
                    // very little memory was freed => allocate a new pool for anticipated heap growth
                    gcx.newPool(1, false);
                }
                // tryAlloc will succeed if a new pool was allocated above, if it fails allocate a new pool now
                if (!tryAlloc() && (!gcx.newPool(1, false) || !tryAlloc()))
                    // out of luck or memory
                    onOutOfMemoryError();
            }
            assert(p !is null);

            // Return next item from free list
            gcx.bucket[bin] = (cast(List*)p).next;
            pool = (cast(List*)p).pool;
            //debug(PRINTF) printf("\tmalloc => %p\n", p);
            debug (MEMSTOMP) memset(p, 0xF0, size);
        }
        else
        {
            p = gcx.bigAlloc(size, &pool, alloc_size);
            if (!p)
                onOutOfMemoryError();
        }
        debug (SENTINEL)
        {
            size -= SENTINEL_EXTRA;
            p = sentinel_add(p);
            sentinel_init(p, size);
            alloc_size = size;
        }
        gcx.log_malloc(p, size);

        if (bits)
        {
            gcx.setBits(pool, cast(size_t)(sentinel_sub(p) - pool.baseAddr) >> pool.shiftBy, bits);
        }
        return p;
    }


    /**
     *
     */
    void *calloc(size_t size, uint bits = 0, size_t *alloc_size = null, const TypeInfo ti = null) nothrow
    {
        if (!size)
        {
            if(alloc_size)
                *alloc_size = 0;
            return null;
        }

        size_t localAllocSize = void;
        void* p = void;
        if(alloc_size is null) alloc_size = &localAllocSize;

        // Since a finalizer could launch a new thread, we always need to lock
        // when collecting.  The safest way to do this is to simply always lock
        // when allocating.
        {
            gcLock.lock();
            p = mallocNoSync(size, bits, *alloc_size, ti);
            gcLock.unlock();
        }

        memset(p, 0, size);
        if (!(bits & BlkAttr.NO_SCAN))
        {
            memset(p + size, 0, *alloc_size - size);
        }

        return p;
    }

    /**
     *
     */
    void *realloc(void *p, size_t size, uint bits = 0, size_t *alloc_size = null, const TypeInfo ti = null) nothrow
    {
        size_t localAllocSize = void;
        auto oldp = p;
        if(alloc_size is null) alloc_size = &localAllocSize;

        // Since a finalizer could launch a new thread, we always need to lock
        // when collecting.  The safest way to do this is to simply always lock
        // when allocating.
        {
            gcLock.lock();
            p = reallocNoSync(p, size, bits, *alloc_size, ti);
            gcLock.unlock();
        }

        if (p !is oldp && !(bits & BlkAttr.NO_SCAN))
        {
            memset(p + size, 0, *alloc_size - size);
        }

        return p;
    }


    //
    // bits will be set to the resulting bits of the new block
    //
    private void *reallocNoSync(void *p, size_t size, ref uint bits, ref size_t alloc_size, const TypeInfo ti = null) nothrow
    {
        if (gcx.running)
            onInvalidMemoryOperationError();

        if (!size)
        {   if (p)
            {   freeNoSync(p);
                p = null;
            }
            alloc_size = 0;
        }
        else if (!p)
        {
            p = mallocNoSync(size, bits, alloc_size, ti);
        }
        else
        {   void *p2;
            size_t psize;

            //debug(PRINTF) printf("GC::realloc(p = %p, size = %zu)\n", p, size);
            debug (SENTINEL)
            {
                sentinel_Invariant(p);
                psize = *sentinel_size(p);
                if (psize != size)
                {
                    if (psize)
                    {
                        Pool *pool = gcx.findPool(p);

                        if (pool)
                        {
                            auto biti = cast(size_t)(sentinel_sub(p) - pool.baseAddr) >> pool.shiftBy;

                            if (bits)
                            {
                                gcx.clrBits(pool, biti, ~BlkAttr.NONE);
                                gcx.setBits(pool, biti, bits);
                            }
                            else
                            {
                                bits = gcx.getBits(pool, biti);
                            }
                        }
                    }
                    p2 = mallocNoSync(size, bits, alloc_size, ti);
                    if (psize < size)
                        size = psize;
                    //debug(PRINTF) printf("\tcopying %d bytes\n",size);
                    memcpy(p2, p, size);
                    p = p2;
                }
            }
            else
            {
                auto pool = gcx.findPool(p);
                psize = pool.getSize(p);     // get allocated size
                if (psize >= PAGESIZE && size >= PAGESIZE)
                {
                    auto psz = psize / PAGESIZE;
                    auto newsz = (size + PAGESIZE - 1) / PAGESIZE;
                    if (newsz == psz)
                        return p;

                    auto pagenum = pool.pagenumOf(p);

                    if (newsz < psz)
                    {   // Shrink in place
                        debug (MEMSTOMP) memset(p + size, 0xF2, psize - size);
                        pool.freePages(pagenum + newsz, psz - newsz);
                    }
                    else if (pagenum + newsz <= pool.npages)
                    {   // Attempt to expand in place
                        foreach (binsz; pool.pagetable[pagenum + psz .. pagenum + newsz])
                            if (binsz != B_FREE) goto Lfallthrough;

                        debug (MEMSTOMP) memset(p + psize, 0xF0, size - psize);
                        debug(PRINTF) printFreeInfo(pool);
                        memset(&pool.pagetable[pagenum + psz], B_PAGEPLUS, newsz - psz);
                        pool.freepages -= (newsz - psz);
                        debug(PRINTF) printFreeInfo(pool);
                    }
                    else
                        goto Lfallthrough; // does not fit into current pool
                    pool.updateOffsets(pagenum);
                    if (bits)
                    {
                        immutable biti = cast(size_t)(p - pool.baseAddr) >> pool.shiftBy;
                        gcx.clrBits(pool, biti, ~BlkAttr.NONE);
                        gcx.setBits(pool, biti, bits);
                    }
                    alloc_size = newsz * PAGESIZE;
                    return p;
                    Lfallthrough:
                        {}
                }
                if (psize < size ||             // if new size is bigger
                    psize > size * 2)           // or less than half
                {
                    if (psize && pool)
                    {
                        auto biti = cast(size_t)(p - pool.baseAddr) >> pool.shiftBy;

                        if (bits)
                        {
                            gcx.clrBits(pool, biti, ~BlkAttr.NONE);
                            gcx.setBits(pool, biti, bits);
                        }
                        else
                        {
                            bits = gcx.getBits(pool, biti);
                        }
                    }
                    p2 = mallocNoSync(size, bits, alloc_size, ti);
                    if (psize < size)
                        size = psize;
                    //debug(PRINTF) printf("\tcopying %d bytes\n",size);
                    memcpy(p2, p, size);
                    p = p2;
                }
                else
                    alloc_size = psize;
            }
        }
        return p;
    }


    /**
     * Attempt to in-place enlarge the memory block pointed to by p by at least
     * minbytes beyond its current capacity, up to a maximum of maxsize.  This
     * does not attempt to move the memory block (like realloc() does).
     *
     * Returns:
     *  0 if could not extend p,
     *  total size of entire memory block if successful.
     */
    size_t extend(void* p, size_t minsize, size_t maxsize, const TypeInfo ti = null) nothrow
    {
        gcLock.lock();
        auto rc = extendNoSync(p, minsize, maxsize, ti);
        gcLock.unlock();
        return rc;
    }


    //
    //
    //
    private size_t extendNoSync(void* p, size_t minsize, size_t maxsize, const TypeInfo ti = null) nothrow
    in
    {
        assert(minsize <= maxsize);
    }
    body
    {
        if (gcx.running)
            onInvalidMemoryOperationError();

        //debug(PRINTF) printf("GC::extend(p = %p, minsize = %zu, maxsize = %zu)\n", p, minsize, maxsize);
        debug (SENTINEL)
        {
            return 0;
        }
        else
        {
            auto pool = gcx.findPool(p);
            if (!pool)
                return 0;
            auto psize = pool.getSize(p);   // get allocated size
            if (psize < PAGESIZE)
                return 0;                   // cannot extend buckets

            auto psz = psize / PAGESIZE;
            auto minsz = (minsize + PAGESIZE - 1) / PAGESIZE;
            auto maxsz = (maxsize + PAGESIZE - 1) / PAGESIZE;

            auto pagenum = pool.pagenumOf(p);

            size_t sz;
            for (sz = 0; sz < maxsz; sz++)
            {
                auto i = pagenum + psz + sz;
                if (i == pool.npages)
                    break;
                if (pool.pagetable[i] != B_FREE)
                {   if (sz < minsz)
                        return 0;
                    break;
                }
            }
            if (sz < minsz)
                return 0;
            debug (MEMSTOMP) memset(pool.baseAddr + (pagenum + psz) * PAGESIZE, 0xF0, sz * PAGESIZE);
            memset(pool.pagetable + pagenum + psz, B_PAGEPLUS, sz);
            pool.updateOffsets(pagenum);
            pool.freepages -= sz;
            return (psz + sz) * PAGESIZE;
        }
    }


    /**
     *
     */
    size_t reserve(size_t size) nothrow
    {
        if (!size)
        {
            return 0;
        }

        gcLock.lock();
        auto rc = reserveNoSync(size);
        gcLock.unlock();
        return rc;
    }


    //
    //
    //
    private size_t reserveNoSync(size_t size) nothrow
    {
        assert(size != 0);
        assert(gcx);

        if (gcx.running)
            onInvalidMemoryOperationError();

        return gcx.reserve(size);
    }


    /**
     *
     */
    void free(void *p) nothrow
    {
        if (!p)
        {
            return;
        }

        gcLock.lock();
        freeNoSync(p);
        gcLock.unlock();
    }


    //
    //
    //
    private void freeNoSync(void *p) nothrow
    {
        debug(PRINTF) printf("Freeing %p\n", cast(size_t) p);
        assert (p);

        if (gcx.running)
            onInvalidMemoryOperationError();

        Pool*  pool;
        size_t pagenum;
        Bins   bin;
        size_t biti;

        // Find which page it is in
        pool = gcx.findPool(p);
        if (!pool)                              // if not one of ours
            return;                             // ignore

        pagenum = pool.pagenumOf(p);

        debug(PRINTF) printf("pool base = %p, PAGENUM = %d of %d, bin = %d\n", pool.baseAddr, pagenum, pool.npages, pool.pagetable[pagenum]);
        debug(PRINTF) if(pool.isLargeObject) printf("Block size = %d\n", pool.bPageOffsets[pagenum]);

        bin = cast(Bins)pool.pagetable[pagenum];

        // Verify that the pointer is at the beginning of a block,
        //  no action should be taken if p is an interior pointer
        if (bin > B_PAGE) // B_PAGEPLUS or B_FREE
            return;
        if ((sentinel_sub(p) - pool.baseAddr) & (binsize[bin] - 1))
            return;

        sentinel_Invariant(p);
        p = sentinel_sub(p);
        biti = cast(size_t)(p - pool.baseAddr) >> pool.shiftBy;

        gcx.clrBits(pool, biti, ~BlkAttr.NONE);

        if (bin == B_PAGE)              // if large alloc
        {   size_t npages;

            // Free pages
            npages = pool.bPageOffsets[pagenum];
            debug (MEMSTOMP) memset(p, 0xF2, npages * PAGESIZE);
            pool.freePages(pagenum, npages);
        }
        else
        {   // Add to free list
            List *list = cast(List*)p;

            debug (MEMSTOMP) memset(p, 0xF2, binsize[bin]);

            list.next = gcx.bucket[bin];
            list.pool = pool;
            gcx.bucket[bin] = list;
        }

        gcx.log_free(sentinel_add(p));
    }


    /**
     * Determine the base address of the block containing p.  If p is not a gc
     * allocated pointer, return null.
     */
    void* addrOf(void *p) nothrow
    {
        if (!p)
        {
            return null;
        }

        gcLock.lock();
        auto rc = addrOfNoSync(p);
        gcLock.unlock();
        return rc;
    }


    //
    //
    //
    void* addrOfNoSync(void *p) nothrow
    {
        if (!p)
        {
            return null;
        }

        auto q = gcx.findBase(p);
        if (q)
            q = sentinel_add(q);
        return q;
    }


    /**
     * Determine the allocated size of pointer p.  If p is an interior pointer
     * or not a gc allocated pointer, return 0.
     */
    size_t sizeOf(void *p) nothrow
    {
        if (!p)
        {
            return 0;
        }

        gcLock.lock();
        auto rc = sizeOfNoSync(p);
        gcLock.unlock();
        return rc;
    }


    //
    //
    //
    private size_t sizeOfNoSync(void *p) nothrow
    {
        assert (p);

        debug (SENTINEL)
        {
            p = sentinel_sub(p);
            size_t size = gcx.findSize(p);

            // Check for interior pointer
            // This depends on:
            // 1) size is a power of 2 for less than PAGESIZE values
            // 2) base of memory pool is aligned on PAGESIZE boundary
            if (cast(size_t)p & (size - 1) & (PAGESIZE - 1))
                size = 0;
            return size ? size - SENTINEL_EXTRA : 0;
        }
        else
        {
            size_t size = gcx.findSize(p);

            // Check for interior pointer
            // This depends on:
            // 1) size is a power of 2 for less than PAGESIZE values
            // 2) base of memory pool is aligned on PAGESIZE boundary
            if (cast(size_t)p & (size - 1) & (PAGESIZE - 1))
                return 0;
            return size;
        }
    }


    /**
     * Determine the base address of the block containing p.  If p is not a gc
     * allocated pointer, return null.
     */
    BlkInfo query(void *p) nothrow
    {
        if (!p)
        {
            BlkInfo i;
            return  i;
        }

        gcLock.lock();
        auto rc = queryNoSync(p);
        gcLock.unlock();
        return rc;
    }


    //
    //
    //
    BlkInfo queryNoSync(void *p) nothrow
    {
        assert(p);

        BlkInfo info = gcx.getInfo(p);
        debug(SENTINEL)
        {
            if (info.base)
            {
                info.base = sentinel_add(info.base);
                info.size = *sentinel_size(info.base);
            }
        }
        return info;
    }


    /**
     * Verify that pointer p:
     *  1) belongs to this memory pool
     *  2) points to the start of an allocated piece of memory
     *  3) is not on a free list
     */
    void check(void *p) nothrow
    {
        if (!p)
        {
            return;
        }

        gcLock.lock();
        checkNoSync(p);
        gcLock.unlock();
    }


    //
    //
    //
    private void checkNoSync(void *p) nothrow
    {
        assert(p);

        sentinel_Invariant(p);
        debug (PTRCHECK)
        {
            Pool*  pool;
            size_t pagenum;
            Bins   bin;
            size_t size;

            p = sentinel_sub(p);
            pool = gcx.findPool(p);
            assert(pool);
            pagenum = pool.pagenumOf(p);
            bin = cast(Bins)pool.pagetable[pagenum];
            assert(bin <= B_PAGE);
            size = binsize[bin];
            assert((cast(size_t)p & (size - 1)) == 0);

            debug (PTRCHECK2)
            {
                if (bin < B_PAGE)
                {
                    // Check that p is not on a free list
                    List *list;

                    for (list = gcx.bucket[bin]; list; list = list.next)
                    {
                        assert(cast(void*)list != p);
                    }
                }
            }
        }
    }


    /**
     * add p to list of roots
     */
    void addRoot(void *p) nothrow
    {
        if (!p)
        {
            return;
        }

        gcLock.lock();
        gcx.addRoot(p);
        gcLock.unlock();
    }


    /**
     * remove p from list of roots
     */
    void removeRoot(void *p) nothrow
    {
        if (!p)
        {
            return;
        }

        gcLock.lock();
        gcx.removeRoot(p);
        gcLock.unlock();
    }


    /**
     *
     */
    @property auto rootIter()
    {
        auto iter(scope int delegate(ref Root) nothrow dg)
        {
            gcLock.lock();
            auto res = gcx.roots.opApply(dg);
            gcLock.unlock();
            return res;
        }
        return &iter;
    }


    /**
     * add range to scan for roots
     */
    void addRange(void *p, size_t sz, const TypeInfo ti = null) nothrow
    {
        if (!p || !sz)
        {
            return;
        }

        //debug(PRINTF) printf("+GC.addRange(p = %p, sz = 0x%zx), p + sz = %p\n", p, sz, p + sz);

        gcLock.lock();
        gcx.addRange(p, p + sz, ti);
        gcLock.unlock();

        //debug(PRINTF) printf("-GC.addRange()\n");
    }


    /**
     * remove range
     */
    void removeRange(void *p) nothrow
    {
        if (!p)
        {
            return;
        }

        gcLock.lock();
        gcx.removeRange(p);
        gcLock.unlock();
    }

    /**
     * run finalizers
     */
    void runFinalizers(in void[] segment) nothrow
    {
        gcLock.lock();
        gcx.runFinalizers(segment);
        gcLock.unlock();
    }

    /**
     *
     */
    @property auto rangeIter()
    {
        auto iter(scope int delegate(ref Range) nothrow dg)
        {
            gcLock.lock();
            auto res = gcx.ranges.opApply(dg);
            gcLock.unlock();
            return res;
        }
        return &iter;
    }


    /**
     * Do full garbage collection.
     * Return number of pages free'd.
     */
    size_t fullCollect() nothrow
    {
        debug(PRINTF) printf("GC.fullCollect()\n");
        size_t result;

        // Since a finalizer could launch a new thread, we always need to lock
        // when collecting.
        {
            gcLock.lock();
            result = gcx.fullcollect();
            gcLock.unlock();
        }

        version (none)
        {
            GCStats stats;

            getStats(stats);
            debug(PRINTF) printf("poolsize = %zx, usedsize = %zx, freelistsize = %zx\n",
                    stats.poolsize, stats.usedsize, stats.freelistsize);
        }

        gcx.log_collect();
        return result;
    }


    /**
     * do full garbage collection ignoring roots
     */
    void fullCollectNoStack() nothrow
    {
        // Since a finalizer could launch a new thread, we always need to lock
        // when collecting.
        {
            gcLock.lock();
            gcx.noStack++;
            gcx.fullcollect();
            gcx.noStack--;
            gcLock.unlock();
        }
    }


    /**
     * minimize free space usage
     */
    void minimize() nothrow
    {
        gcLock.lock();
        gcx.minimize();
        gcLock.unlock();
    }


    /**
     * Retrieve statistics about garbage collection.
     * Useful for debugging and tuning.
     */
    void getStats(out GCStats stats) nothrow
    {
        gcLock.lock();
        getStatsNoSync(stats);
        gcLock.unlock();
    }


    //
    //
    //
    private void getStatsNoSync(out GCStats stats) nothrow
    {
        size_t psize = 0;
        size_t usize = 0;
        size_t flsize = 0;

        size_t n;
        size_t bsize = 0;

        //debug(PRINTF) printf("getStats()\n");
        memset(&stats, 0, GCStats.sizeof);

        for (n = 0; n < gcx.npools; n++)
        {   Pool *pool = gcx.pooltable[n];

            psize += pool.npages * PAGESIZE;
            for (size_t j = 0; j < pool.npages; j++)
            {
                Bins bin = cast(Bins)pool.pagetable[j];
                if (bin == B_FREE)
                    stats.freeblocks++;
                else if (bin == B_PAGE)
                    stats.pageblocks++;
                else if (bin < B_PAGE)
                    bsize += PAGESIZE;
            }
        }

        for (n = 0; n < B_PAGE; n++)
        {
            //debug(PRINTF) printf("bin %d\n", n);
            for (List *list = gcx.bucket[n]; list; list = list.next)
            {
                //debug(PRINTF) printf("\tlist %p\n", list);
                flsize += binsize[n];
            }
        }

        usize = bsize - flsize;

        stats.poolsize = psize;
        stats.usedsize = bsize - flsize;
        stats.freelistsize = flsize;
    }
}


/* ============================ Gcx =============================== */

enum
{   PAGESIZE =    4096,
    POOLSIZE =   (4096*256),
}


enum
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
    B_MAX
}


alias ubyte Bins;


struct List
{
    List *next;
    Pool *pool;
}


struct Range
{
    void *pbot;
    void *ptop;
    alias pbot this; // only consider pbot for relative ordering (opCmp)
}

struct Root
{
    void *proot;
    alias proot this;
}


immutable uint[B_MAX] binsize = [ 16,32,64,128,256,512,1024,2048,4096 ];
immutable size_t[B_MAX] notbinsize = [ ~(16-1),~(32-1),~(64-1),~(128-1),~(256-1),
                                ~(512-1),~(1024-1),~(2048-1),~(4096-1) ];

/* ============================ Gcx =============================== */

struct Gcx
{
    static if (USE_CACHE){
        byte *cached_pool_topAddr;
        byte *cached_pool_baseAddr;
        Pool *cached_pool;
        debug (CACHE_HITRATE)
        {
            ulong cached_pool_queries;
            ulong cached_pool_hits;
        }
    }
    Treap!Root roots;
    Treap!Range ranges;

    uint noStack;       // !=0 means don't scan stack
    uint log;           // turn on logging
    uint anychanges;
    uint inited;
    uint running;
    int disabled;       // turn off collections if >0

    byte *minAddr;      // min(baseAddr)
    byte *maxAddr;      // max(topAddr)

    size_t npools;
    Pool **pooltable;

    List*[B_MAX]bucket;        // free list for each size


    void initialize()
    {   int dummy;

        (cast(byte*)&this)[0 .. Gcx.sizeof] = 0;
        log_init();
        roots.initialize();
        ranges.initialize();
        //printf("gcx = %p, self = %x\n", &this, self);
        inited = 1;
    }


    void Dtor()
    {
        if (GC.config.profile)
        {
            printf("\tNumber of collections:  %llu\n", cast(ulong)numCollections);
            printf("\tTotal GC prep time:  %lld milliseconds\n",
                   prepTime.total!("msecs"));
            printf("\tTotal mark time:  %lld milliseconds\n",
                   markTime.total!("msecs"));
            printf("\tTotal sweep time:  %lld milliseconds\n",
                   sweepTime.total!("msecs"));
            printf("\tTotal page recovery time:  %lld milliseconds\n",
                   recoverTime.total!("msecs"));
            long maxPause = maxPauseTime.total!("msecs");
            printf("\tMax Pause Time:  %lld milliseconds\n", maxPause);
            long gcTime = (recoverTime + sweepTime + markTime + prepTime).total!("msecs");
            printf("\tGrand total GC time:  %lld milliseconds\n", gcTime);
            long pauseTime = (markTime + prepTime).total!("msecs");
            printf("GC summary:%5lld MB,%5lld GC%5lld ms, Pauses%5lld ms <%5lld ms\n",
                   cast(long) maxPoolMemory >> 20, cast(ulong)numCollections, gcTime,
                   pauseTime, maxPause);
        }

        debug(CACHE_HITRATE)
        {
            printf("\tGcx.Pool Cache hits: %llu\tqueries: %llu\n",cached_pool_hits,cached_pool_queries);
        }

        inited = 0;

        for (size_t i = 0; i < npools; i++)
        {   Pool *pool = pooltable[i];

            pool.Dtor();
            cstdlib.free(pool);
        }
        if (pooltable)
        {
            cstdlib.free(pooltable);
            pooltable = null;
        }

        roots.removeAll();
        ranges.removeAll();
    }


    void Invariant() const { }

    debug(INVARIANT)
    invariant()
    {
        if (inited)
        {
            //printf("Gcx.invariant(): this = %p\n", &this);

            for (size_t i = 0; i < npools; i++)
            {   auto pool = pooltable[i];

                pool.Invariant();
                if (i == 0)
                {
                    assert(minAddr == pool.baseAddr);
                }
                if (i + 1 < npools)
                {
                    assert(pool.opCmp(pooltable[i + 1]) < 0);
                }
                else if (i + 1 == npools)
                {
                    assert(maxAddr == pool.topAddr);
                }
            }

            foreach (range; ranges)
            {
                assert(range.pbot);
                assert(range.ptop);
                assert(range.pbot <= range.ptop);
            }

            for (size_t i = 0; i < B_PAGE; i++)
            {
                for (auto list = cast(List*)bucket[i]; list; list = list.next)
                {
                }
            }
        }
    }


    /**
     *
     */
    void addRoot(void *p) nothrow
    {
        roots.insert(Root(p));
    }


    /**
     *
     */
    void removeRoot(void *p) nothrow
    {
        roots.remove(Root(p));
    }


    /**
     *
     */
    void addRange(void *pbot, void *ptop, const TypeInfo ti) nothrow
    {
        //debug(PRINTF) printf("Thread %x ", pthread_self());
        debug(PRINTF) printf("%p.Gcx::addRange(%p, %p)\n", &this, pbot, ptop);
        ranges.insert(Range(pbot, ptop));
    }


    /**
     *
     */
    void removeRange(void *pbot) nothrow
    {
        //debug(PRINTF) printf("Thread %x ", pthread_self());
        debug(PRINTF) printf("Gcx.removeRange(%p)\n", pbot);
        ranges.remove(Range(pbot, pbot)); // only pbot is used, see Range.opCmp

        // debug(PRINTF) printf("Wrong thread\n");
        // This is a fatal error, but ignore it.
        // The problem is that we can get a Close() call on a thread
        // other than the one the range was allocated on.
        //assert(zero);
    }


    /**
     *
     */
    void runFinalizers(in void[] segment) nothrow
    {
        foreach (pool; pooltable[0 .. npools])
        {
            if (!pool.finals.nbits) continue;

            if (pool.isLargeObject)
            {
                foreach (ref pn; 0 .. pool.npages)
                {
                    Bins bin = cast(Bins)pool.pagetable[pn];
                    if (bin > B_PAGE) continue;
                    size_t biti = pn;

                    auto p = pool.baseAddr + pn * PAGESIZE;

                    if (!pool.finals.test(biti) ||
                        !rt_hasFinalizerInSegment(sentinel_add(p), segment))
                        continue;

                    rt_finalize2(sentinel_add(p), false, false);
                    clrBits(pool, biti, ~BlkAttr.NONE);

                    if (pn < pool.searchStart) pool.searchStart = pn;

                    debug(COLLECT_PRINTF) printf("\tcollecting big %p\n", p);
                    log_free(sentinel_add(p));

                    size_t n = 1;
                    for (; pn + n < pool.npages; ++n)
                        if (pool.pagetable[pn + n] != B_PAGEPLUS) break;
                    debug (MEMSTOMP) memset(pool.baseAddr + pn * PAGESIZE, 0xF3, n * PAGESIZE);
                    pool.freePages(pn, n);
                }
            }
            else
            {
                foreach (ref pn; 0 .. pool.npages)
                {
                    Bins bin = cast(Bins)pool.pagetable[pn];

                    if (bin >= B_PAGE) continue;

                    immutable size = binsize[bin];
                    auto p = pool.baseAddr + pn * PAGESIZE;
                    const ptop = p + PAGESIZE;
                    auto biti = pn * (PAGESIZE/16);
                    immutable bitstride = size / 16;

                    GCBits.wordtype toClear;
                    size_t clearStart = (biti >> GCBits.BITS_SHIFT) + 1;
                    size_t clearIndex;

                    for (; p < ptop; p += size, biti += bitstride, clearIndex += bitstride)
                    {
                        if (clearIndex > GCBits.BITS_PER_WORD - 1)
                        {
                            if (toClear)
                            {
                                Gcx.clrBitsSmallSweep(pool, clearStart, toClear);
                                toClear = 0;
                            }

                            clearStart = (biti >> GCBits.BITS_SHIFT) + 1;
                            clearIndex = biti & GCBits.BITS_MASK;
                        }

                        if (!pool.finals.test(biti) ||
                            !rt_hasFinalizerInSegment(sentinel_add(p), segment))
                            continue;

                        rt_finalize2(sentinel_add(p), false, false);
                        toClear |= GCBits.BITS_1 << clearIndex;

                        debug(COLLECT_PRINTF) printf("\tcollecting %p\n", p);
                        log_free(sentinel_add(p));

                        debug (MEMSTOMP) memset(p, 0xF3, size);
                        pool.freebits.set(biti);
                    }

                    if (toClear)
                    {
                        Gcx.clrBitsSmallSweep(pool, clearStart, toClear);
                    }
                }
            }
        }
    }


    /**
     * Find Pool that pointer is in.
     * Return null if not in a Pool.
     * Assume pooltable[] is sorted.
     */
    Pool *findPool(bool bypassCache = !USE_CACHE)(void *p) nothrow
    {
        static if (!bypassCache && USE_CACHE)
        {
            debug (CACHE_HITRATE) cached_pool_queries++;
            if (p < cached_pool_topAddr
                && p >= cached_pool_baseAddr)
            {
                debug (CACHE_HITRATE) cached_pool_hits++;
                return cached_pool;
            }
        }
        if (p >= minAddr && p < maxAddr)
        {
            if (npools <= 1)
            {
                return npools == 0 ? null : pooltable[0];
            }

            /* The pooltable[] is sorted by address, so do a binary search
             */
            auto pt = pooltable;
            size_t low = 0;
            size_t high = npools - 1;
            while (low <= high)
            {
                size_t mid = (low + high) >> 1;
                auto pool = pt[mid];
                if (p < pool.baseAddr)
                    high = mid - 1;
                else if (p >= pool.topAddr)
                    low = mid + 1;
                else
                {
                    static if (!bypassCache && USE_CACHE)
                    {
                        cached_pool_topAddr = pool.topAddr;
                        cached_pool_baseAddr = pool.baseAddr;
                        cached_pool = pool;
                    }
                    return pool;
                }
            }
        }
        return null;
    }


    /**
     * Find base address of block containing pointer p.
     * Returns null if not a gc'd pointer
     */
    void* findBase(void *p) nothrow
    {
        Pool *pool;

        pool = findPool(p);
        if (pool)
        {
            size_t offset = cast(size_t)(p - pool.baseAddr);
            size_t pn = offset / PAGESIZE;
            Bins   bin = cast(Bins)pool.pagetable[pn];

            // Adjust bit to be at start of allocated memory block
            if (bin <= B_PAGE)
            {
                return pool.baseAddr + (offset & notbinsize[bin]);
            }
            else if (bin == B_PAGEPLUS)
            {
                auto pageOffset = pool.bPageOffsets[pn];
                offset -= pageOffset * PAGESIZE;
                pn -= pageOffset;

                return pool.baseAddr + (offset & (offset.max ^ (PAGESIZE-1)));
            }
            else
            {
                // we are in a B_FREE page
                assert(bin == B_FREE);
                return null;
            }
        }
        return null;
    }


    /**
     * Find size of pointer p.
     * Returns 0 if not a gc'd pointer
     */
    size_t findSize(void *p) nothrow
    {
        Pool* pool = findPool(p);
        if (pool)
            return pool.getSize(p);
        return 0;
    }

    /**
     *
     */
    BlkInfo getInfo(void* p) nothrow
    {
        Pool*   pool;
        BlkInfo info;

        pool = findPool(p);
        if (pool)
        {
            size_t offset = cast(size_t)(p - pool.baseAddr);
            size_t pn = offset / PAGESIZE;
            Bins   bin = cast(Bins)pool.pagetable[pn];

            ////////////////////////////////////////////////////////////////////
            // findAddr
            ////////////////////////////////////////////////////////////////////

            if (bin <= B_PAGE)
            {
                info.base = cast(void*)((cast(size_t)p) & notbinsize[bin]);
            }
            else if (bin == B_PAGEPLUS)
            {
                auto pageOffset = pool.bPageOffsets[pn];
                offset = pageOffset * PAGESIZE;
                pn -= pageOffset;
                info.base = pool.baseAddr + (offset & (offset.max ^ (PAGESIZE-1)));

                // fix bin for use by size calc below
                bin = cast(Bins)pool.pagetable[pn];
            }

            ////////////////////////////////////////////////////////////////////
            // findSize
            ////////////////////////////////////////////////////////////////////

            info.size = binsize[bin];
            if (bin == B_PAGE)
            {
                info.size = pool.bPageOffsets[pn] * PAGESIZE;
            }

            ////////////////////////////////////////////////////////////////////
            // getBits
            ////////////////////////////////////////////////////////////////////

            // reset the offset to the base pointer, otherwise the bits
            // are the bits for the pointer, which may be garbage
            offset = cast(size_t)(info.base - pool.baseAddr);
            info.attr = getBits(pool, cast(size_t)(offset >> pool.shiftBy));
        }
        return info;
    }

    void resetPoolCache() nothrow
    {
        static if (USE_CACHE){
            cached_pool_topAddr = cached_pool_topAddr.init;
            cached_pool_baseAddr = cached_pool_baseAddr.init;
            cached_pool = cached_pool.init;
        }
    }

    /**
     * Compute bin for size.
     */
    static Bins findBin(size_t size) nothrow
    {
        static const byte[2049] binTable = ctfeBins();

        return (size <= 2048) ?
            (cast(Bins) binTable[size]) :
            B_PAGE;
    }

    static Bins findBinImpl(size_t size) nothrow
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

    /**
     * Computes the bin table using CTFE.
     */
    static byte[2049] ctfeBins() nothrow
    {
        byte[2049] ret;
        for(size_t i = 0; i < 2049; i++)
        {
            ret[i] = cast(byte) findBinImpl(i);
        }

        return ret;
    }


    /**
     * Allocate a new pool of at least size bytes.
     * Sort it into pooltable[].
     * Mark all memory in the pool as B_FREE.
     * Return the actual number of bytes reserved or 0 on error.
     */
    size_t reserve(size_t size) nothrow
    {
        size_t npages = (size + PAGESIZE - 1) / PAGESIZE;

        // Assume reserve() is for small objects.
        Pool*  pool = newPool(npages, false);

        if (!pool)
            return 0;
        return pool.npages * PAGESIZE;
    }


    /**
     * Minimizes physical memory usage by returning free pools to the OS.
     */
    void minimize() nothrow
    {
        debug(PRINTF) printf("Minimizing.\n");

        static bool isUsed(Pool *pool) nothrow
        {
            return pool.freepages < pool.npages;
        }

        // semi-stable partition
        for (size_t i = 0; i < npools; ++i)
        {
            auto pool = pooltable[i];
            // find first unused pool
            if (isUsed(pool)) continue;

            // move used pools before unused ones
            size_t j = i + 1;
            for (; j < npools; ++j)
            {
                pool = pooltable[j];
                if (!isUsed(pool)) continue;
                // swap
                pooltable[j] = pooltable[i];
                pooltable[i] = pool;
                ++i;
            }
            // npooltable[0 .. i]      => used
            // npooltable[i .. npools] => free

            // free unused pools
            for (j = i; j < npools; ++j)
            {
                pool = pooltable[j];
                debug(PRINTF) printFreeInfo(pool);
                pool.Dtor();
                cstdlib.free(pool);
            }
            npools = i;
        }

        if (npools)
        {
            minAddr = pooltable[0].baseAddr;
            maxAddr = pooltable[npools - 1].topAddr;
        }
        else
        {
            minAddr = maxAddr = null;
        }

        static if (USE_CACHE){
            resetPoolCache();
        }

        debug(PRINTF) printf("Done minimizing.\n");
    }

    unittest
    {
        enum NPOOLS = 6;
        enum NPAGES = 10;
        Gcx gcx;

        void reset()
        {
            foreach(i, ref pool; gcx.pooltable[0 .. gcx.npools])
                pool.freepages = pool.npages;
            gcx.minimize();
            assert(gcx.npools == 0);

            if (gcx.pooltable is null)
                gcx.pooltable = cast(Pool**)cstdlib.malloc(NPOOLS * (Pool*).sizeof);
            foreach(i; 0 .. NPOOLS)
            {
                auto pool = cast(Pool*)cstdlib.malloc(Pool.sizeof);
                *pool = Pool.init;
                gcx.pooltable[i] = pool;
            }
            gcx.npools = NPOOLS;
        }

        void usePools()
        {
            foreach(pool; gcx.pooltable[0 .. NPOOLS])
            {
                pool.pagetable = cast(ubyte*)cstdlib.malloc(NPAGES);
                memset(pool.pagetable, B_FREE, NPAGES);
                pool.npages = NPAGES;
                pool.freepages = NPAGES / 2;
            }
        }

        // all pools are free
        reset();
        assert(gcx.npools == NPOOLS);
        gcx.minimize();
        assert(gcx.npools == 0);

        // all pools used
        reset();
        usePools();
        assert(gcx.npools == NPOOLS);
        gcx.minimize();
        assert(gcx.npools == NPOOLS);

        // preserves order of used pools
        reset();
        usePools();

        {
            Pool*[NPOOLS] opools = gcx.pooltable[0 .. NPOOLS];
            gcx.pooltable[2].freepages = NPAGES;

            gcx.minimize();
            assert(gcx.npools == NPOOLS - 1);
            assert(gcx.pooltable[0] == opools[0]);
            assert(gcx.pooltable[1] == opools[1]);
            assert(gcx.pooltable[2] == opools[3]);
        }

        // gcx reduces address span
        reset();
        usePools();

        byte* base, top;

        {
            byte*[NPOOLS] mem = void;
            foreach(i; 0 .. NPOOLS)
                mem[i] = cast(byte*)os_mem_map(NPAGES * PAGESIZE);

            extern(C) static int compare(in void* p1, in void *p2)
            {
                return p1 < p2 ? -1 : cast(int)(p2 > p1);
            }
            cstdlib.qsort(mem.ptr, mem.length, (byte*).sizeof, &compare);

            foreach(i, pool; gcx.pooltable[0 .. NPOOLS])
            {
                pool.baseAddr = mem[i];
                pool.topAddr = pool.baseAddr + NPAGES * PAGESIZE;
            }

            base = gcx.pooltable[0].baseAddr;
            top = gcx.pooltable[NPOOLS - 1].topAddr;
        }

        gcx.minimize();
        assert(gcx.npools == NPOOLS);
        assert(gcx.minAddr == base);
        assert(gcx.maxAddr == top);

        gcx.pooltable[NPOOLS - 1].freepages = NPAGES;
        gcx.pooltable[NPOOLS - 2].freepages = NPAGES;

        gcx.minimize();
        assert(gcx.npools == NPOOLS - 2);
        assert(gcx.minAddr == base);
        assert(gcx.maxAddr == gcx.pooltable[NPOOLS - 3].topAddr);

        gcx.pooltable[0].freepages = NPAGES;

        gcx.minimize();
        assert(gcx.npools == NPOOLS - 3);
        assert(gcx.minAddr != base);
        assert(gcx.minAddr == gcx.pooltable[0].baseAddr);
        assert(gcx.maxAddr == gcx.pooltable[NPOOLS - 4].topAddr);

        // free all
        foreach(pool; gcx.pooltable[0 .. gcx.npools])
            pool.freepages = NPAGES;
        gcx.minimize();
        assert(gcx.npools == 0);
        cstdlib.free(gcx.pooltable);
        gcx.pooltable = null;
    }


    /**
     * Allocate a chunk of memory that is larger than a page.
     * Return null if out of memory.
     */
    void *bigAlloc(size_t size, Pool **poolPtr, ref size_t alloc_size) nothrow
    {
        debug(PRINTF) printf("In bigAlloc.  Size:  %d\n", size);

        Pool*  pool;
        size_t npages;
        size_t n;
        size_t pn;
        size_t freedpages;
        void*  p;
        int    state;
        bool   collected = false;

        npages = (size + PAGESIZE - 1) / PAGESIZE;

        for (state = disabled ? 1 : 0; ; )
        {
            // This code could use some refinement when repeatedly
            // allocating very large arrays.

            for (n = 0; n < npools; n++)
            {
                pool = pooltable[n];
                if(!pool.isLargeObject || pool.freepages < npages) continue;
                pn = pool.allocPages(npages);
                if (pn != OPFAIL)
                    goto L1;
            }

            // Failed
            switch (state)
            {
            case 0:
                // Try collecting
                collected = true;
                freedpages = fullcollect();
                if (freedpages >= npools * ((POOLSIZE / PAGESIZE) / 4))
                {   state = 1;
                    continue;
                }
                // Release empty pools to prevent bloat
                minimize();
                // Allocate new pool
                pool = newPool(npages, true);
                if (!pool)
                {   state = 2;
                    continue;
                }
                pn = pool.allocPages(npages);
                assert(pn != OPFAIL);
                goto L1;
            case 1:
                // Release empty pools to prevent bloat
                minimize();
                // Allocate new pool
                pool = newPool(npages, true);
                if (!pool)
                {
                    if (collected)
                        goto Lnomemory;
                    state = 0;
                    continue;
                }
                pn = pool.allocPages(npages);
                assert(pn != OPFAIL);
                goto L1;
            case 2:
                goto Lnomemory;
            default:
                assert(false);
            }
        }

      L1:
        debug(PRINTF) printFreeInfo(pool);
        pool.pagetable[pn] = B_PAGE;
        if (npages > 1)
            memset(&pool.pagetable[pn + 1], B_PAGEPLUS, npages - 1);
        pool.updateOffsets(pn);
        pool.freepages -= npages;

        debug(PRINTF) printFreeInfo(pool);

        p = pool.baseAddr + pn * PAGESIZE;
        debug(PRINTF) printf("Got large alloc:  %p, pt = %d, np = %d\n", p, pool.pagetable[pn], npages);
        debug (MEMSTOMP) memset(p, 0xF1, size);
        alloc_size = npages * PAGESIZE;
        //debug(PRINTF) printf("\tp = %p\n", p);

        *poolPtr = pool;
        return p;

      Lnomemory:
        return null; // let caller handle the error
    }


    /**
     * Allocate a new pool with at least npages in it.
     * Sort it into pooltable[].
     * Return null if failed.
     */
    Pool *newPool(size_t npages, bool isLargeObject) nothrow
    {
        Pool*  pool;
        Pool** newpooltable;
        size_t newnpools;
        size_t i;

        //debug(PRINTF) printf("************Gcx::newPool(npages = %d)****************\n", npages);

        // Minimum of POOLSIZE
        size_t minPages = (GC.config.minPoolSize << 20) / PAGESIZE;
        if (npages < minPages)
            npages = minPages;
        else if (npages > minPages)
        {   // Give us 150% of requested size, so there's room to extend
            auto n = npages + (npages >> 1);
            if (n < size_t.max/PAGESIZE)
                npages = n;
        }

        // Allocate successively larger pools up to 8 megs
        if (npools)
        {   size_t n;

            n = GC.config.minPoolSize + GC.config.incPoolSize * npools;
            if (n > GC.config.maxPoolSize)
                n = GC.config.maxPoolSize;                 // cap pool size
            n *= (1 << 20) / PAGESIZE;                     // convert MB to pages
            if (npages < n)
                npages = n;
        }

        //printf("npages = %d\n", npages);

        pool = cast(Pool *)cstdlib.calloc(1, Pool.sizeof);
        if (pool)
        {
            pool.initialize(npages, isLargeObject);
            if (!pool.baseAddr)
                goto Lerr;

            newnpools = npools + 1;
            newpooltable = cast(Pool **)cstdlib.realloc(pooltable, newnpools * (Pool *).sizeof);
            if (!newpooltable)
                goto Lerr;

            // Sort pool into newpooltable[]
            for (i = 0; i < npools; i++)
            {
                if (pool.opCmp(newpooltable[i]) < 0)
                     break;
            }
            memmove(newpooltable + i + 1, newpooltable + i, (npools - i) * (Pool *).sizeof);
            newpooltable[i] = pool;

            pooltable = newpooltable;
            npools = newnpools;

            minAddr = pooltable[0].baseAddr;
            maxAddr = pooltable[npools - 1].topAddr;
        }

        if (GC.config.profile)
        {
            size_t gcmem = 0;
            for(i = 0; i < npools; i++)
                gcmem += pooltable[i].topAddr - pooltable[i].baseAddr;
            if(gcmem > maxPoolMemory)
                maxPoolMemory = gcmem;
        }
        return pool;

      Lerr:
        pool.Dtor();
        cstdlib.free(pool);
        return null;
    }


    /**
     * Allocate a page of bin's.
     * Returns:
     *  0       failed
     */
    int allocPage(Bins bin) nothrow
    {
        Pool*  pool;
        size_t n;
        size_t pn;
        byte*  p;
        byte*  ptop;

        //debug(PRINTF) printf("Gcx::allocPage(bin = %d)\n", bin);
        for (n = 0; n < npools; n++)
        {
            pool = pooltable[n];
            if(pool.isLargeObject) continue;
            pn = pool.allocPages(1);
            if (pn != OPFAIL)
                goto L1;
        }
        return 0;               // failed

      L1:
        pool.pagetable[pn] = cast(ubyte)bin;
        pool.freepages--;

        // Convert page to free list
        size_t size = binsize[bin];
        List **b = &bucket[bin];

        p = pool.baseAddr + pn * PAGESIZE;
        ptop = p + PAGESIZE;
        for (; p < ptop; p += size)
        {
            (cast(List *)p).next = *b;
            (cast(List *)p).pool = pool;
            *b = cast(List *)p;
        }
        return 1;
    }

    /**
     * Mark overload for initial mark() call.
     */
    void mark(void *pbot, void *ptop) nothrow
    {
        mark(pbot, ptop, MAX_MARK_RECURSIONS);
    }

    /**
     * Search a range of memory values and mark any pointers into the GC pool.
     */
    void mark(void *pbot, void *ptop, int nRecurse) nothrow
    {
        //import core.stdc.stdio;printf("nRecurse = %d\n", nRecurse);
        void **p1 = cast(void **)pbot;
        void **p2 = cast(void **)ptop;
        size_t pcache = 0;
        uint changes = 0;

        //printf("marking range: %p -> %p\n", pbot, ptop);
        for (; p1 < p2; p1++)
        {
            auto p = cast(byte *)(*p1);

            //if (log) debug(PRINTF) printf("\tmark %p\n", p);
            if (p >= minAddr && p < maxAddr)
            {
                if ((cast(size_t)p & ~cast(size_t)(PAGESIZE-1)) == pcache)
                    continue;

                auto pool = findPool!true(p);
                if (pool)
                {
                    size_t offset = cast(size_t)(p - pool.baseAddr);
                    size_t biti = void;
                    size_t pn = offset / PAGESIZE;
                    Bins   bin = cast(Bins)pool.pagetable[pn];
                    void* base = void;

                    // For the NO_INTERIOR attribute.  This tracks whether
                    // the pointer is an interior pointer or points to the
                    // base address of a block.
                    bool pointsToBase = false;

                    //debug(PRINTF) printf("\t\tfound pool %p, base=%p, pn = %zd, bin = %d, biti = x%x\n", pool, pool.baseAddr, pn, bin, biti);

                    // Adjust bit to be at start of allocated memory block
                    if (bin < B_PAGE)
                    {
                        // We don't care abou setting pointsToBase correctly
                        // because it's ignored for small object pools anyhow.
                        auto offsetBase = offset & notbinsize[bin];
                        biti = offsetBase >> pool.shiftBy;
                        base = pool.baseAddr + offsetBase;
                        //debug(PRINTF) printf("\t\tbiti = x%x\n", biti);
                    }
                    else if (bin == B_PAGE)
                    {
                        auto offsetBase = offset & notbinsize[bin];
                        base = pool.baseAddr + offsetBase;
                        pointsToBase = (base == sentinel_sub(p));
                        biti = offsetBase >> pool.shiftBy;
                        //debug(PRINTF) printf("\t\tbiti = x%x\n", biti);

                        pcache = cast(size_t)p & ~cast(size_t)(PAGESIZE-1);
                    }
                    else if (bin == B_PAGEPLUS)
                    {
                        pn -= pool.bPageOffsets[pn];
                        base = pool.baseAddr + (pn * PAGESIZE);
                        biti = pn * (PAGESIZE >> pool.shiftBy);
                        pcache = cast(size_t)p & ~cast(size_t)(PAGESIZE-1);
                    }
                    else
                    {
                        // Don't mark bits in B_FREE pages
                        assert(bin == B_FREE);
                        continue;
                    }

                    if(pool.nointerior.nbits && !pointsToBase && pool.nointerior.test(biti))
                    {
                        continue;
                    }

                    //debug(PRINTF) printf("\t\tmark(x%x) = %d\n", biti, pool.mark.test(biti));
                    if (!pool.mark.testSet(biti))
                    {
                        //if (log) debug(PRINTF) printf("\t\tmarking %p\n", p);
                        if (!pool.noscan.test(biti))
                        {
                            if(nRecurse == 0) {
                                // Then we've got a really deep heap graph.
                                // Start marking stuff to be scanned when we
                                // traverse the heap again next time, to save
                                // stack space.
                                pool.scan.set(biti);
                                changes = 1;
                                pool.newChanges = true;
                            } else {
                                // Directly recurse mark() to prevent having
                                // to traverse the heap O(D) times where D
                                // is the max depth of the heap graph.
                                if (bin < B_PAGE)
                                {
                                    mark(base, base + binsize[bin], nRecurse - 1);
                                }
                                else
                                {
                                    auto u = pool.bPageOffsets[pn];
                                    mark(base, base + u * PAGESIZE, nRecurse - 1);
                                }
                            }
                        }

                        debug (LOGGING) log_parent(sentinel_add(pool.baseAddr + (biti << pool.shiftBy)), sentinel_add(pbot));
                    }
                }
            }
        }
        anychanges |= changes;
    }


    /**
     * Return number of full pages free'd.
     */
    size_t fullcollect() nothrow
    {
        size_t n;
        Pool*  pool;
        MonoTime start, stop, begin;

        if (GC.config.profile)
        {
            begin = start = currTime;
        }

        debug(COLLECT_PRINTF) printf("Gcx.fullcollect()\n");
        //printf("\tpool address range = %p .. %p\n", minAddr, maxAddr);

        if (running)
            onInvalidMemoryOperationError();
        running = 1;

        thread_suspendAll();

        anychanges = 0;
        for (n = 0; n < npools; n++)
        {
            pool = pooltable[n];
            pool.mark.zero();
            pool.scan.zero();
            if(!pool.isLargeObject) pool.freebits.zero();
        }

        debug(COLLECT_PRINTF) printf("Set bits\n");

        // Mark each free entry, so it doesn't get scanned
        for (n = 0; n < B_PAGE; n++)
        {
            for (List *list = bucket[n]; list; list = list.next)
            {
                pool = list.pool;
                assert(pool);
                pool.freebits.set(cast(size_t)(cast(byte*)list - pool.baseAddr) / 16);
            }
        }

        debug(COLLECT_PRINTF) printf("Marked free entries.\n");

        for (n = 0; n < npools; n++)
        {
            pool = pooltable[n];
            pool.newChanges = false;  // Some of these get set to true on stack scan.
            if(!pool.isLargeObject)
            {
                pool.mark.copy(&pool.freebits);
            }
        }

        if (GC.config.profile)
        {
            stop = currTime;
            prepTime += (stop - start);
            start = stop;
        }

        if (!noStack)
        {
            debug(COLLECT_PRINTF) printf("\tscan stacks.\n");
            // Scan stacks and registers for each paused thread
            thread_scanAll(&mark);
        }

        // Scan roots[]
        debug(COLLECT_PRINTF) printf("\tscan roots[]\n");
        foreach (root; roots)
        {
            mark(cast(void*)&root.proot, cast(void*)(&root.proot + 1));
        }

        // Scan ranges[]
        debug(COLLECT_PRINTF) printf("\tscan ranges[]\n");
        //log++;
        foreach (range; ranges)
        {
            debug(COLLECT_PRINTF) printf("\t\t%p .. %p\n", range.pbot, range.ptop);
            mark(range.pbot, range.ptop);
        }
        //log--;

        debug(COLLECT_PRINTF) printf("\tscan heap\n");
        int nTraversals;
        while (anychanges)
        {
            //import core.stdc.stdio;  printf("nTraversals = %d\n", ++nTraversals);
            for (n = 0; n < npools; n++)
            {
                pool = pooltable[n];
                pool.oldChanges = pool.newChanges;
                pool.newChanges = false;
            }

            debug(COLLECT_PRINTF) printf("\t\tpass\n");
            anychanges = 0;
            for (n = 0; n < npools; n++)
            {
                pool = pooltable[n];
                if(!pool.oldChanges) continue;

                auto shiftBy = pool.shiftBy;
                auto bbase = pool.scan.base();
                auto btop = bbase + pool.scan.nwords;
                //printf("\t\tn = %d, bbase = %p, btop = %p\n", n, bbase, btop);
                for (auto b = bbase; b < btop;)
                {
                    auto bitm = *b;
                    if (!bitm)
                    {   b++;
                        continue;
                    }
                    *b = 0;

                    auto o = pool.baseAddr + (b - bbase) * ((typeof(bitm).sizeof*8) << shiftBy);

                    auto firstset = bsf(bitm);
                    bitm >>= firstset;
                    o += firstset << shiftBy;

                    while(bitm)
                    {
                        auto pn = cast(size_t)(o - pool.baseAddr) / PAGESIZE;
                        auto bin = cast(Bins)pool.pagetable[pn];
                        if (bin < B_PAGE)
                        {
                            mark(o, o + binsize[bin]);
                        }
                        else if (bin == B_PAGE)
                        {
                            auto u = pool.bPageOffsets[pn];
                            mark(o, o + u * PAGESIZE);
                        }

                        bitm >>= 1;
                        auto nbits = bsf(bitm);
                        bitm >>= nbits;
                        o += (nbits + 1) << shiftBy;
                    }
                }
            }
        }

        thread_processGCMarks(&isMarked);
        thread_resumeAll();

        if (GC.config.profile)
        {
            stop = currTime;
            markTime += (stop - start);
            Duration pause = stop - begin;
            if (pause > maxPauseTime)
                maxPauseTime = pause;
            start = stop;
        }

        // Free up everything not marked
        debug(COLLECT_PRINTF) printf("\tfree'ing\n");
        size_t freedpages = 0;
        size_t freed = 0;
        for (n = 0; n < npools; n++)
        {   size_t pn;

            pool = pooltable[n];

            if(pool.isLargeObject)
            {
                for(pn = 0; pn < pool.npages; pn++)
                {
                    Bins bin = cast(Bins)pool.pagetable[pn];
                    if(bin > B_PAGE) continue;
                    size_t biti = pn;

                    if (!pool.mark.test(biti))
                    {   byte *p = pool.baseAddr + pn * PAGESIZE;

                        sentinel_Invariant(sentinel_add(p));
                        if (pool.finals.nbits && pool.finals.testClear(biti))
                            rt_finalize2(sentinel_add(p), false, false);
                        clrBits(pool, biti, ~BlkAttr.NONE ^ BlkAttr.FINALIZE);

                        debug(COLLECT_PRINTF) printf("\tcollecting big %p\n", p);
                        log_free(sentinel_add(p));
                        pool.pagetable[pn] = B_FREE;
                        if(pn < pool.searchStart) pool.searchStart = pn;
                        freedpages++;
                        pool.freepages++;

                        debug (MEMSTOMP) memset(p, 0xF3, PAGESIZE);
                        while (pn + 1 < pool.npages && pool.pagetable[pn + 1] == B_PAGEPLUS)
                        {
                            pn++;
                            pool.pagetable[pn] = B_FREE;

                            // Don't need to update searchStart here because
                            // pn is guaranteed to be greater than last time
                            // we updated it.

                            pool.freepages++;
                            freedpages++;

                            debug (MEMSTOMP)
                            {   p += PAGESIZE;
                                memset(p, 0xF3, PAGESIZE);
                            }
                        }
                    }
                }
            }
            else
            {

                for (pn = 0; pn < pool.npages; pn++)
                {
                    Bins bin = cast(Bins)pool.pagetable[pn];

                    if (bin < B_PAGE)
                    {
                        auto   size = binsize[bin];
                        byte *p = pool.baseAddr + pn * PAGESIZE;
                        byte *ptop = p + PAGESIZE;
                        size_t biti = pn * (PAGESIZE/16);
                        size_t bitstride = size / 16;

                        GCBits.wordtype toClear;
                        size_t clearStart = (biti >> GCBits.BITS_SHIFT) + 1;
                        size_t clearIndex;

                        for (; p < ptop; p += size, biti += bitstride, clearIndex += bitstride)
                        {
                            if(clearIndex > GCBits.BITS_PER_WORD - 1)
                            {
                                if(toClear)
                                {
                                    Gcx.clrBitsSmallSweep(pool, clearStart, toClear);
                                    toClear = 0;
                                }

                                clearStart = (biti >> GCBits.BITS_SHIFT) + 1;
                                clearIndex = biti & GCBits.BITS_MASK;
                            }

                            if (!pool.mark.test(biti))
                            {
                                sentinel_Invariant(sentinel_add(p));

                                pool.freebits.set(biti);
                                if (pool.finals.nbits && pool.finals.test(biti))
                                    rt_finalize2(sentinel_add(p), false, false);
                                toClear |= GCBits.BITS_1 << clearIndex;

                                List *list = cast(List *)p;
                                debug(COLLECT_PRINTF) printf("\tcollecting %p\n", list);
                                log_free(sentinel_add(list));

                                debug (MEMSTOMP) memset(p, 0xF3, size);

                                freed += size;
                            }
                        }

                        if(toClear)
                        {
                            Gcx.clrBitsSmallSweep(pool, clearStart, toClear);
                        }
                    }
                }
            }
        }

        if (GC.config.profile)
        {
            stop = currTime;
            sweepTime += (stop - start);
            start = stop;
        }

        // Zero buckets
        bucket[] = null;

        // Free complete pages, rebuild free list
        debug(COLLECT_PRINTF) printf("\tfree complete pages\n");
        size_t recoveredpages = 0;
        for (n = 0; n < npools; n++)
        {   size_t pn;

            pool = pooltable[n];
            if(pool.isLargeObject) continue;
            for (pn = 0; pn < pool.npages; pn++)
            {
                Bins   bin = cast(Bins)pool.pagetable[pn];
                size_t biti;
                size_t u;

                if (bin < B_PAGE)
                {
                    size_t size = binsize[bin];
                    size_t bitstride = size / 16;
                    size_t bitbase = pn * (PAGESIZE / 16);
                    size_t bittop = bitbase + (PAGESIZE / 16);
                    byte*  p;

                    biti = bitbase;
                    for (biti = bitbase; biti < bittop; biti += bitstride)
                    {   if (!pool.freebits.test(biti))
                            goto Lnotfree;
                    }
                    pool.pagetable[pn] = B_FREE;
                    if(pn < pool.searchStart) pool.searchStart = pn;
                    pool.freepages++;
                    recoveredpages++;
                    continue;

                 Lnotfree:
                    p = pool.baseAddr + pn * PAGESIZE;
                    for (u = 0; u < PAGESIZE; u += size)
                    {   biti = bitbase + u / 16;
                        if (pool.freebits.test(biti))
                        {   List *list;

                            list = cast(List *)(p + u);
                            if (list.next != bucket[bin])       // avoid unnecessary writes
                                list.next = bucket[bin];
                            list.pool = pool;
                            bucket[bin] = list;
                        }
                    }
                }
            }
        }

        if (GC.config.profile)
        {
            stop = currTime;
            recoverTime += (stop - start);
            ++numCollections;
        }

        debug(COLLECT_PRINTF) printf("\trecovered pages = %d\n", recoveredpages);
        debug(COLLECT_PRINTF) printf("\tfree'd %u bytes, %u pages from %u pools\n", freed, freedpages, npools);

        running = 0; // only clear on success

        return freedpages + recoveredpages;
    }

    /**
     * Returns true if the addr lies within a marked block.
     *
     * Warning! This should only be called while the world is stopped inside
     * the fullcollect function.
     */
    int isMarked(void *addr) nothrow
    {
        // first, we find the Pool this block is in, then check to see if the
        // mark bit is clear.
        auto pool = findPool!true(addr);
        if(pool)
        {
            auto offset = cast(size_t)(addr - pool.baseAddr);
            auto pn = offset / PAGESIZE;
            auto bins = cast(Bins)pool.pagetable[pn];
            size_t biti = void;
            if(bins <= B_PAGE)
            {
                biti = (offset & notbinsize[bins]) >> pool.shiftBy;
            }
            else if(bins == B_PAGEPLUS)
            {
                pn -= pool.bPageOffsets[pn];
                biti = pn * (PAGESIZE >> pool.shiftBy);
            }
            else // bins == B_FREE
            {
                assert(bins == B_FREE);
                return IsMarked.no;
            }
            return pool.mark.test(biti) ? IsMarked.yes : IsMarked.no;
        }
        return IsMarked.unknown;
    }


    /**
     *
     */
    uint getBits(Pool* pool, size_t biti) nothrow
    in
    {
        assert(pool);
    }
    body
    {
        uint bits;

        if (pool.finals.nbits &&
            pool.finals.test(biti))
            bits |= BlkAttr.FINALIZE;
        if (pool.noscan.test(biti))
            bits |= BlkAttr.NO_SCAN;
        if (pool.nointerior.nbits && pool.nointerior.test(biti))
            bits |= BlkAttr.NO_INTERIOR;
//        if (pool.nomove.nbits &&
//            pool.nomove.test(biti))
//            bits |= BlkAttr.NO_MOVE;
        if (pool.appendable.test(biti))
            bits |= BlkAttr.APPENDABLE;
        return bits;
    }


    /**
     *
     */
    void setBits(Pool* pool, size_t biti, uint mask) nothrow
    in
    {
        assert(pool);
    }
    body
    {
        // Calculate the mask and bit offset once and then use it to
        // set all of the bits we need to set.
        immutable dataIndex = 1 + (biti >> GCBits.BITS_SHIFT);
        immutable bitOffset = biti & GCBits.BITS_MASK;
        immutable orWith = GCBits.BITS_1 << bitOffset;

        if (mask & BlkAttr.FINALIZE)
        {
            if (!pool.finals.nbits)
                pool.finals.alloc(pool.mark.nbits);
            pool.finals.data[dataIndex] |= orWith;
        }
        if (mask & BlkAttr.NO_SCAN)
        {
            pool.noscan.data[dataIndex] |= orWith;
        }
//        if (mask & BlkAttr.NO_MOVE)
//        {
//            if (!pool.nomove.nbits)
//                pool.nomove.alloc(pool.mark.nbits);
//            pool.nomove.data[dataIndex] |= orWith;
//        }
        if (mask & BlkAttr.APPENDABLE)
        {
            pool.appendable.data[dataIndex] |= orWith;
        }

        if (pool.isLargeObject && (mask & BlkAttr.NO_INTERIOR))
        {
            if(!pool.nointerior.nbits)
                pool.nointerior.alloc(pool.mark.nbits);
            pool.nointerior.data[dataIndex] |= orWith;
        }
    }


    /**
     *
     */
    void clrBits(Pool* pool, size_t biti, uint mask) nothrow
    in
    {
        assert(pool);
    }
    body
    {
        immutable dataIndex =  1 + (biti >> GCBits.BITS_SHIFT);
        immutable bitOffset = biti & GCBits.BITS_MASK;
        immutable keep = ~(GCBits.BITS_1 << bitOffset);

        if (mask & BlkAttr.FINALIZE && pool.finals.nbits)
            pool.finals.data[dataIndex] &= keep;
        if (mask & BlkAttr.NO_SCAN)
            pool.noscan.data[dataIndex] &= keep;
//        if (mask & BlkAttr.NO_MOVE && pool.nomove.nbits)
//            pool.nomove.data[dataIndex] &= keep;
        if (mask & BlkAttr.APPENDABLE)
            pool.appendable.data[dataIndex] &= keep;
        if (pool.nointerior.nbits && (mask & BlkAttr.NO_INTERIOR))
            pool.nointerior.data[dataIndex] &= keep;
    }

    void clrBitsSmallSweep(Pool* pool, size_t dataIndex, GCBits.wordtype toClear) nothrow
    in
    {
        assert(pool);
    }
    body
    {
        immutable toKeep = ~toClear;
        if (pool.finals.nbits)
            pool.finals.data[dataIndex] &= toKeep;

        pool.noscan.data[dataIndex] &= toKeep;

//        if (pool.nomove.nbits)
//            pool.nomove.data[dataIndex] &= toKeep;

        pool.appendable.data[dataIndex] &= toKeep;

        if (pool.nointerior.nbits)
            pool.nointerior.data[dataIndex] &= toKeep;
    }

    /***** Leak Detector ******/


    debug (LOGGING)
    {
        LogArray current;
        LogArray prev;


        void log_init()
        {
            //debug(PRINTF) printf("+log_init()\n");
            current.reserve(1000);
            prev.reserve(1000);
            //debug(PRINTF) printf("-log_init()\n");
        }


        void log_malloc(void *p, size_t size) nothrow
        {
            //debug(PRINTF) printf("+log_malloc(p = %p, size = %zd)\n", p, size);
            Log log;

            log.p = p;
            log.size = size;
            log.line = GC.line;
            log.file = GC.file;
            log.parent = null;

            GC.line = 0;
            GC.file = null;

            current.push(log);
            //debug(PRINTF) printf("-log_malloc()\n");
        }


        void log_free(void *p) nothrow
        {
            //debug(PRINTF) printf("+log_free(%p)\n", p);
            auto i = current.find(p);
            if (i == OPFAIL)
            {
                debug(PRINTF) printf("free'ing unallocated memory %p\n", p);
            }
            else
                current.remove(i);
            //debug(PRINTF) printf("-log_free()\n");
        }


        void log_collect() nothrow
        {
            //debug(PRINTF) printf("+log_collect()\n");
            // Print everything in current that is not in prev

            debug(PRINTF) printf("New pointers this cycle: --------------------------------\n");
            size_t used = 0;
            for (size_t i = 0; i < current.dim; i++)
            {
                auto j = prev.find(current.data[i].p);
                if (j == OPFAIL)
                    current.data[i].print();
                else
                    used++;
            }

            debug(PRINTF) printf("All roots this cycle: --------------------------------\n");
            for (size_t i = 0; i < current.dim; i++)
            {
                void* p = current.data[i].p;
                if (!findPool!true(current.data[i].parent))
                {
                    auto j = prev.find(current.data[i].p);
                    debug(PRINTF) printf(j == OPFAIL ? "N" : " ");
                    current.data[i].print();
                }
            }

            debug(PRINTF) printf("Used = %d-------------------------------------------------\n", used);
            prev.copy(&current);

            debug(PRINTF) printf("-log_collect()\n");
        }


        void log_parent(void *p, void *parent) nothrow
        {
            //debug(PRINTF) printf("+log_parent()\n");
            auto i = current.find(p);
            if (i == OPFAIL)
            {
                debug(PRINTF) printf("parent'ing unallocated memory %p, parent = %p\n", p, parent);
                Pool *pool;
                pool = findPool!true(p);
                assert(pool);
                size_t offset = cast(size_t)(p - pool.baseAddr);
                size_t biti;
                size_t pn = offset / PAGESIZE;
                Bins bin = cast(Bins)pool.pagetable[pn];
                biti = (offset & notbinsize[bin]);
                debug(PRINTF) printf("\tbin = %d, offset = x%x, biti = x%x\n", bin, offset, biti);
            }
            else
            {
                current.data[i].parent = parent;
            }
            //debug(PRINTF) printf("-log_parent()\n");
        }

    }
    else
    {
        void log_init() nothrow { }
        void log_malloc(void *p, size_t size) nothrow { }
        void log_free(void *p) nothrow { }
        void log_collect() nothrow { }
        void log_parent(void *p, void *parent) nothrow { }
    }
}


/* ============================ Pool  =============================== */


struct Pool
{
    byte* baseAddr;
    byte* topAddr;
    GCBits mark;        // entries already scanned, or should not be scanned
    GCBits scan;        // entries that need to be scanned
    GCBits freebits;    // entries that are on the free list
    GCBits finals;      // entries that need finalizer run on them
    GCBits noscan;      // entries that should not be scanned
    GCBits appendable;  // entries that are appendable
    GCBits nointerior;  // interior pointers should be ignored.
                        // Only implemented for large object pools.

    size_t npages;
    size_t freepages;     // The number of pages not in use.
    ubyte* pagetable;

    bool isLargeObject;
    bool oldChanges;  // Whether there were changes on the last mark.
    bool newChanges;  // Whether there were changes on the current mark.

    uint shiftBy;    // shift count for the divisor used for determining bit indices.

    // This tracks how far back we have to go to find the nearest B_PAGE at
    // a smaller address than a B_PAGEPLUS.  To save space, we use a uint.
    // This limits individual allocations to 16 terabytes, assuming a 4k
    // pagesize.
    uint* bPageOffsets;

    // This variable tracks a conservative estimate of where the first free
    // page in this pool is, so that if a lot of pages towards the beginning
    // are occupied, we can bypass them in O(1).
    size_t searchStart;

    void initialize(size_t npages, bool isLargeObject) nothrow
    {
        this.isLargeObject = isLargeObject;
        size_t poolsize;

        shiftBy = isLargeObject ? 12 : 4;

        //debug(PRINTF) printf("Pool::Pool(%u)\n", npages);
        poolsize = npages * PAGESIZE;
        assert(poolsize >= POOLSIZE);
        baseAddr = cast(byte *)os_mem_map(poolsize);

        // Some of the code depends on page alignment of memory pools
        assert((cast(size_t)baseAddr & (PAGESIZE - 1)) == 0);

        if (!baseAddr)
        {
            //debug(PRINTF) printf("GC fail: poolsize = x%zx, errno = %d\n", poolsize, errno);
            //debug(PRINTF) printf("message = '%s'\n", sys_errlist[errno]);

            npages = 0;
            poolsize = 0;
        }
        //assert(baseAddr);
        topAddr = baseAddr + poolsize;
        auto nbits = cast(size_t)poolsize >> shiftBy;

        mark.alloc(nbits);
        scan.alloc(nbits);

        // pagetable already keeps track of what's free for the large object
        // pool.
        if(!isLargeObject)
        {
            freebits.alloc(nbits);
        }

        noscan.alloc(nbits);
        appendable.alloc(nbits);

        pagetable = cast(ubyte*)cstdlib.malloc(npages);
        if (!pagetable)
            onOutOfMemoryError();

        if(isLargeObject)
        {
            bPageOffsets = cast(uint*)cstdlib.malloc(npages * uint.sizeof);
            if (!bPageOffsets)
                onOutOfMemoryError();
        }

        memset(pagetable, B_FREE, npages);

        this.npages = npages;
        this.freepages = npages;
    }


    void Dtor() nothrow
    {
        if (baseAddr)
        {
            int result;

            if (npages)
            {
                result = os_mem_unmap(baseAddr, npages * PAGESIZE);
                assert(result == 0);
                npages = 0;
            }

            baseAddr = null;
            topAddr = null;
        }
        if (pagetable)
        {
            cstdlib.free(pagetable);
            pagetable = null;
        }

        if(bPageOffsets)
            cstdlib.free(bPageOffsets);

        mark.Dtor();
        scan.Dtor();
        if(isLargeObject)
        {
            nointerior.Dtor();
        }
        else
        {
            freebits.Dtor();
        }
        finals.Dtor();
        noscan.Dtor();
        appendable.Dtor();
    }


    void Invariant() const {}


    debug(INVARIANT)
    invariant()
    {
        //mark.Invariant();
        //scan.Invariant();
        //freebits.Invariant();
        //finals.Invariant();
        //noscan.Invariant();
        //appendable.Invariant();
        //nointerior.Invariant();

        if (baseAddr)
        {
            //if (baseAddr + npages * PAGESIZE != topAddr)
                //printf("baseAddr = %p, npages = %d, topAddr = %p\n", baseAddr, npages, topAddr);
            assert(baseAddr + npages * PAGESIZE == topAddr);
        }

        if(pagetable !is null)
        {
            for (size_t i = 0; i < npages; i++)
            {
                Bins bin = cast(Bins)pagetable[i];
                assert(bin < B_MAX);
            }
        }
    }

    void updateOffsets(size_t fromWhere) nothrow
    {
        assert(pagetable[fromWhere] == B_PAGE);
        size_t pn = fromWhere + 1;
        for(uint offset = 1; pn < npages; pn++, offset++)
        {
            if(pagetable[pn] != B_PAGEPLUS) break;
            bPageOffsets[pn] = offset;
        }

        // Store the size of the block in bPageOffsets[fromWhere].
        bPageOffsets[fromWhere] = cast(uint) (pn - fromWhere);
    }

    /**
     * Allocate n pages from Pool.
     * Returns OPFAIL on failure.
     */
    size_t allocPages(size_t n) nothrow
    {
        if(freepages < n) return OPFAIL;
        size_t i;
        size_t n2;

        //debug(PRINTF) printf("Pool::allocPages(n = %d)\n", n);
        n2 = n;
        for (i = searchStart; i < npages; i++)
        {
            if (pagetable[i] == B_FREE)
            {
                if(pagetable[searchStart] < B_FREE)
                {
                    searchStart = i + (!isLargeObject);
                }

                if (--n2 == 0)
                {   //debug(PRINTF) printf("\texisting pn = %d\n", i - n + 1);
                    return i - n + 1;
                }
            }
            else
            {
                n2 = n;
                if(pagetable[i] == B_PAGE)
                {
                    // Then we have the offset information.  We can skip a
                    // whole bunch of stuff.
                    i += bPageOffsets[i] - 1;
                }
            }
        }

        if(pagetable[searchStart] < B_FREE)
        {
            searchStart = npages;
        }

        return OPFAIL;
    }

    /**
     * Free npages pages starting with pagenum.
     */
    void freePages(size_t pagenum, size_t npages) nothrow
    {
        //memset(&pagetable[pagenum], B_FREE, npages);
        if(pagenum < searchStart) searchStart = pagenum;

        for(size_t i = pagenum; i < npages + pagenum; i++)
        {
            if(pagetable[i] < B_FREE)
            {
                freepages++;
            }

            pagetable[i] = B_FREE;
        }
    }

    /**
     * Given a pointer p in the p, return the pagenum.
     */
    size_t pagenumOf(void *p) const nothrow
    in
    {
        assert(p >= baseAddr);
        assert(p < topAddr);
    }
    body
    {
        return cast(size_t)(p - baseAddr) / PAGESIZE;
    }

    /**
     * Get size of pointer p in pool.
     */
    size_t getSize(void *p) const nothrow
    in
    {
        assert(p >= baseAddr);
        assert(p < topAddr);
    }
    body
    {
        size_t pagenum = pagenumOf(p);
        Bins bin = cast(Bins)pagetable[pagenum];
        size_t size = binsize[bin];
        if (bin == B_PAGE)
        {
            size = bPageOffsets[pagenum] * PAGESIZE;
        }
        return size;
    }

    /**
     * Used for sorting pooltable[]
     */
    int opCmp(const Pool *p2) const nothrow
    {
        if (baseAddr < p2.baseAddr)
            return -1;
        else
            return cast(int)(baseAddr > p2.baseAddr);
    }
}


/* ============================ SENTINEL =============================== */


debug (SENTINEL)
{
    const size_t SENTINEL_PRE = cast(size_t) 0xF4F4F4F4F4F4F4F4UL; // 32 or 64 bits
    const ubyte SENTINEL_POST = 0xF5;           // 8 bits
    const uint SENTINEL_EXTRA = 2 * size_t.sizeof + 1;


    inout(size_t*) sentinel_size(inout void *p) nothrow { return &(cast(inout size_t *)p)[-2]; }
    inout(size_t*) sentinel_pre(inout void *p)  nothrow { return &(cast(inout size_t *)p)[-1]; }
    inout(ubyte*) sentinel_post(inout void *p)  nothrow { return &(cast(inout ubyte *)p)[*sentinel_size(p)]; }


    void sentinel_init(void *p, size_t size) nothrow
    {
        *sentinel_size(p) = size;
        *sentinel_pre(p) = SENTINEL_PRE;
        *sentinel_post(p) = SENTINEL_POST;
    }


    void sentinel_Invariant(const void *p) nothrow
    {
        debug
        {
            assert(*sentinel_pre(p) == SENTINEL_PRE);
            assert(*sentinel_post(p) == SENTINEL_POST);
        }
        else if(*sentinel_pre(p) != SENTINEL_PRE || *sentinel_post(p) != SENTINEL_POST)
            onInvalidMemoryOperationError(); // also trigger in release build
    }


    void *sentinel_add(void *p) nothrow
    {
        return p + 2 * size_t.sizeof;
    }


    void *sentinel_sub(void *p) nothrow
    {
        return p - 2 * size_t.sizeof;
    }
}
else
{
    const uint SENTINEL_EXTRA = 0;


    void sentinel_init(void *p, size_t size) nothrow
    {
    }


    void sentinel_Invariant(const void *p) nothrow
    {
    }


    void *sentinel_add(void *p) nothrow
    {
        return p;
    }


    void *sentinel_sub(void *p) nothrow
    {
        return p;
    }
}
