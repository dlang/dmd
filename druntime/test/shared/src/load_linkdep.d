import core.runtime;
import core.stdc.string;

extern(C) alias RunDepTests = int function();

void main(string[] args)
{
    import utils : dllExt, loadSym;

    auto name = args[0] ~ '\0';
    const pathlen = strrchr(name.ptr, '/') - name.ptr + 1;
    name = name[0 .. pathlen] ~ "liblinkdep." ~ dllExt;

    auto h = Runtime.loadLibrary(name);
    assert(h);
    RunDepTests runDepTests;
    loadSym(h, runDepTests, "runDepTests");
    assert(runDepTests());
    assert(Runtime.unloadLibrary(h));
}
