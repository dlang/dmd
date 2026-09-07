/**
 * Smoke tests for the opt-in thread-local GC (`tgc`, 0.1.0 prototype).
 *
 * Run with: --DRT-gcopt=gc:tgc
 */
import core.memory;
import core.thread;
import core.atomic;
import core.exception : OutOfMemoryError;
import cstdlib = core.stdc.stdlib;
import core.stdc.string : memset;

extern (C) uint _d_tgc_region_create() nothrow @nogc;
extern (C) bool _d_tgc_region_attach(uint regionId) nothrow @nogc;
extern (C) void* _d_tgc_region_malloc(uint regionId, size_t size, uint bits) nothrow @nogc;
extern (C) const(char)* _d_tgc_version() nothrow @nogc;

shared size_t otherThreadAllocs;
shared bool otherDone;
shared bool collectDone;

class ChainNode
{
    ChainNode next;
    size_t value;
}

pragma(inline, false)
ChainNode makeChain(size_t length)
{
    ChainNode head;
    foreach_reverse (i; 0 .. length)
    {
        auto node = new ChainNode;
        node.next = head;
        node.value = i;
        head = node;
    }
    return head;
}

pragma(inline, false)
void installTailRoot(void* range, size_t bytes)
{
    auto target = new ubyte[256];
    target[0] = 0x5A;
    *cast(void**)(range + bytes - (void*).sizeof) = target.ptr;
}

pragma(inline, false)
void clobberStack()
{
    void*[8192] zeros;
    zeros[] = null;
}

void worker()
{
    // A fresh worker heap exercises the tiny-index linear lookup tier.
    void*[4] tinyBlocks;
    foreach (ref p; tinyBlocks)
        p = GC.malloc(32, GC.BlkAttr.NO_SCAN);
    foreach (p; tinyBlocks)
    {
        auto found = GC.addrOf(p + 7);
        assert(found == p);
        GC.free(p);
    }

    // Allocate on this thread's private heap
    foreach (i; 0 .. 100)
    {
        auto p = new int[64];
        p[0] = cast(int) i;
        atomicOp!"+="(otherThreadAllocs, 1);
    }
    // Keep a live allocation so collect on another thread must not free it
    auto keep = new ubyte[1024];
    keep[0] = 42;

    // Wait until main has collected, then verify our data survived
    while (!atomicLoad(collectDone))
        Thread.yield();

    assert(keep[0] == 42);
    atomicStore(otherDone, true);
}

void main()
{
    import core.stdc.string : strcmp;
    auto ver = _d_tgc_version();
    assert(ver !is null && !strcmp(ver, "0.2.3"));

    // Shared region scaffold: create, attach, alloc
    auto rid = _d_tgc_region_create();
    assert(rid != 0);
    bool attached = _d_tgc_region_attach(rid);
    assert(attached);
    auto rp = cast(int*) _d_tgc_region_malloc(rid, int.sizeof, 0);
    assert(rp !is null);
    *rp = 123;
    assert(*rp == 123);

    // Exercise both lookup tiers and interior-pointer handling.
    void*[16] blocks;
    foreach (i; 0 .. blocks.length)
        blocks[i] = GC.malloc(64, GC.BlkAttr.NO_SCAN);
    foreach (p; blocks)
    {
        auto interior = p + 31;
        auto found = GC.addrOf(interior);
        assert(found == p);
        assert(GC.sizeOf(interior) == 0);
        assert(GC.getAttr(interior) == 0);
        auto setResult = GC.setAttr(interior, GC.BlkAttr.NO_MOVE);
        auto clearResult = GC.clrAttr(interior, GC.BlkAttr.NO_SCAN);
        assert(setResult == 0);
        assert(clearResult == 0);
        auto resized = GC.realloc(interior, 128);
        assert(resized is null);
        GC.free(interior);
        auto stillLive = GC.addrOf(p);
        assert(stillLive == p);
        auto atEnd = GC.addrOf(p + 64);
        assert(atEnd is null);
    }
    auto removed = blocks[7];
    GC.free(removed);
    auto removedLookup = GC.addrOf(removed + 1);
    assert(removedLookup is null);
    blocks[7] = null;
    foreach (p; blocks)
        GC.free(p);

    bool overflowRejected;
    try
    {
        auto impossible = GC.malloc(size_t.max);
        if (impossible)
            GC.free(impossible);
    }
    catch (OutOfMemoryError)
        overflowRejected = true;
    assert(overflowRejected);

    auto before = GC.profileStats().numCollections;

    // Local allocations
    int[] local;
    foreach (i; 0 .. 50)
        local ~= cast(int) i;
    assert(local.length == 50);

    // A heap pointer chain requires fixpoint marking beyond direct roots.
    auto chain = makeChain(300);
    GC.collect();
    size_t chainLength;
    for (auto node = chain; node; node = node.next)
    {
        assert(node.value == chainLength);
        chainLength++;
    }
    assert(chainLength == 300);

    // The sole deliberate root is beyond the old 4 MiB scan cutoff.
    enum registeredBytes = 5 * 1024 * 1024;
    auto registered = cstdlib.malloc(registeredBytes);
    assert(registered !is null);
    memset(registered, 0, registeredBytes);
    GC.addRange(registered, registeredBytes);
    installTailRoot(registered, registeredBytes);
    clobberStack();
    GC.collect();
    auto tailRoot = *cast(void**)(registered + registeredBytes - (void*).sizeof);
    assert((cast(ubyte*) tailRoot)[0] == 0x5A);
    GC.removeRange(registered);
    cstdlib.free(registered);

    auto t = new Thread(&worker);
    t.start();

    // Wait until the worker has allocated
    while (atomicLoad(otherThreadAllocs) < 50)
        Thread.yield();

    // Collect on the main thread only — must not STW-destroy worker heap
    GC.collect();
    atomicStore(collectDone, true);

    t.join();
    assert(atomicLoad(otherDone));

    // Detach smoke: spawn work then detach is documented for @nogc threads;
    // here we only verify GC still functions after a normal thread exit.
    auto after = GC.profileStats().numCollections;
    assert(after >= before);

    // Force more collections via threshold pressure
    foreach (i; 0 .. 200)
    {
        auto junk = new ubyte[4096];
        junk[0] = cast(ubyte) i;
    }
    GC.collect();

    assert(local[0] == 0 && local[$ - 1] == 49);
}
