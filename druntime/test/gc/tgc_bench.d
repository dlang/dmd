/**
 * Simple GC benchmark for comparing backends.
 *
 * Usage:
 *   tgc_bench                         # default conservative GC
 *   tgc_bench --DRT-gcopt=gc:tgc
 *   tgc_bench --DRT-gcopt=gc:tgc tgcShared:symgc
 *
 * Environment: TGC_BENCH_ITERS (default 50000), TGC_BENCH_THREADS (default 4)
 */
import core.memory;
import core.thread;
import core.time;
import core.stdc.stdio;
import core.stdc.stdlib;

extern (C) uint _d_tgc_region_create() nothrow @nogc;
extern (C) bool _d_tgc_region_attach(uint regionId) nothrow @nogc;
extern (C) void* _d_tgc_region_malloc(uint regionId, size_t size, uint bits) nothrow @nogc;
extern (C) const(char)* _d_tgc_version() nothrow @nogc;

__gshared uint benchRegion;

void allocWorker()
{
    if (benchRegion)
        _d_tgc_region_attach(benchRegion);
    foreach (i; 0 .. 2000)
    {
        if (benchRegion)
        {
            auto p = cast(int*) _d_tgc_region_malloc(benchRegion, 64, 0);
            if (p)
                *p = cast(int) i;
        }
        else
        {
            auto p = new int[16];
            p[0] = cast(int) i;
        }
    }
}

void main()
{
    size_t iters = 50_000;
    size_t nThreads = 4;
    if (const v = getenv("TGC_BENCH_ITERS"))
        iters = cast(size_t) atol(v);
    if (const v = getenv("TGC_BENCH_THREADS"))
        nThreads = cast(size_t) atol(v);

    const char* ver = _d_tgc_version();
    if (ver && ver[0])
        printf("tgc version: %s\n", ver);

    foreach (i; 0 .. 1000)
        auto w = new byte[128];
    GC.collect();

    MonoTime t0 = MonoTime.currTime;
    foreach (i; 0 .. iters)
    {
        auto p = new byte[64 + (i & 63)];
        p[0] = cast(byte) i;
    }
    printf("single-thread alloc: %llu ms (%zu allocs)\n",
           cast(ulong)(MonoTime.currTime - t0).total!"msecs", iters);

    t0 = MonoTime.currTime;
    GC.collect();
    printf("GC.collect pause: %llu ms\n", cast(ulong)(MonoTime.currTime - t0).total!"msecs");

    if (_d_tgc_version()[0])
    {
        benchRegion = _d_tgc_region_create();
        _d_tgc_region_attach(benchRegion);
    }

    Thread[] threads;
    threads.length = nThreads;
    t0 = MonoTime.currTime;
    foreach (i; 0 .. nThreads)
    {
        threads[i] = new Thread(&allocWorker);
        threads[i].start();
    }
    foreach (t; threads)
        t.join();
    printf("multi-thread worker phase: %llu ms (%zu threads)\n",
           cast(ulong)(MonoTime.currTime - t0).total!"msecs", nThreads);

    auto stats = GC.profileStats();
    printf("collections: %llu\n", cast(ulong) stats.numCollections);
}
