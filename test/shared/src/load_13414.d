import core.runtime, core.atomic, core.sys.linux.dlfcn;

shared uint tlsDtor, dtor;
void staticDtorHook() { atomicOp!"+="(tlsDtor, 1); }
void sharedStaticDtorHook() { atomicOp!"+="(dtor, 1); }

void runTest(string name)
{
    auto h = Runtime.loadLibrary(name);
    assert(h !is null);

    *cast(void function()*).dlsym(h, "_D9lib_1341414staticDtorHookOPFZv") = &staticDtorHook;
    *cast(void function()*).dlsym(h, "_D9lib_1341420sharedStaticDtorHookOPFZv") = &sharedStaticDtorHook;

    Runtime.unloadLibrary(h);
    assert(tlsDtor == 1);
    assert(dtor == 1);
}

void main(string[] args)
{
    auto name = args[0];
    assert(name[$-"load_13414".length-1 .. $] == "/load_13414");
    name = name[0 .. $-"load_13414".length] ~ "lib_13414.so";

    runTest(name);
}
