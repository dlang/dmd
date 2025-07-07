import core.atomic;
import core.runtime;
import core.stdc.string : strrchr;

shared uint tlsDtor, dtor;
void staticDtorHook() { atomicOp!"+="(tlsDtor, 1); }
void sharedStaticDtorHook() { atomicOp!"+="(dtor, 1); }

void runTest(string name)
{
    auto h = Runtime.loadLibrary(name);
    assert(h !is null);

    import utils : isDlcloseNoop, loadSym;
    void function()* pLibStaticDtorHook, pLibSharedStaticDtorHook;
    loadSym(h, pLibStaticDtorHook, "_D9lib_1341414staticDtorHookOPFZv");
    loadSym(h, pLibSharedStaticDtorHook, "_D9lib_1341420sharedStaticDtorHookOPFZv");

    *pLibStaticDtorHook = &staticDtorHook;
    *pLibSharedStaticDtorHook = &sharedStaticDtorHook;

    const unloaded = Runtime.unloadLibrary(h);
    assert(unloaded);
    assert(tlsDtor == 1);
    static if (isDlcloseNoop)
        assert(dtor == 0);
    else
        assert(dtor == 1);
}

void main(string[] args)
{
    import utils : dllExt;
    auto name = args[0] ~ '\0';
    const pathlen = strrchr(name.ptr, '/') - name.ptr + 1;
    name = name[0 .. pathlen] ~ "lib_13414." ~ dllExt;

    runTest(name);
}
