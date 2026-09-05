// https://github.com/dlang/dmd/issues/23081
// GC scan threads livelock when no global stack pop occurs during markParallel.
//
// evStackFilled is a manual-reset event.  markParallel sets it unconditionally
// before the pull loop.  If toscanRoots is small enough that pointersPerThread==0
// (nothing pre-pushed to the global scan stack) AND the live structure fits in
// mark()'s 32-entry local stack (nothing spills), the event is never reset.
// Background scan threads then spin forever: evStackFilled.wait() returns
// immediately, pullFromScanStack is a no-op, evDone is broadcast, repeat.
//
// The fix resets evStackFilled after pullLoop returns, symmetrically with the
// setIfInitialized() call above it.
//
// We use parallel:128 (capped to logical_cpus - 1 by startScanThreads) to push
// numScanThreads as high as the host allows.  The bug only triggers when
// numScanThreads + 1 exceeds toscanRoots.length, so on few-core CI runners this
// test passes without exercising the regression path; on many-core machines
// (>= ~20 cores) it reliably triggers without the fix.
//
// NOTE: GC.collect() calls fullcollect(isFinal=true) which disables parallel
// scan threads.  To trigger parallel marking we rely on automatic collections
// driven by allocations filling the initial pool.

import core.memory;
import core.thread;
import core.stdc.stdio;
import core.sys.posix.sys.resource;
import core.time;

void main()
{
    auto collections = GC.profileStats().numCollections;

    // Allocate enough to fill the first GC pool (minPoolSize:1 = 1MB) so the
    // allocator triggers an automatic collection (isFinal=false path) rather
    // than growing the heap.  Keep each object tiny so the live set is small.
    foreach (i; 0 .. 8192)
        new int[32]; // 8192 * 128 bytes = 1MB of small allocations

    assert(GC.profileStats().numCollections > collections,
        "test did not trigger an automatic GC collection");

    // Measure CPU consumption during a quiescent sleep.
    // Without the fix, the scan threads from the last automatic collection
    // are still spinning because evStackFilled was never reset.
    rusage before, after;
    getrusage(RUSAGE_SELF, &before);
    Thread.sleep(500.msecs);
    getrusage(RUSAGE_SELF, &after);

    long userUs = (after.ru_utime.tv_sec  - before.ru_utime.tv_sec)  * 1_000_000L
                + (after.ru_utime.tv_usec - before.ru_utime.tv_usec);
    long sysUs  = (after.ru_stime.tv_sec  - before.ru_stime.tv_sec)  * 1_000_000L
                + (after.ru_stime.tv_usec - before.ru_stime.tv_usec);
    long totalCpuUs = userUs + sysUs;
    long wallUs = 500_000L;

    double ratio = cast(double)totalCpuUs / wallUs;
    printf("CPU/wall ratio during quiescent sleep: %.2f\n", ratio);
    assert(ratio < 2.0, "GC scan threads are spinning -- livelock detected (#23081)");
}
