/**
 * Opt-in thread-local garbage collector (`tgc`).
 *
 * Each attached thread owns a private heap arena. Collection scans and sweeps
 * only that thread's stack, TLS, roots/ranges, and blocks — it does not call
 * `thread_suspendAll`. Detached `@nogc` threads are never paused by `tgc`.
 *
 * Cross-thread pointer sharing of GC blocks is unsupported in v1 except via
 * explicit ownership transfer that returns memory through a remote free list.
 * Prefer copy or `immutable` message passing (`std.concurrency`). Partitioned
 * shared regions are planned as Phase 2.
 *
 * Select with `--DRT-gcopt=gc:tgc`. Informal side-name: "realtime GC".
 *
 * Copyright: Copyright dlang-supplemental contributors 2026.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */
module core.internal.gc.impl.tgc.gc;

import core.gc.gcinterface;

import core.internal.container.array;
import core.internal.spinlock;

import core.thread.threadbase : ThreadBase;

import cstdlib = core.stdc.stdlib : calloc, free, malloc, realloc;
import core.stdc.string : memcpy, memset;
static import core.memory;

extern (C) noreturn onOutOfMemoryError(void* pretend_sideffect = null, string file = __FILE__, size_t line = __LINE__) @trusted pure nothrow @nogc; /* dmd @@@BUG11461@@@ */
extern (C) void rt_finalizeFromGC(void* p, size_t size, uint attr, const TypeInfo typeInfo) nothrow;
extern (C) void* thread_stackTop() nothrow @nogc;
extern (C) void* thread_stackBottom() nothrow @nogc;

private enum size_t headerAlign = (void*).sizeof;
private enum size_t collectThresholdInit = 256 * 1024;

private struct BlkHeader
{
    size_t size;       /// user-visible allocation size
    uint attr;
    uint marked;       /// non-zero when marked during collect
    ThreadHeap* heap;  /// owning thread heap
    BlkHeader* next;   /// intrusive list in owner heap
    BlkHeader* prev;
}

private struct ThreadHeap
{
    BlkHeader* head;
    size_t usedBytes;
    size_t allocatedTotal; /// bytes allocated on this thread since start
    size_t collectThreshold = collectThresholdInit;
    size_t numCollections;

    // Remote frees pushed by other threads (ownership transfer).
    void** remotePtrs;
    size_t remoteLen;
    size_t remoteCap;
    SpinLock remoteLock;

    bool collecting;

    static ThreadHeap* create() nothrow @nogc
    {
        auto h = cast(ThreadHeap*) cstdlib.calloc(1, ThreadHeap.sizeof);
        if (!h)
            onOutOfMemoryError();
        h.collectThreshold = collectThresholdInit;
        h.remoteLock = SpinLock(SpinLock.Contention.brief);
        return h;
    }

    void pushRemote(void* p) nothrow @nogc
    {
        remoteLock.lock();
        if (remoteLen == remoteCap)
        {
            size_t ncap = remoteCap ? remoteCap * 2 : 16;
            auto np = cast(void**) cstdlib.realloc(remotePtrs, ncap * (void*).sizeof);
            if (!np)
            {
                remoteLock.unlock();
                onOutOfMemoryError();
            }
            remotePtrs = np;
            remoteCap = ncap;
        }
        remotePtrs[remoteLen++] = p;
        remoteLock.unlock();
    }

    void drainRemote() nothrow @nogc
    {
        remoteLock.lock();
        size_t n = remoteLen;
        void** ptrs = remotePtrs;
        remoteLen = 0;
        remoteLock.unlock();

        foreach (i; 0 .. n)
        {
            auto p = ptrs[i];
            if (!p)
                continue;
            auto h = headerOf(p);
            if (h && h.heap is &this)
                unlinkAndFree(h);
        }
    }

    void link(BlkHeader* h) nothrow @nogc
    {
        h.prev = null;
        h.next = head;
        if (head)
            head.prev = h;
        head = h;
        usedBytes += h.size;
    }

    void unlink(BlkHeader* h) nothrow @nogc
    {
        if (h.prev)
            h.prev.next = h.next;
        else
            head = h.next;
        if (h.next)
            h.next.prev = h.prev;
        if (usedBytes >= h.size)
            usedBytes -= h.size;
        else
            usedBytes = 0;
    }

    void unlinkAndFree(BlkHeader* h) nothrow @nogc
    {
        unlink(h);
        // GC.free does not run finalizers; call destroy() first if needed.
        cstdlib.free(h);
    }

    void unlinkAndFreeFinalize(BlkHeader* h) nothrow
    {
        unlink(h);
        if (h.attr & BlkAttr.FINALIZE)
            rt_finalizeFromGC(h + 1, h.size, h.attr, null);
        cstdlib.free(h);
    }

    static BlkHeader* headerOf(void* p) nothrow @nogc
    {
        if (!p)
            return null;
        return cast(BlkHeader*) p - 1;
    }

    BlkHeader* findBlock(void* p) nothrow @nogc
    {
        if (!p)
            return null;
        for (auto h = head; h; h = h.next)
        {
            void* base = h + 1;
            void* end = base + h.size;
            if (p >= base && p < end)
                return h;
        }
        return null;
    }
}

// TLS pointer to the calling thread's heap
private static ThreadHeap* tlsHeap;

private __gshared ThreadHeap*[] allHeaps;
private __gshared size_t allHeapsLen;
private __gshared size_t allHeapsCap;
private __gshared SpinLock heapsLock;

private void registerHeap(ThreadHeap* h) nothrow @nogc
{
    heapsLock.lock();
    if (allHeapsLen == allHeapsCap)
    {
        size_t ncap = allHeapsCap ? allHeapsCap * 2 : 8;
        auto np = cast(ThreadHeap**) cstdlib.realloc(allHeaps.ptr, ncap * (ThreadHeap*).sizeof);
        if (!np)
        {
            heapsLock.unlock();
            onOutOfMemoryError();
        }
        allHeaps = np[0 .. ncap];
        allHeapsCap = ncap;
    }
    allHeaps[allHeapsLen++] = h;
    heapsLock.unlock();
}

private void unregisterHeap(ThreadHeap* h) nothrow @nogc
{
    heapsLock.lock();
    foreach (i; 0 .. allHeapsLen)
    {
        if (allHeaps[i] is h)
        {
            allHeaps[i] = allHeaps[allHeapsLen - 1];
            allHeapsLen--;
            break;
        }
    }
    heapsLock.unlock();
}

private ThreadHeap* currentHeap() nothrow @nogc
{
    if (tlsHeap)
        return tlsHeap;
    tlsHeap = ThreadHeap.create();
    registerHeap(tlsHeap);
    auto t = ThreadBase.getThis();
    if (t !is null)
        t.tlsGCData() = tlsHeap;
    return tlsHeap;
}

// register GC in C constructor
private pragma(crt_constructor) void gc_tgc_ctor()
{
    heapsLock = SpinLock(SpinLock.Contention.brief);
    _d_register_tgc_gc();
}

extern (C) void _d_register_tgc_gc()
{
    import core.gc.registry;
    registerGCFactory("tgc", &initialize, &threadInitHook);
}

private void threadInitHook(ThreadBase base) nothrow @nogc
{
    // Called before the thread is fully registered; ensure a heap exists.
    if (tlsHeap is null)
    {
        tlsHeap = ThreadHeap.create();
        registerHeap(tlsHeap);
    }
    base.tlsGCData() = tlsHeap;
}

private GC initialize()
{
    import core.lifetime : emplace;

    auto gc = cast(ThreadGC) cstdlib.malloc(__traits(classInstanceSize, ThreadGC));
    if (!gc)
        onOutOfMemoryError();

    return emplace(gc);
}

/**
 * Thread-local GC implementation.
 *
 * Also known informally as a "realtime GC" because collection does not
 * globally stop-the-world; the name registered with the runtime is `tgc`.
 */
class ThreadGC : GC
{
    Array!Root roots;
    Array!Range ranges;
    SpinLock rootsLock;
    bool disabled;
    size_t profileCollections;
    ulong profilePauseTicks;

    this()
    {
        rootsLock = SpinLock(SpinLock.Contention.brief);
        // Ensure the initializing thread has a heap.
        cast(void) currentHeap();
    }

    ~this()
    {
    }

    void enable()
    {
        disabled = false;
    }

    void disable()
    {
        disabled = true;
    }

    void collect() nothrow
    {
        collectHeap(currentHeap());
    }

    void minimize() nothrow
    {
        auto h = currentHeap();
        h.drainRemote();
    }

    uint getAttr(void* p) nothrow
    {
        auto blk = queryBlock(p);
        return blk ? blk.attr : 0;
    }

    uint setAttr(void* p, uint mask) nothrow
    {
        auto blk = queryBlock(p);
        if (!blk)
            return 0;
        blk.attr |= mask;
        return blk.attr;
    }

    uint clrAttr(void* p, uint mask) nothrow
    {
        auto blk = queryBlock(p);
        if (!blk)
            return 0;
        blk.attr &= ~mask;
        return blk.attr;
    }

    void* malloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        return alloc(size, bits, false);
    }

    BlkInfo qalloc(size_t size, uint bits, const scope TypeInfo ti) nothrow
    {
        BlkInfo retval;
        retval.base = alloc(size, bits, false);
        retval.size = size;
        retval.attr = bits;
        return retval;
    }

    void* calloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        return alloc(size, bits, true);
    }

    void* realloc(void* p, size_t size, uint bits, const TypeInfo ti) nothrow
    {
        if (!p)
            return alloc(size, bits, false);
        if (!size)
        {
            free(p);
            return null;
        }

        auto blk = queryBlock(p);
        if (!blk)
        {
            // Unknown pointer — allocate fresh
            return alloc(size, bits, false);
        }

        auto heap = blk.heap;
        if (heap !is currentHeap())
        {
            // Cannot realloc foreign block in place; copy into local heap.
            auto np = alloc(size, bits ? bits : blk.attr, false);
            auto n = size < blk.size ? size : blk.size;
            memcpy(np, p, n);
            free(p);
            return np;
        }

        if (size <= blk.size)
        {
            blk.size = size;
            if (bits)
                blk.attr = bits;
            return p;
        }

        auto np = alloc(size, bits ? bits : blk.attr, false);
        memcpy(np, p, blk.size);
        heap.unlinkAndFree(blk);
        return np;
    }

    size_t extend(void* p, size_t minsize, size_t maxsize, const TypeInfo ti) nothrow
    {
        return 0;
    }

    size_t reserve(size_t size) nothrow
    {
        return 0;
    }

    void free(void* p) nothrow @nogc
    {
        if (!p)
            return;
        auto blk = queryBlock(p);
        if (!blk)
            return;
        auto owner = blk.heap;
        auto local = tlsHeap;
        if (owner is local || local is null)
        {
            if (owner)
                owner.unlinkAndFree(blk);
            return;
        }
        // Cross-thread free: queue for owning thread (ownership transfer).
        owner.pushRemote(p);
    }

    void* addrOf(void* p) nothrow @nogc
    {
        auto blk = queryBlock(p);
        return blk ? cast(void*)(blk + 1) : null;
    }

    size_t sizeOf(void* p) nothrow @nogc
    {
        auto blk = queryBlock(p);
        return blk ? blk.size : 0;
    }

    BlkInfo query(void* p) nothrow
    {
        auto blk = queryBlock(p);
        if (!blk)
            return BlkInfo.init;
        BlkInfo info;
        info.base = cast(void*)(blk + 1);
        info.size = blk.size;
        info.attr = blk.attr;
        return info;
    }

    core.memory.GC.Stats stats() @trusted nothrow
    {
        core.memory.GC.Stats s;
        auto h = currentHeap();
        s.usedSize = h.usedBytes;
        s.freeSize = 0;
        s.allocatedInCurrentThread = h.allocatedTotal;
        return s;
    }

    core.memory.GC.ProfileStats profileStats() @trusted nothrow
    {
        core.memory.GC.ProfileStats s;
        s.numCollections = profileCollections;
        return s;
    }

    void addRoot(void* p) nothrow @nogc
    {
        rootsLock.lock();
        roots.insertBack(Root(p));
        rootsLock.unlock();
    }

    void removeRoot(void* p) nothrow @nogc
    {
        rootsLock.lock();
        foreach (ref r; roots)
        {
            if (r is p)
            {
                r = roots.back;
                roots.popBack();
                rootsLock.unlock();
                return;
            }
        }
        rootsLock.unlock();
        assert(false);
    }

    @property RootIterator rootIter() return @nogc
    {
        return &rootsApply;
    }

    private int rootsApply(scope int delegate(ref Root) nothrow dg)
    {
        rootsLock.lock();
        foreach (ref r; roots)
        {
            if (auto result = dg(r))
            {
                rootsLock.unlock();
                return result;
            }
        }
        rootsLock.unlock();
        return 0;
    }

    void addRange(void* p, size_t sz, const TypeInfo ti = null) nothrow @nogc
    {
        rootsLock.lock();
        ranges.insertBack(Range(p, p + sz, cast() ti));
        rootsLock.unlock();
    }

    void removeRange(void* p) nothrow @nogc
    {
        rootsLock.lock();
        foreach (ref r; ranges)
        {
            if (r.pbot is p)
            {
                r = ranges.back;
                ranges.popBack();
                rootsLock.unlock();
                return;
            }
        }
        rootsLock.unlock();
        assert(false);
    }

    @property RangeIterator rangeIter() return @nogc
    {
        return &rangesApply;
    }

    private int rangesApply(scope int delegate(ref Range) nothrow dg)
    {
        rootsLock.lock();
        foreach (ref r; ranges)
        {
            if (auto result = dg(r))
            {
                rootsLock.unlock();
                return result;
            }
        }
        rootsLock.unlock();
        return 0;
    }

    void runFinalizers(const scope void[] segment) nothrow
    {
    }

    bool inFinalizer() nothrow
    {
        auto h = tlsHeap;
        return h !is null && h.collecting;
    }

    ulong allocatedInCurrentThread() nothrow
    {
        return currentHeap().allocatedTotal;
    }

    void[] getArrayUsed(void* ptr, bool atomic = false) nothrow
    {
        return null;
    }

    bool expandArrayUsed(void[] slice, size_t newUsed, bool atomic = false) nothrow @safe
    {
        return false;
    }

    size_t reserveArrayCapacity(void[] slice, size_t request, bool atomic = false) nothrow @safe
    {
        return 0;
    }

    bool shrinkArrayUsed(void[] slice, size_t existingUsed, bool atomic = false) nothrow
    {
        return false;
    }

    void initThread(ThreadBase t) nothrow @nogc
    {
        if (tlsHeap is null)
        {
            tlsHeap = ThreadHeap.create();
            registerHeap(tlsHeap);
        }
        t.tlsGCData() = tlsHeap;
    }

    void cleanupThread(ThreadBase t) nothrow @nogc
    {
        auto h = cast(ThreadHeap*) t.tlsGCData();
        if (!h)
            return;
        // Free remaining blocks; do not leave memory owned by a dead thread.
        h.drainRemote();
        auto cur = h.head;
        while (cur)
        {
            auto n = cur.next;
            h.unlinkAndFree(cur);
            cur = n;
        }
        h.head = null;
        unregisterHeap(h);
        if (tlsHeap is h)
            tlsHeap = null;
        t.tlsGCData() = null;
        cstdlib.free(h.remotePtrs);
        cstdlib.free(h);
    }

private:

    BlkHeader* queryBlock(void* p) nothrow @nogc
    {
        if (!p)
            return null;
        // Fast path: local heap
        if (tlsHeap)
        {
            if (auto b = tlsHeap.findBlock(p))
                return b;
        }
        // Slow path: search registered heaps (for free/query of foreign ptrs)
        heapsLock.lock();
        foreach (i; 0 .. allHeapsLen)
        {
            if (auto b = allHeaps[i].findBlock(p))
            {
                heapsLock.unlock();
                return b;
            }
        }
        heapsLock.unlock();
        return null;
    }

    void* alloc(size_t size, uint bits, bool zero) nothrow
    {
        auto heap = currentHeap();
        heap.drainRemote();

        if (!disabled && heap.usedBytes >= heap.collectThreshold)
            collectHeap(heap);

        size_t total = BlkHeader.sizeof + size;
        // Align user payload
        auto raw = zero ? cstdlib.calloc(1, total) : cstdlib.malloc(total);
        if (size && raw is null)
            onOutOfMemoryError();
        if (!zero)
            memset(raw, 0, BlkHeader.sizeof);

        auto h = cast(BlkHeader*) raw;
        h.size = size;
        h.attr = bits;
        h.marked = 0;
        h.heap = heap;
        h.next = null;
        h.prev = null;
        heap.link(h);
        heap.allocatedTotal += size;

        if (heap.usedBytes > heap.collectThreshold)
            heap.collectThreshold = heap.usedBytes * 2;

        return cast(void*)(h + 1);
    }

    void collectHeap(ThreadHeap* heap) nothrow
    {
        if (!heap || heap.collecting || disabled)
            return;

        heap.collecting = true;
        heap.drainRemote();

        // Clear marks
        for (auto b = heap.head; b; b = b.next)
            b.marked = 0;

        // Mark from stack (current thread only — no STW)
        void* top;
        void* bot;
        tryStackBounds(top, bot);
        if (top && bot)
        {
            if (top > bot)
            {
                auto tmp = top;
                top = bot;
                bot = tmp;
            }
            markRange(heap, top, bot);
        }

        // Mark from TLS of this thread
        markTLS(heap);

        // Mark from global roots/ranges
        rootsLock.lock();
        foreach (ref r; roots)
        {
            if (r.proot)
                markPtr(heap, *cast(void**) r.proot);
            markPtr(heap, r.proot);
        }
        foreach (ref r; ranges)
            markRange(heap, r.pbot, r.ptop);
        rootsLock.unlock();

        // Fixpoint: scan marked blocks for interior pointers (conservative)
        size_t markedCount = 0;
        for (auto b = heap.head; b; b = b.next)
            if (b.marked)
                markedCount++;
        size_t prevMarked = size_t.max;
        while (prevMarked != markedCount)
        {
            prevMarked = markedCount;
            for (auto b = heap.head; b; b = b.next)
            {
                if (!b.marked || (b.attr & BlkAttr.NO_SCAN))
                    continue;
                void* base = b + 1;
                markRange(heap, base, base + b.size);
            }
            markedCount = 0;
            for (auto b = heap.head; b; b = b.next)
                if (b.marked)
                    markedCount++;
        }

        // Sweep unmarked
        auto b = heap.head;
        while (b)
        {
            auto next = b.next;
            if (!b.marked)
                heap.unlinkAndFreeFinalize(b);
            b = next;
        }

        heap.numCollections++;
        profileCollections++;
        heap.collecting = false;
    }

    void tryStackBounds(ref void* top, ref void* bot) nothrow
    {
        top = null;
        bot = null;
        if (ThreadBase.getThis() is null)
        {
            // Without attachment, approximate with a local and a small window.
            void* approx;
            top = &approx;
            bot = cast(void*)(&approx) + 4096;
            return;
        }
        top = thread_stackTop();
        bot = thread_stackBottom();
    }

    void markTLS(ThreadHeap* heap) nothrow
    {
        import rt.sections;
        auto rng = initTLSRanges();
        scanTLSRanges(rng, (void* pbeg, void* pend) nothrow {
            markRange(heap, pbeg, pend);
        });
    }

    void markRange(ThreadHeap* heap, void* pbot, void* ptop) nothrow
    {
        if (!pbot || !ptop || pbot >= ptop)
            return;
        auto p = cast(void**) pbot;
        auto e = cast(void**) ptop;
        // Align
        auto addr = cast(size_t) p;
        addr = (addr + (void*).sizeof - 1) & ~((void*).sizeof - 1);
        p = cast(void**) addr;
        for (; p + 1 <= e; ++p)
            markPtr(heap, *p);
    }

    void markPtr(ThreadHeap* heap, void* p) nothrow
    {
        if (!p)
            return;
        auto b = heap.findBlock(p);
        if (b)
            b.marked = 1;
    }
}
