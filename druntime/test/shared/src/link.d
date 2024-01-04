import lib;

version (DigitalMars) version = NoExceptions;

void testEH()
{
    bool passed;
    try
        lib.throwException();
    catch (Exception e)
        passed = true;
    _assert(passed); passed = false;

    _assert(lib.collectException({throw new Exception(null);}) !is null);
    _assert(lib.collectException({lib.throwException();}) !is null);
}

void testGC()
{
    import core.memory;
    lib.alloc();
    lib.tls_alloc();
    lib.access();
    lib.tls_access();
    GC.collect();
    lib.tls_access();
    lib.access();
    lib.tls_free();
    lib.free();
}

// order of dtor calls during termination reversed as lib.dll is unloaded before druntime_shared.dll
shared uint lib_unloaded = 0;

import core.atomic : atomicOp;
shared static this() { _assert(lib.shared_static_ctor == 1); }
shared static ~this() { _assert(lib.shared_static_dtor == lib_unloaded); }
shared uint static_ctor, static_dtor;
static this() { _assert(lib.static_ctor == atomicOp!"+="(static_ctor, 1)); }
static ~this() { _assert(lib.static_dtor + 1 - lib_unloaded == atomicOp!"+="(static_dtor, 1)); }

void testInit()
{
    import core.thread;

    _assert(shared_static_ctor == 1);
    _assert(static_ctor == 1);

    _assert(lib.static_ctor == 1);
    _assert(lib.static_dtor == 0);
    static void foo()
    {
        _assert(lib.shared_static_ctor == 1);
        _assert(lib.shared_static_dtor == 0);
        _assert(lib.static_ctor == 2);
        _assert(lib.static_dtor == 0);
    }
    auto thr = new Thread(&foo);
    thr.start();
    _assert(thr.join() is null);
    _assert(lib.shared_static_ctor == 1);
    _assert(lib.shared_static_dtor == 0);
    _assert(lib.static_ctor == 2);
    _assert(lib.static_dtor == 1);
}

void main()
{
    version (NoExceptions) {}
    else
        testEH();
    testGC();
    testInit();
    version (Windows) lib_unloaded = 1;
}
