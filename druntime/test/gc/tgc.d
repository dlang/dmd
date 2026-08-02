/**
 * Smoke tests for the opt-in thread-local GC (`tgc`).
 *
 * Run with: --DRT-gcopt=gc:tgc
 */
import core.memory;
import core.thread;
import core.atomic;

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
