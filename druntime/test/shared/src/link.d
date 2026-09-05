import lib;

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

import core.atomic : atomicLoad, atomicOp;
shared static this() { _assert(atomicLoad(lib.shared_static_ctor) == 1); }
shared static ~this() { _assert(atomicLoad(lib.shared_static_dtor) == 0); }
shared uint static_ctor, static_dtor;
static this() { _assert(atomicLoad(lib.static_ctor) == atomicOp!"+="(static_ctor, 1)); }
static ~this() { _assert(atomicLoad(lib.static_dtor) + 1 == atomicOp!"+="(static_dtor, 1)); }

void testInit()
{
    import core.thread;

    _assert(atomicLoad(shared_static_ctor) == 1);
    _assert(atomicLoad(static_ctor) == 1);

    _assert(atomicLoad(lib.static_ctor) == 1);
    _assert(atomicLoad(lib.static_dtor) == 0);
    static void foo()
    {
        _assert(atomicLoad(lib.shared_static_ctor) == 1);
        _assert(atomicLoad(lib.shared_static_dtor) == 0);
        _assert(atomicLoad(lib.static_ctor) == 2);
        _assert(atomicLoad(lib.static_dtor) == 0);
    }
    auto thr = new Thread(&foo);
    thr.start();
    _assert(thr.join() is null);
    _assert(atomicLoad(lib.shared_static_ctor) == 1);
    _assert(atomicLoad(lib.shared_static_dtor) == 0);
    _assert(atomicLoad(lib.static_ctor) == 2);
    _assert(atomicLoad(lib.static_dtor) == 1);
}

void main()
{
    testEH();
    testGC();
    testInit();
}
