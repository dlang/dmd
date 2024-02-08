import core.runtime;
import core.atomic;
import core.stdc.string;

shared uint tlsDtor, dtor;
void staticDtorHook() { atomicOp!"+="(tlsDtor, 1); }
void sharedStaticDtorHook() { atomicOp!"+="(dtor, 1); }

void runTest(string name)
{
    auto h = Runtime.loadLibrary(name);
    assert(h !is null);

    import utils : loadSym;
    void function()* pLibStaticDtorHook, pLibSharedStaticDtorHook;
    loadSym(h, pLibStaticDtorHook, "_D9lib_1341414staticDtorHookOPFZv");
    loadSym(h, pLibSharedStaticDtorHook, "_D9lib_1341420sharedStaticDtorHookOPFZv");

    *pLibStaticDtorHook = &staticDtorHook;
    *pLibSharedStaticDtorHook = &sharedStaticDtorHook;

    const unloaded = Runtime.unloadLibrary(h);
    version (CRuntime_Musl)
    {
        // On Musl, unloadLibrary is a no-op because dlclose is a no-op
        assert(!unloaded);
        assert(tlsDtor == 0);
        assert(dtor == 0);
    }
    else
    {
        assert(unloaded);
        assert(tlsDtor == 1);
        assert(dtor == 1);
    }
}

void main(string[] args)
{
    import utils : dllExt;
    auto name = args[0] ~ '\0';
    const pathlen = strrchr(name.ptr, '/') - name.ptr + 1;
    name = name[0 .. pathlen] ~ "lib_13414." ~ dllExt;

    runTest(name);
}
