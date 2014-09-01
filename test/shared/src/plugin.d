import core.thread, core.memory, core.atomic;

shared uint gctor, gdtor, tctor, tdtor;
shared static this() { if (atomicOp!"+="(gctor, 1) != 1) assert(0); }
shared static ~this() { if (atomicOp!"+="(gdtor, 1) != 1) assert(0); }
static this() { atomicOp!"+="(tctor, 1); }
static ~this() { atomicOp!"+="(tdtor, 1); }

Thread t;

void launchThread() { (t = new Thread({})).start(); }
void joinThread() { t.join(); }

extern(C) int runTests()
{
    try
    {
        assert(atomicLoad!(MemoryOrder.acq)(gctor) == 1);
        assert(atomicLoad!(MemoryOrder.acq)(gdtor) == 0);
        assert(atomicLoad!(MemoryOrder.acq)(tctor) >= 1);
        assert(atomicLoad!(MemoryOrder.acq)(tdtor) >= 0);
        // test some runtime functionality
        launchThread();
        GC.collect();
        joinThread();
    }
    catch (Throwable)
    {
        return false;
    }
    return true;
}

// Provide a way to initialize D from C programs that are D agnostic.
import core.runtime : rt_init, rt_term;

extern(C) int plugin_init()
{
    return rt_init();
}

extern(C) int plugin_term()
{
    return rt_term();
}
