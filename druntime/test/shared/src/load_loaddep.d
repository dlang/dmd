import core.runtime;
import core.stdc.string;

extern(C) alias RunDepTests = int function(const char*);

void main(string[] args)
{
    import utils : dllExt, loadSym;

    auto name = args[0] ~ '\0';
    const pathlen = strrchr(name.ptr, '/') - name.ptr + 1;
    auto root = name[0 .. pathlen];
    auto libloaddep = root ~ "libloaddep." ~ dllExt;
    auto h = Runtime.loadLibrary(libloaddep);
    RunDepTests runDepTests;
    loadSym(h, runDepTests, "runDepTests");
    assert(runDepTests((root ~ "lib." ~ dllExt ~ "\0").ptr));
    assert(Runtime.unloadLibrary(h));
}
