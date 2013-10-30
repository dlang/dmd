import core.thread, core.memory;

shared uint gctor, gdtor, tctor, tdtor;
shared static this() { ++gctor; }
shared static ~this() { ++gdtor; }
static this() { ++tctor; }
static ~this() { ++tdtor; }

Thread t;

void launchThread() { (t = new Thread({})).start(); }
void joinThread() { t.join(); }

extern(C) int runTests()
{
    try
    {
        assert(gctor == 1);
        assert(gdtor == 0);
        assert(tctor >= 1);
        assert(tdtor >= 0);
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
