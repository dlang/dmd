/**
 * A GC leak detector, reimplemented on top of core.gc.monitor.
 *
 * This used to be compiled into the conservative GC under
 * debug (LOGGING), requiring a specially-built druntime. As the GC
 * reports every allocation and free (including blocks reclaimed by
 * collections) to a registered monitor, the same functionality is
 * now available in a plain program against a stock druntime.
 *
 * The detector tracks every GC allocation and free, and after each
 * collection prints the blocks allocated since the previous collection
 * that survived it, i.e. potential leaks.
 */
import core.gc.monitor;
import core.memory;

import core.stdc.stdio : printf;
import core.stdc.stdlib : free, realloc;
import core.stdc.string : memmove;

struct Log
{
    void* p;
    size_t size;
}

// Log storage must come from the C heap: monitor callbacks must not
// allocate GC memory, and the C heap is not scanned by the GC, so
// storing the pointers there does not keep the blocks alive.
__gshared Log* logs;
__gshared size_t numLogs, capLogs;
__gshared size_t numCollects;

void onAlloc(void* p, size_t size) nothrow @nogc
{
    if (numLogs == capLogs)
    {
        capLogs = capLogs ? capLogs * 2 : 1024;
        logs = cast(Log*) realloc(logs, capLogs * Log.sizeof);
        assert(logs !is null);
    }
    logs[numLogs++] = Log(p, size);
}

void onFree(void* p, size_t size, bool collected) nothrow @nogc
{
    foreach (i; 0 .. numLogs)
    {
        if (logs[i].p is p)
        {
            memmove(logs + i, logs + i + 1, (numLogs - i - 1) * Log.sizeof);
            numLogs--;
            return;
        }
    }
}

void onCollect(size_t freedPages) nothrow @nogc
{
    numCollects++;
    printf("collection %zu: %zu pages freed, %zu blocks still live\n",
           numCollects, freedPages, numLogs);
}

bool isLogged(void* p) nothrow @nogc
{
    foreach (i; 0 .. numLogs)
        if (logs[i].p is p)
            return true;
    return false;
}

// Keep the garbage out of main's stack frame so the conservative
// collector does not see stale references to it.
pragma(inline, false)
void allocateGarbage()
{
    foreach (i; 0 .. 1000)
    {
        auto arr = new ubyte[](1024 + i);
        arr[0] = 0xA5;
    }
}

void main()
{
    setGCMonitor(&onAlloc, &onFree, &onCollect);

    allocateGarbage();
    auto live = new ubyte[](256);

    GC.collect();
    assert(numCollects >= 1);

    // the collection freed the garbage, which the detector then
    // no longer tracks, while the live block is still accounted for
    assert(isLogged(live.ptr));
    assert(numLogs < 100);

    printf("%zu blocks still live at exit:\n", numLogs);
    foreach (i; 0 .. numLogs)
        printf("    p = %p, size = %llu\n", logs[i].p, cast(ulong) logs[i].size);

    assert(live[0] == 0);
    free(logs);
}
