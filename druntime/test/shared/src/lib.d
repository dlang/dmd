module lib;

// use _assert instead of assert to also fail in release builds
void _assert(bool cond)
{
    if (!cond) assert(false);
}

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
void access() { _assert(root.toString() !is null); } // vtbl call will fail if finalized
void free() { root = null; }

Object tls_root;
void tls_alloc() { tls_root = new Object(); }
void tls_access() { _assert(tls_root.toString() !is null); } // vtbl call will fail if finalized
void tls_free() { tls_root = null; }

void stack(alias func)()
{
    // allocate some extra stack space to not keep references to GC memory on the scanned stack
    ubyte[1024] buf = void;
    func();
}

void testGC()
{
    import core.memory;

    stack!alloc();
    stack!tls_alloc();
    stack!access();
    stack!tls_access();
    GC.collect();
    stack!tls_access();
    stack!access();
    stack!tls_free();
    stack!free();
}

// test Init
import core.atomic : atomicOp;
shared uint shared_static_ctor, shared_static_dtor, static_ctor, static_dtor;
shared static this() { _assert(atomicOp!"+="(shared_static_ctor, 1) == 1); }
shared static ~this() { _assert(atomicOp!"+="(shared_static_dtor, 1) == 1); }
static this() { atomicOp!"+="(static_ctor, 1); }
static ~this() { atomicOp!"+="(static_dtor, 1); }

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
    import core.thread;

    bool passed;
    try
        throwException();
    catch (Exception e)
        passed = true;
    _assert(passed);
    _assert(collectException({throwException();}) !is null);

    testGC();

    _assert(shared_static_ctor == 1);
    _assert(static_ctor == 1);
    static void run()
    {
        _assert(static_ctor == 2);
        _assert(shared_static_ctor == 1);
        testGC();
    }
    auto thr = new Thread(&run);
    thr.start();
    thr.join();
    _assert(static_dtor == 1);

    passed = false;
    foreach (m; ModuleInfo)
        if (m.name == "lib") passed = true;
    _assert(passed);
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

version (DigitalMars) version (Windows)
{
    import core.sys.windows.dll;
    mixin SimpleDllMain;
}
