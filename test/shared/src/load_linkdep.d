import core.runtime, core.sys.posix.dlfcn;

extern(C) alias RunDepTests = int function();

void main(string[] args)
{
    auto name = args[0];
    assert(name[$-13 .. $] == "/load_linkdep");
    name = name[0 .. $-12] ~ "liblinkdep.so";

    auto h = Runtime.loadLibrary(name);
    assert(h);
    auto runDepTests = cast(RunDepTests)dlsym(h, "runDepTests");
    assert(runDepTests());
    assert(Runtime.unloadLibrary(h));
}
