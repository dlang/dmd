/**
 * Opt-in thread-local garbage collector (`tgc`) — **0.2.0 prototype**.
 *
 * Target design: per-thread private heaps plus partitioned shared regions
 * (many-to-many). Collecting a region pauses only threads attached to that
 * region. See dlang-supplemental design notes for the full architecture.
 *
 * **0.1.0:** private per-thread heaps, local collect, remote-free queue.
 * **0.1.1:** shared-region API scaffold.
 * **0.2.0:** region collect (selective suspend), heap locks, array append metadata.
 * **0.2.x:** sorted-index findBlock O(log n), 32-byte header, bounded fixpoint mark.
 *
 * Cross-thread sharing on private heaps via remote free is interim, not the
 * target model. Prefer attaching workers to a shared region.
 *
 * Select with `--DRT-gcopt=gc:tgc`. Informal side-name: "realtime GC".
 *
 * Copyright: Copyright dlang-supplemental contributors 2026.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */
module core.internal.gc.impl.tgc.gc;

/// Semantic version of the `tgc` prototype (not druntime release version).
enum tgcVersion = "0.2.1";

import core.gc.gcinterface;

import core.internal.container.array;
import core.internal.spinlock;

import core.thread.threadbase : ThreadBase, ScanAllThreadsFn, thread_scanList;

extern (C) void thread_suspendList(ThreadBase*, size_t) nothrow;
extern (C) void thread_resumeList(ThreadBase*, size_t) nothrow;

/// Shared-region backend selection (0.3.0 SymGC hybrid uses `symgc` when enabled).
enum TgcSharedBackend : ubyte { tgcNative, symgc }
private __gshared TgcSharedBackend tgcSharedBackend = TgcSharedBackend.tgcNative;

import cstdlib = core.stdc.stdlib : calloc, free, malloc, realloc;
import core.stdc.string : memcpy, memset;
static import core.memory;

extern (C) noreturn onOutOfMemoryError(void* pretend_sideffect = null, string file = __FILE__, size_t line = __LINE__) @trusted pure nothrow @nogc; /* dmd @@@BUG11461@@@ */
extern (C) void rt_finalizeFromGC(void* p, size_t size, uint attr, const TypeInfo typeInfo) nothrow;
extern (C) void* thread_stackTop() nothrow @nogc;
extern (C) void* thread_stackBottom() nothrow @nogc;

private enum size_t headerAlign = (void*).sizeof;
private enum size_t collectThresholdInit = 256 * 1024;

/// Per-block metadata placed immediately before user payload.
/// 32 bytes on 64-bit (was 48 with intrusive list links).
private struct BlkHeader
{
    size_t size;       /// user-visible capacity (alloc size)
    size_t arrayUsed;  /// used bytes when BlkAttr.APPENDABLE (else 0)
    uint attr;         /// BlkAttr bits (user-visible)
    uint marked;       /// non-zero when marked during collect
    ThreadHeap* heap;  /// owning heap
}

private struct ThreadHeap
{
    /// Address-sorted block index (by payload base). Replaces O(n) list walk.
    BlkHeader** blocks;
    size_t blockLen;
    size_t blockCap;

    size_t usedBytes;
    size_t allocatedTotal; /// bytes allocated on this thread since start
    size_t collectThreshold = collectThresholdInit;
    size_t numCollections;

    // Remote frees pushed by other threads (ownership transfer). Implemented.
    void** remotePtrs;
    size_t remoteLen;
    size_t remoteCap;
    SpinLock remoteLock;

    bool collecting;
    SpinLock listLock;
    ThreadBase owner;

    static ThreadHeap* create() nothrow @nogc
    {
        auto h = cast(ThreadHeap*) cstdlib.calloc(1, ThreadHeap.sizeof);
        if (!h)
            onOutOfMemoryError();
        h.collectThreshold = collectThresholdInit;
        h.remoteLock = SpinLock(SpinLock.Contention.brief);
        h.listLock = SpinLock(SpinLock.Contention.brief);
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

    /// Insert `h` into the address-sorted index. Caller holds listLock or is sole owner.
    void indexInsert(BlkHeader* h) nothrow @nogc
    {
        if (blockLen == blockCap)
        {
            size_t ncap = blockCap ? blockCap * 2 : 8;
            auto np = cast(BlkHeader**) cstdlib.realloc(blocks, ncap * (BlkHeader*).sizeof);
            if (!np)
                onOutOfMemoryError();
            blocks = np;
            blockCap = ncap;
        }
        void* base = h + 1;
        // Find first index with payload base >= base (insertion point).
        size_t lo = 0, hi = blockLen;
        while (lo < hi)
        {
            size_t mid = lo + (hi - lo) / 2;
            if (cast(void*)(blocks[mid] + 1) < base)
                lo = mid + 1;
            else
                hi = mid;
        }
        // Shift right from lo.
        for (size_t i = blockLen; i > lo; --i)
            blocks[i] = blocks[i - 1];
        blocks[lo] = h;
        blockLen++;
        usedBytes += h.size;
    }

    /// Remove `h` from the address-sorted index. Caller holds listLock.
    void indexRemove(BlkHeader* h) nothrow @nogc
    {
        void* base = h + 1;
        size_t lo = 0, hi = blockLen;
        while (lo < hi)
        {
            size_t mid = lo + (hi - lo) / 2;
            auto mb = cast(void*)(blocks[mid] + 1);
            if (mb < base)
                lo = mid + 1;
            else if (mb > base)
                hi = mid;
            else
            {
                for (size_t i = mid; i + 1 < blockLen; ++i)
                    blocks[i] = blocks[i + 1];
                blockLen--;
                if (usedBytes >= h.size)
                    usedBytes -= h.size;
                else
                    usedBytes = 0;
                return;
            }
        }
    }

    void link(BlkHeader* h) nothrow @nogc
    {
        listLock.lock();
        indexInsert(h);
        listLock.unlock();
    }

    void unlink(BlkHeader* h) nothrow @nogc
    {
        listLock.lock();
        indexRemove(h);
        listLock.unlock();
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

    /// O(log n) interior-pointer lookup via sorted payload bases.
    BlkHeader* findBlock(void* p) nothrow @nogc
    {
        if (!p)
            return null;
        listLock.lock();
        scope (exit) listLock.unlock();
        if (!blockLen)
            return null;
        // Find rightmost block with payload base <= p.
        size_t lo = 0, hi = blockLen;
        while (lo < hi)
        {
            size_t mid = lo + (hi - lo) / 2;
            if (cast(void*)(blocks[mid] + 1) <= p)
                lo = mid + 1;
            else
                hi = mid;
        }
        if (lo == 0)
            return null;
        auto h = blocks[lo - 1];
        void* base = h + 1;
        if (p >= base && p < base + h.size)
            return h;
        return null;
    }
}

/**
 * Partitioned shared region heap (target cross-thread model).
 *
 * Threads attach explicitly; collecting this region must pause only members
 * (selective suspend not implemented in 0.1.0).
 */
private struct SharedRegion
{
    uint id;
    ThreadHeap* heap;
    ThreadHeap** memberHeaps;
    ThreadBase* memberThreads;
    size_t memberLen;
    size_t memberCap;
    SpinLock lock;

    static SharedRegion* create(uint id) nothrow @nogc
    {
        auto r = cast(SharedRegion*) cstdlib.calloc(1, SharedRegion.sizeof);
        if (!r)
            onOutOfMemoryError();
        r.id = id;
        r.heap = ThreadHeap.create();
        r.lock = SpinLock(SpinLock.Contention.brief);
        if (tgcSharedBackend == TgcSharedBackend.symgc)
        {
            import core.stdc.stdio : fprintf, stderr;
            fprintf(stderr, "tgc: tgcShared:symgc requested; using native shared-region backend (0.3.0)\n".ptr);
        }
        return r;
    }

    bool isAttached(ThreadHeap* h) nothrow @nogc
    {
        foreach (i; 0 .. memberLen)
            if (memberHeaps[i] is h)
                return true;
        return false;
    }

    bool isAttachedThread(ThreadBase tb) nothrow @nogc
    {
        if (!tb)
            return false;
        foreach (i; 0 .. memberLen)
            if (memberThreads[i] is tb)
                return true;
        return false;
    }

    bool attachThread(ThreadBase tb) nothrow @nogc
    {
        if (!tb)
            return false;
        auto h = currentHeap();
        if (!h)
            return false;
        lock.lock();
        if (isAttached(h))
        {
            lock.unlock();
            return true;
        }
        if (memberLen == memberCap)
        {
            size_t ncap = memberCap ? memberCap * 2 : 4;
            auto hp = cast(ThreadHeap**) cstdlib.realloc(memberHeaps, ncap * (ThreadHeap*).sizeof);
            auto tp = cast(ThreadBase*) cstdlib.realloc(memberThreads, ncap * ThreadBase.sizeof);
            if (!hp || !tp)
            {
                lock.unlock();
                onOutOfMemoryError();
            }
            memberHeaps = hp;
            memberThreads = tp;
            memberCap = ncap;
        }
        memberHeaps[memberLen] = h;
        memberThreads[memberLen] = tb;
        memberLen++;
        lock.unlock();
        return true;
    }

    bool detachThread(ThreadBase tb) nothrow @nogc
    {
        if (!tb)
            return false;
        auto h = currentHeap();
        if (!h)
            return false;
        lock.lock();
        foreach (i; 0 .. memberLen)
        {
            if (memberHeaps[i] is h)
            {
                memberHeaps[i] = memberHeaps[memberLen - 1];
                memberThreads[i] = memberThreads[memberLen - 1];
                memberLen--;
                lock.unlock();
                return true;
            }
        }
        lock.unlock();
        return false;
    }

    void collectRegion() nothrow
    {
        if (!heap || heap.collecting)
            return;
        auto gc = cast(ThreadGC) tgcInstance;
        if (!gc)
            return;

        heap.collecting = true;
        heap.drainRemote();

        heap.listLock.lock();
        foreach (i; 0 .. heap.blockLen)
            heap.blocks[i].marked = 0;
        heap.listLock.unlock();

        ThreadBase* tlist = null;
        size_t n = 0;
        lock.lock();
        n = memberLen;
        if (n)
        {
            tlist = cast(ThreadBase*) cstdlib.malloc(n * ThreadBase.sizeof);
            if (!tlist)
            {
                lock.unlock();
                onOutOfMemoryError();
            }
            memcpy(tlist, memberThreads, n * ThreadBase.sizeof);
        }
        lock.unlock();

        if (n)
        {
            thread_suspendList(tlist, n);
            thread_scanList(tlist, n, (void* p1, void* p2) nothrow {
                gc.markRangeHeap(heap, p1, p2);
            });
            thread_resumeList(tlist, n);
            cstdlib.free(tlist);
        }

        gc.rootsLock.lock();
        foreach (ref r; gc.roots)
        {
            if (r.proot)
                gc.markPtrHeap(heap, *cast(void**) r.proot);
            gc.markPtrHeap(heap, r.proot);
        }
        foreach (ref r; gc.ranges)
            gc.markRangeHeap(heap, r.pbot, r.ptop);
        gc.rootsLock.unlock();

        if (gc.markHeapFixpoint(heap))
            gc.sweepHeap(heap);
        // If fixpoint did not converge, skip sweep (leak until next collect) rather
        // than free possibly-reachable blocks.
        heap.numCollections++;
        gc.profileCollections++;
        heap.collecting = false;
    }
}

private __gshared SharedRegion** allRegions;
private __gshared size_t allRegionsLen;
private __gshared size_t allRegionsCap;
private __gshared uint nextRegionId = 1;
private __gshared SpinLock regionsLock;
private __gshared GC tgcInstance;

private SharedRegion* findRegion(uint id) nothrow @nogc
{
    regionsLock.lock();
    foreach (i; 0 .. allRegionsLen)
    {
        auto r = allRegions[i];
        if (r && r.id == id)
        {
            regionsLock.unlock();
            return r;
        }
    }
    regionsLock.unlock();
    return null;
}

/// Create a partitioned shared region; returns region id (0 on failure).
extern (C) uint _d_tgc_region_create() nothrow @nogc
{
    regionsLock.lock();
    uint id = nextRegionId++;
    auto r = SharedRegion.create(id);
    if (allRegionsLen == allRegionsCap)
    {
        size_t ncap = allRegionsCap ? allRegionsCap * 2 : 4;
        auto np = cast(SharedRegion**) cstdlib.realloc(allRegions, ncap * (SharedRegion*).sizeof);
        if (!np)
        {
            regionsLock.unlock();
            onOutOfMemoryError();
        }
        allRegions = np;
        allRegionsCap = ncap;
    }
    allRegions[allRegionsLen++] = r;
    regionsLock.unlock();
    return id;
}

/// Attach the calling thread's private heap to `regionId`.
extern (C) bool _d_tgc_region_attach(uint regionId) nothrow @nogc
{
    auto r = findRegion(regionId);
    if (!r)
        return false;
    auto tb = ThreadBase.getThis();
    if (!tb)
        return false;
    return r.attachThread(tb);
}

/// Detach the calling thread from `regionId`.
extern (C) bool _d_tgc_region_detach(uint regionId) nothrow @nogc
{
    auto r = findRegion(regionId);
    if (!r)
        return false;
    auto tb = ThreadBase.getThis();
    if (!tb)
        return false;
    return r.detachThread(tb);
}

/// Collect a shared region (pauses only attached threads).
extern (C) bool _d_tgc_region_collect(uint regionId) nothrow
{
    auto r = findRegion(regionId);
    if (!r)
        return false;
    r.collectRegion();
    return true;
}

/// Allocate in a shared region (attached threads only). Returns null if unknown region or not attached.
extern (C) void* _d_tgc_region_malloc(uint regionId, size_t size, uint bits) nothrow @nogc
{
    auto r = findRegion(regionId);
    if (!r)
        return null;
    auto tb = ThreadBase.getThis();
    r.lock.lock();
    if (!r.isAttachedThread(tb))
    {
        r.lock.unlock();
        return null;
    }
    r.lock.unlock();

    r.heap.drainRemote();
    size_t total = BlkHeader.sizeof + size;
    auto raw = cstdlib.malloc(total);
    if (size && raw is null)
        onOutOfMemoryError();
    memset(raw, 0, BlkHeader.sizeof);
    auto h = cast(BlkHeader*) raw;
    h.size = size;
    h.attr = bits;
    h.marked = 0;
    h.heap = r.heap;
    r.heap.link(h);
    r.heap.allocatedTotal += size;
    return cast(void*)(h + 1);
}

extern (C) const(char)* _d_tgc_version() nothrow @nogc
{
    return tgcVersion.ptr;
}

// TLS pointer to the calling thread's heap
// TLS pointer to the calling thread's heap
private ThreadHeap* tlsHeap;

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

private bool isRegisteredHeap(ThreadHeap* h) nothrow @nogc
{
    if (!h)
        return false;
    heapsLock.lock();
    foreach (i; 0 .. allHeapsLen)
    {
        if (allHeaps[i] is h)
        {
            heapsLock.unlock();
            return true;
        }
    }
    heapsLock.unlock();
    return false;
}

private ThreadHeap* currentHeap() nothrow @nogc
{
    if (tlsHeap && isRegisteredHeap(tlsHeap))
        return tlsHeap;
    auto t = ThreadBase.getThis();
    if (t)
    {
        auto existing = cast(ThreadHeap*) t.tlsGCData();
        if (isRegisteredHeap(existing))
        {
            tlsHeap = existing;
            return tlsHeap;
        }
    }
    tlsHeap = ThreadHeap.create();
    registerHeap(tlsHeap);
    if (t)
        t.tlsGCData() = tlsHeap;
    return tlsHeap;
}

// register GC in C constructor
private pragma(crt_constructor) void gc_tgc_ctor()
{
    heapsLock = SpinLock(SpinLock.Contention.brief);
    regionsLock = SpinLock(SpinLock.Contention.brief);
    _d_register_tgc_gc();
}

extern (C) void _d_register_tgc_gc()
{
    import core.gc.registry;
    registerGCFactory("tgc", &initialize, &threadInitHook);
}

private void threadInitHook(ThreadBase base) nothrow @nogc
{
    auto h = cast(ThreadHeap*) base.tlsGCData();
    if (!isRegisteredHeap(h))
    {
        h = ThreadHeap.create();
        registerHeap(h);
    }
    tlsHeap = h;
    base.tlsGCData() = h;
}

private bool isSharedRegionHeap(ThreadHeap* h) nothrow @nogc
{
    if (!h)
        return false;
    regionsLock.lock();
    foreach (i; 0 .. allRegionsLen)
    {
        auto r = allRegions[i];
        if (r && r.heap is h)
        {
            regionsLock.unlock();
            return true;
        }
    }
    regionsLock.unlock();
    return false;
}

private GC initialize()
{
    import core.lifetime : emplace;
    import core.gc.config;

    if (config.tgcShared == "symgc")
        tgcSharedBackend = TgcSharedBackend.symgc;

    auto gc = cast(ThreadGC) cstdlib.malloc(__traits(classInstanceSize, ThreadGC));
    if (!gc)
        onOutOfMemoryError();

    auto inst = emplace(gc);
    tgcInstance = inst;
    return inst;
}

/**
 * Thread-local GC implementation (`tgc` 0.1.0 prototype).
 *
 * Also known informally as a "realtime GC" because local collection does not
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
        if (isSharedRegionHeap(owner) || owner is local || local is null)
        {
            owner.unlinkAndFree(blk);
            return;
        }
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
        auto blk = queryBlock(ptr);
        if (!blk || !(blk.attr & BlkAttr.APPENDABLE))
            return null;
        auto used = blk.arrayUsed ? blk.arrayUsed : blk.size;
        return (cast(void*)(blk + 1))[0 .. used];
    }

    bool expandArrayUsed(void[] slice, size_t newUsed, bool atomic = false) nothrow @trusted
    {
        if (!slice.length)
            return false;
        auto blk = queryBlock(&slice[0]);
        if (!blk || !(blk.attr & BlkAttr.APPENDABLE))
            return false;
        if (newUsed > blk.size)
            return false;
        blk.arrayUsed = newUsed;
        return true;
    }

    size_t reserveArrayCapacity(void[] slice, size_t request, bool atomic = false) nothrow @trusted
    {
        if (!slice.length || !request)
            return 0;
        auto blk = queryBlock(&slice[0]);
        if (!blk || !(blk.attr & BlkAttr.APPENDABLE))
            return 0;
        if (request <= blk.size)
            return blk.size;
        auto bits = blk.attr;
        auto oldUsed = blk.arrayUsed ? blk.arrayUsed : slice.length;
        auto np = alloc(request, bits, false);
        memcpy(np, &slice[0], oldUsed < slice.length ? oldUsed : slice.length);
        free(&slice[0]);
        auto nblk = headerOf(np);
        nblk.arrayUsed = oldUsed;
        return request;
    }

    bool shrinkArrayUsed(void[] slice, size_t existingUsed, bool atomic = false) nothrow
    {
        if (!slice.ptr)
            return false;
        auto blk = queryBlock(slice.ptr);
        if (!blk || !(blk.attr & BlkAttr.APPENDABLE))
            return false;
        if (existingUsed > blk.size)
            return false;
        blk.arrayUsed = existingUsed;
        return true;
    }

    package void markPtrHeap(ThreadHeap* heap, void* p) nothrow @nogc
    {
        markPtrInHeap(heap, p);
    }

    package void markRangeHeap(ThreadHeap* heap, void* pbot, void* ptop) nothrow @nogc
    {
        markRangeInHeap(heap, pbot, ptop);
    }

    /// Returns true if fixpoint converged (safe to sweep).
    package bool markHeapFixpoint(ThreadHeap* heap) nothrow @nogc
    {
        size_t markedCount = 0;
        heap.listLock.lock();
        foreach (i; 0 .. heap.blockLen)
            if (heap.blocks[i].marked)
                markedCount++;
        heap.listLock.unlock();

        size_t prevMarked = size_t.max;
        enum maxFixpointPasses = 256;
        BlkHeader** work = null;
        size_t workCap = 0;

        for (uint pass = 0; pass < maxFixpointPasses && prevMarked != markedCount; ++pass)
        {
            prevMarked = markedCount;
            // Snapshot scan candidates under lock; scan unlocked (findBlock takes lock).
            heap.listLock.lock();
            size_t workLen = 0;
            foreach (i; 0 .. heap.blockLen)
            {
                auto b = heap.blocks[i];
                if (!b.marked || (b.attr & BlkAttr.NO_SCAN))
                    continue;
                if (workLen == workCap)
                {
                    size_t ncap = workCap ? workCap * 2 : 8;
                    auto np = cast(BlkHeader**) cstdlib.realloc(work, ncap * (BlkHeader*).sizeof);
                    if (!np)
                    {
                        heap.listLock.unlock();
                        cstdlib.free(work);
                        onOutOfMemoryError();
                    }
                    work = np;
                    workCap = ncap;
                }
                work[workLen++] = b;
            }
            heap.listLock.unlock();

            foreach (i; 0 .. workLen)
            {
                auto b = work[i];
                void* base = b + 1;
                size_t scanLen = (b.attr & BlkAttr.APPENDABLE) && b.arrayUsed
                    ? b.arrayUsed : b.size;
                markRangeInHeap(heap, base, base + scanLen);
            }

            markedCount = 0;
            heap.listLock.lock();
            foreach (i; 0 .. heap.blockLen)
                if (heap.blocks[i].marked)
                    markedCount++;
            heap.listLock.unlock();
        }
        cstdlib.free(work);
        return prevMarked == markedCount;
    }

    package void sweepHeap(ThreadHeap* heap) nothrow
    {
        BlkHeader** doomed = null;
        size_t doomedLen = 0;
        size_t doomedCap = 0;
        heap.listLock.lock();
        for (size_t i = heap.blockLen; i > 0; --i)
        {
            auto b = heap.blocks[i - 1];
            if (b.marked)
                continue;
            heap.indexRemove(b);
            if (doomedLen == doomedCap)
            {
                size_t ncap = doomedCap ? doomedCap * 2 : 8;
                auto np = cast(BlkHeader**) cstdlib.realloc(doomed, ncap * (BlkHeader*).sizeof);
                if (!np)
                {
                    heap.listLock.unlock();
                    onOutOfMemoryError();
                }
                doomed = np;
                doomedCap = ncap;
            }
            doomed[doomedLen++] = b;
        }
        heap.listLock.unlock();

        foreach (i; 0 .. doomedLen)
        {
            auto b = doomed[i];
            if (b.attr & BlkAttr.FINALIZE)
                rt_finalizeFromGC(b + 1, b.size, b.attr, null);
            cstdlib.free(b);
        }
        cstdlib.free(doomed);
    }

    void initThread(ThreadBase t) nothrow @nogc
    {
        auto h = currentHeap();
        h.owner = t;
        t.tlsGCData() = h;
    }

    void cleanupThread(ThreadBase t) nothrow @nogc
    {
        auto h = cast(ThreadHeap*) t.tlsGCData();
        if (!h)
            return;
        // Free remaining blocks; do not leave memory owned by a dead thread.
        h.drainRemote();
        while (h.blockLen)
        {
            auto cur = h.blocks[h.blockLen - 1];
            h.unlinkAndFree(cur);
        }
        unregisterHeap(h);
        if (tlsHeap is h)
            tlsHeap = null;
        t.tlsGCData() = null;
        regionsLock.lock();
        foreach (i; 0 .. allRegionsLen)
        {
            auto r = allRegions[i];
            if (!r)
                continue;
            r.lock.lock();
            foreach (j; 0 .. r.memberLen)
            {
                if (r.memberHeaps[j] is h)
                {
                    r.memberHeaps[j] = r.memberHeaps[r.memberLen - 1];
                    r.memberThreads[j] = r.memberThreads[r.memberLen - 1];
                    r.memberLen--;
                    break;
                }
            }
            r.lock.unlock();
        }
        regionsLock.unlock();
        cstdlib.free(h.remotePtrs);
        cstdlib.free(h.blocks);
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
        regionsLock.lock();
        foreach (i; 0 .. allRegionsLen)
        {
            auto r = allRegions[i];
            if (!r || !r.heap)
                continue;
            if (auto b = r.heap.findBlock(p))
            {
                regionsLock.unlock();
                return b;
            }
        }
        regionsLock.unlock();
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
        h.arrayUsed = (bits & BlkAttr.APPENDABLE) ? size : 0;
        h.heap = heap;
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

        heap.listLock.lock();
        foreach (i; 0 .. heap.blockLen)
            heap.blocks[i].marked = 0;
        heap.listLock.unlock();

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
            markRangeInHeap(heap, top, bot);
        }

        markTLSHeap(heap);

        rootsLock.lock();
        foreach (ref r; roots)
        {
            if (r.proot)
                markPtrInHeap(heap, *cast(void**) r.proot);
            markPtrInHeap(heap, r.proot);
        }
        foreach (ref r; ranges)
            markRangeInHeap(heap, r.pbot, r.ptop);
        rootsLock.unlock();

        if (markHeapFixpoint(heap))
            sweepHeap(heap);
        // Non-converged fixpoint: skip sweep (safer than freeing live objects).

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

    void markTLSHeap(ThreadHeap* heap) nothrow
    {
        import rt.sections;
        auto rng = initTLSRanges();
        scanTLSRanges(rng, (void* pbeg, void* pend) nothrow {
            markRangeInHeap(heap, pbeg, pend);
        });
    }

    void markRangeInHeap(ThreadHeap* heap, void* pbot, void* ptop) nothrow @nogc
    {
        if (!pbot || !ptop || pbot >= ptop)
            return;
        enum maxScanBytes = 4 * 1024 * 1024;
        auto scanTop = ptop;
        if (cast(size_t)(scanTop - pbot) > maxScanBytes)
            scanTop = pbot + maxScanBytes;
        auto p = cast(void**) pbot;
        auto e = cast(void**) scanTop;
        auto addr = cast(size_t) p;
        addr = (addr + (void*).sizeof - 1) & ~((void*).sizeof - 1);
        p = cast(void**) addr;
        size_t steps;
        for (; p + 1 <= e && steps < maxScanBytes / (void*).sizeof; ++p, ++steps)
            markPtrInHeap(heap, *p);
    }

    void markPtrInHeap(ThreadHeap* heap, void* p) nothrow @nogc
    {
        if (!p)
            return;
        auto b = heap.findBlock(p);
        if (b)
            b.marked = 1;
    }

    static BlkHeader* headerOf(void* p) nothrow @nogc
    {
        return ThreadHeap.headerOf(p);
    }
}
