import core.runtime, core.sys.posix.dlfcn;

extern(C) alias RunDepTests = int function(const char*);

void main(string[] args)
{
    auto root = args[0][0..$-"load_loaddep".length];
    auto libloaddep = root ~ "libloaddep.so";
    auto h = Runtime.loadLibrary(libloaddep);
    auto runDepTests = cast(RunDepTests)dlsym(h, "runDepTests");
    assert(runDepTests((root ~ "lib.so\0").ptr));
    assert(Runtime.unloadLibrary(h));
}
