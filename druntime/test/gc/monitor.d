import core.gc.monitor;
import core.memory;

__gshared size_t numAllocs;
__gshared size_t numFreesExplicit, numFreesCollected;
__gshared size_t allocBytes;
__gshared size_t numCollects;
__gshared size_t freedPagesTotal;

void onAlloc(void* p, size_t size) nothrow @nogc
{
    numAllocs++;
    allocBytes += size;
}

void onFree(void* p, size_t size, bool collected) nothrow @nogc
{
    assert(size > 0);
    if (collected)
        numFreesCollected++;
    else
        numFreesExplicit++;
}

void onCollect(size_t freedPages) nothrow @nogc
{
    numCollects++;
    freedPagesTotal += freedPages;
}

// keep allocations out of main's stack frame so the conservative
// collector does not see stale references to the garbage
pragma(inline, false)
void allocateGarbage()
{
    foreach (i; 0 .. 1000)
    {
        auto arr = new ubyte[](1024 + i);
        // touch the memory so the allocation is not optimized away
        arr[0] = 0xA5;
    }
}

void main()
{
    setGCMonitor(&onAlloc, &onFree, &onCollect);

    allocateGarbage();
    auto live = new ubyte[](256);

    const beforeCollectAllocs = numAllocs;
    assert(beforeCollectAllocs >= 1001);
    assert(allocBytes > 0);

    GC.collect();

    // Most of the garbage must have been reported as freed by
    // collections (conservative scanning may retain a few blocks).
    assert(numFreesCollected >= beforeCollectAllocs * 9 / 10);
    assert(numCollects >= 1);
    assert(freedPagesTotal > 0);

    // an explicit free is reported as such
    auto explicitFree = new ubyte[](64);
    const beforeExplicit = numFreesExplicit;
    GC.free(explicitFree.ptr);
    assert(numFreesExplicit == beforeExplicit + 1);

    // unregistering must stop the reporting
    setGCMonitor(null, null, null);
    const beforeAllocs = numAllocs, beforeCollects = numCollects;
    auto uncounted = new ubyte[](32);
    GC.collect();
    assert(numAllocs == beforeAllocs);
    assert(numCollects == beforeCollects);

    // keep `live` and `uncounted` alive until here
    assert(live[0] == 0 && uncounted[0] == 0);
}
