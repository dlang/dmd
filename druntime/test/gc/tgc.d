/**
 * Smoke tests for the opt-in thread-local GC (`tgc`, 0.1.0 prototype).
 *
 * Run with: --DRT-gcopt=gc:tgc
 */
import core.memory;
import core.thread;
import core.atomic;

extern (C) uint _d_tgc_region_create() nothrow @nogc;
extern (C) bool _d_tgc_region_attach(uint regionId) nothrow @nogc;
extern (C) void* _d_tgc_region_malloc(uint regionId, size_t size, uint bits) nothrow @nogc;
extern (C) const(char)* _d_tgc_version() nothrow @nogc;

shared size_t otherThreadAllocs;
shared bool otherDone;
shared bool collectDone;

void worker()
{
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
    assert(ver !is null && !strcmp(ver, "0.2.0"));

    // Shared region scaffold: create, attach, alloc
    auto rid = _d_tgc_region_create();
    assert(rid != 0);
    bool attached = _d_tgc_region_attach(rid);
    assert(attached);
    auto rp = cast(int*) _d_tgc_region_malloc(rid, int.sizeof, 0);
    assert(rp !is null);
    *rp = 123;
    assert(*rp == 123);

    auto before = GC.profileStats().numCollections;

    // Local allocations
    int[] local;
    foreach (i; 0 .. 50)
        local ~= cast(int) i;
    assert(local.length == 50);

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
