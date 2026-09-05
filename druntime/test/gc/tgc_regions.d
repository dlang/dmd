/**
 * Shared-region tests for tgc 0.2.0+
 *
 * Run with: --DRT-gcopt=gc:tgc
 */
import core.memory;
import core.thread;
import core.atomic;
import core.stdc.string : strcmp;

extern (C) uint _d_tgc_region_create() nothrow @nogc;
extern (C) bool _d_tgc_region_attach(uint regionId) nothrow @nogc;
extern (C) void* _d_tgc_region_malloc(uint regionId, size_t size, uint bits) nothrow @nogc;
extern (C) bool _d_tgc_region_collect(uint regionId) nothrow;
extern (C) const(char)* _d_tgc_version() nothrow @nogc;

shared uint regionId;
shared bool workerReady;
shared bool collectDone;
shared int* sharedCell;

void worker()
{
    bool attached = _d_tgc_region_attach(regionId);
    assert(attached);
    sharedCell = cast(shared int*) _d_tgc_region_malloc(regionId, int.sizeof, 0);
    assert(sharedCell !is null);
    atomicStore(workerReady, true);

    while (!atomicLoad(collectDone))
        Thread.yield();

    // Must still be valid after region collect from main (root on main after join setup)
    assert(*sharedCell == 42);
}

void main()
{
    auto ver = _d_tgc_version();
    assert(ver !is null && !strcmp(ver, "0.2.1"));

    regionId = _d_tgc_region_create();
    assert(regionId != 0);
    bool attached = _d_tgc_region_attach(regionId);
    assert(attached);

    auto t = new Thread(&worker);
    t.start();

    while (!atomicLoad(workerReady))
        Thread.yield();

    // Keep a reference on this thread so the cell stays live
    auto localRef = sharedCell;
    assert(localRef !is null);
    *localRef = 42;

    bool collected = _d_tgc_region_collect(regionId);
    assert(collected);
    atomicStore(collectDone, true);
    t.join();

    assert(*localRef == 42);

    // Junk collect on private heap still works
    foreach (i; 0 .. 100)
        auto x = new int[i % 17 + 1];
    GC.collect();
}
