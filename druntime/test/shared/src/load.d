import core.runtime;
import core.stdc.string : strrchr;
import core.thread;

version (DragonFlyBSD) import core.sys.dragonflybsd.dlfcn : RTLD_NOLOAD;
version (FreeBSD) import core.sys.freebsd.dlfcn : RTLD_NOLOAD;
version (linux) import core.sys.linux.dlfcn : RTLD_NOLOAD;
version (NetBSD) import core.sys.netbsd.dlfcn : RTLD_NOLOAD;
version (OSX) import core.sys.darwin.dlfcn : RTLD_NOLOAD;
version (Solaris) import core.sys.solaris.dlfcn : RTLD_NOLOAD;

void* openLib(string s)
{
    auto h = Runtime.loadLibrary(s);
    assert(h !is null);

    import utils : loadSym;

    loadSym(h, libThrowException, "_D3lib14throwExceptionFZv");
    loadSym(h, libCollectException, "_D3lib16collectExceptionFDFZvZC9Exception");

    loadSym(h, libAlloc, "_D3lib5allocFZv");
    loadSym(h, libTlsAlloc, "_D3lib9tls_allocFZv");
    loadSym(h, libAccess, "_D3lib6accessFZv");
    loadSym(h, libTlsAccess, "_D3lib10tls_accessFZv");
    loadSym(h, libFree, "_D3lib4freeFZv");
    loadSym(h, libTlsFree, "_D3lib8tls_freeFZv");

    loadSym(h, libSharedStaticCtor, "_D3lib18shared_static_ctorOk");
    loadSym(h, libSharedStaticDtor, "_D3lib18shared_static_dtorOk");
    loadSym(h, libStaticCtor, "_D3lib11static_ctorOk");
    loadSym(h, libStaticDtor, "_D3lib11static_dtorOk");

    return h;
}

void closeLib(void* h)
{
    Runtime.unloadLibrary(h);
}

__gshared
{
    void function() libThrowException;
    Exception function(void delegate()) libCollectException;

    void function() libAlloc;
    void function() libTlsAlloc;
    void function() libAccess;
    void function() libTlsAccess;
    void function() libFree;
    void function() libTlsFree;

    shared uint* libSharedStaticCtor;
    shared uint* libSharedStaticDtor;
    shared uint* libStaticCtor;
    shared uint* libStaticDtor;
}

void testEH()
{
    bool passed;
    try
        libThrowException();
    catch (Exception e)
        passed = true;
    assert(passed); passed = false;

    assert(libCollectException({throw new Exception(null);}) !is null);
    assert(libCollectException({libThrowException();}) !is null);
}

void testGC()
{
    import core.memory;
    libAlloc();
    libTlsAlloc();
    libAccess();
    libTlsAccess();
    GC.collect();
    libTlsAccess();
    libAccess();
    libTlsFree();
    libFree();
}

void testInit()
{

    assert(*libStaticCtor == 1);
    assert(*libStaticDtor == 0);
    static void run()
    {
        assert(*libSharedStaticCtor == 1);
        assert(*libSharedStaticDtor == 0);
        assert(*libStaticCtor == 2);
        assert(*libStaticDtor == 0);
    }
    auto thr = new Thread(&run);
    thr.start();
    thr.join();
    assert(*libSharedStaticCtor == 1);
    assert(*libSharedStaticDtor == 0);
    assert(*libStaticCtor == 2);
    assert(*libStaticDtor == 1);
}

const(ModuleInfo)* findModuleInfo(string name)
{
    foreach (m; ModuleInfo)
        if (m.name == name) return m;
    return null;
}

void runTests(string libName)
{
    assert(findModuleInfo("lib") is null);
    auto handle = openLib(libName);
    assert(findModuleInfo("lib") !is null);

    testEH();
    testGC();
    testInit();

    closeLib(handle);
    assert(findModuleInfo("lib") is null);
}

void main(string[] args)
{
    auto name = args[0] ~ '\0';
    const pathlen = strrchr(name.ptr, '/') - name.ptr + 1;
    import utils : dllExt, isDlcloseNoop;
    name = name[0 .. pathlen] ~ "lib." ~ dllExt;

    runTests(name);

    static if (!isDlcloseNoop)
    {
        // lib is no longer resident
        name ~= '\0';
        version (Windows)
        {
            import core.sys.windows.winbase;
            assert(!GetModuleHandleA(name.ptr));
        }
        else
        {
            import core.sys.posix.dlfcn : dlopen, RTLD_LAZY;
            assert(dlopen(name.ptr, RTLD_LAZY | RTLD_NOLOAD) is null);
        }
        name = name[0 .. $-1];

        auto thr = new Thread({runTests(name);});
        thr.start();
        thr.join();
    }
}
