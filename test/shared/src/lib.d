// test EH
void throwException()
{
    throw new Exception(null);
}

Exception collectException(void delegate() dg)
{
    try
        dg();
    catch (Exception e)
        return e;
    return null;
}

// test GC
__gshared Object root;
void alloc() { root = new Object(); }
void access() { assert(root.toString() !is null); } // vtbl call will fail if finalized
void free() { root = null; }

Object tls_root;
void tls_alloc() { tls_root = new Object(); }
void tls_access() { assert(tls_root.toString() !is null); } // vtbl call will fail if finalized
void tls_free() { tls_root = null; }

// test Init
shared uint shared_static_ctor, shared_static_dtor, static_ctor, static_dtor;
shared static this() { if (++shared_static_ctor != 1) assert(0); }
shared static ~this() { if (++shared_static_dtor != 1) assert(0); }
static this() { ++static_ctor; }
static ~this() { ++static_dtor; }

extern(C) int runTests()
{
    try
        runTestsImpl();
    catch (Throwable)
        return 0;
    return 1;
}

void runTestsImpl()
{
    import core.memory, core.thread;

    bool passed;
    try
        throwException();
    catch (Exception e)
        passed = true;
    assert(passed);
    assert(collectException({throwException();}) !is null);

    alloc();
    tls_alloc();
    access();
    tls_access();
    GC.collect();
    tls_access();
    access();
    tls_free();
    free();

    assert(shared_static_ctor == 1);
    assert(static_ctor == 1);
    static void run()
    {
        assert(static_ctor == 2);
        assert(shared_static_ctor == 1);
    }
    auto thr = new Thread(&run);
    thr.start();
    thr.join();
    assert(static_dtor == 1);

    passed = false;
    foreach (m; ModuleInfo)
        if (m.name == "lib") passed = true;
    assert(passed);
}

// Provide a way to initialize D from C programs that are D agnostic.
import core.runtime : rt_init, rt_term;

extern(C) int lib_init()
{
    return rt_init();
}

extern(C) int lib_term()
{
    return rt_term();
}

shared size_t* _finalizeCounter;

class MyFinalizer
{
    ~this()
    {
        import core.atomic;
        atomicOp!"+="(*_finalizeCounter, 1);
    }
}

class MyFinalizerBig : MyFinalizer
{
    ubyte[4096] _big = void;
}

extern(C) void setFinalizeCounter(shared(size_t)* p)
{
    _finalizeCounter = p;
}
