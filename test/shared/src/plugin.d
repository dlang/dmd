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
